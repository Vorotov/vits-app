---
phase: 05-localization-settings
plan: 01
subsystem: l10n + settings
status: complete
tags: [l10n, settings, riverpod, shared-preferences, a11y, criterion-4]
requires:
  - AppLocalizations (gen-l10n, Phase 1)
  - localeControllerProvider wired to MaterialApp.locale (Phase 1, D-10/D-11)
  - BqColors / BqRadii / BqSpace / BqText.mono (Phases 1-4)
provides:
  - sharedPreferencesProvider (synchronous prefs seed, app-lifetime)
  - LocaleController with a DERIVED language allowlist and a synchronous build()
  - SettingsScreen (S7) + LanguagePicker
  - ARB keys languageName / languageSystem / settingsLanguageTitle
  - ARB key addSupplementCatalogSemantics (Amendment A2, code half)
  - declared English fallback via preferred-supported-locales
affects:
  - every test harness that pumps BoostqueApp or mounts AppShell
  - lib/features/stack/add_supplement_sheet.dart (a11y label only)
tech-stack:
  added: []
  patterns:
    - "Throwing provider + override-in-main() for a value that must exist before frame 1"
    - "Self-referential ARB key (languageName) resolved via lookupAppLocalizations"
    - "State-first, persist-after ordering in a Notifier that writes to disk"
    - "Comment-stripped source gates behind a prove-the-glob assertion"
key-files:
  created:
    - lib/features/settings/language_picker.dart
    - test/features/settings_screen_test.dart
  modified:
    - l10n.yaml
    - .gitignore
    - lib/core/l10n/arb/app_en.arb
    - lib/core/l10n/arb/app_uk.arb
    - lib/core/l10n/gen/app_localizations.dart
    - lib/core/l10n/gen/app_localizations_en.dart
    - lib/core/l10n/gen/app_localizations_uk.dart
    - lib/core/providers.dart
    - lib/core/l10n/locale_controller.dart
    - lib/main.dart
    - lib/features/settings/settings_screen.dart
    - lib/features/stack/add_supplement_sheet.dart
    - test/l10n/locale_controller_test.dart
    - test/smoke_test.dart
    - test/widget/app_shell_test.dart
    - test/features/planner_screen_test.dart
    - integration_test/data03_loop_test.dart
decisions:
  - "P-4 Option A shipped: sharedPreferencesProvider throws unless overridden, so LocaleController.build() seeds synchronously and a stored override is live on the first painted frame — no cold-start language flash."
  - "The English fallback is DECLARED (preferred-supported-locales: [en] in l10n.yaml), not inherited from gen-l10n's alphabetical ordering (PF-1, L10N-02)."
  - "The shipped-language allowlist is derived from AppLocalizations.supportedLocales, never enumerated — the sanitization that keeps a tampered code away from lookupAppLocalizations now follows the ARB files (T-05-01, T-05-02)."
  - "setLocale sets state BEFORE persisting; a failed write costs the next launch only and is deliberately not surfaced (PF-3, DECIDED-8)."
  - "Amendment A2's code half landed here rather than in 05-05, because 05-03's zero-hardcoded-strings gate runs a wave earlier and would otherwise arrive red."
metrics:
  duration: ~50m
  completed: 2026-08-16
actuals:
  tokens: 42000
  tasks: 3
  commits: 3
---

# Phase 5 Plan 01: Settings Screen and the Language Switch Summary

A user can switch the app language from Settings and the whole app — nav bar, both other tabs, a pushed route, an open sheet — re-reads in that language within one frame; the choice is applied on the first painted frame after a restart; and the shipped-language set is derived from the ARB files rather than listed in Dart.

## What Shipped

| Artifact | Kind | Notes |
|---|---|---|
| `l10n.yaml` | config | `preferred-supported-locales: [en]` declares the fallback; `untranslated-messages-file` makes a missing non-template key assertable |
| `.gitignore` | config | `l10n-untranslated.json` — gen-l10n diagnostic output, never committed |
| `languageName` / `languageSystem` / `settingsLanguageTitle` | copy | Both locales, `@`-metadata in the template. `languageName` is self-referential: every ARB declares its own endonym under the same key |
| `addSupplementCatalogSemantics` | copy | Amendment A2's code half — the repo's only concatenation of localized fragments is gone |
| `sharedPreferencesProvider` | provider | Throws unless overridden; resolved once in `main()` before `runApp` |
| `LocaleController` | store | Derived allowlist, synchronous `build()`, state-first `setLocale` |
| `SettingsScreen` (S7) | screen | Title, mono eyebrow, one language card. No async surface, no error surface, no CTA |
| `LanguagePicker` | component | `[null, ...supportedLocales]`, checked-row semantics on the row, `minHeight: 52`, wrapping labels |

## Tasks and Commits

| Task | Commit | What |
|---|---|---|
| 1 (tracer, TDD) | `7d8ff17` | Config, ARB, provider, controller, `main()`, screen, picker, A2 — plus the four tracer tests written first (RED confirmed as missing generated getters) |
| 2 | `f38d6de` | Every harness that reaches `LocaleController` closed; `locale_controller_test.dart` rewritten for the synchronous contract |
| 3 | `054845b` | The full S7 contract as 28 further assertions in `settings_screen_test.dart` |

## Verification

- `flutter analyze` — **0 issues**.
- `flutter test` — **582 passing, 0 failing** (baseline 547 + 35 new: 32 in `settings_screen_test.dart`, +3 net in `locale_controller_test.dart`).
- `git diff pubspec.yaml` — empty. **Zero new packages**, `fonts:` block untouched (LOCKED-FONT honoured; no `fontFamilyFallback` added).
- `git diff lib/core/theme/tokens.dart` — empty. **Zero new tokens**.
- `integration_test/` was NOT run (needs a device) — the code change that keeps it working landed and analyzes clean.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] A sixth harness reached `LocaleController` that the plan's enumeration missed**
- **Found during:** Task 2, running the FULL suite as the task instructs.
- **Issue:** `test/features/planner_screen_test.dart`'s `system back` group mounts the real `AppShell`, whose `IndexedStack` mounts the Settings tab — and therefore the language picker — even while the Stack tab is visible. Its shared `makeContainer()` had no prefs override, so two tests threw `UnimplementedError`. The same shape of miss hit `app_shell_test.dart`'s minute-ticker test, which builds its own `ProviderContainer` rather than going through `scoped()`.
- **Fix:** prefs override added to `planner_screen_test.dart`'s `makeContainer()` (via a `late SharedPreferences` resolved in `setUp`) and to the standalone ticker container. Both are documented in place so a later test that mounts the shell inherits the seed.
- **Files modified:** `test/features/planner_screen_test.dart`, `test/widget/app_shell_test.dart`
- **Commit:** `f38d6de`

### Intentional test-design changes

**2. Tracer Test 1 proves the switch in BOTH directions, not just the English tap.**
The plan specified: empty mock prefs, tap the English endonym row, assert English after one pump. But the flutter_test environment already resolves to English with an empty store, so that tap would have switched nothing and the assertion would have passed against a screen that never changed. The test now taps Ukrainian first (asserting the whole tree flips in one frame), then taps English (asserting it flips back in one frame) — a strict superset of the specified claim, and the only version that can actually fail if the wire breaks.

**3. The pushed-route propagation test opens the regimen editor by tapping a seeded stack card**, which is the plan's "from the Stack tab" path; the locale is then changed through the controller as specified, and the single-pump assertion follows.

## Threat Mitigations Applied

| Threat | Disposition | Where |
|---|---|---|
| T-05-01 (tampered `app_locale` → launch crash) | mitigated | Derived allowlist in `LocaleController.build()`; proven by the tampered-code unit test AND the rendered selection-invariant test (`'zz'` checks the System row, no exception) |
| T-05-02 (stored code whose ARB was removed) | mitigated | Same derived allowlist; pinned by a dedicated unit test naming the removed-ARB scenario |
| T-05-05 (rapid repeated taps) | accepted | `setLocale` is synchronous-state + idempotent write; last write wins |
| T-05-SC (supply chain) | mitigated | `git diff pubspec.yaml` is empty — zero dependency lines added |

## Known Stubs

None. No placeholder text, no empty-state stand-in, no unwired data source. The Settings feature's only write surface is the `app_locale` key, and it is wired end-to-end.

## Notes for Later Plans

- `sharedPreferencesProvider` now throws unless overridden. **Any new test that pumps `BoostqueApp` or mounts `AppShell` must supply it** — the `UnimplementedError` names the provider, so the failure is loud rather than silent.
- The generated `supportedLocales` order is now controlled by `preferred-supported-locales`, so 05-03's criterion-4 gate can assert `supportedLocales.first == Locale('en')` as a declared fact rather than an alphabetical coincidence.
- Amendment A2's **test half** (the two-locale semantics-tree assertion for the add-supplement label) is still owned by 05-05 Task 1; only the code half landed here.
- LOCKED-FONT stands: no font asset changed, no `fontFamilyFallback` added. Record it as a locked v1 decision in the phase summary.

## Self-Check: PASSED

All four claimed files exist on disk; all three claimed commits (`7d8ff17`, `f38d6de`, `054845b`) are in this branch's log.
