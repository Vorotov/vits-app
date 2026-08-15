---
phase: 02-stack-management
plan: 04
subsystem: stack
tags: [flutter, riverpod, l10n, widget-tests, regimen-editor]
requires:
  - 02-01 (softDeleteCascade, repositories, in-memory test harness)
  - 02-02 (BqSegmented, plan-02-02 theme tokens)
  - 02-03 (RegimenEditorController + regimenEditorProvider, stack_status helpers)
provides:
  - RegimenEditorScreen (mockup screen 05 / UI-SPEC S3) — full editor surface incl. pinned footer with save, pause/resume, confirmed delete
  - editor ARB key set (~38 keys total across both tasks) in en + uk incl. slotsPerDay 4-form uk plural
affects:
  - 02-05 (navigation into RegimenEditorScreen from cards/sheet)
tech-stack:
  added: []
  patterns:
    - "Thin view over tested controller: screen mutates RegimenDraft only, zero business logic"
    - "Preview strip derives from isActiveOn on a throwaway draft Regimen (P-9 single source of cycle truth)"
    - "24h time on both picker and display via MediaQuery alwaysUse24HourFormat builder + formatTimeOfDay"
    - "Pump-driven Drift stream assertions in widget tests (never await .first under FakeAsync)"
key-files:
  created:
    - lib/features/stack/regimen_editor_screen.dart
    - test/features/regimen_editor_test.dart
  modified:
    - lib/core/l10n/arb/app_en.arb
    - lib/core/l10n/arb/app_uk.arb
    - lib/core/l10n/gen/ (regenerated, committed)
    - test/l10n/plurals_test.dart
decisions:
  - "saveHintActive carries a {start} date placeholder (locale MMMMd) matching the mockup's dynamic date, instead of a static sentence"
  - "Editor top-bar title is Expanded (ellipsis under extreme constraint) so the НА ПАУЗІ badge can never overflow the Row — no fixed-width text container"
  - "Delete cascade call lives solely inside the dialog's confirm-button handler; the footer delete button's only direct effect is showDialog (UI-SPEC #19, T-02-04)"
metrics:
  duration: ~2h across two executor sessions
  completed: 2026-08-15
status: complete
actuals:
  tokens: 18747
  tasks: 2
  commits: 2
requirements: [REGI-01, REGI-02, REGI-03, REGI-04, STACK-04]
---

# Phase 2 Plan 04: Regimen Editor Screen Summary

Regimen editor (mockup screen 05) built as a thin view over the tested wave-2 controller: periodicity toggle, locale-aware date/time pickers, 7-day-step sliders, live 28-bar isActiveOn preview, 1-6 slot editor, and a pinned footer with save, pause/resume, and dialog-confirmed cascade delete — all copy from ARB keys in both locales, widget-tested against a real in-memory Drift DB in uk locale.

> **Continuation note:** Task 1 was executed by a prior agent (commit e7519e2) which died at the start of Task 2; its partial Task-2 edit was reset before this session. This session executed Task 2 only, on the verified Task-1 baseline.

## Tasks

| Task | Name | Commit |
| ---- | ---- | ------ |
| 1 | Editor screen structure — top bar, periodicity panel, pickers, sliders, preview strip, slots editor | e7519e2 (prior agent) |
| 2 | Pinned footer — save, pause/resume, confirmed delete + action widget tests | 25ed555 |

## What was built

- **Task 1 (prior agent):** `RegimenEditorScreen(supplementId)` watching `regimenEditorProvider`; S3 layout — top bar with НА ПАУЗІ badge, read-only supplement header (PF-5), `BqSegmented` cyclic/course toggle, surface panel with `_DateField`s (dateOnly at picker receipt, course end `firstDate: startDate`) and `_SliderRow`s (7–112/15, 0–84/12), `_CyclePreviewStrip` (exactly 28 bars via `isActiveOn`, 4-day sampling), `_SlotRow` list (24h both sides, inline dose-label input, disabled-not-hidden minus at floor), `_AddSlotButton` with `_DashedBorderPainter` (disabled at cap), neutral interval note. 28 structure ARB keys incl. `slotsPerDay` with all four uk CLDR forms; plurals test extended at 1/2/5/11/21.
- **Task 2 (this session):** `_EditorFooter` — pinned via `bottomNavigationBar` (surfaceAlt, hairline top border, 12/20 padding): accent save button (radius 13 mockup-exact, 15/w600, label flips `saveAndStart`/`saveWhilePaused`, awaits `controller.save()` then pops); pause/resume secondary + delete destructive outlined buttons (Interaction Contract 7 pressed overlays); centered save hint flipping `saveHintActive({start})`/`saveHintPaused`. Delete opens the REQUIRED `AlertDialog` (`deleteConfirmTitle`/`deleteConfirmBody`); cancel/dismiss changes nothing; the cascade call appears solely in the confirm handler, then pops to Stack. 10 new ARB keys in both locales, gen output regenerated and committed.

## Verification

- `flutter test test/features/regimen_editor_test.dart` — 8/8 green (4 structure + 4 action tests: course save persistence with inclusive endDate, cyclic save of onDays/offDays/slot times, four-pause-signals-as-one-state, delete dialog cancel/confirm-cascade + route pop; `takeException` null in uk throughout)
- Full `flutter test` — 134/134 green (Task-1 baseline intact)
- `flutter analyze` — 0 issues
- `grep 'Color(0x'` on the screen file — empty (token-only styling)
- Both ARB files carry the full Task-1 + Task-2 key sets; uk `slotsPerDay` has one/few/many/other

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Top-bar Row overflow when the paused badge appears**
- **Found during:** Task 2 (four-pause-signals widget test: RenderFlex overflowed 9.8px at 390pt)
- **Issue:** Task 1's top bar laid out `title + Spacer + badge` with a rigid title, so title + badge intrinsic widths could exceed the bar width
- **Fix:** Title wrapped in `Expanded` (single line, ellipsis only under extreme constraint) — badge keeps intrinsic size; honors the "no fixed-width text containers" i18n rule
- **Files modified:** lib/features/stack/regimen_editor_screen.dart
- **Commit:** 25ed555

**2. [Rule 1 - Bug] Widget-test deadlocks awaiting Drift stream futures under FakeAsync**
- **Found during:** Task 2 (delete test hit the 10-minute per-test timeout twice)
- **Issue:** `await watchAll().first` (and awaiting `StreamSubscription.cancel()` in `addTearDown`) never resolves inside flutter_test's fake-async zone — Drift emits via zero-duration timers that only fire when the tester pumps
- **Fix:** Pump-driven pattern — listen into a local variable, assert after pumps; cancel the subscription `unawaited` followed by a pump inside the test body
- **Files modified:** test/features/regimen_editor_test.dart
- **Commit:** 25ed555

No scope deviations — all plan functionality shipped as specified.

## Known Stubs

None. The Task-1 footer placeholder was fully replaced in Task 2; no TODO/FIXME/placeholder copy or unwired data paths remain in the plan's files.

## Notes for later plans

- Navigation into this screen (card tap / sheet push) is owned by plan 02-05, which should push `RegimenEditorScreen(supplementId:)` as a route (save and confirmed delete both `maybePop`).
- Backstop #16 (uk footer labels on one line at 390pt in a real font on a simulator) remains a phase-sign-off visual check — widget tests use the Ahem font, so they over-approximate text widths; the layout passed even under Ahem for the footer buttons.
- Broken-windows ledger (`gsd-tools windows append`) not written: the gsd-tools CLI is unavailable in this worktree execution context and there are no open defects to record.

## Self-Check: PASSED

- FOUND: lib/features/stack/regimen_editor_screen.dart
- FOUND: test/features/regimen_editor_test.dart
- FOUND: commit e7519e2 (Task 1)
- FOUND: commit 25ed555 (Task 2)
