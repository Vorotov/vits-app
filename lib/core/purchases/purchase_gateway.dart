/// The seam between the app and RevenueCat.
///
/// The FIFTH interface in this codebase that exists so the layer above it can
/// be tested without the thing below it. The three repository interfaces are
/// its model in spirit; `NotificationScheduler` is its model in shape, and for
/// the same hard reason: a plugin call under `flutter test` does not no-op, it
/// throws, so any widget tree that reaches un-seamed plugin code dies with an
/// obscure error naming an obfuscated field.
///
/// Three shaping decisions, written down because each is load-bearing.
///
/// 1. **The seam speaks product ids and already-formatted price strings, never
///    RevenueCat types.** No `Package`, no `StoreProduct`, no `CustomerInfo`
///    crosses it. That is what keeps `package:purchases_flutter` resolving in
///    exactly one file of `lib/`, which `test/purchases/purchase_privacy_test.dart`
///    turns into a gate. It also means the support screen can be pumped in a
///    widget test with three hand-built [TipProduct]s and no plugin anywhere.
///
/// 2. **The price is a STRING the store formatted, never a number the app
///    formats.** `StoreProduct.priceString` already carries the user's
///    storefront currency, its symbol, its placement and its separator. An app
///    that turned 4.99 into text would be guessing at all four, and would guess
///    wrong for most of the seven languages this app ships in.
///
/// 3. **Cancelled is a distinct result from failed.** A user who swipes the
///    system sheet away has done nothing wrong and must see nothing at all; a
///    genuine failure earns a message. Collapsing them would produce an error
///    surface after a deliberate back-out, which is the single most common
///    complaint about hand-built purchase screens.
///
/// There is no entitlement, no `CustomerInfo` read, no Restore and no feature
/// gate, and none of that is an omission: the app sells three consumable tips
/// that unlock nothing (SHIP-01, decided 2026-09-09). An auto-renewing
/// subscription, if one is ever wanted, adds methods here rather than reshaping
/// what is here.
library;

/// One tip the store is currently offering.
///
/// Carries what the screen renders and nothing else. Notably NO title and no
/// description: the labels are ARB copy in seven languages, while App Store
/// Connect holds one display name per product in one language. Rendering the
/// store's name would put an untranslated string in the middle of a translated
/// screen.
class TipProduct {
  /// The product id, as App Store Connect and RevenueCat both know it.
  final String id;

  /// The price, formatted by the store for the user's own storefront.
  final String priceString;

  const TipProduct({required this.id, required this.priceString});

  /// Value equality over BOTH fields, deliberately rather than the inherited
  /// identity. Apple can move a storefront price under a running app, and a
  /// `FutureProvider` compares its old value to its new one: identity equality
  /// would make every refresh a distinct object (harmless), while equality over
  /// the id alone would hide a real price change behind a stale render.
  @override
  bool operator ==(Object other) =>
      other is TipProduct && other.id == id && other.priceString == priceString;

  @override
  int get hashCode => Object.hash(id, priceString);

  @override
  String toString() => 'TipProduct($id, $priceString)';
}

/// What came of asking the store to sell one tip.
///
/// Three cases and not two, for the reason in this library's doc comment: the
/// screen renders nothing for [cancelled] and a message for [failed].
enum TipPurchaseResult {
  /// The store took the money. Nothing is unlocked, nothing is persisted, and
  /// nothing needs to be: a consumable tip is an event, not a setting.
  bought,

  /// The user backed out of the system sheet. Not an error; not reported.
  cancelled,

  /// Anything else: no network, a store outage, a declined payment, a build
  /// with no override installed.
  failed,
}

/// Everything the app asks of RevenueCat.
abstract class PurchaseGateway {
  const PurchaseGateway();

  /// Prepares the SDK.
  ///
  /// Runs from a post-first-frame callback, never before `runApp` — it is a
  /// network round trip with no frame-1 dependency, and the two gates over that
  /// window in `test/notifications/` count and needle what may appear there.
  ///
  /// **Nothing else on this interface may be called until this future
  /// completes.** Calling [tips] or [buy] while configure is still in flight
  /// throws `There is no singleton instance` from inside the SDK
  /// (purchases-flutter #1090, #1187, errors.rev.cat/configuring-sdk). That
  /// ordering is not left to a comment: `purchaseBootstrapProvider` exposes a
  /// completion flag and `tipProductsProvider` returns empty until it flips.
  Future<void> configure();

  /// The tips the store will currently sell, in the order the offering lists
  /// them.
  ///
  /// Empty is a NORMAL answer, not an error: a device that has never been
  /// online cannot fetch an offering, and the screen renders that honestly
  /// rather than as a failure.
  Future<List<TipProduct>> tips();

  /// Asks the store to sell the tip with [productId].
  ///
  /// Never throws. Every failure the SDK can raise is mapped to
  /// [TipPurchaseResult.failed], and a user back-out to
  /// [TipPurchaseResult.cancelled], because the caller is a button handler and
  /// a purchase sheet is the one place in this app where an unhandled error
  /// would surface on top of the operating system's own UI.
  Future<TipPurchaseResult> buy(String productId);
}

/// The default every test gets and the one production gets if the override in
/// `main()` is ever dropped.
///
/// **It reports [TipPurchaseResult.failed], and that asymmetry with
/// `NoopNotificationScheduler` is the point.** A no-op scheduler that silently
/// does nothing costs a reminder. A no-op gateway that silently reported
/// success would tell a user their money had arrived when no store had been
/// asked for anything. The honest no-op for a payment is a refusal.
///
/// It defaults to no-op rather than throwing, for the reason
/// `notificationSchedulerProvider` spells out: a throwing default would break
/// every existing test that pumps the root app widget, while this makes it
/// impossible for any test to reach the plugin by accident.
class NoopPurchaseGateway extends PurchaseGateway {
  const NoopPurchaseGateway();

  @override
  Future<void> configure() async {}

  @override
  Future<List<TipProduct>> tips() async => const <TipProduct>[];

  @override
  Future<TipPurchaseResult> buy(String productId) async =>
      TipPurchaseResult.failed;
}
