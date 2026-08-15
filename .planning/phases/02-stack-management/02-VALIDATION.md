---
phase: 2
slug: stack-management
# status lifecycle: draft (seeded by plan-phase) → validated (set by validate-phase §6)
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-08-14
---

# Phase 2 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | flutter_test (SDK) + mocktail 1.0.5 |
| **Config file** | none needed — pubspec.yaml already wires flutter_test/mocktail (Phase 1) |
| **Quick run command** | `flutter test <changed test file>` |
| **Full suite command** | `flutter analyze && flutter test` |
| **Estimated runtime** | ~40 seconds full suite |

---

## Sampling Rate

- **After every task commit:** Run `flutter test <task's test file>`
- **After every plan wave:** Run `flutter analyze && flutter test`
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** ~60 seconds

---

## Per-Task Verification Map

*(Filled by gsd-planner when plans are written; per 02-RESEARCH.md ## Validation Architecture: repo-delta behaviors — cascade soft-delete stamps regimen + future pending logs only, pause filter excludes paused-pending from watchDay, resume re-materializes — get Drift in-memory DB tests; editor validation rules V-1 get widget/unit tests; catalog search gets locale-aware match unit tests.)*

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 02-01/T1 | 02-01 | 1 | STACK-02 | T-02-03 | free text via Drift parameterized companions only | widget (tracer e2e) | `flutter test test/features/stack_screen_test.dart` | ⬜ Wave 0 (created by task) | ⬜ pending |
| 02-01/T2 | 02-01 | 1 | STACK-04, REGI-04 | T-02-01, T-02-02 | cascade stamps only pending ≥ fromDay; pause = query filter, zero row stamps | unit (in-memory Drift) | `flutter test test/db/cascade_delete_test.dart test/db/pause_filter_test.dart` | ⬜ Wave 0 (created by task) | ⬜ pending |
| 02-02/T1 | 02-02 | 1 | STACK-03 | — | — | unit (exact-value tokens/theme) | `flutter test test/theme/theme_test.dart` | ✅ extend existing | ⬜ pending |
| 02-02/T2 | 02-02 | 1 | STACK-01, REGI-01 | — | — | widget | `flutter test test/widget/bq_segmented_test.dart` | ⬜ Wave 0 (created by task) | ⬜ pending |
| 02-03/T1 | 02-03 | 2 | REGI-01..04 | T-02-05 | PF-8 double-save keeps exactly one regimen row | unit (controller) | `flutter test test/features/regimen_editor_controller_test.dart` | ⬜ Wave 0 (created by task) | ⬜ pending |
| 02-03/T2 | 02-03 | 2 | STACK-03 | — | statusOf never reads the clock | unit (pure fn matrix) | `flutter test test/features/stack_status_test.dart` | ⬜ Wave 0 (created by task) | ⬜ pending |
| 02-04/T1 | 02-04 | 3 | REGI-01, REGI-02, REGI-03 | — | invalid regimens unrepresentable (clamps, firstDate) | widget + plural unit | `flutter test test/features/regimen_editor_test.dart test/l10n/plurals_test.dart` | ⬜ Wave 0 (created by task) | ⬜ pending |
| 02-04/T2 | 02-04 | 3 | REGI-04, STACK-04 | T-02-04 | delete only via confirm dialog; cancel changes nothing | widget | `flutter test test/features/regimen_editor_test.dart` | ⬜ Wave 0 (same file) | ⬜ pending |
| 02-05/T1 | 02-05 | 4 | STACK-01 | T-02-07 | liability words absent from catalog ARB values | unit (cross-locale search) | `flutter test test/features/catalog_search_test.dart` | ⬜ Wave 0 (created by task) | ⬜ pending |
| 02-05/T2 | 02-05 | 4 | STACK-03, REGI-04 | T-02-08 | error state renders ARB copy only, no exception text | widget + plural unit | `flutter test test/features/stack_screen_test.dart test/l10n/plurals_test.dart` | ✅ extend 02-01 file | ⬜ pending |
| 02-05/T3 | 02-05 | 4 | STACK-01, STACK-02 | — | no camera/scanning path ships (PF-5/D1/D3) | widget | `flutter test test/features/stack_screen_test.dart` | ✅ extend 02-01 file | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

Existing infrastructure covers all phase requirements — flutter_test + mocktail installed and green (82/82) since Phase 1. No Wave 0 setup needed.

---

## Manual-Only Verifications

- Visual fidelity of Stack screen + editors vs mockup screens (simulator, uk locale)
- Date/time picker localization rendering (uk month/day names)
