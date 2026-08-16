# Cross-Phase Integration Check — Boostque v1

Scope: Phases 1–5 (Foundation, Stack Management, Daily Tracking, Planner Views,
Localization & Settings). Method: static trace of each E2E flow across phase
boundaries. No `flutter` commands run (analyzer/tests/device runs already
confirmed green by the orchestrator).

## Per-flow verdicts

### Flow 1 — Plan → see → mark: WORKS
Traced end to end:
`add_supplement_sheet.dart:119/149` (`supplementRepoProvider.upsert`) →
`_popThenPushEditor` → `regimen_editor_controller.dart:380`
(`regimenRepoProvider.upsert`, slot reconcile in one transaction) →
`regimensStreamProvider` re-emits → `dayDosesProvider`
(`core/providers.dart:108`) re-runs `ensureLogsForDay` + `watchDay` →
`calendar_screen.dart:92-93` renders the resolved day →
`day_block_section.dart` groups by time block →
`dose_row.dart:93` `intakeRepoProvider.setStatus` (the app's single write
site; tap toggles taken↔pending = undo; long-press → `dose_action_sheet` →
same `_apply`) → Drift row update → `watchDay` stream re-emits → row repaints.
Persistence is a real row update, not local state. In-flight `_busy` guard
prevents double-write oscillation.

### Flow 2 — Cycle correctness across Today / Цикли / Рік: BROKEN (one seam)
Single activity decision point holds by design: `isActiveOn`
(`core/domain/cycle_math.dart:26`) is the only implementation, called from
exactly two places — `drift_repositories.dart:285` (materialization) and
`planner_view_model.dart:60` (`activeRuns`, feeding both `buildCyclesModel`
and `buildYearModel`) — plus the editor's read-only 28-day preview strip
(`regimen_editor_screen.dart:571`), which builds a throwaway draft Regimen
rather than re-deriving modular math. No duplicate cycle logic exists.

**BLOCKER — stale materialized doses after a schedule edit.**
`RegimenRepository.upsert` (`drift_repositories.dart:159-209`) rewrites the
regimen row and reconciles slots but never touches `intakeLogs`, and
`watchDay` (`drift_repositories.dart:311-353`) filters only on: log deleted,
regimen deleted, supplement deleted, slot deleted-and-pending, regimen
paused-and-pending. It never re-checks `isActiveOn`. So if a day was already
materialized (Today always is; any browsed day too) and the user then edits
`startDate`, `onDays`/`offDays`, `kind`, or shortens a course `endDate`, the
previously written pending rows survive for days the new schedule says are
OFF. Today keeps showing the dose; the planner (pure projection) shows the day
bare. Concrete repro: today is on-cycle → Today materializes a dose → open the
editor, move `startDate` to tomorrow → save → Цикли/Рік show today off, Today
still lists a tappable pending dose.
Mutation coverage is asymmetric: delete (cascade stamps future pending logs),
slot removal (slot `deletedAt` filter) and pause (paused-and-pending filter)
are all handled — only schedule-shape edits are not. No test covers this case
(`test/providers_calendar_test.dart` exercises re-materialization only for a
fixed schedule).
Affected requirements: TRACK-01/TRACK-02 vs PLAN-01/PLAN-02, REGI-01/REGI-02.
Fix shape: either stamp `deletedAt` on future pending logs of the regimen
inside the `upsert` transaction (mirroring `softDeleteCascade`), or add an
`isActiveOn`-equivalent predicate to `watchDay`. Since the pause/slot cases
chose the filter route, extending the filter keeps one policy.

### Flow 3 — Pause / resume: WORKS
One draft flag, three consistent surfaces. `togglePause`
(`regimen_editor_controller.dart:324`) flips the draft; `save` persists it via
the same `upsert` (`paused: draft.paused`), and `RegimensCompanion.paused`
lands in the row. Downstream: Today suppresses future doses through the
paused-and-pending filter in `watchDay` (taken/skipped history stays visible,
resume needs zero writes); Stack shows `StackStatus.paused` —
`stack_status.dart:40` checks `r.paused` before any date logic, so a paused
planned/finished regimen still reads paused; planner shows a bare track
because `isActiveOn` returns false on every day (`planner_view_model.dart:173`
`row.paused` additionally adds the word so it is distinguishable from
"off-cycle all window").
**WARNING (orphaned API):** `RegimenRepository.setPaused` /
`DriftRegimenRepository.setPaused` (`drift_repositories.dart:212`) has no
production caller — pause flows entirely through `upsert`. Dead but tested
surface; a future "pause from the Stack card" would be the second write path
for the same bit. Remove it or route the editor through it.

### Flow 4 — Delete: WORKS
`regimen_editor_controller.deleteSupplement:410` →
`softDeleteCascade(supplementId, fromDay: ref.read(todayProvider))` — the day
comes from the single clock, not `DateTime.now()`. The transaction
(`drift_repositories.dart:75-119`) stamps supplement, its active regimens,
their active slots, and only `pending` logs dated ≥ today. Effects:
Stack drops it (`watchAll` filters `deletedAt.isNull()` →
`supplementsStreamProvider` → `stackEntriesProvider`); planner drops it (same
provider is the planner's only data source, `planner_providers.dart:38/51`);
Today drops future pending doses both by the stamped logs and by the
`regimens.deletedAt.isNull()`/`supplements.deletedAt.isNull()` joins in
`watchDay`. Taken/skipped rows and past pending rows keep `deletedAt` null —
history preserved, as required by STACK-04/DATA-02.

### Flow 5 — Language switch: WORKS
`language_picker.dart:82` → `localeControllerProvider.notifier.setLocale` →
`main.dart:62` `MaterialApp.locale`. All feature state lives in Riverpod
providers hosted by the `ProviderScope` ABOVE `MaterialApp`
(`main.dart:37-42`), so a locale change rebuilds the localization subtree only:
`selectedDayProvider`, `selectedWeekProvider`, `selectedMonthProvider`,
`calendarPageProvider`, `plannerSegmentProvider` and every Drift stream are
untouched. `home: const AppShell()` keeps `_AppShellState._selectedIndex`
(same element updated in place). Selected week/month are stored as DATES, not
indices (`planner_providers.dart:89/141`), so even a full model rebuild
re-resolves to the same bucket. Catalog rows snapshot the active locale's name
at add time (`add_supplement_sheet.dart:104` copy-on-add) — deliberate, not
corruption.

### Flow 6 — Midnight rollover: WORKS
`TodayController` (`core/today_controller.dart`) is the only sanctioned date
read: no `DateTime.now()` outside it, `drift_repositories` (audit timestamps
only) and `calendar_providers._minuteOfDay` (a minute-of-day int that cannot
yield a date). It re-derives from the clock rather than incrementing, uses
local-midnight construction (DST-safe) and re-refreshes on `AppLifecycleListener`
resume. Consumers verified: Today via `resolvedDayProvider`
(`calendar_providers.dart:49`, `null` selection = follow today), week strip
(`week_strip.dart:126`), Stack card status (`stack_screen.dart:45` →
`statusOf`), planner `todayIndex`/`currentWeekIndex`/year model
(`planner_providers.dart:37/50/175`). All three surfaces move on one state
change.

## Seams and drift

1. **Materialization vs projection (BLOCKER, flow 2).** Two representations of
   the same schedule — written rows vs computed runs — reconciled only on
   create, never on edit. This is the one place the phases genuinely disagree.
2. **`setPaused` orphan (WARNING).** Repository capability with no consumer;
   pause is written through `upsert`. Two potential write paths for one bit.
3. **Two day-dose providers (documented, healthy).** `dayDosesProvider`
   materializes, `dayDosesReadOnlyProvider` does not (WR-06). The read-only
   one is currently unused in production — `week_strip.dart:170` watches the
   MATERIALIZING `dayDosesProvider` for its 7 visible days, which is the exact
   write-amplification the read-only variant was introduced to prevent (bounded
   to the visible week + TickerMode gate, so not a defect, but the variant's
   stated rationale and its actual use have drifted apart). WARNING.
4. **Clock discipline: no drift.** Single `todayProvider`; `statusOf`,
   `isActiveOn`, `buildCyclesModel`, `buildYearModel` all take `today` as a
   parameter and never read a clock.
5. **Repository-interface boundary: intact.** `features/` imports only
   `core/domain/repositories.dart` types via `core/providers.dart`; no Drift
   symbol leaks into a feature file. `DriftIntakeRepository` itself consumes
   `RegimenRepository` through the interface.

## Requirements integration map (cross-phase paths only)

| Requirement | Integration path | Status |
|---|---|---|
| STACK-01/02 | add sheet → `supplementRepoProvider.upsert` → stream → Stack + planner | WIRED |
| STACK-03 | `stackEntriesProvider` → `statusOf`/`scheduleSummaryOf` → card | WIRED |
| STACK-04 | editor → `softDeleteCascade` → Stack, Today, both planner views | WIRED |
| REGI-01/02 | editor → `regimenRepoProvider.upsert` → `isActiveOn` consumers | PARTIAL — stale logs on edit (seam 1) |
| REGI-03 | slot reconcile → slot `deletedAt` → `watchDay` filter | WIRED |
| REGI-04 | pause flag → `watchDay` filter + `statusOf` + bare track | WIRED |
| TRACK-01..03 | `dayDosesProvider` → `dose_row` → `setStatus` → stream | WIRED |
| TRACK-04 | week strip dot ← `dayDosesProvider` | WIRED (see seam 3) |
| PLAN-01..04 | `stackEntriesProvider` + `todayProvider` → planner models | PARTIAL — disagrees with Today after edits (seam 1) |
| L10N-01..04 | `localeControllerProvider` → `MaterialApp.locale` → all screens | WIRED |
| DATA-01..03 | UUID PKs, soft deletes, `dateOnly` UTC keys across all repos | WIRED |

## Overall verdict

**INTEGRATED WITH ONE BLOCKER.** Five of six flows complete end to end with no
missing connection; the phase boundaries are unusually clean (one clock, one
activity predicate, one status write site, one delete path). The single real
break is that a schedule EDIT does not reconcile already-materialized doses,
so Phase 3's Today and Phase 4's planner can show different answers for the
same day. Fix that (plus the two warnings) and the milestone is coherent.
