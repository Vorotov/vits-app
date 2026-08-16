---
phase: 05-localization-settings
plan: 04
subsystem: testing / i18n
tags: [l10n, widget-tests, text-scale, accessibility, riverpod]
status: complete

requires:
  - "05-01: sharedPreferencesProvider + derived LocaleController (synchronous seed)"
  - "05-02: the P-9 error-surface rendering rule on Stack and Calendar"
provides:
  - "test/support/locale_matrix.dart — shared bilingual assertion helpers and the single A8 allowlist"
  - "Locale-parameterized harnesses in app_shell, stack, regimen_editor and calendar suites"
  - "Rendered proof of L10N-01 criterion 1 on six previously English-uncovered surfaces"
  - "Rendered proof of L10N-03 propagation into a pushed route and an open modal sheet"
affects:
  - "lib/features/stack/regimen_editor_screen.dart (two real layout fixes)"

tech-stack:
  added: []
  patterns:
    - "`String locale = 'uk'` + `TextScaler?` harness signature, now shared by every widget suite"
    - "One shared library for cross-suite test assertions, used only where duplication would fragment a gate"

key-files:
  created:
    - test/support/locale_matrix.dart
  modified:
    - test/widget/app_shell_test.dart
    - test/features/stack_screen_test.dart
    - test/features/regimen_editor_test.dart
    - test/features/calendar_screen_test.dart
    - lib/features/stack/regimen_editor_screen.dart

decisions:
  - "Two genuine layout overflows found by the matrix were FIXED in the widget rather than assertion-relaxed, which required touching lib/ despite the plan's zero-production-code rule"
  - "Matrix seeds use Latin supplement names: user data is exempt from the Cyrillic sweep by construction, and widening the allowlist to cover user data would gut it"
  - "The date and time picker chrome gets a test each rather than one chained test — a dismissed picker leaves the page it was opened from unresponsive to further synthetic taps in this harness"

metrics:
  duration: ~55 min
  completed: 2026-08-16

actuals:
  tokens: 17000
  tasks: 3
  commits: 3
---

# Phase 5 Plan 04: Bilingual Render Matrix Summary

A locale × text-scale matrix across four widget suites turns L10N-01 criterion 1 from an ARB audit result into 51 rendered per-screen assertions — and found two real `RenderFlex` overflows in the regimen editor that only appear at an accessibility text scale.

## What Was Built

| Task | Commit | Output |
|---|---|---|
| 1 | `a616b88` | `test/support/locale_matrix.dart` + app shell (4 matrix cases) + Stack screen/sheet (12 cases) + E-12 |
| 2 | `82c7cd7` | Regimen editor (12 cases) + pushed-route propagation + Material picker chrome (4 cases) |
| 3 | `69d1a00` | Calendar day view + dose action sheet (16 cases) + open-sheet propagation + E-16 |

**Test counts:** 590 → 641 across the whole suite (+51). Per file: `app_shell_test.dart` 4 → 7, `stack_screen_test.dart` 13 → 26, `regimen_editor_test.dart` 10 → 27, `calendar_screen_test.dart` 72 → 90. `flutter analyze`: 0 issues.

### The shared helper

`test/support/locale_matrix.dart` is a library (no `main()`), holding what would otherwise be copied four times: the named `overflowReason` and `cyrillicLeakReason` device-consequence constants, `expectNoCyrillicWhileEn(tester)` (a sweep over every rendered `Text`, including `Text.rich` via `textSpan.toPlainText()`), and the single A8 allowlist. The allowlist has exactly one entry — `Українська`, the language picker's endonym, legitimately Cyrillic in any active language — matched by whole-string equality, never as a substring and never by loosening the regex.

### Coverage closed

Six surfaces that had zero English render coverage now render and are asserted in both languages at textScaler 1.0 and 1.6: the app shell, the Stack screen (populated / empty), the add-supplement sheet (both tabs), the regimen editor (cyclic / course / paused), the Calendar day view (populated / empty / past-day-with-unmarked-doses), and the dose action sheet. Each case asserts a locale-DISTINCTIVE string, so a screen rendering entirely in the fallback language fails rather than passing on a bare render; each English case runs the Cyrillic sweep; each asserts `takeException()` null with the named reason.

### Propagation (criterion 3)

- **E-11:** `localeControllerProvider` flipped with the regimen editor PUSHED re-localizes header and pinned footer within a single `pump()`, with `RegimenEditorScreen` still mounted (in place, not re-pushed).
- **E-10:** the same flip with the dose action sheet OPEN re-localizes both sheet actions in one frame, `BottomSheet` still mounted.
- **E-16:** the flip performed while `dayDosesProvider` is failing with Riverpod's default retry LIVE (no `retry:` override) keeps the error surface up and re-renders copy + retry control in the new language — the one assertion proving 05-02's rendering rule and 05-01's propagation compose.
- **Material chrome:** `showDatePicker` and `showTimePicker` headers and actions asserted against `GlobalMaterialLocalizations.delegate.load(locale)` in both languages — the half of "every screen displays correctly" no ARB gate can cover.
- **E-12:** a supplement added from the catalog in Ukrainian keeps its stored name after switching to English, while the ARB chrome around it changes — the "did the flip even happen" control assertion is present, so the E-12 claim cannot pass trivially.

No golden-file snapshots were added anywhere (P-8's rejection is part of the contract).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Two real `RenderFlex` overflows in the regimen editor at textScaler 1.6**
- **Found during:** Task 2, the first run of the editor matrix
- **Issue:** `_SliderRow`'s `Row(label, Spacer, value)` overflowed by up to **126 px** and the DOSE-TIMES header `Row(eyebrow, Spacer, slotsPerDay)` by **77–84 px**, in BOTH languages, at textScaler 1.6. A `Spacer` between two intrinsically-sized children has nothing to give once they exceed the width — in release that is a clipped label, not debug stripes (T-05-09, the CR-01 / WR-04 defect class).
- **Fix:** the leading label is now `Expanded`, so it takes the leftover width and wraps; the trailing value still sits at the trailing edge at scale 1.0, so mockup fidelity at the default scale is unchanged. `SizedBox(width: BqSpace.sm)` replaces the `Spacer`.
- **Files modified:** `lib/features/stack/regimen_editor_screen.dart`
- **Commit:** `82c7cd7`

**Conflict resolved deliberately:** the plan's acceptance criteria say `git diff --stat lib/` is empty, but the plan's own threat register (T-05-09) says "the fix for a red case is a computed extent or a flexible child, never a relaxed assertion", and the orchestrator's brief says to fix the widget and record it as a deviation. Fixing won; `lib/` therefore carries one file's diff for this plan, `pubspec.yaml` none.

### Plan-shape adjustments (no behaviour lost)

**2. Picker chrome split into two tests per locale instead of one.** After a picker route is dismissed, the page it was opened from stops responding to further synthetic taps in this harness (the second `tester.tap` hit-tests into the dismissed route's scope). Chaining date → time in one body would have silently proven only that the time picker never opened. Each picker now gets its own freshly pumped editor; the claim is unchanged and the reason is recorded in the file.

**3. App-shell folding.** The plan asked that the existing English shell test become a matrix member rather than a duplicate. Both single-locale label-render tests were folded into the matrix; what the English test uniquely claimed — that `BoostqueApp` with no stored override follows the system locale, and that tabs switch in place — is kept as its own test.

**4. Empty-day matrix case waits on the no-stack body, not the title.** The Calendar deliberately assumes a non-empty stack until `stackEntriesProvider` resolves, so waiting on `emptyDayTitle` alone asserted against the neutral copy one frame too early. The wait now targets `emptyDayBodyNoStack`, which is the state the case claims.

## Verification

- `flutter gen-l10n && flutter analyze` — 0 issues.
- `flutter test` — **641 passed, 0 failed** (whole suite; `integration_test/` not run, per brief).
- `git diff --stat pubspec.yaml` empty; `lib/` limited to the one overflow fix above.
- `grep -c "const Locale('uk')"` is **0** in `app_shell_test.dart`, `regimen_editor_test.dart` and `calendar_screen_test.dart`.
- No `pumpAndSettle` follows any locale flip in any file; every flip is a single `pump()`.

## For UAT

**State explicitly so it is not filed as a bug (E-12):** supplements already in the stack do NOT rename when the app language changes. Catalog entries copy the active locale's name at add-time and become user data from that moment; the chrome around them (eyebrow, status chips, headings) does follow the language.

## Known Stubs

None.

## Self-Check: PASSED

- `test/support/locale_matrix.dart` — FOUND
- `.planning/phases/05-localization-settings/05-04-SUMMARY.md` — FOUND
- Commits `a616b88`, `82c7cd7`, `69d1a00` — FOUND on `worktree-agent-a09e29b44c61dcf91`

## Notes for the Next Plan

- `test/support/` is now a real directory in this repo. It exists for cross-suite gate data (the A8 allowlist); adding self-contained helpers there instead of in the suite that uses them would erode the house style it was carved out of.
- The Cyrillic sweep only sees `Text` widgets. Copy that reaches the user through `Semantics(label:)` alone, or through a `CustomPainter`'s `TextPainter`, is not covered — a future accessibility-copy phase should extend the sweep rather than assume it is exhaustive.
