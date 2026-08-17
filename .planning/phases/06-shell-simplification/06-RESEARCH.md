# Phase 6: Shell & Simplification — Research

**Researched:** 2026-08-17
**Domain:** Flutter app chrome (custom bottom navigation, pushed routes, floating action button), Riverpod provider lifetime under `IndexedStack`, editorial-copy removal across a bilingual ARB surface
**Confidence:** HIGH on the code inventory (every claim below was read from the file this session, with line ranges); MEDIUM on two design questions the spec did not settle (§Open Questions Q1, Q2)

**Standard-stack delta: ZERO new packages. I agree with the brief and state it loudly** — every capability this phase needs (`SizedBox`/`Semantics`/`InkResponse`/`SafeArea`, `Navigator.push`, `Scaffold.floatingActionButton`, `MediaQuery.textScalerOf`) ships in the Flutter SDK already on disk. See §Standard Stack Delta for the one temptation to refuse.

---

## User Constraints

No `06-CONTEXT.md` exists yet (`/gsd-discuss-phase` has not run for this phase). The binding constraints are therefore the approved spec and `CLAUDE.md`.

### Locked Decisions (from `docs/superpowers/specs/2026-08-17-boostque-v1.1-design.md` §1, §3, §4 — approved in chat 2026-08-17)

- The bottom bar is replaced by a hand-built `BqNavBar`: **56dp base + safe-area**, 22dp icon over a 10sp label, selected state = `BqColors.accent` + weight 400→600, background `surfaceAlt` with the hairline top border unchanged. [CITED: spec §1.1]
- **The bar keeps labels.** Icon-only is rejected as an accessibility and localization regression. [CITED: spec §1.1]
- The bar's height **must grow with `MediaQuery.textScalerOf` exactly as `WeekStrip.stripHeightFor` does**. A fixed 56dp that clips at 2.0 is not acceptable. [CITED: spec §1.1]
- Three tabs: **Стек / Сьогодні / Календар**. Сьогодні = today's doses + week strip + past-day browsing. Календар = the planner (`Цикли | Рік`). [CITED: spec §1.2]
- **Settings leaves the bar**, becomes a gear icon top-right on each of the three screens, pushing a full-screen route. The settings screen content is unchanged from v1. [CITED: spec §1.2]
- The v1 in-tab page swap **is deleted**: `calendarPageProvider`, the `plannerTitle` header action, the `PopScope` back-interception, the `‹ Сьогодні` back control. [CITED: spec §1.2]
- `AppShell`'s `IndexedStack` keeps three children; the `TickerMode` gating (WR-05) stays valid but the minute ticker **now belongs to the Сьогодні tab**. [CITED: spec §1.2]
- Deep state (selected week / selected month) must survive a tab switch identically. `resolvedWeekIndexProvider` / `resolvedMonthIndexProvider` identity-based selection already does this — **verify, do not rebuild**. [CITED: spec §1.2]
- The weekly concurrent-load **chart stays**; every judgement layered on it goes. Removed: comfort-3 dashed reference line, `risk`-coloured over-limit segment, the three verdict chips, the `межа 5 · комфорт 3` axis caption and limit badge, red month counts in Рік, `weekNoteOverLimit`, the slot-pip "free slots" framing, `editorialLimit`/`comfortLoad` and their plural keys. [CITED: spec §3]
- The **educational disclaimer stays** on both planner segments. [CITED: spec §3]
- The forbidden-vocabulary gate **stays and gets stricter**: `межа`, `перевищ`, `норма` should now be absent from planner copy entirely. [CITED: spec §3]
- A floating **+** button, bottom-right, above the nav bar, on **Стек, Сьогодні and Календар** only. Accent fill, white glyph, existing elevation language, `EdgeInsetsDirectional`, clears the nav bar at every text scale, opens the existing add-supplement sheet unchanged, semantics = a labelled button (`addSupplement`). [CITED: spec §4]
- **The full-width "Додати добавку" button is removed from the Stack screen**; the Stack empty state's body copy is repointed at the + button. [CITED: spec §4]

### Claude's Discretion

- The internal composition of `BqNavBar` (widget tree, ink treatment, exact extent constants) — the spec fixes the *appearance* and the *scaling rule*, not the implementation.
- Whether the FAB is `FloatingActionButton` or hand-built, and where it is mounted. (This research makes a strong recommendation: §P-4.)
- Where the gear control sits inside each screen's existing header, and its exact ARB key naming.
- The new load-chart bar-height denominator (see **Q1** — flagged as needing user confirmation, not assumed).

### Deferred Ideas (OUT OF SCOPE — ignore completely)

Notifications (all of spec §2 → Phase 7); notification settings UI; the 6-slots-per-day cap (a *different* limit, unchanged); app name and bundle id; release signing; the Cyrillic font question; home-screen widgets; backend sync; label scanning; the Advisor tab. [CITED: spec §5]

---

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| NAV-01 | Bottom navigation is a slim custom bar (56dp base) that scales with text size and never clips | §P-1 (extent formula), §P-2 (semantics parity), §PF-1/PF-2, §E-1..E-3 |
| NAV-02 | Three tabs: Стек, Сьогодні (today + recent-day browsing), Календар (Цикли/Рік planner) | §P-3 (blast radius, symbol-by-symbol), §Architecture Patterns "Provider lifetime under the new shell", §E-4..E-6 |
| NAV-03 | Settings is reachable from a top-right control on all three tabs and is no longer a tab | §P-5 (push route + back affordance precedent), §PF-6, §E-7 |
| UX-01 | A floating add-supplement button appears on all three tabs and nowhere else | §P-4 (mount it on the root `Scaffold` — structural, not per-screen), §E-8..E-9 |
| PLAN-05 | The planner presents concurrent load without any limit, threshold, verdict or warning colour | §P-6 (full deletion inventory), §P-7 (copy/gate rework), §Q1, §E-10..E-13 |

---

## Summary

This phase is a **subtraction phase wearing an addition phase's clothes**. Three of the five success criteria are met by deleting code, and the two additions (`BqNavBar`, the FAB) are small widgets. The risk is therefore not "can we build it" — it is (a) silent test rot across a 594-`test()` suite that pins the current shell and the current editorial framing in prose-heavy assertions, and (b) two places where a deletion leaves a **hole that the code cannot compile around**, which the spec did not notice.

Those two holes are worth stating up front, because they are the only genuine design decisions in the phase. **First: the load chart's bar heights are defined *in terms of* `editorialLimit`.** `planner_load_chart.dart:266-272` computes `mainHeight = min(load, editorialLimit) / editorialLimit * 38` — the limit is the chart's *y-axis denominator*, not decoration. Deleting `editorialLimit` deletes the scale. The chart cannot be drawn until a replacement denominator is chosen, and the obvious replacements (a renamed constant) reintroduce a threshold by another name. **Second: `plannerDisclaimer` is itself limit copy** — uk reads "Межа в 5 речовин — наше редакційне правило… а не медичний норматив" (`app_uk.arb:160`). The spec says the disclaimer stays; but the sentence that stays cannot be *this* sentence, and `planner_copy_safety_test.dart` has a live assertion that `plannerDisclaimer` is *strictly longer than* `disclaimerEducational` and *contains* it. Rewriting the disclaimer to a neutral sentence that still satisfies both halves of that assertion is a two-minute job **if the planner knows about it** and a confusing red test if it does not.

The rest of the work is well-precedented in this codebase. The 56dp bar has an exact idiom to copy (`stripHeightFor`, `monthCardExtentFor`) and an exact semantics contract to reproduce (Flutter's own `NavigationBar` sets `SemanticsRole.tabBar`/`SemanticsRole.tab` and wraps itself in a `SafeArea`). The settings push route has a precedent two files over (`RegimenEditorScreen`'s back chevron + `Navigator.maybePop`). And the FAB has a structurally elegant home — the root `Scaffold`'s `floatingActionButton` slot in `AppShell`, which makes "exactly the three tabs and nowhere else" true by construction rather than by a per-screen boolean, and which gets nav-bar clearance at every text scale for free because `Scaffold` measures the actual `bottomNavigationBar`.

One correction to the spec that the plan must not transcribe verbatim into a doc comment: **`NavigationBar`'s 80dp height is not fixed.** It is `height ?? navigationBarTheme.height ?? defaults.height!` (`navigation_bar.dart:281`), so `NavigationBarThemeData(height: 56)` would compile. The real reasons to hand-build are better ones, and this codebase writes rationale into doc comments, so a wrong rationale is a durable lie. See §P-1.

**Primary recommendation:** Sequence the phase as *(1) delete the page swap and restructure the shell → (2) `BqNavBar` + the extent test → (3) settings push route → (4) FAB on the root Scaffold → (5) the limit removal, ending with the copy gate*. Do the limit removal **last and in one plan**, because it touches five widget files, ~13 ARB keys and three gates at once, and a partial removal leaves the copy-safety gate failing for reasons unrelated to the code being edited.

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Tab selection & offstage gating | App shell widget (`AppShell` `State`) | — | Already `StatefulWidget` local state (`app_shell.dart:32`); no provider needed, and promoting it to Riverpod would be scope creep |
| Bar height at a text scale | Pure function in the bar's own file | — | The `stripHeightFor` / `monthCardExtentFor` idiom: a top-level `double f(TextScaler)` that a unit test can call without pumping a widget |
| "Which day am I looking at" | `calendar_providers.dart` (`selectedDayProvider` / `resolvedDayProvider`) | Today screen widget | Unchanged by this phase — it already survives a tab round trip (`calendar_providers.dart:30-39`) |
| "Which week / month is selected" | `planner_providers.dart` (identity-keyed selections) | Planner screen `ref.listen` keep-alive | Already correct; the tab move makes it *more* durable, not less (§"Provider lifetime") |
| Minute-of-day ticker | `nowMinutesProvider` + the **Сьогодні** screen's `TickerMode` gate | — | The gate is what cancels the timer, not `autoDispose` (`calendar_providers.dart:84-110`); it moves with the Today page |
| Settings reachability | `Navigator` (root) | Each screen's header | A pushed `MaterialPageRoute`, matching `StackScreen`→`RegimenEditorScreen` (`stack_screen.dart:231-236`) |
| Add-supplement affordance | Root `Scaffold.floatingActionButton` in `AppShell` | `showAddSupplementSheet` (unchanged) | Mounting once at the shell makes UX-01's "exactly three tabs" structural |
| Concurrent-load *measurement* | `planner_view_model.dart` (`weekLoads`, `WeekLoad.load`) | — | **Stays.** Only the *judgement* built on top of it is removed |
| Concurrent-load *scale* | `planner_view_model.dart` (new) | Load chart widget | The denominator must be a model concern, not a widget constant — see §Q1 |

---

## Standard Stack Delta

**No packages added. No packages removed.** [VERIFIED: `pubspec.yaml` read at repo root; every widget named below resolves inside `package:flutter/material.dart` on the installed SDK]

| Capability needed | What ships already | Where |
|---|---|---|
| Flutter SDK | 3.47.0 | `frameworkVersion` in `/opt/homebrew/share/flutter/bin/cache/flutter.version.json` [VERIFIED: read this session] |
| Custom bar chrome | `Container` + `Row` + `Expanded` + `Semantics` + `SafeArea` | precedent: `BqSegmented` (`lib/core/widgets/bq_segmented.dart:43-96`) |
| Text-scale-aware extent | `MediaQuery.textScalerOf(context)` + `TextScaler.scale` | precedent: `week_strip.dart:78-79`, `planner_year_grid.dart:101-106` |
| Pushed full-screen route | `Navigator.of(context).push(MaterialPageRoute…)` | precedent: `stack_screen.dart:231-236` |
| Back affordance on a pushed route | `IconButton(Icons.arrow_back_ios_new)` + `Navigator.maybePop` | precedent: `regimen_editor_screen.dart:221-223` |
| FAB | `FloatingActionButton` + `Scaffold.floatingActionButton` | SDK; default size 56×56 (`floating_action_button.dart:783-785`, `_FABDefaultsM3.sizeConstraints`) [VERIFIED: read this session] |

### The one temptation to refuse

`NavigationBarThemeData(height: 56)`. It **would** compile — `navigation_bar.dart:281` reads `height ?? navigationBarTheme.height ?? defaults.height!` and `_NavigationBarDefaultsM2`/`M3` supply `height: 80.0` (`:1383`, `:1430`) [VERIFIED: `/opt/homebrew/share/flutter/packages/flutter/lib/src/material/navigation_bar.dart:281,1383,1430`]. Refuse it anyway, for the two reasons in §P-1 — and record *those* reasons, not the spec's "the theme cannot express it".

---

## Architecture Patterns

### System Architecture Diagram

```
                        ┌───────────────────────────────┐
   system back ────────▶│  Navigator (root, MaterialApp)│
   gear tap ───────────▶│  push/pop SettingsScreen      │
                        └───────────────┬───────────────┘
                                        │ home:
                        ┌───────────────▼─────────────────────────────┐
                        │ AppShell  (Scaffold)                        │
                        │   ├─ body: IndexedStack(index: _selected)   │
                        │   │    ├─[0] TickerMode ─ StackScreen       │
                        │   │    ├─[1] TickerMode ─ TodayScreen       │──▶ nowMinutesProvider
                        │   │    └─[2] TickerMode ─ PlannerScreen     │    (gated: enabled only)
                        │   ├─ floatingActionButton: BqAddFab ────────┼──▶ showAddSupplementSheet
                        │   └─ bottomNavigationBar: BqNavBar          │
                        │         height = fixed + scaler.scale(text) │
                        │         + SafeArea bottom inset             │
                        └───────────────┬─────────────────────────────┘
                          onSelected(i) │ setState
                                        ▼
                        (paint switches; NOTHING unmounts,
                         NOTHING disposes — see Provider lifetime)
```

Data flow into the three tabs is unchanged from v1: `stackEntriesProvider` → `cyclesModelProvider`/`yearModelProvider` (planner) and `dayDosesProvider(day)` (today). The only edge this phase moves is *which widget subtree* watches the minute ticker and the week warmer.

### Recommended file structure

```
lib/
├── app_shell.dart                     # rewritten: 3 new tabs, FAB slot, BqNavBar
├── core/widgets/
│   ├── bq_nav_bar.dart                # NEW — the hand-built bar + navBarHeightFor()
│   └── bq_add_fab.dart                # NEW (or fold into app_shell.dart)
├── features/calendar/
│   ├── today_screen.dart              # NEW — _TodayPage promoted out of calendar_screen.dart
│   ├── calendar_screen.dart           # DELETED (its only remaining job was the page swap)
│   ├── calendar_providers.dart        # CalendarPage/CalendarPageController/calendarPageProvider deleted
│   ├── planner_screen.dart            # back control deleted; chips neutralized
│   ├── planner_load_chart.dart        # threshold line, over-bar, colour bands, axis caption deleted
│   ├── planner_week_detail.dart       # verdict switch, chip, pips, free-slots half deleted
│   ├── planner_year_grid.dart         # `over` red count deleted
│   ├── planner_month_detail.dart      # monthMeta loses its limit placeholder
│   └── planner_view_model.dart        # editorialLimit/comfortLoad/LoadVerdict* deleted; load SCALE added
└── features/settings/settings_screen.dart  # gains a back control; loses nav-bar bottom padding
```

---

### P-1 — The slim bar: what a hand-built replacement owes

**What:** A `BqNavBar` that is visually 56dp at scale 1.0 and grows with the reader's text size, mounted in `AppShell`'s `Scaffold.bottomNavigationBar` slot.

**Why hand-built (the accurate rationale — do not transcribe the spec's):**

1. **A themed height would still clip.** `NavigationBar` renders `SizedBox(height: effectiveHeight)` (`navigation_bar.dart:298`) around a destination stack of a 24dp icon, a 32dp indicator (`_kIndicatorHeight = 32`, `:29`) and a label. The height is a hard box; the label inside it is not. Setting `height: 56` gives you a 56dp box that overflows the moment the text scale rises — the **CR-01 defect class**, which this codebase has already paid for twice (`week_strip.dart:63-77` documents seven bottom overflows at 1.6 and 2.0; `planner_year_grid.dart:5-17` documents the same lesson at the grid).
2. **The height must be a function, not a value.** Nothing in `NavigationBarThemeData` accepts `double Function(TextScaler)`. The rule NAV-01 states can only be expressed by owning the box.

[VERIFIED: `/opt/homebrew/share/flutter/packages/flutter/lib/src/material/navigation_bar.dart:29,281,298,1383,1430` — read this session; `frameworkVersion` `3.47.0`]

**The extent formula — copy the established idiom verbatim.** `week_strip.dart:60-79` reads, verbatim:

```dart
/// The part of the strip's height that does NOT follow the text scale: the
/// padding 9/10, the 6px and 7px gaps, the 4px dot, the 1px borders, plus the
/// design slack the mockup's 82px carries at scale 1.0.
const double _stripFixedExtent = 48;

/// The text-bearing part of a cell at scale 1.0: the mono 10 dow line plus the
/// 14px day number, with their line boxes.
const double _stripTextExtent = 34;

double stripHeightFor(TextScaler scaler) =>
    _stripFixedExtent + scaler.scale(_stripTextExtent);
```

[VERIFIED: lib/features/calendar/week_strip.dart:60-79]

The second instance of the idiom, for a two-part content box, is `planner_year_grid.dart:101-106`:

```dart
double monthCardExtentFor(TextScaler scaler, int rowCount) =>
    _monthCardFixedExtent +
    scaler.scale(_monthCardHeaderTextExtent) +
    (rowCount <= 0
        ? 0.0
        : rowCount * _barHeight + (rowCount - 1) * _barGap);
```

[VERIFIED: lib/features/calendar/planner_year_grid.dart:101-106]

**The bar's equivalent:** `navBarHeightFor(TextScaler scaler) = _navBarFixedExtent + scaler.scale(_navBarLabelExtent)`, where the fixed part carries the 22dp icon box, the icon→label gap and the vertical padding, and the scaled part carries **only the 10sp label's line box**. The icon must not scale (it is not text; `Icon` sizes from `IconThemeData`, not the text scaler), which is exactly why splitting the extent is correct rather than multiplying the whole 56.

**Safe area:** `NavigationBar` wraps itself in `SafeArea(maintainBottomViewPadding: …)` (`navigation_bar.dart:290-292`) [VERIFIED]. A hand-built bar must supply its own — `SafeArea(top: false, child: SizedBox(height: navBarHeightFor(...), child: …))` inside the decorated `Container`, so the hairline border and `surfaceAlt` fill run to the physical screen edge while the touch targets sit above the home indicator. The v1 shell relied on `NavigationBar` for this (`app_shell.dart:19-23` records it as an accepted deviation) — that reliance disappears with the widget.

**Do not lose:** the 1px `BqColors.hairline` top border and `BqColors.surfaceAlt` fill (`app_shell.dart:56-62`) survive verbatim; the mockup-exact `EdgeInsetsDirectional.only(top: 10, start: 22, end: 22)` (`:64`) is re-derived for the tighter bar and stays a hardcoded pixel value per the UI-SPEC spacing exemption recorded in `tokens.dart:213-216`.

---

### P-2 — Semantics parity: what `NavigationBar` gave for free

A hand-built bar silently drops accessibility affordances unless they are re-declared. Flutter's own bar declares, verbatim:

- `role: SemanticsRole.tabBar, explicitChildNodes: true, container: true` on the bar (`navigation_bar.dart:293-296`)
- per destination: `MergeSemantics` → `Semantics(role: SemanticsRole.tab, selected: i == selectedIndex, …)` (`:302-307`)

[VERIFIED: `/opt/homebrew/share/flutter/packages/flutter/lib/src/material/navigation_bar.dart:293-307`]

**The `BqNavBar` contract, therefore:**

| Property | Requirement | Codebase precedent |
|---|---|---|
| Container node | `Semantics(container: true, explicitChildNodes: true, role: SemanticsRole.tabBar)` | new — no precedent, take it from the SDK |
| Per-tab node | `MergeSemantics` → `Semantics(button: true, selected: …, label: <ARB label>, excludeSemantics: true, onTap: select)` | `week_strip.dart:249-261`, `bq_segmented.dart:56-64` |
| **`onTap` on the Semantics node itself** | **mandatory** — `excludeSemantics: true` drops every descendant action | `week_strip.dart:255-260` states the WR-02 lesson verbatim: *"the action lives on THIS node, not on the GestureDetector below it… without this a cell announced itself as a button that VoiceOver / TalkBack could not activate"* |
| Press feedback | either `InkResponse` (like `planner_year_grid.dart:238-249`) or an opacity change (like `planner_load_chart.dart:305-308`, *"The opacity change IS the press feedback; no ripple"*) | both precedented — choose one and say which |
| Tap target | `HitTestBehavior.opaque` over the whole cell, not the glyph | `week_strip.dart:263-265` |
| RTL | `EdgeInsetsDirectional` / `PositionedDirectional` only, and `Row` order flows from `Directionality` automatically | project-wide rule (CLAUDE.md i18n constraint) |
| Label text | no fixed-width container; `maxLines: 1, softWrap: false` is acceptable **only because the extent formula scales the line box** (the `week_strip.dart:286-290` argument) | `week_strip.dart:286-296` |

`SemanticsRole` exists on this SDK (used at `navigation_bar.dart:294`). If for any reason the role enum proves awkward, `button: true, selected: …` alone is the fallback and is what every other bespoke control in this codebase already uses — but state the downgrade explicitly rather than letting it happen silently.

---

### P-3 — Tab restructure: the complete blast radius

**A finding that shrinks the work:** the spec says *"Сьогодні gaining the week strip"*. It does not gain anything — `WeekStrip` is **already** a child of the Today page (`calendar_screen.dart:104`), and past-day browsing already lives there. What actually happens is that the file's outer wrapper is deleted and its inner page is promoted.

#### Symbols that die

| Symbol | Location | Notes |
|---|---|---|
| `enum CalendarPage { today, planner }` | `calendar_providers.dart:58` | verbatim from source |
| `class CalendarPageController` | `calendar_providers.dart:66-76` | with `showPlanner()` / `showToday()` |
| `final calendarPageProvider` | `calendar_providers.dart:79-82` | `NotifierProvider.autoDispose<CalendarPageController, CalendarPage>` |
| `class CalendarScreen` | `calendar_screen.dart:64-84` | the whole class — its body is the `PopScope`/page-swap branch |
| the `PopScope(canPop: false, onPopInvokedWithResult: …)` | `calendar_screen.dart:70-79` | back-interception |
| the `plannerTitle` `TextButton` inside the header `Wrap` | `calendar_screen.dart:197-207` | **the `Wrap` itself and the `backToToday` button at `:210-221` SURVIVE** |
| the planner's back control `Align`/`TextButton` with `'‹ ${l10n.backToToday}'` | `planner_screen.dart:136-150` | the `‹` literal disappears with it |
| `import '…/planner_screen.dart'` in `calendar_screen.dart` | `calendar_screen.dart:49` | |
| `import '…/calendar_providers.dart'` in `planner_screen.dart` | `planner_screen.dart:34` | after the back control goes, `planner_screen.dart` needs nothing from that library |

#### Consumers that must be updated

| File | Change |
|---|---|
| `lib/app_shell.dart:45-87` | children become `StackScreen()`, `TodayScreen()`, `PlannerScreen()`; destinations become `tabStack`, **a new `tabToday` key**, `tabCalendar`; `tabSettings` leaves the bar |
| `lib/features/calendar/today_screen.dart` (new) | `_TodayPage` (`calendar_screen.dart:87-111`) promoted to public `TodayScreen`; `_Header`, `_DayBody`, `_EmptyDayState`, `_Disclaimer` and `_screenPadding` move with it |
| `lib/features/calendar/planner_screen.dart:1-21` | library doc-comment rewritten: it currently asserts *"the DECIDED-1 page swap lives entirely in `calendar_screen.dart` + `calendar_providers.dart`"* — a claim about a file that no longer exists |
| `lib/features/calendar/calendar_providers.dart:31-35` | `selectedDayProvider`'s doc says *"the shell keeps the Calendar screen mounted"* — still true, but the screen is now named Today |
| `test/**` | see §Test Churn |

#### Provider lifetime under the new shell — the WR-05 question, answered

`AppShell` uses `IndexedStack` + per-child `TickerMode` (`app_shell.dart:45-55`, verbatim):

```dart
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

[VERIFIED: lib/app_shell.dart:45-55]

`IndexedStack` **builds and keeps every child mounted**; only painting is suppressed. Consequences the plan must handle explicitly:

1. **The minute ticker.** `nowMinutesProvider` is `StreamProvider.autoDispose` (`calendar_providers.dart:106`), and its doc states verbatim: *"What actually cancels the periodic subscription is the screen's `TickerMode` gate — `_DayBody` stops watching this provider while the tab is offstage, and autoDispose then tears the timer down. Keep the two together: dropping the gate silently re-arms a timer nobody is looking at."* (`:95-99`). The gate is `final visible = TickerMode.valuesOf(context).enabled;` at `calendar_screen.dart:323`. **It must move to `TodayScreen` intact.** Losing it is invisible at runtime and caught only by `test/widget/app_shell_test.dart:125`.
2. **The week warmer.** `week_strip.dart:150-151` gates `_WeekWarmer` on `TickerMode.valuesOf(context).enabled` — *"the app writes nothing at all for a calendar the user has not opened"*. It rides along with `WeekStrip` into the Today tab. No change, but verify the gate still resolves (it reads the *ambient* `TickerMode`, which is supplied by `AppShell`, so promoting the page does not break it).
3. **The planner becomes permanently mounted — and that is the fix, not the bug.** Today `PlannerScreen` mounts only while `calendarPageProvider == planner`. It holds `plannerSegmentProvider` via `ref.watch` (`planner_screen.dart:85`) and `selectedWeekProvider`/`selectedMonthProvider` via `ref.listen` (`:94-95`, whose comment explains the keep-alive: *"Switching segments unmounts a body, and these providers are autoDispose per D-23: without a listener held HERE… the user's pick is silently reset"*). Under the page swap, **returning to Today unmounted the planner and disposed all three** — so the segment reset to Цикли on every re-entry. As a tab, the screen never unmounts, so all three survive a tab switch **by construction**. This satisfies the spec's *"verify, do not rebuild"* and success criterion 2.
   ⚠️ **But it inverts an existing test expectation** if any test asserts the reset. Grep `plannerSegmentProvider` in `test/features/planner_screen_test.dart` before writing the plan.
4. **`cyclesModelProvider` / `yearModelProvider` become permanently alive.** Both are `Provider.autoDispose` watched unconditionally in `PlannerScreen.build` (`planner_providers.dart:35-54`, consumed at `planner_screen.dart:240,347`). Always-mounted means they now recompute on **every** `stackEntriesProvider` emission and at midnight, even while the user is on Стек. `buildYearModel` runs a full-year `isActiveOn` scan per regimen (`planner_view_model.dart:560-619`).
   **Assessment: acceptable, and do not gate it.** These are synchronous derivations, not subscriptions — there is no timer to leak and no Drift stream to open (`planner_providers.dart:7-17` records that the planner reaches no materializing path at all). The recompute frequency is "when the stack changes", not per frame. Gating the watch on `TickerMode` would blank the screen on re-entry and require the `_held` hold-last-value machinery from `calendar_screen.dart:250-312` for no measured benefit. **Record this as a considered decision in the plan** so a later reader does not "fix" it — and, if the planner wants a cheap safety net, add a rebuild-count assertion rather than a gate.
5. **`selectedDayProvider` / `resolvedDayProvider`** (`calendar_providers.dart:36-50`) are unaffected: already never disposed, already survive a tab round trip.

---

### P-4 — The FAB: mount it once, on the root Scaffold

**Recommendation: `Scaffold.floatingActionButton` on `AppShell`'s `Scaffold`, not on each screen's inner `Scaffold`.**

Three reasons, all structural:

1. **UX-01 becomes true by construction.** "On exactly the three tabs and nowhere else" is satisfied because the FAB lives in the same `Scaffold` as the `IndexedStack`, and Settings is now a *pushed route with its own `Scaffold`* — it can never inherit the shell's FAB. No per-screen `showFab` boolean to get wrong, and no test needed to prove a flag is set correctly on three screens.
2. **Nav-bar clearance at every text scale is free.** `Scaffold` computes the FAB's offset from the *measured* `bottomNavigationBar`. Because `BqNavBar`'s height is `navBarHeightFor(scaler)`, the FAB rises with the bar automatically. A hand-positioned `Positioned(bottom: 56 + 16)` in a `Stack` would reproduce **exactly the CR-01 class of bug this phase exists to remove** — a hardcoded offset against a scaling neighbour.
3. **Each screen's inner `Scaffold` would place it wrong.** `StackScreen` (`stack_screen.dart:46`), `_TodayPage` (`calendar_screen.dart:95`) and `PlannerScreen` (`planner_screen.dart:97`) each build their own `Scaffold` *inside* the shell's body — whose bottom edge is behind the nav bar. A FAB there would sit under the bar.

**`FloatingActionButton` vs. hand-built:** use `FloatingActionButton`. It is 56×56 by default (`floating_action_button.dart:783-785`) which matches the mockup's affordance scale, it already provides ink, elevation and the correct minimum tap target, and `FloatingActionButtonLocation.endFloat` (the `Scaffold` default) is direction-aware. Style it inline (`backgroundColor: BqColors.accent`, `foregroundColor: BqColors.surface`) or via a `floatingActionButtonTheme` in `bqTheme()`; there is currently **no** `floatingActionButtonTheme` in `theme.dart` [VERIFIED: grep of `lib/core/theme/theme.dart` returned only `navigationBarTheme` at `:50`], so adding one is a clean token-only addition consistent with D-07.

**Semantics:** `FloatingActionButton.tooltip` yields a semantics label, but this codebase's rule (WR-02) is that the action and the label live on the same node. Prefer an explicit wrapper — `Semantics(button: true, label: l10n.addSupplement, excludeSemantics: true, onTap: open, child: FloatingActionButton(onPressed: open, …))` — or, minimally, pass both `tooltip:` and verify activation by `tester.semantics` rather than by tapping, which is what `test/features/stack_screen_test.dart:838` already does for the catalog rows.

**Bottom padding:** every screen body currently pads `bottom: 84` "to clear the nav bar" (`stack_screen.dart:55`, `calendar_screen.dart:343`, `planner_screen.dart:651`, `settings_screen.dart:46`). With a *slimmer* bar plus a 56dp FAB with a 16dp margin, 84 still clears both — keep it, and let the text-scale matrix prove it rather than re-deriving a number. **Settings' 84 becomes dead space** once it is a pushed route with no bar; reduce it there.

**Stack screen consequences:** delete `stack_screen.dart:82-101` (the `SizedBox(width: double.infinity, child: FilledButton(…))`) and the following `SizedBox(height: BqSpace.md)` at `:102`. Then rewrite three doc comments that become false:
- `stack_screen.dart:7-8` — *"empty: `emptyStackTitle`/`emptyStackBody` below the still-visible CTA"*
- `stack_screen.dart:181-182` — *"title + body under the CTA; the CTA above remains the single next-step affordance"*
- `calendar_screen.dart:479-480` — *"an empty stack gets the one next step that helps — named, not linked, because the nav bar is the affordance"*

---

### P-5 — Settings as a pushed route

**The route:** `Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const SettingsScreen()))`, matching `stack_screen.dart:231-236` exactly. Locale propagation into pushed routes is already proven by plan 05-04's bilingual matrix, so no new i18n concern.

**The gap the spec does not mention: `SettingsScreen` has no back affordance.** It is a bare `Scaffold` with a body-level title and no `AppBar` (`settings_screen.dart:20`: *"No `AppBar` — the title lives in the body, matching Stack, Calendar and Planner"*). As a tab that was correct. As a pushed route it strands the user on any device without a reliable back gesture. **The precedent to copy is two files over** — `regimen_editor_screen.dart:198` *"Editor top bar: back chevron, title, trailing НА ПАУЗІ badge when paused"*, implemented as `onPressed: () => Navigator.maybePop(context)` with `Icons.arrow_back_ios_new` (`:221-223`). Use `maybePop`, not `pop`, for the same reason the editor does.

**The gear control** goes in the top-right of all three screens. Each has a different header shape:
- `StackScreen` — a plain `Text(l10n.stackTitle)` as the first `ListView` child (`stack_screen.dart:58-61`); it needs a `Row` around the title.
- `TodayScreen` — a `Row` whose end child is the conditionally-present `DayProgressRing` (`calendar_screen.dart:166-230`). ⚠️ `calendar_screen.dart:186-189` warns verbatim: *"The header's title ROW above is left structurally untouched for the same reason — it never gains a third non-flexible child."* **Adding the gear here is exactly the forbidden third rigid child (WR-04).** Options: put the gear *above* the title row in its own end-aligned row, or make the trailing slot a `Row(mainAxisSize: min)` holding ring + gear and accept that its combined width is bounded. State the choice; do not discover it at scale 2.0.
- `PlannerScreen` — header `Column` (`planner_screen.dart:132-171`); the slot vacated by the deleted back control is the natural home, mirrored to the end side.

**ARB:** `tabSettings` currently serves two placements deliberately (`settings_screen.dart:49-50`: *"One key, two placements: the nav destination and this title, so the tab and its screen can never disagree"*). It is no longer a tab. Either rename it `settingsTitle` (honest, but touches `app_shell_test.dart`, `settings_screen_test.dart`, `l10n_device_test.dart`) or keep the name and accept that it lies. **Recommend the rename** — this codebase does not tolerate names that lie, and the churn is mechanical. The same key then labels the gear's `Semantics`, preserving the "one key, two placements" property.

---

### P-6 — The limit removal: complete inventory, DELETE vs. NEUTRAL

`editorialLimit = 5` and `comfortLoad = 3` are defined once, at `planner_view_model.dart:406` and `:409` [VERIFIED: lib/features/calendar/planner_view_model.dart:391-409, quoted below]:

```dart
const int editorialLimit = 5;

/// The upper bound of the comfort band (PLAN-04) — see [editorialLimit].
const int comfortLoad = 3;
```

#### DELETED outright

| Item | Location |
|---|---|
| `editorialLimit`, `comfortLoad` | `planner_view_model.dart:406`, `:409` |
| `sealed class LoadVerdict`, `ComfortVerdict`, `LimitVerdict`, `OverLimitVerdict`, `verdictOf` | `planner_view_model.dart:414-441` |
| dashed reference line: `_thresholdOffset`, `_dashOn`, `_dashOff`, `_thresholdWidth`, the `PositionedDirectional(key: ValueKey('load-threshold'))`, `_ThresholdLinePainter` | `planner_load_chart.dart:73-77`, `:177-184`, `:371-391` |
| the over-limit bar segment: `overHeight`, the `load-over-$index` `Container` | `planner_load_chart.dart:269-272`, `:321-332` |
| the axis caption `_AxisLabel(text: l10n.loadAxisLegend(editorialLimit, comfortLoad))` | `planner_load_chart.dart:199-202` |
| the limit badge `Text(l10n.limitBadge(editorialLimit))` | `planner_screen.dart:319-329` |
| the verdict switch + `week-verdict-chip` `Container` | `planner_week_detail.dart:90-113`, `:166-188` |
| `_SlotPips` (the "free slots" visual) and its call site | `planner_week_detail.dart:192`, `:244-284` |
| the free-slots half of the meta line and `final free = editorialLimit - load;` | `planner_week_detail.dart:85`, `:153-154` |
| the verdict `note` `Text` | `planner_week_detail.dart:223-232` |
| the Рік footnote `yearFootnote(substancesLimitCount(editorialLimit))` | `planner_screen.dart:353-354` |
| `BqColors.thresholdDash` (its only consumer is the deleted painter) | `tokens.dart:142-150` |

#### NEUTRALIZED (kept, judgement removed)

| Item | Before | After |
|---|---|---|
| load-chart bar colour | `load <= comfortLoad ? loadBar : load <= editorialLimit ? warn : risk` (`planner_load_chart.dart:273-277`) | always `BqColors.loadBar` |
| Цикли summary chip colours | `atLimit ? warn/warnBg : calm/calmBg` (`planner_screen.dart:284-286`) | one neutral pair at every load |
| Рік peak chip colours | `over ? warn/warnBg : calm/calmBg` (`planner_screen.dart:408-410`) | one neutral pair |
| month-card count colour | `over ? BqColors.risk : BqColors.textFaint` (`planner_year_grid.dart:296`), with `final over = month.load > editorialLimit;` (`:202`) | always `textFaint` |
| month-detail meta | `l10n.monthMeta(substancesCount(rows.length), editorialLimit)` (`planner_month_detail.dart:142-145`) | a one-placeholder count |
| week-detail meta line | `weekLoadLabel(load, slotsCount(editorialLimit))` (`planner_week_detail.dart:153`) | `substancesCount(load)` |
| load-chart bar **height** | `min(load, editorialLimit) / editorialLimit * 38` (`planner_load_chart.dart:266-268`) | `round(load / scheduledCount * 38)` — **Q1 is RESOLVED by spec §3.1**: the denominator is the number of supplements carrying a schedule |

#### Colours that must NOT be deleted

`BqColors.risk` / `riskBg` are load-bearing outside the planner: `regimen_editor_screen.dart:902-904` and `:1017-1018` (the delete control). `BqColors.warn` / `warnBg` likewise: `dose_row.dart:207` (overdue label) and `day_block_section.dart:197-198`. [VERIFIED: grep over `lib/` this session]. Only `thresholdDash` becomes orphaned. Note `theme_test.dart` may assert token presence — check before deleting.

---

### P-7 — Copy, ARB and the gates

#### ARB keys deleted (13)

`limitBadge`, `loadAxisLegend`, `verdictComfort`, `verdictLimit`, `verdictOverLimit`, `weekNoteComfort`, `weekNoteLimit`, `weekNoteOverLimit`, `weekFreeSlots`, `weekNoFreeSlots`, `weekLoadLabel`, `substancesLimitCount`, `slotsCount`, `cyclesCount`.

Usage check confirming each is orphaned by the removal [VERIFIED: grep over `lib/` excluding `gen/`, this session]:

| Key | Only consumers |
|---|---|
| `slotsCount` | `planner_week_detail.dart`, `planner_load_chart.dart` — both deleted call sites |
| `cyclesCount` | `planner_week_detail.dart` only (inside `weekNoteOverLimit`) |
| `substancesLimitCount` | `planner_screen.dart` only (inside `yearFootnote`) |
| `limitBadge`, `plannerThisWeek`, `yearFootnote` | `planner_screen.dart` |
| `weekLoadLabel` | `planner_week_detail.dart`, `planner_load_chart.dart` |
| `monthMeta` | `planner_month_detail.dart` |

Keys that **stay**: `substancesCount` (three consumers, neutral), `periodsCount` (`planner_gantt.dart`), `weeksCount` (**regimen editor** — not planner copy, do not delete).

#### ARB keys changed

- `monthMeta` — `"{count} · межа {max}"` → one placeholder, no `межа`.
- `weekBarSemantics` — `"{range}, {load}"`; its `load` argument was `weekLoadLabel(load, slotsCount(limit))` (`planner_load_chart.dart:292`) → becomes `substancesCount(load)`. Key text unchanged; call site changes.
- **`plannerDisclaimer` — MUST be rewritten.** Current uk: `"Межа в 5 речовин — наше редакційне правило для зручності відстеження, а не медичний норматив. Освітній матеріал, не медична порада."` (`app_uk.arb:160`); en at `app_en.arb:847`. [VERIFIED, quoted verbatim]. It names the limit twice. See §PF-7 for the constraint the rewrite must satisfy.

#### ARB keys added

| Key | Purpose |
|---|---|
| `tabToday` | the new middle destination label (uk «Сьогодні») — ⚠️ **not** `backToToday`, which is the Today header's escape-hatch control and must stay a distinct string even if the words match today |
| `settingsTitle` (rename of `tabSettings`) | gear semantics label + settings screen title |
| (optional) a neutral Рік closing note replacing `yearFootnote` | spec §3 keeps the matrix; a neutral footnote is discretionary |

`addSupplement` (`app_uk.arb:22`, "Додати добавку") is **reused** for the FAB semantics — no new key. `emptyStackBody` (`app_uk.arb:19`, "Додайте першу добавку — з каталогу або вручну.") is repointed at the + button per spec §4. `emptyDayBodyNoStack` and `emptyPlannerBody` reference «вкладці «Стек»» — still accurate, no change.

#### The forbidden-vocabulary gate: tightening it correctly

`test/l10n/planner_copy_safety_test.dart` currently has three moving parts:

1. `forbiddenVocabulary` — add `межа`/`меж`, `перевищ`, and move `норма` **out of** the negation-only list into this one (the spec's "stricter"). ⚠️ **Do this only after the disclaimer rewrite lands**, or the gate fails on approved copy.
2. `negationOnlyVocabulary` + `negationBearingKeys` — become dead once `plannerDisclaimer` no longer denies a medical standard. Delete both, do not leave them as an unused permission (the `no_hardcoded_strings_test.dart:636` idiom — *"every allowlist entry still classifies something in the tree"* — is the right instinct even though the copy gate does not enforce it).
3. **`expect(arbKeys.length, greaterThanOrEqualTo(40))`** — this floor is the "gate that can't fail" tripwire, and **it WILL fail.** The planner surface is **50 keys today** [VERIFIED: computed this session from `app_en.arb` against the test's own `plannerKeyPrefixes` + `plannerKeysExact`]; deleting 13 leaves ~37. The floor must be re-derived to the true post-removal count and the new number written into the test with a reason, so a *later* silent shrink still trips it. Deleting entries from `plannerKeysExact` (`limitBadge`, `substancesLimitCount`, `slotsCount`, `cyclesCount`) is also required, or the `covered.difference(arbKeys)` assertion fails.
4. The trailing standalone test — *"the over-limit note ships truncated — the fat-soluble clause is never restored"* — asserts on `weekNoteOverLimit`, which no longer exists. **Delete the test, keep `'жиророзчин'` and `'fat-soluble'` in `forbiddenVocabulary`** — the guarantee survives as a vocabulary rule even after its subject key is gone.

#### `test/l10n/plurals_test.dart`

Lines `80-123` assert CLDR forms for `cyclesCount`, `slotsCount`, `substancesLimitCount` and `weekLoadLabel(…, slotsCount(…))` [VERIFIED: read this session]. All four tests are deleted with their keys. `arb_parity_test.dart` and `new_language_contract_test.dart` derive from the ARB and self-adjust; neither has an unused-key detector [VERIFIED: grep for `unused|orphan|referenced` returned nothing], so **orphaned keys will not fail a test — the deletions must be done by hand and reviewed by hand.**

---

## Don't Hand-Roll

| Problem | Don't build | Use instead | Why |
|---|---|---|---|
| FAB nav-bar clearance | `Positioned(bottom: barHeight + gap)` in a `Stack` | `Scaffold.floatingActionButton` on the root `Scaffold` | Scaffold measures the real bar; a literal offset re-creates CR-01 against a scaling neighbour |
| FAB geometry / ink / min tap size | a `Container` + `GestureDetector` circle | `FloatingActionButton` | 56×56, elevation and ink are SDK defaults (`floating_action_button.dart:783-785`) |
| Back navigation from Settings | a custom pop handler | `Navigator.maybePop` + `Icons.arrow_back_ios_new` | precedent at `regimen_editor_screen.dart:221-223`, incl. the double-pop guard reasoning at `:838`, `:996` |
| Bar-height scaling | a magic multiplier on 56 | `fixed + scaler.scale(textPart)` | the established idiom, twice: `week_strip.dart:78-79`, `planner_year_grid.dart:101-106` |
| Tab semantics | a bare `GestureDetector` | `Semantics(button/selected/label, onTap:) → GestureDetector` | WR-02: `excludeSemantics` drops descendant actions (`week_strip.dart:255-260`) |
| A charting package for the neutralized load chart | `fl_chart` | plain `Row`/`Expanded`/`Container` | CLAUDE.md "What NOT to Use" rejects `fl_chart` by name; `planner_load_chart.dart:5-7` restates it |
| Keeping the planner's week/month selection alive | new keep-alive machinery | nothing — the tab move does it | `planner_providers.dart:114-176` identity-based resolution already handles staleness |

**Key insight:** every "new" widget in this phase has a twin already in the repo. The correct move is transcription, not invention — and the doc comments on those twins record *why* each shape was chosen, which is what a fresh implementation would lose.

---

## Common Pitfalls

### PF-1 — Fixed heights clip at 1.6 / 2.0 (the CR-01 class)
**What goes wrong:** a `SizedBox(height: 56)` around a label that grows. **Why:** `Icon` does not scale with text but `Text` does, and a constant reserves for neither. **Avoid:** the `navBarHeightFor(scaler)` split; scale only the label's line box. **Warning sign:** any bare numeric height in a widget that contains a `Text`.

### PF-2 — The bar looks fine but is unusable with a screen reader
**What goes wrong:** `Semantics(button: true, excludeSemantics: true)` wrapping a `GestureDetector` whose `onTap` is then dropped. **Why:** `excludeSemantics` removes descendant actions. **Avoid:** put `onTap` on the `Semantics` node *and* the detector, as `week_strip.dart:255-265` does. **Warning sign:** a test that taps by coordinate passes while `SemanticsAction.tap` finds nothing.

### PF-3 — The minute ticker silently re-arms or silently dies
**What goes wrong:** the `TickerMode.valuesOf(context).enabled` read at `calendar_screen.dart:323` is dropped or moved to the wrong tab during the file split. **Why:** `autoDispose` alone does nothing under `IndexedStack`. **Avoid:** move the gate with the widget; keep `app_shell_test.dart:125` green (retargeted at `Сьогодні`). **Warning sign:** `container.exists(nowMinutesProvider)` true while on the Stack tab.

### PF-4 — The Today header gains a forbidden third rigid child
**What goes wrong:** the gear is dropped into the header `Row` beside the ring. **Why:** `calendar_screen.dart:186-189` records verbatim that this row *"never gains a third non-flexible child"* (WR-04). **Avoid:** a separate end-aligned row, or a bounded trailing group. **Warning sign:** overflow at textScaler 2.0 in uk only.

### PF-5 — `backToToday` and the new `tabToday` are collapsed into one key
**What goes wrong:** the nav label reuses `backToToday` because both read «Сьогодні». **Why:** they are different strings that happen to match in uk; en already differs contextually, and a future locale will diverge. **Avoid:** mint `tabToday`. **Warning sign:** an ARB description that has to describe two unrelated placements.

### PF-6 — A pushed Settings with no way back
**What goes wrong:** `SettingsScreen` ships as a route with no `AppBar` and no chevron. **Why:** it was designed as a tab (`settings_screen.dart:20`). **Avoid:** the `regimen_editor_screen.dart:221-223` pattern. **Warning sign:** the change passes every widget test (tests pop programmatically) and fails the first manual run.

### PF-7 — The disclaimer rewrite breaks its own gate
**What goes wrong:** `plannerDisclaimer` is reduced to the educational sentence. **Why:** `planner_copy_safety_test.dart` asserts, verbatim, `expect(l10n.plannerDisclaimer.length, greaterThan(l10n.disclaimerEducational.length))` **and** `expect(l10n.plannerDisclaimer.contains(l10n.disclaimerEducational), isTrue)`. **Avoid:** rewrite to a neutral sentence that *still adds* something and *still ends with* `disclaimerEducational` verbatim — e.g. uk «Планувальник показує, як ваші цикли накладаються в часі. Освітній матеріал, не медична порада.» Both assertions then keep working unchanged, which is the cheapest correct outcome.

### PF-8 — The copy-safety floor (`>= 40`) turns the gate into a red herring
**What goes wrong:** the planner ARB surface drops to ~37 and a gate about *vocabulary* fails with a message about *coverage*, during a commit that is deleting copy on purpose. **Why:** the floor exists to catch a prefix filter that stopped matching (a real failure mode), but cannot distinguish it from an intentional shrink. **Avoid:** re-derive and rewrite the floor in the same commit as the deletions, with the new count and a one-line reason. **Warning sign:** the temptation to "just lower it a bit" — lower it to the *measured* count.

### PF-9 — Deleting a colour token that another feature uses
**What goes wrong:** `BqColors.risk` is removed with the over-limit bar. **Why:** it is also the regimen editor's delete-control colour (`regimen_editor_screen.dart:902-904`, `:1017-1018`). **Avoid:** only `thresholdDash` is orphaned. **Warning sign:** `theme_test.dart` failing for a screen this phase never touched.

### PF-10 — The load chart cannot be drawn after the constant is deleted
See §Q1 — **already decided, not an open decision.** Spec §3.1 supplies the replacement denominator (the scheduled-supplement ceiling, computed in `planner_view_model.dart`), and plan 06-05 installs it before plan 06-06 deletes the constant, so the chart is never left undrawable.

### PF-11 — `planner_invariants_test.dart`'s glob floor
`test/features/planner_invariants_test.dart:83` globs `Directory('lib/features/calendar')` and asserts a minimum file count (*"a smaller set means the glob stopped matching"*, `:124-130`). This phase **adds** `today_screen.dart` and **removes** `calendar_screen.dart` — net zero, so the floor should hold. Verify rather than assume, and note that `today_screen.dart` now enters the "no raw colour literal / no wall-clock read / no materializing path" gates it was never scanned by before. That is a *good* outcome, but it may surface pre-existing findings in code that merely moved.

---

## Code Examples

### The extent function (transcribe the idiom)

```dart
/// The part of the bar's height that does NOT follow the text scale: the 22dp
/// icon box, the icon→label gap, and the vertical padding.
const double _navBarFixedExtent = /* derive from the 56dp target at scale 1.0 */;

/// The text-bearing part at scale 1.0: the 10sp destination label's line box.
const double _navBarLabelExtent = /* the label line box only */;

/// Height reserved for the bar, for [scaler] — the `stripHeightFor` idiom
/// (week_strip.dart:78). A constant clips at 1.6 and 2.0 (CR-01); the icon
/// does not scale, so only the label extent is passed through the scaler.
double navBarHeightFor(TextScaler scaler) =>
    _navBarFixedExtent + scaler.scale(_navBarLabelExtent);
```

### The per-tab semantics node (WR-02 shape, from `week_strip.dart:249-265`)

```dart
MergeSemantics(
  child: Semantics(
    button: true,
    selected: index == selectedIndex,
    label: label,
    excludeSemantics: true,
    // The action lives on THIS node, not on the GestureDetector below it:
    // `excludeSemantics` drops every descendant action (WR-02).
    onTap: () => onSelected(index),
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onSelected(index),
      child: /* icon + label column */,
    ),
  ),
)
```

### The shell, after (shape only)

```dart
Scaffold(
  body: IndexedStack(
    index: _selectedIndex,
    children: [
      for (final (index, screen) in const <Widget>[
        StackScreen(),
        TodayScreen(),
        PlannerScreen(),
      ].indexed)
        TickerMode(enabled: index == _selectedIndex, child: screen),
    ],
  ),
  floatingActionButton: const BqAddFab(),   // three tabs, structurally
  bottomNavigationBar: BqNavBar(
    selectedIndex: _selectedIndex,
    onSelected: (i) => setState(() => _selectedIndex = i),
    destinations: [ /* tabStack, tabToday, tabCalendar */ ],
  ),
)
```

---

## Validation Rules

| # | Rule | Enforced by |
|---|---|---|
| V-1 | `navBarHeightFor(TextScaler.linear(s))` is strictly increasing in `s` and equals the 56dp target at 1.0 | pure unit test, no pump |
| V-2 | The shell renders three destinations, in the active language, with no layout exception at 1.0 / 1.6 / 2.0 × uk / en | widget matrix (extend `app_shell_test.dart:200`) |
| V-3 | `tabSettings`/`settingsTitle` appears **zero** times in the bar | widget test asserting absence |
| V-4 | Every nav destination is activatable via `SemanticsAction.tap` | semantics test (`stack_screen_test.dart:838` idiom) |
| V-5 | `nowMinutesProvider` exists only while the **Сьогодні** tab is selected | `app_shell_test.dart:125`, retargeted |
| V-6 | `grep -r "calendarPageProvider\|CalendarPage\|PopScope" lib/` returns nothing | source-glob gate (the `planner_invariants_test.dart:149` idiom) |
| V-7 | The planner segment / selected week / selected month survive a tab round trip | widget test: select → switch tab → return → assert selection |
| V-8 | The FAB is present on all three tabs and absent on the pushed Settings route | widget test |
| V-9 | Settings pushes and pops without changing `_selectedIndex` | widget test |
| V-10 | No `load-threshold`, `load-over-*`, `week-verdict-chip`, `week-pip-*` key resolves anywhere | widget test asserting `findsNothing` |
| V-11 | `grep -r "editorialLimit\|comfortLoad\|verdictOf" lib/` returns nothing | source-glob gate |
| V-12 | No planner copy contains `межа`/`меж`/`перевищ`/`норма` in either locale | `planner_copy_safety_test.dart`, tightened |
| V-13 | The planner-ARB coverage floor is re-derived, and the gate still detects a broken prefix filter | `planner_copy_safety_test.dart` |
| V-14 | `plannerDisclaimer` still renders on both segments and on the empty/error surfaces | existing tests in `planner_screen_test.dart` — must stay green |
| V-15 | ARB parity and derived plural forms stay green in both locales | `arb_parity_test.dart`, `plurals_test.dart`, `new_language_contract_test.dart` |
| V-16 | Zero new packages in `pubspec.yaml` | diff review + `pubspec.lock` unchanged except by `flutter pub get` |

---

## Edge Coverage

| # | Edge | Expected |
|---|---|---|
| E-1 | textScaler 2.0, uk, all three labels | bar grows; no overflow; labels single-line |
| E-2 | Device with a home indicator (iPhone) | bar fill + hairline reach the screen edge; targets sit above the indicator |
| E-3 | RTL directionality (future-proofing, not shipped) | destination order and FAB position mirror; no `EdgeInsets` (non-directional) anywhere new |
| E-4 | Tab switch while the day's dose stream is mid-load | held-and-inert rows behave exactly as v1 (`calendar_screen.dart:425-437`) — the hold survives the move |
| E-5 | Midnight rollover while on the Календар tab | `todayProvider` re-emits; planner window slides; the identity-keyed week selection either re-resolves or falls back to today (`planner_providers.dart:114-132`) |
| E-6 | Return to Сьогодні after browsing a past day, then switching tabs twice | the browsed day persists (`selectedDayProvider` never disposes) |
| E-7 | Push Settings from Календар, change language, pop | the planner re-renders in the new language on the tab the user left (05-04 precedent) |
| E-8 | FAB tapped while the add sheet is already open | sheet must not stack — check `showAddSupplementSheet`'s guard |
| E-9 | FAB at textScaler 2.0 over a long scrolled list | glyph size unchanged; clearance rises with the bar; last list item still reachable under `bottom: 84` |
| E-10 | A week with load 0 | the zero stub (`planner_load_chart.dart:333-343`) survives unchanged — it is not limit framing |
| E-11 | A week with load 9 (well above the old limit) | a single neutral bar; no over-segment; height per the Q1 scale |
| E-12 | A year with no coverage at all | `peakIndex < 0` → chip omitted (`planner_screen.dart:395`) — unchanged |
| E-13 | Empty stack / errored stack on both planner segments | `_EmptyPlanner` / `_PlannerError` + disclaimer unchanged (`planner_screen.dart:612-630`) |
| E-14 | A supplement deleted while its month card is selected | identity-keyed month selection degrades to today's month (`planner_providers.dart:162-176`) |

---

## Validation Architecture

`.planning/config.json` was not read this session; treat Nyquist validation as **enabled** (absent ⇒ enabled).

### Test framework

| Property | Value |
|---|---|
| Framework | `flutter_test` (SDK-bundled) + `integration_test` (SDK-bundled) |
| Config file | none — `flutter test` discovers `test/` |
| Quick run | `flutter test test/widget/app_shell_test.dart test/features/planner_screen_test.dart` |
| Full suite | `flutter test` |
| Current size | **594 `test(`/`testWidgets(` call sites under `test/`** [VERIFIED: counted this session] across 40 files; the spec's "719 tests" counts expanded matrix cases |

### Sampling rate

- **Per task commit:** the one or two files the task touches, plus `flutter analyze`.
- **Per wave merge:** `flutter test` (full) — the gates in `test/l10n/` are cross-cutting and only a full run proves them.
- **Phase gate:** full suite green, plus both on-device integration tests re-run (spec §6).

### Test churn — named files and the shape of the change

| File | Tests | Change |
|---|---|---|
| `test/widget/app_shell_test.dart` | 6 | **Every test.** `:100` asserts `find.text('Settings')` in the bar then taps it expecting an in-place swap → becomes a push. `:125` (WR-05 ticker) taps `'Календар'` expecting the ticker to start → must tap `'Сьогодні'`. `:170` "switching to Settings renders heading" → push/pop. `:200` matrix asserts `tabSettings` present → asserts absent + gear present + `tabToday` present. Add the 2.0 row (currently 1.0/1.6 only) for NAV-01. |
| `test/features/planner_screen_test.dart` | 63 | Largest churn. 4 page-swap references (`:388` back control, `:502`/`:621`/`:631` `PopScope`/`SystemNavigator.pop`, `:671` "the Today page mounts no PopScope") → **delete outright**, they assert a deleted mechanism. 22 lines referencing verdict/threshold/pip/limit → invert to absence assertions. 6 `PlannerScreen` mounts + 3 `AppShell` mounts need the new shell shape. |
| `test/features/calendar_screen_test.dart` | 71 | 2 `CalendarScreen` references → `TodayScreen`. **Zero** `plannerTitle` references [VERIFIED: `grep -c` returned 0], so the header-action deletion costs almost nothing here. `backToToday` tests (`:482`, `:504`, `:3206`) all survive. |
| `test/features/planner_invariants_test.dart` | 10 | Glob floor (`:124-130`) re-verified; the "no excluded mockup content" render pass (`:455`) and both-segments pass (`:512`) updated for the removed chrome. |
| `test/features/stack_screen_test.dart` | 23 | ~6 references to the full-width `addSupplement` button (`:767`, `:787-789`, `:861-863`, `:1064`) → retarget at the FAB; `:767` `findsOneWidget` must **not** silently start matching the FAB's label and pass for the wrong reason. |
| `test/features/settings_screen_test.dart` | 26 | 3 `AppShell`/`BoostqueApp` mounts → push route; add a back-control test. |
| `test/l10n/planner_copy_safety_test.dart` | 4 groups + 1 | `plannerCopy()` map loses 13 entries; `plannerKeysExact` loses 4; the `>= 40` floor re-derived; `negationOnly*` deleted; forbidden list widened; the trailing `weekNoteOverLimit` test deleted. |
| `test/l10n/plurals_test.dart` | — | Delete the `cyclesCount` / `slotsCount` / `substancesLimitCount` / `weekLoadLabel` tests (`:80-123`). |
| `test/theme/theme_test.dart` | — | `navigationBarTheme` assertions → either deleted or replaced by `BqNavBar` styling assertions; check for a `thresholdDash` token assertion. |
| `test/smoke_test.dart` | 1 | 2 shell references. |
| `integration_test/data03_loop_test.dart` | 1 | 2 `CalendarScreen`, 4 `AppShell` references; the device loop navigates by tab label. |
| `integration_test/l10n_device_test.dart` | 1 | 6 shell references; asserts three tab labels per locale. |

### Wave 0 gaps

- [ ] `test/core/widgets/bq_nav_bar_test.dart` — V-1, V-2, V-4 (new file)
- [ ] `test/features/today_screen_test.dart` — or extend `calendar_screen_test.dart` after the rename (decide once; do not split assertions across both)
- [ ] a FAB test file, or a FAB group inside `app_shell_test.dart` — V-8
- [ ] a source-glob gate for V-6 / V-11, following the `planner_invariants_test.dart:149` idiom

No framework install needed.

---

## Security Domain

No `security_enforcement: false` was found; the domain is assessed and is **near-empty for this phase**.

| ASVS Category | Applies | Control |
|---|---|---|
| V2 Authentication | no | offline, no accounts (locked v1 property) |
| V3 Session Management | no | none exists |
| V4 Access Control | no | single-user local DB |
| V5 Input Validation | no | this phase adds no input surface; the add sheet is unchanged |
| V6 Cryptography | no | none used |

**Threat notes specific to this phase:** (1) *information disclosure via copy* — the phase removes health-adjacent judgement language, which strictly reduces exposure; (2) *the platform-config gate* (`test/platform_config_test.dart`) must stay green — this phase must not add a permission or a manifest entry, and it needs none.

---

## Open Questions (RESOLVED)

### Q1 — What replaces `editorialLimit` as the load chart's height denominator? **[RESOLVED by spec §3.1 — the ceiling is the number of supplements carrying a schedule; research options A/B/C below are all rejected and must not be planned]**

> **RESOLVED by spec §3.1.** The denominator is **the number of supplements currently carrying a schedule**, computed in `planner_view_model.dart` beside the week loads (06-UI-SPEC S13, plan 06-05 Task 1). `load ≤ ceiling` then holds by construction, so no cap, no clipping and no over-bar are needed. **Options A, B and C below — including B, this section's own recommendation — are all rejected and must not be planned or implemented.** The table is kept for the record of what was considered, not as a menu.

`planner_load_chart.dart:266-268` reads, verbatim:

```dart
    final mainHeight =
        (math.min(load, editorialLimit) / editorialLimit * _barFullHeight)
            .roundToDouble();
```

Deleting `editorialLimit` deletes the y-axis. Options:

| Option | Behaviour | Cost |
|---|---|---|
| **A. Self-scaling to the window's peak** — `denominator = max(1, weeks.map(load).max)` computed in `CyclesModel` | No threshold anywhere; the tallest bar is always full height | A one-substance stack renders a full-height bar, which overstates; and the whole chart re-scales when a supplement is added, so bar heights are not comparable across sessions |
| **B. Self-scaling with a floor** — `max(peak, 3)` | Fixes the one-substance case | The floor is a number the code chose; a reviewer will ask whether it is a limit in disguise. It is *not* — it carries no colour, no copy and no verdict — but that must be documented |
| **C. Fixed scale constant** (`loadChartScale = 5`) | Smallest diff | **Rejected:** it is `editorialLimit` renamed, and a load of 8 would clip or need an over-bar — the exact thing PLAN-05 removes |

~~**Recommendation: B**, with the constant named for what it is (a *drawing scale*, not a rule), defined in `planner_view_model.dart` beside the model that computes the peak, and covered by a unit test.~~ **Superseded — do not follow this recommendation.** Spec §3.1 settled the question after this research was written: the denominator is the scheduled-supplement count, not a peak and not a constant. B is rejected along with A and C.

### Q2 — Does the Цикли summary chip keep its `calm` palette, or go fully neutral? **[ASSUMED]**

Spec §3 says the chip becomes "a plain count: N речовин цього тижня". `calm`/`calmBg` currently means "below the limit" — a *verdict*, just a friendly one. Keeping green says "you're fine", which is still an opinion. **Recommend the neutral `chip` / `textSecondary` pair** used by the schedule chips (`stack_screen.dart:377-393`), so the planner offers no opinion at all — matching spec §3's framing that the app "no longer offers any opinion". Confirm with the user.

### Q3 — Rename `tabSettings` → `settingsTitle`? **[ASSUMED]**

Mechanical churn across three test files against a name that would otherwise lie. Recommend the rename; confirm.

### Q4 — Which of `calendar_screen_test.dart`'s 71 tests move to a new `today_screen_test.dart`? **[ASSUMED]**

Recommend renaming the file wholesale rather than splitting — a split invites duplicate coverage and orphaned helpers.

---

## Environment Availability

| Dependency | Required by | Available | Version | Fallback |
|---|---|---|---|---|
| Flutter SDK | everything | ✓ | 3.47.0 (`/opt/homebrew/share/flutter`) | — |
| `flutter_test` / `integration_test` | the suite | ✓ | SDK-bundled | — |
| iOS simulator / Android emulator | device backstops (spec §6) | not probed this session | — | scope the device pass at plan time |
| `node` / gsd-tools | research seams | ✗ | — | plain file tools used throughout; provider selection and confidence tiers assigned manually |

No missing dependency blocks this phase.

---

## Assumptions Log

| # | Claim | Section | Risk if wrong |
|---|---|---|---|
| A1 | Bar-height denominator replacement (Option B) | Q1 | The chart is redrawn twice, or ships with a disguised limit — a PLAN-05 violation caught only at review |
| A2 | Summary/peak chips go fully neutral rather than staying `calm` | Q2 | The app still offers an opinion; success criterion 5 arguably unmet |
| A3 | `tabSettings` is renamed `settingsTitle` | P-5 / Q3 | Extra churn, or a key whose name lies |
| A4 | The Рік `yearFootnote` is deleted rather than rewritten neutrally | P-6 | The Рік segment loses a line the mockup had; cosmetic |
| A5 | `bottom: 84` still clears bar + FAB at every scale | P-4 | The last list item sits under the FAB at 2.0; caught by the text-scale matrix if it exists |
| A6 | `showAddSupplementSheet` already guards against double-open | E-8 | Two stacked sheets from a double tap |
| A7 | `test/theme/theme_test.dart` asserts `navigationBarTheme` and may assert `thresholdDash` | Test churn | A surprise red test in an unrelated file |
| A8 | `planner_screen_test.dart` does not assert that the segment *resets* on re-entry | P-3 | A test inverts and the tab-persistence win looks like a regression |
| A9 | Post-removal planner-ARB count is ~37 | PF-8 | The re-derived floor is wrong; recompute during the plan rather than trusting this number |

---

## Sources

### Primary (HIGH confidence — read from disk this session)

- `lib/app_shell.dart`, `lib/main.dart`
- `lib/features/calendar/`: `calendar_screen.dart`, `calendar_providers.dart`, `week_strip.dart`, `planner_screen.dart`, `planner_load_chart.dart`, `planner_week_detail.dart`, `planner_year_grid.dart`, `planner_month_detail.dart`, `planner_providers.dart`, `planner_view_model.dart`
- `lib/features/stack/stack_screen.dart`, `lib/features/settings/settings_screen.dart`, `lib/core/widgets/bq_segmented.dart`, `lib/core/theme/tokens.dart`, `lib/core/theme/theme.dart` (`:30-90`)
- `lib/core/l10n/arb/app_uk.arb`, `lib/core/l10n/arb/app_en.arb`
- `test/widget/app_shell_test.dart`, `test/l10n/planner_copy_safety_test.dart` (full), plus targeted reads of `plurals_test.dart`, `no_hardcoded_strings_test.dart`, `arb_parity_test.dart`, `planner_invariants_test.dart`, `planner_screen_test.dart`, `calendar_screen_test.dart`, `stack_screen_test.dart`
- **Flutter SDK source:** `/opt/homebrew/share/flutter/packages/flutter/lib/src/material/navigation_bar.dart` (`:29`, `:281`, `:290-307`, `:1383`, `:1430`); `.../floating_action_button.dart` (`:783-785`); `bin/cache/flutter.version.json` (`frameworkVersion: 3.47.0`)

### Secondary (spec / roadmap — authoritative for intent, not for code facts)

- `docs/superpowers/specs/2026-08-17-boostque-v1.1-design.md` §1, §3, §4, §5, §6, §7
- `.planning/ROADMAP.md` — Phase 6 goal and five success criteria
- `.planning/phases/04-planner-views/04-UI-SPEC.md` §"Forbidden vocabulary", S4-amendment, S6
- `.claude/CLAUDE.md` — locked stack and constraints

### Not consulted

No web search, no Context7, no package registry lookups — **no external dependency is added or changed by this phase**, so there is nothing whose version could be stale. `gsd-tools` was unavailable (`node` absent from the sandbox); provider-selection and confidence tiers were assigned by hand per the source hierarchy.

---

## Metadata

**Confidence breakdown**

| Area | Level | Reason |
|---|---|---|
| Code inventory / blast radius | HIGH | Every symbol cited with a file and line range, read this session; no claim rests on grep alone |
| Flutter SDK behaviour (`NavigationBar`, FAB) | HIGH | Read from the installed 3.47.0 source, with line numbers |
| Test churn estimate | HIGH on *which files*, MEDIUM on *how many assertions* | File-level counts are measured; the per-assertion shape inside 2 987- and 3 497-line files is sampled, not exhaustive |
| ARB / gate impact | HIGH | Key counts computed from `app_en.arb` against the gate's own filters |
| The load-chart scale (Q1) | LOW — **decision required** | The spec did not settle it; three options with real trade-offs |
| Chip neutrality (Q2) | LOW — **decision required** | Reasonable people differ; the spec's wording supports either |

**Package legitimacy audit:** not applicable — **zero packages installed or changed by this phase.**

**Research date:** 2026-08-17
**Valid until:** 2026-09-16 (30 days — the codebase facts are stable; re-verify the Flutter SDK line numbers after any `flutter upgrade`)
