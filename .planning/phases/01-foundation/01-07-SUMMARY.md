---
phase: 01-foundation
plan: 07
subsystem: database
tags: [drift, riverpod, repositories, materialization, soft-delete, uuid]

requires:
  - phase: 01-foundation (01-02)
    provides: Domain models (Supplement/Regimen/DoseSlot, enums) and DST-safe cycle math (dateOnly, isActiveOn)
  - phase: 01-foundation (01-05)
    provides: Sync-ready Drift schema (SyncColumns, IntakeLogs unique (slotId, date), BoostqueDb.forTesting/open)
provides:
  - SupplementRepository / RegimenRepository / IntakeRepository interfaces + StackEntry / DayDose view models + combineStackEntries (core/domain, pure Dart)
  - DriftSupplementRepository / DriftRegimenRepository / DriftIntakeRepository — soft-delete-only, updatedAt-bumping, deterministically ordered
  - Idempotent ensureLogsForDay materialization (isActiveOn-gated, batch insertOrIgnore, status-preserving)
  - Riverpod provider graph (dbProvider, repo providers, stream providers, stackEntriesProvider) with documented D-23 dispose policy
affects: [02-stack, 03-daily-tracking, 04-planners, 05-l10n]

actuals:
  tokens: 8250
  tasks: 3
  commits: 6

tech-stack:
  added: []
  patterns:
    - Repository interfaces in core/domain, Drift impls in core/db; UI depends on interfaces only (D-22)
    - Soft delete only — mutations stamp deletedAt/updatedAt, no Drift delete statements anywhere
    - Deterministic ordering — createdAt asc with id asc tiebreak on every list query; equal updatedAt resolves by id (future LWW sync contract)
    - Materialization uses InsertMode.insertOrIgnore exclusively; insertOnConflictUpdate reserved for supplement/regimen upserts
    - Provider composition (nested AsyncValue.when) instead of stream combinators; repository-level providers NOT autoDispose (D-23)

key-files:
  created:
    - lib/core/domain/repositories.dart
    - lib/core/db/drift_repositories.dart
    - lib/core/providers.dart
    - test/db/repositories_test.dart
    - test/providers_test.dart
  modified: []

key-decisions:
  - "Upserts preserve createdAt by reading the existing row first inside the upsert (insertOnConflictUpdate with explicit companion), so createdAt is set on first insert only"
  - "Upserting a soft-deleted supplement/regimen/slot revives it (deletedAt cleared) — an upsert makes the entity active by definition"
  - "DayDose.regimen embeds only the dose's own slot as context; full slot sets come from RegimenRepository.watchAll"
  - "combineStackEntries pairs first-created regimen per supplement when multiple exist (deterministic via regimen list order)"

patterns-established:
  - "Domain-name clash handling: drift_repositories.dart imports domain models with `as domain` prefix since generated row classes share names (Supplement/Regimen)"
  - "Riverpod 3 tests keep a container.listen subscription alive — unlistened providers pause and stop recomputing"

requirements-completed: [DATA-01, DATA-02]

coverage:
  - id: D1
    description: "Repository interfaces + StackEntry/DayDose view models + combineStackEntries in pure-Dart core/domain"
    requirement: DATA-01
    verification:
      - kind: unit
        ref: "test/db/repositories_test.dart#fresh database (DATA-01/empty)"
        status: pass
      - kind: other
        ref: "grep gate: no package:drift import under lib/core/domain/"
        status: pass
    human_judgment: false
  - id: D2
    description: "Drift supplement/regimen repositories: upsert, soft-delete-only, deterministic ordering, atomic slot reconciliation"
    requirement: DATA-02
    verification:
      - kind: unit
        ref: "test/db/repositories_test.dart#SupplementRepository + RegimenRepository groups (8 tests)"
        status: pass
      - kind: other
        ref: "grep gates: transaction present; no .delete( calls in drift_repositories.dart"
        status: pass
    human_judgment: false
  - id: D3
    description: "Idempotent ensureLogsForDay materialization — insertOrIgnore, isActiveOn gating, status preservation, same-minute slots, watchDay ordering"
    requirement: DATA-01
    verification:
      - kind: unit
        ref: "test/db/repositories_test.dart#IntakeRepository group (6 tests)"
        status: pass
      - kind: other
        ref: "region-scoped gate: no insertOnConflictUpdate inside ensureLogsForDay"
        status: pass
    human_judgment: false
  - id: D4
    description: "Riverpod provider graph typed against interfaces with documented NOT-autoDispose policy and provider-composition stackEntriesProvider"
    verification:
      - kind: unit
        ref: "test/providers_test.dart (3 tests)"
        status: pass
      - kind: other
        ref: "grep gates: 'NOT autoDispose' present; no .autoDispose, no StreamController, no rxdart"
        status: pass
    human_judgment: false
  - id: D5
    description: "Fresh install launches to the three-tab shell with no errors and empty data; boostque.sqlite lands in app-documents (phase-end human check)"
    requirement: DATA-01
    verification: []
    human_judgment: true
    rationale: "Requires launching the app on a wiped simulator/emulator and visually confirming shell + backgrounding behavior — no automated test covers the full-app half"

duration: 10min
completed: 2026-08-14
status: complete
---

# Phase 1 Plan 07: Repositories, Materialization & Provider Graph Summary

**Soft-delete-only Drift repositories behind pure-Dart interfaces, idempotent status-preserving dose materialization via batch insertOrIgnore, and a Riverpod provider graph combining streams through provider composition**

## Performance

- **Duration:** 10 min
- **Started:** 2026-08-14T18:10:33Z
- **Completed:** 2026-08-14T18:20:46Z
- **Tasks:** 3 (all TDD)
- **Files modified:** 5 created

## Accomplishments

- Repository contracts locked for Phases 2-5: `SupplementRepository`/`RegimenRepository`/`IntakeRepository` + `StackEntry`/`DayDose` view models in `core/domain`, with the LWW sync-determinism rule (equal updatedAt resolves by id) documented at the interface
- Drift implementations enforce every DATA-02 invariant: no delete statements anywhere, every mutation bumps updatedAt to now-UTC at the repository boundary, createdAt set on first insert only, list queries ordered createdAt asc / id asc
- Regimen upsert reconciles slots atomically in a transaction — incoming slots upserted (revived if soft-deleted), removed slots stamped with deletedAt, rows never removed
- `ensureLogsForDay` is idempotent and cycle-correct: `isActiveOn` is the single activity decision point, batch `InsertMode.insertOrIgnore` against unique (slotId, date) makes re-runs free and never resets a recorded taken/skipped status (RESEARCH Pitfall 4 regression-tested); same-minute slots produce distinct rows
- Provider graph wires interfaces to implementations lazily; `stackEntriesProvider` combines supplements + regimens via nested `AsyncValue.when` provider composition (no stream combinators, no rxdart); D-23 dispose policy recorded once in the file header
- Full phase suite green: `flutter analyze` 0 issues, `flutter test` 79/79 (phase exit criterion D-27)

## Task Commits

Each TDD task produced RED + GREEN commits:

1. **Task 1: Repository interfaces + Supplement/Regimen Drift impls** — `2daed1a` (test), `21fa76b` (feat)
2. **Task 2: DriftIntakeRepository idempotent materialization** — `e953b6e` (test), `1c642f8` (feat)
3. **Task 3: Riverpod provider graph + dispose policy** — `59b9270` (test), `9049276` (feat)

_No refactor commits — implementations came out clean on GREEN._

## Files Created/Modified

- `lib/core/domain/repositories.dart` — interfaces, StackEntry/DayDose, combineStackEntries, ordering/LWW doc
- `lib/core/db/drift_repositories.dart` — three Drift repositories incl. ensureLogsForDay/setStatus/watchDay
- `lib/core/providers.dart` — dbProvider, repo providers, stream providers, stackEntriesProvider, D-23 policy
- `test/db/repositories_test.dart` — 15 tests: empty/ordering/soft-delete/upsert/slot-reconciliation/materialization/idempotence/off-day/status-preservation/same-minute/watchDay-ordering
- `test/providers_test.dart` — 3 tests: interface typing, fresh-install empty AsyncData, upsert flowing into stackEntries

## Decisions Made

- Upserts read the existing row first (inside the regimen transaction) so `insertOnConflictUpdate` can preserve createdAt while still being a true single-statement upsert
- Upsert revives soft-deleted rows (deletedAt cleared) — consistent with slot revival mandated by the plan
- `DayDose.regimen.slots` carries just the joined slot as context rather than the full slot set (avoids extra queries per row; full sets come from `RegimenRepository.watchAll`)
- `watchDay` does not filter soft-deleted slots — a materialized log for a since-replaced slot remains visible history (plan specified filtering regimens/supplements only)

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

- Riverpod 3.x removed `AsyncValue.valueOrNull` — test helper switched to an `AsyncData(value:)` pattern match
- Riverpod 3 pauses unlistened providers: the fresh-install provider test needed a live `container.listen` subscription for the derived provider to recompute on stream emissions (recorded as a pattern for future provider tests)
- Generated Drift row classes share names with domain models (`Supplement`, `Regimen`) — resolved with an `as domain` import prefix in `drift_repositories.dart` and `show`-scoped imports in `providers.dart`

## TDD Gate Compliance

All three tasks have RED (`test(01-07):`) commits preceding GREEN (`feat(01-07):`) commits; each RED run failed (missing implementation) and each GREEN run passed. No refactor phase needed.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Phase 1 is fully executed: 7/7 plans have summaries; `flutter analyze` clean and `flutter test` 79/79 green (D-27)
- Phases 2-3 can code against the repository interfaces and provider graph verbatim (superpowers plan Task 6 shapes preserved exactly)
- Outstanding phase-end human check (plan `<verification>`): launch on a wiped simulator/emulator — three-tab shell opens with no errors/data, background/foreground survives, `boostque.sqlite` in app-documents
- REQUIREMENTS.md/ROADMAP.md tracking sync left to the orchestrator (node unavailable in this session); DATA-01/DATA-02 declaring plans are now all complete

---
*Phase: 01-foundation*
*Completed: 2026-08-14*

## Self-Check: PASSED

All 6 key files exist on disk; all 6 task commits (2daed1a, 21fa76b, e953b6e, 1c642f8, 59b9270, 9049276) present in git log; full suite re-verified green (79/79) with flutter analyze clean.
