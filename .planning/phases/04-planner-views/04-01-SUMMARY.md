---
phase: 04-planner-views
plan: 01
subsystem: ui
tags: [flutter, riverpod, custom-paint, gantt, date-math, projection, l10n]

# Dependency graph
requires:
  - phase: 01-foundation
    provides: cycle_math.dart (dateOnly/isActiveOn), design tokens, gen-l10n pipeline, todayProvider convention
  - phase: 02-stack-management
    provides: stackEntriesProvider's StackEntry shape, statusOf's planned rule, BqSegmented
  - phase: 03-daily-tracking
    provides: the Calendar tab frame and header, week_strip's mondayOfWeek, the WR-06 read-only lesson, the widget-test harness
provides:
  - "plannerWindow/firstOfMonth/addMonths/daysInMonth in cycle_math.dart, plus mondayOfWeek promoted out of week_strip.dart"
  - "planner_view_model.dart — the clockless, three-import pure projection layer (runs, gantt segments, month columns, week buckets, load verdicts, month cells, year model)"
  - "planner_providers.dart — cyclesModelProvider, yearModelProvider, segment/week/month selection with clamped resolvers"
  - "planner_gantt.dart — PlannerGantt card, GanttRowBar and its CustomPainter (solid active / clipped-hatch planned)"
  - "planner_screen.dart — the navigation-agnostic in-tab planner page"
  - "CalendarPage + calendarPageProvider — the Calendar tab's page swap and its PopScope"
  - "The eight Phase-4 colour tokens and the plannerTitle ARB key in both locales"
  - "The intakeLogs row-count regression that pins the planner's zero-write invariant"
affects: [04-02, 04-03, 04-04, 04-05, planner rendering, load chart, year grid]

actuals:
  tokens: 27600
  tasks: 3
  commits: 3

tech-stack:
  added: []
  patterns:
    - "Read-only projection: planner code reaches only stackEntriesProvider + todayProvider; a row-count test enforces it"
    - "Runs-not-formulas: activeRuns scans isActiveOn day by day and coalesces; the cycle formula exists in exactly one place"
    - "Derived model behind a Provider: Riverpod's cache IS the memoization (PF-10)"
    - "In-tab page swap over Navigator.push, with the swapped page kept navigation-agnostic"

key-files:
  created:
    - lib/features/calendar/planner_view_model.dart
    - lib/features/calendar/planner_providers.dart
    - lib/features/calendar/planner_gantt.dart
    - lib/features/calendar/planner_screen.dart
    - test/domain/planner_window_test.dart
    - test/features/planner_view_model_test.dart
    - test/features/planner_screen_test.dart
    - test/providers_planner_test.dart
  modified:
    - lib/core/domain/cycle_math.dart
    - lib/core/theme/tokens.dart
    - lib/core/l10n/arb/app_en.arb
    - lib/core/l10n/arb/app_uk.arb
    - lib/features/calendar/calendar_providers.dart
    - lib/features/calendar/calendar_screen.dart
    - lib/features/calendar/week_strip.dart
    - test/theme/theme_test.dart

key-decisions:
  - "The planner window span is derived from real month boundaries (120-123 days), never the mockup's hardcoded 122"
  - "GanttRow carries its runs as well as its painted fractions — week buckets need dates, and a fraction cannot answer 'active that week'"
  - "CyclesModel carries its week loads, so the load chart and the resolved-week provider read one cached model"
  - "MonthCell.full is a getter over the named fullMonthFraction constant, making the 0.84/0.85 boundary directly testable"
  - "Drift subscriptions in widget tests are cancelled in-body, never via addTearDown — an awaited cancel after the DB closes hangs the test"

patterns-established:
  - "Zero-write gate: capture the intakeLogs row count, resolve the model, assert the count is byte-identical with a reason: naming the guarantee"
  - "Clamped selection resolvers: every screen-scoped index folds over the model's own list length so a stale selection cannot index out of bounds"
  - "Boundary constants are named once and asserted from both sides (3/4, 5/6, 0.84/0.85), so moving one is a one-line, test-caught edit"

requirements-completed: [PLAN-01]

coverage:
  - id: D1
    description: "A user reaches the planner from the Calendar tab and sees one gantt row per regimen-bearing supplement, drawn from their real database"
    requirement: PLAN-01
    verification:
      - kind: integration
        ref: "test/features/planner_screen_test.dart#tapping the Calendar header's planner action opens the planner and draws one gantt row per regimen-bearing entry (DECIDED-1, DECIDED-7)"
        status: pass
      - kind: integration
        ref: "test/features/planner_screen_test.dart#the planner's back control restores the Today header"
        status: pass
    human_judgment: false
  - id: D2
    description: "Solid segments mark started cycles and hatched segments mark cycles that begin after today (DECIDED-4)"
    verification:
      - kind: unit
        ref: "test/features/planner_view_model_test.dart#ganttSegments — a run is planned as a WHOLE (DECIDED-4)"
        status: pass
    human_judgment: true
    rationale: "The model's planned/active flag is proven by test, but the PAINTED result — hatch density, segment radius, the 2px floor's legibility on a real 340px track — is a visual judgment no assertion in this plan makes. Confirm on device."
  - id: D3
    description: "Opening the planner writes nothing — proven by a row-count regression, not by inspection"
    requirement: PLAN-01
    verification:
      - kind: integration
        ref: "test/providers_planner_test.dart#resolving the Cycles model creates NO IntakeLog rows (PF-2 / the WR-06 lesson)"
        status: pass
      - kind: integration
        ref: "test/providers_planner_test.dart#resolving the YEAR model creates no IntakeLog rows either — the case a materializing implementation would pay for most (PF-2)"
        status: pass
      - kind: integration
        ref: "test/features/planner_screen_test.dart#opening the planner writes no IntakeLog row through the UI (PF-2 / WR-06)"
        status: pass
    human_judgment: false
  - id: D4
    description: "Every projection the rest of the phase renders exists as a tested pure function (week buckets, verdicts, month cells, year model)"
    verification:
      - kind: unit
        ref: "test/features/planner_view_model_test.dart (52 tests: weekBuckets, weekLoads, verdictOf, monthCellFor, buildYearModel, regimen-shape edges)"
        status: pass
      - kind: unit
        ref: "test/domain/planner_window_test.dart (63 tests: all twelve start months in a common and a leap year, year crossings, fraction sums)"
        status: pass
    human_judgment: false
  - id: D5
    description: "Eight Phase-4 colour tokens and the plannerTitle key in both locales"
    verification:
      - kind: unit
        ref: "test/theme/theme_test.dart#BqColors — Phase-4 token additions (04-UI-SPEC Token Additions)"
        status: pass
      - kind: other
        ref: "flutter gen-l10n (clean, no untranslated-message warning)"
        status: pass
    human_judgment: false

# Metrics
duration: ~75min
completed: 2026-08-16
status: complete
---

# Phase 4 Plan 01: Planner Tracer Summary

**A read-only planner reachable from the Calendar tab: real regimens scanned through `isActiveOn` into a clockless projection, painted as solid/hatched gantt segments, with an `intakeLogs` row-count regression proving the whole trip writes nothing.**

## Performance

- **Duration:** ~75 min of active execution (the session paused mid-run for a usage-limit reset)
- **Tasks:** 3
- **Files modified:** 19 (8 created, 11 modified)
- **Tests:** 290 → 422 (132 added), `flutter analyze` 0 issues

## Accomplishments

- **The architecture is proven end-to-end on one thin path.** Real regimens in a real database → `plannerWindow` + `activeRuns` → one cached provider → a gantt a user reaches by tapping a header button, with the back path returning to Today. Every later plan in this phase renders over a model that is already correct.
- **The phase's defining invariant is pinned on the first commit.** Three separate tests — provider-level for the Cycles model, provider-level for the year-scale Year model, and widget-level through the real tap path — assert the `intakeLogs` row count is unchanged. This is the Phase-3 WR-06 failure caught before it can happen at year scale, and it is a count, not a code review.
- **Activity has exactly one definition in the app.** `activeRuns` scans `isActiveOn` day by day and coalesces; a grep gate rejects modulo, on-day or off-day arithmetic inside the view-model. The Today screen and the planner cannot disagree about whether a day is active.
- **The window is derived, never assumed.** All twelve start months are asserted against the summed real lengths of their four months, in both a common and a leap year — 24 windows, plus year crossings and a 29-day February column. The mockup's hardcoded 122 appears nowhere.
- **Every number the rest of the phase renders now exists as a tested pure function:** week buckets, concurrent loads, the three verdict bands, month coverage cells and the twelve-month year model with its tie-broken peak.

## Task Commits

1. **Task 1: Tracer — real regimens to a reachable gantt, with the zero-write gate** — `f8bdaa2` (feat)
2. **Task 2: The full pure projection set — week buckets, verdicts, month cells, peak month** — `0f34038` (feat)
3. **Task 3: The edge matrix — leap years, year crossings, exclusions, one-day runs** — `23fd144` (test)

## Files Created/Modified

**Created**
- `lib/features/calendar/planner_view_model.dart` — the pure core: `DateRun`/`activeRuns`, `GanttSegment`/`ganttSegments`, `MonthColumn`, `GanttRow`, `CyclesModel`/`buildCyclesModel`, `WeekBucket`/`weekBuckets`, `WeekLoad`/`weekLoads`, `editorialLimit`/`comfortLoad`, the sealed `LoadVerdict` trio + `verdictOf`, `MonthCell`/`monthCellFor`, `YearMonth`/`YearModel`/`buildYearModel`. Exactly three imports, no clock read, no strings.
- `lib/features/calendar/planner_providers.dart` — `cyclesModelProvider`, `yearModelProvider`, `plannerSegmentProvider` (default Цикли), `selectedWeek`/`selectedMonth` with clamped resolved indices.
- `lib/features/calendar/planner_gantt.dart` — `PlannerGantt` card, `GanttRowBar`, `_GanttRowPainter` (chip track, solid accent active segments, clipped 4px hatch + 1px border planned segments, 2px minimum width).
- `lib/features/calendar/planner_screen.dart` — the planner page; navigation-agnostic by construction.
- `test/domain/planner_window_test.dart` (63 tests), `test/features/planner_view_model_test.dart` (52), `test/providers_planner_test.dart` (5), `test/features/planner_screen_test.dart` (3).

**Modified**
- `lib/core/domain/cycle_math.dart` — `firstOfMonth`, `addMonths`, `daysInMonth`, `plannerWindow`, and `mondayOfWeek` moved here verbatim.
- `lib/features/calendar/week_strip.dart` — local `mondayOfWeek` deleted; the strip now uses the promoted one (moved and re-verified as its own step, so a strip regression could not hide inside a larger diff).
- `lib/core/theme/tokens.dart` + `test/theme/theme_test.dart` — the eight Phase-4 colours under their own banner, each asserted.
- `lib/core/l10n/arb/app_{en,uk}.arb` + regenerated gen output — `plannerTitle`.
- `lib/features/calendar/calendar_providers.dart` — `CalendarPage` + `calendarPageProvider`.
- `lib/features/calendar/calendar_screen.dart` — the page swap, the `PopScope`, and the header action `Wrap`.

## Decisions Made

- **`GanttRow` carries its runs, not just its painted fractions.** Week buckets ask "is this supplement active in that week", which is a question about dates; a 0..1 fraction cannot answer it without inverting the projection. Carrying the runs keeps one derivation feeding both the painter and the buckets.
- **`CyclesModel` carries its `weeks`.** The load chart (plan 04-03) and `resolvedWeekIndexProvider` both need the buckets; putting them in the model means one cached derivation rather than two, and the resolver has a list to clamp against.
- **`MonthCell.full` is a getter over a named `fullMonthFraction` constant.** The plan required asserting the 0.84/0.85 boundary directly, which a constructor-computed bool cannot express without fabricating day counts. This follows the `blockStartsMinutes` "the ONE place a boundary lives" convention.
- **The planner page renders no error text yet.** Plan 04-01 deliberately owns no error ARB key; the loading and error branches render an empty body rather than raw exception text, and plan 04-02 fills in `plannerLoadError` + `retry`. Rendering nothing is the safe half of that contract, never a stack trace.

## Deviations from Plan

None — plan executed as written. No deviation rule fired; every edge asserted in Task 3 already held in the Task 1/2 production code, so no production file changed in Task 3.

## Issues Encountered

1. **`ProviderListenable` is not part of Riverpod 3's public API.** The provider test's generic `resolve<T>` helper was typed against it and failed to compile. Resolved by typing the helper as `Provider<AsyncValue<T>>`, which is the concrete shape both planner models use.
2. **A widget test hung to the 10-minute timeout.** Cause: `addTearDown(subscription.cancel)` on a Drift query stream. `flutter_test` awaits teardown callbacks, and a Drift subscription's `cancel()` does not settle once the database has been closed, so the test hung after its assertions had already passed. The existing suite's convention is to cancel in-body before `tearDownTree`; the test now does that, with a comment recording why. Same family as the known "never await a Drift stream in a widget-test path" lesson.
3. **A stale unused import** (`planner_view_model.dart` in the provider test) surfaced as the only analyze warning after Task 1 and was removed before the commit.

## Verification

- `flutter analyze` — **0 issues**
- `flutter test` — **422 passing** (Phase-3 baseline of 290 intact, 132 added)
- `flutter gen-l10n` — clean, no untranslated-message warning, both ARB files in sync
- Grep gates, all passing: 0 materializing imports, 0 `DateTime.now`, 0 colour literals and 0 cycle re-derivation in planner files; `planner_view_model.dart` imports exactly 3 libraries; `mondayOfWeek` declared only in `cycle_math.dart`; 0 forbidden `Duration(days: 30|31|365)` forms
- `integration_test/` was NOT run (requires a device; outside `flutter test`)

## Known Stubs

Two placements are intentionally partial, each assigned by the PLAN itself to plan 04-02 and neither blocking this plan's goal:

| Item | File | Reason |
|---|---|---|
| Gantt row semantics label is the supplement name only | `lib/features/calendar/planner_gantt.dart` (`GanttRowBar`) | The fuller `ganttRowSemantics` label (name + schedule + period count) needs ARB keys plan 04-02 owns. The row is still announced and readable today. |
| Planner loading/error branches render an empty body | `lib/features/calendar/planner_screen.dart` (`_PlannerBody`) | `plannerLoadError` + `retry` are plan 04-02's keys. Rendering nothing is deliberate — raw exception text is never placed in the tree. |

## User Setup Required

None — no external service configuration, no new packages, no dependency change.

## Next Phase Readiness

- **Plans 04-02 through 04-05 render over a proven model.** Every projection they need is already a tested pure function behind a cached provider; none of them needs to touch date math again.
- **Deliberately absent, by plan design:** month labels, month gridlines, the today marker, the legend, the summary chip, the segmented control, the load chart, the week-detail card, the year grid, the empty/error surfaces, and the disclaimer. All sit *beside* what was built and land without changing it.
- **One item to watch:** the plan's `<threat_model>` assigns `mitigate` to ad-hoc colour literals in planner widgets (T-04-04). The grep gate passes now; later plans adding chrome must keep it at zero, and the eight-token list is closed.
- **UAT question carried forward (DECIDED-4):** whether a running cycle's future tail should stay solid (current, mockup-exact, and consistent with the Stack tab's ЗАПЛАНОВАНО chip) or split at today. Reversal is a one-line change in `ganttSegments`.

## Self-Check: PASSED

- All 8 created files exist on disk; all 11 modified files present in the diff.
- All three task commits exist on `worktree-agent-a8ea642e719a723c0`: `f8bdaa2`, `0f34038`, `23fd144`.
- `flutter analyze` 0 issues and `flutter test` 422 passing, re-run after the final commit.

---
*Phase: 04-planner-views · Plan: 01*
*Completed: 2026-08-16*
