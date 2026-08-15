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
import 'package:boostque/core/providers.dart';
import 'package:boostque/core/theme/theme.dart';
import 'package:boostque/core/today_controller.dart';
import 'package:boostque/features/calendar/calendar_providers.dart';
import 'package:boostque/features/calendar/calendar_screen.dart';
import 'package:boostque/features/calendar/planner_gantt.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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

  ProviderContainer makeContainer() {
    return ProviderContainer(
      overrides: [
        dbProvider.overrideWith((ref) {
          final database = BoostqueDb.forTesting(NativeDatabase.memory());
          ref.onDispose(database.close);
          db = database;
          return database;
        }),
        todayProvider.overrideWith(() => _FixedToday(today)),
        // Pins the OTHER sanctioned clock read so the Today page under the
        // planner never depends on what time the suite runs at.
        nowMinutesProvider.overrideWith((ref) => Stream.value(600)),
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
  Future<void> seed(ProviderContainer container) async {
    final supplements = container.read(supplementRepoProvider);
    await supplements.upsert(magnesium);
    await supplements.upsert(creatine);
    await supplements.upsert(vitaminD);
    final regimens = container.read(regimenRepoProvider);
    await regimens.upsert(cyclic('r1', 's1'));
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
}

/// Pins `todayProvider` to a fixed calendar day.
class _FixedToday extends TodayController {
  _FixedToday(this.day);

  final DateTime day;

  @override
  DateTime build() => day;
}
