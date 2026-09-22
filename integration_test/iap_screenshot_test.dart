/// Captures the App Store Connect review screenshot for the three tips.
///
/// ## Why this is separate from `store_screenshots_test.dart`
///
/// Different asset, different destination. That file produces the listing
/// gallery, and `tool/make_screenshots.sh` clears its output directory and
/// derives a 6.5-inch set from it. The support screen does not belong in a
/// listing gallery: it is the picture App Store Connect demands in the
/// **Review Screenshot** field of each in-app purchase, so it goes to its own
/// directory and never joins the five.
///
/// ## Why the offering is stubbed, and why that is honest
///
/// App Store Connect will not let a product be submitted without a screenshot
/// showing where it appears in the app, and the app cannot show a real price
/// until the product exists and is approved. That is a genuine circle, and
/// Apple's own answer to it is that the screenshot may show the purchase as it
/// will appear.
///
/// So this pumps the REAL screen, with the real copy, the real layout and the
/// real product identifiers, and replaces exactly one thing: the network call
/// that fetches prices. The prices below are the prices being configured in
/// App Store Connect. Nothing about the picture is a mock-up, and no part of
/// it is drawn by this file.
///
/// The stub lives here, in `integration_test/`, and never in `lib/`. The seam
/// it plugs into is `purchaseGatewayProvider`, which defaults to the no-op and
/// is overridden in `main()` for production;
/// `test/purchases/purchase_privacy_test.dart` asserts the plugin behind it
/// stays reachable from exactly one file.
///
///     tool/make_iap_screenshot.sh
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vitomy/core/providers.dart';
import 'package:vitomy/core/purchases/purchase_gateway.dart';
import 'package:vitomy/core/purchases/purchase_providers.dart';
import 'package:vitomy/core/purchases/tip_products.dart';
import 'package:vitomy/features/support/support_screen.dart';
import 'package:vitomy/main.dart' show VitomyApp;

const Duration _screenshotWait = Duration(seconds: 8);

/// The three tips exactly as they are being configured in App Store Connect,
/// with the US storefront's formatting.
///
/// Change these together with the prices in the dashboard, or the screenshot
/// starts describing a product that is not for sale.
const _offering = <TipProduct>[
  TipProduct(id: tipSmallId, priceString: r'$0.99'),
  TipProduct(id: tipMediumId, priceString: r'$1.99'),
  TipProduct(id: tipLargeId, priceString: r'$4.99'),
];

/// A gateway that answers from [_offering] and refuses to buy anything.
///
/// [buy] is deliberately unreachable rather than merely unused: this runs on a
/// simulator against a build with no products, and a real purchase attempt
/// would open a system sheet over the screen being photographed.
class _ScreenshotGateway extends PurchaseGateway {
  const _ScreenshotGateway();

  @override
  Future<void> configure() async {}

  @override
  Future<List<TipProduct>> tips() async => _offering;

  @override
  Future<TipPurchaseResult> buy(String productId) async =>
      TipPurchaseResult.cancelled;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('in-app purchase review screenshot', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    // English is the store's primary language, and neither the intro nor a
    // first-run hint belongs in a screenshot Apple will read.
    await prefs.setString('app_locale', 'en');
    await prefs.setBool('onboarding_seen', true);
    await prefs.setStringList(
      'first_run_hints_seen',
      const ['hint_cycle', 'hint_mark_dose'],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          purchaseGatewayProvider.overrideWithValue(const _ScreenshotGateway()),
        ],
        child: const VitomyApp(),
      ),
    );
    await _pump(tester, 20);

    // Settings is a pushed route behind the gear, on whichever tab the app
    // opened. Found by the gear's own glyph rather than by its semantics
    // label: the label is `settingsTitle`, which is the string "Settings", and
    // `find.bySemanticsLabel` matched a list item inside the scrollable body
    // first. The glyph is unambiguous.
    await _tap(
      tester,
      find.ancestor(
        of: find.byIcon(Icons.settings_outlined),
        matching: find.byType(IconButton),
      ),
    );
    await _pumpUntil(
      tester,
      () => find.text('Reset intro and hints').evaluate().isNotEmpty,
      'the Settings screen',
    );

    // Settings is a ListView and the support row is its last entry, so on a
    // phone it is genuinely below the fold and not built at all. Scrolling is
    // the same thing a user does, and `find.text` cannot see an unbuilt child.
    final supportRow = find.text('Support the developer');
    if (supportRow.evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        supportRow,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await _pump(tester, 6);
    }

    await _tap(tester, supportRow.first);
    await _pumpUntil(
      tester,
      () =>
          find.byType(SupportScreen).evaluate().isNotEmpty &&
          find.text(r'$4.99').evaluate().isNotEmpty,
      'the support screen with all three tips priced',
    );
    // All three must be on screen, or the picture does not show the product it
    // is filed against.
    expect(find.text(r'$0.99'), findsOneWidget);
    expect(find.text(r'$1.99'), findsOneWidget);
    expect(find.text(r'$4.99'), findsOneWidget);

    await _screenshot(tester, 'tip-review');
    debugPrint('iap screenshot: done');
  });
}

Future<void> _pump(WidgetTester tester, int frames, [int ms = 50]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(Duration(milliseconds: ms));
  }
}

Future<void> _pumpUntil(
  WidgetTester tester,
  bool Function() condition,
  String what, {
  int attempts = 200,
}) async {
  for (var i = 0; i < attempts; i++) {
    if (condition()) return;
    await tester.pump(const Duration(milliseconds: 50));
  }
  fail('timed out waiting for $what');
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder.first);
  await _pump(tester, 4);
  await tester.tap(finder.first);
  await _pump(tester, 10);
}

/// Asks the host watcher for a screenshot, the mechanism
/// `store_screenshots_test.dart` and `data03_loop_test.dart` both use: the test
/// process runs on the device and cannot spawn `xcrun`, so it drops a request
/// file and waits for it to disappear.
Future<void> _screenshot(WidgetTester tester, String name) async {
  File? request;
  try {
    final dir = await getApplicationDocumentsDirectory();
    request = File('${dir.path}/bq_shot_$name.request');
    await request.writeAsString(name);
  } catch (e) {
    debugPrint('screenshot request failed for $name: $e');
    return;
  }
  for (var i = 0; i < _screenshotWait.inMilliseconds ~/ 50; i++) {
    await tester.pump(const Duration(milliseconds: 50));
    if (!request.existsSync()) {
      debugPrint('iap screenshot: captured $name');
      return;
    }
  }
  try {
    request.deleteSync();
  } catch (_) {}
  debugPrint('iap screenshot: NOT captured (no host watcher): $name');
}
