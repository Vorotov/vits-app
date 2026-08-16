/// Schedule-edit reconciliation tests (INTEGRATION-CHECK flow 2, REGI-01/02,
/// PLAN-01/02 vs TRACK-01/02).
///
/// Materialization (written IntakeLog rows) and projection (the planner's pure
/// `isActiveOn` runs) are two representations of the same schedule. They were
/// reconciled on CREATE but not on EDIT: `RegimenRepository.upsert` rewrites
/// the regimen row without touching `intakeLogs`, so pending doses already
/// written for previously-active days survived a `startDate` / `onDays` /
/// `offDays` / `kind` / course-`endDate` change, and Today kept showing a
/// tappable dose on a day Цикли/Рік drew as a break.
///
/// The fix extends `watchDay`'s existing filter policy (the one already used
/// for pause and slot removal): PENDING doses on days the CURRENT schedule
/// says are inactive are filtered out at read time. No row is ever stamped, so
/// editing the schedule back restores the day with zero writes — and, unlike a
/// `deletedAt` stamp, cannot poison `ensureLogsForDay`'s insert-or-ignore on
/// the unique (slotId, date) key (the Phase-3 revival trap, PF-1).
///
/// Harness copied from `test/db/pause_filter_test.dart`: in-memory database,
/// the three Drift repositories built in setUp, closed in tearDown; fixtures
/// seeded through the repositories so the production write path is exercised;
/// raw table reads prove DB state.
library;

import 'package:boostque/core/db/database.dart' show BoostqueDb;
import 'package:boostque/core/db/drift_repositories.dart';
import 'package:boostque/core/domain/cycle_math.dart' show isActiveOn;
import 'package:boostque/core/domain/models.dart';
import 'package:boostque/core/domain/repositories.dart' show DayDose;
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
    id: 'sl1',
    minutesFromMidnight: 8 * 60,
    doseLabel: '400 мг',
  );

  /// A cyclic regimen with a 3-on/3-off shape, so moving `startDate` by three
  /// days flips every day's activity.
  Regimen cyclic({
    required DateTime startDate,
    int onDays = 3,
    int offDays = 3,
  }) =>
      Regimen(
        id: 'r1',
        supplementId: 's1',
        kind: RegimenKind.cyclic,
        startDate: startDate,
        endDate: null,
        onDays: onDays,
        offDays: offDays,
        paused: false,
        slots: const [morningSlot],
      );

  Regimen course({required DateTime startDate, required DateTime endDate}) =>
      Regimen(
        id: 'r1',
        supplementId: 's1',
        kind: RegimenKind.course,
        startDate: startDate,
        endDate: endDate,
        onDays: 0,
        offDays: 0,
        paused: false,
        slots: const [morningSlot],
      );

  /// Materializes [day] and returns that day's visible doses.
  Future<List<DayDose>> materializeAndRead(DateTime day) async {
    await intake.ensureLogsForDay(day);
    return intake.watchDay(day).first;
  }

  test(
      'moving startDate so a materialized day becomes OFF hides its pending '
      'dose — without deleting the row (flow 2 blocker)', () async {
    await supps.upsert(s1);
    // 3-on from Mon 2026-08-10 => 10/11/12 on, 13/14/15 off.
    await regs.upsert(cyclic(startDate: DateTime.utc(2026, 8, 10)));

    final onDay = DateTime.utc(2026, 8, 12);
    expect(await materializeAndRead(onDay), hasLength(1),
        reason: '2026-08-12 is the third on-day of the first block');

    // The user edits the schedule: the cycle now starts three days later, so
    // 08-12 lands in the leading off-block.
    await regs.upsert(cyclic(startDate: DateTime.utc(2026, 8, 13)));
    expect(isActiveOn(await _regimen(regs), onDay), isFalse,
        reason: 'sanity: the planner projects 2026-08-12 as a break');

    expect(await intake.watchDay(onDay).first, isEmpty,
        reason: 'Today must not keep a tappable dose on a day the schedule '
            'now says is a break');

    // DATA-02: filtered out at read time, never removed and never stamped.
    final raw = await db.select(db.intakeLogs).get();
    expect(raw, hasLength(1), reason: 'soft-delete-only: the row survives');
    expect(raw.single.deletedAt, isNull,
        reason: 'a schedule edit is a query-level filter, exactly like pause '
            '— stamping deletedAt would poison re-materialization');
  });

  test('a TAKEN dose on a now-inactive day survives as history', () async {
    await supps.upsert(s1);
    await regs.upsert(cyclic(startDate: DateTime.utc(2026, 8, 10)));

    final day = DateTime.utc(2026, 8, 11);
    final dose = (await materializeAndRead(day)).single;
    await intake.setStatus(dose.logId, DoseStatus.taken);

    // Edit the schedule so 08-11 is no longer an on-day.
    await regs.upsert(cyclic(startDate: DateTime.utc(2026, 8, 13)));

    final after = await intake.watchDay(day).first;
    expect(after, hasLength(1),
        reason: 'history is never rewritten by a later edit — what the user '
            'actually took stays on the day it happened');
    expect(after.single.status, DoseStatus.taken);
    expect(after.single.logId, dose.logId);
  });

  test('a SKIPPED dose on a now-inactive day survives as history', () async {
    await supps.upsert(s1);
    await regs.upsert(cyclic(startDate: DateTime.utc(2026, 8, 10)));

    final day = DateTime.utc(2026, 8, 11);
    final dose = (await materializeAndRead(day)).single;
    await intake.setStatus(dose.logId, DoseStatus.skipped);

    await regs.upsert(cyclic(startDate: DateTime.utc(2026, 8, 13)));

    final after = await intake.watchDay(day).first;
    expect(after, hasLength(1), reason: 'skipped is a recorded decision');
    expect(after.single.status, DoseStatus.skipped);
  });

  test('shortening a course endDate hides pending doses past the new end',
      () async {
    await supps.upsert(s1);
    await regs.upsert(course(
      startDate: DateTime.utc(2026, 8, 10),
      endDate: DateTime.utc(2026, 8, 20),
    ));

    for (var d = 10; d <= 18; d++) {
      expect(await materializeAndRead(DateTime.utc(2026, 8, d)), hasLength(1),
          reason: '2026-08-$d is inside the original course window');
    }

    // The user shortens the course to end on 08-15.
    await regs.upsert(course(
      startDate: DateTime.utc(2026, 8, 10),
      endDate: DateTime.utc(2026, 8, 15),
    ));

    for (var d = 10; d <= 15; d++) {
      expect(await intake.watchDay(DateTime.utc(2026, 8, d)).first, hasLength(1),
          reason: '2026-08-$d is still inside the shortened course');
    }
    for (var d = 16; d <= 18; d++) {
      expect(await intake.watchDay(DateTime.utc(2026, 8, d)).first, isEmpty,
          reason: '2026-08-$d is past the new endDate');
    }

    expect(await db.select(db.intakeLogs).get(), hasLength(9),
        reason: 'all nine materialized rows survive — no row is removed');
  });

  test('editing the schedule BACK re-materializes the day losslessly '
      '(no insert-or-ignore revival trap)', () async {
    await supps.upsert(s1);
    await regs.upsert(cyclic(startDate: DateTime.utc(2026, 8, 10)));

    final day = DateTime.utc(2026, 8, 12);
    final before = (await materializeAndRead(day)).single;

    // Off...
    await regs.upsert(cyclic(startDate: DateTime.utc(2026, 8, 13)));
    expect(await intake.watchDay(day).first, isEmpty);

    // ...and back on again.
    await regs.upsert(cyclic(startDate: DateTime.utc(2026, 8, 10)));
    final restored = await materializeAndRead(day);
    expect(restored, hasLength(1),
        reason: 'the day comes back — a stamped row would have been blocked '
            'forever by the unique (slotId, date) insert-or-ignore key');
    expect(restored.single.logId, before.logId,
        reason: 'the same row, revived by the filter, not a fresh insert');
    expect(await db.select(db.intakeLogs).get(), hasLength(1),
        reason: 'the round trip neither duplicates nor loses rows');
  });

  test('an edit leaves days the new schedule still covers untouched',
      () async {
    await supps.upsert(s1);
    await regs.upsert(cyclic(startDate: DateTime.utc(2026, 8, 10)));

    // 08-10..08-12 on, 08-13..08-15 off, 08-16..08-18 on.
    for (final d in [10, 11, 12, 16, 17, 18]) {
      expect(await materializeAndRead(DateTime.utc(2026, 8, d)), hasLength(1));
    }

    // Widen the on-block to 4 days (4-on/3-off from 08-10): 08-10..08-13 on,
    // 08-14..08-16 off, 08-17..08-20 on.
    await regs.upsert(cyclic(startDate: DateTime.utc(2026, 8, 10), onDays: 4));

    for (final d in [10, 11, 12, 17, 18]) {
      expect(await intake.watchDay(DateTime.utc(2026, 8, d)).first, hasLength(1),
          reason: '2026-08-$d is still an on-day — its dose must not vanish');
    }
    expect(await intake.watchDay(DateTime.utc(2026, 8, 16)).first, isEmpty,
        reason: '2026-08-16 became an off-day under the wider on-block');
  });

  test(
      'switching kind cyclic -> course reconciles days outside the course '
      'window', () async {
    await supps.upsert(s1);
    await regs.upsert(cyclic(startDate: DateTime.utc(2026, 8, 10), offDays: 0));

    for (var d = 10; d <= 16; d++) {
      expect(await materializeAndRead(DateTime.utc(2026, 8, d)), hasLength(1));
    }

    await regs.upsert(course(
      startDate: DateTime.utc(2026, 8, 10),
      endDate: DateTime.utc(2026, 8, 13),
    ));

    for (var d = 10; d <= 13; d++) {
      expect(await intake.watchDay(DateTime.utc(2026, 8, d)).first, hasLength(1),
          reason: '2026-08-$d is inside the new course window');
    }
    for (var d = 14; d <= 16; d++) {
      expect(await intake.watchDay(DateTime.utc(2026, 8, d)).first, isEmpty,
          reason: '2026-08-$d is outside the new course window');
    }
  });

  test(
      'after an edit, Today and the planner agree day by day: watchDay is '
      'non-empty exactly where isActiveOn is true', () async {
    await supps.upsert(s1);
    await regs.upsert(cyclic(startDate: DateTime.utc(2026, 8, 10)));

    // Materialize a three-week window under the ORIGINAL schedule.
    for (var d = 0; d < 21; d++) {
      await intake.ensureLogsForDay(DateTime.utc(2026, 8, 10 + d));
    }

    // Edit: shift the phase by two days and change the cycle shape.
    await regs.upsert(cyclic(
      startDate: DateTime.utc(2026, 8, 12),
      onDays: 5,
      offDays: 2,
    ));
    final edited = await _regimen(regs);

    // The production chain, exactly as `dayDosesProvider` runs it: any regimen
    // edit re-runs `ensureLogsForDay` (which brings NEWLY-active days in) and
    // then `watchDay` (which filters days the edit took OUT).
    for (var d = 0; d < 21; d++) {
      final day = DateTime.utc(2026, 8, 10 + d);
      final today = await materializeAndRead(day);
      expect(today.isNotEmpty, isActiveOn(edited, day),
          reason: 'Today and Цикли/Рік must give the same answer for $day '
              '(no dose was recorded, so nothing is history)');
    }
  });
}

/// The single active regimen, read back through the repository — the same
/// value the planner projects through `isActiveOn`.
Future<Regimen> _regimen(DriftRegimenRepository regs) async =>
    (await regs.watchAll().first).single;
