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
| — | — | — | STACK-01..04, REGI-01..04 | — | N/A (offline, local-only) | unit/widget | `flutter test` | ✅ infra exists | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

Existing infrastructure covers all phase requirements — flutter_test + mocktail installed and green (82/82) since Phase 1. No Wave 0 setup needed.

---

## Manual-Only Verifications

- Visual fidelity of Stack screen + editors vs mockup screens (simulator, uk locale)
- Date/time picker localization rendering (uk month/day names)
