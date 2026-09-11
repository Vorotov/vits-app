/// Cascade soft-delete tests (plan 02-01, STACK-04, E-2, T-02-01).
///
/// Proves `SupplementRepository.softDeleteCascade` stamps the supplement,
/// its regimens, their slots, and every future PENDING IntakeLog (date >=
/// fromDay) in one transaction — while taken/skipped history and past
/// pending rows keep `deletedAt == null`. Raw table reads follow the
/// Phase-1 soft-delete-survival assertion style (DATA-02).
library;

import 'package:vitomy/core/db/database.dart' show VitomyDb;
import 'package:vitomy/core/db/drift_repositories.dart';
import 'package:vitomy/core/domain/models.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late VitomyDb db;
  late DriftSupplementRepository supps;
  late DriftRegimenRepository regs;
  late DriftIntakeRepository intake;

  setUp(() {
    db = VitomyDb.forTesting(NativeDatabase.memory());
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
  final pastDay = DateTime.utc(2026, 8, 12);

  /// Cyclic regimen starting two days before [today] with offDays 0
  /// (always on) and one 08:00 slot.
  Regimen r1() => Regimen(
        id: 'r1',
        supplementId: 's1',
        kind: RegimenKind.cyclic,
        startDate: pastDay,
        endDate: null,
        onDays: 56,
        offDays: 0,
        paused: false,
        slots: const [
          DoseSlot(id: 'sl1', minutesFromMidnight: 8 * 60, doseLabel: '400 мг'),
        ],
      );

  Future<void> seed() async {
    await supps.upsert(s1);
    await regs.upsert(r1());
  }

  test(
      'cascade stamps supplement + regimen + slot + future pending log, '
      'keeps taken history (E-2)', () async {
    await seed();

    // Past day: materialize and record taken (history).
    await intake.ensureLogsForDay(pastDay);
    final pastLog = (await intake.watchDay(pastDay).first).single;
    await intake.setStatus(pastLog.logId, DoseStatus.taken);

    // Today: materialized, still pending.
    await intake.ensureLogsForDay(today);

    final suppBefore = (await db.select(db.supplements).get()).single;
    final regimenBefore = (await db.select(db.regimens).get()).single;
    final slotBefore = (await db.select(db.regimenSlots).get()).single;
    await Future<void>.delayed(const Duration(milliseconds: 5));

    await supps.softDeleteCascade('s1', fromDay: today);

    // Streams hide everything.
    expect(await supps.watchAll().first, isEmpty,
        reason: 'supplement hidden after cascade');
    expect(await regs.watchAll().first, isEmpty,
        reason: 'regimen hidden after cascade');

    // Raw reads: rows survive with deletedAt stamped and updatedAt bumped.
    final rawSupp = (await db.select(db.supplements).get()).single;
    expect(rawSupp.deletedAt, isNotNull);
    expect(rawSupp.updatedAt.isAfter(suppBefore.updatedAt), isTrue,
        reason: 'cascade bumps supplement updatedAt (T-01-16)');

    final rawRegimen = (await db.select(db.regimens).get()).single;
    expect(rawRegimen.deletedAt, isNotNull);
    expect(rawRegimen.updatedAt.isAfter(regimenBefore.updatedAt), isTrue,
        reason: 'cascade bumps regimen updatedAt');

    final rawSlot = (await db.select(db.regimenSlots).get()).single;
    expect(rawSlot.deletedAt, isNotNull);
    expect(rawSlot.updatedAt.isAfter(slotBefore.updatedAt), isTrue,
        reason: 'cascade bumps slot updatedAt');

    final rawLogs = await db.select(db.intakeLogs).get();
    expect(rawLogs, hasLength(2), reason: 'soft delete only — no row removed');
    final past = rawLogs.singleWhere((l) => l.date == pastDay);
    expect(past.deletedAt, isNull,
        reason: 'taken history rows are never touched');
    expect(past.status, DoseStatus.taken);
    final todays = rawLogs.singleWhere((l) => l.date == today);
    expect(todays.deletedAt, isNotNull,
        reason: 'future pending rows (date >= fromDay) are stamped');
  });

  test('pending log dated BEFORE fromDay keeps deletedAt null (scoping)',
      () async {
    await seed();
    final yesterday = DateTime.utc(2026, 8, 13);
    await intake.ensureLogsForDay(yesterday); // pending, before fromDay
    await intake.ensureLogsForDay(today); // pending, on fromDay

    await supps.softDeleteCascade('s1', fromDay: today);

    final rawLogs = await db.select(db.intakeLogs).get();
    expect(rawLogs, hasLength(2));
    expect(rawLogs.singleWhere((l) => l.date == yesterday).deletedAt, isNull,
        reason: 'only date >= fromDay AND status == pending is stamped');
    expect(rawLogs.singleWhere((l) => l.date == today).deletedAt, isNotNull);
  });
}
