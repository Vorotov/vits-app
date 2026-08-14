---
phase: 01-foundation
plan: 04
subsystem: i18n
tags: [gen-l10n, arb, icu-plurals, ukrainian, riverpod, shared_preferences]

requires:
  - phase: 01-foundation (plan 01-01)
    provides: Flutter scaffold at repo root with flutter_riverpod, shared_preferences, flutter_localizations deps
provides:
  - gen-l10n pipeline (l10n.yaml + pubspec generate:true) generating AppLocalizations into lib/core/l10n/gen/
  - app_en.arb + app_uk.arb with shell strings and substancesCount/weeksCount plurals (all four uk CLDR forms)
  - context.l10n extension (lib/core/l10n/l10n.dart)
  - LocaleController + localeControllerProvider (Riverpod 3.x Notifier, SharedPreferences key app_locale, sanitized load)
affects: [01-06 app shell, 01-07 providers, phase-5 settings/language picker, all feature screens]

actuals:
  tokens: 4930
  tasks: 2
  commits: 3

tech-stack:
  added: []
  patterns:
    - "gen-l10n source-dir path: synthetic-package false + pubspec generate:true, imports via package:boostque/core/l10n/gen/"
    - "Plural unit tests via AppLocalizations.delegate.load — no widget pump (RESEARCH Pattern 6)"
    - "Riverpod 3.x Notifier with async SharedPreferences load kicked off in build(), state set only on validated input"

key-files:
  created:
    - l10n.yaml
    - lib/core/l10n/arb/app_en.arb
    - lib/core/l10n/arb/app_uk.arb
    - lib/core/l10n/gen/app_localizations.dart
    - lib/core/l10n/gen/app_localizations_en.dart
    - lib/core/l10n/gen/app_localizations_uk.dart
    - lib/core/l10n/l10n.dart
    - lib/core/l10n/locale_controller.dart
    - test/l10n/plurals_test.dart
    - test/l10n/locale_controller_test.dart
  modified:
    - pubspec.yaml

key-decisions:
  - "uk `other` plural branch mirrors `few` text as non-integer fallback (RESEARCH Assumption A4)"
  - "Supported language codes exposed as LocaleController.supportedLanguageCodes {en, uk} — single source for sanitization"
  - "Generated lib/core/l10n/gen/ files committed to git so wave-3 plans build without running gen-l10n first"

patterns-established:
  - "Every user-visible string reads via context.l10n; ARB pair is the only string source"
  - "Untrusted local storage validated on load: unknown app_locale values → null/system (T-01-07)"

requirements-completed: [DATA-01]

coverage:
  - id: D1
    description: "gen-l10n pipeline configured (l10n.yaml per D-08 + pubspec generate:true) producing AppLocalizations in lib/core/l10n/gen/"
    requirement: DATA-01
    verification:
      - kind: other
        ref: "flutter gen-l10n && [ -s lib/core/l10n/gen/app_localizations.dart ]"
        status: pass
    human_judgment: false
  - id: D2
    description: "en/uk ARB seeds with shell strings and substancesCount/weeksCount plurals covering all four uk CLDR forms incl. 11-14 exception"
    requirement: DATA-01
    verification:
      - kind: unit
        ref: "test/l10n/plurals_test.dart#uk plurals + en plurals (counts 1/2/5/11/21 uk, 1/2/21 en)"
        status: pass
    human_judgment: false
  - id: D3
    description: "context.l10n extension importing generated AppLocalizations by package path"
    verification:
      - kind: other
        ref: "flutter analyze (0 issues; extension compiles against non-null AppLocalizations.of)"
        status: pass
    human_judgment: false
  - id: D4
    description: "LocaleController persisting app_locale with null=system semantics and sanitized load of unsupported values"
    requirement: DATA-01
    verification:
      - kind: unit
        ref: "test/l10n/locale_controller_test.dart#4 tests (load uk, empty→null, persist/clear, sanitize de→null)"
        status: pass
    human_judgment: false

duration: 4min
completed: 2026-08-14
status: complete
---

# Phase 1 Plan 04: i18n Foundation Summary

**gen-l10n pipeline with en/uk ARB pair proving all four Ukrainian CLDR plural forms (incl. the 11-14 exception) at counts 1/2/5/11/21, plus a sanitizing SharedPreferences-backed LocaleController**

## Performance

- **Duration:** 4 min
- **Started:** 2026-08-14T17:57:04Z
- **Completed:** 2026-08-14T18:00:44Z
- **Tasks:** 2
- **Files modified:** 11

## Accomplishments

- l10n.yaml (all seven D-08 option lines) + pubspec `generate: true` — gen-l10n runs and regenerates idempotently
- app_en.arb / app_uk.arb seeded with appTitle, tabStack/tabCalendar/tabSettings, disclaimerEducational, and plural exemplars substancesCount/weeksCount; uk plurals carry one/few/many/other
- Plural unit tests via `AppLocalizations.delegate.load` (no widget pump): uk 1→речовина, 2→речовини, 5→речовин, 11→речовин (11-14 exception), 21→речовина; same matrix for тиждень/тижні/тижнів; en one/other — 18 expectations, all green
- `context.l10n` extension with non-null `AppLocalizations.of` (nullable-getter: false)
- LocaleController (Riverpod 3.x `Notifier<Locale?>`, plain non-autoDispose `NotifierProvider`): null = follow system; persists/removes SharedPreferences key `app_locale`; stored values outside {en, uk} sanitized to null (T-01-07) — 4 tests green

## Task Commits

Each task was committed atomically:

1. **Task 1: gen-l10n config + ARB seeds + generation + context.l10n + plural tests** - `1bb0be1` (feat)
2. **Task 2: LocaleController** - `c9bea6d` (test, TDD RED) + `7b77875` (feat, TDD GREEN)

## Files Created/Modified

- `l10n.yaml` - gen-l10n config (arb-dir lib/core/l10n/arb, output lib/core/l10n/gen, synthetic-package false, nullable-getter false)
- `pubspec.yaml` - added `generate: true` under `flutter:` (only permitted edit; RESEARCH Pitfall 3)
- `lib/core/l10n/arb/app_en.arb` - English template ARB with @-metadata (placeholder count: int)
- `lib/core/l10n/arb/app_uk.arb` - Ukrainian ARB with all four CLDR plural branches in both plural strings
- `lib/core/l10n/gen/*.dart` - generated AppLocalizations (committed for wave-3 consumers)
- `lib/core/l10n/l10n.dart` - `L10nX.l10n` extension, re-exports AppLocalizations
- `lib/core/l10n/locale_controller.dart` - LocaleController + localeControllerProvider
- `test/l10n/plurals_test.dart` - 18 plural expectations across uk/en
- `test/l10n/locale_controller_test.dart` - 4 controller behavior tests

## Decisions Made

- uk `other` branch mirrors `few` text (non-integer fallback, RESEARCH Assumption A4) — never hit for integer counts
- Exposed `LocaleController.supportedLanguageCodes` as a public static const so the Phase-5 language picker can reuse the same allow-set

## Deviations from Plan

None - plan executed exactly as written.

(Note: `flutter gen-l10n` on Flutter 3.47 warns that `synthetic-package` "no longer has any effect" — the option is now a no-op past its removal, exactly as RESEARCH anticipated. The line is kept per the D-08 lock and the acceptance-criteria grep; output lands in lib/core/l10n/gen/ as required either way.)

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Plan 01-06 can wire MaterialApp with `AppLocalizations.delegate` / `supportedLocales: [en, uk]` and watch `localeControllerProvider` with zero additional i18n setup
- All future screens read strings via `context.l10n`; new keys are appended to both ARB files then `flutter gen-l10n`
- REQUIREMENTS.md not modified in this worktree (shared orchestrator artifact; DATA-01 completion marking deferred to the orchestrator per single-writer contract)

## Self-Check: PASSED

- l10n.yaml, both ARBs, gen output, l10n.dart, locale_controller.dart, both test files exist on disk ✓
- Commits 1bb0be1, c9bea6d, 7b77875 present in git log ✓
- `flutter test test/l10n/` → 8/8 pass; `flutter analyze` → 0 issues; `flutter gen-l10n` idempotent ✓

---
*Phase: 01-foundation*
*Completed: 2026-08-14*
