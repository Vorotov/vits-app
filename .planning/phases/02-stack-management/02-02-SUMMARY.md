---
phase: 02-stack-management
plan: 02
subsystem: theme
tags: [tokens, theme, widgets, segmented, tdd]
status: complete
requires:
  - lib/core/theme/tokens.dart (Phase-1 BqColors/BqRadii)
  - lib/core/theme/theme.dart (Phase-1 bqTheme)
provides:
  - BqColors.cardBorder/inputBorder/scrim/dragHandle/accentBorder/riskBorder/textDisabled/iconDisabled
  - BqRadii.input/segInner/sheet
  - bqTheme() inputDecorationTheme/sliderTheme/datePickerTheme/timePickerTheme/bottomSheetTheme
  - BqSegmented reusable pill control (lib/core/widgets/bq_segmented.dart)
affects:
  - 02-03/02-04 screen plans (style forms, pickers, sheets, segments by token name)
  - Phase 4 (BqSegmented reuse for the Рік/Цикли toggle)
tech-stack:
  added: []
  patterns:
    - "Hand-built segmented control per 02-RESEARCH P-10 (SDK SegmentedButton rejected — M3 look fights mockup pill design)"
    - "InputDecorationThemeData (Flutter 3.47 normalized sub-theme type) instead of legacy InputDecorationTheme"
key-files:
  created:
    - lib/core/widgets/bq_segmented.dart
    - test/widget/bq_segmented_test.dart
  modified:
    - lib/core/theme/tokens.dart
    - lib/core/theme/theme.dart
    - test/theme/theme_test.dart
decisions:
  - "focusedBorder uses BqColors.accent (plan-granted discretion) so focus state is visible against the .14-alpha inputBorder"
  - "datePickerTheme adds headerBackgroundColor accent / headerForegroundColor surface; timePickerTheme adds dialHandColor accent — the 'accent from tokens' part of the UI-SPEC delta"
  - "BqSegmented segments use Semantics(excludeSemantics: true) so the merged node carries exactly one label (no label duplication with the child Text)"
  - "Segment vertical padding 9 (mockup range 9-10)"
metrics:
  duration: ~10 min
  completed: 2026-08-15
actuals:
  tokens: 5200
  tasks: 2
  commits: 3
---

# Phase 2 Plan 02: Shared Visual Infrastructure Summary

11 mockup-sourced tokens, five bqTheme() sub-themes (inputs/sliders/pickers/sheets), and the hand-built BqSegmented pill control — all token-only (D-07), all test-locked.

## What was built

- **tokens.dart**: 8 new `BqColors` (cardBorder 0x1717171B, inputBorder 0x2417171B, scrim 0x5217171B, dragHandle 0x2917171B, accentBorder 0x664A4E7C, riskBorder 0x4DA8443C, textDisabled 0xFFB9B9C0, iconDisabled 0xFFD8D7D1) + 3 new `BqRadii` (input 11, segInner 8, sheet 26), each with a doc comment citing its mockup line — values verbatim from the 02-UI-SPEC Token Additions table, the only new literals this plan introduces.
- **theme.dart**: `bqTheme()` extended with `inputDecorationTheme` (surface fill, BqRadii.input radius, 1px inputBorder side, accent focused side, textMuted hint, 13/14 EdgeInsetsDirectional content padding), `sliderTheme` (accent track+thumb, field inactive), `datePickerTheme`/`timePickerTheme` (surface backgrounds, accent header/dial), `bottomSheetTheme` (paper bg, scrim barrier, 26px top corners). Zero raw hex in theme.dart (`grep -v '^ *//' | grep -c '0xFF'` = 0).
- **lib/core/widgets/bq_segmented.dart** (new directory): stateless `BqSegmented({labels, selectedIndex, onChanged})` supporting 2+ segments. Container fill BqColors.cardBorder at BqRadii.seg with 2px padding; each segment an Expanded opaque GestureDetector with 9px vertical padding, active segment surface/ink pill at BqRadii.segInner, inactive transparent/textSecondary, 13.5/w500 labels inheriting Instrument Sans from the theme, no fixed widths. Each segment wrapped in `MergeSemantics > Semantics(selected, button, label)`.

## How verified

- TDD for Task 1: RED commit with 8 new failing assertion groups (`1e1f372`), then GREEN (`4eef4dc`). Theme suite: 25 tests (17 pre-existing untouched + 8 new) green.
- Widget test (`b917443`): tap on "Разовий курс" fires `onChanged(1)`; `isSemantics(isSelected:, isButton:)` flags swap when the parent moves `selectedIndex`; two long uk labels at a 390-width surface throw no overflow exception.
- Full `flutter test`: **90/90 green** (worktree baseline was 79 before this plan; all pre-existing tests remain green, +11 new). `flutter analyze`: **0 issues**.
- Grep gates: `grep -rn 'Color(0x' lib/core/widgets/` → empty; file contains `Semantics` and `BqRadii.segInner`.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Deprecation] `containsSemantics` → `isSemantics` in the widget test**
- **Found during:** Task 2 (`flutter analyze` reported 4 `deprecated_member_use` infos)
- **Issue:** `containsSemantics` was deprecated after Flutter 3.40; analyzer would not be clean
- **Fix:** migrated to the drop-in `isSemantics` matcher (same nullable-param, checks-only-specified semantics)
- **Files modified:** test/widget/bq_segmented_test.dart
- **Commit:** b917443

No other deviations — plan executed as written.

## Observations

- The suite baseline in this worktree was 79 tests, not the 82 stated in the execution context (possibly counts from a sibling wave plan). All 79 stayed green.
- Flutter 3.47 normalizes `ThemeData.inputDecorationTheme` to `InputDecorationThemeData`; the theme uses the new type directly (no deprecation surface).

## Self-Check: PASSED

- FOUND: lib/core/theme/tokens.dart (11 new constants)
- FOUND: lib/core/theme/theme.dart (5 sub-themes)
- FOUND: lib/core/widgets/bq_segmented.dart
- FOUND: test/widget/bq_segmented_test.dart
- FOUND commits: 1e1f372, 4eef4dc, b917443
