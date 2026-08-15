---
phase: 4
slug: planner-views
status: ready
nyquist_compliant: true
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

Filled from the 5 committed plans (14 tasks). Per 04-RESEARCH.md ## Validation Architecture: the planner is a pure projection of `isActiveOn` — window/segment/load/year math gets unit tests over pinned windows (leap year, year boundary, paused, soft-deleted); the zero-write invariant is gated at four layers (import grep, provider row-count, selection-tap row-count, full-render row-count); rendering gets widget tests including a text-scale matrix; PLAN-04 is gated by an ARB forbidden-vocabulary test plus per-segment disclaimer finders.

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 04-01/T1 | 04-01 | 1 | PLAN-01 | T-04-01 | tracer path performs zero writes (row-count gate on first commit) | widget (tracer e2e) | `flutter test test/features/planner_screen_test.dart` | ⬜ created by task | ⬜ pending |
| 04-01/T2 | 04-01 | 1 | PLAN-01 | — | pure view-model: no clock, no strings, no persistence | unit (pure fn) | `flutter test test/features/planner_view_model_test.dart` | ⬜ created by task | ⬜ pending |
| 04-01/T3 | 04-01 | 1 | PLAN-01 | T-04-01 | leap-year/year-boundary math; paused + soft-deleted excluded; provider row-count zero | unit + provider | `flutter test test/features/planner_view_model_test.dart test/providers_planner_test.dart` | ⬜ created by task | ⬜ pending |
| 04-02/T1 | 04-02 | 2 | PLAN-01, PLAN-04 | T-04-02 | forbidden-vocabulary absent from both locales | unit (ARB + plurals) | `flutter gen-l10n && flutter test test/l10n/plurals_test.dart test/l10n/planner_copy_test.dart` | ⬜ created by task | ⬜ pending |
| 04-02/T2 | 04-02 | 2 | PLAN-04 | T-04-02 | disclaimer renders on BOTH segments unconditionally | widget | `flutter test test/features/planner_screen_test.dart` | ✅ extend 04-01 file | ⬜ pending |
| 04-02/T3 | 04-02 | 2 | PLAN-01 | — | — | widget | `flutter test test/features/planner_screen_test.dart` | ✅ extend | ⬜ pending |
| 04-03/T1 | 04-03 | 3 | PLAN-01 | — | — | widget | `flutter test test/features/planner_screen_test.dart` | ✅ extend | ⬜ pending |
| 04-03/T2 | 04-03 | 3 | PLAN-02 | T-04-01 | week selection writes nothing (row-count across a tap); accessible action on the Semantics node | widget | `flutter test test/features/planner_screen_test.dart` | ✅ extend | ⬜ pending |
| 04-03/T3 | 04-03 | 3 | PLAN-02 | — | — | widget | `flutter test test/features/planner_screen_test.dart` | ✅ extend | ⬜ pending |
| 04-04/T1 | 04-04 | 4 | PLAN-03 | — | year grid extent scales with text size and supplement count | widget | `flutter test test/features/planner_screen_test.dart` | ✅ extend | ⬜ pending |
| 04-04/T2 | 04-04 | 4 | PLAN-03, PLAN-04 | T-04-02 | footnote renders ABOVE the disclaimer (rendered position asserted) | widget | `flutter test test/features/planner_screen_test.dart` | ✅ extend | ⬜ pending |
| 04-04/T3 | 04-04 | 4 | PLAN-03 | T-04-01 | full render pass creates zero IntakeLog rows; live mutation respects soft delete | widget + row-count | `flutter test test/features/planner_screen_test.dart` | ✅ extend | ⬜ pending |
| 04-05/T1 | 04-05 | 5 | PLAN-01..03 | — | no layout exception at 1.0/1.6/2.0 x uk/en; actions reachable via semantics activation | widget (scale matrix) | `flutter test test/features/planner_screen_test.dart` | ✅ extend | ⬜ pending |
| 04-05/T2 | 04-05 | 5 | PLAN-04 | T-04-01, T-04-02 | read-only + editorial invariants as executable gates | unit (invariants) | `flutter test test/features/planner_invariants_test.dart` | ⬜ created by task | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

Existing infrastructure covers all phase requirements — flutter_test + mocktail green at 290/290 since Phase 3. No Wave 0 setup needed.

---

## Manual-Only Verifications

- Visual fidelity of the Cycles gantt, load chart and Year matrix vs mockup screens 03/04 (uk locale, real device)
- The DATA-03 on-device loop test (`flutter test integration_test/data03_loop_test.dart -d <device>`) must still pass on both platforms after this phase — planner screens must not regress the core loop
