---
phase: 04-planner-views
plan: 04
subsystem: calendar/planner
tags: [flutter, riverpod, year-grid, month-detail, a11y, i18n, layout]
status: complete
requires:
  - "04-01: planner_view_model.dart — YearModel, YearMonth, MonthCell, editorialLimit"
  - "04-02: the 160-key ARB set, the planner page shell and its _BodyScroll footnote slot"
  - "04-03: planner_gantt.dart, planner_load_chart.dart, planner_week_detail.dart, the scrollBody test helper"
provides:
  - "lib/features/calendar/planner_year_grid.dart — PlannerYearGrid, _MonthCard, monthCardExtentFor"
  - "lib/features/calendar/planner_month_detail.dart — PlannerMonthDetail and its per-supplement row"
  - "the completed Рік body: peak chip, grid, legend, month detail, footnote, disclaimer"
affects:
  - "lib/features/calendar/planner_screen.dart"
  - "test/features/planner_screen_test.dart"
tech-stack:
  added: []
  patterns:
    - "stripHeightFor idiom extended to a grid delegate: fixed part + scaler.scale(text part) + content extent"
    - "SliverGridDelegateWithFixedCrossAxisCount with a computed main-axis extent, never a child aspect ratio"
    - "screen-level ref.listen to hold autoDispose selection state for a screen's lifetime"
key-files:
  created:
    - lib/features/calendar/planner_year_grid.dart
    - lib/features/calendar/planner_month_detail.dart
  modified:
    - lib/features/calendar/planner_screen.dart
    - test/features/planner_screen_test.dart
decisions:
  - "The month-card extent is computed from the text scaler and the stack size and is never capped (DECIDED-5); a fixed childAspectRatio is grep-gated out."
  - "The 22% bar-width floor ships verbatim — two days of coverage stay visible."
  - "The peak chip warns STRICTLY above the editorial limit while the Цикли summary chip warns at or above it; both comparisons now carry a comment pointing at the other (DECIDED-6)."
  - "Рік renders yearFootnote ABOVE the same plannerDisclaimer key Цикли renders, proven by rendered vertical position (DECIDED-8, M9)."
  - "The year legend names supplements by their full name: the domain model carries no short-name field, and a Wrap absorbs the extra width."
  - "Both planner selections are held alive by a screen-level ref.listen — autoDispose otherwise reset them on every segment switch."
metrics:
  duration: 19m
  completed: 2026-08-16
actuals:
  tokens: 16800
  tasks: 3
  commits: 6
---

# Phase 4 Plan 4: Рік Segment Summary

The Year segment ships whole: a twelve-card coverage matrix whose main-axis extent is computed from the text scaler and the stack size (never a fixed aspect ratio), an inline month detail naming each supplement's coverage state, the peak chip, the two-tone legend, and the year footnote sitting above the same educational disclaimer the Цикли body carries.

## What was built

**`lib/features/calendar/planner_year_grid.dart`** (new, 363 lines)

- `monthCardExtentFor(TextScaler, int rowCount)` — the load-bearing piece. Two named constants (`_monthCardFixedExtent` for the paddings/borders/bar-row margin, `_monthCardHeaderTextExtent` for the mono header line) plus `rowCount × 4 + (rowCount − 1) × 3` of bar extent. Only the text part is scaled, carrying the same reasoning comment `stripHeightFor` does and naming the CR-01/WR-04 defect a constant would reproduce.
- `PlannerYearGrid` — a `GridView.builder` with `SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, mainAxisSpacing: 8, crossAxisSpacing: 8, mainAxisExtent: …)`, `shrinkWrap: true` and `NeverScrollableScrollPhysics` inside the page's own scroll.
- `_MonthCard` — `surfaceAlt` + 1px `cardBorder` unselected, `monthSelectedBg` + 1.6px `accent` selected, `BqRadii.dayCell` radius (a month cell in a year matrix *is* a calendar cell — no third 11px token). Flexible mono `LLL` uppercased label against a rigid mono count; the count renders `risk` **strictly** above `editorialLimit`. Selection and the tap action sit on the card's own `Semantics` node (WR-02); the whole card is the target, and `InkResponse` already hit-tests opaque over its full box.
- `_CoverageBar` — one 4px `yearBarTrack` per gantt-eligible supplement in stack order, always rendered, with a `FractionallySizedBox` fill at `0` / `1` / `max(round(frac × 100)/100, 0.22)` and the supplement's own colour at `alpha 0.30` when the month's whole coverage is planned.

**`lib/features/calendar/planner_month_detail.dart`** (new, 258 lines)

Always-inline card: uppercased standalone `LLLL` title against `monthMeta` with a pre-formatted `substancesCount`; rows filtered to `frac > 0` in stack order, each a 9×9 dot (tinted `alpha 0.50` when planned), an `Expanded` name/hint column and a non-flexible, non-wrapping state; a zero-coverage month renders `monthEmpty` inside the same card.

**`lib/features/calendar/planner_screen.dart`** (extended)

`_YearPeakChip` (same geometry as the Цикли summary chip, warn strictly above the limit), `_YearLegend` (a `Wrap` of two-tone swatches closing with `yearLegendHint`), `_TwoToneSwatch`, and the Рік body order: peak chip → grid card → legend → month-detail card → `yearFootnote` → `plannerDisclaimer`.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Both planner selections were reset by every segment switch**

- **Found during:** Task 3
- **Issue:** `selectedWeekProvider` and `selectedMonthProvider` are `autoDispose` (D-23) and their only listeners lived inside the segment body. Switching segments unmounted that body, dropped the last listener and silently reset the user's pick — violating Interaction Contract 2. The 04-03 test masked the week half of this with a `container.listen` the real screen never had.
- **Fix:** `PlannerScreen.build` now `ref.listen`s both selection providers, holding them for the screen's lifetime without rebuilding on selection change.
- **Files modified:** `lib/features/calendar/planner_screen.dart`
- **Commit:** 9811f83

**2. [Rule 3 - Blocking] `InkWell.hitTestBehavior` does not exist on Flutter 3.47**

- **Found during:** Task 1
- **Issue:** the plan's "opaque hit-test behavior" was written as a named argument that this SDK's `InkWell` does not accept (compile error).
- **Fix:** dropped the argument — `InkResponse` already hit-tests `HitTestBehavior.opaque` over its full box (`ink_well.dart:1418`), which is the behavior the plan asked for. The comment records where that guarantee lives.
- **Files modified:** `lib/features/calendar/planner_year_grid.dart`
- **Commit:** fe690d9

**3. [Rule 3 - Blocking] Two 04-02/04-03 assertions became viewport-dependent**

- **Found during:** Task 2
- **Issue:** the Рік body grew from two elements to six, so the closing disclaimer and (at textScaler 2.0) the grid itself moved below the fold and stopped being built by the `ListView`.
- **Fix:** the "disclaimer closes BOTH segments" test now scrolls the Рік body the way it already scrolled the Цикли one; the textScaler-2.0 test scrolls before waiting for the cards. No production behaviour changed — the finders were the thing that had gone stale.
- **Files modified:** `test/features/planner_screen_test.dart`
- **Commit:** 0198301

### Deliberate departures from the plan text

- **Year legend short names.** The plan and the mockup call for a "short name" per legend entry; `Supplement` carries no such field (only `name`, `doseText`, `colorValue`, `note`). Adding a domain field is a Rule-4 architectural change, so the legend names supplements the way every other surface does and lets the `Wrap` absorb the width. Flagged for UAT.
- **The peak chip is genuinely tall at textScaler 2.0** in the widget-test font (each glyph is a full em square, so the rigid count claims far more width than on a device). The layout is correct — the flexible sentence wraps rather than overflowing, which is the locked "no fixed-size text container" rule working — but the 2.0 test scrolls the body rather than pretending the grid stays above the fold. Worth a look on a real device at UAT.

## Verification

- `flutter analyze` — **0 issues**
- `flutter test` — **489 passed**, 0 failed (472 baseline + 17 new)
- `flutter test test/features/planner_screen_test.dart` — 50 passed

Acceptance greps, all met:

| Gate | Result |
|------|--------|
| `childAspectRatio` in `planner_year_grid.dart` (comments stripped) | 0 |
| `mainAxisExtent` in `planner_year_grid.dart` | 1 |
| `textScalerOf` in `planner_year_grid.dart` | 1 |
| `excludeSemantics` in `planner_year_grid.dart`, with `onTap` in the same `Semantics(` | 2 (one is prose) |
| `showModalBottomSheet` across both new files (comments stripped) | 0 |
| `DateFormat('LLLL'` / `DateFormat('LLL'` across both new files | 2 |
| `DateFormat('MMMM'` / `DateFormat('MMM'` across both new files (comments stripped) | 0 |
| `Color(0x` across `planner_*.dart` (comments stripped) | 0 |
| `buildCyclesModel` / `buildYearModel` / `activeRuns(` in any planner widget file | 0 |
| `dayDoses` / `ensureLogsForDay` / `IntakeRepository` / `intakeRepoProvider` in `planner_*.dart` | 0 |

## Threat mitigations delivered

| Threat | Mitigation shipped |
|--------|--------------------|
| T-04-16 (missing required framing) | `yearFootnote` above `plannerDisclaimer`, asserted by rendered vertical position, not presence |
| T-04-17 (hidden data) | the 22% floor carried over verbatim, asserted against a two-day-coverage month against its raw fraction |
| T-04-18 (clipped layout) | computed main-axis extent; a fixed aspect ratio is grep-gated; twelve supplements pumped at textScaler 2.0 with `takeException()` null |
| T-04-19 (uk month case) | `LLL`/`LLLL` standalone patterns only, grep-gated on both year files, labels asserted against `DateFormat` output |
| T-04-20 (out-of-range selection) | `resolvedMonthIndexProvider`'s existing clamp exercised; the year is always today's, no paging |

## Self-Check: PASSED

All four claimed files exist on disk; all six commit hashes resolve in `git log`.

## Not done / for UAT

- The live-device half of backstop #24 (an actual midnight rollover on a device) stays a hand check; the automatable half now runs on the pinned clock.
- Legend short names and the peak-chip line count at large text scales (see "Deliberate departures").
