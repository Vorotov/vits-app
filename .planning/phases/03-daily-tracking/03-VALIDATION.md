---
phase: 3
slug: daily-tracking
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-08-15
---

# Phase 3 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | flutter_test (SDK) + mocktail 1.0.5 |
| **Config file** | none needed — established Phase 1/2 |
| **Quick run command** | `flutter test <changed test file>` |
| **Full suite command** | `flutter analyze && flutter test` |
| **Estimated runtime** | ~45 seconds full suite (162 tests at phase start) |

---

## Sampling Rate

- **After every task commit:** Run `flutter test <task's test file>`
- **After every plan wave:** Run `flutter analyze && flutter test`
- **Before `/gsd-verify-work`:** Full suite green
- **Max feedback latency:** ~60 seconds

---

## Per-Task Verification Map

*(Filled by gsd-planner. Per 03-RESEARCH.md ## Validation Architecture: the materialization choke point (dayDosesProvider) gets in-memory Drift provider tests; midnight rollover + DST anchors get pinned-date unit tests; mark/undo gets widget tests asserting DB round-trip; missed-styling gets a raw-row assertion that the DB stays pending; DATA-03 both-platform run is a human checkpoint.)*

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| — | — | — | TRACK-01..04, DATA-03 | — | N/A (offline, local-only) | unit/widget | `flutter test` | ✅ infra exists | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

Existing infrastructure covers all phase requirements — flutter_test + mocktail green at 162/162 since Phase 2. No Wave 0 setup needed.

---

## Manual-Only Verifications

- DATA-03: full plan→see→mark loop on an iOS simulator AND an Android emulator (targetSdk 36)
- Visual fidelity of the Today/Calendar screen vs mockup (uk locale), including the progress ring
- Midnight rollover observed live (or via device clock change)
