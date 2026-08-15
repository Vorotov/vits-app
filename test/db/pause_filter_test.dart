/// Pause-filter tests (plan 02-01, REGI-04, PF-1, E-1, T-02-02).
///
/// Proves pause is a pure query-level filter in `watchDay`: pausing hides a
/// regimen's PENDING doses without mutating a single IntakeLog row (raw
/// zero-stamp assertion), resuming restores them instantly with statuses
/// preserved, and `ensureLogsForDay` after resume re-materializes losslessly
/// (the insertOrIgnore revival trap is impossible). Also proves `watchDay`
/// excludes soft-deleted log rows.
library;

import 'package:boostque/core/db/database.dart'
    show BoostqueDb, IntakeLogsCompanion;
import 'package:boostque/core/db/drift_repositories.dart';
import 'package:boostque/core/domain/models.dart';
import 'package:drift/drift.dart' show Value;
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

  final today = DateTime.utc(2026, 8, 14);

  /// Active always-on regimen with morning + evening slots.
  Regimen r1() => Regimen(
        id: 'r1',
        supplementId: 's1',
        kind: RegimenKind.cyclic,
        startDate: DateTime.utc(2026, 8, 1),
        endDate: null,
        onDays: 56,
        offDays: 0,
        paused: false,
        slots: const [
          DoseSlot(id: 'sl1', minutesFromMidnight: 8 * 60, doseLabel: '200 мг'),
          DoseSlot(
              id: 'sl2', minutesFromMidnight: 20 * 60, doseLabel: '200 мг'),
        ],
      );

  Future<void> seed() async {
    await supps.upsert(s1);
    await regs.upsert(r1());
  }

  test(
      'pause hides pending doses without stamping any log row; resume '
      'restores; re-materialization after resume is lossless (PF-1, E-1)',
      () async {
    await seed();
    await intake.ensureLogsForDay(today);

    var doses = await intake.watchDay(today).first;
    expect(doses, hasLength(2), reason: 'two pending doses materialized');

    // Record the morning dose as taken, then pause.
    final morning =
        doses.firstWhere((d) => d.slot.minutesFromMidnight == 8 * 60);
    await intake.setStatus(morning.logId, DoseStatus.taken);
    await regs.setPaused('r1', true);

    doses = await intake.watchDay(today).first;
    expect(doses, hasLength(1),
        reason: 'paused hides only the pending dose — history stays visible');
    expect(doses.single.status, DoseStatus.taken);

    // PF-1 core: pausing stamped ZERO intakeLogs rows (raw table read).
    final rawWhilePaused = await db.select(db.intakeLogs).get();
    expect(rawWhilePaused.where((l) => l.deletedAt != null), isEmpty,
        reason: 'pause is a query filter — it must never mutate log rows');

    // Resume: everything is back, statuses preserved, zero writes needed.
    await regs.setPaused('r1', false);
    doses = await intake.watchDay(today).first;
    expect(doses, hasLength(2), reason: 'resume restores instantly');
    expect(
        doses
            .firstWhere((d) => d.slot.minutesFromMidnight == 8 * 60)
            .status,
        DoseStatus.taken,
        reason: 'statuses preserved across the pause round trip');
    expect(
        doses
            .firstWhere((d) => d.slot.minutesFromMidnight == 20 * 60)
            .status,
        DoseStatus.pending);

    // ensureLogsForDay after resume: no duplicates, no lost rows (the
    // insertOrIgnore revival trap cannot bite because nothing was stamped).
    await intake.ensureLogsForDay(today);
    final after = await intake.watchDay(today).first;
    expect(after, hasLength(2));
    expect(await db.select(db.intakeLogs).get(), hasLength(2),
        reason: 're-materialization neither duplicates nor loses rows');
    expect(
        after
            .firstWhere((d) => d.slot.minutesFromMidnight == 8 * 60)
            .status,
        DoseStatus.taken,
        reason: 'recorded status survives re-materialization');
  });

  test(
      'removing a slot in the editor hides its PENDING dose from watchDay '
      'while every other dose survives (CR-02)', () async {
    await seed();
    await intake.ensureLogsForDay(today);

    var doses = await intake.watchDay(today).first;
    expect(doses, hasLength(2));

    // The morning dose is already recorded; the evening slot is the one the
    // user removes in the regimen editor (a soft delete on regimenSlots).
    final morning =
        doses.firstWhere((d) => d.slot.minutesFromMidnight == 8 * 60);
    await intake.setStatus(morning.logId, DoseStatus.taken);
    await regs.upsert(Regimen(
      id: 'r1',
      supplementId: 's1',
      kind: RegimenKind.cyclic,
      startDate: DateTime.utc(2026, 8, 1),
      endDate: null,
      onDays: 56,
      offDays: 0,
      paused: false,
      slots: const [
        DoseSlot(id: 'sl1', minutesFromMidnight: 8 * 60, doseLabel: '200 мг'),
      ],
    ));

    doses = await intake.watchDay(today).first;
    expect(doses, hasLength(1),
        reason: 'the removed slot\'s pending dose disappears — it must not '
            'stay rendered, counted in the ring, or markable');
    expect(doses.single.slot.id, 'sl1');
    expect(doses.single.status, DoseStatus.taken,
        reason: 'the surviving slot keeps its recorded history');

    // DATA-02: the removed slot's log row is still THERE, only filtered out.
    expect(await db.select(db.intakeLogs).get(), hasLength(2),
        reason: 'slot removal is a query-level filter, not a row delete');

    // Re-materializing after the removal never revives the phantom dose.
    await intake.ensureLogsForDay(today);
    expect(await intake.watchDay(today).first, hasLength(1));
  });

  test('a dose already RECORDED on a removed slot stays visible history '
      '(CR-02)', () async {
    await seed();
    await intake.ensureLogsForDay(today);

    final doses = await intake.watchDay(today).first;
    final evening =
        doses.firstWhere((d) => d.slot.minutesFromMidnight == 20 * 60);
    await intake.setStatus(evening.logId, DoseStatus.taken);

    // Remove the evening slot AFTER it was taken.
    await regs.upsert(Regimen(
      id: 'r1',
      supplementId: 's1',
      kind: RegimenKind.cyclic,
      startDate: DateTime.utc(2026, 8, 1),
      endDate: null,
      onDays: 56,
      offDays: 0,
      paused: false,
      slots: const [
        DoseSlot(id: 'sl1', minutesFromMidnight: 8 * 60, doseLabel: '200 мг'),
      ],
    ));

    final after = await intake.watchDay(today).first;
    expect(after, hasLength(2),
        reason: 'history is never rewritten by a later edit — the taken '
            'evening dose stays on the day it happened');
    expect(
        after
            .firstWhere((d) => d.slot.minutesFromMidnight == 20 * 60)
            .status,
        DoseStatus.taken);
  });

  test('watchDay excludes soft-deleted log rows', () async {
    await seed();
    await intake.ensureLogsForDay(today);
    final doses = await intake.watchDay(today).first;
    expect(doses, hasLength(2));

    // Stamp one log row directly, the way the delete cascade would.
    final now = DateTime.now().toUtc();
    await (db.update(db.intakeLogs)
          ..where((t) => t.id.equals(doses.first.logId)))
        .write(IntakeLogsCompanion(
      deletedAt: Value(now),
      updatedAt: Value(now),
    ));

    final after = await intake.watchDay(today).first;
    expect(after, hasLength(1),
        reason: 'watchDay filters intakeLogs.deletedAt IS NULL');
    expect(after.single.logId, isNot(doses.first.logId));
  });
}
