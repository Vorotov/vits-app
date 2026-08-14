---
phase: 01-foundation
plan: 01
subsystem: infra
tags: [flutter, riverpod, drift, fonts, scaffold]

requires: []
provides:
  - Buildable Flutter project `boostque` (org com.boostque) at repo root, iOS + Android
  - Locked dependency set installed via pub (flutter_riverpod, drift, drift_flutter, path_provider, uuid, shared_preferences, flutter_localizations, intl; dev: build_runner, drift_dev, flutter_lints, mocktail)
  - Minimal ProviderScope entry point (`BoostqueApp`) + green smoke widget test
  - Instrument Sans + JetBrains Mono variable fonts bundled under assets/fonts/ with OFL licenses, declared as single-entry pubspec families
  - Platform config: com.boostque.dev bundle/application id, Android targetSdk 36, no network permission
affects: [01-02, 01-03, 01-04, 01-05, 01-06, 01-07]

actuals:
  tokens: 29000
  tasks: 2
  commits: 2

tech-stack:
  added: [flutter_riverpod ^3.4.2, drift ^2.34.3, drift_flutter ^0.3.1, path_provider ^2.1.6, uuid ^4.6.0, shared_preferences ^2.5.5, flutter_localizations (sdk), intl (SDK-resolved ^0.20.3), build_runner ^2.16.0, drift_dev ^2.34.5, flutter_lints ^6.0.0, mocktail ^1.0.5]
  patterns:
    - "Dependencies installed via `flutter pub add` only — resolver validates versions, never hand-edited"
    - "Variable fonts: one pubspec fonts: entry per family, no weight: fanning (FontWeight → wght axis auto-maps, Flutter 3.41+)"

key-files:
  created:
    - lib/main.dart
    - test/smoke_test.dart
    - assets/fonts/InstrumentSans[wdth,wght].ttf
    - assets/fonts/JetBrainsMono[wght].ttf
    - assets/fonts/OFL-InstrumentSans.txt
    - assets/fonts/OFL-JetBrainsMono.txt
    - android/app/build.gradle.kts
    - ios/Runner.xcodeproj/project.pbxproj
  modified:
    - pubspec.yaml
    - .gitignore

key-decisions:
  - "intl left unpinned — SDK resolution picked 0.20.3 via flutter_localizations (D-04)"
  - "No sqlite3_flutter_libs — drift 2.32+ bundles SQLite natively (D-04)"
  - "Single variable-font TTF per family committed to repo; no runtime font fetching (D-05)"

patterns-established:
  - "Offline-only dependency surface: no http/dio/cronet/google_fonts anywhere in pubspec (DATA-01)"
  - "No user-visible strings in widget code — lib/main.dart renders SizedBox.shrink() only (i18n rule)"

requirements-completed: [DATA-01]

coverage:
  - id: D1
    description: "Flutter project scaffold at repo root with locked deps, com.boostque.dev ids, targetSdk 36, minimal ProviderScope app compiling for iOS simulator and Android debug"
    requirement: DATA-01
    verification:
      - kind: other
        ref: "flutter analyze && flutter test test/smoke_test.dart && flutter build ios --simulator --debug && flutter build apk --debug"
        status: pass
      - kind: other
        ref: "grep gates: targetSdk 36, applicationId com.boostque.dev, 3x PRODUCT_BUNDLE_IDENTIFIER com.boostque.dev, no INTERNET permission, approved-package allowlist + networking-package denylist in pubspec.yaml"
        status: pass
    human_judgment: false
  - id: D2
    description: "Instrument Sans + JetBrains Mono bundled as single variable-font TTFs with OFL licenses and declared as single-entry pubspec font families"
    requirement: DATA-01
    verification:
      - kind: other
        ref: "size gate (>100KB per TTF, sfnt magic bytes verified), OFL files non-empty, exactly one non-comment pubspec reference per font file, family names present; flutter analyze && flutter test"
        status: pass
    human_judgment: false
  - id: D3
    description: "Resolved dependency tree matches the Package Legitimacy Audit (no unexpected direct or transitive packages)"
    verification: []
    human_judgment: true
    rationale: "Plan mandates a phase-end human review of `flutter pub deps --style=compact` against the audit table in 01-RESEARCH.md — no automated legitimacy seam exists"

duration: 2h 14m wall clock (incl. session-limit interruption between tasks)
completed: 2026-08-14
status: complete
---

# Phase 1 Plan 01: Tracer Scaffold Summary

**Buildable boostque Flutter skeleton (iOS + Android, com.boostque.dev, targetSdk 36) with the full locked Phase-1 dependency set and both variable fonts bundled offline**

## Performance

- **Duration:** 2h 14m wall clock (includes a session-limit interruption between Task 1 and Task 2; active execution ~40 min)
- **Started:** ~2026-08-14T15:30:00Z (Task 1, prior executor session)
- **Completed:** 2026-08-14T17:55:00Z
- **Tasks:** 2
- **Files modified:** 71 (66 scaffold files in Task 1, 5 font/pubspec files in Task 2)

## Accomplishments

- Scaffolded `boostque` at repo root via `flutter create` (org com.boostque, platforms ios+android), preserving the pre-existing `.DS_Store` gitignore line
- Installed the entire D-04 locked dependency set through `flutter pub add` (resolver-validated); intl SDK-resolved, no networking package, no sqlite3_flutter_libs
- Set com.boostque.dev on both platforms (3 Runner pbxproj entries + applicationId) and explicit `targetSdk = 36`
- Proved the thinnest end-to-end slice: minimal `ProviderScope(child: BoostqueApp())` analyzes clean, smoke widget test green, and both `flutter build ios --simulator --debug` and `flutter build apk --debug` compile
- Bundled Instrument Sans `[wdth,wght]` and JetBrains Mono `[wght]` variable TTFs (sfnt magic verified, >100KB each) with OFL licenses; declared exactly one `fonts:` entry per family with no `weight:` fanning

## Task Commits

Each task was committed atomically:

1. **Task 1: Scaffold boostque, platform ids, locked deps, both platform builds (tracer)** - `9e9d113` (feat)
2. **Task 2: Bundle variable fonts + pubspec declaration** - `d8df262` (feat)

## Files Created/Modified

- `pubspec.yaml` - Locked dependency set + two single-entry font family declarations
- `lib/main.dart` - `main()` → `runApp(ProviderScope(child: BoostqueApp()))`; empty offline-safe MaterialApp (rewired by plan 01-06)
- `test/smoke_test.dart` - Pumps ProviderScope + BoostqueApp, asserts one MaterialApp (Wave-0 test-harness proof)
- `android/app/build.gradle.kts` - `applicationId = "com.boostque.dev"`, `targetSdk = 36`
- `ios/Runner.xcodeproj/project.pbxproj` - 3x `PRODUCT_BUNDLE_IDENTIFIER = com.boostque.dev` (RunnerTests left as generated)
- `assets/fonts/InstrumentSans[wdth,wght].ttf`, `assets/fonts/JetBrainsMono[wght].ttf` - Variable fonts from canonical google/fonts paths
- `assets/fonts/OFL-InstrumentSans.txt`, `assets/fonts/OFL-JetBrainsMono.txt` - Font licenses
- `.gitignore` - Flutter template + preserved `.DS_Store` line

## Decisions Made

- Followed plan as specified; intl version (0.20.3) came from SDK resolution, not hand-pinned

## Deviations from Plan

None - plan executed exactly as written.

## Known Stubs

- `lib/main.dart` renders `Scaffold(body: SizedBox.shrink())` — intentional tracer minimum; plan 01-06 rewires `BoostqueApp` with theme + l10n + app shell (declared in this plan's output spec, not a defect)

## Issues Encountered

- Executor session hit its limit between Task 1 and Task 2 (fonts downloaded but not yet declared/committed). Continuation executor verified Task 1 commit `9e9d113`, validated the downloaded TTFs (sfnt magic bytes, sizes), and completed Task 2 without redoing work.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Wave-1 tracer proven: pub resolution → Dart compile → iOS + Android toolchains → test harness all green on one skeleton
- Plans 01-02..01-07 can expand from this slice (domain math, theme tokens, l10n, Drift schema, app shell, repositories)
- Phase-end human-check outstanding: review `flutter pub deps --style=compact` against the Package Legitimacy Audit in 01-RESEARCH.md (coverage D3)
- DATA-01 recorded in `requirements-completed` but NOT yet checked off in REQUIREMENTS.md — five sibling plans (01-02/03/04/06/07) also declare it and are unfinished (shared-ID gate)

## Self-Check: PASSED

- `lib/main.dart`, `test/smoke_test.dart`, both TTFs, both OFL files exist on disk — verified `[ -f ]`
- Commits `9e9d113` and `d8df262` exist in `git log`
- All Task 1 + Task 2 acceptance criteria re-run and passing (analyze 0 issues, smoke test green, both platform builds succeed, all grep gates pass)

---
*Phase: 01-foundation*
*Completed: 2026-08-14*
