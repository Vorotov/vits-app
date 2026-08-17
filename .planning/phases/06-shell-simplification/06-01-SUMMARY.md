---
phase: 06-shell-simplification
plan: 01
subsystem: app-shell
status: complete
tags: [nav-bar, text-scale, semantics, theme-deletion, tracer]
requires: []
provides:
  - "lib/core/widgets/bq_nav_bar.dart — BqNavBar + navBarHeightFor(TextScaler)"
  - "BqNavDestination value type (icon / selectedIcon / label)"
  - "test/support/locale_matrix.dart — bqTextScaleMatrix [1.0, 1.6, 2.0] + bqLocaleMatrix"
affects:
  - lib/app_shell.dart
  - lib/core/theme/theme.dart
  - lib/core/theme/tokens.dart
  - test/theme/theme_test.dart
  - test/widget/app_shell_test.dart
  - test/features/settings_screen_test.dart
  - test/features/planner_screen_test.dart
  - integration_test/data03_loop_test.dart
  - integration_test/l10n_device_test.dart
tech-stack:
  added: []
  patterns:
    - "Third instance of the stripHeightFor extent idiom: two documented constants + one top-level function of TextScaler, unit-tested without pumping"
    - "DecoratedBox rather than Container when a decoration carries a Border and the laid-out extent must stay exact"
    - "onTap duplicated onto the Semantics node itself under excludeSemantics: true (WR-02)"
    - "SemanticsRole.tabBar / .tab alongside button+selected, not instead of them"
key-files:
  created:
    - lib/core/widgets/bq_nav_bar.dart
    - test/core/widgets/bq_nav_bar_test.dart
  modified:
    - lib/app_shell.dart
    - lib/core/theme/theme.dart
    - lib/core/theme/tokens.dart
    - test/theme/theme_test.dart
    - test/widget/app_shell_test.dart
    - test/support/locale_matrix.dart
    - test/features/settings_screen_test.dart
    - test/features/planner_screen_test.dart
    - integration_test/data03_loop_test.dart
    - integration_test/l10n_device_test.dart
decisions:
  - "The hairline top border is painted by DecoratedBox, not Container: a Border inside a Container's decoration is padding, so the bar measured 57dp against NAV-01's 56dp. DecoratedBox paints the same 1px line without consuming layout, keeping the painted extent exactly navBarHeightFor(scaler) + bottom inset."
  - "SemanticsRole.tabBar / SemanticsRole.tab were available and are used on Flutter 3.47 — no downgrade to button-only was needed. button: true and selected: … are kept alongside the roles, so the roles are additive."
  - "The sub-theme deletion is gated by INVERTED assertions in theme_test.dart (three cases asserting absence), not by deleting the three D-25 cases."
  - "tokens.dart doc comments were corrected in the same commit: they still documented the 66px destination column and 24px home-indicator overrides that this plan deletes."
metrics:
  duration: ~35 min
  completed: 2026-08-17
  tests_before: 719
  tests_after: 738
actuals:
  tokens: 22000
  tasks: 3
  commits: 4
---

# Phase 6 Plan 01: BqNavBar Tracer Summary

The hand-built `BqNavBar` replaces Material's `NavigationBar` in `AppShell` at a
56dp base height derived from `navBarHeightFor(TextScaler)` (44 fixed + the
scaled 12px label line box), with per-destination semantics actions that survive
`excludeSemantics` — the SDK widget and its `ThemeData` sub-theme are gone from
`lib/`, and the destination set is v1's three, unchanged.

## What was built

**`lib/core/widgets/bq_nav_bar.dart`** (new, 231 lines)

- `navBarHeightFor(TextScaler)` = `_navBarFixedExtent (44)` +
  `scaler.scale(_navBarLabelExtent (12))` → **56.0 at scale 1.0, 68.0 at 2.0**,
  strictly increasing. Only the label passes through the scaler, because `Icon`
  sizes from `IconThemeData` and does not follow it — which is why the extent is
  split rather than multiplied whole.
- `BqNavDestination` — an immutable icon-pair + already-localized label, so the
  widget never reaches for `context.l10n` and stays a pure function of its
  arguments.
- `BqNavBar` — `DecoratedBox` (surfaceAlt fill, 1px `hairline` top border) >
  `Padding` (start 22 / end 22) > `SafeArea(top: false)` > `SizedBox(height:
  navBarHeightFor(...))` > `Semantics(tabBar)` > `Row` of three `Expanded`
  cells; each cell `MergeSemantics` > `Semantics(button, selected, role: tab,
  excludeSemantics, onTap)` > `InkResponse` > `Column`(22dp `Icon`, 4px gap,
  10/1.2 label at w600+accent or w400+textFaint).
- The library doc comment records the **accurate** D-1 rationale: the SDK bar's
  height *is* themeable (`navigation_bar.dart:281`), but the resolved height
  lands in a hard `SizedBox` around a label that grows with the scaler, and no
  `ThemeData` field accepts a `double Function(TextScaler)`. It also records the
  deliberate `InkResponse` choice over the load chart's opacity idiom.

**Deletions** — SDK `NavigationBar` + its three `NavigationDestination`
children, the outer `Container` and its `top: 10` padding (folded into the
extent), the `AppShell` doc block recording the three v1 accepted deviations,
and the whole `navigationBarTheme:` entry from `bqTheme()`. The `IndexedStack` +
per-child `TickerMode` block and its WR-05 comment are byte-for-byte unchanged;
`_selectedIndex` remains plain `StatefulWidget` state.

**`test/core/widgets/bq_nav_bar_test.dart`** (new, 15 tests) — three extent
cases calling `navBarHeightFor` directly with no `pumpWidget`; styling and
chrome; the painted-extent-equals-formula case; the equal-`Expanded`-cell and
no-width-bounding-ancestor case that keeps the v1 66px column gone; four
semantics cases driven by `SemanticsAction.tap` (there is **no** `tester.tap` in
the file); two static-render absence cases.

**Matrix** — `bqTextScaleMatrix` `[1.0, 1.6, 2.0]` and `bqLocaleMatrix` hoisted
into `test/support/locale_matrix.dart`; `app_shell_test.dart` sweeps all six
cells, each asserting `takeException()` is null, all three labels present, and
the bar's real painted height equalling `navBarHeightFor(scale) + inset`.

## Verification

| Gate | Result |
|------|--------|
| `flutter analyze` | **No issues found** |
| `flutter test` | **738 passed**, 0 failed (719 baseline + 19 new, zero tests deleted) |
| SDK `NavigationBar` / `NavigationDestination` in `lib/` | none — remaining grep hits are `bottomNavigationBar:` (a `Scaffold` property) and doc-comment prose |
| `grep -n navigationBarTheme lib/core/theme/theme.dart` | 0 matches |
| `grep -c FittedBox lib/core/widgets/bq_nav_bar.dart` | 0 |
| `grep -c "EdgeInsets("` / `EdgeInsets.only(left\|right` in the bar | 0 / 0 |
| `git diff --quiet -- pubspec.yaml pubspec.lock` | clean (T-06-SC) |
| Extent mutation check | `_navBarFixedExtent = 43` was confirmed to turn two extent cases red (55.0 vs 56.0, 67.0 vs 68.0) before restoring 44 |

The tracer feedback gate was run before Task 2 began: the Task 1 `<verify>`
commands re-passed end to end (analyze clean, affected suites green, grep gates
zero), so expansion proceeded.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] The `Container` border made the bar 57dp, not 56dp**
- **Found during:** Task 1, on the first GREEN run
- **Issue:** The plan's shape specifies a decorated `Container` with a
  `Border(top: …)`. A `Container` translates its decoration's border into
  padding, so the laid-out height was `1 + navBarHeightFor(scaler)` — 57.0 at
  scale 1.0. That silently falsifies both NAV-01's "56dp" and Task 3's
  per-cell `height == navBarHeightFor(scale) + inset` assertion.
- **Fix:** `DecoratedBox` + explicit `Padding` instead of `Container`.
  `DecoratedBox` paints the identical hairline without insetting its child, so
  the 1px line paints over the top of the 8px pad already inside the extent and
  the painted height is exactly the formula. Rationale recorded in the widget.
- **Files modified:** `lib/core/widgets/bq_nav_bar.dart`
- **Commit:** `fce8ce6`

**2. [Rule 3 - Blocking] Four other suites scoped their finders to the SDK widget**
- **Found during:** Task 1, full-suite run (7 failures)
- **Issue:** The plan named only `app_shell_test.dart` as needing retargeting,
  but `settings_screen_test.dart` (4 `find.descendant(of: find.byType(
  NavigationBar))` call sites), `planner_screen_test.dart` (a
  `tester.widget<NavigationBar>(…).selectedIndex` helper) and both
  `integration_test/` suites also reached for the SDK type. `app_shell_test.dart`
  itself needed **no** retargeting — its finders were already behavioural.
- **Fix:** Retargeted every finder to `BqNavBar`. No assertion was weakened:
  `selectedTab` reads `BqNavBar.selectedIndex`, which is the same claim about
  which tab the shell reports as selected.
- **Files modified:** `test/features/settings_screen_test.dart`,
  `test/features/planner_screen_test.dart`,
  `integration_test/data03_loop_test.dart`,
  `integration_test/l10n_device_test.dart`
- **Commit:** `fce8ce6`

**3. [Rule 2 - Correctness] `tokens.dart` doc comments had become lies**
- **Found during:** Task 1, running the plan's grep gates
- **Issue:** `tokens.dart:214` documented the nav-bar spacing exemption as
  "top 10 / horizontal 22 / destination column 66 / home-indicator 24"; this
  plan deletes three of those four. Three colour tokens also credited their
  purpose to `NavigationBar`, a widget that no longer resolves in `lib/`.
- **Fix:** Both corrected. `tokens.dart` was not in the plan's
  `files_modified`, but this phase's own rule is that a wrong doc comment is a
  durable lie, and the UI-SPEC Supersedes row explicitly voids those three
  overrides.
- **Files modified:** `lib/core/theme/tokens.dart`
- **Commit:** `fce8ce6`

### Scope notes

Nothing outside this plan's remit was touched: the destination **set** (three,
v1's labels/icons/order/index mapping), the tab structure, settings placement,
the FAB and everything planner-related are untouched — those are plans
06-02..06-06. `SemanticsRole.tabBar`/`.tab` proved available on Flutter 3.47, so
the documented button-only downgrade path was not taken.

## Known Stubs

None. The bar renders three destinations synchronously from its arguments; there
is no async source, no placeholder copy and no unwired prop in the new file.

## Threat Flags

None. This plan adds no write, no persistence, no permission request and no
network call; `pubspec.yaml`/`pubspec.lock` are byte-identical (T-06-SC gate
passed after every task).

## Self-Check: PASSED

- `lib/core/widgets/bq_nav_bar.dart` — FOUND
- `test/core/widgets/bq_nav_bar_test.dart` — FOUND
- `.planning/phases/06-shell-simplification/06-01-SUMMARY.md` — FOUND
- Commits `1d149b5`, `fce8ce6`, `2ed13a1`, `501f66f` — all FOUND in `git log`

## Follow-ups for later plans

- `bqTextScaleMatrix` / `bqLocaleMatrix` now exist in
  `test/support/locale_matrix.dart` — the FAB and header matrices in 06-02..06-06
  should read them rather than re-declaring a scale literal.
- `BqNavBar` takes its destinations as a list, so the 06-02+ destination-set
  restructuring is a change to `app_shell.dart`'s argument list, not to the bar.
- The `SemanticsRole.tabBar` validator requires **every** direct semantics child
  to carry `SemanticsRole.tab`; any future non-tab child added to the bar's `Row`
  will trip it.
