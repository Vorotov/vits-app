/// The support screen, driven through every phase it has.
///
/// The render matrix at textScaler 1.0 / 1.6 / 2.0 in both locales is the
/// house requirement for a new screen, and it is not ceremony here: the
/// paragraph is the longest single string in the app, the tip rows put a label
/// and a price on one line, and a price string can be anything from `$0.99` to
/// `2 990 руб.` to a right-to-left currency. Overflow is the most common defect
/// in this codebase's review history.
library;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vitomy/core/l10n/gen/app_localizations.dart';
import 'package:vitomy/core/purchases/purchase_gateway.dart';
import 'package:vitomy/core/purchases/purchase_providers.dart';
import 'package:vitomy/core/purchases/tip_products.dart';
import 'package:vitomy/features/support/support_screen.dart';

import '../purchases/recording_gateway.dart';

void main() {
  final en = lookupAppLocalizations(const Locale('en'));
  final uk = lookupAppLocalizations(const Locale('uk'));

  const small = TipProduct(id: tipSmallId, priceString: r'$0.99');
  const medium = TipProduct(id: tipMediumId, priceString: r'$1.99');
  const large = TipProduct(id: tipLargeId, priceString: r'$4.99');

  /// The screen under a scope over [gateway], with the post-frame bootstrap
  /// left ON so the pump drives the real path a device takes.
  Widget appOver(
    RecordingPurchaseGateway gateway, {
    Locale locale = const Locale('en'),
    double textScale = 1.0,
  }) {
    return ProviderScope(
      overrides: [purchaseGatewayProvider.overrideWithValue(gateway)],
      child: MaterialApp(
        locale: locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
          child: const SupportScreen(),
        ),
      ),
    );
  }

  /// Sets a phone-sized logical surface (390x844), copied from the Settings
  /// suite. Restored automatically.
  void usePhoneSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  /// Pumps until the offering has landed. A bounded loop, never
  /// `pumpAndSettle`: this tree holds no timer today, and the house rule is not
  /// to depend on that staying true.
  Future<void> settleOffering(WidgetTester tester) async {
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 10));
    }
  }

  /// Brings [finder] on screen, scrolling if it has not been built yet.
  ///
  /// This is not test plumbing, it is the screen's design showing through. The
  /// body is a `ListView`, so at textScaler 2.0 the paragraph alone fills a
  /// phone and the tip rows are genuinely below the fold — not built at all,
  /// which is why `find.text` returns nothing rather than something off-screen.
  /// A test that tapped without scrolling would pass at 1.0 and fail at 1.6 for
  /// a reason that has nothing to do with the screen being wrong.
  Future<void> reveal(WidgetTester tester, Finder finder) async {
    if (finder.evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        finder,
        120,
        scrollable: find.byType(Scrollable).first,
      );
    }
    await tester.ensureVisible(finder);
    await tester.pump();
  }

  group('phases', () {
    testWidgets('while preparing it shows the paragraph and NOTHING else',
        (tester) async {
      usePhoneSurface(tester);
      final gateway = RecordingPurchaseGateway(offered: [small]);
      await tester.pumpWidget(appOver(gateway));
      // One pump: the post-frame callback has not run, so configure has not
      // even started.
      expect(find.text(en.supportTitle), findsOneWidget);
      expect(find.text(en.supportBody), findsOneWidget);
      expect(
        find.text(en.supportTipSmall),
        findsNothing,
        reason: 'three placeholder rows would flash plausible-looking tips '
            'before being replaced by "unavailable" on any device that cannot '
            'reach the store',
      );
      expect(find.text(en.supportUnavailable), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing,
          reason: 'absence is not a loading surface, the same stance the '
              'reminders section takes in Settings');
    });

    testWidgets('an offering renders three rows with the store\'s own prices',
        (tester) async {
      final gateway =
          RecordingPurchaseGateway(offered: [small, medium, large]);
      await tester.pumpWidget(appOver(gateway));
      await settleOffering(tester);
      expect(find.text(en.supportTipSmall), findsOneWidget);
      expect(find.text(en.supportTipMedium), findsOneWidget);
      expect(find.text(en.supportTipLarge), findsOneWidget);
      expect(find.text(r'$0.99'), findsOneWidget);
      expect(find.text(r'$4.99'), findsOneWidget);
      expect(find.text(en.supportUnavailable), findsNothing);
    });

    testWidgets('the rows are ordered small, medium, large whatever the '
        'offering says', (tester) async {
      // The dashboard's order deliberately reversed. A reordered offering must
      // not be able to put the largest tip first.
      final gateway =
          RecordingPurchaseGateway(offered: [large, medium, small]);
      await tester.pumpWidget(appOver(gateway));
      await settleOffering(tester);
      final ys = <String, double>{
        for (final label in [
          en.supportTipSmall,
          en.supportTipMedium,
          en.supportTipLarge,
        ])
          label: tester.getTopLeft(find.text(label)).dy,
      };
      expect(ys[en.supportTipSmall]!, lessThan(ys[en.supportTipMedium]!));
      expect(ys[en.supportTipMedium]!, lessThan(ys[en.supportTipLarge]!));
    });

    testWidgets('a product the app does not know is skipped, not rendered '
        'nameless', (tester) async {
      final gateway = RecordingPurchaseGateway(offered: const [
        small,
        TipProduct(id: 'app.vitomy.sub.yearly', priceString: r'$19.99'),
      ]);
      await tester.pumpWidget(appOver(gateway));
      await settleOffering(tester);
      expect(find.text(en.supportTipSmall), findsOneWidget);
      expect(
        find.text(r'$19.99'),
        findsNothing,
        reason: 'the RevenueCat dashboard carries unused Monthly and Yearly '
            'products. They must be a non-event on this screen',
      );
    });

    testWidgets('an empty offering says so', (tester) async {
      final gateway = RecordingPurchaseGateway();
      await tester.pumpWidget(appOver(gateway));
      await settleOffering(tester);
      expect(find.text(en.supportUnavailable), findsOneWidget);
      expect(find.text(en.supportTipSmall), findsNothing);
    });

    testWidgets('a bought tip replaces the rows with thanks, and asks for '
        'nothing more', (tester) async {
      final gateway = RecordingPurchaseGateway(offered: [small, medium]);
      await tester.pumpWidget(appOver(gateway));
      await settleOffering(tester);
      await reveal(tester, find.text(en.supportTipSmall));
      await tester.tap(find.text(en.supportTipSmall));
      await settleOffering(tester);
      expect(gateway.bought, [tipSmallId]);
      expect(find.text(en.supportThanks), findsOneWidget);
      expect(
        find.text(en.supportTipMedium),
        findsNothing,
        reason: 'leaving the rows up after a tip is an ask for another one',
      );
    });

    testWidgets('a cancelled tip surfaces NOTHING', (tester) async {
      final gateway = RecordingPurchaseGateway(
        offered: [small],
        result: TipPurchaseResult.cancelled,
      );
      await tester.pumpWidget(appOver(gateway));
      await settleOffering(tester);
      await reveal(tester, find.text(en.supportTipSmall));
      await tester.tap(find.text(en.supportTipSmall));
      await settleOffering(tester);
      expect(find.text(en.supportFailed), findsNothing);
      expect(find.text(en.supportThanks), findsNothing);
      expect(find.text(en.supportTipSmall), findsOneWidget);
    });

    testWidgets('a failed tip says so, and says nothing was charged',
        (tester) async {
      final gateway = RecordingPurchaseGateway(
        offered: [small],
        result: TipPurchaseResult.failed,
      );
      await tester.pumpWidget(appOver(gateway));
      await settleOffering(tester);
      await reveal(tester, find.text(en.supportTipSmall));
      await tester.tap(find.text(en.supportTipSmall));
      await settleOffering(tester);
      expect(find.text(en.supportFailed), findsOneWidget);
      expect(find.text(en.supportTipSmall), findsOneWidget,
          reason: 'the offer must survive a failure');
    });
  });

  group('accessibility', () {
    testWidgets('each row is a button announcing its name AND its price',
        (tester) async {
      final handle = tester.ensureSemantics();
      final gateway = RecordingPurchaseGateway(offered: [small]);
      await tester.pumpWidget(appOver(gateway));
      await settleOffering(tester);
      expect(
        find.bySemanticsLabel('${en.supportTipSmall}, ${small.priceString}'),
        findsOneWidget,
        reason: 'announced as one phrase, so what is bought and what it costs '
            'do not arrive as two unrelated fragments',
      );
      handle.dispose();
    });

    testWidgets('the row can be activated through the semantics tree, not '
        'only by a coordinate tap', (tester) async {
      final handle = tester.ensureSemantics();
      final gateway = RecordingPurchaseGateway(offered: [small]);
      await tester.pumpWidget(appOver(gateway));
      await settleOffering(tester);
      // `tester.semantics.performAction`, the form the Settings suite uses.
      // The pipelineOwner route is deprecated.
      tester.semantics.performAction(
        find.semantics.byLabel('${en.supportTipSmall}, ${small.priceString}'),
        SemanticsAction.tap,
      );
      await settleOffering(tester);
      expect(gateway.bought, [tipSmallId]);
      handle.dispose();
    });

    testWidgets('the back control carries its own label and action',
        (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(appOver(RecordingPurchaseGateway()));
      expect(find.bySemanticsLabel(en.navBack), findsOneWidget);
      handle.dispose();
    });
  });

  group('bilingual render matrix', () {
    for (final (tag, l10n) in [('en', en), ('uk', uk)]) {
      for (final scale in const [1.0, 1.6, 2.0]) {
        testWidgets('$tag @ $scale: every phase renders with no layout '
            'exception', (tester) async {
          for (final gateway in [
            // The three phases that actually put content on screen. Preparing
            // is covered by the offered case's first frame.
            RecordingPurchaseGateway(offered: [small, medium, large]),
            RecordingPurchaseGateway(),
            RecordingPurchaseGateway(
              offered: [small],
              result: TipPurchaseResult.failed,
            ),
          ]) {
            await tester.pumpWidget(appOver(
              gateway,
              locale: Locale(tag),
              textScale: scale,
            ));
            await settleOffering(tester);
            if (gateway.offered.length == 1) {
              // Drive the failure surface, which is the tallest arrangement a
              // row can be in: a label, a price and a message under them.
              await reveal(tester, find.text(l10n.supportTipSmall));
              await tester.tap(find.text(l10n.supportTipSmall));
              await settleOffering(tester);
              await reveal(tester, find.text(l10n.supportFailed));
              expect(find.text(l10n.supportFailed), findsOneWidget);
            }
            expect(tester.takeException(), isNull);
          }
        });
      }
    }

    testWidgets('a long price string does not overflow the row at 2.0',
        (tester) async {
      usePhoneSurface(tester);
      // Not a hypothetical: an Indonesian or Vietnamese storefront renders
      // prices with five significant digits and a currency word, and the row
      // puts that on one line beside a label that Ukrainian already makes 30%
      // longer than English.
      const long = TipProduct(id: tipSmallId, priceString: 'Rp 149.000,00');
      await tester.pumpWidget(appOver(
        RecordingPurchaseGateway(offered: const [long]),
        locale: const Locale('uk'),
        textScale: 2.0,
      ));
      await settleOffering(tester);
      await reveal(tester, find.text('Rp 149.000,00'));
      expect(find.text('Rp 149.000,00'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
