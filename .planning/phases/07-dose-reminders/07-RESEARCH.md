# Phase 7: Dose Reminders — Research

**Researched:** 2026-08-17
**Domain:** Local (non-push) scheduled notifications on iOS + Android in Flutter
**Confidence:** HIGH on packages, API surface, platform config and testability (all executed or read from the shipped 22.3.0 source this session); MEDIUM on two named runtime behaviours flagged inline.

> **This document does not re-open settled questions.** The two-tier plan, grouping by
> time-of-day, and `inexactAllowWhileIdle` are contract (spec §2). Prior research —
> `docs/research/2026-08-16-notifications-research.md` — is treated as settled and is only
> *corrected* where this session's direct verification found it wrong. Three such corrections
> are called out explicitly in **§10 Corrections to prior research**; the planner must read
> that section.

---

## User Constraints

No `07-CONTEXT.md` exists yet (`/Users/dima/supplements/.planning/phases/07-dose-reminders/` is
empty). The binding constraints therefore come from the approved spec, ROADMAP and CLAUDE.md.

### Locked Decisions (approved spec `docs/superpowers/specs/2026-08-17-boostque-v1.1-design.md` §2)

- **One notification per time-of-day, not per supplement.** Three supplements at 08:00 = one
  notification reading "3 прийоми". Tapping opens the **Сьогодні** tab.
- **Two tiers.** Tier A (repeating, `DateTimeComponents.time`) for times where *every*
  contributing regimen runs daily (`cyclic && offDays == 0`); Tier B (individually scheduled
  instances over a rolling horizon) for everything else.
- **Budget 60 pending requests, horizon 30 days, whichever binds first.** Topped up on every
  app resume via the existing `AppLifecycleListener`.
- **`AndroidScheduleMode.inexactAllowWhileIdle`.** No `SCHEDULE_EXACT_ALARM`, no
  `USE_EXACT_ALARM`. Accepted cost: ~10–15 min jitter while dozing.
- **Fire only on active days** — the same `isActiveOn` predicate. Paused regimens and
  soft-deleted supplements produce nothing.
- **Permission asked at first regimen save**, never at launch. Denied ⇒ app fully functional,
  schedules nothing, no nagging.
- **Three new packages**, all necessary: `flutter_local_notifications`, `timezone`,
  `flutter_timezone`.
- **`POST_NOTIFICATIONS` and `VIBRATE` arrive via the plugin's own manifest and must NOT be
  declared in ours.** The platform-config gate must be extended to cover the new manifest state.
- **`lib/core/notifications/notification_plan.dart` is pure**; `notification_service.dart` is
  the only file importing the plugin.
- **Timezone boundary:** `tz.TZDateTime(tz.local, day.year, day.month, day.day, h, m)` —
  **never** `.toLocal()` on a UTC date-only value.

### Explicitly deferred (spec §2.6, §5 — OUT OF SCOPE)

Notification settings UI (on/off, per-slot vs summary, quiet hours, re-ask path); the
6-slots-per-day cap; app name and bundle id; release signing; home-screen widgets; sync.

### Claude's discretion (not fixed by the spec — planner may decide)

Notification id derivation scheme; reconciliation algorithm shape; debounce strategy; whether
to ship a tail "sentinel" notification (prior research Q2); whether to cancel a reminder for a
dose already marked taken (prior research Q3 — recommended DEFER); the exact ARB keys.

---

## Phase Requirements

| ID | Description | Research support |
|----|-------------|------------------|
| NOTIF-01 | Reminded at each scheduled dose time, grouped per time-of-day, only on active days; tapping opens Сьогодні | §5 API surface (`zonedSchedule`), §8 hook points (`isActiveOn`, `activeRuns`), §8.6 tap→tab routing (requires lifting `AppShell._selectedIndex` into a provider) |
| NOTIF-02 | No exact-alarm permission on Android; within the iOS 64-request cap | §3 verified release manifest delta; §5 `AndroidScheduleMode.inexactAllowWhileIdle`; budget enforced in the pure plan |
| NOTIF-03 | Permission requested at first regimen save; app fully usable when denied | §6 permission mechanics; §8.4 `RegimenEditorController.save()` is the hook |
| NOTIF-04 | Re-derives on regimen change, on resume, across midnight and DST | §8 reschedule triggers; §7 timezone init; §9.3 DST test recipe (verified output) |

---

## Summary

Everything asked for is now verified rather than remembered. I downloaded and read the
**exact `flutter_local_notifications` 22.3.0 source from pub.dev** (not `master`, not the
rendered README — a README summary I fetched first showed a *hybrid of pre-20.x and 22.x call
shapes* and would have cost a wave), resolved the three packages **against this repo's real
`pubspec.yaml`**, and **built both a debug and a release APK** of the real app with all three
packages wired in. The Android release merged manifest was dumped before and after.

Three results dominate the plan:

1. **The whole plugin API is now fully-named.** `zonedSchedule` takes *every* argument by name,
   including `required AndroidScheduleMode androidScheduleMode` **with no default**, and
   `initialize` takes `required InitializationSettings settings`. Any snippet from training
   data, from a blog, or from the plugin's own README's "Scheduling a notification" block
   (which still shows `zonedSchedule(0, ..., const NotificationDetails(...), ...)` — a mix of
   positional and named that **does not compile**) will fail. The correct shapes are in §5,
   quoted from the shipped source.

2. **The plugin is NOT a safe no-op under `flutter test`.** I ran it: every call path reaches
   `FlutterLocalNotificationsPlatform.instance`, which is a `static late` field with **no
   default**, so it throws `LateInitializationError` — not `MissingPluginException`, not a
   silent no-op. The README's "the methods will be mostly no-op" is false for 22.3.0 in a host
   test. This makes the `NotificationScheduler` seam **mandatory**, not stylistic: any widget
   test whose tree touches the service without the seam will explode. There is also a *second*,
   verified path (`registerWith()` + mock method channel) that is excellent for asserting the
   exact platform payload — see §9.

3. **The release-manifest delta is exactly three permissions and no more.** Baseline release
   merged manifest today: one AGP-generated entry. After: `POST_NOTIFICATIONS`, `VIBRATE`
   (both from the plugin's manifest, unavoidable, unprivileged) and `RECEIVE_BOOT_COMPLETED`
   (ours). **No `INTERNET`, no `SCHEDULE_EXACT_ALARM`, no `USE_EXACT_ALARM`.** Both APKs built
   green under AGP 9.1.0 / Gradle 9.3.1 with desugaring enabled.

**Primary recommendation:** add the three packages at the versions in §2; make the Android
gradle + manifest edits in §3 exactly as written (they are the ones I built); write the pure
plan and the `NotificationScheduler` interface first and mock *that* everywhere; put the one
channel-level payload test behind `AndroidFlutterLocalNotificationsPlugin.registerWith()`.

---

## Architectural Responsibility Map

| Capability | Primary tier | Secondary tier | Rationale |
|------------|-------------|----------------|-----------|
| Deciding *which* notifications should exist | Domain (pure Dart, `lib/core/notifications/notification_plan.dart`) | — | Whole correctness surface; must be unit-testable to `cycle_math` standard (spec §2.4). Reads no clock, no `tz`, no plugin. |
| Wall-clock → instant conversion | Adapter (`lib/core/notifications/tz_conversion.dart`) | — | Needs `package:timezone`; keeps the domain free of it. The single inverse of `dateOnly()` in the app. |
| Talking to the OS (schedule/cancel/query/permission) | Platform adapter (`notification_service.dart`) | — | The only file importing the plugin. Behind an abstract `NotificationScheduler`. |
| Deciding *when* to re-derive | Riverpod graph (`core/providers.dart` + a new sync provider) | App lifecycle | Reuses `regimensStreamProvider` / `todayProvider` / `AppLifecycleListener` already in the codebase. |
| Asking for permission | UI/state (`RegimenEditorController.save()` call site) | Platform adapter | Spec §2.5 ties the ask to a user action; the adapter only exposes the primitive. |
| Notification *copy* | l10n (ARB + `lookupAppLocalizations`) | Platform adapter | Text is baked at scheduling time — see Pitfall 7 (locale change). |
| Routing a tap to Сьогодні | App shell (`AppShell`) | Platform adapter | `_selectedIndex` is currently local `State` — must be lifted (§8.6). |

---

## Standard Stack

### Core

| Library | Version | Purpose | Why standard |
|---------|---------|---------|--------------|
| `flutter_local_notifications` | `^22.3.0` | Schedule/cancel/query local notifications on both platforms | Only mature maintained option; verified publisher `dexterx.dev`; BSD-3. `environment: sdk: ^3.10.0, flutter: ">=3.38.1"` — we run Dart 3.13 / Flutter 3.47 ✓ [VERIFIED: /tmp/fln2203/pubspec.yaml, downloaded from pub.dev archive] |
| `timezone` | `^0.11.1` | `TZDateTime`, `getLocation`, tz database | Transitive via the plugin (`timezone: ^0.11.0`), but app code imports it directly — declaring it is required by `depend_on_referenced_packages`. Pure Dart ⇒ runs in `flutter test` [VERIFIED: executed this session] |
| `flutter_timezone` | `^5.1.0` | Read the device's IANA zone id | `timezone` cannot; Dart cannot (`DateTime.now().timeZoneName` gives an abbreviation). Exposes `FlutterTimezone.getLocalTimezone() → Future<TimezoneInfo>`; `.identifier` is the IANA string [VERIFIED: ~/.pub-cache/hosted/pub.dev/flutter_timezone-5.1.0/lib/timezone_info.dart:17] |

**Verified resolution against this repo's real `pubspec.yaml`** (copied to `/tmp/bqresolve`, three
deps added, `flutter pub get` run — no conflicts, nothing else moved):

```
flutter_local_notifications: 22.3.0        flutter_local_notifications_platform_interface: 12.2.0
flutter_local_notifications_linux: 8.0.1   flutter_local_notifications_windows: 3.1.1
flutter_local_notifications_web: 1.0.0     timezone: 0.11.1
flutter_timezone: 5.1.0                    clock: 1.1.2
equatable: 2.1.0                           plugin_platform_interface: 2.1.8
intl: 0.20.3  (UNCHANGED)                  flutter_riverpod: 3.4.2  (UNCHANGED)
drift: 2.34.3 (UNCHANGED)                  shared_preferences: 2.5.5 (UNCHANGED)
```

[VERIFIED: `flutter pub get` executed 2026-08-17 in /tmp/bqresolve]. **`intl` stays at 0.20.3** —
the SDK pin the project's locked decision protects is not disturbed.

**Installation:**

```bash
flutter pub add flutter_local_notifications timezone flutter_timezone
```

> Do **not** hand-pin `intl` while doing this (existing locked decision, CLAUDE.md).

### Supporting (dev only, optional)

| Library | Version | Purpose | When to use |
|---------|---------|---------|-------------|
| `plugin_platform_interface` | `^2.1.8` (already transitive) | `MockPlatformInterfaceMixin` | ONLY if you decide to mock `FlutterLocalNotificationsPlatform.instance` directly instead of the app's own seam. Recommended **against** — see §9.2. |

### Alternatives considered

| Instead of | Could use | Tradeoff |
|------------|-----------|----------|
| `flutter_timezone` | ~25 lines of hand-rolled platform channel (`TimeZone.current.identifier` / `ZoneId.systemDefault().getId()`) | Prior research recommended taking the package. **New evidence tilts this slightly:** the Flutter 3.47 build emits `WARNING: Your app uses the following plugins that apply Kotlin Gradle Plugin (KGP): flutter_timezone. Future versions of Flutter will fail to build if your app uses plugins that apply KGP.` [VERIFIED: build output, /tmp/bqbuild, 2026-08-17]. Not blocking today; a dated liability. See Risk R-4. |
| `flutter_local_notifications` | `awesome_notifications` | Rejected in prior research on maturity (self-described "under development"); confirms the same iOS 64 cap so buys nothing. Not re-litigated. |

---

## Package Legitimacy Audit

> The `gsd-tools query package-legitimacy` seam could not be run — `node` is not on this
> agent's PATH (stated environment constraint). Audit performed manually against pub.dev and
> the downloaded archives instead. All three packages were sourced from **official plugin
> documentation and the pub.dev registry**, not from a model guess.

| Package | Registry | Publisher | Source repo | Evidence gathered this session | Verdict | Disposition |
|---------|----------|-----------|-------------|-------------------------------|---------|-------------|
| `flutter_local_notifications` | pub.dev | `dexterx.dev` (verified) | github.com/MaikuB/flutter_local_notifications | Archive downloaded, `pubspec.yaml` + full Dart source read; APK built against it; ~2.5M weekly downloads [CITED: docs/research/2026-08-16-notifications-research.md §10] | OK | Approved |
| `timezone` | pub.dev | `labs.dart.dev` (verified) | github.com/srawlins/timezone | Resolved to 0.11.1; executed in a host test; tzdata 2025c [CITED: pub.dev/packages/timezone] | OK | Approved |
| `flutter_timezone` | pub.dev | `wolverinebeach.net` (verified) | github.com/JeroenWeener/flutter_timezone (maintained fork of `flutter_native_timezone`) | Archive on disk read (`timezone_info.dart`, `flutter_timezone.dart`, `android/build.gradle`); linked into a green release APK | OK | Approved — but see Risk R-4 (KGP deprecation warning) |

**Packages removed due to SLOP verdict:** none.
**Packages flagged SUS:** none.

---

## 2. Package versions and platform requirements, verified current

| Fact | Value | Source |
|------|-------|--------|
| `flutter_local_notifications` latest | **22.3.0**, published ~9 days before 2026-08-17 | [CITED: pub.dev/packages/flutter_local_notifications] |
| Its SDK constraint | `sdk: ^3.10.0`, `flutter: ">=3.38.1"` | [VERIFIED: /tmp/fln2203/pubspec.yaml — we run Dart 3.13.0 / Flutter 3.47.0 ✓] |
| Its Android floor | `minSdkVersion 24`, `compileSdk 36`, `JavaVersion.VERSION_17`, `coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.1.4'` | [VERIFIED: /tmp/fln2203/android/build.gradle:26,28-30,35,45] |
| Our Android floor | `minSdk = flutter.minSdkVersion` = **24**, `compileSdk = flutter.compileSdkVersion` = **36**, `targetSdk = 36`, Java 17, Kotlin JVM 17 | [VERIFIED: android/app/build.gradle.kts:12-15,24-26 + /opt/homebrew/share/flutter/packages/flutter_tools/gradle/src/main/kotlin/FlutterExtension.kt:23,26,34] |
| Our AGP / Gradle | AGP **9.1.0**, Gradle **9.3.1**, Kotlin **2.4.0** — plugin requires AGP ≥ 8.11.1 ✓ | [VERIFIED: android/settings.gradle.kts:21, android/gradle/wrapper/gradle-wrapper.properties] |
| iOS floor | plugin podspec `s.ios.deployment_target = '13.0'`; SPM `platforms: [.iOS("13.0")]` | [VERIFIED: /tmp/fln2203/ios/flutter_local_notifications.podspec:19, ios/flutter_local_notifications/Package.swift:9] |
| Our iOS target | `IPHONEOS_DEPLOYMENT_TARGET = 15.0` ✓ | [VERIFIED: ios/Runner.xcodeproj/project.pbxproj:363,491,543] |
| iOS dependency manager | **Swift Package Manager** — the repo has *no* `ios/Podfile`; `Runner.xcodeproj` carries SPM `packageReferences`. Both new plugins ship `Package.swift`, so no CocoaPods is introduced. | [VERIFIED: `ls ios/` — no Podfile; `grep packageReferences ios/Runner.xcodeproj/project.pbxproj` → 6 hits; both plugins' `ios/*/Package.swift` present] |
| `timezone` | **0.11.1**, bundles IANA **tzdata 2025c** | [CITED: pub.dev/packages/timezone] |
| `flutter_timezone` | **5.1.0**, Android `minSdkVersion 21`, `compileSdkVersion 35` | [VERIFIED: ~/.pub-cache/hosted/pub.dev/flutter_timezone-5.1.0/android/build.gradle:39,50] |

**Nothing in the phase is blocked by a version floor.** Every requirement is already met by the
current toolchain.

---

## 3. Exact platform setup

### 3.1 Android — `android/app/build.gradle.kts` (REQUIRED, currently absent)

The project has `compileOptions` but **no desugaring**. Without this the build fails with
`Dependency ':flutter_local_notifications' requires core library desugaring to be enabled for
:app` — the single most-reported issue for this plugin
([#2405](https://github.com/MaikuB/flutter_local_notifications/issues/2405),
[#2389](https://github.com/MaikuB/flutter_local_notifications/issues/2389),
[flutter#161964](https://github.com/flutter/flutter/issues/161964)).

This is the **exact diff I built and shipped a green release APK with**:

```kotlin
    compileOptions {
        isCoreLibraryDesugaringEnabled = true          // ← ADD (note the Kotlin-DSL `is` prefix)
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
```

and, at the **end of the file, outside the `android { }` block**:

```kotlin
dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
```

> `multiDexEnabled true` appears in the README snippet. It was **not needed** — both APKs built
> without it. Do not add it speculatively. [VERIFIED: build succeeded without it]

### 3.2 Android — `android/app/src/main/AndroidManifest.xml` (REQUIRED)

Inside `<manifest>`:

```xml
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
```

Inside `<application>` (the plugin cannot fire a scheduled notification without these):

```xml
<receiver android:exported="false"
    android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver" />
<receiver android:exported="false"
    android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
    <intent-filter>
        <action android:name="android.intent.action.BOOT_COMPLETED"/>
        <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>
        <action android:name="android.intent.action.QUICKBOOT_POWERON" />
        <action android:name="com.htc.intent.action.QUICKBOOT_POWERON"/>
    </intent-filter>
</receiver>
```

[VERIFIED: /tmp/fln2203/README.md "AndroidManifest.xml setup" §, and both receivers confirmed
present in the merged manifest of my build]

**Do NOT add** `SCHEDULE_EXACT_ALARM`, `USE_EXACT_ALARM`, `POST_NOTIFICATIONS` or `VIBRATE`.
The plugin's own manifest is exactly two lines and nothing else:

```xml
<uses-permission android:name="android.permission.VIBRATE" />
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
```

[VERIFIED: /tmp/fln2203/android/src/main/AndroidManifest.xml — the whole file]

### 3.3 The release-manifest delta — measured, not assumed

I built `flutter build apk --release` twice from full copies of this repo: once pristine, once
with the three packages plus the edits above. Merged release manifest,
`build/app/intermediates/merged_manifests/release/processReleaseManifest/AndroidManifest.xml`:

| | Permissions in the RELEASE merged manifest |
|---|---|
| **Today (baseline)** | `com.boostque.dev.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION` (AGP-generated) |
| **After Phase 7** | `com.boostque.dev.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION`, `android.permission.POST_NOTIFICATIONS`, `android.permission.RECEIVE_BOOT_COMPLETED`, `android.permission.VIBRATE` |

[VERIFIED: two `flutter build apk --release` runs, /tmp/bqbase and /tmp/bqbuild, 2026-08-17]

**Delta = exactly three, all unprivileged.** No `INTERNET` (that one is in
`android/app/src/debug/AndroidManifest.xml` and is debug-only — confirmed by the debug merged
manifest containing it and the release one not). No exact-alarm permission of any kind.

**This is what `test/platform_config_test.dart` should be extended to assert.** Concretely, add a
group that (a) reads `android/app/src/main/AndroidManifest.xml` after `_stripXmlComments` and
fails on `SCHEDULE_EXACT_ALARM`, `USE_EXACT_ALARM`, `INTERNET`, `ACCESS_NETWORK_STATE`,
`USE_FULL_SCREEN_INTENT` and `ACCESS_NOTIFICATION_POLICY`; and (b) asserts both receivers and
`RECEIVE_BOOT_COMPLETED` **are** present, so a later manifest cleanup cannot silently break
scheduling. The existing `_stripXmlComments` helper (`test/platform_config_test.dart:24`) already
solves the "a comment naming the forbidden thing trips its own gate" problem — reuse it.

### 3.4 Android — ProGuard

**Nothing to do.** "For flutter_local_notifications v19 and higher, the ProGuard rules are
automatically provided by the GSON." [VERIFIED: /tmp/fln2203/README.md:465]. We are on 22.3.0.
The release APK built green with default `minifyEnabled` settings.

### 3.5 iOS — `ios/Runner/AppDelegate.swift` (REQUIRED, one or two lines)

The repo is **already UIScene-migrated** and is exactly the shape the plugin's own example app
uses (`FlutterAppDelegate, FlutterImplicitEngineDelegate` + registration in
`didInitializeImplicitFlutterEngine`). No migration work — the plugin's open issue
[#2721](https://github.com/MaikuB/flutter_local_notifications/issues/2721) about stale README iOS
instructions does not bite us.

Current file (`ios/Runner/AppDelegate.swift`) with the required additions marked:

```swift
import Flutter
import UIKit
import flutter_local_notifications                                     // ← ADD (only if you use ②)

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    UNUserNotificationCenter.current().delegate = self as UNUserNotificationCenterDelegate  // ← ① ADD
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    FlutterLocalNotificationsPlugin.setPluginRegistrantCallback { (registry) in   // ← ② OPTIONAL
        GeneratedPluginRegistrant.register(with: registry)
    }
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
```

- **① is required.** Without it, foreground presentation and the tap callback do not work.
  [VERIFIED: /tmp/fln2203/README.md "iOS setup / General setup", and
  /tmp/fln2203/example/ios/Runner/AppDelegate.swift, which is line-for-line our shape]
- **② is only needed for the background/action isolate** (`onDidReceiveBackgroundNotificationResponse`,
  notification action buttons). Phase 7's spec is "tapping opens Сьогодні" — a foreground
  callback — so ② can be skipped. Adding it is harmless and future-proofs actions.

### 3.6 iOS — `Info.plist`

**No key is required.** Local notifications need no `Info.plist` entry, no entitlement and no
`UIBackgroundModes`. The plugin's iOS setup section lists only the AppDelegate line.
`ios/Runner/Info.plist` already carries the `UIApplicationSceneManifest` the UIScene shape needs.
[VERIFIED: full `<key>` listing of ios/Runner/Info.plist; plugin README iOS §]

---

## 4. State of the Art — what changed and what a stale snippet will get wrong

| Old (≤ v19) | Current (22.3.0) | Impact |
|---|---|---|
| `zonedSchedule(id, title, body, date, details, androidScheduleMode: ...)` — mixed positional/named | **Every parameter named**, `notificationDetails:` and `androidScheduleMode:` both `required` | A copied snippet does not compile. The plugin's own README §"Scheduling a notification" is **still stale** on this. |
| `initialize(settings, onDidReceiveNotificationResponse: ...)` positional first arg | `initialize({required InitializationSettings settings, ...})` | Same. |
| `show(id, title, body, details, payload: ...)` | `show({required int id, String? title, String? body, NotificationDetails? notificationDetails, String? payload})` | Same. |
| `cancel(id, tag: ...)` | `cancel({required int id, String? tag})` | Same. |
| `IOSInitializationSettings` | `DarwinInitializationSettings` is the base; `IOSInitializationSettings` still exists (extends it, adds `requestCarPlayPermission`) since 17.3.0 | Either compiles. Use `DarwinInitializationSettings` — CarPlay is irrelevant here. |
| `requestPermission()` (Android) | `requestNotificationsPermission()` | The old name is gone. |
| Hand-written GSON ProGuard rules | Auto-provided since v19 | Delete-nothing; just don't add them. |
| `sqlite3_flutter_libs`-style extra manifest permissions from the plugin | Since v16 the plugin declares only `POST_NOTIFICATIONS` + `VIBRATE` | Our "no privileged permission" property survives. |

**Deprecated / do not use:** `schedule`, `showDailyAtTime`, `showWeeklyAtDayAndTime` (superseded
by `zonedSchedule`); `periodicallyShow` (fixed intervals, wrong model for dose times).

---

## 5. The exact current API surface

All signatures below are **quoted from the shipped 22.3.0 archive**, not from memory or a
rendered doc page.

### 5.1 `initialize`

```dart
// /tmp/fln2203/lib/src/flutter_local_notifications_plugin.dart:110-115
Future<bool?> initialize({
  required InitializationSettings settings,
  DidReceiveNotificationResponseCallback? onDidReceiveNotificationResponse,
  DidReceiveBackgroundNotificationResponseCallback?
      onDidReceiveBackgroundNotificationResponse,
}) async
```

Throws `ArgumentError('Android settings must be set when targeting Android platform.')` if
`settings.android == null` on Android, and the iOS equivalent on iOS. Both must be supplied.

### 5.2 `DarwinInitializationSettings` — the three defaults that matter

```dart
// /tmp/fln2203/lib/src/platform_specifics/darwin/initialization_settings.dart:7-20
const DarwinInitializationSettings({
  this.requestAlertPermission = true,        // ← DEFAULT TRUE
  this.requestSoundPermission = true,        // ← DEFAULT TRUE
  this.requestBadgePermission = true,        // ← DEFAULT TRUE
  this.requestProvisionalPermission = false,
  this.requestCriticalPermission = false,
  this.requestProvidesAppNotificationSettings = false,
  this.defaultPresentAlert = true,
  this.defaultPresentSound = true,
  this.defaultPresentBadge = true,
  this.defaultPresentBanner = true,
  this.defaultPresentList = true,
  this.notificationCategories = const <DarwinNotificationCategory>[],
});
```

**All three permission flags MUST be set to `false`** or `initialize()` fires the one-and-only
iOS system prompt at whatever moment you call it — which directly violates NOTIF-03 ("never at
launch"). This is the single highest-consequence default in the whole API.

### 5.3 The callback typedefs

```dart
// flutter_local_notifications_platform_interface-12.2.0/lib/src/typedefs.dart
typedef DidReceiveNotificationResponseCallback =
    void Function(NotificationResponse details);
typedef DidReceiveBackgroundNotificationResponseCallback =
    void Function(NotificationResponse details);
```

`NotificationResponse` carries `{int? id, String? actionId, String? input, String? payload,
Map<String,dynamic> data, NotificationResponseType notificationResponseType}`.
`NotificationResponseType` ∈ `{selectedNotification, selectedNotificationAction,
notificationDismissed}`. [VERIFIED: .../lib/src/types.dart:108-176]

The background variant runs on a **separate isolate** and its function must be a top-level or
static function annotated `@pragma('vm:entry-point')`. **Phase 7 does not need it** — grouping
by time-of-day means there are no action buttons, and "tap opens Сьогодні" is a foreground
concern. Skip it; it is the source of most of this plugin's confusion.

### 5.4 `zonedSchedule` — the call the whole phase turns on

```dart
// /tmp/fln2203/lib/src/flutter_local_notifications_plugin.dart:409-417
Future<void> zonedSchedule({
  required int id,
  required TZDateTime scheduledDate,
  required NotificationDetails notificationDetails,
  required AndroidScheduleMode androidScheduleMode,   // ← no default; must be passed
  String? title,
  String? body,
  String? payload,
  DateTimeComponents? matchDateTimeComponents,
}) async
```

### 5.5 The two shapes Phase 7 issues

```dart
// TIER A — one repeating request per time-of-day. Costs 1 against the iOS 64 cap forever.
await plugin.zonedSchedule(
  id: id,
  title: title,                       // localized, from lookupAppLocalizations
  body: body,                         // e.g. «3 прийоми» — count only, no names
  scheduledDate: firstFireInstant,    // TZDateTime, next occurrence
  notificationDetails: _details,
  androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
  matchDateTimeComponents: DateTimeComponents.time,   // ← makes it a daily repeat
  payload: payload,
);

// TIER B — one one-shot per (time-of-day, active day) within horizon ∩ budget.
await plugin.zonedSchedule(
  id: id,
  title: title,
  body: body,
  scheduledDate: instant,
  notificationDetails: _details,
  androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
  // matchDateTimeComponents deliberately OMITTED — a course must never repeat
  payload: payload,
);
```

with

```dart
const _details = NotificationDetails(
  android: AndroidNotificationDetails(
    'doses_v1',                       // channel id — treat as versioned; channels are immutable
    'Dose reminders',                 // channel name (see Pitfall 8 re. localization)
    channelDescription: '...',
    importance: Importance.high,      // heads-up
    visibility: NotificationVisibility.private,  // lock-screen content redacted until unlock
    category: AndroidNotificationCategory.reminder,
  ),
  iOS: DarwinNotificationDetails(),
);
```

`NotificationVisibility` is `enum { private, public, secret }` — index 0/1/2. **It exists only on
`AndroidNotificationDetails`, NOT on `AndroidNotificationChannel`** (see §10 correction C-1).
[VERIFIED: .../android/enums.dart:212-222; .../android/notification_channel.dart has no
`visibility` field; and the wire payload I captured shows `visibility: 0`]

`AndroidScheduleMode` is `enum { alarmClock, exact, exactAllowWhileIdle, inexact,
inexactAllowWhileIdle }`. [VERIFIED: .../android/schedule_mode.dart — the whole file]

### 5.6 Channel creation, cancellation, querying

```dart
// Android only; create the channel EXPLICITLY at init so it exists in Settings before
// the first notification. Channels are immutable after creation — hence `doses_v1`.
await plugin
    .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
    ?.createNotificationChannel(const AndroidNotificationChannel(
      'doses_v1',
      'Dose reminders',
      description: '...',
      importance: Importance.high,
    ));

Future<void> cancel({required int id, String? tag});
Future<void> cancelAll();
Future<List<PendingNotificationRequest>> pendingNotificationRequests();
```

`PendingNotificationRequest` is `const PendingNotificationRequest(this.id, this.title, this.body,
this.payload)` — **four positional fields and no scheduled time**. [VERIFIED:
platform_interface .../types.dart:17-38]. That is why the reconciliation key must fold the fire
time into the id: a slot moved 09:00→10:00 is otherwise indistinguishable from an unchanged one.

`AndroidNotificationChannel`'s constructor is `(this.id, this.name, {description, groupId,
importance, bypassDnd, playSound, sound, enableVibration, vibrationPattern, showBadge,
enableLights, ledColor, audioAttributesUsage})`. [VERIFIED: .../android/notification_channel.dart]

### 5.7 What actually crosses the platform channel

Captured from a real run (`flutter test`, mock method-channel handler on
`dexterous.com/flutter/local_notifications`) — this is the ground truth for any payload assertion:

```
method: zonedSchedule
{
  id: 42, title: Час прийому, body: 3 прийоми, payload: today,
  timeZoneName: Europe/Kyiv,
  scheduledDateTime: 2030-03-28T09:00:00,                 // wall clock, offset STRIPPED
  scheduledDateTimeISO8601: 2030-03-28T09:00:00.000+0200, // sent but IGNORED by Android
  matchDateTimeComponents: 0,                             // DateTimeComponents.time
  platformSpecifics: { channelId: doses_v1, channelName: Doses, importance: 3,
                       visibility: 0, scheduleMode: inexactAllowWhileIdle, ... }
}
```

[VERIFIED: executed 2026-08-17, /tmp/flnprobe/test/probe2_test.dart]

Android reconstructs the instant as
`ZonedDateTime.of(LocalDateTime.parse(scheduledDateTime), ZoneId.of(timeZoneName))`
[VERIFIED: /tmp/fln2203/android/src/main/java/.../FlutterLocalNotificationsPlugin.java:620-621,
1374]. **The offset the Dart side computed is discarded** — only the wall clock and the zone name
travel. This matters for the DST overlap; see Pitfall 3.

---

## 6. Permission mechanics, per platform

### 6.1 iOS

```dart
// /tmp/fln2203/lib/src/platform_flutter_local_notifications.dart:759-770
Future<bool?> requestPermissions({
  bool sound = false, bool alert = false, bool badge = false,
  bool provisional = false, bool critical = false, bool carPlay = false,
  bool providesAppNotificationSettings = false,
});

Future<NotificationsEnabledOptions?> checkPermissions();   // line 780
Future<bool?> openAppNotificationSettings();               // line 812
```

Reached via
`plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()?...`
(returns `null` off iOS — use `?.`, never `!`).

- **Returns:** `true` = granted, `false` = denied, `null` = not running on iOS.
- **Repeat calls:** iOS presents the system prompt **exactly once for the app's lifetime**. Every
  later call returns the stored answer and shows nothing. There is no retry. [CITED: Apple
  `UNUserNotificationCenter.requestAuthorization` semantics; corroborated in prior research §2]
- **"Denied" vs "not yet asked":** `requestPermissions` cannot distinguish them — both return
  `false`-ish. `checkPermissions()` returns a `NotificationsEnabledOptions` with
  `{isEnabled, isAlertEnabled, isBadgeEnabled, isSoundEnabled, isProvisionalEnabled,
  isCriticalEnabled, isProvidesAppNotificationSettingsEnabled, isCarPlayEnabled}` [VERIFIED:
  .../platform_flutter_local_notifications.dart:780-798] — but it too reports the *effective*
  state, not the authorization status enum. `UNAuthorizationStatus.notDetermined` is **not
  surfaced by this plugin at all** [VERIFIED: no `authorizationStatus` field anywhere in the
  Dart API].
  **Consequence:** if you need "have we ever asked?", you must store that bit yourself
  (SharedPreferences, one bool) — but per prior research §6 the app should ask the *platform*
  for the effective state and use its own flag only to answer "should we show the pre-prompt".
- **`requestProvisionalPermission`:** do not use. A quiet-delivery reminder that never banners is
  not a reminder.

### 6.2 Android

```dart
// /tmp/fln2203/lib/src/platform_flutter_local_notifications.dart:205, 624, 634
Future<bool?> requestNotificationsPermission();   // POST_NOTIFICATIONS, API 33+; no-op below
Future<bool?> areNotificationsEnabled();
Future<bool?> openAppNotificationSettings();
```

- **Returns:** `true` granted, `false` denied, `null` off Android. On API < 33 it is a documented
  no-op (notifications are on by default).
- **Repeat calls:** Android shows the rationale dialog until the user has denied it twice; after
  that the system silently returns denied and the only route is
  `openAppNotificationSettings()`.
- **"Denied" vs "not yet asked":** `areNotificationsEnabled()` returns whether the app *can post*.
  It returns `false` for both "never asked" and "permanently denied". Same conclusion as iOS: if
  the distinction matters, keep one local bool.
- **Do NOT call** `requestExactAlarmsPermission()` or `requestFullScreenIntentPermission()` —
  both exist on the same class (lines 179, 197) and both are Play-policy landmines for this app.

### 6.3 Where to call it (NOTIF-03)

The hook is `RegimenEditorController.save()` — see §8.4. Ask **after** the first save resolves
successfully, not before, and not on every save. A short pre-prompt sheet before the system
dialog is the standard pattern and is worth it given there is no retry (prior research §6).

---

## 7. Timezone initialization

### 7.1 The handshake

```dart
import 'package:timezone/data/latest_all.dart' as tzdata;  // NOT latest.dart — see below
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';

Future<void> initTimeZones() async {
  tzdata.initializeTimeZones();                       // loads the database; pure Dart, no channel
  try {
    final info = await FlutterTimezone.getLocalTimezone();   // platform channel
    tz.setLocalLocation(tz.getLocation(info.identifier));
  } catch (error, stack) {
    // Degrade, never fail the launch — same stance as main()'s SharedPreferences guard.
    FlutterError.reportError(FlutterErrorDetails(
      exception: error, stack: stack, library: 'boostque',
      context: ErrorDescription('resolving the device time zone'),
    ));
    // tz.local defaults to UTC when setLocalLocation was never called.
  }
}
```

`FlutterTimezone.getLocalTimezone()` returns `Future<TimezoneInfo>`; the IANA string is
`.identifier`. [VERIFIED: flutter_timezone-5.1.0/lib/flutter_timezone.dart:21-30,
lib/timezone_info.dart:17]

### 7.2 `latest_all.dart`, not `latest.dart` — now proven, not asserted

I ran both. With the trimmed `package:timezone/data/latest.dart`,
`tz.getLocation('Europe/Kiev')` throws
`LocationNotFoundException: Location with the name "Europe/Kiev" doesn't exist`. With
`latest_all.dart` it resolves. [VERIFIED: /tmp/flnprobe/test/probe3_test.dart and
probe_test.dart, executed 2026-08-17]

Some Android builds still report the deprecated alias `Europe/Kiev`. Using the trimmed database
would therefore throw on a real Ukrainian device — the app's primary audience. **Use
`latest_all.dart` and keep the try/catch anyway.**

### 7.3 Where it runs relative to `runApp`

`lib/main.dart` is already `async` and already has a bootstrap step between
`WidgetsFlutterBinding.ensureInitialized()` and `runApp(...)` (the `SharedPreferences.getInstance()`
await, lines 15-36). **Put `initTimeZones()` in that same window**, after
`ensureInitialized()` (the platform channel needs the binding) and before `runApp`.

Ordering rules:

- `tzdata.initializeTimeZones()` must precede **any** `tz.getLocation` / `tz.TZDateTime`
  construction, or you get `TimeZoneInitializationException` / `LocationNotFoundException`.
- `tz.setLocalLocation(...)` must precede any use of `tz.local`. If you build a `TZDateTime`
  against `tz.local` before it, you silently get **UTC** — every reminder off by the device's
  offset. For Kyiv that is 2 or 3 hours. This failure is *silent*, which is what makes it
  dangerous.
- The `await` on `FlutterTimezone` is a real platform-channel round trip. Follow the existing
  `SharedPreferences` precedent exactly: `try`/`catch` + `FlutterError.reportError`, never let it
  hold `runApp` hostage. A wrong timezone costs correct reminder times; a thrown error costs the
  whole app.

**Also re-resolve on resume.** The user can fly to another timezone while the app is
backgrounded. `TodayController` already owns an `AppLifecycleListener(onResume: _refresh)`
(`lib/core/today_controller.dart:66`); the notification sync's resume hook should re-read
`getLocalTimezone()` and, if the identifier changed, `setLocalLocation` + full reschedule.

---

## 8. Existing code this must hook into

All paths are real and were read this session.

### 8.1 The domain — activity decision (unchanged, reuse verbatim)

| Symbol | File:line | Signature |
|---|---|---|
| `dateOnly` | `lib/core/domain/cycle_math.dart:16` | `DateTime dateOnly(DateTime d)` → `DateTime.utc(d.year, d.month, d.day)` |
| `isActiveOn` | `lib/core/domain/cycle_math.dart:26` | `bool isActiveOn(Regimen r, DateTime day)` |
| `mondayOfWeek` | `cycle_math.dart:55` | `DateTime mondayOfWeek(DateTime day)` |
| `activeRuns` | `lib/features/calendar/planner_view_model.dart:51` | `List<DateRun> activeRuns(Regimen r, DateTime from, DateTime toInclusive)` |
| `DateRun` | `planner_view_model.dart:27` | `{DateTime start, DateTime end}` — both inclusive, date-only UTC |

**`isActiveOn` is the ONE activity decision point** and its cyclic branch already gives the tier
split for free (`cycle_math.dart:39-40`):

```dart
if (r.onDays <= 0) return false;
if (r.offDays == 0) return true;          // ← Tier A candidate
```

**Tier A predicate**, stated exactly: `r.kind == RegimenKind.cyclic && !r.paused && r.onDays > 0
&& r.offDays == 0 && r.endDate` irrelevant (cyclic ignores it) **and `!dateOnly(r.startDate)
.isAfter(today)`** — a future-start daily regimen must be treated as Tier B until it starts, or
the repeat fires before the regimen begins. Everything else is Tier B.

> **`activeRuns` lives in `features/calendar/`.** `core/` must never import `features/`
> (established in `today_controller.dart`'s library doc). The planner must either (a) move
> `activeRuns`/`DateRun` down into `lib/core/domain/` — clean, and both call sites benefit — or
> (b) have `notification_plan.dart` walk `isActiveOn` day-by-day itself. **(a) is recommended**;
> `planner_view_model.dart`'s own doc calls `activeRuns` "the ONLY activity decision in the
> planner", and duplicating the walk re-creates the PF-1 defect that comment exists to prevent.
> `test/features/planner_view_model_test.dart` already covers it and follows the move.

### 8.2 The models

`lib/core/domain/models.dart`: `Regimen {id, supplementId, kind, startDate, endDate, onDays,
offDays, paused, slots}`; `DoseSlot {id, minutesFromMidnight (0..1439, wall-clock, timezone-
independent), doseLabel}`; `RegimenKind {cyclic, course}`; `Supplement {id, name, doseText,
colorValue, note}`.

`minutesFromMidnight` is exactly the grouping key the spec's "one per time-of-day" needs — it is
already timezone-free and already the sort key in `DriftRegimenRepository` ("slots sorted by
minutesFromMidnight asc, id asc", `repositories.dart:69`).

### 8.3 Repositories and providers

| Symbol | File:line | Notes |
|---|---|---|
| `RegimenRepository.watchAll()` | `lib/core/domain/repositories.dart:70` | `Stream<List<Regimen>>`, slots included |
| `SupplementRepository.watchAll()` | `repositories.dart:47` | needed only if notification copy ever names a supplement (it does not) |
| `combineStackEntries` | `repositories.dart:149` | pairs supplements↔regimens |
| `regimensBySupplement` | `repositories.dart:135` | the PF-8 one-regimen-per-supplement collapse |
| `regimensStreamProvider` | `lib/core/providers.dart:93` | app-lifetime `StreamProvider<List<Regimen>>` |
| `stackEntriesProvider` | `providers.dart:196` | `Provider<AsyncValue<List<StackEntry>>>` — watch THIS, not `regimensStreamProvider`, if copy ever needs names |
| `todayProvider` | `lib/core/today_controller.dart:92` | `NotifierProvider<TodayController, DateTime>` — the app's single clock; already midnight- and DST-safe |
| `TodayController._lifecycle` | `today_controller.dart:66` | `AppLifecycleListener(onResume: _refresh)` — the existing resume hook |

**Reschedule triggers, mapped to real providers:**

| Trigger (spec §2.4) | Hook | Status |
|---|---|---|
| regimen created / edited / paused / resumed | `ref.watch(regimensStreamProvider)` | free — already reactive |
| supplement deleted | same (cascade soft-deletes the regimen; `softDeleteCascade`, `repositories.dart:62`) | free |
| midnight rollover | `ref.watch(todayProvider)` | free, already DST-safe and tested |
| app resumed | a second `AppLifecycleListener(onResume:)` in the sync notifier | ~5 lines; `TodayController` is the precedent |
| permission granted | after `requestPermissions` / `requestNotificationsPermission` returns true | §6.3 |
| **locale changed** | `ref.watch(localeControllerProvider)` | **not in the spec's list — see Pitfall 7** |

A single `notificationSyncProvider` watching `regimensStreamProvider` + `todayProvider` +
`localeControllerProvider` covers everything but resume. It **must debounce**: the editor's save
writes regimen and slots in one transaction but the Drift stream can emit more than once, and
each sync is dozens of platform-channel round trips.

### 8.4 The permission ask point (NOTIF-03)

`lib/features/stack/regimen_editor_controller.dart`:

- `final regimenEditorProvider = NotifierProvider.autoDispose.family<RegimenEditorController,
  RegimenDraft, String>(RegimenEditorController.new);` — line 516
- `Future<void> save()` — line 383. It is a **serialized chain**, not a single-flight:
  `save()` → `_chainedSave(_saveInFlight)` → `_doSave()`. `await save()` means *the draft as it
  was at the call* is on disk.
- `Future<void> deleteSupplement()` — line 506.

**Ask after `await save()` resolves at the call site (the editor screen's save button), not
inside `_doSave()`.** Three reasons: `_doSave` can legitimately `return` early when `!ref.mounted`
(lines 415, 474) or `throw StateError` on a blind seed (line 428), so "the save succeeded" is not
a single point in there; the controller is `autoDispose` and may be gone; and a permission dialog
is a UI concern that the controller's own doc keeps out of itself.

### 8.5 Grouping and copy

- `lib/features/calendar/day_view_model.dart:29` — `const blockStartsMinutes = <int>[0, 720,
  1080, 1320]` and `blockIndexOf(int)` (line 35), `groupIntoBlocks(List<DayDose>)` (line 68).
  These group *rendered doses* into morning/day/evening/night **blocks** — a coarser grouping
  than the notification's. The notification groups by **exact `minutesFromMidnight`**. Do not
  reuse `blockIndexOf` for notifications; they answer different questions.
- ARB: `lib/core/l10n/arb/app_en.arb` + `app_uk.arb`, 155 keys, template is `app_en.arb`
  (`l10n.yaml`). Ukrainian plurals already use all four CLDR forms, e.g.
  `substancesCount: "{count, plural, one{{count} речовина} few{{count} речовини}
  many{{count} речовин} other{{count} речовини}}"`. The notification body needs the same shape
  for "N прийоми".
- **Getting localized text without a `BuildContext`:** the generated file exposes the top-level
  `AppLocalizations lookupAppLocalizations(Locale locale)`
  (`lib/core/l10n/gen/app_localizations.dart:1054`), which returns **synchronously**. That is the
  seam the notification service uses. Do not try to reach a `BuildContext` from the scheduler.
- `test/l10n/no_hardcoded_strings_test.dart` scans **all of `lib/`**, flagging any literal with
  ≥2 letters after interpolation stripping. The channel name (`'Dose reminders'`) and any
  fallback copy **will trip it** — plan for an allowlist entry with a rationale (its doc
  explicitly forbids widening the flagging pattern instead).

### 8.6 Routing a tap to Сьогодні (NOTIF-01)

`lib/app_shell.dart` holds the selected tab in **local `State`**:

```dart
class _AppShellState extends State<AppShell> {
  int _selectedIndex = 0;                 // 0 = Стек, 1 = Сьогодні, 2 = Календар
  ...
  onSelected: (index) { setState(() => _selectedIndex = index); },
```

Nothing outside the widget can change it. Phase 7 must lift it into a Riverpod notifier (e.g.
`selectedTabProvider`) so the notification callback can set it to 1.

Two entry points, both needed:

- **Warm / backgrounded tap:** `onDidReceiveNotificationResponse` passed to `initialize()`.
- **Cold start from a tap:** `await plugin.getNotificationAppLaunchDetails()` returns
  `NotificationAppLaunchDetails {bool didNotificationLaunchApp, NotificationResponse?
  notificationResponse}` [VERIFIED: platform_interface types.dart:150-162]. The `initialize`
  callback is explicitly documented as **unable** to handle the launch case
  [VERIFIED: plugin doc comment, flutter_local_notifications_plugin.dart:100-103].

**Tests that will need updating** when `_selectedIndex` moves:
`test/widget/app_shell_test.dart` (lines 144, 163, 298 reference the IndexedStack positional
mapping and "the app opens on the Stack tab"), `test/widget/shell_invariants_test.dart:151-156`,
`test/core/widgets/bq_add_fab_test.dart`, `test/features/planner_screen_test.dart`.

### 8.7 The bootstrap

`lib/main.dart:11-43` — `WidgetsFlutterBinding.ensureInitialized()` → guarded
`await SharedPreferences.getInstance()` → `runApp(ProviderScope(overrides: [...]))`.
Add `await initTimeZones()` and the plugin `initialize()` + `createNotificationChannel()` in the
same window. Consider exposing the initialized plugin the same way `sharedPreferencesProvider`
is exposed — a `Provider` that throws unless overridden in `main()` and in tests
(`providers.dart:62-66` is the exact pattern, including the reason the throw is deliberate).

---

## 9. How to test this without a device

### 9.1 The boundary is achievable — and the impure remainder is small

Spec §2.4 puts all correctness in a pure `notification_plan.dart`. **Confirmed achievable.**
Everything the plan needs — `Regimen`, `DoseSlot`, `isActiveOn`, `activeRuns`, `today`, `horizon`,
`budget` — is already pure Dart with no clock read. Suggested shape:

```dart
// lib/core/notifications/notification_plan.dart — pure. Imports models.dart and
// cycle_math.dart ONLY. No timezone, no plugin, no Flutter, no clock.
List<PlannedNotification> planNotifications({
  required List<Regimen> regimens,
  required DateTime today,        // dateOnly() UTC, passed in — never read
  required int horizonDays,
  required int budget,
});

class PlannedNotification {
  final int id;
  final DateTime? day;               // null ⇔ repeating (tier A)
  final int minutesFromMidnight;     // wall-clock, timezone-free
  final bool repeatsDaily;
  final int doseCount;               // for the ICU plural body
  final String payload;
}
```

**What the impure service is left holding — exactly four things, none of them a decision:**

1. `TZDateTime` construction from `(day, minutesFromMidnight)` — the one-line field-wise
   conversion, plus `tz` init.
2. Localizing `doseCount` into title/body via `lookupAppLocalizations(locale)`.
3. Issuing `zonedSchedule` / `cancel` for the diff, and reading
   `pendingNotificationRequests()`.
4. Permission calls and the channel creation.

The **diff itself is pure too** and should live beside the plan:
`({Set<int> toCancel, List<PlannedNotification> toSchedule}) reconcile(List<PlannedNotification>
desired, Set<int> pending)`. Never `cancelAll()` — it also dismisses already-delivered reminders
the user has not acted on, and leaves a window with nothing scheduled.

### 9.2 Does the plugin ship a testable interface? — Yes, two, both with caveats

**(a) `FlutterLocalNotificationsPlatform` is a `PlatformInterface` with a settable `instance`.**
Mocking it requires `plugin_platform_interface`'s `MockPlatformInterfaceMixin` (else
`PlatformInterface.verifyToken` throws), which means declaring `plugin_platform_interface` as a
dev_dependency even though it is already transitive (`depend_on_referenced_packages`). And
`FlutterLocalNotificationsPlugin.zonedSchedule`'s Android branch does an `instance is
AndroidFlutterLocalNotificationsPlugin` check followed by `!`, so the mock must `implements
AndroidFlutterLocalNotificationsPlugin`. **Workable but brittle. Not recommended.**

**(b) `registerWith()` + a mock method channel — recommended for exactly one test.** Verified
working:

```dart
const _channel = MethodChannel('dexterous.com/flutter/local_notifications');

setUp(() {
  AndroidFlutterLocalNotificationsPlugin.registerWith();     // sets the late instance
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_channel, (call) async {
        calls.add(call);
        if (call.method == 'pendingNotificationRequests') return <dynamic>[];
        if (call.method == 'initialize') return true;
        return null;
      });
});
```

This captures the full argument map shown in §5.7 and lets a single host test assert the things
that matter platform-side and cannot be asserted anywhere else:
`scheduleMode == 'inexactAllowWhileIdle'`, `timeZoneName`, the exact `scheduledDateTime` wall
clock, `matchDateTimeComponents` present for tier A and **absent** for tier B, and
`visibility == 0`. [VERIFIED: executed 2026-08-17, /tmp/flnprobe/test/probe2_test.dart, passing]

**(c) The app's own `NotificationScheduler` interface + `mocktail` — the default for everything
else.** `mocktail ^1.0.5` is already a dev_dependency. Three or four methods
(`schedule`, `cancel`, `pending`, `requestPermission`) mirror the three existing repository
interfaces, and every widget test stays plugin-free.

### 9.3 **The seam is mandatory, not stylistic** — verified

I ran the plugin under `flutter test`:

```
PROBE targetPlatform=TargetPlatform.android
PROBE instance THREW LateError: LateInitializationError: Field '_instance@…' has not been initialized.
PROBE resolve THREW LateError: …
PROBE zonedSchedule THREW LateError: …
```

Two verified facts behind this:

- Under `flutter test`, `defaultTargetPlatform` is forced to `TargetPlatform.android`
  [VERIFIED: `/opt/homebrew/share/flutter/packages/flutter/lib/src/foundation/_platform_io.dart:29-34`
  — `if (Platform.environment.containsKey('FLUTTER_TEST')) result = TargetPlatform.android;`].
  So the Android code path is the one host tests take.
- `static late FlutterLocalNotificationsPlatform _instance;` has **no default value**
  [VERIFIED: flutter_local_notifications_platform_interface-12.2.0/lib/…:16].

So the README's "the methods will be mostly no-op" does **not** hold for 22.3.0 in a plain
`flutter test`. Any test whose widget tree reaches un-seamed plugin code fails with an obscure
`LateError`. Put the seam in from commit 1.

### 9.4 DST — assertable in pure Dart, with the exact outputs

`package:timezone` is pure Dart and runs in `flutter test`. Real outputs from this session
(`tzdata.initializeTimeZones()` then `tz.TZDateTime(getLocation('Europe/Kyiv'), …)`):

| Case | Input | `TZDateTime` result |
|---|---|---|
| Spring gap (2027-03-28, 03:00→04:00) | `(2027, 3, 28, 3, 0)` | `2027-03-28 04:00:00.000+0300` — shifted **forward** past the gap |
| Autumn overlap (2026-10-25, 04:00→03:00) | `(2026, 10, 25, 3, 0)` | `2026-10-25 03:00:00.000+0200` — the **later** (winter) offset, i.e. the *second* 03:00 |

[VERIFIED: executed 2026-08-17, /tmp/flnprobe/test/probe_test.dart]

Pin both with unit tests. Also add the negative-offset regression the spec asks for: a fixture in
e.g. `America/New_York` where `.toLocal()` on a date-only UTC value flips the calendar day —
`DateTime.utc(2026, 8, 16).toLocal()` is 2026-08-15 there.

### 9.5 Device-only

Actual delivery timing; the permission dialogs; Doze/battery-saver latency; reboot rescheduling;
force-stop; OEM background killers; lock-screen appearance; behaviour at exactly 64 pending;
iOS's own resolution of a `UNCalendarNotificationTrigger` landing in a DST gap. The repo already
has the harness: `integration_test/data03_loop_test.dart`, `integration_test/l10n_device_test.dart`.

---

## 10. Corrections to prior research

Three claims in `docs/research/2026-08-16-notifications-research.md` are wrong or imprecise. They
matter because a planner would otherwise write them into a task.

- **C-1 — "`NotificationVisibility` … also settable channel-wide at creation" (§8).**
  **False for the Dart API.** `AndroidNotificationChannel`'s constructor has **no `visibility`
  parameter** [VERIFIED: /tmp/fln2203/lib/src/platform_specifics/android/notification_channel.dart
  — full constructor quoted in §5.6 above]. Visibility is settable only per-notification via
  `AndroidNotificationDetails.visibility`. Set it on **every** `zonedSchedule` call; a task that
  says "set it once on the channel" produces public lock-screen content.

- **C-2 — "the Dart side normalises *before* the plugin is called … so the gap/overlap behaviour
  is pinned by a unit test" (§4).** **Half true.** Only `scheduledDateTime` (the **wall clock,
  offset stripped**) and `timeZoneName` reach Android; `scheduledDateTimeISO8601` is sent but
  never read by the native side [VERIFIED: tz_datetime_mapper.dart + Android
  `FlutterLocalNotificationsPlugin.java:620-621` uses `LocalDateTime.parse(scheduledDateTime)`].
  For the **spring gap** the Dart normalization *is* preserved (the wall clock itself changes
  03:00→04:00). For the **autumn overlap** it is **not**: Dart picks the later (+0200)
  occurrence, but only the string `2026-10-25T03:00:00` travels, and `java.time`'s documented
  overlap rule picks the **earlier** offset — so Android fires at the *first* 03:00, an hour
  before what the Dart test asserted. A unit test on `TZDateTime` alone therefore does **not**
  pin the overlap. Assert the wall clock crossing the channel (§9.2b) instead, and state the
  one-hour overlap divergence as known behaviour.

- **C-3 — "If you decide to use the plugin class directly as part of your tests, the methods will
  be mostly no-op" (the plugin's own README, quoted in §7 of prior research).** **False for
  22.3.0.** Every path throws `LateInitializationError`. See §9.3.

Additionally, prior research did not mention **core library desugaring** or the
**`multiDexEnabled`/AGP** requirements at all. Those are the most likely first-build failure and
are covered in §3.1.

---

## 11. Don't Hand-Roll

| Problem | Don't build | Use instead | Why |
|---|---|---|---|
| Reading the device's IANA zone | A `MethodChannel` + Swift/Kotlin | `flutter_timezone` | The project has zero custom native code today; a hand-rolled channel needs its own integration test on two platforms. (Counter-pressure: Risk R-4.) |
| DST-correct wall-clock → instant | `DateTime` arithmetic, `Duration(hours: 24)`, `.toLocal()` | `tz.TZDateTime(location, y, m, d, h, min)` | The gap/overlap rules are not expressible in `DateTime`. `.toLocal()` on a date-only UTC value shifts the whole day west of UTC. |
| "Is this regimen active today" | A second copy of the cycle formula | `isActiveOn` / `activeRuns` | `planner_view_model.dart:38-50` documents this as the PF-1 defect class the codebase already fixed once. |
| Rescheduling after reboot | A boot receiver of your own | `ScheduledNotificationBootReceiver` (manifest entry, §3.2) | The plugin re-arms from its own persisted cache with no Flutter engine. |
| Notification ids | `String.hashCode` | A hand-written FNV-1a over `"tier|hhmm|yyyy-mm-dd"`, masked `& 0x7fffffff` | Dart does not guarantee `hashCode` stability across SDK versions or platforms; the id is a persisted cross-process key. Ten pure lines. `validateId` also rejects anything outside 32-bit range [VERIFIED: platform_interface helpers.dart:5-14]. |
| Clearing stale schedules | `cancelAll()` | `reconcile(desired, pending)` set diff | `cancelAll` dismisses delivered-but-unacted notifications and leaves a gap. |
| Suppressing an off-day at delivery time | anything | Nothing — filter at schedule time | Neither platform has a delivery-time hook for **local** notifications (spec §2.2 — "impossible, not merely worse"). |

---

## 12. Common Pitfalls

**Pitfall 1 — `DarwinInitializationSettings`'s three `true` defaults fire the iOS prompt at
`initialize()`.** Sets NOTIF-03 on fire silently, and iOS gives no second chance.
*Avoid:* set `requestAlertPermission`, `requestSoundPermission`, `requestBadgePermission` all to
`false`. *Warning sign:* the system dialog appears on first launch instead of after the first
regimen save. *Test:* a source gate asserting all three literals are `false` in
`notification_service.dart`.

**Pitfall 2 — a stale `zonedSchedule` snippet.** The plugin's own README still shows the
pre-20.x mixed positional/named form. *Avoid:* copy §5.4/§5.5 of this document. *Warning sign:*
"Too many positional arguments".

**Pitfall 3 — the autumn DST overlap diverges between the Dart test and Android.** See C-2.
*Avoid:* assert at the channel boundary, not on `TZDateTime` alone; document the one-hour
divergence as accepted. *Warning sign:* a green unit test and a device that fires an hour early
on the last Sunday of October.

**Pitfall 4 — `zonedSchedule` throws `ArgumentError` for a past date.**
`validateDateIsInTheFuture(scheduledDate, matchDateTimeComponents)` throws
`ArgumentError.value(scheduledDate, 'scheduledDate', 'Must be a date in the future')` whenever
`matchDateTimeComponents == null` and the instant is before `clock.now()` [VERIFIED:
/tmp/fln2203/lib/src/helpers.dart, and reproduced:
`PROBE2 past date THREW ArgumentError: Invalid argument (scheduledDate): Must be a date in the future`].
Tier B is exactly the `matchDateTimeComponents == null` case, and there is a real race: today's
09:00 slot is in the past by the time a 09:05 resume syncs.
*Avoid:* filter `instant.isAfter(tz.TZDateTime.now(tz.local))` in the service before every tier-B
call, and wrap each call so one bad instant cannot abort the whole batch. It uses
`package:clock`, so `withClock` can drive it in tests.

**Pitfall 5 — building a `TZDateTime` before `tz.setLocalLocation`.** Silently yields UTC; every
reminder is off by the device offset. *Avoid:* initialize in `main()` before `runApp` (§7.3);
add an assert in `tz_conversion.dart`.

**Pitfall 6 — `Europe/Kiev` on the trimmed database.** Throws `LocationNotFoundException` on
exactly the app's primary audience. *Avoid:* `latest_all.dart` + try/catch (§7.2).

**Pitfall 7 — notification copy is baked at scheduling time and does not follow a language
change.** Not in the spec's trigger list. A user who switches to English in Settings keeps
Ukrainian banners for up to 30 days. *Avoid:* add `localeControllerProvider` to the sync
provider's watch set (§8.3). *Warning sign:* none — it is silent; only a test catches it.

**Pitfall 8 — the Android channel name is user-visible in system Settings and is immutable.**
It is created once, from whatever locale was active then, and cannot be changed by an app update
— only by a new channel id, which resets the user's own customization. *Avoid:* decide
deliberately. Either use a locale-neutral name, or accept the first-run locale and version the
id (`doses_v1`). *This is a genuine open decision (Q-2).*

**Pitfall 9 — the zero-hardcoded-strings gate.** `test/l10n/no_hardcoded_strings_test.dart` scans
all of `lib/` and will flag notification literals. *Avoid:* add named allowlist entries with
rationales; its doc explicitly forbids widening the flagging patterns instead.

**Pitfall 10 — `LateInitializationError` in host tests.** See §9.3. *Warning sign:* an existing
green widget test starts failing with a `LateError` naming an obfuscated field.

**Pitfall 11 — force-stop and OEM battery killers (Android).** A force-stopped app receives no
broadcasts including `BOOT_COMPLETED`, and Xiaomi/Huawei/Samsung defer or block alarms without
an autostart grant. No API detects either. *Mitigation:* documentation only for v1.1 (prior
research Q5); do not build detection.

**Pitfall 12 — bundle id.** Still the placeholder `com.boostque.dev`
(`android/app/build.gradle.kts:19`). Changing it wipes every pending iOS notification on existing
installs. Belongs on the pre-release checklist, not this phase.

---

## 13. Risks and mitigations

| # | Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|---|
| **R-1** | Wave 1 burned on stale API shapes | was HIGH, now LOW | a whole wave | §5 is quoted from the shipped 22.3.0 source. Make the tracer plan compile one real `zonedSchedule` call in wave 1. |
| **R-2** | Android build fails on missing desugaring | was HIGH, now LOW | half a day | §3.1 is the exact diff I built green (debug + release). Make it a wave-1 task with `flutter build apk --debug` as its verification. |
| **R-3** | Release manifest silently gains a privileged permission | LOW | Play rejection; breaks a locked property | §3.3's measured delta; extend `test/platform_config_test.dart` in wave 1, before any notification code lands. |
| **R-4** | `flutter_timezone` applies the Kotlin Gradle Plugin; Flutter warns "future versions of Flutter will fail to build" | MEDIUM (future) | a future Flutter upgrade blocks the build | [VERIFIED: build warning, 2026-08-17]. Accept for v1.1 — it is a warning, not an error. Record it as a known upgrade blocker. The ~25-line hand-rolled channel remains the escape hatch, and this warning is new evidence for it (prior research Q4 assumed the package had no such liability). |
| **R-5** | AGP 9 vs. plugins using removed DSL (`compileSdkVersion` string form in `flutter_timezone/android/build.gradle:39`) | was MEDIUM, now LOW | build break | Both APKs built green under AGP 9.1.0 / Gradle 9.3.1. Verified, not assumed. |
| **R-6** | Autumn-DST overlap fires an hour early on Android | MEDIUM (twice a year) | one dose reminder off by an hour | C-2. Document as accepted behaviour; do not attempt to "fix" it — java.time's rule is the platform's. |
| **R-7** | Tier-B horizon lapses silently on iOS for cycling regimens (~a week) | HIGH by design | reminders stop, no signal | Named honestly in spec §2.3. Optional 1-request sentinel notification at the tail (prior research Q2) — a product decision, not a technical one. |
| **R-8** | The `AppShell` tab-index lift churns four existing test files | HIGH | rework, not risk | §8.6 names them. Budget it in the plan rather than discovering it. |
| **R-9** | `activeRuns` lives in `features/`, which `core/` may not import | HIGH | architectural violation or duplicated cycle math | §8.1 — move `activeRuns`/`DateRun` into `lib/core/domain/`. Recommend a dedicated early task. |
| **R-10** | Notification copy frozen in the pre-change language for up to 30 days | MEDIUM | user-visible i18n bug | Pitfall 7 — add `localeControllerProvider` to the sync triggers. |
| **R-11** | iOS eviction rule at 64 is genuinely unresolved (README says "last set"; other sources say "soonest firing") | LOW | wrong reminders dropped | The 60-request budget in the pure plan means we never find out. Enforce it in the plan function, not in the service. |

---

## 14. Environment Availability

| Dependency | Required by | Available | Version | Fallback |
|---|---|---|---|---|
| Flutter SDK | everything | ✓ | 3.47.0 stable (Dart 3.13, engine 5f77625673) | — |
| Android SDK + Gradle | Android build | ✓ | AGP 9.1.0, Gradle 9.3.1, compileSdk 36 | — |
| Xcode / iOS toolchain | iOS build | not exercised this session | — | Phase 6 shipped on iOS, so it is present |
| Swift Package Manager | iOS plugin linkage | ✓ (no Podfile; `Runner.xcodeproj` carries `packageReferences`) | — | both plugins ship `Package.swift` |
| `node` / `gsd-tools` | the package-legitimacy seam | ✗ | — | manual audit performed (§Package Legitimacy Audit) |
| Physical Android device (OEM battery behaviour) | R-11 / Pitfall 11 verification | unknown | — | document only; do not gate the phase on it |

**Missing with no fallback:** none.
**Missing with fallback:** `node` (manual audit).

---

## Validation Architecture

### Test framework

| Property | Value |
|---|---|
| Framework | `flutter_test` (SDK-bundled) + `integration_test` (SDK-bundled) |
| Config file | none — `pubspec.yaml` dev_dependencies; `mocktail ^1.0.5` for mocks |
| Quick run command | `flutter test test/domain test/core` |
| Full suite command | `flutter test` |
| Device command | `flutter test integration_test/ -d <device>` |

### Phase requirements → test map

| Req | Behavior | Type | Automated command | File exists? |
|---|---|---|---|---|
| NOTIF-01 | grouping by time-of-day; count is right; only active days | unit | `flutter test test/notifications/notification_plan_test.dart` | ❌ Wave 0 |
| NOTIF-01 | tap payload routes to tab index 1 | widget | `flutter test test/widget/app_shell_test.dart` | ✅ exists, needs extension |
| NOTIF-02 | release manifest declares no exact-alarm/INTERNET; receivers present | source gate | `flutter test test/platform_config_test.dart` | ✅ exists, needs extension |
| NOTIF-02 | `scheduleMode == inexactAllowWhileIdle` on the wire | channel | `flutter test test/notifications/notification_channel_payload_test.dart` | ❌ Wave 0 |
| NOTIF-02 | plan never exceeds budget 60 / horizon 30; tier A never truncated away | unit | same as NOTIF-01 plan test | ❌ Wave 0 |
| NOTIF-03 | permission asked after first save, not at init; denied ⇒ zero scheduler calls | widget (mocked seam) | `flutter test test/features/regimen_editor_test.dart` | ✅ exists, needs extension |
| NOTIF-03 | all three Darwin request flags are `false` | source gate | new gate file | ❌ Wave 0 |
| NOTIF-04 | regimen edit / pause / delete / midnight / resume each cause exactly one debounced sync | unit (mocked seam) | `flutter test test/notifications/notification_sync_test.dart` | ❌ Wave 0 |
| NOTIF-04 | DST spring gap → 04:00+0300; autumn overlap → 03:00+0200; `.toLocal()` regression fails | unit | `flutter test test/notifications/tz_conversion_test.dart` | ❌ Wave 0 |
| NOTIF-04 | reconcile: unchanged/time-edited/deleted/rolled-over | unit | plan test | ❌ Wave 0 |
| NOTIF-01..04 | one real delivery per platform | manual / device | `flutter test integration_test/ -d <device>` | ✅ harness exists |

### Sampling rate

- **Per task commit:** `flutter test test/notifications test/domain`
- **Per wave merge:** `flutter test`
- **Phase gate:** full suite green + one observed delivery on each platform (ROADMAP criterion 5).

### Wave 0 gaps

- [ ] `test/notifications/notification_plan_test.dart` — NOTIF-01, NOTIF-02 (budget), NOTIF-04 (reconcile)
- [ ] `test/notifications/tz_conversion_test.dart` — NOTIF-04 (DST + `.toLocal()` regression)
- [ ] `test/notifications/notification_sync_test.dart` — NOTIF-04 (triggers, debounce)
- [ ] `test/notifications/notification_channel_payload_test.dart` — NOTIF-02 (wire assertions via `registerWith()` + mock channel)
- [ ] Extend `test/platform_config_test.dart` — NOTIF-02 (manifest delta, both directions)
- [ ] Allowlist entries in `test/l10n/no_hardcoded_strings_test.dart` for the channel name
- [ ] No framework install needed.

---

## Security Domain

`security_enforcement: true`, `security_asvs_level: 1` (`.planning/config.json`).

### Applicable ASVS categories

| Category | Applies | Standard control |
|---|---|---|
| V2 Authentication | no | no accounts, no network (DATA-01) |
| V3 Session Management | no | no sessions |
| V4 Access Control | **yes (device-local)** | Lock-screen exposure is the access-control surface here. `NotificationVisibility.private` on every `AndroidNotificationDetails`; on iOS, content control only (the plugin exposes no `hiddenPreviewsBodyPlaceholder`), which is precisely why the spec's count-only body is a **security control**, not a copy choice. |
| V5 Input Validation | **yes** | The notification `payload` is a string that re-enters the app on tap and can be replayed by the OS after an app update. Treat it as untrusted: validate/whitelist before acting on it (the codebase already does this for the stored locale tag, `locale_controller.dart` — same stance). |
| V6 Cryptography | no | nothing new is stored or transmitted |
| V7 Error handling / logging | **yes** | Never log supplement names in a notification failure path. |
| V10 Malicious code | **yes** | Three new third-party packages — audited above; no `postinstall`-equivalent in the pub ecosystem, but plugin native code executes at boot via the boot receiver. |
| V14 Configuration | **yes** | The manifest gate (§3.3) *is* the control. Also: the release build is still debug-signed (`test/platform_config_test.dart:124-143` records it) — unchanged pre-existing blocker, not this phase's. |

### Known threat patterns

| Pattern | STRIDE | Mitigation |
|---|---|---|
| Health-adjacent data on the lock screen | Information disclosure | count-only body, no supplement names; `visibility: private` on Android |
| Notification payload replayed/forged into a navigation action | Tampering | whitelist the payload; never `eval`/route on raw content |
| A new package adds a privileged permission via manifest merge | Elevation of privilege | measured merged-manifest gate (§3.3), asserted in CI |
| Silent loss of reminders (revoked permission, force-stop, exact-alarm throw on boot) | Denial of service | `inexactAllowWhileIdle` avoids the throw path entirely; reconcile on every resume |
| Third-party plugin executes at device boot | Elevation of privilege | inherent to `RECEIVE_BOOT_COMPLETED`; mitigated by the plugin's verified-publisher provenance and by not enabling `exported=true` on either receiver |

---

## Assumptions Log

| # | Claim | Section | Risk if wrong |
|---|---|---|---|
| A1 | iOS's `UNCalendarNotificationTrigger` behaviour when the wall clock falls in a DST gap is undocumented; assumed to match Android's forward shift | §9.4, C-2 | one dose off by an hour on iOS, twice a year. Device-verifiable. |
| A2 | iOS's eviction rule past 64 pending is unresolved (README says "last set"; other readings say "soonest firing") | R-11 | none in practice — the 60 budget means it is never reached |
| A3 | `~10–15 min` Doze jitter is derived from the 10-min `setWindow` clamp and the 7/hour while-idle quota, not from a single quoted figure | spec §2.2 | user-visible lateness larger than stated. Measure on device. |
| A4 | Package download/like counts quoted in the audit come from the 2026-08-16 research, not re-fetched today | Package Legitimacy Audit | negligible — publisher verification and archive inspection were done this session |
| A5 | The iOS build with the three packages was **not** exercised this session (no Xcode run). Android was, twice. | §2, R-2 | an iOS-only linkage surprise. Mitigated: both plugins ship `Package.swift`, deployment targets clear (13.0 ≤ 15.0), and the repo is already SPM-based. **Run `flutter build ios --simulator` as the first task of the tracer plan.** |
| A6 | The Play policy analysis for `USE_EXACT_ALARM` is carried over from prior research; not re-fetched | §Locked Decisions | none — the decision is already locked and the compliant path needs no permission |

---

## Open Questions

1. **Q-1 — Sentinel notification at the tail of the tier-B horizon?**
   *Known:* on iOS, cycling/course reminders go silent after the horizon with no signal.
   *Unclear:* whether nagging a lapsed user is wanted.
   *Recommendation:* add it, plainly worded; cost is 1 request. Product decision — surface in discuss-phase.

2. **Q-2 — The Android notification channel name is immutable and locale-frozen at creation.**
   *Known:* channels cannot be renamed by an app update; only a new id works, and that resets user
   customization. *Unclear:* whether to use a locale-neutral name or accept the first-run locale.
   *Recommendation:* decide explicitly before the first release; version the id (`doses_v1`).

3. **Q-3 — Cancel the reminder for a dose already marked taken?**
   *Recommendation:* defer to v1.2 (prior research Q3). It adds a fourth trigger on the app's most
   frequent write and makes the pure plan depend on `IntakeLog` state.

4. **Q-4 — Move `activeRuns`/`DateRun` into `lib/core/domain/`, or have the plan walk `isActiveOn`
   itself?** *Recommendation:* move (R-9). Needs a planner decision because it touches Phase-4 code
   and its tests.

5. **Q-5 — Keep `flutter_timezone` given the KGP deprecation warning (R-4)?**
   *Recommendation:* keep for v1.1; record as an upgrade blocker. Reconsider if a Flutter upgrade
   fails.

---

## Sources

### Primary — HIGH confidence (executed or read from source this session)

- **`flutter_local_notifications` 22.3.0 archive**, downloaded from
  `https://pub.dev/api/archives/flutter_local_notifications-22.3.0.tar.gz` and read in full:
  `pubspec.yaml`, `lib/src/flutter_local_notifications_plugin.dart`,
  `lib/src/platform_flutter_local_notifications.dart`,
  `lib/src/platform_specifics/darwin/initialization_settings.dart`,
  `lib/src/platform_specifics/android/{schedule_mode,enums,notification_channel,notification_details}.dart`,
  `lib/src/{helpers,typedefs,tz_datetime_mapper}.dart`, `android/AndroidManifest.xml`,
  `android/build.gradle`, `android/src/main/java/.../FlutterLocalNotificationsPlugin.java`,
  `ios/flutter_local_notifications.podspec`, `ios/flutter_local_notifications/Package.swift`,
  `README.md`, `example/ios/Runner/AppDelegate.swift`
- **`flutter_local_notifications_platform_interface` 12.2.0 archive** — `lib/src/{types,typedefs,helpers}.dart`,
  `lib/flutter_local_notifications_platform_interface.dart`
- **`flutter_timezone` 5.1.0** from `~/.pub-cache` — `lib/{flutter_timezone,timezone_info}.dart`,
  `android/build.gradle`, `ios/flutter_timezone/Package.swift`
- **Executed probes** (`/tmp/flnprobe`, `flutter test`, 2026-08-17): `defaultTargetPlatform`
  under FLUTTER_TEST; `LateInitializationError` on every plugin path; `registerWith()` + mock
  method channel capturing the full `zonedSchedule` payload; past-date `ArgumentError`;
  Europe/Kyiv DST gap and overlap normalization; `latest.dart` vs `latest_all.dart` on
  `Europe/Kiev`
- **Executed builds** (2026-08-17): `flutter pub get` against this repo's real pubspec +3 deps
  (`/tmp/bqresolve`); `flutter build apk --debug` and `--release` with the packages and edits
  (`/tmp/bqbuild`); `flutter build apk --release` pristine baseline (`/tmp/bqbase`); merged
  release manifests dumped from both
- **Flutter SDK 3.47.0 source**: `packages/flutter/lib/src/foundation/_platform_io.dart`,
  `packages/flutter_tools/gradle/src/main/kotlin/FlutterExtension.kt`
- **This repo, read in full or in part**: `lib/core/domain/{models,cycle_math,repositories}.dart`,
  `lib/core/{providers,today_controller}.dart`, `lib/core/l10n/{l10n,locale_controller}.dart` +
  `gen/app_localizations.dart`, `lib/main.dart`, `lib/app_shell.dart`,
  `lib/features/calendar/{planner_view_model,day_view_model,calendar_providers,today_screen}.dart`,
  `lib/features/stack/regimen_editor_controller.dart`, `lib/core/widgets/bq_add_fab.dart`,
  `test/platform_config_test.dart`, `test/l10n/no_hardcoded_strings_test.dart`,
  `android/app/build.gradle.kts`, `android/settings.gradle.kts`,
  `android/app/src/{main,debug}/AndroidManifest.xml`, `ios/Runner/{AppDelegate,SceneDelegate}.swift`,
  `ios/Runner/Info.plist`, `pubspec.yaml`, `l10n.yaml`, `.planning/config.json`

### Secondary — MEDIUM confidence

- [pub.dev/packages/flutter_local_notifications](https://pub.dev/packages/flutter_local_notifications) — version, publish date, publisher
- [pub.dev/packages/timezone](https://pub.dev/packages/timezone) — 0.11.1, tzdata 2025c
- [pub.dev/packages/flutter_timezone](https://pub.dev/packages/flutter_timezone) — 5.1.0, publisher
- `docs/research/2026-08-16-notifications-research.md` — platform constraints, Play policy, iOS 64 cap, OEM behaviour (settled; corrected in §10 where verified otherwise)
- `docs/superpowers/specs/2026-08-17-boostque-v1.1-design.md` §2 — the approved architecture
- [flutter_local_notifications#2405](https://github.com/MaikuB/flutter_local_notifications/issues/2405), [#2389](https://github.com/MaikuB/flutter_local_notifications/issues/2389), [flutter#161964](https://github.com/flutter/flutter/issues/161964) — the desugaring failure mode
- [flutter_local_notifications#2721](https://github.com/MaikuB/flutter_local_notifications/issues/2721) — stale README iOS instructions vs UIScene (does not affect us)

### Tertiary — LOW confidence / unresolved

- iOS DST-gap resolution for `UNCalendarNotificationTrigger` (A1) — no authoritative source found
- iOS eviction order past 64 pending (A2) — two credible sources disagree
- Doze latency figure (A3) — derived, not quoted

---

## Metadata

**Confidence breakdown:**

- Package versions & resolution: **HIGH** — resolved against this repo's real pubspec and built
- Platform setup (Android): **HIGH** — both APKs built; merged manifests dumped before/after
- Platform setup (iOS): **MEDIUM-HIGH** — plugin/SPM/deployment-target facts verified from source,
  but no Xcode build run (A5)
- API surface: **HIGH** — quoted from the shipped 22.3.0 archive, several calls executed
- Permission mechanics: **HIGH** on signatures/returns; **MEDIUM** on OS-level repeat-prompt
  behaviour (carried from prior research)
- Timezone init & DST: **HIGH** for Dart-side (executed); **MEDIUM** for iOS native gap behaviour (A1)
- Testability: **HIGH** — both seams executed
- Existing-code hooks: **HIGH** — every symbol read at the cited line

**Research date:** 2026-08-17
**Valid until:** 2026-09-16 (30 days). `flutter_local_notifications` is on a fast minor cadence
(22.3.0 was ~9 days old at research time) — re-check the version before the phase starts if more
than a month passes.
