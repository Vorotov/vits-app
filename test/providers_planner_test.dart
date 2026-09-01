/// Provider-layer proofs for the planner (plan 04-01, T-04-01, PF-2).
///
/// Container harness copied from test/providers_calendar_test.dart:
/// [dbProvider] is overridden with an in-memory database (D-19) and seeding
/// goes through the repository providers read off the SAME container, so
/// production code paths are exercised.
///
/// Riverpod 3 pauses unlistened providers, so every provider under test is
/// held open with `container.listen(...)` before its value is polled.
///
/// The row-count test below is this phase's defining regression. Phase 3 shipped
/// WR-06 — a 4px dot that materialized up to ~371 days of `IntakeLog` rows
/// because it read through the materializing provider — and at planner scale
/// the same mistake is an order of magnitude worse. The gate is a COUNT, not a
/// code review: the planner may not create a single row, and the assertion
/// fails the instant a materializing import sneaks back in.
library;

import 'package:boostque/core/db/database.dart' show BoostqueDb, IntakeLog;
import 'package:boostque/core/domain/models.dart';
import 'package:boostque/core/providers.dart';
import 'package:boostque/core/today_controller.dart';
import 'package:boostque/features/calendar/planner_providers.dart';
import 'package:boostque/features/calendar/planner_view_model.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // TodayController is overridden below, but the binding is still what makes a
  // widget-free test safe to run against provider code that can reach
  // framework services.
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;
  late BoostqueDb db;

  final today = DateTime.utc(2026, 8, 13);

  setUp(() {
    container = ProviderContainer(
      overrides: [
        dbProvider.overrideWith((ref) {
          final database = BoostqueDb.forTesting(NativeDatabase.memory());
          ref.onDispose(database.close);
          db = database;
          return database;
        }),
        // Pins the app's single clock so the window, and therefore every
        // assertion below, is the same on any machine on any day.
        todayProvider.overrideWith(() => _FixedToday(today)),
      ],
    );
  });

  tearDown(() => container.dispose());

  const magnesium = Supplement(
    id: 's1',
    name: 'Магній',
    doseText: '400 мг',
    colorValue: 0xFF6B6FA8,
    note: '',
  );
  const creatine = Supplement(
    id: 's2',
    name: 'Креатин',
    doseText: '5 г',
    colorValue: 0xFF3F7A6A,
    note: '',
  );

  /// A 14-on/14-off cycle starting on 1 August, with one 08:00 slot so the
  /// materializing path has something real to create.
  ///
  /// The start date stays where it is even though the window moved back a
  /// month (owner change 2026-09-01, so the band now opens on 1 July): what
  /// this file needs from it is that the pinned 13 August clock falls on an ON
  /// day, which is what lets `materializeOneDay` create the rows the PF-2 gate
  /// counts. Backdating it to the new window start would put 13 August in the
  /// cycle's first OFF phase and the gate would compare two zeros.
  Regimen cyclicR1({bool paused = false}) => Regimen(
        id: 'r1',
        supplementId: 's1',
        kind: RegimenKind.cyclic,
        startDate: DateTime.utc(2026, 8, 1),
        endDate: null,
        onDays: 14,
        offDays: 14,
        paused: paused,
        slots: const [
          DoseSlot(id: 'sl1', minutesFromMidnight: 480, doseLabel: '400 мг'),
        ],
      );

  Regimen pausedR2() => Regimen(
        id: 'r2',
        supplementId: 's2',
        kind: RegimenKind.cyclic,
        startDate: DateTime.utc(2026, 8, 1),
        endDate: null,
        onDays: 28,
        offDays: 0,
        paused: true,
        slots: const [
          DoseSlot(id: 'sl2', minutesFromMidnight: 600, doseLabel: '5 г'),
        ],
      );

  Future<List<IntakeLog>> rawLogs() => db.select(db.intakeLogs).get();

  Future<void> seed() async {
    final supplements = container.read(supplementRepoProvider);
    await supplements.upsert(magnesium);
    await supplements.upsert(creatine);
    final regimens = container.read(regimenRepoProvider);
    await regimens.upsert(cyclicR1());
    await regimens.upsert(pausedR2());
  }

  /// Holds [provider] open (Riverpod 3 pauses unlistened providers) and polls
  /// until it carries data.
  Future<T> resolve<T>(Provider<AsyncValue<T>> provider) async {
    final sub = container.listen(provider, (_, _) {});
    addTearDown(sub.close);
    for (var i = 0; i < 200; i++) {
      final value = container.read(provider);
      if (value case AsyncData(value: final data)) return data;
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    fail('$provider never resolved — last value: ${container.read(provider)}');
  }

  /// Materializes one real day through the app's only materializing path, so
  /// the row-count gate below compares a NON-ZERO count rather than two zeros.
  Future<void> materializeOneDay(DateTime day) async {
    final sub = container.listen(dayDosesProvider(day), (_, _) {});
    addTearDown(sub.close);
    for (var i = 0; i < 200; i++) {
      if ((await rawLogs()).isNotEmpty) return;
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    fail('the day never materialized — the gate below would prove nothing');
  }

  test('the Cycles model carries one row per regimen-bearing entry, in stack '
      'order, with the paused row kept and empty (DECIDED-7)', () async {
    await seed();

    final model = await resolve(cyclesModelProvider);

    expect(model.rows, hasLength(2));
    expect(model.rows[0].entry.supplement.id, 's1');
    expect(model.rows[1].entry.supplement.id, 's2');
    expect(model.rows[0].segments, isNotEmpty);
    expect(model.rows[1].segments, isEmpty,
        reason: 'a paused regimen keeps its row and renders a bare track');
    expect(model.span, 123,
        reason: 'Jul..Oct 2026 = 31+31+30+31. The owner\'s 2026-09-01 shift '
            'moved the band back a month, so the number the provider hands '
            'the screen is no longer the mockup\'s Aug..Nov 122 (P-4)');
  });

  test('resolving the Cycles model creates NO IntakeLog rows (PF-2 / the '
      'WR-06 lesson)', () async {
    await seed();
    await materializeOneDay(today);

    final before = await rawLogs();
    expect(before, isNotEmpty,
        reason: 'the gate must compare a real count, not two zeros');

    final model = await resolve(cyclesModelProvider);
    expect(model.rows, isNotEmpty);

    final after = await rawLogs();
    expect(after.length, before.length,
        reason: 'the planner is a projection — it must never materialize a '
            'single IntakeLog row (PF-2 / WR-06)');
    expect(after.map((r) => r.id), before.map((r) => r.id),
        reason: 'not one row was added, removed or replaced');
  });

  test('following today resolves to the model\'s OWN currentWeekIndex — one '
      'derivation, not two searches (WR-02)', () async {
    await seed();

    final model = await resolve(cyclesModelProvider);
    final sub = container.listen(resolvedWeekIndexProvider, (_, _) {});
    addTearDown(sub.close);

    expect(container.read(resolvedWeekIndexProvider), model.currentWeekIndex,
        reason: 'the week detail follows today by reading the model, and the '
            'summary chip reads the same field — two copies of the same '
            'search can silently disagree, and one of them used to fall back '
            'to a load of 0 rather than to a real bucket');
    final bucket = model.weeks[model.currentWeekIndex].bucket;
    expect(bucket.start.isAfter(today), isFalse);
    expect(bucket.endInclusive.isBefore(today), isFalse);
  });

  group('selections survive a window shift by IDENTITY, never by position '
      '(WR-03)', () {
    late _MovableToday clock;

    setUp(() {
      container.dispose();
      container = ProviderContainer(
        overrides: [
          dbProvider.overrideWith((ref) {
            final database = BoostqueDb.forTesting(NativeDatabase.memory());
            ref.onDispose(database.close);
            db = database;
            return database;
          }),
          todayProvider.overrideWith(() {
            clock = _MovableToday(today);
            return clock;
          }),
        ],
      );
    });

    test('a picked week keeps describing the SAME seven days after the window '
        'slides forward a month', () async {
      await seed();
      final before = await resolve(cyclesModelProvider);
      final sub = container.listen(resolvedWeekIndexProvider, (_, _) {});
      addTearDown(sub.close);
      final weekSub = container.listen(selectedWeekProvider, (_, _) {});
      addTearDown(weekSub.close);

      // A week deep enough into the window to still exist after the shift.
      final picked = before.weeks[7].bucket.start;
      container.read(selectedWeekProvider.notifier).select(picked);
      expect(container.read(resolvedWeekIndexProvider), 7);

      // Midnight on the first of the next month: the window slides forward and
      // every bucket index shifts by roughly four weeks.
      clock.jumpTo(DateTime.utc(2026, 9, 1));
      final after = await resolve(cyclesModelProvider);
      final index = container.read(resolvedWeekIndexProvider);

      expect(after.weeks[index].bucket.start, picked,
          reason: 'the user picked a WEEK, not a slot in a list. A bare index '
              'would still be in range and would silently start describing a '
              'different week — the week-detail card changing what it is '
              'about with nobody touching it');
      expect(index, isNot(7),
          reason: 'the same week now sits at a different index, which is '
              'exactly why the index could not be the thing stored');
    });

    test('a picked week that the new window no longer contains falls back to '
        'following today, not to a neighbour', () async {
      await seed();
      final before = await resolve(cyclesModelProvider);
      final sub = container.listen(resolvedWeekIndexProvider, (_, _) {});
      addTearDown(sub.close);
      final weekSub = container.listen(selectedWeekProvider, (_, _) {});
      addTearDown(weekSub.close);

      // Bucket 0 opens on 27 July, six days before the August window — it is
      // gone entirely once the window starts in September.
      container
          .read(selectedWeekProvider.notifier)
          .select(before.weeks.first.bucket.start);
      expect(container.read(resolvedWeekIndexProvider), 0);

      clock.jumpTo(DateTime.utc(2026, 9, 1));
      final after = await resolve(cyclesModelProvider);

      expect(container.read(resolvedWeekIndexProvider), after.currentWeekIndex,
          reason: 'a selection the model can no longer honour degrades to the '
              '"follow today" default — the one state the user can read off '
              'the screen — rather than to whatever week happens to sit at '
              'the old index');
    });

    test('a picked month keeps its identity across a YEAR rollover', () async {
      await seed();
      final sub = container.listen(resolvedMonthIndexProvider, (_, _) {});
      addTearDown(sub.close);
      final monthSub = container.listen(selectedMonthProvider, (_, _) {});
      addTearDown(monthSub.close);

      final before = await resolve(yearModelProvider);
      // December 2026 — index 11 of the 2026 grid.
      container
          .read(selectedMonthProvider.notifier)
          .select(before.months[11].month);
      expect(container.read(resolvedMonthIndexProvider), 11);

      clock.jumpTo(DateTime.utc(2027, 1, 1));
      final after = await resolve(yearModelProvider);
      expect(after.year, 2027);

      expect(container.read(resolvedMonthIndexProvider), 0,
          reason: 'December 2026 is not a month of the 2027 grid, so the '
              'selection follows today (January) instead of silently becoming '
              'December 2027 — a month the user never picked');
    });
  });

  test('an entry with no regimen never reaches the model', () async {
    await container.read(supplementRepoProvider).upsert(magnesium);

    final model = await resolve(cyclesModelProvider);
    expect(model.rows, isEmpty);
  });

  test('resolving the YEAR model creates no IntakeLog rows either — the case '
      'a materializing implementation would pay for most (PF-2)', () async {
    await seed();
    await materializeOneDay(today);

    final before = await rawLogs();
    expect(before, isNotEmpty,
        reason: 'the gate must compare a real count, not two zeros');

    final cycles = await resolve(cyclesModelProvider);
    final year = await resolve(yearModelProvider);
    expect(cycles.rows, isNotEmpty);
    expect(year.months, hasLength(12),
        reason: 'a full year was scanned, not a single day');

    final after = await rawLogs();
    expect(after.length, before.length,
        reason: 'scanning a whole year is arithmetic, not materialization — '
            'the planner must never write a row (PF-2 / WR-06)');
  });

  test('a soft-deleted supplement disappears from BOTH models on the next '
      'emission (PF-9)', () async {
    await seed();

    final sub = container.listen(cyclesModelProvider, (_, _) {});
    addTearDown(sub.close);
    final yearSub = container.listen(yearModelProvider, (_, _) {});
    addTearDown(yearSub.close);

    expect((await resolve(cyclesModelProvider)).rows, hasLength(2));
    expect((await resolve(yearModelProvider)).entries, hasLength(2));

    // The cascade is the real production path: it soft-deletes the supplement,
    // its regimens and their slots in one transaction.
    await container
        .read(supplementRepoProvider)
        .softDeleteCascade('s1', fromDay: today);

    Future<bool> gone() async {
      for (var i = 0; i < 200; i++) {
        final cycles = container.read(cyclesModelProvider);
        final year = container.read(yearModelProvider);
        if (cycles case AsyncData(value: final c)) {
          if (year case AsyncData(value: final y)) {
            if (c.rows.length == 1 && y.entries.length == 1) return true;
          }
        }
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      return false;
    }

    expect(await gone(), isTrue,
        reason: 'both streams filter deletedAt, so nothing in the planner '
            'has to know about soft deletes');
    expect(
      (container.read(cyclesModelProvider) as AsyncData<CyclesModel>)
          .value
          .rows
          .single
          .entry
          .supplement
          .id,
      's2',
    );
  });
}

/// Pins `todayProvider` to a fixed calendar day.
class _FixedToday extends TodayController {
  _FixedToday(this.day);

  final DateTime day;

  @override
  DateTime build() => day;
}

/// A pinned clock that can be MOVED — the midnight rollover, without waiting
/// for one. The real controller re-derives the day from the system clock on a
/// timer; the tests that need a window shift drive that transition directly.
class _MovableToday extends TodayController {
  _MovableToday(this._day);

  DateTime _day;

  @override
  DateTime build() => _day;

  void jumpTo(DateTime day) {
    _day = day;
    state = day;
  }
}
