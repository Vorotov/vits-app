/// Repository contract tests (plan 01-07).
///
/// Runs against an in-memory Drift database (D-19) and exercises the
/// repository layer only through the domain interfaces plus raw table reads
/// where soft-delete survival must be proven (DATA-02 — no hard deletes).
library;

import 'package:boostque/core/db/database.dart' show BoostqueDb, SupplementsCompanion;
import 'package:boostque/core/db/drift_repositories.dart';
import 'package:boostque/core/domain/models.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late BoostqueDb db;
  late DriftSupplementRepository supps;
  late DriftRegimenRepository regs;

  setUp(() {
    db = BoostqueDb.forTesting(NativeDatabase.memory());
    supps = DriftSupplementRepository(db);
    regs = DriftRegimenRepository(db);
  });

  tearDown(() => db.close());

  const s1 = Supplement(
    id: 's1',
    name: 'Магній',
    doseText: '400 мг',
    colorValue: 0xFF6B6FA8,
    note: '',
  );

  Regimen r1({List<DoseSlot> slots = const [
    DoseSlot(id: 'sl1', minutesFromMidnight: 22 * 60, doseLabel: '400 мг'),
  ]}) =>
      Regimen(
        id: 'r1',
        supplementId: 's1',
        kind: RegimenKind.cyclic,
        startDate: DateTime.utc(2026, 8, 1),
        endDate: null,
        onDays: 56,
        offDays: 28,
        paused: false,
        slots: slots,
      );

  group('fresh database (DATA-01/empty)', () {
    test('supplements watchAll emits empty list without error', () async {
      expect(await supps.watchAll().first, isEmpty);
    });

    test('regimens watchAll emits empty list without error', () async {
      expect(await regs.watchAll().first, isEmpty);
    });
  });

  group('SupplementRepository', () {
    test('upsert inserts, then updates fields and bumps updatedAt', () async {
      await supps.upsert(s1);
      final inserted = await supps.watchAll().first;
      expect(inserted.single.name, 'Магній');

      final rawAfterInsert = (await db.select(db.supplements).get()).single;
      final createdAt0 = rawAfterInsert.createdAt;
      final updatedAt0 = rawAfterInsert.updatedAt;

      await Future<void>.delayed(const Duration(milliseconds: 5));
      await supps.upsert(const Supplement(
        id: 's1',
        name: 'Магній цитрат',
        doseText: '400 мг',
        colorValue: 0xFF6B6FA8,
        note: 'оновлено',
      ));

      final rows = await supps.watchAll().first;
      expect(rows, hasLength(1), reason: 'same id must update, not duplicate');
      expect(rows.single.name, 'Магній цитрат');
      expect(rows.single.note, 'оновлено');

      final rawAfterUpdate = (await db.select(db.supplements).get()).single;
      expect(rawAfterUpdate.updatedAt.isAfter(updatedAt0), isTrue,
          reason: 'upsert must bump updatedAt (T-01-16)');
      expect(rawAfterUpdate.createdAt, createdAt0,
          reason: 'createdAt is set on first insert only');
    });

    test('softDelete hides row from watchAll but keeps it in the table', () async {
      await supps.upsert(s1);
      await supps.softDelete('s1');

      expect(await supps.watchAll().first, isEmpty,
          reason: 'deletedAt IS NULL defines active (DATA-02/empty)');

      final raw = await db.select(db.supplements).get();
      expect(raw, hasLength(1), reason: 'soft delete, never a hard delete');
      expect(raw.single.deletedAt, isNotNull);
    });

    test('equal createdAt orders deterministically by id (DATA-01/ordering)',
        () async {
      final t = DateTime.utc(2026, 8, 14, 12);
      // Insert raw so both rows carry the SAME createdAt instant; insert
      // 'b' first so bare insertion order would betray a missing tiebreak.
      for (final id in ['b', 'a']) {
        await db.into(db.supplements).insert(SupplementsCompanion.insert(
              id: id,
              name: id,
              doseText: '',
              colorValue: 0,
              note: '',
              createdAt: t,
              updatedAt: t,
            ));
      }
      final rows = await supps.watchAll().first;
      expect(rows.map((s) => s.id).toList(), ['a', 'b'],
          reason: 'createdAt asc with id asc as tiebreak');
    });
  });

  group('RegimenRepository', () {
    test('upsert stores regimen; findForSupplement returns slots sorted', () async {
      await supps.upsert(s1);
      await regs.upsert(r1(slots: const [
        DoseSlot(id: 'sl3', minutesFromMidnight: 20 * 60, doseLabel: '200 мг'),
        DoseSlot(id: 'sl2', minutesFromMidnight: 8 * 60, doseLabel: '200 мг'),
      ]));

      final r = await regs.findForSupplement('s1');
      expect(r, isNotNull);
      expect(r!.slots.map((s) => s.id).toList(), ['sl2', 'sl3'],
          reason: 'slots sorted by minutesFromMidnight then id');
      expect(r.onDays, 56);
      expect(r.offDays, 28);
    });

    test('re-upsert replaces slots softly: new set active, old rows survive',
        () async {
      await supps.upsert(s1);
      await regs.upsert(r1()); // sl1 @ 22:00
      await regs.upsert(r1(slots: const [
        DoseSlot(id: 'sl2', minutesFromMidnight: 8 * 60, doseLabel: '200 мг'),
        DoseSlot(id: 'sl3', minutesFromMidnight: 20 * 60, doseLabel: '200 мг'),
      ]));

      final r = await regs.findForSupplement('s1');
      expect(r!.slots.map((s) => s.id).toList(), ['sl2', 'sl3'],
          reason: 'exactly the new slot set is active');

      final rawSlots = await db.select(db.regimenSlots).get();
      expect(rawSlots, hasLength(3),
          reason: 'replaced slot row survives (no hard delete)');
      final sl1 = rawSlots.singleWhere((s) => s.id == 'sl1');
      expect(sl1.deletedAt, isNotNull,
          reason: 'replaced slot is soft-deleted, not removed');
    });

    test('setPaused flips the flag and bumps updatedAt', () async {
      await supps.upsert(s1);
      await regs.upsert(r1());
      final before = (await db.select(db.regimens).get()).single;
      expect(before.paused, isFalse);

      await Future<void>.delayed(const Duration(milliseconds: 5));
      await regs.setPaused('r1', true);

      final after = (await db.select(db.regimens).get()).single;
      expect(after.paused, isTrue);
      expect(after.updatedAt.isAfter(before.updatedAt), isTrue,
          reason: 'mutation must bump updatedAt (T-01-16)');

      final r = await regs.findForSupplement('s1');
      expect(r!.paused, isTrue);
    });

    test('softDelete hides regimen from watchAll but keeps the row', () async {
      await supps.upsert(s1);
      await regs.upsert(r1());
      await regs.softDelete('r1');

      expect(await regs.watchAll().first, isEmpty);
      final raw = await db.select(db.regimens).get();
      expect(raw, hasLength(1));
      expect(raw.single.deletedAt, isNotNull);
    });
  });
}
