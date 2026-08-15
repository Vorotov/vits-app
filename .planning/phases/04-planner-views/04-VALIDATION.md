---
phase: 4
slug: planner-views
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-08-16
---

# Phase 4 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | flutter_test (SDK) + mocktail 1.0.5; integration_test (SDK) for the on-device loop |
| **Config file** | none needed — established Phases 1-3 |
| **Quick run command** | `flutter test <changed test file>` |
| **Full suite command** | `flutter analyze && flutter test` |
| **Estimated runtime** | ~50 seconds full suite (290 tests at phase start) |

---

## Sampling Rate

- **After every task commit:** Run `flutter test <task's test file>`
- **After every plan wave:** Run `flutter analyze && flutter test`
- **Before `/gsd-verify-work`:** Full suite green
- **Max feedback latency:** ~60 seconds

---

## Per-Task Verification Map

*(Filled by gsd-planner. Per 04-RESEARCH.md ## Validation Architecture: the planner is a pure projection of `isActiveOn` — its view-model gets unit tests over pinned windows including leap years and year boundaries; the zero-write invariant gets a row-count regression test (`test/providers_planner_test.dart`) proving no IntakeLog rows are created by opening either planner screen; rendering gets widget tests including text-scale coverage per the CR-01/WR-04 lessons; PLAN-04 disclaimer presence gets a per-screen assertion.)*

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| — | — | — | PLAN-01..04 | — | N/A (offline, read-only projections, zero writes) | unit/widget | `flutter test` | ✅ infra exists | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

Existing infrastructure covers all phase requirements — flutter_test + mocktail green at 290/290 since Phase 3. No Wave 0 setup needed.

---

## Manual-Only Verifications

- Visual fidelity of the Cycles gantt, load chart and Year matrix vs mockup screens 03/04 (uk locale, real device)
- The DATA-03 on-device loop test (`flutter test integration_test/data03_loop_test.dart -d <device>`) must still pass on both platforms after this phase — planner screens must not regress the core loop
