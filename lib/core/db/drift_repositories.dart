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

import 'dart:async';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../domain/cycle_math.dart';
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

  /// Cascade soft delete (STACK-04, T-02-01): one transaction stamping the
  /// supplement, its active regimens, their active slots, and every PENDING
  /// IntakeLog dated [fromDay] or later. Taken/skipped rows and past pending
  /// rows keep `deletedAt` null — history is never touched. Stamping logs is
  /// safe here (unlike pause, PF-1) precisely because deletion is permanent.
  @override
  Future<void> softDeleteCascade(String supplementId,
          {required DateTime fromDay}) =>
      db.transaction(() async {
        final now = DateTime.now().toUtc();
        final day = dateOnly(fromDay);

        await (db.update(db.supplements)
              ..where((t) => t.id.equals(supplementId)))
            .write(SupplementsCompanion(
          deletedAt: Value(now),
          updatedAt: Value(now),
        ));

        final regimenRows = await (db.select(db.regimens)
              ..where((t) =>
                  t.supplementId.equals(supplementId) & t.deletedAt.isNull()))
            .get();
        final regimenIds = [for (final r in regimenRows) r.id];

        await (db.update(db.regimens)..where((t) => t.id.isIn(regimenIds)))
            .write(RegimensCompanion(
          deletedAt: Value(now),
          updatedAt: Value(now),
        ));

        await (db.update(db.regimenSlots)
              ..where((t) =>
                  t.regimenId.isIn(regimenIds) & t.deletedAt.isNull()))
            .write(RegimenSlotsCompanion(
          deletedAt: Value(now),
          updatedAt: Value(now),
        ));

        // IntakeLogs carries regimenId directly — no join needed.
        await (db.update(db.intakeLogs)
              ..where((t) =>
                  t.regimenId.isIn(regimenIds) &
                  t.date.isBiggerOrEqualValue(day) &
                  t.status.equalsValue(domain.DoseStatus.pending) &
                  t.deletedAt.isNull()))
            .write(IntakeLogsCompanion(
          deletedAt: Value(now),
          updatedAt: Value(now),
        ));
      });
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

/// Drift implementation of [IntakeRepository].
class DriftIntakeRepository implements IntakeRepository {
  DriftIntakeRepository(this.db, {RegimenRepository? regimens})
      : _regimens = regimens ?? DriftRegimenRepository(db);

  final BoostqueDb db;

  /// Regimen source consumed via the interface, not the concrete class —
  /// repositories depend on repository contracts just like UI/state code does.
  final RegimenRepository _regimens;

  /// Idempotent materialization (D-22, RESEARCH Pattern 3).
  ///
  /// Inserts one pending IntakeLog per active slot for the calendar day of
  /// [day] using `InsertMode.insertOrIgnore`: the unique (slotId, date) key
  /// makes re-runs free, and — critically — an existing row's status is NEVER
  /// touched (upsert modes are prohibited in this method; RESEARCH Pitfall 4).
  /// The batch runs as a single transaction, so an interruption mid-write
  /// leaves no partial multi-row state (DATA-02/concurrency).
  ///
  /// [isActiveOn] is the ONLY activity decision point — cycle/course/paused
  /// logic lives solely in core/domain/cycle_math.dart.
  @override
  Future<void> ensureLogsForDay(DateTime day) async {
    final utcDay = dateOnly(day);
    final now = DateTime.now().toUtc();
    // Active regimens with their active slots, via the regimen repository's
    // canonical soft-delete-aware query.
    final regimens = await _firstEvent(_regimens.watchAll());

    final entries = <IntakeLogsCompanion>[
      for (final r in regimens)
        if (isActiveOn(r, utcDay))
          for (final slot in r.slots)
            IntakeLogsCompanion.insert(
              id: const Uuid().v4(),
              regimenId: r.id,
              slotId: slot.id,
              date: utcDay,
              status: domain.DoseStatus.pending,
              createdAt: now,
              updatedAt: now,
            ),
    ];
    await db.batch((b) {
      b.insertAll(db.intakeLogs, entries, mode: InsertMode.insertOrIgnore);
    });
  }

  @override
  Future<void> setStatus(String logId, domain.DoseStatus status) async {
    final now = DateTime.now().toUtc();
    await (db.update(db.intakeLogs)..where((t) => t.id.equals(logId))).write(
      IntakeLogsCompanion(status: Value(status), updatedAt: Value(now)),
    );
  }

  @override
  Stream<List<DayDose>> watchDay(DateTime day) {
    final utcDay = dateOnly(day);
    final query = db.select(db.intakeLogs).join([
      innerJoin(
        db.regimenSlots,
        db.regimenSlots.id.equalsExp(db.intakeLogs.slotId),
      ),
      innerJoin(
        db.regimens,
        db.regimens.id.equalsExp(db.intakeLogs.regimenId),
      ),
      innerJoin(
        db.supplements,
        db.supplements.id.equalsExp(db.regimens.supplementId),
      ),
    ])
      // Pause filter (REGI-04, PF-1): the ONE excluded combination is
      // paused-and-pending — taken/skipped history stays visible while a
      // regimen is paused, and resuming restores pending doses with zero
      // writes. Soft-deleted log rows are excluded outright.
      ..where(db.intakeLogs.date.equals(utcDay) &
          db.intakeLogs.deletedAt.isNull() &
          db.regimens.deletedAt.isNull() &
          db.supplements.deletedAt.isNull() &
          (db.regimens.paused.equals(false) |
              db.intakeLogs.status
                  .equalsValue(domain.DoseStatus.pending)
                  .not()))
      ..orderBy([
        OrderingTerm.asc(db.regimenSlots.minutesFromMidnight),
        OrderingTerm.asc(db.intakeLogs.id),
      ]);

    return query.watch().map((rows) => rows.map((row) {
          final log = row.readTable(db.intakeLogs);
          final slotRow = row.readTable(db.regimenSlots);
          final regimenRow = row.readTable(db.regimens);
          final supplementRow = row.readTable(db.supplements);
          final slot = domain.DoseSlot(
            id: slotRow.id,
            minutesFromMidnight: slotRow.minutesFromMidnight,
            doseLabel: slotRow.doseLabel,
          );
          return DayDose(
            logId: log.id,
            supplement: _toSupplement(supplementRow),
            // The embedded regimen carries the dose's own slot as context;
            // full slot sets come from RegimenRepository.watchAll.
            regimen: _toRegimen(regimenRow, [slot]),
            slot: slot,
            status: log.status,
          );
        }).toList());
  }
}

/// The first event of [stream], WITHOUT awaiting the subscription's cancel.
///
/// `Stream.first` completes only after `cancel()` resolves, and Drift defers a
/// query-stream close through a timer that never settles inside flutter_test's
/// fake-async zone — so `await someQuery.watch().first` deadlocks any widget
/// test that materializes a day through `ensureLogsForDay` (found wiring the
/// plan 03-01 tracer; the Phase-2 tests hit the same wall from the other side,
/// see the "awaiting .first un-pumped deadlocks" note in stack_screen_test).
/// Cancelling un-awaited is equivalent here: the value is already in hand and
/// the subscription is single-use.
Future<T> _firstEvent<T>(Stream<T> stream) {
  final completer = Completer<T>();
  late StreamSubscription<T> sub;
  sub = stream.listen(
    (value) {
      if (completer.isCompleted) return;
      completer.complete(value);
      unawaited(sub.cancel());
    },
    onError: (Object error, StackTrace stackTrace) {
      if (completer.isCompleted) return;
      completer.completeError(error, stackTrace);
      unawaited(sub.cancel());
    },
    onDone: () {
      if (completer.isCompleted) return;
      completer.completeError(
        StateError('stream closed before emitting a value'),
      );
    },
  );
  return completer.future;
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
