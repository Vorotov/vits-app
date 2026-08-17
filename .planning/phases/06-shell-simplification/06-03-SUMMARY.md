---
phase: 06-shell-simplification
plan: 03
subsystem: shell / navigation
tags: [navigation, deletion, l10n, riverpod, accessibility]
status: complete
requires:
  - 06-01 (BqNavBar, the hand-built text-scale-aware bar)
  - 06-02 (the settings gear on all three screens + Settings as a pushed route)
provides:
  - "TodayScreen — the Today page as its own public screen"
  - "a three-destination shell: Стек | Сьогодні | Календар"
  - "ARB key tabToday (both locales); tabSettings renamed settingsTitle"
  - "test/widget/shell_invariants_test.dart — source-glob absence gates over lib/"
affects:
  - lib/app_shell.dart
  - lib/features/calendar/*
  - lib/features/settings/settings_screen.dart
  - lib/features/stack/stack_screen.dart
  - integration_test/*
tech-stack:
  added: []
  patterns:
    - "source-glob invariant gate over lib/, comments included (planner_invariants idiom)"
    - "mutation-proved tests: gates and survival cases each shown red before being trusted"
key-files:
  created:
    - lib/features/calendar/today_screen.dart
    - test/widget/shell_invariants_test.dart
    - test/features/today_screen_test.dart (renamed from calendar_screen_test.dart)
  modified:
    - lib/app_shell.dart
    - lib/features/calendar/calendar_providers.dart
    - lib/features/calendar/planner_screen.dart
    - lib/features/settings/settings_screen.dart
    - lib/features/stack/stack_screen.dart
    - lib/core/l10n/arb/app_uk.arb
    - lib/core/l10n/arb/app_en.arb
    - test/features/planner_screen_test.dart
    - test/features/settings_screen_test.dart
    - test/features/stack_screen_test.dart
    - test/widget/app_shell_test.dart
    - integration_test/data03_loop_test.dart
    - integration_test/l10n_device_test.dart
  deleted:
    - lib/features/calendar/calendar_screen.dart
decisions:
  - "The Календар glyph changes to calendar_month (from v1's calendar_today) so Сьогодні (today) and Календар read as single-day vs. span (D-2)."
  - "cyclesModelProvider / yearModelProvider are now permanently alive and recompute on every stack emission even on Стек. Accepted, deliberately not gated: synchronous derivations, no timer, no stream, no materializing path — gating on TickerMode would blank the planner on re-entry for no measured benefit."
  - "The plan's absolute `plannerTitle` absence criterion was scoped rather than obeyed: the planner's own screen title legitimately uses the key. The gate asserts exactly one file may name it."
  - "The two PopScope system-back tests were deleted; the half of their claim that survives (back on a tab is NOT intercepted) was re-encoded as a new test."
metrics:
  duration: ~75 min
  completed: 2026-08-17
actuals:
  tokens: 25000
  tasks: 3
  commits: 3
---

# Phase 6 Plan 03: Three Destinations Summary

The shell now runs on Стек | Сьогодні | Календар with the planner as a first-class
destination: the Today page was promoted into `today_screen.dart`, `calendar_screen.dart`
and the whole in-tab page-swap mechanism (enum, controller, provider, `PopScope`
back-interception, the `plannerTitle` header action and the planner's `‹ Сьогодні`
control) were deleted, Settings left the bar for good, and source-glob gates now fail if
any of it comes back — including inside a comment.

## What was built

**Task 1 — `refactor(06-03)` `309e1b2`.** Pure extraction. `TodayScreen` became public in
its own file with `_Header`, `_DayBody`/`_DayBodyState`, `_EmptyDayState`, `_Disclaimer`,
the `_screenPadding` constant and the 06-02 gear row. The two named must-move-intact
pieces moved verbatim: the `TickerMode.valuesOf(context).enabled` read (grep: 1 in
`today_screen.dart`, 0 in `calendar_screen.dart`) and the `_held`/`_heldDay` WR-01
hold-last-value machinery. `CalendarScreen` kept the page swap and rendered `TodayScreen`.
756 tests green with **zero test edits** — the extraction proved behaviour-preserving by
construction, which is what made Task 2 a small diff rather than a file move tangled with
deletions.

**Task 2 — `feat(06-03)` `5a2893c`, one atomic commit across 19 files.** Copy first
(`tabToday` added in both locales as a key distinct from `backToToday`; `tabSettings` →
`settingsTitle`; `flutter gen-l10n` re-run and its output committed), then the deletions in
inventory order (call sites → declarations → the screen file), then the shell rewire, then
Settings, then every consumer retargeted in the same commit. The `IndexedStack` children are
`StackScreen()`, `TodayScreen()`, `PlannerScreen()`, each still wrapped in
`TickerMode(enabled: index == _selectedIndex)`; the WR-05 comment survives with "the Calendar
tab reads it" → "the Сьогодні tab reads it". Settings' dead `bottom: 84` nav-bar clearance
became `BqSpace.lg`.

**Task 3 — `test(06-03)` `6021c82`.** `shell_invariants_test.dart` (its own file, so 06-05/06-06
can edit `planner_invariants_test.dart` without colliding) gates `lib/` — comments included —
on `CalendarScreen`, `CalendarPage`, `calendarPageProvider`, `PopScope`, `tabSettings`, SDK
`NavigationBar(`/`NavigationDestination(` mounts and `navigationBarTheme:`, plus a scoped
`plannerTitle` gate and a shell-composition check. `app_shell_test` gained the three-destination
count and the settings-title **absence** inside the bar's subtree. `planner_screen_test` gained
four selection-survival cases and the system-back case.

## Verification

| Gate | Result |
|---|---|
| `flutter analyze` | 0 issues |
| `flutter test` | **764 passed**, 0 failed (baseline 756) |
| `git diff --quiet -- pubspec.yaml pubspec.lock` | clean (exit 0) |
| `grep -rn -E "calendarPageProvider\|CalendarPageController\|enum CalendarPage\|CalendarScreen\|PopScope" lib` | zero matches |
| `grep -rn "tabSettings" lib test integration_test` | zero matches |
| `grep -c "tabToday"` uk / en ARB | 1 / 2 — and `backToToday` still present (both keys coexist) |
| `grep -rn "Icons.calendar_today" lib` | zero matches; `Icons.today*` and `Icons.calendar_month*` both in `app_shell.dart` |
| `ls lib/features/calendar/calendar_screen.dart` | gone |
| `grep -c "bottom: 84" lib/features/settings/settings_screen.dart` | 0 |
| `test/features/calendar_screen_test.dart` | renamed to `today_screen_test.dart` (git rename, same 71 tests) |
| `flutter test test/features/planner_invariants_test.dart` | green |

**Both gates were proved red, not assumed green (T-06-06):**

1. Re-introducing `calendarPageProvider` **inside a comment** in `app_shell.dart` failed
   `shell_invariants_test.dart` with `[lib/app_shell.dart references calendarPageProvider]`;
   reverted, green again.
2. The four survival tests were run against a shell mutated to render
   `children[_selectedIndex]` (unmounting offstage children) — all four went red, so they are
   not passing for a "the container held the value anyway" reason. Reverted, green again.

**File-count floor, verified rather than assumed (PF-11):** `planner_invariants_test.dart:83-130`
globs `lib/features/calendar/planner_*.dart` — **not** the whole directory. This phase's +1
(`today_screen.dart`) / −1 (`calendar_screen.dart`) never touched that set, so the floor needed
no re-derivation; the file is green.

**Integration tests:** not run (no device, per instruction) but retargeted so they compile and
would pass — `data03_loop_test.dart` now taps `Сьогодні` for the day loop and asserts
`Налаштування` is absent from the bar; `l10n_device_test.dart` section (g) walks
`Icons.today_outlined` → `Icons.calendar_month_outlined` → gear → chevron-pop instead of the
deleted destination path.

## Tests: deleted vs. retargeted

**Deleted (3)** — each asserted a mechanism that no longer exists:

| Test | Why |
|---|---|
| `the planner's back control restores the Today header` | the `‹ Сьогодні` control is deleted |
| `a system back with the planner open returns to Today and never leaves the Calendar tab` | the `PopScope` is deleted |
| `a second system back, now on Today, is NOT swallowed…` | ditto; its surviving half is re-encoded (below) |

Their `group('system back')` helper block went with them; `shellApp` was promoted to the file's
outer scope and `recordPlatformCalls`/`systemBack` were re-declared in the new deep-state group.

**Retargeted, never weakened:**

- `tapping the Calendar header's planner action opens the planner…` → `the Календар destination
  shows the planner and draws one gantt row per regimen-bearing entry`. Same gantt assertions;
  the supplement-with-no-regimen check became gantt-scoped because the shell keeps the Стек tab
  mounted, so a bare `find.text('Вітамін D3')` would now match the stack list.
- `opening the planner writes no IntakeLog row (PF-2/WR-06)` → same claim, driven through the
  real shell and a Календар destination tap.
- `the Calendar header's two text actions flow onto a SECOND LINE at 2.0 (WR-04)` → the second
  action was deleted with the page swap, so the pair-geometry assertion had no subject. It now
  asserts what still has to hold: the container is **still a `Wrap`** (a `Row` would re-arm WR-04
  the moment anyone adds an action), exactly one action survives, and nothing overflows at 2.0.
- `app_shell_test`'s `switching to Settings renders heading without overflow` → the gear pushes
  Settings; the heading now renders **once** (the destination label is gone), and the test
  additionally asserts no settings text is in the bar beforehand.
- `settings_screen_test`'s `openSettings` helper: tapped the nav destination, now taps the gear.
  A push animates where a destination switch did not, so the helper pumps bounded frames until
  the route arrives — `pumpAndSettle` stays forbidden in that file, and the one-frame language
  claim is still measured from the row tap, after the transition.
- `pushing Settings from the shell preserves the selected tab` now runs from destinations **0, 1
  and 2** (was 0 and 1), and its stale "Settings is STILL a destination in this plan" comment was
  rewritten.

**Added (11):** 4 in `shell_invariants_test.dart`, 1 three-destination/absence case in
`app_shell_test.dart`, 5 in the deep-state group, 1 extra push-preservation case (destination 2).
756 − 3 + 11 = **764**.

**Nothing needed inverting.** The plan warned that a pre-existing test asserting the planner
segment *resets* on re-entry would be asserting the old bug. Grepping `plannerSegmentProvider`
across `test/features/planner_screen_test.dart` returned **zero** hits — no such test existed, so
there was nothing to invert. Recorded because "found nothing" and "did not look" are
indistinguishable in a summary otherwise.

## Deviations from Plan

### Auto-fixed

**1. [Rule 1 – Bug in the plan's acceptance criterion] The `plannerTitle` absence gate is scoped, not absolute**
- **Found during:** Task 2.
- **Issue:** the criterion `grep -rn … plannerTitle lib/ returns zero matches` would require
  deleting `planner_screen.dart:193`'s `Text(l10n.plannerTitle)` — the planner's own screen title.
  The deletion inventory only ever listed the *header entry action*; obeying the grep literally
  would have shipped an untitled planner.
- **Fix:** deleted the header action only; the gate asserts **exactly one file** (plus the ARB/generated
  l10n files that declare the key) may name `plannerTitle`, which fails both if the header action
  returns and if a third screen borrows the title.
- **Also:** the key's ARB description claimed "ONE key, TWO placements" — now false, so it was
  rewritten in the same commit.
- **Files:** `lib/features/calendar/planner_screen.dart`, `lib/core/l10n/arb/app_en.arb`,
  `test/widget/shell_invariants_test.dart`. **Commits:** `5a2893c`, `6021c82`.

**2. [Rule 3 – Blocking] The `tabSettings` rename reached two files the plan did not list**
- `lib/features/stack/stack_screen.dart` and `test/features/stack_screen_test.dart` carry the gear
  (added in 06-02, after this plan was written) and referenced the old key. Mechanical rename;
  without it the tree does not compile. **Commit:** `5a2893c`.

**3. [Rule 3 – Blocking] The SDK-widget gate needed constructor-shaped needles**
- **Issue:** gating on the bare word `NavigationBar` flagged three legitimate sites —
  `Scaffold(bottomNavigationBar:)` (a slot name every screen uses) and `BqNavBar`'s own doc comment,
  which names `NavigationBar`/`navigationBarTheme.height` **on purpose** as the D-1 rationale wave 1
  required be written down.
- **Fix:** the gate matches `NavigationBar(`, `NavigationDestination(` and `navigationBarTheme:` —
  mounts and the theme field, not prose. The reasoning is recorded in the gate itself.
- **Commit:** `6021c82`.

**4. [Rule 3 – Blocking] `l10n_device_test.dart` section (g) rewrote its navigation path**
- It tapped `Icons.calendar_today_outlined` (gone) and returned from Settings by tapping a
  destination — impossible now that Settings is an opaque pushed route covering the bar. It now
  pops with the chevron, which also makes it a live check of Interaction Contract 3.
- **Commit:** `5a2893c`.

### Accepted, recorded so nobody "fixes" it

`cyclesModelProvider` / `yearModelProvider` are permanently alive and recompute on every
`stackEntriesProvider` emission even while the user is on Стек. This is the intended consequence of
making the planner a destination: they are synchronous derivations with no timer, no Drift stream
and no materializing path, and gating them on `TickerMode` would blank the planner on re-entry and
drag in hold-last-value machinery for no measured benefit (Interaction Contract 7).

## Requirements

- **NAV-02 — satisfied.** Three destinations; Сьогодні holds today's doses and the week strip
  (the strip was already a `TodayScreen` child — the spec's "Сьогодні gaining the week strip"
  described no work); Календар holds the Цикли/Рік planner.
- **NAV-03 — satisfied end to end.** Settings is not a destination (asserted as an absence inside
  the bar's subtree), is reachable from the gear on all three tabs, returns to the tab it was opened
  from (now proved from all three), and the page swap and its back-interception exist nowhere in the
  codebase.

## Known Stubs

None.

## Follow-ups for later plans in this phase

- The FAB (06-04) will need the Today body's `bottom: 84` re-proved against bar + FAB; it was
  deliberately left at 84 here with its comment intact.
- `plannerDisclaimer`, `limitBadge` and the rest of the limit machinery are untouched — 06-05/06-06.

## Self-Check: PASSED

- `lib/features/calendar/today_screen.dart` — FOUND
- `test/widget/shell_invariants_test.dart` — FOUND
- `test/features/today_screen_test.dart` — FOUND
- `lib/features/calendar/calendar_screen.dart` — absent, as intended
- Commits `309e1b2`, `5a2893c`, `6021c82` — all present in `git log`
