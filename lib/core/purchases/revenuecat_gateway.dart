/// The one file in `lib/` that imports `package:purchases_flutter`.
///
/// That is a checked fact, not a convention:
/// `test/purchases/purchase_privacy_test.dart` asserts the import resolves here
/// and nowhere else. It is the same containment
/// `notification_service.dart` holds over the notifications plugin, and it
/// exists for the same two reasons — every plugin call throws under
/// `flutter test`, and a seam that leaks its implementation's types stops being
/// a seam the first time a widget reads one.
///
/// ## What this class deliberately does not do
///
/// It never calls `setAttributes`, `setEmail`, `setDisplayName`,
/// `setPhoneNumber` or `logIn`. **Subscriber attributes are the only place app
/// data could reach RevenueCat's systems**, and they contain nothing unless
/// something puts it there. That is what keeps the app's narrowed privacy
/// claim — supplement data never leaves the device, the only traffic is the
/// purchase, and it carries none of it — true by construction rather than by
/// intention. A source gate holds it.
///
/// It also never reads `CustomerInfo` and never asks about entitlements. The
/// app sells three consumable tips that unlock nothing, so there is no state to
/// restore, nothing to gate, and no reinstall asymmetry to design around
/// (SHIP-01, decided 2026-09-09).
library;

import 'package:flutter/services.dart' show PlatformException;
import 'package:purchases_flutter/purchases_flutter.dart';

import 'package:vitomy/core/purchases/purchase_gateway.dart';
import 'package:vitomy/core/purchases/revenuecat_key.dart';

/// [PurchaseGateway] backed by the RevenueCat SDK.
class RevenueCatGateway extends PurchaseGateway {
  /// The public SDK key this instance configures with.
  ///
  /// Injected with a default rather than read from the constant directly, so a
  /// test can construct one over a fake key without the constant being
  /// reachable from the assertion.
  final String apiKey;

  const RevenueCatGateway({this.apiKey = revenueCatIosKey});

  @override
  Future<void> configure() async {
    // An empty key is the un-filled state of `revenuecat_key.dart`, and
    // handing it to the SDK produces an opaque platform error a few frames
    // later. Failing here instead puts the reason in the crash report that
    // `PurchaseBootstrap` writes, and lands the screen on its honest
    // "unavailable" state rather than on a purchase sheet that cannot work.
    if (apiKey.isEmpty) {
      throw StateError('revenueCatIosKey is empty');
    }
    // Rejected at the seam as well as by two gates, because the gates protect
    // the repository and this protects a build made from a dirty tree. A Test
    // Store key routes every purchase to a simulator modal and takes no money,
    // while looking from the inside exactly like a working build.
    if (apiKey.startsWith('test_')) {
      throw StateError('revenueCatIosKey is a Test Store key');
    }
    await Purchases.setLogLevel(LogLevel.info);
    await Purchases.configure(PurchasesConfiguration(apiKey));
  }

  @override
  Future<List<TipProduct>> tips() async {
    final offerings = await Purchases.getOfferings();
    final current = offerings.current;
    // No current offering is a NORMAL answer, not an error: products still in
    // review in App Store Connect, or a dashboard whose offering has not been
    // marked current, both arrive here. The screen renders it as "unavailable".
    if (current == null) return const <TipProduct>[];
    return [
      for (final package in current.availablePackages)
        TipProduct(
          id: package.storeProduct.identifier,
          // The store's own formatted price, verbatim. It already carries the
          // user's storefront currency, its symbol, its placement and its
          // separator, and the app must not try to reproduce any of the four.
          priceString: package.storeProduct.priceString,
        ),
    ];
  }

  @override
  Future<TipPurchaseResult> buy(String productId) async {
    final offerings = await Purchases.getOfferings();
    final current = offerings.current;
    if (current == null) return TipPurchaseResult.failed;
    // Matched by product identifier rather than by RevenueCat package id: the
    // seam speaks App Store product ids, which is what App Store Connect, the
    // receipt and a support email all agree on. A package identifier is a
    // RevenueCat-side name that can be renamed in a dashboard without any
    // store noticing.
    Package? match;
    for (final package in current.availablePackages) {
      if (package.storeProduct.identifier == productId) match = package;
    }
    if (match == null) return TipPurchaseResult.failed;
    try {
      // `Purchases.purchase(PurchaseParams…)` rather than the older
      // `purchasePackage`, which is deprecated in 10.x.
      await Purchases.purchase(PurchaseParams.package(match));
      return TipPurchaseResult.bought;
    } on PlatformException catch (error) {
      // The user backing out of the system sheet is the ONE outcome that must
      // produce no message at all, so it is separated here rather than in the
      // screen, where a reader would have to know that one error code among
      // dozens is not an error.
      final code = PurchasesErrorHelper.getErrorCode(error);
      return code == PurchasesErrorCode.purchaseCancelledError
          ? TipPurchaseResult.cancelled
          : TipPurchaseResult.failed;
    } catch (_) {
      // Anything the SDK can raise that is not a PlatformException. A purchase
      // sheet is the one place in this app where an unhandled error would
      // surface on top of the operating system's own UI.
      return TipPurchaseResult.failed;
    }
  }
}
