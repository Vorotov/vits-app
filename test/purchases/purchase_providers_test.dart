/// The ordering guarantee this layer exists for, proved by driving it.
///
/// The SDK throws `There is no singleton instance` when any method is called
/// while `configure()` is still in flight (purchases-flutter #1090, #1187). A
/// comment saying "call configure first" is not a control; a counter asserting
/// the offering was never fetched early is. Most of this file is that one
/// claim, approached from several directions.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vitomy/core/purchases/purchase_gateway.dart';
import 'package:vitomy/core/purchases/purchase_providers.dart';

import 'recording_gateway.dart';

void main() {
  const small = TipProduct(id: 'app.vitomy.tip.small', priceString: r'$2.99');
  const medium = TipProduct(id: 'app.vitomy.tip.medium', priceString: r'$4.99');

  /// A container over the recorder, with the post-frame trigger disabled so
  /// each test drives the bootstrap itself. Without the override the notifier
  /// would schedule its own configure on the first frame and race every
  /// assertion below.
  ProviderContainer containerOver(
    RecordingPurchaseGateway gateway, {
    bool autoBootstrap = false,
  }) {
    final container = ProviderContainer(
      overrides: [
        purchaseGatewayProvider.overrideWithValue(gateway),
        purchaseAutoBootstrapProvider.overrideWithValue(autoBootstrap),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  /// Captures what reaches the crash logger, the way
  /// `test/l10n/cold_start_degradation_test.dart` does. Every degradation in
  /// this layer is silent to the user and reported to the logger, so the report
  /// is the only evidence the failure was noticed at all: asserting it turns
  /// what would otherwise be noise in the test output into a checked fact.
  List<FlutterErrorDetails> captureReports() {
    final reported = <FlutterErrorDetails>[];
    final previous = FlutterError.onError;
    FlutterError.onError = reported.add;
    addTearDown(() => FlutterError.onError = previous);
    return reported;
  }

  group('readiness', () {
    test('starts pending, and nothing has been asked of the SDK', () {
      final gateway = RecordingPurchaseGateway();
      final container = containerOver(gateway);
      expect(container.read(purchaseReadinessProvider), PurchaseReadiness.pending);
      expect(gateway.configureCalls, 0);
      expect(
        gateway.tipsCalls,
        0,
        reason: 'reading the readiness provider must not itself reach the SDK',
      );
    });

    test('becomes ready once configure completes', () async {
      final gateway = RecordingPurchaseGateway();
      final container = containerOver(gateway);
      await container.read(purchaseReadinessProvider.notifier).bootstrap();
      expect(container.read(purchaseReadinessProvider), PurchaseReadiness.ready);
      expect(gateway.configureCalls, 1);
    });

    test('a configure that throws leaves it FAILED, and does not rethrow',
        () async {
      final reported = captureReports();
      final gateway = RecordingPurchaseGateway(throwOnConfigure: true);
      final container = containerOver(gateway);
      await expectLater(
        container.read(purchaseReadinessProvider.notifier).bootstrap(),
        completes,
        reason: 'this runs from a post-frame callback, where an escaping error '
            'becomes an unhandled root-zone error. The stance is the one '
            'NotificationBootstrap takes: a subsystem carrying one feature may '
            'not hold the app hostage',
      );
      expect(container.read(purchaseReadinessProvider), PurchaseReadiness.failed);
      expect(reported, hasLength(1));
      expect(
        reported.single.context.toString(),
        contains('configuring the purchase SDK'),
        reason: 'the user sees nothing, so the crash logger is the only place '
            'this failure is ever visible',
      );
    });

    test('bootstrapping twice configures once', () async {
      final gateway = RecordingPurchaseGateway();
      final container = containerOver(gateway);
      final notifier = container.read(purchaseReadinessProvider.notifier);
      await notifier.bootstrap();
      await notifier.bootstrap();
      expect(
        gateway.configureCalls,
        1,
        reason: 'the SDK is a singleton and configuring it twice is a '
            'documented way to lose the first configuration',
      );
    });

    test('two bootstraps racing configure once', () async {
      final gateway = RecordingPurchaseGateway();
      final container = containerOver(gateway);
      final notifier = container.read(purchaseReadinessProvider.notifier);
      await Future.wait([notifier.bootstrap(), notifier.bootstrap()]);
      expect(gateway.configureCalls, 1);
    });
  });

  group('the support controller', () {
    test('offers nothing and asks nothing while readiness is pending',
        () async {
      final gateway = RecordingPurchaseGateway(offered: [small, medium]);
      final container = containerOver(gateway);
      final state = container.read(supportControllerProvider);
      expect(state.phase, SupportPhase.preparing);
      expect(state.tips, isEmpty);
      await Future<void>.delayed(Duration.zero);
      expect(
        gateway.tipsCalls,
        0,
        reason: 'THE bug this whole layer exists to prevent: asking for an '
            'offering before configure has completed throws "There is no '
            'singleton instance" from inside the SDK',
      );
    });

    test('fetches the offering once readiness flips, and offers it', () async {
      final gateway = RecordingPurchaseGateway(offered: [small, medium]);
      final container = containerOver(gateway);
      container.listen(supportControllerProvider, (_, _) {});
      await container.read(purchaseReadinessProvider.notifier).bootstrap();
      await Future<void>.delayed(Duration.zero);
      final state = container.read(supportControllerProvider);
      expect(gateway.tipsCalls, 1);
      expect(state.phase, SupportPhase.offered);
      expect(state.tips, [small, medium]);
    });

    test('an empty offering is UNAVAILABLE, not an error', () async {
      final gateway = RecordingPurchaseGateway();
      final container = containerOver(gateway);
      container.listen(supportControllerProvider, (_, _) {});
      await container.read(purchaseReadinessProvider.notifier).bootstrap();
      await Future<void>.delayed(Duration.zero);
      expect(
        container.read(supportControllerProvider).phase,
        SupportPhase.unavailable,
        reason: 'a device that has never been online cannot fetch an offering, '
            'and that is a normal state to render honestly rather than a crash',
      );
    });

    test('a failed configure lands on UNAVAILABLE without touching the SDK '
        'again', () async {
      captureReports();
      final gateway = RecordingPurchaseGateway(throwOnConfigure: true);
      final container = containerOver(gateway);
      container.listen(supportControllerProvider, (_, _) {});
      await container.read(purchaseReadinessProvider.notifier).bootstrap();
      await Future<void>.delayed(Duration.zero);
      expect(container.read(supportControllerProvider).phase,
          SupportPhase.unavailable);
      expect(gateway.tipsCalls, 0);
    });

    test('an offering fetch that throws is UNAVAILABLE, not a thrown error',
        () async {
      final reported = captureReports();
      final gateway = RecordingPurchaseGateway(throwOnTips: true);
      final container = containerOver(gateway);
      container.listen(supportControllerProvider, (_, _) {});
      await container.read(purchaseReadinessProvider.notifier).bootstrap();
      await Future<void>.delayed(Duration.zero);
      expect(container.read(supportControllerProvider).phase,
          SupportPhase.unavailable);
      expect(reported.single.context.toString(),
          contains('fetching the tip offering'));
    });
  });

  group('buying', () {
    /// A container already carrying an offering, which is the only state a buy
    /// can start from.
    Future<ProviderContainer> offering(RecordingPurchaseGateway gateway) async {
      final container = containerOver(gateway);
      container.listen(supportControllerProvider, (_, _) {});
      await container.read(purchaseReadinessProvider.notifier).bootstrap();
      await Future<void>.delayed(Duration.zero);
      expect(container.read(supportControllerProvider).phase,
          SupportPhase.offered);
      return container;
    }

    test('a bought tip ends on THANKS', () async {
      final gateway = RecordingPurchaseGateway(offered: [small]);
      final container = await offering(gateway);
      await container.read(supportControllerProvider.notifier).buy(small.id);
      expect(container.read(supportControllerProvider).phase,
          SupportPhase.thanks);
      expect(gateway.bought, [small.id]);
    });

    test('a cancelled tip returns to the offer with NO failure flag', () async {
      final gateway = RecordingPurchaseGateway(
        offered: [small],
        result: TipPurchaseResult.cancelled,
      );
      final container = await offering(gateway);
      await container.read(supportControllerProvider.notifier).buy(small.id);
      final state = container.read(supportControllerProvider);
      expect(state.phase, SupportPhase.offered);
      expect(
        state.failed,
        isFalse,
        reason: 'swiping the system sheet away is not an error and must '
            'surface nothing at all. This is the single most common complaint '
            'about hand-built purchase screens',
      );
    });

    test('a failed tip returns to the offer WITH the failure flag', () async {
      final gateway = RecordingPurchaseGateway(
        offered: [small],
        result: TipPurchaseResult.failed,
      );
      final container = await offering(gateway);
      await container.read(supportControllerProvider.notifier).buy(small.id);
      final state = container.read(supportControllerProvider);
      expect(state.phase, SupportPhase.offered);
      expect(state.failed, isTrue);
      expect(state.tips, [small],
          reason: 'the offer must survive a failure, or a user who taps once '
              'and misses is left with an empty screen');
    });

    test('a second buy clears the previous failure before it starts', () async {
      final gateway = RecordingPurchaseGateway(
        offered: [small],
        result: TipPurchaseResult.failed,
      );
      final container = await offering(gateway);
      final notifier = container.read(supportControllerProvider.notifier);
      await notifier.buy(small.id);
      expect(container.read(supportControllerProvider).failed, isTrue);
      gateway.result = TipPurchaseResult.bought;
      await notifier.buy(small.id);
      expect(container.read(supportControllerProvider).failed, isFalse);
    });

    test('a buy while one is in flight is ignored', () async {
      final gateway = RecordingPurchaseGateway(offered: [small]);
      final container = await offering(gateway);
      final notifier = container.read(supportControllerProvider.notifier);
      await Future.wait([notifier.buy(small.id), notifier.buy(small.id)]);
      expect(
        gateway.bought,
        [small.id],
        reason: 'two system purchase sheets cannot be open at once, and a '
            'double tap on a 44px target is ordinary',
      );
    });

    test('buying while preparing reaches the store not at all', () async {
      final gateway = RecordingPurchaseGateway(offered: [small]);
      final container = containerOver(gateway);
      await container.read(supportControllerProvider.notifier).buy(small.id);
      expect(gateway.bought, isEmpty);
    });
  });
}
