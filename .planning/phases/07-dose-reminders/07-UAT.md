---
status: in_progress
phase: 07-dose-reminders
source: [07-06-PLAN.md, 07-RESEARCH.md §9.5, 07-UI-SPEC.md §12 backstops]
started: 2026-08-17T00:00:00Z
updated: 2026-08-17T00:00:00Z
---

## Current Test

1 — awaiting a human on device (Android automated half is green; iOS needs one tap)

## Regression — the v1 device suite, after Phase 7

Both pre-existing device tests were re-run on both platforms after the whole
phase merged, because Phase 7 changed `main()`, lifted the tab index out of
widget state and added an `AppLifecycleListener` — three things that could
plausibly disturb the cold-start and tab-preservation guarantees they assert.

| Test | Android (emulator-5554, API 36) | iOS (iPhone 17, iOS 26.5) |
|---|---|---|
| `data03_loop_test.dart` | PASS | PASS |
| `l10n_device_test.dart` | PASS | PASS |

## Tests

Everything in this list is device-only **because the app cannot observe it**, not
because nobody wrote a test. Delivery, its timing, the lock-screen rendering, the
two permission dialogs and the Android channel row are operating-system surfaces
outside the Flutter view hierarchy; no `WidgetTester` on either platform can see
or touch any of them. What a device CAN be asked automatically — whether the OS
accepted the reminders the app asked it to hold — is entry A, and it is a test
rather than a step.

Two devices are needed throughout: a physical Android phone and a physical
iPhone. A simulator/emulator is enough for entry A, and is **not** enough for
entries 1, 2, 3, 8 or 9.

### 0. P1 — PRE-STEP: notification permission granted on each device
expected: the app is permitted to post notifications on both devices BEFORE
anything below runs. On Android, from the host shell:
`adb shell pm grant com.boostque.dev android.permission.POST_NOTIFICATIONS`
(an emulator below API 33 needs no grant — the permission does not exist there).
On iOS there is no shell equivalent: launch the app by hand, save one regimen,
and answer the system dialog **Allow**; there is exactly one prompt per install.
Without the grant the app schedules **nothing, by design** — the sync's enabled
check is what makes a denied permission silent — so every entry below would
observe an empty set and could be mistaken for a pass. Entry A fails with a
message naming this step rather than allowing that.
result: **Android — DONE.** Granted on emulator-5554 (API 36). Worth recording
for whoever runs this next: the grant must be applied to the build the test
harness itself installs. Granting against a separately-installed APK is lost when
`flutter test` reinstalls, and the guard then fires — which is how the guard was
first observed working, having been un-runnable for its author. Sequence that
works: `flutter build apk --debug` → `adb install -r` → `pm grant` → run the test.

**iOS — NOT DONE, and it is a human step.** Confirmed empirically rather than
assumed: `xcrun simctl privacy` has no notifications service (its list is
calendar / contacts / location / photos / media-library / microphone / motion /
reminders / siri), so there is no shell route. Driving the prompt from a
throwaway harness put the dialog on screen and left `requestPermission()`
returning **null** — unanswered — with `isEnabled()` still false either side.
Automating the tap through System Events was tried and is unavailable (macOS
accessibility control of Simulator is not granted to this shell). Someone has to
tap **Allow**.

### A. P1 — automated half: the OS is actually holding what the app asked for
expected: on each platform,
`flutter test integration_test/notification_device_test.dart -d <device-id>`
is green. It asserts, in this order: that the resolved scheduler is the
plugin-backed one and NOT the no-op (a test that resolves the no-op reads an
always-empty pending list and passes while measuring nothing); that the
permission check answers true, failing with the pre-step above if it does not;
and then that the operating system's own pending-request set contains the id the
app derives for a 23:47 daily repeat after a regimen is saved. It finishes by
deleting the supplement it created and asserting the id is gone, so the device is
left as it was found. Record the device identifier of each run. It proves the app
asked for the right thing and the OS accepted it — **nothing about delivery**.
result: **Android — PASS**, emulator-5554 (API 36, Ukrainian). Verbatim:

```
NOTIF: stack already holds 0 supplement(s)
NOTIF: this run uses "NOTIF-07 Тест 0" (notif-device-0-1786991933631763)
NOTIF: waiting for pending request 530437442 (23:47 repeat)
NOTIF: OS holds 1 pending request(s), including 530437442
NOTIF: 530437442 cancelled; this run left no reminder behind
```

This is the first evidence in the whole phase that is not a test asserting
against another test: Android's own scheduler is holding a request the app
derived, and the device was left clean. It also incidentally discharges one of
the two gates 07-06 reported as un-provable — the permission guard was seen
firing for real on the first, ungranted run.

**iOS — BLOCKED on entry 0.** The scheduler resolves to `PluginNotificationScheduler`
(not the no-op) on the iPhone 17 simulator, so the wiring is confirmed that far;
the run stops at the permission guard exactly as designed.

### 1. P1 — a reminder is actually DELIVERED
expected: on each device, with permission granted, create a supplement with a
cyclic regimen active today and one dose slot a few minutes ahead; leave the app
backgrounded. At that time ONE notification arrives, titled «Час прийому» (or
"Time for your doses" in English), with a body reading the scheduled time then
the dose count — e.g. «08:00 · 3 прийоми». Not one notification per supplement:
one per time-of-day. Nothing inside the app can observe delivery, which is why
this is the phase's central device check.
result:

### 2. P2 — delivery latency under the inexact schedule mode, while dozing
expected: with the device left untouched and screen-off long enough to enter
Doze, a reminder still arrives, and it arrives within roughly 10–15 minutes of
its scheduled time. Note the observed delay. The accepted figure is DERIVED from
the platform's documented behaviour for `inexactAllowWhileIdle`, never measured —
only a device can measure it, and the reminder body restates the scheduled time
precisely because the OS timestamps DELIVERY rather than schedule.
result:

### 3. P1 — the lock-screen rendering
expected: with the device locked, a delivered reminder shows the constant title
over the time-and-count body, both legible at the LARGEST system text size
(Settings → Display → Font size, maximum), truncating neither the time nor the
count. **No supplement name appears anywhere in it.** The budgets the suite
asserts are character counts (title ≤ 24, body ≤ 32 at count 999); this is the
only check of what those counts actually look like rendered.
result:

### 4. P1 — the Android channel row, and its rename in place
expected: Android only. Settings → Apps → Boostque → Notifications shows ONE
channel, under its Ukrainian name «Нагадування про прийом» with the description
«Одне нагадування на кожен час прийому у вашому розкладі.». Then switch the app's
language to English in the app's own Settings screen, return to Android's
notification settings and reopen that screen: the SAME channel now reads "Dose
reminders" / "One reminder for each dose time in your schedule.", and there is
**no second channel**. A second channel would mean the id had been re-versioned,
which orphans the user's own customizations on the first one.
result:

### 5. P1 — the iOS permission dialog, once
expected: iOS only, on a FRESH install. Add a supplement and save its first
regimen. The editor pops FIRST, and only then does the system dialog appear —
over the screen the editor returned to, with nothing of the app's own before it
or after it: no sheet, no explanation, no snackbar, no banner. Answer Allow. Save
a SECOND regimen: no dialog appears again. On Android 13+ the same sequencing
applies to the POST_NOTIFICATIONS dialog; below API 33 nothing appears at all,
which is correct.
result:

### 6. P1 — denial leaves the app fully usable
expected: on a fresh install, answer the permission dialog with Don't Allow /
Deny. Every screen is then identical to the granted case — no banner, no
snackbar, no badge, no empty state, no disabled control anywhere. The ONLY
acknowledgement in the whole app is the Settings screen's reminders row, which
reads that reminders are not allowed and whose control opens the operating
system's own notification settings for this app. Confirm that control actually
lands on the app's notification page.
result:

### 7. P1 — the tap destination, warm and cold
expected: background the app while on **Стек**, and first browse a PAST day on
Сьогодні before backgrounding. Tap a delivered reminder: the app opens on
**Сьогодні showing TODAY**, not the browsed day. Then force-quit the app
entirely, wait for the next reminder and tap it COLD: it opens directly on
Сьогодні with **no Стек frame visible** at any point. Also: with the regimen
editor open, tap a reminder — the editor must NOT be popped; the tab changes
underneath it.
result:

### 8. P2 — reboot re-arming
expected: with reminders scheduled, restart the device completely and do NOT
open the app. Reminders scheduled before the restart still arrive afterwards.
This is what the manifest's boot-completed receiver exists for, and nothing in
the Dart suite can see whether it works.
result:

### 9. P3 — behaviour at the platform's own pending-request ceiling — OBSERVATION, NOT A STEP
expected: nothing to perform. Recorded so it is a known unknown rather than an
assumption. iOS keeps at most 64 pending local requests per app, and the two
credible descriptions of what it evicts past that ceiling disagree with each
other. The app enforces a budget of 60 inside its own pure plan and orders its
never-lapsing repeats first, so it is built so as never to find out which
description is right. If a future change raises or removes that budget, this
becomes a real device check; today the honest record is that the app deliberately
does not reach the ceiling.
result: not applicable by construction — the budget is 60 against a platform
ceiling of 64, asserted end to end in `test/notifications/notification_privacy_test.dart`

### 10. P3 — the one-hour divergence at the autumn transition — OBSERVATION TO CONFIRM, NOT A DEFECT TO FIX
expected: on the last Sunday of October, a reminder scheduled for a wall-clock
time inside the repeated hour (03:00 in Europe/Kyiv) fires at the FIRST 03:00 on
Android — an hour earlier than the Dart side's own normalization picks. Only the
wall clock and the zone name cross the platform channel; the offset Dart computed
is discarded, and `java.time`'s documented overlap rule picks the earlier of the
two identical times. That rule is the platform's. Confirming it twice a year is
cheaper than trying to defeat it, and any "fix" would mean re-implementing the
platform's own overlap resolution on the Dart side.
result:
