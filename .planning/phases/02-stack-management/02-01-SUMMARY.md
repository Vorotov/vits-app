---
phase: 02-stack-management
plan: 01
subsystem: stack-ui, persistence
status: complete
tags: [tracer, drift, riverpod, soft-delete, pause-filter, i18n]
requirements: [STACK-02, STACK-04, REGI-04]
dependency-graph:
  requires:
    - phase 01 foundation (stackEntriesProvider, supplementRepoProvider, Drift schema, gen-l10n, bqTheme)
  provides:
    - "showAddSupplementSheet() + manual add form (STACK-02 tracer path)"
    - "SupplementRepository.softDeleteCascade contract + Drift transaction impl (STACK-04)"
    - "watchDay deletedAt + pause filters (REGI-04, PF-1 — consumed by Phase 3)"
  affects:
    - plans 02-02..02-05 (expand the proven UI->provider->repo->Drift skeleton)
tech-stack:
  added: []
  patterns:
    - "Widget test with real in-memory Drift DB: dbProvider override + pumpUntilFound polling + in-body teardown pumps to flush Drift stream-close timers"
    - "Cascade soft delete as one db.transaction with a single captured now"
    - "Pause as pure query filter: paused==false OR status != pending"
key-files:
  created:
    - lib/features/stack/add_supplement_sheet.dart
    - test/features/stack_screen_test.dart
    - test/db/cascade_delete_test.dart
    - test/db/pause_filter_test.dart
  modified:
    - lib/features/stack/stack_screen.dart (stub -> ConsumerWidget card list + CTA)
    - lib/core/domain/repositories.dart (softDeleteCascade contract)
    - lib/core/db/drift_repositories.dart (cascade impl + watchDay filters)
    - lib/core/l10n/arb/app_en.arb, app_uk.arb (+6 keys), lib/core/l10n/gen/ (regenerated)
    - test/smoke_test.dart, test/widget/app_shell_test.dart (adapted to tracer)
decisions:
  - "Drag handle uses BqColors.field instead of the not-yet-added dragHandle token (token additions land with the full styling plan; no hex literal allowed in features/)"
  - "Widget tests pump a SizedBox at test end to flush Drift's zero-duration stream-close timers (flutter_test pending-timer check)"
metrics:
  duration: ~10 min
  completed: 2026-08-15
actuals:
  tokens: 9000
  tasks: 2
  commits: 3
---

# Phase 2 Plan 01: Tracer + Repo Delta Summary

Manual add-supplement flows sheet -> supplementRepoProvider -> real Drift DB -> stackEntriesProvider -> stack card, plus softDeleteCascade transaction and watchDay deletedAt/pause filters with regression tests.

## What Was Built

- **StackScreen (rewrite):** `ConsumerWidget` on `stackEntriesProvider` — heading (`stackTitle`), full-width accent CTA opening the add sheet, minimal cards (4px color bar at .85 opacity, name 15/w600, dose 12.5 muted), 9px gaps, 84px bottom padding. Loading renders header+CTA with no spinner (UI truth #2); error renders `SizedBox.shrink()` (documented `stackLoadError` surface arrives in 02-05).
- **add_supplement_sheet.dart (new):** `showAddSupplementSheet()` -> `showModalBottomSheet(isScrollControlled: true)`; drag handle, header (title + accent "Закрити"), name/dose fields (`textCapitalization: sentences`), save CTA disabled while `name.trim().isEmpty` (V-1 — disabled state is the whole validation surface). Keyboard inset via `EdgeInsetsDirectional.only(bottom: MediaQuery.viewInsetsOf(context).bottom)` + scrollable body (PF-6). On save: `const Uuid().v4()` at the save boundary, round-robin `BqSeriesColors.palette[count % 8]`, `upsert`, pop.
- **softDeleteCascade:** contract on `SupplementRepository` (pure Dart, `fromDay` passed by caller); Drift impl as one `db.transaction` with a single captured `now` stamping supplement -> active regimens -> their active slots -> intakeLogs where `regimenId IN ids AND date >= fromDay AND status == pending AND deletedAt IS NULL`. History and past pending rows never touched.
- **watchDay filters:** added `intakeLogs.deletedAt IS NULL` and the pause filter `(paused == false OR status != pending)` — taken/skipped history stays visible while paused; pause mutates zero log rows (PF-1).
- **i18n:** 6 new ARB keys in both locales (`stackTitle`, `addSupplement`, `close`, `nameLabel`, `doseLabel`, `addManualSupplement`), gen output regenerated and committed.

## How Verified

- `flutter test test/features/stack_screen_test.dart` — tracer widget test in uk locale against a real in-memory Drift DB: CTA opens sheet, save disabled for empty and whitespace-only names, save persists and the card appears from the DB stream, sheet closes, no exceptions.
- `flutter test test/db/cascade_delete_test.dart test/db/pause_filter_test.dart` — E-2 (history kept, future pending stamped, all parents stamped with bumped updatedAt, fromDay scoping) and E-1/PF-1 (pause hides only pending via query filter with raw zero-stamp assertion; resume restores statuses; `ensureLogsForDay` after resume is lossless; watchDay excludes soft-deleted rows).
- Full suite: **84 tests green** (was 79 at baseline; +1 widget, +4 repo tests). `flutter analyze`: 0 issues.
- Grep gates: no `Color(0x` in `lib/features/stack/`; no non-comment `.delete(` in drift_repositories.dart; repositories.dart imports only `models.dart`.

## TDD Gate Compliance

- RED: `b183479` (`test(02-01)…`) — cascade tests failed to compile (API absent), pause tests failed behaviorally (filters absent).
- GREEN: `60f5941` (`feat(02-01)…`) — all 4 new tests pass.
- REFACTOR: not needed.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Drift stream-close timers fail flutter_test's pending-timer check**
- **Found during:** Task 1 (widget test)
- **Issue:** Disposing the ProviderScope at test end schedules Drift `StreamQueryStore.markAsClosed` zero-duration timers that flutter_test flags as pending.
- **Fix:** Tests pump `SizedBox` + two timed pumps inside the test body before completion.
- **Files:** test/features/stack_screen_test.dart, test/smoke_test.dart, test/widget/app_shell_test.dart
- **Commits:** a69d7ec, 60f5941

**2. [Rule 1 - Bug] Pre-existing smoke/app-shell tests broke as a direct consequence of the tracer**
- **Found during:** Task 2 full-suite run
- **Issue:** StackScreen now watches `dbProvider` (tests pumping the real app hit the on-disk DB path / pending timers) and its heading changed from `tabStack` to `stackTitle` (finder counts wrong).
- **Fix:** Both tests now override `dbProvider` with an in-memory DB (D-19) and assert the new heading (`My stack` / `Мій стек`) separately from tab labels.
- **Files:** test/smoke_test.dart, test/widget/app_shell_test.dart
- **Commit:** 60f5941

### Minor implementation deviations

- **Drag handle color:** used existing `BqColors.field` instead of the UI-SPEC `dragHandle` token — token additions to `tokens.dart` are owned by a later Phase-2 plan and feature code may not carry hex literals. Cosmetic; refine in 02-05.
- **`Override` type not nameable:** flutter_riverpod 3.4 does not export an `Override` type usable as an annotation-free type argument; the shell-test helper wraps `ProviderScope` construction instead of returning a typed override list.
- **Baseline count:** the orchestrator prompt cited 82 pre-existing tests; the actual baseline in this worktree was 79 (all green before and after adaptation).

## Known Stubs

| Stub | File | Reason / resolving plan |
|------|------|-------------------------|
| Error branch renders `SizedBox.shrink()` | lib/features/stack/stack_screen.dart | Plan-specified: `stackLoadError` + retry surface is owned by plan 02-05 |
| Cards omit hairline border, chips, status, schedule summary, empty state | lib/features/stack/stack_screen.dart | Plan-specified: full card anatomy owned by plan 02-05 |

## Threat Flags

None — the cascade and pause paths are exactly the surfaces covered by the plan's threat model (T-02-01/T-02-02 mitigations regression-locked by the two new test files; T-02-03 accepted: all writes go through parameterized Drift companions).

## Commits

| Commit | Message |
|--------|---------|
| a69d7ec | feat(02-01): tracer — manual add supplement flows sheet -> repo -> Drift -> stack card |
| b183479 | test(02-01): add failing tests for softDeleteCascade and watchDay pause/deletedAt filters |
| 60f5941 | feat(02-01): implement softDeleteCascade transaction + watchDay deletedAt/pause filters |

## Self-Check: PASSED

- lib/features/stack/add_supplement_sheet.dart — FOUND
- test/db/cascade_delete_test.dart, test/db/pause_filter_test.dart, test/features/stack_screen_test.dart — FOUND
- Commits a69d7ec, b183479, 60f5941 — FOUND in git log
- `flutter analyze` 0 issues; `flutter test` 84/84 green
