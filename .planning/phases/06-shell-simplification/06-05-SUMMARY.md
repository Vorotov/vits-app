---
phase: 06-shell-simplification
plan: 05
subsystem: planner
tags: [planner, load-chart, l10n, a11y, limit-removal]
requires: ["06-04"]
provides:
  - "CyclesModel.scheduledCount — the load chart's denominator, with an asserted load <= ceiling invariant"
  - "ARB key loadScaleCaption (uk + en)"
  - "A load chart with one bar colour, no reference line and no over-segment"
  - "planner_load_chart.dart free of weekLoadLabel — 06-06 can delete the key"
affects:
  - lib/features/calendar/planner_view_model.dart
  - lib/features/calendar/planner_load_chart.dart
  - lib/features/calendar/planner_screen.dart
  - lib/core/l10n/arb/app_uk.arb
  - lib/core/l10n/arb/app_en.arb
tech-stack:
  added: []
  patterns:
    - "The chart's scale is a MODEL value passed in by the screen; the widget neither computes nor defaults it"
    - "Geometry safety by construction (load <= ceiling) instead of by guard branch — no cap, no clamp, no zero check"
key-files:
  created: []
  modified:
    - lib/features/calendar/planner_view_model.dart
    - lib/features/calendar/planner_load_chart.dart
    - lib/features/calendar/planner_screen.dart
    - lib/core/l10n/arb/app_uk.arb
    - lib/core/l10n/arb/app_en.arb
    - lib/core/l10n/gen/app_localizations.dart
    - lib/core/l10n/gen/app_localizations_en.dart
    - lib/core/l10n/gen/app_localizations_uk.dart
    - test/features/planner_view_model_test.dart
    - test/features/planner_screen_test.dart
    - test/l10n/planner_copy_safety_test.dart
decisions:
  - "The ceiling is the number of supplements currently carrying a schedule (design spec §3.1). Research's options A (peak), B (peak-with-floor) and C (fixed constant) stay rejected and unimplemented."
  - "scheduledCount is derived from loadRows — the same collection the week loads count — so load <= ceiling holds by construction and the chart needs no cap, clamp or over-segment."
  - "The axis-centre label was REPLACED, not removed: a self-scaling chart with an invisible denominator invites the reader to invent a limit."
  - "The week-column semantics label now passes substancesCount(load); weekBarSemantics itself is untouched."
metrics:
  duration: ~45m
  completed: 2026-08-17
actuals:
  tokens: 21000
  tasks: 3
  commits: 4
status: complete
---

# Phase 06 Plan 05: Load Chart Neutralization Summary

The weekly load chart now scales against the user's own scheduled stack instead of an
editorial limit: one bar colour at every height, no dashed reference line, no over-limit
segment, and a factual scale caption where the limit legend used to sit.

## What Was Built

**Task 1 — the ceiling on the model.** `CyclesModel.scheduledCount` holds how many
supplements currently carry a schedule, filled in `buildCyclesModel` from `loadRows` — the
very collection the week loads are counted from, so `load <= scheduledCount` holds by
construction rather than by coincidence. Its doc comment records that invariant, why it
makes an over-bar and a cap unnecessary, and why the two edge values (ceiling 1 → a full
bar; ceiling 0 → the empty state, no chart) are correct by design.

Behaviour tests came first and failed first: full-schedule stacks, an unscheduled
supplement not raising the ceiling, a paused supplement counted exactly as the loads count
it, ceiling 1 with a full-load week, ceiling 0 for both "nothing scheduled" and an empty
stack, and an invariant test asserting `load <= scheduledCount` over every bucket of 40
deterministically generated stacks (varying size, cadence, start offsets, pauses and
schedule-bearing-ness).

**Task 2 — the chart.** Bar height is now `round(load / scheduledCount * 38)`, with the
ceiling passed in from `planner_screen.dart` off the model (the widget holds no scale of
its own). Deleted: the second height computation and the `load-over-$index` container, the
threshold offset / dash-on / dash-off / width constants, the `load-threshold`
`PositionedDirectional`, `_ThresholdLinePainter`, and the three-way bar-colour ternary.
The `load == 0` 2px stub survives unchanged. The axis row keeps its three-slot shape with
`loadScaleCaption` in the centre — uk «повний стовпчик — увесь стек», en "full bar = your
whole stack" — added to both locales and regenerated with `flutter gen-l10n`. The
week-column accessibility label keeps `weekBarSemantics` and now passes
`substancesCount(load)` instead of `weekLoadLabel(load, slotsCount(editorialLimit))`.

**Task 3 — the contract as tests.** Stack-of-one draws a full bar (commented in the test as
correct-by-design, since it is the case a later reader is most likely to file as a bug);
four loads against a ceiling of four rise strictly with the largest exactly 38; every bar
in a mixed-load chart resolves the same bar token, asserted across all bars in one pump;
a stack with nothing scheduled renders the empty state and **no** `PlannerLoadChart` at all
(absence asserted, not just the empty state's presence); the caption renders at mono 10 in
both locales. The former dashed-line test was inverted into an absence test covering both
`load-threshold` and every `load-over-$index` key.

## Verification

- `flutter analyze` — **0 issues**.
- `flutter test` — **790 passing**, up from the 778 baseline; zero tests deleted.
- `git diff --quiet -- pubspec.yaml pubspec.lock` — clean (no package added).
- `grep -rnE "ThresholdLinePainter|load-threshold|load-over" lib/features/calendar/` → 0.
- `grep -cE "BqColors\.(warn|risk|calm)" lib/features/calendar/planner_load_chart.dart` → 0;
  the state colours in `dose_row.dart`, `day_block_section.dart`, `day_progress_ring.dart`
  and `week_strip.dart` are untouched.
- `grep -c "BqColors.loadBar" lib/features/calendar/planner_load_chart.dart` → 1.
- `grep -c "weekBarSemantics" lib/features/calendar/planner_load_chart.dart` → 1.
- `grep -rn "loadAxisLegend" lib/` (excluding generated + ARB) → 0.
- `loadScaleCaption` present in both ARB files and in all three generated locale files.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 — missing critical functionality] The new ARB key would have arrived unscanned
by the PLAN-04 copy gate**
- **Found during:** Task 2
- **Issue:** `test/l10n/planner_copy_safety_test.dart` demands that every planner ARB key be
  rendered into `plannerCopy()` and scanned for forbidden vocabulary, but its prefix list
  carries `loadChart` and `loadAxis` only. `loadScaleCaption` matched neither, so the new
  caption would have shipped outside the gate — the exact "new copy arrives unchecked"
  failure (WR-04) that test exists to prevent, and it would have passed silently.
- **Fix:** Added the `loadScale` prefix and a `loadScaleCaption` entry in `plannerCopy()`.
- **Files modified:** `test/l10n/planner_copy_safety_test.dart`
- **Commit:** 220b554

### Deliberate scope notes

**`grep -rn "weekLoadLabel" lib/` is not yet zero, and that is correct.** The plan's
acceptance criterion assumed the chart was the key's last consumer. It is not:
`planner_week_detail.dart:153` still calls it, and 06-06 explicitly owns that call site
(06-06-PLAN.md line 69 deletes the free-slots half of that meta line) before it deletes the
key. `add_supplement_sheet.dart:360` names it only in a code comment, and the generated
l10n still defines it. **The chart's consumer — the one this plan owns — is gone**, and
`planner_load_chart.dart` contains no `weekLoadLabel` reference at all.

**Existing planner tests were inverted, never weakened.** Three load-chart tests changed
meaning deliberately: the banding test now asserts heights against the new denominator and
one colour, the dashed-line test asserts absence of the line and of every over-bar key, and
the semantics test asserts `4 речовини` with an explicit `isNot(contains('слот'))`. Nothing
was deleted or relaxed.

**Not touched, on purpose:** `editorialLimit`, `comfortLoad`, `LoadVerdict`, the
`thresholdDash` token and every ARB key 06-06 removes — their remaining consumers (week
detail, year grid, the two summary chips) still compile and their tests still pass.

## Known Stubs

None.

## Threat Flags

None — no new network, auth, file-access or schema surface. T-06-12 (division by a zero
ceiling) is mitigated by absence, asserted by the no-chart test rather than by a guard
branch; T-06-13 by the model-side invariant test; T-06-14 by the two-locale caption test.

## Self-Check: PASSED

- `lib/features/calendar/planner_view_model.dart` — FOUND
- `lib/features/calendar/planner_load_chart.dart` — FOUND
- `lib/core/l10n/arb/app_uk.arb`, `app_en.arb` — FOUND, both carry `loadScaleCaption`
- `.planning/phases/06-shell-simplification/06-05-SUMMARY.md` — FOUND
- Commits 4627d0a, dca8b66, 220b554, 1ad87f4 — all FOUND in `git log`
