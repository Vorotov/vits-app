---
phase: 5
slug: localization-settings
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-08-16
---

# Phase 5 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | flutter_test (SDK) + mocktail 1.0.5; integration_test (SDK) for the on-device loop |
| **Config file** | none needed — established Phases 1-4 |
| **Quick run command** | `flutter test <changed test file>` |
| **Full suite command** | `flutter analyze && flutter test` |
| **Estimated runtime** | ~60 seconds full suite (547 tests at phase start) |

---

## Sampling Rate

- **After every task commit:** Run `flutter test <task's test file>`
- **After every plan wave:** Run `flutter analyze && flutter test`
- **Before `/gsd-verify-work`:** Full suite green
- **Max feedback latency:** ~60 seconds

---

## Per-Task Verification Map

*(Filled by gsd-planner. Per 05-RESEARCH.md ## Validation Architecture: L10N-01 and zero-hardcoded-strings are already satisfied and must be REGRESSION-GATED, not re-implemented; the real work is criterion 4 — a synthetic third locale must resolve with zero code edits, proven by a test that exercises it; the bilingual render matrix must cover every screen in BOTH locales, closing the measured gap (stack/regimen-editor/app-shell currently have zero English render coverage); instant switching and persistence get widget + prefs round-trip tests; the Riverpod auto-retry error-surface defect gets a test asserting the error surface appears immediately rather than after backoff.)*

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| — | — | — | L10N-01..04 | — | N/A (offline; only new persisted value is the language override) | unit/widget | `flutter test` | ✅ infra exists | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

Existing infrastructure covers all phase requirements — flutter_test + mocktail green at 547/547 since Phase 4. No Wave 0 setup needed.

---

## Manual-Only Verifications

- Language override on a real device: switch uk↔en in Settings, confirm every open screen (including a pushed editor and an open bottom sheet) updates instantly, then force-quit and relaunch to confirm persistence
- System-language detection on a fresh install with the device set to uk, en, and a third language (English fallback)
- `flutter test integration_test/data03_loop_test.dart -d <device>` must still pass on BOTH platforms after this phase (final v1 regression gate)
