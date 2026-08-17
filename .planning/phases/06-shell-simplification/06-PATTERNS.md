# Phase 6: Shell & Simplification - Pattern Map

**Mapped:** 2026-08-17
**Files analyzed:** 4 created, 13 modified, 2 deleted (lib) + 12 test files churned
**Analogs found:** 15 / 17 (2 elements have NO local analog — see §No Analog Found)

> **Phase shape:** this is a RESTRUCTURING + DELETION phase. Most "new" files are
> promotions of existing private widgets, and most "new" code is transcription of an
> idiom that already exists twice in the repo. Classification below therefore carries a
> **Change kind** column (NEW / PROMOTED / MODIFIED / DELETED / NEUTRALIZED) alongside
> role and data flow — the planner should sequence by change kind, not by role.

> **⚠️ Spec supersedes research on Q1.** `06-RESEARCH.md` §Q1 lists three options (A/B/C)
> for the load-chart denominator and marks the decision open. The design spec **§3.1
> "What the bars scale against (decided 2026-08-17)"** settles it: **the ceiling is the
> number of supplements that currently carry a schedule** — a full bar means "every
> scheduled supplement in your stack overlaps this week". Self-scaling-to-peak (research
> option A) and a fixed 10 are explicitly *rejected* by the spec. Named edge cases: a
> stack of 1 (one overlap = full bar, correct), and a ceiling of 0 (planner already
> renders its empty state, no chart). Research options B and C must **not** be planned.

---

## File Classification

| File | Change kind | Role | Data flow | Closest analog | Match |
|---|---|---|---|---|---|
| `lib/core/widgets/bq_nav_bar.dart` | NEW | core widget (stateless control) | event-driven (index selection) | `lib/core/widgets/bq_segmented.dart` | exact (the repo's one hand-built selectable control) |
| `navBarHeightFor(TextScaler)` (in the same file) | NEW | pure function | transform | `week_strip.dart:59-79` `stripHeightFor` | exact |
| `lib/core/widgets/bq_add_fab.dart` (or folded into `app_shell.dart`) | NEW | core widget | event-driven | **none** — see §No Analog Found | none |
| `lib/features/calendar/today_screen.dart` | PROMOTED | screen | request-response (Riverpod streams) | `calendar_screen.dart:87-111` `_TodayPage` (the exact code being promoted) | identity |
| `lib/app_shell.dart` | MODIFIED (rewritten body) | shell / route host | event-driven | itself (v1, `app_shell.dart:37-89`) | identity |
| `lib/features/calendar/calendar_screen.dart` | DELETED | screen | — | — | — |
| `lib/features/calendar/calendar_providers.dart` | MODIFIED (deletions) | provider module | state | itself `:55-82` | identity |
| `lib/features/calendar/planner_screen.dart` | MODIFIED | screen | request-response | itself | identity |
| `lib/features/calendar/planner_load_chart.dart` | NEUTRALIZED | widget | transform (model → geometry) | itself `:258-345` | identity |
| `lib/features/calendar/planner_week_detail.dart` | NEUTRALIZED | widget | transform | itself | identity |
| `lib/features/calendar/planner_year_grid.dart` | NEUTRALIZED | widget | transform | itself `:202,:296` | identity |
| `lib/features/calendar/planner_month_detail.dart` | NEUTRALIZED | widget | transform | itself `:142-145` | identity |
| `lib/features/calendar/planner_view_model.dart` | MODIFIED (delete + add scale) | pure model | transform | itself `:388-445` | identity |
| `lib/features/settings/settings_screen.dart` | MODIFIED (gains back control) | screen (now a pushed route) | request-response | `regimen_editor_screen.dart:198-240` `_TopBar` | exact |
| `lib/features/stack/stack_screen.dart` | MODIFIED (CTA removed, gear added) | screen | CRUD list | itself `:46-102` | identity |
| `lib/core/theme/theme.dart` | MODIFIED | config | — | itself `:50-70` `navigationBarTheme` | identity |
| `lib/core/theme/tokens.dart` | MODIFIED (drop `thresholdDash`) | config | — | itself `:142-150` | identity |
| `lib/core/l10n/arb/app_{uk,en}.arb` | MODIFIED | config / copy | — | itself | identity |
| `test/core/widgets/bq_nav_bar_test.dart` | NEW | test | — | `test/support/locale_matrix.dart` + `app_shell_test.dart:200` matrix | role-match |

---

## Pattern Assignments

### `lib/core/widgets/bq_nav_bar.dart` (NEW — core widget, event-driven)

**Primary analog:** `lib/core/widgets/bq_segmented.dart` — the codebase's only hand-built
selectable control. Copy its *shape* wholesale: a decorated `Container`, a `Row` of
`Expanded` children, one `MergeSemantics` → `Semantics(selected/button/label/
excludeSemantics)` → `GestureDetector(behavior: HitTestBehavior.opaque)` per item,
token-only styling, and a library doc-comment that states why the SDK widget was refused.

**Doc-comment + token rule** (`bq_segmented.dart:1-15`):

```dart
/// Hand-built segmented pill control (02-RESEARCH.md P-10).
///
/// The SDK [SegmentedButton]'s M3 look (outlined segments + selected
/// checkmark) fights the mockup's padded-pill design, so this is a plain
/// decorated container with a `Row` of tappable segments.
///
/// TOKEN-ONLY RULE (D-07): all styling comes from `BqColors` / `BqRadii`;
/// the only literals are the mockup-exact paddings and the 13.5/w500 segment
/// label typography locked in 02-UI-SPEC (...).
library;
```

`BqNavBar`'s equivalent doc-comment must state the **corrected** rationale (spec §1.1
correction block): *not* "the height is not themeable" (false — `navigation_bar.dart:281`
resolves `height ?? navigationBarTheme.height ?? defaults.height!`), but (1) the resolved
height lands in a hard `SizedBox` that does not grow with the text scaler, and (2) no
`ThemeData` field accepts a `double Function(TextScaler)`.

**Per-destination item** (`bq_segmented.dart:54-93` — the structural skeleton):

```dart
for (int i = 0; i < labels.length; i++)
  Expanded(
    child: MergeSemantics(
      child: Semantics(
        selected: i == selectedIndex,
        button: true,
        label: labels[i],
        excludeSemantics: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => onChanged(i),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 9),
            ...
```

**⚠️ One mandatory correction to that skeleton.** `BqSegmented` places `onTap` **only** on
the `GestureDetector` under an `excludeSemantics: true` node — the exact WR-02 defect. Do
**not** copy that half. The corrected form is `week_strip.dart:249-265`, which carries the
lesson verbatim:

```dart
return MergeSemantics(
  child: Semantics(
    button: true,
    selected: isSelected,
    label: DateFormat.yMMMMEEEEd(locale).format(day),
    excludeSemantics: true,
    // The action lives on THIS node, not on the GestureDetector below it:
    // `excludeSemantics` drops every descendant action, so without this a
    // cell announced itself as a button that VoiceOver / TalkBack could
    // not activate — and day browsing is the screen's primary affordance
    // (WR-02).
    onTap: select,
    child: GestureDetector(
      // The whole padded cell is the tap target — a 4px dot must never
      // define it (Interaction Contract 8).
      behavior: HitTestBehavior.opaque,
      onTap: select,
```

**Extent function** (`week_strip.dart:59-79`, transcribe the idiom including the
two-constant split and the rationale comment):

```dart
/// The part of the strip's height that does NOT follow the text scale:
/// padding 9/10, the 6px and 7px gaps, the 4px dot, the 1px borders, plus the
/// design slack the mockup's 82px carries at scale 1.0.
const double _stripFixedExtent = 48;

/// The text-bearing part of a cell at scale 1.0: the mono 10 dow line plus the
/// 14px day number, with their line boxes.
const double _stripTextExtent = 34;

/// Height reserved for the strip, for [scaler].
///
/// ... a constant would clip the cells at any accessibility text scale (CR-01
/// reproduced 7 bottom overflows at 1.6 and at 2.0). Only the two text lines
/// grow with the scaler; the paddings, the gaps and the 4px dot do not. ...
double stripHeightFor(TextScaler scaler) =>
    _stripFixedExtent + scaler.scale(_stripTextExtent);
```

`navBarHeightFor` = `_navBarFixedExtent` (22dp icon box + icon→label gap + vertical
padding) + `scaler.scale(_navBarLabelExtent)` (the 10sp label line box **only** — `Icon`
sizes from `IconThemeData`, not the text scaler). Second precedent for the same idiom on a
two-part box: `planner_year_grid.dart:101-106` `monthCardExtentFor`.

**Label `Text`** — copy the pinned-line-count argument at `week_strip.dart:283-296`:
`maxLines: 1, softWrap: false`, legitimate *only because* the extent formula scales the
line box.

**Chrome to carry over verbatim** (`app_shell.dart:56-64`):

```dart
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: BqColors.surfaceAlt,
          border: Border(
            top: BorderSide(color: BqColors.hairline, width: 1),
          ),
        ),
        // Mockup-exact pixel overrides (UI-SPEC) — hardcoded here only.
        padding: const EdgeInsetsDirectional.only(top: 10, start: 22, end: 22),
```

**Selected-state styling source** (`theme.dart:50-70`) — the `navigationBarTheme` being
deleted holds the exact values the hand-built bar must reproduce inline: fontSize 10,
`FontWeight.w500` → per spec §1.1 becomes **w400 unselected / w600 selected**;
`BqColors.accent` selected, `BqColors.textFaint` unselected, for both label and icon;
`backgroundColor: BqColors.surfaceAlt`, `elevation: 0`.

**Press feedback** — two precedented options, pick one and *say which* in the doc comment:
`InkResponse` (`planner_year_grid.dart:238-249`) or an opacity change
(`planner_load_chart.dart:305-308`: *"The opacity change IS the press feedback; no ripple
(Interaction Contract 11)"*).

**Safe area** — the hand-built bar owns it now: `SafeArea(top: false, …)` *inside* the
decorated `Container`, so fill + hairline reach the physical edge while targets sit above
the home indicator. `app_shell.dart:19-23` records the v1 reliance on `NavigationBar` for
this as an accepted deviation; that deviation note is deleted with the widget.

---

### `lib/app_shell.dart` (MODIFIED — shell, event-driven)

**Analog: itself.** The `IndexedStack` + per-child `TickerMode` block (`app_shell.dart:38-55`)
is v1's WR-05 fix and **must survive the restructure byte-for-byte apart from the child
list**, including its comment:

```dart
      // [IndexedStack] builds and KEEPS every child mounted — only painting is
      // suppressed — so all three screens are alive from app launch on every
      // tab. [TickerMode] is how an offstage screen learns it is offstage
      // (WR-05): the Calendar tab reads it to stop watching the minute ticker
      // and to stop warming the visible week while nobody is looking at it,
      // which is what its autoDispose providers were documented to do and,
      // under a bare IndexedStack, never did.
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          for (final (index, screen) in const <Widget>[
            StackScreen(),
            CalendarScreen(),
            SettingsScreen(),
          ].indexed)
            TickerMode(enabled: index == _selectedIndex, child: screen),
        ],
      ),
```

Children become `StackScreen()`, `TodayScreen()`, `PlannerScreen()`; the comment's "the
Calendar tab reads it" becomes "the Сьогодні tab reads it". `_selectedIndex` stays plain
`StatefulWidget` state (`:31-32`) — do not promote it to Riverpod.

New slots: `floatingActionButton:` (see below) and `bottomNavigationBar: BqNavBar(...)`.

---

### `lib/core/widgets/bq_add_fab.dart` (NEW — core widget, event-driven)

**No local analog** (see §No Analog Found). Structural rules from research §P-4, all of
which the planner must state as decisions rather than rediscover:

1. Mount on the **root `Scaffold` in `AppShell`**, not per-screen. Makes UX-01 ("exactly
   three tabs, nowhere else") true by construction — Settings is a pushed route with its
   own `Scaffold` and can never inherit it.
2. Nav-bar clearance is free: `Scaffold` measures the real `bottomNavigationBar`, whose
   height is `navBarHeightFor(scaler)`. A hand-positioned `Positioned(bottom: 56 + 16)`
   would re-create the CR-01 class this phase exists to remove.
3. Each screen's inner `Scaffold` (`stack_screen.dart:46`, `calendar_screen.dart:95`,
   `planner_screen.dart:97`) sits *inside* the shell body — a FAB there would land under
   the bar.

**Colour pattern to copy** — the accent-filled button being deleted from the Stack screen
(`stack_screen.dart:84-99`) is the app's existing accent-fill language:

```dart
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: BqColors.accent,
                  foregroundColor: BqColors.surface,
                  overlayColor: BqColors.accentPressed,
                  ...
                onPressed: () => showAddSupplementSheet(context),
                child: Text(l10n.addSupplement),
```

`backgroundColor: BqColors.accent` / `foregroundColor: BqColors.surface` carry straight
onto the FAB (inline, or as a new `floatingActionButtonTheme` in `bqTheme()` — there is
none today; `theme.dart` has only `navigationBarTheme` at `:50`).

**Semantics** — WR-02 applies: wrap in `Semantics(button: true, label: l10n.addSupplement,
excludeSemantics: true, onTap: open, child: FloatingActionButton(onPressed: open, …))`.
`addSupplement` is **reused**, no new ARB key.

---

### `lib/features/calendar/today_screen.dart` (PROMOTED — screen)

**Analog: the code itself.** `_TodayPage` (`calendar_screen.dart:87-111`) becomes public
`TodayScreen`; `_Header`, `_DayBody`, `_EmptyDayState`, `_Disclaimer` and
`const double _screenPadding = 20;` (`:52-55`) move with it.

```dart
/// The Today page ("Сьогодні", mockup screen 02, UI-SPEC S4).
class _TodayPage extends ConsumerWidget {
  const _TodayPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final day = ref.watch(resolvedDayProvider);
    final doses = ref.watch(dayDosesProvider(day));

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(day: day, doses: doses),
            const SizedBox(height: BqSpace.md),
            const WeekStrip(),
            Expanded(child: _DayBody(doses: doses, day: day)),
```

Note `WeekStrip` is **already** a child here — the spec's "Сьогодні gaining the week strip"
describes no work.

**Two things that must move intact:**
- the `TickerMode` gate `final visible = TickerMode.valuesOf(context).enabled;`
  (`calendar_screen.dart:323`) — dropping it silently re-arms `nowMinutesProvider`
  (PF-3; caught only by `app_shell_test.dart:125`);
- the `_held` / `_heldDay` hold-last-value machinery (`calendar_screen.dart:250-276`) with
  its WR-01 comments — a day-change flash guard, unrelated to this phase.

**Header edit — the WR-04 trap.** The `plannerTitle` `TextButton` (`:197-207`) is deleted;
the surrounding `Wrap` and the `backToToday` button (`:210-221`) **survive**. The gear must
NOT join the title `Row`, which states verbatim (`:185-189`):

```dart
                // A Wrap, NOT a Row: at textScaler 2.0 the two uk labels
                // ("Планувальник", "Сьогодні") do not fit one line, and a Row
                // would overflow exactly as the header did in WR-04. The
                // header's title ROW above is left structurally untouched for
                // the same reason — it never gains a third non-flexible child.
```

The `Row` at `:166-230` already has `Expanded` + `SizedBox(width: 10)` +
`DayProgressRing`. Adding the gear as a third rigid child is the forbidden move. Choose
(and record) either a separate end-aligned row above the title, or a bounded
`Row(mainAxisSize: MainAxisSize.min)` trailing group holding ring + gear.

---

### `lib/features/settings/settings_screen.dart` (MODIFIED — pushed route)

**Analog: `regimen_editor_screen.dart:198-240`** — the back-affordance precedent, exact:

```dart
/// Editor top bar: back chevron, title, trailing НА ПАУЗІ badge when paused,
/// hairline bottom border (UI-SPEC S3).
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.maybePop(context),
            icon: const Icon(
              Icons.arrow_back_ios_new,
              size: 18,
              color: BqColors.textSecondary,
            ),
          ),
          Expanded(
            // Flexible, not fixed-width: the trailing badge keeps its
            // intrinsic size and the title yields — never a Row overflow.
            child: Text(
```

`maybePop`, not `pop` — same reason the editor uses it. Push site pattern:
`stack_screen.dart:231-236` (`Navigator.of(context).push(MaterialPageRoute<void>(...))`).

Also: `settings_screen.dart:46`'s `bottom: 84` was nav-bar clearance and becomes dead space
on a pushed route — reduce it there only.

**ARB:** `tabSettings` currently serves two placements by design (`settings_screen.dart:49-50`).
Research recommends renaming to `settingsTitle` (research Q3, marked ASSUMED) — the same
key then labels the gear's `Semantics` and the screen title, preserving the "one key, two
placements" property. Touches `app_shell_test.dart`, `settings_screen_test.dart`,
`l10n_device_test.dart`.

---

### `lib/features/stack/stack_screen.dart` (MODIFIED)

Delete `:82-101` (the `SizedBox(width: double.infinity, child: FilledButton(…))`, quoted
above) **and** the trailing `const SizedBox(height: BqSpace.md);` at `:102`. The title
`Text(l10n.stackTitle)` at `:58-61` is a bare first `ListView` child and needs a `Row`
wrapper for the gear.

Three doc comments become false and must be rewritten in the same commit:
- `stack_screen.dart:7-8` — *"empty: `emptyStackTitle`/`emptyStackBody` below the still-visible CTA"*
- `stack_screen.dart:181-182` — *"title + body under the CTA; the CTA above remains the single next-step affordance"*
- `calendar_screen.dart:479-480` — *"an empty stack gets the one next step that helps — named, not linked, because the nav bar is the affordance"* (moves into `today_screen.dart`)

Keep `bottom: 84` (`:51-56`) — its comment *"bottom >= 84px clears the nav bar (UI-SPEC #4)"*
still holds against a slimmer bar plus a 56dp FAB; let the text-scale matrix prove it.

---

### The limit removal (`planner_*`) — NEUTRALIZED, one plan, last

**Pattern: every deletion site is a conditional expression collapsing to its neutral arm.**
The planner should transcribe these five collapses:

| Site | Before | After |
|---|---|---|
| `planner_load_chart.dart:273-277` | `load <= comfortLoad ? loadBar : load <= editorialLimit ? warn : risk` | `BqColors.loadBar` |
| `planner_screen.dart:284-286` | `atLimit ? warnBg : calmBg` (+ fg pair) | one neutral pair (research Q2 recommends the neutral `chip`/`textSecondary` pair from `stack_screen.dart:377-393`, **ASSUMED**) |
| `planner_screen.dart:408-410` | `over ? warnBg : calmBg` | same neutral pair |
| `planner_year_grid.dart:296` | `over ? BqColors.risk : BqColors.textFaint` | `BqColors.textFaint`; delete `final over = …` at `:202` |
| `planner_month_detail.dart:142-145` | `monthMeta(substancesCount(rows.length), editorialLimit)` | one-placeholder count |

**The chart's y-axis** (`planner_load_chart.dart:263-277`) — the hole the deletion opens:

```dart
    // Verbatim from the mockup (lines 904-906): the main bar is the load
    // capped at the limit, and everything above the limit becomes a
    // proportional over-bar. `risk` here means "above OUR editorial limit".
    final mainHeight =
        (math.min(load, editorialLimit) / editorialLimit * _barFullHeight)
            .roundToDouble();
    final overHeight = load > editorialLimit
        ? ((load - editorialLimit) / editorialLimit * _barFullHeight)
            .roundToDouble()
        : 0.0;
```

Per **spec §3.1**, the denominator becomes the count of supplements currently carrying a
schedule, computed in `planner_view_model.dart` beside `weekLoads` (a *model* concern, not
a widget constant — Architectural Responsibility Map). `overHeight` and the `load-over-$index`
`Container` (`:321-332`) disappear entirely, since load can never exceed the ceiling.
The `load == 0` stub at `:333-343` **survives unchanged** — it is not limit framing.

**Semantics label** (`planner_load_chart.dart:288-293`): `weekLoadLabel(load,
slotsCount(editorialLimit))` → `substancesCount(load)`. The `weekBarSemantics` key text is
unchanged; only the argument changes.

**The doc comment being deleted** (`planner_view_model.dart:390-405`) is 16 lines of
editorial rationale including the deliberate DECIDED-6 chip asymmetry. It goes with the
constants — nothing survives it.

---

## Shared Patterns

### WR-02 — the action lives on the `Semantics` node
**Source:** `week_strip.dart:255-265` (comment quoted in full above)
**Apply to:** every `BqNavBar` destination, the FAB wrapper
`excludeSemantics: true` drops **every** descendant action. `onTap` goes on the `Semantics`
node *and* the `GestureDetector`. `BqSegmented` violates this and must not be copied
verbatim on this point.

### CR-01 — computed extents, never a constant around a `Text`
**Source:** `week_strip.dart:59-79`; second instance `planner_year_grid.dart:101-106`
**Apply to:** `navBarHeightFor`; any new box that contains a label
Split the extent: fixed part (icons, padding, gaps, borders) + `scaler.scale(textPart)`.

### Token-only styling (D-07)
**Source:** `bq_segmented.dart:6-10`
**Apply to:** `BqNavBar`, `BqAddFab`
All colours/radii from `BqColors`/`BqRadii`; the only permitted literals are mockup-exact
paddings and typography, each carrying a comment naming the UI-SPEC exemption
(`app_shell.dart:63` and `tokens.dart:213-216` are the precedent for the spacing carve-out).

### Directional insets only
**Source:** `app_shell.dart:64`, `week_strip.dart:268`, `regimen_editor_screen.dart:212-217`
**Apply to:** everything new
`EdgeInsetsDirectional` / `PositionedDirectional` / `BorderRadiusDirectional` — never
`EdgeInsets` with left/right. Project-wide RTL rule.

### Pushed-route + back-affordance pair
**Source:** push `stack_screen.dart:231-236`; back `regimen_editor_screen.dart:220-227`
**Apply to:** the Settings gear on all three screens

### Locale from the tree, casing through intl
**Source:** `calendar_screen.dart:129-145`
**Apply to:** any new copy site
`Localizations.localeOf(context).toString()`, never a literal tag; `toBeginningOfSentenceCase`
/ `bqUpperCase` with the locale, never Dart's `toUpperCase()` (WR-03).

### Bilingual × text-scale render matrix
**Source:** `test/support/locale_matrix.dart` (the repo's single shared test library, with
`overflowReason` / `cyrillicLeakReason` / `cyrillicAllowlist`) + `app_shell_test.dart:200`
**Apply to:** `bq_nav_bar_test.dart`, the retargeted `app_shell_test.dart`
Import the helpers rather than re-declaring an allowlist — the file's own doc comment
explains that a four-way copy is four places to get an exception wrong. Add the 2.0 row
(the matrix is 1.0/1.6 today) for NAV-01.

---

## Deletion inventory

Sequence deletions in this order to avoid dangling references: **(A) page-swap → (B) shell
→ (C) settings → (D) FAB/CTA → (E) limit machinery, ending with the copy gate.**

### A — page swap (delete first; nothing depends on these once the shell is rewritten)

| Symbol / element | Current location | Dangling-reference risk |
|---|---|---|
| `enum CalendarPage { today, planner }` | `calendar_providers.dart:58` | — |
| `class CalendarPageController` (`showPlanner`/`showToday`) | `calendar_providers.dart:66-76` | — |
| `final calendarPageProvider` | `calendar_providers.dart:79-82` | referenced by `calendar_screen.dart:69,77,199` and `planner_screen.dart:140` — delete those call sites **first** |
| `class CalendarScreen` (whole class) | `calendar_screen.dart:64-84` | referenced by `app_shell.dart:5,50`, `smoke_test.dart`, `integration_test/data03_loop_test.dart` |
| the `PopScope(canPop: false, onPopInvokedWithResult:)` | `calendar_screen.dart:70-79` | asserted by `planner_screen_test.dart:502,621,631,671` — those tests are **deleted**, not fixed |
| `plannerTitle` `TextButton` in the header `Wrap` | `calendar_screen.dart:197-207` | `Wrap` itself + `backToToday` button (`:210-221`) **SURVIVE** |
| planner back control `Align`/`TextButton` `'‹ ${l10n.backToToday}'` | `planner_screen.dart:136-150` | the `‹` literal and its string-literal-exception comment go with it; asserted by `planner_screen_test.dart:388` |
| `import '…/planner_screen.dart'` | `calendar_screen.dart:49` | — |
| `import '…/calendar_providers.dart'` | `planner_screen.dart:34` | only after the back control goes |
| the whole file `calendar_screen.dart` | — | after `today_screen.dart` exists |
| `planner_screen.dart` library doc (`:1-21`) claim that the swap "lives entirely in `calendar_screen.dart` + `calendar_providers.dart`" | `planner_screen.dart:1-21` | a claim about a deleted file |
| `calendar_providers.dart:31-35` doc *"the shell keeps the Calendar screen mounted"* | — | rename to Today |

### B — shell

| Element | Location |
|---|---|
| `NavigationBar` + 3 `NavigationDestination`s | `app_shell.dart:65-87` |
| `tabSettings` destination | `app_shell.dart:81-85` |
| the "Accepted deviations … SafeArea/NavigationBar handle the home indicator" doc block | `app_shell.dart:19-23` |
| `navigationBarTheme: NavigationBarThemeData(…)` | `theme.dart:50-70` — read its values into `BqNavBar` **before** deleting; asserted by `test/theme/theme_test.dart` |
| `import …/settings_screen.dart` as a stack child | `app_shell.dart:6` (kept, but for the push site) |

### C — settings

| Element | Location |
|---|---|
| `tabSettings` ARB key (renamed → `settingsTitle`) | `app_uk.arb` / `app_en.arb`; consumers `app_shell.dart:84`, `settings_screen.dart:49-50` |
| the `bottom: 84` nav-bar clearance | `settings_screen.dart:46` |

### D — Stack CTA

| Element | Location |
|---|---|
| full-width `SizedBox`+`FilledButton(addSupplement)` | `stack_screen.dart:82-101` |
| its trailing `SizedBox(height: BqSpace.md)` | `stack_screen.dart:102` |
| doc comments asserting the CTA | `stack_screen.dart:7-8`, `:181-182`, `calendar_screen.dart:479-480` |
| tests targeting the button | `stack_screen_test.dart:767, 787-789, 861-863, 1064` — retarget at the FAB; `:767`'s `findsOneWidget` must not silently start matching the FAB label |

### E — limit machinery (delete last, in ONE plan)

| Element | Location |
|---|---|
| `const int editorialLimit = 5` + its 16-line doc | `planner_view_model.dart:390-406` |
| `const int comfortLoad = 3` | `planner_view_model.dart:408-409` |
| `sealed class LoadVerdict`, `ComfortVerdict`, `LimitVerdict`, `OverLimitVerdict`, `verdictOf` | `planner_view_model.dart:411-441` |
| `_thresholdOffset`, `_dashOn`, `_dashOff`, `_thresholdWidth`, `PositionedDirectional(key: ValueKey('load-threshold'))`, `_ThresholdLinePainter` | `planner_load_chart.dart:73-77, 177-184, 371-391` |
| `overHeight` + `load-over-$index` container | `planner_load_chart.dart:269-272, 321-332` |
| `_AxisLabel(text: l10n.loadAxisLegend(editorialLimit, comfortLoad))` | `planner_load_chart.dart:199-202` |
| `Text(l10n.limitBadge(editorialLimit))` | `planner_screen.dart:319-329` |
| `final atLimit = load >= editorialLimit;` | `planner_screen.dart:284` |
| `final over = load > editorialLimit;` (year peak chip) | `planner_screen.dart:408` |
| `yearFootnote(substancesLimitCount(editorialLimit))` | `planner_screen.dart:353-354` |
| verdict switch + `week-verdict-chip` container | `planner_week_detail.dart:90-113, 166-188` |
| `_SlotPips` class + call site | `planner_week_detail.dart:192, 244-284` |
| `final free = editorialLimit - load;` + the free-slots half of the meta line | `planner_week_detail.dart:85, 153-154` |
| the verdict `note` `Text` | `planner_week_detail.dart:223-232` |
| `final over = month.load > editorialLimit;` | `planner_year_grid.dart:202` |
| `BqColors.thresholdDash` (sole consumer is the deleted painter) | `tokens.dart:142-150` |
| **13 ARB keys** `limitBadge`, `loadAxisLegend`, `verdictComfort`, `verdictLimit`, `verdictOverLimit`, `weekNoteComfort`, `weekNoteLimit`, `weekNoteOverLimit`, `weekFreeSlots`, `weekNoFreeSlots`, `weekLoadLabel`, `substancesLimitCount`, `slotsCount`, `cyclesCount` | `app_uk.arb` / `app_en.arb` |
| `plurals_test.dart` tests for `cyclesCount`/`slotsCount`/`substancesLimitCount`/`weekLoadLabel` | `test/l10n/plurals_test.dart:80-123` |
| `plannerKeysExact` entries `limitBadge`, `substancesLimitCount`, `slotsCount`, `cyclesCount` | `test/l10n/planner_copy_safety_test.dart` |
| `negationOnlyVocabulary` + `negationBearingKeys` | `test/l10n/planner_copy_safety_test.dart` |
| the trailing "over-limit note ships truncated" test | `test/l10n/planner_copy_safety_test.dart` — **keep** `'жиророзчин'`/`'fat-soluble'` in `forbiddenVocabulary` |

**Must NOT be deleted** (PF-9): `BqColors.risk`/`riskBg` (`regimen_editor_screen.dart:902-904,
1017-1018`), `BqColors.warn`/`warnBg` (`dose_row.dart:207`, `day_block_section.dart:197-198`),
ARB `substancesCount`, `periodsCount`, `weeksCount` (the last is the **regimen editor**, not
planner copy).

**Two gates that will go red for non-obvious reasons:**
1. `expect(arbKeys.length, greaterThanOrEqualTo(40))` in `planner_copy_safety_test.dart` —
   50 keys today, ~37 after; re-derive to the *measured* count with a one-line reason
   (PF-8), do not "lower it a bit".
2. `plannerDisclaimer` is itself limit copy (`app_uk.arb:160`, `app_en.arb:847`) and must be
   rewritten, but the gate asserts it is **strictly longer than** and **contains**
   `disclaimerEducational` — so the rewrite must still add a sentence and still end with
   `disclaimerEducational` verbatim (PF-7).
3. No test detects orphaned ARB keys (`arb_parity_test.dart` / `new_language_contract_test.dart`
   both self-adjust) — **the 13 deletions must be done and reviewed by hand.**

---

## No Analog Found

| Element | Role | Data flow | Reason |
|---|---|---|---|
| `BqAddFab` / `FloatingActionButton` | core widget | event-driven | **Zero `FloatingActionButton` and zero `floatingActionButton:` occurrences anywhere in `lib/` today** [VERIFIED: `grep -rn` this session, empty result]. No elevation-language precedent for a circular floating control either. Take geometry/ink/elevation from the SDK default (56×56, `floating_action_button.dart:783-785`) and colour from `stack_screen.dart:84-99`'s accent-fill `FilledButton`. |
| `Semantics(role: SemanticsRole.tabBar / .tab)` | accessibility contract | — | **`SemanticsRole` appears nowhere in `lib/`** [VERIFIED: `grep -rn` this session, empty result]. Take it from the SDK (`navigation_bar.dart:293-307`). Fallback if the enum proves awkward: `button: true, selected: …` alone, which is what every other bespoke control here uses — but **state the downgrade explicitly** rather than letting it happen silently. |

Also with no direct local analog but well-covered by RESEARCH.md rather than by code:
the source-glob gates for V-6 / V-11 (`grep` for `calendarPageProvider` / `editorialLimit`
returning nothing) — follow the `planner_invariants_test.dart:149` idiom, and note that
`planner_invariants_test.dart:83-130`'s file-count floor over `lib/features/calendar` is
net-zero for this phase (+`today_screen.dart`, −`calendar_screen.dart`); verify, don't
assume (PF-11).

---

## Metadata

**Analog search scope:** `lib/` (all), `test/support/`, targeted reads in `test/l10n/`
**Files read this session:** `app_shell.dart`, `bq_segmented.dart`, `week_strip.dart`
(2 ranges), `calendar_screen.dart` (1 range), `calendar_providers.dart` (1 range),
`regimen_editor_screen.dart` (1 range), `stack_screen.dart` (1 range),
`planner_screen.dart` (1 range), `planner_load_chart.dart` (1 range),
`planner_view_model.dart` (1 range), `theme.dart` (1 range), `locale_matrix.dart` (1 range);
plus 2 repo-wide greps
**Pattern extraction date:** 2026-08-17
