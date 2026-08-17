---
phase: 06-shell-simplification
plan: 02
subsystem: app-shell
tags: [navigation, a11y, i18n, settings, text-scale]
status: complete
requires:
  - "06-01 (BqNavBar + navBarHeightFor; four suites retargeted at BqNavBar)"
provides:
  - "ARB key navBack (uk «Назад» / en \"Back\") in both locale files + generated l10n"
  - "A start-aligned 44x44 back control on SettingsScreen calling Navigator.maybePop"
  - "An identical end-aligned, text-free gear row above the title on Стек, Сьогодні and Планувальник, pushing SettingsScreen as a full-screen MaterialPageRoute"
  - "Widget coverage: gear presence/geometry matrix (uk x en x 1.0/1.6/2.0), SemanticsAction.tap activation on gear and back control, and tab preservation across a Settings push/pop from two starting destinations"
affects:
  - "06-03 (removes the Settings destination, renames tabSettings -> settingsTitle, drops the planner's ‹ Сьогодні control and settings_screen.dart's bottom: 84)"
tech-stack:
  added: []
  patterns:
    - "WR-02: the tap action lives on the Semantics node itself, not only on the IconButton under excludeSemantics"
    - "D-5: a dedicated, text-free control row above the title instead of a third child in a title Row"
    - "maybePop, never pop, on a screen that must not assume it was pushed (regimen_editor_screen.dart:221)"
key-files:
  created: []
  modified:
    - lib/core/l10n/arb/app_en.arb
    - lib/core/l10n/arb/app_uk.arb
    - lib/core/l10n/gen/app_localizations.dart
    - lib/core/l10n/gen/app_localizations_en.dart
    - lib/core/l10n/gen/app_localizations_uk.dart
    - lib/features/settings/settings_screen.dart
    - lib/features/stack/stack_screen.dart
    - lib/features/calendar/calendar_screen.dart
    - lib/features/calendar/planner_screen.dart
    - test/features/settings_screen_test.dart
    - test/features/stack_screen_test.dart
    - test/features/calendar_screen_test.dart
    - test/features/planner_screen_test.dart
decisions:
  - "Tap-target assertions are a FLOOR (>= 44) plus scale-invariance, not an equality against 44.0: the S11/S12 recipe (IconButton + BoxConstraints.tightFor(44,44) + zero padding) renders a 48dp box because Material wraps it to MaterialTapTargetSize.padded. 48 >= 44 satisfies the guidance; asserting 44.0 exactly would have meant fighting the SDK for a worse tap target."
  - "\"The route covers the nav bar\" is asserted as the framework fact it is — under an opaque full-screen route the whole shell goes offstage, so find.byType(BqNavBar) finds nothing while skipOffstage: false still finds it. hitTestable() was tried first and is unusable here: the bar's centre falls in the icon/label gap, so it is never hit-testable and the assertion would have passed vacuously."
  - "The Settings source gate now carries TWO closed size lists — type at 25/15/10.5 and icon glyphs at 18 — instead of folding the 18dp chevron into the font-size list, which would have licensed an 18px Text on the one screen whose type list is closed."
metrics:
  duration: ~21 min
  completed: 2026-08-17
  tests_before: 738
  tests_after: 756
actuals:
  tokens: 17400
  tasks: 3
  commits: 3
---

# Phase 6 Plan 02: Settings Gear and Back Control Summary

Settings gained a way in and a way out that does not depend on being a tab: an identical end-aligned, text-free gear row above the title on all three bar-reachable screens pushing `SettingsScreen` as a full-screen route, and a start-aligned `navBack`-labelled chevron on that route calling `Navigator.maybePop`. Purely additive — Settings is still a destination, so the app is never left with it unreachable.

## What shipped

**Task 1 — `navBack` and the Settings back control (`4a3c409`)**

- `navBack` in `app_en.arb` (with an ARB description stating it is a screen-reader-only label on the pushed route's back control) and `app_uk.arb`, in the same commit; `flutter gen-l10n` output committed alongside.
- `settings_screen.dart` gained a start-aligned `Row` as the first child of the existing `ListView`, holding one `IconButton` — `BoxConstraints.tightFor(44, 44)`, `padding: EdgeInsets.zero`, `Icons.arrow_back_ios_new` at 18dp in `BqColors.textSecondary`, verbatim from `regimen_editor_screen.dart:221-226` — wrapped in `Semantics(button, label: navBack, excludeSemantics: true, onTap: maybePop)`.
- No `AppBar`, no `appBarTheme`, no async surface: the Phase-5 rules for `features/settings/` are unchanged, and the suite's own source gates (`no loading surface`, `no error surface`, `no alert token`, `no database`) still pass over the edited file.
- Four new cases: label per locale, box >= 44 and identical at 1.0/1.6/2.0, `SemanticsAction.tap` carries a tap action and pops a genuinely pushed route, and activation on a bare root is a silent no-op (what `maybePop` buys over `pop`).

**Task 2 — the gear on all three bar-reachable screens (`6a7090a`)**

- One identical block per screen: an end-aligned `Row` above the title with a single 44x44 `IconButton`, `Icons.settings_outlined` at 20dp in `BqColors.textSecondary`, ARB-sourced semantics label (`tabSettings` — the key 06-03 renames to `settingsTitle`), pushing `MaterialPageRoute<void>(builder: (_) => const SettingsScreen())`, plus a file-local `_openSettings(BuildContext)` so the push shape is written once per file.
- Placement: new first `ListView` child on Стек; a new `Column(crossAxisAlignment: stretch)` wrapper inside `_Header`'s existing `Padding` on Сьогодні, with the title `Row` moved into it **unchanged**; new first `Column` child on Планувальник, above the surviving `‹ Сьогодні` control (the two coexist for exactly one commit, by plan).
- The WR-04 reasoning is written onto the new row on all three screens, naming the rejected alternative, so a later reader does not tidy the gear into a title row.
- Per-screen coverage: presence in both locales at all three scales, filled-glyph absence, box >= 44 and scale-invariant, `SemanticsAction.tap` pushing a `SettingsScreen` while the tab underneath stays mounted; plus a **child-count assertion on the Сьогодні title row** read off the widget tree (not the source) and a no-`Text` assertion on the planner's gear row.

**Task 3 — overflow matrix and push/pop tab preservation (`bb90dc2`)**

- Each of the three header matrices (uk x en x 1.0/1.6/2.0 = six cells per screen) now also collects the gear **row's** height and asserts a single distinct value across scales, alongside `tester.takeException()` being null per cell.
- New shell group in `planner_screen_test.dart` mounting the real `AppShell`: from destinations 0 and 1, tap the visible gear, assert the pushed route is current, opaque, and takes the whole shell offstage (`find.byType(BqNavBar)` finds nothing; `skipOffstage: false` still finds it — covered, not unmounted), then `Navigator.maybePop` and assert `BqNavBar.selectedIndex` is unchanged.

## Verification

- `flutter analyze` — **0 issues**.
- `flutter test` — **756 passed, 0 failed** (baseline 738; +18, zero tests deleted).
- `flutter gen-l10n` succeeds; `test/l10n` green (86 tests: ARB parity, template-only metadata, plural forms, no hardcoded strings).
- `git diff --quiet -- pubspec.yaml pubspec.lock` succeeds — no package added or removed (T-06-SC).
- `grep -c "Icons.settings_outlined"` returns 1 for each of the three screens; `grep -rnE "CircularProgressIndicator|plannerLoadError|retry"` and `grep -rnE "BqColors\.(risk|warn|calm)"` over `lib/features/settings/` both return zero; `grep -nE "EdgeInsets\.only\((left|right)"` over the three screens returns zero.
- `integration_test/` was NOT run (needs a device), per instruction.

## Deviations from Plan

### 1. [Rule 3 — blocking] The 44x44 tap target renders as a 48dp box

- **Found during:** Task 1, first test run.
- **Issue:** the plan's acceptance implies a 44x44 tap target, and `expect(tester.getSize(control), const Size(44, 44))` failed with `Size(48, 48)`. Material wraps an `IconButton` to `MaterialTapTargetSize.padded` regardless of `constraints`, so the S11/S12 recipe produces a 44dp constrained icon box inside a 48dp tap target.
- **Fix:** the widget is built exactly as the spec dictates (unchanged); the assertion became a floor (`>= 44` on both axes) plus scale-invariance across the 1.0/1.6/2.0 matrix, with the 48-vs-44 fact and its reason written into the `reason:` string. Forcing `tapTargetSize: shrinkWrap` to hit 44.0 exactly would have made the tap target *smaller* to satisfy a test.
- **Files:** `test/features/settings_screen_test.dart`, `test/features/stack_screen_test.dart`, `test/features/calendar_screen_test.dart`, `test/features/planner_screen_test.dart`.
- **Commits:** `4a3c409`, `6a7090a`.

### 2. [Rule 2 — missing critical coverage] The Settings font-size gate would have rejected the 18dp chevron

- **Found during:** Task 1.
- **Issue:** `settings source invariants > no hex color literal and no font size outside 25/15/10.5` greps `(?:fontSize|\bsize):\s*([\d.]+)` over `lib/features/settings/*.dart`. The back chevron's `size: 18` is an icon glyph box, not type, but the gate cannot tell them apart. Adding `18` to the type list would have licensed an 18px `Text` on the one screen whose type list is deliberately closed; naming the constant to dodge the regex would have hidden the value from the gate entirely.
- **Fix:** the gate now strips `Icon(...)` calls before the type sweep and checks their `size:` against a **second closed list** (`{18}`). Strictly stronger than before — icon sizes were previously ungated.
- **Files:** `test/features/settings_screen_test.dart`.
- **Commit:** `4a3c409`.

### 3. [Rule 3 — blocking] `hitTestable()` cannot express "the route covers the bar"

- **Found during:** Task 3.
- **Issue:** the first version of the shell test asserted `find.byType(BqNavBar).hitTestable()` — `findsNothing` while pushed, `findsOneWidget` after popping. The second half failed: `BqNavBar` is never hit-testable, because its centre point falls in the gap between a destination's icon and its label, so the first half was passing vacuously.
- **Fix:** replaced with the framework fact — an opaque full-screen route takes the shell offstage, so `find.byType(BqNavBar)` finds nothing while `find.byType(BqNavBar, skipOffstage: false)` still finds it (covered, not unmounted), together with `route.isCurrent` and `route.opaque`. The selected index is read through the offstage finder while the route is up.
- **Files:** `test/features/planner_screen_test.dart`.
- **Commit:** `bb90dc2`.

### 4. [Scope] One Task-2 acceptance criterion is not satisfiable in this plan

- `grep -rn "Icons.settings\b" lib/` returns exactly one match: `lib/app_shell.dart:66`, the nav destination's `selectedIcon`. That is the Settings **destination**, which this plan is explicitly forbidden from removing (Settings stays a tab for one more commit so it is never unreachable). The criterion belongs to plan 06-03, which deletes the destination. The gear itself is outlined-only, asserted per screen by `expect(find.byIcon(Icons.settings), findsNothing)` in all three suites.

### 5. [Structural, no behaviour change] Two test-harness additions

- `calendar_screen_test.dart`'s `makeContainer` gained an optional `prefs` parameter (mirroring the stack and planner suites) — mounting `SettingsScreen` reaches `LocaleController`, which reads `sharedPreferencesProvider` synchronously and throws unless overridden.
- `settings_screen_test.dart` and `planner_screen_test.dart` now import `test/support/locale_matrix.dart` **with `show bqTextScaleMatrix`**: both files predate the shared library and declare their own `overflowReason`, so a bare import would collide. The scale list is the part that must not be a per-file literal.
- No pre-existing assertion was weakened or deleted in any of the four suites. The one pre-existing case whose subject changed structurally (the Сьогодні title `Row` is now nested one level deeper inside a `Column`) needed no edit — it asserts on the row that owns the ring, which is still that row.

## Follow-ups for 06-03 (already in that plan, restated as handoff)

- Remove the Settings destination and `Icons.settings`/`Icons.settings_outlined` from `app_shell.dart`; the gear then becomes the only entry point and the duplicate `SettingsScreen` in the `IndexedStack` disappears (the shell push/pop test asserts a **delta** in mounted `SettingsScreen`s precisely so it survives that change).
- Rename `tabSettings` -> `settingsTitle`; three gear call sites and the Settings title read it, plus `settings_screen_test.dart`, `app_shell_test.dart`, `planner_screen_test.dart` and `stack_screen_test.dart`.
- Delete the planner's `‹ Сьогодні` control (it currently coexists with the new gear row) and reduce `settings_screen.dart`'s `bottom: 84` to `BqSpace.lg`.

## Known Stubs

None. Every control added is wired to a real navigation action and asserted end-to-end through the semantics tree.

## Self-Check: PASSED

- `lib/features/settings/settings_screen.dart` — FOUND (back control present)
- `lib/features/stack/stack_screen.dart`, `lib/features/calendar/calendar_screen.dart`, `lib/features/calendar/planner_screen.dart` — FOUND (one gear each)
- `lib/core/l10n/arb/app_uk.arb`, `app_en.arb` — FOUND (`navBack` in both)
- Commits `4a3c409`, `6a7090a`, `bb90dc2` — FOUND in `git log`
- `flutter analyze` 0 issues, `flutter test` 756/756 green — re-run after the final commit
