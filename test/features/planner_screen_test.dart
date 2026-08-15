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
      expect(fractionOf(1), isNot(closeTo(0.5, 0.002)),
          reason: 'an even-quarter layout would land the middle rule at 0.5');

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
}

/// Pins `todayProvider` to a fixed calendar day.
class _FixedToday extends TodayController {
  _FixedToday(this.day);

  final DateTime day;

  @override
  DateTime build() => day;
}
