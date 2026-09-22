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
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vitomy/core/db/database.dart' show VitomyDb;
import 'package:vitomy/core/domain/models.dart';
import 'package:vitomy/core/l10n/l10n.dart';
import 'package:vitomy/core/l10n/locale_controller.dart';
import 'package:vitomy/core/notifications/notification_providers.dart';
import 'package:vitomy/core/providers.dart';
import 'package:vitomy/core/theme/theme.dart';
import 'package:vitomy/core/widgets/bq_add_fab.dart';
import 'package:vitomy/core/widgets/bq_nav_bar.dart';
import 'package:vitomy/features/settings/language_picker.dart';
import 'package:vitomy/features/settings/settings_screen.dart';
import 'package:vitomy/main.dart';

// The shared seam double, rather than a fourth recorder: it answers all three
// permission states and records what it was asked, which is what the row's
// control has to be proven against.
import '../notifications/recording_scheduler.dart';
// `show` rather than a bare import: this file declares its own `overflowReason`
// (it predates the shared library) and importing the whole library would
// collide. The scale list is the one thing that must NOT be a per-file literal
// — the file that quietly omits a scale has a matrix that no longer covers it.
import '../support/locale_matrix.dart' show bqTextScaleMatrix;

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

/// The consequence of a missing or unreachable back control on the pushed
/// Settings route (plan 06-02, S12, research PF-6).
const String strandedReason =
    'a pushed route with no working back affordance passes every widget test — '
    'tests pop programmatically — and strands the user on the first manual run '
    'on any device without a reliable back gesture. Settings is a pushed route '
    'from plan 06-02 on, so the control is the only guaranteed way out';

/// Why the back control's box is asserted as a FLOOR and not as 44.0 exactly.
const String backTapTargetReason =
    'the control is built to the S12 recipe — an IconButton with '
    'BoxConstraints.tightFor(44, 44) and zero padding — and Material then '
    'wraps it to its 48dp padded tap target, so the rendered box is 48 while '
    'the constrained icon box is 44. 48 >= 44 satisfies the guidance; what '
    'must not happen is a box SMALLER than 44 or one that changes with the '
    'text scaler, and both of those are what this case measures';

/// The visible label of the host route the push tests start from.
///
/// A literal in a test file, not copy: it names the harness, never the app.
const String pushHostLabel = 'host route';

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
    // `onboarding_seen` rides along under every case: these suites model a
    // returning user reaching Settings through the shell, and VitomyApp
    // now opens through the onboarding gate. First-launch behaviour is
    // onboarding_gate_test.dart's job.
    SharedPreferences.setMockInitialValues({
      'onboarding_seen': true,
      ...values,
    });
    return SharedPreferences.getInstance();
  }

  /// The real app under a scope carrying both overrides P-4 Option A forces:
  /// the prefs seed, and an in-memory Drift database (D-19).
  ProviderScope appScope(SharedPreferences prefs) {
    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        dbProvider.overrideWith((ref) {
          final db = VitomyDb.forTesting(NativeDatabase.memory());
          ref.onDispose(db.close);
          return db;
        }),
      ],
      child: const VitomyApp(),
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

  /// A host route that PUSHES [SettingsScreen], which is what the screen
  /// actually is from plan 06-02 on. The bare-root [settingsApp] above cannot
  /// prove anything about popping, because there is nothing under it.
  Widget pushHostApp(SharedPreferences prefs, {String locale = 'uk'}) {
    return ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: MaterialApp(
        locale: Locale(locale),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: bqTheme(),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const SettingsScreen(),
                  ),
                ),
                child: const Text(pushHostLabel),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// The back control's `IconButton`, scoped through its glyph so the finder
  /// cannot drift onto some other button the screen grows later.
  Finder backControl() => find.ancestor(
        of: find.byIcon(Icons.arrow_back_ios_new),
        matching: find.byType(IconButton),
      );

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

  /// Pushes the Settings route from the gear on the visible tab.
  ///
  /// Settings stopped being a destination in plan 06-03 (NAV-03), so this taps
  /// the gear — which is language-independent by construction, an icon with no
  /// painted text, hence the icon finder rather than a label one. Only the
  /// visible tab's gear is onstage, so the finder resolves to exactly one.
  Future<void> openSettings(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.settings_outlined));
    // A PUSH animates, unlike the destination switch this replaced, so the
    // route needs frames to arrive. Bounded frames, never `pumpAndSettle`:
    // the shell's midnight timer and minute ticker never settle. The
    // one-frame language claim below is measured AFTER this, from the row
    // tap — pumping the transition in does not weaken it.
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 20));
      if (find.byType(SettingsScreen).evaluate().isNotEmpty &&
          find.byType(LanguagePicker).evaluate().isNotEmpty) {
        break;
      }
    }
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
    await openSettings(tester);
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
    expect(find.text(uk.settingsTitle), findsWidgets,
        reason: 'the screen title and the gear label share settingsTitle, '
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
    await openSettings(tester);

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
    await openSettings(tester);

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
    await openSettings(tester);

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

      expect(find.text(uk.settingsTitle), findsOneWidget);
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
        tester.element(find.byType(VitomyApp)),
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
        tester.element(find.byType(VitomyApp)),
        listen: false,
      );

      // The add sheet is opened through the shell's FAB since plan 06-04 —
      // matched by widget, not by the `addSupplement` label, which is now a
      // semantics label rather than painted text (T-06-10).
      await tester.tap(find.byType(BqAddFab));
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
  // The back control on the pushed route (plan 06-02, S12, #13).
  // -------------------------------------------------------------------

  group('S12 back control', () {
    for (final locale in const ['uk', 'en']) {
      final l10n = lookupAppLocalizations(Locale(locale));

      testWidgets(
          '$locale: the control renders once, is labelled navBack in the '
          'ACTIVE locale, and its box is >= 44 and TEXT-FREE — identical at '
          '1.0 / 1.6 / 2.0', (tester) async {
        usePhoneSurface(tester);
        final prefs = await seedPrefs({});
        final sizes = <Size>[];
        for (final scale in bqTextScaleMatrix) {
          await tester.pumpWidget(
            settingsApp(
              prefs,
              locale: locale,
              textScaler: TextScaler.linear(scale),
            ),
          );
          await tester.pump();

          expect(backControl(), findsOneWidget, reason: strandedReason);
          expect(
            find.bySemanticsLabel(l10n.navBack),
            findsOneWidget,
            reason: 'the control is icon-only, so the ARB label is the ONLY '
                'thing a screen-reader user has — and it must follow the '
                'active language like every other string on this screen',
          );
          final size = tester.getSize(backControl());
          expect(size.width, greaterThanOrEqualTo(44.0),
              reason: backTapTargetReason);
          expect(size.height, greaterThanOrEqualTo(44.0),
              reason: backTapTargetReason);
          expect(tester.takeException(), isNull, reason: overflowReason);
          sizes.add(size);
        }

        expect(sizes.toSet(), hasLength(1),
            reason: 'the control holds NO text, so its extent is pure '
                'geometry — a scale-dependent box would mean something '
                'textual leaked into the row and the D-5 argument for a '
                'dedicated row no longer holds (measured: $sizes)');
      });
    }

    testWidgets('the control carries its own tap action under '
        'excludeSemantics (WR-02)', (tester) async {
      usePhoneSurface(tester);
      final prefs = await seedPrefs({});
      await tester.pumpWidget(settingsApp(prefs));
      await tester.pump();

      expect(
        tester
            .getSemantics(find.bySemanticsLabel(uk.navBack))
            .getSemanticsData()
            .hasAction(SemanticsAction.tap),
        isTrue,
        reason: '`excludeSemantics: true` drops every DESCENDANT action, so '
            'the node has to carry one itself — without it Settings announces '
            'a back button VoiceOver and TalkBack cannot press, while passing '
            'every coordinate-tap test',
      );
    });

    testWidgets(
        'activating the control through SemanticsAction.tap pops the PUSHED '
        'route — not a coordinate tap', (tester) async {
      usePhoneSurface(tester);
      final prefs = await seedPrefs({});
      await tester.pumpWidget(pushHostApp(prefs));
      await tester.pump();

      await tester.tap(find.text(pushHostLabel));
      await tester.pumpAndSettle();
      expect(find.text(uk.settingsTitle), findsOneWidget,
          reason: 'the pushed Settings route must be on screen before the '
              'pop is exercised');

      // Assistive technology does not tap widgets. It activates actions.
      tester.semantics.performAction(
        find.semantics.byLabel(uk.navBack),
        SemanticsAction.tap,
      );
      await tester.pumpAndSettle();

      expect(find.text(uk.settingsTitle), findsNothing, reason: strandedReason);
      expect(find.text(pushHostLabel), findsOneWidget,
          reason: 'popping returns to the route underneath, unchanged');
    });

    testWidgets(
        'activating the control on a BARE ROOT throws nothing and leaves the '
        'screen up — what maybePop buys over pop', (tester) async {
      usePhoneSurface(tester);
      final prefs = await seedPrefs({});
      await tester.pumpWidget(settingsApp(prefs));
      await tester.pump();

      tester.semantics.performAction(
        find.semantics.byLabel(uk.navBack),
        SemanticsAction.tap,
      );
      await tester.pump();

      expect(tester.takeException(), isNull,
          reason: 'the screen must not assume it was pushed: `pop` on a root '
              'route pops nothing and, with a system-back handler behind it, '
              'is the shape that closes the whole app — `maybePop` is why '
              'this is a no-op instead');
      expect(find.text(uk.settingsTitle), findsOneWidget,
          reason: 'a no-op leaves the screen exactly where it was');
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

    test('no hex color literal, no font size outside 25/15/10.5, and no icon '
        'size outside 18 appears (token-only styling)', () {
      const allowedSizes = {'25', '15', '10.5'};
      // A GLYPH box is not type. Plan 06-02 added the 18dp back chevron (S12,
      // verbatim from regimen_editor_screen.dart:221-226); folding 18 into the
      // font-size list above would have licensed an 18px Text on the one
      // screen whose type list is closed. Two lists, both closed.
      const allowedIconSizes = {'18'};
      final hex = RegExp(r'0x[0-9a-fA-F]{6,8}');
      final fontSize = RegExp(r'(?:fontSize|\bsize):\s*([\d.]+)');
      // An `Icon(...)` call. No Icon call in this feature nests a paren, so a
      // flat negated class is exact here rather than an approximation — and if
      // one ever does, the outer sweep below sees its `size:` and fails loudly
      // instead of skipping it.
      final iconCall = RegExp(r'\bIcon\([^()]*\)');
      forEachSource((path, source) {
        expect(hex.hasMatch(source), isFalse,
            reason: '$path hardcodes a color; every surface, border and '
                'foreground on this screen has a named token');
        for (final call in iconCall.allMatches(source)) {
          for (final match in fontSize.allMatches(call.group(0)!)) {
            expect(allowedIconSizes, contains(match.group(1)),
                reason: '$path introduces icon size ${match.group(1)}; the '
                    'icon-size list is CLOSED at 18');
          }
        }
        for (final match in fontSize.allMatches(
          source.replaceAll(iconCall, 'Icon()'),
        )) {
          expect(allowedSizes, contains(match.group(1)),
              reason: '$path introduces font size ${match.group(1)}; the '
                  'component-level list is CLOSED at 25 / 15 / 10.5');
        }
      });
    });
  });

  // -------------------------------------------------------------------
  // The reminders permission row (NOTIF-05, DECIDED-9a, plan 07-05).
  //
  // ADDITIVE in full. Every gate above passes unedited, and the three states
  // are pumped through this file's own bilingual, text-scale, no-digit and
  // Cyrillic-leak sweeps rather than through new ones.
  // -------------------------------------------------------------------

  group('S7 reminders permission row (NOTIF-05)', () {
    /// The Settings screen with the permission answer pinned from OUTSIDE, the
    /// way `settingsApp` pins the locale and the text scale.
    ///
    /// [allowed] is the seam's answer, not the row's state: the row asks the
    /// controller, the controller asks the seam, and `null` is the third real
    /// answer — a platform that cannot say, which is also every widget test
    /// that installs no seam at all.
    Widget remindersApp(
      SharedPreferences prefs, {
      required bool? allowed,
      String locale = 'uk',
      TextScaler? textScaler,
    }) {
      return ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          notificationSchedulerProvider
              .overrideWithValue(RecordingScheduler(enabled: allowed)),
        ],
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

    /// Pumps until the permission answer has resolved — it arrives one
    /// microtask after the row mounts, never as a loading state.
    Future<void> pumpResolved(WidgetTester tester) async {
      await tester.pump();
      await tester.pump();
      await tester.pump();
    }

    /// Every string the language half of this screen renders, derived rather
    /// than transcribed — the set the screen showed BEFORE this plan.
    ///
    /// [l10n.settingsShowIntroAgain] is in the set because the show-intro-again
    /// row ships in every build. Naming it here is what keeps the assertion
    /// EXACT rather than loosened to a superset — the point of this test is
    /// that the reminders section adds nothing while its answer is unknown,
    /// and that claim only means something if every other row is enumerated.
    ///
    /// [l10n.settingsSupportRow] joined it on 2026-09-22 with the tip screen,
    /// for the same reason and by the same rule: a row that ships in every
    /// build is enumerated here. The alternative — relaxing this to a superset
    /// so new rows land silently — would retire the only assertion in the
    /// repository that says what this screen contains.
    Set<String> languageOnlyText(AppLocalizations l10n) => <String>{
          l10n.settingsTitle,
          l10n.settingsLanguageTitle,
          l10n.languageSystem,
          for (final locale in AppLocalizations.supportedLocales)
            lookupAppLocalizations(locale).languageName,
          '✓',
          l10n.settingsShowIntroAgain,
          l10n.settingsSupportRow,
        };

    testWidgets(
        'with the answer UNKNOWN the screen renders exactly what it rendered '
        'before this plan — no section, no placeholder, no spinner',
        (tester) async {
      usePhoneSurface(tester);
      final prefs = await seedPrefs({});
      await tester.pumpWidget(remindersApp(prefs, allowed: null));
      await pumpResolved(tester);

      expect(renderedText(tester).toSet(), languageOnlyText(uk),
          reason: 'absence is not a loading surface. A row stating an unknown '
              'fact would be a lie on the one screen whose whole job is to be '
              'truthful about configuration, and this screen may carry no '
              'spinner, skeleton or async value at all.');
      expect(find.text(uk.settingsRemindersTitle), findsNothing);
      expect(find.text(uk.settingsRemindersOpenSystem), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('with the answer ALLOWED the section, the statement and the '
        'control all render', (tester) async {
      usePhoneSurface(tester);
      final prefs = await seedPrefs({});
      await tester.pumpWidget(remindersApp(prefs, allowed: true));
      await pumpResolved(tester);

      expect(find.text(uk.settingsRemindersTitle), findsOneWidget);
      expect(find.text(uk.settingsRemindersAllowed), findsOneWidget);
      expect(find.text(uk.settingsRemindersBlocked), findsNothing);
      expect(find.text(uk.settingsRemindersOpenSystem), findsOneWidget,
          reason: 'the control is offered in BOTH states: a user who allowed '
              'reminders may still want to reach the operating system own '
              'settings for them.');
    });

    testWidgets('with the answer NOT ALLOWED the same section renders with the '
        'other statement', (tester) async {
      usePhoneSurface(tester);
      final prefs = await seedPrefs({});
      await tester.pumpWidget(remindersApp(prefs, allowed: false));
      await pumpResolved(tester);

      expect(find.text(uk.settingsRemindersTitle), findsOneWidget);
      expect(find.text(uk.settingsRemindersBlocked), findsOneWidget);
      expect(find.text(uk.settingsRemindersAllowed), findsNothing);
      expect(find.text(uk.settingsRemindersOpenSystem), findsOneWidget,
          reason: 'this is the only route back on iOS after a refusal, and '
              'after a second refusal on Android.');
    });

    testWidgets(
        'the row SELF-CORRECTS: coming back from the system settings is a '
        'resume, and the statement follows it with no further action',
        (tester) async {
      usePhoneSurface(tester);
      final prefs = await seedPrefs({});
      final scheduler = RecordingScheduler(enabled: false);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            notificationSchedulerProvider.overrideWithValue(scheduler),
          ],
          child: MaterialApp(
            locale: const Locale('uk'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: bqTheme(),
            home: const SettingsScreen(),
          ),
        ),
      );
      await pumpResolved(tester);
      expect(find.text(uk.settingsRemindersBlocked), findsOneWidget);

      // The user leaves through the control, switches reminders on in the
      // operating system's own settings, and comes back.
      scheduler.enabled = true;
      for (final state in const [
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]) {
        await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
          'flutter/lifecycle',
          const StringCodec().encodeMessage(state.toString()),
          (_) {},
        );
      }
      await pumpResolved(tester);

      expect(find.text(uk.settingsRemindersAllowed), findsOneWidget,
          reason: 'this is what lets the row carry no retry control — which '
              'this screen\'s own gates forbid anyway.');
      expect(find.text(uk.settingsRemindersBlocked), findsNothing);
    });

    testWidgets('the eyebrow is a semantics HEADER, like the language one',
        (tester) async {
      usePhoneSurface(tester);
      final prefs = await seedPrefs({});
      await tester.pumpWidget(remindersApp(prefs, allowed: false));
      await pumpResolved(tester);

      expect(
        tester.getSemantics(find.text(uk.settingsRemindersTitle)),
        isSemantics(isHeader: true),
        reason: 'assistive technology navigates by heading; the second section '
            'must be reachable the same way the first is',
      );
    });

    testWidgets('the control is a BUTTON in the semantics tree, carrying its '
        'own label and its own tap action (WR-02)', (tester) async {
      usePhoneSurface(tester);
      final prefs = await seedPrefs({});
      await tester.pumpWidget(remindersApp(prefs, allowed: false));
      await pumpResolved(tester);

      final node =
          tester.getSemantics(find.bySemanticsLabel(uk.settingsRemindersOpenSystem));
      expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue,
          reason: '`excludeSemantics: true` drops every DESCENDANT action, so '
              'the node has to carry one itself — without it the row announces '
              'a button VoiceOver and TalkBack cannot press, while passing '
              'every coordinate-tap test');
    });

    testWidgets(
        'activating the control through SemanticsAction.tap opens the system '
        'settings exactly once — not a coordinate tap', (tester) async {
      usePhoneSurface(tester);
      final prefs = await seedPrefs({});
      final scheduler = RecordingScheduler(enabled: false);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            notificationSchedulerProvider.overrideWithValue(scheduler),
          ],
          child: MaterialApp(
            locale: const Locale('uk'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: bqTheme(),
            home: const SettingsScreen(),
          ),
        ),
      );
      await pumpResolved(tester);

      // Assistive technology does not tap widgets. It activates actions.
      tester.semantics.performAction(
        find.semantics.byLabel(uk.settingsRemindersOpenSystem),
        SemanticsAction.tap,
      );
      await pumpResolved(tester);

      expect(
        scheduler.calls
            .where((c) => c.method == openSystemSettingsCall)
            .length,
        1,
      );
      expect(tester.takeException(), isNull);
    });

    for (final locale in const ['uk', 'en']) {
      for (final allowed in const <bool?>[null, true, false]) {
        testWidgets(
            '$locale: the screen renders with no layout exception, no digit '
            'and no stray Cyrillic with the answer $allowed, at 1.0 / 1.6 / '
            '2.0', (tester) async {
          usePhoneSurface(tester);
          final prefs = await seedPrefs({});
          final endonyms = {
            for (final l in AppLocalizations.supportedLocales)
              lookupAppLocalizations(l).languageName,
          };
          final cyrillic = RegExp(r'[Ѐ-ӿ]');

          for (final scale in bqTextScaleMatrix) {
            await tester.pumpWidget(
              remindersApp(
                prefs,
                allowed: allowed,
                locale: locale,
                textScaler: TextScaler.linear(scale),
              ),
            );
            await pumpResolved(tester);

            expect(tester.takeException(), isNull, reason: overflowReason);
            for (final data in renderedText(tester)) {
              expect(RegExp(r'[0-9]').hasMatch(data), isFalse,
                  reason: 'the new copy carries NO numeral and no magnitude: '
                      'the honest statement of the horizon limitation wants a '
                      'number and that number belongs to the deferred settings '
                      'surface. "$data" means one crept in.');
              if (locale == 'en' && cyrillic.hasMatch(data)) {
                expect(endonyms, contains(data),
                    reason: 'a Cyrillic string reached the tree while en was '
                        'active: "$data" — a literal escaped the ARB');
              }
            }
          }
        });
      }
    }
  });
}
