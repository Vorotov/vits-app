# Phase 3: Daily Tracking - Research

**Researched:** 2026-08-15
**Domain:** Flutter feature UI + state — Today/Calendar screen (time-blocked dose list, day-progress ring, week day-strip, one-tap mark taken/skipped + undo, view-computed "missed"), materialization wiring for `ensureLogsForDay`, midnight-safe "today", both-platform full-loop run (DATA-03) — over the Phase-1/2 domain/DB/provider foundation
**Confidence:** HIGH (all relevant Phase-1/2 code and the mockup Calendar screen read line-by-line this session; the one no-precedent SDK API — `AppLifecycleListener` — fetched from api.flutter.dev this session; block boundaries, skip affordance, and past-day missed styling are mockup gaps flagged ASSUMED)

<user_constraints>
## User Constraints (no CONTEXT.md exists — sources: approved design spec `docs/superpowers/specs/2026-08-14-boostque-v1-design.md`, `.claude/CLAUDE.md`, REQUIREMENTS.md locked decisions, Phase-1/2 decisions)

### Locked Decisions
- Flutter + Dart single codebase; Riverpod + Drift; UI depends on repository interfaces only (`SupplementRepository`/`RegimenRepository`/`IntakeRepository`) — Drift types never appear in `features/`
- **Missed semantics (REQUIREMENTS "Decisions Locked During Definition"):** an unmarked dose is displayed as "missed" when its date is strictly before today (**device-local calendar day**); the IntakeLog row itself stays `pending` — no schema change, no status write. Presented neutrally, never guilt-framed (TRACK-03)
- Dose occurrences are **materialized** IntakeLog rows: "Rows are generated ahead for the near horizon and **lazily for browsed dates**" (design spec Data model) — so a future widget/notification scheduler can read "today's doses" without app logic
- Date-only values normalized as `DateTime.utc(y,m,d)`; **domain never reads the clock** (D-13/D-15); every date comparison via `dateOnly()`
- Soft delete only, UUID PKs, createdAt/updatedAt on every row (DATA-02); every repo mutation bumps `updatedAt`
- Riverpod dispose policy (D-23): app-lifetime repo/stream providers NOT autoDispose; screen-scoped state MAY be autoDispose — recorded in `core/providers.dart`, do not re-litigate
- Token-only styling (D-07): all UI via `BqColors`/`BqRadii`/`BqSpace`/`BqText`/`bqTheme()` — no ad-hoc hex literals in feature code
- Zero hardcoded user-visible strings (gen-l10n en/uk ARBs, all four uk CLDR plural forms); `EdgeInsetsDirectional` only; no fixed-width text containers
- No new packages without strong justification (D-04); bespoke layouts as plain widgets/`CustomPaint`, no generic calendar packages (CLAUDE.md "What NOT to Use": no `table_calendar`-style packages)
- Mockup `claude_design_mockup/Boostque v0.1.dc.html` is the authoritative visual reference (screen 02 · КАЛЕНДАР for this phase)
- Pause = query-level filter in `watchDay` (`paused AND pending` excluded), never a log-row mutation (Phase-2 PF-1) — already implemented and tested
- DATA-03 mapped to this phase: full plan→see→mark loop builds and runs on iOS simulator/device AND Android emulator/device (targetSdk 36)

### Claude's Discretion
- Exact time-block hour boundaries (mockup gives block anchor times, not ranges — recommendation below, confirm at UAT)
- Skip affordance + undo interaction shape (mockup models only a taken-toggle; TRACK-02 adds "skipped")
- Past-day "missed" visual treatment (mockup has no past-day view; must be neutral per TRACK-03)
- Week-strip navigation depth (mockup shows current week only, no pager affordance)
- Empty-day state design (mockup shows none)
- File organization inside `features/calendar/`, widget decomposition

### Deferred Ideas (OUT OF SCOPE)
- Notifications (NOTF-01) and home-screen widgets (WIDG-01) — v2; materialized rows are the enabler, nothing more to build now
- History/adherence/streaks (HIST-01) — v1 never aggregates missed counts, no streaks anywhere (guilt-framing is a documented uninstall driver)
- The mockup's zinc/magnesium spacing-advice card (mockup lines 260-263 — an interaction claim; naive interaction checking is never-ship per REQUIREMENTS Out of Scope)
- Interaction warn chips on dose rows ("взаємодія з КОК", "2 год після сертраліну" — mockup lines 609, 614) — same liability exclusion
- Cycles/Year planner views (Phase 4), language override (Phase 5)
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| TRACK-01 | Today's doses grouped by time blocks (morning/day/evening/night) with a day-progress ring | P-4 (block grouping, pure fn + boundary recommendation), P-8 (ring CustomPaint spec, mockup-exact), mockup block/row anatomy quoted verbatim |
| TRACK-02 | Mark a dose taken or skipped with one tap; undo the mark | P-7 (tap-toggle per mockup `tog`, skip affordance recommendation, `setStatus` round-trip verified), PF-4 (double-tap race lesson from CR-01) |
| TRACK-03 | Browse past/current-week days; unmarked past doses render as "missed" — view-computed, DB stays pending, neutral | P-2 (lazy materialization of browsed days), P-6 (missed derivation + styling), P-9 (week strip), E-2/E-3 raw-row assertions |
| TRACK-04 | Doses appear only on cycle-active days; correct across DST + year boundaries | P-2 (`ensureLogsForDay` → `isActiveOn` single decision point, verified), P-1/PF-2 (local-midnight rollover math), DST/year-boundary test skeletons |
| DATA-03 | Full loop builds and runs on iOS + Android (targetSdk 36) | Environment Availability (targetSdk 36 verified in build.gradle.kts), both-platform checkpoint recommendation |
</phase_requirements>

## Project Constraints (from CLAUDE.md)

- GSD workflow for all file changes; package set locked (no new packages expected this phase — confirmed below: zero needed)
- `flutter analyze` clean and `flutter test` green are exit criteria for every plan
- Bespoke layouts (ring, day strip, block list) as plain Flutter widgets/`CustomPaint` — no charting or calendar packages
- Bundle id placeholder `com.boostque.dev`; DATA-03 is a dev-build verification, not a store-release step

## Summary

Phase 3 needs **zero new packages and zero schema changes**. Every persistence surface already exists and is tested: `ensureLogsForDay` (idempotent insert-or-ignore on unique `(slotId, date)`), `watchDay` (joined stream with pause/deletedAt filters), and `setStatus` (accepts any `DoseStatus`, including `pending` — which makes undo a plain status write). The critical integration fact: **`ensureLogsForDay` currently has no production caller** — it is exercised only by tests [VERIFIED: grep this session — callers are `test/db/*` only]. Wiring it is the heart of this phase.

The recommended wiring is a single choke point: a `dayDosesProvider` family (autoDispose, keyed by UTC date-only `DateTime`) whose build **watches the regimens stream (so any regimen add/edit/pause/resume re-materializes), awaits `ensureLogsForDay(day)`, then yields `watchDay(day)`**. Because materialization is idempotent and never touches existing statuses, calling it on every rebuild is free. This one provider answers every "who materializes?" question: today, browsed past days, browsed future days within the week, and post-resume re-materialization all flow through it — exactly the design spec's "generated ahead for the near horizon and lazily for browsed dates." The second new piece of state is a midnight-safe `todayProvider` (Notifier + one-shot Timer to the next **local** midnight + `AppLifecycleListener.onResume` re-check), which closes Phase-2 review finding IN-06 (stack card statuses stale across midnight) for both tabs at once.

The mockup pins down the Today screen almost completely: block anchors 08:00/13:00/19:00/22:00 with labels Ранок/День/Вечір/Ніч and meal tags, exact row anatomy (24px circular check, strike-through on taken, chip stack), the conic-gradient ring (`#3F7A6A` on `#E4E3DD` = `BqColors.calm` on `BqColors.field`), the Mon–Sun week strip with today highlighted in accent, and block-header state logic (accent "current" block, `X з Y` warn tag on past blocks, `усе прийнято` calm tag on complete ones). What it does **not** give: hour-range boundaries for slot→block mapping (the demo hardcodes each dose's block), any skip affordance, any past-day view, and the current-block rule (hardcoded `nowBlock = 2`). Those four gaps get explicit recommendations below, each flagged ASSUMED for UAT confirmation.

**Primary recommendation:** Build in three slices — (1) state layer: `todayProvider` + `dayDosesProvider` + block-grouping pure helpers, fully unit-tested including DST/year-boundary materialization (TRACK-04); (2) Today view: blocks, rows, tap-to-mark with undo, ring, header; (3) week strip + day browsing + missed rendering + the both-platform run checkpoint (DATA-03).

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| "Today" value + midnight rollover | State (`core/providers.dart`, new `TodayController`) | Widget (consume only) | The clock may be read at the state/widget boundary (Phase-1 precedent: repos read `DateTime.now().toUtc()`, `stack_screen.dart:43` reads `dateOnly(DateTime.now())`); domain stays clockless |
| Materialization trigger | State (`dayDosesProvider` build) | Data (`ensureLogsForDay`, exists) | Provider is the choke point; repo stays a dumb idempotent primitive; `isActiveOn` remains the ONLY activity decision point |
| Day dose stream | Data (`watchDay`, exists with pause/deletedAt filters) | State (family provider) | Already built + tested in Phase 2 (plan 02-01) |
| Block grouping, `доза n з m`, missed/overdue derivation | Pure view-model helpers (`features/calendar/day_view_model.dart`) | Widget | Pure functions of `List<DayDose>` + explicit `today`/`now` params — unit-testable without widgets, clockless |
| Mark taken/skipped/undo | Widget → `IntakeRepository.setStatus` via `ref.read` | Data | One-line status writes; guard double-activation (CR-01 lesson) |
| Progress ring | Widget (`CustomPaint`) | — | Bespoke conic arc; no package (locked) |
| Week strip | Widget | State (selected-day provider) | Plain `Row` of 7 cells driven by `todayProvider` + per-day dose summaries |
| Locale date formatting (header, strip) | `intl` `DateFormat` + gen-l10n | — | Already wired; never hand-built strings |
| Both-platform run (DATA-03) | Build/config (`android/app/build.gradle.kts` targetSdk 36 — already set) | Human-verify checkpoint | Config verified; runtime proof needs a human on simulator+emulator |

## Standard Stack (delta)

### New packages required: NONE

| Need | Use (already available) | Notes |
|------|------------------------|-------|
| Midnight rollover + resume detection | SDK `Timer` (`dart:async`) + `AppLifecycleListener` | `AppLifecycleListener({WidgetsBinding? binding, VoidCallback? onResume, ..., ValueChanged<AppLifecycleState>? onStateChange})`; create directly outside widgets, uses the default binding automatically, `dispose()` when done [CITED: api.flutter.dev/flutter/widgets/AppLifecycleListener-class.html — fetched this session] |
| Day-dose reactive stream | `IntakeRepository.watchDay` [VERIFIED: lib/core/db/drift_repositories.dart:309-362 — joins logs×slots×regimens×supplements, filters `intakeLogs.deletedAt.isNull() & regimens.deletedAt.isNull() & supplements.deletedAt.isNull() & (paused == false OR status != pending)`, orders by `minutesFromMidnight asc, log id asc`] | Nothing to change |
| Materialization | `IntakeRepository.ensureLogsForDay` [VERIFIED: drift_repositories.dart:274-298 — `InsertMode.insertOrIgnore`, one batch, `isActiveOn` the only gate; repositories.dart:94-97 contract "Re-running never duplicates rows and never resets an existing row's status"] | **No production caller exists — this phase adds the wiring** |
| Mark/undo | `IntakeRepository.setStatus(String logId, DoseStatus status)` [VERIFIED: drift_repositories.dart:301-306 — plain status write + `updatedAt` bump; `DoseStatus { pending, taken, skipped }` VERIFIED: models.dart:20] | Undo = `setStatus(logId, DoseStatus.pending)`; no new API |
| Ring | `CustomPaint` + `Canvas.drawArc` (SDK) | ~25 lines; exact conic fidelity, no M3 fights (mockup ring is a hard-edged conic-gradient, `CircularProgressIndicator` adds caps/animation defaults) |
| Mono numerals (ring text, block times, day numbers) | `BqText.mono(...)` [VERIFIED: lib/core/theme/theme.dart:128-146 — JetBrains Mono + `FontFeature.tabularFigures()`, doc comment says "consumed from Phase 3 on"] | Built for this phase already |
| Locale header date | `DateFormat('EEEE, d MMMM', locale)` (`intl`, installed) | uk renders "четвер, 13 серпня" (genitive month in format context) [ASSUMED — standard intl uk CLDR data; assert in a unit test at 1 exemplar date] |
| Selected-day / minute-tick state | Riverpod `Notifier` / `StreamProvider.autoDispose.family` (installed, Riverpod 3 manual syntax — no codegen, per project convention) | Family + constructor-arg pattern proven in Phase 2 (`regimenEditorProvider`) |

### Theme delta: NONE required

`bqTheme()` already carries everything this screen needs (text theme, nav bar, chips are hand-styled containers per Phase-2 convention). No new sub-themes — all Today-screen surfaces are plain decorated containers off tokens. All ring/strip/row colors map to existing tokens: `calm`(#3F7A6A), `field`(#E4E3DD), `accent`(#4A4E7C), `warn`/`warnBg`, `chip`, `cardBorder`, `surface`, `surfaceAlt`, `paper`, `ink`, `textSecondary`, `textMuted`, `textFaint` [VERIFIED: lib/core/theme/tokens.dart:13-106 — every hex the mockup Calendar screen uses is already a token].

## Package Legitimacy Audit

No packages added this phase. Dependency set unchanged from Phase 1's audit. **Packages removed due to [SLOP] verdict:** none. **Packages flagged as suspicious [SUS]:** none. (`node`/`gsd-tools` unavailable in this sandbox — no automated seam run; irrelevant since the install delta is empty.)

## Architecture Patterns

### System flow (this phase)

```
                       ┌──────────────────────────────────────────────┐
                       │ todayProvider (P-1, core/providers.dart)     │
                       │  Notifier<DateTime> — UTC date-only          │
                       │  Timer→next LOCAL midnight + onResume check  │
                       └───────┬──────────────────────────┬───────────┘
                               │                          │ (also consumed by
                               ▼                          ▼  StackScreen → closes IN-06)
        ┌──────────────────────────────┐        ┌────────────────────┐
        │ selectedDayProvider (P-3)    │        │ stack cards statusOf│
        │  null ⇒ "follow today"       │        └────────────────────┘
        └───────────┬──────────────────┘
                    │ resolved day (UTC date-only)
                    ▼
        ┌───────────────────────────────────────────────┐
        │ dayDosesProvider(day)  (P-2, family autoDispose)│
        │  1. ref.watch(regimensStreamProvider)  ← invalidates on any
        │  2. await intakeRepo.ensureLogsForDay(day)  regimen change
        │  3. yield* intakeRepo.watchDay(day)           │
        └───────────┬───────────────────────────────────┘
                    │ List<DayDose> (slot-time ordered)
                    ▼
        ┌───────────────────────────────────────────────┐
        │ pure view-model helpers (P-4/P-5/P-6)          │
        │  groupIntoBlocks / doseIndexOfDay / isMissed / │
        │  overdue + current-block (given now-minutes)   │
        └───────────┬───────────────────────────────────┘
                    ▼
   CalendarScreen: header+ring (P-8) · week strip (P-9) · block list
   row tap ──► intakeRepo.setStatus(logId, taken|pending)   (P-7)
   row long-press ──► setStatus(skipped|pending)            (P-7)
```

### P-1: Midnight-safe `todayProvider` (closes IN-06)

**What:** A `Notifier<DateTime>` in `core/providers.dart` holding `dateOnly(DateTime.now())`, self-updating at local midnight and on app resume. NOT autoDispose (app-lifetime, shared by Calendar and Stack per D-23).

```dart
/// The current device-local calendar day as a UTC date-only value.
/// The ONE place the "what day is it" clock is read (widgets consume this).
class TodayController extends Notifier<DateTime> {
  Timer? _timer;
  AppLifecycleListener? _lifecycle;

  @override
  DateTime build() {
    ref.onDispose(() { _timer?.cancel(); _lifecycle?.dispose(); });
    _lifecycle = AppLifecycleListener(onResume: _refresh);   // timers suspend in bg
    _schedule();
    return dateOnly(DateTime.now());
  }

  void _refresh() {
    final day = dateOnly(DateTime.now());
    if (day != state) state = day;      // DateTime == is exact for utc/utc (P-2 note)
    _schedule();                        // reschedule — resume may have jumped days
  }

  void _schedule() {
    _timer?.cancel();
    final now = DateTime.now();
    // LOCAL constructor handles month/year rollover AND DST (a 23h/25h day
    // yields the correct wall-clock midnight) — never add Duration(hours: 24).
    final nextMidnight = DateTime(now.year, now.month, now.day + 1);
    _timer = Timer(nextMidnight.difference(now) + const Duration(seconds: 1), _refresh);
  }
}
final todayProvider = NotifierProvider<TodayController, DateTime>(TodayController.new);
```

**Why here:** clock-read policy precedent is "repositories and the widget layer may read the clock; domain never does" [VERIFIED: drift_repositories.dart:11 — "Domain code never reads the clock"; stack_screen.dart:16-18 — "The clock is read HERE (widget layer)"]. A state-layer controller is the same boundary, centralized. StackScreen swaps its per-build `dateOnly(DateTime.now())` (line 43) for `ref.watch(todayProvider)` — closing IN-06 exactly as the review prescribed ("when Phase 3 introduces a 'today' ticker/provider for the calendar, consume it here too" [VERIFIED: 02-REVIEW.md IN-06]).

**Testability:** the midnight math is untestable through `DateTime.now()` directly — extract `DateTime nextLocalMidnight(DateTime now)` as a pure top-level function and unit-test it (incl. a DST-transition day and Dec 31); the controller itself gets a smoke test only.

### P-2: `dayDosesProvider` — materialize-then-watch, one choke point

**What:** the single answer to "where/when does `ensureLogsForDay` run":

```dart
/// Doses for one calendar day. `day` MUST be a dateOnly() UTC value —
/// it is the family cache key (see PF-1).
final dayDosesProvider = StreamProvider.autoDispose
    .family<List<DayDose>, DateTime>((ref, day) async* {
  // Re-materialize whenever any regimen changes (add/edit/pause/resume/delete):
  // watching the stream makes Riverpod rebuild this provider on every emission.
  ref.watch(regimensStreamProvider);
  final intake = ref.watch(intakeRepoProvider);
  await intake.ensureLogsForDay(day);   // idempotent: insertOrIgnore, never resets status
  yield* intake.watchDay(day);
});
```

**Why this shape answers every materialization question:**
- **Today:** watched whenever the Calendar tab shows today → rows exist before first paint.
- **Browsed past/future days:** the family instance for that day runs the same build → design spec's "lazily for browsed dates" verbatim. Past-day rows materialize as `pending` → render as missed (P-6) with zero writes beyond the insert itself.
- **Regimen added/edited/resumed while calendar open:** `regimensStreamProvider` emits → provider rebuilds → re-materializes → `watchDay` re-emits. The pause round-trip needs zero writes (pause filter is query-level [VERIFIED: drift_repositories.dart:325-336]), and resume-day re-materialization is proven lossless [VERIFIED: test/db/pause_filter_test.dart:106-110 — "ensureLogsForDay after resume: no duplicates, no lost rows"].
- **Midnight rollover:** the screen watches `dayDosesProvider(resolvedSelectedDay)`; when `todayProvider` flips, the resolved day changes, a fresh family instance materializes the new day. Nothing special to write.
- **App resume after days closed:** same path — `todayProvider.onResume` recomputes, family key changes.

`autoDispose` is correct for the family (browsed-day instances die when navigated away — D-23 permits autoDispose for screen-scoped state); today's instance stays alive while the tab is visible. Do NOT make it non-autoDispose: every browsed day would leak a Drift stream subscription forever.

**Cheapness check:** re-running `ensureLogsForDay` per regimen emission is one in-memory `watchAll().first` + one batched `insertOrIgnore` [VERIFIED: drift_repositories.dart:274-298]; with ≤ tens of regimens this is sub-millisecond SQLite work. No debouncing needed.

### P-3: Selected-day state — "null means follow today"

**What:** `Notifier<DateTime?>` (autoDispose OK, calendar-scoped). `null` = "today" (the default); an explicit UTC date-only value = user browsed. The resolved day is `selected ?? ref.watch(todayProvider)`.

**Why nullable:** if the selection stored a concrete date, sitting on "today" across midnight would silently strand the user on yesterday. With null-as-today the rollover auto-follows, and an explicit past-day selection intentionally stays put (the user chose it). Recommend: tapping the today cell (or the "Сьогодні" title) resets to null. When the week rolls over while an explicit selection is off the new strip, keep the selection but render the strip for the selection's week (see P-9 navigation note).

### P-4: Time-block grouping — boundaries + pure helpers

**Mockup ground truth** [VERIFIED: mockup lines 616-621, quoted verbatim]:

```js
const BLOCK_META = [
  { time: '08:00', label: 'Ранок', tag: 'зі сніданком' },
  { time: '13:00', label: 'День', tag: 'з обідом' },
  { time: '19:00', label: 'Вечір', tag: 'з вечерею' },
  { time: '22:00', label: 'Ніч', tag: 'перед сном' }
];
```

These are **anchor/display times, not ranges** — every mockup dose carries an explicit `block:` index [VERIFIED: mockup lines 606-615]. The app must map `slot.minutesFromMidnight` → block. **Recommended boundaries** (must place the editor's default/next-slot times `['08:00','13:00','19:00','22:00','10:30','16:00']` and fallback `21:00` sensibly [VERIFIED: mockup line 650; regimen_editor_controller nextSlotDefaults]):

| Block | Range (minutes) | Range (wall clock) | Check against known times |
|-------|-----------------|--------------------|-----------------------------|
| Ранок (morning) | [0, 720) | 00:00–11:59 | 08:00 ✓, 10:30 ✓ |
| День (day) | [720, 1080) | 12:00–17:59 | 13:00 ✓, 16:00 ✓ |
| Вечір (evening) | [1080, 1320) | 18:00–21:59 | 19:00 ✓, 21:00 ✓ |
| Ніч (night) | [1320, 1440) | 22:00–23:59 | 22:00 ✓, 22:30 (mockup melatonin) ✓ |

[ASSUMED — boundaries inferred; the 00:00–03:59 = "morning" simplification and the 21:00 → evening call want a UAT glance. Encode as a single const list so changing a boundary is one line.]

**Block header time:** show the earliest slot time in the block (real user times, `BqText.mono`), not the fixed anchor — a 09:30-only morning reading "08:00" would be false. The anchor times remain only as defaults inherited from Phase 2. [ASSUMED — mockup can't distinguish since demo slots equal anchors; flag at UAT.]

**Empty blocks: hide them** (mockup demo has all four populated; rendering an empty "Ніч — перед сном" section with no rows adds noise). [ASSUMED — discretion.]

**`доза n з m` chip** [VERIFIED: mockup line 608 — `cycle: 'доза 1 з 3'` on multi-slot regimens]: `DayDose.regimen.slots` contains ONLY the dose's own slot [VERIFIED: drift_repositories.dart:355-357 — "The embedded regimen carries the dose's own slot as context"] — do NOT read `regimen.slots.length` for `m` (it is always 1; see PF-6). Derive from the day's own list: group `List<DayDose>` by `regimen.id`; `m` = group size, `n` = 1-based index in slot-time order (the list is already slot-time ordered). Show the chip only when `m > 1` (mockup shows no chip for single-slot regimens — D3/Омега/Магній rows have `note` chips instead).

All grouping/index/missed helpers live in a pure file (`features/calendar/day_view_model.dart` recommended), taking `List<DayDose>` + explicit `today`/`nowMinutes` params — the `stack_status.dart` shape [VERIFIED: stack_status.dart:1-18 — "this file NEVER reads the clock"], unit-tested without widgets.

### P-5: Current block + intra-day "не прийнято вчасно" (overdue)

**Mockup ground truth** [VERIFIED: mockup lines 718-748]: `nowBlock = 2` is hardcoded at demo time 16:20; `missed = !on && bi < nowBlock` puts warn styling on untaken doses of earlier blocks; block header: `timeFg` accent when `bi == nowBlock`; tag = `'усе прийнято'` (calm) when all taken, `'{done} з {items.length}'` (warn) for past blocks, else the meal tag (neutral). Note the demo's nowBlock=2 at 16:20 means **a block turns "past" once its own anchor time has passed** (13:00 < 16:20 → День is past; 19:00 > 16:20 → Вечір is current) — not a range-containment rule.

**Recommended generalization** (real slots, not anchors) [ASSUMED — the hardcoded demo under-determines this]:
- A **dose is overdue** when: viewing today AND `status == pending` AND its `slot.minutesFromMidnight < nowMinutes`. Overdue gets the mockup warn treatment: chip `'не прийнято вчасно'` (`warn`/`warnBg`), row border `rgba(176,122,34,.4)` [VERIFIED: mockup lines 727-733] — token: `BqColors.warn` at 40% alpha needs a one-off token addition (`warnBorder = Color(0x66B07A22)`) per the Phase-2 precedent of mockup-sourced token additions.
- A **block is past** when ALL its doses' slot times have passed; **current** = the first non-past block; blocks after it are future (meal tag, neutral).
- `nowMinutes` comes from a tiny `StreamProvider.autoDispose` minute ticker (`Stream.periodic(Duration(minutes: 1))` mapping to minutes-since-local-midnight), alive only while the calendar watches it. A minute of latency at a block boundary is fine.

**Guilt-framing check:** this warn treatment is mockup-authoritative for *today only* and reads as "ще можна прийняти" context, not a failure log; it never accumulates (no counts, no streaks). Past days never use warn styling (P-6).

### P-6: Missed — view-computed, neutral, zero writes

**Locked semantics** [REQUIREMENTS "Decisions Locked During Definition", verbatim]: "an unmarked dose is displayed as 'missed' when its date is strictly before today (device-local calendar day); the IntakeLog row itself stays `pending`".

```dart
bool isMissed(DayDose d, {required DateTime viewedDay, required DateTime today}) =>
    d.status == DoseStatus.pending && dateOnly(viewedDay).isBefore(dateOnly(today));
```

`today` from `todayProvider` (which is derived from device-local y/m/d — matching "device-local calendar day" exactly). **No repository call, no status write, anywhere in the missed path.** The widget test must assert the raw row: after rendering a past day with missed styling, `db.select(db.intakeLogs)` still shows `status == pending` (raw-read pattern from `test/db/repositories_test.dart` harness).

**Visual treatment (invented — mockup has no past-day view)** [ASSUMED, flag at UAT]: neutral, not warn — checkbox circle stays empty with the default `rgba(23,23,27,.22)` border, name in `textMuted`, one chip `'пропущено'` in neutral chip colors (`chip` bg / `textSecondary` fg — the ПАУЗА palette [VERIFIED: mockup line 583 — paused chip `fg:'#5C5C66', bg:'#F2F1EE'`]), no row-border change. A missed dose on a past day **remains tappable** — marking it taken late is a legitimate correction (`setStatus` is date-agnostic), and undo returns it to pending/missed.

**Skipped styling (also invented)** [ASSUMED]: distinct from taken — checkbox filled `textFaint` with a `−` glyph (vs calm `✓`), name struck-through in `textMuted`, no chip needed. Neutral by construction.

### P-7: Mark taken / skipped / undo

**Mockup ground truth:** tap toggles taken — `tog(id)` flips a boolean; taken rows show `✓` in a calm-filled circle, strike-through name, `rowBg` `surfaceAlt` [VERIFIED: mockup lines 687, 729-736]. There is **no skip affordance and no snackbar** in the mockup.

**Recommendation** (TRACK-02 requires taken OR skipped + undo):
- **Tap** = toggle `pending ↔ taken`. Undo-of-taken is literally the mockup interaction (tap again). One tap, mockup-exact.
- **Long-press** = toggle `pending ↔ skipped` (long-press a taken dose also offers nothing — skip is only meaningful from pending/skipped). Simple, discoverable enough for v1, no new chrome. [ASSUMED — alternatives: a trailing overflow zone per row, or a swipe action; long-press is the least visual noise. Confirm at UAT.]
- **No snackbar-undo**: undo = the inverse gesture on the same row (tap-again / long-press-again). Zero timers, zero SnackBar queue management, and the state is always visible on the row itself. If UAT wants an explicit affordance, a SnackBar with `setStatus(logId, previous)` is a 5-line add later.
- Implementation: `ref.read(intakeRepoProvider).setStatus(logId, next)` — `watchDay` re-emits and the row re-renders; no local optimistic state needed (in-memory SQLite latency is imperceptible; on-device writes are single-digit ms).
- Status transition table (view enforces; repo accepts anything):

| Current | Tap → | Long-press → |
|---------|-------|--------------|
| pending | taken | skipped |
| taken | pending (undo) | — (no-op) |
| skipped | taken [ASSUMED — or pending; pick one and test it] | pending (undo) |

**Ring counts skipped as not-taken:** `takenCount = count(taken)`, `total = all doses` — mockup formula verbatim (`takenCount / DOSES.length`) [VERIFIED: mockup lines 716-717], and matches success criterion "taken vs. total".

### P-8: Day-progress ring — `CustomPaint`, mockup-exact

**Mockup ground truth** [VERIFIED: mockup lines 210-211, 880]: outer circle 46px, `background: conic-gradient(#3F7A6A pct%, #E4E3DD 0)` — a hard-edged sweep, calm on field; inner circle 36px filled `#F7F6F3` (paper), centered text `{takenCount}/{totalDoses}` in JetBrains Mono 500 12px `#3F7A6A` with `tnum`.

**Implementation:** a 46×46 `CustomPaint`: paint full ring `BqColors.field` (stroke width 5, or two filled circles), then `canvas.drawArc(rect, -pi/2, 2*pi*pct, ...)` in `BqColors.calm` with `StrokeCap.butt` (hard edge, matching conic-gradient; `CircularProgressIndicator` is rejected: its M3 defaults add rounded caps + gap + implicit animations that fight the mockup). Center text: `BqText.mono(size: 12, color: BqColors.calm)` — `tnum` already included [VERIFIED: theme.dart:143]. Repaint via `shouldRepaint: old.pct != pct` — no animation needed for v1 (mockup has none). Add `Semantics(label: ...)` with an ARB string ("{taken} з {total} прийнято") since a bare CustomPaint is invisible to screen readers.

When browsing a non-today day, the ring shows that day's counts (same formula — the header is per-viewed-day). [ASSUMED — mockup only shows today; consistent and cheap.]

### P-9: Week day-strip

**Mockup ground truth** [VERIFIED: mockup lines 215-222, 751-761]: 7 equal-flex cells, Mon–Sun (`ПН 10 … НД 16`), gap 5, radius 11, padding 9/10; per cell: dow (mono 10px), day number (500 14px), 4px dot. Today: `bg #4A4E7C` (accent), white text, dot `rgba(255,255,255,.6)`; other days: white bg, `cardBorder` border; dot green `#3F7A6A` on the three past days, `#DEDDD7` (field) on future days.

**Semantics to implement:**
- Cells are **tap targets** selecting the day (mockup is static, but TRACK-03 requires browsing — the strip is the affordance).
- Week = the week containing the **resolved selected day**, Monday-first (mockup order; uk locale is Monday-first anyway — using `MaterialLocalizations.firstDayOfWeekIndex` would flip en-US to Sunday and diverge from the mockup; recommend hard Monday-first for v1 visual consistency [ASSUMED — flag at UAT]). Day numbers via `DateFormat.E`/`DateFormat.d` with the active locale — never hand-built.
- **Dot meaning (invented)** [ASSUMED]: past day → `calm` when every materialized dose that day is non-pending (all handled), `field` otherwise; today → mockup's translucent white; future → `field`. Requires per-day summaries for up to 6 non-selected days: watch `dayDosesProvider(day)` for each strip day (7 autoDispose family instances — each is one cheap SQLite watch; also pre-materializes the visible week, satisfying "generated ahead for the near horizon"). If that feels heavy at plan time, v1-minimal fallback: neutral dots everywhere except today (pure cosmetics, zero queries).
- **Browsing depth:** TRACK-03 says "past and current week days". Recommend: swipe/chevron to previous weeks (each week is just a date-range render; `dayDosesProvider` handles any day), future capped at the current week's Sunday (no browsing into future weeks — planner views own the future). Minimal compliant alternative: current week only. Decide at plan time; the provider layer is identical either way. [ASSUMED — mockup shows no pager.]
- **Header** [VERIFIED: mockup lines 206-207]: title "Сьогодні" + subtitle "четвер, 13 серпня" (`DateFormat('EEEE, d MMMM')`). For a browsed non-today day, title = the weekday name or the formatted date [ASSUMED — recommend: title stays localized "Сьогодні" only when resolved day == today; otherwise the weekday capitalized, subtitle unchanged format].

### Anti-Patterns to Avoid

- **Calling `ensureLogsForDay` from inside `watchDay` or any repo read path** — repos stay side-effect-free on reads; materialization is the provider's job (single choke point, P-2).
- **A second "is this day active" implementation anywhere in features/** — `isActiveOn` via `ensureLogsForDay` is the only activity gate; the view renders exactly what `watchDay` emits. If a day looks wrong, the fix is in domain/tests, never a view-side filter.
- **Writing `missed` (or any status) to the DB from view logic** — locked decision; the only status writer is the user's tap/long-press through `setStatus`.
- **`DateTime.now()` scattered in calendar widgets** — everything flows from `todayProvider` / the minute ticker; per-build clock reads reintroduce IN-06.
- **Porting the mockup's zinc/magnesium advice card or dose-row interaction chips** — interaction claims, never-ship (Deferred Ideas above). Also don't port the hardcoded "16:20" status bar or Радник/Профіль tabs (Phase-1 shell already replaces them).
- **Non-normalized family keys** — `dayDosesProvider(DateTime.now())` creates a phantom cache entry and queries a non-midnight "day". Every family arg passes through `dateOnly()` (PF-1).
- **Skipping the double-activation guard on setStatus taps** — CR-01/WR-01 (Phase 2) were exactly this class of bug; see PF-4.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| "What day is it" + rollover | Per-screen timers, per-build `DateTime.now()` | `todayProvider` (P-1), one place | IN-06 fix must be shared; two clocks drift |
| Day-activity decision | View-side cycle filters | `ensureLogsForDay` → `isActiveOn` (exists, DST-tested) | Single source of cycle truth (Phase-1 D-14) |
| Re-materialization on regimen change | Manual "refresh" buttons / imperative calls after each editor save | `ref.watch(regimensStreamProvider)` inside the day family (P-2) | Riverpod's graph already knows when regimens change |
| Undo infrastructure | Command stack / snackbar queue | `setStatus(logId, pending)` — status writes are symmetric | The repo API is already undo-shaped |
| Locale weekday/month names | ARB keys per weekday/month or string tables | `intl` `DateFormat` (`EEEE`, `d MMMM`, `E`, `d`) | Locked rule: dates via intl, never hand-built |
| Plural forms in counts/semantics labels | `if (n == 1)` logic | ICU plurals in ARB (all four uk forms) | Locked; proven by Phase-1/2 plural tests |
| Progress arc | Chart package | `CustomPaint.drawArc` (~25 lines) | Locked bespoke-widget rule; exact fidelity |
| Stream combination (day + today + ticker) | Manual StreamZip/combineLatest | Riverpod provider composition (`ref.watch` of each) | Established Pattern 5 from Phase 1 [VERIFIED: providers.dart:12-18] |

## Validation Rules (V-1)

| Concern | Rule | Enforced where |
|---------|------|----------------|
| Status writes | Only `pending`/`taken`/`skipped`, only via row gestures, transition table P-7 | Widget layer decides `next`; repo accepts any (unchanged) |
| Double-activation | A row ignores gestures while its `setStatus` future is in flight | Row widget guard (`_busy` flag) — CR-01/WR-01 precedent (PF-4) |
| Family keys | Every `dayDosesProvider` arg is `dateOnly()`-normalized | Call sites (strip/selected-day resolver produce only normalized values); `assert(day == dateOnly(day))` in the provider as backstop |
| Browsing range | Future days beyond current week not reachable | Strip/pager construction (structural, no validation code) |
| Missed | Never written to DB; derived only when `viewedDay < today` | Pure helper `isMissed` + raw-row test assertion |

## Common Pitfalls

### PF-1: Non-normalized `DateTime` family keys silently fork the cache
**What goes wrong:** `DateTime` equality requires same microseconds AND same `isUtc`; `dayDosesProvider(DateTime.now())` vs `dayDosesProvider(dateOnly(now))` are two different family entries — one queries a nonsense "day" (`watchDay` normalizes internally so it *works*, but you now hold two subscriptions and can double-materialize UI state).
**Avoid:** All keys originate from `todayProvider`/strip cells (already normalized); assert normalization at the provider entry.
**Warning sign:** duplicate Drift stream subscriptions for the same date in devtools; a test watching two spellings of the same day sees two provider instances.

### PF-2: Midnight timer scheduled as "+24h" breaks on DST days
**What goes wrong:** `Timer(Duration(hours: 24))` fires at 23:00 or 01:00 on Ukraine's 25h/23h DST days (last Sundays of March/October), making "today" flip an hour early/late.
**Avoid:** compute next midnight via the LOCAL `DateTime(y, m, d + 1)` constructor and subtract (P-1) — Dart normalizes day overflow and the difference absorbs DST. Add the +1s fudge so the tick lands after midnight, and always **re-derive** the day from the clock in the callback (never increment the old value); the resume listener covers suspended timers.
**Warning sign:** unit test of `nextLocalMidnight` around a DST date fails; today flips at 23:00 in an October manual test.

### PF-3: `ensureLogsForDay` still has zero production callers after the UI lands
**What goes wrong:** `watchDay` renders only materialized rows; wire the screen straight to `watchDay` and every day is empty despite active regimens — the classic "works in tests, blank on device" failure (the repo tests always call `ensureLogsForDay` manually).
**Avoid:** the P-2 provider is the only sanctioned `watchDay` consumer; grep-check at review: `watchDay` must have exactly one caller in `lib/` (the day family).
**Warning sign:** an integration-style test that seeds a regimen via `regimenRepo.upsert`, watches `dayDosesProvider(today)` (no manual ensure), and expects rows — write exactly that test.

### PF-4: Double-tap races on `setStatus` (the CR-01 lesson, again)
**What goes wrong:** two quick taps enqueue `pending→taken` twice; the second computes `next` from stale state (`taken→pending`), and the row visually "doesn't respond". Worse with tap+long-press interleavings. Not data-corrupting (last write wins on one row) but feels broken.
**Avoid:** per-row in-flight guard: ignore gestures while the previous write's future is pending; compute `next` from the row's *current* rendered status at gesture time. Widget-test the double-tap (Phase-2 pattern: `test/features/regimen_editor_test.dart` double-tap test).
**Warning sign:** rapid-tap widget test ends with status != taken.

### PF-5: Mockup content that must NOT ship in this phase
The mockup Calendar screen is authoritative for *visuals*, not *scope*. Do not port: the **zinc/magnesium spacing advice card** [VERIFIED: mockup lines 260-263 — "Цинк і магній стоять у різних блоках навмисно…"] and **row interaction chips** (`'взаємодія з КОК'`, `'2 год після сертраліну'` — lines 609, 614) — interaction claims, never-ship; the **hardcoded date/time** ("четвер, 13 серпня", "16:20") — everything comes from the clock/intl; the mockup's **`не разом із цинком` note on Магній** (line 614) — that's a `supplement.note` in our model, fine, but only if the user typed it (never seed it). The **disclaimer line DOES ship** [VERIFIED: mockup line 264 — "Розклад складено з ваших власних записів. Освітній матеріал, не медична порада."] — new ARB key; note the existing `disclaimerEducational` key holds only the second sentence [VERIFIED: app_uk.arb:7].

### PF-6: `DayDose.regimen.slots` is a single-slot context, not the full set
**What goes wrong:** rendering `доза {n} з {regimen.slots.length}` always shows "з 1" — the embedded regimen carries only the dose's own slot [VERIFIED: drift_repositories.dart:355-357].
**Avoid:** derive `m`/`n` by grouping the day's `DayDose` list by `regimen.id` (P-4). Never call `regimenRepo` from the row renderer for this.
**Warning sign:** the chond fixture (3 slots) renders "доза 1 з 1".

### PF-7: Loading flash when switching days
**What goes wrong:** each strip tap watches a *different* family instance → `AsyncLoading` for a frame or two → the list blanks and re-appears, reading as flicker.
**Avoid:** acceptable v1 mitigation: render the previous list from `asyncValue.valueOrNull ?? previousData` (hold last data in the screen state), or just accept the sub-frame blank — in-memory-fast SQLite typically resolves before the next frame. If the strip pre-watches all 7 days (P-9 dots), today↔week-day switches are already warm. Don't reach for keepAlive hacks.
**Warning sign:** visible blank between day switches on device.

### PF-8: New count-bearing ARB keys missing uk plural forms
**What goes wrong:** this phase adds count keys (`blockProgress`, ring semantics label). A uk key missing `many` silently renders wrong at 5/11.
**Avoid:** all four CLDR forms (one/few/many/other) on every count key, both files in the same commit; extend `test/l10n/plurals_test.dart` exemplars (1, 2, 5, 11, 21). Note `blockProgress` "X з Y" needs no plural (bare numerals), but the semantics label ("{taken} з {total} прийнято") does if phrased with a noun.
**Warning sign:** plural test extension fails, or `flutter gen-l10n` warns untranslated.

### PF-9: Paused-regimen doses are invisible, not disabled
**What goes wrong:** assuming a paused regimen's pending doses need "greyed" rendering — they are filtered OUT by `watchDay` (`paused AND pending` excluded), while its taken/skipped history remains visible [VERIFIED: drift_repositories.dart:325-336]. Overdue/missed/ring math must not special-case pause — the data layer already did.
**Avoid:** treat `watchDay` output as ground truth; write the view-model tests against fixtures that include a paused regimen with mixed statuses (reuse `test/db/pause_filter_test.dart` fixtures).

## Code Examples

### Pure grouping helpers (features/calendar/day_view_model.dart — clockless)

```dart
/// Block index for a slot time. Boundaries per P-4 (ASSUMED, single const).
const blockStartsMinutes = [0, 720, 1080, 1320]; // morning, day, evening, night
int blockIndexOf(int minutesFromMidnight) {
  for (var i = blockStartsMinutes.length - 1; i >= 0; i--) {
    if (minutesFromMidnight >= blockStartsMinutes[i]) return i;
  }
  return 0;
}

/// Groups the (already slot-time-ordered) day list into non-empty blocks and
/// computes per-regimen dose indices (P-4 / PF-6).
List<DayBlock> groupIntoBlocks(List<DayDose> doses) { /* fold by blockIndexOf */ }

/// P-6 — the ONLY missed rule (locked decision, view-computed).
bool isMissed(DayDose d, {required DateTime viewedDay, required DateTime today}) =>
    d.status == DoseStatus.pending &&
    dateOnly(viewedDay).isBefore(dateOnly(today));

/// P-5 — overdue applies on today only.
bool isOverdue(DayDose d, {required bool viewingToday, required int nowMinutes}) =>
    viewingToday &&
    d.status == DoseStatus.pending &&
    d.slot.minutesFromMidnight < nowMinutes;
```

### DST + year-boundary materialization test skeleton (TRACK-04)

```dart
// Cycle math is UTC-pure (Phase-1 tested); this test proves the FULL chain
// (ensureLogsForDay → watchDay) stays exact across the uk DST fall-back day
// and a year boundary. Europe/Kyiv DST ends Sun 2026-10-25.
test('one log per slot per day across DST transition', () async {
  // cyclic r1: start 2026-10-19 (Mon), onDays 7, offDays 7, one 08:00 slot
  for (var d = 0; d < 14; d++) {
    final day = DateTime.utc(2026, 10, 19).add(Duration(days: d));
    await intake.ensureLogsForDay(day);
    await intake.ensureLogsForDay(day); // idempotency under repetition
    final doses = await intake.watchDay(day).first;
    expect(doses.length, d < 7 ? 1 : 0); // exactly on-week then off-week, incl. Oct 25
  }
});
test('cycle continues correctly across year boundary', () async {
  // cyclic start 2026-12-28, onDays 7, offDays 7 → active through Jan 3, off Jan 4
  // assert watchDay on 2026-12-31, 2027-01-01, 2027-01-03 (1 dose) and 2027-01-04 (0)
});
```

### Raw-row missed assertion (TRACK-03 — "DB stays pending")

```dart
// after pumping a past day rendered with the 'пропущено' chip:
final raw = await db.select(db.intakeLogs).get();
expect(raw.single.status, DoseStatus.pending);   // view-only missed — no write
```

### New ARB keys inventory (both files, uk verbatim from mockup where it exists)

```
calendarTitleToday      "Today" / "Сьогодні"                          [mockup 206]
blockMorning/blockDay/blockEvening/blockNight
                        "Morning/Day/Evening/Night" / "Ранок/День/Вечір/Ніч"  [mockup 617-620]
blockTagBreakfast       "with breakfast" / "зі сніданком"             [617]
blockTagLunch           "with lunch" / "з обідом"                     [618]
blockTagDinner          "with dinner" / "з вечерею"                   [619]
blockTagSleep           "before sleep" / "перед сном"                 [620]
blockAllTaken           "all taken" / "усе прийнято"                  [744]
blockProgress           "{done} of {total}" / "{done} з {total}"      [744 — bare numerals, no plural]
overdueLabel            "not taken on time" / "не прийнято вчасно"    [727]
missedLabel             "missed" / "пропущено"                        [ASSUMED — invented neutral chip, P-6]
doseCycleChip           "dose {n} of {m}" / "доза {n} з {m}"          [608]
ringSemantics           "{taken} of {total} taken" / plural-correct uk [a11y, P-8 — needs 4 uk forms]
calendarDisclaimer      full two-sentence line                        [264 — distinct from disclaimerEducational]
emptyDayTitle/emptyDayBody                                            [ASSUMED — no-doses state, discretion]
```

(en renderings [ASSUMED — Claude translations, UAT eyes]. Weekday/month/date strings come from `intl`, NOT ARB.)

## Edge Coverage

| # | Edge | Expected behavior |
|---|------|-------------------|
| E-1 | App open across midnight on Today | `todayProvider` flips → resolved day changes → new family materializes; yesterday's untaken doses now render missed when browsed; Stack statuses also refresh (IN-06 closed) |
| E-2 | Browse a past day never opened before | Lazily materialized as pending → missed styling; raw rows stay `pending` (locked); tappable to mark late |
| E-3 | Browse a past day for a regimen created today with a backdated startDate | `isActiveOn` says active → rows materialize → missed. Accepted: cycle truth governs, matches TRACK-04 [ASSUMED acceptable — flag at UAT if it surprises] |
| E-4 | Pause → browse days → resume | Paused: pending hidden per filter, history visible; resume: rows reappear with zero writes; day family re-materializes via regimens watch (proven lossless in pause_filter_test) |
| E-5 | Regimen slot time edited after past logs exist | Slot join is live: past days display the NEW time (accepted Phase-2 quirk, PF-8 note there); no action |
| E-6 | All doses skipped | Ring shows 0/N (taken vs total, mockup formula); block tag: `'усе прийнято'` would be wrong — recommend the done-tag only when all *taken*; otherwise past block shows `{done} з {total}` [ASSUMED — flag] |
| E-7 | Day with zero doses (empty stack, off-week, all paused) | Empty state (`emptyDayTitle`/`Body`), ring 0/0 → render ring empty-track with "0/0" or hide ring [ASSUMED — recommend hiding the ring at total == 0]; disclaimer still shown |
| E-8 | DST fall-back day (2026-10-25) and spring-forward | Exactly one log per active slot; day boundaries correct (UTC date-only math end-to-end; TRACK-04 test) |
| E-9 | Year boundary (Dec 28 cycle spanning Jan) | Cycle continues uninterrupted (TRACK-04 test) |
| E-10 | Future day within current week | Materialized lazily, renders pending rows, NO overdue/missed styling (both gated on viewedDay/today), meal tags neutral |
| E-11 | Rapid tap + long-press interleaving on one row | In-flight guard: second gesture ignored; final status deterministic (PF-4 test) |
| E-12 | Device timezone change / travel | `onResume` re-derives today from the local clock; no stored local dates exist anywhere (all UTC date-only) — worst case is a one-day shift of "today", self-correcting |

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | `flutter_test` (SDK) + in-memory Drift (`BoostqueDb.forTesting(NativeDatabase.memory())`) + ProviderScope overrides — harness proven in Phases 1–2 |
| Config file | `analysis_options.yaml` (exists) |
| Quick run command | `flutter test test/features/<file>_test.dart` |
| Full suite command | `flutter analyze && flutter test` (162 tests green at Phase-2 close) |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| TRACK-01 | Block grouping (boundaries, dose-index derivation, empty-block hiding) | unit (pure helpers) | `flutter test test/features/day_view_model_test.dart` | ❌ Wave 0 |
| TRACK-01 | Today view renders blocks + ring counts from a live in-memory DB | widget | `flutter test test/features/calendar_screen_test.dart` | ❌ Wave 0 |
| TRACK-02 | Tap → taken in DB; tap again → pending; long-press → skipped; double-tap guarded | widget + raw-row asserts | same file | ❌ Wave 0 |
| TRACK-03 | Past-day browse: missed styling, raw row stays pending; strip navigation | widget + raw-row assert | same file (+ `day_view_model_test.dart` for `isMissed`) | ❌ Wave 0 |
| TRACK-04 | DST (2026-10-25) + year-boundary materialization exact; ensure→watch chain | unit (repo chain) | `flutter test test/db/materialization_boundaries_test.dart` | ❌ Wave 0 |
| TRACK-04 | `dayDosesProvider` materializes without manual ensure; re-materializes on regimen change | provider unit (container harness) | `flutter test test/providers_calendar_test.dart` | ❌ Wave 0 |
| (P-1) | `nextLocalMidnight` pure fn: normal day, DST day, Dec 31 | unit | `flutter test test/features/today_provider_test.dart` | ❌ Wave 0 |
| DATA-03 | Full loop on iOS simulator + Android emulator (targetSdk 36) | **manual — checkpoint:human-verify** (no device automation in suite; `integration_test` reserved but not required for v1 per design spec) | `flutter run` on both | — |
| (l10n) | New count keys correct at 1/2/5/11/21 uk | unit | extend `test/l10n/plurals_test.dart` | exists — extend |

### Sampling Rate
- Per task commit: the relevant single test file; per wave merge: `flutter analyze && flutter test`; phase gate: full suite green + the DATA-03 human-verify checkpoint before `/gsd-verify-work`.

### Wave 0 Gaps
- [ ] `test/features/day_view_model_test.dart` — pure helpers (build FIRST; everything renders through them)
- [ ] `test/db/materialization_boundaries_test.dart` — DST/year-boundary chain (TRACK-04 gate)
- [ ] `test/providers_calendar_test.dart` — day family + today controller wiring (harness: `test/providers_test.dart` container/override pattern)
- [ ] `test/features/calendar_screen_test.dart`, `test/features/today_provider_test.dart`
- [ ] Plural-test extension for `ringSemantics`
- No new fixtures framework; reuse the in-memory-DB + ProviderScope harness and the pause/cascade test fixtures

## Security Domain

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2/V3/V4 Auth/Session/Access | No | Offline single-user app, unchanged |
| V5 Input Validation | Marginal | No free-text input this phase; only enum status writes through gestures (transition table P-7); Drift parameterized queries throughout — no raw SQL in the delta |
| V6 Cryptography | No | Unencrypted SQLite remains the accepted v1 trade-off |

Threat notes: no destructive actions added (status writes are all reversible by design — undo IS the feature). The one integrity rule: no code path may write `DoseStatus` except the two row gestures; the missed path is read-only (locked). Grep-check at review: `setStatus` callers in `lib/` limited to the calendar row handlers.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Flutter SDK 3.47 / Dart 3.13 | everything | ✓ | 3.47.0 | — |
| Android targetSdk 36 | DATA-03 | ✓ [VERIFIED: android/app/build.gradle.kts:23 — `targetSdk = 36`] | 36 | — |
| iOS simulator (Xcode 26.5) + Android emulator | DATA-03 run checkpoint | ✓ per design-spec environment (both platforms built in Phase 1, criterion 1) | — | Physical devices |
| `node` (gsd-tools seams) | automated research seams | ✗ (sandbox constraint) | — | Manual verification performed (as Phases 1–2) |

No blocking gaps. DATA-03 needs a human at the checkpoint (simulator + emulator run of the full add→schedule→see→mark loop) — plan it as `checkpoint:human-verify`, not an automated task.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Block hour boundaries (morning <12:00, day 12–18, evening 18–22, night ≥22) | P-4 | A dose lands in a neighboring block — one-line const fix; UAT eyeball |
| A2 | Block header shows earliest real slot time, not the 08:00/13:00/19:00/22:00 anchors | P-4 | Cosmetic; trivially swappable |
| A3 | Skip affordance = long-press toggle; skipped→tap = taken | P-7 | Interaction-taste; UAT confirms; repo API unaffected |
| A4 | Past-day missed styling: neutral `пропущено` chip in paused-chip palette; skipped uses `−` glyph | P-6 | Cosmetic, invented (no mockup reference); UAT |
| A5 | Empty blocks hidden; ring hidden at total == 0; empty-day state invented | P-4/E-7 | Cosmetic; UAT |
| A6 | Week strip hard Monday-first in both locales; dot = all-handled indicator; previous-week browsing via swipe/chevron, future capped at current week | P-9 | UX scope call — planner/UAT; provider layer identical either way |
| A7 | `DateFormat('EEEE, d MMMM', 'uk')` renders "четвер, 13 серпня" (genitive) | header | One unit test catches it; fallback pattern `'EEEE, d MMMM'` vs `'EEEE, d MMM'` adjustments |
| A8 | Non-today browsed days show that day's ring counts in the same header | P-8 | Cosmetic |
| A9 | Backdated-regimen past days rendering as missed is acceptable (E-3) | Edge | Product-taste; flag at UAT |
| A10 | `Stream.periodic` minute ticker is acceptable battery/perf-wise while calendar is visible | P-5 | Nil in practice (autoDispose; UI-thread no-op map) |

## Open Questions

1. **How far back can the user browse?** (P-9/A6)
   - What we know: TRACK-03 says "past and current week days"; mockup shows one static week; `dayDosesProvider` supports any day for free.
   - What's unclear: whether "past" means arbitrary past weeks or just the elapsed part of the current week.
   - Recommendation: previous-week paging (cheap, honest reading of "past days"); cap future at current week's end. Confirm during planning/UAT — no architecture changes either way.
2. **Intra-day overdue treatment — ship the mockup's warn styling or soften?** (P-5)
   - What we know: mockup shows `'не прийнято вчасно'` warn chips + `X з Y` warn tags for earlier blocks of today; the neutrality mandate in TRACK-03 formally covers *past days* only.
   - What's unclear: whether amber-on-today crosses the "never guilt-framed" line for the user.
   - Recommendation: ship mockup-exact (it is the approved visual), keep past days neutral; revisit at UAT.
3. **Skipped rows and the block "усе прийнято" tag** (E-6)
   - What we know: mockup has no skipped state; tag fires on all-taken.
   - Recommendation: done-tag on all-taken only; a block with skips that's fully handled shows the past-block `X з Y` tag (honest). Confirm at UAT.

## Sources

### Primary (HIGH confidence)
- Project code read line-by-line this session: `lib/core/domain/{models,cycle_math,repositories}.dart`, `lib/core/db/{database,drift_repositories}.dart`, `lib/core/providers.dart`, `lib/core/theme/{tokens,theme}.dart`, `lib/features/stack/{stack_screen,stack_status}.dart`, `lib/features/calendar/calendar_screen.dart` (stub), `android/app/build.gradle.kts` — all line citations refer to these reads
- `claude_design_mockup/Boostque v0.1.dc.html` — Calendar screen (lines 193-274) and script data (576-761, 860-880) read this session; all mockup citations verbatim
- Test suite read/grepped this session: `test/db/{repositories,pause_filter,cascade_delete}_test.dart` callers of `ensureLogsForDay` (proving zero production callers), pause round-trip losslessness
- [api.flutter.dev — AppLifecycleListener](https://api.flutter.dev/flutter/widgets/AppLifecycleListener-class.html) — fetched this session; constructor/dispose semantics quoted in Standard Stack
- `.planning/phases/02-stack-management/02-RESEARCH.md`, `02-REVIEW.md` (IN-01..07, CR-01/WR-01 double-activation lessons, IN-06 midnight staleness), `02-PATTERNS.md` (test harnesses, import conventions, file-header convention)

### Secondary (MEDIUM confidence)
- REQUIREMENTS.md / ROADMAP.md / design spec `docs/superpowers/specs/2026-08-14-boostque-v1-design.md` — locked missed semantics, materialization strategy ("lazily for browsed dates"), v1 test expectations

### Tertiary (LOW confidence)
- intl uk CLDR rendering of `'EEEE, d MMMM'` as "четвер, 13 серпня" (A7) and Ukraine 2026 DST dates (last Sundays of March/October → 2026-10-25) — training knowledge, each pinned by a unit test rather than a doc fetch

## Metadata

**Confidence breakdown:**
- Repo/provider integration (materialization wiring, pause interplay, undo via setStatus): HIGH — every claim cites read code with line ranges; the key negative claim (no ensureLogsForDay production caller) grep-verified
- Mockup extraction (block meta, row anatomy, ring, strip, state logic): HIGH — verbatim quotes from this session's read
- Midnight/lifecycle mechanics: HIGH for the API (fetched), MEDIUM for DST-date specifics (test-pinned)
- Invented UX (boundaries, skip, missed/skipped styling, strip navigation): LOW by nature — all flagged ASSUMED with cheap reversal paths

**Research date:** 2026-08-15
**Valid until:** ~30 days (SDK APIs and mockup stable; no fast-moving dependencies in this phase)
