---
phase: 04-planner-views
plan: 03
subsystem: features/calendar
status: complete
tags: [planner, cycles, gantt, chart, a11y, i18n, read-only]
requires:
  - lib/features/calendar/planner_view_model.dart
  - lib/features/calendar/planner_providers.dart
  - lib/core/theme/tokens.dart
  - lib/core/l10n/arb/app_uk.arb
provides:
  - lib/features/calendar/planner_load_chart.dart
  - lib/features/calendar/planner_week_detail.dart
  - "PlannerGantt: complete gantt card (month scale, gridlines, today marker, legend)"
  - "The assembled Цикли body: summary chip, gantt, load chart, week detail, disclaimer"
affects:
  - lib/features/calendar/planner_screen.dart
  - test/features/planner_screen_test.dart
tech-stack:
  added: []
  patterns:
    - "LayoutBuilder reads the width once; every model fraction becomes a PositionedDirectional pixel offset (P-8)"
    - "Expanded(flex: month.days) sizes the month scale to real day counts, so no fixed fraction can be hardcoded (PF-3)"
    - "Semantics(button/selected/onTap) on the column node itself, with excludeSemantics in the SAME invocation (WR-02)"
    - "A Stack column whose only child is PositionedDirectional(bottom: 0) lets an over-limit bar exceed the chart without a layout throw"
    - "One exhaustive switch over the sealed LoadVerdict maps each band to an ARB key and a colour pair (the BlockTag idiom)"
key-files:
  created:
    - lib/features/calendar/planner_load_chart.dart
    - lib/features/calendar/planner_week_detail.dart
  modified:
    - lib/features/calendar/planner_gantt.dart
    - lib/features/calendar/planner_screen.dart
    - test/features/planner_screen_test.dart
decisions:
  - "The tap target is the whole 53px column (46px chart + 7px headroom), opaque, with the action on its own Semantics node — the four DECIDED-10 mitigations, all of them"
  - "Exactly one dashed reference line, at the comfort-3 height; the 5 limit is drawn structurally as the cap of the main bar (DECIDED-2)"
  - "Each column's bars live in a bottom-positioned Stack child so an extreme over-limit week grows upward instead of throwing a Column overflow"
  - "planner_screen.dart now reads editorialLimit from the pure model instead of restating 5 in a private constant"
metrics:
  duration: ~50m
  completed: 2026-08-16
  tasks: 3
  commits: 6
actuals:
  tokens: 19450
  tasks: 3
  commits: 6
---

# Phase 4 Plan 03: Цикли Gantt Chrome, Load Chart and Week Detail Summary

The Цикли segment is now whole: the gantt carries a real month scale with boundaries at real month lengths and a single today line, an eighteen-or-nineteen-column concurrent-load chart sits under it against one dashed comfort reference, and tapping any week re-renders an inline detail card naming that week's load, verdict, supplements and what a user might do about it — all of it read-only.

## What was built

**Task 1 — the gantt card completed** (`planner_gantt.dart`)

- `_MonthScale`: one mono `LLL` standalone abbreviation per `MonthColumn`, each in an `Expanded(flex: month.days)`. The flex weights *are* the real day counts, so a 120-to-123-day window can never be mis-sized by a hardcoded quarter (PF-3, T-04-11). Labels are locale-uppercased `intl` output, pinned to one line with ellipsis.
- `_RowsWithRules`: a `LayoutBuilder` reads the available width once and converts every model fraction to pixels there. Three `PositionedDirectional` 1px `hairline` rules land at the cumulative interior month boundaries; one `todayMarker` rule lands at `(todayIndex + 0.5) / span`. Today is inside the window by construction, so the marker has no absent branch.
- `_GanttLegend`: exactly three entries under a 1px rule — accent swatch, hatched swatch (a small `CustomPaint` reusing the segment hatch), `chip` swatch. The mockup's fourth entry does not ship (M1), and the assertion the test makes is the count.
- A `RepaintBoundary` wraps the card (Interaction Contract 12).

**Task 2 — the concurrent-load chart** (`planner_load_chart.dart`, new)

- `PlannerLoadChart`: mono header, then a 53px `Stack` holding a `Row` of `Expanded` `_WeekColumn`s with 3px gaps, then an axis row whose two dates are the **actual** bucket bounds through `intl` (M6) either side of `loadAxisLegend`.
- Bar heights transcribed verbatim: `round(min(load, 5) / 5 * 38)` for the main bar, `round((load - 5) / 5 * 38)` for the over-bar. Banding from the UI-SPEC table: `loadBar` ≤ 3, `warn` 4-5, `risk` above. A zero week draws the 2px `field` stub instead of nothing (DECIDED-3, M8).
- `_ThresholdLinePainter`: one 4-on/4-off dashed line, 22.8px above the baseline — the comfort reference, and the only one. The limit needs no ink because it is already where the main bar caps.
- Touch: `HitTestBehavior.opaque` over the full 53px column; `Semantics(button, selected, label, excludeSemantics, onTap)` in a single invocation on the column node; selection through the notifier read; opacity 1.0/0.5 as the only feedback, no ripple.
- `_CyclesSummaryChip` added to `planner_screen.dart`, banded at `load >= editorialLimit` (deliberately asymmetric with the year peak chip — DECIDED-6).

**Task 3 — the inline week detail** (`planner_week_detail.dart`, new)

- Header: an `Expanded` range/meta column against a non-flexible, non-wrapping verdict chip (WR-04).
- One exhaustive `switch` over the sealed `LoadVerdict` maps each band to its verdict key, its note key and its colour pair. `OverLimitVerdict` carries the load, which becomes a pre-formatted `cyclesCount` inside the already-truncated note.
- `_SlotPips`: `max(5, load)` equal-flex pips — accent below the load, `surface` + `checkBorder` above it, `risk` at index ≥ 5, so an over-limit week shows its excess as pips that ran past the row.
- Name chips in a `Wrap`; zero names is an empty `Wrap` and nothing else.

## Verification

- `flutter analyze` — **0 issues**
- `flutter test` — **472 passing** (452 baseline + 20 new), 0 failures
- `test/features/planner_screen_test.dart` — 33 tests
- Gates: `RepaintBoundary` count 1; `LayoutBuilder` ≥ 1; no `0.25`/`25.4`/`24.6` outside comments; `Color(0x` count 0 across every `planner_*.dart`; `HitTestBehavior.opaque` present; `excludeSemantics` and `onTap` in the same `Semantics(` invocation; `showModalBottomSheet` count 0; the verdict switch has no default arm; no planner file names `dayDosesProvider` or `ensureLogsForDay` outside prose.
- A DB row-count assertion brackets the one gesture this screen has: a selection tap materializes nothing.

## Deviations from Plan

### Auto-fixed issues

**1. [Rule 3 - Blocking] Over-limit bars would have thrown a `Column` overflow**

- **Found during:** Task 2
- **Issue:** the plan's literal shape — a bottom-aligned `Column` of bars inside a fixed-height chart — throws in debug as soon as `main + over` exceeds the chart height, which happens from load 7 upward.
- **Fix:** each column's bars sit in a `PositionedDirectional(start/end/bottom: 0)` child of a per-column `Stack`, which leaves the height unconstrained. The bars keep their exact transcribed heights and an extreme week grows upward rather than crashing.
- **Files modified:** `lib/features/calendar/planner_load_chart.dart`
- **Commit:** ec47e65

**2. [Rule 3 - Blocking] `containsSemantics` is deprecated in Flutter 3.47**

- **Found during:** Task 2
- **Issue:** `flutter analyze` flags `containsSemantics` (deprecated after 3.40) and the deprecated matcher additionally crashes its own mismatch description when handed a `Finder`.
- **Fix:** `isSemantics(...)` applied to the `SemanticsNode` from `tester.getSemantics`.
- **Files modified:** `test/features/planner_screen_test.dart`
- **Commit:** ec47e65

**3. [Rule 2 - Missing critical functionality] Two sources for the editorial limit**

- **Found during:** Task 2
- **Issue:** `planner_screen.dart` carried its own `_editorialLimit = 5` while the pure model already owns `editorialLimit`. Two constants for one editorial rule is exactly the drift PLAN-04 cannot afford.
- **Fix:** the private constant is gone; the screen reads `editorialLimit` from `planner_view_model.dart`, as the two new widgets do.
- **Files modified:** `lib/features/calendar/planner_screen.dart`
- **Commit:** ec47e65

**4. [Rule 1 - Bug] Two 04-02 shell tests broke on the fuller body**

- **Found during:** Task 3
- **Issue:** an active supplement's name now appears twice (gantt row **and** week-detail name chip), and the closing disclaimer moved below the `ListView`'s built range once the body grew to four cards.
- **Fix:** the name assertion is scoped to `PlannerGantt`; a `scrollBody` helper drags the body before asserting on anything below the fold. Both are honest corrections to assertions the new layout invalidated, not relaxations.
- **Files modified:** `test/features/planner_screen_test.dart`
- **Commit:** 0e5be06

### Deliberate reading of an ambiguous spec line

The UI-SPEC's "full 46px chart height *plus* the 7px above the tallest bar → ≥53px" is implemented as 7px of headroom folded into the top of each column, giving a 53px opaque target with the mockup's own 7px chart→axis gap preserved separately below it. The test asserts `column.height >= 53` rather than an exact 53, so a later re-reading of that line does not become a test edit.

## Known Stubs

None. Every element the plan names is wired to real model data.

## Backstops still open (not automatable — must be checked by hand before phase sign-off)

- **#22** Gantt legibility with 7+ long uk names at 390pt: hatched planned segments distinguishable from solid active ones at an 11px track.
- **#23** Picking a specific week among 18 columns on a physical device, and how obvious a mis-tap is.

## Self-Check: PASSED

- FOUND: `lib/features/calendar/planner_load_chart.dart`
- FOUND: `lib/features/calendar/planner_week_detail.dart`
- FOUND: `lib/features/calendar/planner_gantt.dart`
- FOUND: `lib/features/calendar/planner_screen.dart`
- FOUND: commits baac1ef, dabc337, 7310f73, ec47e65, 4fa9056, 0e5be06
