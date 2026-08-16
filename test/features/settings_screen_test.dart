/// Settings screen (S7) contract — the L10N-03 loop proven end-to-end.
///
/// Task 1 of plan 05-01 owns the four tracer tests below: the instant switch,
/// the flash-free restart, clearing the override, and the derived option list.
/// Task 3 extends this file with the rest of the S7 contract.
///
/// `pumpAndSettle` is forbidden in this file. The app shell keeps a midnight
/// timer and a minute ticker alive for the whole session, so settling would
/// hang; and needing more than one `pump()` after a language tap would itself
/// prove the switch is not instant (PF-3).
library;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:boostque/core/db/database.dart' show BoostqueDb;
import 'package:boostque/core/l10n/l10n.dart';
import 'package:boostque/core/providers.dart';
import 'package:boostque/features/settings/language_picker.dart';
import 'package:boostque/main.dart';

/// The consequence of a red case, named in device terms rather than as a
/// restatement of the assertion.
const String instantReason =
    'the language must be live on the very next frame: a user who taps a row '
    'and watches the screen keep its old language reads that as a dead '
    'control, and DECIDED-7 removed every confirmation affordance that could '
    'have covered for the delay';

void main() {
  final en = lookupAppLocalizations(const Locale('en'));
  final uk = lookupAppLocalizations(const Locale('uk'));

  /// Seeds the mock store and returns the instance the scope is built over —
  /// the synchronous seed [sharedPreferencesProvider] hands to
  /// `LocaleController.build()` (P-4 Option A).
  Future<SharedPreferences> seedPrefs(Map<String, Object> values) async {
    SharedPreferences.setMockInitialValues(values);
    return SharedPreferences.getInstance();
  }

  /// The real app under a scope carrying both overrides P-4 Option A forces:
  /// the prefs seed, and an in-memory Drift database (D-19).
  ProviderScope appScope(SharedPreferences prefs) {
    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        dbProvider.overrideWith((ref) {
          final db = BoostqueDb.forTesting(NativeDatabase.memory());
          ref.onDispose(db.close);
          return db;
        }),
      ],
      child: const BoostqueApp(),
    );
  }

  /// Tears the tree down inside the test body so Drift's stream-close
  /// zero-duration timers fire before flutter_test's pending-timer check.
  Future<void> flushTearDown(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 10));
    await tester.pump(const Duration(milliseconds: 10));
  }

  /// Taps the Settings destination in the nav bar, in whatever language the
  /// app is currently reading.
  Future<void> openSettings(WidgetTester tester, AppLocalizations l10n) async {
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text(l10n.tabSettings),
      ),
    );
    await tester.pump();
  }

  Finder rows() => find.descendant(
        of: find.byType(LanguagePicker),
        matching: find.byType(InkWell),
      );

  testWidgets(
      'tapping a language row re-reads the whole app within ONE frame '
      '(L10N-03, Interaction Contract 1)', (tester) async {
    final prefs = await seedPrefs({});
    await tester.pumpWidget(appScope(prefs));
    await tester.pump();

    // The test environment resolves to English with no stored override, so
    // the tracer proves the switch in both directions rather than tapping the
    // language that happens to be active already.
    await openSettings(tester, en);
    expect(find.text(en.settingsLanguageTitle), findsOneWidget);

    await tester.tap(find.text(uk.languageName));
    await tester.pump(); // exactly one frame

    expect(find.text(uk.settingsLanguageTitle), findsOneWidget,
        reason: instantReason);
    expect(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text(uk.tabStack),
      ),
      findsOneWidget,
      reason: 'the nav bar sits outside the Settings screen — if it lags a '
          'frame the user sees two languages on screen at once',
    );
    expect(find.text(uk.tabSettings), findsWidgets,
        reason: 'the screen title and the nav destination share tabSettings, '
            'so both must be Ukrainian on the same frame');

    await tester.tap(find.text(en.languageName));
    await tester.pump(); // exactly one frame

    expect(find.text(en.settingsLanguageTitle), findsOneWidget,
        reason: instantReason);
    expect(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text(en.tabStack),
      ),
      findsOneWidget,
      reason: instantReason,
    );

    await flushTearDown(tester);
  });

  testWidgets(
      'the choice survives a full app-tree restart and is applied on the '
      'FIRST painted frame (L10N-03, no system-language flash)', (tester) async {
    final prefs = await seedPrefs({});
    await tester.pumpWidget(appScope(prefs));
    await tester.pump();
    await openSettings(tester, en);

    await tester.tap(find.text(uk.languageName));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 10));

    final stored = await SharedPreferences.getInstance();
    expect(stored.getString('app_locale'), 'uk',
        reason: 'the write happens after the repaint, but it must still '
            'happen — otherwise the next launch silently reverts');

    // Tear the tree down and boot a FRESH scope over the same store.
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 10));

    await tester.pumpWidget(appScope(stored));

    expect(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text(uk.tabStack),
      ),
      findsOneWidget,
      reason: 'asserted before any additional pump: an async seed would '
          'render one English frame first, which on a real cold start is the '
          'visible flash P-4 Option A exists to remove',
    );

    await flushTearDown(tester);
  });

  testWidgets(
      'tapping System default clears the stored override and follows the '
      'system language (E-6, Interaction Contract 3)', (tester) async {
    final prefs = await seedPrefs({'app_locale': 'uk'});
    await tester.pumpWidget(appScope(prefs));
    await tester.pump();
    await openSettings(tester, uk);

    expect(find.text(uk.settingsLanguageTitle), findsOneWidget,
        reason: 'the stored override must already be live on frame 1');

    await tester.tap(find.text(uk.languageSystem));
    await tester.pump(); // exactly one frame
    expect(find.text(en.settingsLanguageTitle), findsOneWidget,
        reason: instantReason);

    await tester.pump(const Duration(milliseconds: 10));
    final stored = await SharedPreferences.getInstance();
    expect(stored.getString('app_locale'), isNull,
        reason: 'System default REMOVES the key rather than storing a code — '
            'a stored code would freeze the app against a later device '
            'language change');

    await flushTearDown(tester);
  });

  testWidgets(
      'the card renders 1 + supportedLocales.length rows, in GENERATED order '
      '(L10N-04, criterion 4)', (tester) async {
    final prefs = await seedPrefs({});
    await tester.pumpWidget(appScope(prefs));
    await tester.pump();
    await openSettings(tester, en);

    expect(
      rows(),
      findsNWidgets(1 + AppLocalizations.supportedLocales.length),
      reason: 'the row count is derived from the generated locale list; a '
          'hardcoded count silently stops growing the day an ARB lands',
    );

    final first = AppLocalizations.supportedLocales.first;
    final secondRowLabel = tester
        .widgetList<Text>(
          find.descendant(of: rows().at(1), matching: find.byType(Text)),
        )
        .first;
    expect(
      secondRowLabel.data,
      lookupAppLocalizations(first).languageName,
      reason: 'row 2 must be supportedLocales.first read through its OWN ARB '
          '— a name-sorted list would still look right while breaking the '
          '"one new ARB file, no code changes" contract',
    );

    await flushTearDown(tester);
  });
}
