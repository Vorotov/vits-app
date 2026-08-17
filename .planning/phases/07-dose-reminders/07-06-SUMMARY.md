---
phase: 07-dose-reminders
plan: 06
subsystem: notifications
status: complete
tags: [notifications, source-gates, privacy, budget, device-test, uat, security]
requires:
  - lib/core/notifications/ (all ten files, as plans 07-01..07-05 left them)
  - lib/main.dart (the five overrides the device test reproduces)
  - test/notifications/recording_scheduler.dart (the shared seam double — plan 07-04)
  - test/platform_config_test.dart (the two comment-stripping helpers, and the manifest gate this plan extends)
  - test/widget/shell_invariants_test.dart (the glob self-proof and forbidden-symbol-map idiom)
  - integration_test/data03_loop_test.dart (the on-device harness and its two habits)
provides:
  - test/notifications/notification_invariants_test.dart (17 phase-level absence gates)
  - test/notifications/notification_privacy_test.dart (6 behavioural proofs)
  - integration_test/notification_device_test.dart (the automated half of the device pass)
  - .planning/phases/07-dose-reminders/07-UAT.md (the pre-step, the automated half, ten device entries)
affects:
  - test/platform_config_test.dart (one added assertion; every DATA-02 line untouched)
tech-stack:
  added: []
  patterns:
    - a phase-level gate that deliberately DUPLICATES a file-level one, widened from one file to a glob, with the duplication's reason written in the file's own doc
    - a behavioural privacy proof that seeds the forbidden data INTO the container under test, so the leak it forbids is reachable rather than hypothetical
    - a device test whose first assertion is that it is not measuring the no-op, and whose permission check fails naming a pre-step rather than reporting an empty set as a pass
key-files:
  created:
    - test/notifications/notification_invariants_test.dart
    - test/notifications/notification_privacy_test.dart
    - integration_test/notification_device_test.dart
    - .planning/phases/07-dose-reminders/07-UAT.md
  modified:
    - test/platform_config_test.dart
decisions:
  - The comment stripper is COPIED from platform_config_test.dart rather than extracted into a shared helper. Extracting it would mean editing two gate files to share code, which is this codebase's stated way for a gate to stop being one.
  - The payload is asserted as a CONSTANT rather than as a captured field, because the seam has no payload parameter at all — the app cannot vary it. Recorded in the test's doc so the difference from the plan's wording is visible.
  - The device test writes through the real repositories rather than driving the editor's UI. The write is the same object the editor's controller calls, and the sync observes it through the same stream; text finders and scroll positions are exactly the fragility that made the last two device files fail on the device rather than in review.
  - The device regimen is DAILY (promotable to a repeat) at 23:47. A repeat is ordered ahead of every one-shot, so the assertion survives a user's real stack being at the budget; the minute makes an id collision as unlikely as a minute can be.
  - The extended manifest gate asserts INTERNET as a SET equality over variants, after discovering the profile manifest legitimately declares it.
metrics:
  duration: one session
  completed: 2026-08-17
  tasks: 3
  commits: 3
actuals:
  tokens: 19500
  tasks: 3
  commits: 3
---

# Phase 7 Plan 06: The Absence Gates, the Behavioural Proofs and the Device Pass Summary

Every absence this phase promised is now an assertion with a named consequence and
a recorded red message; the two properties that could not be argued structurally —
that no supplement name reaches a lock screen, and that no stack size breaches the
platform ceiling — are proven by driving the real sync; and what only a device can
show is written down specifically enough to execute, with nothing in between
dressed up as a test.

## What was built

| Task | What | Commit |
| ---- | ---- | ------ |
| 1 | `notification_invariants_test.dart` — 17 phase-level absence gates, one group per property, every group proving its glob and stripping comments first | `bafd3ec` |
| 2 | `notification_privacy_test.dart` — the per-name/per-field privacy proof in both languages, the end-to-end budget proof, the repeat-survival proof, the soft-delete case; plus one added assertion in `platform_config_test.dart` | `3b1d9b4` |
| 3 | `notification_device_test.dart` and `07-UAT.md` — the automated half, written so it cannot pass without measuring, and the device list | `7c91f4b` |

## Verification

- `flutter analyze` — clean, at every commit and at HEAD.
- `flutter test` — **1037 passing** (1013 baseline + 24 new), zero tests deleted,
  zero tests edited. The 24 are 17 gates, 6 behavioural proofs and 1 manifest
  assertion.
- `git diff --quiet main..HEAD -- pubspec.yaml pubspec.lock` — succeeds.
- `git diff --stat main..HEAD -- lib/ android/ ios/` — **empty**. This plan adds
  no production code at all, and every mutation below was reverted to the byte.
- The whole-plan diff is five files: four added, one modified.

### Every gate shown red by a deliberate mutation, and the mutation reverted

The house rule this plan was written to satisfy: a gate that cannot be made to
fail is not a gate. Each mutation below was applied, the named test run, the exact
failure recorded, and the mutation reverted immediately.

| # | Mutation | The test that went red, and what it said |
| - | --- | --- |
| 1 | `BqSpace.md` read from `notification_constants.dart` | "no file under lib/core/notifications/ reads a design token" — `Expected: empty / Actual: ['lib/core/notifications/notification_constants.dart reads BqSpace. (a spacing token — this phase lays out nothing at all)']` |
| 2 | (same edit) an import of `core/theme/` | "no file under lib/core/notifications/ imports the theme" — `Expected: empty / Actual: ['lib/core/notifications/notification_constants.dart']` |
| 3 | (same edit) an import of the plugin | "exactly one file under lib/ imports the plugin" — `Expected: ['…/notification_service.dart'] / Actual: ['…/notification_constants.dart', '…/notification_service.dart']` |
| 4 | a new `lib/features/settings/notification_row.dart` | "no file under lib/features/ is a notification file" — `Expected: empty / Actual: ['lib/features/settings/notification_row.dart']` |
| 5 | `l10n.doseReminderTitle` read in the Settings screen | BOTH ARB-key gates — `Actual: ['lib/features/settings/settings_screen.dart names doseReminderTitle']` |
| 6 | **the plan's mandated vacuity check** — a local named `areNotificationsEnabled` in the Settings reminders row | "none of the five plugin primitives resolves under lib/features/" — `Expected: empty / Actual: ['lib/features/settings/settings_screen.dart reaches areNotificationsEnabled (the Android enabled check)']` |
| 7 | `visibility: NotificationVisibility.private` removed from `_details()` | the visibility count gate — `Expected: <1> / Actual: <0> … Detail objects: 1, private visibility: 0.` |
| 8 | `DarwinNotificationDetails(badgeNumber: 1)` | the chrome gate — `Actual: ['…/notification_service.dart sets badgeNumber — …a persistent nagging surface…']` |
| 9 | `color: null` on the Android details | the accent-colour gate — `Expected: empty / Actual: ['lib/core/notifications/notification_service.dart']` |
| 10 | `requestAlertPermission: false` → `true` | the Darwin flags gate — `Expected: <1> / Actual: <0>`, with the message naming the launch-time prompt and the lost second chance |
| 11 | live calls to `cancelAll`, `requestExactAlarmsPermission`, `requestFullScreenIntentPermission`, and a `basicLocaleListResolution` call in `main.dart` | the forbidden-four gate — all four offenders listed in one message, each with its own consequence |
| 12 | the scheduler override deleted from `main.dart` | "main.dart INSTALLS the scheduler override" — `Expected: true / Actual: <false>` |
| 13 | `notificationTitle` appends `Ашваганда-QX7` | the privacy proof, in **both** languages — `the TITLE of the reminder at 480 carries the supplement name "Ашваганда-QX7": "Час прийому Ашваганда-QX7"` / `"Time for your doses Ашваганда-QX7"` |
| 14 | `notificationBody` appends `Rhodiola-ZK2` (title mutation reverted first, so the BODY assertion is the one observed) | `the BODY of the reminder at 480 carries the supplement name "Rhodiola-ZK2": "08:00 · 1 прийом Rhodiola-ZK2"` / `"08:00 · 1 dose Rhodiola-ZK2"` |
| 15 | the sync's `budget: notificationBudget` → `1000000` | the end-to-end budget proof — `Expected: a value less than or equal to <60> / Actual: <794>` |
| 16 | the budget truncated from the FRONT instead of the tail | the repeat-survival proof — `Expected: Set:[1992733382, 1175922935] / Actual: Set:[]` |
| 17 | `reconcile` rule 3 disabled | the soft-delete case — `Expected: Set:[1177326967, 992773158, 1009550777] / Actual: Set:[]` |
| 18 | `SCHEDULE_EXACT_ALARM` added to the **profile** manifest | the extended manifest gate — `android/app/src/profile/AndroidManifest.xml declares android.permission.SCHEDULE_EXACT_ALARM…`. Note that the two PRE-EXISTING manifest assertions stayed green: both read the `main` variant only. |

Both non-vacuity guards in the privacy proof were also exercised as reasoning
rather than assumed: the call-count floor (`>= 15`) and the reachability
assertion (the five names really are resolvable in the very container under
test) both sit ahead of the loop they protect.

### The two guards in the device test were NOT shown red — stated plainly

`integration_test/notification_device_test.dart` was **not run on any device or
simulator**, by instruction, so neither of its two anti-vacuity guards has been
observed failing. What is known about them:

- Its first assertion is `isA<PluginNotificationScheduler>()` against a provider
  whose default is `NoopNotificationScheduler` — and that the default really is
  the no-op, and that the no-op's `pending()` really is always empty, are
  **already asserted in the host suite** (`notification_bootstrap_test.dart`,
  group "the seam defaults"). So the premise the guard rests on is a checked
  fact; only the guard's own red path is unobserved.
- Its permission check is `expect(enabled, isTrue)` against a `Future<bool?>`,
  which fails for both `false` and `null` — the two states a device without the
  grant can produce. Its failure message names both pre-steps verbatim.
- The file compiles and type-checks: `flutter analyze` is clean over
  `integration_test/` as well as `lib/` and `test/`.

## Deviations from the plan

### 1. The comment stripper is copied, not shared

Task 1's acceptance criterion asks that "the existing helper idiom is used rather
than a new stripper being written". `_stripCodeComments` is **private** to
`test/platform_config_test.dart`, so it cannot be imported. It is copied verbatim,
under the same name, with a doc comment naming its origin and why it was not
extracted: extracting it would mean editing two gate files to share a helper, and
this codebase's own position (`recording_scheduler.dart`, which deliberately
leaves plan 07-01's smaller recorder alone) is that editing a gate to reuse code
is how a gate stops being one. `grep -c "_stripCodeComments"` returns 3 in the new
file, so the criterion's grep is satisfied either way.

### 2. The payload is asserted as a constant, because the seam has no payload

The plan's behaviour list asks that "every captured title, body and payload" be
asserted against each name. **There is no captured payload.** `scheduleOnce` and
`scheduleDaily` take an id, a time, a title and a body — the payload is added
inside the plugin adapter as the single `doseTapPayload` constant, and 07-01's
wire test asserts that exact value crossing the platform channel. The app cannot
vary it per call even if it wanted to.

So the privacy proof asserts the constant against every name (the same claim about
the same bytes), and additionally pins it to its one known token and to the
whitelist that accepts it — so a per-call payload arriving in a future refactor
cannot pass unnoticed. The reason is written in the test's own library doc rather
than only here.

### 3. The `color:` needle is scoped to the notification layer; the other four are app-wide

The plan says the five decided-against chrome settings "appear nowhere". Four of
them (`badgeNumber`, `groupKey`, `threadIdentifier`, `interruptionLevel`) are
plugin-specific names that occur nowhere legitimately, and are gated across the
whole of `lib/`. `color:` is not: it is ordinary and correct in every widget in
the app, so an app-wide needle would flag dozens of legitimate lines and be
deleted within a week. It is scoped to `lib/core/notifications/`, and the scope's
reason is written beside it — a gate whose scope exceeds its stated reason is the
failure shape the Phase 6 review found.

### 4. The device test writes through the repositories rather than through the editor's UI

The plan describes the automated half as driving the app's UI: "add a supplement,
configure a daily regimen with a known time, save it". It writes through
`supplementRepoProvider` and `regimenRepoProvider` instead — the same objects the
editor's own save controller calls, observed by the sync through the same Drift
stream.

The reason is the two habits the plan itself asks this file to inherit. Both were
learned by `data03_loop_test.dart` and `l10n_device_test.dart` failing **on the
device**: a text finder that matched nothing because a populated stack pushed the
card below the fold, and an `ensureVisible` that dragged a visible cell out of a
paged viewport. Every one of those defects was in the UI-driving half, and none of
them was in the assertion the test existed to make. This file's assertion is about
what the operating system is holding; driving the editor's widgets would add the
entire failure surface of the UI to a check that is not about the UI — and I could
not run it to find out. What the editor's own save does is already covered on
device by `data03_loop_test.dart` and in the host suite by
`regimen_editor_test.dart`.

Recorded as a deviation because it is one: this file does not prove that the SAVE
BUTTON schedules a reminder. It proves that a saved regimen is held by the OS.

### 5. The UAT list carries eleven entries, not "the pre-step plus nine"

Task 3's acceptance criterion asks for "the permission pre-step plus nine numbered
entries"; the same task's action block separately asks for an entry on the autumn
one-hour divergence, which is not one of the nine. The list therefore has the
pre-step (0), the automated half (A), the plan's nine (1–9), and the autumn
observation (10). Both instructions are satisfied; neither could be alone.

### 6. `07-UAT.md`'s ceiling entry carries a `result:` already

Entry 9 (the platform's pending-request ceiling) is recorded as an observation
with its result filled in — "not applicable by construction" — rather than left
blank for a human. The plan asks for it to be "a known unknown rather than a
step", and leaving an empty `result:` line on a step nobody can perform is how a
UAT list acquires a permanent unchecked box that everybody learns to ignore.

## A real finding: the profile manifest declares INTERNET

The extension to `test/platform_config_test.dart` was first written to assert
that no variant except `debug` declares `INTERNET`. It went red immediately on
`android/app/src/profile/AndroidManifest.xml`, which declares it — legitimately.
`profile` is one of the Flutter template's two development manifests and the tool
needs the VM-service connection there for exactly the reason `debug` does. **The
assertion was wrong, not the manifest.**

It is now a SET equality (`{debug, profile}`), which is strictly stronger than
what was there before in the way that matters: the two pre-existing assertions
read the `main` variant only, so a permission parked in `profile` was outside
every gate in this repository — as mutation 18 above demonstrates. Recorded here
because it is a fact about the repository that nobody had written down.

## What was NOT verified

Stated plainly, because each is a real limit on what the green suite above proves.

1. **Nothing ran on a device or a simulator.** No reminder was delivered, no lock
   screen was read, no permission dialog was shown, no Android channel row was
   opened. `integration_test/notification_device_test.dart` compiles and
   type-checks and has never executed. Every entry in `07-UAT.md`, including its
   automated half A, is outstanding.
2. **The device test's own two guards are unobserved** — see above. Their premises
   are checked facts; their red paths are not.
3. **No iOS or Android build was run.** This plan touches no platform file, no
   `pubspec` and no `lib/` file, so a build could not have been affected — but it
   was not run, and the phase's build evidence is still plan 07-01's.
4. **The advisory whole-phase diff check was not performed as a command.** The
   name-only diff over the phase's commits under `lib/core/theme/` and
   `lib/core/widgets/` is advisory in the gate file's own doc because the commit
   range is not derivable from inside a test. What IS verified is stronger for
   this plan specifically: its own diff against `main` touches no `lib/` file at
   all.
5. **`STATE.md` and `ROADMAP.md` were not updated**, by instruction, and
   `gsd-tools` was not run — `node` is not available in this executor's
   environment.
6. **The privacy proof cannot exercise a leak through a path that does not
   exist.** The mutation that proved it bites had to INVENT a leak by hardcoding a
   name into the copy layer, because the layer has no parameter through which a
   real name could arrive. That is the point of the structural gate, and it means
   this test's value is entirely prospective: it is what will catch the refactor
   that gives some helper a name to carry.

## Known Stubs

None. Every test this plan adds asserts a property that holds today, and none
carries a placeholder, a skip or a TODO. `07-UAT.md` has empty `result:` lines by
design — it is a checklist awaiting a device pass, which is the artifact the plan
asked for.

## Threat Flags

None. No security-relevant surface appeared beyond the plan's `<threat_model>`.
Every mitigation it names is now a named test:

- **T-07-32** (a name reaching a lock screen in a future refactor) — proven
  behaviourally, per name and per field, in both languages, with the names
  deliberately present and reachable in the container; shown red by a copy layer
  that appends one.
- **T-07-33** (a later detail object without the private visibility) — an EXACT
  count match app-wide, shown red at 1 versus 0.
- **T-07-34** (a privileged alarm request added later) — gated at phase level
  over all of `lib/` in addition to the file-level gate, with the store-policy
  consequence in the message.
- **T-07-35** (a blanket clear reintroduced as a convenience) — gated app-wide
  with its user-visible cost stated; the soft-delete proof separately shows the
  app cancelling by id.
- **T-07-36** (the budget re-expanded downstream) — the number of CALLS bounded,
  not merely the number of planned entries, against a stack 13× the ceiling; plus
  the repeats asserted to survive truncation.
- **T-07-37** (a device claim never actually observed) — the automated half is
  written so that it cannot pass without measuring, and this summary states
  plainly that it has not been run. The unobservable half is a specific written
  list, and the plan is non-autonomous so it cannot be closed without it.
- **T-07-SC** — no install task existed; `git diff --quiet -- pubspec.yaml
  pubspec.lock` succeeds.

## Notes for whoever runs the device pass

- Run order: pre-step 0 (the grant), then entry A on each platform, then the
  manual entries. Entry A fails naming the pre-step if the grant is missing, so an
  accidental skip reports itself.
- Entry A leaves the device as it found it: it creates one supplement, asserts the
  OS holds its reminder, then soft-deletes it and asserts the reminder is gone.
- If entry A times out, its own message lists the three things to check in order,
  and the log will contain the full pending-id set and the on-screen text at the
  moment of the timeout.
- The one documented precondition of entry A's assertion: no other regimen in the
  device's stack may have a dose slot at 23:47 without also running every day.

## Self-Check: PASSED

- All four created files exist on disk, and `test/platform_config_test.dart`
  carries the added assertion.
- All three commits resolve in `git log`: `bafd3ec`, `3b1d9b4`, `7c91f4b`.
- `flutter analyze` clean and `flutter test` 1037 passing at the recorded HEAD.
- The whole-plan diff (`git diff main..HEAD`) was read end to end. **No mutation
  residue:** `git diff --stat main..HEAD -- lib/ android/ ios/` is empty, so every
  one of the eighteen mutations above was reverted to the byte. `git status` is
  clean apart from this summary.
