---
phase: 01-foundation
plan: 02
subsystem: domain
tags: [dart, cycle-math, dst, tdd, value-models]

requires:
  - phase: 01-foundation (plan 01-01)
    provides: Flutter project scaffold, pubspec, analysis_options, test harness
provides:
  - Pure-Dart domain value models (Supplement, Regimen, DoseSlot, RegimenKind, DoseStatus) with assert-based range validation
  - DST-safe cycle math (dateOnly, isActiveOn) proven by unit tests across a DST transition and a year boundary (D-16 phase exit criterion for this layer)
affects: [01-05, 01-07, calendar, planner, materializer]

actuals:
  tokens: 3250
  tasks: 2
  commits: 4

tech-stack:
  added: []
  patterns:
    - "Domain layer is pure Dart: no Flutter/Drift/I-O imports under lib/core/domain/"
    - "Date-only values are always DateTime.utc(y,m,d); no DateTime.now() in domain functions (D-13)"
    - "Time-type separation: date-only UTC days vs minutesFromMidnight wall clock vs UTC instants (D-15)"

key-files:
  created:
    - lib/core/domain/models.dart
    - lib/core/domain/cycle_math.dart
    - test/domain/models_test.dart
    - test/domain/cycle_math_test.dart
  modified: []

key-decisions:
  - "Range validation via asserts in const constructors (compile-time const proof + debug-mode rejection), matching plan's ArgumentError/assert allowance"
  - "Regimen declares a const constructor but const instantiation is proven only for DoseSlot/Supplement — DateTime has no const constructor in Dart"
  - "isPlannedOn deliberately NOT built (plan scope note: deferred to Phase 4 planner math)"

patterns-established:
  - "Cycle day arithmetic: d.difference(start).inDays % (onDays + offDays) < onDays on UTC-normalized values only"
  - "isActiveOn semantics locked per D-14: paused -> false; before start -> false; course inclusive end (null end -> false); offDays=0 -> always on; onDays<=0 -> false"

requirements-completed: [DATA-01]

coverage:
  - id: D1
    description: "Domain value models (Supplement, Regimen, DoseSlot, enums) with range validation"
    requirement: DATA-01
    verification:
      - kind: unit
        ref: "test/domain/models_test.dart (9 tests: range rejection, const proof, enum sets)"
        status: pass
    human_judgment: false
  - id: D2
    description: "dateOnly + isActiveOn correct across EU DST transitions and 2026->2027 year boundary"
    requirement: DATA-01
    verification:
      - kind: unit
        ref: "test/domain/cycle_math_test.dart (17 tests: CONTEXT exemplars, DST parity, year boundary, guards)"
        status: pass
      - kind: other
        ref: "grep gates: no flutter/drift imports and no DateTime.now under lib/core/domain/"
        status: pass
    human_judgment: false

duration: 3min
completed: 2026-08-14
status: complete
---

# Phase 1 Plan 02: Domain Models + Cycle Math Summary

**Pure-Dart domain layer: validated value models plus DST-safe isActiveOn/dateOnly, proven by 26 unit tests spanning EU DST transitions and the 2026→2027 year boundary before any DB or UI consumer exists**

## Performance

- **Duration:** 3 min
- **Started:** 2026-08-14T17:56:06Z
- **Completed:** 2026-08-14T17:59:16Z
- **Tasks:** 2 (both TDD, RED→GREEN)
- **Files modified:** 4 created

## Accomplishments

- `lib/core/domain/models.dart`: `RegimenKind`, `DoseStatus`, `DoseSlot`, `Regimen`, `Supplement` — const constructors, final fields, named required params, assert-validated ranges (minutesFromMidnight 0..1439, onDays/offDays >= 0), identifiers verbatim per the phase symbol index (mitigates T-01-04)
- `lib/core/domain/cycle_math.dart`: `dateOnly()` → `DateTime.utc(y,m,d)` and `isActiveOn()` implementing exactly D-14, with day differences computed only on UTC-normalized values (mitigates T-01-05)
- D-16 exit criterion satisfied for this layer: tests assert the CONTEXT exemplar 56on/28off cycle (whose window crosses 2026-10-25 EU DST end), 1on/1off parity across both 2026 EU DST transitions, and 28on/28off across the year boundary
- Grep gates green: no Flutter/Drift imports and no `DateTime.now` anywhere under `lib/core/domain/`

## Task Commits

Each TDD task produced RED and GREEN commits:

1. **Task 1 RED: failing model tests** - `1d65c58` (test)
2. **Task 1 GREEN: domain value models** - `aabdafa` (feat)
3. **Task 2 RED: failing cycle math tests** - `6e4f2d8` (test)
4. **Task 2 GREEN: dateOnly + isActiveOn** - `96de370` (feat)

No REFACTOR commits — implementations were minimal on first pass.

## Files Created/Modified

- `lib/core/domain/models.dart` - Value models + enums, pure dart:core, range asserts, D-15 time-type docs
- `lib/core/domain/cycle_math.dart` - dateOnly + isActiveOn, imports only models.dart
- `test/domain/models_test.dart` - 9 tests: range rejection, const instantiation proof, enum value sets
- `test/domain/cycle_math_test.dart` - 17 tests: CONTEXT exemplars, DST parity, year boundary, course/paused/guards, dateOnly normalization

## Decisions Made

- Range validation via asserts inside const constructors (plan allowed "ArgumentError/assert"); asserts are active under `flutter test`, and const constructors give the compile-time proof Task 1 required
- Const instantiation proven for `DoseSlot`/`Supplement` only — `DateTime` has no const constructor in Dart, so `Regimen` cannot appear in a const context (documented in the test file)
- Added one extra guard test beyond the plan's list (`onDays == 0` cyclic → never active) since the implementation spec includes that branch — coverage, not scope creep

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## TDD Gate Compliance

- RED gates: `test(01-02)` commits `1d65c58`, `6e4f2d8` — both test files failed (missing implementation files) before their GREEN commits
- GREEN gates: `feat(01-02)` commits `aabdafa`, `96de370` — suites pass after implementation
- REFACTOR: none needed

## Next Phase Readiness

- Plans 01-05 and 01-07 can import `DoseStatus`, `Regimen`, `isActiveOn` verbatim per the phase symbol index
- The materializer (01-07) has its single source of truth for "is this regimen active on day X"
- `isPlannedOn` intentionally deferred to Phase 4 (planner math) per the plan's scope note

## Self-Check: PASSED

- All 4 source/test files plus SUMMARY exist on disk
- Commits 1d65c58, aabdafa, 6e4f2d8, 96de370 present in history on base fff1314
- `flutter test test/domain/` 26/26 green; `flutter analyze` 0 issues; import + clock grep gates pass
- Working tree clean; no shared orchestrator artifacts (STATE.md/ROADMAP.md/REQUIREMENTS.md) modified

---
*Phase: 01-foundation*
*Completed: 2026-08-14*
