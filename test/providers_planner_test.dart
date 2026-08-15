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

  /// A 14-on/14-off cycle from the window's first day, with one 08:00 slot so
  /// the materializing path has something real to create.
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
    expect(model.span, 122);
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
