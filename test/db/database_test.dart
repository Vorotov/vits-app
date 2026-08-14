/// Schema tests for the sync-ready Drift database (DATA-02).
///
/// Proves the four structural invariants the persistence contract rests on:
/// 1. Every table mixes in SyncColumns (TEXT UUID id PK, createdAt,
///    updatedAt, nullable deletedAt) — per D-17.
/// 2. IntakeLogs enforces a composite unique key on (slotId, date) so
///    materialization via insert-or-ignore is idempotent — per D-18.
/// 3. DateTime values round-trip as UTC (text-based datetime storage keeps
///    the UTC-midnight calendar identity intact) — per D-13/D-18.
/// 4. Soft delete: freshly-inserted rows have deletedAt == null.
library;

import 'package:boostque/core/db/database.dart';
import 'package:boostque/core/domain/models.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late BoostqueDb db;

  setUp(() {
    db = BoostqueDb.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
  });

  IntakeLogsCompanion log({
    required String id,
    String regimenId = 'rg1',
    String slotId = 'sl1',
    DateTime? date,
    DateTime? createdAt,
  }) {
    final now = createdAt ?? DateTime.utc(2026, 8, 14, 10, 30, 5);
    return IntakeLogsCompanion.insert(
      id: id,
      regimenId: regimenId,
      slotId: slotId,
      date: date ?? DateTime.utc(2026, 8, 14),
      status: DoseStatus.pending,
      createdAt: now,
      updatedAt: now,
    );
  }

  group('SyncColumns introspection (DATA-02)', () {
    test('all four tables exist', () {
      expect(db.allTables.map((t) => t.actualTableName).toSet(), {
        'supplements',
        'regimens',
        'regimen_slots',
        'intake_logs',
      });
    });

    test(
        'every table has id, created_at, updated_at, deleted_at '
        'and primary key exactly {id}', () {
      for (final table in db.allTables) {
        final columns = table.columnsByName.keys.toSet();
        expect(
          columns,
          containsAll(<String>['id', 'created_at', 'updated_at', 'deleted_at']),
          reason: '${table.actualTableName} is missing a SyncColumns column',
        );
        expect(
          table.$primaryKey.map((c) => c.name).toSet(),
          {'id'},
          reason: '${table.actualTableName} primary key must be exactly {id}',
        );
      }
    });
  });

  group('IntakeLogs unique key (slotId, date)', () {
    test('duplicate (slotId, date) with insert-or-ignore leaves one row',
        () async {
      await db.into(db.intakeLogs).insert(log(id: 'log-1'));

      // Same (slotId, date), different id — must be silently ignored.
      await db
          .into(db.intakeLogs)
          .insert(log(id: 'log-2'), mode: InsertMode.insertOrIgnore);

      final rows = await db.select(db.intakeLogs).get();
      expect(rows.length, 1);
      expect(rows.single.id, 'log-1');
    });
  });

  group('UTC round-trip (text-based datetime storage)', () {
    test('date reads back as DateTime.utc(2026, 8, 14) with isUtc true',
        () async {
      await db.into(db.intakeLogs).insert(log(id: 'log-1'));

      final row = (await db.select(db.intakeLogs).get()).single;
      expect(row.date.isUtc, isTrue);
      expect(row.date, DateTime.utc(2026, 8, 14));
    });

    test('createdAt round-trips the exact UTC instant supplied', () async {
      final instant = DateTime.utc(2026, 8, 14, 10, 30, 5);
      await db.into(db.intakeLogs).insert(log(id: 'log-1', createdAt: instant));

      final row = (await db.select(db.intakeLogs).get()).single;
      expect(row.createdAt.isUtc, isTrue);
      expect(row.createdAt, instant);
    });
  });

  group('Soft delete', () {
    test('freshly-inserted row has deletedAt null', () async {
      await db.into(db.intakeLogs).insert(log(id: 'log-1'));

      final row = (await db.select(db.intakeLogs).get()).single;
      expect(row.deletedAt, isNull);
    });
  });
}
