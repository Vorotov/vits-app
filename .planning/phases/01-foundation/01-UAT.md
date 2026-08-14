---
status: testing
phase: 01-foundation
source: [01-VERIFICATION.md]
started: 2026-08-14T19:05:00Z
updated: 2026-08-14T19:05:00Z
---

## Current Test

number: 1
name: Visual fidelity vs mockup in Ukrainian locale
expected: |
  App shell on iOS simulator in uk locale matches mockup footer styling: surfaceAlt tab bar,
  accent-colored selected tab, faint unselected tabs; "Налаштування" label fits without clipping.
awaiting: user response

## Tests

### 1. Visual fidelity vs mockup in Ukrainian locale
expected: Shell matches mockup screen-01 footer (colors, typography); "Налаштування" tab label renders without clipping or ellipsis
result: [pending]

### 2. Fresh-install launch and local database location
expected: On a wiped simulator/emulator the app launches to the three-tab shell with no errors and no login; backgrounding/foregrounding survives; boostque.sqlite is created under the app-documents directory
result: [pending]

### 3. Package legitimacy review
expected: `flutter pub deps --style=compact` output matches the Package Legitimacy Audit in 01-RESEARCH.md (no unexpected transitive packages)
result: [pending]

### 4. DATA-02 concurrency backstop
expected: Confidence that mid-write interruption leaves DB consistent — structural evidence exists (single Drift transaction wraps materialization); accept as backstop or request an interruption simulation test
result: [pending]

## Summary

total: 4
passed: 0
issues: 0
pending: 4
skipped: 0
blocked: 0

## Gaps
