/// Drift-backed repository implementations (D-22, D-26).
///
/// The only layer that touches [BoostqueDb]. UI/state code depends on the
/// interfaces in `core/domain/repositories.dart`; these classes are wired in
/// via `core/providers.dart`.
///
/// Persistence rules enforced here:
/// - Soft delete only: rows are hidden by stamping `deletedAt`, never removed
///   (DATA-02). No Drift delete statement appears in this file.
/// - Every mutation bumps `updatedAt` to now-UTC at this boundary; `createdAt`
///   is set on first insert only (T-01-16). Domain code never reads the clock.
/// - List queries filter `deletedAt IS NULL` and order by `createdAt` asc with
///   `id` asc as tiebreak (DATA-01/ordering).
/// - Fully offline: only local file/memory I/O, no network (D-26, DATA-01).
library;

import 'package:drift/drift.dart';

import '../domain/models.dart' as domain;
import '../domain/repositories.dart';
import 'database.dart';

/// Drift implementation of [SupplementRepository].
class DriftSupplementRepository implements SupplementRepository {
  DriftSupplementRepository(this.db);

  final BoostqueDb db;

  @override
  Stream<List<domain.Supplement>> watchAll() => (db.select(db.supplements)
        ..where((t) => t.deletedAt.isNull())
        ..orderBy([
          (t) => OrderingTerm.asc(t.createdAt),
          (t) => OrderingTerm.asc(t.id),
        ]))
      .watch()
      .map((rows) => rows.map(_toSupplement).toList());

  @override
  Future<void> upsert(domain.Supplement s) async {
    final now = DateTime.now().toUtc();
    final existing = await (db.select(db.supplements)
          ..where((t) => t.id.equals(s.id)))
        .getSingleOrNull();
    await db.into(db.supplements).insertOnConflictUpdate(SupplementsCompanion(
          id: Value(s.id),
          name: Value(s.name),
          doseText: Value(s.doseText),
          colorValue: Value(s.colorValue),
          note: Value(s.note),
          createdAt: Value(existing?.createdAt ?? now),
          updatedAt: Value(now),
          deletedAt: const Value(null),
        ));
  }

  @override
  Future<void> softDelete(String id) async {
    final now = DateTime.now().toUtc();
    await (db.update(db.supplements)..where((t) => t.id.equals(id))).write(
      SupplementsCompanion(deletedAt: Value(now), updatedAt: Value(now)),
    );
  }
}

/// Drift implementation of [RegimenRepository].
class DriftRegimenRepository implements RegimenRepository {
  DriftRegimenRepository(this.db);

  final BoostqueDb db;

  /// Active regimens left-joined with their active slots, deterministically
  /// ordered (regimen createdAt/id, then slot minutesFromMidnight/id).
  JoinedSelectStatement<HasResultSet, dynamic> _joined() =>
      db.select(db.regimens).join([
        leftOuterJoin(
          db.regimenSlots,
          db.regimenSlots.regimenId.equalsExp(db.regimens.id) &
              db.regimenSlots.deletedAt.isNull(),
        ),
      ])
        ..where(db.regimens.deletedAt.isNull())
        ..orderBy([
          OrderingTerm.asc(db.regimens.createdAt),
          OrderingTerm.asc(db.regimens.id),
          OrderingTerm.asc(db.regimenSlots.minutesFromMidnight),
          OrderingTerm.asc(db.regimenSlots.id),
        ]);

  @override
  Stream<List<domain.Regimen>> watchAll() => _joined().watch().map(_groupRows);

  @override
  Future<domain.Regimen?> findForSupplement(String supplementId) async {
    final rows = await (_joined()
          ..where(db.regimens.supplementId.equals(supplementId)))
        .get();
    final regimens = _groupRows(rows);
    return regimens.isEmpty ? null : regimens.first;
  }

  @override
  Future<void> upsert(domain.Regimen r) => db.transaction(() async {
        final now = DateTime.now().toUtc();
        final existing = await (db.select(db.regimens)
              ..where((t) => t.id.equals(r.id)))
            .getSingleOrNull();
        await db.into(db.regimens).insertOnConflictUpdate(RegimensCompanion(
              id: Value(r.id),
              supplementId: Value(r.supplementId),
              kind: Value(r.kind),
              startDate: Value(r.startDate),
              endDate: Value(r.endDate),
              onDays: Value(r.onDays),
              offDays: Value(r.offDays),
              paused: Value(r.paused),
              createdAt: Value(existing?.createdAt ?? now),
              updatedAt: Value(now),
              deletedAt: const Value(null),
            ));

        // Reconcile slots: upsert the incoming set (reviving soft-deleted
        // ids), then soft-delete previously-active slots that are no longer
        // present. Row removal is prohibited (DATA-02) — replaced slot rows
        // survive with deletedAt stamped.
        final existingSlots = await (db.select(db.regimenSlots)
              ..where((t) => t.regimenId.equals(r.id)))
            .get();
        final existingById = {for (final s in existingSlots) s.id: s};
        for (final slot in r.slots) {
          await db.into(db.regimenSlots).insertOnConflictUpdate(
                RegimenSlotsCompanion(
                  id: Value(slot.id),
                  regimenId: Value(r.id),
                  minutesFromMidnight: Value(slot.minutesFromMidnight),
                  doseLabel: Value(slot.doseLabel),
                  createdAt: Value(existingById[slot.id]?.createdAt ?? now),
                  updatedAt: Value(now),
                  deletedAt: const Value(null),
                ),
              );
        }
        final incomingIds = r.slots.map((s) => s.id).toList();
        await (db.update(db.regimenSlots)
              ..where((t) =>
                  t.regimenId.equals(r.id) &
                  t.deletedAt.isNull() &
                  t.id.isNotIn(incomingIds)))
            .write(RegimenSlotsCompanion(
          deletedAt: Value(now),
          updatedAt: Value(now),
        ));
      });

  @override
  Future<void> setPaused(String regimenId, bool paused) async {
    final now = DateTime.now().toUtc();
    await (db.update(db.regimens)..where((t) => t.id.equals(regimenId))).write(
      RegimensCompanion(paused: Value(paused), updatedAt: Value(now)),
    );
  }

  @override
  Future<void> softDelete(String regimenId) async {
    final now = DateTime.now().toUtc();
    await (db.update(db.regimens)..where((t) => t.id.equals(regimenId))).write(
      RegimensCompanion(deletedAt: Value(now), updatedAt: Value(now)),
    );
  }

  List<domain.Regimen> _groupRows(List<TypedResult> rows) {
    final order = <String>[];
    final regimenRows = <String, Regimen>{};
    final slotsById = <String, List<domain.DoseSlot>>{};
    for (final row in rows) {
      final r = row.readTable(db.regimens);
      if (!regimenRows.containsKey(r.id)) {
        order.add(r.id);
        regimenRows[r.id] = r;
        slotsById[r.id] = [];
      }
      final s = row.readTableOrNull(db.regimenSlots);
      if (s != null) {
        slotsById[r.id]!.add(domain.DoseSlot(
          id: s.id,
          minutesFromMidnight: s.minutesFromMidnight,
          doseLabel: s.doseLabel,
        ));
      }
    }
    return [
      for (final id in order) _toRegimen(regimenRows[id]!, slotsById[id]!),
    ];
  }
}

domain.Supplement _toSupplement(Supplement row) => domain.Supplement(
      id: row.id,
      name: row.name,
      doseText: row.doseText,
      colorValue: row.colorValue,
      note: row.note,
    );

domain.Regimen _toRegimen(Regimen row, List<domain.DoseSlot> slots) =>
    domain.Regimen(
      id: row.id,
      supplementId: row.supplementId,
      kind: row.kind,
      startDate: row.startDate,
      endDate: row.endDate,
      onDays: row.onDays,
      offDays: row.offDays,
      paused: row.paused,
      slots: slots,
    );
