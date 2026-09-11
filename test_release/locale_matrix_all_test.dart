/// The full render sweep: every main screen, in every shipped language, at
/// every text scale this project supports.
///
/// WHY THIS IS NOT IN `test/`. The fast suite already renders these screens,
/// but only in uk and en — twenty-four hardcoded `['uk','en']` loops scattered
/// across `test/`, each earning its place by asserting something specific
/// about the screen it covers. Widening all twenty-four to seven languages
/// would multiply the everyday suite's cost by three and a half for a class of
/// defect that cannot reach a user between one edit and the next. So this file
/// does the widening in ONE place instead, as a single focused sweep, and the
/// owner runs it before a production build. The twenty-four loops are
/// deliberately left alone.
///
/// The split is a DIRECTORY, not a tag: `flutter test` with no arguments runs
/// `test/` only, so nothing here slows the everyday loop, and turning this
/// gate off would mean deleting a directory rather than editing a line in a
/// config file.
///
/// WHAT THIS SWEEP ASSERTS. One thing, on purpose: that rendering throws no
/// layout exception. In a release build an overflow is not a debug stripe —
/// it is a clipped label or a dropped element, and it is the CR-01 / WR-04
/// defect class this codebase has shipped twice. Per-screen semantics belong
/// to the per-screen suites in `test/`, which already own them.
///
/// WHAT IT DOES NOT COVER, stated plainly rather than implied by absence:
///
///  * The onboarding screens and the first-run hints. Both are suppressed here
///    by the seeded preferences (this sweep models a returning user, which is
///    the only way to reach the three tabs at all), and both have their own
///    suites in `test/features/`. They are NOT swept in seven languages by
///    anything.
///  * The regimen editor, the add-supplement sheet, the dose action sheet, and
///    the planner's week and month detail sheets. All are pushed or presented
///    surfaces reached by a gesture this sweep does not make.
///  * Anything about correctness of the rendered content. A screen that
///    renders the wrong language, or the wrong day, passes here.
///
/// ARABIC IS RENDERED UNDER REAL RTL. `WidgetsApp` derives the reading
/// direction from the active locale, so pinning `locale: Locale('ar')` gives a
/// genuinely right-to-left tree — and the sweep asserts that it did, so a
/// future change that pins a direction somewhere cannot make the Arabic rows
/// quietly become another LTR run. Before this file, nothing in this
/// repository had ever rendered a whole screen right-to-left;
/// `test/features/planner_gantt_rtl_test.dart` covered one widget under an
/// explicit `Directionality`, which is a different and narrower claim.
library;

import 'package:vitomy/app_shell.dart';
import 'package:vitomy/core/db/database.dart' show VitomyDb;
import 'package:vitomy/core/domain/models.dart';
import 'package:vitomy/core/l10n/l10n.dart';
import 'package:vitomy/core/providers.dart';
import 'package:vitomy/core/theme/theme.dart';
import 'package:vitomy/core/today_controller.dart';
import 'package:vitomy/features/calendar/calendar_providers.dart';
import 'package:vitomy/features/calendar/dose_row.dart';
import 'package:vitomy/features/calendar/planner_gantt.dart';
import 'package:vitomy/features/calendar/planner_load_chart.dart';
import 'package:vitomy/features/calendar/planner_screen.dart';
import 'package:vitomy/features/calendar/planner_year_grid.dart';
import 'package:vitomy/features/settings/settings_screen.dart';
import 'package:vitomy/features/stack/stack_screen.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// The scale list is the SHARED one. A per-file literal is a per-file decision,
// and the file that quietly omits a scale has a matrix that no longer covers
// it.
import '../test/support/locale_matrix.dart' show bqTextScaleMatrix;

/// The consequence of a red `takeException()` cell, named in device terms.
const String overflowReason =
    'a layout exception at an accessibility text scale is a clipped label or a '
    'dropped element in RELEASE, not debug stripes. Fix the surface\'s '
    'computed extent or make the child flexible — never shrink the text, and '
    'never drop the cell';

void main() {
  // Locale-NEUTRAL names on purpose. These are user data, copied onto the row
  // at add-time, and they never re-localize (E-12) — a Ukrainian name would
  // render as Ukrainian on the Arabic run and say nothing about the app.
  const magnesium = Supplement(
    id: 's1',
    name: 'Magnesium',
    doseText: '400 mg',
    colorValue: 0xFF6B6FA8,
    note: '',
  );
  const creatine = Supplement(
    id: 's2',
    name: 'Creatine',
    doseText: '5 g',
    colorValue: 0xFF3F7A6A,
    note: '',
  );

  // A pinned clock, so the header date strings, the week strip and the
  // planner's four-month window are the same on any machine on any day.
  final today = DateTime.utc(2026, 8, 13);

  /// An always-active cyclic regimen — the Today tab needs materialized doses
  /// to render a populated day rather than its empty state.
  final daily = Regimen(
    id: 'r1',
    supplementId: 's1',
    kind: RegimenKind.cyclic,
    startDate: DateTime.utc(2026, 1, 1),
    endDate: null,
    onDays: 1,
    offDays: 0,
    paused: false,
    slots: const [
      DoseSlot(id: 'sl1', minutesFromMidnight: 480, doseLabel: '1 cap'),
      DoseSlot(id: 'sl2', minutesFromMidnight: 1200, doseLabel: '1 cap'),
    ],
  );

  /// A one-time course, so the planner's gantt has a bar with two ends inside
  /// the window instead of one that spans everything.
  final course = Regimen(
    id: 'r2',
    supplementId: 's2',
    kind: RegimenKind.course,
    startDate: DateTime.utc(2026, 8, 5),
    endDate: DateTime.utc(2026, 9, 30),
    onDays: 0,
    offDays: 0,
    paused: false,
    slots: const [
      DoseSlot(id: 'sl3', minutesFromMidnight: 540, doseLabel: '5 g'),
    ],
  );

  late SharedPreferences prefs;

  setUp(() async {
    // A RETURNING user: the intro gate and both one-time hints are already
    // dismissed. Without this the shell is never reached — the onboarding gate
    // renders the intro instead — and the hints would sit between the week
    // strip and the day body on the Today tab.
    // The analyzer decides "is this a test?" by looking for a `test/`
    // directory in the path, and this file deliberately does not live in one.
    // The call is exactly as legitimate here as in the twenty files under
    // `test/` that make it; the ignore is the price of the directory split,
    // and it is one line rather than a project-wide rule relaxation.
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues({
      'onboarding_seen': true,
      'first_run_hints_seen': <String>['hint_cycle', 'hint_mark_dose'],
    });
    prefs = await SharedPreferences.getInstance();
  });

  ProviderContainer makeContainer() => ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          dbProvider.overrideWith((ref) {
            final db = VitomyDb.forTesting(NativeDatabase.memory());
            ref.onDispose(db.close);
            return db;
          }),
          todayProvider.overrideWith(() => _FixedToday(today)),
          // The OTHER sanctioned clock read, pinned so the Today tab's current
          // block and overdue treatments do not depend on the hour the release
          // gate happens to be run at — 10:00, between the two slots.
          nowMinutesProvider.overrideWith((ref) => Stream.value(600)),
        ],
      );

  Widget app(
    ProviderContainer container, {
    required String locale,
    required TextScaler textScaler,
  }) {
    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        locale: Locale(locale),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: bqTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: textScaler),
          child: child!,
        ),
        home: const AppShell(),
      ),
    );
  }

  /// A phone-sized logical surface (390x844) — the narrowest realistic width,
  /// which is where a text scale actually bites.
  void usePhoneSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  /// Bounded frame pumping. NEVER `pumpAndSettle` on a tree containing the
  /// shell or Today: `TodayController` keeps a midnight `Timer` alive for the
  /// whole session and the minute ticker is permanently pending, so settling
  /// against them either hangs or returns for a reason the test did not intend
  /// (PF-7).
  Future<void> pumpFrames(WidgetTester tester, [int frames = 40]) async {
    for (var i = 0; i < frames; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
  }

  /// Tears the tree down inside the test body so Drift's zero-duration
  /// stream-close timers and the midnight `Timer` are gone before
  /// flutter_test's pending-timer check runs.
  Future<void> tearDownTree(
    WidgetTester tester,
    ProviderContainer container,
  ) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 10));
    container.dispose();
    await tester.pump(const Duration(milliseconds: 10));
    await tester.pump(const Duration(milliseconds: 10));
  }

  /// Fails with the cell's coordinates attached, so a red run names the
  /// language and scale without anyone re-reading the loop.
  void expectNoLayoutException(
    WidgetTester tester, {
    required String where,
  }) {
    expect(tester.takeException(), isNull, reason: '$where: $overflowReason');
  }

  /// Drags the planner's body scroll until [target] has been BUILT, checking
  /// for a layout exception after every step.
  ///
  /// The planner's `_BodyScroll` is a lazy `ListView`: a card below the fold
  /// is never laid out, so a sweep that only pumps covers whatever fits at
  /// scale 1.0 and progressively less as the scale rises — exactly backwards.
  /// Dragging is also the only way this sweep sees a card mid-scroll, which is
  /// where a constrained-height child fails.
  ///
  /// Bounded, like every pump in this file: `scrollUntilVisible` settles the
  /// tree internally, and the shell's midnight `Timer` never lets it.
  Future<void> scrollUntilBuilt(
    WidgetTester tester,
    Finder target, {
    required String where,
  }) async {
    for (var step = 0; step < 15; step++) {
      if (target.evaluate().isNotEmpty) return;
      await tester.drag(find.byType(ListView), const Offset(0, -220));
      await pumpFrames(tester, 8);
      expectNoLayoutException(tester, where: '$where (scrolling, step $step)');
    }
  }

  final tags = AppLocalizations.supportedLocales
      .map((l) => l.toLanguageTag())
      .toList();

  test('the sweep covers every language the app ships', () {
    // Derived from the app itself, so an eighth language is swept the day its
    // ARB lands. A hardcoded list here would be the twenty-fifth
    // `['uk','en']`.
    expect(tags.length, greaterThanOrEqualTo(7),
        reason: 'the shipped-locale list resolved to ${tags.length} entries. '
            'If a language was deliberately dropped, lower this floor in the '
            'same commit that drops it — silently sweeping fewer languages is '
            'the failure this line exists to catch');
    expect(tags, contains('ar'),
        reason: 'Arabic is the only right-to-left language shipping, and the '
            'RTL cells below are the only whole-screen RTL coverage in this '
            'repository');
  });

  for (final tag in tags) {
    for (final scale in bqTextScaleMatrix) {
      testWidgets(
          '$tag @ $scale: Stack, Today, Цикли, Рік and Settings all render '
          'with no layout exception', (tester) async {
        usePhoneSurface(tester);
        final container = makeContainer();
        await container.read(supplementRepoProvider).upsert(magnesium);
        await container.read(supplementRepoProvider).upsert(creatine);
        await container.read(regimenRepoProvider).upsert(daily);
        await container.read(regimenRepoProvider).upsert(course);

        final l10n = lookupAppLocalizations(Locale(tag));

        await tester.pumpWidget(
          app(container, locale: tag, textScaler: TextScaler.linear(scale)),
        );
        await pumpFrames(tester);

        // ---- The reading direction, asserted rather than assumed. ----
        // Arabic must be a genuinely RTL tree; every other language must not
        // be. Read off a widget INSIDE the shell, so this is the direction the
        // screens were actually laid out with — not the one MaterialApp was
        // asked for.
        final expected =
            tag == 'ar' ? TextDirection.rtl : TextDirection.ltr;
        expect(
          Directionality.of(tester.element(find.byType(AppShell))),
          expected,
          reason: '$tag: the shell laid out in the wrong reading direction. '
              'For ar this is the whole point of the row — a pinned '
              'Directionality anywhere above the screens would turn the only '
              'RTL coverage in this repository into a fourth LTR run',
        );

        // ---- Tab 1: Stack (the tab the app opens on). ----
        // The seeded card is asserted PRESENT, not just the screen type: an
        // empty-state screen renders one short sentence and would sail through
        // every overflow assertion below while covering none of the layout
        // this sweep exists for.
        expect(find.byType(StackScreen), findsOneWidget);
        expect(find.text('Magnesium'), findsOneWidget,
            reason: '$tag @ $scale: the seeded stack never arrived, so this '
                'cell swept an empty state and proved nothing');
        expectNoLayoutException(tester, where: '$tag @ $scale, Stack');

        // ---- Tab 2: Today. ----
        // Tapped through the real nav bar, by the label in the active
        // language, so the sweep exercises the same path a user takes.
        await tester.tap(find.text(l10n.tabToday));
        await pumpFrames(tester);
        expect(find.byType(DoseRow), findsWidgets,
            reason: '$tag @ $scale: no dose row materialized, so the Today '
                'cell swept the empty day instead of a populated one');
        expectNoLayoutException(tester, where: '$tag @ $scale, Today');

        // ---- Tab 3: the planner, in BOTH segments. ----
        // It opens on Цикли (the gantt and the weekly load chart); Рік is the
        // twelve-month coverage matrix, a completely different layout, and a
        // sweep that never taps the other segment covers half the screen.
        await tester.tap(find.text(l10n.tabCalendar));
        await pumpFrames(tester);
        expect(find.byType(PlannerScreen), findsOneWidget);
        expect(find.byType(PlannerGantt), findsOneWidget,
            reason: '$tag @ $scale: the gantt is absent, so this cell swept '
                'the planner\'s empty state, not its chart');
        expectNoLayoutException(tester, where: '$tag @ $scale, planner Цикли');

        // The weekly concurrent-load chart sits under the gantt and is below
        // the fold at the larger scales — same lazy-list reason as Рік below.
        await scrollUntilBuilt(
          tester,
          find.byType(PlannerLoadChart),
          where: '$tag @ $scale, planner Цикли',
        );
        expect(find.byType(PlannerLoadChart), findsOneWidget,
            reason: '$tag @ $scale: the weekly load chart never laid out, '
                'even after scrolling the body to the end');
        expectNoLayoutException(tester, where: '$tag @ $scale, planner Цикли');

        await tester.tap(find.text(l10n.plannerSegYear));
        await pumpFrames(tester);
        // Scrolled to, not merely tapped for. `_BodyScroll` is a lazy
        // `ListView`, so at textScaler 2.0 the header alone can push the
        // twelve-month grid past the bottom of a 390x844 viewport and it is
        // never built. Discovered by this sweep: the first version of this
        // cell asserted the grid was present straight after the tap, and went
        // red at 2.0 in en, es, fr and uk — the four languages whose header
        // copy is long enough to do it — while ar, hi and zh passed. That is
        // a correct lazy list, not a defect, but a sweep that stops at the
        // fold covers only what happens to fit.
        await scrollUntilBuilt(
          tester,
          find.byType(PlannerYearGrid),
          where: '$tag @ $scale, planner Рік',
        );
        expect(find.byType(PlannerYearGrid), findsOneWidget,
            reason: '$tag @ $scale: the twelve-month matrix never laid out, '
                'even after scrolling the body to the end');
        expectNoLayoutException(tester, where: '$tag @ $scale, planner Рік');

        // ---- The pushed Settings route, including the language picker. ----
        // The picker renders every shipped language in its OWN script, which
        // makes it the widest single row of text in the app and the likeliest
        // place for a scale to bite.
        await tester.tap(find.byIcon(Icons.settings_outlined));
        await pumpFrames(tester);
        expect(find.byType(SettingsScreen), findsOneWidget);
        expectNoLayoutException(tester, where: '$tag @ $scale, Settings');

        await tearDownTree(tester, container);
      });
    }
  }
}

/// The app's clock, pinned. `flutter_test`'s fake-async zone controls `Timer`
/// but never `DateTime.now()`, so the seam is the controller, not the clock.
class _FixedToday extends TodayController {
  _FixedToday(this.day);

  final DateTime day;

  @override
  DateTime build() => day;
}
