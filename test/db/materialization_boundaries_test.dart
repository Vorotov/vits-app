/// TRACK-04 gate: DST and year-boundary materialization exactness
/// (plan 03-02, Task 2, E-8, E-9, PF-3).
///
/// Proves the FULL production chain — `ensureLogsForDay` (whose only gate is
/// `isActiveOn`) followed by `watchDay` — stays exact across Ukraine's 2026
/// DST transitions (fall-back Sun 2026-10-25, spring-forward Sun 2026-03-29)
/// and across the 2026/2027 year boundary. All day arithmetic runs on UTC
/// date-only values, where `Duration.inDays` is exact and no 23h/25h local day
/// can shift a calendar day.
///
/// It also pins the two losslessness properties the phase rests on:
/// re-materializing a day never duplicates a row (insert-or-ignore on
/// (slotId, date)) and never resets an already-recorded status (T-03-07).
///
/// Harness copied from `test/db/pause_filter_test.dart`: in-memory database,
/// the three Drift repositories built in setUp, closed in tearDown. Fixtures
/// are seeded through the repositories, so the production write path is what
/// is exercised. Dose counts are asserted as exact numbers, never as
/// "greater than zero".
library;

import 'package:boostque/core/db/database.dart' show BoostqueDb;
import 'package:boostque/core/db/drift_repositories.dart';
import 'package:boostque/core/domain/models.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late BoostqueDb db;
  late DriftSupplementRepository supps;
  late DriftRegimenRepository regs;
  late DriftIntakeRepository intake;

  setUp(() {
    db = BoostqueDb.forTesting(NativeDatabase.memory());
    supps = DriftSupplementRepository(db);
    regs = DriftRegimenRepository(db);
    intake = DriftIntakeRepository(db);
  });

  tearDown(() => db.close());

  const s1 = Supplement(
    id: 's1',
    name: 'Магній',
    doseText: '400 мг',
    colorValue: 0xFF6B6FA8,
    note: '',
  );

  const morningSlot = DoseSlot(
    id: 'sl-morning',
    minutesFromMidnight: 8 * 60,
    doseLabel: '200 мг',
  );
  const eveningSlot = DoseSlot(
    id: 'sl-evening',
    minutesFromMidnight: 20 * 60,
    doseLabel: '200 мг',
  );

  /// Seeds one supplement plus a cyclic regimen through the repositories.
  Future<void> seedCyclic({
    required DateTime startDate,
    int onDays = 7,
    int offDays = 7,
    List<DoseSlot> slots = const [morningSlot],
  }) async {
    await supps.upsert(s1);
    await regs.upsert(
      Regimen(
        id: 'r1',
        supplementId: 's1',
        kind: RegimenKind.cyclic,
        startDate: startDate,
        endDate: null,
        onDays: onDays,
        offDays: offDays,
        paused: false,
        slots: slots,
      ),
    );
  }

  /// Materializes [day] twice (idempotency under repetition) and returns the
  /// first emission of that day's dose stream.
  Future<List<DayDoseCount>> materializeAndRead(DateTime day) async {
    await intake.ensureLogsForDay(day);
    await intake.ensureLogsForDay(day);
    final doses = await intake.watchDay(day).first;
    return [
      for (final d in doses)
        DayDoseCount(d.slot.minutesFromMidnight, d.status, d.logId),
    ];
  }

  test(
    'DST fall-back window: exactly one dose on each of the seven on-days '
    '(including 2026-10-25) and zero on each of the seven off-days (E-8)',
    () async {
      await seedCyclic(startDate: DateTime.utc(2026, 10, 19));

      for (var d = 0; d < 14; d++) {
        final day = DateTime.utc(2026, 10, 19).add(Duration(days: d));
        final doses = await materializeAndRead(day);
        expect(
          doses,
          hasLength(d < 7 ? 1 : 0),
          reason: 'day $day must hold exactly ${d < 7 ? 1 : 0} dose(s)',
        );
      }
    },
  );

  test(
    'spring-forward day (Sun 2026-03-29) holds exactly one dose (E-8)',
    () async {
      await seedCyclic(startDate: DateTime.utc(2026, 3, 23));

      // The whole 2026-03-23..2026-03-29 on-week, spring-forward included.
      for (var d = 0; d < 7; d++) {
        final day = DateTime.utc(2026, 3, 23).add(Duration(days: d));
        expect(await materializeAndRead(day), hasLength(1), reason: '$day');
      }
      expect(await materializeAndRead(DateTime.utc(2026, 3, 29)), hasLength(1));
      expect(
        await materializeAndRead(DateTime.utc(2026, 3, 30)),
        isEmpty,
        reason: 'the off-week starts the day after the spring-forward day',
      );
    },
  );

  test(
    'cycle continues uninterrupted across the year boundary: one dose on '
    '2026-12-31, 2027-01-01 and 2027-01-03, zero on 2027-01-04 (E-9)',
    () async {
      await seedCyclic(startDate: DateTime.utc(2026, 12, 28));

      expect(
        await materializeAndRead(DateTime.utc(2026, 12, 31)),
        hasLength(1),
      );
      expect(await materializeAndRead(DateTime.utc(2027, 1, 1)), hasLength(1));
      expect(
        await materializeAndRead(DateTime.utc(2027, 1, 3)),
        hasLength(1),
        reason: 'the seventh on-day of the cycle',
      );
      expect(
        await materializeAndRead(DateTime.utc(2027, 1, 4)),
        isEmpty,
        reason: 'the first off-day of the cycle',
      );
    },
  );

  test(
    're-materializing a day never resets a recorded status and never changes '
    'the row count (T-03-07)',
    () async {
      await seedCyclic(startDate: DateTime.utc(2026, 10, 19));
      final day = DateTime.utc(2026, 10, 25);

      final before = await materializeAndRead(day);
      expect(before, hasLength(1));
      expect(before.single.status, DoseStatus.pending);

      await intake.setStatus(before.single.logId, DoseStatus.taken);

      final after = await materializeAndRead(day);
      expect(after, hasLength(1));
      expect(
        after.single.logId,
        before.single.logId,
        reason: 'the same row, not a fresh insert',
      );
      expect(
        after.single.status,
        DoseStatus.taken,
        reason: 'insert-or-ignore never overwrites a recorded status',
      );
      expect(await db.select(db.intakeLogs).get(), hasLength(1));
    },
  );

  test('a multi-slot regimen yields exactly one dose per slot per active day, '
      'ordered by slot minute ascending', () async {
    await seedCyclic(
      startDate: DateTime.utc(2026, 10, 19),
      slots: const [eveningSlot, morningSlot],
    );

    for (var d = 0; d < 7; d++) {
      final day = DateTime.utc(2026, 10, 19).add(Duration(days: d));
      final doses = await materializeAndRead(day);
      expect(doses, hasLength(2), reason: '$day: one dose per slot');
      expect(doses.map((x) => x.minutes), [
        8 * 60,
        20 * 60,
      ], reason: 'watchDay orders by slot minute ascending');
    }

    expect(
      await materializeAndRead(DateTime.utc(2026, 10, 26)),
      isEmpty,
      reason: 'the off-week holds no doses for any slot',
    );
    expect(
      await db.select(db.intakeLogs).get(),
      hasLength(14),
      reason: '7 active days x 2 slots, with every day materialized twice',
    );
  });
}

/// Minimal projection of a materialized dose — keeps assertions about counts,
/// ordering and status readable.
class DayDoseCount {
  final int minutes;
  final DoseStatus status;
  final String logId;

  const DayDoseCount(this.minutes, this.status, this.logId);
}
