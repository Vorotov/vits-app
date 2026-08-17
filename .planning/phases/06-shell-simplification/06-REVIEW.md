---
phase: 06-shell-simplification
reviewed: 2026-08-17T00:00:00Z
depth: deep
diff_base: 98ffc92..HEAD
files_reviewed: 38
files_reviewed_list:
  - integration_test/data03_loop_test.dart
  - integration_test/l10n_device_test.dart
  - lib/app_shell.dart
  - lib/core/l10n/arb/app_en.arb
  - lib/core/l10n/arb/app_uk.arb
  - lib/core/l10n/gen/app_localizations.dart
  - lib/core/l10n/gen/app_localizations_en.dart
  - lib/core/l10n/gen/app_localizations_uk.dart
  - lib/core/theme/theme.dart
  - lib/core/theme/tokens.dart
  - lib/core/widgets/bq_add_fab.dart
  - lib/core/widgets/bq_nav_bar.dart
  - lib/features/calendar/calendar_providers.dart
  - lib/features/calendar/planner_load_chart.dart
  - lib/features/calendar/planner_month_detail.dart
  - lib/features/calendar/planner_screen.dart
  - lib/features/calendar/planner_view_model.dart
  - lib/features/calendar/planner_week_detail.dart
  - lib/features/calendar/planner_year_grid.dart
  - lib/features/calendar/today_screen.dart
  - lib/features/settings/settings_screen.dart
  - lib/features/stack/add_supplement_sheet.dart
  - lib/features/stack/stack_screen.dart
  - test/core/widgets/bq_add_fab_test.dart
  - test/core/widgets/bq_nav_bar_test.dart
  - test/features/planner_invariants_test.dart
  - test/features/planner_screen_test.dart
  - test/features/planner_view_model_test.dart
  - test/features/settings_screen_test.dart
  - test/features/stack_screen_test.dart
  - test/features/today_screen_test.dart
  - test/l10n/no_hardcoded_strings_test.dart
  - test/l10n/planner_copy_safety_test.dart
  - test/l10n/plurals_test.dart
  - test/support/locale_matrix.dart
  - test/theme/theme_test.dart
  - test/widget/app_shell_test.dart
  - test/widget/shell_invariants_test.dart
findings:
  critical: 2
  warning: 6
  info: 5
  total: 13
status: issues_found
---

# Phase 6: Code Review Report

**Reviewed:** 2026-08-17
**Depth:** deep (cross-file: import graph, deleted-symbol trace, Flutter SDK source, empirical probes)
**Files Reviewed:** 38 (23 `lib/`, 13 `test/`, 2 `integration_test/`)
**Status:** issues_found

## Summary

Baseline health is good and I could not break most of what the phase claims.
`flutter analyze` is clean, `flutter test` is 780/780 green, ARB parity holds at
155/155 keys in both locales, and every deleted symbol in the 06-PATTERNS
"Deletion inventory" (A–E) resolves nowhere in `lib/`, `test/` or
`integration_test/` except inside gates that name it as forbidden. Specifically
verified and **not** defective:

- **No dangling references.** `editorialLimit`, `comfortLoad`, `verdictOf`,
  `LoadVerdict`, `thresholdDash`, `calendarPageProvider`, `CalendarPage`,
  `CalendarScreen`, `tabSettings`, `monthMeta`, `yearFootnote` and the 16 ARB
  keys are gone from production code. `navigationBarTheme` is removed.
- **The load-chart division cannot fault.** `scheduledCount == rows.length` and
  `_surface`'s empty gate is `rows.isEmpty`, so `scheduledCount == 0` is
  unreachable inside the widget; `load <= scheduledCount` holds because both are
  counted off the same `loadRows` list. No NaN, no clamp needed.
- **No surviving warning colour or threshold.** `BqColors.(risk|warn|calm)`
  returns nothing across `lib/features/calendar/planner_*.dart`; the year-grid
  and both chips are unconditional.
- **State survival.** Nothing that the page swap preserved is lost. The three
  planner selections are kept alive by `ref.listen` in a screen that never
  unmounts, `_selectedIndex` is untouched by the Settings push, and `_DayBody`'s
  `TickerMode` gate, `_held`/`_heldDay` machinery and `nowMinutes` cache all moved
  intact.
- **The FAB is structurally absent on Settings**, and its nav-bar clearance is
  measured by `Scaffold` (no hardcoded offset anywhere).
- **Icon size does not follow the text scaler** (`Icon.applyTextScaling`
  defaults to `false`, `bqTheme()` sets no `iconTheme`), so the split-extent
  formula's premise is sound and the bar has ~18dp of slack at every scale.
- **Integration tests are not broken by `IndexedStack`** — I probed this: the
  default `skipOffstage: true` finders do skip non-selected `IndexedStack`
  children on Flutter 3.47, so `find.text('Сьогодні')` and
  `find.byIcon(Icons.settings_outlined)` stay single-match.

What the phase did **not** get right: two contracted UI behaviours are silently
absent at runtime while every test passes, and the "a wrong rationale is a
durable lie" standard the phase applies to itself is violated in four places by
the phase's own commits.

---

## Critical Issues

### CR-01: The nav bar's press feedback never renders — `InkResponse` splashes are painted behind the bar's own opaque fill

**File:** `lib/core/widgets/bq_nav_bar.dart:136-140`, `:188-194`

**Issue:** `BqNavBar` is `DecoratedBox(surfaceAlt) > Padding > SafeArea > SizedBox > Semantics > Row > Expanded > InkResponse`. There is **no `Material` widget anywhere inside `BqNavBar`** — I verified this empirically (`find.descendant(of: BqNavBar, matching: Material)` returns 0). `InkResponse` therefore registers its ink feature on the nearest ancestor `Material`, which is the one `Scaffold` wraps its entire layout in (`scaffold.dart:3236`, `color: scaffoldBackgroundColor`); the probe reports that ancestor as the full-screen `800×600` Material filled with `BqColors.paper`. `_RenderInkFeatures.paint` (`material.dart:621-635`) paints ink features **first** and then calls `super.paint` for the child subtree — so the splash is drawn under the whole child tree, including this bar's fully opaque `surfaceAlt` `DecoratedBox`. The ripple is invisible on every destination, at every scale.

This is not cosmetic drift, it is the failure of a contract the code argues for at length. `bq_nav_bar.dart:26-31` states press feedback is `InkResponse` "chosen deliberately over the load chart's opacity idiom … tapping the ALREADY-SELECTED destination must still feel like it registered, which an opacity change tied to selection cannot express. Not to be 'unified' with the chart later." 06-UI-SPEC S8 records the same decision. The v1 `NavigationBar` supplied its own `Material`, so this regressed with the hand-built replacement. `bq_nav_bar_test.dart:317-335` asserts only that the callback fires — it cannot see paint — so nothing catches it.

**Fix:** put a transparent `Material` between the fill and the ink, so the splash lands on a layer above `surfaceAlt`:

```dart
return DecoratedBox(
  decoration: const BoxDecoration(
    color: BqColors.surfaceAlt,
    border: Border(top: BorderSide(color: BqColors.hairline, width: 1)),
  ),
  // The InkResponses below need a Material to paint into. Without one they
  // reach the Scaffold's root Material, whose ink layer paints BEHIND this
  // DecoratedBox's opaque fill — a ripple nobody can see (CR-01).
  child: Material(
    type: MaterialType.transparency,
    child: Padding(
      padding: const EdgeInsetsDirectional.only(start: 22, end: 22),
      child: SafeArea(top: false, child: /* … unchanged … */),
    ),
  ),
);
```

`MaterialType.transparency` adds no colour, no elevation and no layout, so the 56dp extent assertion in `bq_nav_bar_test.dart:182-192` still holds. Add a regression test that a tap-down produces an `InkResponse` splash on a Material **inside** `BqNavBar` (`expect(find.descendant(of: find.byType(BqNavBar), matching: find.byType(Material)), findsOneWidget)` is the cheap version).

---

### CR-02: `loadScaleCaption` is truncated on every phone, in both locales — the caption that exists to keep the neutralized chart honest is unreadable

**File:** `lib/features/calendar/planner_load_chart.dart:180-203`, `:212-235`

**Issue:** The axis row is `Row(children: [_AxisLabel, _AxisLabel, _AxisLabel])` and `_AxisLabel` is `Expanded > Text(maxLines: 1, overflow: TextOverflow.ellipsis)`. Three equal thirds. On a 390pt device the chart's inner width is `390 − 20 − 20` (screen padding) `− 14 − 14` (card padding) `= 322`, so the centre slot is **107.3 logical pixels**. I measured the caption in that exact layout:

```
uk caption="повний стовпчик — увесь стек" chars=28 slotWidth=107.33 intrinsic=280.0 ellipsized=true
en caption="full bar = your whole stack"  chars=27 slotWidth=107.33 intrinsic=270.0 ellipsized=true
```

(280/270 is the test font at 1:1 em; with the real JetBrains Mono the 0.6 em advance gives ≈168 px uk / ≈162 px en — still over 107 px, still ellipsized, and it gets monotonically worse at textScaler 1.6 and 2.0.) The user sees roughly `повний стовпчик …` / `full bar = your…`. Meanwhile the two date labels each occupy a third and use less than half of it.

06-UI-SPEC D-4 makes this caption load-bearing: "removing `loadAxisLegend` would leave a **self-scaling chart with an invisible ceiling** — a reader who cannot see the denominator will invent one, and the most likely invention is a limit … This is the one place where deleting more copy would make the screen *less* honest." UI consideration #21 lists "`loadScaleCaption` is legible at mono 10 in both locales" as a sign-off condition. As submitted, the phase ships a self-scaling chart whose ceiling is *still* invisible — the exact state D-4 argued against — with the added cost of a dangling ellipsis. No test covers it: `grep -rn loadScaleCaption test/` matches only the copy-safety key inventory; every render-matrix test passes precisely *because* `overflow: ellipsis` suppresses the layout exception.

**Fix:** the caption must not compete with the date bounds for width. Give it its own full-width row under them, which also matches the mockup's "axis then legend" reading order:

```dart
Row(
  children: [
    _AxisLabel(text: startLabel, align: TextAlign.start),
    _AxisLabel(text: endLabel,   align: TextAlign.end),
  ],
),
const SizedBox(height: 2),
Text(
  l10n.loadScaleCaption,
  textAlign: TextAlign.center,
  maxLines: 2,               // it is a caption, not a data label — it may wrap
  style: BqText.mono(
    size: _axisSize, weight: FontWeight.w400,
    color: BqColors.textFaint, letterSpacing: 0,
  ),
),
```

If the three-slot row must be kept for mockup fidelity, size the two date labels to their intrinsic width and give the caption the remainder (`Flexible(flex: …)` / `IntrinsicWidth`), and drop `maxLines: 1` on the caption. Either way, add a render test that asserts the caption's `RenderParagraph.didExceedMaxLines` is `false` at 390pt × {1.0, 1.6} × {uk, en} — a truncated ceiling statement is the defect, and only a measured test will keep it fixed.

---

## Warnings

### WR-01: `BqAddFab`'s second-sheet guard can latch permanently

**File:** `lib/core/widgets/bq_add_fab.dart:50-56`

**Issue:**

```dart
bool _sheetOpen = false;

void _open() {
  if (_sheetOpen) return;
  _sheetOpen = true;
  showAddSupplementSheet(context).whenComplete(() => _sheetOpen = false);
}
```

The flag is raised *before* the call and is only ever lowered by the `whenComplete` callback that the same expression registers. Any synchronous throw out of `showAddSupplementSheet` — `showModalBottomSheet` asserts on a missing `Navigator`/`Overlay`, and `Navigator.of` throws when the FAB's context is momentarily out of a navigator during a route swap — skips the registration and leaves `_sheetOpen == true` for the widget's whole lifetime. `BqAddFab` lives on the root `Scaffold` and is never disposed, so the app's only add affordance is silently dead until relaunch, with no state change a user or a test could observe. `bq_add_fab_test.dart:181-203` exercises only the happy double-tap path.

**Fix:** make the reset unconditional on the failure edge.

```dart
void _open() {
  if (_sheetOpen) return;
  _sheetOpen = true;
  try {
    showAddSupplementSheet(context).whenComplete(() => _sheetOpen = false);
  } catch (_) {
    // A guard that can latch is worse than no guard: the FAB is the app's
    // ONLY add affordance and nothing here would ever lower the flag again.
    _sheetOpen = false;
    rethrow;
  }
}
```

### WR-02: `_YearPeakChip`'s class doc contradicts its own body — it still describes the deleted limit comparison

**File:** `lib/features/calendar/planner_screen.dart:404-407`

**Issue:** The doc reads "The Рік peak chip: the densest month of the year **against the limit**. / Same geometry as the Цикли summary chip, **deliberately NOT the same comparison** — see the banding comment below (DECIDED-6)." The banding comment it points at was deleted by 06-05/06-06, and the surviving inline comment at `:440-443` says the opposite in as many words: "no longer 'the same geometry, a different comparison': there is no comparison left for the two to disagree about, so the DECIDED-6 asymmetry is moot". A reader hitting the class doc first is told the chip encodes a judgement it no longer makes. This is the same "durable lie" class `shell_invariants_test.dart:6-11` exists to prevent — that gate only greps page-swap symbols, so it does not see this.

**Fix:** rewrite the class doc to match `:440-443`, e.g. "The Рік peak chip: which month of the year is densest, and how many supplements overlap there. A plain count on the app's neutral chip — the same treatment as the Цикли summary chip, because there is no longer a limit for the two to be asymmetric about (06-UI-SPEC S13)."

### WR-03: `_Header`'s doc on the planner still announces a "back control" that was deleted with the page swap

**File:** `lib/features/calendar/planner_screen.dart:123-124`

**Issue:** "Fixed header, outside the scroll: **back control**, title, segment-dependent subtitle, segmented control." The `‹ Сьогодні` control was deleted (deletion inventory A) and the slot now holds the settings gear. The file's own library doc at `:5-6` was correctly updated to say "the settings gear row"; this one was not, so the file describes its header two different ways ten lines apart.

**Fix:** `/// Fixed header, outside the scroll: the settings gear row, title, segment-dependent subtitle, segmented control.`

### WR-04: `settings_screen.dart`'s library doc still calls the screen a tab and still asserts the deleted editorial limit

**File:** `lib/features/settings/settings_screen.dart:1`, `:6-7`, `:20`

**Issue:** Three false statements in one doc block, all falsified by this phase:
- `:1` — "Settings **tab** — full S7 contract" — Settings is a pushed route since 06-03 (NAV-03, S12); the body of the same file documents this correctly at `:44` and `:52-61`.
- `:6-7` — "no educational disclaimer (PLAN-04 binds it to planner screens, **where an editorial limit is actually asserted**)" — no editorial limit is asserted anywhere any more; PLAN-05 deleted the entire layer, and the rewritten `plannerDisclaimer` asserts none.
- `:20` — "matching Stack, **Calendar** and Planner" — `CalendarScreen` was deleted; the three peers are Стек, Сьогодні and Календар.

**Fix:** rewrite the block. The disclaimer rationale in particular must be re-stated on its true basis (PLAN-04 binds the disclaimer to the planner surfaces; Settings is not one), not on a limit that no longer exists.

### WR-05: `_navBarFixedExtent`'s doc describes padding the widget does not apply

**File:** `lib/core/widgets/bq_nav_bar.dart:54-58` (with `:195-198`)

**Issue:** The constant is documented as "8px top pad + the 22px icon box + the 4px icon-to-label gap + 10px bottom pad". The widget applies **no** vertical padding at all: the destination `Column` is `mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min` inside a `SizedBox(height: navBarHeightFor(scaler))`, so the 18dp of slack at scale 1.0 (56 − 22 − 4 − 12) is split evenly 9/9, not 8/10, and at scale 2.0 it is 15/15. The total is correct; the decomposition — the thing anyone editing these constants will reason from — is not, and it silently drops the mockup's intended 8/10 asymmetry.

**Fix:** either implement the stated padding (`Padding(padding: EdgeInsetsDirectional.only(top: 8, bottom: 10))` around the `Column`, with `MainAxisAlignment.start`) or, preferably, correct the doc to describe what the code does:

```dart
/// The part of the bar's height that does NOT follow the text scale: the 22px
/// icon box, the 4px icon-to-label gap, and 18px of vertical slack that the
/// centred Column distributes evenly above and below the content. v1's
/// `top: 10` padding on the shell's outer Container is folded in here …
```

### WR-06: The Today header now ends in dead space on today — the exact pattern S13 forbids on the week-detail card

**File:** `lib/features/calendar/today_screen.dart:212-243`

**Issue:** `const SizedBox(height: BqSpace.sm)` at `:212` is unconditional, but the `Wrap` it separates from the subtitle now has exactly one conditional child — `if (!isToday) TextButton(backToToday)` at `:229-241`. The `plannerTitle` action that used to make the `Wrap` unconditionally non-empty was deleted by this phase. So in the default state of the app's most-used screen (viewing today), the header renders subtitle → 8px gap → an empty `Wrap` → nothing. 06-UI-SPEC S13 states the rule for the analogous case explicitly ("The card must not end in dead space … The name-chip `Wrap` and its 14px top margin render only when there is at least one entry"), and consideration #16 makes it a truth; the same reasoning was not carried across to the header the same phase emptied.

**Fix:** bind the gap to the content it separates.

```dart
if (!isToday) ...[
  const SizedBox(height: BqSpace.sm),
  Wrap(
    spacing: BqSpace.sm,
    runSpacing: BqSpace.sm,
    children: [
      TextButton(
        onPressed: () => ref.read(selectedDayProvider.notifier).followToday(),
        child: Text(l10n.backToToday, style: /* … */),
      ),
    ],
  ),
],
```

The `Wrap`-not-`Row` rationale at `:213-221` still applies and should stay; only the gap moves inside the condition.

---

## Info

### IN-01: The gear control is copy-pasted three times, verbatim

**Files:** `lib/features/stack/stack_screen.dart:41-43` + `:76-111`, `lib/features/calendar/today_screen.dart:54-56` + `:156-190`, `lib/features/calendar/planner_screen.dart:51-53` + `:156-190`

**Issue:** `_openSettings` (3 identical lines) and the gear `Row` (a 35-line `Row > Semantics > IconButton` block, byte-identical apart from one comment paragraph) exist three times. 06-UI-SPEC S11 justifies the shape as "one reviewable pattern covers all three instead of three bespoke placements" — but the implementation is three copies, so a fix to the semantics wiring or the 44×44 constraint has to be made three times and can drift. `test/features/planner_screen_test.dart` and `stack_screen_test.dart` each re-assert the same three properties independently.

**Fix:** extract `BqSettingsGearRow` into `lib/core/widgets/` next to `BqNavBar` and `BqAddFab`, taking nothing but `BuildContext` (it already reads its label from `context.l10n`). One widget, one test file, three call sites of one line each.

### IN-02: `'межа'` is dead in the copy gate — `'меж'` already matches it

**File:** `test/l10n/planner_copy_safety_test.dart:55-56`, `:70`

**Issue:** `_contains` is case-insensitive for lowercase terms, and `'меж'` is a prefix of `'межа'`, so line 55 can never produce a hit that line 56 does not. The same redundancy is copied into `limitVocabulary` at `:70`. Harmless, but a forbidden-vocabulary list whose entries are not all reachable invites the next editor to assume the others are decorative too.

**Fix:** drop `'межа'` and keep `'меж'` with its comment merged: `'меж', // межа / межі / межу / перевищення межі — every declined form`.

### IN-03: The `PopScope` gate is broader than the mechanism it protects

**File:** `test/widget/shell_invariants_test.dart:75-78`

**Issue:** The gate forbids the bare substring `PopScope` anywhere under `lib/`, comments included, with the stated reason "the back-interception. System back on a tab must behave exactly as it does in any single-screen app". That reason is about the **shell**, but the scope is the whole app: a future unsaved-changes guard on `RegimenEditorScreen` — a legitimate and likely need — trips a gate whose failure message will describe a page swap that no longer exists.

**Fix:** scope the needle to the files that could reintroduce the interception (`app_shell.dart`, `today_screen.dart`, `planner_screen.dart`), or keep the app-wide scan but say so in the reason: "no `PopScope` may exist today; if a future editor guard needs one, add its file to this gate's allowlist with a stated reason rather than deleting the gate."

### IN-04: `navBarHeightFor` scales a line box as if it were a font size

**File:** `lib/core/widgets/bq_nav_bar.dart:62`, `:75-76`

**Issue:** `_navBarLabelExtent = 12` is documented as "the 10sp label's line box (10 x line-height 1.2)", and the height is `44 + scaler.scale(12)`. `TextScaler.scale` takes a *font size*; for the non-linear platform scalers Android 14+ supplies, `scale(12)` is not `1.2 × scale(10)` (larger sizes are compressed more), so the reserved extent drifts below the real line box exactly when the scale is largest. The 18dp of slack in the current layout absorbs the difference, so this is not a live clip today — but it makes the equality `bq_nav_bar_test.dart:123-125` asserts ("10 × 1.2 is the 12px line box navBarHeightFor reserves") true only for linear scalers, which is the only kind the test uses.

**Fix:** `double navBarHeightFor(TextScaler scaler) => _navBarFixedExtent + scaler.scale(_navBarLabelFontSize) * _navBarLabelHeight;` with `_navBarLabelFontSize = 10` and `_navBarLabelHeight = 1.2` — the same two numbers the `TextStyle` at `:219-220` uses, so they can no longer disagree.

### IN-05: Stale "Settings tab" wording in the retargeted device test

**File:** `integration_test/l10n_device_test.dart:144`, `:150`, `:284`, `:489`

**Issue:** The phase updated one `_pumpUntil` message to "the pushed Settings route" (`:465`) and left three others reading "the Settings tab"; `:144`'s comment still says "The **tab** is found by ICON, never by label". Same class as WR-02/03/04, in a file the phase edited for exactly this reason.

**Fix:** replace the three remaining "the Settings tab" strings with "the pushed Settings route" and reword `:144` to "The gear is found by ICON, never by label".

---

_Reviewed: 2026-08-17_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: deep_
