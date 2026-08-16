---
phase: 05-localization-settings
plan: 02
subsystem: async-error-surfaces
tags: [riverpod, error-handling, i18n, intl, testing]
status: complete

requires:
  - Phase 2 Stack screen error surface (stackLoadError + retry)
  - Phase 3 Calendar day-view error surface (dayLoadError + retry)
  - Phase 4 Planner error surface (plannerLoadError + retry), 04-REVIEW.md CR-02
provides:
  - "\"Has an error\" beats \"is loading\" as a graph-wide rule: a retrying Drift failure reaches every async screen surface as a real error, on the first frame after it happens, with production auto-retry untouched"
  - Locale-aware sentence casing for the Calendar day header weekday
affects:
  - lib/core/providers.dart (stackEntriesProvider merge semantics — see Deviations)
  - Any future screen reading stackEntriesProvider or dayDosesProvider

tech-stack:
  added: []
  patterns:
    - "skipLoadingOnReload: true at every AsyncValue.when() that owns a designed error surface — including the DERIVED merge in providers.dart, not only the screens"
    - "AsyncValue(hasError: true) as the first switch arm, never AsyncError() alone"
    - "toBeginningOfSentenceCase(value, locale) with the locale threaded from Localizations.localeOf(context)"
    - "Error-surface tests run with Riverpod's default retry LIVE — no retry: override, no pumpAndSettle"

key-files:
  created: []
  modified:
    - lib/features/calendar/planner_screen.dart
    - lib/features/stack/stack_screen.dart
    - lib/features/calendar/calendar_screen.dart
    - lib/core/providers.dart
    - test/features/planner_screen_test.dart
    - test/features/stack_screen_test.dart
    - test/features/calendar_screen_test.dart

decisions:
  - "The A1 fix is NOT complete at the three screen surfaces: stackEntriesProvider's merge swallowed the error before any screen could see it. Fixed there too, with the narrowest possible edit (two named arguments)."
  - "Auto-retry stays enabled in application code; zero retry: occurrences under lib/. The retry override appears only in the pre-existing CR-02 recovery test."
  - "The Calendar hold (WR-01/PF-7) is preserved exactly: a genuine day switch with no error still takes the loading arm and still holds the previous day's rows."
  - "toBeginningOfSentenceCase output is byte-identical to the retired helper in uk and en, pinned by a new bilingual test that was confirmed green against the OLD helper first — the A7 fallback was not needed."

metrics:
  duration: ~45 min
  completed: 2026-08-16
  tests_before: 547
  tests_after: 555

actuals:
  tokens: 83800
  tasks: 3
  commits: 3
---

# Phase 5 Plan 02: Error Surface Beats Loading Surface Summary

A retrying Drift failure now reaches the Stack, Calendar-day and Planner error surfaces on the first frame after it happens instead of blanking them for ~38 seconds, with Riverpod's auto-retry still live in production — and the day header's weekday is sentence-cased through `intl` with the active locale.

## What was built

**Task 1 — "has an error" beats "is loading" (commit `f244b11`)**

| Site | Change |
|---|---|
| `planner_screen.dart` `_surface` | first switch arm is `AsyncValue(hasError: true)`, not `AsyncError()`; the `_surface` doc comment no longer documents the defect as designed behaviour |
| `stack_screen.dart` | `skipLoadingOnReload: true` as the first named argument of `entries.when(...)` |
| `calendar_screen.dart` | same argument on `widget.doses.when(...)`; the held-list loading arm and its `IgnorePointer`/WR-01 rationale are untouched |
| `lib/core/providers.dart` | **deviation** — the same argument on both merges inside `stackEntriesProvider` (see Deviations) |

**Task 2 — six tests with the retry timers LIVE (commit `52d957a`)**

One test per surface × `uk`/`en`. Each seeds the failure on the STREAM that actually fails (never on a derivation — the named-recovery-path rule from CR-02), supplies **no** `retry:` override, and never calls `pumpAndSettle` (PF-7). Each asserts the localized copy AND the retry label are present, that the seeded exception message and the string `Exception` reach no rendered `Text` (T-05-03), and — on Calendar — that the previous day's held rows are gone.

The Calendar pair needed a new stub, `_OneDayFailingIntakeRepo`, because the existing `_ErroringIntakeRepo` fails with a `StateError`. `defaultRetry` refuses to retry an `Error` (`if (error is ProviderException || error is Error) return null`), so that stub reaches `AsyncError` immediately and never entered the backoff window at all — which is a second reason the defect survived Phase 3 and 4. Drift throws `Exception` subtypes, so the new stub seeds an `Exception` and fails exactly ONE day, leaving the day the user came from genuinely resolved so its held rows are real.

**Task 3 — `toBeginningOfSentenceCase` (commit `6b3e59f`)**

`_capitalizeFirst` and its rune-based docstring are deleted; the call site now reads `toBeginningOfSentenceCase(DateFormat('EEEE', locale).format(day), locale)` with the locale threaded from the same `Localizations.localeOf(context)` read the surrounding `DateFormat` uses. The formatter and the localized string are still read inside `build` (PF-4). The four `toUpperCase()` sites are untouched (`git diff --stat` on all four is empty).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 — Blocking] `stackEntriesProvider` swallowed the error before any screen could see it**

- **Found during:** Task 1, before writing any code, by probing the real provider graph.
- **Issue:** 05-RESEARCH.md P-9 analysed the three screen surfaces but not the derivation between them. `stackEntriesProvider` merges the two stream providers with `supplements.when(data:, loading:, error:)` — the *same* `skipLoadingOnReload: false` default the fix is about. Probed against the real graph with retry live:
  - raw `supplementsStreamProvider` → `AsyncLoading(error: Exception: boom-from-drift, retrying)`, `hasError: true`
  - derived `stackEntriesProvider` → plain `AsyncLoading()`, **`hasError: false`**

  So the Stack screen and the Planner were handed an `AsyncValue` with no error in it at all. No rendering rule at those two surfaces — `hasError` pattern, `skipLoadingOnReload`, anything — could have worked. The planner is worse still: `cyclesModelProvider`/`yearModelProvider` use `whenData`, whose loading arm is `AsyncLoading<NewT>(progress: progress)` and drops the error outright ([riverpod-3.4.2/async_value.dart:186]).
- **Fix:** `skipLoadingOnReload: true` on both merges in `stackEntriesProvider`, so a retrying failure is converted to a real `AsyncError` at the merge point and propagates. Two named arguments plus a comment explaining why they are load-bearing — deliberately the narrowest edit available, because plan 05-01 is concurrently editing this file in its own worktree.
- **Files modified:** `lib/core/providers.dart`
- **Commit:** `f244b11`
- **⚠ Merge note for the orchestrator:** `lib/core/providers.dart` is shared with plan 05-01. This plan's change is confined to the body of `stackEntriesProvider` (the last declaration in the file) plus its doc comment. Nothing else in the file was touched.

### Deviation from an acceptance criterion (reported, not worked around)

Task 2's criterion *"reverting Task 1's change in `planner_screen.dart` alone makes the planner pair of tests fail"* is **NOT met**, and no test was bent to make it appear met. Measured, by reverting one change at a time and re-running:

| Reverted alone | uk/en Stack pair | uk/en Planner pair | uk/en Calendar pair |
|---|---|---|---|
| `providers.dart` merge | **FAIL** | **FAIL** | n/a (different provider) |
| `calendar_screen.dart` arg | n/a | n/a | **FAIL** |
| `planner_screen.dart` arm | n/a | pass | n/a |
| `stack_screen.dart` arg | pass | n/a | n/a |

Cause: once the merge converts the retrying failure to a real `AsyncError`, `stackEntriesProvider` can only ever be `AsyncError` or a *plain* `AsyncLoading` — never an `AsyncLoading` carrying an error — so at those two surfaces the old `AsyncError()` pattern and the new `hasError` pattern are currently indistinguishable. The two screen-level changes are therefore correct, mandated by UI-SPEC A1, and defence-in-depth against any future change to the merge or to `whenData` — but not independently observable today. The load-bearing change for Stack and Planner is the `providers.dart` one; for Calendar it is the screen-level one, because `dayDosesProvider` is a `StreamProvider` the screen reads directly.

The six new tests as a set ARE load-bearing: every one of them fails if the corresponding fix is removed.

## Verification

- `flutter analyze` — **0 issues**.
- `flutter test` — **555 passed, 0 failed** (baseline 547; +6 error-surface tests, +2 casing tests). `integration_test/` not run, per instruction.
- `flutter test test/l10n/month_names_test.dart` — passes with **zero edits** to that file.
- `git diff --stat pubspec.yaml` — empty. No package added, `intl` untouched (T-05-SC).
- `grep -rn --include='*.dart' 'retry:' lib/` — **0 hits**. Auto-retry is not disabled anywhere in application code (T-05-06 accepted as planned).
- `grep -v '^\s*//' lib/features/calendar/planner_screen.dart | grep -c 'AsyncError()'` → 0; `'hasError: true'` → 1.
- `skipLoadingOnReload: true` → exactly 1 in `stack_screen.dart`, exactly 1 in `calendar_screen.dart`.
- `_capitalizeFirst` → 0; `toBeginningOfSentenceCase` → 1, with a locale argument.
- `git diff --stat` on `planner_year_grid.dart`, `planner_month_detail.dart`, `planner_gantt.dart`, `week_strip.dart` — empty.
- None of the six new error tests calls `pumpAndSettle` or supplies a `retry:` override.

## Known Stubs

None.

## Threat Flags

None. No new network endpoint, auth path, file access pattern or schema change. T-05-03 (exception text in the tree) is asserted negatively by all six new tests; T-05-06 is accepted exactly as the register planned.

## Self-Check: PASSED

- `.planning/phases/05-localization-settings/05-02-SUMMARY.md` — FOUND
- `lib/core/providers.dart`, `lib/features/stack/stack_screen.dart`, `lib/features/calendar/calendar_screen.dart`, `lib/features/calendar/planner_screen.dart` — FOUND
- Commits `f244b11`, `52d957a`, `6b3e59f` — FOUND in `git log`
