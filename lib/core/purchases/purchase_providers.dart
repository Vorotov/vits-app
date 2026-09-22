/// The purchase layer's Riverpod graph: the mockable seam, the readiness whose
/// ORDERING is a checked fact, and the one screen's state machine.
///
/// ## Why readiness is a three-valued enum and not a bool
///
/// A bool can say "ready", and its negation then has to carry two different
/// situations that the support screen must render differently: the SDK has not
/// finished configuring yet, and the SDK tried and could not. The first is a
/// sub-second window in which the screen shows a quiet placeholder; the second
/// is a lasting state in which it says so. Collapsing them would put the word
/// "unavailable" on screen for a moment during every ordinary launch, which is
/// the kind of flash P-4 already exists to remove elsewhere in this app.
///
/// ## Dispose policy
///
/// [purchaseGatewayProvider] and [purchaseReadinessProvider] are app-lifetime,
/// inheriting the stance recorded once in `core/providers.dart`: configure runs
/// once per launch and its answer is good for the session.
/// [supportControllerProvider] is autoDispose, which the same policy permits
/// for screen-scoped state, and here it is what makes leaving and reopening the
/// screen re-fetch a stale offering.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:vitomy/core/purchases/purchase_gateway.dart';

/// The seam every test mocks.
///
/// **Defaults to the no-op implementation**, and is overridden in `main()` with
/// the RevenueCat-backed one. The same choice `notificationSchedulerProvider`
/// makes, for the same reason: a throwing default would break every test that
/// pumps the root app widget, while a no-op default makes it impossible for a
/// test to reach the plugin by accident.
///
/// The cost is paid by a test rather than by a comment: a forgotten override
/// means a shipped build that can never sell anything, so a source gate asserts
/// `main()` installs it.
final purchaseGatewayProvider = Provider<PurchaseGateway>(
  (ref) => const NoopPurchaseGateway(),
);

/// Whether [PurchaseBootstrap] schedules its own post-first-frame configure.
///
/// True in production, overridden to false by the provider suite so each test
/// drives the bootstrap itself rather than racing a frame callback. It is a
/// provider rather than a constructor argument because the notifier is built by
/// Riverpod, which hands it no arguments at all.
final purchaseAutoBootstrapProvider = Provider<bool>((ref) => true);

/// How far the SDK has got.
enum PurchaseReadiness {
  /// Configure has not finished. The screen shows a placeholder, and nothing
  /// anywhere may call the SDK.
  pending,

  /// Configure completed. The SDK may be asked for an offering.
  ready,

  /// Configure threw. There is nothing to sell this session, and the screen
  /// says so.
  failed,
}

/// App-lifetime: the SDK is configured once per launch.
final purchaseReadinessProvider =
    NotifierProvider<PurchaseBootstrap, PurchaseReadiness>(
  PurchaseBootstrap.new,
);

/// Configures the SDK AFTER the first frame, and reports how it went.
///
/// **The ordering is binding, not stylistic**, and it is the same rule
/// `NotificationBootstrap` follows for the same class of reason. Configure is a
/// network round trip. It has no frame-1 dependency: nothing the app paints on
/// its first frame mentions a purchase, and the one screen that does is three
/// taps away behind a pushed route. Moving it ahead of the first frame would
/// leave the whole suite green and every cold start slower.
class PurchaseBootstrap extends Notifier<PurchaseReadiness> {
  bool _inFlight = false;

  @override
  PurchaseReadiness build() {
    // Its own post-frame callback rather than a call site in `main()`, which is
    // the one window in this app two separate gates police — a counted gate
    // over its awaits and a needle gate over its contents. Scheduling from here
    // means the purchase layer adds nothing to that window at all: `main()`
    // installs an override, and an override installs a value without running a
    // provider body.
    if (ref.read(purchaseAutoBootstrapProvider)) {
      WidgetsBinding.instance.addPostFrameCallback((_) => bootstrap());
    }
    return PurchaseReadiness.pending;
  }

  /// Configures the SDK. Idempotent, and never throws.
  Future<void> bootstrap() async {
    // The caller is a post-frame callback, so the container may already be gone
    // by the time it runs — a test that replaces one scope with another.
    if (!ref.mounted) return;
    if (_inFlight || state != PurchaseReadiness.pending) return;
    _inFlight = true;
    try {
      await ref.read(purchaseGatewayProvider).configure();
      if (ref.mounted) state = PurchaseReadiness.ready;
    } catch (error, stack) {
      // The stance `main()` takes for the preferences store and
      // `NotificationBootstrap` takes for the zone database: a subsystem
      // carrying one feature may not hold the app hostage, and there is
      // nothing the user could do about it anyway (CR-02). A tip that cannot
      // be offered costs a tip.
      //
      // This catch is not defensive padding. It runs from a post-frame
      // callback, where an escaping error is an unhandled root-zone error
      // rather than a caught future — and the first ever launch of a device
      // with no network is a real path into it, because nothing in the SDK
      // works before `api.revenuecat.com` has been reached once.
      if (ref.mounted) state = PurchaseReadiness.failed;
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stack,
          library: 'vitomy',
          context: ErrorDescription('configuring the purchase SDK'),
        ),
      );
    } finally {
      _inFlight = false;
    }
  }
}

/// What the support screen is doing.
///
/// [preparing] and [unavailable] are deliberately distinct for the reason this
/// library's header gives. [thanks] is terminal for the life of the screen: a
/// consumable tip is an event, so there is nothing to return to and nothing to
/// undo.
enum SupportPhase { preparing, offered, purchasing, thanks, unavailable }

/// Everything the support screen renders, as one value.
@immutable
class SupportState {
  final SupportPhase phase;

  /// The offer, empty outside [SupportPhase.offered] and
  /// [SupportPhase.purchasing].
  final List<TipProduct> tips;

  /// Whether the LAST purchase attempt failed. Cleared when the next one
  /// starts, and never set by a cancellation.
  final bool failed;

  const SupportState({
    this.phase = SupportPhase.preparing,
    this.tips = const <TipProduct>[],
    this.failed = false,
  });

  SupportState copyWith({
    SupportPhase? phase,
    List<TipProduct>? tips,
    bool? failed,
  }) =>
      SupportState(
        phase: phase ?? this.phase,
        tips: tips ?? this.tips,
        failed: failed ?? this.failed,
      );

  @override
  bool operator ==(Object other) =>
      other is SupportState &&
      other.phase == phase &&
      other.failed == failed &&
      listEquals(other.tips, tips);

  @override
  int get hashCode => Object.hash(phase, failed, Object.hashAll(tips));
}

/// Screen-scoped, and autoDispose so reopening the screen re-reads the offer.
///
/// `isAutoDispose` on an ordinary [NotifierProvider] rather than the
/// `.autoDispose` builder: Riverpod 3 folded the separate `AutoDisposeNotifier`
/// base class away, and the builder still expects it.
final supportControllerProvider =
    NotifierProvider<SupportController, SupportState>(
  SupportController.new,
  isAutoDispose: true,
);

/// The support screen's whole state machine.
///
/// It owns the offering fetch rather than exposing a `FutureProvider` beside
/// itself, and that is what makes the SDK's ordering rule structural: the only
/// code path that can reach [PurchaseGateway.tips] runs off a readiness value
/// that is already [PurchaseReadiness.ready]. There is no arrangement of
/// widgets that can ask early, because no widget can ask at all.
class SupportController extends Notifier<SupportState> {
  bool _buying = false;

  @override
  SupportState build() {
    // Watched, not read: the screen can be open while configure is still in
    // flight, and this is what moves it off the placeholder when it lands.
    switch (ref.watch(purchaseReadinessProvider)) {
      case PurchaseReadiness.pending:
        return const SupportState();
      case PurchaseReadiness.failed:
        return const SupportState(phase: SupportPhase.unavailable);
      case PurchaseReadiness.ready:
        // Started here rather than awaited: `build` is synchronous, and the
        // screen renders the placeholder until this lands.
        unawaited(_load());
        return const SupportState();
    }
  }

  Future<void> _load() async {
    try {
      final offered = await ref.read(purchaseGatewayProvider).tips();
      if (!ref.mounted) return;
      state = offered.isEmpty
          // An empty offering is not a failure. A device that has never been
          // online cannot fetch one, and neither can a build whose products are
          // still awaiting review in App Store Connect.
          ? const SupportState(phase: SupportPhase.unavailable)
          : SupportState(phase: SupportPhase.offered, tips: offered);
    } catch (error, stack) {
      if (!ref.mounted) return;
      state = const SupportState(phase: SupportPhase.unavailable);
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stack,
          library: 'vitomy',
          context: ErrorDescription('fetching the tip offering'),
        ),
      );
    }
  }

  /// Asks the store to sell [productId].
  ///
  /// Ignored unless the screen is actually showing an offer, which closes two
  /// paths at once: a double tap on a 44px target cannot open two system
  /// purchase sheets, and no code path can reach the SDK while configure is
  /// still in flight.
  Future<void> buy(String productId) async {
    if (_buying || state.phase != SupportPhase.offered) return;
    _buying = true;
    state = state.copyWith(phase: SupportPhase.purchasing, failed: false);
    try {
      final result = await ref.read(purchaseGatewayProvider).buy(productId);
      if (!ref.mounted) return;
      switch (result) {
        case TipPurchaseResult.bought:
          state = state.copyWith(phase: SupportPhase.thanks);
        case TipPurchaseResult.cancelled:
          // Nothing at all. The user swiped the sheet away, which is not an
          // error and must not produce a message.
          state = state.copyWith(phase: SupportPhase.offered);
        case TipPurchaseResult.failed:
          state = state.copyWith(phase: SupportPhase.offered, failed: true);
      }
    } finally {
      _buying = false;
    }
  }
}
