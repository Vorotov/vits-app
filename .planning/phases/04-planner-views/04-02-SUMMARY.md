---
phase: 04-planner-views
plan: 02
subsystem: planner
status: complete
tags: [l10n, arb, plurals, month-case, planner-shell, disclaimer, a11y, PLAN-04]
requires:
  - 04-01 (planner_view_model, planner_providers, planner_gantt, PlannerScreen skeleton)
  - lib/features/stack/stack_status.dart (ScheduleSummary hierarchy)
provides:
  - The complete Phase-4 ARB key set (42 new keys) in both locales, regenerated
  - The planner shell — segmented control, segment-dependent subtitle, empty/error/loading surfaces, the disclaimer closing both segments
  - lib/features/stack/schedule_summary_text.dart — the single schedule-description composition shared by the Stack card and the gantt row
  - The full ganttRowSemantics label on every gantt row
affects:
  - lib/features/stack/stack_screen.dart (its schedule chip now calls the shared helper; output unchanged, proven by its untouched tests)
tech-stack:
  added: []
  patterns:
    - "Pre-formatted plural composition: a count is declined once by its own ICU key, then passed into the sentence key as a String placeholder — never a nested plural block"
    - "intl STANDALONE pattern letters (LLLL/LLL) for every month name that stands without a day number"
    - "Riverpod 3 AsyncValue pattern-matching for the data/empty/error/loading surface quadruple"
    - "Pure derivation and its rendering live in sibling files, so the pure file keeps its no-Flutter/no-l10n rule"
key-files:
  created:
    - lib/features/stack/schedule_summary_text.dart
    - test/l10n/month_names_test.dart
    - test/l10n/planner_copy_safety_test.dart
  modified:
    - lib/core/l10n/arb/app_en.arb
    - lib/core/l10n/arb/app_uk.arb
    - lib/core/l10n/gen/ (regenerated, committed)
    - lib/features/calendar/planner_screen.dart
    - lib/features/calendar/planner_gantt.dart
    - lib/features/stack/stack_status.dart
    - lib/features/stack/stack_screen.dart
    - test/features/planner_screen_test.dart
    - test/l10n/plurals_test.dart
decisions:
  - "The Цикли subtitle is NOT capitalized: the mockup renders 'серпень — листопад 2026' lowercase, so the plan's 'reuse the rune-safe capitalizer' instruction has no site in this plan's copy"
  - "The month-case test pins the standalone/format inequality on a COMPOSED pattern (LLLL y vs MMMM y), because intl falls back to the standalone form for a single-field pattern and a bare MMMM comparison would prove nothing"
  - "The disclaimer renders under every state including loading — PLAN-04 is unconditional and S6c's 'empty body' means no cards, not no copy"
  - "The Рік month count comes from DateTime.monthsPerYear rather than a literal 12 (DECIDED-9 makes it structural)"
  - "The shared schedule-description helper is a sibling file, not a function in stack_status.dart, so that file keeps its no-Flutter/no-l10n/no-strings rule"
metrics:
  duration: ~18 min
  completed: 2026-08-15
actuals:
  tokens: 34300
  tasks: 3
  commits: 5
---

# Phase 4 Plan 02: Planner Vocabulary and Shell Summary

The planner got its whole vocabulary and its permanent frame: 42 ARB keys in both
locales with uk plural and month-case correctness locked by tests, a shell that
switches between Цикли and Рік and survives an empty or failing stack, and the
educational disclaimer closing both segments as the same key — with PLAN-04's
editorial-framing rule enforced by a test over the loaded localizations rather
than by a reviewer.

## What Was Built

**Task 1 — the ARB copy set (commit `d3a732e`).**
42 new keys added to `app_uk.arb` and `app_en.arb` in one commit, taken verbatim
from the UI-SPEC Copywriting Contract; `lib/core/l10n/gen/` regenerated and
committed. Every en key carries an `@`-description and every interpolating key a
typed `placeholders` block. Three keys are ICU plurals with all four uk CLDR
forms (`monthsCount`, `cyclesCount`, `periodsCount`); every other count reaches
a sentence pre-formatted, following the existing composition convention rather
than nesting plural blocks. `substancesCount`, `weeksCount`, `noBreak`,
`slotsPerDay`, `backToToday`, `retry` and `disclaimerEducational` were reused,
not duplicated. Three descriptions carry requirement weight in prose:
`plannerDisclaimer` (the PLAN-04 closure on both segments, `yearFootnote` above
it not instead of it), `weekNoteOverLimit` (the truncated pharmacological
clause, never restored), `legendPlanned` (the legend has exactly three entries).

**Task 2 — the planner shell (commits `24f751e` RED, `012e4fd` GREEN).**
`BqSegmented` with the Рік/Цикли labels driven by `plannerSegmentProvider`,
Цикли default; a segment-dependent subtitle naming the window's first and last
month (with a cross-year variant) or today's year plus a pre-formatted month
count; `_CyclesBody` / `_YearBody` as the seams plans 04-03 and 04-04 fill; the
three S6c surfaces (two empty-body variants, fixed error copy plus a retry that
invalidates only `stackEntriesProvider`, and a loading branch with no spinner);
and one `_FaintNote` disclaimer closing both bodies under every state.

**Task 3 — the shared schedule description (commits `6e338af` RED, `be9559b` GREEN).**
New `lib/features/stack/schedule_summary_text.dart` composes a `ScheduleSummary`
into its sentence with a `withSlots` flag. The Stack card now calls it with the
tail included — its existing tests pass with no assertion changed, which is what
proves the output is identical — and the gantt row renders the same composition
with the tail omitted, as a second `Flexible` ellipsised child beside the name.
The row's placeholder Semantics label became the full `ganttRowSemantics`
composition.

## Verification

- `flutter analyze` — 0 issues
- `flutter test` — 452 tests pass (422 baseline + 30 new); no baseline test changed
- `flutter gen-l10n` — clean, no untranslated-message warning
- ARB key lists are identical between the two files (160 keys each); every en key has an `@`-description
- `grep -c 'many{' app_uk.arb` went 5 → 8 (exactly the three new plurals); `grep -c 'substancesCount' app_uk.arb` prints 1
- Task-2 greps: `BqSegmented` 2, `class .*Segmented` 0, `plannerDisclaimer` 1, `DateFormat('LLLL'` ≥1, non-comment `DateFormat('MMMM'` 0, `Localizations.localeOf` 1
- Task-3 greps: non-comment `slotsPerDay` in `planner_gantt.dart` 0, `cycleSummaryCyclic` composed in exactly 1 file, `Color(0x` across `planner_*.dart` 0
- The read-only gate (`test/providers_planner_test.dart`) still passes: no planner file reaches `dayDosesProvider` or `ensureLogsForDay`

## Deviations from Plan

### 1. [Rule 1 — Bug] The month-case test could not assert the plan's inequality as written

- **Found during:** Task 1, step (5)
- **Issue:** the plan (and PF-4) called for asserting that `DateFormat('LLLL','uk')`
  and `DateFormat('MMMM','uk')` yield different strings for the same date. They do
  not: `intl` falls back to the standalone form when the month is the ONLY field
  in the pattern, so a bare `MMMM` renders "серпень", not "серпня". Written as
  planned, the test would have failed permanently — or, worse, been "fixed" by
  deleting the assertion that matters.
- **Fix:** the inequality is asserted on a COMPOSED pattern instead —
  `LLLL y` → "серпень 2026" vs `MMMM y` → "серпня 2026" — which is exactly the
  shape a "just put the year in the same DateFormat" refactor of the subtitle
  would produce, so the test now guards the real hazard. The locale data itself is
  also pinned (`STANDALONEMONTHS[7]` ≠ `MONTHS[7]`), and the single-field fallback
  is pinned and explained so nobody simplifies the planner to `MMMM` on the
  strength of the coincidence. The abbreviated pair coincides in uk data
  ("серп." for both, with a trailing period), pinned as fact.
- **Files modified:** `test/l10n/month_names_test.dart`
- **Commit:** `d3a732e`

### 2. [Rule 3 — Blocking] `Override` is not public API in Riverpod 3

- **Found during:** Task 2 RED
- **Issue:** the shell tests needed to pin `stackEntriesProvider` to a fixed
  `AsyncValue`; a `List<Override>` parameter does not compile because
  `flutter_riverpod` does not export `Override` (the same gap as
  `ProviderListenable`, noted in the wave-1 handoff).
- **Fix:** the test container helper takes an
  `AsyncValue<List<StackEntry>>?` and builds the override internally.
- **Files modified:** `test/features/planner_screen_test.dart`
- **Commit:** `24f751e`

### 3. [Plan instruction not applicable] The rune-safe capitalizer was not reused

- **Found during:** Task 2
- **Issue:** the plan says to reuse `_capitalizeFirst` from `calendar_screen.dart`
  for the subtitle's month names. The mockup (line 288) renders the subtitle
  lowercase — "серпень — листопад 2026" — and `intl` already returns exactly that,
  so capitalizing would have shipped a visual deviation from the authoritative
  mockup for no gain.
- **Fix:** no capitalization site exists in this plan's copy; the helper stays
  private to `calendar_screen.dart`. If plan 04-04's peak-month chip or
  month-detail title needs sentence casing, that is where to promote it — the
  month-detail title is uppercased, not capitalized, so it likely never will.
- **Files modified:** none
- **Commit:** n/a

### 4. [Rule 1 — Bug] `sort_child_properties_last` on `_BodyScroll`

- **Found during:** Task 2 GREEN
- **Issue:** `flutter analyze` flagged `children:` before `footnote:`.
- **Fix:** argument order swapped; the analyzer is treated as build-breaking.
- **Files modified:** `lib/features/calendar/planner_screen.dart`
- **Commit:** `012e4fd`

## Notes for Later Plans

- **04-03 / 04-04 seams.** `_CyclesBody` and `_YearBody` each render a `_surface`
  result inside `_BodyScroll`; insert new cards into the `cards:` callback. Do not
  add a second disclaimer — `_BodyScroll` already closes every body, and the
  `grep -c 'plannerDisclaimer' == 1` gate depends on that staying true.
- **The empty predicate is per-segment:** `model.rows.isEmpty` for Цикли,
  `model.entries.isEmpty` for Рік. Both are already the regimen-bearing subset.
- **The abbreviated uk month renders "серп." with a trailing period**, not the
  mockup's "СЕР". The gantt month header and month-card label uppercase the intl
  output (`СЕРП.`), which is the L10N-04-correct result; raise it at UAT if the
  period reads badly, but do not hardcode a table.
- **`_editorialLimit = 5` is named once** in `planner_screen.dart`. Plans 04-03
  and 04-04 need the same number plus `comfortLoad = 3`; promote both to the
  model layer if a second file needs them rather than restating the literal.
- **`scheduleSummaryText(..., withSlots: false)`** is the only sanctioned way to
  describe a regimen in the planner.

## Known Stubs

None. `_YearBody` renders no cards yet, but that is plan 04-04's scope and is
documented as a seam in the file's own header, not a stub: the body renders its
real closing copy and its real empty/error surfaces today.

## Self-Check: PASSED

- `lib/features/stack/schedule_summary_text.dart` — FOUND
- `test/l10n/month_names_test.dart` — FOUND
- `test/l10n/planner_copy_safety_test.dart` — FOUND
- Commits `d3a732e`, `24f751e`, `012e4fd`, `6e338af`, `be9559b` — all FOUND in `git log`
