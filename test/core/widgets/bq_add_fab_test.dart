import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:boostque/app_shell.dart';
import 'package:boostque/core/db/database.dart' show BoostqueDb;
import 'package:boostque/core/l10n/l10n.dart';
import 'package:boostque/core/providers.dart';
import 'package:boostque/core/theme/theme.dart';
import 'package:boostque/core/theme/tokens.dart';
import 'package:boostque/core/widgets/bq_add_fab.dart';

/// [BqAddFab] — the app's single add-supplement affordance (UX-01, UI-SPEC S10).
///
/// The FAB is exercised through the SHELL rather than in isolation: its whole
/// contract is "mounted once, on the root [Scaffold]", and a bare
/// `pumpWidget(BqAddFab())` would prove nothing about that. The presence /
/// absence sweep across destinations lives in `app_shell_test.dart`; this file
/// owns the widget's own three claims — it is a labelled button, assistive
/// technology can activate it, and a repeated activation opens ONE sheet.
///
/// Every activation here goes through [SemanticsAction.tap], never
/// `tester.tap`: `excludeSemantics: true` drops every descendant action, so a
/// FAB whose onTap lived only on the SDK button would announce a button
/// VoiceOver / TalkBack cannot press while passing every coordinate-tap test
/// in this repository (WR-02).
void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  ProviderScope scoped(Widget child) {
    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        dbProvider.overrideWith((ref) {
          final db = BoostqueDb.forTesting(NativeDatabase.memory());
          ref.onDispose(db.close);
          return db;
        }),
      ],
      child: child,
    );
  }

  Widget shellApp({String locale = 'uk'}) => scoped(
        MaterialApp(
          locale: Locale(locale),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: bqTheme(),
          home: const AppShell(),
        ),
      );

  /// Bounded frame pumping. Never `pumpAndSettle`: the shell keeps a midnight
  /// [Timer] alive for the whole session, and settling against a live clock
  /// either hangs or passes for a reason the test did not intend (PF-7).
  Future<void> pumpFrames(WidgetTester tester, [int frames = 20]) async {
    for (var i = 0; i < frames; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
  }

  Future<void> flushTearDown(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 10));
    await tester.pump(const Duration(milliseconds: 10));
  }

  group('BqAddFab — the single add affordance (UX-01, S10)', () {
    testWidgets('uk: exactly one FAB, and it is a BUTTON labelled '
        'addSupplement — never an unlabelled glyph', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(shellApp());
      await pumpFrames(tester);

      final l10n = lookupAppLocalizations(const Locale('uk'));

      expect(find.byType(BqAddFab), findsOneWidget);
      expect(
        tester.getSemantics(find.byType(BqAddFab)),
        isSemantics(
          isButton: true,
          label: l10n.addSupplement,
          hasTapAction: true,
        ),
        reason: 'the glyph is `Icons.add` and the label is never painted, so '
            'the semantics node is the ONLY thing that tells a screen-reader '
            'user what this disc does',
      );

      handle.dispose();
      await flushTearDown(tester);
    });

    testWidgets('uk: the FAB writes no colours of its own — they resolve from '
        'floatingActionButtonTheme (D-07)', (tester) async {
      await tester.pumpWidget(shellApp());
      await pumpFrames(tester);

      final fab = tester.widget<FloatingActionButton>(
        find.descendant(
          of: find.byType(BqAddFab),
          matching: find.byType(FloatingActionButton),
        ),
      );
      expect(fab.backgroundColor, isNull,
          reason: 'a colour written here would be a SECOND place the FAB\'s '
              'fill lives, and the theme entry would silently stop being the '
              'source of truth');
      expect(fab.foregroundColor, isNull);
      expect(fab.elevation, isNull);
      expect(fab.tooltip, isNull,
          reason: 'excludeSemantics drops a tooltip anyway, and this app '
              'renders no tooltips');

      // The RESOLVED paint, not just the absence of an override: the disc a
      // user sees must be the accent token.
      final material = tester.widget<Material>(
        find
            .descendant(
              of: find.byType(FloatingActionButton),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(material.color, BqColors.accent);
      expect(material.elevation, 0);

      await flushTearDown(tester);
    });

    testWidgets('uk: SemanticsAction.tap OPENS the add-supplement sheet',
        (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(shellApp());
      await pumpFrames(tester);

      final l10n = lookupAppLocalizations(const Locale('uk'));
      expect(find.byType(BottomSheet), findsNothing);

      tester.semantics.performAction(
        find.semantics.byLabel(l10n.addSupplement),
        SemanticsAction.tap,
      );
      await pumpFrames(tester);

      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.text(l10n.searchCatalogHint), findsOneWidget,
          reason: 'the sheet that opened is the EXISTING add-supplement sheet, '
              'untouched by this phase — its catalog tab is the default');

      handle.dispose();
      await flushTearDown(tester);
    });

    testWidgets('uk: a SECOND activation while the sheet is open does not '
        'stack a second sheet (T-06-09)', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(shellApp());
      await pumpFrames(tester);

      final l10n = lookupAppLocalizations(const Locale('uk'));

      // Both activations are dispatched against the SAME semantics tree, with
      // no frame between them — the double-activation an impatient user (or a
      // switch-control repeat) actually produces. `showAddSupplementSheet`
      // has no guard of its own (its `_busy` flag guards the two ADD paths
      // inside the sheet, not a second sheet), so the guard lives in the FAB.
      final node = find.semantics.byLabel(l10n.addSupplement);
      tester.semantics.performAction(node, SemanticsAction.tap);
      tester.semantics.performAction(node, SemanticsAction.tap);
      await pumpFrames(tester);

      expect(find.byType(BottomSheet), findsOneWidget,
          reason: 'two stacked sheets means dismissing one leaves the user '
              'staring at an identical second one');
      expect(tester.takeException(), isNull);

      handle.dispose();
      await flushTearDown(tester);
    });
  });
}
