---
phase: 07-dose-reminders
plan: 02
subsystem: notifications
status: complete
tags: [notifications, cycle-math, property-test, budget, reconciliation, pure]
requires:
  - lib/core/domain/cycle_math.dart (isActiveOn, dateOnly)
  - lib/core/domain/models.dart (Regimen, DoseSlot, RegimenKind)
  - lib/core/notifications/notification_plan.dart (planNotifications, notificationIdFor — plan 07-01)
  - lib/core/notifications/notification_scheduler.dart (PendingNotification — plan 07-01)
provides:
  - runsEveryDayFrom (the tier-A predicate, in cycle_math.dart beside isActiveOn)
  - tier promotion inside planNotifications, with repeats-first ordering
  - reconcile(desired, pending) and DesiredNotification
affects:
  - nothing outside the four files this plan owns; no widget, token, ARB key or platform file
tech-stack:
  added: []
  patterns:
    - a predicate that mirrors another function's internals kept in the SAME file, bound by a property test rather than by a comment
    - property tests with NAMED bounds, where the bound is part of the stated property and its two excluded shapes are named in a comment
    - every property and guard shown red by a deliberate mutation before being trusted
key-files:
  created: []
  modified:
    - lib/core/domain/cycle_math.dart
    - lib/core/notifications/notification_plan.dart
    - test/domain/cycle_math_test.dart
    - test/notifications/notification_plan_test.dart
decisions:
  - The tier question is asked per MINUTE over the whole regimen set, never per regimen; a minute one cycling-or-course regimen touches falls back wholesale. Proven load-bearing by mutation.
  - A contributor that will never fire (suspended, already over) also blocks promotion. The fallback is always correct and merely more expensive, so conservatism here costs requests, never truthfulness.
  - No `ScheduledNotification` type was built; `reconcile` compares against the seam's `PendingNotification`, which plan 07-01 already declared. The plan's artifact list and its own read_first disagreed; the read_first matches the tree.
  - Nine of plan 07-01's tests were retargeted at a new `tierB()` fixture rather than edited in their claims — their subject (the one-shot path) had been promoted out from under them.
metrics:
  duration: two sessions (the first ended on a session limit, mid-verification)
  completed: 2026-08-17
  tasks: 3
  commits: 4
actuals:
  tokens: 9800
  tasks: 3
  commits: 4
---

# Phase 7 Plan 02: The Pure Plan Complete Summary

The tier split and the reconciler both land as pure functions: a minute of day whose every contributor runs daily now costs exactly one pending request forever, repeats are structurally unreachable by budget truncation, and every re-derivation is a set difference that also detects text the ids cannot see.

## What was built

| Task | What | Commit |
| ---- | ---- | ------ |
| 1 | `runsEveryDayFrom` in `cycle_math.dart`, one screenful below `isActiveOn`, plus six single-case tests and two property tests over a generated regimen set | `098e868` |
| 2 | Tier promotion inside `planNotifications`, computed per minute over the whole set, with repeats-first ordering and the budget on the tail | `fd3b942` |
| 3 | `reconcile` and `DesiredNotification`, comparing rendered title and body as well as ids | `cf0479c` |
| — | Follow-up from reading the whole-plan diff end to end: the last bounded-generator range named, one test helper privatised. No behaviour change | `4fa3f27` |

## Verification

- `flutter analyze` — clean, at every commit and at final HEAD.
- `flutter test` — **910 passing** (880 baseline + 30 new), zero tests deleted, four consecutive green full runs.
- `git diff --quiet -- pubspec.yaml pubspec.lock` — succeeds. No package added, removed or moved.
- `git diff --stat fa6308f..HEAD -- lib/features/ lib/core/theme/ lib/core/widgets/ android/ ios/ lib/core/l10n/` — **empty**. `activeRuns` has not moved and no Phase-4 file was touched.
- `grep -rn "runsEveryDayFrom" lib/` — exactly one declaration, in `lib/core/domain/cycle_math.dart`, plus one call site in `notification_plan.dart`.
- `grep -cE "package:timezone|package:flutter_local_notifications|package:flutter/|DateTime.now" lib/core/notifications/notification_plan.dart` — **0**.
- `grep -rn "cancelAll" lib/` — **0** matches anywhere in the app.
- Word-boundary grep for `onDays|offDays|RegimenKind|paused` in `notification_plan.dart` — **0**. A plain `grep -cE` reports 3, all of them `horizonDays` containing the substring `onDays`: exactly the false positive plan 07-01's summary recorded as its deviation 6.

### Red-then-green evidence

| Behaviour | The failure actually seen first |
| --- | --- |
| The tier predicate | `Error: Method not found: 'runsEveryDayFrom'` |
| Tier promotion (10 of 13 tests) | `Expected: an object with length of <1> / Actual: [<30 one-shots>]`; `Expected: ['repeat/480','16/600',…] / Actual: [16/480, 16/600,…]` |
| `reconcile` | `Error: 'DesiredNotification' isn't a type` / `Method not found: 'reconcile'` |

Three of task 2's tests were green before the change — the fallback guards (mixed minute, daily-plus-course, future start). They could not be red first, because the old code promoted nothing and satisfied them vacuously. They were therefore proven by mutation instead, below.

### Gates and properties proven to bite, not merely written

Every claim this plan makes about its own tests was checked by deliberately breaking the code or the bound and watching the named test go red. Each mutation was reverted immediately.

| Mutation | What went red |
| --- | --- |
| Delete the pre-start guard from `runsEveryDayFrom` | the POSITIVE property, naming the exact generated input: `runsEveryDayFrom accepted cyclic(start: 2027-04-01 [today+228], end: null, on: 189, off: 0, paused: false) but isActiveOn is false on day 0 of the walk` |
| Widen `_boundedMaxCourseLengthDays` 120 → 500 | the NEGATIVE property, with exactly excluded shape 1: `rejected course(start: 2025-11-21 [today-268], end: 2027-11-23, …) but isActiveOn holds on every one of the 400 days` — so the bound is load-bearing, which is what the comment above the test claims |
| Delete `..removeAll(blocked)` — ask the tier question per regimen instead of per minute | both mixed-minute fallback tests, plus one of plan 07-01's grouping tests |
| Compare ids only in `reconcile` | the locale case: `Expected: Set:[394657086] / Actual: Set:[]` — literally the empty diff DECIDED-16 warns about |

Both property tests also carry a non-vacuity assertion (`accepted > 20`, `rejected > 20`), so a generator that stopped producing interesting regimens fails rather than passing empty. Those thresholds are a floor, not a measurement, so the real counts were measured by raising each threshold to an impossible value and reading the failure: of 1000 samples per direction, the positive property actually exercises **57 accepted** regimens and the negative property **979 rejected** ones. 57 is a genuinely small number — it is the product of the four independent conditions the predicate requires all holding at once — and it is the number the `offDays == 0` weighting in the generator exists to keep off the floor.

## Deviations from the plan

### 1. Nine of plan 07-01's tests had to be edited — the plan said none would

The plan states the one-shot path "stays exactly as it is" and its task-1 criteria expect the suite to pass untouched. It does not: nine of plan 07-01's tests went red the moment promotion landed, because their fixtures are `cyclic(on: 30, off: 0)` — a **daily** regimen, which is precisely what the new rule promotes. Their claims are about the one-shot path (the day walk, ordering by day, the now boundary, truncation from the far future, the id a one-shot derives), so leaving them alone would have silently retargeted each at the repeat tier under a one-shot name.

Fixed by moving the fixture and never the claim: a new `tierB()` helper (`on: 60, off: 1`) is active on every day these tests look at, but is not promotable, so **every expected value is unchanged, verbatim**. One test title changed — `every emitted notification is a one-shot in this plan` was a statement about 07-01's state and is now `every notification a tier-B regimen emits is a one-shot`. Zero tests deleted; the diff's single removed `test(` line is that rename.

Two tests were deliberately left on a daily fixture, because promotion makes them stronger: `a regimen starting mid-horizon starts contributing on its start day` (future start, correctly not promoted) and `a count never includes a regimen inactive on that particular day` (now also a mixed-minute case).

### 2. The plan asks for a `ScheduledNotification` type that must not exist

The artifact list names "`DesiredNotification` / `ScheduledNotification` value types". Building the second would have been a duplicate of `PendingNotification`, which plan 07-01 already declared on the seam — and which **the same task's own `<read_first>` calls** "the pending-request value type plan 07-01 declared, which is what this function compares against". The plan contradicts itself; the `read_first` is the half that matches the tree. Not built.

### 3. Consequently the import list DID change, against a stated must-have truth

The truth reads: "`planNotifications` grows a tier and `reconcile` joins it, and the file's import list does not change." `reconcile` compares against the platform's own record, so it must name the type that record arrives as — `notification_plan.dart` now imports `notification_scheduler.dart`.

The truth's stated *purpose* is intact and verified: the pure plan "remains free of any clock, timezone, plugin or Flutter import". `notification_scheduler.dart` has **zero imports of its own**, so nothing impure is reachable through it, and the grep gate still returns 0. The alternative — accepting the pending set as an anonymous record to dodge the import — would have bought a literally-unchanged import list by pushing a hand-built mapping onto every caller, where a mistake is silent.

### 4. `runsEveryDayFrom`'s "zero or negative on-day count" is tested at zero only

A negative `onDays` is unconstructible: `Regimen`'s own `assert(onDays >= 0)` forbids it, so there is no input to test. The predicate still mirrors `isActiveOn`'s `<= 0` rather than `== 0`, so it stays a mirror of the rule rather than of the model's asserts.

### 5. One inaccurate doc line corrected in passing (Rule 1)

`notification_plan.dart`'s library doc claimed the file imports "the notification constants". It never did, in 07-01 or now. Corrected to state what it actually imports and why each is pure.

### 6. Two gaps against task 1's own acceptance criteria, found by reading the diff rather than by a red test

Commit `4fa3f27`. The criterion "the bounded generator's ranges appear as named constants, not as inline literals, so the bound is visible as a decision rather than as a coincidence" was satisfied for three of the four ranges; the start-offset range was still a bare `400`. It is now `_boundedMaxStartOffsetDays`, same value, so generation is bit-identical. Separately, `startOffsetLabel` was the file's one top-level helper without an underscore. Neither was caught by a test, because neither is testable — which is the argument for reading the diff end to end as a distinct step rather than trusting a green suite.

## What was NOT verified

Stated plainly, because each of these is a real limit on what the green suite above proves.

1. **Nothing in this plan has a production caller, so none of it has run against the platform.** `reconcile` and the tier-A entries are exercised only by their own unit tests. Plan 07-04 owns the sync loop that will first call them for real. In particular, the claim that a promoted minute's first fire is computed correctly by the platform from `matchDateTimeComponents: DateTimeComponents.time` rests on plan 07-01's wire assertion and on research §5.5 — **this plan did not re-verify it**, and it is the one assumption the tier-A design turns on.
2. **The 400-day walk does not test DST, and cannot.** The comment inherits that framing from the existing tests in the file, and it is true of `isActiveOn`'s *design* — but every value in these functions is a `DateTime.utc(y,m,d)` date-only, so no timezone is reachable from either the predicate or the property. The walk buys a year boundary and a long modulo horizon; it does not and cannot catch a timezone bug. The real DST boundary is `tz_conversion.dart`, which plan 07-01 owns and tests.
3. **Three of task 2's tests could not be shown red before the implementation** — the mixed-minute, daily-plus-course, and future-start fallback guards. The pre-change code satisfied them vacuously, because it promoted nothing at all. They were proven by mutation afterwards instead, which is a weaker order than red-then-green and is recorded as such.
4. **The negative property's bound is verified sound, not verified complete.** Widening the course bound was shown to produce exactly the first of the two excluded shapes, so that shape is real. The second — a cyclic regimen with breaks and an on-day count of 400 or more — is argued, not demonstrated: the bounded generator cannot produce it, so no run of this suite has ever exhibited it.
5. **No iOS or Android build was run.** This plan touches no platform file, no `pubspec`, and no plugin, so a build could not have been affected — but it was not run, and the phase's build evidence is still plan 07-01's.
6. **The estimate/actual comparison is not like-for-like across plans.** `actuals.tokens: 9800` is `chars/4` over this plan's realized `+` diff (39,200 characters), against an estimate of 86,000. The gap is genuine — this plan added two small pure functions — but the reader should know both numbers measure the diff, not the session.

## Known Stubs

None. Both functions this plan adds are complete and fully covered.

`reconcile` and the tier-A entries have **no production caller yet** — plan 07-04 owns the sync loop that renders the copy, calls `reconcile`, and issues `scheduleDaily` for the entries with a null day. That is the wave boundary the plan describes, not an unfinished piece: `scheduleDaily` and `nextDailyOccurrence` already exist on the seam and are asserted on the wire (07-01), and `notificationIdFor(day: null, …)` already derives the tier-A id.

## Threat Flags

None. No security-relevant surface appeared beyond the plan's `<threat_model>`. Every mitigation it names is now a named test:

- **T-07-08** (a wrongly promoted minute) — the per-minute rule, with the mixed-minute and future-start tests; proven by mutation.
- **T-07-09** (budget truncation removing a repeat) — asserted as an equality between the repeat count of the budgeted and unbudgeted plans, not as a spot check.
- **T-07-10** (stale text after a language change) — the locale test, proven to be the only thing standing between the app and an empty diff.
- **T-07-11** (a blanket clear) — structural: the return type has no such field, `grep -rn "cancelAll" lib/` is 0, and the empty-desired case returns 40 individual cancellations.
- **T-07-12** (drift between predicate and rule) — the two property tests, both proven to bite.
- **T-07-SC** — no install task existed; `git diff --quiet -- pubspec.yaml pubspec.lock` succeeds.

## Notes for the next plans

- **Plan 07-04 (sync):** the loop is `planNotifications(...)` → render title/body per entry → `reconcile(desired:, pending:)` → apply. `DesiredNotification.notification.repeatsDaily` chooses `scheduleDaily` over `scheduleOnce`; `reconcile` imposes no I/O ordering on purpose, so cancel-then-schedule or interleaved is yours to pick.
- **`nowMinutesFromMidnight` has one legitimate clock source**, `todayProvider`/`TodayController` — the app's single wall-clock read. Do not introduce a bare `DateTime.now()` for it; that would falsify `TodayController`'s "the ONE wall-clock read" claim and leave the at-now boundary unpinnable by the fake clock.
- A promoted minute is emitted even when it is already past today. That is correct and tested: the platform computes a repeat's first fire from the time components via `nextDailyOccurrence`, so the adapter must not filter it.
- The locale trigger (DECIDED-16) needs no special casing at the reconcile layer — re-render the copy and re-run the diff, and the text comparison does the rest.

## Self-Check: PASSED

- Both modified `lib/` files exist and carry the new symbols: `runsEveryDayFrom` at `lib/core/domain/cycle_math.dart:75`, `reconcile` and `DesiredNotification` in `lib/core/notifications/notification_plan.dart`.
- All four commits resolve in `git log`: `098e868`, `fd3b942`, `cf0479c`, `4fa3f27`.
- `flutter analyze` clean and `flutter test` 910 passing at the recorded HEAD, re-run after the session resumed.
- The whole-plan diff (`git diff main..HEAD`) was read end to end. No mutation residue: `..removeAll(blocked)` and the full title-and-body comparison are both present in `lib/`, and both `greaterThan(20)` non-vacuity assertions are back in the test file after the count measurement. `git status` is clean apart from this summary.
