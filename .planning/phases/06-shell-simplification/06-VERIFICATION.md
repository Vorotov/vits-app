---
phase: 06-shell-simplification
verified: 2026-08-17T16:20:00Z
status: passed
score: 5/5 must-haves verified
behavior_unverified: 0
overrides_applied: 0
requirements:
  - id: NAV-01
    status: satisfied
  - id: NAV-02
    status: satisfied
  - id: NAV-03
    status: satisfied
  - id: UX-01
    status: satisfied
  - id: PLAN-05
    status: satisfied
warnings:
  - item: "Stale doc comment — lib/features/calendar/planner_screen.dart:123 describes the header as holding a 'back control', which no longer exists (it was the deleted page-swap chevron)."
    severity: warning
    fix: "Rewrite the _Header doc comment to read 'Fixed header, outside the scroll: settings gear, title, segment-dependent subtitle, segmented control.'"
  - item: "PLAN-05 copy gate is Ukrainian-only — test/l10n/planner_copy_safety_test.dart:70 limitVocabulary holds four uk stems ('межа','меж','перевищ','норма'). The gate loops over uk AND en, so English limit copy ('limit', 'exceeds', 'threshold', 'over the limit') is currently ungated. The shipped en copy is clean by inspection, not by gate."
    severity: warning
    fix: "Add en stems to limitVocabulary: 'limit', 'exceed', 'threshold', 'medical standard' (the last already in forbiddenVocabulary)."
  - item: "LoadVerdict is absent from lib/ but is NOT in the planner_invariants_test forbidden-identifier map (only verdictOf, week-verdict-chip, editorialLimit, comfortLoad, thresholdDash, _SlotPips, load-threshold, load-over-, week-pip- are). A re-introduced sealed LoadVerdict with a differently named resolver would not trip the gate."
    severity: info
    fix: "Add 'LoadVerdict': 'the verdict family, deleted' to the forbidden map at test/features/planner_invariants_test.dart:263."
---

# Phase 6: Shell & Simplification Verification Report

**Phase Goal:** The app's chrome matches how it is actually used — a slim bottom bar with Стек / Сьогодні / Календар, settings out of the way, one consistent add affordance — and the planner reports concurrent load without judging it.

**Verified:** 2026-08-17
**Status:** passed (5/5), with 2 warnings and 1 info
**Re-verification:** No — initial verification
**Method:** goal-backward. Every conclusion below was re-derived from `lib/` source, from `git show` of the pre-phase state, or from a command I executed myself. SUMMARY.md files were not used as evidence.

## Commands I Ran

| Command | Result |
| ------- | ------ |
| `flutter analyze` | **No issues found!** (ran in 2.5s) |
| `flutter test` (host only, no device) | **780 tests, All tests passed!** (~14s) |
| `git status --short` | clean apart from an untracked `claude_design_mockup/.thumbnail` |
| debt-marker scan over the 34 `.dart` files changed in `daa32aa..HEAD` | zero `TODO / FIXME / XXX / TBD / HACK / PLACEHOLDER` |

Integration tests were **not** run (no device work, per instruction). `integration_test/` was touched by 06-04 and its coverage is therefore unverified here.

---

## Goal Achievement

### Observable Truths

| # | Truth (ROADMAP Success Criterion) | Status | Gated by a test that would fail? |
| - | --------------------------------- | ------ | -------------------------------- |
| 1 | Bottom bar is visibly slimmer than v1's, renders Стек/Сьогодні/Календар, no clip or overflow at 1.0/1.6/2.0 in both locales | ✓ VERIFIED | Yes — painted-extent assertions, 6-cell bilingual × scale matrix |
| 2 | Сьогодні holds today's doses + week strip; Календар holds Цикли/Рік; no in-tab page swap and no back-interception anywhere | ✓ VERIFIED | Yes — source glob over all of `lib/`, plus deep-state survival tests |
| 3 | Settings opens from a top-right control on every tab and returns without disturbing the tab | ✓ VERIFIED | Yes — gear group on all three screens, tab-preservation on the real `AppShell` for destinations 0/1/2 |
| 4 | Floating add button on exactly the three tabs, opens the existing sheet, reachable by assistive tech, only add affordance on Stack | ✓ VERIFIED | Yes — per-destination presence, absence under pushed Settings, `SemanticsAction.tap` opens the sheet, `FilledButton` absence |
| 5 | Weekly concurrent load with no reference line, no verdict, no limit badge, no warning colour anywhere; educational disclaimer still on both segments | ✓ VERIFIED (copy half partially gated — see W-2) | Mostly — absence gates over `planner_*.dart` and the whole of `lib/`; disclaimer rendered-tree tests |

**Score: 5/5 truths verified.**

---

## Criterion 1 — The slim bottom bar (NAV-01)

**Verdict: MET.**

### The height formula, computed by hand from source

`lib/core/widgets/bq_nav_bar.dart:58,62,75-76`:

```dart
const double _navBarFixedExtent = 44;   // 8 top pad + 22 icon + 4 gap + 10 bottom pad
const double _navBarLabelExtent = 12;   // 10sp label × line-height 1.2
double navBarHeightFor(TextScaler scaler) =>
    _navBarFixedExtent + scaler.scale(_navBarLabelExtent);
```

My own arithmetic:

| Scale | 44 + scale × 12 | Content actually needed (22 icon + 4 gap + label line box) | Fits? |
| ----- | --------------- | --------------------------------------------------------- | ----- |
| 1.0 | **56.0** | 22 + 4 + 12 = 38 | yes, 18 slack |
| 1.6 | **63.2** | 22 + 4 + 19.2 = 45.2 | yes, 18 slack |
| 2.0 | **68.0** | 22 + 4 + 24 = 50 | yes, 18 slack |

The split is correct: `Icon` takes its size from `IconThemeData` and does not follow the text scaler, so only the label term is multiplied. The `Column` uses `mainAxisSize: MainAxisSize.min` inside a fixed-height `SizedBox`, so the slack is absorbed, not overflowed.

### "Visibly slimmer than v1's" — measured against the actual v1 code

`git show fce8ce6~1:lib/app_shell.dart` shows v1 was a Material `NavigationBar` (SDK default height 80dp) inside a `Container` with `padding: EdgeInsetsDirectional.only(top: 10, ...)` and a 1px `Border(top:)` that a `Container` decoration adds to layout. **v1 ≈ 91dp; v1.1 = 56dp.** Roughly a 38% reduction. This is not a claim I took from a SUMMARY — it is the diff.

### The tests that would fail

- `test/core/widgets/bq_nav_bar_test.dart:81` — `navBarHeightFor(TextScaler.noScaling) == 56.0` exactly.
- `:101` — `navBarHeightFor(linear(2.0)) == 68.0` exactly, with a reason naming 112 as the wrong answer (whole-extent scaling).
- `:182` — **painted extent**, not the function's return value: `tester.getSize(find.byType(BqNavBar)).height` compared to `navBarHeightFor(...)` at 1.0 and 2.0. This is the assertion the brief asked me to look for, and it exists. The doc comment at `bq_nav_bar.dart:128-135` records why `DecoratedBox` replaced `Container` — a `Container` border is padding and made the bar 57dp.
- `test/widget/app_shell_test.dart:331-385` — the bilingual matrix. For each of `bqLocaleMatrix = ['uk','en']` × `bqTextScaleMatrix = [1.0, 1.6, 2.0]` (`test/support/locale_matrix.dart:68,72`) it asserts, on the real shell:
  - `find.text(l10n.tabStack/tabToday/tabCalendar)` each `findsOneWidget` — in the *active* language, so a locale fallback fails here rather than passing on a bare render;
  - `tester.getSize(bar).height == navBarHeightFor(linear(scale)) + MediaQuery.padding.bottom` — painted extent at **1.6 as well**, which the widget-level test does not cover;
  - `tester.takeException() isNull` — no overflow;
  - Cyrillic-leak sweep while `en` is active.

ARB values confirmed directly: `app_uk.arb:4-6` → `Стек`, `Сьогодні`, `Календар`.

**Nothing to fix.**

---

## Criterion 2 — Сьогодні / Календар, and the page swap gone (NAV-02, NAV-03)

**Verdict: MET.** One stale doc comment (W-1).

### Content, from source

- `lib/features/calendar/today_screen.dart:65,76,485` — `dayDosesProvider(day)`, `const WeekStrip()` outside the scroll view, `DayBlockSection` in the body, `DayProgressRing` in the header. The `backToToday` escape hatch (`:235`) is live and is a *different* ARB key from `tabToday` (documented at `app_en.arb:13`).
- `lib/features/calendar/planner_screen.dart:204` — `BqSegmented(labels: [l10n.plannerSegYear, l10n.plannerSegCycles])`, i.e. the Рік/Цикли planner.
- `lib/app_shell.dart:48-58` — `IndexedStack` over exactly `StackScreen()`, `TodayScreen()`, `PlannerScreen()`, each wrapped in `TickerMode(enabled: index == _selectedIndex)`.

### The absence evidence I gathered myself

`grep -rn` over the whole of `lib/`:

| Identifier | Occurrences in `lib/` |
| ---------- | --------------------- |
| `CalendarPage` | **0** |
| `CalendarPageController` | **0** |
| `CalendarScreen` | **0** |
| `calendarPageProvider` | **0** |
| `PopScope` | **0** |
| `WillPopScope` | **0** |
| `editorialLimit` | **0** |
| `comfortLoad` | **0** |
| `LoadVerdict` | **0** |
| `thresholdDash` | **0** |

`lib/features/calendar/calendar_screen.dart` does not exist in the tree (confirmed by `find lib -name '*.dart'`). All ten identifiers survive only inside test *gate strings*, which is where they should be.

### The gate that would fail

`test/widget/shell_invariants_test.dart` globs **every** `.dart` file under `lib/` — generated `app_localizations*.dart` included, on purpose — and asserts a forbidden map containing `CalendarScreen`, `CalendarPage`, `calendarPageProvider`, `PopScope`, `tabSettings`, `NavigationBar(`, `NavigationDestination(`, `navigationBarTheme:`. Comments are **not** stripped, deliberately (`:8-11`), so a doc comment describing the deleted mechanism also fails. It self-checks the glob first (`:52` — `>= 20` files, `app_shell.dart` present), so it cannot pass vacuously. `:142` additionally asserts the shell mounts exactly the three screens, does **not** mount `SettingsScreen`, and keeps `TickerMode(`.

Runtime behaviour is separately gated in `test/features/planner_screen_test.dart`:
- "the selected planner SEGMENT / WEEK / MONTH survives leaving Календар and coming back"
- "the BROWSED DAY survives leaving Сьогодні and coming back"
- "a system back on a tab is NOT intercepted: it reaches the platform, changes no destination and throws nothing (NAV-03)"

All four passed in my run.

### W-1: stale doc comment

`lib/features/calendar/planner_screen.dart:123` reads:

```
/// Fixed header, outside the scroll: back control, title, segment-dependent
/// subtitle, segmented control.
```

There is no back control in `_Header` (I read `:120-215` in full — it is gear row, title, subtitle, `BqSegmented`). `grep -rn "arrow_back" lib/` returns only `settings_screen.dart:90` and `regimen_editor_screen.dart:223`. The "back control" was the deleted page-swap chevron. By this phase's own stated standard — `shell_invariants_test.dart:8-11`, "a comment about a deleted mechanism is a durable lie" — this is a defect the gate missed because it names a concept, not a forbidden identifier.

**Actionable:** rewrite `planner_screen.dart:123` to `/// Fixed header, outside the scroll: settings gear, title, segment-dependent subtitle, segmented control.`

---

## Criterion 3 — Settings from a top-right control on every tab (NAV-03)

**Verdict: MET.**

### From source

`grep -rn "settings_outlined" lib/` returns exactly three mounts, one per bar-reachable screen:

| Screen | Gear | Push |
| ------ | ---- | ---- |
| `lib/features/stack/stack_screen.dart` | `:104` | `:42` |
| `lib/features/calendar/today_screen.dart` | `:183` | `:55` |
| `lib/features/calendar/planner_screen.dart` | `:183` | `:52` |

All three are structurally identical: a dedicated `Row(mainAxisAlignment: MainAxisAlignment.end)` **above** the title (top-right, direction-neutral via `EdgeInsetsDirectional`), holding a `Semantics(button: true, label: l10n.settingsTitle, excludeSemantics: true, onTap: …)` around an `IconButton` with `BoxConstraints.tightFor(width: 44, height: 44)`. The push is `Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen()))` — a push, not a replace, which is what preserves the shell beneath.

`SettingsScreen` is not in the shell's `IndexedStack` (asserted at `shell_invariants_test.dart:154`), and `tabSettings` is gone from the ARB (asserted in the same forbidden map).

### The tests that would fail

Three parallel `group('the settings gear (S11)')` blocks — `stack_screen_test.dart:1222`, `today_screen_test.dart:3410`, `planner_screen_test.dart:2992` — each looping `['uk','en']`, each asserting: exactly one gear, outlined variant, box ≥ 44 **identical at 1.0/1.6/2.0**, the semantics node carries its own `SemanticsAction.tap`, activating that action pushes `SettingsScreen`, and the gear row contains zero `Text` descendants.

"Returns without disturbing the tab" is gated on the **real `AppShell`** (`planner_screen_test.dart:3118`+), parameterised over destinations 0, 1 and 2, reading `tester.widget<BqNavBar>(...).selectedIndex` before, during (offstage under the pushed route) and after the pop. All three cells passed.

**Nothing to fix.**

---

## Criterion 4 — One floating add button (UX-01)

**Verdict: MET.**

### From source

`grep -rn "FloatingActionButton\|BqAddFab\|showAddSupplementSheet" lib/` — the add affordance has exactly **one** mount point in the entire app: `lib/app_shell.dart:71`, `floatingActionButton: const BqAddFab()`, on the shell's **root** `Scaffold`. There is no `showFab` flag anywhere. Because `SettingsScreen` is a pushed route with its own `Scaffold`, "on exactly the three tabs and nowhere else" is structural rather than conditional.

`lib/core/widgets/bq_add_fab.dart:60-81` — `Semantics(button: true, label: context.l10n.addSupplement, excludeSemantics: true, onTap: _open)` wrapping the SDK `FloatingActionButton`. The `onTap` on the semantics node (not only on the button) is what makes it activatable by assistive tech under `excludeSemantics`. `_open` calls the **existing** `showAddSupplementSheet(context)` from `lib/features/stack/add_supplement_sheet.dart:40`, with a `_sheetOpen` re-entrancy guard so two activations cannot stack two modal routes.

Clearance is delegated to the `Scaffold`'s default end-float location measuring the real `bottomNavigationBar` — no hand-written offset.

### The Stack CTA is gone

`git show 980aee0` shows the deleted `SizedBox(width: double.infinity, child: FilledButton(... onPressed: showAddSupplementSheet ...))` and the removed `import add_supplement_sheet.dart` from `stack_screen.dart`. It sat in the **header**, above the list, so it was present in every list state — which means the empty-state absence gate covers all states. `grep` confirms `stack_screen.dart` no longer imports the sheet and contains no `FilledButton`.

Empty-state copy repointed in both locales:
- uk `app_uk.arb:21` — `Додайте першу добавку кнопкою + — з каталогу або вручну.`
- en `app_en.arb:93` — `Add your first supplement with the + button — from the catalog or manually.`

The `@description` records the reason it names the **action** rather than a corner ("bottom right"): it stays true under RTL and if the button moves.

### The tests that would fail

- `app_shell_test.dart:399-439` — presence asserted **per destination** (0, 1, 2), each `findsOneWidget` plus `isSemantics(isButton: true, label: l10n.addSupplement, hasTapAction: true)`. A single-tab test would have passed against a per-screen mount; this one would not.
- `app_shell_test.dart:441` — absence while the pushed Settings route is on top, in the widget tree **and** in the semantics tree (`find.semantics.byLabel(...)` `findsNothing`), and restoration on pop.
- `bq_add_fab_test.dart:160` — `SemanticsAction.tap` **opens the add-supplement sheet**; `:181` — a second activation while open does not push a second sheet.
- `app_shell_test.dart:486-519` — clearance matrix, `uk`/`en` × 1.0/1.6/2.0: `fab.bottom <= bar.top`, and the gap is monotonically non-shrinking as the bar grows (which is what catches a hardcoded offset from the outside).
- `app_shell_test.dart:521` — source gate: no literal vertical offset written in `app_shell.dart` or `bq_add_fab.dart` (comment lines excluded).
- `stack_screen_test.dart:446-459` — the FAB matched by **widget type and semantics node**, never by the `addSupplement` label (which is now a semantics label, not painted text), plus `find.byType(FilledButton) findsNothing` on the Стек screen.

That last point is worth naming as good practice: retargeting the finder to the label would have kept the test green for the wrong reason. It was deliberately avoided (T-06-10).

**Nothing to fix.**

---

## Criterion 5 — Load without judgement (PLAN-05)

**Verdict: MET.** Copy half is partially gated (W-2); one identifier missing from the gate (I-1).

### The chart, read in full

`lib/features/calendar/planner_load_chart.dart` — I read all 363 lines:

- **No painter at all.** `grep -rn "CustomPaint" lib/features/calendar/` returns hits only in `day_progress_ring.dart` (the Today ring) and `planner_gantt.dart` (cycle bars + hatch swatch). The load chart is plain widgets. There is nowhere for a reference line to be drawn.
- **One bar colour at every height** — `:347`, `color: BqColors.loadBar`, unconditional. No band lookup, no ternary on load.
- **No over-segment.** `:280-281` — `mainHeight = (load / scheduledCount * _barFullHeight).roundToDouble()`, with no cap, clamp or clip, because `load <= scheduledCount` holds by construction (both derived from the same collection).
- **No denominator in the semantics label.** `:298` — `l10n.substancesCount(load)`, a bare count. The comment states why: `"4 з 4 речовин"` would be a tautology with no limit to measure against.
- **The scale is stated in words** — `:193`, `l10n.loadScaleCaption` (uk `повний стовпчик — увесь стек`, en `full bar = your whole stack`) sits in the axis row's centre slot, replacing the deleted `loadAxisLegend` which named an editorial limit.

### The week detail card

`lib/features/calendar/planner_week_detail.dart:78-95` — the header `Row` now holds **exactly one** `Expanded` child (the date range); the trailing verdict chip is deleted, not shrunk. `:97-100` renders `l10n.substancesCount(week.load)` with no denominator and no free-slot half. No pips.

### Absence, from my own greps

- `grep -rn "BqColors\.\(risk\|warn\|calm\)" lib/features/calendar/planner_*.dart` → **NONE**.
- `thresholdDash`, `editorialLimit`, `comfortLoad`, `LoadVerdict` → **0 in all of `lib/`** (including `tokens.dart` — the token is deleted, not merely unused).
- `grep -in "limit\|ліміт\|норма\|verdict\|threshold\|порог" lib/core/l10n/arb/app_uk.arb` → **no matches at all**.
- Grepping the en ARB planner keys for `limit|exceed|threshold|safe|normal` returns exactly one line, `plannerDisclaimer`, and only because it contains the substring "over **time**". No English limit copy ships.

`git show fdf0078` confirms 16 ARB keys were deleted from both locales (`limitBadge`, `loadAxisLegend`, `verdictComfort/Limit/OverLimit`, `weekNoteComfort/Limit/OverLimit`, `weekFreeSlots`, `weekNoFreeSlots`, `weekLoadLabel`, `substancesLimitCount`, `slotsCount`, `cyclesCount`, `monthMeta`, `yearFootnote`), 171 → 155 per file.

### The disclaimer still renders

`app_uk.arb:148` — `Планувальник показує, як ваші цикли накладаються в часі. Освітній матеріал, не медична порада.`
`app_en.arb:745` — the English equivalent.

It denies nothing and names no limit, and it still ends with the app-wide `disclaimerEducational` sentence verbatim.

Rendered-tree gates that would fail (`test/features/planner_screen_test.dart`):
- `:550` — the disclaimer closes **both** segments, same key.
- `:578` — it is the **last** element of both bodies.
- `:622` — it still renders on the no-supplements body of both segments.
- `test/features/planner_invariants_test.dart:516` — the same, over the real tree, plus PLAN-04 vocabulary.
- `test/l10n/planner_copy_safety_test.dart:254` — the disclaimer is non-empty, strictly longer than `disclaimerEducational`, and *contains* it.

### The absence gate

`test/features/planner_invariants_test.dart:255-280` globs `lib/features/calendar/planner_*.dart` (self-checking `>= 8` files first) and forbids `week-verdict-chip`, `week-pip-`, `_SlotPips`, `load-threshold`, `load-over-`, `thresholdDash`, `editorialLimit`, `comfortLoad`, `verdictOf`. A sibling gate at `:225` forbids `BqColors.(risk|warn|calm)` in those same files — deliberately scoped to `planner_*` because the Today surfaces (`dose_row`, `day_block_section`, `day_progress_ring`, `week_strip`) legitimately use state colours, and a directory-wide glob would be red on correct code. The scoping rationale is written into the test and I agree with it.

`test/l10n/planner_copy_safety_test.dart:233` — "carries NO limit vocabulary at all, in any key, including the disclaimer (PLAN-05)", with the old `норма` negation exemption **deleted** along with the sentence that needed it.

### W-2: the copy gate is Ukrainian-only

`test/l10n/planner_copy_safety_test.dart:70`:

```dart
const limitVocabulary = <String>['межа', 'меж', 'перевищ', 'норма'];
```

`main()` loops `for (final tag in const ['uk', 'en'])` (`:175`) and runs the PLAN-05 gate against **both** locales — but the term list holds only Ukrainian stems. English limit copy (`limit`, `exceeds`, `threshold`, `normal range`) would pass the gate untouched. `forbiddenVocabulary` does carry four English entries (`overdose`, `fat-soluble`, `Shift cycle`, `Compare weeks`, `medical standard`) but none of them is a *limit* word.

The shipped English copy is clean — I checked it directly — so the criterion is MET in fact. It is the *enforcement* that is asymmetric, and PLAN-05 is exactly the kind of requirement that regresses through copy.

**Actionable:** extend `limitVocabulary` with `'limit'`, `'exceed'`, `'threshold'`. (`'normal'` risks false positives; `'medical standard'` is already covered.)

### I-1: `LoadVerdict` is not in the forbidden map

`git show fdf0078` confirms the sealed `LoadVerdict` family was deleted from `planner_view_model.dart`, and it is at zero occurrences in `lib/`. But the forbidden map at `planner_invariants_test.dart:263-268` lists `verdictOf` (the resolver) and not `LoadVerdict` (the type). A re-introduced verdict type with a differently named resolver would slip through the identifier gate — though the judgement-colour gate and the copy gate would likely still catch it downstream.

**Actionable (low priority):** add `'LoadVerdict': 'the verdict family, deleted'` to that map.

---

## Requirements Coverage

| Requirement | Text (from `.planning/REQUIREMENTS.md`, Milestone v1.1) | Status | Evidence |
| ----------- | ------------------------------------------------------ | ------ | -------- |
| **NAV-01** | Slim custom bar, 56dp base (down from Material's fixed 80dp), height scales with the text scaler, never clips at 1.0/1.6/2.0 | ✓ SATISFIED | `navBarHeightFor` = 44 + scale×12 → 56 / 63.2 / 68, hand-computed; painted extent asserted at all three scales × both locales; v1 measured at ≈91dp from `git show fce8ce6~1` |
| **NAV-02** | Three tabs: Стек, Сьогодні (today's doses + week-strip browsing), Календар (Цикли/Рік planner) | ✓ SATISFIED | `app_shell.dart:48-58` + `:77-99`; `today_screen.dart:65,76,485`; `planner_screen.dart:204`; ARB `Стек/Сьогодні/Календар` |
| **NAV-03** | Settings reachable from a top-right control on all three tabs, no longer a tab; the v1 in-tab planner page-swap mechanism is removed | ✓ SATISFIED | Three identical gear rows; `SettingsScreen` absent from the `IndexedStack`; `CalendarScreen`/`CalendarPage`/`calendarPageProvider`/`PopScope`/`tabSettings` all at zero occurrences in `lib/`, gated by a whole-`lib/` glob |
| **UX-01** | Floating add-supplement button on all three tabs and nowhere else; Stack's full-width add button removed and its empty state repointed | ✓ SATISFIED | Single mount at `app_shell.dart:71`; per-destination presence + absence-under-Settings tests; `git show 980aee0` deletion of the `FilledButton`; `emptyStackBody` rewritten in both locales to name the `+` action |
| **PLAN-05** | Planner presents concurrent weekly load without any limit, threshold, reference line, verdict or warning colour; the educational disclaimer remains | ✓ SATISFIED (enforcement gap W-2) | Load chart has no painter, one bar colour, no over-segment; zero judgement colours in `planner_*`; 16 limit keys deleted; `plannerDisclaimer` rendered last on both segments and on the empty/error surfaces |

**Orphaned requirements:** none. `NOTIF-01..04` are mapped to Phase 7, not this phase.

---

## Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
| ---- | ---- | ------- | -------- | ------ |
| `lib/features/calendar/planner_screen.dart` | 123 | Doc comment names a "back control" that does not exist | ⚠️ Warning | Misleads the next reader; violates this phase's own stated comment-accuracy standard |
| `test/l10n/planner_copy_safety_test.dart` | 70 | `limitVocabulary` is uk-only while the gate runs on uk **and** en | ⚠️ Warning | The English half of PLAN-05's copy guarantee is unenforced |
| `test/features/planner_invariants_test.dart` | 263 | `LoadVerdict` missing from the forbidden-identifier map | ℹ️ Info | A re-introduced verdict type could evade the identifier gate |

Zero `TODO / FIXME / XXX / TBD / HACK / PLACEHOLDER` markers across the 34 `.dart` files changed in this phase. Zero analyzer issues.

---

## Behavioural Spot-Checks

| Behaviour | Evidence | Status |
| --------- | -------- | ------ |
| Nav bar paints its computed extent, not a constant | `tester.getSize(BqNavBar).height == navBarHeightFor(scaler) + inset`, 6 matrix cells | ✓ PASS |
| Tab switch preserves deep state (segment, week, month, browsed day) | 4 named tests on the real shell | ✓ PASS |
| System back on a tab is not intercepted | named test, NAV-03 | ✓ PASS |
| Gear push/pop returns to the same destination | 3 tests (destinations 0/1/2) on the real `AppShell` | ✓ PASS |
| FAB activation via `SemanticsAction.tap` opens the sheet | `bq_add_fab_test.dart:160` | ✓ PASS |
| Second FAB activation does not stack a second sheet | `bq_add_fab_test.dart:181` | ✓ PASS |
| FAB clears the bar and the gap never shrinks as the bar grows | clearance matrix, uk/en × 3 scales | ✓ PASS |
| Disclaimer is the last element of both planner segments | `planner_screen_test.dart:578` | ✓ PASS |

All 780 host tests pass; I ran the suite twice with identical results.

---

## Gaps Summary

**No blockers. The phase goal is achieved.**

Every one of the five success criteria is true in the code, and — importantly, since the brief asked me to distinguish these — every one of the five is also *gated by a test that would fail if it were violated*. The two strongest cases are the ones built on absence: `shell_invariants_test.dart` globs the whole of `lib/` (generated l10n included, comments not stripped) and `planner_invariants_test.dart` globs `planner_*.dart`, both self-checking their globs so they cannot pass vacuously. I reproduced both by hand with `grep` and got zero hits for all ten deleted identifiers.

Three items are worth closing, none of which blocks Phase 7:

1. **(warning)** `lib/features/calendar/planner_screen.dart:123` — rewrite the `_Header` doc comment; it still names a "back control" from the deleted page swap. This phase's own gate documentation calls a comment about a deleted mechanism "a durable lie"; this one survived only because it names a concept rather than an identifier.
2. **(warning)** `test/l10n/planner_copy_safety_test.dart:70` — add `'limit'`, `'exceed'`, `'threshold'` to `limitVocabulary`. The gate already runs against `en`; it just has nothing English to look for. The shipped English copy is clean today, so this is a regression guard, not a defect.
3. **(info)** `test/features/planner_invariants_test.dart:263` — add `'LoadVerdict'` to the forbidden-identifier map alongside `verdictOf`.

**Out of scope for this verification:** `integration_test/` was modified by plan 06-04 and was not run (no device work). Its correctness is unverified here.

---

_Verified: 2026-08-17_
_Verifier: Claude (gsd-verifier), goal-backward, evidence re-derived from source and executed commands_
