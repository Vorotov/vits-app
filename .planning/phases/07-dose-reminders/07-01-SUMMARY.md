---
phase: 07-dose-reminders
plan: 01
subsystem: notifications
status: complete
tags: [notifications, timezone, platform-config, tracer, l10n]
requires:
  - lib/core/domain/cycle_math.dart (isActiveOn, dateOnly)
  - lib/core/domain/models.dart (Regimen, DoseSlot)
  - lib/core/l10n/gen/app_localizations.dart (lookupAppLocalizations)
provides:
  - lib/core/notifications/ (constants, tz boundary, pure plan, seam, plugin adapter, providers)
  - notificationSchedulerProvider (the seam every later plan mocks)
  - notificationBootstrapProvider (the readiness precondition every later plan reads)
  - timeZoneLoaderProvider (the injectable device-zone read)
  - four ARB keys in both locales
affects:
  - lib/main.dart (two lazy overrides; locale observation; nothing added before runApp)
  - android/app/build.gradle.kts, android/app/src/main/AndroidManifest.xml
  - ios/Runner/AppDelegate.swift
  - test/platform_config_test.dart, test/l10n/no_hardcoded_strings_test.dart
  - test/l10n/cold_start_degradation_test.dart (see deviation 1)
tech-stack:
  added:
    - flutter_local_notifications ^22.3.0
    - timezone ^0.11.1
    - flutter_timezone ^5.1.0
    - com.android.tools:desugar_jdk_libs:2.1.4 (Gradle, core-library desugaring)
  patterns:
    - the fourth mockable interface in the codebase, defaulting to a NO-OP rather than a throw
    - platform-channel reads injected as providers with an inert default, so a bare container reaches no plugin
    - source gates over native config and over the pre-runApp window, needle-based, never count-based
key-files:
  created:
    - lib/core/notifications/notification_constants.dart
    - lib/core/notifications/tz_conversion.dart
    - lib/core/notifications/notification_plan.dart
    - lib/core/notifications/notification_scheduler.dart
    - lib/core/notifications/notification_service.dart
    - lib/core/notifications/notification_providers.dart
    - test/notifications/tz_conversion_test.dart
    - test/notifications/notification_plan_test.dart
    - test/notifications/notification_channel_payload_test.dart
    - test/notifications/notification_bootstrap_test.dart
  modified:
    - pubspec.yaml, pubspec.lock
    - android/app/build.gradle.kts
    - android/app/src/main/AndroidManifest.xml
    - ios/Runner/AppDelegate.swift
    - lib/main.dart
    - lib/core/l10n/arb/app_en.arb, lib/core/l10n/arb/app_uk.arb
    - test/platform_config_test.dart
    - test/l10n/no_hardcoded_strings_test.dart
    - test/l10n/cold_start_degradation_test.dart
decisions:
  - The notification bootstrap absorbs its own failures and leaves the readiness flag false; without that catch a plugin-less environment kills the launch path with an unhandled LateInitializationError.
  - The timezone load is injected through a provider whose default is null ("nothing to bootstrap"), for the same reason the scheduler defaults to a no-op — otherwise every existing widget test reaches a platform channel.
  - The notification locale is OBSERVED from MaterialApp.builder rather than re-derived, so no second copy of MaterialApp's resolution rule enters lib/.
  - No time-formatting helper was built: the seam takes rendered title/body, so DECIDED-5's DateFormat.Hm helper belongs with the copy/sync layer of a later plan.
metrics:
  duration: one session
  completed: 2026-08-17
  tasks: 3
  commits: 4
actuals:
  tokens: 35000
  tasks: 3
  commits: 4
---

# Phase 7 Plan 01: Notification Tracer Summary

The whole notification architecture is proven end to end on one commit sequence: both platforms build with the three new packages, the pure plan produces the right set of instants, the plugin sits behind a mockable seam that nothing but `main()` bypasses, and a real `zonedSchedule` crosses the platform channel with every platform-side fact asserted against the captured argument map.

## What was built

| Task | What | Commit |
| ---- | ---- | ------ |
| 1 | Three packages; core-library desugaring; the manifest's one permission and two receivers; the iOS delegate; the platform-config gate asserting the DECLARED permission set by equality | `200a433` |
| 2 | The pure half: constants, the `instantFor` timezone boundary, `planNotifications`, `notificationIdFor`; the value-and-path-scoped allowlist entry | `e07bfa4` |
| 3 | The seam, the plugin adapter, the providers, the FLAG-3-legal bootstrap, four ARB keys, the wire test and the needle gate | `4063fbb` |

## Verification

- `flutter build ios --simulator` — green BEFORE any change (18.7s), green after task 1 (14.4s), green after task 3 (8.4s). Research assumption A5 is retired in the tree that ships.
- `flutter build apk --debug` — green with desugaring enabled (25.1s, then 6.6s).
- `flutter analyze` — clean.
- `flutter test` — **880 passing** (797 baseline + 83 new), zero tests deleted, three consecutive full runs green.
- ARB parity and plural gates green and **unmodified**.
- `git diff --stat` over the phase shows nothing added or modified under `lib/core/theme/`, `lib/core/widgets/` or `lib/features/`.

### Gates proven to bite, not merely written

Every source gate this plan adds was shown red before being trusted:

- Injecting `SCHEDULE_EXACT_ALARM` into the main manifest turned BOTH the set-equality assertion and the named-absence assertion red; reverted.
- Adding a throwaway translatable literal under `lib/core/notifications/` was still reported by the classification gate, proving the new allowlist predicate is value-scoped and not path-only; reverted. This is the hand-check the plan prescribed.
- Adding `await initTimeZones()` before `runApp` turned the FLAG-3 needle gate red with the message naming the cost; reverted.

### Red-then-green evidence

| Behaviour | The failure actually seen first |
| --- | --- |
| The timezone boundary | `Error when reading 'lib/core/notifications/tz_conversion.dart': No such file or directory` / `Method not found: 'instantFor'` |
| The pure plan | `The getter 'day' isn't defined for the type 'Object?'` (the return type did not exist yet) |
| The seam and providers | `Error when reading '.../notification_providers.dart': No such file or directory` / `Type 'NotificationScheduler' not found` |
| The string gate's new entry | the classification gate listed `'doses_v1'` and `'today'` under `notification_constants.dart`, and separately `'scheduling a one-shot dose reminder'` once the service existed |
| The Darwin permission flags | `Expected: false / Actual: <null>` — the wire assertion was WRONG, not the code (see below) |
| The bootstrap in a plugin-less host | `LateInitializationError: Field '_instance@760271368' has not been initialized` — research correction C-3, reproduced live |

## Deviations from the plan

### 1. `test/l10n/cold_start_degradation_test.dart` was edited — against an explicit acceptance criterion

The plan requires "**zero existing test files edited by this task**", with the rationale that the no-op default makes it true. The no-op default does its job for every widget test — but that file drives the **real `main()`**, which installs the real overrides on purpose. After this phase the launch path in a plugin-less host reports **three** faults (the preferences store, the device-zone read, the plugin's own instance), and `tester.takeException()` collapses to `Multiple exceptions (3) were detected...` as soon as there is more than one. The test went **flaky**: green in isolation, red in the full suite.

Fixed by collecting reported errors and asserting that the **preferences** failure is among them, rather than asserting the type of whichever exception happened to be last. The test's claim is unchanged and now stated more precisely; the assertion is strictly stronger. The alternative was to stop reporting a real device fault in order to keep a test green, which the UI contract's own error-state row forbids.

Note on evidence: the red-check for this edited assertion was attempted by removing `main()`'s `reportError` — that mutation hung the test run (swallowing the error entirely changes the async shape), so it was abandoned rather than pursued. The assertion is nonetheless specific by construction: it filters to `MissingPluginException` entries and requires one whose context names `SharedPreferences`, and the device-zone failure's context reads `resolving the device time zone`, so it cannot satisfy it.

### 2. The bootstrap gained a `catch` the plan did not specify (Rule 2 — missing critical error handling)

Without it, `scheduler.initialize()` in an environment with no registered plugin throws `LateInitializationError` out of an async void path and takes the launch with it. Reminders are the only thing a bootstrap failure may cost. The readiness flag stays `false`, so nothing downstream can schedule against a half-built platform, and the failure is reported to the crash logger exactly like the preferences store's.

### 3. Two pieces not in the plan's artifact list (both inside files the plan does list)

- **`timeZoneLoaderProvider`** — the timezone load had to be injectable for precisely the reason the scheduler is: `initTimeZones` ends in a platform-channel read, so an un-injected default would make every existing widget test reach a plugin. Its default is `null`, meaning "nothing to bootstrap", which is the honest answer in a bare container.
- **Locale observation in `MaterialApp.builder`** — the bootstrap must write ARB channel copy, which needs a locale. Every way of *deriving* one reproduces `MaterialApp`'s resolution rule, which DECIDED-15 calls the PF-1 defect shape and sign-off condition 23 forbids outright (`basicLocaleListResolution` appears nowhere in `lib/` — verified). Observing the locale the tree is actually rendering is the mechanism those documents specify, and a later plan can promote it into a named resolved-locale provider rather than deleting it.

### 4. No time-formatting helper was built

DECIDED-5 puts the 24-hour `DateFormat.Hm` formatting in one named Dart helper "in the notification service". The seam takes **rendered** `title`/`body` strings, so that helper belongs with the copy/sync layer a later plan owns; building it here would have created a consumer-less function. The plan's stated behaviour — the rendered body at count 3 in Ukrainian is exactly `08:00 · 3 прийоми` — is asserted directly against the ARB, which is what the claim is actually about.

### 5. The allowlist entry covers THREE literals, not two — confirmed, and the count is recorded

UI-SPEC sign-off condition 27 says "exactly two literals". It is **off by one**. The third is `'@mipmap/ic_launcher'`, which is translatable under `\p{L}{2,}` (`mipmap`, `launcher`) and matches no existing predicate. The plan predicted this and it is exactly what happened: the classification gate flagged it the moment `notification_service.dart` existed. The corrected count for the phase is **three in this entry, plus one member added to the existing preferences-key entry in plan 07-05**.

### 6. Four acceptance-criterion greps do not return their stated numbers, though every property holds

All four are the "a doc comment naming the forbidden thing trips its own gate" shape this repository already solved with comment strippers:

| Criterion | Reports | Why | The property |
| --- | --- | --- | --- |
| `git diff -- pubspec.yaml \| grep -c "intl"` → 0 | 2 | unchanged **context** lines mention `intl` | `git diff -U0` restricted to changed lines reports 0 — the locked entry is untouched, and `pubspec.lock` still resolves `intl` 0.20.3 |
| `grep -cE "onDays\|offDays\|RegimenKind"` in the plan → 0 | 3 | **`horizonDays` contains the substring `onDays`** | word-boundary grep reports 0; no part of the cycle formula is restated |
| `grep -c "hashCode"` in the plan → 0 | 1 | the doc comment explaining why Dart's hash is unusable for a persisted cross-process key | comment-stripped grep reports 0 |
| `grep -cE "requestExactAlarmsPermission\|...\|AndroidScheduleMode.exact"` → 0 | 1 | the doc comment naming the two forbidden request methods so nobody adds them | the comment-stripped source gate in the wire test asserts 0 |

Each of these is now a **named test failure** rather than a shell grep: the wire test's `source gates` group strips comments and asserts the real properties.

### 7. One planned assertion was moved, because it is unobservable where the plan put it

The plan lists "all three Darwin `request*Permission` flags are literal `false`" among the wire test's assertions. Under `flutter test` `defaultTargetPlatform` is forced to android, so `initialize()` serializes **only** `AndroidInitializationSettings` and the iOS flags cross no channel at all. The first run reported `Expected: false / Actual: <null>`. They are now a comment-stripped **source gate** — which is what research's Pitfall 1 and UI-SPEC condition 10 asked for in the first place — and a companion test asserts the absence of the key on the wire so the reason the source gate exists is written down where it is needed.

## Known Stubs

| Stub | File | Why it is intentional and who resolves it |
| --- | --- | --- |
| `_handleTap` validates the payload and then does nothing | `lib/core/notifications/notification_providers.dart` | Routing to the Сьогодні tab is plan 07-03's, which also lifts the tab index out of `State`. The whitelist check is here from the first commit deliberately, so no build can ever route on an unvalidated payload. |
| `nextDailyOccurrence` has no production caller | `lib/core/notifications/tz_conversion.dart` | The tier-A repeating optimization lands in plan 07-02. It is written here because it is the other half of the SAME timezone boundary, and splitting one boundary across two waves is how the two halves drift. It is fully tested. |
| `pending`, `cancel`, `requestPermission`, `isEnabled`, `openSystemSettings`, `launchPayload` have no production caller | `lib/core/notifications/notification_scheduler.dart` | The interface IS the architecture (the plan says so explicitly); the reconcile loop, the permission ask and the launch routing arrive in plans 07-02/03/04. All are exercised by tests. |

No stub prevents this plan's goal: the tracer's claim is that the architecture is proven end to end, and a real notification does cross the channel.

## Threat Flags

None. No security-relevant surface appeared beyond the plan's `<threat_model>`. Two of its mitigations are now stronger than planned:

- **T-07-01** — a source gate asserts that neither `notification_plan.dart` nor `notification_service.dart` can reach `SupplementRepository`, `stackEntriesProvider` or `supplementsStreamProvider`, so the capability to learn a supplement name provably does not exist.
- **T-07-02** — the manifest gate asserts the declared permission set by **equality**, in both directions, and was shown red against an injected `SCHEDULE_EXACT_ALARM`.

## Notes for the next plans

- **Plan 07-02** (tier A): `nextDailyOccurrence` and `scheduleDaily` already exist and are asserted on the wire, including `matchDateTimeComponents: 0`. `notificationIdFor(day: null, ...)` derives the tier-A id and provably cannot collide with a one-shot at the same minute. No interface change is needed.
- **Plan 07-03** (routing): the counted-await gate over the pre-`runApp` window is yours alone, and belongs beside the frame-1 guarantee it protects. The needle gate in `notification_bootstrap_test.dart` is deliberately count-free and must not be edited when you add the launch-details read. `launchPayload()` is already on the seam.
- **Plan 07-04/05** (sync, settings row): `notificationBootstrapProvider` is the readiness precondition to gate scheduling on; `timeZoneLoaderProvider` is the seam to override in tests that need the bootstrap to run. The locale observation in `MaterialApp.builder` is the place to promote into a named resolved-locale provider. DECIDED-5's `DateFormat.Hm` helper is unbuilt and is yours.
- **Known upgrade blocker, unchanged from research R-4:** the Android build prints `WARNING: Your app uses the following plugins that apply Kotlin Gradle Plugin (KGP): flutter_timezone. Future versions of Flutter will fail to build...`. A warning, not an error, on both builds.

## Self-Check: PASSED

All ten created files exist on disk; all three task commits resolve in `git log`; `flutter analyze` clean and `flutter test` 880 passing at the recorded HEAD.
