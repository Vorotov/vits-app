/// Settings screen (S7) contract — the L10N-03 loop proven end-to-end, then
/// every one of UI Considerations #1-#11 and #13 as a passing assertion.
///
/// `pumpAndSettle` is forbidden in this file. The app shell keeps a midnight
/// timer and a minute ticker alive for the whole session, so settling would
/// hang; and needing more than one `pump()` after a language change would
/// itself prove the switch is not instant (PF-3).
library;

import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:boostque/core/db/database.dart' show BoostqueDb;
import 'package:boostque/core/domain/models.dart';
import 'package:boostque/core/l10n/l10n.dart';
import 'package:boostque/core/l10n/locale_controller.dart';
import 'package:boostque/core/providers.dart';
import 'package:boostque/core/theme/theme.dart';
import 'package:boostque/core/widgets/bq_nav_bar.dart';
import 'package:boostque/features/settings/language_picker.dart';
import 'package:boostque/features/settings/settings_screen.dart';
import 'package:boostque/main.dart';

/// The consequence of a red case, named in device terms rather than as a
/// restatement of the assertion.
const String instantReason =
    'the language must be live on the very next frame: a user who taps a row '
    'and watches the screen keep its old language reads that as a dead '
    'control, and DECIDED-7 removed every confirmation affordance that could '
    'have covered for the delay';

const String overflowReason =
    'a layout exception at an accessibility text scale is a clipped label in '
    'RELEASE — not debug stripes. The Settings list is the newest and least '
    'proven surface in the app; the fix is a wrapping label, never a relaxed '
    'assertion (CR-01 / WR-04)';

const String tapTargetReason =
    'a row shorter than 52px is a miss-prone tap target on a real thumb, and '
    '14 + 15x1.3 + 14 = 47.5px means the minHeight is load-bearing at scale '
    '1.0 rather than a safety net';

/// [source] with every comment line removed.
///
/// Line comments only, because this codebase writes no block comments — the
/// gate asserts that on its own behalf below, so the day one appears it says
/// so instead of silently reading commentary as code.
String stripComments(String source) => source
    .split('\n')
    .where((line) => !line.trimLeft().startsWith('//'))
    .join('\n');

/// Every Dart file under the Settings feature, resolved by GLOB rather than
/// by a hardcoded list: a third settings file added by a later phase is gated
/// the day it lands, with no one having to remember this test exists.
List<File> settingsSources() {
  final files = Directory('lib/features/settings')
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  return files;
}

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

  /// The Settings screen alone, with the rendering locale and the text scale
  /// pinned from outside — the `plannerApp` harness shape, so the matrix below
  /// is a loop rather than copy-paste. It touches no database and starts no
  /// timer, so these tests need no Drift teardown.
  Widget settingsApp(
    SharedPreferences prefs, {
    String locale = 'uk',
    TextScaler? textScaler,
  }) {
    return ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: MaterialApp(
        locale: Locale(locale),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: bqTheme(),
        builder: (context, child) => textScaler == null
            ? child!
            : MediaQuery(
                data: MediaQuery.of(context).copyWith(textScaler: textScaler),
                child: child!,
              ),
        home: const SettingsScreen(),
      ),
    );
  }

  /// Sets a phone-sized logical surface (390x844); restored automatically.
  void usePhoneSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  /// Tears the tree down inside the test body so Drift's stream-close
  /// zero-duration timers fire before flutter_test's pending-timer check.
  Future<void> flushTearDown(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 10));
    await tester.pump(const Duration(milliseconds: 10));
  }

  /// Pumps frames until [finder] matches (Drift stream emissions arrive
  /// asynchronously; `pumpAndSettle` cannot be used with live timers).
  Future<void> pumpUntilFound(WidgetTester tester, Finder finder) async {
    for (var i = 0; i < 200; i++) {
      await tester.pump(const Duration(milliseconds: 10));
      if (finder.evaluate().isNotEmpty) return;
    }
    fail('timed out waiting for $finder');
  }

  /// Taps the Settings destination in the nav bar, in whatever language the
  /// app is currently reading.
  Future<void> openSettings(WidgetTester tester, AppLocalizations l10n) async {
    await tester.tap(
      find.descendant(
        of: find.byType(BqNavBar),
        matching: find.text(l10n.tabSettings),
      ),
    );
    await tester.pump();
  }

  Finder rows() => find.descendant(
        of: find.byType(LanguagePicker),
        matching: find.byType(InkWell),
      );

  /// Every row's own semantics node — the row IS the node (WR-02), so a
  /// `checked` property anywhere else would itself be a defect.
  Iterable<Semantics> rowSemantics(WidgetTester tester) => tester
      .widgetList<Semantics>(
        find.descendant(
          of: find.byType(LanguagePicker),
          matching: find.byType(Semantics),
        ),
      )
      .where((s) => s.properties.checked != null);

  int checkedCount(WidgetTester tester) =>
      rowSemantics(tester).where((s) => s.properties.checked ?? false).length;

  String checkedLabel(WidgetTester tester) => rowSemantics(tester)
      .firstWhere((s) => s.properties.checked ?? false)
      .properties
      .label!;

  /// Every string this tree actually put on screen.
  Iterable<String> renderedText(WidgetTester tester) => tester
      .widgetList<Text>(find.byType(Text))
      .map((t) => t.data)
      .whereType<String>();

  // -------------------------------------------------------------------
  // Task 1 — the tracer: the whole L10N-03 loop on one path.
  // -------------------------------------------------------------------

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
        of: find.byType(BqNavBar),
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
        of: find.byType(BqNavBar),
        matching: find.text(en.tabStack),
      ),
      findsOneWidget,
      reason: instantReason,
    );

    await flushTearDown(tester);
  });

  testWidgets(
      'the choice survives a full app-tree restart and is applied on the '
      'FIRST painted frame (L10N-03, no system-language flash)',
      (tester) async {
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
        of: find.byType(BqNavBar),
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

  // -------------------------------------------------------------------
  // Rendering and structure (UI Considerations #1, #2, #8).
  // -------------------------------------------------------------------

  group('S7 rendering and structure', () {
    testWidgets(
        'the card renders one row per option and a divider between each pair '
        '(#1, #2)', (tester) async {
      usePhoneSurface(tester);
      final prefs = await seedPrefs({});
      await tester.pumpWidget(settingsApp(prefs));
      await tester.pump();

      final locales = AppLocalizations.supportedLocales;
      expect(rows(), findsNWidgets(1 + locales.length),
          reason: 'computed from the generated list, never written as a '
              'number — with one shipped language the card is 2 rows, with '
              'three it is 4');
      expect(
        find.descendant(
          of: find.byType(LanguagePicker),
          matching: find.byType(Divider),
        ),
        findsNWidgets(locales.length),
        reason: 'one full-bleed hairline between each adjacent pair; a '
            'trailing divider would make the last row look unfinished '
            'against the card radius',
      );
      expect(locales, isNotEmpty,
          reason: 'the template ARB is a build requirement, so the list can '
              'never be empty and no empty state may be authored (#2)');
    });

    testWidgets(
        'row 1 is languageSystem in the ACTIVE locale and each later row is '
        'that locale OWN endonym, in generated order (#1, P-2)', (tester) async {
      usePhoneSurface(tester);
      final prefs = await seedPrefs({});
      await tester.pumpWidget(settingsApp(prefs, locale: 'uk'));
      await tester.pump();

      final expected = <String>[
        uk.languageSystem,
        for (final locale in AppLocalizations.supportedLocales)
          lookupAppLocalizations(locale).languageName,
      ];
      final actual = [
        for (var i = 0; i < expected.length; i++)
          tester
              .widgetList<Text>(
                find.descendant(of: rows().at(i), matching: find.byType(Text)),
              )
              .first
              .data,
      ];

      expect(actual, expected,
          reason: 'the ORDER is asserted, not just the membership: a '
              'name-sorted list would still look right on screen while making '
              'row order depend on the active language and moving the '
              'fallback away from supportedLocales.first');
    });

    testWidgets('the title and the eyebrow render, and the eyebrow is a '
        'semantics HEADER (#8)', (tester) async {
      usePhoneSurface(tester);
      final prefs = await seedPrefs({});
      await tester.pumpWidget(settingsApp(prefs, locale: 'uk'));
      await tester.pump();

      expect(find.text(uk.tabSettings), findsOneWidget);
      expect(
        tester.getSemantics(find.text(uk.settingsLanguageTitle)),
        isSemantics(isHeader: true),
        reason: 'assistive technology navigates by heading; without the flag '
            'the only way to reach the language list is to sweep the screen',
      );
    });
  });

  // -------------------------------------------------------------------
  // Selection invariant (UI Consideration #6, T-05-01 rendered).
  // -------------------------------------------------------------------

  group('S7 selection invariant', () {
    testWidgets('no stored override: exactly one row is checked and it is the '
        'System row', (tester) async {
      usePhoneSurface(tester);
      final prefs = await seedPrefs({});
      await tester.pumpWidget(settingsApp(prefs, locale: 'uk'));
      await tester.pump();

      expect(checkedCount(tester), 1,
          reason: 'zero checks leaves the user unable to tell what is active; '
              'two makes the radio group a lie');
      expect(checkedLabel(tester), uk.languageSystem);
    });

    testWidgets('a stored shipped code: exactly one row is checked and it is '
        'that language row', (tester) async {
      usePhoneSurface(tester);
      final prefs = await seedPrefs({'app_locale': 'uk'});
      await tester.pumpWidget(settingsApp(prefs, locale: 'uk'));
      await tester.pump();

      expect(checkedCount(tester), 1);
      expect(checkedLabel(tester), uk.languageName);
    });

    testWidgets(
        'a stored code outside the shipped set checks the System row and '
        'raises no exception (T-05-01 rendered)', (tester) async {
      usePhoneSurface(tester);
      final prefs = await seedPrefs({'app_locale': 'zz'});
      await tester.pumpWidget(settingsApp(prefs, locale: 'uk'));
      await tester.pump();

      expect(checkedCount(tester), 1);
      expect(checkedLabel(tester), uk.languageSystem);
      expect(tester.takeException(), isNull,
          reason: 'a tampered or stale stored code must degrade to '
              '"follow system"; reaching lookupAppLocalizations with it '
              'would be an unrecoverable launch crash, not a cosmetic bug');
    });
  });

  // -------------------------------------------------------------------
  // Interaction and propagation (#9, Interaction Contracts 1-3, 8).
  // -------------------------------------------------------------------

  group('S7 interaction', () {
    testWidgets('tapping the already-selected row is a no-op, not a toggle-off '
        '(Interaction Contract 2)', (tester) async {
      usePhoneSurface(tester);
      final prefs = await seedPrefs({'app_locale': 'uk'});
      await tester.pumpWidget(settingsApp(prefs, locale: 'uk'));
      await tester.pump();

      await tester.tap(find.text(uk.languageName));
      await tester.pump();

      expect(checkedCount(tester), 1);
      expect(checkedLabel(tester), uk.languageName,
          reason: 'a mutually-exclusive option has no off state — clearing it '
              'would leave the app with no language selected');
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'a locale change re-localizes a PUSHED ROUTE in place, in one frame '
        '(Interaction Contract 8, E-11)', (tester) async {
      usePhoneSurface(tester);
      final prefs = await seedPrefs({'app_locale': 'uk'});
      await tester.pumpWidget(appScope(prefs));
      await tester.pump();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(BoostqueApp)),
        listen: false,
      );
      await container.read(supplementRepoProvider).upsert(
            const Supplement(
              id: 's1',
              name: 'Магній бісглицинат',
              doseText: '400 мг',
              colorValue: 0xFF6B6FA8,
              note: '',
            ),
          );
      await pumpUntilFound(tester, find.text('Магній бісглицинат'));

      await tester.tap(find.text('Магній бісглицинат'));
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }
      expect(find.text(uk.scheduleTitle), findsOneWidget,
          reason: 'the regimen editor must be the pushed route under test');

      container.read(localeControllerProvider.notifier).setLocale(
            const Locale('en'),
          );
      await tester.pump(); // exactly one frame

      expect(find.text(en.scheduleTitle), findsOneWidget, reason: instantReason);

      await flushTearDown(tester);
    });

    testWidgets(
        'a locale change re-localizes an OPEN BOTTOM SHEET in place, in one '
        'frame (Interaction Contract 8, E-10)', (tester) async {
      usePhoneSurface(tester);
      final prefs = await seedPrefs({'app_locale': 'uk'});
      await tester.pumpWidget(appScope(prefs));
      await tester.pump();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(BoostqueApp)),
        listen: false,
      );

      await tester.tap(find.text(uk.addSupplement));
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }
      expect(find.text(uk.searchTab), findsOneWidget,
          reason: 'the add-supplement sheet must be open under test');

      container.read(localeControllerProvider.notifier).setLocale(
            const Locale('en'),
          );
      await tester.pump(); // exactly one frame

      expect(find.text(en.searchTab), findsOneWidget,
          reason: 'a sheet route sits in the same Navigator overlay, below '
              "MaterialApp's Localizations — if it lagged, the user would be "
              'reading two languages at once mid-gesture');

      await flushTearDown(tester);
    });
  });

  // -------------------------------------------------------------------
  // Geometry and text scale (#7, #11, #13 render side).
  // -------------------------------------------------------------------

  group('S7 geometry and text scale', () {
    for (final locale in const ['uk', 'en']) {
      for (final scale in const <double>[1.0, 1.6, 2.0]) {
        testWidgets(
            '$locale: the Settings screen renders with no layout exception '
            'and rows >= 52px at textScaler $scale (#7, #11)', (tester) async {
          usePhoneSurface(tester);
          final prefs = await seedPrefs({});
          await tester.pumpWidget(
            settingsApp(
              prefs,
              locale: locale,
              textScaler: TextScaler.linear(scale),
            ),
          );
          await tester.pump();

          expect(tester.takeException(), isNull, reason: overflowReason);

          final count = 1 + AppLocalizations.supportedLocales.length;
          for (var i = 0; i < count; i++) {
            expect(tester.getSize(rows().at(i)).height,
                greaterThanOrEqualTo(52.0),
                reason: tapTargetReason);
          }
        });
      }
    }

    testWidgets('at textScaler 2.0 every row label WRAPS — null maxLines and '
        'null overflow (#7)', (tester) async {
      usePhoneSurface(tester);
      final prefs = await seedPrefs({});
      await tester.pumpWidget(
        settingsApp(prefs, textScaler: const TextScaler.linear(2.0)),
      );
      await tester.pump();

      final labels = tester.widgetList<Text>(
        find.descendant(of: rows(), matching: find.byType(Text)),
      );
      expect(labels, isNotEmpty);
      for (final label in labels) {
        expect(label.maxLines, isNull,
            reason: 'wrapping is proven as a property, not inferred from the '
                'absence of a red box: a maxLines of 1 truncates a long '
                'endonym silently in release');
        expect(label.overflow, isNull, reason: 'an ellipsis would hide the '
            'end of a language name the user cannot otherwise read');
      }
    });

    testWidgets('while English is active no Cyrillic reaches the tree, except '
        'a Cyrillic-script endonym (#11, A8)', (tester) async {
      usePhoneSurface(tester);
      final prefs = await seedPrefs({});
      await tester.pumpWidget(settingsApp(prefs, locale: 'en'));
      await tester.pump();

      // The one allowlist entry, and it is an explicit list rather than a
      // relaxed regex: a language's own name is legitimately written in its
      // own script no matter which language the app is reading.
      final endonyms = {
        for (final locale in AppLocalizations.supportedLocales)
          lookupAppLocalizations(locale).languageName,
      };
      final cyrillic = RegExp(r'[Ѐ-ӿ]');
      for (final data in renderedText(tester)) {
        if (!cyrillic.hasMatch(data)) continue;
        expect(endonyms, contains(data),
            reason: 'a Cyrillic string reached the tree while en was active: '
                '"$data" — a literal escaped the ARB');
      }
    });

    for (final locale in const ['uk', 'en']) {
      testWidgets('$locale: no rendered Text on the Settings screen contains '
          'a digit (#13)', (tester) async {
        usePhoneSurface(tester);
        final prefs = await seedPrefs({});
        await tester.pumpWidget(settingsApp(prefs, locale: locale));
        await tester.pump();

        for (final data in renderedText(tester)) {
          expect(RegExp(r'[0-9]').hasMatch(data), isFalse,
              reason: 'this screen shows no numeral, no date and no month '
                  'name: "$data" means a count, a version or a formatted '
                  'value crept onto the app least-visited, most-static '
                  'surface');
        }
      });
    }
  });

  // -------------------------------------------------------------------
  // Screen-scope source gates (#3, #4, #5, #13).
  // -------------------------------------------------------------------

  group('settings source invariants', () {
    late Map<String, String> sources;

    setUpAll(() {
      sources = {
        for (final file in settingsSources())
          file.path: stripComments(file.readAsStringSync()),
      };
    });

    void forEachSource(void Function(String path, String source) check) {
      sources.forEach(check);
    }

    test('the glob actually resolves the settings files — a gate over an '
        'empty file set is worse than no gate', () {
      expect(sources, isNotEmpty);
      expect(sources.length, greaterThanOrEqualTo(2),
          reason: 'the phase ships two settings files (screen, picker); a '
              'smaller set means the glob stopped matching and every gate '
              'below became decoration');
      expect(sources.keys.any((p) => p.endsWith('language_picker.dart')), isTrue,
          reason: 'the picker is the file criterion 4 actually rests on');
      forEachSource((path, source) {
        expect(source.contains('/*'), isFalse,
            reason: 'the comment stripper handles line comments only; a block '
                'comment in $path would be read as code');
      });
    });

    test('no language code and no endonym literal appears (#5, criterion 4)',
        () {
      final code = RegExp("['\"][a-z]{2}['\"]");
      final endonyms = [
        for (final locale in AppLocalizations.supportedLocales)
          lookupAppLocalizations(locale).languageName,
      ];
      forEachSource((path, source) {
        expect(code.hasMatch(source), isFalse,
            reason: '$path names a language code; adding app_pl.arb would '
                'then need an edit here, which criterion 4 forbids');
        for (final endonym in endonyms) {
          expect(source.contains(endonym), isFalse,
              reason: '$path hardcodes "$endonym"; the label must come from '
                  "that locale OWN ARB via lookupAppLocalizations");
        }
      });
    });

    test('no switch or Map keyed on a locale appears (#5)', () {
      forEachSource((path, source) {
        expect(source.contains('switch ('), isFalse,
            reason: '$path branches per value; a per-locale branch is the '
                'exact shape criterion 4 forbids');
        expect(source.contains('Map<'), isFalse,
            reason: '$path declares a map; a code -> name map would have to '
                'be edited for every new ARB');
      });
    });

    test('no loading surface exists — no spinner, shimmer or skeleton (#3)',
        () {
      const forbidden = [
        'ProgressIndicator',
        'Shimmer',
        'Skeleton',
        'AsyncLoading',
      ];
      forEachSource((path, source) {
        for (final widget in forbidden) {
          expect(source.contains(widget), isFalse,
              reason: '$path has a loading affordance, but supportedLocales '
                  'is a compile-time const and LocaleController is a '
                  'synchronous Notifier — nothing here can ever be pending');
        }
      });
    });

    test('no error surface exists — no error copy, retry or exception text '
        '(#4, DECIDED-8)', () {
      const forbidden = ['Error', 'retry', 'catch (', 'onError'];
      forEachSource((path, source) {
        for (final token in forbidden) {
          expect(source.contains(token), isFalse,
              reason: '$path surfaces a failure, but no provider on this '
                  'screen can fail; a failed prefs write is silent by design '
                  'because the language visibly DID take effect');
        }
      });
    });

    test('no formatter and no plural key appears (#13)', () {
      const forbidden = ['DateFormat', 'NumberFormat', 'Intl.plural'];
      forEachSource((path, source) {
        for (final token in forbidden) {
          expect(source.contains(token), isFalse,
              reason: '$path formats a value, but this screen renders no '
                  'numeral, no date and no month name');
        }
      });
    });

    test('no alert token and no disclaimer string appears (#13)', () {
      const forbidden = [
        'BqColors.risk',
        'BqColors.warn',
        'BqColors.calm',
        'disclaimerEducational',
      ];
      forEachSource((path, source) {
        for (final token in forbidden) {
          expect(source.contains(token), isFalse,
              reason: '$path carries $token; Settings asserts no editorial '
                  'limit and makes no health claim, so the disclaimer would '
                  'dilute into boilerplate and an alert color would signal a '
                  'danger that does not exist here');
        }
      });
    });

    test('nothing under features/settings touches the database (#13, '
        'Interaction Contract 4)', () {
      const forbidden = ['drift', 'database.dart', 'Repository', 'repositories'];
      forEachSource((path, source) {
        for (final token in forbidden) {
          expect(source.contains(token), isFalse,
              reason: '$path reaches persistence; the entire feature write '
                  'surface is one shared_preferences key');
        }
      });
    });

    test('no hex color literal and no font size outside 25/15/10.5 appears '
        '(token-only styling)', () {
      const allowedSizes = {'25', '15', '10.5'};
      final hex = RegExp(r'0x[0-9a-fA-F]{6,8}');
      final fontSize = RegExp(r'(?:fontSize|\bsize):\s*([\d.]+)');
      forEachSource((path, source) {
        expect(hex.hasMatch(source), isFalse,
            reason: '$path hardcodes a color; every surface, border and '
                'foreground on this screen has a named token');
        for (final match in fontSize.allMatches(source)) {
          expect(allowedSizes, contains(match.group(1)),
              reason: '$path introduces font size ${match.group(1)}; the '
                  'component-level list is CLOSED at 25 / 15 / 10.5');
        }
      });
    });
  });
}
