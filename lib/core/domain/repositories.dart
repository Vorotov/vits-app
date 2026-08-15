/// Repository contracts and view models for Boostque (D-22).
///
/// Pure Dart: imports only the domain models — no Flutter, no Drift, no I/O.
/// UI and state code (Phases 2-5) depend exclusively on these interfaces;
/// `lib/core/db/drift_repositories.dart` provides the Drift-backed
/// implementations.
///
/// Ordering and sync determinism (DATA-01/ordering, DATA-02/ordering):
/// - Every list query orders by `createdAt` ascending with `id` (lexicographic)
///   as the tiebreak, so equal timestamps resolve deterministically.
/// - The same rule is the future last-write-wins sync contract: when two rows
///   carry an equal `updatedAt`, the winner/order resolves by `id`
///   (lexicographic). Documented here now so LWW sync inherits it unchanged.
library;

import 'models.dart';

/// A supplement paired with its regimen (if any) — the Stack tab's row model.
class StackEntry {
  final Supplement supplement;
  final Regimen? regimen;

  const StackEntry({required this.supplement, this.regimen});
}

/// One materialized dose occurrence joined with its full context — the
/// Today/Calendar row model.
class DayDose {
  final String logId;
  final Supplement supplement;
  final Regimen regimen;
  final DoseSlot slot;
  final DoseStatus status;

  const DayDose({
    required this.logId,
    required this.supplement,
    required this.regimen,
    required this.slot,
    required this.status,
  });
}

/// Supplement persistence contract.
abstract class SupplementRepository {
  /// Active (non-soft-deleted) supplements, ordered by createdAt asc, id asc.
  Stream<List<Supplement>> watchAll();

  /// Inserts or updates by id. Sets `updatedAt` (and `createdAt` on first
  /// insert) at the repository boundary; clears any soft-delete marker.
  Future<void> upsert(Supplement s);

  /// Soft delete: stamps `deletedAt`, never removes the row (DATA-02).
  Future<void> softDelete(String id);

  /// Cascade soft delete: stamps `deletedAt` on the supplement, its active
  /// regimens and their slots, and every PENDING IntakeLog dated [fromDay]
  /// (UTC date-only) or later — one transaction, never removing a row
  /// (DATA-02). Past days and taken/skipped rows are never touched.
  /// [fromDay] is passed in by the caller as `dateOnly(DateTime.now())`
  /// because domain code never reads the clock.
  Future<void> softDeleteCascade(String supplementId,
      {required DateTime fromDay});
}

/// Regimen persistence contract. Slots are included on every read.
abstract class RegimenRepository {
  /// Active regimens with their active slots (sorted by minutesFromMidnight
  /// asc, id asc), ordered by createdAt asc, id asc.
  Stream<List<Regimen>> watchAll();

  /// The active regimen for [supplementId], slots included, or null.
  Future<Regimen?> findForSupplement(String supplementId);

  /// Inserts or updates the regimen and reconciles its slots atomically:
  /// incoming slots are upserted (reviving soft-deleted ids), previously
  /// active slots absent from the incoming set are soft-deleted.
  Future<void> upsert(Regimen r);

  /// Flips the paused flag, bumping `updatedAt`.
  Future<void> setPaused(String regimenId, bool paused);

  /// Soft delete: stamps `deletedAt`, never removes the row (DATA-02).
  Future<void> softDelete(String regimenId);
}

/// Intake-log persistence contract.
abstract class IntakeRepository {
  /// Materialized doses for the calendar day of [day], joined with slot,
  /// regimen, and supplement; ordered by slot minutesFromMidnight asc with
  /// log id asc as tiebreak. Soft-deleted parents are excluded.
  Stream<List<DayDose>> watchDay(DateTime day);

  /// Idempotently materializes one pending IntakeLog per active slot for the
  /// calendar day of [day]. Re-running never duplicates rows and never resets
  /// an existing row's status (insert-or-ignore on unique (slotId, date)).
  Future<void> ensureLogsForDay(DateTime day);

  /// Records a dose status, bumping `updatedAt`.
  Future<void> setStatus(String logId, DoseStatus status);
}

/// Pairs each supplement with its regimen by `supplementId`, preserving the
/// supplement order. Pure function — consumed by the combined stack provider
/// (RESEARCH Pattern 5 provider composition).
List<StackEntry> combineStackEntries(
  List<Supplement> supplements,
  List<Regimen> regimens,
) {
  final bySupplement = <String, Regimen>{
    for (final r in regimens.reversed) r.supplementId: r,
  };
  return [
    for (final s in supplements)
      StackEntry(supplement: s, regimen: bySupplement[s.id]),
  ];
}
