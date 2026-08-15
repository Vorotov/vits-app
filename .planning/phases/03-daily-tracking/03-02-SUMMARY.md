---
phase: 03-daily-tracking
plan: 02
subsystem: calendar
status: complete
tags: [view-model, pure-functions, cycle-math, tdd, track-04]
requires:
  - lib/core/domain/repositories.dart (DayDose)
  - lib/core/domain/cycle_math.dart (dateOnly, isActiveOn)
  - lib/core/db/drift_repositories.dart (ensureLogsForDay, watchDay)
provides:
  - blockStartsMinutes / blockIndexOf (the ONE time-block boundary definition)
  - DayBlock / groupIntoBlocks
  - doseCyclePosition (доза n з m)
  - isMissed / isOverdue
  - sealed BlockTag (AllTakenTag | AllMarkedTag | ProgressTag | MealTag) + blockTagOf
  - currentBlockIndex
  - dayRingCounts
affects:
  - plans 03-03 / 03-04 / 03-05 (the vocabulary the Today screen renders)
tech-stack:
  added: []
  patterns:
    - "stack_status.dart shape copied exactly: library doc-comment contract, three pure domain imports, clockless top-level functions, sealed result hierarchy with zero user-visible strings"
    - "Dart 3 record returns for multi-value pure results: ({int n, int m}), ({int taken, int total})"
key-files:
  created:
    - lib/features/calendar/day_view_model.dart
    - test/features/day_view_model_test.dart
    - test/db/materialization_boundaries_test.dart
  modified: []
decisions:
  - "ProgressTag.done counts taken doses only — skipped is marked but not done (UI-SPEC blockProgress = {taken} з {total})"
  - "'Passed' is strict everywhere: a dose exactly at nowMinutes is still due, so overdue, block-past and currentBlockIndex share one boundary rule"
  - "currentBlockIndex returns the block's blockIndex (0..3), not its position in the non-empty list — the header rule is bi == nowBlock"
  - "blockTagOf on an empty block returns MealTag (defensive; groupIntoBlocks never emits one)"
  - "doseCyclePosition falls back to (n:1) when the dose is absent from the day list rather than throwing — a renderer must never crash on a stale row"
metrics:
  duration: ~35 min
  completed: 2026-08-15
  tasks: 2
  tests_added: 38
actuals:
  tokens: 7852
  tasks: 2
  commits: 3
---

# Phase 3 Plan 02: Pure Day View-Model + TRACK-04 Materialization Gate Summary

Clockless, repository-free derivation of every rendering decision the Today screen makes — time-block grouping, `доза n з m` positions, missed/overdue predicates, block tags and ring counts — plus a date-pinned proof that the `ensureLogsForDay` → `watchDay` chain stays exact across Ukraine's 2026 DST transitions and the 2026/2027 year boundary.

## What Was Built

**`lib/features/calendar/day_view_model.dart` (new, 3 imports, 0 UI-framework references)**

- `blockStartsMinutes` — the single const holding the four block starts (DECIDED-1). The literals `720`, `1080` and `1320` appear nowhere else in the file, so moving a boundary is a one-line edit that the boundary tests catch.
- `blockIndexOf(minutes)` — scans the const from the end; a minute equal to a block start opens that block.
- `DayBlock` + `groupIntoBlocks` — non-empty blocks only, chronological, input slot-time order preserved inside each block, `earliestMinutes` reporting the earliest REAL slot time present (M5: never the mockup's 08:00/13:00/19:00/22:00 editor-default anchors).
- `doseCyclePosition(dayDoses, dose)` — groups the day's own list by `regimen.id`. `DayDose.regimen.slots` always holds exactly one slot in production (PF-6), and the test asserts that shape explicitly before asserting `m == 3`.
- `isMissed(d, viewedDay:, today:)` — the ONE missed rule: pending AND the viewed day strictly before today, both normalized through `dateOnly`. Pure predicate, no repository handle, no write path reachable from this library (T-03-05).
- `isOverdue(d, viewingToday:, nowMinutes:)` — gated on `viewingToday` first, so no warn-colored state is derivable for any other day (TRACK-03 neutrality, DECIDED-5).
- Sealed `BlockTag` (`AllTakenTag` / `AllMarkedTag` / `ProgressTag` / `MealTag`) + `blockTagOf` implementing the DECIDED-6 order exactly — a block containing skips can never claim they were taken.
- `currentBlockIndex(blocks, viewingToday:, nowMinutes:)` — the accent header rule; null off today and once every block of today has passed.
- `dayRingCounts(doses)` — taken vs every dose of the day, skipped counted as not-taken (DECIDED-7).

**`test/features/day_view_model_test.dart` (new, 32 tests)** — pure-function matrix in the `stack_status_test.dart` fixture-builder style. Both sides of 719/720, 1079/1080 and 1319/1320 asserted explicitly; every Phase-2 editor default (480, 630, 780, 960, 1140, 1320) plus the 1260 fallback pinned to its block; the PF-6 case asserts each embedded `regimen.slots` has length 1 while `m == 3`; `isOverdue` false for a past-day view at `nowMinutes: 1439`; `currentBlockIndex` null for non-today; PF-9 paused fixtures prove the helpers make no pause-specific decision.

**`test/db/materialization_boundaries_test.dart` (new, 6 tests)** — the TRACK-04 gate on the `pause_filter_test.dart` harness (in-memory Drift db, three repositories in `setUp`, closed in `tearDown`, fixtures seeded through the repositories so the production write path is exercised). Every day in a window is materialized **twice** then read from `watchDay`, with exact dose counts asserted (never "greater than zero") on 2026-10-25 (DST fall-back), 2026-03-29 (spring-forward), 2026-12-31, 2027-01-01, 2027-01-03 and 2027-01-04. One case marks a dose taken, re-materializes the same day, and asserts the same `logId`, still `taken`, with an unchanged row count (T-03-07). A multi-slot case asserts one dose per slot per active day in ascending slot-minute order.

## Verification

| Check | Result |
|-------|--------|
| `flutter test test/features/day_view_model_test.dart` | 32/32 pass |
| `flutter test test/db/materialization_boundaries_test.dart` | 6/6 pass |
| `flutter test` (both plan files together) | 38/38 pass |
| `flutter analyze` | No issues found |
| `grep -c '^import' lib/features/calendar/day_view_model.dart` | 3 |
| `grep -c 'flutter' lib/features/calendar/day_view_model.dart` | 0 |
| `grep -c 'blockStartsMinutes' lib/features/calendar/day_view_model.dart` | 5 |
| `720\|1080\|1320` in day_view_model.dart | line 29 only (the const declaration) |
| `grep -c 'DateTime(' test/db/materialization_boundaries_test.dart` | 0 (every literal is `DateTime.utc(...)`) |

The full-suite gate is deliberately **not** run here: this plan shares wave 1 with 03-01, which is concurrently rewriting `calendar_screen.dart`, `stack_screen.dart` and the ARB files in its own worktree. The orchestrator runs `flutter test` at the wave boundary.

## Decisions Made

1. **`ProgressTag.done` = taken count only.** UI-SPEC's `blockProgress` renders "{taken} з {total}"; a skipped dose is marked but not done, so a block with one skip and one pending reads `0 з 2`. Documented on the class.
2. **One strictness rule for "passed".** `isOverdue`, the block-past test inside `blockTagOf`, and `currentBlockIndex` all use `slotMinutes < nowMinutes` via the shared private `_blockHasPassed`, so a dose exactly at the now-minute is uniformly still due. Tested on both sides.
3. **`currentBlockIndex` returns the block index (0..3), not a list position.** The mockup's header rule is `bi == nowBlock`; returning a list position would break as soon as a block is hidden. Test: with an empty evening block, `nowMinutes: 980` returns `3`, not `2`.
4. **Defensive `MealTag` for an empty `DayBlock`.** `groupIntoBlocks` never emits one, but `DayBlock` is a public const class — an empty block must not fall through `every((d) => taken)` and claim `AllTakenTag`.
5. **`doseCyclePosition` returns `n: 1` for a dose absent from the day list** instead of throwing: a renderer holding a row from the previous stream emission must degrade, not crash.

## Deviations from Plan

None — both tasks executed exactly as written. No deviation rules fired; no auth gates; no package installs (dependency set unchanged, matching the plan's `T-03-SC accept` disposition).

## TDD Gate Compliance

- **Task 1** followed the full cycle: `test(03-02)` RED commit `9960103` (test file failing to compile — no implementation), then `feat(03-02)` GREEN commit `d266827`. No refactor commit was needed.
- **Task 2** is a **proof task, not a feature task**: its `<files>` list contains only the test file, and the behavior it pins (`ensureLogsForDay` → `watchDay` exactness) was implemented and shipped in Phase 1. It passed on first run, which is the expected and correct outcome for a retroactive gate — there is no production code in this plan for it to drive. Committed as `test(03-02)` (`d12f02f`). The plan-level RED→GREEN sequence is satisfied by Task 1.

## Known Stubs

None. Every function is fully implemented and exercised by tests; no placeholder values, no TODO/FIXME markers, no unwired data paths.

## Threat Flags

None. The new production file imports only the three pure domain libraries — no repository, no Drift, no UI framework — so it introduces no network endpoint, no auth path, no file access and no schema change. The plan's registered mitigations are all enforced: T-03-05 by the 3-import gate, T-03-06 by the file containing no activity rule at all, T-03-07 by the double-materialization + recorded-status assertions.

## Self-Check: PASSED

- `lib/features/calendar/day_view_model.dart` — FOUND
- `test/features/day_view_model_test.dart` — FOUND
- `test/db/materialization_boundaries_test.dart` — FOUND
- Commits `9960103`, `d266827`, `d12f02f` — FOUND in `git log`
