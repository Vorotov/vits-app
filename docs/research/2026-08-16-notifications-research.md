# Local dose notifications for VitoMy v1.1 — research

**Date:** 2026-08-16
**Scope:** local (non-push) dose reminders on iOS + Android for the existing Flutter/Riverpod/Drift codebase
**Status:** research only — no code written, no packages added
**Confidence overall:** HIGH on platform constraints and package choice; MEDIUM on two named edge cases (iOS DST-gap behaviour, iOS eviction order at the 64 cap), both flagged inline and both device-verifiable.

---

## Summary

Three facts drive the entire design, and two of them are hard limits that cannot be engineered around.

**1. iOS allows exactly 64 pending local notification requests per app, system-wide, with no workaround.** An Apple engineer restated this in January 2026 on the developer forums: *"there is a limit of 64 for how many simultaneous notification requests can be active/pending at one time per app. This is a system limit and there is no way around it."* A **repeating** request counts as **one** against the cap no matter how many times it fires. With 6 slots/day and several supplements, a naive "schedule every future dose" plan exhausts the cap in days.

**2. Google Play forbids `USE_EXACT_ALARM` for this app.** The Play policy grants the auto-granted exact-alarm permission only to two app categories, quoted verbatim from the Play Console policy page: *"The app is an alarm or timer app"* and *"The app is a calendar app that shows event notifications."* A supplement reminder is neither, and the policy explicitly does not list medication or health reminders. Declaring `USE_EXACT_ALARM` risks rejection. The compliant choice is **inexact alarms** (`AndroidScheduleMode.inexactAllowWhileIdle`), which Android's own docs recommend for reminder apps and which need **no permission at all**: *"If your app doesn't need to invoke an alarm at an exact time... use an inexact alarm. Specifically, call `setAndAllowWhileIdle()`."* The cost is delivery jitter of roughly 10–15 minutes when the device is dozing — acceptable for "take your magnesium," unacceptable for an alarm clock.

**3. The platform cannot conditionally suppress a scheduled local notification.** There is no delivery-time hook for local notifications on either platform (iOS's `UNNotificationServiceExtension` applies to *remote* push only). So "one daily repeating notification per slot, suppressed on off-days" — the obvious way to beat the 64 cap — is **not implementable**. Off-day suppression must happen at *scheduling* time, not delivery time.

The recommendation is a **two-tier hybrid**: regimens that are active every single day (cyclic, `offDays == 0`, no end) get one *repeating* request per slot — cost 1 against the cap, correct forever, self-healing across DST. Everything else (cyclic with breaks, courses) gets *one-shot* requests over a rolling horizon, budget-capped and topped up whenever the app comes to the foreground. The honest failure mode of tier two is stated in §5.

Everything the scheduler needs already exists in `lib/core/domain/`: `isActiveOn` decides active days, `activeRuns` (in `planner_view_model.dart`) already coalesces them, and `DoseSlot.minutesFromMidnight` is already a timezone-independent wall-clock value. The new code is one pure function plus a thin plugin adapter.

**Primary recommendation:** add `flutter_local_notifications ^22.3.0`, `timezone ^0.11.1`, `flutter_timezone ^5.1.0`; use `AndroidScheduleMode.inexactAllowWhileIdle` (no exact-alarm permission, Play-compliant); schedule via the two-tier hybrid with a 60-request budget; put the whole plan in a pure, clock-free function in `lib/core/domain/` and hide the plugin behind a `NotificationScheduler` interface in the existing repository-interface style.

---

## 1. Package recommendation

### What gets added

| Package | Version | Necessary because | Verdict |
|---|---|---|---|
| `flutter_local_notifications` | `^22.3.0` (published ~8 days before 2026-08-16) | The only mature, maintained option. 2.5M weekly downloads, 7.3k likes, 150/150 pub points, BSD-3. Requires Flutter ≥ 3.38.1 (we run 3.47.0 ✓), Android minSdk 24 (Flutter default is 24 ✓), compileSdk 36 (targetSdk is already 36 ✓), iOS 13+ (deployment target is 15.0 ✓), Java 17 (already set in `build.gradle.kts` ✓). | **Required.** |
| `timezone` | `^0.11.1` (labs.dart.dev, verified publisher, ~48 days old, 2.99M weekly downloads) | Pulled in transitively by the plugin, but app code must `import 'package:timezone/timezone.dart'` to construct `TZDateTime` and `import 'package:timezone/data/latest_all.dart'` to load the database. Importing a transitive dependency without declaring it is a lint error and a breakage waiting to happen. | **Required as a direct dependency.** |
| `flutter_timezone` | `^5.1.0` (wolverinebeach.net, verified, ~2 months old, 823k weekly downloads, 150 pub points) | `timezone` has no way to read the device's IANA zone, and Dart has no such API either — `DateTime.now().timeZoneName` returns an abbreviation ("EET"), not `Europe/Kyiv`. The plugin's own docs say you must get this from native code or a package. Exposes `FlutterTimezone.getLocalTimezone()`. | **Required unless we hand-roll** (see below). |

Nothing else. No permission-handler package: `flutter_local_notifications` exposes `requestNotificationsPermission()` (Android) and `requestPermissions(...)` (iOS) directly.

### The one place the "zero new packages" rule could be honoured harder

`flutter_timezone` can be replaced by ~25 lines of platform channel: `TimeZone.current.identifier` on iOS, `java.time.ZoneId.systemDefault().getId()` on Android. That removes a third-party dependency from a project that currently has none of consequence.

**Recommendation: take the package anyway.** A hand-rolled channel adds Swift + Kotlin surface to a project that today has zero custom native code, needs its own integration test on both platforms, and re-implements exactly what an actively-maintained, verified-publisher package with 823k weekly downloads already does. The dependency is smaller than the maintenance it replaces. Worth surfacing as a decision (see Open Questions Q4) since it's a defensible call either way.

### Alternative considered and rejected

**`awesome_notifications` (0.12.1, ~45 days old, 3.4k likes).** Still pre-1.0 and self-describes as *"plugin under development"* with per-platform percentage-complete estimates. It confirms the same iOS 64 limit, so it buys nothing on the hard constraint. Richer scheduling model (`NotificationAndroidCrontab`) that this app does not need. Rejected on maturity for an app whose core promise is that the reminder actually arrives.

**Firebase Cloud Messaging / any push approach.** Rejected on the locked constraint: VitoMy ships with no `INTERNET` permission in the release manifest and no backend. Off the table.

### Installation

```bash
flutter pub add flutter_local_notifications timezone flutter_timezone
```

### Platform config changes required

**`android/app/src/main/AndroidManifest.xml`** — add inside `<manifest>`:

```xml
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
```

and inside `<application>`:

```xml
<receiver android:exported="false"
  android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver" />
<receiver android:exported="false"
  android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
  <intent-filter>
    <action android:name="android.intent.action.BOOT_COMPLETED"/>
    <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>
    <action android:name="android.intent.action.QUICKBOOT_POWERON"/>
    <action android:name="com.htc.intent.action.QUICKBOOT_POWERON"/>
  </intent-filter>
</receiver>
```

Note: `POST_NOTIFICATIONS` and `VIBRATE` are declared by the **plugin's own manifest** and arrive via manifest merge — do **not** add them by hand. Verified by reading the plugin's `android/src/main/AndroidManifest.xml`, which contains exactly those two `<uses-permission>` entries and nothing else. **Do not declare `SCHEDULE_EXACT_ALARM` or `USE_EXACT_ALARM`** (see §3).

The boot receiver's four actions are read directly from `ScheduledNotificationBootReceiver.java`, which calls `rescheduleNotifications(context)` for `ACTION_BOOT_COMPLETED`, `ACTION_MY_PACKAGE_REPLACED`, and the two QUICKBOOT variants. `MY_PACKAGE_REPLACED` is what makes Android self-heal after an app update — worth having even though the README's snippet omits it.

**`ios/Runner/AppDelegate.swift`** — one line to add, inside `didFinishLaunchingWithOptions`:

```swift
UNUserNotificationCenter.current().delegate = self as UNUserNotificationCenterDelegate
```

**Good news on iOS setup:** the plugin has an open issue (#2721, opened 2025-11-15, still open) that its README iOS instructions predate Flutter's `UISceneDelegate` migration. **This project is already correct.** `ios/Runner/AppDelegate.swift` already conforms to `FlutterImplicitEngineDelegate` and registers plugins in `didInitializeImplicitFlutterEngine`; `ios/Runner/SceneDelegate.swift` already subclasses `FlutterSceneDelegate`; `Info.plist` already declares `UIApplicationSceneManifest`. That is exactly the shape Flutter's UIScene breaking-change guide requires, and it is what the plugin's own example app migrated to in v21.0.0. No migration work.

---

## 2. iOS constraints

| Question | Answer | Confidence |
|---|---|---|
| Is the cap still 64? | **Yes. 64 pending requests per app.** Restated by an Apple engineer in an accepted answer, thread posted Dec 2025, answered Jan 2026: *"This is a system limit and there is no way around it."* | HIGH |
| Do repeating notifications count against it? | **A repeating request counts as 1**, regardless of how many deliveries it produces. This is what makes tier one of the recommended architecture viable. | HIGH |
| Which requests are dropped when you exceed 64? | **Unresolved.** Apple's docs/forums are read by some as "the system keeps the soonest-firing 64"; the plugin's README states *"iOS will only keep the 64 notifications that were last set."* These are different rules with different consequences. **Design so we never find out** — enforce the budget in our own code (§5). | LOW — do not depend on either reading |
| Permission timing / UX | One system prompt, ever. Once the user answers, `requestPermissions` returns the stored answer and shows nothing. There is no second chance. See §6. | HIGH |
| Survive app update? | **Yes**, per an Apple engineer (Jan '25): *"Scheduled local notifications will persist after an app update as long as you have not changed the app's bundle id."* One developer in that same thread posted a reproducible counter-case that Apple did not follow up on. Since our design reschedules on every foreground, this is self-healing either way — but it is a reason **not** to change the bundle id casually. Note: the bundle id is still the placeholder `app.vitomy`; **changing it before release wipes every pending notification on existing installs.** | MEDIUM (self-healing, so low risk) |
| Survive reinstall? | No — deleting the app removes its notifications. The plugin README warns that on older iOS versions notifications scheduled before an uninstall could reappear after reinstall, and suggests clearing on first launch. Cheap insurance: on first-ever launch, `cancelAll()` before scheduling. | MEDIUM |
| Fire if the app has never been opened since boot? | **Yes.** Local notification requests are held and delivered by the system, not by the app process; the app is not launched or woken to deliver them. iOS has no "app must have run since boot" gate — that is an Android-only concern. | HIGH |
| Time zone handling | Verified by reading the plugin's `FlutterLocalNotificationsPlugin.m`: `buildUserNotificationCalendarTrigger:` builds an `NSTimeZone` from the passed zone name, sets it on both the date formatter and the `NSCalendar`, then extracts `NSDateComponents` and creates a `UNCalendarNotificationTrigger`. Without `matchDateTimeComponents` it extracts year/month/day/hour/minute/second and uses `repeats:NO`. With `DateTimeComponents.time` it extracts only hour/minute/second and uses **`repeats:YES`**. | HIGH |

**Consequence of the trigger detail:** `matchDateTimeComponents: DateTimeComponents.time` produces a genuine OS-level daily repeat on iOS, evaluated by the system calendar in the stored zone. It survives DST correctly (the OS re-resolves 09:00 local each day) and costs one slot of the 64. That is precisely what tier one exploits.

---

## 3. Android constraints

### POST_NOTIFICATIONS (Android 13+)

Runtime permission, denied until asked. Request with `AndroidFlutterLocalNotificationsPlugin.requestNotificationsPermission()` (returns `Future<bool?>`). The permission itself is declared by the plugin's manifest — no app-side declaration needed. Two dismissals mark it permanently denied; from then on only `openAppNotificationSettings()` (added in plugin v22.3.0) can help.

### Exact alarms — the policy answer

**Do not use `USE_EXACT_ALARM`.** The Google Play policy grants it only when *"your app's core, user facing functionality requires precisely-timed actions"*, and enumerates two cases verbatim: *"The app is an alarm or timer app"* and *"The app is a calendar app that shows event notifications."* Medication and health reminders are **not** listed. The policy's own escape hatch: *"If you have a use case for exact alarm functionality that's not covered above, you should evaluate if using `SCHEDULE_EXACT_ALARM` as an alternative is an option."*

**Do not use `SCHEDULE_EXACT_ALARM` either** — not for policy reasons, but for reliability ones:

- Since Android 14 it is **not pre-granted** to fresh installs of apps targeting API 33+, and a backup-and-restore migration lands on the new device with it **denied**.
- The user (or the system) can revoke it at any time; on revocation *"your app stops and all future exact alarms are canceled."*
- The plugin **throws** when it's missing rather than degrading. Verified in `FlutterLocalNotificationsPlugin.java`: `checkCanScheduleExactAlarms()` throws `ExactAlarmPermissionException` when `!alarmManager.canScheduleExactAlarms()` on API 31+, surfacing to Dart as `PlatformException(exact_alarms_not_permitted)`. Worse, in `rescheduleNotifications(context)` — the **boot** path — the same exception is caught and the notification is **silently dropped from the plugin's cache** with only a `Log.e`. So a user who revokes the permission and reboots loses every reminder with no signal anywhere.

**Use `AndroidScheduleMode.inexactAllowWhileIdle`.** Verified against `ScheduleMode.java` (values: `alarmClock`, `exact`, `exactAllowWhileIdle`, `inexact`, `inexactAllowWhileIdle`) and `setupAllowWhileIdleAlarm(...)`: `inexactAllowWhileIdle` has `useExactAlarm() == false` and `useAlarmClock() == false`, so it calls `AlarmManagerCompat.setAndAllowWhileIdle(...)` and **never reaches `checkCanScheduleExactAlarms`**. No permission, no throw, no Play-policy exposure, and it still fires during Doze. This is verbatim what Android's own alarm docs recommend for reminder apps.

The tradeoff, stated plainly: expect the reminder within roughly 10–15 minutes of the scheduled time when the device is dozing, and near-exact when the screen is on. `setWindow()`-class inexact alarms are clipped to a 10-minute minimum window on Android 12+, and while-idle alarms are throttled to 7 per hour during Doze. For a supplement reminder this is the right trade; for an alarm clock it would not be.

### Doze, App Standby buckets, and the rarely-opened-app problem

Android's power-management limits, quoted from the official table:

| Bucket | Alarms |
|---|---|
| Active | No limits |
| Working set | 10 per hour |
| Frequent | 2 per hour |
| Rare | 1 per hour |
| Restricted | **One alarm per day**, exact or inexact |

VitoMy is a daily-open app by design, so it should sit in Active/Working set for engaged users. But a user who stops opening it drifts toward Rare — and at 6 slots/day the "1 per hour" cap does not bite (doses are hours apart), while "Restricted" (1/day) would. Android 16 (API 36, our target) *enforces* bucket quotas more aggressively than earlier releases. This is a real degradation curve for lapsed users and is worth a line in the design doc rather than a surprise in a bug report.

### Reboot

Alarms do not survive reboot; the plugin's `ScheduledNotificationBootReceiver` re-arms them. Verified in the Java source: `rescheduleNotifications(context)` reads the plugin's own persisted cache (Gson-serialised `NotificationDetails` in SharedPreferences, via `loadScheduledNotifications`) and re-schedules each one **without needing a Flutter engine or the app to be launched**. That works — but note it means the plugin keeps a **second, parallel copy of scheduling state** outside our Drift database. The two can drift apart (an exact-alarm failure at boot silently prunes the cache, as above). Our reconciliation strategy (§5) treats `pendingNotificationRequests()` as the source of truth about *what is scheduled* and the DB as the source of truth about *what should be* — which resolves this cleanly.

**Stopped-state gotcha:** an app that has been **force-stopped** by the user receives no broadcasts at all, including `BOOT_COMPLETED`, until the user manually launches it again. Force-stop also cancels all pending alarms. Nothing can be done about this in code; it is worth knowing when triaging "notifications stopped working" reports.

### Manufacturer battery killers

`dontkillmyapp.com` documents the landscape; the ones that matter:

- **Xiaomi / MIUI, Huawei / EMUI:** apps need an explicit **"Autostart" / "Background autostart"** permission to run after boot or to be re-woken. Off by default for third-party apps. Without it the boot receiver never runs.
- **Samsung One UI:** puts unused apps into **"sleeping" / "deep sleeping"**; a deep-sleeping app has its alarms deferred and background work blocked entirely. Samsung ranks worst on the community scorecard.
- **OnePlus / OPPO / vivo:** "App Auto-Launch" toggle, similarly off by default on some models.

There is no API to detect or fix this. The standard mitigation is a one-time in-app hint pointing the user at battery settings on affected OEMs. That is a **UX decision, not a technical one** — see Open Questions Q5. Given that Settings UI is deferred for v1.1, the pragmatic answer is probably "document it, don't build it yet."

### Notification channel — get it right the first time

Android notification channels are **immutable after creation**: importance, sound, vibration, and lock-screen visibility set at creation cannot be changed by an app update. Create the channel explicitly at init via `createNotificationChannel(AndroidNotificationChannel(...))` rather than letting it be created implicitly on first `show()`, so the channel exists in system Settings before the first notification. If the settings turn out wrong post-release, the only fix is a new channel id — which resets any customisation the user made. Pick `Importance.high` (heads-up) and `NotificationVisibility.private` (see §8) and treat the channel id as versioned (`doses_v1`).

---

## 4. Integration with the existing domain

### The conversion boundary — exactly one line, in exactly one place

The codebase's `dateOnly()` rule is *"use the y/m/d fields of the input as-is — a local wall-clock value maps to the UTC calendar day with the same date fields, never local midnight (D-13)."* The notification layer needs the **exact inverse**, and it is the only place in the app that ever performs it:

```dart
// lib/core/notifications/tz_conversion.dart — the ONLY place a date-only
// UTC value and a wall-clock minute become a real instant.
tz.TZDateTime fireInstant(DateTime dayUtc, int minutesFromMidnight) =>
    tz.TZDateTime(
      tz.local,
      dayUtc.year, dayUtc.month, dayUtc.day,   // fields, not .toLocal()
      minutesFromMidnight ~/ 60,
      minutesFromMidnight % 60,
    );
```

**Never `dayUtc.toLocal()`.** For any user west of UTC, `DateTime.utc(2026, 8, 16).toLocal()` is 2026-08-15 — a whole day of reminders silently shifted. The date-only value is a *label*, not an instant; only its fields are meaningful. This mirrors `dateOnly()`'s doc comment exactly and should carry the same warning.

### DST — what actually happens to a 03:00 dose

Ukraine still observes DST: parliament passed abolition (Law 4201, July 2024) but the President did not sign it, and the changes continue — the next autumn transition is 2026-10-25, 04:00 → 03:00. So in `Europe/Kyiv`:

- **Spring forward (last Sunday of March, 03:00 → 04:00):** the hour 03:00–03:59 **does not exist**. A 03:00 dose has no valid instant that day.
- **Autumn back (last Sunday of October, 04:00 → 03:00):** the hour 03:00–03:59 **occurs twice**.

Behaviour, verified from source:

- **Android — deterministic.** `zonedScheduleNotification` computes `ZonedDateTime.of(LocalDateTime.parse(scheduledDateTime), ZoneId.of(timeZoneName)).toInstant().toEpochMilli()`. `java.time`'s documented resolution rules: a **gap** shifts forward by the gap length → the 03:00 dose fires at **04:00**; an **overlap** picks the **earlier** offset → fires at the **first** 03:00, once. No duplicate, no miss.
- **Android repeats — DST-safe.** `getNextFireDateMatchingDateTimeComponents` rebuilds the next fire from `now`'s date plus the *stored wall-clock* hour/minute in the stored `ZoneId`, then advances by whole days until it is in the future. Wall-clock time is preserved across DST rather than a fixed 24h interval being added. Correct.
- **iOS — expected-correct but unverified.** `UNCalendarNotificationTrigger` resolves the components against the system calendar in the stored zone, which handles the overlap; behaviour in a **gap** is not documented and I could not find an authoritative statement. `[ASSUMED]` — verify on device.

**Practical mitigation, and it is cheap:** the `timezone` package is pure Dart and runs in `flutter test`. `tz.TZDateTime(getLocation('Europe/Kyiv'), 2027, 3, 28, 3, 0)` can be asserted in a unit test, and whatever it normalises to is what both platforms receive — the Dart side normalises *before* the plugin is called. So the gap/overlap behaviour is pinned by a unit test, not left to platform archaeology. Add one test per transition direction.

**Also worth flagging to the user:** twice a year, one dose lands at a nominally wrong time (or, in the autumn overlap, a user could reasonably expect two). Nobody dies from taking creatine at 04:00 instead of 03:00, but it should be a known-and-accepted behaviour rather than a bug report.

### tzdata staleness — a genuine footgun

`timezone 0.11.1` bundles **IANA tzdata 2025c**. If a country changes its DST rules (Ukraine's own abolition law could be signed at any time), the app schedules against stale rules until the package is bumped and a new build ships. Nothing to do about it beyond knowing it, and re-running `flutter pub upgrade` before each release.

Load `package:timezone/data/latest_all.dart` (443 KB), **not** `latest.dart` (361 KB). The 82 KB buys the deprecated aliases — and `flutter_timezone` returns whatever identifier the OS reports, which on some Android builds is still **`Europe/Kiev`**, a deprecated alias absent from the trimmed database. Wrap `tz.getLocation(name)` in a try/catch that falls back to UTC and reports via `FlutterError.reportError` rather than crashing, in the same spirit as `main()`'s existing SharedPreferences degradation.

### Reschedule triggers — where they hook into the existing graph

The plan must be recomputed when any of these change:

| Trigger | Hook | Notes |
|---|---|---|
| Regimen created / edited / paused / deleted | `regimensStreamProvider` emits | Already reactive. `dayDosesProvider` uses the same trick (`ref.watch(regimensStreamProvider)`), so this is an established pattern. Supplement rename changes notification *text* — watch `stackEntriesProvider` instead to catch both. |
| App foregrounded | `AppLifecycleListener(onResume:)` | `TodayController` already owns one; a second listener is fine, or reuse via `ref.listen(todayProvider, ...)`. The foreground top-up is what keeps the rolling horizon alive. |
| Local midnight rollover | `todayProvider` emits a new day | Already implemented, already DST-safe (`nextLocalMidnight`), already tested. Free. |
| Permission granted | after `requestNotificationsPermission()` / `requestPermissions()` returns true | First-ever schedule. |
| Dose marked taken/skipped | `dayDosesProvider` | **Optional** — see Open Questions Q3. |

A single `notificationSyncProvider` watching `stackEntriesProvider` + `todayProvider` covers the first three. It must **debounce**: the regimen editor's save writes the regimen and reconciles slots in one transaction but the stream may emit more than once, and each sync is dozens of platform-channel round-trips.

**Architecture fit:** define `abstract class NotificationScheduler` in `lib/core/domain/` alongside the three existing repository interfaces, and put the `flutter_local_notifications` implementation in `lib/core/notifications/`. This is exactly the D-22 pattern (`UI and state code depend on the interfaces only`), and it keeps every widget test free of the plugin's platform channels — which otherwise throw `MissingPluginException` in `flutter test`.

---

## 5. Scheduling architecture

### The arithmetic that rules out the naive approach

A realistic stack — 8 supplements, average 1.5 slots each — is **12 notifications per active day**. At 64 requests that is **5.3 days** of coverage, before any headroom. At 6 slots on a single regimen plus a few others, worse. "Schedule everything" is not an option on iOS.

### Option (a): pure rolling horizon

Schedule every dose from now until the budget runs out; top up on foreground.

- ✅ Exactly correct on off-days (only active days are ever scheduled).
- ✅ One code path, no special cases.
- ❌ Coverage ends at ~4–5 days. A user who doesn't open the app for a week gets **silence** — and silence is the failure mode most likely to make them think the feature is broken. Worst of all, the failure is invisible.

### Option (b): daily repeating per slot + in-app suppression

- ❌ **Not implementable.** There is no delivery-time hook for local notifications on either platform. iOS's `UNNotificationServiceExtension` intercepts *remote* push only; local notifications are delivered by the system daemon without waking the app. Android's plugin gives no cancellation callback and the app process may not even be alive. A repeating notification for a 5-on/2-off regimen would fire on the two off days, every week, forever. Wrong behaviour, not a tradeoff.
- ✅ But the *degenerate case is correct and free*: a regimen with no off-days and no end date is active every day, so a daily repeat needs no suppression at all.

### Option (c): the hybrid — **recommended**

Partition regimens at plan time:

**Tier A — perpetual daily.** `kind == cyclic && offDays == 0 && !paused` (and, per `isActiveOn`, `onDays > 0`). Every day from `startDate` onward is active, forever.
→ One `zonedSchedule` per slot with `matchDateTimeComponents: DateTimeComponents.time`, anchored at the next occurrence.
→ **Cost: 1 request per slot. Coverage: unbounded.** Verified DST-safe on Android (wall-clock recomputation) and on iOS (`repeats:YES` `UNCalendarNotificationTrigger`, system-resolved).
→ Caveat: if `startDate` is in the future, the repeat must not be armed until then — schedule a one-shot for the first day and promote to a repeat on a later sync, or simply treat future-start regimens as tier B until they start (simpler; recommended).

**Tier B — bounded or intermittent.** Everything else: cyclic with `offDays > 0`, and all courses.
→ One one-shot `zonedSchedule` per (slot, active day), generated by walking `isActiveOn` day by day over `[today, today + horizonDays]` — or better, by reusing the existing `activeRuns(regimen, from, toInclusive)` from `planner_view_model.dart`, which already coalesces active days into runs and is already tested.
→ Sorted by fire instant ascending, then **truncated at the remaining budget**.

**Budget:** `budget = 60` on iOS (64 minus 4 headroom, because we do not trust either reading of the eviction rule). Android has no cap — use a **time-based** horizon there instead (30 days is comfortable; the plugin persists them and re-arms on boot). The pure plan function takes `budget` and `horizonDays` as parameters, so the platform difference lives in one provider, not in the domain.

**Greedy truncation is the right rule:** taking the first N by fire time maximises *contiguous* coverage. Taking them per-regimen round-robin would give partial coverage of everything and complete coverage of nothing.

### Failure mode of the recommendation, stated honestly

| Scenario | Outcome |
|---|---|
| Daily-cycle supplements, user never opens app for a month | ✅ **Reminders keep arriving.** Tier A repeats indefinitely. This is the common case and it just works. |
| Cyclic 5-on/2-off, user doesn't open app for 2 weeks (iOS) | ❌ **Reminders stop** once the tier-B budget horizon is passed (~4–7 days, depending on how much budget tier A leaves). Silent. |
| Same, Android | ✅ Fine — 30-day horizon, no cap. |
| Course ending in 3 weeks | ✅ Correct within the horizon; needs a top-up. Notably, **courses must be one-shots, never repeats** — a repeating request for a course would keep firing forever after the course ends unless the app is opened to cancel it. |
| Device reboot | ✅ iOS: unaffected. Android: boot receiver re-arms from the plugin's own cache. |
| App force-stopped (Android) | ❌ All alarms cancelled; no `BOOT_COMPLETED` until manual launch. Unfixable. |
| DST transition | ✅ Tier A recomputes wall-clock; tier B is rescheduled on the next foreground anyway. |

**Mitigation for the tier-B silent gap, cost 1 request:** schedule a **sentinel** notification at the tail of the horizon — *"Відкрийте VitoMy, щоб оновити нагадування."* It converts a silent failure into a visible, actionable one. This is the standard workaround for the iOS cap and it is honest with the user. It is also a product decision, not a technical one (see Open Questions Q2). The counter-argument: VitoMy's core loop *is* opening the app daily to check doses off, so a user who hasn't opened it in a week has already stopped using it, and nagging them may not be wanted.

### Notification identity — the piece that makes reconciliation work

Both platforms key notifications by `int` id (iOS stringifies it). Our domain keys by UUID slot id + date. Bridge:

```
Tier A: id = fnv1a32("R|$slotId|$hhmm")        & 0x7fffffff
Tier B: id = fnv1a32("O|$slotId|$yyyy-mm-dd|$hhmm") & 0x7fffffff
```

Use a hand-written FNV-1a in the domain layer — **not** `String.hashCode`, which Dart does not guarantee to be stable across SDK versions or platforms. Ten lines, pure, trivially testable.

**Why the fire time is inside the hash:** `pendingNotificationRequests()` returns only `id`, `title`, `body`, `payload` — **not** the scheduled time. So a slot whose time was edited from 09:00 to 10:00 would be indistinguishable from an unchanged one if the id were derived from the slot id alone. Folding the wall-clock time into the hash makes "the time changed" show up as "different id", and a plain set-difference on ids becomes an exactly-correct reconciliation:

```dart
({Set<int> toCancel, List<PlannedNotification> toSchedule}) reconcile(
  List<PlannedNotification> desired,
  Set<int> pending,
);
```

Pure. Testable. No `cancelAll()`, which would also dismiss reminders the user hasn't acted on yet and would leave a window with nothing scheduled.

Collision risk across ~60 live ids in a 2^31 space is on the order of 10⁻¹² — ignorable. Put the slot id and date in the `payload` so a future deep-link-on-tap has what it needs.

### Sketch of the pure function (the whole point of the design)

```dart
// lib/core/domain/notification_plan.dart — pure. No clock, no tz, no plugin,
// no Flutter. Imports models.dart, cycle_math.dart, repositories.dart only.
List<PlannedNotification> planNotifications({
  required List<StackEntry> stack,   // existing view model: supplement + regimen
  required DateTime today,           // dateOnly() UTC, passed in — never read
  required int horizonDays,
  required int budget,
});
```

`PlannedNotification` carries `{int id, DateTime day, int minutesFromMidnight, bool repeatsDaily, String payload}` — dates and minutes, **no `TZDateTime`**, so the domain stays free of the `timezone` package. The adapter converts.

---

## 6. Permissions UX

**When to ask: on the first successful regimen save — not at first launch.**

iOS gives exactly one system prompt for the app's lifetime; Android 13+ effectively gives two before permanent denial. Asking cold at first launch, before the user has entered a single supplement, spends that one shot at the moment the user has the least reason to say yes. Asking right after they've defined a schedule — the moment the app has something to remind them *about* — is when the request is self-explanatory. A short pre-prompt sheet before the system dialog ("VitoMy can remind you at each dose time. Reminders never leave your phone.") is the standard pattern and is worth the one extra screen, given there is no retry.

**Critical implementation detail:** `DarwinInitializationSettings` defaults `requestAlertPermission`, `requestSoundPermission`, `requestBadgePermission` all to **`true`** — meaning a default `initialize()` fires the iOS prompt immediately on first launch, exactly what we're trying to avoid. **Set all three to `false`** and call `IOSFlutterLocalNotificationsPlugin.requestPermissions(alert: true, badge: true, sound: true)` explicitly at the chosen moment.

**When denied:** the app must remain fully usable — it already is; notifications are additive to a manual check-off loop. Concretely:
- Never block, never re-prompt, never nag on launch.
- Store nothing about the denial; ask the platform (`checkPermissions()` on iOS, `areNotificationsEnabled()` on Android) so the app tracks reality rather than a stale local flag.
- The only affordance: a passive row that appears **only when permission is absent**, with a button calling `openAppNotificationSettings()` (v22.3.0, both platforms). Settings screen already exists (`features/settings/settings_screen.dart`) even though the *notification settings UI* is deferred — one status row is not a settings UI.

**`requestProvisionalPermission` (iOS 12+):** delivers quietly to Notification Center with no prompt, and the user can promote it later. Tempting for a no-friction v1.1, but a dose reminder that never appears as a banner is a reminder that doesn't remind. **Recommend against.**

**Open question this raises:** if a user denies and there is no notification settings UI in v1.1, is a single status row in Settings enough discoverability? See Open Questions Q6.

---

## 7. Testing strategy

The design deliberately puts everything interesting on the pure side of one seam.

### Genuinely unit-testable (`flutter test`, no device)

| What | How |
|---|---|
| **The plan itself** — which notifications should exist for a given stack, today, horizon and budget | `planNotifications(...)` is pure and clock-free, in the exact style of the existing `activeRuns` / `day_view_model` functions. Cases: cyclic no-break → tier A repeat; cyclic 5/2 → only active days; course → bounded, never a repeat; paused → nothing; future `startDate` → nothing before it; budget truncation → first-N by time, and prove tier A is never truncated away by a chatty tier B. |
| **Reconciliation** | `reconcile(desired, pending)` — pure set logic. Cases: nothing changed → both sets empty; slot time edited → old id cancelled, new id scheduled; regimen deleted → cancel only; day rolled over → yesterday's ids cancelled. |
| **Id derivation** | FNV-1a is pure. Test stability (same input → same id across runs) and that a time change produces a different id. |
| **The wall-clock ↔ date-only conversion, including DST** | `timezone` is **pure Dart and works in `flutter test`**. `tz.initializeTimeZones()` then assert `TZDateTime(getLocation('Europe/Kyiv'), 2027, 3, 28, 3, 0)` (spring gap) and the October overlap. This pins the single riskiest behaviour in the feature without a device. Also assert the never-`.toLocal()` rule with a fixture in a negative-offset zone (e.g. `America/New_York`) where the bug would flip the date. |
| **Trigger wiring** | With `NotificationScheduler` mocked via `mocktail` (already a dev dependency), assert that a regimen edit / midnight rollover / resume produces exactly one debounced sync, and that a widget test never touches the plugin. |
| **Degradation** | `getLocation('Europe/Kiev')` on a trimmed database → falls back to UTC and reports, does not throw. Permission denied → app renders normally, no scheduler calls. |

### Device-only (`integration_test/`, and manual)

Actual delivery at the right minute; the permission dialogs; Doze/battery-saver latency; reboot rescheduling; force-stop behaviour; OEM background killers (needs a physical Xiaomi/Samsung); lock-screen appearance for the privacy check; iOS behaviour when a scheduled notification lands in a DST gap; behaviour at exactly 64 pending. The repo already has an `integration_test/` harness (`data03_loop_test.dart`, `l10n_device_test.dart`), so the pattern exists.

### The seam that makes it work

```
lib/core/domain/notification_plan.dart   ← pure: the plan (100% unit-testable)
lib/core/domain/notification_scheduler.dart ← abstract interface (3 methods)
lib/core/notifications/fln_scheduler.dart   ← the only file importing the plugin
lib/core/notifications/tz_conversion.dart   ← the only place TZDateTime is built
```

Same shape as `repositories.dart` / `drift_repositories.dart`. Every widget test in the existing suite stays plugin-free.

---

## 8. Privacy

A lock-screen banner reading **"Ashwagandha — 600 mg"** is health-adjacent data displayed to anyone holding the phone. This is a fully offline, no-account, no-network app; leaking its data via the lock screen would be the only place it leaks at all.

**What each platform offers:**

- **Android:** `AndroidNotificationDetails.visibility` of type `NotificationVisibility` — three documented values: `public` ("Show this notification in its entirety on all lockscreens"), `private` ("Show this notification on all lockscreens, but conceal sensitive or private information on secure lockscreens"), `secret` ("Do not reveal any part of this notification on a secure lockscreen"). Also settable channel-wide at creation. `private` is the right default: visible on the lock screen, content redacted by the system until unlock.
- **iOS: nothing equivalent is exposed.** iOS's native mechanism is `UNNotificationCategory(hiddenPreviewsBodyPlaceholder:)`, and `flutter_local_notifications`' `DarwinNotificationCategory` exposes only `identifier`, `actions`, and `options` — **no `hiddenPreviewsBodyPlaceholder`**. Whether previews are hidden on the lock screen is therefore entirely the **user's** setting (Settings → Notifications → Show Previews), not ours.

**Consequence: on iOS the only control we have is the content itself.**

**Recommended default — write nothing sensitive in the first place:**

- **Title:** generic, e.g. «Час прийому» / "Time for a dose".
- **Body:** counts and time, **no supplement names**: «3 добавки о 09:00» / "3 supplements at 09:00" (ICU plural — the app's l10n already handles Ukrainian one/few/many, and this string needs it).
- **Android:** `visibility: NotificationVisibility.private` on both the channel and the details.
- The names are one tap away, in an app that opens straight to Today.

**This has a large architectural side effect, and it points the other way from the stated intent.** The brief says *"one notification per dose slot."* But grouping by **time-of-day** — one notification covering every dose due at that minute — is better on three axes at once:

1. **Privacy:** a count-only body is natural, not a compromise.
2. **iOS cap:** cuts request count by the average number of concurrent doses. A user with 12 doses across 4 distinct times needs **4** requests/day, not 12 — tripling the effective horizon.
3. **UX:** four buzzes a day instead of twelve.

The cost is that the notification no longer tells you *which* supplement without opening the app — which, for a count-only privacy-safe body, is already true. **This is the most consequential open question in this document** (Q1).

**Also worth deciding:** whether users who *want* names on the lock screen can opt in later. Since notification settings UI is explicitly deferred, the answer for v1.1 is "no" — but the plan function should carry the content style as a parameter so adding the toggle later touches one call site, not the domain.

---

## 9. Open questions for the user

**Q1 — Per-slot or grouped-by-time? (biggest one.)** One notification per dose slot, as briefed, or one per distinct time-of-day covering all doses due then? Grouping is materially better for the iOS 64 cap (roughly 3× the horizon for a typical stack), for privacy, and for buzz fatigue. It costs the ability to name the supplement in the banner — which the recommended privacy default already gives up. **Recommendation: group by time.**

**Q2 — Sentinel notification?** On iOS the tier-B horizon runs out (~4–7 days) and reminders for cycling/course regimens go silent with no signal. Add a single "open VitoMy to refresh reminders" notification at the tail of the horizon (cost: 1 request, converts silent failure into visible)? Or accept the silence on the grounds that a user who hasn't opened the app in a week has lapsed anyway? **Recommendation: add it, plainly worded.**

**Q3 — Cancel the reminder for a dose already marked taken?** If the 21:00 dose is checked off at 20:00, the reminder still fires. Cancelling it is correct but adds a fourth reschedule trigger (on every intake status change — the app's most frequent write) and makes the plan function depend on `IntakeLog` state, not just regimens. **Recommendation: defer to v1.2**, but note that the ~1-slot-per-dose churn is small and it is the kind of detail users notice.

**Q4 — `flutter_timezone`, or ~25 lines of hand-rolled platform channel?** The project currently has zero custom native code and a zero-new-packages rule. **Recommendation: take the package** — an actively-maintained, verified-publisher package at 823k weekly downloads beats native code we'd have to test on two platforms ourselves.

**Q5 — OEM battery-killer hint on Android?** Xiaomi/Huawei/Samsung silently break scheduled notifications unless the user grants autostart / disables deep-sleep. No API detects this. Ship a one-time hint on affected manufacturers, or document-and-wait? **Recommendation: document only for v1.1**, since building it well needs the settings UI that is deferred.

**Q6 — Discoverability when permission is denied.** With no notification settings screen in v1.1, a user who taps "Don't Allow" has no way back except system Settings. Is a single passive status row in the existing Settings screen (with an "Open system settings" button) enough, or is that already the deferred settings UI creeping in? **Recommendation: one status row — it's a status indicator, not a settings surface.**

**Q7 — Bundle id.** Still the placeholder `app.vitomy`. Changing it wipes every pending iOS notification on existing installs. Not urgent (the app reschedules on foreground) but it belongs on the pre-release checklist alongside the app-name decision already flagged in CLAUDE.md.

**Q8 — Accept 10–15 min DST/Doze jitter and the twice-yearly off-by-an-hour dose?** The Play-compliant inexact-alarm choice means Android reminders can arrive up to ~15 minutes late while dozing, and a 03:00 dose lands at 04:00 on Ukraine's spring-forward Sunday. Both are consequences of correct choices, not bugs — but the user should sign off rather than discover them.

---

## 10. Sources

All fetched 2026-08-16 unless noted.

### HIGH confidence — official docs, official source code, Apple engineer statements

| Source | Used for | Date |
|---|---|---|
| [Apple Developer Forums thread 811171](https://developer.apple.com/forums/thread/811171) — accepted answer from an Apple engineer | The 64-request cap: *"there is a limit of 64... This is a system limit and there is no way around it."* | Posted Dec 2025, answered Jan 2026 |
| [Apple Developer Forums thread 772031](https://developer.apple.com/forums/thread/772031) — Apple engineer | Notifications persist across app update if bundle id unchanged (one unresolved counter-report in-thread) | Jan 2025 |
| [Google Play — Permissions and APIs that Access Sensitive Information](https://support.google.com/googleplay/android-developer/answer/16558241) | `USE_EXACT_ALARM` eligibility, verbatim: alarm/timer apps and calendar apps only; medication/health reminders not listed | Current |
| [Android Developers — Schedule alarms](https://developer.android.com/develop/background-work/services/alarms) | `SCHEDULE_EXACT_ALARM` vs `USE_EXACT_ALARM`; Android 14 default denial; `canScheduleExactAlarms()`; `setAndAllowWhileIdle()` recommended for reminder apps; `setWindow()` 10-min minimum | Current |
| [Android Developers — Power management restrictions](https://developer.android.com/topic/performance/power/power-details) | Per-bucket alarm quotas (Active unlimited → Restricted 1/day); Doze while-idle 7/hour | Current |
| [Android Developers — App Standby Buckets](https://developer.android.com/topic/performance/appstandby) | Bucket definitions; Android 16 (API 36) quota enforcement | Current |
| [Flutter — UISceneDelegate adoption](https://docs.flutter.dev/release/breaking-changes/uiscenedelegate) | UIScene default in Flutter 3.41; `FlutterImplicitEngineDelegate` / `FlutterSceneDelegate` shape; Apple's post-iOS-26 enforcement | Current |
| `FlutterLocalNotificationsPlugin.java` ([raw source](https://raw.githubusercontent.com/MaikuB/flutter_local_notifications/master/flutter_local_notifications/android/src/main/java/com/dexterous/flutterlocalnotifications/FlutterLocalNotificationsPlugin.java), read in full) | `zonedScheduleNotification` epoch computation; `getNextFireDateMatchingDateTimeComponents` DST-safe repeat; `checkCanScheduleExactAlarms` throwing; `rescheduleNotifications` silently pruning on boot; `setupAllowWhileIdleAlarm` mapping | master @ 2026-08-16 |
| `ScheduleMode.java`, `ScheduledNotificationBootReceiver.java`, plugin `AndroidManifest.xml` (raw sources, read in full) | Five schedule modes and their alarm-method mapping; the four boot-receiver actions; plugin-declared `POST_NOTIFICATIONS` + `VIBRATE` | master @ 2026-08-16 |
| `FlutterLocalNotificationsPlugin.m` (iOS, `buildUserNotificationCalendarTrigger:`) | `UNCalendarNotificationTrigger` construction; `repeats:YES` for `DateTimeComponents.time`; timezone applied to formatter and calendar | master @ 2026-08-16 |
| [pub.dev — flutter_local_notifications](https://pub.dev/packages/flutter_local_notifications) + [changelog](https://pub.dev/packages/flutter_local_notifications/changelog) | v22.3.0; Flutter ≥3.38.1, compileSdk 36, minSdk 24, iOS 13+, Java 17; `openAppNotificationSettings()` in 22.3.0; UIScene example migration in 21.0.0; named params since 20.0.0 | v22.3.0, ~8 days old |
| pub.dev API docs: [FlutterLocalNotificationsPlugin](https://pub.dev/documentation/flutter_local_notifications/latest/flutter_local_notifications/FlutterLocalNotificationsPlugin-class.html), [Android](https://pub.dev/documentation/flutter_local_notifications/latest/flutter_local_notifications/AndroidFlutterLocalNotificationsPlugin-class.html), [iOS](https://pub.dev/documentation/flutter_local_notifications/latest/flutter_local_notifications/IOSFlutterLocalNotificationsPlugin-class.html), [DarwinInitializationSettings](https://pub.dev/documentation/flutter_local_notifications/latest/flutter_local_notifications/DarwinInitializationSettings-class.html), [NotificationVisibility](https://pub.dev/documentation/flutter_local_notifications/latest/flutter_local_notifications/NotificationVisibility-class.html), [DarwinNotificationCategory](https://pub.dev/documentation/flutter_local_notifications/latest/flutter_local_notifications/DarwinNotificationCategory-class.html) | Exact method signatures; `requestAlertPermission` defaults to `true`; `NotificationVisibility` values; absence of `hiddenPreviewsBodyPlaceholder` | latest |
| [pub.dev — timezone](https://pub.dev/packages/timezone) | v0.11.1, tzdata **2025c**, database variants and sizes (`latest` 361 KB / `latest_all` 443 KB / `latest_10y` 85 KB) | ~48 days old |
| [pub.dev — flutter_timezone](https://pub.dev/packages/flutter_timezone) | v5.1.0, verified publisher, 823k weekly downloads, `getLocalTimezone()`; maintained fork of `flutter_native_timezone` | ~2 months old |
| Local repo inspection | `ios/Runner/AppDelegate.swift` + `SceneDelegate.swift` already UIScene-migrated; `Info.plist` scene manifest; `targetSdk = 36`, `IPHONEOS_DEPLOYMENT_TARGET = 15.0`, Flutter default `minSdkVersion = 24`; `cycle_math.dart`, `models.dart`, `repositories.dart`, `providers.dart`, `today_controller.dart`, `planner_view_model.dart` | 2026-08-16 |

### MEDIUM confidence

| Source | Used for | Note |
|---|---|---|
| [flutter_local_notifications README](https://github.com/MaikuB/flutter_local_notifications/blob/master/flutter_local_notifications/README.md) | Manifest/receiver snippets; *"iOS will only keep the 64 notifications that were last set"*; reinstall-resurrection warning on old iOS | The eviction claim **conflicts** with the "soonest-firing 64" reading elsewhere; treated as unresolved |
| [Issue #2721 — iOS setup vs UIScene migration guide](https://github.com/MaikuB/flutter_local_notifications/issues/2721) | README iOS instructions predate UIScene; PR #2761 in flight | Open, filed 2025-11-15 |
| [Ukraine DST status](https://www.timeanddate.com/time/change/ukraine/kyiv) + [reporting on Law 4201](https://thepublic.info/en/news/ukrayina_znovu_perexodit_na_litnii_cas_comu_sezonne_perevedennia_godinnikiv_dosi_ne_skasuvali) | DST still observed; abolition law passed July 2024 but unsigned; next transition 2026-10-25 04:00→03:00 | Corroborated across several outlets |
| [dontkillmyapp.com](https://dontkillmyapp.com/) and related coverage | Xiaomi/Huawei autostart, Samsung deep-sleep, OnePlus auto-launch | Community-maintained, no vendor documentation exists |
| [pub.dev — awesome_notifications](https://pub.dev/packages/awesome_notifications) | v0.12.1, self-described "under development"; confirms iOS 64 / Android 500 | Rejected on maturity |

### LOW confidence / explicitly unresolved

- **Which requests iOS evicts past 64** (soonest-firing vs last-set). Two credible sources disagree. Mitigated by never exceeding a self-imposed budget of 60.
- **iOS behaviour when a `UNCalendarNotificationTrigger` falls in a DST gap.** No authoritative statement found. `[ASSUMED]` — pinned by a Dart-side unit test on `TZDateTime` normalisation plus one on-device check.
- **Exact Doze latency for `setAndAllowWhileIdle`.** "~10–15 minutes" is derived from the documented 10-minute `setWindow` clamp and the 7-per-hour while-idle Doze quota, not from a single quoted figure. Directionally right; measure on device.
