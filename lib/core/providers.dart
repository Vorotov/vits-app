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
import 'domain/cycle_math.dart' show dateOnly;
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

/// Materialized doses for one calendar day — the app's materialization choke
/// point and the ONLY production caller of `ensureLogsForDay` / consumer of
/// `watchDay` (PF-3).
///
/// autoDispose (the exception D-23 permits for screen-scoped state): every
/// browsed day opens a Drift subscription, and keeping them alive would leak
/// one per day the user ever looks at.
///
/// [day] MUST be a `dateOnly()` UTC value — it is the family cache key, so a
/// non-normalized key silently forks the cache into a phantom day (PF-1); the
/// assert is the backstop, all keys originate from `resolvedDayProvider`.
final dayDosesProvider = StreamProvider.autoDispose
    .family<List<DayDose>, DateTime>((ref, day) async* {
  assert(
    day == dateOnly(day),
    'dayDosesProvider key must be a dateOnly() UTC value (PF-1), got: $day',
  );
  // Watching the regimens stream re-runs this build on any regimen
  // add/edit/pause/resume/delete, so the day re-materializes with no
  // imperative refresh call anywhere in the app.
  ref.watch(regimensStreamProvider);
  final intake = ref.watch(intakeRepoProvider);
  // Idempotent insert-or-ignore: re-running never duplicates a row and never
  // resets an existing status, so calling it on every rebuild is free.
  await intake.ensureLogsForDay(day);
  yield* intake.watchDay(day);
});

/// The same day's doses, READ-ONLY: it never calls `ensureLogsForDay`.
///
/// The week strip needs one bit per day (is every dose handled?) to colour a
/// 4px dot. Reading that through [dayDosesProvider] made a cosmetic dot the
/// app's biggest writer: each week the pager passed through materialized
/// 7 days × slots of IntakeLog rows, so the database grew with pager travel
/// rather than with user intent — up to ~371 days for a strip the user may
/// never have looked at (WR-06).
///
/// The dot reads exactly the same rows; it just does not create them. Days
/// that were never materialized have no rows and are therefore "not fully
/// handled" — which is what the neutral dot already meant for them.
///
/// Same `dateOnly()` UTC key rule as [dayDosesProvider] (PF-1).
final dayDosesReadOnlyProvider = StreamProvider.autoDispose
    .family<List<DayDose>, DateTime>((ref, day) {
  assert(
    day == dateOnly(day),
    'dayDosesReadOnlyProvider key must be a dateOnly() UTC value (PF-1), '
    'got: $day',
  );
  // Re-runs on any regimen add/edit/pause/resume/delete, exactly like the
  // materializing provider — the dot must not go stale.
  ref.watch(regimensStreamProvider);
  return ref.watch(intakeRepoProvider).watchDay(day);
});

/// Re-subscribes the two streams the stack is derived from.
///
/// The ONE recovery path behind every "try again" control that reads
/// [stackEntriesProvider]. It names the STREAM providers deliberately:
/// [stackEntriesProvider] is a plain `Provider` with no subscription of its
/// own, and Riverpod invalidation propagates to dependents, never to
/// dependencies — so invalidating the derivation re-runs its body against the
/// same two errored streams and returns the same error. A retry that targets
/// the derivation is a button that cannot work (CR-02).
///
/// Living here rather than in a screen keeps Interaction Contract 6 intact:
/// the planner reaches [stackEntriesProvider] and `todayProvider` and nothing
/// else from the core graph, and calls this named path to recover.
void retryStack(WidgetRef ref) {
  ref.invalidate(supplementsStreamProvider);
  ref.invalidate(regimensStreamProvider);
}

/// Supplements paired with their regimens — the Stack tab's row list.
///
/// Provider composition (RESEARCH Pattern 5): watches both stream providers
/// and merges their AsyncValues; Riverpod re-runs this whenever either
/// underlying Drift stream emits. Loading/error states propagate from
/// whichever source is not ready yet.
///
/// `skipLoadingOnReload: true` on BOTH merges is load-bearing, not stylistic.
/// Riverpod 3 reports a failing stream as an `AsyncLoading` that CARRIES the
/// error while it retries on its own backoff, and `when` defaults
/// `skipLoadingOnReload` to false — so without these two arguments this
/// derivation collapses a retrying failure into a plain `AsyncLoading` with no
/// error at all, and every screen downstream (Stack directly, the planner via
/// `whenData`, whose loading arm drops the error outright) is structurally
/// unable to render its designed error surface for the whole ~38.2s window,
/// no matter what rendering rule it uses (A1 / P-9, 04-REVIEW.md CR-02).
final stackEntriesProvider = Provider<AsyncValue<List<StackEntry>>>((ref) {
  final supplements = ref.watch(supplementsStreamProvider);
  final regimens = ref.watch(regimensStreamProvider);
  return supplements.when(
    skipLoadingOnReload: true,
    data: (s) => regimens.when(
      skipLoadingOnReload: true,
      data: (r) => AsyncData(combineStackEntries(s, r)),
      loading: () => const AsyncLoading(),
      error: AsyncError.new,
    ),
    loading: () => const AsyncLoading(),
    error: AsyncError.new,
  );
});
