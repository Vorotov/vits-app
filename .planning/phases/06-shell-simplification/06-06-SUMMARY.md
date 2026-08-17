---
phase: 06-shell-simplification
plan: 06
subsystem: planner
tags: [plan-05, deletion, l10n, copy-gate, absence-gates]
status: complete
requires:
  - "06-05: the scheduled-supplement ceiling and the neutralized load chart"
provides:
  - "A planner with no verdict, no badge, no pip row, no footnote and no judgement colour anywhere"
  - "A rewritten plannerDisclaimer in both locales carrying no limit vocabulary"
  - "A strictly stronger copy gate (four uk limit stems in the hard list, the negation exemption deleted)"
  - "Two source-glob absence gates over lib/features/calendar/planner_*.dart"
affects:
  - lib/features/calendar/planner_week_detail.dart
  - lib/features/calendar/planner_screen.dart
  - lib/features/calendar/planner_year_grid.dart
  - lib/features/calendar/planner_month_detail.dart
  - lib/features/calendar/planner_view_model.dart
  - lib/core/theme/tokens.dart
  - lib/core/l10n/arb/app_uk.arb
  - lib/core/l10n/arb/app_en.arb
tech-stack:
  added: []
  patterns:
    - "Absence proven by in-suite source-glob gates, not by acceptance-criterion greps that run once"
    - "A deleted sentence key is deleted, never neutralized — a neutral sentence key is an empty vessel"
key-files:
  created: []
  modified:
    - lib/features/calendar/planner_week_detail.dart
    - lib/features/calendar/planner_screen.dart
    - lib/features/calendar/planner_year_grid.dart
    - lib/features/calendar/planner_month_detail.dart
    - lib/features/calendar/planner_view_model.dart
    - lib/core/theme/tokens.dart
    - lib/core/l10n/arb/app_uk.arb
    - lib/core/l10n/arb/app_en.arb
    - lib/features/stack/add_supplement_sheet.dart
    - test/features/planner_screen_test.dart
    - test/features/planner_view_model_test.dart
    - test/features/planner_invariants_test.dart
    - test/features/stack_screen_test.dart
    - test/l10n/planner_copy_safety_test.dart
    - test/l10n/plurals_test.dart
    - test/l10n/no_hardcoded_strings_test.dart
    - test/theme/theme_test.dart
decisions:
  - "The measured post-deletion planner-key count is 35 (51 before). The coverage floor moved 40 → 35 in the same commit as the deletion; research's ~37 and the 13/16 deletion counts were all wrong, and only the measurement was used"
  - "The judgement-colour gate is scoped to planner_*.dart and the scope is documented AT the gate, naming the four Today-screen survivors — a directory-wide gate is red on correct code"
  - "The _BodyScroll `footnote` parameter was removed along with its only caller: an optional slot with no consumer is the vessel the next footnote gets poured into"
metrics:
  duration: ~19 min
  completed: 2026-08-17
  tasks: 3
  commits: 3
  tests_passing: 780
actuals:
  tokens: 61000
  tasks: 3
  commits: 3
---

# Phase 6 Plan 6: PLAN-05 Completed by Absence — Summary

Deleted every judgement the planner layered on concurrent load — the verdict family, the slot pips, the limit badge, the year footnote, the banded chip colours and the red month counts — together with the two limit constants, the dead threshold token and sixteen ARB keys in both locales, then widened the copy gate and added source-glob gates so none of it can return silently.

## What was built

**Task 1 — `0538108` `feat(06-06)`: the last planner surfaces, and the disclaimer rewrite**

The disclaimer was rewritten **first**, before any gate widening, because the old text named the limit twice in Ukrainian and the widened gate would otherwise have gone red on copy nobody had fixed yet:

- uk «Планувальник показує, як ваші цикли накладаються в часі. Освітній матеріал, не медична порада.»
- en "The planner shows how your cycles overlap over time. Educational material, not medical advice."

Both live disclaimer assertions (`length > disclaimerEducational.length`, `contains(disclaimerEducational)`) pass **unedited** — verified by `git diff HEAD~2` over that region showing no `+`/`-` on either.

- **Week-detail card:** now range → `substancesCount(load)` → name-chip `Wrap`. The verdict switch, the `week-verdict-chip` container, `_SlotPips` and its call site, `final free = editorialLimit - load`, the free-slots half of the meta line and the verdict note are gone. The header `Row` holds exactly one child, which retires its overflow risk outright. The `Wrap` and its 14px top margin render only when `week.entries.isNotEmpty`, so a zero-cycle card ends after the meta line with no dead space.
- **Цикли summary chip:** limit badge and at-limit boolean deleted; neutral `chip` / `textSecondary` pair (the `stack_screen.dart:377-393` pair) at every load.
- **Рік peak chip:** same neutral pair; over-limit boolean deleted.
- **Year grid:** month count is `textFaint` unconditionally; the over-limit boolean and the ternary are gone.
- **Year footnote:** deleted, not neutralized — and `_BodyScroll`'s `footnote` parameter with it. Рік now closes on the disclaimer alone, exactly as Цикли does.
- **Month detail:** `substancesCount(rows.length)` rendered directly instead of the two-placeholder `monthMeta`.

**Task 2 — `fdf0078` `refactor(06-06)`: the machinery, the token and sixteen keys**

- `planner_view_model.dart`: `editorialLimit` with its 16-line editorial doc block (including the now-moot DECIDED-6 chip-asymmetry rationale), `comfortLoad`, the sealed `LoadVerdict` with its three subclasses, and `verdictOf` — all deleted.
- `tokens.dart`: `thresholdDash` deleted (its painter went in 06-05). Its neighbours were not touched: `grep -cE "riskBg|warnBg|calmBg"` returns **3 before and 3 after**.
- **Sixteen ARB keys deleted from BOTH locales in one commit**, each with its description and placeholder block: `limitBadge`, `loadAxisLegend`, `verdictComfort`, `verdictLimit`, `verdictOverLimit`, `weekNoteComfort`, `weekNoteLimit`, `weekNoteOverLimit`, `weekFreeSlots`, `weekNoFreeSlots`, `weekLoadLabel`, `substancesLimitCount`, `slotsCount`, `cyclesCount`, `monthMeta`, `yearFootnote`.
- Every test naming a deleted getter was edited in the same commit, so the tree never stopped compiling.

**Task 3 — `cc6a84a` `test(06-06)`: the gate gets stricter, and absence becomes assertable**

- `forbiddenVocabulary` widened with `межа`, `меж`, `перевищ`, `норма`; every Phase-4 entry retained, including `жиророзчин` / `fat-soluble`. `medical standard` moved into the hard list too.
- `negationOnlyVocabulary`, `negationBearingKeys` and the negation test deleted outright; replaced by a named `limitVocabulary` gate that exempts nothing, **including the disclaimer**.
- **Gate proven red before being trusted:** `«по тижнях»` → `«по тижнях, межа 5»` in the live `app_uk.arb`, `flutter gen-l10n`, and both the PLAN-04 and the new PLAN-05 test failed with `Offenders: [loadChartMeta contains "межа", loadChartMeta contains "меж"]`. Reverted; `git diff --stat lib/core/l10n/` is clean.
- New source-glob gate for `BqColors.(risk|warn|calm)` over `planner_*.dart` **only**, with the four survivors named in the gate's own comment.
- New source-glob gate for the deleted judgement names (`week-verdict-chip`, `week-pip-`, `_SlotPips`, `load-threshold`, `load-over-`, `thresholdDash`, `editorialLimit`, `comfortLoad`, `verdictOf`).
- New widget test proving the disclaimer is the **last child** of both bodies, read from the `ListView`'s child list rather than from y-offsets (a card below the fold and a card below the disclaimer look identical to a geometric assertion).

## The measured numbers

| Measurement | Before | After |
|---|---|---|
| `app_uk.arb` keys | 171 | **155** |
| `app_en.arb` keys | 171 | **155** |
| `app_en.arb` total entries (keys + `@meta`) | 343 | 311 |
| **Planner-key count** (the coverage floor's subject) | 51 | **35** |
| Coverage-floor assertion | `greaterThanOrEqualTo(40)` | `greaterThanOrEqualTo(35)` |
| `planner_*.dart` files (invariants floor) | 8 | 8 — floor unchanged, re-measured not assumed |
| `riskBg\|warnBg\|calmBg` in `tokens.dart` | 3 | 3 |
| Tests passing | 790 | **780** |

**The ARB floor was set from the measurement, not from a guess.** Research estimated ~37 on an assumption of 13 deletions; this phase deleted 16; the real answer is 35. The reason string at the assertion names this phase, the count and the previous floor.

The test count fell by 10 because twelve tests asserting deleted designs were deleted (four verdict-band tests, two `thresholdDash` token tests, four uk plural/limit tests, two en ones) and two new absence gates plus a disclaimer-position test were added.

## Deviations from Plan

### Auto-fixed issues

**1. [Rule 3 - Blocking] The en `cyclesCount` plural test also called a deleted getter**

- **Found during:** Task 2
- **Issue:** The plan enumerated the en group's `slotsCount`/`substancesLimitCount` test by name but not the en `cyclesCount` test (`plurals_test.dart:148-152`). `cyclesCount` is one of the sixteen deleted keys, so that test stopped compiling.
- **Fix:** Deleted it with the others, in the same commit as the deletion — the plan's own stated principle ("every test that names a deleted getter is edited in THIS task").
- **Commit:** `fdf0078`

**2. [Rule 1 - Bug] Doc comments and ARB descriptions naming deleted keys as live mechanisms**

- **Found during:** Task 2
- **Issue:** `weekBarSemantics`'s ARB description said its `load` argument is "a pre-formatted `weekLoadLabel` string" — false since 06-05 (it is `substancesCount`) and now naming a key that does not exist. `addSupplementCatalogSemantics`, `add_supplement_sheet.dart`, `stack_screen_test.dart` and `no_hardcoded_strings_test.dart` all called the composition convention "the `weekLoadLabel` idiom".
- **Fix:** `weekBarSemantics`'s description corrected (with a one-clause note on why it changed); the convention renamed "the pre-formatted-count idiom" in all four places. Purely historical references ("it replaces `loadAxisLegend`, which named an editorial limit") were kept — a rationale that names what a thing replaced is not a lie.
- **Commit:** `fdf0078`

**3. [Rule 1 - Bug] The text-scale matrix asserted a scroll position mid-settle**

- **Found during:** Task 1
- **Issue:** `sweepBody` asserted `pixels == maxScrollExtent`. With the bodies now shorter, the final drag left the position ~5px past a `maxScrollExtent` that only shrank once the last card was built, and the equality failed for Рік at textScaler 1.0 in both locales.
- **Fix:** The sweep now pumps the correction out before returning; the assertion reads `greaterThanOrEqualTo`, and — the actual strengthening — each matrix case now also asserts the **closing line was built**, which is what "swept to the end" has to mean. A scroll offset alone can be an estimate; the closing line cannot.
- **Commit:** `0538108`

### Judgement calls

- **`_BodyScroll.footnote` removed, not left unused.** The plan deletes the footnote's copy and its call site; leaving the optional parameter behind would leave the exact empty vessel the plan refuses elsewhere (`monthMeta`). Same reasoning, applied to a widget parameter.
- **The last test in `planner_copy_safety_test.dart` still reads "the disclaimer itself still frames the limit as editorial".** The name is now inaccurate — the disclaimer frames no limit. It was left **untouched on purpose**: the plan forbids editing that region, and its two assertions are the ones that had to keep passing unedited. Renaming it is a one-line follow-up for whoever next opens that file, not something to slip into this phase's diff.

## Threat mitigations verified

| Threat | Verification |
|---|---|
| T-06-15 over-broad token deletion | `grep -cE "riskBg\|warnBg\|calmBg" lib/core/theme/tokens.dart` = 3, unchanged. The four Today-screen consumers still carry 4 / 3 / 2 / 1 `risk`/`warn`/`calm` usages (`dose_row`, `day_block_section`, `day_progress_ring`, `week_strip`) |
| T-06-16 wrong ARB key deleted | `grep -c "weeksCount" lib/core/l10n/arb/app_uk.arb` = 1; the regimen editor's tests pass |
| T-06-17 a gate weakened to go green | Floor re-derived from a measurement (35) in the same commit as the deletion; the negation exemption deleted rather than retained; the widened vocabulary gate proven red by temporary reinsertion, then reverted |
| T-06-18 disclaimer silently dropped | New widget test asserts it is the LAST child of both bodies; existing shell tests assert it on the empty and error surfaces |
| T-06-SC pub installs | `git diff --quiet -- pubspec.yaml pubspec.lock` succeeds |

## Verification

- `flutter analyze` — **0 issues**
- `flutter test` — **780 passing, 0 failing**
- `grep -rnE "BqColors\.(risk|warn|calm)" lib/features/calendar/planner_*.dart` — zero matches, and asserted in-suite
- `grep -rnE "week-verdict-chip|week-pip-|_SlotPips" lib/features/calendar/` — zero matches
- `grep -rn --include='*.dart' -E "editorialLimit|comfortLoad|verdictOf|LoadVerdict|ComfortVerdict|LimitVerdict|OverLimitVerdict|thresholdDash" lib/` — zero matches
- Each of the sixteen deleted keys returns zero **live** references in `lib/`, `test/`, `integration_test/` (remaining matches are prose naming what was deleted, in comments that explain the deletion)
- `integration_test/` untouched and still compiling (not run — needs a device)

## Known stubs

None.

## What remains for the orchestrator — device / human checks only

Everything automatable in this phase is automated. These four are the phase-wide backstops that an executor with no device cannot run, and they should be run once, on hardware, before sign-off:

1. **Nav bar and FAB on real hardware.** On a physical iPhone with a home indicator **and** on an Android device with gesture navigation: the 56dp bar's three targets are comfortably hittable, the fill and hairline reach the physical screen edge, and the FAB does not collide with the system gesture area — checked at textScaler **1.0 and 2.0**.
2. **Settings as a pushed route, across a language change.** From Календар: open Settings via the gear, change the language, pop. You must land back on the **Календар** tab, re-rendered in the new language, with no stale header subtitle and no lost planner week/month selection.
3. **The load chart with a real multi-supplement stack.** It must read as "my whole stack overlaps here", not as a limit; the scale caption (`loadScaleCaption`) must be legible at mono 10 in **both** locales.
4. **Both existing on-device integration tests pass on iOS and Android.** They were kept compiling but were never executed in this worktree (no device available to an executor).

Nothing in this list blocks a merge of this plan; they gate the phase's sign-off.

## Self-Check: PASSED

- `.planning/phases/06-shell-simplification/06-06-SUMMARY.md` — FOUND
- `0538108`, `fdf0078`, `cc6a84a` — all three FOUND in `git log`
- `flutter analyze` 0 issues, `flutter test` 780 passing at `cc6a84a`
