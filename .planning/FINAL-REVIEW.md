---
phase: final-whole-codebase
reviewed: 2026-08-16T00:00:00Z
depth: deep
scope: whole-codebase (all of lib/ excluding generated l10n, plus the test suite)
files_reviewed: 41
files_reviewed_list:
  - lib/main.dart
  - lib/app_shell.dart
  - lib/core/providers.dart
  - lib/core/today_controller.dart
  - lib/core/db/database.dart
  - lib/core/db/drift_repositories.dart
  - lib/core/domain/cycle_math.dart
  - lib/core/domain/models.dart
  - lib/core/domain/repositories.dart
  - lib/core/l10n/casing.dart
  - lib/core/l10n/l10n.dart
  - lib/core/l10n/locale_controller.dart
  - lib/core/theme/theme.dart
  - lib/core/theme/tokens.dart
  - lib/core/widgets/bq_segmented.dart
  - lib/features/calendar/calendar_providers.dart
  - lib/features/calendar/calendar_screen.dart
  - lib/features/calendar/day_block_section.dart
  - lib/features/calendar/day_progress_ring.dart
  - lib/features/calendar/day_view_model.dart
  - lib/features/calendar/dose_action_sheet.dart
  - lib/features/calendar/dose_row.dart
  - lib/features/calendar/planner_gantt.dart
  - lib/features/calendar/planner_load_chart.dart
  - lib/features/calendar/planner_month_detail.dart
  - lib/features/calendar/planner_providers.dart
  - lib/features/calendar/planner_screen.dart
  - lib/features/calendar/planner_view_model.dart
  - lib/features/calendar/planner_week_detail.dart
  - lib/features/calendar/planner_year_grid.dart
  - lib/features/calendar/week_strip.dart
  - lib/features/settings/language_picker.dart
  - lib/features/settings/settings_screen.dart
  - lib/features/stack/add_supplement_sheet.dart
  - lib/features/stack/catalog.dart
  - lib/features/stack/regimen_editor_controller.dart
  - lib/features/stack/regimen_editor_screen.dart
  - lib/features/stack/schedule_summary_text.dart
  - lib/features/stack/stack_screen.dart
  - lib/features/stack/stack_status.dart
  - test/ (suite reviewed as a whole; specific files cited per finding)
findings:
  critical: 1
  warning: 8
  info: 6
  total: 15
status: issues_found
remediation:
  applied: 2026-08-16
  fixed: [CR-01, WR-01, WR-02, WR-03, WR-04, WR-05, WR-06, WR-07, WR-08, TW-1, TW-2]
  open: [IN-01, IN-02, IN-03, IN-04, IN-05, IN-06, TW-3, TW-4]
  suite_after: 715 tests green (from 701); flutter analyze clean
---

# Boostque v1 — Whole-Codebase Final Review

**Reviewed:** 2026-08-16
**Depth:** deep (cross-file call chains, layered-fix archaeology, test-suite audit)
**Files Reviewed:** 41 source files + 33 test files
**Status:** issues_found

## Remediation status (applied 2026-08-16)

The Critical and all eight Warnings are fixed, plus test weaknesses TW-1 and
TW-2. The six Info findings and TW-3/TW-4 are documented and deliberately left
open. Suite after: **715 tests green** (from 701), `flutter analyze` clean.

| ID | Status | Commit |
|----|--------|--------|
| CR-01 | fixed | `1ec271f` |
| WR-01 | fixed | `594cd56` |
| WR-02 | fixed | `37e05a3` |
| WR-03 | fixed | `46c63e7` |
| WR-04 | fixed | `f977688` |
| WR-05 | fixed | `ca4fa6f` |
| WR-06 | fixed (refactor, no behaviour change) | `7ec5c69` |
| WR-07 | fixed — ring formatted AND the gate widened (closes TW-3's spelling) | `5ab4a63` |
| WR-08 | fixed | `2129e09` |
| TW-1 | fixed | `6cd1140` |
| TW-2 | fixed | `d5c903e` |
| IN-01 … IN-06 | open — documented, not fixed | — |
| TW-3 | superseded by WR-07's widened gate; the analyzer-based rewrite TW-4 asks for is still open | — |
| TW-4 | open — `stripComments` still strips line comments only | — |

Every behavioural fix was confirmed RED against the pre-fix code before being
applied; the two structural ones (WR-06, TW-2) were verified differently and
that is recorded on their rows below.

## Summary

This codebase is unusually disciplined: the domain layer is genuinely pure, the
repository boundary is real, activity is decided in one function, and the
source-scanning l10n/planner gates are stronger than most projects ever build.
Most of what I probed for came back clean (see "What I looked for and did not
find").

**One Critical.** The materialization path is write-only: `ensureLogsForDay`
inserts rows for days a regimen is active on, but nothing ever removes a row
when the regimen stops being active on that day, and `watchDay` never re-asks
`isActiveOn`. Because `_WeekWarmer` eagerly materializes the *whole current
week including its future days*, any schedule edit that shrinks the active set
leaves live, tappable doses on days the planner simultaneously renders as
off-days. The two views of the app's core value proposition disagree, and the
Today screen is the one that is wrong.

The eight Warnings cluster in two places: **the regimen editor's save path**
(state written back across an await, single-flight future that can swallow a
newer draft, a write to a possibly-disposed Notifier) and **the planner's
degenerate-input handling** (an all-zero year still claims a "densest month").

**Layered-fix damage is low but non-zero.** The repeated CR/WR remediations
across phases produced defensible, well-documented code — but they also
produced two places where a rule established in one file was never carried to
its sibling (`resolvedWeekIndexProvider` vs `resolvedMonthIndexProvider`;
`NumberFormat` in the year grid vs raw interpolation in the ring), and one
comment that no longer describes what the code proves (the TodayController
disposal test).

---

## Critical Issues

### CR-01: Materialized doses are never pruned — editing a schedule leaves live doses on days the regimen is no longer active

**Status:** FIXED in `1ec271f` — `watchDay` re-asks `isActiveOn` in its map step (query-level, no writes), exactly as proposed. Editor-level regression coverage added later under TW-2 (`d5c903e`).

**Files:**
- `lib/core/db/drift_repositories.dart:276-300` (`ensureLogsForDay` — insert-only)
- `lib/core/db/drift_repositories.dart:311-353` (`watchDay` — no `isActiveOn` re-check)
- `lib/features/calendar/week_strip.dart:150-174` (`_WeekWarmer` — pre-materializes future days)

**Issue:**

`ensureLogsForDay` is the only writer of `IntakeLogs` rows and it only ever
inserts (`InsertMode.insertOrIgnore`). `watchDay` filters on
`intakeLogs.deletedAt`, `regimens.deletedAt`, `supplements.deletedAt`,
`regimens.paused` and `regimenSlots.deletedAt` — but it never consults
`isActiveOn`. There is no prune path anywhere in `lib/` (grep for `isActiveOn`
returns exactly four call sites: `ensureLogsForDay`, `activeRuns`, the editor's
preview strip, and nothing else).

So an already-materialized pending row outlives the schedule that created it.

Reachable repro, entirely through the UI:

1. Today is Mon. Create a supplement with a cyclic regimen, `start = today`,
   `onDays = 7`, `offDays = 7`, one 08:00 slot.
2. Open the Calendar tab. `_WeekWarmer` (`week_strip.dart:169-171`) calls
   `dayDosesProvider` for `mondayOfWeek(today) + 0..6` — **seven pending
   IntakeLog rows, including Tue–Sun which are in the future.**
3. Open the regimen editor and move the start date forward two days. Save.
4. `isActiveOn` is now false for Mon and Tue. `activeRuns` — and therefore the
   whole planner — shows those days as off. `watchDay(Tue)` still returns the
   stale row, so the Today screen shows a due dose, styles it overdue after
   08:00, and lets the user mark it taken.

The same holds for switching cyclic→course with an end date in the past, for
shortening a course, and for any start-date change. Because the warmer runs on
every visit to the Calendar tab, the stale window is not a rare race — it is
the normal state after any schedule edit made mid-week.

Impact: the app's stated core value ("see exactly what to take today, with
cycles and breaks computed correctly") is violated, and the corrupted rows are
*writable* — a user can record `taken` against a dose their schedule says does
not exist, permanently polluting intake history.

Note the pause path was solved correctly at the query level (`watchDay`'s
paused-and-pending exclusion, REGI-04/PF-1) precisely so no rows had to be
touched. The same technique was never applied to schedule membership.

**Fix (query-level, mirrors the existing pause filter — no writes, reversible):**

Materialization membership cannot be expressed in SQL against a cyclic
`(start, onDays, offDays)` without arithmetic, so the cleanest fix is at the
repository boundary in `watchDay`'s map step, using the regimen row already
joined in:

```dart
// drift_repositories.dart, inside watchDay's .map((rows) => ...)
return query.watch().map((rows) => rows
    .where((row) {
      final regimenRow = row.readTable(db.regimens);
      final log = row.readTable(db.intakeLogs);
      // A row the schedule no longer claims is history only: keep it if the
      // user recorded something on it, hide it if it is still pending.
      // Same shape as the paused-and-pending rule above (REGI-04, PF-1).
      return log.status != domain.DoseStatus.pending ||
          isActiveOn(_toRegimen(regimenRow, const []), log.date);
    })
    .map((row) { /* existing DayDose construction */ })
    .toList());
```

(`_toRegimen(regimenRow, const [])` is safe: `isActiveOn` reads only
`paused`/`kind`/`startDate`/`endDate`/`onDays`/`offDays`, never `slots`.)

Add a reconcile pass to `ensureLogsForDay` only if you also want the rows gone
from disk; the query filter alone restores correctness and preserves DATA-02.

**Required test (currently absent — see TW-2):** seed a cyclic regimen, call
`ensureLogsForDay` for a day it is active on, `upsert` the regimen with a later
`startDate`, then assert `watchDay(thatDay)` is empty while a row previously
marked `taken` on that day still returns.

---

## Warnings

### WR-01: `RegimenEditorController._doSave` writes a stale draft back over concurrent edits

**Status:** FIXED in `594cd56` — the post-await write now merges the resolved regimen id and the minted slot ids into the CURRENT state, matching slot ids back by time of day. Confirmed RED first, via a gated repository that parks `upsert` mid-flight.

**File:** `lib/features/stack/regimen_editor_controller.dart:345-403`

**Issue:** `_doSave` captures `final draft = state;` at line 347 and, after
`await repo.upsert(...)`, assigns `state = draft.copyWith(regimenId:..., slots:
slots)` at line 401. Any edit the user makes during the awaited transaction —
the slider, the time picker, or a keystroke in the `TextFormField` at
`regimen_editor_screen.dart:642-660` — is silently reverted. Worse, the
`TextFormField`'s key (`slot-dose-$index-${slot.minutesFromMidnight}`) does not
change on a dose-label edit, so the field keeps *displaying* the typed text
while the draft and the database hold the old value. The save button is
disabled during the flight, but nothing else on the form is.

**Fix:** merge instead of overwrite — only stamp the ids that the save resolved:

```dart
final slotIdByTime = {for (final s in slots) s.minutesFromMidnight: s.id};
state = state.copyWith(
  regimenId: regimenId,
  slots: [
    for (final s in state.slots)
      s.id != null ? s : s.copyWith(id: slotIdByTime[s.minutesFromMidnight]),
  ],
);
```

or, simplest and safest for v1, disable the whole form (`AbsorbPointer`) while
`_saving` is true.

### WR-02: `save()`'s single-flight can resolve successfully without persisting the current draft

**Status:** FIXED in `37e05a3` — saves are SERIALIZED rather than coalesced: each caller gets its own future, the next starts when the previous settles (either way), and the PF-8/T-02-05 no-concurrent-re-check guarantee is preserved by the serialization. The existing double-tap test was retargeted from "same future" to "both run, still one row". Confirmed RED first.

**File:** `lib/features/stack/regimen_editor_controller.dart:342-343`

**Issue:**

```dart
Future<void> save() =>
    _saveInFlight ??= _doSave().whenComplete(() => _saveInFlight = null);
```

A second `save()` issued while the first is in flight returns the *first*
call's future. The comment justifies this for the double-tap case (identical
drafts), which is correct — but the contract it establishes is "`await save()`
means the current draft is on disk", and that is false whenever the draft
changed between the two calls. `save()` is public and the controller test
(`test/features/regimen_editor_controller_test.dart`) drives it directly, so
this is not only a UI-guarded path.

**Fix:** chain instead of coalescing —
`_saveInFlight = (_saveInFlight ?? Future.value()).then((_) => _doSave())` —
or document on `save()` that the in-flight future is only equivalent for an
unchanged draft and have the UI be the sole guarantor.

### WR-03: `_doSave` writes `state` after an await on an `autoDispose` provider that the user can dispose mid-save

**Status:** FIXED in `46c63e7` — both post-await `state` writes check `ref.mounted`. The screen's catch now handles the unmounted case explicitly, reporting the error to the framework rather than swallowing it (there is no button to re-enable and no surface for the SnackBar). Confirmed RED first — `UnmountedRefException`.

**Files:** `lib/features/stack/regimen_editor_controller.dart:401`,
`lib/features/stack/regimen_editor_screen.dart:943-962`, `:221`

**Issue:** `regimenEditorProvider` is `NotifierProvider.autoDispose.family`
(line 419) and is kept alive only by `RegimenEditorScreen.build`'s `ref.watch`.
Tapping Save and immediately using system back / the top-bar back button
(`regimen_editor_screen.dart:221`) pops the route, disposes the provider, and
then `_doSave` resumes and executes `state = draft.copyWith(...)`. Riverpod 3's
`Notifier.state` setter calls `ref._throwIfInvalidUsage()`
(`riverpod-3.4.2/lib/src/core/provider/notifier_provider.dart:90-95`) and
throws on a disposed ref.

Today the blast radius is small — `_save`'s `catch (_)` swallows it, `mounted`
is false so no SnackBar, and the `upsert` already committed. But the error is
swallowed by a handler written for a *failed write*, so a genuinely failed
write and a post-dispose state write are now indistinguishable, and the user
gets no feedback for either.

**Fix:** guard the write and keep the future alive:

```dart
await repo.upsert(...);
if (!ref.mounted) return;          // Riverpod 3 exposes Ref.mounted
state = draft.copyWith(regimenId: regimenId, slots: slots);
```

and have `_save` distinguish "write failed" from "screen went away" rather than
catching everything with `catch (_)`.

### WR-04: The Рік peak chip claims a "densest month" for a year with zero coverage

**Status:** FIXED in `f977688` — "no peak" is representable (`peakIndex == -1`) and `_YearPeakChip` renders nothing for it, matching UI-SPEC S6c's "the summary/peak chip is omitted (there is nothing to summarize)". No new ARB copy needed. Model-level and screen-level tests, both confirmed RED first.

**Files:** `lib/features/calendar/planner_view_model.dart:585-597`,
`lib/features/calendar/planner_screen.dart:389-401`

**Issue:** `buildYearModel` folds `peakLoad` from a seed of `0`. If every month
has `load == 0` — a stack whose only regimens are all paused, or all start
after this calendar year — then `tiedIndices` contains all twelve months,
`peakTied` is `true`, and `peakIndex` resolves to the current month. The chip
renders `l10n.peakMonthsTie(<current month>)` with `l10n.substancesCount(0)`:
"the densest months, including August — 0 substances".

`_YearBody`'s empty state does not catch this, because it keys on
`model.entries.isEmpty` (line 361) and a paused regimen keeps its entry
(`buildYearModel:560-565` filters only on `regimen == null`). Reachable in
three taps: add a supplement, save a regimen, pause it.

**Fix:** make "no peak" representable and render nothing:

```dart
// planner_view_model.dart
final peakIndex = peakLoad == 0 ? -1 : /* existing tie-break */;
```
and in `_YearPeakChip`, `if (model.peakIndex < 0) return const SizedBox.shrink();`
(or render `l10n.emptyPlanner*` copy). Add the same zero-load guard to the
`_CyclesSummaryChip` reading if you want symmetry — that one is honest at zero,
so it needs no change.

### WR-05: A `course` regimen with a null `endDate` displays its start date as its end date

**Status:** FIXED in `ca4fa6f` — the invariant "a course draft always carries an end date" now lives in one function (`_courseEnd`) applied at BOTH boundaries that can produce a course draft (`setKind`, which already seeded 28 days, and `_draftFrom`, which did not). The render sites read it through an asserted getter, per 02-UI-SPEC E3 ("invalid regimens are unrepresentable in the UI"). Confirmed RED first.

**Files:** `lib/features/stack/regimen_editor_screen.dart:357-366`, `:391-394`,
`lib/features/stack/regimen_editor_controller.dart:385-387`

**Issue:** `_PeriodicityPanel` renders the "Кінець" field as
`date: draft.endDate ?? draft.startDate` and the summary as
`courseSummaryRange(start, draft.endDate ?? draft.startDate)`. There is no
representation for "this course has no end date", so a null end renders
indistinguishably from a one-day course. `_doSave` will then persist
`endDate: null`, and `isActiveOn` returns `false` for a course with a null end
(`cycle_math.dart:35-36`) — the regimen is permanently inactive while the
editor shows a valid one-day course and the Stack card shows АКТИВНА.

This is not reachable through the editor today (`setKind` seeds a 28-day end),
so it is a *defensive gap*, not a live bug — but it is a silent-lie gap in the
one screen whose whole job is to show the schedule, and the null is
representable in both the model and the schema.

**Fix:** render the absent case explicitly rather than substituting the start
date — e.g. `if (draft.kind == course && draft.endDate == null)` show the field
in an unset state and disable Save, or have `_draftFrom` seed a default end for
a course that arrives without one (mirroring `setKind`).

### WR-06: `_DayBody` mutates widget state from inside `build()`

**Status:** FIXED in `7ec5c69` — the capture moved to `initState` + `didUpdateWidget` with the same settled condition; `_resolved` is now pure. Behaviour is unchanged by design, so there is NO red-first test for this one: the three existing hold-window groups in `calendar_screen_test.dart` (day switch, same-day reload, error-over-hold) are the regression net and stayed green.

**File:** `lib/features/calendar/calendar_screen.dart:328-382`

**Issue:** `_resolved()` assigns `_held = list; _heldDay = widget.day;` and is
called from the collection-`switch` inside `build()`. Mutating `State` fields
during build is a Flutter anti-pattern; it works here only because nothing in
the same frame reads them and `_heldRows` is only reachable from a *different*
arm of the same switch. The correctness of the WR-01/WR-06 hold mechanism now
depends on the arm ordering of a `switch` two authors have already reordered.

**Fix:** move the capture out of build — e.g. `didUpdateWidget`:

```dart
@override
void didUpdateWidget(_DayBody old) {
  super.didUpdateWidget(old);
  final doses = widget.doses;
  if (doses is AsyncData && !doses.isLoading && !doses.hasError) {
    _held = doses.requireValue;
    _heldDay = widget.day;
  }
}
```

### WR-07: The "numerals are locale-formatted" rule is violated in the ring and unenforceable by its own gate

**Status:** FIXED in `5ab4a63` — the ring formats both counts through `NumberFormat.decimalPattern(locale)` built inside `build`, and the gate now also flags a BARE identifier interpolation (`$name` / `${name}`). To stay sharp it inspects only a `Text()`'s POSITIONAL arguments, so `key: ValueKey<String>('month-$index-label')` is not swept up, and a braced expression carrying a call or field access (`${fmt.format(x)}`, `${l10n.key}`) is deliberately not matched. Confirmed RED: the widened gate fails on `day_progress_ring.dart:72` and on nothing else in `lib/`. This also closes TW-3.

**Files:** `lib/features/calendar/day_progress_ring.dart:72`,
`test/l10n/no_hardcoded_strings_test.dart:644-665`

**Issue:** `DayProgressRing` renders `Text('$taken/$total')` — raw ASCII digits
with no `NumberFormat`. `planner_year_grid.dart:286` does the same job through
`NumberFormat.decimalPattern(locale).format(month.load)`, so the codebase
already disagrees with itself about its own rule. The gate that exists to
enforce this (`no Text() argument stringifies a value with .toString()`) matches
only the literal `.toString()` token, so `'$x'` interpolation — the far more
common way to write it — passes untouched. The rule is documented, violated,
and unenforced simultaneously.

**Fix:** format the counts (`NumberFormat.decimalPattern(locale)`), and widen
the gate's `toStringCallPattern` to also flag `$identifier` interpolation of
non-`String` locals inside a `Text(` argument (or at minimum add the ring's
counter to a named allowlist entry so the exception is visible).

### WR-08: One-regimen-per-supplement is enforced by two independent, unwritten conventions that must agree

**Status:** FIXED in `2129e09` — the rule is stated once in `regimensBySupplement()` and used by all three read paths, including `ensureLogsForDay`, which previously materialized doses for EVERY regimen. Deliberately a collapse rather than an `assert` or a partial unique index: a second row is exactly what the documented sync/import future delivers, and the app must stay coherent on data it did not write rather than crash on it (and a schema migration is out of scope for a review fix). Confirmed RED first.

**Files:** `lib/core/domain/repositories.dart:109-120`,
`lib/core/db/drift_repositories.dart:150-156`, `:283-296`

**Issue:** Three code paths answer "which regimen belongs to this supplement",
and they answer it three different ways:

- `combineStackEntries` builds `{for (final r in regimens.reversed) r.supplementId: r}` —
  last-write-wins over a *reversed* list, so the **first** regimen by
  `createdAt` wins. Nothing in the file says so; you have to reason about map
  literal duplicate-key semantics plus the reversal to see it.
- `findForSupplement` returns `regimens.first` — also first-by-`createdAt`,
  because `_joined()` orders that way.
- `ensureLogsForDay` iterates **all** regimens from `watchAll()` and
  materializes doses for every one of them.

The first two agree only by coincidence of a shared SQL sort. If a second
regimen row ever exists for one supplement (a sync merge, an import, a
`_seedWasBlind` failure mode that slips through), the Stack card and the editor
would show regimen A while the Today screen materializes doses for A **and** B
— double doses that no screen can explain and no test would catch.

**Fix:** state the rule in one place and enforce it there. Either add a
`UNIQUE(supplementId) WHERE deletedAt IS NULL` partial index to `Regimens`, or
give `ensureLogsForDay` the same "one regimen per supplement" collapse the other
two paths use, and replace the `regimens.reversed` idiom with an explicit
comment or a `putIfAbsent` over the forward list.

---

## Info

### IN-01: Dead production API on both repositories

`SupplementRepository.softDelete` (`drift_repositories.dart:62-67`) and
`RegimenRepository.softDelete` (`:220-225`) are never called from `lib/` —
production only ever uses `softDeleteCascade`. Both are covered by
`test/db/repositories_test.dart`, so the suite reports coverage on code no user
can reach. Either wire them or delete them; a soft-delete that bypasses the
cascade is exactly the kind of API a future phase reaches for by mistake.

### IN-02: `upsert` unconditionally resurrects soft-deleted rows

`DriftSupplementRepository.upsert:57` and `DriftRegimenRepository.upsert:175`,
`:195` all pass `deletedAt: const Value(null)`. Safe today because production
always mints a fresh UUID, but the documented sync/import future will call
`upsert` with *existing* ids, and this silently undeletes. Worth an explicit
`revive: false` parameter or a comment at the call site rather than in the
class doc.

### IN-03: Opening the editor on an out-of-grid regimen rewrites its schedule on Save

`_clampDays` (`regimen_editor_controller.dart:234-237`) snaps persisted
`onDays`/`offDays` onto a 7-day grid at *seed* time, so a regimen with
`onDays: 100` becomes `98` in the draft and is written back as `98` by a Save
the user made for an unrelated reason. Documented as "lossless for
editor-written rows", which is true — but the loss is silent for every other
writer.

### IN-04: The editor permits two slots at the same time of day

`addSlot` (`:285-298`) skips already-used default times, but `setSlotTime`
(`:308-313`) has no duplicate check. Two slots at 08:00 materialize two
identical doses every active day and make `_intervalText`
(`regimen_editor_screen.dart:186-195`) print a 0 h 0 min interval note. Cheap
fix: reject or merge a duplicate minute in `setSlotTime`.

### IN-05: `resolvedMonthIndexProvider` reads the clock instead of the model's own answer

`planner_providers.dart:175` falls back to `(ref.watch(todayProvider).month - 1).clamp(0, last)`
while its sibling `resolvedWeekIndexProvider:131` deliberately falls back to
`model.currentWeekIndex` — the "one derivation, one truth" rule WR-02
established. They agree today only because `buildYearModel` always renders
today's year. The rule was fixed for weeks and never carried to months.

### IN-06: Unencrypted health-adjacent data is deliberately included in OS backups

`database.dart:109-118` documents that the SQLite file must stay inside the
platform documents directory *and* must never be excluded from iCloud /
Android Auto Backup. That is a recorded decision (D-21/DATA-02), but it means a
user's full supplement and intake history leaves the device in cleartext. Worth
one explicit line in the first release's privacy copy rather than living only
in a source comment.

---

## Layered-fix damage

I traced every `CR-`/`WR-` reference in the source against what the code
actually does. The remediations held up better than expected — no fix silently
undid an earlier one, and I found no dead defensive branch. Three residues:

1. **A rule fixed in one file and not its sibling.** The week resolver was
   rewritten to read `model.currentWeekIndex` (WR-02, "one derivation, one
   truth"); the month resolver ten lines below still re-reads the clock
   (IN-05). Same for the numeral-formatting rule: fixed in
   `planner_year_grid.dart` via `NumberFormat`, never applied to
   `day_progress_ring.dart` (WR-07).

2. **A comment that outlived its proof.**
   `test/features/today_provider_test.dart:107-109` claims "the test completing
   is the proof that nothing stayed armed". It is not — see TW-1. This is the
   only comment I found that asserts something the code does not establish.

3. **A guard whose scope was narrowed by a later fix without the doc following.**
   `dose_row.dart`'s `_apply` is documented as "the ONE place in the app that
   writes a `DoseStatus`", and that is still true. But `_onLongPress` checks
   `_busy` *before* opening the sheet and `_apply` checks it again after — the
   second check happens after an arbitrarily long modal gap, during which
   `widget.dose` may describe a row the stream has since removed. `_apply`
   writes by `logId` to a row that may now be soft-deleted; `setStatus` will
   update a `deletedAt`-stamped row without complaint. Not user-visible (the
   row is hidden either way) and not worth a Warning, but the "guarded write
   path" documentation is stronger than the guard.

Two things I checked specifically for overlap damage and found **clean**:
- The three-layer error precedence (`stackEntriesProvider`'s explicit
  error→value→loading ordering, plus each screen's `AsyncValue(hasError: true)`
  first arm). `providers.dart:196-211` is correct, and
  `supplements.error!`/`stackTrace!` cannot NPE — Riverpod 3 stores both in one
  nullable record (`async_value.dart:125,607,610`), so `hasError` implies both.
- Drift's `where()` on a joined statement **ANDs** rather than replaces
  (`select_with_join.dart:351-357`), so `findForSupplement`'s second `..where`
  really does narrow to one supplement. Had it replaced, the editor would have
  overwritten arbitrary regimens.

---

## Test-suite weaknesses

The suite is large (568 tests, 1789 assertions, 18k lines) and mostly earns it —
the ARB parity, no-hardcoded-strings, planner-invariant and new-language gates
all defend their own validity first (`expect(sources, isNotEmpty)` plus a file
count plus a "does the glob still see `features/`" check), which is exactly the
right instinct. Specific holes:

**TW-1 — FIXED in `6cd1140`.** (Original finding below.)

**TW-1 — a test whose stated proof is not a proof.**
`test/features/today_provider_test.dart:91-110` is the only test of
`TodayController` and it asserts the initial value plus, per its comment, that
`container.dispose()` cancels the midnight timer. It does not: this is a plain
`test()` with no `fakeAsync`, and `flutter_test` only detects pending timers
inside `testWidgets`. Delete `ref.onDispose` from `today_controller.dart:43-48`
entirely and this test still passes. **The midnight rollover itself
(`_refresh`/`_schedule` re-arm) and the `AppLifecycleListener(onResume:)` path
have no test at all** — that is the single riskiest piece of date logic in the
app (DST, timezone change while backgrounded, resume after days) and it is
uncovered. Rewrite with `fakeAsync` and assert the state flips at
`nextLocalMidnight + 1s` and re-arms.

**TW-2 — FIXED in `d5c903e`.** (Original finding below.)

**TW-2 — the CR-01 blind spot.** No test edits a regimen in a way that *removes*
active days after materialization. `test/providers_calendar_test.dart:117` only
adds a slot; `:133` only re-upserts an identical regimen;
`test/db/materialization_boundaries_test.dart` seeds once and never edits;
`test/db/pause_filter_test.dart` covers only the pause axis. Every edit in the
suite is additive, which is precisely why CR-01 survived five phases.

**TW-3 — CLOSED by WR-07's widened gate (`5ab4a63`).** (Original finding below.)

**TW-3 — a gate that only catches the less common spelling.** The
"numerals reach the tree formatted" gate
(`test/l10n/no_hardcoded_strings_test.dart:644-665`) matches `.toString()` and
nothing else, so `Text('$taken/$total')` passes. Trivially satisfiable by
writing the violation the natural way.

**TW-4 — the source-scanning gates are brittle by construction.** Both
`no_hardcoded_strings_test.dart:521-532` and
`planner_invariants_test.dart:138-147` guard `stripComments`' line-only
stripping by asserting *no file in scope contains `/*` at all*. That is
self-consistent and honestly documented, but it means the day any file needs a
block comment (a `dartdoc` code sample, a generated header), the gates fail
rather than adapt — and the tempting fix under time pressure is to widen the
exclusion, which blinds them. Prefer parsing with `analyzer` or at least
teaching `stripComments` about block comments now.

**TW-5 — assertions are strong where it matters.** Worth recording the positive:
dose counts are asserted as exact numbers with reasons rather than
`greaterThan(0)`; `test/features/calendar_screen_test.dart:2130-2146` genuinely
pins the `_WeekWarmer`'s write scope to seven rows;
`test/features/planner_invariants_test.dart:526-562` pins the planner's zero
row-count invariant. The `isNotEmpty`/`isNotNull` hits I grepped are all
glob-validity guards or structural existence checks, not substitutes for real
assertions. I did not find a single `skip:`.

---

## What I looked for and did not find

Recorded so the absence is auditable rather than assumed:

- **Soft-delete completeness.** Every list/watch query filters `deletedAt IS NULL`:
  `watchAll` for supplements (`:35`) and regimens (`:138`), the slot left-join
  condition (`:135`), and all four filters in `watchDay` (`:339-341`). No query
  is missing one. No `delete(` statement exists anywhere in `lib/`.
- **Cascade scoping.** `softDeleteCascade` correctly restricts the log sweep to
  `date >= fromDay AND status == pending AND deletedAt IS NULL`, so taken/skipped
  history and past pending rows survive. `isIn([])` on an empty regimen list
  degrades to a false constant in Drift, not to "all rows".
- **Injection / traversal / secrets.** No raw SQL string building anywhere (all
  Drift builders); no `eval`, no `Process`, no file paths from user input; the
  only network-adjacent decision (`google_fonts`) was correctly rejected. The
  only SharedPreferences key is sanitized against an ARB-derived allowlist
  before use (`locale_controller.dart:54-68`), including the `get` vs
  `getString` type-confusion guard.
- **Startup crash paths.** `main()` cannot fail to call `runApp` — the
  SharedPreferences failure is caught and degrades to `null`, and
  `sharedPreferencesProvider` is nullable so the degraded value is
  representable rather than a second throw.
- **Index-out-of-range on the planner.** `model.weeks[model.currentWeekIndex]`,
  `model.months[model.peakIndex]`, `month.cells[i]` and
  `weeks[resolvedWeekIndexProvider]` are all provably in range:
  `weekBuckets` always yields ≥17 buckets, `months` is always exactly 12,
  `cells` is built one-per-entry in the same order, and both resolvers return
  either a found index or a model-derived fallback.
- **Timer / subscription leaks.** `TodayController` cancels its timer and
  disposes its lifecycle listener in `ref.onDispose`; `nowMinutesProvider` is
  autoDispose *and* gated by `TickerMode` (the gate is what actually tears it
  down under `IndexedStack`); `_WeekStripState` disposes its `PageController`;
  `_AddSupplementSheetState` disposes all three `TextEditingController`s.
  `_firstEvent` cancels its subscription on value, error and completion.
- **`BuildContext` across async gaps.** Every one is guarded —
  `dose_row.dart:89` resolves the messenger *before* the await,
  `add_supplement_sheet.dart` captures the `NavigatorState` before awaiting,
  and `regimen_editor_screen.dart` checks `context.mounted`/`dialogContext.mounted`
  at each of its four gaps.
- **Destructive-action confirmation.** The cascade is reachable from exactly one
  call site, inside the confirm handler of an `AlertDialog`, and a failed
  cascade pops `false` so the editor stays open.

---

_Reviewed: 2026-08-16_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: deep — whole codebase_
