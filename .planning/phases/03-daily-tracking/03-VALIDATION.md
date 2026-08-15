---
phase: 3
slug: daily-tracking
status: ready
nyquist_compliant: true
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

Filled from the 5 committed plans (14 tasks). Per 03-RESEARCH.md ## Validation Architecture: the materialization choke point gets provider tests over a real in-memory Drift DB; midnight/DST math gets pinned-date unit tests; mark/undo gets widget tests asserting the DB round-trip; missed-derivation gets a raw-row assertion; DATA-03 is a human checkpoint paired with real build gates.

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 03-01/T1 | 03-01 | 1 | TRACK-01, TRACK-02 | T-03-01 | status writes go through the repository only; tracer proves persistence | widget (tracer e2e) | `flutter test test/features/calendar_screen_test.dart` | ⬜ created by task | ⬜ pending |
| 03-01/T2 | 03-01 | 1 | TRACK-01, TRACK-04 | T-03-02 | materialization idempotent; paused doses filtered at query level | unit (providers + in-memory Drift) | `flutter test test/features/today_provider_test.dart test/providers_calendar_test.dart` | ⬜ created by task | ⬜ pending |
| 03-01/T3 | 03-01 | 1 | TRACK-01 | — | single clock source; no per-widget now() | widget | `flutter test test/features/stack_screen_test.dart` | ✅ extend existing | ⬜ pending |
| 03-02/T1 | 03-02 | 1 | TRACK-01, TRACK-03 | — | pure helpers never touch repositories or the clock | unit (pure fn matrix) | `flutter test test/features/day_view_model_test.dart` | ⬜ created by task | ⬜ pending |
| 03-02/T2 | 03-02 | 1 | TRACK-04 | T-03-03 | DST/year-boundary correctness over the real repository chain | unit (in-memory Drift, pinned dates) | `flutter test test/db/materialization_boundaries_test.dart test/features/day_view_model_test.dart` | ⬜ created by task | ⬜ pending |
| 03-03/T1 | 03-03 | 2 | TRACK-01 | — | ARB parity; no untranslated messages | unit (plurals + tokens) | `flutter gen-l10n && flutter test test/l10n/plurals_test.dart test/theme/theme_test.dart` | ✅ extend existing | ⬜ pending |
| 03-03/T2 | 03-03 | 2 | TRACK-01 | — | — | widget | `flutter test test/features/calendar_screen_test.dart` | ✅ extend 03-01 file | ⬜ pending |
| 03-03/T3 | 03-03 | 2 | TRACK-01 | — | — | widget | `flutter test test/features/calendar_screen_test.dart` | ✅ extend 03-01 file | ⬜ pending |
| 03-04/T1 | 03-04 | 3 | TRACK-01 | — | ticker is the only second clock read, minute-of-day only | widget | `flutter test test/features/calendar_screen_test.dart` | ✅ extend | ⬜ pending |
| 03-04/T2 | 03-04 | 3 | TRACK-01, TRACK-02 | T-03-01, T-03-04 | single guarded setStatus site; double-tap deterministic | widget | `flutter test test/features/calendar_screen_test.dart` | ✅ extend | ⬜ pending |
| 03-04/T3 | 03-04 | 3 | TRACK-02 | T-03-04 | action sheet returns a status, never writes | widget | `flutter test test/features/calendar_screen_test.dart` | ✅ extend | ⬜ pending |
| 03-05/T1 | 03-05 | 4 | TRACK-03 | — | pager bounded (52 weeks back, capped at current week) | widget | `flutter test test/features/calendar_screen_test.dart` | ✅ extend | ⬜ pending |
| 03-05/T2 | 03-05 | 4 | TRACK-03 | T-03-05 | missed is view-computed; raw IntakeLog rows stay pending | widget + raw-row unit | `flutter test test/features/calendar_screen_test.dart` | ✅ extend | ⬜ pending |
| 03-05/T3 | 03-05 | 4 | DATA-03 | — | both-platform build integrity | human check + build gates | `flutter analyze && flutter test && flutter build apk --debug && flutter build ios --simulator --no-codesign` | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

Existing infrastructure covers all phase requirements — flutter_test + mocktail green at 162/162 since Phase 2. No Wave 0 setup needed.

---

## Manual-Only Verifications

- DATA-03: full plan→see→mark loop on an iOS simulator AND an Android emulator (targetSdk 36)
- Visual fidelity of the Today/Calendar screen vs mockup (uk locale), including the progress ring
- Midnight rollover observed live (or via device clock change)
