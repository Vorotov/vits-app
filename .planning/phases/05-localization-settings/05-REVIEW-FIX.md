---
phase: 05-localization-settings
fixed_at: 2026-08-16
review_path: .planning/phases/05-localization-settings/05-REVIEW.md
iteration: 1
findings_in_scope: 8
fixed: 8
skipped: 0
status: all_fixed
---

# Phase 5: Code Review Fix Report

**Fixed at:** 2026-08-16
**Source review:** `.planning/phases/05-localization-settings/05-REVIEW.md`
**Iteration:** 1

**Summary:**
- Findings in scope: 8 (CR-01, CR-02, WR-01 … WR-06)
- Fixed: 8
- Skipped: 0
- Out of scope (untouched, still open): IN-01 … IN-07

**Gates after the last fix** — run in the MAIN CHECKOUT (no worktree; this run
was explicitly instructed to work on `main` directly, and `.planning/config.json`
carries no worktree opt-in for this path):
- `flutter analyze` — **No issues found**
- `flutter test` — **693/693 passing** (676 baseline + 17 new)
- `integration_test/` was NOT run (needs a device) but is covered by
  `flutter analyze`, which includes it; `l10n_device_test.dart` calls the real
  `main()` and its two persisted-value assertions (`'en'`, `'uk'`) are unchanged
  by WR-05, because `Locale('en').toLanguageTag()` is `'en'`.

## Fixed Issues

### CR-01: A tampered or wrong-typed `app_locale` value crashes the app at launch

**Files modified:** `lib/core/l10n/locale_controller.dart`,
`test/l10n/locale_controller_test.dart`
**Commit:** `eb2b837`
**Applied fix:** `build()` now reads the raw `Object?` through
`SharedPreferences.get` and type-tests it before the membership check, so the
type of untrusted storage is sanitized alongside its content. The regression
test loops over an int, a bool, a double and a `List` under `app_locale`; it
throws a `ProviderException` against the previous code (verified red first).

### CR-02: An unguarded `SharedPreferences.getInstance()` in `main()` can leave the app permanently blank

**Files modified:** `lib/main.dart`, `lib/core/providers.dart`,
`lib/core/l10n/locale_controller.dart`,
`test/l10n/cold_start_degradation_test.dart` (new),
`test/l10n/no_hardcoded_strings_test.dart`
**Commit:** `18d85c9`
**Applied fix:** `sharedPreferencesProvider` is `Provider<SharedPreferences?>`
so "the store could not be opened" is representable (the un-overridden throw is
kept — a missed test harness still fails loudly). `main()` catches, reports via
`FlutterError.reportError`, and starts anyway; `build()` reads through `?.` and
`setLocale` returns early on a null store, which is DECIDED-8's already-accepted
cost of one launch of amnesia.

The new gate drives the **real `main()`** with a deliberately broken store (no
`setMockInitialValues` anywhere in that file — the premise is asserted, not
assumed) and proves a `MaterialApp` is attached. Only `path_provider` is given a
host implementation, because the launch path opens the real database; the store
under test stays broken.

The source gate's existing "assertion and thrown-error messages" allowlist
category was extended to the two crash-report constructors
(`FlutterErrorDetails`, `ErrorDescription`) rather than widening any pattern.

### WR-01: `stackEntriesProvider` still drops an error when the other stream is loading

**Files modified:** `lib/core/providers.dart`,
`test/features/stack_screen_test.dart`
**Commit:** `049f87b`
**Applied fix:** the nested `when` is replaced by an explicit precedence across
both sources — **error, then value, then loading**. Value-beats-loading is
deliberate and preserves what `skipLoadingOnReload: true` bought: a re-emission
that still carries its previous value keeps the last good pairing rather than
blanking the list. Regression test (both locales) errors
`regimensStreamProvider` while `supplementsStreamProvider` has not emitted; it
was red in both locales before the fix.

### WR-02: The A1 flag added to the Stack screen is inert, and its comment says otherwise

**Files modified:** `lib/features/stack/stack_screen.dart`,
`test/features/stack_screen_test.dart`
**Commit:** `6f38a5a`
**Applied fix:** the preferred option — the screen is now robust on its own
terms, using the planner's shape (`switch` with `AsyncValue(hasError: true)`
first, then data, then loading). The comment states what actually protects the
surface and records why the old flag could never change an outcome here. A
screen-level test pins the screen straight to a failed value, so it asserts the
screen's rule rather than the wiring.

### WR-03: A3 was applied to one casing site; four locale-independent `toUpperCase()` calls survive

**Files modified:** `lib/core/l10n/casing.dart` (new),
`lib/features/calendar/week_strip.dart`,
`lib/features/calendar/planner_gantt.dart`,
`lib/features/calendar/planner_year_grid.dart`,
`lib/features/calendar/planner_month_detail.dart`,
`test/l10n/casing_test.dart` (new), `test/l10n/no_hardcoded_strings_test.dart`
**Commit:** `6b5a0dd`
**Applied fix:** uppercasing gets ONE definition, `bqUpperCase(value, locale)`,
mirroring what A3 did for sentence case: the default Unicode mapping plus the
single documented exception Dart gets wrong (tr/az `i` → `İ`, `ı` → `I`). All
four sites call it. Both comments claiming "locale-aware uppercasing" are
replaced with what is true: intl formats, `bqUpperCase` cases, and Dart's
`toUpperCase()` is locale-independent. The source gate gains a named allowlist
entry scoped to `casing.dart` alone for the two language subtags.

### WR-04: The language-change write is a discarded future

**Files modified:** `lib/core/l10n/locale_controller.dart`,
`lib/features/settings/language_picker.dart`,
`test/l10n/locale_controller_test.dart`
**Commit:** `7bb0464`
**Applied fix:** the handling lives in the controller, because the phase's own
gate forbids `Error` / `catch (` / `onError` under `lib/features/settings/`.
Both failure shapes are covered — a throw AND the `false` return the review
noted was dropped — and both go to `FlutterError.reportError`: invisible to the
user (DECIDED-8's silence is preserved), visible to a crash logger. The call
site now says `unawaited(...)`, so fire-and-forget is stated rather than
accidental. Two regression tests over a write-refusing store (mocktail) fail
against the previous controller.

### WR-05: Locale identity is collapsed to `languageCode` in three places

**Files modified:** `lib/core/l10n/locale_controller.dart`,
`lib/features/settings/language_picker.dart`,
`test/l10n/locale_controller_test.dart`,
`test/l10n/new_language_contract_test.dart`
**Commit:** `fbdfcf0`
**Applied fix:** the first of the review's two options (full locale identity),
not the ARB-regex tightening — regional variants stay possible. The allowlist is
a tag→`Locale` map derived from `supportedLocales`
(`supportedLanguageCodes` → `supportedLocaleTags`); `build()` returns the
generated `Locale` instance itself, so the picker's comparison holds by
identity; `setLocale` persists `toLanguageTag()`; the picker compares whole
locales. **No migration is needed**: `Locale('uk').toLanguageTag()` is `'uk'`,
so every already-stored value still resolves.

### WR-06: The A1 flag silently disables the `IgnorePointer` hold on a same-day reload

**Files modified:** `lib/features/calendar/calendar_screen.dart`,
`test/features/calendar_screen_test.dart`
**Commit:** `5554d17`
**Applied fix:** the behaviour was restored rather than the comment rewritten —
the guard protects a real write path. The body is now a property match: error
first, then data-and-settled, then held-and-inert for every loading shape
(including the loading-with-previous-value one a regimen change produces). The
data and hold arms moved into `_resolved()` / `_heldRows()` so the switch stays
an expression. The regression test taps a held row during a regimen-triggered
reload, asserts the log stays `pending`, then asserts the same tap lands once
the day re-resolves — proving the inertness is a window, not a broken screen.
It fails against the previous rendering rule.

## Not Fixed (deliberately out of scope)

IN-01 … IN-07 were excluded by the fix scope and remain open in `05-REVIEW.md`.
Two of them are now partially mitigated as a side effect, and neither is
resolved:

- **IN-01** (mutable public allowlist): the field was rewritten for WR-05 and
  `supportedLocaleTags` is now a getter returning a fresh set, so mutating the
  returned set no longer affects sanitization. The backing map is still a plain
  mutable `static final`. Left as documented.
- **IN-03** (allowlist entries keyed on the enclosing call): not narrowed. Both
  entries ADDED during these fixes are scoped narrowly on purpose — one to the
  two crash-report constructors, one to a single file path — so the fixes did
  not widen the surface IN-03 describes.

## Verification notes

- Every fix was committed atomically, in finding order, each with the source and
  test changes together.
- CR-01, CR-02, WR-01, WR-04 and WR-06 were verified RED against the pre-fix
  code before the fix landed (CR-02 as a compile failure on the nullable
  provider, then as a launch failure; WR-04 and WR-06 by stashing the source
  file and re-running).
- WR-02, WR-03 and WR-05 are structural/documentation-correctness fixes whose
  tests pin the new contract rather than reproducing a runtime failure.
- `flutter analyze` was run after every fix and is clean; the full suite was run
  after the last one.

---

_Fixed: 2026-08-16_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 1_
