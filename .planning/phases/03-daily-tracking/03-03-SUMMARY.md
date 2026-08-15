---
phase: 03-daily-tracking
plan: 03
subsystem: calendar
tags: [tokens, l10n, arb, intl, custompaint, accessibility, header]
status: complete
requires:
  - "03-01: resolvedDayProvider / selectedDayProvider / dayDosesProvider, todayProvider"
  - "03-02: dayRingCounts (pure day view-model)"
provides:
  - "BqColors.checkBorder / warnBorder / onAccentMuted, BqRadii.doseRow / dayCell"
  - "The complete Phase-3 ARB copy set in both locales (27 keys) + regenerated gen output"
  - "DayProgressRing — CustomPaint arc + mono counter + ringSemantics label"
  - "CalendarScreen's permanent frame: fixed header above a scrolling body closed by the disclaimer"
affects:
  - "03-04 (grouped blocks, chips, action sheet) consumes the tokens and copy without touching tokens.dart or the ARB files"
  - "03-05 (week strip, empty/error surfaces) inserts WeekStrip at the named 16px gap in the header column"
tech-stack:
  added: []
  patterns:
    - "intl DateFormat with Localizations.localeOf(context).toString() — never a literal locale tag"
    - "CustomPainter whose shouldRepaint compares only its single drawn input (the _DashedBorderPainter analog)"
    - "Semantics(label:, excludeSemantics: true) over a canvas + its redundant visual counter"
key-files:
  created:
    - lib/features/calendar/day_progress_ring.dart
  modified:
    - lib/core/theme/tokens.dart
    - lib/core/l10n/arb/app_en.arb
    - lib/core/l10n/arb/app_uk.arb
    - lib/core/l10n/gen/app_localizations.dart
    - lib/core/l10n/gen/app_localizations_en.dart
    - lib/core/l10n/gen/app_localizations_uk.dart
    - lib/features/calendar/calendar_screen.dart
    - test/theme/theme_test.dart
    - test/l10n/plurals_test.dart
    - test/features/calendar_screen_test.dart
decisions:
  - "uk ringSemantics declines `доза` after the preposition «з»: one -> «дози» (1, 21), few/many/other -> «доз» — so 21 reads «21 з 21 дози прийнято», not «доз»"
  - "en ringSemantics ships as a one/other ICU plural rather than the UI-SPEC's bare illustrative string, so total == 1 reads «1 of 1 dose taken»; the `other` form is the spec string verbatim"
  - "ARB @-metadata lives on the en template only, matching the established Phase-1/2 convention (app_uk.arb is flat) rather than duplicating descriptions into uk"
  - "The ring's Semantics excludes its child Text — without it a screen reader reads the counts twice («2 з 5 доз прийнято, 2/5»)"
  - "The DayProgressRing total > 0 contract is an initializer-list assert, which keeps the constructor const while still throwing at runtime for a non-const caller"
  - "The week-strip slot is a bare named SizedBox gap with a comment, not a placeholder widget — nothing renders there until plan 03-05"
metrics:
  duration: ~35 min
  completed: 2026-08-15
  tasks: 3
  commits: 3
actuals:
  tokens: 14000
  tasks: 3
  commits: 3
---

# Phase 3 Plan 03: Tokens, Copy Set, Ring and Header Summary

The Today screen gained its permanent skeleton and its full vocabulary: five mockup-sourced design tokens, all 27 Phase-3 ARB keys in both locales with four-form uk plurals on the one count key, a hand-painted day-progress ring, and a fixed locale-formatted header over a scrolling body that closes with the disclaimer.

## What was built

**Task 1 — tokens + the whole Phase-3 copy surface (commit `14c9da2`).**
`BqColors.checkBorder` (0x3817171B), `warnBorder` (0x66B07A22), `onAccentMuted` (0xB3FFFFFF) and `BqRadii.doseRow` (13) / `dayCell` (11) were added under a Phase-3 banner matching the Phase-2 convention, each carrying its mockup-line citation. That is the closed list from the UI-SPEC "Token Additions" table — nothing else was added, and all five are asserted in `test/theme/theme_test.dart` so a future edit cannot silently change a value.

All 27 Phase-3 keys landed in `app_en.arb` and `app_uk.arb` in the same commit, with `@`-metadata descriptions and typed `int`/`String` placeholder blocks on the en template. `ringSemantics` is the phase's only count key and carries all four uk CLDR forms on `total`; `blockProgress` and `doseCycleChip` are bare-numeral interpolations with no plural block, as specified. `calendarDisclaimer`'s description records that it deliberately holds the two-sentence mockup line 264 while the pre-existing `disclaimerEducational` holds only the second sentence. `flutter gen-l10n` ran clean (no untranslated-message warning) and the regenerated `lib/core/l10n/gen/` output is committed.

**Task 2 — DayProgressRing (commit `a5dc61c`, TDD).**
A 46px `SizedBox` over a `CustomPaint`: a 5px `BqColors.field` track stroked on a 41px circle, then the `BqColors.calm` progress arc swept clockwise from twelve o'clock with `StrokeCap.butt` so the leading edge is as hard as the mockup's conic gradient (M10). The counter renders through `BqText.mono(size: 12, color: BqColors.calm)`; the whole widget is wrapped in `Semantics(label: ringSemantics(taken, total))`. `shouldRepaint` compares the fraction only — proved by a test that pumps 2/5, 4/10 and 4/5 and asserts no repaint between the two equal fractions. Callers own the `total == 0` case (DECIDED-7); a constructor assert makes that contract impossible to regress silently.

**Task 3 — the fixed header (commit `42268fa`, TDD).**
`calendar_screen.dart` went from a single `ListView` to `Scaffold → SafeArea → Column` of [header, 16px week-strip gap, `Expanded` scroll body]. The header sits outside the scroll view (asserted structurally: the subtitle is not a descendant of any `Scrollable`). Title = the localized today string while following, otherwise the capitalized `DateFormat('EEEE', locale)` weekday; subtitle = `'EEEE, d MMMM'` on today and `'d MMMM'` elsewhere, the locale always from `Localizations.localeOf(context)`. The uk exemplar is pinned at 2026-08-13 to the exact string "четвер, 13 серпня" (A7). `backToToday` renders only off today and clears the selection on tap. The ring renders only when the day's async value has data with a non-zero total. The body keeps 18/20/84 padding and now ends with `calendarDisclaimer` on every day.

## Verification

| Gate | Result |
|------|--------|
| `flutter analyze` | 0 issues |
| `flutter test` (full suite) | 232 passed (215 baseline + 17 new), 0 failures |
| `flutter gen-l10n` | clean, no untranslated-message warning |
| ARB key-list diff (uk vs en) | empty — 116 keys each, all 27 new keys in both |
| `many{` among new uk keys | `ringSemantics` only |
| `grep -c 'StrokeCap.butt' day_progress_ring.dart` | 1 |
| `grep -c 'CircularProgressIndicator' day_progress_ring.dart` | 0 |
| `grep -c 'shouldRepaint' day_progress_ring.dart` | 1 |
| `Color(0x` in new calendar files (non-comment) | 0 in both |
| `grep -c "DateFormat('EEEE, d MMMM'" calendar_screen.dart` | 1 |
| `grep -c 'Localizations.localeOf' calendar_screen.dart` | 1 |
| `grep -c 'calendarDisclaimer' calendar_screen.dart` | 1 |
| `DateTime.now` under `lib/features/` (doc comments excluded) | 0 |

## Deviations from Plan

### Auto-fixed issues

**1. [Rule 1 - Bug] The ring's Semantics label absorbed its own counter text**
- **Found during:** Task 2 (GREEN step — the label assertion failed)
- **Issue:** `Semantics(label: ...)` over a subtree containing the "2/5" `Text` merges the child into the node, so the label read back as `"2 з 5 доз прийнято\n2/5"` — a screen reader would announce the counts twice.
- **Fix:** added `excludeSemantics: true`; the localized label is the single spoken form.
- **Files modified:** `lib/features/calendar/day_progress_ring.dart`
- **Commit:** `a5dc61c`

**2. [Rule 3 - Blocking] `AsyncValue.valueOrNull` does not exist in Riverpod 3**
- **Found during:** Task 3 (compile failure)
- **Issue:** The header read the ring counts through `doses.valueOrNull`, a Riverpod 2 getter removed in the 3.x line the project pins.
- **Fix:** replaced with a Dart 3 `switch (doses) { AsyncData(:final value) => value, _ => null }` pattern match — version-independent and exhaustive.
- **Files modified:** `lib/features/calendar/calendar_screen.dart`
- **Commit:** `42268fa`

### Interpretation choices (recorded, not silent)

- **en `ringSemantics` ships as a one/other plural.** The UI-SPEC gives the en rendering as the illustrative "{taken} of {total} doses taken"; taken literally, `total == 1` would read "1 of 1 doses taken". The key is implemented as a CLDR one/other plural whose `other` form is the spec string verbatim, satisfying the task's "correct English at 1, 2 and 21" behavior bullet.
- **`@`-metadata is on the en template only.** The task text says every key gets `@`-metadata in both files, but `app_uk.arb` has been a flat key/value file since Phase 1 (gen-l10n reads metadata from the template only). The established convention was followed rather than introducing a duplicate-metadata style in one commit.
- **The `total > 0` assert is in the initializer list, not the constructor body.** Same runtime behavior for the (non-const) misuse the plan guards against, and it keeps the constructor `const` so the widget stays const-constructible at every call site.
- **uk plural wording for `ringSemantics`.** The noun after the preposition «з» takes the genitive, so the `one` form is «дози» («21 з 21 дози прийнято») while few/many/other take «доз». This is the linguistically correct declension of the spec's example string, exercised at 1/2/5/11/21.

## Known Stubs

None introduced by this plan. Two regions in `calendar_screen.dart` remain deliberately unfinished and are documented in the file's own doc comment with the plan that owns each:
- the 16px gap where plan 03-05 inserts `WeekStrip` (a named `SizedBox`, not a placeholder widget);
- the loading and error branches of the body, which render nothing until plan 03-05 adds `emptyDayTitle` / `dayLoadError` + retry. The disclaimer already renders on those branches, as UI-SPEC #1 requires.

The dose row is still the plan-03-01 tracer shape (it now consumes `BqRadii.doseRow` and `BqColors.checkBorder`); plan 03-04 replaces it with the mockup-exact anatomy.

## Threat Model Coverage

- **T-03-08** (wrong locale silently produces English dates) — mitigated: the locale is sourced from `Localizations.localeOf`, the uk rendering is pinned by an exact-string test at a fixed date, and the widget harness loads the real localization delegates.
- **T-03-09** (misleading progress) — mitigated: counts come from the tested `dayRingCounts`, and the constructor assert enforces the never-at-zero-total rule.
- **T-03-11** (design drift) — mitigated: five-token closed list plus a passing `Color(0x` grep gate on both new calendar files.
- **T-03-SC** — no package install occurred; the dependency set is unchanged.

No new security-relevant surface was introduced: no network endpoint, no auth path, no file access, no schema change. The ring's Semantics label exposes only the user's own dose counts on their own device (T-03-10, accepted).

## Self-Check: PASSED
