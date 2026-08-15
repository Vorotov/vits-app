/// Provider-layer proofs for the calendar day family (plan 03-01, Task 2).
///
/// Container harness copied from test/providers_test.dart: [dbProvider] is
/// overridden with an in-memory database, so no test touches the on-disk
/// boostque.sqlite file (D-19). Seeding goes through the repository providers
/// read off the SAME container, so production code paths are exercised.
///
/// This file NEVER calls the repository's materialization primitive — that is
/// exactly the point: `dayDosesProvider` is its only production caller (PF-3),
/// and a test that materialized by hand would prove nothing about the app.
///
/// Riverpod 3 pauses unlistened providers, so every family instance under test
/// is held open with `container.listen(...)` before its emissions are awaited;
/// an unlistened instance never runs its build and never materializes.
///
/// Coverage: materialization without a manual ensure (PF-3), re-materialization
/// driven by the regimens stream, status survival across re-materialization
/// (T-03-01), the pause/resume round trip with a raw zero-mutation assertion
/// (PF-9, E-4), and the `dateOnly()` family-key assert (PF-1).
library;

import 'package:boostque/core/db/database.dart' show BoostqueDb, IntakeLog;
import 'package:boostque/core/domain/models.dart';
import 'package:boostque/core/domain/repositories.dart';
import 'package:boostque/core/providers.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late ProviderContainer container;
  late BoostqueDb db;

  setUp(() {
    container = ProviderContainer(
      overrides: [
        dbProvider.overrideWith((ref) {
          final database = BoostqueDb.forTesting(NativeDatabase.memory());
          ref.onDispose(database.close);
          db = database;
          return database;
        }),
      ],
    );
  });

  tearDown(() => container.dispose());

  const s1 = Supplement(
    id: 's1',
    name: 'Магній',
    doseText: '400 мг',
    colorValue: 0xFF6B6FA8,
    note: '',
  );

  final day = DateTime.utc(2026, 8, 14);

  /// Always-on cyclic regimen (offDays 0) covering [day], with [slots].
  Regimen r1({List<DoseSlot> slots = const [
    DoseSlot(id: 'sl1', minutesFromMidnight: 480, doseLabel: '200 мг'),
  ], bool paused = false}) =>
      Regimen(
        id: 'r1',
        supplementId: 's1',
        kind: RegimenKind.cyclic,
        startDate: DateTime.utc(2026, 8, 1),
        endDate: null,
        onDays: 56,
        offDays: 0,
        paused: paused,
        slots: slots,
      );

  /// Holds the family instance for [d] open (Riverpod 3 pauses unlistened
  /// providers) and returns nothing — callers poll via [waitForDoses].
  void keepOpen(DateTime d) {
    final sub = container.listen(dayDosesProvider(d), (_, _) {});
    addTearDown(sub.close);
  }

  /// Polls `dayDosesProvider(d)` until it holds AsyncData with [count] doses.
  Future<List<DayDose>> waitForDoses(DateTime d, int count) async {
    for (var i = 0; i < 200; i++) {
      final value = container.read(dayDosesProvider(d));
      if (value case AsyncData(value: final doses) when doses.length == count) {
        return doses;
      }
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    fail('dayDosesProvider($d) never reached $count doses — last value: '
        '${container.read(dayDosesProvider(d))}');
  }

  Future<List<IntakeLog>> rawLogs() => db.select(db.intakeLogs).get();

  Future<void> seed({List<DoseSlot>? slots}) async {
    await container.read(supplementRepoProvider).upsert(s1);
    await container.read(regimenRepoProvider).upsert(
          slots == null ? r1() : r1(slots: slots),
        );
  }

  test('materializes one dose per active slot with NO manual ensure call '
      '(PF-3, TRACK-04)', () async {
    await seed();
    keepOpen(day);

    final doses = await waitForDoses(day, 1);
    expect(doses.single.supplement.name, 'Магній');
    expect(doses.single.slot.minutesFromMidnight, 480);
    expect(doses.single.status, DoseStatus.pending);
    expect(await rawLogs(), hasLength(1),
        reason: 'the provider materialized the row, not the test');
  });

  test('a regimen edit re-materializes the same family instance (the regimens '
      'stream drives the rebuild)', () async {
    await seed();
    keepOpen(day);
    await waitForDoses(day, 1);

    await container.read(regimenRepoProvider).upsert(r1(slots: const [
          DoseSlot(id: 'sl1', minutesFromMidnight: 480, doseLabel: '200 мг'),
          DoseSlot(id: 'sl2', minutesFromMidnight: 1200, doseLabel: '200 мг'),
        ]));

    final doses = await waitForDoses(day, 2);
    expect(doses.map((d) => d.slot.minutesFromMidnight), [480, 1200],
        reason: 'doses stay ordered by slot time');
  });

  test('a dose already marked taken keeps that status across '
      're-materialization (T-03-01)', () async {
    await seed();
    keepOpen(day);
    final doses = await waitForDoses(day, 1);

    await container
        .read(intakeRepoProvider)
        .setStatus(doses.single.logId, DoseStatus.taken);
    await waitForDoses(day, 1);

    // Any regimen write re-runs the build, so the day re-materializes.
    await container.read(regimenRepoProvider).upsert(r1());
    final after = await waitForDoses(day, 1);

    expect(after.single.status, DoseStatus.taken,
        reason: 'insert-or-ignore never resets an existing row status');
    expect(await rawLogs(), hasLength(1),
        reason: 're-materialization neither duplicates nor loses rows');
  });

  test('pausing removes pending doses and resuming restores them with ZERO '
      'log-row writes (PF-9, E-4, REGI-04)', () async {
    await seed();
    keepOpen(day);
    await waitForDoses(day, 1);

    final before = await rawLogs();
    expect(before, hasLength(1));

    await container.read(regimenRepoProvider).setPaused('r1', true);
    expect(await waitForDoses(day, 0), isEmpty,
        reason: 'pause is a query-level filter on pending doses');

    await container.read(regimenRepoProvider).setPaused('r1', false);
    final restored = await waitForDoses(day, 1);
    expect(restored.single.status, DoseStatus.pending);

    final after = await rawLogs();
    expect(after, hasLength(1), reason: 'the round trip inserted nothing new');
    expect(after.single.id, before.single.id);
    expect(after.single.status, before.single.status);
    expect(after.single.updatedAt, before.single.updatedAt,
        reason: 'pause/resume must not stamp a single IntakeLog row — the '
            'provider layer adds no pause logic of its own (PF-9)');
    expect(after.single.deletedAt, isNull);
  });

  test('a non-normalized family key trips the PF-1 assert instead of forking '
      'the cache into a phantom day', () async {
    await seed();
    // 10:00 on the same calendar day — a value dateOnly() would have flattened.
    final bad = DateTime.utc(2026, 8, 14, 10);
    keepOpen(bad);

    await expectLater(
      container.read(dayDosesProvider(bad).future),
      throwsA(isA<AssertionError>()),
    );
  });
}
