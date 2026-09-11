---
phase: 01-foundation
plan: 03
subsystem: ui
tags: [flutter, theme, design-tokens, material3, variable-fonts]

requires:
  - phase: 01-foundation (plan 01-01)
    provides: Flutter scaffold + bundled variable fonts (Instrument Sans, JetBrains Mono) declared in pubspec fonts
provides:
  - lib/core/theme/tokens.dart — BqColors (19 palette colors + hairline), BqSeriesColors.palette (8), BqRadii (5), BqSpace (7)
  - lib/core/theme/theme.dart — bqTheme() ThemeData factory + BqText.mono() helper
  - test/theme/theme_test.dart — exact-hex and theme-wiring assertions (17 tests)
affects: [01-06 app shell, phase-2 stack screens, phase-3 calendar, phase-4 planners, phase-5 settings]

actuals:
  tokens: 3200
  tasks: 2
  commits: 4

tech-stack:
  added: []
  patterns:
    - "Token-only styling (D-07): all colors/radii/spacing come from tokens.dart; zero raw hex outside it (grep-gated)"
    - "Variable-font weight selection via plain FontWeight (wght axis auto-mapping, Flutter 3.41+) — no FontVariation, no google_fonts"
    - "abstract final class holders of static consts for token namespaces"

key-files:
  created:
    - lib/core/theme/tokens.dart
    - lib/core/theme/theme.dart
    - test/theme/theme_test.dart
  modified: []

key-decisions:
  - "NavigationBar indicatorColor set to Colors.transparent — mockup shows a flat two-state bar with no pill indicator (discretionary choice allowed by UI-SPEC, recorded here)"
  - "hairline token encoded as Color(0x1417171B) — alpha 0x14 ≈ 0.078 matches mockup rgba(23,23,27,.08) top border"
  - "ColorScheme built via fromSeed(BqColors.accent).copyWith(primary: accent, surface: paper) so exact mockup hexes override seeded tonal values"

patterns-established:
  - "Token-only rule: later phases import tokens.dart/theme.dart and never define hex values"
  - "BqText.mono() with FontFeature.tabularFigures() is the canonical style for numerals/counters from Phase 3 on"

requirements-completed: [DATA-01]

coverage:
  - id: D1
    description: "All mockup design tokens (19-color palette + hairline, 8-color series palette, radii card 14/panel 16/button 12/chip 5/seg 10, 8-point spacing scale) exist as typed Dart constants"
    requirement: DATA-01
    verification:
      - kind: unit
        ref: "test/theme/theme_test.dart#BqColors/BqSeriesColors/BqRadii/BqSpace groups"
        status: pass
      - kind: other
        ref: "grep -c '0xFF' lib/core/theme/tokens.dart == 27 (19 BqColors + 8 series)"
        status: pass
    human_judgment: false
  - id: D2
    description: "bqTheme() encodes the mockup design system (paper scaffold, accent primary, heading 25/w600/-0.5/1.1, body 13/w400/1.4, NavigationBar surfaceAlt/accent/textFaint with 10/w500 labels) exclusively from tokens; BqText.mono() returns JetBrains Mono with tabular figures"
    requirement: DATA-01
    verification:
      - kind: unit
        ref: "test/theme/theme_test.dart#bqTheme() and BqText.mono groups"
        status: pass
      - kind: other
        ref: "! grep -rEq '0xFF[0-9A-Fa-f]{6}' lib/core/theme/theme.dart (zero raw hex) && flutter analyze (0 issues)"
        status: pass
    human_judgment: false

duration: 4min
completed: 2026-08-14
status: complete
---

# Phase 1 Plan 03: Design Tokens + Theme Summary

**Full mockup palette (19 colors + hairline), 8-color series palette, radii and 8-pt spacing as typed constants, plus bqTheme() with heading/body/NavigationBar roles and BqText.mono() — all test-locked against drift**

## Performance

- **Duration:** 4 min
- **Started:** 2026-08-14T17:57:06Z
- **Completed:** 2026-08-14T18:00:45Z
- **Tasks:** 2 (both TDD)
- **Files modified:** 3

## Accomplishments

- `lib/core/theme/tokens.dart`: BqColors (canvas, paper, surface, surfaceAlt, chip, field, ink, textSecondary, textMuted, textFaint, accent, accentPressed, accentChipBg, calm/calmBg, warn/warnBg, risk/riskBg, hairline), BqSeriesColors.palette (8, mockup order), BqRadii (card 14 / panel 16 / button 12 / chip 5 / seg 10), BqSpace (xs 4 → xxxl 64)
- `lib/core/theme/theme.dart`: bqTheme() — Material 3, bundled 'Instrument Sans' via plain FontWeight (wght axis), paper scaffold, accent-seeded ColorScheme with exact-token overrides, heading role 25/w600/−0.5/1.1, body role 13/w400/1.4, NavigationBarThemeData per D-25; BqText.mono() with 'JetBrains Mono' + tabularFigures
- 17 exact-value tests lock every hex, radius, spacing step, and theme wiring; `flutter analyze` clean; grep gate proves zero raw hex in theme.dart

## Task Commits

Each task was committed atomically (TDD: test → feat):

1. **Task 1: Design tokens — palette, series, radii, spacing**
   - RED `50d53f1` (test) → GREEN `b017c28` (feat)
2. **Task 2: bqTheme() ThemeData + BqText.mono helper**
   - RED `4c433f8` (test) → GREEN `3276035` (feat)

No refactor commits needed — implementations were clean on first pass.

## Files Created/Modified

- `lib/core/theme/tokens.dart` — single source of truth for palette, series, radii, spacing (D-06/D-07); doc comments restate the token-only rule and the NavigationBar pixel-override exemption
- `lib/core/theme/theme.dart` — bqTheme() ThemeData factory + BqText.mono(); imports only material + tokens.dart; zero raw hex
- `test/theme/theme_test.dart` — 17 tests asserting exact hexes, series order, radii, spacing, theme wiring, NavigationBar label/icon state resolution, mono helper

## Decisions Made

- **NavigationBar indicator = Colors.transparent** (discretionary per UI-SPEC): the mockup nav bar is a flat two-state design with no Material pill indicator; recorded here as the plan required
- **hairline = Color(0x1417171B)**: alpha 0x14 (20/255 ≈ 0.078) encodes the mockup's `rgba(23,23,27,.08)` 1px top border
- **ColorScheme.fromSeed(...).copyWith(primary, surface)**: seeding gives Material 3 a complete tonal scheme while the exact mockup hexes override the two colors Phase 1 actually renders

## Deviations from Plan

None - plan executed exactly as written.

## TDD Gate Compliance

RED gate (`test(...)` commits 50d53f1, 4c433f8) and GREEN gate (`feat(...)` commits b017c28, 3276035) both present per task; each RED run was confirmed failing before implementation.

## Issues Encountered

- `claude_design_mockup/VitoMy v0.1.dc.html` is untracked in git and therefore absent from the isolated worktree. Locked hex values from 01-CONTEXT.md / 01-UI-SPEC.md were used as ground truth (as the plan specifies); the mockup CSS was additionally cross-checked read-only from the main checkout — all hexes match.
- Minor compile fix during Task 1 GREEN: `library;` directive had to precede the import in tokens.dart (caught by the test run before commit; not a deviation).

## Orchestrator Notes

- REQUIREMENTS.md was NOT modified: DATA-01 is shared with sibling plans still executing in this wave (shared-ID gate #2388), and node is not on PATH in this worktree. Orchestrator should run the requirements mark-complete step after the wave merges.
- STATE.md / ROADMAP.md untouched per parallel-execution contract.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Plan 01-06 can style the shell entirely via bqTheme()/tokens with zero new color/typography decisions (heading + NavigationBar roles pre-encoded)
- Phases 2–5 consume BqRadii/BqSeriesColors/BqText.mono without re-deriving any value

## Self-Check: PASSED

- All 3 created files exist on disk (tokens.dart, theme.dart, theme_test.dart)
- All 4 task commits present in git log (50d53f1, b017c28, 4c433f8, 3276035); docs commit is this SUMMARY's own commit
- `flutter test test/theme/` → 17/17 pass; `flutter analyze` → 0 issues; hex grep gates pass

---
*Phase: 01-foundation*
*Completed: 2026-08-14*
