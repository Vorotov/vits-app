/// Phase-5 on-device localization regression test — Backstops 14 and 15,
/// driven against the REAL app on a real iOS/Android device or simulator.
///
/// Run it with (iOS simulator example):
///
/// ```
/// flutter test integration_test/l10n_device_test.dart -d <device-id>
/// ```
///
/// ## Why this file exists next to `data03_loop_test.dart`
///
/// `data03_loop_test.dart` pumps `BoostqueApp` itself. It therefore proves the
/// core loop but says NOTHING about the async `main()` bootstrap that plan
/// 05-01 introduced (`WidgetsFlutterBinding.ensureInitialized()` →
/// `await SharedPreferences.getInstance()` → `runApp` with
/// `sharedPreferencesProvider` overridden). This file is the only coverage of
/// that path (T-05-10): every launch here goes through `app.main()` — the real
/// entry point, unmodified — so a bootstrap that hangs, throws, or forgets the
/// override fails here and only here.
///
/// ## What it asserts
///
/// - (a) the app launches through `main()` and paints the three-tab shell;
/// - (b) Settings is reachable and the language card lists exactly
///   `1 + supportedLocales.length` rows — System default first, then every
///   shipped language under its OWN endonym (`Українська`, `English`);
/// - (c) selecting English re-renders Settings, the nav bar, a bottom sheet
///   and a pushed route in English **on the very next frame**, with no
///   restart prompt, dialog, snackbar or thrown exception (DECIDED-7);
/// - (d) the reverse switch and the System-default option behave the same,
///   System default resolving to the device's own language;
/// - (e) E-12, asserted as INTENDED: a supplement added from the catalog in
///   Ukrainian keeps its stored Ukrainian name after the switch to English —
///   copy-on-add makes the name user data (`catalog.dart:11-15`). The chrome
///   around it (eyebrow, status chip, headings) does flip, which is the
///   control assertion that stops E-12 from passing trivially;
/// - (f) Backstop 15's cold start: with `en` stored, a FRESH `app.main()`
///   paints English on the first frame that contains the shell, and no
///   Ukrainian frame is painted before it.
///
/// ## What (f) does and does not prove — read before trusting it
///
/// The restart in (f) is a fresh `main()` inside the SAME OS process. It
/// exercises the real bootstrap and the synchronous `LocaleController` seed,
/// but `SharedPreferences.getInstance()` caches its instance per process, so
/// it is NOT proof that the value survived to disk. Disk durability across a
/// genuine process kill is proved OUTSIDE this file, by terminating and
/// relaunching the installed app from the host
/// (`xcrun simctl terminate/launch`, `adb shell am force-stop` + `am start`)
/// and screenshotting the result. Do not upgrade the claim in this file.
///
/// ## Device state
///
/// The test is tolerant of pre-existing device data, like DATA-03: it never
/// deletes rows, it normalizes any stored language override back to System
/// default at the start instead of assuming there is none, and it reuses the
/// E-12 catalog supplement if a previous run already added it.
///
/// It DELIBERATELY finishes with `en` stored in SharedPreferences — that is
/// the fixture the host-side cold-start check needs. A rerun normalizes it
/// away in step (b).
///
/// ## Premise
///
/// The device's own system language must be Ukrainian; step (b) asserts this
/// rather than assuming it, because "System default follows the device" is
/// meaningless otherwise.
///
/// ## Screenshots
///
/// Same constraint and same protocol as DATA-03: the test runs ON the device
/// and cannot spawn `xcrun`/`adb`, so [_screenshot] drops a request file into
/// the app documents directory for a host watcher
/// (`tool/l10n_screenshot_watcher.sh <ios|android> <device-id> <out-dir>`) to
/// consume. With no watcher running the test still passes.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:boostque/core/domain/repositories.dart';
import 'package:boostque/core/l10n/l10n.dart';
import 'package:boostque/core/l10n/locale_controller.dart';
import 'package:boostque/core/providers.dart';
import 'package:boostque/core/widgets/bq_add_fab.dart';
import 'package:boostque/core/widgets/bq_nav_bar.dart';
import 'package:boostque/features/calendar/week_strip.dart';
import 'package:boostque/features/settings/language_picker.dart';
import 'package:boostque/features/settings/settings_screen.dart';
import 'package:boostque/features/stack/regimen_editor_screen.dart';
import 'package:boostque/features/stack/stack_screen.dart';
import 'package:boostque/main.dart' as app;
import 'package:boostque/main.dart' show BoostqueApp;

/// The SharedPreferences key `LocaleController` owns (D-10).
const String _prefsKey = 'app_locale';

/// The catalog entry E-12 is asserted against, in both shipped languages.
const String _ukCatalogName = 'Магній бісглицинат';
const String _enCatalogName = 'Magnesium bisglycinate';

/// How long [_screenshot] waits for a host watcher before giving up.
const Duration _screenshotWait = Duration(seconds: 12);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'L10N: language switching + cold start, on device, through real main()',
    (tester) async {
      // =================================================================
      // (a) launch through the REAL entry point
      // =================================================================
      // Not `pumpWidget(BoostqueApp())`: the whole point of this file is the
      // async bootstrap in main() — ensureInitialized, the awaited
      // SharedPreferences load, and the provider override handed to runApp.
      await app.main();
      final launchFrames = await _pumpUntilShell(tester);
      debugPrint('L10N (a): main() painted the shell after $launchFrames frame(s)');

      expect(find.byType(BoostqueApp), findsOneWidget, reason: 'runApp ran');
      expect(find.byType(BqNavBar), findsOneWidget, reason: 'app shell');
      expect(find.byType(StackScreen), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'clean bootstrap');

      final container = ProviderScope.containerOf(
        tester.element(find.byType(BoostqueApp)),
        listen: false,
      );
      // The SAME store main() resolved — a second getInstance() returns the
      // process-cached instance, which is exactly why the cold-start claim in
      // step (i) is bounded the way it is (see the library doc).
      final prefs = await SharedPreferences.getInstance();

      // =================================================================
      // (b) Settings, normalized to System default, read in Ukrainian
      // =================================================================
      // The tab is found by ICON, never by label: the label is the very thing
      // under test and changes language mid-run.
      await _tap(tester, find.byIcon(Icons.settings_outlined));
      await _pumpUntil(
        tester,
        () => find.byType(SettingsScreen).evaluate().isNotEmpty,
        'the Settings tab',
      );
      expect(find.byType(LanguagePicker), findsOneWidget);

      // Tolerant of a previous run's leftover override (this test ends with
      // one on purpose): clear it through the picker, not through the store.
      final stored = container.read(localeControllerProvider);
      if (stored != null) {
        debugPrint('L10N (b): found a stored override ($stored) — clearing it');
        await _tap(tester, find.text(_l10n(tester).languageSystem));
        await _pump(tester, 6);
      }
      expect(container.read(localeControllerProvider), isNull);
      expect(prefs.getString(_prefsKey), isNull, reason: 'override cleared');

      // The premise, asserted rather than assumed.
      final systemLocale =
          WidgetsBinding.instance.platformDispatcher.locales.first;
      debugPrint('L10N (b): device system locale is $systemLocale');
      expect(
        systemLocale.languageCode,
        'uk',
        reason: 'this test requires the DEVICE language to be Ukrainian — '
            '"System default follows the device" is unprovable otherwise',
      );
      expect(_locale(tester).languageCode, 'uk');

      // Ukrainian chrome, both in the nav bar and on the screen. Scoped
      // finders, not bare ones: `settingsTitle` is deliberately reused for the
      // gear's semantics label AND the screen title, so both placements are
      // checked where they live instead of by counting matches app-wide.
      expect(_inNav('Стек'), findsWidgets);
      expect(_inNav('Сьогодні'), findsWidgets);
      expect(_inNav('Календар'), findsWidgets);
      expect(_inNav('Налаштування'), findsNothing,
          reason: 'Settings left the bar in plan 06-03 (NAV-03)');
      expect(_inSettings('Налаштування'), findsOneWidget,
          reason: 'gear label + screen title share one ARB key');
      expect(find.text('МОВА'), findsOneWidget);

      // The picker contract: System default FIRST, then one row per shipped
      // language under its OWN endonym, and exactly one row checked.
      final rows = find.descendant(
        of: find.byType(LanguagePicker),
        matching: find.byType(InkWell),
      );
      expect(
        rows,
        findsNWidgets(1 + AppLocalizations.supportedLocales.length),
        reason: 'System default + one row per ARB file',
      );
      expect(find.text('Системна'), findsOneWidget);
      expect(find.text('Українська'), findsOneWidget,
          reason: 'uk names itself in Ukrainian');
      expect(find.text('English'), findsOneWidget,
          reason: 'en names itself in English even while the UI is Ukrainian');
      expect(_checkedRows(tester), 1, reason: 'exactly one option checked');
      // System default is the checked one and it is the FIRST row.
      final systemRowY = tester.getTopLeft(find.text('Системна')).dy;
      expect(systemRowY, lessThan(tester.getTopLeft(find.text('Українська')).dy));
      expect(systemRowY, lessThan(tester.getTopLeft(find.text('English')).dy));
      debugPrint('L10N (b): picker contract OK, Ukrainian via System default');

      await _screenshot(tester, 'settings-uk');

      // =================================================================
      // (c) E-12 fixture: a CATALOG supplement added while Ukrainian is live
      // =================================================================
      await _leaveSettings(tester);
      await _goToTab(tester, Icons.inventory_2_outlined, Icons.inventory_2);
      await _pumpUntil(
        tester,
        () => find.byType(StackScreen).evaluate().isNotEmpty,
        'the Stack tab',
      );
      expect(find.text('Мій стек'), findsOneWidget);

      var entries = await _stack(tester, container);
      final alreadyThere = entries.any((e) => e.supplement.name == _ukCatalogName);
      if (alreadyThere) {
        debugPrint('L10N (c): "$_ukCatalogName" already in the stack — reused');
      } else {
        // The shell's floating + since plan 06-04 — the Стек screen's
        // full-width add button is deleted.
        await _tap(tester, find.byType(BqAddFab));
        await _pumpUntil(
          tester,
          () => find.byType(BottomSheet).evaluate().isNotEmpty,
          'the add-supplement sheet',
        );
        // The sheet opens on the catalog tab, in Ukrainian.
        expect(find.text('Пошук у базі'), findsOneWidget);
        expect(find.text('Вручну'), findsOneWidget);

        await tester.enterText(
          find.descendant(
            of: find.byType(BottomSheet),
            matching: find.byType(TextField),
          ),
          'Магній',
        );
        await _pump(tester, 8);
        await _tap(tester, find.text(_ukCatalogName));
        await _pumpUntil(
          tester,
          () => find.byType(RegimenEditorScreen).evaluate().isNotEmpty,
          'the regimen editor pushed after the catalog pick',
        );
        // No regimen is wanted — this run only needs the Supplement row.
        await _tap(tester, find.byIcon(Icons.arrow_back_ios_new));
        await _pumpUntil(
          tester,
          () => find.byType(RegimenEditorScreen).evaluate().isEmpty,
          'the editor to pop',
        );
        entries = await _stack(tester, container);
        expect(
          entries.any((e) => e.supplement.name == _ukCatalogName),
          isTrue,
          reason: 'the catalog pick copied the Ukrainian name onto the row',
        );
        debugPrint('L10N (c): added "$_ukCatalogName" from the catalog');
      }
      final e12Id = entries
          .firstWhere((e) => e.supplement.name == _ukCatalogName)
          .supplement
          .id;

      // =================================================================
      // (d) switch to English — instantly, with no restart prompt
      // =================================================================
      await _tap(tester, find.byIcon(Icons.settings_outlined));
      await _pumpUntil(
        tester,
        () => find.byType(SettingsScreen).evaluate().isNotEmpty,
        'the Settings tab',
      );

      // ONE frame between the tap and the assertions: criterion 3 says the
      // language applies instantly, and `LocaleController.setLocale` sets
      // state BEFORE the disk write precisely so this holds (PF-3).
      await tester.tap(find.text('English'));
      await tester.pump();

      expect(_locale(tester).languageCode, 'en',
          reason: 'MaterialApp took the new locale on the very next frame');
      expect(find.text('LANGUAGE'), findsOneWidget);
      expect(_inSettings('Settings'), findsOneWidget, reason: 'screen title');
      expect(_inNav('Settings'), findsNothing, reason: 'not a destination');
      expect(_inNav('Stack'), findsWidgets);
      expect(_inNav('Today'), findsWidgets);
      expect(_inNav('Calendar'), findsWidgets);
      expect(find.text('System default'), findsOneWidget);
      expect(find.text('МОВА'), findsNothing);
      expect(find.text('Налаштування'), findsNothing);
      expect(find.text('Системна'), findsNothing);
      // Endonyms do NOT translate — that is the whole point of the label rule.
      expect(find.text('Українська'), findsOneWidget);
      expect(find.text('English'), findsOneWidget);
      expect(_checkedRows(tester), 1);

      // DECIDED-7: selecting IS the commit. Nothing may appear to confirm it.
      expect(find.byType(Dialog), findsNothing, reason: 'no restart prompt');
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
      expect(find.byType(BottomSheet), findsNothing);
      expect(tester.takeException(), isNull);
      debugPrint('L10N (d): uk -> en applied in ONE frame, no restart prompt');

      await _pump(tester, 6);
      expect(prefs.getString(_prefsKey), 'en', reason: 'override persisted');
      await _screenshot(tester, 'settings-en');

      // =================================================================
      // (e) E-12: chrome flips, the saved supplement NAME does not
      // =================================================================
      await _leaveSettings(tester);
      await _goToTab(tester, Icons.inventory_2_outlined, Icons.inventory_2);
      await _pumpUntil(
        tester,
        () => find.text('My stack').evaluate().isNotEmpty,
        'the Stack tab in English',
      );
      // Control assertions: the chrome around the card really did flip, so a
      // green E-12 cannot mean "the switch never happened".
      expect(find.text('SUPPLEMENTS'), findsOneWidget);
      expect(find.text('ДОБАВКИ'), findsNothing);
      // v1 asserted a full-width "Add supplement" FilledButton here. Plan
      // 06-04 deleted it: the shell's floating + is the only add affordance
      // now (UX-01), so its absence is the assertion — and it is checked on a
      // NON-empty stack, which is the case the deleted button used to serve.
      expect(
        find.widgetWithText(FilledButton, 'Add supplement'),
        findsNothing,
        reason: 'UX-01: the Stack screen has no add CTA of its own any more',
      );
      expect(find.byType(BqAddFab), findsOneWidget,
          reason: 'the shell FAB is what replaced it');

      // The claim itself, at the data layer (the name is user data now)...
      final afterSwitch = await _stack(tester, container);
      expect(
        afterSwitch.firstWhere((e) => e.supplement.id == e12Id).supplement.name,
        _ukCatalogName,
        reason: 'E-12 (INTENDED): copy-on-add makes the catalog name user '
            'data; switching the app language must NOT rename it',
      );
      // ...and on screen. The English catalog name must appear NOWHERE.
      expect(find.text(_enCatalogName), findsNothing,
          reason: 'E-12: the stored supplement did not re-localize');
      await tester.scrollUntilVisible(
        find.text(_ukCatalogName),
        200,
        scrollable: find.descendant(
          of: find.byType(StackScreen),
          matching: find.byType(Scrollable),
        ).first,
        maxScrolls: 60,
      );
      await _pump(tester, 4);
      expect(find.text(_ukCatalogName), findsOneWidget);
      debugPrint('L10N (e): E-12 asserted as INTENDED — name kept, chrome flipped');

      // =================================================================
      // (f) an OPEN bottom sheet and a PUSHED route follow the language
      // =================================================================
      // Through the shell's floating + since plan 06-04 — the full-width CTA
      // this step used to tap no longer exists.
      await _tap(tester, find.byType(BqAddFab));
      await _pumpUntil(
        tester,
        () => find.byType(BottomSheet).evaluate().isNotEmpty,
        'the add-supplement sheet in English',
      );
      expect(find.text('Search catalog'), findsOneWidget);
      expect(find.text('Add manually'), findsOneWidget);
      expect(find.text('Name or active substance'), findsOneWidget);

      // Flip the language WHILE the modal route is on screen. The picker is
      // unreachable behind a modal, so this one hop is driven through the
      // controller rather than the UI — the picker's own wiring is proved in
      // (d), (g) and (h); what is proved HERE is that an already-mounted
      // modal route rebuilds with the new locale.
      await container
          .read(localeControllerProvider.notifier)
          .setLocale(const Locale('uk'));
      await tester.pump();
      expect(find.text('Пошук у базі'), findsOneWidget,
          reason: 'the OPEN sheet re-rendered in Ukrainian on the next frame');
      expect(find.text('Вручну'), findsOneWidget);
      expect(find.text('Search catalog'), findsNothing);
      debugPrint('L10N (f): an open bottom sheet re-rendered in one frame');

      // Back to English, still with the sheet open, then close it.
      await container
          .read(localeControllerProvider.notifier)
          .setLocale(const Locale('en'));
      await tester.pump();
      expect(find.text('Search catalog'), findsOneWidget);
      await _tap(tester, find.widgetWithText(TextButton, 'Close'));
      await _pumpUntil(
        tester,
        () => find.byType(BottomSheet).evaluate().isEmpty,
        'the sheet to close',
      );

      // A pushed route: the regimen editor, opened from the E-12 card.
      await _tap(tester, find.text(_ukCatalogName));
      await _pumpUntil(
        tester,
        () => find.byType(RegimenEditorScreen).evaluate().isNotEmpty,
        'the regimen editor pushed from the card',
      );
      expect(find.text('Dosing schedule'), findsOneWidget);
      expect(find.text('PERIODICITY'), findsOneWidget);
      expect(find.text('Cyclic'), findsOneWidget);
      expect(find.text('DOSE TIMES'), findsOneWidget);
      // The supplement's own name inside the pushed route is user data too.
      expect(find.text(_enCatalogName), findsNothing);

      await container
          .read(localeControllerProvider.notifier)
          .setLocale(const Locale('uk'));
      await tester.pump();
      expect(find.text('Розклад прийому'), findsOneWidget,
          reason: 'the PUSHED route re-rendered in Ukrainian on the next frame');
      expect(find.text('ПЕРІОДИЧНІСТЬ'), findsOneWidget);
      expect(find.text('Dosing schedule'), findsNothing);
      debugPrint('L10N (f): a pushed route re-rendered in one frame');

      await _tap(tester, find.byIcon(Icons.arrow_back_ios_new));
      await _pumpUntil(
        tester,
        () => find.byType(RegimenEditorScreen).evaluate().isEmpty,
        'the editor to pop',
      );

      // =================================================================
      // (g) the Сьогодні + Календар surfaces follow too
      // =================================================================
      await _goToTab(tester, Icons.today_outlined, Icons.today);
      await _pumpUntil(
        tester,
        () => find.byType(WeekStrip).evaluate().isNotEmpty,
        'the Сьогодні tab in Ukrainian',
      );
      expect(find.text('Сьогодні'), findsWidgets);
      await _goToTab(tester, Icons.calendar_month_outlined, Icons.calendar_month);
      await _pumpUntil(
        tester,
        () => find.text('Рік').evaluate().isNotEmpty,
        'the planner in Ukrainian',
      );
      expect(find.text('Цикли'), findsOneWidget);
      expect(find.text('Планувальник'), findsOneWidget,
          reason: 'the Календар destination IS the planner (NAV-02) — there '
              'is no in-tab entry action to tap any more');

      // Switch to English from Settings and come back: the planner, which was
      // built while Ukrainian was live, must have followed. Settings is a
      // PUSHED route now, so coming back is a pop — and it must land on the
      // same destination it was opened from.
      await _tap(tester, find.byIcon(Icons.settings_outlined));
      await _pumpUntil(
        tester,
        () => find.byType(SettingsScreen).evaluate().isNotEmpty,
        'the pushed Settings route',
      );
      await tester.tap(find.text('English'));
      await tester.pump();
      expect(_inSettings('Settings'), findsOneWidget);
      await _tap(tester, find.byIcon(Icons.arrow_back_ios_new));
      await _pumpUntil(
        tester,
        () => find.text('Year').evaluate().isNotEmpty,
        'the planner in English',
      );
      expect(find.text('Cycles'), findsOneWidget);
      expect(find.text('Рік'), findsNothing);
      expect(find.text('Цикли'), findsNothing);
      expect(tester.takeException(), isNull);
      debugPrint('L10N (g): Сьогодні + Календар followed the switch');

      // =================================================================
      // (h) back to Ukrainian, then System default
      // =================================================================
      await _tap(tester, find.byIcon(Icons.settings_outlined));
      await _pumpUntil(
        tester,
        () => find.byType(SettingsScreen).evaluate().isNotEmpty,
        'the Settings tab',
      );
      await tester.tap(find.text('Українська'));
      await tester.pump();
      expect(_locale(tester).languageCode, 'uk');
      expect(find.text('МОВА'), findsOneWidget);
      expect(_inSettings('Налаштування'), findsOneWidget);
      expect(_inNav('Стек'), findsWidgets);
      expect(find.text('LANGUAGE'), findsNothing);
      expect(_checkedRows(tester), 1);
      await _pump(tester, 6);
      expect(prefs.getString(_prefsKey), 'uk');
      debugPrint('L10N (h): en -> uk applied in ONE frame');

      // System default: clears the override and follows the device.
      await tester.tap(find.text('Системна'));
      await tester.pump();
      expect(container.read(localeControllerProvider), isNull,
          reason: 'System default means NO override');
      expect(_locale(tester).languageCode, systemLocale.languageCode,
          reason: 'System default follows the device language');
      expect(find.text('МОВА'), findsOneWidget);
      expect(_checkedRows(tester), 1);
      await _pump(tester, 6);
      expect(prefs.getString(_prefsKey), isNull,
          reason: 'System default REMOVES the key rather than storing a code');
      expect(tester.takeException(), isNull);
      debugPrint('L10N (h): System default -> ${_locale(tester)} (device)');

      // =================================================================
      // (i) Backstop 15 cold start: a FRESH main() with `en` stored
      // =================================================================
      await tester.tap(find.text('English'));
      await tester.pump();
      expect(_locale(tester).languageCode, 'en');
      await _pump(tester, 10);
      expect(prefs.getString(_prefsKey), 'en');

      // Tear the tree down, then boot the app again through main() itself.
      await tester.pumpWidget(const SizedBox());
      await _pump(tester, 20);
      expect(find.byType(BoostqueApp), findsNothing);

      await app.main();
      // Assert on the FIRST frame that contains the shell — and fail if any
      // frame before it painted Ukrainian. That is precisely the "no
      // system-language frame first" claim the synchronous seed exists for
      // (P-4 Option A), reduced to something a test can observe.
      var frames = 0;
      var painted = false;
      for (var i = 0; i < 200 && !painted; i++) {
        await tester.pump(const Duration(milliseconds: 50));
        frames++;
        expect(
          find.text('Стек').evaluate(),
          isEmpty,
          reason: 'a Ukrainian frame painted before the stored English one '
              '(frame $frames) — the synchronous seed regressed',
        );
        painted = find.text('Stack').evaluate().isNotEmpty;
      }
      expect(painted, isTrue, reason: 'the shell repainted after main()');
      expect(_inNav('Today'), findsWidgets);
      expect(_inNav('Calendar'), findsWidgets);
      expect(tester.takeException(), isNull);
      debugPrint(
        'L10N (i): fresh main() painted ENGLISH on shell frame $frames, '
        'with no Ukrainian frame before it '
        '(same-process restart — disk durability is proved by the host-side '
        'terminate/launch step, not here)',
      );

      await _screenshot(tester, 'coldstart-en');

      // The `en` override is left in place ON PURPOSE: it is the fixture the
      // host-side cold-start check reads. Step (b) clears it on a rerun.
      expect(prefs.getString(_prefsKey), 'en',
          reason: 'fixture for the host-side cold-start relaunch');

      // Leave the tree down so Drift's stream-close timers and the midnight
      // timer are gone before the harness's pending-timer check.
      await tester.pumpWidget(const SizedBox());
      await _pump(tester, 20);
    },
    timeout: const Timeout(Duration(minutes: 10)),
  );
}

/// Pumps [frames] real frames, [ms] apart (the live binding runs real time).
Future<void> _pump(WidgetTester tester, int frames, [int ms = 50]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(Duration(milliseconds: ms));
  }
}

/// Pumps until [condition] holds, failing with [what] on timeout.
///
/// Never `pumpAndSettle`: the minute ticker and the midnight timer are both
/// permanently pending, and Drift emissions arrive asynchronously.
Future<void> _pumpUntil(
  WidgetTester tester,
  bool Function() condition,
  String what, {
  int attempts = 200,
}) async {
  for (var i = 0; i < attempts; i++) {
    await tester.pump(const Duration(milliseconds: 50));
    if (condition()) return;
  }
  fail('L10N timed out waiting for $what');
}

/// Pumps single frames until the app shell exists; returns the frame count.
Future<int> _pumpUntilShell(WidgetTester tester) async {
  for (var i = 1; i <= 200; i++) {
    await tester.pump(const Duration(milliseconds: 50));
    if (find.byType(BqNavBar).evaluate().isNotEmpty) return i;
  }
  fail('L10N timed out waiting for main() to paint the app shell');
}

/// Scrolls [finder] into view (no-op outside a scrollable), taps it, and pumps.
Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await _pump(tester, 4);
  await tester.tap(finder);
  await _pump(tester, 8);
}

/// Pops the pushed Settings route back to the shell.
///
/// Since plan 06-02 (NAV-03) Settings is a route ON TOP of the shell, not a
/// fourth destination, so the navigation bar is offstage while it is open and
/// no tab can be tapped from here. Every "now go to tab X" step that follows a
/// Settings visit has to leave through the back control first.
Future<void> _leaveSettings(WidgetTester tester) async {
  await _tap(tester, find.byIcon(Icons.arrow_back_ios_new));
  await _pumpUntil(
    tester,
    () => find.byType(SettingsScreen).evaluate().isEmpty,
    'Settings to pop back to the shell',
  );
}

/// Selects a bar destination, tolerating that it may already be selected.
///
/// The bar swaps a destination's glyph when it is selected (`inventory_2` for
/// `inventory_2_outlined`), and since plan 06-02 Settings is a route rather
/// than a fourth destination — so popping it leaves the tab the user came from
/// still selected, showing the FILLED glyph. A step that says "go to Стек"
/// therefore has to accept "already there" instead of hunting for an outlined
/// icon that is legitimately not on screen. In v1 this could not arise:
/// visiting Settings always deselected whatever tab preceded it.
Future<void> _goToTab(
  WidgetTester tester,
  IconData icon,
  IconData selectedIcon,
) async {
  if (find.byIcon(selectedIcon).evaluate().isNotEmpty) return;
  await _tap(tester, find.byIcon(icon));
}

/// The shell's navigation bar, INCLUDING when it is offstage.
///
/// Since plan 06-03 (NAV-03) Settings is a pushed opaque route rather than a
/// fourth destination, so while it is open the shell beneath it is still
/// mounted — that is precisely what "returns to the tab you were on" rests on —
/// but it is marked offstage, and `find.byType` skips offstage widgets by
/// default. Without `skipOffstage: false` every assertion below that reads the
/// locale or the bar's labels throws `Bad state: No element` the moment
/// Settings is open, which is exactly when this test needs to read them.
Finder _navBar() => find.byType(BqNavBar, skipOffstage: false);

/// The locale the widget tree is actually rendering in.
Locale _locale(WidgetTester tester) =>
    Localizations.localeOf(tester.element(_navBar()));

/// The strings the widget tree is actually rendering with.
AppLocalizations _l10n(WidgetTester tester) =>
    AppLocalizations.of(tester.element(_navBar()));

/// [text] as rendered inside the bottom navigation bar.
///
/// Offstage-tolerant for the same reason as [_navBar]: the bar's labels are
/// rebuilt in the new language while Settings sits on top of it, and the point
/// of checking them here is that the rebuild reached the shell too, not only
/// the visible route.
Finder _inNav(String text) => find.descendant(
      of: _navBar(),
      matching: find.text(text, skipOffstage: false),
    );

/// [text] as rendered inside the Settings screen body.
Finder _inSettings(String text) =>
    find.descendant(of: find.byType(SettingsScreen), matching: find.text(text));

/// How many language rows currently render the selected check glyph.
int _checkedRows(WidgetTester tester) => find
    .descendant(of: find.byType(LanguagePicker), matching: find.text('✓'))
    .evaluate()
    .length;

/// The stack as the app's own provider graph reports it, once it has data.
Future<List<StackEntry>> _stack(
  WidgetTester tester,
  ProviderContainer container,
) async {
  List<StackEntry>? list;
  await _pumpUntil(
    tester,
    () {
      if (container.read(stackEntriesProvider)
          case AsyncData(value: final data)) {
        list = data;
        return true;
      }
      return false;
    },
    'stackEntriesProvider to resolve',
  );
  return list!;
}

/// Requests a host-side screenshot named [name] and waits briefly for it.
///
/// See the library doc: the device process cannot spawn `xcrun`/`adb`, so this
/// drops a request file in the app documents directory for a watcher to pick
/// up. Without a watcher the test simply continues.
Future<void> _screenshot(WidgetTester tester, String name) async {
  File? request;
  try {
    final dir = await getApplicationDocumentsDirectory();
    request = File('${dir.path}/bq_shot_$name.request');
    await request.writeAsString(name);
  } catch (e) {
    debugPrint('L10N screenshot request failed for $name: $e');
    return;
  }
  final deadline = _screenshotWait.inMilliseconds ~/ 50;
  for (var i = 0; i < deadline; i++) {
    await tester.pump(const Duration(milliseconds: 50));
    if (!request.existsSync()) {
      debugPrint('L10N screenshot taken: $name');
      return;
    }
  }
  try {
    request.deleteSync();
  } catch (_) {}
  debugPrint('L10N screenshot NOT taken (no host watcher): $name');
}
