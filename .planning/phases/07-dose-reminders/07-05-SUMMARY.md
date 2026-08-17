---
phase: 07-dose-reminders
plan: 05
subsystem: notifications
status: complete
tags: [notifications, permission, settings, l10n, lifecycle, riverpod]
requires:
  - lib/core/notifications/notification_scheduler.dart (requestPermission, isEnabled, openSystemSettings — plan 07-01)
  - lib/core/notifications/notification_providers.dart (notificationSchedulerProvider — plan 07-01)
  - lib/core/providers.dart (sharedPreferencesProvider, nullable, throwing default)
  - lib/core/l10n/locale_controller.dart (the untrusted-storage read precedent)
  - lib/core/today_controller.dart (the AppLifecycleListener precedent)
  - lib/core/notifications/notification_sync.dart (the trigger set — plan 07-04)
  - test/notifications/recording_scheduler.dart (the shared seam double — plan 07-04)
provides:
  - lib/core/notifications/notification_permission.dart (NotificationPermission, notificationPermissionProvider, notificationAskedKey)
  - the ask at the regimen editor's save call site (NOTIF-03)
  - the reminders permission section in the Settings screen (NOTIF-05, DECIDED-9a)
  - four ARB keys in both locales
affects:
  - lib/features/stack/regimen_editor_screen.dart (_EditorFooter is now a ConsumerStatefulWidget; one call after the pop)
  - lib/features/settings/settings_screen.dart (three private widgets; no new file under lib/features/)
  - lib/core/notifications/notification_sync.dart (one added listen)
  - test/l10n/no_hardcoded_strings_test.dart (the preferences-key entry, extended by VALUE)
  - test/notifications/recording_scheduler.dart (records two more calls; can be made to throw)
  - .planning/phases/07-dose-reminders/07-UI-SPEC.md (a correction block under DECIDED-7)
tech-stack:
  added: []
  patterns:
    - a three-valued nullable held in an app-lifetime notifier, where the third value means "not yet known" and renders NOTHING rather than a loading surface
    - a notifier that is a TRIGGER for one consumer and a VALUE for another, and therefore does no platform work at build time — the one reader asks when it appears
    - a diagnostic string passed to a helper already wrapped in ErrorDescription, so it sits literally inside the constructor the hardcoded-string gate recognises
    - a NavigatorObserver used to assert ORDER between a pop and a side effect, because maybePop resolves while the exit transition is still running
    - a widget-tree snapshot taken BEFORE a flow and compared after it, so "the app looks identical afterwards" is a claim about the app rather than about two runs agreeing
key-files:
  created:
    - lib/core/notifications/notification_permission.dart
    - test/notifications/notification_permission_test.dart
  modified:
    - lib/core/notifications/notification_sync.dart
    - lib/features/stack/regimen_editor_screen.dart
    - lib/features/settings/settings_screen.dart
    - lib/core/l10n/arb/app_en.arb
    - lib/core/l10n/arb/app_uk.arb
    - lib/core/l10n/gen/* (regenerated)
    - test/features/regimen_editor_test.dart
    - test/features/settings_screen_test.dart
    - test/notifications/notification_sync_test.dart
    - test/notifications/recording_scheduler.dart
    - test/l10n/no_hardcoded_strings_test.dart
    - .planning/phases/07-dose-reminders/07-UI-SPEC.md
decisions:
  - The permission notifier does NOT read the platform at build time. The sync listens to it as a trigger, so an eager read would fire wherever the trigger is wanted; the one reader of the value asks for it when it mounts.
  - The provider is declared beside its notifier rather than in notification_providers.dart, which is this file's own import — the precedent notification_locale.dart set in 07-04.
  - The asked-once flag is recorded even when the request threw. The prompt may already have been shown, and on iOS there is no second one to spend.
  - The prefs read is guarded, because sharedPreferencesProvider's default THROWS. In production main() always installs it, so the guard can only meet the throw in a test container that installed no store — which is the same fact as "no store".
  - The ordering claim is carried by a NavigatorObserver, not by looking for the editor widget: maybePop resolves mid-transition, so the widget is still on screen either way and a widget-presence test would pass with the ask issued first.
metrics:
  duration: one session
  completed: 2026-08-17
  tasks: 3
  commits: 4
actuals:
  tokens: 61000
  tasks: 3
  commits: 4
---

# Phase 7 Plan 05: The Permission Ask and the Settings Row Summary

The app asks for permission at the one moment it means something — after the
write, after the pop, at most once per install — and Settings now states whether
reminders are allowed with the only route back, on a screen whose every existing
gate passes untouched.

## What was built

| Task | What | Commit |
| ---- | ---- | ------ |
| 1 | The permission controller: three states, the once-per-install gate, the resume refresh, the route into the system settings | `5c499c5` |
| 2 | The ask at the save call site, the sync's new trigger, and the FLAG-1 rationale corrected in the code and in the contract | `2881a13` |
| 3 | Four ARB keys and the private reminders section in Settings | `1266656` |
| — | The row's self-correction on a resume, proven end to end | `00e9f7f` |

## Verification

- `flutter analyze` — clean, at every commit and at final HEAD.
- `flutter test` — **1013 passing** (973 baseline + 40 new), **two consecutive
  green full runs**, zero tests deleted.
- **Every pre-existing gate in `test/features/settings_screen_test.dart` passes
  UNMODIFIED.** `git diff` on that file removes not one line (the only `^-` line
  in the diff is the `--- a/…` header). All twelve source gates — the glob, the
  language-code regex, the switch/Map ban, the no-loading-surface list, the
  no-error-surface list, the formatter ban, the alert-token ban, the persistence
  ban, the hex/font-size/icon-size list and the block-comment check — run over
  the new code and pass.
- Same for `test/features/regimen_editor_test.dart`: no deleted `expect(` line,
  every save, failure, pause and delete assertion green as written.
- `git diff --quiet -- pubspec.yaml pubspec.lock` — succeeds.
- `grep -rnE "areNotificationsEnabled|checkPermissions|requestPermissions|requestNotificationsPermission|openAppNotificationSettings" lib/features/` — **nothing**. The controller's public members are `refresh`, `askOnce` and `openSystemSettings`; none contains any of those five substrings. Plan 07-06 can install its standing gate as written.
- `ls lib/features/settings/*.dart | wc -l` — **2**. No new file under `lib/features/`.
- `grep -cE "showDialog|showModalBottomSheet|SnackBar|MaterialBanner|Text\(|BuildContext" lib/core/notifications/notification_permission.dart` — **0**, and asserted as a named source gate rather than only run by hand.
- `grep -cE "drift|Repository|database" lib/core/notifications/notification_permission.dart` — **0**, likewise gated.
- `grep -cE "showDialog|showModalBottomSheet|MaterialBanner" lib/features/stack/regimen_editor_screen.dart` — **1**, identical to its pre-plan value at `8368e41`. The delete confirmation is still the only modal.
- `git diff 8368e41..HEAD -- test/l10n/no_hardcoded_strings_test.dart` touches exactly the `_isPreferencesKey` predicate and the allowlist entry above it. No flagging pattern widened, no path-scoped predicate added.
- `flutter gen-l10n` succeeds; `test/l10n` — 79 passing, ARB parity, plural, copy-safety and hardcoded-string gates green and otherwise unmodified.

### Red-then-green evidence

| Behaviour | The failure actually seen first |
| --- | --- |
| The permission controller | `Error when reading 'lib/core/notifications/notification_permission.dart': No such file or directory` |
| The asked-once key in the allowlist | the gate listed the literal under "a literal carrying words that no category explains" |
| The ask at the save call site | `Expected: ['pop', 'request'] / Actual: []` |
| Exactly one request per install | `Expected: <1> / Actual: <0>` |
| A permission answer as a sync trigger | `Expected: <2> / Actual: <1>` |
| The four ARB keys and the row | 13 compile errors, `The getter 'settingsRemindersTitle' isn't defined for the type 'AppLocalizations'` |

**One case was green before the change and is recorded as a guard rather than as
evidence:** "a FAILED save issues no request at all". Nothing asked before the
call site existed, so it could not go red first. It earns its place as a
regression guard — it is what would catch the ask being moved above the failure
branch — and its claim is proven by the ordering mutation below, which shows the
same code path being observed.

### Gates proven to bite, not merely written

Every claim was checked by breaking the code and watching the named test go red.
Each mutation was reverted immediately and the suite re-run.

| Mutation | What went red |
| --- | --- |
| Delete the asked-once guard in `askOnce` | three tests — second ask, pre-stored flag, and the throwing repeat (`Expected: empty / Actual: [two calls]`) |
| Neuter the controller's resume refresh | the resume test (`Expected: true / Actual: <false>`) AND the Settings self-correction test (`Found 0 widgets with text "Нагадування дозволено"`) |
| Move the ask ahead of `await maybePop()` | the ordering test (`Expected: ['pop','request'] / Actual: ['request','pop']`) |
| Delete the row's `initState` refresh | five Settings cases (`Found 0 widgets with text "НАГАДУВАННЯ"`) |
| Render a placeholder while the answer is unknown | the identity case (`Expected: Set['Налаштування','МОВА','Системна','English','Українська','✓'] / Actual: [… '…']`) |

## Deviations from the plan

### 1. `build()` does NOT kick off a refresh — the one reader does

The plan says the notifier's build "returns unknown and kicks off a refresh". It
returns unknown and asks nothing.

The reason is a conflict the plan could not have seen, because it also asks
(task 2) for the notifier to join the sync's trigger set. Doing both means the
sync builds the notifier, the notifier immediately calls `isEnabled()` on the
seam, and **two existing sync tests whose entire claim is "nothing at all is
called" before the preconditions hold** (`notification_sync_test.dart:242`,
`:260`) would have gone red — for a call the sync did not make, on a
notifier those tests do not know exists. Editing them was not an option and
would have been wrong anyway: the property they assert is real.

Resolved by making the notifier a leaf that does no platform work until asked.
The Settings section — the only reader of the value — requests a fresh answer in
its `initState`, which is also why it is stateful. The argument holds
independently of the tests: the sync already takes its own fresh `isEnabled()`
on every application, so a second read at app start buys nothing and costs a
platform round trip on the launch path.

A new sync test pins the new property directly: **building the sync costs no
permission read of its own.**

### 2. The provider is declared beside its notifier, not in `notification_providers.dart`

The plan says "register the notifier in the providers file". That file is
`notification_permission.dart`'s own import (it holds
`notificationSchedulerProvider`), so declaring the permission provider there
would be an import cycle. `notification_locale.dart` and `notification_sync.dart`
both already declare their own providers for the same reason — the precedent is
07-04's, and this follows it.

### 3. The diagnostic strings are wrapped at the call site, not inside the helper

The four crash-report sentences first sat as bare `String` arguments to a private
`_report` helper. The hardcoded-string gate flagged all four: its diagnostic
category is keyed on the ENCLOSING CALL (`ErrorDescription`,
`FlutterErrorDetails`), and one indirection away from that constructor a sentence
is indistinguishable from unexplained copy. Rather than widen the allowlist —
which the file's own rule forbids and which would have blessed real copy
elsewhere — the helper now takes an `ErrorDescription`, so each sentence sits
literally inside the constructor the gate recognises. The gate was right and the
code was wrong.

### 4. The `sharedPreferencesProvider` read is guarded

The plan's `<read_first>` describes that provider as "the nullable preferences
provider and what a null store means". It is nullable, but its default also
**throws** — deliberately, so a missed harness fails loudly on the launch-path
language read. `askOnce` is reached from the regimen editor, and roughly ten
existing editor tests build no store at all, so an unguarded read would have
turned every one of them red with an `UnimplementedError`, and reporting it would
have tripped their `takeException()` assertions.

The read is therefore wrapped and degrades to "no store", **without** a crash
report. The justification is narrow and written in the code: `main()` always
installs the override (possibly with `null`), so this branch is unreachable in
production; a container that installed no store is the same fact as a store that
could not be opened, which this path already answers with "ask, and accept the
memory is lost".

### 5. The ordering claim needed a NavigatorObserver

The plan asks for the request to be "asserted by observing that the editor is no
longer on screen at the moment the request is recorded". That observation cannot
carry the claim: `Navigator.maybePop()` resolves as soon as the pop is decided,
while the exit transition is still running, so the editor widget is still in the
tree at that moment whether the ask fires before or after the await. A test
written that way passes both ways.

The order is asserted instead against a `NavigatorObserver.didPop`, which is a
real, observable navigator event. Moving the ask ahead of the await flips the
recorded sequence, shown above.

### 6. "The rendered tree is identical" is asserted against the pre-editor tree

The plan asks for the granted and denied trees to be compared with each other.
That form only proves the two runs agree. Each case instead snapshots the whole
widget tree (types plus every rendered string) **before the editor is pushed at
all** and asserts the post-save tree equals it — which is the contract's actual
sentence, "whatever the user answers, the app looks identical afterwards". The
same expectation covers the throwing-request case, so all three states are held
to one standard rather than to three private ones.

### 7. The stale comments in `notification_sync.dart` were corrected

That file's trigger comment counted its listeners ("these four cover every
trigger but one", "resume is the sixth"). Adding a fifth listen made the prose
wrong, so it was rewritten to say what is left over rather than to carry an
arithmetic a later plan will break again. The existing test group name "the six
triggers, one at a time" was left alone — the new case lives in its own group,
because renaming a group is editing a gate.

## What was NOT verified

Stated plainly, because each is a real limit on what the green suite proves.

1. **Nothing ran on a device or a simulator.** No operating-system permission
   dialog was ever shown. Both platforms' prompts are OS surfaces `WidgetTester`
   cannot touch, so **every claim about what the user sees at the prompt rests on
   the seam contract and on 07-RESEARCH §6**, not on observation. The UI
   contract's backstop statement for N2/N6 — "saving the first regimen pops the
   editor and then shows the system prompt over the Stack screen with nothing of
   the app's own before or after it" — remains unexercised.
2. **`openAppNotificationSettings()` was never observed to open anything.** The
   test asserts the seam call; whether Android and iOS actually land the user on
   the app's notification page is 07-01's adapter's claim, and it too has never
   been run on a device.
3. **The asked-once flag has never survived a real process restart.** The tests
   restart the container, not the app. `shared_preferences` durability is
   assumed, exactly as the language override assumes it.
4. **No iOS or Android build was run.** This plan touches no platform file, no
   `pubspec` and no plugin, so a build could not have been affected — but it was
   not run.
5. **The row's "sub-perceptible window" is a judgement, not a measurement.** The
   answer resolves a microtask after the section mounts in a test; no timing was
   measured on a device, where the platform channel round trip is real. If it
   ever became perceptible the section would visibly appear a beat after the
   screen — which is the accepted cost of refusing a loading surface, and is
   recorded in the widget's own doc.
6. **The three-state row was never seen by a human.** Its geometry is asserted at
   text scales 1.0 / 1.6 / 2.0 in both languages with no layout exception, but
   nobody has looked at it beside the language card.
7. **Nothing proves the ask reaches the platform in production.** `main()`
   installs the plugin-backed seam and a source gate from 07-01 asserts that; the
   ask itself is only ever exercised through the double.

## Known Stubs

None. Every symbol this plan adds has a production caller: `askOnce` is called
from the editor's save, `refresh` from the row's `initState` and from the resume
listener, `openSystemSettings` from the row's control, and the provider is read
by the row, the editor and the sync.

## Threat Flags

None. No security-relevant surface appeared beyond the plan's `<threat_model>`.
Every mitigation it names is now a named test:

- **T-07-26** (a repeat prompt on every save) — the persisted flag, with tests
  for the second ask, the pre-stored flag and the two-regimen case, all shown red
  against the deleted guard.
- **T-07-27** (the permission flow blocking or losing a save) — the request is
  issued after the write and after `didPop`, on the success branch only; the
  failed-save case asserts zero calls, and the granted/denied/throwing cases all
  assert the tree equals the pre-editor tree.
- **T-07-28** (the flag read from untrusted storage) — read as an untrusted
  object with its type checked; a wrong type and a missing store are both tested
  and neither throws.
- **T-07-29** (the Settings row leaking schedule detail) — four constant strings,
  swept through the screen's own no-digit and Cyrillic-leak gates in all three
  states and both languages.
- **T-07-30** (a stale row) — the resume refresh, proven end to end in the
  Settings suite and shown red against the neutered listener.
- **T-07-31** (the primitives reachable from feature code) — the grep returns
  nothing, and the controller's own file carries a source gate asserting that no
  member of its API names one of the five primitives.
- **T-07-SC** — no install task existed; `git diff --quiet -- pubspec.yaml
  pubspec.lock` succeeds.

## Notes for the next plans

- **Plan 07-06's standing gate** can be written exactly as the plan states:
  `grep -rnE "areNotificationsEnabled|checkPermissions|requestPermissions|requestNotificationsPermission|openAppNotificationSettings" lib/features/` is empty, and the one call site under `lib/features/` reaches `refresh` / `openSystemSettings` on the controller. A weaker gate would be a mistake: the point is that the invariant holds AS WRITTEN rather than being relaxed.
- **The Settings feature is still exactly two files**, and the suite's own glob
  gate asserts a floor of two. A third file added later is gated the day it
  lands.
- **`RecordingScheduler` now records `requestPermission` and
  `openSystemSettings`**, can be made to throw on the request
  (`requestFailure`), and can run a callback at request time
  (`onRequestPermission`). Prefer extending it over writing another recorder.
- **The permission notifier does no work until asked.** Anything that wants the
  value must call `refresh()`; anything that only wants to know when it changes
  can listen for free.

## Self-Check: PASSED

- Both created files exist on disk; all four commits resolve in `git log`
  (`5c499c5`, `2881a13`, `1266656`, `00e9f7f`).
- `flutter analyze` clean and `flutter test` 1013 passing at the recorded HEAD,
  over two consecutive full runs.
- The whole-plan diff (`git diff 8368e41..HEAD`) was read end to end. No mutation
  residue: `_alreadyAsked()`, `AppLifecycleListener(onResume: () =>
  unawaited(refresh()))`, `unawaited(permission.askOnce())` after the `maybePop`,
  the `initState` refresh and the `SizedBox.shrink()` for the unknown state are
  all present.
- `git status` is clean apart from this summary.
