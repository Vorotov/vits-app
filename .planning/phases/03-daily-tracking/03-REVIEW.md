---
phase: 03-daily-tracking
reviewed: 2026-08-15T20:11:49Z
depth: standard
files_reviewed: 17
files_reviewed_list:
  - lib/core/today_controller.dart
  - lib/core/providers.dart
  - lib/core/db/drift_repositories.dart
  - lib/core/theme/tokens.dart
  - lib/core/l10n/arb/app_en.arb
  - lib/core/l10n/arb/app_uk.arb
  - lib/features/calendar/calendar_providers.dart
  - lib/features/calendar/calendar_screen.dart
  - lib/features/calendar/day_view_model.dart
  - lib/features/calendar/day_block_section.dart
  - lib/features/calendar/day_progress_ring.dart
  - lib/features/calendar/dose_row.dart
  - lib/features/calendar/dose_action_sheet.dart
  - lib/features/calendar/week_strip.dart
  - lib/features/stack/stack_screen.dart
  - lib/features/stack/regimen_editor_controller.dart
  - lib/app_shell.dart
findings:
  critical: 2
  warning: 8
  info: 10
  total: 20
status: issues_found
---

# Phase 3: Code Review Report

**Reviewed:** 2026-08-15T20:11:49Z
**Depth:** standard
**Files Reviewed:** 17
**Status:** issues_found

## Summary

Reviewed the Phase-3 daily-tracking delta: the midnight clock controller, the calendar
provider graph (`selectedDayProvider` / `resolvedDayProvider` / `nowMinutesProvider` /
`dayDosesProvider`), the pure day view-model, all five calendar widgets, the
`_firstEvent` repository helper, the token and ARB additions, and the `todayProvider`
adoption in the Stack tab. Baseline verified independently: `flutter analyze` clean,
`flutter test` 273/273 green.

**Invariants that hold (grep- and probe-verified, not taken on trust):**

- `ensureLogsForDay` and `watchDay` have exactly one production caller each —
  `dayDosesProvider` (`providers.dart:95-96`); `setStatus` has exactly one call site —
  `DoseRow._apply` (`dose_row.dart:93`). Nothing in `day_view_model.dart` or the strip
  can write a status; the missed path is read-only, and the raw-row test proves it.
- Midnight math uses the LOCAL date constructor and re-derives the day from the clock
  in the callback (PF-2 honored); `dateOnly()` normalization holds for every family key
  (week cells are `weekStart.add(Duration(days: i))` off a UTC date-only Monday).
- Ring/block/missed/overdue derivations are clockless pure functions with explicit
  `today`/`nowMinutes` parameters; `doseCyclePosition` derives `m` from the day list, not
  `regimen.slots` (PF-6 honored).
- Riverpod 3 pause semantics are handled in tests via explicit `container.listen`.
- **Security:** nothing to report. Offline app, no network, no secrets, no `eval`/shell
  in `lib/`, all Drift queries parameterized; the phase adds only enum status writes.

**What is actually broken.** Two proven defects rise above the noise. First, the Today
screen clips at accessibility text scales — I reproduced 7 × 9px vertical overflows at
`textScaler` 1.6 and 7 × 62px plus a 65px horizontal overflow at 2.0, against a code
comment that explicitly promises the opposite. There is zero text-scale coverage in the
whole suite (`grep -r textScaler test` → 0 hits), which is why it shipped. Second,
`watchDay` never filters soft-deleted `regimenSlots`, so a dose time the user removed in
the editor keeps rendering — and keeps accepting marks — in the calendar forever; I
confirmed this against the real repositories (2 doses before the slot removal, still 2
after). Both are reproducible, not theoretical.

The remaining warnings cluster around three seams: state held across a day switch that is
rendered with the *new* day's identity, `BuildContext` used after the action sheet's async
gap, and a documented `autoDispose` rationale that `IndexedStack` makes false.

## Critical Issues

### CR-01: Week strip clips its content at accessibility text scales — a fixed 82px height with a doc comment promising the opposite

**File:** `lib/features/calendar/week_strip.dart:55-61,123-124` (comment at `56-60`)
**Issue:** `_stripHeight` is a hard-coded `82` and the strip is wrapped in
`SizedBox(height: _stripHeight)`, giving the `PageView` a bounded cross-axis extent. The
cell content (9px pad + dow + 6 + number + 7 + dot + 10px pad) is text-scale dependent, so
the box is only big enough at scale 1.0. Reproduced against the real screen:

| textScaler | result |
|---|---|
| 1.0 | clean |
| 1.6 | `A RenderFlex overflowed by 9.0 pixels on the bottom.` × 7 (one per cell) |
| 2.0 | `A RenderFlex overflowed by 62 pixels on the bottom.` × 7 |

1.6 is inside the normal iOS "Larger Text" and Android font-size ranges — this is not an
exotic setting. In debug the screen paints overflow stripes across the strip; in release
the day numbers and dots are silently clipped. The class doc at lines 56-60 asserts
"cells size to their own content inside it … so a larger text scale grows the cell into the
slack rather than overflowing it" — that claim is false as written, which is worse than no
comment, and it is why no test was written for it.

This also violates the locked i18n/a11y rule in CLAUDE.md ("no fixed-width text
containers"): the vertical axis is the same failure mode.

**Fix:** Stop hard-coding the extent — let it follow the text scale, and add the missing
coverage.

```dart
// week_strip.dart — scale the reserved extent with the text scaler:
@override
Widget build(BuildContext context) {
  final today = ref.watch(todayProvider);
  final resolved = ref.watch(resolvedDayProvider);
  ref.listen<DateTime>(resolvedDayProvider, (_, next) => _syncPageTo(next, today));

  // 82 is the scale-1.0 design height; the text-bearing part of the cell
  // (dow 10 + number 14 + the two gaps) is what grows.
  final scaler = MediaQuery.textScalerOf(context);
  final height = 82 - 30 + scaler.scale(30);

  return SizedBox(height: height, child: PageView.builder(...));
}
```

And add a regression test that pumps `CalendarScreen` under
`MediaQuery(data: ...copyWith(textScaler: const TextScaler.linear(2.0)))` and asserts
`tester.takeException()` is null (see IN-08 — the suite has no text-scale test at all).

### CR-02: `watchDay` renders doses for soft-deleted slots — a dose time the user deleted keeps appearing in the calendar and stays markable

**File:** `lib/core/db/drift_repositories.dart:313-338` (the `where` clause at `331-338`)
**Issue:** The day query inner-joins `regimenSlots` but filters `deletedAt` on
`intakeLogs`, `regimens` and `supplements` **only** — never on `regimenSlots`. Slot removal
in the regimen editor is a soft delete (`drift_repositories.dart:200-208` stamps
`deletedAt` on slots no longer in the incoming set), so every already-materialized
`IntakeLog` for that slot keeps satisfying the join.

Verified against the real repositories (temporary probe, since removed):

```
PROBE before slot delete: 2 doses
PROBE after slot delete:  2 doses [sl1, sl2]      // sl2 was removed in the editor
```

User-visible consequence: the user opens the editor, deletes the 20:00 slot, saves — and
today's calendar still shows a 20:00 dose, still counts it in the ring denominator, still
counts it toward the block's `X з Y` warn tag, and still lets them mark it taken. There is
no UI path to get rid of it. `ensureLogsForDay` correctly stops creating *new* rows (it
iterates `regimens.watchAll()`, which excludes deleted slots), so the day the slot is
removed is exactly the day that breaks — and every past day the user browses.

The Phase-2 review did not catch this because Phase 2 had no consumer of `watchDay`;
Phase 3 is the first phase where the gap is visible, and this phase's own `DoseRow` is what
makes the phantom dose writable.

**Fix:** Mirror the pause rule — hide the *pending* dose of a removed slot while keeping
its recorded history, so nothing already logged disappears:

```dart
..where(db.intakeLogs.date.equals(utcDay) &
    db.intakeLogs.deletedAt.isNull() &
    db.regimens.deletedAt.isNull() &
    db.supplements.deletedAt.isNull() &
    // NEW: a removed slot's future/pending doses vanish; taken/skipped history stays.
    (db.regimenSlots.deletedAt.isNull() |
        db.intakeLogs.status.equalsValue(domain.DoseStatus.pending).not()) &
    (db.regimens.paused.equals(false) |
        db.intakeLogs.status.equalsValue(domain.DoseStatus.pending).not()))
```

Add a repo test alongside `pause_filter_test.dart`: materialize two slots, remove one via
`regimenRepo.upsert`, assert `watchDay` yields one pending dose and that a previously
`taken` dose on the removed slot survives.

## Warnings

### WR-01: The held dose list is rendered with the *new* day's identity — a tap in that window writes to the wrong day, and a past-day row can flash warn styling

**File:** `lib/features/calendar/calendar_screen.dart:207,230-241,297-307`
**Issue:** `_held` caches the last resolved list (PF-7 anti-flicker, good), but the
loading branch renders it through `_blocks(_held!, viewingToday: viewingToday)` and
`_blocks` passes `day: widget.day` — the **new** day — plus the new `viewingToday`.
`DayBlockSection` then hands those to `DoseRow`, which uses them for `isMissed`
(`viewedDay`), `isOverdue` (`viewingToday`) and, critically, still carries the *old* day's
`dose.logId`. Two consequences:

1. A tap landing in the hold window calls `setStatus(<yesterday's logId>, taken)` while the
   header, ring and strip all show the newly selected day. The user marks a dose on a day
   they are no longer looking at, with no feedback that anything went to the wrong day.
2. Switching *from* a past day *to* today renders the held past rows with
   `viewingToday: true`, so past-day doses momentarily get the amber `warnBorder` and the
   "не прийнято вчасно" chip — the exact treatment TRACK-03 forbids off today.

The existing PF-7 test (`calendar_screen_test.dart:2257`) asserts only that the rows are
still on screen; it never taps during the hold window or checks their styling.

**Fix:** Hold the day alongside the list and render the held rows with the day they
actually belong to:

```dart
List<DayDose>? _held;
DateTime? _heldDay;              // NEW

// data branch:
data: (list) { _held = list; _heldDay = widget.day; return _blocks(list, widget.day, ...); }
// loading branch: render with _heldDay, not widget.day
loading: () => _held == null
    ? const <Widget>[]
    : _blocks(_held!, _heldDay!, viewingToday: _heldDay == today),
```

(Or, more conservatively, pass `absorbing: true` on the held frame so no gesture can reach
a stale row.)

### WR-02: Week-strip cells announce as buttons but expose no tap action to screen readers

**File:** `lib/features/calendar/week_strip.dart:202-219` (the `excludeSemantics: true` at `207`)
**Issue:** The cell wraps its `GestureDetector` in
`Semantics(button: true, selected: …, label: …, excludeSemantics: true)`.
`excludeSemantics: true` drops **all** descendant semantics, including the
`GestureDetector`'s `SemanticsAction.tap`. The node therefore advertises itself as a
button and gives a full localized date, but has no activation action for VoiceOver /
TalkBack to invoke. Verified with a semantics probe against the real screen:

```
PROBE week cell: label="вівторок, 11 серпня 2026 р." tap=false
PROBE dose row:  tap=true longPress=true custom=true
```

`DoseRow` gets this right (it does not exclude descendants, so its gesture actions merge
through) — the strip is the inconsistent one. The existing coverage
(`calendar_screen_test.dart:2042`) taps with `tester.tapAt` (a physical hit test), so it
cannot catch this. Day browsing is TRACK-03's primary affordance; it is currently
unreachable by assistive technology.

**Fix:** Move the tap onto the `Semantics` node itself so it survives the exclusion:

```dart
void select() {
  final selection = ref.read(selectedDayProvider.notifier);
  isToday ? selection.followToday() : selection.select(day);
}

Semantics(
  button: true,
  selected: isSelected,
  label: DateFormat.yMMMMEEEEd(locale).format(day),
  excludeSemantics: true,
  onTap: select,                       // NEW
  child: GestureDetector(onTap: select, ...),
)
```

Assert it: `expect(tester.getSemantics(cell(pastDay)).getSemanticsData().hasAction(SemanticsAction.tap), isTrue)`.

### WR-03: `DoseRow._apply` touches `BuildContext` after an async gap on the long-press path

**File:** `lib/features/calendar/dose_row.dart:86-101,116-121`
**Issue:** `_apply` resolves `ScaffoldMessenger.of(context)` and `context.l10n` as its
first two statements, which is correct for the tap path (no gap yet). The long-press path
is different: `_onLongPress` awaits `showDoseActionSheet(...)` — an arbitrarily long gap,
because the sheet stays open until the user chooses — and only then calls `_apply(chosen)`,
which reads `context` from a `State` that may no longer be mounted. The day stream can
remove the row underneath the open sheet (a background regimen edit or pause emission, a
midnight rollover, or `backToToday` fired from an accessibility action), leaving
`_apply`'s `ScaffoldMessenger.of(context)` to throw
"Looking up a deactivated widget's ancestor is unsafe."

`_apply` also calls `messenger.showSnackBar` in its `catch` with no `mounted` check on the
messenger's own state.

**Fix:**

```dart
Future<void> _onLongPress() async {
  if (_busy) return;
  final chosen = await showDoseActionSheet(context, widget.dose);
  if (chosen == null || !mounted) return;   // NEW: mounted check
  await _apply(chosen);
}
```

### WR-04: Block header overflows horizontally at large text scales — three non-flexible children

**File:** `lib/features/calendar/day_block_section.dart:86-120`
**Issue:** The header `Row` puts the mono time, the block label and `_BlockTagChip` in as
**non-flexible** children, with only the 1px divider wrapped in `Expanded`. `Expanded`
protects the divider, not the row: once the three text children plus the 30px of fixed gaps
exceed the available width, the `Row` overflows. Reproduced on the real screen at
`textScaler` 2.0: `A RenderFlex overflowed by 65 pixels on the right.` (390pt surface,
40pt of screen padding → 350pt available; "08:00" + "Ранок" + "зі сніданком" at 2× exceed it).

The file's doc comment says "the divider … is the flexible element, so a long label or a
long tag can never overflow the header row" — that is only true for long *text at scale
1.0*, not for scaled text.

**Fix:** Make the label and the tag shrinkable, not just the divider:

```dart
Flexible(child: Text(label, overflow: TextOverflow.ellipsis, style: ...)),
const SizedBox(width: 10),
const Expanded(child: SizedBox(height: 1, child: ColoredBox(color: BqColors.cardBorder))),
const SizedBox(width: 10),
Flexible(child: _BlockTagChip(...)),
```

### WR-05: The `autoDispose` rationale documented for the minute ticker and the day family is false under `IndexedStack`

**File:** `lib/features/calendar/calendar_providers.dart:53-58`; `lib/core/providers.dart:75-77`; `lib/app_shell.dart:38-45`
**Issue:** `nowMinutesProvider`'s doc claims the periodic subscription "exists only while
the Calendar tab is watched and is cancelled the moment it is not, so the app never keeps a
timer alive for a screen nobody is looking at." The shell is an `IndexedStack`
(`app_shell.dart:38`), which **builds and keeps every child mounted**; only painting is
suppressed. `CalendarScreen` is therefore alive from app launch, on every tab, forever.
Consequences:

- The 1-minute `Stream.periodic` ticker starts at launch and never stops, rebuilding the
  whole day list every minute while the user sits on the Stack or Settings tab.
- The week strip's 7 `dayDosesProvider` watches run at launch, so the app materializes the
  whole visible week (7 `ensureLogsForDay` writes + 7 live Drift day queries) before the
  user has ever opened the calendar. The comment "generated ahead for the near horizon" is
  the design intent, but the trigger is not what the code claims it is.
- `selectedDayProvider` / `resolvedDayProvider` are `autoDispose` but never actually
  dispose, so their "screen-scoped" contract is unenforced.

Nothing is *incorrect* here, but three doc comments describe a lifecycle the app does not
have, which is exactly how the next reader gets a wrong mental model.

**Fix:** Either make the claims true (`TickerMode`/`Visibility`-gated calendar, or swap the
`IndexedStack` for lazy tab construction) or correct all three comments to state that the
calendar is app-lifetime under the current shell and that the ticker runs continuously.
The cheapest honest fix is to gate the ticker on visibility:

```dart
// app_shell.dart — stop the periodic clock for offstage tabs
IndexedStack(index: _selectedIndex, children: [...])  // -> wrap children in
// TickerMode(enabled: _selectedIndex == i, child: ...) and have the calendar
// pause nowMinutesProvider when not enabled.
```

### WR-06: Swiping the week pager materializes up to ~371 days of `IntakeLog` rows to colour a 4px dot

**File:** `lib/features/calendar/week_strip.dart:53,125-134,268-292`
**Issue:** Every `_HandledDot` watches `dayDosesProvider(day)` — which is the app's
materialization choke point — purely to decide one of two dot colours. Each page the pager
builds therefore fires **7 concurrent `ensureLogsForDay` writes** (each opening its own
`regimens.watchAll()` query stream via `_firstEvent`, plus a batched insert transaction
that then invalidates every live `watchDay` stream). With `weekPageCount = 53`, swiping to
the back of the pager materializes up to 371 days × slots of rows, permanently, for a
cosmetic dot the user may never have looked at.

`ensureLogsForDay` is idempotent so this is not corrupting, and per-swipe cost is bounded —
but the *write* is unbounded in the sense that the DB grows with pager travel, not with
user intent. The dot has no data behind it for days that were never materialized before,
which means the feature is self-justifying: it creates the data it then reports on.

**Fix:** Read the dot from a cheap aggregate that does not write, e.g. one `watch` over the
week's `intakeLogs` (`date BETWEEN weekStart AND weekEnd`, grouped by date) instead of 7
full materialize-then-watch family instances; keep `dayDosesProvider` for the *selected*
day only. If pre-materializing the visible week is wanted, do it once for the current week
rather than for every page the pager passes through.

### WR-07: `doseSheetSubtitle` renders a dangling separator when the slot has no dose label

**File:** `lib/features/calendar/dose_action_sheet.dart:85-92`; `lib/core/l10n/arb/app_uk.arb` / `app_en.arb` (`"doseSheetSubtitle": "{time} · {dose}"`)
**Issue:** `dose.slot.doseLabel` is optional and frequently empty (the Phase-2 editor
allows it, and half of this phase's own test fixtures use `doseLabel: ''`). The sheet
interpolates it unconditionally, producing `08:00 · ` with a trailing middle dot and a
trailing space. `DoseRow` guards exactly this case (`dose_row.dart:308`,
`if (dose.slot.doseLabel.isNotEmpty)`), so the two surfaces disagree.

**Fix:** Add a second ARB key for the label-less case and branch on it:

```dart
Text(
  dose.slot.doseLabel.isEmpty
      ? l10n.doseSheetSubtitleTimeOnly(time)
      : l10n.doseSheetSubtitle(time, dose.slot.doseLabel),
  ...
)
```

### WR-08: The working tree carries an uncommitted dependency change and a throwaway probe with a hardcoded simulator UDID

**File:** `pubspec.yaml` (+6 lines, adds the `integration_test` dev dependency),
`pubspec.lock` (+39), untracked `integration_test/_probe_test.dart`
**Issue:** The phase's committed state does not match the working tree. `pubspec.yaml` and
`pubspec.lock` are modified but uncommitted, so a clean clone / CI runner resolves a
different dependency set than the machine this phase was verified on. The untracked
`integration_test/_probe_test.dart` is a throwaway with three problems if it is ever
committed as-is: it shells out with `Process.run('xcrun', ['simctl', …])` from inside a
test, it hardcodes one machine's simulator UDID
(`FA55ED0D-2F18-4153-BCA5-8AE96B1E637E`), and it hardcodes an absolute
`/private/tmp/claude-501/...` scratchpad path.

**Fix:** Commit the `integration_test` dev dependency deliberately (it is a legitimate
DATA-03 harness and CLAUDE.md already reserves it) with the lock file in the same commit,
and delete `integration_test/_probe_test.dart` — or replace it with a real smoke test that
takes the device id from `--dart-define`/env and writes nothing outside the test's own
temp dir.

## Info

### IN-01: `DoseRow` has no key, so `_busy` / `_pressed` follow list position rather than the dose

**File:** `lib/features/calendar/day_block_section.dart:123-133`
**Issue:** Rows are built positionally with no `key`. When the day list changes shape
(a pause filters a pending dose out, a slot is added), Flutter reuses each `_DoseRowState`
for whatever dose now occupies that index — carrying the in-flight `_busy` guard and the
`_pressed` border across to a different dose. Transient (the `finally` clears it), but the
guard is a correctness mechanism and it should be bound to the dose it guards.
**Fix:** `DoseRow(key: ValueKey(dose.logId), ...)`.

### IN-02: All seven status dots share one `const ValueKey('week-dot')`

**File:** `lib/features/calendar/week_strip.dart:301`
**Issue:** Legal (different parents), but `find.byKey(const ValueKey('week-dot'))` matches
7 widgets, so every dot assertion must be wrapped in `find.descendant`. A key that does not
identify anything is a trap for the next test author.
**Fix:** `ValueKey('week-dot-$day')`, or drop the key and find the dot by its position in
the cell.

### IN-03: `_firstEvent` cancels un-awaited on every materialization, and would throw on a synchronous stream

**File:** `lib/core/db/drift_repositories.dart:367-400`
**Issue:** Two smells in an otherwise well-justified helper. (a) `sub` is
`late StreamSubscription<T>` assigned from `stream.listen(...)`; if a stream ever emitted
synchronously during `listen` (a sync `StreamController`, a test double), the `onData`
handler would hit `sub.cancel()` before the assignment and throw
`LateInitializationError`. Drift's streams are async, so this is latent, not live.
(b) The un-awaited cancel means every `ensureLogsForDay` leaves a regimens query
subscription closing in the background — with 8 concurrent day providers on calendar open
(WR-06) that is 8 per materialization pass.
**Fix:** Hoist the guard —
`StreamSubscription<T>? sub; sub = stream.listen(...); unawaited(sub?.cancel());` — and add
a one-line comment that the un-awaited cancel is accepted because the subscription is
single-use.

### IN-04: The `TodayController` timer test asserts nothing about the timer, and is midnight-flaky

**File:** `test/features/today_provider_test.dart:90-111`
**Issue:** The comment says "the test completing is the proof that nothing stayed armed",
but this is a plain `test()`, not `testWidgets` — there is no pending-timer check to fail,
so the disposal claim is unverified. Separately,
`expect(today, dateOnly(DateTime.now()))` compares two independent clock reads and fails if
the suite happens to straddle local midnight.
**Fix:** Use `fakeAsync` (or `testWidgets` + `tester.binding`) to assert the timer is gone
after `container.dispose()`, and compare against a single captured `DateTime.now()`.

### IN-05: The ring blinks out on a day switch while the body deliberately holds its list

**File:** `lib/features/calendar/calendar_screen.dart:106-112` vs `239-241`
**Issue:** `_DayBody` holds the previous list through `AsyncLoading` (PF-7), but `_Header`
maps any non-`AsyncData` state to `counts == null` and omits the ring entirely. The result
is inconsistent: rows persist while the ring disappears and reappears one frame later.
**Fix:** Give the header the same hold treatment, or accept the flash and drop the hold in
the body — but pick one policy.

### IN-06: `_nowMinutes` starts at 0, so the first frame treats every dose as not-yet-due

**File:** `lib/features/calendar/calendar_screen.dart:198,212-216`
**Issue:** Until `nowMinutesProvider` delivers its first value (one microtask), the body
renders with `nowMinutes == 0`: no dose is overdue and the earliest block is "current".
Sub-frame in practice, but the initial value is a lie rather than an absence.
**Fix:** Make `_nowMinutes` nullable and skip the overdue/current-block treatments until it
resolves, so the first frame is neutral rather than wrong.

### IN-07: `todayProvider` is watched three times per frame across three widgets

**File:** `lib/features/calendar/calendar_screen.dart:95,217`; `lib/features/calendar/day_block_section.dart:62`; `lib/features/calendar/week_strip.dart:117`
**Issue:** `_Header`, `_DayBody`, every `DayBlockSection` and `WeekStrip` each
`ref.watch(todayProvider)` independently and re-derive `viewingToday`. It is cheap and
correct, but the same value is threaded through constructor parameters *and* re-read from
the graph in the same subtree — `DayBlockSection` receives `viewingToday` as a parameter and
then watches `todayProvider` anyway for `today`.
**Fix:** Pass `today` down alongside `viewingToday` (it is already computed one level up)
so a block section is a pure function of its inputs.

### IN-08: The suite has zero text-scaling coverage — which is how CR-01 and WR-04 shipped

**File:** `test/` (whole tree)
**Issue:** `grep -rn "textScaler\|textScale" test lib` returns nothing. Every widget test
pumps at scale 1.0 on a 390×844 surface. Both layout defects in this review reproduce with
a one-line `MediaQuery` wrapper.
**Fix:** Add a small scale group to `calendar_screen_test.dart` that pumps the screen at
1.0 / 1.6 / 2.0 and asserts `tester.takeException()` is null, and give the Stack tab the
same treatment while you are there.

### IN-09: `_blockHasPassed` and `blockTagOf` disagree about the empty-block case

**File:** `lib/features/calendar/day_view_model.dart:176,201,208-209`
**Issue:** `blockTagOf` explicitly guards `if (doses.isEmpty) return const MealTag();`,
while `currentBlockIndex` calls `_blockHasPassed` on the same block with no such guard —
and `every` on an empty list returns `true`, so an empty block would silently read as
"passed". `groupIntoBlocks` never emits an empty block, so both are unreachable; the
inconsistency is a signal that the impossible state was reasoned about twice with two
answers.
**Fix:** Drop the redundant `isEmpty` guard in `blockTagOf` and add
`assert(block.doses.isNotEmpty)` to `_blockHasPassed`, so the invariant is stated once.

### IN-10: The pager does not re-sync when `today` crosses a week boundary under a held selection

**File:** `lib/features/calendar/week_strip.dart:103-121`
**Issue:** `_syncPageTo` runs only from `ref.listen(resolvedDayProvider, ...)`. If the user
holds an explicit past-day selection and the app sits open across a midnight that is also a
Monday, `today` changes (so every page's `weekStartForPage` shifts back one week) while
`resolvedDayProvider` does not — leaving the controller on a page index that now renders a
different week, with no highlighted cell.
**Fix:** Also listen to `todayProvider` and re-run `_syncPageTo(resolved, next)`.

---

_Reviewed: 2026-08-15T20:11:49Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
