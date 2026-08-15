---
phase: 02-stack-management
plan: 03
subsystem: stack-feature-logic
tags: [riverpod, notifier-family, tdd, pure-functions, pf-8]
requires:
  - 02-01 (softDeleteCascade on SupplementRepository; stackEntriesProvider warm graph)
provides:
  - RegimenDraft + DraftSlot + RegimenEditorController + regimenEditorProvider (autoDispose.family by supplementId)
  - StackStatus enum (fresh/active/paused/planned/finished) + statusOf + scheduleSummaryOf
affects:
  - 02-04 (editor screen consumes regimenEditorProvider as a thin view)
  - 02-05 (stack cards render statusOf/scheduleSummaryOf output)
tech-stack:
  added: []
  patterns:
    - "Riverpod 3 constructor-arg family Notifier (P-5): NotifierProvider.autoDispose.family with supplementId through the constructor"
    - "Synchronous seeding from a warm Provider<AsyncValue> snapshot via ref.read + AsyncData pattern-match (UI-SPEC #17)"
    - "Sealed class summary hierarchy for exhaustive widget switches (Dart 3)"
key-files:
  created:
    - lib/features/stack/regimen_editor_controller.dart
    - lib/features/stack/stack_status.dart
    - test/features/regimen_editor_controller_test.dart
    - test/features/stack_status_test.dart
  modified: []
decisions:
  - "PF-8 id resolution order in save(): draft.regimenId -> save-time findForSupplement re-check -> mint UUID; resolved regimen id AND minted slot ids written back into the draft so every later save reuses them"
  - "togglePause flips the draft only; persistence happens on save() — matches the mockup's 'Зберегти, цикл на паузі' CTA (documented in the library doc comment)"
  - "NotifierProvider.autoDispose.family compiled and behaved correctly on flutter_riverpod 3.4.2 — the A3 plain-.family fallback was NOT needed"
  - "nextSlotDefaults stored as minutes-from-midnight ints [480,780,1140,1320,630,960] with fallback 1260 (21:00); the fallback is unreachable via the public API (pigeonhole: <=5 slots can't exhaust 6 defaults) but kept for mockup parity"
metrics:
  duration: ~25 min
  completed: 2026-08-15
status: complete
actuals:
  tokens: 9400
  tasks: 2
  commits: 4
---

# Phase 2 Plan 03: RegimenDraft/RegimenEditorController + status helpers Summary

Regimen editor draft state machine (Riverpod 3 autoDispose.family Notifier with PF-8 id reuse, slot clamping, date normalization) plus pure clock-free statusOf/scheduleSummaryOf helpers — all locked by 29 new unit tests before any UI exists.

## What was built

### Task 1 — `lib/features/stack/regimen_editor_controller.dart`
- `DraftSlot` (nullable id carried across saves) and immutable `RegimenDraft` with sentinel-based `copyWith` for nullable fields (regimenId, endDate).
- `RegimenEditorController extends Notifier<RegimenDraft>` taking `supplementId` through its constructor (P-5 — FamilyNotifier is gone in Riverpod 3); `regimenEditorProvider = NotifierProvider.autoDispose.family<RegimenEditorController, RegimenDraft, String>` (D-23 screen-scoped autoDispose).
- `build()` seeds synchronously: pattern-matches `ref.read(stackEntriesProvider)` for `AsyncData`, maps an existing regimen (regimenId + slot ids carried) or returns defaults (cyclic 56/28, 1 slot at 08:00 with empty label, `startDate = dateOnly(DateTime.now())` — feature-layer clock read, normalized).
- Mutators: `setKind` (course seeds endDate = start + 27 days), `setStartDate` (clamps endDate up), `setEndDate`, `setOnDays`/`setOffDays`, `addSlot` (NEXT_SLOT walk skipping used times, cap 6), `removeSlot` (floor 1), `setSlotTime` (re-sorts), `setSlotDoseLabel`, `togglePause` (draft-only).
- `save()`: PF-8 three-step id resolution, cyclic saves null endDate, slots map to `DoseSlot` reusing surviving ids / minting UUIDs only for new ones, then writes resolved ids back into state. `deleteSupplement()` delegates to `softDeleteCascade(supplementId, fromDay: dateOnly(now))`.
- Zero Drift imports (D-22 verified by grep); no Flutter widget imports.

### Task 2 — `lib/features/stack/stack_status.dart`
- `enum StackStatus { fresh, active, paused, planned, finished }`.
- `statusOf(StackEntry, DateTime today)` — precedence fresh → paused (before any date logic) → planned → finished (course, inclusive end passed — E-4/D10) → active; every comparison through `dateOnly`; zero clock reads (grep-verified).
- Sealed `ScheduleSummary` hierarchy: `CyclicSummary(onDays, offDays, slotCount)` / `CourseSummary(start, end?, slotCount)` / `NoSummary`; paused regimens keep their summary (UI-SPEC S1). No strings, no Flutter imports — wave 4 maps to ARB keys.

## Verification

- `flutter test test/features/regimen_editor_controller_test.dart` — 14/14 green (incl. PF-8 double-save single-row proof via `regimenRepo.watchAll()` and the stale-draft `findForSupplement` re-check test for T-02-05)
- `flutter test test/features/stack_status_test.dart` — 15/15 green (full matrix incl. the three boundary cases: start==today active, end==today active, end+1 finished)
- Full `flutter test` — **124/124 green** (95 at base, none broken); `flutter analyze` — 0 issues
- Acceptance greps: `package:drift` in controller = 0; `NotifierProvider.autoDispose.family` + `findForSupplement` present; `DateTime.now` in stack_status.dart = 0; `package:flutter/` in stack_status.dart = 0

## TDD Gate Compliance

Both tasks followed RED → GREEN with commits in sequence: `test(02-03)` f931171 → `feat(02-03)` 4fabcda (Task 1); `test(02-03)` 8898c3e → `feat(02-03)` a91b7af (Task 2). Both RED runs failed for the intended reason (implementation file absent). No refactor commits needed.

## Commits

| Commit | Type | Description |
|--------|------|-------------|
| f931171 | test | failing tests for RegimenEditorController (seeding, clamping, PF-8, pause, delete) |
| 4fabcda | feat | RegimenDraft + RegimenEditorController family Notifier |
| 8898c3e | test | failing matrix tests for statusOf + scheduleSummaryOf |
| a91b7af | feat | statusOf + scheduleSummaryOf pure helpers |

## Deviations from Plan

None - plan executed exactly as written. (One doc-comment reword in stack_status.dart to keep the textual `DateTime.now` acceptance grep at 0 — no behavior involved.)

## Known Stubs

None. The `fallbackSlotMinutes` (21:00) branch in `addSlot` is unreachable through the public API (pigeonhole over 6 default times) — kept deliberately for mockup parity and documented in the decisions above; it is defensive, not a stub.

## Notes for waves 3-4

- Editor screens: watch `regimenEditorProvider(supplementId)`, call notifier methods only — zero business logic in widgets.
- Card renderer: `statusOf(entry, dateOnly(DateTime.now()))` — the widget layer owns the clock read; switch exhaustively over `ScheduleSummary` (sealed) for the schedule chip.
- `statusFinished` chip (ЗАВЕРШЕНО, planned styling) is the D10 invented treatment — confirm at UAT.

## Self-Check: PASSED

- FOUND: lib/features/stack/regimen_editor_controller.dart
- FOUND: lib/features/stack/stack_status.dart
- FOUND: test/features/regimen_editor_controller_test.dart
- FOUND: test/features/stack_status_test.dart
- FOUND: commits f931171, 4fabcda, 8898c3e, a91b7af
