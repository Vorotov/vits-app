/// Riverpod provider graph for Boostque (D-22, D-23).
///
/// ## Dispose policy (D-23) — decided once for the whole app, recorded here
///
/// Repository-level providers and StreamProviders in this file are
/// intentionally NOT autoDispose: they are app-lifetime, cheap to keep warm,
/// and shared across all three tabs — disposing and re-creating them on tab
/// switches would only churn Drift stream subscriptions for no benefit.
/// Screen-scoped state in `features/` MAY be autoDispose. This file is the
/// single place this policy is recorded; do not re-litigate it per provider.
///
/// ## Composition (RESEARCH Pattern 5)
///
/// Combining supplements + regimens uses Riverpod provider composition — a
/// derived provider watching two StreamProviders' AsyncValues. No hand-rolled
/// stream combinators, no reactive-extensions package: Riverpod's dependency
/// graph re-runs the derived provider whenever either stream emits.
///
/// UI and state code depend on the interfaces from
/// `core/domain/repositories.dart` only (D-22); the Drift implementations are
/// wired in here and nowhere else.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'db/database.dart' show BoostqueDb;
import 'db/drift_repositories.dart';
import 'domain/models.dart';
import 'domain/repositories.dart';

/// The app database. Lazy: constructed only when first watched, so code
/// paths that never touch persistence (the Phase-1 shell, widget tests)
/// never open the on-disk file (D-19). Overridden with an in-memory
/// database in tests.
final dbProvider = Provider<BoostqueDb>((ref) {
  final db = BoostqueDb.open();
  ref.onDispose(db.close);
  return db;
});

/// Supplement persistence, typed against the domain interface (D-22).
final supplementRepoProvider = Provider<SupplementRepository>(
  (ref) => DriftSupplementRepository(ref.watch(dbProvider)),
);

/// Regimen persistence, typed against the domain interface (D-22).
final regimenRepoProvider = Provider<RegimenRepository>(
  (ref) => DriftRegimenRepository(ref.watch(dbProvider)),
);

/// Intake-log persistence, typed against the domain interface (D-22).
final intakeRepoProvider = Provider<IntakeRepository>(
  (ref) => DriftIntakeRepository(
    ref.watch(dbProvider),
    regimens: ref.watch(regimenRepoProvider),
  ),
);

/// Active supplements, live from the database (NOT autoDispose per D-23).
final supplementsStreamProvider = StreamProvider<List<Supplement>>(
  (ref) => ref.watch(supplementRepoProvider).watchAll(),
);

/// Active regimens with slots, live from the database (NOT autoDispose
/// per D-23).
final regimensStreamProvider = StreamProvider<List<Regimen>>(
  (ref) => ref.watch(regimenRepoProvider).watchAll(),
);

/// Supplements paired with their regimens — the Stack tab's row list.
///
/// Provider composition (RESEARCH Pattern 5): watches both stream providers
/// and merges their AsyncValues; Riverpod re-runs this whenever either
/// underlying Drift stream emits. Loading/error states propagate from
/// whichever source is not ready yet.
final stackEntriesProvider = Provider<AsyncValue<List<StackEntry>>>((ref) {
  final supplements = ref.watch(supplementsStreamProvider);
  final regimens = ref.watch(regimensStreamProvider);
  return supplements.when(
    data: (s) => regimens.when(
      data: (r) => AsyncData(combineStackEntries(s, r)),
      loading: () => const AsyncLoading(),
      error: AsyncError.new,
    ),
    loading: () => const AsyncLoading(),
    error: AsyncError.new,
  );
});
