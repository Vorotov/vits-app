---
phase: 07-dose-reminders
plan: 03
subsystem: notifications
status: complete
tags: [notifications, routing, shell, riverpod, cold-start]
requires:
  - lib/core/notifications/notification_constants.dart (isKnownNotificationPayload, doseTapPayload, todayTabIndex)
  - lib/core/notifications/notification_scheduler.dart (launchPayload, initialize's onTap)
  - lib/core/notifications/notification_providers.dart (NotificationBootstrap, as plan 07-01 left it)
  - lib/features/calendar/calendar_providers.dart (selectedDayProvider.followToday)
provides:
  - selectedTabProvider (the shell's destination, app-lifetime and writable from outside the widget)
  - initialTabIndexProvider + launchNotificationPayloadProvider (the frame-1 launch seed)
  - notificationTapProvider (the warm tap report the plugin callback writes)
  - the COUNTED gate over the pre-runApp window (test/notifications/notification_routing_test.dart)
affects:
  - lib/app_shell.dart (stateful -> consumer; the two-effect tap handler)
  - lib/main.dart (one guarded launch read, one added override)
tech-stack:
  added: []
  patterns:
    - a frame-1 seed provider read ONCE (never watched) so a launch answer cannot arrive mid-session
    - taps modelled as EVENTS (payload + sequence) rather than as a setting, so a repeat tap is not swallowed
    - two gates over one window with one owner each — a needle gate (what may never be there) and a counted gate (how much may be)
key-files:
  created:
    - lib/core/selected_tab_controller.dart
    - test/core/selected_tab_controller_test.dart
    - test/notifications/notification_routing_test.dart
  modified:
    - lib/app_shell.dart
    - lib/core/notifications/notification_providers.dart
    - lib/main.dart
decisions:
  - The tap report carries a SEQUENCE alongside the payload, with value equality over both. A bare String? makes two consecutive taps compare equal, so no listener fires and the second tap leaves the user on a past day.
  - The launch seed provider holds the raw PAYLOAD, not a pre-resolved index, because the plan's own frame-1 tests for an unknown payload are only observable if the payload passes through the provider — and because it is what makes the cold and warm paths share one predicate.
  - The launch read is a named top-level function below main(), so the pre-runApp window holds the READ while the plugin adapter's construction stays out of it (07-01's needle gate forbids the construction there).
  - Validation happens at the ONE place that acts on the payload (AppShell), not also in the plugin callback: two copies of a security control is how the copies come to disagree.
metrics:
  duration: one session (resumed once after a session limit)
  completed: 2026-08-17
  tasks: 3
  commits: 3
actuals:
  tokens: 61000
  tasks: 3
  commits: 3
---

# Phase 7 Plan 03: Tap Routing Summary

A tapped reminder now reaches Сьогодні from both doors — warm, and on the first
painted frame from cold — and it returns the browsed day to today on the way, so
the reminder never points at a day the user is not looking at.

## What was built

| Task | What | Commit |
| ---- | ---- | ------ |
| 1 | `selectedTabProvider` + its read-once seed; `AppShell` converted from stateful to consumer with everything else byte-for-byte | `4f70a02` |
| 2 | The tap-report notifier, the plugin callback reduced to one line, and the two-effect handler in the shell | `9948ba1` |
| 3 | The guarded launch read in `main()`, the payload-derived seed, the frame-1 guarantee and the COUNTED window gate | `6d26a65` |

## Verification

- `flutter analyze` — clean at every commit and at HEAD.
- `flutter test` — **899 passing** (880 baseline + 19 new), zero tests deleted,
  two consecutive full runs green.
- **Zero existing test files edited.** `app_shell_test.dart`,
  `shell_invariants_test.dart`, `bq_add_fab_test.dart` and
  `planner_screen_test.dart` all pass untouched — the plan predicted this for
  the last two and it held for all four. Both accessibility assertions in
  `app_shell_test.dart` (semantics activation, and re-activating the selected
  destination being a no-op) pass unedited.
- `git diff --stat` over the whole plan is empty for
  `test/notifications/notification_bootstrap_test.dart`, `lib/features/`,
  `lib/core/theme/`, `lib/core/widgets/`, `android/`, `ios/`, `pubspec.yaml`
  and `pubspec.lock`.
- `grep -c setState lib/app_shell.dart` → 0; `StatefulWidget` → 0;
  `TickerMode(` → 1; the three destination screen constructors → 3.
- The forbidden navigation/modal calls grep over
  `notification_providers.dart` → 0.

### Red-then-green evidence

| Behaviour | The failure actually seen first |
| --- | --- |
| The tab notifier | `Error when reading 'lib/core/selected_tab_controller.dart': No such file or directory` / `Undefined name 'selectedTabProvider'` |
| The warm tap | `Undefined name 'notificationTapProvider'` |
| The cold seed | `Undefined name 'launchNotificationPayloadProvider'` |

### Gates proven to bite, not merely written

Every gate this plan adds was shown red against a deliberate mutation, then the
mutation reverted:

| Mutation | What went red |
| --- | --- |
| `ref.read` → `ref.watch` on the seed | `Expected: <0> / Actual: <2>` — a re-resolved seed yanked the tab mid-session |
| drop `followToday()` from the handler | `Expected: null / Actual: DateTime:<2026-08-14>` |
| drop the whitelist check | `Expected: <0> / Actual: <1>`, on BOTH the unknown-payload and the null-payload cases |
| drop the tap sequence increment | `Expected: null / Actual: DateTime:<2026-08-15>` — the second tap was swallowed |
| add a third `await` to the pre-`runApp` window | `Expected: <2> / Actual: <3>`, with the message naming FLAG-3, both permitted awaits and what a third would cost |
| a seed that ignores the launch payload | `Found 0 widgets with text "Today"` on frame one, and the warm/cold parity test `Expected: <1> / Actual: <0>` |
| remove the guard around the launch read | the degradation test went red (`+13 -1 … [E]`) and the run then WEDGED — the same shape 07-01 recorded for its analogous mutation, and the exact locked history this guard exists for |

## Deviations from the plan

### 1. The tap report carries a SEQUENCE — the plan says it holds "the last reported payload"

A bare `String?` is wrong, and the failure is silent. `ref.listen` fires on
change, so two consecutive taps carrying the same token compare equal and notify
nobody. A user who taps a reminder, lands on Сьогодні, browses back to Monday and
then taps the next reminder would stay on Monday — the precise defect DECIDED-10
exists to prevent, reintroduced through the back door.

The state is therefore a small value type holding the payload AND a tap count,
with value equality deliberately written over both rather than left as identity:
identity would make it work by accident of allocation, and the next editor who
adds a `copyWith` or an equality would break repeat taps with every test still
green. A test drives two taps with a browse in between; dropping the increment
turns it red.

### 2. The launch seed provider holds a PAYLOAD, and so this file does know one notification constant

Task 1 says the seed exists "so the cold-start path in task 3 can supply an answer
without this file knowing anything about notifications" — but task 3 requires
frame-1 tests for a **null** and an **unknown** payload, and neither is observable
unless the payload itself passes through the provider. A pre-resolved index would
move the whitelist into `main()`, where no test can reach it.

The plan's own artifact list already says this file holds "the overridable
**launch-payload** provider" (line 58), so the two halves of the plan disagree and
the artifact list is the half that is testable. Resolution: the payload provider
lives here and the seed derives the index through `isKnownNotificationPayload`.
The import reached is `notification_constants.dart`, which imports nothing at all
— a pure value, not the notification machinery, and `core` still never touches
`features`.

### 3. The launch read is a named function below `main()`, because two of this phase's rules collide

FLAG-3 permits the launch-details read in the pre-`runApp` window. 07-01's needle
gate forbids the string `PluginNotificationScheduler(` anywhere in that window.
The read cannot happen without that adapter. Both rules are right and the plan
does not mention the collision.

Resolved by putting the READ in the window (`await _launchNotificationPayload()`)
and the CONSTRUCTION in a named top-level function below it. That is honest to
what the needle protects — its own stated reason is that constructing the adapter
there "would make its `initialize()` the next thing anyone adds", and this
function asks one question and returns, initializing nothing and creating no
channel. It is nonetheless a textual gap in that gate, recorded here rather than
left for a reviewer to find. **07-01's gate file was not edited**, which was the
non-negotiable part.

### 4. One test assertion was wrong, not the code (the pushed-route case)

The DECIDED-11 case first asserted the offstage nav bar's `selectedIndex` and
failed `Expected: <1> / Actual: <0>` — while the state was already correct.
Flutter does not rebuild a subtree that is offstage under an opaque route, so the
bar under the pushed Settings route still carries the index it was built with.

The assertion now reads the container while the route is up, then pops the route
and asserts the render. That states DECIDED-11's accepted cost explicitly — "the
right place, just later" — instead of asserting a repaint the framework
deliberately defers. Verified by a scratch probe that printed the provider (1),
the bar before the pop (0) and the bar after it (1).

### 5. `test/notifications/notification_bootstrap_test.dart` needed no change at all

Recorded because the plan asks for it by name: 07-01's needle gate is green with
`git diff --stat` **empty**. The counted gate this plan adds lives in
`notification_routing_test.dart` beside the frame-1 guarantee, and the two do not
contradict each other — one says what may never be in the window, the other says
how much may be.

## What could NOT be verified

- **No device cold-start check was run.** The frame-1 guarantee is asserted by a
  single unsettled `pumpWidget` in a host test, which is what makes it a frame
  COUNT rather than a wall-clock claim — the same standard the existing
  cold-start guarantee uses. Whether a real launch-from-tap on the Android
  emulator or the iOS simulator visibly opens on Сьогодні is untested here; the
  plan asked for a measured number only if something extra joined the window,
  and nothing did.
- **The plugin's own tap delivery is untested**, by design. Every routing test
  drives the notifier directly with the scheduler seam at its no-op default. What
  is proven is that the plugin's callback contains one line and that the line
  calls the same mutator the tests call; that a real `onDidReceiveNotification
  Response` fires at all remains 07-01's wire test's claim, not this plan's.
- **`getNotificationAppLaunchDetails()` returning a real payload** is likewise
  never exercised against the platform — only the seam's answer is. The failing
  path IS exercised end-to-end through the real `main()`.

## Known Stubs

None. Both halves of NOTIF-01's routing — the warm tap and the cold launch — are
wired to real state that the shell renders, with no placeholder values and no
component left waiting for a data source.

## Threat Flags

None. No security-relevant surface appeared beyond the plan's `<threat_model>`.
Two of its mitigations are now stronger than planned:

- **T-07-13** — the whitelist is applied at the single point of effect and is
  shown red against a mutation that removes it, on both the unknown-payload and
  the null-payload cases.
- **T-07-15** — the counted gate's failure message names FLAG-3, both permitted
  awaits and the cost of a third, and was shown red against an injected await.

## Notes for the next plans

- `selectedTabProvider` is the single writer of the shell's destination. If a
  later plan needs to open a destination (a settings deep link, a widget tap), it
  writes through the notifier — not through a new piece of shell state.
- `launchNotificationPayloadProvider` is the seam to override for any test that
  needs a launch-from-tap; `initialTabIndexProvider` is the seam for a launch
  destination that has nothing to do with notifications.
- **The pre-`runApp` window is now full.** Two awaits, both with a frame-1
  dependency, and a counted gate that fails on a third. Anything a later plan
  wants to do at launch belongs in the post-first-frame bootstrap 07-01 built.
- The `NotificationTap` value type is where a richer payload would land if a
  later phase ever carries more than one token — but DECIDED-13 says it should
  not, and the single-equality whitelist is what keeps a dose time out of a
  string the OS persists.

## Self-Check: PASSED

All three created files and all three modified files exist on disk; all three
task commits (`4f70a02`, `9948ba1`, `6d26a65`) resolve in `git log`;
`flutter analyze` clean and `flutter test` 899 passing at the recorded HEAD.
