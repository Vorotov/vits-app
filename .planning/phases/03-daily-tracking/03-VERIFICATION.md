---
phase: 03-daily-tracking
verified: 2026-08-15T20:07:02Z
status: passed
score: 38/43 must-haves verified
behavior_unverified: 1
overrides_applied: 0
behavior_unverified_items:
  - truth: "todayProvider is the one place the app reads the calendar clock: it self-updates at the next LOCAL midnight (computed with the local date constructor, never a fixed 24-hour duration) and re-derives on app resume (PF-2)"
    test: "Run the app past local midnight with it open, then background it across a midnight boundary and resume"
    expected: "The Today view moves to the new day (header date + week strip + Stack tab statuses all follow) with no stale header date; yesterday's unmarked doses render as `не позначено` when browsed"
    why_human: "nextLocalMidnight()'s arithmetic is pinned by 4 unit tests and disposal cancels the timer, but no test fires the Timer or drives AppLifecycleListener.onResume — the state transition itself (Timer -> _refresh -> state = new day) is present and wired but never exercised"
human_verification:
  - test: "DATA-03 — walk the full plan->see->mark loop on an iOS simulator/device AND an Android emulator/device: add a supplement, configure a cyclic regimen, open Calendar, see the dose, tap it taken, tap it back to pending"
    expected: "The loop completes on both platforms at targetSdk 36. `flutter build apk --debug` and `flutter build ios --simulator --no-codesign` both succeed."
    why_human: "Requires simulator/emulator control. targetSdk = 36 is confirmed in android/app/build.gradle.kts:23, but the two build gates and the device walkthrough were NOT independently executed by this verifier — 03-05-SUMMARY.md records the runtime half as PENDING and does not claim it. Orchestrator is executing this half separately."
  - test: "Midnight rollover — leave the app open across local midnight (or change the device clock past it), and separately background it across midnight and resume"
    expected: "Today view advances to the new day with no stale header date; browsing yesterday shows its unmarked doses as `не позначено`; the Stack tab's card statuses advance with it"
    why_human: "Declared `verification: backstop` in 03-01-PLAN.md; also the behavior-unverified item above. Timer firing and app-resume are not reachable from flutter_test."
  - test: "On a simulator at 390pt width in uk, render one dose row carrying a longest-case name (\"Вітамін B12 метилкобаламін\", \"Хондропротектор\") plus a `доза 3 з 3` chip, a user note chip and the `не прийнято вчасно` chip"
    expected: "Nothing clips or overflows; the name wraps and the chips break to a new line"
    why_human: "Declared `verification: backstop` in 03-04-PLAN.md — visual judgment. An automated proxy exists and passes (test: \"dose row uk: the longest realistic uk name plus three chips does not overflow a 390pt row\"), but it asserts absence of overflow errors, not visual acceptability."
  - test: "Open the Calendar tab on a 667pt-class device (iPhone SE) in both uk and en"
    expected: "Header, ring and week strip remain fully visible with the block list scrolling beneath them"
    why_human: "Declared `verification: backstop` in 03-05-PLAN.md — layout-at-size visual judgment; widget tests run at a fixed surface size."
---

# Phase 3: Daily Tracking Verification Report

**Phase Goal:** A user can see exactly what to take today (and browse recent days) and mark each dose taken or skipped with one tap — the daily loop that is Boostque's core value — running correctly end-to-end on both platforms.
**Verified:** 2026-08-15T20:07:02Z
**Status:** passed — all 4 human-verification items confirmed in 03-UAT.md (DATA-03 automated on both platforms; backstops accepted on combined structural + on-device evidence)
**Re-verification:** No — initial verification

## Independent Re-run Evidence

All commands below were executed by this verifier in its own process, not read from SUMMARY.md.

| Command | Result |
|---------|--------|
| `flutter analyze` | `No issues found! (ran in 2.0s)` — exit 0 |
| `flutter test` (full suite, run once) | `00:05 +273: All tests passed!` — exit 0, 273/273 |
| `flutter gen-l10n` | exit 0; `git status --porcelain lib/core/l10n/` → **empty** (committed generated code matches the ARB) |

### VALIDATION.md per-task commands (all re-run)

| Task IDs | Command | Result |
|----------|---------|--------|
| 03-01/T1, 03-03/T2-T3, 03-04/T1-T3, 03-05/T1-T2 | `flutter test test/features/calendar_screen_test.dart` | +54 All tests passed |
| 03-01/T2 | `flutter test test/features/today_provider_test.dart test/providers_calendar_test.dart` | +10 All tests passed |
| 03-01/T3 | `flutter test test/features/stack_screen_test.dart` | +11 All tests passed |
| 03-02/T1 | `flutter test test/features/day_view_model_test.dart` | +32 All tests passed |
| 03-02/T2 | `flutter test test/db/materialization_boundaries_test.dart` | +6 All tests passed |
| 03-03/T1 | `flutter gen-l10n && flutter test test/l10n/plurals_test.dart test/theme/theme_test.dart` | +41 All tests passed |
| 03-05/T3 | `flutter build apk --debug` / `flutter build ios --simulator --no-codesign` | **NOT RUN** — folded into the DATA-03 human item |

### Phase invariant greps (re-run)

| Invariant | Command | Result |
|-----------|---------|--------|
| Single `setStatus` UI call site | `grep -rn "setStatus" lib/` | 1 UI call site: `lib/features/calendar/dose_row.dart:93`. Others are the interface decl (`domain/repositories.dart:100`), the Drift impl (`db/drift_repositories.dart:303`) and a doc comment. ✓ |
| `DateTime.now` confined under `lib/features/` | `grep -rn "DateTime\.now" lib/features/` | Exactly 1 file, 1 site: `calendar_providers.dart:72` (`_minuteOfDay()`, the sanctioned minute ticker). ✓ |
| Calendar-date clock centralized | `grep -rn "DateTime\.now" lib/` | Date reads only in `core/today_controller.dart` (3) + `db/drift_repositories.dart` (persistence `updatedAt`, `.toUtc()`). No per-build date read in any screen. ✓ |
| Single materialization choke point | `grep -rn "ensureLogsForDay\|watchDay" lib/` | Sole production caller/consumer: `lib/core/providers.dart:95-96`. ✓ |
| No raw color literals in the calendar feature | `grep -rn "Color(0x" lib/features/calendar/` | NONE ✓ |
| No hardcoded user-visible strings | `grep -rn "Text('\|Text(\"" lib/features/calendar/` (excluding `l10n.`) | NONE ✓ |
| Debt markers in phase files | `grep -rn -E "TBD\|FIXME\|XXX\|HACK\|PLACEHOLDER\|TODO"` over `lib/features/calendar/`, `lib/core/today_controller.dart`, `lib/core/providers.dart`, `lib/core/theme/tokens.dart` | NONE ✓ |

## Goal Achievement

### ROADMAP Success Criteria (the contract)

| # | Success Criterion | Status | Evidence |
|---|-------------------|--------|----------|
| SC1 | Today's doses grouped into time blocks (morning/day/evening/night) alongside a day-progress ring reflecting taken vs. total | ✓ VERIFIED | `groupIntoBlocks`/`blockIndexOf` over one const boundary list (`day_view_model.dart:20-45`); `DayBlockSection` renders only non-empty blocks; `DayProgressRing` fed by `dayRingCounts` at `calendar_screen.dart:112,158-159`. Tests: "blocks uk: only non-empty blocks render, in chronological order (DECIDED-1)"; "DayProgressRing uk: taken 2 of 5 renders \"2/5\" and the localized ringSemantics label" |
| SC2 | User can mark any dose taken or skipped with one tap, and undo the mark | ✓ VERIFIED | `dose_row.dart:86-121` — single guarded `_apply` → `intakeRepoProvider.setStatus`. Tests: "uk: tapping a dose row persists taken; tapping again returns it to pending (TRACK-02)"; "dose row uk: tapping a SKIPPED row writes taken (DECIDED-2 tap column)"; "dose action sheet uk: choosing mark-skipped pops the sheet and drives the RAW row to skipped"; undo exposed as `CustomSemanticsAction(l10n.undoMark)` and as the sheet's undo row |
| SC3 | User can browse past and current-week days; unmarked past doses render as neutrally-framed "missed" while the DB row stays pending | ✓ VERIFIED | `WeekStrip` (307 lines, bounded 53-page pager) + `isMissed` pure predicate; missed reuses the LIVE pending visual (`dose_row.dart:181-193`), chip only. Tests: "browsing uk: browsing a past day renders the not-marked chip while EVERY raw intake-log row stays pending (T-03-15, TRACK-03)"; "browsing uk: no warn or destructive color renders anywhere on a past day, and its unmarked dose is still tappable (DECIDED-3)" |
| SC4 | Doses appear only on days a regimen's cycle is actually active, verified correct across DST transitions and year boundaries | ✓ VERIFIED | `test/db/materialization_boundaries_test.dart`, 6/6 pass over a real in-memory Drift chain: spring-forward 2026-03-29, fall-back 2026-10-25 (materialized twice, no duplicate), the seven-on/seven-off fall-back window, the 2026-12-31→2027-01-04 year boundary, and status preservation under re-materialization |
| SC5 | The full plan-see-mark-taken loop builds and runs on an iOS simulator/device and an Android emulator/device (targetSdk 36) | ? NEEDS HUMAN | `android/app/build.gradle.kts:23` → `targetSdk = 36` ✓. Build gates and the device walkthrough were NOT executed by this verifier; 03-05-SUMMARY.md itself records the runtime half as PENDING with `human_judgment: true` and an empty `verification: []`. Routed to human item 1. |

### Plan must_haves — 03-01 (Tracer / clock / choke point)

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | `dayDosesProvider` is the single production caller of `ensureLogsForDay` and the single consumer of `watchDay`; doses appear with no manual materialization call | ✓ VERIFIED | grep confirms `lib/core/providers.dart:95-96` is the only production site. Test: "uk: a seeded supplement + active regimen renders a dose row with NO manual materialization call (PF-3, TRACK-01)" and "materializes one dose per active slot with NO manual ensure call (PF-3, TRACK-04)" |
| 2 | Tap marks taken in the real DB and re-renders from `watchDay`; tapping again returns to pending | ✓ VERIFIED | Test: "uk: tapping a dose row persists taken; tapping again returns it to pending (TRACK-02)" |
| 3 | A rapid double tap ends deterministically at taken (in-flight guard; `next` computed from the rendered status) | ✓ VERIFIED | `_busy` guard `dose_row.dart:80,87,91`; `_onTap` reads `widget.dose.status` at gesture time (`:105-109`). Test: "uk: two taps with NO pump between them end at taken, not oscillating back to pending (PF-4)" |
| 4 | `todayProvider` is the one calendar-clock read; self-updates at the next LOCAL midnight (local date constructor, never a fixed 24h) and re-derives on app resume | ⚠️ PRESENT_BEHAVIOR_UNVERIFIED | Present and wired: `nextLocalMidnight` uses `DateTime(y, m, d+1)` (`today_controller.dart:32-33`), `AppLifecycleListener(onResume: _refresh)` (`:52`), `_refresh` re-derives rather than increments (`:60`). Math pinned by 4 tests incl. "nextLocalMidnight lands 23-25 hours away — never a fixed 24h assumption (PF-2)", and disposal is tested. But no test fires the Timer or drives onResume — the transition itself is unexercised. → human item 2 |
| 5 | The Stack tab consumes `todayProvider` instead of a per-build clock read (closes IN-06) | ✓ VERIFIED | No `DateTime.now` in `lib/features/stack/`. Test: "uk: card status follows the shared todayProvider clock — ЗАПЛАНОВАНО before the start date, АКТИВНА inside the window (IN-06)" |
| 6 | Every `dayDosesProvider` family key is `dateOnly()`-normalized; a non-normalized key trips an assert | ✓ VERIFIED | `providers.dart:84-87`; all keys originate at `resolvedDayProvider`/`SelectedDayController.select` (which calls `dateOnly`). Test: "a non-normalized family key trips the PF-1 assert instead of forking the cache into a phantom day" |
| 7 | Pausing removes pending doses and resuming restores them with zero log-row writes; the provider layer adds no pause logic | ✓ VERIFIED | Test: "pausing removes pending doses and resuming restores them with ZERO log-row writes (PF-9, E-4, REGI-04)". `providers.dart` contains no pause branch — filtering is at the Drift query level |
| 8 | (backstop) Crossing local midnight with the app open moves Today to the new day; yesterday's unmarked doses read `не позначено`; verified live | ? NEEDS HUMAN | `verification: backstop` — abstained per the honest-verifier rule. → human item 2 (deduplicated with #4) |

### Plan must_haves — 03-02 (Pure day view-model + boundary proofs)

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Slot times map to four blocks through one const boundary list, with 719/720, 1079/1080, 1319/1320 pinned by tests | ✓ VERIFIED | `blockStartsMinutes` const + `blockIndexOf`. Tests: "blockIndexOf boundaries (DECIDED-1) both sides of every boundary"; "…the boundary const is the single source of the four blocks" |
| 2 | Blocks derived non-empty, fixed chronological order, each carrying the earliest REAL slot time | ✓ VERIFIED | Tests: "groupIntoBlocks … only non-empty blocks, in block order, earliest real slot time"; "…chronological order regardless of input order"; widget test "the block header shows the EARLIEST REAL slot time, not the mockup anchor (M5)" |
| 3 | `доза n з m` derived by grouping the day's dose list by regimen id, never from `regimen.slots` | ✓ VERIFIED | `doseCyclePosition` groups on `d.regimen.id` (`day_view_model.dart:96-102`). Tests: "doseCyclePosition (PF-6) m comes from the day list even though every regimen.slots holds 1"; "…n follows the day list order" |
| 4 | `isMissed` is the ONE missed rule, a pure predicate taking `today` explicitly, with no repository access and no write path in the file | ✓ VERIFIED | `day_view_model.dart:110-116`; file has no repository import and no write call. 4 tests under "isMissed — the ONE missed rule (TRACK-03, P-6)" |
| 5 | `isOverdue` can only be true while viewing today — no warn state derivable for any other day | ✓ VERIFIED | `viewingToday &&` gates the whole predicate (`:128`). Test: "isOverdue — today only … no non-today view can derive overdue, whatever the now-minute" |
| 6 | Block tag resolution follows DECIDED-6 exactly; a block with skips never claims they were taken | ✓ VERIFIED | `blockTagOf` sealed hierarchy `:170-187`. Tests: "all marked with at least one skip -> allMarked, never allTaken"; "skipped counts toward \"marked\" but not toward done"; plus the full 8-case table |
| 7 | Ring counts are taken vs. every dose of the day, skipped counting as not-taken | ✓ VERIFIED | `dayRingCounts` `:215-218`. Tests: "all skipped -> 0 of n (E-6)"; "taken vs every dose of the day; skipped counts as not-taken" |
| 8 | The full `ensureLogsForDay → watchDay` chain yields exactly one dose per active slot per day across Ukraine's 2026 DST transitions and a year boundary, idempotent, never resetting a marked status | ✓ VERIFIED | 6/6 in `test/db/materialization_boundaries_test.dart` (see SC4) |

### Plan must_haves — 03-03 (Tokens, ARB, ring, header)

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | E4 — ring omitted entirely at `total == 0`; otherwise always renders, counts taken against all doses, carries `ringSemantics`, does not animate | ✓ VERIFIED | `calendar_screen.dart:158` `if (counts != null && counts.total > 0)`. Tests: "DayProgressRing constructing at total == 0 is a programming error (DECIDED-7 …)"; "…renders at both extremes: 0 of 4 and 4 of 4"; "…shouldRepaint compares ONLY the fraction" (no implicit-animation widget in the file) |
| 2 | E5 — header always renders (clock/intl-derived, never empty); `backToToday` appears only off today and disappears on clear | ✓ VERIFIED | `:97-104` title/subtitle unconditional; `:138` `if (!isToday)`. Test: "header uk: backToToday appears only off today and clears the selection when tapped (E5)" |
| 3 | Exactly five new design tokens enter the codebase this phase, and no other literal value in `lib/features/calendar/` | ✓ VERIFIED (with caveat) | `git diff 7ce0d67~1 7ce0d67 -- lib/core/theme/tokens.dart` adds exactly 5: `checkBorder`, `warnBorder`, `onAccentMuted`, `BqRadii.doseRow`, `BqRadii.dayCell`. Zero `Color(0x…)` literals in `lib/features/calendar/`. **Caveat (⚠️ WARNING, not a gap):** one-off mockup-exact *dimension* literals (e.g. `top: 6`, `bottom: 84`, `fontSize: 13`) do remain inline with mockup-line comments — matching the established Phase-2 convention in `stack_screen.dart` (14 occurrences) and `regimen_editor_screen.dart` (26). The truth's absolute wording overstates the intent (D-07 is about the token closed list); no color/radius token value is duplicated as a literal |
| 4 | Every Phase-3 user-visible string exists in both locales in one commit; every count-bearing key carries all four uk CLDR plural forms exercised at 1/2/5/11/21 | ✓ VERIFIED | ARB parity re-checked: 116 keys en / 116 uk, symmetric difference empty. All 5 plural keys (`ringSemantics`, `slotsPerDay`, `stackSummary`, `substancesCount`, `weeksCount`) carry one/few/many/other. `plurals_test.dart:59-64` exercises `ringSemantics` at totals 1/2/5/11/21 |
| 5 | Weekday/month/day-number render through intl `DateFormat` with the active locale, never from ARB; uk subtitle pinned by a test | ✓ VERIFIED | `calendar_screen.dart:94` reads the locale from `Localizations.localeOf(context)` (not a literal tag); `DateFormat('EEEE, d MMMM', locale)`. Test: "header uk: following today renders the localized title and the pinned exemplar subtitle \"четвер, 13 серпня\" (A7)" |
| 6 | Header + ring sit outside the scroll view; scroll body pads bottom ≥ 84px | ✓ VERIFIED | `_Header` and `WeekStrip` are `Column` siblings of the `Expanded(_DayBody)` (`:60-69`); `ListView` padding `bottom: 84` (`:227`). Test: "header uk: the header sits OUTSIDE the scroll view and survives a scroll of the body" |

### Plan must_haves — 03-04 (Block sections, five-state rows, guarded write, sheet)

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | E1 populated — only non-empty blocks, fixed order, 18px apart, rows 7px apart, bottom padding ≥84px | ✓ VERIFIED | `day_block_section.dart:82` (`bottom: 18`), `:124` (`SizedBox(height: 7)`), `calendar_screen.dart:227`. Test: "blocks uk: only non-empty blocks render, in chronological order (DECIDED-1)" |
| 2 | E1 partial — a paused regimen's pending doses are absent (query-level filter), no placeholder/greyed row; its already-marked rows still render | ✓ VERIFIED | Test: "blocks uk: a paused regimen contributes NO pending row and no placeholder, while its taken row still renders (PF-9)" |
| 3 | E1 zero-one-many — `doseCycleChip` only when >1 dose that day, n/m by regimen grouping; `{done} з {total}` bare numerals; `ringSemantics` four-form uk plural at 1/2/5/11/21 | ✓ VERIFIED | `dose_row.dart:214` `if (position.m > 1)`. Tests: "dose row uk: a single dose that day renders NO cycle chip"; "…renders positions 1, 2 and 3 of 3 in slot order (PF-6)"; `plurals_test` "blockProgress and doseCycleChip interpolate bare numerals" + the 1/2/5/11/21 case |
| 4 | E1 long-text — names wrap (no fixed width/ellipsis); amount + chips in a `Wrap`; block-header divider is the flexible element | ✓ VERIFIED | `dose_row.dart:293-323` (two `Flexible`, no `overflow:`), `:328` `Wrap`. Test: "dose row uk: the longest realistic uk name plus three chips does not overflow a 390pt row (E2 long-text)" |
| 5 | E2 states — exactly one of five states per row; overdue only on today, missed only strictly before today, never both | ✓ VERIFIED | `_RowState` enum + fixed-order `_resolveState()` (`:124-139`), exhaustive `switch` with no default. Tests: taken / skipped / pending / overdue / missed rows each pinned, plus "on a day OTHER than today that same pending dose renders neither the overdue chip nor the warn border" |
| 6 | E2 in-flight — gestures ignored while the row's write is in flight; rapid double-tap ends at taken; no per-row spinner | ✓ VERIFIED | `_apply` and `_onLongPress` both early-return on `_busy`; no spinner widget in the file. Tests: "two taps with NO pump between them end at taken (PF-4)"; "dose action sheet uk: a long press issued while the tap write is STILL in flight is swallowed — one write, no sheet (T-03-02)" |
| 7 | E2 error — a failed write leaves the row at its previously rendered status and surfaces `markFailed` once; no optimistic-then-reverted visual | ✓ VERIFIED | `dose_row.dart:94-100` — catch shows a SnackBar, no local status state exists to roll back. Test: "dose row uk: a failed write leaves the row at its previous status and surfaces markFailed once (T-03-13)" |
| 8 | E2 long-text — tap target and layout unaffected by name length; circle and chip `Wrap` keep position while the name column flexes | ✓ VERIFIED | Circle is a fixed 24px sibling of `Expanded(Column)` (`:274-282`); `HitTestBehavior.opaque` over the whole padded row. Same 390pt overflow test |
| 9 | E6 — the sheet renders only actions valid for the current status; dismissing leaves the status unchanged | ✓ VERIFIED | `showDoseActionSheet` returns `Future<DoseStatus?>` and contains **no** repository/`setStatus`/`ref.read` reference — it only `Navigator.pop(result)`. Tests: pending/taken/skipped each assert the exact offered set, plus "dismissing the sheet without choosing leaves the raw status unchanged" |
| 10 | (backstop) Longest uk names + three chips at 390pt in uk clip nothing; verified visually on a simulator | ? NEEDS HUMAN | `verification: backstop` — abstained. Automated proxy passes but asserts absence of overflow errors, not visual acceptability. → human item 3 |

### Plan must_haves — 03-05 (Week strip, browsing, edge states, DATA-03)

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | E1 empty — zero-dose day renders `emptyDayTitle` + the correct body variant, no block headers, NO ring; disclaimer still renders | ✓ VERIFIED | `_EmptyDayState` `:317-355` picks `emptyDayBody` vs `emptyDayBodyNoStack` from `stackEntriesProvider`; `_Disclaimer` is outside the `when` (`:274`). Tests: "browsing uk: a day with no active cycle renders the empty title with the no-cycle body, no block header and NO ring — and still closes with the disclaimer (DECIDED-7)"; "with an EMPTY stack the empty day names the one next step instead" |
| 2 | E1 loading — `AsyncLoading` renders header + strip with an empty list area and NO spinner | ✓ VERIFIED | `loading:` branch returns `const <Widget>[]` or the held list (`:239-241`); no progress-indicator widget anywhere in the file |
| 3 | E1 loading (day switch) — switching days holds the previously rendered list; the list never blanks | ✓ VERIFIED | `_held` state field `:207,232,241`. Test: "browsing uk: switching to a day whose stream has not resolved HOLDS the previous rows — the list never blanks between days (PF-7)" |
| 4 | E1 error — renders `dayLoadError` + `retry` (provider invalidate); no stack trace or raw exception text | ✓ VERIFIED | `error: (_, _)` discards both args (`:245`); retry is `ref.invalidate(dayDosesProvider(widget.day))`. Test: "browsing uk: an errored day stream renders the documented copy plus retry, and never a stack trace (T-03-16)" |
| 5 | E3 populated — exactly 7 cells for the resolved week, Monday-first in both locales, dow/day-number from intl | ✓ VERIFIED | `week_strip.dart:72` `d.subtract(Duration(days: d.weekday - DateTime.monday))` (arithmetic, not `MaterialLocalizations`). Tests: "the resolved week renders exactly 7 Monday-first cells with intl dow labels and day numbers"; "week strip en: the first cell is STILL Monday (DECIDED-4 divergence from firstDayOfWeekIndex)" |
| 6 | E3 loading/error — the strip renders synchronously and never blocks; loading/errored day shows the neutral `field` dot, never a spinner or error cell | ✓ VERIFIED | Cells read `todayProvider`/`resolvedDayProvider` synchronously (`:117-118`); per-cell `dayDosesProvider` watch (`:283`) feeds only the dot. Test: "a day with NO doses shows the neutral dot and the strip still renders — never a spinner, never an error cell (E3)" |
| 7 | E3 overflow — cells `flex: 1`, centered, no fixed widths; paging bounded (52 back, current week forward), finite `itemCount` | ✓ VERIFIED | `const int weekPageCount = 53` used as `itemCount` (`:50,127`). Test: "the pager is BOUNDED — 53 pages, the last of which is today's week; a forward swipe cannot leave it (DECIDED-4)" |
| 8 | Neutrality invariant — no `warn`/`risk` color on any day other than today; no view path writes a status; missed derived purely, raw row stays `pending` | ✓ VERIFIED | `warn` reachable only from the today-gated overdue branch; `risk`/destructive absent from `dose_row.dart`. Tests: "no warn or destructive color renders anywhere on a past day, and its unmarked dose is still tappable (DECIDED-3)"; "browsing a past day renders the not-marked chip while EVERY raw intake-log row stays pending (T-03-15)" |
| 9 | The full plan→see→mark loop builds and runs on an iOS simulator and an Android emulator at targetSdk 36 (DATA-03), confirmed by a human on both platforms | ? NEEDS HUMAN | Same as SC5. → human item 1 |
| 10 | (backstop) On a 667pt-class device the header, ring and strip stay visible with the list scrolling beneath, in uk and en | ? NEEDS HUMAN | `verification: backstop` — abstained. → human item 4 |

**Score:** 38/43 truths verified (1 present, behavior-unverified; 4 routed to human)

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `lib/core/today_controller.dart` | `nextLocalMidnight()` + `TodayController` + app-lifetime `todayProvider` | ✓ VERIFIED | 79 lines; all three present; `NotifierProvider` (not autoDispose) per D-23; consumed by `calendar_screen`, `week_strip`, `calendar_providers`, `stack_screen` |
| `lib/core/providers.dart` | `dayDosesProvider` — autoDispose family, materialize-then-watch choke point | ✓ VERIFIED | `:82-97`; PF-1 assert, `regimensStreamProvider` watch for re-materialization, `ensureLogsForDay` then `yield* watchDay` |
| `lib/features/calendar/calendar_providers.dart` | `selectedDayProvider` (nullable) + `resolvedDayProvider` + `nowMinutesProvider` | ✓ VERIFIED | 74 lines; imported by `calendar_screen` and `week_strip` |
| `lib/features/calendar/calendar_screen.dart` | Complete day surface: fixed header, strip, held-last list body, empty/error states | ✓ VERIFIED | 380 lines; mounted at `lib/app_shell.dart:42` |
| `lib/features/calendar/day_view_model.dart` | 10 pure clockless helpers | ✓ VERIFIED | 218 lines; all named symbols present; no repository or clock import; consumed by 3 files |
| `lib/features/calendar/day_progress_ring.dart` | CustomPaint arc + mono counter + `ringSemantics` | ✓ VERIFIED | 124 lines; imported by `calendar_screen` |
| `lib/features/calendar/day_block_section.dart` | Block header (earliest real slot time, label, flexible divider, tag) + rows | ✓ VERIFIED | 195 lines; imported by `calendar_screen`; renders `DoseRow` |
| `lib/features/calendar/dose_row.dart` | Five-state row, in-flight-guarded handler, app's ONLY `setStatus` call site | ✓ VERIFIED | 422 lines; grep confirms the sole-call-site claim; imported by `day_block_section` |
| `lib/features/calendar/dose_action_sheet.dart` | `showDoseActionSheet()` returning a `DoseStatus?` — never writes | ✓ VERIFIED | 142 lines; zero repository references; imported by `dose_row` |
| `lib/features/calendar/week_strip.dart` | Bounded week PageView, Monday-first 7 cells, handled dots, selection | ✓ VERIFIED | 307 lines; imported by `calendar_screen` |
| `lib/core/theme/tokens.dart` | 5 new tokens | ✓ VERIFIED | Exactly 5 added; all referenced from `lib/features/calendar/` |
| `lib/core/l10n/arb/app_{en,uk}.arb` | Full Phase-3 copy set, both locales | ✓ VERIFIED | 116/116 key parity; `gen-l10n` reproduces the committed generated code byte-identically |
| `test/features/{today_provider,day_view_model,calendar_screen}_test.dart`, `test/providers_calendar_test.dart`, `test/db/materialization_boundaries_test.dart` | Phase-3 proofs | ✓ VERIFIED | 54 + 32 + 10 + 6 named tests, all re-run green by this verifier |

### Key Link Verification

| From | To | Via | Status |
|------|----|-----|--------|
| `calendar_screen.dart` | `core/providers.dart` | `ref.watch(dayDosesProvider(day))` — `:56` | ✓ WIRED (and the only `watchDay` consumer chain in `lib/`) |
| `core/providers.dart` | `core/domain/repositories.dart` | `await ensureLogsForDay(day)` then `yield* watchDay(day)` — `:95-96` | ✓ WIRED |
| `stack_screen.dart` | `core/today_controller.dart` | `ref.watch(todayProvider)`; zero `DateTime.now` in `lib/features/stack/` | ✓ WIRED (IN-06 closed) |
| `day_view_model.dart` | `core/domain/repositories.dart` | consumes `DayDose` only; no strings, no repo calls | ✓ WIRED |
| `calendar_screen.dart` | `day_view_model.dart` | `dayRingCounts` → ring; `groupIntoBlocks`/`currentBlockIndex` → body | ✓ WIRED |
| `calendar_screen.dart` | `calendar_providers.dart` | `resolvedDayProvider` drives title/subtitle; `selectedDayProvider.notifier.followToday()` backs `backToToday` — `:55,144` | ✓ WIRED |
| `day_progress_ring.dart` | `core/theme/tokens.dart` | `BqColors.field` track, `BqColors.calm` arc, `BqText.mono` counter | ✓ WIRED |
| `dose_row.dart` | `core/providers.dart` | `ref.read(intakeRepoProvider).setStatus(...)` behind `_busy` — `:93` | ✓ WIRED |
| `dose_row.dart` | `dose_action_sheet.dart` | `await showDoseActionSheet(...)` then the same guarded `_apply` — `:118-120` | ✓ WIRED |
| `week_strip.dart` | `calendar_providers.dart` | reads `resolvedDayProvider`; writes via `selectedDayProvider.notifier` — `:118,213` | ✓ WIRED |
| `week_strip.dart` | `core/providers.dart` | per-cell `ref.watch(dayDosesProvider(day))` for the handled dot — `:283` | ✓ WIRED |
| `calendar_screen.dart` (via `dose_row`) | `day_view_model.dart` | `isMissed` drives the not-marked chip with zero writes | ✓ WIRED |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|---------------|--------|--------------------|--------|
| `calendar_screen.dart` | `doses` | `dayDosesProvider(day)` → `DriftIntakeRepository.ensureLogsForDay` + `.watchDay` → SQLite | Yes — widget tests assert rows appear from a seeded in-memory Drift DB, and `browsing uk` reads back raw `db.select(db.intakeLogs)` rows | ✓ FLOWING |
| `_Header` ring | `counts` | `dayRingCounts(data)` where `data` unwraps the same stream (`null` while unresolved, never a literal) | Yes — "DayProgressRing uk: taken 2 of 5" | ✓ FLOWING |
| `dose_row.dart` | `dose.status` | `DayDose` from `watchDay`; writes go back through `setStatus` and re-arrive via the stream (no local status state) | Yes — tap test asserts the raw DB row transitions | ✓ FLOWING |
| `week_strip.dart` | per-cell handled dot | `dayDosesProvider(cellDay)` | Yes — "a past day whose every dose is handled shows the calm dot; a pending past day, an empty day and a future day show the neutral dot" | ✓ FLOWING |
| `_EmptyDayState` | `hasStack` | `stackEntriesProvider` (composed from two Drift streams) | Yes — "with an EMPTY stack the empty day names the one next step instead" | ✓ FLOWING |
| `_DayBody` | `_nowMinutes` | `nowMinutesProvider` (`_minuteOfDay()`), default `0` for the first frame only, overwritten on first emission | Yes — overdue/current-block tests pass at injected minute values | ✓ FLOWING |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Static analysis clean | `flutter analyze` | `No issues found!` | ✓ PASS |
| Full suite green | `flutter test` (run once) | `+273: All tests passed!` | ✓ PASS |
| Generated l10n matches ARB | `flutter gen-l10n && git status --porcelain lib/core/l10n/` | empty output | ✓ PASS |
| ARB en/uk key parity | python json symmetric-difference over both ARBs | 116/116, difference empty | ✓ PASS |
| uk four-form plurals present | regex over uk ARB plural bodies | 5/5 keys carry one/few/many/other | ✓ PASS |
| Exactly 5 new tokens | `git diff 7ce0d67~1 7ce0d67 -- lib/core/theme/tokens.dart` | 5 additions, no more | ✓ PASS |
| Single `setStatus` UI site | `grep -rn setStatus lib/` | 1 | ✓ PASS |
| `DateTime.now` in one `lib/features/` file | `grep -rn "DateTime\.now" lib/features/` | 1 file, 1 line | ✓ PASS |
| targetSdk 36 | `grep targetSdk android/app/build.gradle.kts` | `targetSdk = 36` | ✓ PASS |
| Android/iOS build gates | `flutter build apk --debug`, `flutter build ios --simulator` | not executed | ? SKIP → human item 1 |

### Probe Execution

No `scripts/*/tests/probe-*.sh` exist in this repository and no PLAN declares a probe. Step 7c: N/A — the phase's runnable checks are the `flutter analyze`/`flutter test` gates re-run above.

### Requirements Coverage

| Requirement | Source Plan(s) | Description | Status | Evidence |
|-------------|----------------|-------------|--------|----------|
| TRACK-01 | 03-01, 03-02, 03-03, 03-04 | Today's doses grouped by time blocks with a day-progress ring | ✓ SATISFIED | SC1 evidence; `groupIntoBlocks` + `DayBlockSection` + `DayProgressRing` |
| TRACK-02 | 03-01, 03-04 | Mark taken or skipped with one tap; undo | ✓ SATISFIED | SC2 evidence; tap/undo/sheet tests |
| TRACK-03 | 03-02, 03-05 | Browse past/current week; missed computed in view, DB row stays pending, presented neutrally | ✓ SATISFIED | SC3 evidence; raw-row + neutrality-sweep tests |
| TRACK-04 | 03-01, 03-02 | Doses only on active cycle days, correct across DST and year boundaries | ✓ SATISFIED | SC4 evidence; 6 boundary tests over the real chain |
| DATA-03 | 03-05 | App builds and runs the full loop on both iOS and Android (targetSdk 36) | ? NEEDS HUMAN | `targetSdk = 36` confirmed; build gates + device walkthrough not executed by this verifier |

No orphaned requirements: REQUIREMENTS.md maps exactly TRACK-01..04 and DATA-03 to Phase 3, and all five are claimed across the plans' `requirements:` fields.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| — | — | `TBD` / `FIXME` / `XXX` / `HACK` / `TODO` / `PLACEHOLDER` | — | NONE found across `lib/features/calendar/`, `lib/core/today_controller.dart`, `lib/core/providers.dart`, `lib/core/theme/tokens.dart` |
| `lib/features/calendar/calendar_screen.dart` | 239-241 | `loading: () => const <Widget>[]` (empty return) | ℹ️ Info | Deliberate, documented no-spinner design (E1 loading); the sibling `_held` branch supplies the real list on a day switch and is test-covered. Not a stub |
| `lib/features/calendar/calendar_providers.dart` | 21 | `DateTime? build() => null` | ℹ️ Info | `null` is the meaningful "follow today" sentinel (03-RESEARCH P-3), not an unimplemented default |
| `lib/features/calendar/` (various) | various | Inline mockup-exact numeric dimensions alongside `BqSpace`/`BqRadii` tokens | ⚠️ Warning | Matches the established Phase-1/2 convention (`stack_screen.dart`, `regimen_editor_screen.dart`) and each literal carries a mockup-line comment. Softens the absolute wording of 03-03 truth #3 but breaks no token contract |

### Human Verification Required

#### 1. DATA-03 — the full loop on both platforms

**Test:** Build and run on an iOS simulator/device and an Android emulator/device, then walk: add a supplement → configure a cyclic regimen → open Calendar → see the dose on Today → tap it taken → tap it back to pending. Also run the two build gates: `flutter build apk --debug` and `flutter build ios --simulator --no-codesign`.
**Expected:** The loop completes identically on both platforms; both builds succeed; `targetSdk = 36` (already confirmed statically).
**Why human:** Requires simulator/emulator control. This verifier did NOT run the build gates and does not accept the SUMMARY's D7 `status: pass` as evidence. 03-05-SUMMARY.md itself records the runtime half (D8) as `verification: []`, `human_judgment: true`, explicitly NOT performed and NOT claimed.

#### 2. Midnight rollover (covers 03-01 backstop AND the behavior-unverified truth)

**Test:** Leave the app open across local midnight (or advance the device clock past it). Separately, background the app across midnight and resume it.
**Expected:** The Today view advances to the new day — header date, week strip and Stack tab card statuses all follow, with no stale header date. Browsing yesterday shows its unmarked doses as `не позначено`.
**Why human:** The clock arithmetic (`nextLocalMidnight`) is pinned by 4 unit tests and disposal cancels the timer, but nothing exercises the actual transition — the `Timer` firing into `_refresh`, or `AppLifecycleListener.onResume` firing after a backgrounded rollover. Present and wired ≠ behaviorally proven.

#### 3. Longest uk dose row at 390pt

**Test:** On a simulator at 390pt width in uk, render one row with a longest-case name ("Вітамін B12 метилкобаламін", "Хондропротектор") plus a `доза 3 з 3` chip, a user note chip and the `не прийнято вчасно` chip.
**Expected:** Nothing clips or overflows; the name wraps and chips break to a new line.
**Why human:** `verification: backstop` in 03-04-PLAN.md. The automated proxy ("dose row uk: the longest realistic uk name plus three chips does not overflow a 390pt row") passes, but it proves absence of layout exceptions, not visual acceptability.

#### 4. 667pt-class device layout

**Test:** Open the Calendar tab on an iPhone SE-class device in both uk and en.
**Expected:** Header, ring and week strip remain fully visible with the block list scrolling beneath them.
**Why human:** `verification: backstop` in 03-05-PLAN.md — layout-at-size visual judgment; widget tests run at a fixed surface size.

### Gaps Summary

**No gaps.** Every automated must-have resolved VERIFIED against the codebase, independently re-run: `flutter analyze` reports 0 issues, `flutter test` reports 273/273, `flutter gen-l10n` produces no diff, all seven VALIDATION.md automated commands pass, and both of the phase's structural invariants hold under fresh greps (one `setStatus` UI call site at `dose_row.dart:93`; `DateTime.now` confined to one line in one file under `lib/features/`).

The adversarial checks that most often expose a hollow phase all came back clean: the Calendar tab is genuinely mounted in `app_shell.dart:42` (not a Phase-1 stub); the rendered dose list traces to a real `ensureLogsForDay → watchDay` Drift chain rather than a static return; `dose_action_sheet.dart` contains zero repository references, confirming the "never writes" claim; there are no debt markers and no hardcoded user-visible strings in the feature; and ARB parity is exact at 116/116 with the committed generated code reproducible.

The phase is **not** `passed` for two reasons, neither of which is a defect:

1. **Four truths were deliberately deferred to a human** — the three `verification: backstop` items (midnight rollover, longest-uk-name row at 390pt, 667pt-class layout) and DATA-03's runtime half. The plans declared these as human-only up front, and 03-05-SUMMARY.md honestly records DATA-03's device half as PENDING rather than claiming it. This verifier abstained on all four rather than inferring an outcome.
2. **One truth is present-but-behavior-unverified** — `todayProvider`'s midnight/resume self-update. The math and the wiring are proven; the state transition itself is not reachable from `flutter_test` and is folded into human item 2.

One ⚠️ WARNING, not a gap: 03-03 truth #3's absolute wording ("no other literal value appears anywhere in `lib/features/calendar/`") is stricter than what the code does. The token half is exactly right — exactly 5 tokens added, zero raw `Color(0x…)` literals in the feature — but one-off mockup-exact dimension literals remain inline, matching the Phase-1/2 convention. Worth softening the wording in a future plan rather than changing the code.

---

_Verified: 2026-08-15T20:07:02Z_
_Verifier: Claude (gsd-verifier)_
