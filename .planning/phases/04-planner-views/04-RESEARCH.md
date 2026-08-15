# Phase 4: Planner Views - Research

**Researched:** 2026-08-16
**Domain:** Flutter feature UI + pure view-model derivation — the Планувальник screen (~4-month Cycles gantt, weekly concurrent-load chart with inline week detail, 12-month Year coverage matrix with inline month detail), all computed from `isActiveOn` over regimens with ZERO database writes and ZERO IntakeLog materialization, over the Phase-1/2/3 domain/DB/provider foundation
**Confidence:** HIGH for computation strategy, mockup extraction and integration (every claim cites a file+line range read this session, with verbatim quotes); MEDIUM for navigation/IA (the mockup shows the planner screens but no entry affordance — an invented seam, flagged); LOW for the handful of invented UX bits (empty states, touch-target mitigation), all tagged ASSUMED with cheap reversal paths

<user_constraints>
## User Constraints (no CONTEXT.md exists — sources: approved design spec `docs/superpowers/specs/2026-08-14-boostque-v1-design.md`, `.claude/CLAUDE.md`, REQUIREMENTS.md, ROADMAP.md Phase 4, Phase-1/2/3 locked decisions)

### Locked Decisions
- Flutter + Dart single codebase; Riverpod + Drift; UI depends on repository interfaces only — Drift types never appear in `features/` [VERIFIED: .claude/CLAUDE.md "Constraints"; lib/core/providers.dart:42-58]
- **All calendar views are computed projections, never stored** — "Three tables; all calendar views are computed projections, never stored." [VERIFIED: docs/superpowers/specs/2026-08-14-boostque-v1-design.md:67]
- **Cycles/Year live in the calendar feature** — spec structure comment: `calendar/    # Day / Cycles / Year views, mark-as-taken` [VERIFIED: docs/superpowers/specs/2026-08-14-boostque-v1-design.md:54]
- Date-only values normalized as `DateTime.utc(y,m,d)`; **domain never reads the clock** (D-13/D-15) — every date comparison via `dateOnly()` [VERIFIED: lib/core/domain/cycle_math.dart:1-16]
- `isActiveOn` is the single activity decision point [VERIFIED: lib/core/domain/cycle_math.dart:26-45]
- Paused regimens produce no doses and show ПАУЗА status (REGI-04) [VERIFIED: .planning/REQUIREMENTS.md:22]
- Riverpod dispose policy (D-23): app-lifetime repo/stream providers NOT autoDispose; screen-scoped state MAY be autoDispose — "This file is the single place this policy is recorded; do not re-litigate it per provider." [VERIFIED: lib/core/providers.dart:5-11]
- Token-only styling (D-07): "every later phase styles UI exclusively through these constants and `bqTheme()` — no ad-hoc hex literals anywhere else in the codebase, ever." [VERIFIED: lib/core/theme/tokens.dart:5-7]
- Zero hardcoded user-visible strings (gen-l10n en/uk ARBs, all four uk CLDR plural forms); `EdgeInsetsDirectional` only; no fixed-width text containers [VERIFIED: .claude/CLAUDE.md "Constraints"]
- **No charting package, no calendar package** — "Recommend building them as plain Flutter widgets (`Row`/`Stack`/`CustomPaint`) sized directly off the design tokens, which also guarantees exact mockup fidelity that a generic charting library would fight against"; `fl_chart` explicitly relegated to fallback-only, `table_calendar`-style packages explicitly rejected [VERIFIED: .claude/CLAUDE.md "Alternatives Considered" + "What NOT to Use"]
- **The 5-substance limit is editorial, never medical** — Out of Scope: "Treating the 5-substance limit as a safety threshold | It is an editorial tracking-comfort rule; presenting it as medical invites store-review and liability problems" [VERIFIED: .planning/REQUIREMENTS.md:84]
- **Naive/partial interaction checking is never-ship** — "High liability; research verdict: never ship a lightweight version" [VERIFIED: .planning/REQUIREMENTS.md:78]; ADVI-01 ("never a naive version") is v2 [VERIFIED: .planning/REQUIREMENTS.md:70]
- Mockup `claude_design_mockup/Boostque v0.1.dc.html` is the authoritative visual reference — screen 03 · ЦИКЛИ (lines 276-388) and screen 04 · РІК (lines 390-468) for this phase
- Three-tab shell (Stack / Calendar / Settings) is a Phase-1 success criterion [VERIFIED: .planning/ROADMAP.md:31] — a 4th tab is out of bounds

### Claude's Discretion
- Navigation seam: how the user reaches the planner from the Calendar tab (the mockup shows no entry affordance anywhere — see P-3 and Open Question 1)
- Week-bucket alignment for the load chart (mockup uses window-aligned 7-day buckets; Monday alignment is available and matches DECIDED-4 — see P-6)
- Empty states (no supplements at all; a supplement with no regimen) — the mockup shows none
- Whether a currently-running segment splits at today into active + planned halves, or stays wholly "active" (mockup rule is whole-segment — see P-5)
- File decomposition inside `features/calendar/`, widget structure, painter granularity
- Touch-target strategy for the 18-bar load chart

### Deferred Ideas (OUT OF SCOPE)
- Everything in the mockup's planner screens that implies interaction data: the `є взаємодія` gantt legend entry and the risk-red segment styling it drives (mockup lines 328, 635, 639, 648) — naive interaction checking is never-ship
- The `Зсунути цикл` / `Порівняти тижні` action buttons (mockup lines 370-373) — no requirement covers them, and "shift cycle" is a scheduling mutation this phase has no mandate for
- The `+ Додати` FAB on the planner screens (mockup lines 377-380, 457-460) — the add flow lives on the Stack tab
- The `Радник` / `Профіль` nav destinations (mockup lines 383-384) — the app ships three tabs
- Quality scores, ratings, any numeric verdict on a supplement (mockup screen-level assumption: "Оцінки, взаємодії, радник, підписка й онбординг сюди не входять" [VERIFIED: claude_design_mockup/Boostque v0.1.dc.html:34])
- Language override (Phase 5), history/adherence/streaks (HIST-01, v2), notifications/widgets (v2)
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| PLAN-01 | Cycles gantt (~4-month window): one row per supplement, solid segments for active periods, hatched/lighter for planned, today marker | P-4 (window math), P-5 (run coalescing + planned rule), P-8 (gantt rendering), PF-1/PF-3/PF-6, E-1..E-6 |
| PLAN-02 | Weekly concurrent-load chart with the editorial 5-substance limit; tap a week for load, verdict, active supplements | P-6 (week buckets + load), P-7 (verdict thresholds, verbatim copy), P-9 (chart rendering + threshold line), PF-8 (touch targets), E-7/E-8 |
| PLAN-03 | Year matrix: 12 month cards with per-supplement coverage bars (lighter = planned), tap a month for details | P-10 (month-cell derivation), P-11 (grid sizing), PF-3 (leap years), PF-4 (uk month case), E-9/E-10 |
| PLAN-04 | Planner screens carry the educational disclaimer and frame the 5-substance limit as editorial, not medical | P-12 (copy inventory, verbatim uk), PF-5 (exclusion list), V-1 (validation rules), Validation Architecture (a disclaimer-presence test per segment) |
</phase_requirements>

## Project Constraints (from CLAUDE.md)

Actionable directives extracted from `.claude/CLAUDE.md` that the planner must honor in every task:

1. **Zero new packages.** The recommended stack is closed; charting packages are explicitly "alternatives considered" and rejected in favor of hand-built widgets. This phase needs none — see Standard Stack (delta).
2. **No `fl_chart`.** "the mockup's gantt … and the year matrix don't map onto any general-purpose chart type — they're bespoke layouts, not X/Y series data."
3. **No generic calendar/date-picker package** (`table_calendar` named): "Build these views as plain Flutter widgets driven directly by the `core/domain` cycle-math output."
4. **`intl` stays unpinned** — never hand-add a version constraint; re-run `flutter pub get` after any SDK bump.
5. **Locale-aware formatting via `intl`** for every date, month name and number; ICU plurals with all four uk CLDR forms.
6. **`dart analyze` warnings are build-breaking for `core/domain`** — "given how bug-prone date math is." This phase adds date-window math; treat the same bar for the planner's pure view-model.
7. **Riverpod code-gen is a style choice, not a requirement** — the codebase uses hand-written providers throughout (`lib/core/providers.dart`); stay consistent, do not introduce `@riverpod` here.
8. **Bundled fonts via the plain `fonts:` declaration**; `BqText.mono()` is the only mono accessor [VERIFIED: lib/core/theme/theme.dart:128-146].

## Summary

Phase 4 is, computationally, the cheapest phase in the project and the one with the highest chance of being built the expensive way. Every number on both planner screens — gantt segments, weekly concurrent load, monthly coverage fractions, the peak month — is a pure projection of `isActiveOn(regimen, day)` over a bounded window of days. The inputs already exist and are already live: `stackEntriesProvider` pairs supplements with their regimens off two Drift streams and re-emits on any add/edit/pause/resume/delete [VERIFIED: lib/core/providers.dart:132-144], and `todayProvider` is the app's single calendar clock, self-updating at local midnight [VERIFIED: lib/core/today_controller.dart:37-79]. **No new repository method, no new Drift query, and above all no `IntakeLog` row is needed anywhere in this phase.** That last point is the phase's defining constraint: Phase 3's WR-06 finding proved that reading day data through the materializing provider to colour a 4px dot made "the database grow with pager travel rather than with user intent — up to ~371 days for a strip the user may never have looked at" [VERIFIED: .planning/phases/03-daily-tracking/03-REVIEW.md:384-406]. A year matrix drawn the same way would materialize 365 days × slots on first paint. The planner must never touch `dayDosesProvider` or `ensureLogsForDay`; a grep gate belongs in the phase's verification.

The mockup is unusually generous here: it ships the entire derivation as readable JavaScript, and it declares its own architecture — "Single source of truth: day-of-year segments for 2026. Both the gantt and the year matrix derive from this." [VERIFIED: claude_design_mockup/Boostque v0.1.dc.html:629]. That is exactly the shape to reproduce in Dart: one pure function that turns a regimen plus a date window into a coalesced list of active runs, and three small projections off those runs (gantt segments, week buckets, month cells). The window itself is verified from the mockup's constants: `SPAN = 122`, `WIN_A = 212`, `TODAY = 224` [VERIFIED: claude_design_mockup/Boostque v0.1.dc.html:623-628] — day-of-year 212 in 2026 is 1 August and 224 is 13 August, which matches the Today screen's "четвер, 13 серпня" [VERIFIED: claude_design_mockup/Boostque v0.1.dc.html:207]. So the gantt window is `[first day of today's month, +4 months)` — 122 days for August 2026 — and the month gridlines fall at 31/122, 61/122, 92/122, matching the mockup's hardcoded 25.4% / 50% / 75.4% [VERIFIED: claude_design_mockup/Boostque v0.1.dc.html:302-308].

Cost at realistic scale is negligible and memoization beyond Riverpod's own provider cache is unnecessary: the gantt scans 122 days × N supplements and the year scans 365 × N, so at N = 20 that is roughly 10,000 `isActiveOn` calls per recompute, each a handful of integer operations. What matters is *where* it runs: derive it once in a `Provider` that watches `stackEntriesProvider` + `todayProvider` (recomputing only when regimens change or midnight passes), never inside a widget `build()` that a scroll can re-run every frame.

**Primary recommendation:** Build `lib/features/calendar/planner_view_model.dart` as a clockless pure library in the exact style of `day_view_model.dart` / `stack_status.dart` — `activeRuns()` coalescing an `isActiveOn` day-scan into runs, then `ganttSegments()`, `weekLoads()` and `monthCells()` projecting off those runs — expose it through one derived `Provider` per view, and render both screens as plain `Stack`/`Row`/`CustomPaint` widgets styled from Phase-4 token additions transcribed from the mockup. Ship the mockup copy verbatim, minus the exclusion list in PF-5, and put `disclaimerEducational` on both segments (the Year screen's mockup footnote omits it — a PLAN-04 gap that must be closed).

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Is a regimen active on day D | `core/domain/cycle_math.dart` (pure) | — | Already the single decision point; the planner must call it, never re-derive it (PF-1) |
| Window math (month starts, 4-month span, month lengths, Monday alignment) | `core/domain/cycle_math.dart` (pure) | — | Date arithmetic belongs with `dateOnly`; `dart analyze` treats this library as build-breaking (CLAUDE.md) |
| Runs → gantt segments / week loads / month cells | `features/calendar/planner_view_model.dart` (pure) | — | Mirrors `day_view_model.dart`: no Flutter, no l10n, no persistence imports, so nothing in it can write or read the clock |
| Caching + invalidation of the derived model | Riverpod `Provider` (`features/calendar/planner_providers.dart`) | — | Provider cache IS the memoization; invalidation comes free from `stackEntriesProvider` + `todayProvider` |
| Supplement/regimen data access | `core/providers.dart` (existing `stackEntriesProvider`) | — | Already filters soft deletes and orders deterministically; no new repository surface |
| Selected week / selected month | screen-scoped Riverpod state (autoDispose, D-23) | local `StatefulWidget` state | Same tier as `selectedDayProvider`; must be seeded from `todayProvider`, not a constant |
| Gantt row, load bars, year bars painting | `CustomPaint` widgets in `features/calendar/` | plain `Container`s in a `Stack` | Precedent `day_progress_ring.dart`; hatch fill and dashed line have no widget equivalent |
| Localized copy, month names, plural counts | ARB + `intl` `DateFormat` at the widget layer | — | Pure layer stays string-free (day_view_model precedent); month names need standalone (`LLLL`) forms (PF-4) |
| Persistence | **none — this phase writes nothing** | — | Read-only feature; the integrity rule is enforceable by grep (Security Domain) |

## Standard Stack (delta)

### New packages required: NONE

Every capability this phase needs already exists in the tree:

| Need | Already available | Evidence |
|------|-------------------|----------|
| Cycle activity for any day | `isActiveOn(Regimen, DateTime)` | [VERIFIED: lib/core/domain/cycle_math.dart:26-45] |
| Date normalization | `dateOnly(DateTime)` | [VERIFIED: lib/core/domain/cycle_math.dart:16] `DateTime dateOnly(DateTime d) => DateTime.utc(d.year, d.month, d.day);` |
| Monday-of-week arithmetic | `mondayOfWeek(DateTime)` | [VERIFIED: lib/features/calendar/week_strip.dart:87-90] `DateTime mondayOfWeek(DateTime day) { final d = dateOnly(day); return d.subtract(Duration(days: d.weekday - DateTime.monday)); }` |
| Supplements paired with regimens, live | `stackEntriesProvider` | [VERIFIED: lib/core/providers.dart:132-144] |
| Midnight-safe "today" | `todayProvider` | [VERIFIED: lib/core/today_controller.dart:78-79] |
| Segmented Рік / Цикли control | `BqSegmented` — its own doc already names this use: "Reused by the add-supplement sheet tabs, the regimen editor's Циклічно/Разовий курс toggle, and **Phase 4's Рік/Цикли toggle** — supports any number of segments (2+)." | [VERIFIED: lib/core/widgets/bq_segmented.dart:21-23] |
| Hard-edged custom painting precedent | `DayProgressRing` + `_RingPainter` | [VERIFIED: lib/features/calendar/day_progress_ring.dart:40-124] |
| Text-scale-safe computed extents precedent | `stripHeightFor(TextScaler)` | [VERIFIED: lib/features/calendar/week_strip.dart:77-78] |
| Mono numerals with tabular figures | `BqText.mono(...)` | [VERIFIED: lib/core/theme/theme.dart:128-146] |
| Alpha-tinted colors | `Color.withValues(alpha:)` — the codebase's convention | [VERIFIED: lib/features/stack/stack_screen.dart:237] `.withValues(alpha: 0.85)` |

**Explicitly rejected for this phase (CLAUDE.md, restated because a gantt/bar-chart/matrix phase is exactly where they get reached for):** `fl_chart`, `gantt_chart`/`flutter_gantt`/`gantt_view`, `table_calendar`, `syncfusion_flutter_charts`, `google_fonts`. No task in this phase may add a dependency.

### Theme delta: token additions required

All values transcribed verbatim from the mockup; hex alpha computed as `round(opacity × 255)`. These belong in a `## Token Additions` section of the phase UI-SPEC and in `lib/core/theme/tokens.dart` under a `// --- Phase-4 additions ---` banner, matching the Phase-2/3 banner convention [VERIFIED: lib/core/theme/tokens.dart:76, 107].

| Proposed token | Value | Mockup source (verbatim) |
|---|---|---|
| `plannedHatchStrong` | `Color(0x2E4A4E7C)` | `rgba(74,78,124,.18)` in `repeating-linear-gradient(115deg,rgba(74,78,124,.18) 0 4px,rgba(74,78,124,.06) 4px 8px)` [line 647] |
| `plannedHatchWeak` | `Color(0x0F4A4E7C)` | `rgba(74,78,124,.06)` [line 647] |
| `plannedBorder` | `Color(0x734A4E7C)` | `border: 'rgba(74,78,124,.45)'` [line 647] |
| `todayMarker` | `Color(0x5917171B)` | `width:1px;background:#17171B;opacity:.35` [line 305] |
| `gridline` | `Color(0x1217171B)` | `background:rgba(23,23,27,.07)` [lines 306-308] |
| `thresholdDash` | `Color(0x3817171B)` | `repeating-linear-gradient(90deg,rgba(23,23,27,.22) 0 4px,transparent 4px 8px)` [line 339] — same value as existing `checkBorder`; keep a separate name (precedent: `BqRadii.dayCell` is deliberately a separate token with the same value as `input` [VERIFIED: lib/core/theme/tokens.dart:165-167]) |
| `loadBar` | `Color(0xFF7C80AB)` | `bg: w.load > MAX_SLOTS ? T.risk.fg : (w.load > 3 ? T.warn.fg : '#7C80AB')` [line 907] |
| `monthSelectedBg` | `Color(0xFFF2F2F7)` | `bg: sel ? '#F2F2F7' : '#FBFBF9'` [line 833] |
| `yearBarTrack` | `Color(0xFFF0EFEA)` | `background:#F0EFEA` [line 423] |

Reused without addition: `BqColors.chip` `#F2F1EE` = the gantt row track [line 316] **and** the "пауза" legend swatch [line 329]; `BqColors.accent` `#4A4E7C` = active segment [line 646]; `BqColors.risk` `#A8443C` = over-limit bar [line 342]; `BqColors.surfaceAlt` `#FBFBF9` = unselected month card [line 833]; `BqColors.cardBorder` `rgba(23,23,27,.09)` = card + month-card borders [lines 300, 834]; `BqColors.checkBorder` `rgba(23,23,27,.2)` ≈ empty slot-pip border [line 774]; `BqRadii.panel` 16 = planner card radius [lines 300, 333, 352, 414, 439]. Per-supplement colors come from `Supplement.colorValue` [VERIFIED: lib/core/domain/models.dart:101] tinted with `.withValues(alpha: 0.30)` for planned bars (`r.color + '4D'` [line 841], `0x4D/255 = 0.302`) and `alpha: 0.50` for the planned month-row dot (`r.color + '80'` [line 849]).

## Package Legitimacy Audit

Not applicable — this phase installs no external packages (see Standard Stack delta). No registry lookups were required, and no package name in this document originates from a search engine or from training memory. The full dependency set remains the one locked in `pubspec.yaml` and CLAUDE.md.

**Packages removed due to [SLOP] verdict:** none
**Packages flagged as suspicious [SUS]:** none

## Architecture Patterns

### System flow (this phase)

```
Drift (existing tables)                     core/today_controller.dart
  supplements ──┐                              todayProvider (local midnight, resume-safe)
  regimens ─────┤                                      │
                ▼                                      │
core/providers.dart                                    │
  supplementsStreamProvider ─┐                         │
  regimensStreamProvider ────┴─► stackEntriesProvider ─┤
                                    (AsyncValue<List<StackEntry>>)
                                                       ▼
                    features/calendar/planner_providers.dart   [derived Provider — pure, cached]
                        plannerWindowProvider   ← first-of-month(today) .. +4 months
                        cyclesModelProvider     ← rows(segments) + weekBuckets(loads)
                        yearModelProvider       ← 12 × monthCells + peak month
                        selectedWeekProvider / selectedMonthProvider  (autoDispose, seeded from today)
                                                       │
                    features/calendar/planner_view_model.dart  [PURE: no Flutter, no l10n, no DB]
                        activeRuns(Regimen, from, to)  ──► List<DateRun>      (isActiveOn scan + coalesce)
                        ganttSegments(runs, window, today) ──► List<Segment>{active|planned}
                        weekLoads(entriesRuns, buckets) ──► List<WeekLoad>{count, names}
                        monthCells(runs, year, today) ──► List<MonthCell>{frac, full, planned}
                        verdictOf(load) ──► Verdict{comfort|limit|over}
                                                       ▼
                    features/calendar/planner_screen.dart   [render only]
                        header: Планувальник + subtitle + BqSegmented(Рік | Цикли)
                        ── Цикли: summary chip · gantt card (CustomPaint rows, gridlines,
                        │          today marker, legend) · load-chart card (bars + dashed
                        │          threshold) · inline week-detail card · disclaimer
                        └─ Рік:   peak chip · 4×3 month-card grid (per-supplement bars) ·
                                   legend · inline month-detail card · footnote + disclaimer

WRITES: none.  IntakeLog: never read, never created.  ensureLogsForDay: never called.
```

### P-1: The planner is a read-only projection — never a materializer

`dayDosesProvider` is the app's materialization choke point and calls `ensureLogsForDay` on every build [VERIFIED: lib/core/providers.dart:82-97]. Phase 3 already paid for reading through it at week scale and had to introduce `dayDosesReadOnlyProvider` as the fix: "The dot reads exactly the same rows; it just does not create them." [VERIFIED: lib/core/providers.dart:108-110]. At year scale even the read-only variant is wrong — it would open 365 Drift subscriptions to answer a question the regimen row already answers arithmetically.

**Rule:** `features/calendar/planner_*.dart` imports `stackEntriesProvider` and `todayProvider` and nothing else from `core/providers.dart`. Enforce by grep at review: `grep -n "dayDoses\|ensureLogsForDay\|IntakeRepository\|intakeRepoProvider" lib/features/calendar/planner_*.dart` must return nothing.

### P-2: Pure view-model in the established house style

`day_view_model.dart` states the contract this file must copy: "Top-level pure functions in the `stack_status.dart` style: `today`, `viewingToday` and `nowMinutes` arrive as explicit parameters and every date comparison goes through `dateOnly` — this file NEVER reads the clock. It imports only the three pure domain libraries: no UI framework, no l10n, no persistence" [VERIFIED: lib/features/calendar/day_view_model.dart:1-14]. Same three imports (`cycle_math.dart`, `models.dart`, `repositories.dart`), same "no user-visible strings — the renderer switches exhaustively over a sealed hierarchy and maps to ARB keys itself" rule [VERIFIED: lib/features/calendar/day_view_model.dart:12-13], same sealed-class idiom as `BlockTag` / `ScheduleSummary` for the week verdict.

**Location:** `lib/features/calendar/` per the design spec's own structure comment (`calendar/    # Day / Cycles / Year views`) [VERIFIED: docs/superpowers/specs/2026-08-14-boostque-v1-design.md:54]. Prefix the new files `planner_` so the folder stays legible: `planner_view_model.dart`, `planner_providers.dart`, `planner_screen.dart`, `planner_gantt.dart`, `planner_load_chart.dart`, `planner_year_grid.dart`. A sibling `lib/features/planner/` folder is the alternative; it contradicts the spec's enumerated structure for no functional gain, so it is not recommended.

### P-3: Navigation — the planner is a third page *inside* the Calendar tab

What the mockup proves, and what it doesn't:

- Screens 03 and 04 both keep **Календар** selected in the bottom nav (`background:#4A4E7C` on the Календар destination, `border:1.6px solid #A0A0A9` on the others) [VERIFIED: claude_design_mockup/Boostque v0.1.dc.html:382, 462] → the planner is inside the Calendar tab, not a fourth tab. A fourth tab would also break Phase-1 success criterion 1 ("a three-tab shell (Stack / Calendar / Settings)") [VERIFIED: .planning/ROADMAP.md:31].
- Screens 03/04 carry the title `Планувальник` and a two-segment `Рік | Цикли` control [VERIFIED: claude_design_mockup/Boostque v0.1.dc.html:287-292, 401-406], while screen 02 carries `Сьогодні`, a progress ring and a week strip and **no segmented control at all** [VERIFIED: claude_design_mockup/Boostque v0.1.dc.html:203-223] → the planner is a distinct screen, not a segment of the Today screen. The segmented control switches Year↔Cycles *within* the planner.
- The section caption over the whole group reads `день · цикли · рік · розклад` [VERIFIED: claude_design_mockup/Boostque v0.1.dc.html:189] — four peer screens under "Календар і планування".
- **No screen shows how to get from Сьогодні to Планувальник.** This is a genuine mockup gap; the affordance must be invented. [ASSUMED]

**Recommendation:** keep the planner inside the Calendar tab as a swapped page, not a `Navigator.push`. `AppShell` is an `IndexedStack` that "builds and KEEPS every child mounted" [VERIFIED: lib/app_shell.dart:38-45], and a root-level push would cover the `NavigationBar` that the mockup deliberately shows. A local page enum in `CalendarScreen` (`today` | `planner`) preserves the chrome exactly, keeps the existing `TickerMode` gate working, and costs no nested-`Navigator` machinery. Entry affordance: a text/icon action in the Calendar header beside the ring; return affordance: a back control in the planner header. Both are inventions — confirm at UAT (Open Question 1).

If a nested `Navigator` is preferred later for deep-linking, it is a contained refactor: the planner screen itself is unaware of how it was reached.

### P-4: The window — first of this month, four months wide

Verified constants: `const SPAN = 122; … const TODAY = 224; const WIN_A = 212;` [VERIFIED: claude_design_mockup/Boostque v0.1.dc.html:623-628]. Day-of-year 212 (0-based) in a non-leap year is 1 August (31+28+31+30+31+30+31 = 212), and 224 is 13 August — which is the day the Today screen renders [VERIFIED: claude_design_mockup/Boostque v0.1.dc.html:207 `четвер, 13 серпня`]. 122 = 31 (Aug) + 30 (Sep) + 31 (Oct) + 30 (Nov). The header labels and their widths confirm it: `<span style="width:25.4%">СЕРП</span><span style="width:24.6%">ВЕР</span><span style="width:25.4%">ЖОВ</span><span style="width:24.6%">ЛИС</span>` [VERIFIED: claude_design_mockup/Boostque v0.1.dc.html:302] — 31/122 = 25.41%, 30/122 = 24.59%.

So: `windowStart = DateTime.utc(today.year, today.month, 1)`, `windowEndExclusive = DateTime.utc(today.year, today.month + 4, 1)`, `span = windowEndExclusive.difference(windowStart).inDays`. Dart normalizes month overflow in the UTC constructor, so `month + 4` needs no manual year carry. **Column widths and gridline positions must be computed from real month lengths, never fixed at 25%** — the four-month span is 120–123 days depending on the start month (Feb..May 2027 = 28+31+30+31 = 120; Jul..Oct = 123).

Today marker position: `left = (todayIndex + 0.5) / span` — from `todayLeft: ((TODAY - WIN_A + 0.5) / SPAN * 100).toFixed(2) + '%'` [VERIFIED: claude_design_mockup/Boostque v0.1.dc.html:903]. Today is always inside the window by construction, so the marker always renders.

### P-5: Runs, and the "planned" rule

The mockup declares the architecture: "Single source of truth: day-of-year segments for 2026. Both the gantt and the year matrix derive from this." [VERIFIED: claude_design_mockup/Boostque v0.1.dc.html:629]. In the mockup, segments are hand-authored data (`segs: [[59, 114], [236, 291]]` [line 636]); in the app they are **derived by scanning `isActiveOn` day by day across the window and coalescing consecutive true days into runs**. That is the only sanctioned derivation (PF-1).

Segment kind, verbatim: `function segKind(r, s) { return s[0] > TODAY ? 'planned' : (r.risk ? 'risk' : 'active'); }` [VERIFIED: claude_design_mockup/Boostque v0.1.dc.html:639]. Stripped of the `risk` branch (PF-5), the rule is: **a run is `planned` iff its first day is strictly after today; otherwise `active`** — including the future tail of a run that has already started. This is whole-segment, not split-at-today.

Note the consistency with the Stack tab: `statusOf` returns `planned` when "today before startDate" [VERIFIED: lib/features/stack/stack_status.dart:37 `if (day.isBefore(dateOnly(r.startDate))) return StackStatus.planned;`], so for a non-paused regimen the *first* run being hatched is exactly the condition that makes its stack card read ЗАПЛАНОВАНО. Keeping the mockup rule preserves that alignment; splitting runs at today would break it. Recommend mockup-exact; the alternative (split at today so the future tail of a running cycle is hatched) is arguably more informative and is a one-line change in `ganttSegments` — flag at UAT.

Styling, verbatim: `active: { bg: '#4A4E7C', border: '#4A4E7C' }`, `planned: { bg: 'repeating-linear-gradient(115deg,rgba(74,78,124,.18) 0 4px,rgba(74,78,124,.06) 4px 8px)', border: 'rgba(74,78,124,.45)' }` [VERIFIED: claude_design_mockup/Boostque v0.1.dc.html:645-649].

### P-6: Week buckets and concurrent load

Mockup derivation, verbatim [VERIFIED: claude_design_mockup/Boostque v0.1.dc.html:763-768]:

```js
const weeks = [];
for (let i = 0; i < 18; i++) {
  const a = i * 7, b = Math.min(a + 6, SPAN - 1);
  const names = PLAN.filter(r => r.segs.some(s => overlapDays(s, a + WIN_A, b + WIN_A) > 0)).map(r => r.name);
  weeks.push({ i: i, a: a, b: b, load: names.length, names: names, range: fmtDay(a) + ' – ' + fmtDay(b) });
}
```

with `function overlapDays(s, a, b) { return Math.max(0, Math.min(s[1], b) - Math.max(s[0], a) + 1); }` [VERIFIED: claude_design_mockup/Boostque v0.1.dc.html:640].

Two things to carry over exactly: **load counts a supplement once per week if it is active on *any* day of that week** (not every day), and **18 buckets** = `ceil(122 / 7)` with the last bucket clamped to the window end.

One deliberate deviation to consider: the mockup's buckets are window-aligned (bucket 0 starts on the 1st of the month — a Saturday for August 2026), so a "week" is not a calendar week. The app already locked Monday-first weeks in every locale (DECIDED-4, "The first column is Monday everywhere … reaching for `MaterialLocalizations` here would be the bug, not the fix" [VERIFIED: lib/features/calendar/week_strip.dart:8-15]), and the top summary chip literally says "Цього тижня" [VERIFIED: claude_design_mockup/Boostque v0.1.dc.html:920] — which should mean the calendar week containing today, not a bucket that happens to straddle it. **Recommendation: Monday-align the buckets** (`first = mondayOfWeek(windowStart)`, last = the week containing `windowEnd - 1` → 18 or 19 buckets), which makes the "this week" chip honest and the axis labels real week starts. Visual result is indistinguishable; the mockup's own summary uses a hardcoded `cur = weeks[1]` [line 769], plainly a mockup artifact. Flag as a deviation in the UI-SPEC.

To do that, promote `mondayOfWeek` from `week_strip.dart` into `core/domain/cycle_math.dart` (it is pure date-only arithmetic with a DST-safety comment already [VERIFIED: lib/features/calendar/week_strip.dart:83-90]) and have the strip import it — a feature file must not import another feature's widget file.

### P-7: The verdict — three bands, editorial language, verbatim copy

Verbatim [VERIFIED: claude_design_mockup/Boostque v0.1.dc.html:777-786]:

```js
if (sel.load <= 3) {
  sel.verdict = 'КОМФОРТНО'; sel.vFg = T.calm.fg; sel.vBg = T.calm.bg;
  sel.note = 'До трьох речовин одночасно легко відстежувати: якщо щось піде не так, зрозуміло, що саме прибрати.';
} else if (sel.load <= MAX_SLOTS) {
  sel.verdict = 'МЕЖА'; sel.vFg = T.warn.fg; sel.vBg = T.warn.bg;
  sel.note = 'П\'ять — наша межа за замовчуванням. Вище стає важко відрізнити, що дає ефект, а що — побічні відчуття.';
} else {
  sel.verdict = 'ПОНАД МЕЖУ'; sel.vFg = T.risk.fg; sel.vBg = T.risk.bg;
  sel.note = 'Цього тижня перетинаються ' + sel.load + ' ' + plural(sel.load, CYCLES) + '. Варто зсунути старт частини з них або обговорити такий обсяг із лікарем — зокрема через сумарне навантаження жиророзчинними формами.';
}
```

with `const MAX_SLOTS = 5;` [VERIFIED: claude_design_mockup/Boostque v0.1.dc.html:624] and `const CYCLES = ['цикл', 'цикли', 'циклів'];` [VERIFIED: claude_design_mockup/Boostque v0.1.dc.html:658].

Model the verdict as a sealed hierarchy (`ComfortVerdict` / `LimitVerdict` / `OverLimitVerdict(load)`) so the renderer switches exhaustively and maps to ARB keys — the `BlockTag` idiom [VERIFIED: lib/features/calendar/day_view_model.dart:132-167]. The three-band thresholds (≤3, ≤5, >5) are the editorial rule, expressed as two named constants (`comfortLoad = 3`, `editorialLimit = 5`) in one place.

**Copy amendment required (PF-5):** the over-limit note's trailing clause "— зокрема через сумарне навантаження жиророзчинними формами" is a pharmacological claim the app cannot support and sits squarely inside the never-ship interaction-advice exclusion. Ship the sentence truncated: `Цього тижня перетинаються {N}. Варто зсунути старт частини з них або обговорити такий обсяг із лікарем.` — "talk to a doctor" is a referral, not advice, and is consistent with the disclaimer.

Supporting week-detail copy, verbatim: `weekLoadLabel: sel.load + ' з ' + MAX_SLOTS + ' слотів'`, `freeSlotHint: sel.load < MAX_SLOTS ? 'Вільно ' + (MAX_SLOTS - sel.load) + ' — можна планувати старт' : 'Вільних слотів немає'` [VERIFIED: claude_design_mockup/Boostque v0.1.dc.html:913, 921]. Slot pips, verbatim [VERIFIED: claude_design_mockup/Boostque v0.1.dc.html:770-776]: `for (let p = 0; p < Math.max(MAX_SLOTS, sel.load); p++)` with `bg: p >= MAX_SLOTS ? T.risk.fg : (p < sel.load ? '#4A4E7C' : '#FFFFFF')` and `border: p >= MAX_SLOTS ? T.risk.fg : (p < sel.load ? '#4A4E7C' : 'rgba(23,23,27,.2)')`.

Top summary chip, verbatim: `planSummary: 'Цього тижня одночасно ' + cur.load + ' ' + plural(cur.load, SUBST)` with palette `cur.load >= MAX_SLOTS ? T.warn : T.calm` [VERIFIED: claude_design_mockup/Boostque v0.1.dc.html:918-920] and a mono `межа 5` badge on the end [VERIFIED: claude_design_mockup/Boostque v0.1.dc.html:297].

### P-8: Rendering the gantt

Structure, verbatim from the mockup [VERIFIED: claude_design_mockup/Boostque v0.1.dc.html:300-331]: a `#FFFFFF` card (`border:1px solid rgba(23,23,27,.09); border-radius:16px; padding:16px 14px 14px`) containing a mono month-label row (`10.5px`, `letter-spacing:.05em`, `margin-bottom:9px`), then a `position:relative` block holding the today line and three gridlines as absolutely-positioned 1px full-height children, then a `flex-direction:column; gap:13px` list of rows. Each row: a baseline-aligned name (`500 13px`) + hint (`400 10.5px mono #A0A0A9`) line with `margin-bottom:6px`, then `height:11px; border-radius:6px; background:#F2F1EE` as the track, with absolutely-positioned segments (`height:11px; border-radius:6px; box-sizing:border-box`, `left`/`width` as percentages). Legend row below: `flex-wrap:wrap; gap:12px; margin-top:15px; padding-top:13px; border-top:1px solid rgba(23,23,27,.07)` with `14px × 8px` radius-4 swatches.

**Flutter mapping:**
- Outer `LayoutBuilder` to get the row width once; convert every fraction to pixels there. (`FractionallySizedBox` cannot express "left offset + width" inside a `Stack` cleanly; `Positioned` with computed pixels is exact and testable.)
- Gridlines + today marker: `Positioned(left: f * width, top: 0, bottom: 0, width: 1)` children of the rows `Stack` — a direct translation of the mockup's absolute children.
- One `CustomPaint` per row painting track + all its segments, wrapped in `Semantics(label: …)`. A row is pure geometry, and a single painter avoids N nested `Positioned` widgets per row; the precedent for hard-edged custom painting over a Material widget is `_RingPainter` [VERIFIED: lib/features/calendar/day_progress_ring.dart:84-124], including its `shouldRepaint` discipline (compare only what is painted).
- The hatch: `canvas.clipRRect(segmentRRect)` then draw 45°-ish parallel strokes at 4px on / 4px off in `plannedHatchStrong` over a `plannedHatchWeak` fill, then stroke the 1px `plannedBorder` outline. No package, ~15 lines.
- Row list is `N` supplements tall inside the page scroll view; no virtualization needed (a stack is tens of items, not thousands).

Performance: repaint cost is O(total segments) ≈ O(N × runs), typically < 100 primitives. `RepaintBoundary` around the gantt card is worth adding so the load chart's selection changes do not repaint it.

### P-9: Rendering the load chart

Verbatim geometry [VERIFIED: claude_design_mockup/Boostque v0.1.dc.html:338-349]: a `position:relative; height:46px; display:flex; align-items:flex-end; gap:3px` row; the threshold line is `position:absolute; left:0; right:0; bottom:22.8px; height:1px; background:repeating-linear-gradient(90deg,rgba(23,23,27,.22) 0 4px,transparent 4px 8px)`; each week is `flex:1; display:flex; flex-direction:column; justify-content:flex-end; cursor:pointer; opacity:{{ w.opacity }}` containing an over-bar (`border-radius:2px 2px 0 0; background:#A8443C`) above a main bar (`border-radius:2px`). Heights [VERIFIED: claude_design_mockup/Boostque v0.1.dc.html:904-910]: `h: Math.round(Math.min(w.load, MAX_SLOTS) / MAX_SLOTS * 38) + 'px'`, `over: w.load > MAX_SLOTS ? Math.round((w.load - MAX_SLOTS) / MAX_SLOTS * 38) + 'px' : '0px'`, `opacity: w.i === this.state.week ? '1' : '.5'`. Axis labels below: `1 серп` / `межа 5 · комфорт 3` / `30 лис` [VERIFIED: claude_design_mockup/Boostque v0.1.dc.html:347-349].

**Read the threshold line carefully:** `bottom:22.8px` is `0.6 × 38` = the **load-3 "комфорт" line**, not the load-5 line (which is the top of the 38px main-bar area, where the red over-bar begins). The axis caption names both — `межа 5 · комфорт 3`. PLAN-02's phrasing ("against the editorial 5-substance line") is satisfied by the red overflow + the `межа 5` badge + the pips + the verdict chip; whether to also draw a line at 38px is an open question (Open Question 2). Ship the mockup's single dashed line unless UAT says otherwise, and never label either line as a safety threshold.

**Flutter mapping:** `Stack` → [`Row` of `Expanded` week columns (each `Column(mainAxisAlignment: MainAxisAlignment.end)` with two `SizedBox`/`Container` bars, wrapped in `Opacity`), plus a `Positioned(bottom: 22.8, left: 0, right: 0, height: 1)` `CustomPaint` drawing the 4-on/4-off dashes]. All plain widgets; the only painter is the dash line.

### P-10: Month cells for the Year matrix

Verbatim derivation [VERIFIED: claude_design_mockup/Boostque v0.1.dc.html:809-821]:

```js
const cell = (r, m) => {
  const a = MONTH_START[m], b = a + MONTH_LEN[m] - 1;
  let days = 0, plannedDays = 0;
  r.segs.forEach(s => {
    const d = overlapDays(s, a, b);
    if (!d) return;
    days += d;
    if (segKind(r, s) === 'planned' || a > TODAY) plannedDays += d;
  });
  const frac = days / MONTH_LEN[m];
  return { frac: frac, full: frac >= 0.85, planned: days > 0 && plannedDays === days };
};
const monthLoad = MONTHS.map((_, m) => PLAN.filter(r => cell(r, m).frac > 0).length);
```

Bar width, verbatim: `width: c.frac === 0 ? '0%' : (c.full ? '100%' : Math.max(Math.round(c.frac * 100), 22) + '%')`, fill `bg: c.planned ? r.color + '4D' : r.color` [VERIFIED: claude_design_mockup/Boostque v0.1.dc.html:838-842]. The `max(…, 22%)` floor is what keeps a two-day coverage visible — carry it over.

Month-count colour: `countFg: monthLoad[m] > MAX_SLOTS ? T.risk.fg : '#A0A0A9'` [VERIFIED: claude_design_mockup/Boostque v0.1.dc.html:836] — strictly greater than 5 is red, which is exactly what the year footnote explains.

Peak month, verbatim [VERIFIED: claude_design_mockup/Boostque v0.1.dc.html:822-827, 967-970]: max load, ties broken toward the month nearest the current one, label `'Найщільніший місяць — ' + MONTH_NOM[peak]` or `'Найщільніші місяці, зокрема ' + MONTH_NOM[peak]` when more than one month ties, count `monthLoad[peak] + ' ' + plural(monthLoad[peak], SUBST)`, palette `monthLoad[peak] > MAX_SLOTS ? T.warn : T.calm`.

**Note the `>=` / `>` mismatch between screens:** the Cycles summary chip warns at `cur.load >= MAX_SLOTS` [line 918] while the Year peak chip warns at `monthLoad[peak] > MAX_SLOTS` [line 969]. Transcribe both verbatim (a "at the limit" week is worth an amber nudge; a month is only flagged when it exceeds), and record the asymmetry in the UI-SPEC so a later reader does not "fix" it.

Month detail rows, verbatim [VERIFIED: claude_design_mockup/Boostque v0.1.dc.html:847-852]: filter to `frac > 0`, dot tinted `+ '80'` when planned, state text `'заплановано'` / `'приймаю'` / `'частина місяця'`, muted foreground when planned.

The year is `today.year`, Jan..Dec — the mockup's `MONTH_LEN` is a hardcoded non-leap table [VERIFIED: claude_design_mockup/Boostque v0.1.dc.html:625]; the app must compute month length as `DateTime.utc(y, m + 1, 0).day` (PF-3).

### P-11: Rendering the Year grid

Verbatim [VERIFIED: claude_design_mockup/Boostque v0.1.dc.html:414-428]: a white card with `display:grid; grid-template-columns:repeat(4,1fr); gap:8px`; each month card `border-radius:11px; padding:9px 8px 10px`, selected `bg #F2F2F7` + `1.6px solid #4A4E7C`, unselected `bg #FBFBF9` + `1px solid rgba(23,23,27,.09)`; header row = mono label + mono count; then `flex-direction:column; gap:3px; margin-top:9px` of `height:4px; border-radius:2px; background:#F0EFEA` tracks each holding a filled bar.

**Card height depends on N** (`headerLine + 9 + N×4 + (N−1)×3 + 19` of padding) and on the text scaler for the header line. A `GridView.count` with a fixed `childAspectRatio` will clip or leave dead space as the stack grows — the same class of bug as CR-01/WR-04 in Phase 3. **Use `SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, mainAxisSpacing: 8, crossAxisSpacing: 8, mainAxisExtent: computedExtent)` with `shrinkWrap: true` and `NeverScrollableScrollPhysics` inside the page scroll**, computing `mainAxisExtent` exactly like `stripHeightFor` does: fixed part + `scaler.scale(textPart)` [VERIFIED: lib/features/calendar/week_strip.dart:60-78]. Equivalent alternative: three `Row`s of four `Expanded` cards inside an `IntrinsicHeight`; the computed-extent form is cheaper and has a precedent in-repo.

### P-12: Copy and i18n

Existing keys to reuse rather than duplicate:

- `disclaimerEducational` = `"Освітній матеріал, не медична порада."` / `"Educational material, not medical advice."` [VERIFIED: lib/core/l10n/arb/app_uk.arb:7; lib/core/l10n/arb/app_en.arb:19] — its `@` description already notes it is deliberately distinct from `calendarDisclaimer`, "neither key replaces the other" [VERIFIED: lib/core/l10n/arb/app_en.arb:573].
- `substancesCount` = `"{count, plural, one{{count} речовина} few{{count} речовини} many{{count} речовин} other{{count} речовини}}"` [VERIFIED: lib/core/l10n/arb/app_uk.arb:8] — added in Phase 1 and **not yet consumed anywhere in `lib/`** (grep: zero non-generated hits). This phase is its intended consumer.
- `weeksCount` [VERIFIED: lib/core/l10n/arb/app_uk.arb:9] for any week-length label.
- Composition convention: pre-format the count string and pass it into the sentence key, exactly as `cycleSummaryCyclic` does ("placeholders are pre-formatted weeksCount strings" [VERIFIED: lib/core/l10n/arb/app_en.arb:175]).

New plural key required: `cyclesCount` with all four uk forms (`цикл` / `цикли` / `циклів` / `цикли`) for the over-limit note. Full new-key inventory in Code Examples.

**Month names:** Ukrainian distinguishes the *format* (genitive, used with a day number — "13 серпня") from the *standalone* (nominative — "серпень") month name. The Calendar screen correctly uses the genitive pattern with a day (`DateFormat('EEEE, d MMMM', locale)` [VERIFIED: lib/features/calendar/calendar_screen.dart:103]). Every month name on the planner screens is standalone — the Cycles subtitle `серпень — листопад 2026` [VERIFIED: claude_design_mockup/Boostque v0.1.dc.html:288], the peak label `MONTH_NOM` list `['січень', 'лютий', …]` [VERIFIED: claude_design_mockup/Boostque v0.1.dc.html:643], the month card labels `['СІЧ','ЛЮТ',…]` [line 641] and the detail title `MONTHS_FULL` [line 642] — so they need the standalone pattern letters `LLLL` / `LLL`, not `MMMM` / `MMM`. [ASSUMED — CLDR standalone-vs-format convention from training knowledge; pin it with a unit test asserting the uk output rather than trusting it.]

### Anti-Patterns to Avoid

- **Re-deriving cycle activity** with a local `%` computation "because scanning 365 days feels wasteful" — creates a second source of truth that will silently diverge from the Today screen (PF-1).
- **Reaching for `IntakeLog`** to answer "was this supplement active in August" — the regimen answers it arithmetically and for free (P-1).
- **Computing the model inside `build()`** — a scroll then recomputes 10k `isActiveOn` calls per frame (PF-10).
- **Fixed percentage widths for month columns** (25% each) — wrong for every 4-month window except one with equal months (P-4).
- **A generic chart/gantt/calendar package** — CLAUDE.md forbids it, and none of these three layouts is an X/Y series.
- **Presenting 5 as a safety number** — any wording like "перевищено безпечну норму" is a store-review and liability problem (PLAN-04, PF-5).
- **Sheets for the week/month detail** — the mockup puts both details inline in the scroll flow (P-13 below); a modal sheet would hide the chart the user is comparing against.

### P-13: Detail panels are inline, not modal

The week detail is a card in the Cycles scroll flow immediately under the load chart [VERIFIED: claude_design_mockup/Boostque v0.1.dc.html:352-368] and the month detail is a card in the Year scroll flow under the grid + legend [VERIFIED: claude_design_mockup/Boostque v0.1.dc.html:439-453]. Both are *always visible* and simply re-render on selection (`onClick="{{ w.pick }}"` → `this.setState({ week: w.i })` [lines 341, 909]; `pick: () => this.setState({ yearMonth: m })` [line 844]). No `showModalBottomSheet` anywhere in these screens.

Data each detail needs — all already in the derived model:
- **Week:** date range (start/end), load, verdict band, free-slot count, pip array, the list of active supplement *names*, and the verdict note.
- **Month:** month index, per-supplement rows filtered to `frac > 0` with `{name, hint, planned, full}`, the row count, and the editorial limit for the meta line.

Default selection must be seeded from `todayProvider` — the week containing today and today's month (the mockup's `week: 1` is a hardcoded artifact; `yearMonth: NOW_MONTH` [VERIFIED: claude_design_mockup/Boostque v0.1.dc.html:675] already does the right thing for months).

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| "Is this regimen active on day D" | A local `(day - start) % (on + off)` in the planner | `isActiveOn` | Single decision point; it already handles paused, pre-start, course-with-null-end and cyclic edge cases [VERIFIED: lib/core/domain/cycle_math.dart:26-45] |
| Normalizing a date | `DateTime(y,m,d)` / truncating | `dateOnly()` | Local midnight breaks DST-safe day arithmetic (D-13/D-15) |
| Monday of a week | New `weekday` math | `mondayOfWeek()` (promote to `cycle_math.dart`) | Already written, documented DST-safe, and Monday-first is locked in both locales |
| Supplement + regimen pairing | A new join query | `stackEntriesProvider` / `combineStackEntries` | Already live, soft-delete-filtered, deterministically ordered [VERIFIED: lib/core/domain/repositories.dart:109-120] |
| "What day is it" | `DateTime.now()` in a widget | `todayProvider` | The app's one sanctioned calendar-clock read; midnight- and resume-safe [VERIFIED: lib/core/today_controller.dart:1-13] |
| Month length | A `[31,28,31,…]` table | `DateTime.utc(y, m + 1, 0).day` | Leap years (PF-3) |
| Segmented Рік/Цикли control | A new toggle widget | `BqSegmented` | Purpose-built and already names this exact use [VERIFIED: lib/core/widgets/bq_segmented.dart:21-23] |
| Bar charts / gantt / matrix | `fl_chart`, a gantt package | `Row`/`Stack`/`CustomPaint` off tokens | CLAUDE.md decision; these are bespoke layouts, not series data |
| Localized month names | A hardcoded `['січень', …]` list (as the mockup has) | `DateFormat('LLLL'/'LLL', locale)` | L10N-04: "zero hardcoded user-visible strings"; a table would also be wrong-cased in en |
| Plural agreement | `if (n == 1) … else …` | ICU plural ARB keys with all four uk forms | L10N-01, including the 11–14 exception |

**Key insight:** every "hard" thing on these screens is already solved one layer down. The phase's real work is layout fidelity and copy discipline, not computation.

## Validation Rules (V-1)

Rules the implementation must satisfy, checkable mechanically at review:

| # | Rule | Check |
|---|------|-------|
| V-1.1 | The planner performs zero writes | `grep -n "setStatus\|upsert\|softDelete\|ensureLogsForDay" lib/features/calendar/planner_*.dart` → empty |
| V-1.2 | The planner never materializes | `grep -n "dayDosesProvider\|dayDosesReadOnlyProvider\|intakeRepoProvider\|IntakeRepository" lib/features/calendar/planner_*.dart` → empty; plus the row-count regression test (Code Examples) |
| V-1.3 | Activity comes only from `isActiveOn` | `grep -n "%\|onDays\|offDays" lib/features/calendar/planner_view_model.dart` → only inside a comment or absent; the file's only activity call is `isActiveOn` |
| V-1.4 | The pure view-model imports nothing but the three domain libraries | `grep -n "^import" lib/features/calendar/planner_view_model.dart` → `cycle_math.dart`, `models.dart`, `repositories.dart` only |
| V-1.5 | No clock read outside `todayProvider` | `grep -n "DateTime.now()" lib/features/calendar/planner_*.dart` → empty |
| V-1.6 | Token-only styling | `grep -nE "Color\(0x|#[0-9A-Fa-f]{6}" lib/features/calendar/planner_*.dart` → empty (all colors via `BqColors` / `Supplement.colorValue`) |
| V-1.7 | Zero hardcoded user-visible strings | Every `Text(...)` argument resolves to `context.l10n.*` or an `intl` `DateFormat` output |
| V-1.8 | The disclaimer is present on **both** planner segments | Widget test asserts the `disclaimerEducational` sentence is findable with Цикли selected and with Рік selected |
| V-1.9 | No excluded mockup content ships | `grep -n "взаємодія\|Зсунути\|Порівняти\|жиророзчин" lib/ l10n ARBs` → empty |
| V-1.10 | Every count-bearing new ARB key has all four uk forms | Extend `test/l10n/plurals_test.dart` with 1 / 2 / 5 / 11 / 21 |

## Common Pitfalls

### PF-1: Re-deriving cycle activity instead of calling `isActiveOn`
**What goes wrong:** the planner computes `(dayIndex % period) < onDays` locally because it "already has the regimen". A later change to `isActiveOn` (a new regimen kind, a pre-start rule, a pause semantic) updates the Today screen and silently not the planner.
**Why it happens:** scanning 122–365 days feels wasteful next to a closed-form expression.
**How to avoid:** `activeRuns` calls `isActiveOn` per day and coalesces. It is fast (below), and it is the only way the two screens can never disagree.
**Warning signs:** `%`, `onDays`, `offDays`, or `RegimenKind` appearing inside `planner_view_model.dart`.

### PF-2: Materializing IntakeLog rows at planner scale (the WR-06 lesson, one order of magnitude worse)
**What goes wrong:** answering "which supplements are active in week 12" by reading day doses. Phase 3 documented the exact failure: "swiping the week pager materializes up to ~371 days of `IntakeLog` rows to colour a 4px dot … the database grows with pager travel, not with user intent" [VERIFIED: .planning/phases/03-daily-tracking/03-REVIEW.md:384, 400-402].
**Why it happens:** `dayDosesProvider` is the familiar path from Phase 3, and it returns a convenient joined `DayDose`.
**How to avoid:** the planner never imports it (V-1.2), and a provider test asserts the `intakeLogs` row count is unchanged after building both planner models.
**Warning signs:** any `family` provider keyed by a day inside the planner; a growing DB after opening the planner.

### PF-3: Month arithmetic done with `Duration`
**What goes wrong:** `windowStart.add(Duration(days: 122))` for "four months", or the mockup's hardcoded `MONTH_LEN = [31,28,31,…]` [VERIFIED: claude_design_mockup/Boostque v0.1.dc.html:625] carried into Dart — both wrong in a leap year and wrong for any window that is not Aug–Nov.
**How to avoid:** month boundaries via the UTC constructor (`DateTime.utc(y, m + 4, 1)`, which normalizes overflow), month length via `DateTime.utc(y, m + 1, 0).day`, and day counts only between two UTC date-only values (where `inDays` is exact — the reason the whole project normalizes to UTC [VERIFIED: lib/core/domain/cycle_math.dart:3-6]).
**Warning signs:** any `Duration(days: 30)`, `Duration(days: 365)`, or a literal month-length table in `lib/`.

### PF-4: Ukrainian month names in the wrong grammatical case
**What goes wrong:** `DateFormat.MMMM('uk')` renders the *format* (genitive) form — "серпня" — which is right in "13 серпня" and wrong standing alone in "серпень — листопад 2026" or "Найщільніший місяць — серпень".
**How to avoid:** use `LLLL`/`LLL` (standalone) for every month name that appears without a day number, and pin it with a unit test asserting the exact uk strings. Do not hardcode a month table (L10N-04).
**Warning signs:** a subtitle reading "серпня — листопада"; a month card labelled "СЕР" where the mockup says "СЕР" but the peak line says "серпня".

### PF-5: Mockup content that must NOT ship in this phase
Enumerated so the planner can put them on an explicit exclusion list:

| Mockup element | Line(s) | Why excluded |
|---|---|---|
| `є взаємодія` legend entry + the `risk` segment branch it drives | 328, 635, 639, 648 | Interaction claim — never-ship per REQUIREMENTS Out of Scope |
| `— зокрема через сумарне навантаження жиророзчинними формами` (over-limit note tail) | 785 | Pharmacological claim; truncate the sentence after "із лікарем." |
| `Зсунути цикл` / `Порівняти тижні` buttons | 371-372 | No requirement; the first is an unscoped schedule mutation |
| `+ Додати` FAB | 377-380, 457-460 | Add flow belongs to the Stack tab |
| `Радник` / `Профіль` nav destinations | 383-384, 463-464 | Three-tab shell |
| Any score / rating number | screen assumption line 34 | v0.1 explicitly excludes scores |

Plus the standing PLAN-04 rule: the 5-substance limit is only ever described with the mockup's own editorial wording ("наше редакційне правило … а не медичний норматив"); never "safe", "norm", "overdose", "exceeds the safe limit".

### PF-6: Sub-pixel and zero-width segments
**What goes wrong:** a one-day run in a 122-day window is 0.82% ≈ 2.8px on a ~340px track; rounding can collapse it to 0 and the user sees a cycle that "isn't there". The Year matrix already guards this with a 22% floor [VERIFIED: claude_design_mockup/Boostque v0.1.dc.html:840]; the gantt has no such guard.
**How to avoid:** clamp painted segment width to a ≥ 2px minimum, and keep the run's true dates in the model for the semantics label.
**Warning signs:** a supplement with a short course showing an empty track.

### PF-7: Fixed heights and non-flexible rows at accessibility text scales
**What goes wrong:** the exact defects Phase 3 shipped — a hard-coded strip height overflowing at textScaler 1.6/2.0 (CR-01) and a three-non-flexible-child header row overflowing horizontally (WR-04) [VERIFIED: .planning/phases/03-daily-tracking/03-REVIEW.md:110-137, 322-346]. This phase has three high-risk spots: the gantt row's `name` + `hint` baseline row, the month card's `label` + `count` row, and the year grid's card extent.
**How to avoid:** `Flexible` + `ellipsis` on the gantt name and hint; `mainAxisExtent` computed with `MediaQuery.textScalerOf(context)` like `stripHeightFor`; a text-scale group in the widget test at 1.0 / 1.6 / 2.0 asserting `tester.takeException()` is null (IN-08's remediation pattern).
**Warning signs:** any `SizedBox(height: <literal>)` wrapping text; any `Row` of text children with only a divider `Expanded`.

### PF-8: 18 tap targets across a 340px chart
**What goes wrong:** each week column is ~18px wide and 46px tall — well under the 44×44pt guidance, and the visible bar may be only a few px tall for a low-load week.
**How to avoid:** make the *column* the hit target with `HitTestBehavior.opaque` over the full 46px height plus padding above the bars (the Interaction-Contract-8 pattern already used for the week-strip cell: "The whole padded cell is the tap target — a 4px dot must never define it" [VERIFIED: lib/features/calendar/week_strip.dart:270-272]); put `Semantics(button: true, selected: …, label: <week range + load>, onTap: …)` on the node itself, not on a descendant (the WR-02 lesson: `excludeSemantics` drops descendant actions [VERIFIED: lib/features/calendar/week_strip.dart:262-268]); and treat the inline week-detail card as the readable surface for assistive tech.
**Warning signs:** a `GestureDetector` wrapping only the bar `Container`; a semantics probe showing `tap=false` on a week node.

### PF-9: Which rows appear at all — paused, fresh, deleted
- **Soft-deleted** supplements/regimens never arrive: both streams filter `deletedAt` [VERIFIED: lib/core/domain/repositories.dart:46, 68]. Nothing to do.
- **Paused** regimens produce zero runs automatically (`isActiveOn` returns false first thing: `if (r.paused) return false;` [VERIFIED: lib/core/domain/cycle_math.dart:27]). The mockup answers how to show them: the legend's `пауза` swatch is `background:#F2F1EE` [VERIFIED: claude_design_mockup/Boostque v0.1.dc.html:329] — the *same* colour as the row track `background:#F2F1EE` [VERIFIED: claude_design_mockup/Boostque v0.1.dc.html:316]. So a paused supplement keeps its gantt row and shows a bare track, and the legend is what explains it. It contributes 0 to every week load and every month cell, consistent with REGI-04.
- **Fresh** entries (a supplement with no regimen at all — `StackStatus.fresh` [VERIFIED: lib/features/stack/stack_status.dart:32-33]) have nothing to draw and no schedule to explain. Recommend excluding them from the gantt and the year grid. [ASSUMED — confirm at UAT.]

### PF-10: Deriving the model inside `build()`
**What goes wrong:** 10k `isActiveOn` calls per frame while the user scrolls the planner.
**How to avoid:** one `Provider` per view watching `stackEntriesProvider` + `todayProvider`; the widget only reads it. Riverpod's cache is the memoization — no manual memo, no `useMemo`-style structure needed.
**Warning signs:** `activeRuns(` appearing anywhere in a widget file.

### PF-11: A `null`-ended course silently disappears
`isActiveOn` returns false for a `course` whose `endDate` is null (`return end != null && !d.isAfter(dateOnly(end));` [VERIFIED: lib/core/domain/cycle_math.dart:34-36]). A course saved without an end therefore contributes no runs anywhere in the planner. That is correct and consistent with the Today screen, but the planner is where the user will notice — an empty row with a schedule chip. Cover it in the edge table; no special-casing in the planner.

### PF-12: Empty stack, and the Year screen's missing disclaimer
Two mockup gaps:
- The mockup has no empty state for either planner screen (its data is always seven supplements). With zero supplements the gantt card would render as an empty white box with gridlines. Invent an empty state reusing the Stack tab's tone (`emptyStackTitle` / `emptyStackBody` are the models [VERIFIED: lib/core/l10n/arb/app_uk.arb:18-19]). [ASSUMED]
- The Year footnote is `Рік показує, як цикли накладаються один на одний. Червоне число в місяці означає перевищення нашої межі у 5 речовин одночасно.` [VERIFIED: claude_design_mockup/Boostque v0.1.dc.html:454] — it does **not** contain "Освітній матеріал, не медична порада.", while the Cycles footnote does [VERIFIED: claude_design_mockup/Boostque v0.1.dc.html:374]. PLAN-04 requires *every* planner screen to carry it, so the Year screen must append the existing `disclaimerEducational` key. Recording this as a deliberate, requirement-driven addition to the mockup, not a transcription error.

## Code Examples

### Pure runs derivation (features/calendar/planner_view_model.dart — clockless, three domain imports only)

```dart
/// A maximal run of consecutive days on which a regimen is active.
/// Both bounds are INCLUSIVE, date-only UTC values.
class DateRun {
  final DateTime start;
  final DateTime end;
  const DateRun({required this.start, required this.end});
}

/// Coalesces `isActiveOn` over [from]..[toInclusive] into maximal runs.
///
/// The ONLY activity decision in the planner: never re-derive the cycle
/// formula here (PF-1). Linear in the window length; the caller runs it once
/// per regimen inside a Provider, never in build() (PF-10).
List<DateRun> activeRuns(Regimen r, DateTime from, DateTime toInclusive) {
  final runs = <DateRun>[];
  final start = dateOnly(from);
  final last = dateOnly(toInclusive);
  DateTime? openFrom;
  DateTime? openTo;
  for (var d = start; !d.isAfter(last); d = d.add(const Duration(days: 1))) {
    if (isActiveOn(r, d)) {
      openFrom ??= d;
      openTo = d;
    } else if (openFrom != null) {
      runs.add(DateRun(start: openFrom, end: openTo!));
      openFrom = null;
      openTo = null;
    }
  }
  if (openFrom != null) runs.add(DateRun(start: openFrom, end: openTo!));
  return runs;
}
```

`d.add(const Duration(days: 1))` is exact here because `d` is a UTC date-only value — the same guarantee `cycle_math.dart` relies on ("Exact on UTC date-only values: every day is precisely 24h in UTC." [VERIFIED: lib/core/domain/cycle_math.dart:41]).

### Window helpers (core/domain/cycle_math.dart additions — pure)

```dart
/// First day of [d]'s month, date-only UTC.
DateTime firstOfMonth(DateTime d) => DateTime.utc(d.year, d.month, 1);

/// [months] whole months after [d]'s month start. The UTC constructor
/// normalizes month overflow, so no year carry is needed (PF-3).
DateTime addMonths(DateTime d, int months) =>
    DateTime.utc(d.year, d.month + months, 1);

/// Number of days in the month of [d] — leap-year correct (PF-3).
int daysInMonth(DateTime d) => DateTime.utc(d.year, d.month + 1, 0).day;

/// The ~4-month planner window: [first of today's month, +4 months).
({DateTime start, DateTime endExclusive, int span}) plannerWindow(DateTime today) {
  final start = firstOfMonth(today);
  final endExclusive = addMonths(start, 4);
  return (
    start: start,
    endExclusive: endExclusive,
    span: endExclusive.difference(start).inDays, // 120..123, never assumed 122
  );
}
```

### Week buckets and load (pure)

```dart
/// One 7-day bucket of the load chart.
class WeekBucket {
  final DateTime start;        // Monday, date-only UTC
  final DateTime endInclusive; // start + 6, clamped to the window end
  const WeekBucket({required this.start, required this.endInclusive});
}

/// Load of a bucket: a supplement counts ONCE if it is active on ANY day of
/// the bucket (mockup rule, line 766).
class WeekLoad {
  final WeekBucket bucket;
  final List<String> supplementIds; // display order == stack order
  int get load => supplementIds.length;
  const WeekLoad({required this.bucket, required this.supplementIds});
}

bool _overlaps(DateRun r, DateTime a, DateTime b) =>
    !r.start.isAfter(b) && !r.end.isBefore(a);
```

### Verdict (sealed — the `BlockTag` idiom, no strings)

```dart
/// Editorial comfort rule (PLAN-04): NOT a medical threshold. Both numbers
/// live here once and are named for what they are.
const int editorialLimit = 5;   // mockup MAX_SLOTS (line 624)
const int comfortLoad = 3;      // mockup verdict boundary (line 777)

sealed class LoadVerdict { const LoadVerdict(); }
class ComfortVerdict extends LoadVerdict { const ComfortVerdict(); }
class LimitVerdict extends LoadVerdict { const LimitVerdict(); }
class OverLimitVerdict extends LoadVerdict {
  final int load;
  const OverLimitVerdict(this.load);
}

LoadVerdict verdictOf(int load) => load <= comfortLoad
    ? const ComfortVerdict()
    : load <= editorialLimit
        ? const LimitVerdict()
        : OverLimitVerdict(load);
```

### Provider wiring (features/calendar/planner_providers.dart)

```dart
/// The Cycles model: gantt rows + week loads for the current window.
///
/// Derived, cached, and invalidated for free — `stackEntriesProvider`
/// re-emits on any regimen add/edit/pause/resume/delete, `todayProvider`
/// re-emits at local midnight. This is the memoization; there is no other
/// (PF-10). NOT autoDispose is fine (D-23) but autoDispose is also correct
/// here since the planner is screen-scoped — pick one and note it.
final cyclesModelProvider = Provider<AsyncValue<CyclesModel>>((ref) {
  final today = ref.watch(todayProvider);
  return ref.watch(stackEntriesProvider).whenData(
        (entries) => buildCyclesModel(entries, today: today),
      );
});
```

### Gantt row painter skeleton (the `_RingPainter` discipline)

```dart
class _GanttRowPainter extends CustomPainter {
  const _GanttRowPainter({required this.segments, required this.color});

  /// Fractional (0..1) left/right pairs plus their kind — the ONLY thing this
  /// painter draws from, which is why shouldRepaint compares nothing else.
  final List<GanttSegment> segments;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final track = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(6));
    canvas.drawRRect(track, Paint()..color = BqColors.chip);

    for (final s in segments) {
      final left = s.startFraction * size.width;
      // Minimum 2px so a one-day run never vanishes (PF-6).
      final width = math.max(2.0, (s.endFraction - s.startFraction) * size.width);
      final rrect = RRect.fromRectAndRadius(
        Rect.fromLTWH(left, 0, width, size.height),
        const Radius.circular(6),
      );
      if (s.planned) {
        canvas.save();
        canvas.clipRRect(rrect);
        canvas.drawRRect(rrect, Paint()..color = BqColors.plannedHatchWeak);
        // 4px on / 4px off diagonal hatch (mockup line 647).
        final hatch = Paint()
          ..color = BqColors.plannedHatchStrong
          ..strokeWidth = 4;
        for (var x = left - size.height; x < left + width + size.height; x += 8) {
          canvas.drawLine(Offset(x, size.height), Offset(x + size.height, 0), hatch);
        }
        canvas.restore();
        canvas.drawRRect(
          rrect.deflate(0.5),
          Paint()
            ..color = BqColors.plannedBorder
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1,
        );
      } else {
        canvas.drawRRect(rrect, Paint()..color = BqColors.accent);
      }
    }
  }

  @override
  bool shouldRepaint(_GanttRowPainter old) =>
      old.segments != segments || old.color != color;
}
```

### The WR-06 regression gate (test/providers_planner_test.dart)

```dart
test('opening the planner creates no IntakeLog rows', () async {
  // seed: supplement + cyclic regimen with slots, via the real repositories
  final before = await db.select(db.intakeLogs).get();

  final cycles = await _resolve(container, cyclesModelProvider);
  final year = await _resolve(container, yearModelProvider);
  expect(cycles.rows, isNotEmpty);
  expect(year.months, hasLength(12));

  final after = await db.select(db.intakeLogs).get();
  expect(after.length, before.length,
      reason: 'the planner is a projection — it must never materialize (PF-2/WR-06)');
});
```

### New ARB key inventory (both files; uk verbatim from the mockup where it exists)

| Key | uk | Source |
|---|---|---|
| `plannerTitle` | `Планувальник` | line 287 |
| `plannerSegYear` | `Рік` | line 290 |
| `plannerSegCycles` | `Цикли` | line 291 |
| `plannerRangeSubtitle` | `{start} — {end} {year}` (months via `LLLL`) | line 288 |
| `plannerYearSubtitle` | `{year} · 12 місяців` | line 402 |
| `plannerThisWeek` | `Цього тижня одночасно {count}` (count = pre-formatted `substancesCount`) | line 920 |
| `limitBadge` | `межа {max}` | line 297 |
| `legendTaking` | `приймаю` | line 326 |
| `legendPlanned` | `заплановано` | line 327 |
| `legendPaused` | `пауза` | line 329 |
| `loadChartTitle` | `ОДНОЧАСНЕ НАВАНТАЖЕННЯ` | line 335 |
| `loadChartMeta` | `по тижнях` | line 336 |
| `loadAxisLegend` | `межа {max} · комфорт {comfort}` | line 348 |
| `weekLoadLabel` | `{load} з {max} слотів` | line 913 |
| `weekFreeSlots` | `Вільно {n} — можна планувати старт` | line 921 |
| `weekNoFreeSlots` | `Вільних слотів немає` | line 921 |
| `verdictComfort` | `КОМФОРТНО` | line 778 |
| `verdictLimit` | `МЕЖА` | line 781 |
| `verdictOverLimit` | `ПОНАД МЕЖУ` | line 784 |
| `weekNoteComfort` | `До трьох речовин одночасно легко відстежувати: якщо щось піде не так, зрозуміло, що саме прибрати.` | line 779 |
| `weekNoteLimit` | `П'ять — наша межа за замовчуванням. Вище стає важко відрізнити, що дає ефект, а що — побічні відчуття.` | line 782 |
| `weekNoteOverLimit` | `Цього тижня перетинаються {cycles}. Варто зсунути старт частини з них або обговорити такий обсяг із лікарем.` (tail truncated per PF-5) | line 785 |
| `cyclesCount` | `{count, plural, one{{count} цикл} few{{count} цикли} many{{count} циклів} other{{count} цикли}}` | line 658 |
| `plannerDisclaimer` | `Межа в 5 речовин — наше редакційне правило для зручності відстеження, а не медичний норматив. Освітній матеріал, не медична порада.` | line 374 |
| `yearFootnote` | `Рік показує, як цикли накладаються один на одний. Червоне число в місяці означає перевищення нашої межі у {max} речовин одночасно.` | line 454 |
| `yearLegendHint` | `світліше = заплановано` | line 436 |
| `peakMonth` | `Найщільніший місяць — {month}` | line 967 |
| `peakMonthsTie` | `Найщільніші місяці, зокрема {month}` | line 967 |
| `monthMeta` | `{count} · межа {max}` (count = pre-formatted `substancesCount`) | line 972 |
| `monthStateTaking` | `приймаю` | line 850 |
| `monthStatePlanned` | `заплановано` | line 850 |
| `monthStatePartial` | `частина місяця` | line 850 |
| `emptyPlannerTitle` / `emptyPlannerBody` | invented (PF-12) | — |
| `ganttRowSemantics` / `weekBarSemantics` / `monthCardSemantics` | invented a11y labels | — |
| reused: `substancesCount`, `weeksCount`, `disclaimerEducational`, `retry` | — | existing ARB |

## Edge Coverage

| # | Edge | Expected behavior |
|---|------|-------------------|
| E-1 | Zero supplements | Both segments render the invented empty state; no empty gantt card, no 12 blank month cards; the disclaimer still shows (PLAN-04 is unconditional) [ASSUMED copy] |
| E-2 | Supplement with no regimen (`StackStatus.fresh`) | Excluded from the gantt and the year grid (nothing to draw); still visible on the Stack tab [ASSUMED — UAT] |
| E-3 | Paused regimen | Row present with a bare `chip`-coloured track (mockup's `пауза` legend swatch == track colour); counts 0 in every week and month; year rows filter it out via `frac > 0` |
| E-4 | Course with `endDate == null` | Contributes no runs anywhere (PF-11) — consistent with the Today screen, which also shows nothing |
| E-5 | Cyclic regimen with `offDays == 0` | `isActiveOn` returns true for every day from start → one continuous run to the window edge (mockup's "постійно, без циклів" rows [line 631]) |
| E-6 | Cyclic regimen with `onDays == 0` | `isActiveOn` returns false always → empty track, same treatment as paused |
| E-7 | Regimen starting after the window end | No segment in the gantt; still appears in the Year matrix if it starts inside the calendar year (hatched/planned bars) |
| E-8 | Window crossing a year boundary (today in Oct/Nov/Dec) | 4-month window spans into the next year; `addMonths` normalizes; month header labels come from each month's own date, so "СІЧ" of the next year renders correctly. The Year matrix stays on `today.year` — the two views intentionally show different spans |
| E-9 | Leap year (2028) | February month length = 29 via `daysInMonth`; coverage fractions and column widths correct (PF-3) |
| E-10 | DST transitions inside the window (Ukraine: last Sundays of March/October) | Invisible: every value is UTC date-only, `inDays` exact, no local midnight anywhere (`cycle_math.dart` guarantee) |
| E-11 | Load exceeds 5 in some week | Bar splits into a 38px main + red over-bar; verdict `ПОНАД МЕЖУ`; pips extend past 5 in risk colour; note is the truncated over-limit sentence |
| E-12 | Load exceeds 5 in a month | Month-card count renders red (`> 5`, strictly); peak chip uses the warn palette; footnote explains the red number |
| E-13 | Two months tie for peak | `Найщільніші місяці, зокрема {month}` with the tie broken toward the month nearest today (mockup lines 822-827) |
| E-14 | Midnight rollover while the planner is open | `todayProvider` flips → both models recompute → the today marker moves, a run that starts today flips from planned to active, the default week/month selection follows unless the user picked one explicitly |
| E-15 | Regimen edited/paused on the Stack tab while the planner is mounted | `stackEntriesProvider` re-emits → models recompute; no manual refresh (the `IndexedStack` keeps the tab mounted [VERIFIED: lib/app_shell.dart:38-45]) |
| E-16 | 20+ supplements | Year cards grow (computed `mainAxisExtent`); the gantt scrolls; the load chart is unaffected (bars are counts). Above ~12 the 4-column cards get tall — acceptable, flagged in Open Questions |
| E-17 | textScaler 1.6 / 2.0 / 3.0 | No overflow anywhere: gantt name/hint `Flexible`+ellipsis, month grid extent scaled, legend `Wrap`s (PF-7) |
| E-18 | One-day run | Painted at the 2px minimum, still tappable/announced via the row semantics (PF-6) |

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | `flutter_test` (SDK) + in-memory Drift + `ProviderScope` overrides — the harness proven in Phases 1–3 |
| Config file | `analysis_options.yaml` (exists) |
| Quick run command | `flutter test test/features/<file>_test.dart` |
| Full suite command | `flutter analyze && flutter test` (290 tests green at Phase-3 close [VERIFIED: .planning/phases/03-daily-tracking/03-REVIEW.md:100-101]) |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| PLAN-01 | `activeRuns` coalescing: continuous, cyclic on/off, paused, pre-start, course, null-end, window clipping | unit (pure) | `flutter test test/features/planner_view_model_test.dart` | ❌ Wave 0 |
| PLAN-01 | Window math: 4-month span for every start month, leap Feb, year crossing, month column widths sum to 1.0 | unit (pure) | `flutter test test/domain/planner_window_test.dart` | ❌ Wave 0 |
| PLAN-01 | Planned-vs-active segment kind (run starting after today ⇒ planned) and its agreement with `statusOf` | unit (pure) | `planner_view_model_test.dart` | ❌ Wave 0 |
| PLAN-01 | Gantt renders one row per supplement, today marker present, hatched segment present | widget | `flutter test test/features/planner_screen_test.dart` | ❌ Wave 0 |
| PLAN-02 | Week bucketing (Monday alignment, clamped last bucket) and load = any-day overlap | unit (pure) | `planner_view_model_test.dart` | ❌ Wave 0 |
| PLAN-02 | Verdict bands at loads 0/3/4/5/6 and the pip array shape | unit (pure) | `planner_view_model_test.dart` | ❌ Wave 0 |
| PLAN-02 | Tap a week bar → detail card shows that week's range, load, verdict and names; semantics node is tappable | widget | `planner_screen_test.dart` | ❌ Wave 0 |
| PLAN-03 | Month cell frac/full/planned + month load counts + peak-month tie-breaking | unit (pure) | `planner_view_model_test.dart` | ❌ Wave 0 |
| PLAN-03 | Tap a month card → detail rows filtered to `frac > 0` with correct state text | widget | `planner_screen_test.dart` | ❌ Wave 0 |
| PLAN-04 | The educational disclaimer is present with Цикли selected AND with Рік selected | widget | `planner_screen_test.dart` | ❌ Wave 0 |
| PLAN-04 | No excluded copy ships (interaction legend, fat-soluble clause, action buttons) | grep gate in review + ARB assertion | `planner_screen_test.dart` | ❌ Wave 0 |
| (PF-2) | Building both planner models creates zero `IntakeLog` rows | provider unit (in-memory DB row count) | `flutter test test/providers_planner_test.dart` | ❌ Wave 0 |
| (PF-7) | No overflow at textScaler 1.0 / 1.6 / 2.0 on both segments | widget | `planner_screen_test.dart` | ❌ Wave 0 |
| (PF-4) | uk standalone month names render nominative (`серпень`, not `серпня`) | unit | extend `test/l10n/plurals_test.dart` or a new `test/l10n/month_names_test.dart` | ❌ Wave 0 |
| (L10N) | `cyclesCount` / `substancesCount` correct at 1 / 2 / 5 / 11 / 21 uk | unit | extend `test/l10n/plurals_test.dart` | exists — extend |

### Sampling Rate
- **Per task commit:** the single relevant test file (`flutter test test/features/planner_view_model_test.dart` for pure work, `planner_screen_test.dart` for UI work) — each under 30s.
- **Per wave merge:** `flutter analyze && flutter test`.
- **Phase gate:** full suite green (290 baseline + new) before `/gsd-verify-work`.

### Wave 0 Gaps
- [ ] `test/features/planner_view_model_test.dart` — pure derivations (build FIRST; every pixel renders through them)
- [ ] `test/domain/planner_window_test.dart` — window/month/leap arithmetic (`core/domain` gets the build-breaking-warnings bar per CLAUDE.md)
- [ ] `test/providers_planner_test.dart` — the no-materialization regression gate (harness: `test/providers_calendar_test.dart`)
- [ ] `test/features/planner_screen_test.dart` — rendering, selection, disclaimer, text scaling
- [ ] `test/l10n/month_names_test.dart` (or an extension of `plurals_test.dart`) — `LLLL`/`LLL` uk output + new plural keys
- No new fixture framework: reuse the in-memory-DB + `ProviderScope` override harness and the Phase-2/3 seeding helpers

## Security Domain

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | No | Offline single-user app, unchanged |
| V3 Session Management | No | No sessions |
| V4 Access Control | No | No multi-user surface |
| V5 Input Validation | Marginal | This phase accepts **no free-text input at all** — the only inputs are a segment index, a week index and a month index, all bounded by the model's own list lengths. Assert the bounds when seeding selection from `today` |
| V6 Cryptography | No | Unencrypted SQLite remains the accepted v1 trade-off |

**Threat notes (STRIDE):** the only categories with any surface are *Tampering* and *Information Disclosure*, both nil here — the phase is strictly read-only (V-1.1), performs no network I/O, spawns no process, and renders only data the user entered. The one integrity property worth enforcing mechanically is the read-only claim itself: no `setStatus` / `upsert` / `softDelete` / `ensureLogsForDay` reachable from `features/calendar/planner_*.dart` (grep gate at review). The liability surface in this phase is **editorial, not technical** — PF-5's exclusion list and PLAN-04's framing rule are the controls that matter, and they are validated by the disclaimer test and the copy grep gate rather than by any security tooling.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Flutter SDK 3.47 / Dart 3.13 | everything | ✓ | `sdk: ^3.13.0` [VERIFIED: pubspec.yaml:22] | — |
| `intl` (unpinned, SDK-resolved) | month names, plural formatting | ✓ | resolved by `flutter_localizations` | — |
| Existing test harness (in-memory Drift + ProviderScope) | all new tests | ✓ | Phases 1–3 | — |
| `node` / gsd-tools seams | automated research seams | ✗ (sandbox constraint) | — | Manual verification performed, as in Phases 1–3 |
| iOS simulator / Android emulator | visual UAT of the planner | ✓ per Phase-3 DATA-03 run | — | Physical devices |

No blocking gaps and no new external dependency. Nothing in this phase requires a device to be *tested* (all logic is unit/widget-testable); a device is only needed for visual UAT.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | The planner is reached from the Calendar tab via an invented header affordance, rendered as a swapped page inside the tab (nav bar stays visible) | P-3 | IA-level; the planner screen itself is navigation-agnostic, so switching to a nested `Navigator` or a push is contained. Confirm at UAT |
| A2 | uk standalone month names need `LLLL`/`LLL` (nominative) while `MMMM` yields genitive | P-12 / PF-4 | Wrong case in three labels; caught by the month-name unit test, one-character fix |
| A3 | Week buckets are Monday-aligned rather than window-aligned (deviates from the mockup's `i*7` arithmetic) | P-6 | Bucket edges shift by ≤6 days; visual shape identical; one-line change in the bucket builder |
| A4 | `mondayOfWeek` is promoted from `week_strip.dart` to `cycle_math.dart` | P-6 | Trivial refactor; the alternative (duplicating it) violates the single-source rule |
| A5 | Supplements with no regimen are excluded from both planner views | PF-9 / E-2 | Cosmetic; a one-line filter change either way |
| A6 | A run whose start is after today is wholly "planned" (mockup rule), rather than splitting a running cycle at today | P-5 | Informational richness only; one-line change in `ganttSegments`; keeps `statusOf` alignment as-is |
| A7 | The dashed threshold line stays at the mockup's comfort-3 position rather than at the 5 limit | P-9 / Open Q2 | Cosmetic; the `межа 5` badge, pips and red overflow already carry the limit |
| A8 | The over-limit note ships truncated (fat-soluble clause removed) | P-7 / PF-5 | If the truncation reads oddly in uk, rewrite the final sentence — must not restore the clause |
| A9 | Year matrix always shows `today.year` Jan–Dec (no year paging) | P-10 | PLAN-03 says "12 month cards", not "any year"; adding paging later is additive |
| A10 | Empty-state copy for the planner is invented in the Stack tab's tone | PF-12 / E-1 | Cosmetic; UAT |
| A11 | Per-column `HitTestBehavior.opaque` over the full 46px chart height is an adequate touch target for 18 weeks | PF-8 | If it tests badly, widen the chart's vertical padding or reduce the bucket count; the model is unaffected |
| A12 | ~10k `isActiveOn` calls per recompute is imperceptible (sub-millisecond AOT, low single-digit ms in debug) | Summary | If profiling disagrees, cache runs per regimen across both views — a pure-function memo, no architecture change |

## Open Questions (RESOLVED — all four settled in the approved 04-UI-SPEC.md)

> Q1 → RESOLVED: DECIDED-1 (in-tab page swap from a Today-header text action). Q2 → RESOLVED: DECIDED-2 (single comfort-3 dashed line; the 5-limit is expressed structurally by the bar cap plus textually by the badge/legend). Q3 → RESOLVED: DECIDED-5 (no cap on year-grid card height). Q4 → RESOLVED: DECIDED-6 (>=/> asymmetry transcribed verbatim, rationale recorded so it is not 'fixed' later).

1. **How does the user reach the planner?** (P-3, A1)
   - What we know: the mockup renders both planner screens with **Календар** selected in the nav bar and titles them Планувальник; screen 02 has no segmented control and no visible link.
   - What's unclear: the entry affordance is simply absent from the mockup.
   - Recommendation: a header action on the Calendar screen (label or icon) swapping to an in-tab planner page, with a back control in the planner header. Decide at discuss/UAT; the planner screen is agnostic either way.
2. **Where does the dashed reference line go?** (P-9, A7)
   - What we know: the mockup's line is at `bottom:22.8px` = 0.6 × 38px = load 3, and the axis caption reads `межа 5 · комфорт 3`.
   - What's unclear: PLAN-02 phrases the chart as "against the editorial 5-substance line", which the red overflow and the badge already express.
   - Recommendation: ship the mockup's single comfort-3 line; optionally add a second, fainter line at the 5 boundary if UAT finds the limit hard to read. Never label either as a safety line.
3. **How many supplements before the 4-column year grid stops working?** (E-16)
   - What we know: each card holds one 4px bar per supplement with 3px gaps; at N = 20 a card is ~160px tall and the grid ~500px.
   - What's unclear: whether a cap + "+N" affordance is wanted, or whether tall cards are acceptable.
   - Recommendation: no cap in v1 (honest and simple); revisit if UAT with a large stack looks bad.
4. **Does the `>=` / `>` asymmetry between the week summary chip and the year peak chip stay?** (P-10)
   - What we know: the mockup warns at `load >= 5` for the week and at `load > 5` for the month — verbatim, in two places.
   - Recommendation: transcribe both as-is and document the asymmetry in the UI-SPEC so it is not "fixed" later; raise it at UAT as a deliberate question.

## Sources

### Primary (HIGH confidence)
- Project code read line-by-line this session: `lib/core/domain/{models,cycle_math,repositories}.dart`, `lib/core/providers.dart`, `lib/core/today_controller.dart`, `lib/core/theme/{tokens,theme}.dart`, `lib/core/widgets/bq_segmented.dart`, `lib/app_shell.dart`, `lib/features/calendar/{calendar_providers,calendar_screen,day_view_model,day_progress_ring,week_strip}.dart`, `lib/features/stack/stack_status.dart`, `lib/core/l10n/arb/app_{uk,en}.arb`, `pubspec.yaml` — every `[VERIFIED: path:lines]` tag refers to these reads, with the cited values quoted verbatim
- `claude_design_mockup/Boostque v0.1.dc.html` — screen 03 · ЦИКЛИ (lines 276-388), screen 04 · РІК (lines 390-468), screen 02 · КАЛЕНДАР (lines 193-274) and the full planner script (lines 623-668, 763-852, 891-972) read this session; all mockup citations are verbatim quotes with line numbers
- `.planning/phases/03-daily-tracking/03-REVIEW.md` — WR-06 (materialization-by-pager), CR-01/WR-04 (text-scale overflows), WR-02 (semantics action), IN-08 (zero text-scale coverage), and the 290-test baseline
- `.planning/REQUIREMENTS.md` (PLAN-01..04, Out of Scope table, locked decisions), `.planning/ROADMAP.md` (Phase 4 goal + 4 success criteria, Phase-1 three-tab criterion), `.claude/CLAUDE.md` (locked stack, "What NOT to Use", alternatives table)
- `docs/superpowers/specs/2026-08-14-boostque-v1-design.md` — "all calendar views are computed projections, never stored" (line 67) and the `calendar/  # Day / Cycles / Year views` structure (line 54)

### Secondary (MEDIUM confidence)
- `.planning/phases/03-daily-tracking/03-RESEARCH.md` and `03-PATTERNS.md` — house conventions this document mirrors (pure view-model style, test harnesses, ARB composition with pre-formatted plural strings)

### Tertiary (LOW confidence)
- CLDR standalone-vs-format month forms in Ukrainian (`LLLL` → `серпень`, `MMMM` → `серпня`) — training knowledge, deliberately pinned by a unit test rather than a doc fetch (A2); no web access was available in this session (`node`/gsd-tools unavailable, per Environment Availability)
- Perf estimate for ~10k `isActiveOn` calls (A12) — reasoned from operation counts, not measured

## Metadata

**Confidence breakdown:**
- Computation strategy (runs from `isActiveOn`, no materialization, provider-cached derivation): HIGH — every input provider and domain function was read this session and quoted; the anti-pattern is documented from a real in-repo review finding
- Mockup extraction (window constants, segment kinds, week/month derivations, verdict bands, all copy): HIGH — verbatim quotes with line numbers; the `SPAN`/`WIN_A`/`TODAY` constants were cross-checked against the Today screen's rendered date
- Token additions and rendering approach: HIGH for values (transcribed), MEDIUM for widget structure (a design choice constrained by CLAUDE.md, with in-repo precedents cited)
- Navigation/IA: MEDIUM — the mockup proves the planner sits under the Calendar tab but shows no entry affordance; the seam is invented (A1)
- Invented UX (empty states, touch-target mitigation, fresh-entry exclusion): LOW by nature — all flagged ASSUMED with one-line reversal paths
- i18n specifics (uk standalone month case): MEDIUM, test-pinned

**Research date:** 2026-08-16
**Valid until:** ~30 days (no external dependencies in this phase; the mockup and the SDK are stable, so this document ages only if Phase 3's code changes underneath it)
