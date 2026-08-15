---
phase: 03-daily-tracking
plan: 04
subsystem: calendar
tags: [flutter, riverpod, ui, tracking, a11y]
status: complete
requires:
  - lib/features/calendar/day_view_model.dart (groupIntoBlocks, blockTagOf, currentBlockIndex, doseCyclePosition, isMissed, isOverdue)
  - lib/features/calendar/calendar_providers.dart (resolvedDayProvider, selectedDayProvider)
  - lib/core/providers.dart (dayDosesProvider, intakeRepoProvider)
  - lib/core/l10n/arb/* (the complete Phase-3 key set, unchanged this plan)
provides:
  - nowMinutesProvider — autoDispose minute-of-day ticker
  - DayBlockSection — block header (earliest real slot time, label, flexible divider, resolved tag) + its rows
  - DoseRow — the five-state row, the in-flight-guarded gesture handler, the app's ONLY status-write site
  - showDoseActionSheet() — returns the chosen DoseStatus (or null); never writes
affects:
  - lib/features/calendar/calendar_screen.dart (body now renders grouped blocks)
  - lib/features/stack/regimen_editor_controller.dart (doc comment only — clock-gate wording)
tech-stack:
  added: []
  patterns:
    - "Sealed-class exhaustive switch onto (label, fg, bg) records — the Phase-2 _StatusChip idiom, reused for the block tag and the row chips"
    - "Single guarded write gate (_apply) shared by tap, long-press and Semantics custom actions"
    - "Timer-driven StreamProvider (Stream.periodic) — new provider shape for this codebase; autoDispose per D-23"
    - "Widget tests pin BOTH clocks (todayProvider + nowMinutesProvider override) so state derivations are machine-independent"
key-files:
  created:
    - lib/features/calendar/day_block_section.dart
    - lib/features/calendar/dose_row.dart
    - lib/features/calendar/dose_action_sheet.dart
  modified:
    - lib/features/calendar/calendar_providers.dart
    - lib/features/calendar/calendar_screen.dart
    - lib/features/stack/regimen_editor_controller.dart
    - test/features/calendar_screen_test.dart
decisions:
  - "DoseRow was promoted out of calendar_screen.dart in Task 1 rather than Task 2 — DayBlockSection cannot construct a private class living in another library"
  - "The row's name/amount pair uses two Flexible children in a baseline Row, so neither a long uk name nor a long dose label can overflow at 390pt"
  - "The minute ticker's value is cached in _DayBodyState as last-known rather than blocking the day list on the provider's first frame"
  - "The tap-then-long-press guard is proven with a deliberately slow repository, the only way to hold a write genuinely in flight across the 500ms long-press timeout"
metrics:
  duration: ~50m
  completed: 2026-08-15
  tasks: 3
  commits: 3
actuals:
  tokens: 22700
  tasks: 3
  commits: 3
---

# Phase 3 Plan 04: Time Blocks, Dose Row States and the Action Sheet Summary

The flat tracer dose list became the full S4 body: chronological time blocks with honest headers, dose rows in five exhaustive visual states, and the two-gesture marking model (tap toggles, long-press opens a labelled sheet) funnelled through a single in-flight-guarded write site.

## What was built

**Task 1 — minute ticker + time-block sections** (`544e471`)

- `nowMinutesProvider`: an `autoDispose` `StreamProvider<int>` emitting minutes since local midnight, immediate first value then a one-minute periodic re-emit. It is the second and last sanctioned clock read in the app and produces an integer only, never a date.
- `DayBlockSection`: header row (earliest REAL slot time via `formatTimeOfDay(alwaysUse24HourFormat: true)`, block label, an `Expanded` 1px divider as the flexible element, then the tag chip from an exhaustive switch over the sealed `BlockTag`), 9px, the block's rows 7px apart, 18px below the section.
- `calendar_screen`'s body now renders `groupIntoBlocks(...)`; `_DayBody` became a `ConsumerStatefulWidget` that caches the last known tick.
- `DoseRow` was promoted out of `calendar_screen.dart` into its own library so blocks can construct it.

**Task 2 — DoseRow's five states, chip stack, guarded write** (`da76a58`)

- Ordered state resolution (missed → taken → skipped → overdue → pending) guarantees exactly one of the S4 table's five rows renders; overdue and missed are mutually exclusive by construction because `isOverdue` is today-gated and `isMissed` is strictly-before-today-gated.
- Chip `Wrap` in fixed order: cycle position (grouped by `regimen.id`, never `regimen.slots.length`), user note when non-empty, then the state chip.
- `_apply` is the only status-write site in the app: refuses re-entry while in flight, computes nothing itself, surfaces `markFailed` on failure with no optimistic rollback, clears the flag in a `mounted`-guarded `finally`.
- `markTaken` / `markSkipped` / `undoMark` are exposed as Semantics custom actions filtered by the same transition table; the row is one merged semantics target.

**Task 3 — dose action sheet** (`9ddbf19`)

- `showDoseActionSheet(context, dose)` returns the chosen `DoseStatus` or null; the file performs no write at all.
- Rows are filtered by the DECIDED-2 sheet columns — a would-be no-op row is absent, never disabled. Header is the supplement name plus the mono `{time} · {dose}` subtitle.
- `DoseRow.onLongPress` awaits the sheet and feeds the result through the same `_apply` guard, and is refused while a write is in flight.

## Verification

| Gate | Result |
|------|--------|
| `flutter analyze` | 0 issues |
| `flutter test` (full suite) | 258 passed (232 baseline + 26 new) |
| `test/features/calendar_screen_test.dart` | 39 passed |
| `grep -rl 'DateTime.now' lib/features/` | exactly `lib/features/calendar/calendar_providers.dart` |
| `grep -rl 'setStatus' lib/features/` | exactly `lib/features/calendar/dose_row.dart` |
| `grep -c 'pumpAndSettle' test/features/calendar_screen_test.dart` | 0 |
| `grep -c 'alwaysUse24HourFormat: true' day_block_section.dart` | 1 |
| `grep -c 'BqColors.warn' day_block_section.dart` | 2 (both inside the `ProgressTag` branch, which `blockTagOf` emits only when `viewingToday`) |
| `grep -c 'BqColors.risk' dose_row.dart` | 0 |
| `grep -c 'markFailed' dose_row.dart` | 1 |
| `grep -c 'setStatus' dose_action_sheet.dart` | 0 |
| `grep -c 'showDoseActionSheet' dose_row.dart` | 1 |
| `grep -c 'overflow: TextOverflow.ellipsis' dose_row.dart` | 0 |
| `Color(0x` literals outside comments (both new UI files) | 0 |

New test coverage (26 tests across three groups):

- **blocks (8):** empty-block omission and chronological order, earliest-real-time header (M5), accent current block on today, no accent off today, all four tag outcomes (all-taken calm / all-marked neutral / progress warn / meal), paused-regimen partial case (PF-9).
- **dose row (12):** all five states asserted against the row's own decoration, circle decoration and name `TextStyle`; the today/non-today overdue split; the past-day missed row still tappable for a late correction; cycle chip at m>1 and its absence at m==1; note chip ordering inside the `Wrap`; longest-uk-name overflow case; tap on a skipped row; the failing-repository path.
- **dose action sheet (6):** the action set for each of the three starting statuses, the write on selection, no-change on dismissal, the mono subtitle, and the tap-then-long-press interleaving.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] `DoseRow` promoted in Task 1 instead of Task 2**
- **Found during:** Task 1
- **Issue:** `DayBlockSection` (Task 1) must construct dose rows, but the tracer row was a private `_DoseRow` inside `calendar_screen.dart` — unreachable from another library.
- **Fix:** Task 1 moved the tracer row verbatim into `lib/features/calendar/dose_row.dart` with the full public constructor signature; Task 2 then rewrote its body with the five states, chips, semantics and failure surface exactly as planned. No behavior shipped early.
- **Files modified:** `lib/features/calendar/dose_row.dart`, `lib/features/calendar/calendar_screen.dart`
- **Commit:** `544e471`

**2. [Rule 3 - Blocking] Two comment-only mentions of the clock API broke the Task 1 clock gate**
- **Found during:** Task 1
- **Issue:** `grep -rl 'DateTime.now' lib/features/` also matched doc comments in `calendar_screen.dart` and `stack/regimen_editor_controller.dart`, so the single-file invariant could not be asserted.
- **Fix:** Rephrased both comments ("per-build wall-clock read", "a fresh wall-clock read per call"); no code changed.
- **Files modified:** `lib/features/calendar/calendar_screen.dart`, `lib/features/stack/regimen_editor_controller.dart`
- **Commit:** `544e471`

**3. [Rule 3 - Blocking] `CustomSemanticsAction` is not exported by `material.dart`**
- **Found during:** Task 2
- **Issue:** Four analyzer errors — the type lives in `package:flutter/semantics.dart`.
- **Fix:** Added the import.
- **Files modified:** `lib/features/calendar/dose_row.dart`
- **Commit:** `da76a58`

### Plan refinements (no behavior change)

- `DayBlockSection` takes `dayDoses` and `isCurrentBlock` in addition to the parameters the plan enumerated: the row's cycle chip needs the whole day's list (PF-6) and `currentBlockIndex` needs the whole block list, which only the screen has. `today` is read via `ref.watch(todayProvider)` — the reason the widget is a `ConsumerWidget` at all.
- The row's name/amount baseline `Row` uses **two** `Flexible` children (the plan specified a flexing name); a long dose label would otherwise be the overflow vector instead of the name.
- Per the orchestrator's rules, each task shipped as one atomic `feat(03-04)` commit with its tests, rather than the separate RED/GREEN commits `tdd="true"` would normally produce.

### Test-harness notes worth carrying forward

- Modal-sheet tests must pump past the route transition twice: once before tapping an action (the sheet is mounted while still off-screen) and once after, before asserting it is gone.
- Proving the in-flight guard across a long press requires a repository that delays the write — `tester.longPress` internally pumps 500ms, which is long enough for a real in-memory Drift write to land.

## Known Stubs

None. Every element this plan owns is wired to live data; the empty-day and error surfaces remain plan 03-05's scope as designed.

## TDD Gate Compliance

Tasks were marked `tdd="true"`, but the orchestrator mandated one atomic commit per task, so RED and GREEN land in the same commit rather than as separate `test(...)` / `feat(...)` gates. Every behavior bullet in each task has an explicit test, and each task's `<verify><automated>` was run before its commit.

## Threat Flags

None. The plan's threat register is fully mitigated:

| Threat | Status |
|--------|--------|
| T-03-02 (double-apply) | `_apply` guard shared by tap, long-press and Semantics; double-tap and slow-repo tap-then-long-press regression tests |
| T-03-12 (unauthorized write) | `grep -rl 'setStatus' lib/features/` lists exactly one file; the sheet returns a choice |
| T-03-13 (silent write failure) | try/catch surfacing `markFailed`, no rollback, failing-repository test |
| T-03-14 (misleading state) | ordered five-state resolution; overdue/missed mutual exclusion asserted |
| T-03-SC (supply chain) | dependency set unchanged — no package installed this plan |

## Self-Check: PASSED

- FOUND: lib/features/calendar/day_block_section.dart
- FOUND: lib/features/calendar/dose_row.dart
- FOUND: lib/features/calendar/dose_action_sheet.dart
- FOUND: 544e471, da76a58, 9ddbf19
