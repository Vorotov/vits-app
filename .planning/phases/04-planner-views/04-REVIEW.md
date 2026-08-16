---
phase: 04-planner-views
reviewed: 2026-08-16T00:00:00Z
depth: standard
files_reviewed: 25
files_reviewed_list:
  - lib/core/domain/cycle_math.dart
  - lib/core/theme/tokens.dart
  - lib/core/l10n/arb/app_en.arb
  - lib/core/l10n/arb/app_uk.arb
  - lib/features/calendar/planner_view_model.dart
  - lib/features/calendar/planner_providers.dart
  - lib/features/calendar/planner_screen.dart
  - lib/features/calendar/planner_gantt.dart
  - lib/features/calendar/planner_load_chart.dart
  - lib/features/calendar/planner_week_detail.dart
  - lib/features/calendar/planner_year_grid.dart
  - lib/features/calendar/planner_month_detail.dart
  - lib/features/calendar/calendar_providers.dart
  - lib/features/calendar/calendar_screen.dart
  - lib/features/calendar/week_strip.dart
  - lib/features/stack/schedule_summary_text.dart
  - lib/features/stack/stack_status.dart
  - lib/features/stack/stack_screen.dart
  - test/domain/planner_window_test.dart
  - test/features/planner_view_model_test.dart
  - test/features/planner_invariants_test.dart
  - test/features/planner_screen_test.dart
  - test/providers_planner_test.dart
  - test/l10n/month_names_test.dart
  - test/l10n/planner_copy_safety_test.dart
findings:
  critical: 2
  warning: 6
  info: 7
  total: 15
status: issues_found
fixes:
  applied: 2026-08-16
  fixed: 8
  outstanding: 7
  scope: all Critical and Warning findings; the 7 Info findings are left
    documented and unfixed by request
  verification: flutter analyze clean; flutter test 547/547 pass (529 baseline
    + 18 new regression tests), run in the main checkout on main
---

# Phase 4: Code Review Report

**Reviewed:** 2026-08-16
**Depth:** standard
**Files Reviewed:** 25
**Status:** issues_found

## Summary

Baseline reproduced before review: `flutter analyze` → "No issues found", `flutter test` → 527/527 pass.

The transcription work is genuinely good. I traced every formula in `planner_view_model.dart` against 04-RESEARCH's verbatim mockup extracts and found them faithful: `segKind` (planned iff the run's first day is strictly after today, whole-segment, not split), the month cell's `plannedDays` rule (`segKind === 'planned' || a > TODAY`, where `a` is the *month start* — correctly implemented as `monthIsFuture || run.start.isAfter(t)`, not the more tempting per-run clipped start), `frac >= 0.85`, the 22 % bar floor (`max(round(frac*100)/100, 0.22)`), the `>=` / `>` verdict asymmetry between the week chip and the year peak chip, the `min(load,5)/5*38` bar heights, the 0.6×38 comfort line, and the peak tie-break toward the nearest month. Month lengths and the window span go through `DateTime.utc(y, m+1, 0).day` and real month boundaries everywhere — no table, no assumed 122, leap years handled by the calendar itself. The zero-write invariant holds under scrutiny: the only core providers reachable from the planner are `stackEntriesProvider` (a pure derivation over two `watchAll()` streams) and `todayProvider`; nothing transitively reaches `ensureLogsForDay`, and the invariant suite gates it both by grep and by row count. Phase 3's CR-01 (text scale) and WR-02 (semantics action on the excluded node) are both explicitly re-mitigated, and WR-06 has not regressed.

Two defects survive that. The first is a real, reproducible data bug at the window edges: the weekly concurrent-load buckets deliberately extend past the window (DECIDED-3) but the runs they are counted against do not, so the first and last bucket under-report — including, on the first days of a month, the "Цього тижня одночасно N речовин" chip that is this phase's headline number. The second is a control that promises recovery and cannot deliver it: the planner's error retry invalidates a *derived* provider, which in Riverpod never re-subscribes the stream that actually failed.

## Critical Issues

### CR-01: Week buckets count only the days inside the window, so the first and last bucket under-report their load

**Status: FIXED** — `d940743`. `buildCyclesModel` now derives a second, bucket-scoped run list for concurrency (`[buckets.first.start, buckets.last.endInclusive]`) while the painted gantt rows stay window-scoped, exactly as suggested. Four regression tests in `planner_view_model_test.dart` reproduce both cited cases (27 лип – 2 серп with a 27–31 July course; 30 лис – 6 груд with a 1–20 December course) and pin that a run wholly outside the window still paints nothing; both failed against the pre-fix code.

**File:** `lib/features/calendar/planner_view_model.dart:236` (with `285-297`, `244-253`)

**Issue:** `buildCyclesModel` scans each regimen's active runs over `[window.start, window.endExclusive - 1]` only:

```dart
final lastDay = window.endExclusive.subtract(const Duration(days: 1));
...
final runs = activeRuns(regimen, window.start, lastDay);
```

but `weekBuckets` deliberately produces **full Monday weeks**, so bucket 0 can start up to six days *before* the window and the last bucket can end up to six days *after* it (DECIDED-3, and the function's own doc comment says so). `weekLoads` then asks `row.runs.any(overlaps(bucket))` against runs that were never scanned over those extra days, so the extra days always contribute zero.

Reproduced (throwaway probe, since deleted), `today = 2026-08-02`, window `2026-08-01 .. 2026-12-01`:

- bucket 0 renders as **27 лип – 2 серп** and reports **load 0** for a course active 27–31 July (`isActiveOn` returns `true` for those days). Honest answer: 1.
- last bucket renders as **30 лис – 6 груд** and reports **load 0** for a course running 1–20 December, which genuinely overlaps six of that bucket's seven days.

This is not the accepted half of DECIDED-3. DECIDED-3 accepted that the *bounds* spill past the window and mandated "the axis labels show the **actual** bucket start/end dates" — which makes the load a claim about those actual dates. The implementation labels the bucket 27 лип – 2 серп and then answers a question about 1–2 серп only.

User-visible surfaces affected, all of them PLAN-01/PLAN-02 content: the load-chart bar height and colour for the first/last column, the week-detail card (range, `weekLoadLabel`, free-slot hint, pips, verdict chip, verdict note and the name chips — a supplement genuinely active that week is simply absent from the list), and the Цикли summary chip whenever today falls in the first calendar week of the month (today can never land in the last bucket, so that half is chart/detail-only).

No test covers a bucket's pre-window or post-window days; `planner_view_model_test.dart:271-364` only exercises buckets fully inside the window.

**Fix:** derive the runs over the *bucket* span, and keep the gantt's runs window-scoped so the painted geometry is unchanged. Note that simply widening `activeRuns` for everything is not safe: `ganttSegments` clamps to `0..1`, so a run lying entirely before the window collapses to `startFraction == endFraction == 0.0` and `_GanttRowPainter` still paints it at `_minSegmentWidth` (2 px) at the left edge — verified by probe.

```dart
// buildCyclesModel
final buckets = weekBuckets(window.start, window.endExclusive);
final scanFrom = buckets.isEmpty ? window.start : buckets.first.start;
final scanTo   = buckets.isEmpty ? lastDay     : buckets.last.endInclusive;

final rows = <GanttRow>[];
final loadRows = <GanttRow>[];
for (final entry in entries) {
  final regimen = entry.regimen;
  if (regimen == null) continue;
  // Painted geometry: window-scoped, exactly as today.
  final windowRuns = activeRuns(regimen, window.start, lastDay);
  rows.add(GanttRow(
    entry: entry,
    runs: windowRuns,
    segments: ganttSegments(windowRuns, window.start, window.span, today),
  ));
  // Concurrency: scoped to the buckets the chart actually labels (DECIDED-3).
  loadRows.add(GanttRow(
    entry: entry,
    runs: activeRuns(regimen, scanFrom, scanTo),
    segments: const [],
  ));
}
...
weeks: weekLoads(loadRows, buckets),
```

Add a regression test asserting that a regimen active only on the pre-window days of bucket 0 (and only on the post-window days of the last bucket) counts.

### CR-02: The planner's error retry cannot recover — it invalidates a derived provider, never the stream that failed

**Status: FIXED** — `146642a`. `retryStack(WidgetRef)` added to `core/providers.dart` and used by both the planner and the stack, so Interaction Contract 6 holds and the two screens cannot recover differently. The new widget test seeds the failure on the stream, taps retry and asserts the cards appear; it disables Riverpod 3's automatic provider retry so the recovery under test is the button's. (Noted while testing: Riverpod 3 reports a failed stream as loading-carrying-an-error while it retries on its own backoff, so in production the planner shows its blank loading surface during that interval and the designed error surface only after retries stop. Not in this finding's scope — worth a look in a later phase.)

**File:** `lib/features/calendar/planner_screen.dart:713`

**Issue:**

```dart
onPressed: () => ref.invalidate(stackEntriesProvider),
```

`stackEntriesProvider` is a plain `Provider` that *maps* `supplementsStreamProvider` and `regimensStreamProvider` (`lib/core/providers.dart:132-144`). It has no subscription of its own, and it can only ever be `AsyncError` because one of those two stream providers is. Riverpod invalidation propagates to **dependents**, never to dependencies: invalidating the derived provider re-runs its body, re-reads the two still-errored stream providers, and returns the same `AsyncError`. The error surface is therefore permanent for the life of the process — the button does nothing at all.

The correct, already-established pattern is one file away: `lib/features/stack/stack_screen.dart:143-144` invalidates the two *stream* providers, and `lib/features/calendar/calendar_screen.dart:361` invalidates `dayDosesProvider(day)` — the erroring `StreamProvider` itself. The planner is the only retry in the app that targets a derivation.

The test at `test/features/planner_screen_test.dart:622-648` asserts only that the button and its label are present; it never taps it and never asserts recovery, so the suite is green over a dead control.

**Fix:**

```dart
// lib/core/providers.dart — one named recovery path both screens can share.
void retryStack(WidgetRef ref) {
  ref.invalidate(supplementsStreamProvider);
  ref.invalidate(regimensStreamProvider);
}

// planner_screen.dart
onPressed: () => retryStack(ref),
```

Interaction Contract 6 constrains what the planner *reads*, not how it recovers; if naming the stream providers in a planner file is unacceptable, put `retryStack` in `core/providers.dart` and call that. Then extend the test: seed an error, tap retry, flip the override to data, and assert the cards appear.

## Warnings

### WR-01: A paused regimen is invisible to assistive technology on both segments

**Status: FIXED** — `7646e7e`. `GanttRow.paused` carries the state into the model; the gantt row speaks it instead of "0 періодів", and the Рік legend entry — the only place that segment names a paused supplement — carries the same clause. Both reuse the existing `legendPaused` word; two ARB keys added in BOTH locales (`ganttRowSemanticsPaused`, `yearLegendEntrySemantics`) and covered by the PLAN-04 gate.

**File:** `lib/features/calendar/planner_gantt.dart:406-410` (and `lib/features/calendar/planner_year_grid.dart:207-210`)

**Issue:** DECIDED-7 makes "a bare track" the design's statement that a row is paused, and the legend translates that into the word "пауза". Both are purely visual. The row's semantics label is

```dart
label: l10n.ganttRowSemantics(name, hint, l10n.periodsCount(row.runs.length)),
```

so a paused supplement announces its name, its schedule ("4 тижні / 4 тижні" — still rendered, `scheduleSummaryOf` keeps the summary for paused regimens) and "0 періодів". A screen-reader user gets a supplement with a schedule and zero periods and no way to distinguish "paused" from "off-cycle for the whole window" or "starts next year". The same applies to a month card, whose label is only `month + substancesCount`. Phase 3's WR-02 was exactly this class of defect (a state carried only by paint).

**Fix:** carry the pause state into the model row (`entry.regimen?.paused`) and append a clause:

```dart
label: row.paused
    ? l10n.ganttRowSemanticsPaused(name, hint)   // "…, пауза"
    : l10n.ganttRowSemantics(name, hint, l10n.periodsCount(row.runs.length)),
```

reusing the existing `legendPaused` word rather than minting new copy, so the PLAN-04 copy gate stays authoritative.

### WR-02: The summary chip re-derives "the bucket containing today" instead of reading it once

**Status: FIXED** — `7e00cd0`. `CyclesModel.currentWeekIndex` is the single derivation; the chip (now a `StatelessWidget` that reads no clock) and `resolvedWeekIndexProvider` both read it, and the dishonest `load = 0` fallback is gone.

**File:** `lib/features/calendar/planner_screen.dart:275-280` (duplicate of `lib/features/calendar/planner_providers.dart:113-117`)

**Issue:** two independent copies of the same search exist:

```dart
// planner_screen.dart — _CyclesSummaryChip
final index = model.weeks.indexWhere(
  (w) => !w.bucket.start.isAfter(today) && !w.bucket.endInclusive.isBefore(today));
final load = index < 0 ? 0 : model.weeks[index].load;

// planner_providers.dart — resolvedWeekIndexProvider
final index = model.weeks.indexWhere(
  (w) => !w.bucket.start.isAfter(today) && !w.bucket.endInclusive.isBefore(today));
return index < 0 ? 0 : index;
```

They can silently diverge — and CR-01's fix touches exactly this area. The chip's own fallback is also dishonest: `index < 0` yields `load = 0`, which renders "Цього тижня одночасно 0 речовин" with the calm palette rather than admitting it could not resolve the week. The provider's fallback (`index 0`) at least points at a real bucket.

**Fix:** compute the index once, in the pure model:

```dart
// CyclesModel
final int currentWeekIndex; // -1 is impossible: today is inside the window
```

and have both the chip and `resolvedWeekIndexProvider` read `model.currentWeekIndex`. The invariant "today is inside the window by construction" then has one place to be true, the same way `todayIndex` already does.

### WR-03: Week/month selections are bare list indices, so they silently retarget when the model regenerates

**Status: FIXED** — `3feb361`. Both selections now store identity (the bucket's Monday; the month's first day) and resolve by lookup, falling back to "follow today" when the pick is no longer in the model. Three provider tests drive a real window shift and a year rollover through a movable clock.

**File:** `lib/features/calendar/planner_providers.dart:80-95` and `121-136`

**Issue:** `SelectedWeekController` stores an `int` into a bucket list that is rebuilt from `todayProvider`. At a month rollover the window slides forward one month and the whole bucket list shifts by roughly four weeks; the clamp in `resolvedWeekIndexProvider` guarantees no range error, but index 7 now denotes a completely different week, and the week-detail card silently changes what it is describing without the user touching anything. `selectedMonthProvider` has the milder version of this on 1 January (index 11 becomes December of the *new* year).

The doc comment claims the `null`-means-follow idiom protects against exactly this — it does, but only for the unselected case; an explicit pick is precisely the state that drifts. The clamp comment ("a selection left over from a previous window … can never index out of bounds") addresses the crash, not the semantics.

**Fix:** store the identity, not the position — `DateTime?` holding the bucket's Monday for the week, `(int year, int month)?` or a `DateTime?` month start for the month — and resolve to an index by lookup, falling back to "follow today" when the stored value is no longer in the model. That also makes the selection survive a window shift correctly instead of merely legally.

### WR-04: The PLAN-04 copy gate enumerates its keys by hand, so new planner copy is silently unchecked

**Status: FIXED** — `064af4e`. The gate reads `app_en.arb` off disk, selects the planner surface through one prefix list, and fails both ways (an ARB key the map never renders; a map entry the filter no longer classifies as planner copy). Verified by inserting a throwaway planner key — the gate fails with the intended message. `substancesCount` and `weeksCount`, both planner-rendered and previously unscanned, are now sampled. The case-sensitivity handling is untouched.

**File:** `test/l10n/planner_copy_safety_test.dart:77-135`

**Issue:** `plannerCopy()` is a hand-written map of 40-odd keys. Its own docstring is the claim being violated: "a reviewer sees this commit once, this test sees every commit after it". A key added by phase 5 — a new week note, a new empty-state body — is not in the map and is therefore never scanned for forbidden vocabulary, with no failure to say so. This is the liability-bearing gate of the phase; the sibling gate in `planner_invariants_test.dart:82-94` deliberately globs files rather than listing them, for exactly this reason.

**Fix:** parse `lib/core/l10n/arb/app_en.arb` (as the invariants test already reads source files off disk), take every key matching the planner surface, and assert both that each one is present in the map and that its rendered value is clean:

```dart
final arbKeys = (jsonDecode(File('lib/core/l10n/arb/app_en.arb').readAsStringSync())
        as Map<String, dynamic>).keys
    .where((k) => !k.startsWith('@'))
    .where(isPlannerKey)          // one prefix list, one place to extend
    .toSet();
expect(arbKeys.difference(coveredKeys), isEmpty,
    reason: 'a planner key exists that the PLAN-04 gate never reads');
```

### WR-05: The uk copy bakes the value `5` into its grammar, contradicting the "one-line, test-caught edit" claim

**Status: FIXED** — `318749b`. Took the first option: both sentences now take the count pre-formatted through a plural key with all four uk CLDR forms — `slotsCount` (genitive, after «з») and `substancesLimitCount` (accusative, after «межі у …», which `substancesCount`'s nominative one-form cannot supply). At the shipped limit of 5 the rendered copy is byte-for-byte unchanged; `plurals_test.dart` pins the other values in both locales.

**File:** `lib/core/l10n/arb/app_uk.arb` (`weekLoadLabel`, `yearFootnote`) against `lib/features/calendar/planner_view_model.dart:351`

**Issue:** `editorialLimit`'s doc comment says "Both numbers live here once, so moving a boundary is a one-line, test-caught edit." That is false for Ukrainian. `weekLoadLabel` is `"{load} з {max} слотів"` and `yearFootnote` is `"…нашої межі у {max} речовин одночасно"`; both nouns are genitive-plural forms that agree with 5. Change the constant to 2, 3 or 4 and the app renders "2 з 2 слотів" / "межі у 3 речовин", which is ungrammatical — and no test fails, because every test passes 5.

**Fix:** either ICU-pluralize on the limit (`"{max, plural, one{{max} слот} few{{max} слоти} many{{max} слотів} other{{max} слота}}"`, composed into the sentence the way `plannerThisWeek` already composes `substancesCount`), or correct the comment to state that the constant is frozen by copy and add a test that pins it (`expect(editorialLimit, 5, reason: 'uk copy is declined for 5')`).

### WR-06: The hatch geometry is written twice, and the legend swatch must match the segments by hand

**Status: FIXED** — `60d0fea`. One `_paintHatch(canvas, rrect)` helper behind `_hatchStroke` / `_hatchPeriod`, two callers; the helper derives its span from the rrect's own bounds, so the geometry is identical to both originals. No dedicated test — the change is structural and unobservable except through paint; the existing render tests cover that the swatch and segments still draw.

**File:** `lib/features/calendar/planner_gantt.dart:354-373` and `502-519`

**Issue:** `_HatchSwatchPainter.paint` and the planned branch of `_GanttRowPainter.paint` contain the same ten lines — same `plannedHatchWeak` fill, same `strokeWidth = 4`, same `x += 8` step, same `(x, height) → (x + height, 0)` diagonal. The legend's whole job is to say "this ink means planned", so the two are a correctness pair, not just a duplication: change the stroke width in one and the legend starts describing something the chart no longer draws. The `4` and the `8` are also the only bare geometry numbers in a file where every other value (`_trackHeight`, `_rowGap`, `_swatchWidth`, …) is a named, mockup-cited constant.

**Fix:** one helper, two callers:

```dart
const double _hatchStroke = 4;      // mockup line 647: 4px on / 4px off
const double _hatchPeriod = _hatchStroke * 2;

void _paintHatch(Canvas canvas, RRect rrect) { … }
```

## Info

**Status: NOT FIXED — left documented by request.** All seven Info findings below stand as written; none was touched by the fix pass.

### IN-01: Model members that only tests read, and a doc comment that describes a call site that does not exist

**File:** `lib/features/calendar/planner_view_model.dart:164`, `:179`

**Issue:** `GanttRow.runCount` is documented as "spoken by the row's semantics label", but `planner_gantt.dart:409` passes `row.runs.length` directly; the getter's only callers are `planner_view_model_test.dart:212,695`. `CyclesModel.windowEndExclusive` is likewise read only by `planner_view_model_test.dart:218`.

**Fix:** use `runCount` at the semantics call site (making the doc true), or drop both members. A field that exists only to be asserted on encourages tests that pin the model rather than the behaviour.

### IN-02: `toUpperCase()` is documented as locale-aware; Dart's is not

**File:** `lib/features/calendar/planner_gantt.dart:154-155`, `lib/features/calendar/planner_month_detail.dart:116-120`

**Issue:** the comments read "Locale-aware uppercasing of intl output — never a hardcoded uppercase string (M6)". Only the second half is true: `String.toUpperCase()` in Dart applies the Unicode default casing, with no locale tailoring (Turkish dotless ı, Azerbaijani). Harmless for uk/en today, actively misleading if a third locale lands.

**Fix:** reword to "uppercasing of `intl` output rather than a hardcoded uppercase string — note `toUpperCase()` is not locale-tailored; revisit for tr/az".

### IN-03: Card chrome and geometry constants duplicated across the six planner files

**File:** `lib/features/calendar/planner_gantt.dart:33-35` / `planner_load_chart.dart:33-35`; `planner_screen.dart:57-68` / `planner_year_grid.dart:74`; five hand-built card `Container`s

**Issue:** `_cardPadTop / _cardPadHorizontal / _cardPadBottom` are declared with identical names *and* identical values (16/14/14) in two files. `_plannedAlpha = 0.30` is declared twice (`planner_screen.dart:68`, `planner_year_grid.dart:74`) — both transcriptions of the same `4D`. `_swatchRadius`, `_swatchHeight`, `_swatchLabelGap`, `_legendLabelSize`, `_legendTopMargin` exist in both `planner_screen.dart` and `planner_gantt.dart` with *different* values (7 vs 8, 11.5 vs 11, 14 vs 15), which is mockup-faithful but a genuine reading hazard. The `surface + cardBorder + BqRadii.panel` container is hand-built five times.

**Fix:** a `_PlannerCard({required Widget child, EdgeInsetsDirectional padding})` wrapper for the shared chrome, and promote the shared `4D` alpha to a single constant beside `fullMonthFraction` in the model (it is a design rule, not a per-file geometry).

### IN-04: Date ranges are composed in code with a hardcoded dash

**File:** `lib/features/calendar/planner_load_chart.dart:286-287`, `lib/features/calendar/planner_week_detail.dart:137-138`

**Issue:** `'${range.format(a)} – ${range.format(b)}'`. The week-detail file documents `" · "` as "a separator glyph, the sanctioned literal exception" but says nothing about the en dash, and the load chart documents neither. Under the project's "zero hardcoded user-visible strings" rule a range is a *pattern*, not punctuation, and concatenating one in code is the shape that breaks first under RTL (which CLAUDE.md lists as a standing constraint).

**Fix:** one ARB key, `"dateRange": "{start} – {end}"`, used by both call sites.

### IN-05: An extreme over-limit week is clipped without acknowledgement

**File:** `lib/features/calendar/planner_load_chart.dart:308-353`

**Issue:** the bar `Column` sits in a `PositionedDirectional(bottom: 0)` with no `top`, inside a `SizedBox(height: 46 + 7)`. At load 10 the bars total 38 + 38 = 76 px and are silently clipped by the `Stack`'s default `Clip.hardEdge`. The comment ("grows upward instead of throwing") is accurate about the exception but reads as though the growth is visible; past load ≈ 7 the over-bar simply stops getting taller, so two very different weeks look identical.

**Fix:** either clamp `overHeight` explicitly to the available headroom (so the truncation is intentional and testable) or state the cap in the comment. The verdict chip and the pip row already carry the exact number, so no information is lost — but the code should say so.

### IN-06: `~/ 7` in the shared schedule sentence now reaches a second surface

**File:** `lib/features/stack/schedule_summary_text.dart:49-50`

**Issue:** a cyclic regimen renders as `weeksCount(onDays ~/ 7) / weeksCount(offDays ~/ 7)`, so any regimen whose on/off days are not whole weeks reads "0 тижнів". Today only the editor writes regimens and its sliders are week-granular (`regimen_editor_controller.dart:218` clamps to 7..112), so this is latent rather than live — but the 04-02 extraction propagated it from one surface to two, and the planner's gantt row is now the second place it would show.

**Fix:** out of scope for this phase; when sub-week cycles become writable (import, sync, or a day-granular editor), the summary needs a days-vs-weeks branch. Worth a line in the backlog rather than a change here.

### IN-07: Both models are `autoDispose`, so a segment toggle re-scans a full year

**File:** `lib/features/calendar/planner_providers.dart:35-54`

**Issue:** `yearModelProvider` is watched only by the Рік body, which unmounts when the user switches to Цикли; being `autoDispose`, its cache is dropped and the next toggle re-runs `activeRuns` over 365 days × N regimens. `cyclesModelProvider` has the same property when the user leaves the planner. Correct, and cheap at realistic N (04-RESEARCH puts it near 10 000 integer ops), but the file's headline claim — "Riverpod's cache IS the memoization" — is only true within one visit to a segment.

**Fix:** performance is out of v1 review scope, so no change is required. If a large stack ever feels sluggish on the segment toggle, `ref.keepAlive()` guarded by a timer (or hoisting the two models to the screen with `ref.listen`, the idiom already used for the selections) is the smallest fix.

---

_Reviewed: 2026-08-16_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
