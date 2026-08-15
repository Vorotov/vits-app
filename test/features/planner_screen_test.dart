/// Widget tests for the planner page and its Calendar-tab seam
/// (plan 04-01, DECIDED-1, UI-SPEC S4-amendment / S6a).
///
/// Harness pieces come from `calendar_screen_test.dart`: real in-memory Drift
/// database behind the repository providers, a PINNED clock so the window is
/// the same on any machine on any day, locale uk, a 390x844 logical surface,
/// `pumpUntil` instead of `pumpAndSettle` (the midnight timer and the minute
/// ticker are both permanently pending), and an in-body `tearDownTree`.
///
/// The navigation test is driven from the Calendar screen, not by pumping
/// `PlannerScreen` directly, so the tap path under test is the real one.
library;

import 'package:boostque/core/db/database.dart' show BoostqueDb;
import 'package:boostque/core/domain/models.dart';
import 'package:boostque/core/l10n/l10n.dart';
import 'package:boostque/core/domain/repositories.dart' show StackEntry;
import 'package:boostque/core/providers.dart';
import 'package:boostque/core/theme/theme.dart';
import 'package:boostque/core/theme/tokens.dart';
import 'package:boostque/core/today_controller.dart';
import 'package:boostque/features/calendar/calendar_providers.dart';
import 'package:boostque/features/calendar/calendar_screen.dart';
import 'package:boostque/core/widgets/bq_segmented.dart';
import 'package:boostque/features/calendar/planner_gantt.dart';
import 'package:boostque/features/calendar/planner_providers.dart';
import 'package:boostque/features/calendar/planner_screen.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const magnesium = Supplement(
    id: 's1',
    name: 'Магній бісглицинат',
    doseText: '400 мг · капсули',
    colorValue: 0xFF6B6FA8,
    note: '',
  );
  const creatine = Supplement(
    id: 's2',
    name: 'Креатин моногідрат',
    doseText: '5 г',
    colorValue: 0xFF3F7A6A,
    note: '',
  );
  const vitaminD = Supplement(
    id: 's3',
    name: 'Вітамін D3',
    doseText: '2000 МО',
    colorValue: 0xFFB08A2A,
    note: '',
  );

  final today = DateTime.utc(2026, 8, 13);

  late BoostqueDb db;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  /// [stackState] pins `stackEntriesProvider` to a fixed AsyncValue so the
  /// loading and error surfaces can be exercised.
  ///
  /// It is an AsyncValue rather than a list of overrides because Riverpod 3
  /// does not export `Override` as public API — the same shape of gap as
  /// `ProviderListenable`, and the same workaround: type against the concrete
  /// thing instead.
  ProviderContainer makeContainer({
    DateTime? clock,
    AsyncValue<List<StackEntry>>? stackState,
  }) {
    return ProviderContainer(
      overrides: [
        dbProvider.overrideWith((ref) {
          final database = BoostqueDb.forTesting(NativeDatabase.memory());
          ref.onDispose(database.close);
          db = database;
          return database;
        }),
        todayProvider.overrideWith(() => _FixedToday(clock ?? today)),
        // Pins the OTHER sanctioned clock read so the Today page under the
        // planner never depends on what time the suite runs at.
        nowMinutesProvider.overrideWith((ref) => Stream.value(600)),
        if (stackState != null)
          stackEntriesProvider.overrideWith((ref) => stackState),
      ],
    );
  }

  Widget app(ProviderContainer container) {
    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        locale: const Locale('uk'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: bqTheme(),
        home: const CalendarScreen(),
      ),
    );
  }

  /// The planner pumped on its own.
  ///
  /// Legitimate because the screen is navigation-agnostic by design: the tap
  /// path from the Calendar header is proven once, by the tests above, and
  /// every shell assertion below is about the planner itself. It also keeps
  /// the Today page — and its bounded materialization — out of these tests.
  Widget plannerApp(ProviderContainer container, {String locale = 'uk'}) {
    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        locale: Locale(locale),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: bqTheme(),
        home: const PlannerScreen(),
      ),
    );
  }

  /// Finds every widget carrying a `ValueKey<String>` under [prefix].
  ///
  /// Painted primitives — gridlines, the today marker, bars, pips — have no
  /// distinguishing type of their own, so this codebase gives each a keyed
  /// container and finds it by key (the `week-dot` idiom).
  Finder byKeyPrefix(String prefix) => find.byWidgetPredicate((w) {
        final key = w.key;
        return key is ValueKey<String> && key.value.startsWith(prefix);
      });

  void usePhoneSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

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

  Future<void> pumpUntil(
    WidgetTester tester,
    bool Function() condition,
    String what,
  ) async {
    for (var i = 0; i < 200; i++) {
      await tester.pump(const Duration(milliseconds: 10));
      if (condition()) return;
    }
    fail('Timed out waiting for $what');
  }

  Regimen cyclic(String id, String supplementId, {bool paused = false}) =>
      Regimen(
        id: id,
        supplementId: supplementId,
        kind: RegimenKind.cyclic,
        startDate: DateTime.utc(2026, 8, 1),
        endDate: null,
        onDays: 14,
        offDays: 14,
        paused: paused,
        slots: const [
          DoseSlot(id: 'sl-x', minutesFromMidnight: 480, doseLabel: '1 капс.'),
        ],
      );

  /// Two regimen-bearing supplements (one of them paused) plus one fresh
  /// supplement with no regimen at all — so "one row per regimen-bearing
  /// entry" is a real filter, not a tautology.
  /// A one-time course, so the gantt hint's course branch has a real subject.
  final course = Regimen(
    id: 'r3',
    supplementId: 's3',
    kind: RegimenKind.course,
    startDate: DateTime.utc(2026, 8, 5),
    endDate: DateTime.utc(2026, 9, 30),
    onDays: 0,
    offDays: 0,
    paused: false,
    slots: const [
      DoseSlot(id: 'sl-z', minutesFromMidnight: 540, doseLabel: '1 крапля'),
    ],
  );

  /// Seeds one course per start date so the load chart lands a week in every
  /// band at a KNOWN bucket index.
  ///
  /// The window for the pinned 13 August clock runs 1 Aug – 30 Nov, and the
  /// Monday buckets covering it start on 27 July (DECIDED-3). So:
  /// bucket 0 = 27 Jul–2 Aug (nothing has started: load 0),
  /// bucket 1 = 3–9 Aug (load 3), bucket 2 = 10–16 Aug (load 4, and it
  /// contains today), bucket 3 = 17–23 Aug (load 7).
  Future<void> seedBands(
    ProviderContainer container, {
    List<int> startsOnAugust = const [5, 5, 5, 10, 17, 17, 17],
  }) async {
    final supplements = container.read(supplementRepoProvider);
    final regimens = container.read(regimenRepoProvider);
    for (var i = 0; i < startsOnAugust.length; i++) {
      await supplements.upsert(
        Supplement(
          id: 'b$i',
          name: 'Добавка $i',
          doseText: '1 капс.',
          colorValue: 0xFF6B6FA8,
          note: '',
        ),
      );
      await regimens.upsert(
        Regimen(
          id: 'br$i',
          supplementId: 'b$i',
          kind: RegimenKind.course,
          startDate: DateTime.utc(2026, 8, startsOnAugust[i]),
          endDate: DateTime.utc(2026, 11, 30),
          onDays: 0,
          offDays: 0,
          paused: false,
          slots: const [
            DoseSlot(
              id: 'bs',
              minutesFromMidnight: 480,
              doseLabel: '1 капс.',
            ),
          ],
        ),
      );
    }
  }

  Future<void> seed(
    ProviderContainer container, {
    bool courseForVitaminD = false,
  }) async {
    final supplements = container.read(supplementRepoProvider);
    await supplements.upsert(magnesium);
    await supplements.upsert(creatine);
    await supplements.upsert(vitaminD);
    final regimens = container.read(regimenRepoProvider);
    await regimens.upsert(cyclic('r1', 's1'));
    if (courseForVitaminD) await regimens.upsert(course);
    await regimens.upsert(
      Regimen(
        id: 'r2',
        supplementId: 's2',
        kind: RegimenKind.cyclic,
        startDate: DateTime.utc(2026, 8, 1),
        endDate: null,
        onDays: 28,
        offDays: 0,
        paused: true,
        slots: const [
          DoseSlot(id: 'sl-y', minutesFromMidnight: 600, doseLabel: '5 г'),
        ],
      ),
    );
  }

  testWidgets(
      'tapping the Calendar header\'s planner action opens the planner and '
      'draws one gantt row per regimen-bearing entry (DECIDED-1, DECIDED-7)',
      (tester) async {
    usePhoneSurface(tester);
    final container = makeContainer();
    await seed(container);

    await tester.pumpWidget(app(container));
    await pumpUntil(
      tester,
      () => find.text('Планувальник').evaluate().isNotEmpty,
      'the Calendar header entry action',
    );

    // Today's header is what is on screen before the tap.
    expect(find.text('Сьогодні'), findsOneWidget);

    await tester.tap(find.text('Планувальник'));
    await pumpUntil(
      tester,
      () => find.byType(GanttRowBar).evaluate().isNotEmpty,
      'the planner gantt rows',
    );

    expect(find.text('Планувальник'), findsOneWidget,
        reason: 'the planner titles itself with the same key the button used');
    expect(find.byType(GanttRowBar), findsNWidgets(2),
        reason: 'two regimens: one active, one paused — the supplement with '
            'no regimen at all draws no row (DECIDED-7)');
    expect(find.text('Магній бісглицинат'), findsOneWidget);
    expect(find.text('Креатин моногідрат'), findsOneWidget,
        reason: 'a paused regimen keeps its row and shows a bare track');
    expect(find.text('Вітамін D3'), findsNothing);

    await tearDownTree(tester, container);
  });

  testWidgets('the planner\'s back control restores the Today header',
      (tester) async {
    usePhoneSurface(tester);
    final container = makeContainer();
    await seed(container);

    await tester.pumpWidget(app(container));
    await pumpUntil(
      tester,
      () => find.text('Планувальник').evaluate().isNotEmpty,
      'the Calendar header entry action',
    );
    await tester.tap(find.text('Планувальник'));
    await pumpUntil(
      tester,
      () => find.byType(GanttRowBar).evaluate().isNotEmpty,
      'the planner gantt rows',
    );

    // The back control carries the reused `backToToday` copy behind a "‹".
    await tester.tap(find.text('‹ Сьогодні'));
    await pumpUntil(
      tester,
      () => find.byType(GanttRowBar).evaluate().isEmpty,
      'the Today page to come back',
    );

    expect(find.text('Сьогодні'), findsWidgets,
        reason: 'the Today header is back');
    expect(find.byType(GanttRowBar), findsNothing);

    await tearDownTree(tester, container);
  });

  testWidgets('opening the planner writes no IntakeLog row through the UI '
      '(PF-2 / WR-06)', (tester) async {
    usePhoneSurface(tester);
    final container = makeContainer();
    await seed(container);

    await tester.pumpWidget(app(container));
    await pumpUntil(
      tester,
      () => find.text('Планувальник').evaluate().isNotEmpty,
      'the Calendar header entry action',
    );

    // The Today page materializes its own day and the current week — that is
    // Phase 3's bounded, intentional write. Whatever it produced is the
    // baseline the planner must not move.
    var before = 0;
    // Cancelled in-body, never via addTearDown: a Drift subscription's
    // `cancel()` does not settle once the database is closed, so an AWAITED
    // teardown cancel hangs the test until flutter_test's 10-minute timeout.
    final beforeSub = (db.select(db.intakeLogs)).watch().listen((rows) {
      before = rows.length;
    });
    await pumpUntil(tester, () => before > 0, 'the Today page to materialize');
    final baseline = before;

    await tester.tap(find.text('Планувальник'));
    await pumpUntil(
      tester,
      () => find.byType(GanttRowBar).evaluate().isNotEmpty,
      'the planner gantt rows',
    );
    // Give any stray materialization a generous chance to land.
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 10));
    }

    expect(before, baseline,
        reason: 'reaching the planner through the real tap path created no '
            'IntakeLog row (PF-2 / WR-06)');

    beforeSub.cancel();
    await tearDownTree(tester, container);
  });

  // ---------------------------------------------------------------------
  // The shell (plan 04-02, UI-SPEC S6 / S6c, DECIDED-8, Interaction
  // Contracts 1, 2 and 5).
  // ---------------------------------------------------------------------

  /// ONE finder, asserted once per segment — which is what makes DECIDED-8
  /// ("both segments close with the SAME key") the thing actually proven,
  /// rather than two segments each carrying some disclaimer or other.
  final disclaimer = find.text(
    'Межа в 5 речовин — наше редакційне правило для зручності відстеження, '
    'а не медичний норматив. Освітній матеріал, не медична порада.',
  );
  final emptyTitle = find.text('Планувати ще нічого');
  final loadError =
      find.text('Не вдалося завантажити планувальник. Спробуйте ще раз.');

  Future<void> openPlanner(
    WidgetTester tester,
    ProviderContainer container, {
    String locale = 'uk',
  }) async {
    await tester.pumpWidget(plannerApp(container, locale: locale));
    await pumpUntil(
      tester,
      () => find.byType(BqSegmented).evaluate().isNotEmpty,
      'the planner header',
    );
  }

  group('planner shell', () {
    testWidgets('Цикли is the default segment; the subtitle and the body '
        'switch with it, instantly and both ways (S6, Interaction Contract 2)',
        (tester) async {
      usePhoneSurface(tester);
      final container = makeContainer();
      await seed(container);
      await openPlanner(tester, container);
      await pumpUntil(
        tester,
        () => find.byType(GanttRowBar).evaluate().isNotEmpty,
        'the gantt rows',
      );

      // Both segment labels always render (UI-SPEC truth #18).
      expect(find.text('Цикли'), findsOneWidget);
      expect(find.text('Рік'), findsOneWidget);
      // The window subtitle, pinned exactly: uk standalone (nominative) month
      // names for the Aug-Nov window around the pinned clock (PF-4).
      expect(find.text('серпень — листопад 2026'), findsOneWidget);
      expect(find.byType(GanttRowBar), findsWidgets,
          reason: 'Цикли is the default segment (index 1)');

      await tester.tap(find.text('Рік'));
      await tester.pump();

      expect(find.text('2026 · 12 місяців'), findsOneWidget,
          reason: 'the Рік subtitle names the year and a pre-formatted month '
              'count');
      expect(find.text('серпень — листопад 2026'), findsNothing);
      expect(find.byType(GanttRowBar), findsNothing,
          reason: 'the Цикли body is gone, not merely covered');

      await tester.tap(find.text('Цикли'));
      await tester.pump();

      expect(find.text('серпень — листопад 2026'), findsOneWidget);
      expect(find.byType(GanttRowBar), findsWidgets);

      await tearDownTree(tester, container);
    });

    testWidgets('a window crossing 31 December renders the cross-year '
        'subtitle with BOTH years (E-8)', (tester) async {
      usePhoneSurface(tester);
      final container = makeContainer(clock: DateTime.utc(2026, 10, 15));
      await seed(container);
      await openPlanner(tester, container);

      expect(find.text('жовтень 2026 — січень 2027'), findsOneWidget);
      // The Рік matrix stays on today's year while the window has already
      // crossed into the next one (DECIDED-9).
      await tester.tap(find.text('Рік'));
      await tester.pump();
      expect(find.text('2026 · 12 місяців'), findsOneWidget);

      await tearDownTree(tester, container);
    });

    testWidgets('the disclaimer closes BOTH segments — the same key, one '
        'finder (DECIDED-8, PLAN-04)', (tester) async {
      usePhoneSurface(tester);
      final container = makeContainer();
      await seed(container);
      await openPlanner(tester, container);
      await pumpUntil(
        tester,
        () => find.byType(GanttRowBar).evaluate().isNotEmpty,
        'the gantt rows',
      );

      expect(disclaimer, findsOneWidget, reason: 'Цикли closes with it');

      await tester.tap(find.text('Рік'));
      await tester.pump();

      expect(disclaimer, findsOneWidget, reason: 'Рік closes with it too');
      expect(
        find.text('Рік показує, як цикли накладаються один на одний. '
            'Червоне число в місяці означає перевищення нашої межі у '
            '5 речовин одночасно.'),
        findsOneWidget,
        reason: 'the year footnote renders ABOVE the disclaimer, never '
            'instead of it (M9)',
      );

      await tearDownTree(tester, container);
    });

    testWidgets('an empty stack renders the empty block with the '
        'no-supplements body on both segments, and still the disclaimer '
        '(S6c, PLAN-04 is unconditional)', (tester) async {
      usePhoneSurface(tester);
      final container = makeContainer();
      await openPlanner(tester, container);
      await pumpUntil(
        tester,
        () => emptyTitle.evaluate().isNotEmpty,
        'the empty planner block',
      );

      expect(
        find.text('Додайте добавку у вкладці «Стек» — її цикли '
            'з\'являться тут.'),
        findsOneWidget,
      );
      expect(find.byType(GanttRowBar), findsNothing);
      expect(disclaimer, findsOneWidget);

      await tester.tap(find.text('Рік'));
      await tester.pump();

      expect(emptyTitle, findsOneWidget);
      expect(disclaimer, findsOneWidget);

      await tearDownTree(tester, container);
    });

    testWidgets('supplements that all lack a regimen render the OTHER empty '
        'body — a user who owns supplements is never told to add one '
        '(DECIDED-7)', (tester) async {
      usePhoneSurface(tester);
      final container = makeContainer();
      final supplements = container.read(supplementRepoProvider);
      await supplements.upsert(magnesium);
      await supplements.upsert(creatine);

      await openPlanner(tester, container);
      await pumpUntil(
        tester,
        () => emptyTitle.evaluate().isNotEmpty,
        'the empty planner block',
      );

      expect(
        find.text('У ваших добавок ще немає розкладу. Відкрийте добавку у '
            'вкладці «Стек», щоб задати цикл.'),
        findsOneWidget,
      );
      expect(
        find.text('Додайте добавку у вкладці «Стек» — її цикли '
            'з\'являться тут.'),
        findsNothing,
      );
      expect(disclaimer, findsOneWidget);

      await tearDownTree(tester, container);
    });

    testWidgets('a failing stack stream renders the designed error copy plus '
        'retry, and never the exception (S6c, T-04-09)', (tester) async {
      usePhoneSurface(tester);
      final container = makeContainer(
        stackState: AsyncError(
          Exception('boom-from-drift'),
          StackTrace.empty,
        ),
      );
      await openPlanner(tester, container);

      expect(loadError, findsOneWidget);
      expect(find.text('Повторити'), findsOneWidget);
      expect(find.textContaining('boom-from-drift'), findsNothing,
          reason: 'raw exception text never enters the widget tree');
      expect(find.textContaining('Exception'), findsNothing);
      expect(disclaimer, findsOneWidget,
          reason: 'PLAN-04 is unconditional — it closes the error surface too');

      await tester.tap(find.text('Рік'));
      await tester.pump();

      expect(loadError, findsOneWidget);
      expect(disclaimer, findsOneWidget);

      await tearDownTree(tester, container);
    });

    testWidgets('while the stack is loading the header and segmented control '
        'render over an empty body with NO spinner (S6c)', (tester) async {
      usePhoneSurface(tester);
      final container = makeContainer(
        stackState: const AsyncLoading(),
      );
      await openPlanner(tester, container);

      expect(find.text('Планувальник'), findsOneWidget);
      expect(find.byType(BqSegmented), findsOneWidget);
      expect(find.text('серпень — листопад 2026'), findsOneWidget,
          reason: 'the subtitle is clock-derived and never waits on the stack');
      expect(find.byType(CircularProgressIndicator), findsNothing,
          reason: 'a local-DB stream resolves within a frame; a spinner would '
              'only flash');
      expect(find.byType(GanttRowBar), findsNothing);
      expect(emptyTitle, findsNothing,
          reason: 'until the stack resolves the planner assumes it has '
              'entries — the empty block must never flash on the way to data');

      await tearDownTree(tester, container);
    });

    testWidgets('a week selected on Цикли survives a switch to Рік and back '
        '(Interaction Contract 2)', (tester) async {
      usePhoneSurface(tester);
      final container = makeContainer();
      await seed(container);
      // Riverpod 3 pauses providers nobody listens to; this subscription is
      // what keeps the screen-scoped selection alive for the assertion, and
      // stands in for the week column plan 04-03 will add.
      final sub = container.listen(resolvedWeekIndexProvider, (_, _) {});
      addTearDown(sub.close);

      await openPlanner(tester, container);
      await pumpUntil(
        tester,
        () => find.byType(GanttRowBar).evaluate().isNotEmpty,
        'the gantt rows',
      );

      container.read(selectedWeekProvider.notifier).select(3);
      await tester.pump();
      expect(container.read(resolvedWeekIndexProvider), 3);

      await tester.tap(find.text('Рік'));
      await tester.pump();
      await tester.tap(find.text('Цикли'));
      await tester.pump();

      expect(container.read(resolvedWeekIndexProvider), 3,
          reason: 'the segment index chooses which body builds and nothing '
              'else — selection state lives in its own provider');

      await tearDownTree(tester, container);
    });
  });

  // ---------------------------------------------------------------------
  // The gantt row hint (plan 04-02 task 3, M13).
  // ---------------------------------------------------------------------

  group('gantt row hint', () {
    testWidgets('reads the Stack card\'s own schedule description, minus the '
        'daily-slot tail (M13)', (tester) async {
      usePhoneSurface(tester);
      final container = makeContainer();
      await seed(container, courseForVitaminD: true);
      await openPlanner(tester, container);
      await pumpUntil(
        tester,
        () => find.byType(GanttRowBar).evaluate().isNotEmpty,
        'the gantt rows',
      );

      // Cyclic with a break: the same "on / off" composition the Stack chip
      // renders, in the same words.
      expect(find.text('2 тижні / 2 тижні'), findsOneWidget);
      // Cyclic with no break: the no-break wording, never "0 тижнів".
      expect(find.text('4 тижні / без перерви'), findsOneWidget);
      expect(find.textContaining('0 тижнів'), findsNothing);
      // Course: the locale-formatted inclusive range.
      final range = DateFormat.yMd('uk');
      expect(
        find.text('${range.format(DateTime.utc(2026, 8, 5))} – '
            '${range.format(DateTime.utc(2026, 9, 30))}'),
        findsOneWidget,
      );
      // The planner is about time, not daily doses: the slot tail the Stack
      // card appends is absent from every hint.
      expect(find.textContaining('раз на день'), findsNothing);
      expect(find.textContaining('рази на день'), findsNothing);

      await tearDownTree(tester, container);
    });

    testWidgets('each row speaks its name, its schedule and its run count — '
        'the painted bands are invisible to assistive tech', (tester) async {
      usePhoneSurface(tester);
      final handle = tester.ensureSemantics();
      final container = makeContainer();
      await seed(container);
      await openPlanner(tester, container);
      await pumpUntil(
        tester,
        () => find.byType(GanttRowBar).evaluate().isNotEmpty,
        'the gantt rows',
      );

      final label = tester.getSemantics(find.byType(GanttRowBar).first).label;
      expect(label, startsWith('Магній бісглицинат, 2 тижні / 2 тижні, '),
          reason: 'name, then the shared schedule description');
      expect(label, endsWith('періодів'),
          reason: 'closing with a pre-formatted periodsCount — the count of '
              'painted runs is the information the canvas carries');

      // A paused regimen paints nothing, and says so honestly rather than
      // claiming a period it does not have.
      final paused = tester.getSemantics(find.byType(GanttRowBar).at(1)).label;
      expect(paused, startsWith('Креатин моногідрат, 4 тижні / без перерви, '));
      expect(paused, endsWith('0 періодів'));

      handle.dispose();
      await tearDownTree(tester, container);
    });
  });

  // ---------------------------------------------------------------------
  // The gantt chrome (plan 04-03 task 1, UI-SPEC S6a item 2, P-4/P-8,
  // PF-3, M1, Interaction Contract 12).
  // ---------------------------------------------------------------------

  group('gantt chrome', () {
    testWidgets('four standalone uk month abbreviations render in window '
        'order, uppercased (PF-4)', (tester) async {
      usePhoneSurface(tester);
      final container = makeContainer();
      await seed(container);
      await openPlanner(tester, container);
      await pumpUntil(
        tester,
        () => find.byType(GanttRowBar).evaluate().isNotEmpty,
        'the gantt rows',
      );

      // The Aug-Nov window around the pinned clock, in the STANDALONE
      // (nominative) abbreviated forms — `LLL`, never `MMM` and never a table.
      expect(find.text('СЕРП.'), findsOneWidget);
      expect(find.text('ВЕР.'), findsOneWidget);
      expect(find.text('ЖОВТ.'), findsOneWidget);
      expect(find.text('ЛИСТ.'), findsOneWidget);
      expect(byKeyPrefix('gantt-month-'), findsNWidgets(4));

      // Window order, read off the keyed slots rather than the tree order.
      for (final (index, label) in <(int, String)>[
        (0, 'СЕРП.'),
        (1, 'ВЕР.'),
        (2, 'ЖОВТ.'),
        (3, 'ЛИСТ.'),
      ]) {
        expect(
          tester.widget<Text>(find.byKey(ValueKey('gantt-month-$index'))).data,
          label,
        );
      }

      await tearDownTree(tester, container);
    });

    testWidgets('month columns are sized to REAL day counts — a 31-day month '
        'is wider than a 30-day one (PF-3, T-04-11)', (tester) async {
      usePhoneSurface(tester);
      final container = makeContainer();
      await seed(container);
      await openPlanner(tester, container);
      await pumpUntil(
        tester,
        () => find.byType(GanttRowBar).evaluate().isNotEmpty,
        'the gantt rows',
      );

      final august =
          tester.getSize(find.byKey(const ValueKey('gantt-month-0'))).width;
      final september =
          tester.getSize(find.byKey(const ValueKey('gantt-month-1'))).width;
      final october =
          tester.getSize(find.byKey(const ValueKey('gantt-month-2'))).width;

      expect(august, greaterThan(september),
          reason: 'August has 31 days and September 30 — fixed quarter '
              'columns would make these equal');
      expect(october, closeTo(august, 0.01),
          reason: 'October is also 31 days');

      await tearDownTree(tester, container);
    });

    testWidgets('three gridlines sit at the interior month boundaries and '
        'exactly one today marker renders (P-4)', (tester) async {
      usePhoneSurface(tester);
      final container = makeContainer();
      await seed(container);
      await openPlanner(tester, container);
      await pumpUntil(
        tester,
        () => find.byType(GanttRowBar).evaluate().isNotEmpty,
        'the gantt rows',
      );

      expect(byKeyPrefix('gantt-gridline-'), findsNWidgets(3),
          reason: 'a four-month window has three interior boundaries');
      expect(find.byKey(const ValueKey('gantt-today-marker')), findsOneWidget,
          reason: 'today is inside the window by construction, so the marker '
              'always renders — there is no absent branch');

      // The boundaries sit at the cumulative REAL day fractions of a 122-day
      // window — 31/122, 61/122, 92/122 — never at 0.25 / 0.50 / 0.75.
      final track = tester.getRect(find.byType(GanttRowBar).first);
      double fractionOf(int i) =>
          (tester.getRect(byKeyPrefix('gantt-gridline-').at(i)).left -
              track.left) /
          track.width;
      expect(fractionOf(0), closeTo(31 / 122, 0.002));
      expect(fractionOf(1), closeTo(61 / 122, 0.002));
      expect(fractionOf(2), closeTo(92 / 122, 0.002));
      // 31/122 is 0.2541, not 0.25 — the middle boundary happens to land on
      // 0.5 for THIS window (31 + 30 = 61 of 122), which is exactly why the
      // outer two are the ones that prove the columns are not quarters.
      expect(fractionOf(0), isNot(closeTo(0.25, 0.002)));
      expect(fractionOf(2), isNot(closeTo(0.75, 0.002)));

      // (todayIndex + 0.5) / span for the pinned 13 August clock.
      final marker = tester.getRect(find.byKey(const ValueKey(
        'gantt-today-marker',
      )));
      expect((marker.left - track.left) / track.width,
          closeTo(12.5 / 122, 0.002));
      expect(marker.height, greaterThan(0),
          reason: 'the rules span the full height of the row stack');

      await tearDownTree(tester, container);
    });

    testWidgets('the legend renders exactly three entries in BOTH locales — '
        'the mockup\'s interaction entry does not ship (M1)', (tester) async {
      usePhoneSurface(tester);
      final container = makeContainer();
      await seed(container);
      await openPlanner(tester, container);
      await pumpUntil(
        tester,
        () => find.byType(GanttRowBar).evaluate().isNotEmpty,
        'the gantt rows',
      );

      expect(byKeyPrefix('gantt-legend-'), findsNWidgets(3));
      expect(find.text('приймаю'), findsOneWidget);
      expect(find.text('заплановано'), findsOneWidget);
      expect(find.text('пауза'), findsOneWidget);
      expect(find.text('є взаємодія'), findsNothing,
          reason: 'an interaction claim this product does not make');

      await tearDownTree(tester, container);
    });

    testWidgets('the legend still renders exactly three entries in en',
        (tester) async {
      usePhoneSurface(tester);
      final container = makeContainer();
      await seed(container);
      await openPlanner(tester, container, locale: 'en');
      await pumpUntil(
        tester,
        () => find.byType(GanttRowBar).evaluate().isNotEmpty,
        'the gantt rows',
      );

      expect(byKeyPrefix('gantt-legend-'), findsNWidgets(3));
      expect(find.text('taking'), findsOneWidget);
      expect(find.text('planned'), findsOneWidget);
      expect(find.text('paused'), findsOneWidget);
      expect(find.textContaining('interaction'), findsNothing);

      await tearDownTree(tester, container);
    });

    testWidgets('changing the selected week does not rebuild the gantt '
        '(Interaction Contract 12)', (tester) async {
      usePhoneSurface(tester);
      final container = makeContainer();
      await seed(container);
      final sub = container.listen(resolvedWeekIndexProvider, (_, _) {});
      addTearDown(sub.close);

      await openPlanner(tester, container);
      await pumpUntil(
        tester,
        () => find.byType(GanttRowBar).evaluate().isNotEmpty,
        'the gantt rows',
      );

      Finder painted() => find.descendant(
            of: find.byType(GanttRowBar).first,
            matching: find.byType(CustomPaint),
          );
      final before = tester.widget<CustomPaint>(painted());
      expect(
        find.descendant(
          of: find.byType(PlannerGantt),
          matching: find.byType(RepaintBoundary),
        ),
        findsWidgets,
        reason: 'the card is isolated behind its own boundary',
      );

      container.read(selectedWeekProvider.notifier).select(4);
      await tester.pump();
      expect(container.read(resolvedWeekIndexProvider), 4);

      expect(identical(tester.widget<CustomPaint>(painted()), before), isTrue,
          reason: 'the gantt subtree did not even rebuild, so it cannot have '
              'repainted — selection lives in a provider the gantt never '
              'watches');

      await tearDownTree(tester, container);
    });
  });

  // ---------------------------------------------------------------------
  // The concurrent-load chart (plan 04-03 task 2, UI-SPEC S6a item 3,
  // P-9, DECIDED-2/3/10, Interaction Contracts 3, 5, 11).
  // ---------------------------------------------------------------------

  group('load chart', () {
    Future<void> openBands(
      WidgetTester tester,
      ProviderContainer container, {
      List<int> startsOnAugust = const [5, 5, 5, 10, 17, 17, 17],
    }) async {
      await seedBands(container, startsOnAugust: startsOnAugust);
      await openPlanner(tester, container);
      await pumpUntil(
        tester,
        () => byKeyPrefix('load-week-').evaluate().isNotEmpty,
        'the load chart columns',
      );
    }

    Color? fillOf(WidgetTester tester, String key) {
      final box = tester.widget<Container>(find.byKey(ValueKey<String>(key)));
      return (box.decoration! as BoxDecoration).color;
    }

    testWidgets('one column per Monday week of the window — 18 or 19 of them '
        '(DECIDED-3)', (tester) async {
      usePhoneSurface(tester);
      final container = makeContainer();
      await openBands(tester, container);

      final model = container.read(cyclesModelProvider).value!;
      expect(byKeyPrefix('load-week-'), findsNWidgets(model.weeks.length));
      expect(model.weeks.length, anyOf(18, 19),
          reason: 'full Monday weeks covering a 120-123 day window');

      // The axis carries the ACTUAL bucket bounds, never the mockup's
      // hardcoded "1 серп" / "30 лис" (M6).
      expect(find.text('ОДНОЧАСНЕ НАВАНТАЖЕННЯ'), findsOneWidget);
      expect(find.text('по тижнях'), findsOneWidget);
      expect(find.text('межа 5 · комфорт 3'), findsOneWidget);
      final axis = DateFormat.MMMd('uk');
      expect(find.text(axis.format(model.weeks.first.bucket.start)),
          findsOneWidget);
      expect(find.text(axis.format(model.weeks.last.bucket.endInclusive)),
          findsOneWidget);
      expect(find.text('1 серп.'), findsNothing);

      await tearDownTree(tester, container);
    });

    testWidgets('every band draws its own bar: comfort, at the limit, and a '
        'capped main bar with a proportional over-bar (UI-SPEC banding)',
        (tester) async {
      usePhoneSurface(tester);
      final container = makeContainer();
      await openBands(tester, container);

      // Bucket 1 — load 3: the quiet comfort tone, round(3/5*38) = 23.
      expect(fillOf(tester, 'load-main-1'), BqColors.loadBar);
      expect(tester.getSize(find.byKey(const ValueKey('load-main-1'))).height,
          23);
      expect(find.byKey(const ValueKey('load-over-1')), findsNothing);

      // Bucket 2 — load 4: at our editorial limit, round(4/5*38) = 30.
      expect(fillOf(tester, 'load-main-2'), BqColors.warn);
      expect(tester.getSize(find.byKey(const ValueKey('load-main-2'))).height,
          30);

      // Bucket 3 — load 7: the main bar caps at 38 and the excess becomes a
      // proportional over-bar, round(2/5*38) = 15.
      expect(fillOf(tester, 'load-main-3'), BqColors.risk);
      expect(tester.getSize(find.byKey(const ValueKey('load-main-3'))).height,
          38);
      expect(fillOf(tester, 'load-over-3'), BqColors.risk);
      expect(tester.getSize(find.byKey(const ValueKey('load-over-3'))).height,
          15);

      await tearDownTree(tester, container);
    });

    testWidgets('a zero-load week draws the 2px stub and stays selectable '
        '(DECIDED-3, M8)', (tester) async {
      usePhoneSurface(tester);
      final container = makeContainer();
      await openBands(tester, container);

      expect(fillOf(tester, 'load-stub-0'), BqColors.field);
      expect(tester.getSize(find.byKey(const ValueKey('load-stub-0'))).height,
          2);
      expect(find.byKey(const ValueKey('load-main-0')), findsNothing,
          reason: 'the stub stands IN PLACE of a zero-height bar');

      expect(container.read(resolvedWeekIndexProvider), 2,
          reason: 'the default follows the bucket containing today');
      await tester.tap(find.byKey(const ValueKey('load-week-0')));
      await tester.pump();
      expect(container.read(resolvedWeekIndexProvider), 0);

      await tearDownTree(tester, container);
    });

    testWidgets('the WHOLE column is the tap target — a hit well above a '
        'short bar still selects the week (DECIDED-10)', (tester) async {
      usePhoneSurface(tester);
      final container = makeContainer();
      await openBands(tester, container);

      final column = tester.getRect(find.byKey(const ValueKey('load-week-5')));
      expect(column.height, greaterThanOrEqualTo(53),
          reason: 'a ~15px wide column earns its target from its HEIGHT');

      // Two pixels below the column's top edge is empty space above every bar
      // in this chart — the bar itself is at most 38px of a 53px column.
      await tester.tapAt(Offset(column.center.dx, column.top + 2));
      await tester.pump();

      expect(container.read(resolvedWeekIndexProvider), 5);

      await tearDownTree(tester, container);
    });

    testWidgets('the selected column is opaque and every other is half '
        '(Interaction Contract 3)', (tester) async {
      usePhoneSurface(tester);
      final container = makeContainer();
      await openBands(tester, container);

      double opacityOf(int i) => tester
          .widget<Opacity>(
            find.descendant(
              of: find.byKey(ValueKey<String>('load-week-$i')),
              matching: find.byType(Opacity),
            ),
          )
          .opacity;

      expect(opacityOf(2), 1.0, reason: 'today\'s week is the default');
      expect(opacityOf(3), 0.5);

      await tester.tap(find.byKey(const ValueKey('load-week-3')));
      await tester.pump();

      expect(opacityOf(3), 1.0);
      expect(opacityOf(2), 0.5);
      // Selection is the feedback; no ripple (Interaction Contract 11).
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('load-week-3')),
          matching: find.byType(InkWell),
        ),
        findsNothing,
      );

      await tearDownTree(tester, container);
    });

    testWidgets('each column carries its own button, selected state and tap '
        'action, labelled with the week and its load (WR-02)', (tester) async {
      usePhoneSurface(tester);
      final handle = tester.ensureSemantics();
      final container = makeContainer();
      await openBands(tester, container);

      final node = tester.getSemantics(
        find.byKey(const ValueKey('load-week-2')),
      );
      expect(node.label, contains('4 з 5 слотів'),
          reason: 'a pre-formatted weekLoadLabel inside weekBarSemantics');
      expect(node.label, contains('серп.'), reason: 'the week range');
      expect(
        find.byKey(const ValueKey('load-week-2')),
        containsSemantics(
          isButton: true,
          isSelected: true,
          hasTapAction: true,
        ),
      );
      expect(
        find.byKey(const ValueKey('load-week-4')),
        containsSemantics(
          isButton: true,
          isSelected: false,
          hasTapAction: true,
        ),
      );

      handle.dispose();
      await tearDownTree(tester, container);
    });

    testWidgets('exactly one dashed reference line renders, at the comfort '
        'height (DECIDED-2)', (tester) async {
      usePhoneSurface(tester);
      final container = makeContainer();
      await openBands(tester, container);

      expect(find.byKey(const ValueKey('load-threshold')), findsOneWidget,
          reason: 'the 5 limit is drawn structurally, as the cap of the main '
              'bar — a second line there would be redundant chrome');

      // 22.8px above the chart baseline, which is the bottom of a column.
      final line = tester.getRect(find.byKey(const ValueKey('load-threshold')));
      final column = tester.getRect(find.byKey(const ValueKey('load-week-0')));
      expect(column.bottom - line.top, closeTo(22.8, 0.6));

      await tearDownTree(tester, container);
    });

    testWidgets('selecting a week writes nothing (Interaction Contract 5, '
        'T-04-01)', (tester) async {
      usePhoneSurface(tester);
      final container = makeContainer();
      await openBands(tester, container);

      final before = (await db.select(db.intakeLogs).get()).length;
      await tester.tap(find.byKey(const ValueKey('load-week-7')));
      await tester.pump();
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 10));
      }

      expect(container.read(resolvedWeekIndexProvider), 7);
      expect((await db.select(db.intakeLogs).get()).length, before,
          reason: 'the one gesture this screen has materializes no row');

      await tearDownTree(tester, container);
    });

    testWidgets('the summary chip names this week\'s load and bands at OR '
        'above the limit (DECIDED-6)', (tester) async {
      usePhoneSurface(tester);
      final container = makeContainer();
      await openBands(tester, container);

      expect(find.text('Цього тижня одночасно 4 речовини'), findsOneWidget);
      expect(find.text('межа 5'), findsOneWidget);
      expect(fillOf(tester, 'cycles-summary-chip'), BqColors.calmBg,
          reason: 'a load of 4 is still below the limit');

      await tearDownTree(tester, container);
    });

    testWidgets('a this-week load AT the limit turns the summary chip amber '
        '(DECIDED-6)', (tester) async {
      usePhoneSurface(tester);
      final container = makeContainer();
      await openBands(tester, container, startsOnAugust: const [1, 1, 1, 1, 1]);

      expect(find.text('Цього тижня одночасно 5 речовин'), findsOneWidget);
      expect(fillOf(tester, 'cycles-summary-chip'), BqColors.warnBg,
          reason: 'the WEEK chip nudges AT the limit — the year peak chip '
              'deliberately does not (DECIDED-6)');

      await tearDownTree(tester, container);
    });
  });
}

/// Pins `todayProvider` to a fixed calendar day.
class _FixedToday extends TodayController {
  _FixedToday(this.day);

  final DateTime day;

  @override
  DateTime build() => day;
}
