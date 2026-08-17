---
phase: 6
slug: shell-simplification
status: ready
nyquist_compliant: true
created: 2026-08-17
---

# Phase 6 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | flutter_test (SDK) + mocktail 1.0.5; integration_test (SDK) for the two on-device tests |
| **Config file** | none needed — established Phases 1-5 |
| **Quick run command** | `flutter test <changed test file>` |
| **Full suite command** | `flutter analyze && flutter test` |
| **Estimated runtime** | ~75 seconds full suite (719 tests at phase start) |
| **Toolchain note** | no `node` in this worktree — `flutter analyze`, `flutter test`, `flutter gen-l10n` only. Every gate below is a Flutter command or an in-suite source-glob assertion, never a shell script |

---

## Sampling Rate

- **After every task commit:** Run `flutter test <task's test file>`
- **After every plan wave:** Run `flutter analyze && flutter test`
- **After every ARB edit:** `flutter gen-l10n` before the test run — a stale generated delegate makes a green suite meaningless
- **Before `/gsd-verify-work`:** Full suite green, and the three device backstops plus both `integration_test/` device tests run by hand
- **Max feedback latency:** ~75 seconds

---

## Per-Task Verification Map

*(Per 06-RESEARCH.md ## Validation Architecture: this phase is deletion-heavy, so the dominant risk is a **silently-passing gate** — a test that stays green because the thing it asserted no longer exists. Every task below either adds an absence assertion or inverts an existing one, and three tasks are required to prove their new gate **red** by temporary reinsertion before trusting it. NAV-01's text-scale matrix and PLAN-05's copy gate are the two hard verification surfaces; everything else is regression-gated by the existing 719-test suite.)*

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| T1 — BqNavBar live in AppShell | 06-01 | 1 | NAV-01 | T-06-01, T-06-SC | The deleted `navigationBarTheme` cannot be silently replaced by a dead sub-theme; `theme_test.dart`'s assertions are inverted to assert absence, and `NavigationBar`/`NavigationDestination` resolve nowhere in `lib/` | widget + source-glob | `flutter analyze && flutter test test/widget/app_shell_test.dart test/theme/theme_test.dart`; `grep -rn --include=*.dart -E "NavigationBar\|NavigationDestination" lib/ ; test $? -eq 1` | ✅ infra exists | ⬜ pending |
| T2 — Extent, styling, semantics contract | 06-01 | 1 | NAV-01 | T-06-02 | `navBarHeightFor` is strictly increasing and equals 56.0 at scale 1.0; every destination is activatable through `SemanticsAction.tap`, not only by coordinate tap | unit + widget | `flutter test test/core/widgets/bq_nav_bar_test.dart` | ⬜ new file | ⬜ pending |
| T3 — NAV-01 bilingual × text-scale matrix | 06-01 | 1 | NAV-01 | T-06-02 | At 1.0 / 1.6 / 2.0 × uk / en the shell throws no layout exception (`tester.takeException()` is null) and no destination label clips | widget matrix | `flutter test test/widget/app_shell_test.dart`; `flutter test` | ✅ infra exists | ⬜ pending |
| T1 — navBack copy and the Settings back control | 06-02 | 2 | NAV-03 | T-06-03 | The pushed route always has a working back affordance, asserted through `SemanticsAction.tap` on the real control — a programmatic pop cannot detect this defect class | widget + l10n | `flutter gen-l10n && flutter analyze && flutter test test/features/settings_screen_test.dart test/l10n` | ✅ infra exists | ⬜ pending |
| T2 — The gear control on all three tabs | 06-02 | 2 | NAV-03 | T-06-04 | The gear renders unconditionally on all three tabs at a 44×44 target, in its own text-free row — it cannot overflow at any text scale | widget | `flutter analyze && flutter test test/features/stack_screen_test.dart test/features/calendar_screen_test.dart test/features/planner_screen_test.dart` | ✅ infra exists | ⬜ pending |
| T3 — Header overflow matrix + push/pop state | 06-02 | 2 | NAV-03 | T-06-04 | No pre-existing header assertion is relaxed; the Today title row's child count is asserted, so an accidental third child fails a test rather than shipping. Popping Settings leaves `_selectedIndex` unchanged | widget matrix | `flutter analyze && flutter test` | ✅ infra exists | ⬜ pending |
| T1 — Promote the Today page (behaviour-preserving) | 06-03 | 3 | NAV-02 | T-06-07 | The `TickerMode.valuesOf(context).enabled` read survives the file move — its loss is invisible at runtime and only `app_shell_test.dart:125` catches it | widget + grep | `flutter analyze && flutter test test/features/calendar_screen_test.dart test/widget/app_shell_test.dart`; `flutter test` | ✅ infra exists | ⬜ pending |
| T2 — Three destinations; delete the page swap | 06-03 | 3 | NAV-02, NAV-03 | T-06-05 | Deletion order is call-sites-before-declarations in one atomic commit; no dangling reference to `calendarPageProvider`/`CalendarPageController`/`CalendarScreen` survives | widget + source-glob | `flutter gen-l10n && flutter analyze && flutter test`; `grep -rn --include=*.dart -E "calendarPageProvider\|CalendarPageController\|enum CalendarPage\|CalendarScreen" lib/ ; test $? -eq 1` | ✅ infra exists | ⬜ pending |
| T3 — Absence gates + deep-state survival | 06-03 | 3 | NAV-02 | T-06-06 | The new absence gate is **proven red** by temporarily reintroducing a deleted symbol; `planner_invariants_test.dart`'s file-count floor is verified, not assumed (this phase is net-zero on that directory) | source-glob + widget | `flutter analyze && flutter test test/widget/shell_invariants_test.dart test/widget/app_shell_test.dart test/features/planner_screen_test.dart`; `flutter test` | ⬜ new file (`shell_invariants_test.dart`) | ⬜ pending |
| T1 — BqAddFab, its theme entry, its mount point | 06-04 | 4 | UX-01 | T-06-09 | A repeated `SemanticsAction.tap` opens exactly one add sheet — the sheet's existing guard is read, not assumed; if absent, one is added in the FAB | widget | `flutter analyze && flutter test test/core/widgets/bq_add_fab_test.dart test/theme/theme_test.dart test/widget/app_shell_test.dart` | ⬜ new file | ⬜ pending |
| T2 — Remove the Stack add button, repoint the empty state | 06-04 | 4 | UX-01 | T-06-10 | Every retargeted assertion matches the FAB's semantics node, so no test passes for the wrong reason by silently matching the FAB's identical label | widget + l10n | `flutter gen-l10n && flutter analyze && flutter test test/features/stack_screen_test.dart test/features/today_screen_test.dart test/l10n` | ✅ infra exists | ⬜ pending |
| T3 — UX-01 presence/absence + clearance | 06-04 | 4 | UX-01 | T-06-11 | The FAB renders on all three tabs and is structurally absent on the pushed Settings route; the last list item stays reachable at scale 2.0 with `bottom: 84` retained | widget matrix | `flutter analyze && flutter test` | ✅ infra exists | ⬜ pending |
| T1 — The scheduled-supplement ceiling on CyclesModel | 06-05 | 5 | PLAN-05 | T-06-13 | `load <= ceiling` for every bucket of generated multi-supplement models — the invariant is asserted, not assumed, and the chart may neither compute nor default the value | unit (property-style) | `flutter analyze && flutter test test/features/planner_view_model_test.dart` | ✅ infra exists | ⬜ pending |
| T2 — Neutralize the load chart | 06-05 | 5 | PLAN-05 | T-06-13, T-06-14 | No threshold, cap or over-bar artefact resolves in `lib/features/calendar/`; the axis caption is *replaced* not removed, so the self-scaling ceiling stays visible; `weekLoadLabel`'s last `lib/` consumer is cleared before 06-06 deletes the key | widget + l10n + grep | `flutter gen-l10n && flutter analyze && flutter test test/features/planner_screen_test.dart test/l10n` | ✅ infra exists | ⬜ pending |
| T3 — Zero / one / many chart tests | 06-05 | 5 | PLAN-05 | T-06-12 | A zero ceiling never reaches the chart (the existing empty state renders, asserted by the absence of the chart widget), so no division guard exists to get wrong; four-step proportionality proves the denominator is the ceiling | widget | `flutter analyze && flutter test` | ✅ infra exists | ⬜ pending |
| T1 — Neutralize remaining surfaces; rewrite the disclaimer | 06-06 | 6 | PLAN-05 | T-06-18 | The disclaimer rewrite lands **before** any gate widening and keeps both live disclaimer assertions green **without editing them** (`git diff` on that region shows no change); the disclaimer still renders on both segments and the empty and error surfaces | widget + l10n | `flutter gen-l10n && flutter analyze && flutter test test/features/planner_screen_test.dart test/l10n` | ✅ infra exists | ⬜ pending |
| T2 — Delete the limit machinery, the dead token, 16 ARB keys | 06-06 | 6 | PLAN-05 | T-06-15, T-06-16, T-06-17 | The `risk`/`warn`/`calm` families and the regimen editor's `weeksCount` key survive, gated by count; **every test naming a deleted getter is edited in this same commit** (`plurals_test.dart`, `planner_copy_safety_test.dart`) so no intermediate tree fails to compile; the ARB coverage floor is re-derived from the measured count here, not left red for a task | unit + l10n + grep | `flutter gen-l10n && flutter analyze && flutter test`; `grep -rn --include=*.dart -E "editorialLimit\|comfortLoad\|verdictOf\|LoadVerdict" lib/ ; test $? -eq 1` | ✅ infra exists | ⬜ pending |
| T3 — Tighten the vocabulary gate; prove PLAN-05 by absence | 06-06 | 6 | PLAN-05 | T-06-17, T-06-18 | The widened vocabulary gate is **proven red** by temporarily reinserting a forbidden stem; the negation exemption is deleted rather than retained; the judgement-palette source-glob gate is scoped to `lib/features/calendar/planner_*.dart` and names the four Today-screen files that legitimately keep their colours | source-glob + l10n + widget | `flutter analyze && flutter test test/l10n test/features/planner_invariants_test.dart test/features/planner_screen_test.dart`; `flutter test` | ✅ infra exists | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

Existing infrastructure covers all phase requirements — flutter_test + mocktail green at 719/719 at phase start, `flutter gen-l10n` and both `integration_test/` device tests already established in Phases 1-5. **No Wave 0 setup needed.** No package is added or removed this phase (`git diff --quiet -- pubspec.yaml pubspec.lock` is a hard gate at the end of every task, T-06-SC), so there is no dependency step to validate.

Three test files are new but need no new infrastructure — they are ordinary `flutter_test` files created by the tasks that own them: `test/core/widgets/bq_nav_bar_test.dart` (06-01 T2), `test/widget/shell_invariants_test.dart` (06-03 T3) and `test/core/widgets/bq_add_fab_test.dart` (06-04 T1).

---

## Manual-Only Verifications

Executors have no device, so these are orchestrator/human checks run once before phase sign-off — never automated assertions, and never a substitute for the gates above.

- **Backstop 19 (bar + FAB on real hardware):** on a physical iPhone with a home indicator and on an Android device with gesture navigation, the 56dp bar's three targets are comfortably hittable, the `surfaceAlt` fill and the hairline reach the screen edge, and the FAB does not collide with the system gesture area at textScaler 1.0 or 2.0
- **Backstop 20 (locale propagation across a pushed route):** pushing Settings from Календар, changing the language, and popping returns to the Календар tab re-rendered in the new language, with no stale header subtitle and no lost planner selection
- **Backstop 21 (the self-scaling chart reads as a scale, not a limit):** with a real multi-supplement stack, a full bar is understood as "my whole stack overlaps here" rather than as a limit, and `loadScaleCaption` is legible at mono 10 in both locales — raised at UAT if the ceiling reads as a threshold anyway
- **Device regression gate:** **both** existing `integration_test/` device tests must still pass on **iOS and Android** at phase end
