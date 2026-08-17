import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:boostque/core/l10n/l10n.dart';
import 'package:boostque/core/providers.dart';
import 'package:boostque/core/theme/theme.dart';
import 'package:boostque/core/theme/tokens.dart';
import 'package:boostque/core/widgets/bq_settings_gear_row.dart';
import 'package:boostque/features/settings/settings_screen.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/locale_matrix.dart';

/// [BqSettingsGearRow] — the S11 gear control, extracted (IN-01).
///
/// This file owns the WIDGET's claims. The three screens' own gear groups
/// (`stack_screen_test.dart`, `today_screen_test.dart`,
/// `planner_screen_test.dart`) keep owning the PLACEMENT claims — that the row
/// sits above each title, that each header survives the text-scale matrix, and
/// that the push lands over the real shell. Those three groups passed unchanged
/// across the extraction, which is what makes it a refactor rather than a
/// rewrite; nothing here duplicates them.
///
/// Every activation goes through [SemanticsAction.tap], never `tester.tap`:
/// `excludeSemantics: true` drops every descendant action, so a gear whose
/// onTap lived only on the `IconButton` would announce a button VoiceOver /
/// TalkBack cannot press while passing every coordinate-tap test (WR-02).
void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  /// The row alone, on a real route so `Navigator.of` has somewhere to push to.
  ///
  /// A `ProviderScope` is needed only because the pushed [SettingsScreen] reads
  /// the locale controller, which seeds itself synchronously from
  /// `sharedPreferencesProvider`.
  Widget gearApp({String locale = 'uk'}) {
    return ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: MaterialApp(
        locale: Locale(locale),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: bqTheme(),
        home: const Scaffold(body: BqSettingsGearRow()),
      ),
    );
  }

  Finder gear() => find.ancestor(
        of: find.byIcon(Icons.settings_outlined),
        matching: find.byType(IconButton),
      );

  group('BqSettingsGearRow — the S11 recipe, in one place (IN-01)', () {
    for (final locale in const ['uk', 'en']) {
      testWidgets('$locale: one outlined gear, end-aligned, in a 44x44 box '
          'that does not move with the text scaler', (tester) async {
        final List<Size> sizes = <Size>[];

        for (final scale in bqTextScaleMatrix) {
          await tester.pumpWidget(
            MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(scale)),
              child: gearApp(locale: locale),
            ),
          );
          await tester.pump();

          expect(gear(), findsOneWidget);
          expect(find.byIcon(Icons.settings), findsNothing,
              reason: 'the FILLED glyph expresses a selected state and the gear '
                  'has none — it is a control, not a destination');

          final Size size = tester.getSize(gear());
          expect(size.width, greaterThanOrEqualTo(44.0));
          expect(size.height, greaterThanOrEqualTo(44.0));
          sizes.add(size);

          expect(tester.takeException(), isNull,
              reason: 'the row carries NO text, so its extent is pure geometry '
                  'and it cannot overflow at any scale in any locale (D-5) — '
                  'the entire reason the gear gets a row of its own instead of '
                  'a slot in a title row');
        }

        expect(sizes.toSet(), hasLength(1),
            reason: 'a bounded, text-free box does not grow with the scaler. '
                'Measured: $sizes');
      });
    }

    testWidgets('the glyph is 20dp textSecondary and the row is end-aligned',
        (tester) async {
      await tester.pumpWidget(gearApp());
      await tester.pump();

      final Icon icon = tester.widget<Icon>(find.byIcon(Icons.settings_outlined));
      expect(icon.size, 20);
      expect(icon.color, BqColors.textSecondary);

      // The RECIPE's own numbers, not the rendered box. `getSize` above cannot
      // stand in for this: Material wraps the button to its 48dp padded tap
      // target, so a >= 44 floor stays green even if these constraints were cut
      // to 30 — verified by mutation. This file is now the single owner of the
      // S11 recipe, so the recipe is what it has to pin.
      final IconButton button = tester.widget<IconButton>(gear());
      expect(button.constraints,
          const BoxConstraints.tightFor(width: 44, height: 44));
      expect(button.padding, EdgeInsets.zero,
          reason: 'zero padding is what makes the 44 box the icon box rather '
              'than 44 plus Material\'s default inset');

      final Row row =
          tester.widget<Row>(find.ancestor(of: gear(), matching: find.byType(Row)).last);
      expect(row.mainAxisAlignment, MainAxisAlignment.end,
          reason: 'the gear sits on the end side, direction-neutrally');
    });

    for (final locale in const ['uk', 'en']) {
      testWidgets('$locale: the semantics node carries the ARB label and its '
          'OWN tap action (WR-02)', (tester) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(gearApp(locale: locale));
        await tester.pump();

        final l10n = lookupAppLocalizations(Locale(locale));
        expect(
          tester.getSemantics(find.bySemanticsLabel(l10n.settingsTitle)),
          isSemantics(isButton: true, hasTapAction: true),
          reason: 'the gear is icon-only, so the ARB label is the only thing a '
              'screen-reader user has — and `settingsTitle` is one key in two '
              'placements, this control and its destination\'s title, so the '
              'two can never disagree',
        );

        handle.dispose();
      });
    }

    testWidgets('SemanticsAction.tap PUSHES Settings — not a coordinate tap',
        (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(gearApp());
      await tester.pump();

      final l10n = lookupAppLocalizations(const Locale('uk'));
      expect(find.byType(SettingsScreen), findsNothing);

      // Assistive technology does not tap widgets. It activates actions.
      tester.semantics.performAction(
        find.semantics.byLabel(l10n.settingsTitle),
        SemanticsAction.tap,
      );
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }

      expect(find.byType(SettingsScreen), findsOneWidget,
          reason: 'a control that announces itself and navigates nowhere is '
              'worse than no control at all');
      expect(find.byType(BqSettingsGearRow), findsOneWidget,
          reason: 'a PUSH, not a replacement: what the gear was on stays '
              'mounted underneath, which is what keeps the selected '
              'destination and the screen state intact across the return trip');

      handle.dispose();
    });
  });
}
