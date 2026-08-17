---
phase: 07-dose-reminders
plan: 04
subsystem: notifications
status: complete
tags: [notifications, l10n, plurals, sync, debounce, timezone, lifecycle]
requires:
  - lib/core/l10n/gen/app_localizations.dart (lookupAppLocalizations, the four ARB keys — plan 07-01)
  - lib/core/notifications/notification_plan.dart (planNotifications, reconcile, notificationIdFor — plans 07-01/07-02)
  - lib/core/notifications/notification_scheduler.dart (the seam and PendingNotification — plan 07-01)
  - lib/core/notifications/notification_providers.dart (the scheduler seam, the bootstrap, timeZoneLoaderProvider — plan 07-01)
  - lib/core/notifications/tz_conversion.dart (instantFor, initTimeZones — plan 07-01)
  - lib/core/today_controller.dart (todayProvider and its injectable wall-clock read)
  - lib/core/providers.dart (regimensStreamProvider)
provides:
  - lib/core/notifications/notification_copy.dart (title, body, channel copy, the ONE time formatter)
  - lib/core/notifications/notification_locale.dart (notificationLocaleProvider + NotificationLocaleObserver)
  - lib/core/notifications/notification_sync.dart (notificationSyncProvider — the only caller of reconcile)
  - deviceZoneReaderProvider (the injectable resume-time device-zone read)
  - localZoneIdentifier / setLocalZoneIfChanged (tz_conversion)
  - deviceZoneIdentifier (promoted from private)
  - test/notifications/recording_scheduler.dart (the shared argument-recording seam double)
affects:
  - lib/main.dart (the observer replaces the inline locale observation; two watches; one added override)
  - lib/core/notifications/notification_providers.dart (the bootstrap now LISTENS to the resolved locale)
  - lib/core/notifications/tz_conversion.dart (three added symbols, one privatised name promoted)
tech-stack:
  added: []
  patterns:
    - triggers LISTENED rather than watched inside a Notifier's build, so `ref.onDispose` fires only at real disposal
    - a platform read injected as a provider with a null ("nothing to ask") default — the third instance of the 07-01 idiom
    - a test double subclassing the real Notifier and overriding only `build()`, so the production seam under test is the production seam
    - a claim a behavioural test provably cannot carry is moved to a source gate, and the test's own reason says so
key-files:
  created:
    - lib/core/notifications/notification_copy.dart
    - lib/core/notifications/notification_locale.dart
    - lib/core/notifications/notification_sync.dart
    - test/notifications/notification_copy_test.dart
    - test/notifications/notification_sync_test.dart
    - test/notifications/recording_scheduler.dart
  modified:
    - lib/main.dart
    - lib/core/notifications/notification_providers.dart
    - lib/core/notifications/tz_conversion.dart
decisions:
  - The Android channel has ONE writer. 07-01's bootstrap already rewrote the channel per locale, so it now listens to the resolved locale instead of the sync growing a second channel writer.
  - The locale observer is mounted in `builder:`, not `home:` — the position 07-01 established, inside the same localizations but above the navigator, so it wraps every route and there is exactly one observation point.
  - The time formatter takes `locale.toString()`, not a BCP-47 tag, matching every other formatter call site in the app. Recorded in the helper's doc as a deviation from UI-SPEC §7.1.
  - The sync guards the WHOLE application rather than each platform call; the seam already absorbs its own platform errors and skips a past instant by returning, so a per-call guard would be a second copy of that rule.
  - The device-zone re-read is a new injectable provider rather than a second `initTimeZones()` call, because the test has to distinguish "unchanged" from "changed" and re-parsing a megabyte on every resume is not free.
metrics:
  duration: one session
  completed: 2026-08-17
  tasks: 3
  commits: 4
actuals:
  tokens: 21000
  tasks: 3
  commits: 4
---

# Phase 7 Plan 04: Copy and Sync Summary

The reminders are wired to reality: the text is built in the language the interface
is actually rendering, pinned character for character at every Ukrainian plural
boundary and inside a length budget the operating system will actually show, and
one debounced controller re-derives the whole scheduled set on all six triggers —
with every platform call the app makes coming out of `reconcile`.

## What was built

| Task | What | Commit |
| ---- | ---- | ------ |
| 1 | The copy layer, the single 24-hour time formatter, the resolved-locale notifier and its observer; the bootstrap re-pointed at the observed locale | `80873e7` |
| 2 | The sync: four listened triggers, the bootstrap precondition, the debounce, the reconciled application | `efd2d9d` |
| 3 | The lifecycle listener, the resume-time device-zone re-read, six trigger tests one at a time | `b72b5a6` |
| — | One comment corrected after reading the whole diff: the recorded rebuild cost was understated | `afbe00f` |

## Verification

- `flutter analyze` — clean, at every commit and at final HEAD.
- `flutter test` — **973 passing** (929 baseline + 44 new), **two consecutive green full runs**, zero tests deleted.
- **Zero existing test files edited.** `git diff --name-only main..HEAD -- test/` lists only the three files this plan created.
- `git diff --quiet -- pubspec.yaml pubspec.lock` — succeeds.
- `git diff --stat main..HEAD -- lib/features/ lib/core/theme/ lib/core/widgets/ android/ ios/` — **empty**.
- `test/l10n` — 79 passing, ARB parity, plural, copy-safety and hardcoded-string gates all green and **unmodified**. No new allowlist entry was needed: neither new `lib/` file contains a translatable literal.
- `grep -rn "cancelAll" lib/` — nothing.
- `grep -cE "SupplementRepository|stackEntriesProvider" notification_sync.dart` — 0; same for `notification_copy.dart` including `\.name`.
- `grep -c "DateFormat" notification_copy.dart` — exactly **1**. (This forces the doc comment not to name the class it uses; the helper's doc says "the formatting package's hour-and-minute skeleton" for that reason alone.)
- `grep -rc "BuildContext" notification_copy.dart` — 0. `grep -rc "basicLocaleListResolution" lib/` — nothing.
- `grep -rn "BqColors\.\|BqSpace\.\|BqRadii\.\|BqText\." lib/core/notifications/` — nothing.

### Red-then-green evidence

Every behavioural step was written as a failing test, run, and the actual failure recorded.

| Behaviour | The failure actually seen first |
| --- | --- |
| The copy layer and the locale observer | `Error when reading 'lib/core/notifications/notification_copy.dart': No such file or directory` / `Method not found: 'notificationBody'` |
| The channel following the observed locale | `Expected: ['initialize', 'ensureChannel'] / Actual: []` |
| The observer mounted in the real app | `Expected: true / Actual: <false>` |
| The sync | `Error when reading 'lib/core/notifications/notification_sync.dart': No such file or directory` |
| The root widget keeping the sync alive | `Expected: true / Actual: <false>` |
| The resume path and the zone seam | `Undefined name 'deviceZoneReaderProvider'` / `Undefined name 'localZoneIdentifier'` |

### Gates proven to bite, not merely written

Every claim was checked by breaking the code and watching the named test go red. Each mutation was reverted immediately.

| Mutation | What went red |
| --- | --- |
| `DateFormat.Hm` → `DateFormat.jm` | three tests, with `Expected: '19:00' / Actual: '7:00 PM'` — the 24-hour rule this helper exists to hold |
| Title carries the app name | the no-app-name test (`Expected: false / Actual: <true>`) AND the budget test (`Expected: a value less than or equal to <24> / Actual: <29>`) |
| Delete the bootstrap-flag read in the sync | `nothing at all is called while the bootstrap flag is false` |
| Delete the enabled gate | both not-permitted tests (`false` and `null`) |
| Debounce delay → `Duration.zero` | `Expected: <1> / Actual: <4>` |
| Force the one-shot branch for a promoted minute | the tier test |
| Move the cancels after the schedules | the cancel-ordering test |
| Delete the lifecycle listener | three tests: the resume trigger, the zone change, the throwing read |
| `setLocalZoneIfChanged(...)` → a bare `await readZone()` | the zone-change test |
| Delete `_lifecycle?.dispose()` from the dispose callback | **nothing** — see deviation 5; the source gate that now carries this claim WAS then shown red (`Expected: true / Actual: <false>`) |

## Deviations from the plan

### 1. The SYNC does not refresh the Android channel — the bootstrap does

The plan (task 2) has the sync refresh the channel's name and description on a locale
change. It does not, and must not: **07-01 already built that**, and its `bootstrap()`
is already deliberately non-idempotent across locales for exactly this purpose. Adding a
second `ensureChannel` caller would mean two channel writers, two calls per language
change, and two places to keep the "never re-version the id" rule.

Instead the bootstrap now **listens to the resolved locale** itself, so one observation
point feeds one channel writer. The plan's own acceptance criterion — "a language change
produces exactly one application and one channel refresh" — is asserted intact, in the
one test that runs the **real** bootstrap alongside the sync, and it also asserts that
the newly armed title is in the new language.

Listened rather than watched, because a watch would re-run the bootstrap's `build()` and
reset the readiness flag to `false` on every language change — stopping and restarting
everything downstream for a copy rewrite.

### 2. The observer is mounted in `builder:`, not in `home:`

The plan says `home:`. 07-01's summary records that it had already put the locale
observation in `MaterialApp.builder`. Mounting a second observation point in `home:`
would have left two, which is the defect shape DECIDED-15 exists to prevent — applied to
the observation rather than to the resolution. `builder:` is inside the same
`Localizations` and additionally wraps the navigator, so it covers every route.

The plan's note about a test that pumps the shell directly leaving the resolved locale
null is unchanged and is asserted: `null` means no text is built and nothing is
scheduled, which is right for a tree that is not the app.

### 3. The plan's `grep -rn "doses_v" lib/` criterion reports 5 lines, not 1

All four extra matches are the **ARB `@`-metadata descriptions and their generated doc
comments**, both written by 07-01 and both prose about the id rather than a second
version of it. The property the criterion is about holds: exactly one declaration,
`notification_constants.dart:21`, and no second version anywhere in code. This is the
same class of criterion inaccuracy 07-01 recorded as its deviation 6.

Likewise `grep -rnE "(^|[^A-Za-z])DateTime\.now" lib/core/notifications/` reports **2
lines**, both inside the doc comment that explains why a bare wall-clock read is
forbidden. The real property is now a **named test** that strips comments first and
scans every file in the directory.

### 4. `grep -c "AppLifecycleListener" == 1` is unachievable

A listener that is held in order to be disposed needs a typed nullable field, so the type
name appears twice — the declaration and the construction. `today_controller.dart` has
exactly the same two. The gate counts **constructions** (`AppLifecycleListener\(`)
instead, which is the property the criterion was reaching for.

### 5. The disposal test cannot carry its own claim, and now says so

The plan asks for "a disposal test that proves the listener does not outlive the
container". Written, run — and then **deleting the disposal left it green**. The reason is
structural: `_onResume` returns immediately on an unmounted ref, so from the outside a
leaked listener is indistinguishable from a disposed one.

Resolved by splitting the claim honestly. The behavioural test was renamed to what it
actually proves — a resume after disposal is inert and throws nothing, which requires
*either* the disposal *or* the guard, and both are present — and a **source gate** now
extracts the `ref.onDispose` callback and asserts it disposes the listener. That gate was
shown red against the same mutation. The behavioural test's own comment records that it
was tried and could not carry the claim.

### 6. "A second application issues zero platform calls" is asserted as zero MUTATING calls

Read literally the criterion is unsatisfiable: knowing the difference is empty requires
asking the platform what it holds. The test asserts the exact call list is
`[isEnabled, pending]` and that the schedule/cancel list is empty — which is stronger
than a count, and states plainly that the two reads are what make the emptiness knowable.

### 7. The past-instant case is tested through a seam that mimics the adapter, not a throwing one

The plan wants "a one-shot whose instant has already passed does not abort the rest of the
batch". The mechanism that implements this in the shipped tree is 07-01's adapter, which
**returns early** for a past instant rather than throwing. The recorder mimics that shape
exactly (a skip set), and the test asserts the rest of the batch still went out. No
per-call guard was added to the sync — that would be a second copy of the seam's own rule.
The whole application is guarded instead, so a seam that *did* throw is reported and the
next trigger re-derives; `reconcile` makes that self-correcting.

### 8. The recorded rebuild cost was understated in the plan

The plan says watching the sync costs "one rebuild when the bootstrap flag flips". True of
the flag; not of the sync, whose state is a count — so the root widget also rebuilds once
per completed application. Corrected in the comment (`afbe00f`) with what an application
costs, rather than leaving a number a reader would find wrong the first time they measured
it. `ref.listen` would avoid the rebuilds entirely, and was **not** taken: if it did not
keep the provider alive the whole feature would be silently dead in production with every
test still green, and that risk is not worth a handful of MaterialApp rebuilds a day over
a `const` shell.

## Two real findings the tests surfaced

Both were found by a test going red for a reason I did not predict, and both are worth
more than the tests that found them.

### `DateFormat.Hm(locale)` throws unless that locale's formatting symbols are loaded

The sync's first green-path test failed with `LocaleDataException: Locale data has not
been initialized`. In the app this never happens, and not by luck: the resolved locale is
only ever reported by a tree that has **already** loaded that locale's material
localizations, and loading them is exactly what initializes the symbols. But it is an
invisible coupling — it would break the day the global localizations delegate left the
delegate list, and the sync's guard would then turn every reminder into a crash report
rather than a crash. Named in the helper's doc; container tests load the symbols
themselves.

### A debounce test that never elapses time proves nothing

The first version of the debounce test passed against a `Duration.zero` debounce. Two
independent reasons, both worth knowing:

1. **Riverpod collapses an equal re-emission.** Re-emitting the *identical* `List`
   instance produces an equal `AsyncData` and no listener fires at all — so the burst was
   never a burst. The test now emits fresh lists, which is what a Drift query does.
2. **`tester.pump()` with no duration advances no clock**, so no timer of any length
   fires. The gaps between emissions are now real elapsed time inside the window, and the
   test additionally asserts the count is still unchanged *before* the window closes.

Mutating the delay to `Duration.zero` now yields `Expected: <1> / Actual: <4>`.

## What was NOT verified

Stated plainly, because each is a real limit on what the green suite above proves.

1. **Nothing ran on a device or a simulator.** No reminder was delivered, no lock screen
   was read, no Android channel row was opened in system settings. Every platform fact in
   this plan rests on 07-01's wire test and on the seam contract. The UI contract's three
   backstop statements (§12) remain unexercised, and the length budgets are character
   counts, not measured rendering at the largest system text size.
2. **No iOS or Android build was run.** This plan touches no platform file, no `pubspec`
   and no plugin, so a build could not have been affected — but it was not run, and the
   phase's build evidence is still 07-01's.
3. **The plugin's own behaviour for a repeat is still assumed.** That the platform
   computes a promoted minute's first fire from `matchDateTimeComponents: time` is
   07-01's wire assertion and research §5.5; this plan schedules through it for the first
   time but verifies only that the seam was called correctly.
4. **The zone-before-apply ORDERING could not be shown red by a mutation.** Requesting
   the sync before the zone read still applies against the new zone, because the debounce
   window (300ms) dominates a zone read that resolves in a microtask. The statement order
   is correct and the read is `await`ed before `_request()`, but a hypothetical zone read
   slower than the debounce window would break the ordering and no test would notice.
5. **The midnight rollover is driven by a test double, not by the real timer.** The
   trigger test calls `rollTo` on a `TodayController` subclass. The real midnight timer,
   its re-arm and its DST safety are `today_provider_test.dart`'s claims, not this
   plan's; what is proven here is that a change in `todayProvider` produces exactly one
   application.
6. **The debounce delay is a judgement, not a measurement.** 300ms was chosen to swallow
   a save's stream fan-out and stay imperceptible. No measurement of a real Drift save's
   emission spacing was taken.

## Known Stubs

None. Every symbol this plan adds has a production caller: the copy layer is called by
the sync and by the bootstrap, the resolved locale is written by the observer mounted in
`main.dart` and read by both, and the sync is kept alive by the root app widget.

`reconcile` and the tier-A path, which 07-02 recorded as having no production caller,
now have one.

## Threat Flags

None. No security-relevant surface appeared beyond the plan's `<threat_model>`. Every
mitigation it names is now a named test:

- **T-07-18** (a supplement name on a lock screen) — the copy layer takes a count and a
  minute; a source gate asserts neither it nor the sync can reach `SupplementRepository`,
  `stackEntriesProvider` or `supplementsStreamProvider`, and the copy file additionally
  contains no `.name` at all.
- **T-07-19** (an over-budget body truncating away its count) — both budgets asserted over
  `AppLocalizations.supportedLocales`, and shown red at 29 > 24.
- **T-07-20** (notifications in a language the app no longer shows) — the resolved locale
  is a listened trigger, the channel refresh rides the same signal, and the test asserts
  the re-armed title is the new language's.
- **T-07-21** (a permission-denied device generating failing calls) — one enabled check,
  zero mutating calls for both `false` and `null`, shown red against a mutation.
- **T-07-22** (a save fanning out) — the debounce, with a named delay and a stated reason,
  shown red at `Duration.zero`.
- **T-07-23** (scheduling against a stale zone) — the zone is re-read on every resume and
  set before anything is applied; the test asserts the scheduled INSTANTS moved (offset
  `-4h`), not merely that the location was set.
- **T-07-24** (building an instant before the database is loaded) — the bootstrap flag is
  the sync's first read, and a test proves nothing at all is called while it is false.
- **T-07-25** (the channel id re-versioned to relocalize) — one declaration, one writer,
  and the refresh test asserts the copy changed with the id untouched.
- **T-07-SC** — no install task existed; `git diff --quiet -- pubspec.yaml pubspec.lock`
  succeeds.

## Notes for the next plans

- **Plan 07-05 (the settings row):** `notificationSchedulerProvider` already exposes
  `isEnabled()` and `openSystemSettings()`. Read them from the row and nowhere else —
  DECIDED-9a amends the zero-visual-difference invariant to permit exactly one call site
  under `lib/features/`.
- **The permission ask (NOTIF-03):** granting permission is a seventh trigger the sync
  does not currently have. It is not in this plan's trigger list and the sync will not
  re-derive on a grant until the next save, day rollover, resume or language change. If
  the ask lands in a later plan, `notificationSyncProvider`'s notifier needs a public
  request method, or the grant needs to flip a provider the sync already listens to.
- **`test/notifications/recording_scheduler.dart`** is the shared seam double: it records
  every call with its arguments, can answer `isEnabled` with all three states, can hold a
  pending set, and can mimic the adapter's past-instant skip. Prefer extending it over
  writing a fourth recorder.
- **`deviceZoneReaderProvider`** is the seam to override for anything that needs the
  device zone; `timeZoneLoaderProvider` still gates the bootstrap.

## Self-Check: PASSED

- All six created files exist on disk, and all three modified `lib/` files carry the new
  symbols (`notificationLocaleProvider`, `notificationSyncProvider`,
  `deviceZoneReaderProvider`, `setLocalZoneIfChanged`).
- All four commits resolve in `git log`: `80873e7`, `efd2d9d`, `b72b5a6`, `afbe00f`.
- `flutter analyze` clean and `flutter test` 973 passing at the recorded HEAD, over two
  consecutive full runs.
- The whole-plan diff (`git diff main..HEAD`) was read end to end. No mutation residue:
  `DateFormat.Hm`, the bootstrap-flag read, the enabled gate, `notificationSyncDebounce`,
  the cancels-before-schedules loop, `_lifecycle?.dispose()` and `setLocalZoneIfChanged`
  are all present in `lib/`. `git status` is clean apart from this summary.
