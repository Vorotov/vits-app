---
phase: 04-planner-views
verified: 2026-08-16T00:41:58Z
status: passed
score: 48/52 must-haves verified
behavior_unverified: 1
overrides_applied: 0
behavior_unverified_items:
  - truth: "UI-SPEC #18 (E8), system-back clause: system back from the planner returns to Today rather than leaving the tab"
    test: "Open the Calendar tab → tap 'Планувальник' → trigger the platform back gesture / hardware back button (Android back swipe, iOS predictive back)"
    expected: "The Calendar tab swaps back to the Today page, the NavigationBar never moves, and the app does not exit or change tabs"
    why_human: "The PopScope is present and correctly wired (canPop: false + onPopInvokedWithResult → showToday()), but no test in the suite drives a route pop — the only tested path is the in-app '‹ Сьогодні' control, which reaches the same destination state through a different trigger. Presence checks cannot see whether the platform back channel actually reaches the interceptor."
human_verification:
  - test: "DATA-03 on-device loop re-check: flutter test integration_test/data03_loop_test.dart -d <device> on an iOS device/simulator AND an Android emulator/device"
    expected: "Green on both platforms — the planner has not regressed the core plan → see → mark-taken loop"
    why_human: "Requires attached devices. The verifying process has none; the orchestrator is running this separately. Evidence requirement: the two exit codes / test-run tails, one per platform, recorded before phase sign-off. Not to be inferred from the desktop suite."
  - test: "Backstop #22 — gantt legibility under load. On a 390pt simulator in uk, seed 7+ supplements carrying the longest realistic uk names."
    expected: "Hatched planned segments are visually distinguishable from solid active ones at the 11px track height; row labels stay legible and ellipsize rather than overflow"
    why_human: "verification: backstop in 04-03 — a visual-discriminability judgement no widget test can make. Note: 04-05 changed rendered layout on the Рік segment (year legend, month-detail card header, month-detail row), so the month-detail card and the year legend should be looked at specifically."
  - test: "Backstop #23 — week-column tap ergonomics. On a physical device, pick several specific weeks among the 18 load-chart columns."
    expected: "Selecting an intended week is achievable in practice; a mis-tap on an adjacent week is immediately obvious and instantly correctable"
    why_human: "verification: backstop in 04-03 — a ~15px-wide column mitigated by height (53px opaque target, DECIDED-10). Whether that mitigation is sufficient is a physical-touch judgement; a simulator tap proves nothing about it."
  - test: "Backstop #24 — live midnight crossing. Leave the planner open across local midnight, or change the device clock past midnight with the planner on screen."
    expected: "The today marker moves, a run starting today flips from hatched to solid, the default week and month selection re-seed, and the header subtitle is not stale"
    why_human: "verification: backstop in 04-05. The automatable half (advancing the pinned todayProvider clock) is covered by the 'cross-segment integration' group at planner_screen_test.dart:2054; the live/device-clock half — that the real midnight timer fires and the open tree rebuilds — is not reachable from flutter_test."
  - test: "Visual fidelity pass: both planner segments in uk on a real device against mockup screens 03 and 04"
    expected: "Gantt, load chart, week detail, year grid and month detail match the approved mockup's proportions, spacing and colour"
    why_human: "VALIDATION.md 'Manual-Only Verifications' item 1 — pixel/visual judgement against an HTML mockup."
---

# Phase 4: Planner Views Verification Report

**Phase Goal:** A user can see the shape of their supplement schedule over time — overlapping cycles, concurrent load, and a full year of coverage — framed as an editorial tracking aid, never medical guidance.
**Verified:** 2026-08-16T00:41:58Z
**Status:** passed — all 6 human-verification items confirmed in 04-UAT.md (DATA-03 re-run on both devices before and after the fix pass; backstops driven or measured with real numbers; system-back closed with a real test)
**Re-verification:** No — initial verification

## Independent Gate Re-runs

Every command below was re-run by the verifier in its own process. SUMMARY.md claims were not accepted as evidence.

| Gate | Command | Result |
| ---- | ------- | ------ |
| Static analysis | `flutter analyze` | `No issues found! (ran in 2.3s)` — exit 0 ✓ |
| Full suite | `flutter test` | `+527: All tests passed!` — exit 0 ✓ (matches the claimed 527/527) |
| Phase-4 files only | `flutter test` over the 8 Phase-4 test files | `+240: All tests passed!` — exit 0 ✓ |
| No materializing import | comment-stripped grep for `dayDosesProvider\|dayDosesReadOnlyProvider\|ensureLogsForDay\|IntakeRepository\|intakeRepoProvider` over `lib/features/calendar/planner_*.dart` | 0 hits ✓ |
| Single clock source | comment-stripped grep for `DateTime.now(\|DateTime.timestamp(\|clock.now(` over the same 8 files | 0 hits ✓ |
| Token-only colour | comment-stripped grep for `Color(0x\|Color.fromARGB\|(^\|[^A-Za-z0-9_])Colors\.` over the same 8 files | 0 hits ✓ |
| Planner file glob | `ls lib/features/calendar/planner_*.dart \| wc -l` | 8 ✓ (the glob gate's `>= 8` floor is real) |
| Zero-write row count | `planner_invariants_test.dart` full-render + week-tap + month-tap row count; `providers_planner_test.dart` provider-level count | both green, `intakeLogs` count 0 before and after ✓ |
| PLAN-04 copy safety | `flutter test test/l10n/planner_copy_safety_test.dart` | green — 4 tests over both locales ✓ |
| Text-scale matrix | `planner_screen_test.dart:2258` `for (final scale in const <double>[1.0, 1.6, 2.0])` × 2 locales × 4 surfaces | green, `takeException()` null throughout ✓ |
| ARB parity | key-set diff of `app_en.arb` / `app_uk.arb` | 160 / 160, symmetric difference empty ✓ |
| uk CLDR plurals | all 8 count-bearing keys | every one carries `one/few/many/other` ✓ |
| Debt markers | `TBD\|FIXME\|XXX` across all phase-touched files | 0 hits ✓ |

## Goal Achievement

### ROADMAP Success Criteria

| # | Success Criterion | Status | Evidence |
| - | ----------------- | ------ | -------- |
| 1 | ~4-month Cycles gantt: one row per supplement, solid active / lighter-hatched planned segments, today marker | ✓ VERIFIED | `planner_gantt.dart` — `GanttRowBar` + `CustomPainter`; hatch at `plannedHatchStrong/Weak` + `plannedBorder`; `ValueKey('gantt-today-marker')` positioned at `(todayIndex + 0.5)/span * width`; rows come from `buildCyclesModel` in `stackEntriesProvider` order. Window is derived (`plannerWindow` = `[firstOfMonth(today), +4 months)`), with span tests pinning 120 / 122 / 123 at `planner_window_test.dart:24,28,35`. |
| 2 | Weekly concurrent-load chart against the editorial 5-substance line; tap a week for load, verdict, active supplements | ✓ VERIFIED — see reading note below | `planner_load_chart.dart`: main bar `min(load, editorialLimit)/editorialLimit * 38`, `risk` over-bar above it, `loadAxisLegend(editorialLimit, comfortLoad)` renders "межа 5 · комфорт 3". `planner_week_detail.dart`: `weekLoadLabel(load, editorialLimit)`, exhaustive `switch (verdictOf(load))` → verdict chip, `ValueKey('week-name-chips')` `Wrap` of active supplements. Tap→select→no-write proven at `planner_screen_test.dart:1185` and in the invariants row-count test. |
| 3 | 12-month Year matrix of per-supplement coverage bars (lighter = planned); tap a month for detail | ✓ VERIFIED | `planner_year_grid.dart` — 12 cards, `crossAxisCount: 4`, `shrinkWrap: true` + `NeverScrollableScrollPhysics`, `mainAxisExtent: monthCardExtentFor(scaler, rowCount)`, `_minBarFraction = 0.22`. `planner_month_detail.dart` renders per-supplement rows keyed off `Supplement.colorValue`, tinted when coverage is entirely planned. Month tap → `selectedMonthProvider` → `resolvedMonthIndexProvider` asserted at `planner_invariants_test.dart:551-553`. |
| 4 | Every planner screen carries the educational disclaimer and presents the 5-substance limit as editorial, not medical | ✓ VERIFIED | Structural: `_BodyScroll` appends `_FaintNote(plannerDisclaimer)` as the last child unconditionally — both segments and all three async surfaces (data/empty/error) route through it, so it cannot be omitted by state. Behavioural: `planner_invariants_test.dart` asserts `find.text(l10n.plannerDisclaimer)` below the fold on both segments in both locales. Editorial framing gated by `planner_copy_safety_test.dart` (11-term forbidden list + "норма/medical standard" permitted only inside the disclaimer's own negation) and by `excludedMockupContent` over the rendered tree. |

**SC2 reading note (recorded deliberately, per the plan checker's flag).** The roadmap wording is "against the editorial 5-substance line"; the approved UI-SPEC DECIDED-2 ships **one** dashed line, at comfort-3, and expresses the 5-limit structurally and textually rather than as a second dashed rule. I verified the criterion is genuinely met by those mechanisms rather than filing it as a miss:

- **Structural (the strongest form).** `_barFullHeight = 38` is reached at exactly `load == editorialLimit`; everything above it is a separately-coloured `risk` over-bar (`planner_load_chart.dart:266-277`). The 5-line is therefore drawn as a colour discontinuity *at the exact pixel height a dashed 5-line would occupy* — the reader measures against it without extra ink.
- **Textual, four times.** `loadAxisLegend(5, 3)` → "межа 5 · комфорт 3" directly under the chart; `limitBadge(5)` on the summary chip; `weekLoadLabel(load, 5)` in the week detail; the verdict chip via `verdictOf` banding on `editorialLimit`.
- **Not mislabelled.** The one drawn line's only labels are "межа" and "комфорт"; `planner_copy_safety_test.dart` proves neither is ever described as safe, normal, a medical standard or an overdose threshold, in either locale.

A second dashed line at the 38px cap would land on that same boundary and read as redundant chrome on a 46px chart. The criterion's intent — the user can see their weekly load *relative to the editorial 5* — is satisfied. **This is an accepted, documented reading of SC2, not an unmet criterion.**

### Observable Truths — 04-01 (tracer: window math, pure projections, reachable gantt)

| # | Truth | Status | Evidence |
| - | ----- | ------ | -------- |
| 1 | UI-SPEC #5: paused regimen keeps its gantt row, bare track, never hidden/greyed | ✓ VERIFIED | `buildCyclesModel` keeps every regimen-bearing entry; `activeRuns` returns `[]` for a paused regimen without special-casing, and `GanttRow.segments` empty is documented as a valid state. Seeded paused regimen `ir1` in the invariants fixture renders. |
| 2 | UI-SPEC #6: one-day run at 2px floor, zero runs no segment, continuous run full-width | ✓ VERIFIED | `_minSegmentWidth = 2` applied via `math.max` at `planner_gantt.dart:488`; `DateRun` start==end is a real run by construction. |
| 3 | UI-SPEC #19: Calendar entry action always renders and shares a `Wrap` with `backToToday` | ✓ VERIFIED | `calendar_screen.dart:181` `Wrap` (comment cites WR-04); test `planner_screen_test.dart:2481` asserts second-line flow at textScaler 2.0. |
| 4 | Opening the planner creates zero `IntakeLog` rows (row count byte-identical) | ✓ VERIFIED | `providers_planner_test.dart:154,181` (both models) + `planner_invariants_test.dart:526,562` (full widget tree, incl. selections). Re-run green. |
| 5 | `isActiveOn` is the single activity decision; no modulo/on-day/off-day arithmetic re-derived | ✓ VERIFIED | `activeRuns` is the only decision point; gate at `planner_invariants_test.dart:250` forbids `onDays`/`offDays`/`%` in the model. Independently confirmed by reading the file. |
| 6 | The pure view-model imports exactly three libraries | ✓ VERIFIED | Read directly: `cycle_math.dart`, `models.dart`, `repositories.dart` and nothing else. Exact-list gate at `planner_invariants_test.dart:223`. |
| 7 | Window derived, never assumed 122; month fractions from real lengths, sum 1.0 | ✓ VERIFIED | `plannerWindow` computes span from `addMonths(start, 4)`; `MonthColumn.fraction = length / span`; `planner_window_test.dart` pins 120/122/123 and asserts fractions sum to 1.0 across a month sweep (`:150`). |
| 8 | Planner reached as a second page inside the Calendar tab; system back returns to Today; no route pushed | ⚠️ PARTIAL — page-swap ✓ VERIFIED, system-back clause carried by 04-02 #5 below | `calendar_screen.dart:69-83` is a conditional page swap with no `Navigator.push`; the NavigationBar lives in the shell `IndexedStack` and is untouched. The back-to-Today transition is tested through the in-app control (`planner_screen_test.dart:345`). The platform-back path is the unexercised clause — see 04-02 #5. |
| 9 | Exactly eight new colour tokens under a Phase-4 banner; no colour literal in any planner widget | ✓ VERIFIED | `tokens.dart:123` banner, then exactly 8: `plannedHatchStrong`, `plannedHatchWeak`, `plannedBorder`, `todayMarker`, `thresholdDash`, `loadBar`, `monthSelectedBg`, `yearBarTrack`. Colour-literal grep over the 8 planner files: 0 hits. |

### Observable Truths — 04-02 (ARB set, planner shell, empty/error, disclaimer)

| # | Truth | Status | Evidence |
| - | ----- | ------ | -------- |
| 1 | UI-SPEC #1 empty: single `emptyPlannerTitle` block, matching body variant, no chip, disclaimer still renders | ✓ VERIFIED | `_surface` → `_EmptyPlanner` when `isEmpty`; `hasStack ? emptyPlannerBodyNoRegimen : emptyPlannerBody` at `planner_screen.dart:670`; disclaimer appended by `_BodyScroll` regardless of branch. |
| 2 | UI-SPEC #2 loading: header + segmented control, empty body, no spinner | ✓ VERIFIED | `_surface` loading arm returns `const <Widget>[]` — there is no spinner widget to render. Test at `planner_screen_test.dart:650`. |
| 3 | UI-SPEC #3 error: `plannerLoadError` + `retry`, no stack trace or raw exception | ✓ VERIFIED | `AsyncError() => const [_PlannerError()]` — `_PlannerError` is `const` and takes no error object, so no exception text is structurally reachable. Renders `plannerLoadError` + `retry` only. |
| 4 | UI-SPEC #7: gantt row name and mono hint both `Flexible` with ellipsis, no fixed-width box | ✓ VERIFIED | `planner_gantt.dart:423-427` `Flexible` + `TextOverflow.ellipsis`; covered by the text-scale matrix. |
| 5 | UI-SPEC #18: both segments always render; subtitle switches; each segment retains its selection; **system back returns to Today rather than leaving the tab** | ⚠️ PRESENT_BEHAVIOR_UNVERIFIED | First three clauses ✓: subtitle/default at `planner_screen_test.dart:469`, cross-segment selection retention at `:673` (backed by the `9811f83` fix holding both selections for the screen's lifetime). The system-back clause is present and correctly wired (`PopScope(canPop: false, onPopInvokedWithResult: … showToday())`) but **no test in the whole suite drives a route pop** — `grep -rn "popRoute\|PopScope\|didPopRoute\|maybePop" test/` returns only two unrelated `regimen_editor_test.dart` hits. Routed to human verification. |
| 6 | The disclaimer closes BOTH segments as the same ARB key, incl. empty and error surfaces | ✓ VERIFIED | Structural via `_BodyScroll`; asserted at `planner_screen_test.dart:527` and on both segments in both locales in the invariants suite. |
| 7 | No planner copy describes the limit as safe/normal/medical/overdose; enforced by test, not review | ✓ VERIFIED | `planner_copy_safety_test.dart` — 11-term forbidden list over 40+ resolved strings in both locales, plurals sampled at 1/2/5; negation-only terms restricted to `plannerDisclaimer`. Re-run green. |
| 8 | Every Phase-4 string in both locales in one commit; every count-bearing key has all four uk forms at 1/2/5/11/21 | ✓ VERIFIED | ARB key sets identical (160/160). All 8 plural keys carry `one/few/many/other`; `plurals_test.dart` (19 tests) exercises the boundaries. |
| 9 | Standalone month names via standalone pattern letters, pinned by uk nominative test | ✓ VERIFIED | `DateFormat('LLLL', locale)` for the standalone peak-chip month; `DateFormat.MMMd` (format/genitive) where a day number is present. `month_names_test.dart` pins both cases and asserts they genuinely differ in uk. |
| 10 | Gantt row hint composed from the Stack card's schedule-summary helper minus its daily-slot tail | ✓ VERIFIED | `planner_gantt.dart:393-394` — `scheduleSummaryText(scheduleSummaryOf(row.entry), …)`, the same `stack_status.dart` helper the Stack tab uses. |

### Observable Truths — 04-03 (Цикли complete)

| # | Truth | Status | Evidence |
| - | ----- | ------ | -------- |
| 1 | UI-SPEC #4: one row per regimen-bearing entry in stack order, 13px apart; gridlines at real month boundaries; today marker always renders | ✓ VERIFIED | `buildCyclesModel` preserves `stackEntriesProvider` order; `ValueKey('gantt-gridline-$i')` placed from `MonthColumn` fractions; `todayIndex` is inside the window by construction of `plannerWindow`. |
| 2 | UI-SPEC #8: exactly the full Monday weeks covering the window (18 or 19); one opaque tap target ≥53px tall; selected 1.0 / others 0.5 | ✓ VERIFIED | `weekBuckets` from `mondayOfWeek`; `_chartHeight 46 + _chartHeadroom 7 = 53`; `HitTestBehavior.opaque`; `Opacity(selected ? 1.0 : 0.5)`. Test `planner_screen_test.dart:1003` asserts 18-or-19. |
| 3 | UI-SPEC #9: zero-load 2px `field` stub; over-limit 38px cap + proportional `risk` over-bar; 4–5 renders `warn` | ✓ VERIFIED | `_zeroStubHeight = 2` with `BqColors.field`; banding at `planner_load_chart.dart:273-277`. Test at `:1059`. |
| 4 | UI-SPEC #10: chart derives synchronously; no loading/error surface of its own | ✓ VERIFIED | `PlannerLoadChart` takes a resolved `CyclesModel` as a required field — there is no `AsyncValue` in its signature. |
| 5 | UI-SPEC #11: week-detail always renders; at load 0 shows comfort verdict, five empty pips, free-slot line n=5, empty chip `Wrap` | ✓ VERIFIED | `verdictOf(0)` → `ComfortVerdict`; pip row always built; `weekFreeSlots(free)` / `weekNoFreeSlots`; `ValueKey('week-name-chips')` `Wrap` renders empty rather than an empty-state block. |
| 6 | UI-SPEC #12: verdict chip non-flexible, no wrap; range/meta column `Expanded`; name chips in a `Wrap` | ✓ VERIFIED | `planner_week_detail.dart:131` `Expanded`, `:164-177` chip with `softWrap: false` outside any `Flexible`. |
| 7 | Month widths/gridlines from real month lengths, never a fixed quarter; window 120–123 days | ✓ VERIFIED | Same evidence as 04-01 #7; explicitly re-tested at `planner_window_test.dart:136,150`. |
| 8 | Exactly one dashed line, at comfort-3; the 5-limit drawn structurally as the bar cap; neither labelled a safety threshold | ✓ VERIFIED | One `PositionedDirectional(key: 'load-threshold', bottom: 22.8)` with a single `_ThresholdLinePainter`; `_thresholdOffset = 22.8 = 0.6 × 38`. Cap/over-bar per SC2 note. Labels gated by `planner_copy_safety_test.dart`. |
| 9 | Tapping a week selects it, updates the inline detail, writes nothing; never a modal sheet | ✓ VERIFIED | `selectedWeekProvider` → `resolvedWeekIndexProvider`; detail is a sibling card in the same `ListView`, no `showModalBottomSheet` anywhere in the planner files. Write-freedom proven by the invariants row count across a real tap. |
| 10 | Every week column carries `Semantics(button, selected, onTap)` on the node itself, not a descendant | ✓ VERIFIED | `planner_load_chart.dart:282-296` — `onTap: select` on the `Semantics` node above `excludeSemantics: true`. Proven behaviourally: `planner_screen_test.dart` activates it via `tester.semantics.performAction`, not a widget tap. |
| 11 | A `RepaintBoundary` wraps the gantt card | ✓ VERIFIED | `planner_gantt.dart:98` `return RepaintBoundary(`. |
| 12 | **Backstop:** 7+ supplements, longest uk names, 390pt — hatched vs solid distinguishable at 11px, labels legible | ? INSUFFICIENT_SPEC → human | `verification: backstop`. No explicit evidence of a completed simulator pass; 04-05 SUMMARY records it as still open (#22). Not silently passed. |
| 13 | **Backstop:** picking a specific week among 18 columns on a physical device is practical and mis-taps are correctable | ? INSUFFICIENT_SPEC → human | `verification: backstop`. Recorded open as #23. |

### Observable Truths — 04-04 (Рік complete)

| # | Truth | Status | Evidence |
| - | ----- | ------ | -------- |
| 1 | UI-SPEC #13: 12 cards, 4 columns, computed main-axis extent, shrink-wrapped, non-scrolling inside the page scroll | ✓ VERIFIED | `planner_year_grid.dart:147-155` — `shrinkWrap: true`, `NeverScrollableScrollPhysics`, `crossAxisCount: _columns`, `mainAxisExtent: monthCardExtentFor(scaler, rowCount)`. |
| 2 | UI-SPEC #14: extent grows with supplement count, never capped; a zero-coverage month still renders its full track set | ✓ VERIFIED | `monthCardExtentFor` is `fixed + scaler(text) + rowCount * barExtent` with no clamp; tracks are built per entry regardless of `frac`. Test at `planner_screen_test.dart:1647` (twelve supplements at scaler 2.0). |
| 3 | UI-SPEC #15: exactly one card selected; selection changes only fill and border width; count `risk` strictly above the limit | ✓ VERIFIED | `resolvedMonthIndexProvider` returns a single int; `monthSelectedBg` fill; `color: over ? BqColors.risk : BqColors.textFaint` with `over = load > editorialLimit` (strict). |
| 4 | UI-SPEC #16: mono month label `Flexible` with ellipsis, count non-flexible | ✓ VERIFIED | `planner_year_grid.dart:262` `Flexible` label against a rigid count. |
| 5 | UI-SPEC #17: month detail lists only non-zero-coverage supplements in stack order; zero-coverage renders empty copy inside the same card; name column `Expanded`, state text non-flexible and non-wrapping | ✓ VERIFIED | `planner_month_detail.dart` filters on coverage and renders `monthEmpty` inside the card. Note 04-05 amended the state label to WRAP rather than ellipsize ("частина місяця" is state content a truncation would misstate) — a deliberate, recorded refinement of "does not wrap", fixed in the widget rather than by relaxing an assertion. |
| 6 | 22% minimum bar width; ≥85% coverage shows full width | ✓ VERIFIED | `_minBarFraction = 0.22`; `fullMonthFraction = 0.85` with `MonthCell.full`. |
| 7 | Year matrix is always today's year Jan–Dec, no paging; Цикли may cross into next year while Рік does not; each subtitle says which | ✓ VERIFIED | `buildYearModel` hardcodes `DateTime.utc(t.year, 1, 1)`..`12, 31` with no page state; `plannerRangeSubtitle` vs `plannerRangeSubtitleCrossYear` vs `plannerYearSubtitle` are three distinct ARB keys. Cross-year windows pinned at `planner_window_test.dart:118`. |
| 8 | The peak chip warns strictly above the limit while the Цикли chip warns at-or-above; asymmetry deliberate and recorded | ✓ VERIFIED | `planner_screen.dart:399` `final over = load > editorialLimit` with a "do not reconcile them" comment; `editorialLimit` doc in `planner_view_model.dart:344-350` records the asymmetry at source. Test at `planner_screen_test.dart:1837`. |
| 9 | The Year body renders the footnote ABOVE the same disclaimer, not instead of it | ✓ VERIFIED | `_BodyScroll` emits `footnote` then `plannerDisclaimer` as the final child. Rendered-position assertion at `planner_screen_test.dart:1875`. |
| 10 | Tapping a month card selects it and re-renders the inline detail in place; never a modal; writes nothing | ✓ VERIFIED | `selectedMonthProvider` → `resolvedMonthIndexProvider`, asserted == 3 after a real tap at `planner_invariants_test.dart:551-553`, inside the zero-write row-count test. |

### Observable Truths — 04-05 (phase-close invariants)

| # | Truth | Status | Evidence |
| - | ----- | ------ | -------- |
| 1 | UI-SPEC #20: no layout exception at scalers 1.0/1.6/2.0 in both locales; `takeException()` null | ✓ VERIFIED | `planner_screen_test.dart:2258` matrix loop across 4 surfaces × 2 locales × 3 scalers; re-run green. 04-05 fixed three real overflows in the widgets rather than relaxing assertions. |
| 2 | UI-SPEC #21: no planner path writes/materializes/imports the materializing provider; `risk`/`warn` mean only over/at the editorial limit; no forbidden vocabulary in either ARB | ✓ VERIFIED | All three greps independently re-run at 0 hits; row-count test green; copy-safety gate green. |
| 3 | Every selectable node exposes an accessible tap action on its own semantics node, verified by assistive-tech activation not a widget tap | ✓ VERIFIED | Week column and month card both activated through `tester.semantics.performAction` (`planner_screen_test.dart` scale-matrix group, final two cases) — the selection follows. This is the behavioural proof, not a presence check. |
| 4 | Phase-3 baseline preserved: full suite green, static analysis zero issues with the planner in the tree | ✓ VERIFIED | Independently re-run: `flutter analyze` → 0 issues; `flutter test` → 527/527, exit 0. |
| 5 | PLAN-04 enforced by executable checks: disclaimer asserted on both segments, forbidden vocabulary over both locales, no excluded mockup content reachable | ✓ VERIFIED | Three-layer gate confirmed green: `planner_copy_safety_test.dart` (ARB), `planner_invariants_test.dart` `excludedMockupContent` (rendered tree, 7 entries incl. the case-sensitive `Зсунути`), plus the 3-entry legend and no-FAB assertions. |
| 6 | **Backstop:** crossing local midnight with the planner open moves the marker, flips a run hatched→solid, re-seeds selections, no stale subtitle | ? INSUFFICIENT_SPEC → human | `verification: backstop`. The pinned-clock half is covered (`planner_screen_test.dart:2054`); the live/device-clock half is not reachable from flutter_test. Recorded open as #24. |

**Score:** 48/52 truths verified (1 present, behavior-unverified; 3 backstops routed to human)

### Required Artifacts

| Artifact | Expected | Status | Details |
| -------- | -------- | ------ | ------- |
| `lib/core/domain/cycle_math.dart` | `firstOfMonth`, `addMonths`, `daysInMonth`, `plannerWindow`, promoted `mondayOfWeek` | ✓ VERIFIED | All five present; `plannerWindow` returns a record with a derived `span`. Wired by `planner_view_model.dart`. |
| `lib/features/calendar/planner_view_model.dart` | `DateRun`, `activeRuns`, `GanttSegment`, `ganttSegments`, `GanttRow`, `MonthColumn`, `CyclesModel`, `buildCyclesModel` — clockless, string-free | ✓ VERIFIED | 552 lines, all symbols present plus `WeekBucket`/`WeekLoad`/`LoadVerdict`/`MonthCell`/`YearModel`. Three imports exactly; no Cyrillic in comment-stripped source. |
| `lib/features/calendar/planner_providers.dart` | `cyclesModelProvider` | ✓ VERIFIED | Present with `yearModelProvider`, both segment/week/month controllers and the two clamped resolvers. Watches `stackEntriesProvider` + `todayProvider` only. |
| `lib/features/calendar/planner_gantt.dart` | `PlannerGantt` + `GanttRowBar` + painter | ✓ VERIFIED | Present, ~500 lines, `RepaintBoundary`, gridlines, today marker, 3-entry legend, hatch painter. |
| `lib/features/calendar/planner_screen.dart` | In-tab planner page, header, gantt card, shell, empty/error/loading, both bodies | ✓ VERIFIED | Present, ~730 lines; `_CyclesBody`, `_YearBody`, `_surface`, `_BodyScroll`, `_EmptyPlanner`, `_PlannerError`, `_YearPeakChip`, `_YearLegend`. |
| `lib/core/theme/tokens.dart` | Eight Phase-4 colour tokens | ✓ VERIFIED | Banner at `:123`, exactly 8 tokens follow. |
| `lib/features/calendar/planner_load_chart.dart` | `PlannerLoadChart` | ✓ VERIFIED | 388 lines; columns, banding, dashed comfort line, per-column tap + semantics. |
| `lib/features/calendar/planner_week_detail.dart` | `PlannerWeekDetail` | ✓ VERIFIED | Range, load label, free slots, verdict chip, pips, name chips, note. |
| `lib/features/calendar/planner_year_grid.dart` | `PlannerYearGrid`, `_MonthCard`, `monthCardExtentFor` | ✓ VERIFIED | All present; computed extent, 0.22 floor, semantics on the node. |
| `lib/features/calendar/planner_month_detail.dart` | `PlannerMonthDetail` | ✓ VERIFIED | Per-supplement rows, colour dots from `colorValue`, coverage state. |
| `lib/core/l10n/arb/app_uk.arb` / `app_en.arb` | Complete Phase-4 sets, four-form plurals, @-descriptions | ✓ VERIFIED | 160 keys each, symmetric; all 8 plural keys four-form. |
| `test/providers_planner_test.dart` | No-materialization row-count gate | ✓ VERIFIED | 5 tests incl. both models' row counts and soft-delete propagation. |
| `test/l10n/month_names_test.dart` | Standalone-vs-format month case pinning for uk | ✓ VERIFIED | 6 tests; asserts the two cases genuinely differ. |
| `test/l10n/planner_copy_safety_test.dart` | PLAN-04 forbidden-vocabulary gate over both locales | ✓ VERIFIED | 4 tests; the positive half (disclaimer contains the educational sentence and is strictly longer) is asserted too. |
| `test/features/planner_invariants_test.dart` | Source-level read-only/token-only gates + rendered-tree copy exclusion | ✓ VERIFIED | 10 tests; glob-resolved with a `>= 8` floor; block-comment guard so the stripper stays complete. Mutation-tested per SUMMARY (independently plausible — the gate is a plain `contains` over stripped source, which I re-ran by hand at 0 hits). |
| `test/features/planner_screen_test.dart` | Text-scale matrix + assistive-tech activation | ✓ VERIFIED | 57 test bodies, 98KB; matrix loop and both `performAction` cases confirmed present and green. |

No artifact is a stub. No artifact is orphaned — every `lib/features/calendar/planner_*.dart` file is imported and rendered from `planner_screen.dart`, which is itself reached from `calendar_screen.dart`.

### Key Link Verification

| From | To | Via | Status | Details |
| ---- | -- | --- | ------ | ------- |
| `planner_providers.dart` | `core/providers.dart` | `cyclesModelProvider` watches `stackEntriesProvider` only | ✓ WIRED | `ref.watch(stackEntriesProvider).whenData(...)` + `todayProvider`; no day-dose provider named anywhere (grep 0 hits). |
| `planner_view_model.dart` | `cycle_math.dart` | `activeRuns` calls `isActiveOn` per day | ✓ WIRED | `planner_view_model.dart:60` inside the day loop; no formula restated. |
| `calendar_screen.dart` | `planner_screen.dart` | `calendarPageProvider` swaps the tab's page | ✓ WIRED | `:69` conditional return; `PopScope` wraps `PlannerScreen`. No `Navigator.push` in the file. |
| `planner_screen.dart` | `planner_providers.dart` | `plannerSegmentProvider` drives `BqSegmented` and which body builds | ✓ WIRED | `:85` watch, `:105-106` body selection, `:168` select callback. |
| `planner_gantt.dart` | `stack_status.dart` | shared `scheduleSummaryOf` composition renders the row hint | ✓ WIRED | `:393-394`. |
| `planner_copy_safety_test.dart` | `core/l10n/gen/` | loads both locales and asserts every planner string | ✓ WIRED | `AppLocalizations.delegate.load(Locale(tag))` at `:143`. |
| `planner_load_chart.dart` | `planner_providers.dart` | `selectedWeekProvider` written on tap; `resolvedWeekIndexProvider` drives opacity + detail | ✓ WIRED | `:101` watch, `:280` write. |
| `planner_week_detail.dart` | `planner_view_model.dart` | sealed `LoadVerdict` switched exhaustively → ARB keys + colour band | ✓ WIRED | `:90-105` exhaustive `switch (verdictOf(load))`. |
| `planner_gantt.dart` | `planner_view_model.dart` | `MonthColumn` fractions place labels/gridlines; `todayIndex` places the marker | ✓ WIRED | `:136` months field, `:216` gridline keys, `:227` marker position. |
| `planner_year_grid.dart` | `planner_view_model.dart` | `YearModel` cells drive bar widths, count, peak | ✓ WIRED | Model passed as a required field; cells consumed per row. |
| `planner_year_grid.dart` | `planner_providers.dart` | `selectedMonthProvider` written on tap; `resolvedMonthIndexProvider` drives selection + detail | ✓ WIRED | `:201` write, resolver watched for the selected card. |
| `planner_month_detail.dart` | `core/domain/models.dart` | dot reads `Supplement.colorValue`, tinted when coverage is all-planned | ✓ WIRED | `colorValue` read confirmed; the ONLY sanctioned non-token colour, consistent with the literal gate. |
| `planner_invariants_test.dart` | `lib/features/calendar/` | reads planner sources, asserts forbidden imports/clock/literals absent | ✓ WIRED | `plannerSources()` glob resolves 8 files; independently confirmed. |
| `planner_screen_test.dart` | `planner_screen.dart` | pumps both segments at 3 scalers × 2 locales | ✓ WIRED | `TextScaler.linear(scale)` at `:2270,2300,2334,2368`. |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
| -------- | ------------- | ------ | ------------------ | ------ |
| `planner_gantt.dart` | `model.rows` / `segments` | `cyclesModelProvider` → `buildCyclesModel` → `activeRuns` → `isActiveOn` over Drift-backed `stackEntriesProvider` | Yes — invariants test seeds 3 real supplements + 3 real regimens through the real repositories and the gantt renders from them | ✓ FLOWING |
| `planner_load_chart.dart` | `model.weeks` | `weekLoads(rows, weekBuckets(...))` off the same model | Yes — `load-week-*` columns and `resolvedWeekIndexProvider == 5` after a real tap | ✓ FLOWING |
| `planner_week_detail.dart` | selected `WeekLoad.entries` | `resolvedWeekIndexProvider` indexed into `model.weeks` | Yes — name chips are the bucket's real `StackEntry` list | ✓ FLOWING |
| `planner_year_grid.dart` | `model.months[].cells` | `yearModelProvider` → `buildYearModel` → `monthCellFor` over a full-year `activeRuns` scan | Yes — `month-card-*` keys render and `resolvedMonthIndexProvider == 3` after a real tap | ✓ FLOWING |
| `planner_month_detail.dart` | selected month's non-zero cells | `resolvedMonthIndexProvider` into `YearModel` | Yes — filtered from real coverage fractions | ✓ FLOWING |
| `planner_screen.dart` | disclaimer / footnote / subtitle | `context.l10n` over the real generated delegate | Yes — asserted by `find.text(l10n.plannerDisclaimer)` against the loaded localization, in both locales | ✓ FLOWING |

No hollow props, no static fallbacks, no mock-terminated chains. The soft-delete propagation test (`providers_planner_test.dart:202`) proves the chain is live rather than snapshot.

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
| -------- | ------- | ------ | ------ |
| Static analysis clean with planner in tree | `flutter analyze` | `No issues found!`, exit 0 | ✓ PASS |
| Full suite green | `flutter test` | `+527: All tests passed!`, exit 0 | ✓ PASS |
| Phase-4 test files green in isolation | `flutter test` × 8 Phase-4 files | `+240: All tests passed!`, exit 0 | ✓ PASS |
| Zero-write across a full render + week tap + month tap | contained in `planner_invariants_test.dart` (run above) | row count 0 before and after | ✓ PASS |
| Week column activatable through assistive tech | `tester.semantics.performAction` case (run above) | selection follows | ✓ PASS |
| Month card activatable through assistive tech | `tester.semantics.performAction` case (run above) | selection follows | ✓ PASS |
| Midnight rollover (pinned clock) moves the today marker | `planner_screen_test.dart:2054` (run above) | green | ✓ PASS |
| System back (`PopScope`) returns to Today | — | no test exists in the suite | ? SKIP → human |
| DATA-03 loop on iOS + Android | `flutter test integration_test/data03_loop_test.dart -d <device>` | no device attached to this process | ? SKIP → human (orchestrator running separately) |

Per the one-full-run constraint, `flutter test` was run exactly once for the whole suite; the Phase-4-only run was a single additional targeted invocation over the 8 files, and no per-truth re-runs were performed.

### Probe Execution

No `scripts/*/tests/probe-*.sh` exists in this repository and no PLAN declares a probe path — this is a Flutter app whose executable gates are `flutter test` files, all of which were run above.

| Probe | Command | Result | Status |
| ----- | ------- | ------ | ------ |
| — | — | No probes declared or discovered | N/A |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
| ----------- | ----------- | ----------- | ------ | -------- |
| PLAN-01 | 04-01, 04-02, 04-03, 04-05 | Cycles gantt: one row per supplement, solid active / hatched planned, today marker | ✓ SATISFIED | SC1 evidence above; gantt artifact + key links verified, tests green |
| PLAN-02 | 04-03, 04-05 | Weekly concurrent-load chart with the editorial 5-substance limit; tap a week for load, verdict, active supplements | ✓ SATISFIED | SC2 evidence above incl. the DECIDED-2 reading note |
| PLAN-03 | 04-04, 04-05 | Year matrix: 12 month cards with coverage bars (lighter = planned), tap for details | ✓ SATISFIED | SC3 evidence above |
| PLAN-04 | 04-02, 04-04, 04-05 | Educational disclaimer on planner screens; 5-substance limit framed as editorial, not medical | ✓ SATISFIED | SC4 evidence above; three-layer executable gate (ARB, rendered tree, structural `_BodyScroll`) |

No orphaned requirements: REQUIREMENTS.md maps exactly PLAN-01..04 to Phase 4 and all four are claimed by plans. (REQUIREMENTS.md still shows these as `Pending`/unchecked and ROADMAP.md's Progress table still reads `4. Planner Views | 0/? | Not started` — bookkeeping the orchestrator updates on sign-off, not an implementation gap.)

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
| ---- | ---- | ------- | -------- | ------ |
| — | — | `TBD` / `FIXME` / `XXX` across all phase-touched lib and test files | — | 0 hits — no unreferenced debt markers |
| — | — | `TODO` / `HACK` / `PLACEHOLDER` across the 8 planner files and their tests | — | 0 hits |
| — | — | Empty implementations / hardcoded empty render data | — | None. The `_surface` loading arm returns `const <Widget>[]` deliberately (documented no-spinner decision, Phase-3 precedent) and is not a stub — the data arm renders real cards. |
| `.planning/ROADMAP.md` | 149 | Progress table reads `0/? Not started` while all 5 plan checkboxes are `[x]` | ℹ️ Info | Planning bookkeeping only; orchestrator updates on sign-off |
| `.planning/phases/04-planner-views/04-VALIDATION.md` | 46 | Names `test/l10n/planner_copy_test.dart`; the shipped file is `planner_copy_safety_test.dart` | ℹ️ Info | Filename drift in the validation map. The file the PLAN's `must_haves.artifacts` names is the one that exists and is green; no coverage is missing. |

No blockers. No warnings.

### Human Verification Required

#### 1. DATA-03 on-device loop re-check

**Test:** `flutter test integration_test/data03_loop_test.dart -d <device>` on an iOS device/simulator AND an Android emulator/device.
**Expected:** Green on both platforms — the planner has not regressed the core plan → see → mark-taken loop.
**Why human:** Requires attached devices; this verifying process has none. **Evidence requirement:** record both platform runs' exit codes / output tails in this file before phase sign-off. The orchestrator is running this separately — its outcome is deliberately not guessed here, and the desktop 527/527 result does not substitute for it.

#### 2. Backstop #22 — gantt legibility under load

**Test:** On a 390pt simulator in uk, seed 7+ supplements with the longest realistic Ukrainian names and open Цикли.
**Expected:** Hatched planned segments are clearly distinguishable from solid active ones at the 11px track height; row labels stay legible and ellipsize rather than overflow.
**Why human:** `verification: backstop` — a visual-discriminability judgement no widget test can make. 04-05's three layout fixes changed rendered output on the Рік segment, so also look specifically at the month-detail card and the year legend.

#### 3. Backstop #23 — week-column tap ergonomics

**Test:** On a physical device, pick several specific weeks among the 18 load-chart columns.
**Expected:** Hitting the intended week is achievable in practice; a mis-tap on an adjacent week is immediately obvious and instantly correctable.
**Why human:** `verification: backstop`. Columns are ~15px wide, mitigated by a 53px-tall opaque target (DECIDED-10). Whether that mitigation suffices is a physical-touch judgement a simulator tap cannot answer.

#### 4. Backstop #24 — live midnight crossing

**Test:** Leave the planner open across local midnight, or advance the device clock past midnight with the planner on screen.
**Expected:** The today marker moves, a run starting today flips hatched → solid, the default week and month selections re-seed, and the header subtitle is not stale.
**Why human:** `verification: backstop`. The pinned-clock half is already covered by an automated test; the live half — that the real midnight timer fires and the open tree rebuilds — is not reachable from flutter_test.

#### 5. System back returns to Today (behavior-unverified)

**Test:** Calendar tab → tap "Планувальник" → trigger the platform back gesture / hardware back button.
**Expected:** The Calendar tab swaps back to the Today page; the NavigationBar never moves; the app does not exit or change tabs.
**Why human:** The `PopScope(canPop: false, onPopInvokedWithResult: … showToday())` is present and correctly wired, but no test in the suite drives a route pop — the only tested path is the in-app "‹ Сьогодні" control, which reaches the same destination through a different trigger. Presence checks cannot see whether the platform back channel actually reaches the interceptor. Cheap to fold into item 1's device session.

#### 6. Visual fidelity vs mockup

**Test:** Both planner segments in uk on a real device, compared against mockup screens 03 and 04.
**Expected:** Gantt, load chart, week detail, year grid and month detail match the approved mockup's proportions, spacing and colour.
**Why human:** VALIDATION.md "Manual-Only Verifications" item 1 — a pixel/visual judgement.

### Gaps Summary

**No gaps.** Every artifact exists, is substantive, is wired, and carries real data from `stackEntriesProvider` through the pure model to the rendered tree. Every automated gate this phase declared was re-run independently by the verifier and passed: `flutter analyze` at 0 issues, `flutter test` at 527/527, all 8 Phase-4 test files green in isolation at 240 tests, and all three source-level invariant greps (no materializing import, no direct clock read, no colour literal) reproduced by hand at 0 hits over all 8 planner files.

The phase's central architectural promise — that the planner is a **read-only projection** — holds at all four declared layers, and I confirmed each independently rather than trusting the SUMMARY: the import grep, the provider-level row count, the selection-tap row count, and the full-render row count. The PLAN-04 editorial boundary likewise holds at three layers: the ARB forbidden-vocabulary gate over both locales, the rendered-tree exclusion gate over the mockup-deviation list, and structurally in `_BodyScroll`, which appends the disclaimer as an unconditional final child so no async state — data, empty or error — can drop it.

I specifically tried and failed to falsify three things the SUMMARY asserts. The pure view model really does import exactly three domain libraries (read directly, not inferred from its own test). The eight Phase-4 tokens really are eight, under the banner, with no ninth smuggled in. And `plannerWindow` really is derived rather than hardcoded at 122 — with 120 and 123 both pinned by tests.

Four items remain open, none of them an implementation defect:

- **Three `verification: backstop` truths** (#22 gantt legibility, #23 week-tap ergonomics, #24 live midnight) abstain by design — they are non-inferable from code and are recorded as open in the 04-05 SUMMARY. They are routed to human verification rather than silently passed.
- **One behavior-unverified truth**: the system-back clause of UI-SPEC #18. The `PopScope` is present and correct, but the platform-back path is unexercised by any test in the repository; the in-app back control test reaches the same destination through a different trigger, which is not the same proof.
- **DATA-03's on-device re-check** is a declared manual gate that the orchestrator is running separately; its outcome is deliberately not guessed here.

Status is `human_needed`, not `passed`, purely because that human-verification list is non-empty. The codebase side of the phase goal is achieved.

---

_Verified: 2026-08-16T00:41:58Z_
_Verifier: Claude (gsd-verifier)_
