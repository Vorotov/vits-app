---
phase: 07-dose-reminders
validated: 2026-08-17
validator: gsd-plan-checker (goal-backward, pre-execution)
plans_checked: 6
verdict: FAIL — 6 BLOCKERS, 7 CONCERNS
baseline_confirmed: "flutter test = 797 passing (measured), flutter analyze clean"
---

# Phase 7 plan check — goal-backward verification

Method: start from the ROADMAP's six success criteria and the five NOTIF requirements, then
verify the plans deliver them; then attack the plans adversarially for the Phase-6 defect shape
(a gate whose scope is wider than its intent). Every claimed document correction was re-derived
against the real files, not accepted on the plans' word.

**Severity**
- **BLOCKER** — an executor following this plan literally produces something wrong or broken.
- **CONCERN** — worth fixing, not fatal.

---

## Verdict summary

| # | Severity | Plan | Finding |
|---|---|---|---|
| B1 | BLOCKER | 07-03 (+07-01) | Two contradictory `await`-count gates over `main.dart`; 07-03 breaks 07-01's and may not edit it |
| B2 | BLOCKER | 07-01 task 2/3 | `'@mipmap/ic_launcher'` is a third flagged literal; gate 2 of `no_hardcoded_strings_test.dart` will fail |
| B3 | BLOCKER | 07-01 task 2 | Path-scoped allowlist entry would blind the string gate over the whole notification layer |
| B4 | BLOCKER | 07-02 task 1 | The negative property test is false as stated — courses and long `onDays` are counterexamples |
| B5 | BLOCKER | 07-06 task 3 | The device test reads the pending set through the **no-op** seam and cannot answer the OS permission dialog |
| B6 | BLOCKER | 07-06 task 1 | DECIDED-9a's amended `lib/features/` permission-primitive invariant has no permanent gate |
| C1 | CONCERN | 07-04, 07-05 | Four acceptance greps run `grep -c` against a directory without `-r` — they cannot return 0 |
| C2 | CONCERN | 07-04 task 2 | The "current minute of day" has no named source; a bare `DateTime.now()` breaks the one-clock-read rule and the boundary test |
| C3 | CONCERN | 07-05 task 1 | Acceptance ("touches only the allowlist block") contradicts the action (it must edit `_isPreferencesKey`) |
| C4 | CONCERN | all six | Every plan file ends with a stray `</content>` / `</invoke>` tool-artifact line |
| C5 | CONCERN | 07-05 task 3 | `grep -c "features/settings" -r lib/features/settings/ \| wc -l` does not count Dart files |
| C6 | CONCERN | 07-01 task 3 | The `main.dart` await gate is placed in the *wire payload* test file, an unrelated home |
| C7 | CONCERN | 07-01 task 1 | `<done>` says "three unprivileged permissions", the must_have says "exactly one" — merged vs declared, unstated |

**Coverage, dependencies, waves and device honesty all PASS** — see the four sections after the
findings.

---

## BLOCKERS

### B1 — 07-03 breaks the await gate 07-01 installs, and is not allowed to fix it

**Plan file:** `.planning/phases/07-dose-reminders/07-03-PLAN.md` (task 3), with a matching change to `07-01-PLAN.md` (task 3).

Verified against the real `lib/main.dart`: there is today **exactly one** `await` between
`WidgetsFlutterBinding.ensureInitialized()` and `runApp` (the `SharedPreferences` resolution).

- 07-01 task 3 acceptance: *"A source gate in the wire test asserts that between binding
  initialization and `runApp`, `lib/main.dart` contains exactly one `await` — the pre-existing
  preferences one"*, written into `test/notifications/notification_channel_payload_test.dart`.
- 07-03 task 3 adds the launch-details read to that same window — a **second** await — and writes
  its own gate in `test/notifications/notification_routing_test.dart` asserting **exactly two**.

07-03's `files_modified` does not include `test/notifications/notification_channel_payload_test.dart`,
and no task text mentions the older gate. Its own acceptance demands whole-suite green. An executor
therefore lands on a red pre-existing gate with no instruction, and the three ways out are all bad:
delete the 07-01 gate, weaken it, or move the launch read out of the pre-`runApp` window — which
silently destroys 07-03's own frame-1 must_have and DECIDED-12.

**Required change:** add `test/notifications/notification_channel_payload_test.dart` to 07-03's
`files_modified`, and add to 07-03 task 3's action: *"The one-await gate plan 07-01 installed in
`notification_channel_payload_test.dart` is superseded by this task's counted gate. Delete it from
that file in the same commit and re-state it here as exactly two, naming both awaits; do not leave
two gates asserting different counts over the same window."* Optionally also amend 07-01 task 3 to
note the count is expected to become two in plan 07-03, so the number is not read as permanent.

### B2 — the Android small-icon literal is a third flagged string and will fail gate 2

**Plan file:** `07-01-PLAN.md` (task 2's allowlist instruction, and task 3's verify).

`test/l10n/no_hardcoded_strings_test.dart:619` ("every translatable literal in lib/ falls into a
NAMED allowlist category") scans **all** literals in `lib/`, not only user-facing positions, and
`isTranslatable` is `RegExp(r'\p{L}{2,}')`.

07-01 task 3 must construct `AndroidInitializationSettings`, whose `defaultIcon` is a required
positional `String`. UI-SPEC DECIDED-18 / §8 fixes its value: **`@mipmap/ic_launcher`**. That
literal contains `mipmap`, `ic`, `launcher` → `isTranslatable` is true, its enclosing call is
`AndroidInitializationSettings` (in no existing allowlist predicate), and `_isImportPath` does not
match it (it neither starts with `dart:`/`package:` nor ends with `.dart`). Result: gate 2 fails,
in the same task whose acceptance requires `flutter test test/l10n` green.

07-01 task 2 explicitly scopes the new entry to *"exactly the two literals this phase introduces"*
(the channel id and the payload token), mirroring UI-SPEC sign-off condition 27. Condition 27's
arithmetic is therefore off by one in the **other** direction too, independently of the DECIDED-8
bool the planner caught.

Same class of risk, worth naming in the plan: if `tz_conversion.dart`'s degrade path writes a
fallback location name (`'UTC'`), that is a fourth flagged literal.

**Required change:** in `07-01-PLAN.md` task 2, change the allowlist instruction to cover **three**
named literals — channel id, payload token, and the Android small-icon resource name — with the
third's rationale (a platform drawable resource path that must match `android/app/src/main/res/mipmap-*`
byte for byte, the same category as the bundled-font-family entry). Add to task 3's action: *"if the
degrade path names a fallback zone, resolve it through `tz.UTC`/`tz.getLocation` without a new bare
literal, or add it to the same entry in this commit."* Add to task 3's acceptance:
`flutter test test/l10n/no_hardcoded_strings_test.dart` green **after** `notification_service.dart`
exists (today only task 2 runs that file). And record in the summary that sign-off condition 27's
"exactly two literals" is corrected to three.

### B3 — a path-scoped allowlist entry is a gate wider than its intent

**Plan file:** `07-01-PLAN.md` (task 2).

The action says the entry is *"scoped by path to `lib/core/notifications/`"* while also *"covering
exactly the two literals"*. Those are two different predicates. `allowlistEntryFor` returns the
**first** matching entry, so a path-only predicate —
`(Literal l) => l.path.startsWith('lib/core/notifications/')` — permanently blesses **every** string
literal anywhere in the notification layer, in this phase and every future one. That is precisely
the Phase-6 defect shape: a gate whose scope is far wider than its stated intent, and one that
erodes silently because nothing ever fails.

It also silently defeats plan 07-05: the asked-once preferences key lives in
`lib/core/notifications/notification_permission.dart`, so a path-only entry would match it first and
07-05's careful extension of `_isPreferencesKey` would be dead code.

**Required change:** in `07-01-PLAN.md` task 2, state the predicate shape literally: *"the predicate
is a value equality check against the named constants AND a path check — `path.startsWith('lib/core/notifications/') && const {<channel id>, <payload token>, <small-icon name>}.contains(l.value)`.
A path-only predicate is forbidden: it would bless every future literal in the notification layer."*
Add an acceptance criterion: *"a temporary unrelated literal added under `lib/core/notifications/` is
still reported by gate 2 — verify once by hand and record it in the summary."*

### B4 — 07-02's negative property test is false as written

**Plan file:** `07-02-PLAN.md` (task 1, `<behavior>` and `<action>`).

Stated property: *"for every regimen the predicate answers false for, there exists at least one day
in the next 400 on which `isActiveOn` is false — except for the future-start case."*

Derived against the real `lib/core/domain/cycle_math.dart:26-44`, that is false for at least two
regimen shapes a generated set will produce:

1. A **course** whose `endDate` is on or after `today + 399` and whose `startDate` is on or before
   today. `runsEveryDayFrom` answers false (a course always does, correctly), yet `isActiveOn` is
   true on all 400 days.
2. A **cyclic** regimen with `offDays > 0` and `onDays >= 400`. The predicate answers false
   (`offDays != 0`), yet `dayIndex % period < onDays` holds for the whole walk.

An executor writing the test literally gets a red property test on the very task whose deliverable
it is, and the cheap escapes — narrowing the generator until the property is vacuous, or dropping
the negative direction — both remove the thing the test was for.

**Required change:** in `07-02-PLAN.md` task 1, replace the exception clause with a stated,
complete one and bound the generator: *"the negative direction holds only for regimens that can
actually lapse inside the walk. Bound the generated set so it does — cyclic `onDays` in 1..30,
`offDays` in 0..14, course `endDate` within `today + 120` — and state the three exempt shapes in a
comment: a future-start daily regimen, a course outlasting the walk, and a cyclic regimen whose
`onDays` exceeds the walk. The bound is part of the property, not a convenience."*

### B5 — the device test reads the pending set through the no-op seam, and cannot answer the OS dialog

**Plan file:** `07-06-PLAN.md` (task 3).

Two independent defects in one test.

**(a) The seam.** `notificationSchedulerProvider` defaults to the **no-op** implementation (07-01,
by design), and the real plugin-backed one is installed only by `main()`'s override. The existing
device harness this task is told to follow — `integration_test/data03_loop_test.dart:84-89` — does
**not** run `main()`; it builds its own `ProviderScope` with a single `sharedPreferencesProvider`
override and pumps `BoostqueApp`. A device test written on that precedent resolves the **no-op**
scheduler, whose `pending` answer is documented as an empty list. The test then either fails for a
reason that has nothing to do with the device, or — if written tolerantly — passes green while
asserting nothing at all. That is the worst outcome available: a device claim that was never
observed, which this plan's own T-07-37 says it exists to prevent.

**(b) The permission dialog.** The action says *"grant permission when the dialog appears"*. Both
platforms' notification-permission dialogs are OS surfaces outside the Flutter view hierarchy;
`WidgetTester` cannot see or tap them. Without a grant, the sync's enabled check gates everything and
the pending set stays empty by design.

**Required change:** in `07-06-PLAN.md` task 3, add to the action: *"the boot scope must override
`notificationSchedulerProvider` with the plugin-backed implementation exactly as `main()` does —
the default is the no-op and its pending list is always empty, so the assertion would be vacuous.
Assert first that the resolved scheduler is not the no-op, and fail loudly if it is."* And:
*"the permission grant is a documented pre-step, not a test action: on Android
`adb shell pm grant com.boostque.dev android.permission.POST_NOTIFICATIONS` before the run; on iOS
the dialog is human-answered, so the automated half runs on an already-granted install. If the
enabled check answers false, the test must fail with a message naming the pre-step rather than
report an empty pending set as a pass."* Record the pre-step in `07-UAT.md` too.

### B6 — DECIDED-9a's amended invariant gets no permanent gate

**Plan file:** `07-06-PLAN.md` (task 1).

UI-SPEC §4's checkable invariant, as amended by DECIDED-9a, is that the permission primitives are
reachable from exactly one place under `lib/features/` — and 07-05 resolves that by having the row
call named controller methods, so the grep must still return nothing (see the verdict on claimed
correction 5 below: that reasoning is **correct**). But the only check of it anywhere in the phase is
a one-off acceptance grep in 07-05 task 3, which is also malformed (C1). 07-06 owns the phase's
absence gates and enumerates seven properties; this one is not among them. So the invariant that
DECIDED-9a explicitly kept alive is the one property with no standing gate — and it is exactly the
property a future phase erodes by reaching a plugin primitive from a screen.

**Required change:** in `07-06-PLAN.md` task 1, add a group: *"the permission primitives resolve
nowhere under `lib/features/` — `areNotificationsEnabled`, `checkPermissions`, `requestPermissions`,
`requestNotificationsPermission`, `openAppNotificationSettings` — over comment-stripped sources,
with the glob proved first. Reason: DECIDED-9a kept this invariant rather than relaxing it; the
Settings row is allowed to exist only because it reaches named controller methods instead."*

---

## CONCERNS

### C1 — four acceptance greps cannot return what they claim

`grep -c PATTERN lib/` without `-r` prints `grep: lib/: Is a directory` and exits 2 — it cannot
"return 0". Affected, all as **acceptance criteria**:

- `07-04-PLAN.md` task 1: `grep -c "basicLocaleListResolution" lib/`
- `07-04-PLAN.md` task 2: `grep -c "cancelAll" lib/` and `grep -c "doses_v2\|doses_v1'" lib/`
- `07-05-PLAN.md` task 3: `grep -cE "areNotificationsEnabled|..." lib/features/`

Fix: add `-r` to all four. (07-01's `grep -rlc ... lib/` is correct, which is why the omission reads
as a slip rather than a convention.)

### C2 — the "current minute of day" has no named source

`07-04-PLAN.md` task 2 says the application builds the plan from *"the watched regimens, the current
day and the current minute of day"* without saying where the minute comes from. `TodayController`'s
own doc calls its injected `now` *"the ONE wall-clock read in the app"* and explains that
`flutter_test`'s fake-async zone never controls `DateTime.now()`. A bare `DateTime.now()` in the sync
therefore (a) makes that documented claim false and (b) makes 07-01's tested boundary — today's slots
at or before now are dropped — unpinnable from the sync's own tests. Fix: state that the minute is
derived from the same injected clock (`todayControllerProvider`'s `now`), and add
`grep -rc "DateTime.now" lib/core/notifications/` returns 0 to the acceptance list.

### C3 — 07-05 task 1's acceptance forbids what its action requires

Acceptance: *"`git diff -- test/l10n/no_hardcoded_strings_test.dart` touches only the allowlist
block."* The action requires extending `_isPreferencesKey`, which is declared at
`no_hardcoded_strings_test.dart:424`, **above** the allowlist const. 07-01 phrased the equivalent
criterion correctly (*"only the allowlist block and one predicate function"*). Fix: adopt 07-01's
wording in 07-05.

Verified while checking this: the file **does** carry a *"every allowlist entry still classifies
something in the tree"* gate (line 635), so 07-01's claim about it is true, and extending
`_isPreferencesKey` keeps that entry alive because `'app_locale'` still matches.

### C4 — every plan file ends with a tool-artifact line

All six plans end with a stray `</content>` (07-01 with `</content>` + `</invoke>`). Harmless to an
executor but it is leaked tool scaffolding inside a committed contract. Fix: delete the trailing
lines from all six files.

### C5 — the "still exactly two Dart files" check does not count Dart files

`07-05-PLAN.md` task 3: `grep -c "features/settings" -r lib/features/settings/ | wc -l`. With `-c`,
grep prints one line per **scanned** file whether it matches or not, so this counts scanned files by
accident and would also count a non-Dart file. Fix:
`ls lib/features/settings/*.dart | wc -l` equals 2 — or simply rely on the existing glob gate in
`settings_screen_test.dart:854-861`, which already asserts the set and that `language_picker.dart` is
in it.

### C6 — the `main.dart` await gate is homed in the wire-payload test

`07-01-PLAN.md` task 3 puts a source gate over `lib/main.dart` inside
`test/notifications/notification_channel_payload_test.dart`, a file whose entire subject is the
platform channel argument map. That is where B1's collision partly comes from. Fix (with B1): the
counted-await gate belongs in one place for the whole phase — `notification_routing_test.dart`, next
to the frame-1 guarantee it protects.

### C7 — "exactly one permission" vs "three unprivileged permissions"

`07-01-PLAN.md` task 1's must_have says the main manifest declares **exactly one** permission and its
acceptance greps for 1; its `<done>` says *"the release manifest gains exactly three unprivileged
permissions"*. Both are true (one declared plus the plugin's two, merged), but nothing says so.
Verified: `android/app/src/main/AndroidManifest.xml` declares **zero** `uses-permission` today, so
the `grep -c` == 1 criterion is exactly right. Fix: say "declared" and "merged" in the two sentences.

---

## The planner's six claimed document corrections

| # | Claim | Verdict |
|---|---|---|
| 1 | `nowMinutesFromMidnight` prevents a permanently non-empty reconcile diff | **CORRECT** |
| 2 | The Settings row cannot be async; a three-state nullable rendering nothing while unknown passes every gate | **CORRECT** (one gap, see below) |
| 3 | Research Q-4/R-9 is a false dilemma; `runsEveryDayFrom` in `cycle_math.dart` is derivable | **CORRECT** |
| 4 | Sign-off 27 is off by one; extend the existing preferences-key entry | **CORRECT** (and off by one *again* — see B2) |
| 5 | DECIDED-9a's amendment to the `grep lib/features/` invariant is unnecessary | **CORRECT** (but ungated — see B6) |
| 6 | Sign-off 25 is satisfied by a private widget inside `settings_screen.dart` | **CORRECT** |

**1 — the reconciliation-divergence argument holds.** Without the parameter, `planNotifications`
emits a one-shot for a minute already past on `today`. `notification_service.dart` skips any instant
not strictly in the future (07-01 task 3, and the plugin throws `ArgumentError` on that path per
Pitfall 4), so that id never enters the pending set. `reconcile`'s "desired id not pending →
schedule" rule then re-emits it on **every** trigger for the rest of the day: a permanently
non-empty diff and a futile platform round trip per trigger, exactly as claimed. The parameter keeps
the function pure — an `int` argument, symmetric with the already-parameterised `today`, no clock
read, and it makes the "a slot exactly at now" boundary a test rather than a race. (See C2 for the
one loose end: the caller's clock source is unnamed.)

**2 — the constraint list and the resolution both check out, with one gap.** Read
`test/features/settings_screen_test.dart` (1033 lines) directly. Every gate the plan enumerates
exists, over a **glob** of `lib/features/settings/*.dart` with comments stripped by a line-only
stripper: `AsyncLoading` / `ProgressIndicator` / `Shimmer` / `Skeleton` (:940); `switch (` and `Map<`
(:927); `Error` / `retry` / `catch (` / `onError` **as substrings** (:955); `DateFormat` /
`NumberFormat` / `Intl.plural` (:968); `drift` / `database.dart` / `Repository` / `repositories`
(:993); the two-letter-lowercase literal regex `['"][a-z]{2}['"]` (:900); the closed font-size list
25/15/10.5 and icon-size list 18, plus no hex literal (:1004); no `/*` (:861); and the rendered-text
no-digit sweep (:843) and Cyrillic-leak sweep (:819). The plan's own action text warns about the
substring trap and about `Map<`, which is the part most plans get wrong.

The resolution passes unmodified: with the no-op seam the permission state is `null`, so the row
renders nothing and the existing single-`pump` rendering tests see a byte-identical tree; a plain
nullable bool needs no `AsyncValue`, so the loading gate stays true; three-way conditionals avoid
`switch`; all failures are absorbed in `core`, outside the glob, so the error gate stays true.

The one gap the plan does not name: the glob gate also asserts
`sources.length >= 2` **and** that `language_picker.dart` is present, so the "private widget, no new
file" choice is doubly load-bearing — and 07-05's own check of that fact is the broken command in C5.

**3 — the dilemma really is false.** `isActiveOn` (`cycle_math.dart:26`) is already in
`core/domain/` and already the single activity decision; `runsEveryDayFrom` is exactly the branch
that returns `true` unconditionally — `!paused && kind == cyclic && onDays > 0 && offDays == 0`,
plus the future-start guard from the shared `d.isBefore(start)` early return. Derivable with no new
knowledge. `activeRuns` is referenced only by `lib/features/calendar/planner_view_model.dart`
(:51, :298, :306, :551) and nothing in this phase needs a run — only a per-day boolean — so nothing
else requires it moved. The 400-day binding property is the right instrument; its stated negative
direction is wrong (B4).

**4 — the arithmetic correction is right.** Condition 27 reads *"exactly one new named allowlist
entry covering exactly two literals"*. `_isPreferencesKey` is `l.value == 'app_locale'` (:424) — a
value equality, extensible in place — and the phase does introduce a third flagged literal in
DECIDED-8's persisted bool, whose key contains letters and so is `isTranslatable`. Extending the
existing entry keeps "exactly one new entry" literally true while classifying all three, and the
"every allowlist entry still classifies something" gate (:635) keeps the extended entry honest.
Correct. The planner simply did not go far enough: the small-icon literal is a **fourth** (B2).

**5 — no amendment is needed.** The invariant greps for `areNotificationsEnabled`,
`checkPermissions`, `requestPermissions`, `requestNotificationsPermission`. A row that calls
`ref.watch(notificationPermissionProvider)` and a named `openSystemSettings()` contains none of those
substrings, so the grep still returns nothing and DECIDED-9a's "amended to exactly one place" is
satisfied without relaxing anything. Correct — with two riders: the controller's method names must
avoid the needles (`requestPermissions` in particular; a singular `requestPermission` is safe but is
never called from a feature anyway), and the invariant needs a standing gate (B6).

**6 — correct against the real glob gate.** `lib/features/settings/` holds exactly
`language_picker.dart` and `settings_screen.dart`. A private widget inside `settings_screen.dart`
adds no file under `lib/features/` (condition 25), keeps the glob at two so every gate above stays
live, and brings the new code **inside** the gates rather than around them — which is the stricter
choice, not the convenient one.

---

## FLAG-3 compliance — PASS

Only `getNotificationAppLaunchDetails()` is placed before `runApp`, and only by 07-03.

| Plan | Pre-`runApp` additions | Verdict |
|---|---|---|
| 07-01 | none. `tz.initializeTimeZones()`, `initialize()` and `createNotificationChannel()` are all in a post-first-frame callback behind `notificationBootstrapProvider` | PASS |
| 07-02 | pure Dart only | PASS |
| 07-03 | the launch-details read, guarded, degrading to the default destination | PASS |
| 07-04 | none — the locale observer is a widget in `home`, the sync is watched from the app widget | PASS |
| 07-05 | none | PASS |
| 07-06 | tests only | PASS |

Nothing can be scheduled before timezone init: `notificationBootstrapProvider` only reports true
after the zone load, the sync reads it first and returns while false (07-04 task 2), and
`tz_conversion.dart` additionally asserts on the same ordering (07-01 task 2). The ordering is a
value, not a comment — which is what FLAG-3 asked for. The counted-await gate that makes the window
checkable is real but collides with itself (B1).

## The seam — PASS

07-01 task 3 declares `NotificationScheduler` + `NoopNotificationScheduler` and
`notificationSchedulerProvider` defaulting to the no-op, in the **same task** that first imports the
plugin. There is no commit in which plugin code exists without the seam in front of it, and no
window in which a test could reach it: the plugin resolves in exactly one file, the real
implementation is installed only by `main()`'s override, and every existing test pumps
`BoostqueApp`/`AppShell` inside its own `ProviderScope`. 07-01's acceptance that **zero existing test
files are edited** is the right proof of the default being correct. Later plans' tests all drive the
mocked or default seam. The one place this rule is broken is the device test, which needs the
*opposite* (B5).

## Wave safety — PASS

`files_modified` are disjoint within every wave, verified by reading the lists:

- Wave 1: 07-01 alone.
- Wave 2: 07-02 = {`cycle_math.dart`, `notification_plan.dart`, `cycle_math_test.dart`,
  `notification_plan_test.dart`} · 07-03 = {`selected_tab_controller.dart`, `app_shell.dart`,
  `notification_providers.dart`, `main.dart`, `selected_tab_controller_test.dart`,
  `notification_routing_test.dart`, `app_shell_test.dart`, `shell_invariants_test.dart`}.
  **Intersection empty.** No collision.
- Waves 3, 4, 5: one plan each.

B1 is not a worktree collision — the file it needs belongs to already-merged 07-01 — but the fix does
add one file to 07-03's list, which stays disjoint from 07-02's.

## Test-file churn — PASS, and the plans are right about it

07-03 explicitly distrusts research §8.6's cited line numbers, which is correct. Re-checked against
today's tree:

- `lib/app_shell.dart` — still `StatefulWidget` with `_selectedIndex` (UI-SPEC's "app_shell.dart:29"
  is within a line of reality).
- `test/widget/app_shell_test.dart` — never reaches `_AppShellState` or `tester.state`; every mount
  is inside `scoped(...)`/`ProviderScope`. No edit needed.
- `test/core/widgets/bq_add_fab_test.dart:58` and `test/features/planner_screen_test.dart:160,3198` —
  mount `const AppShell()` inside a scope and read `tester.widget<BqNavBar>(...).selectedIndex`,
  never widget state. The plan's prediction of **no edit** in these two is correct.
- `test/widget/shell_invariants_test.dart` — reads `app_shell.dart` as text for the three destination
  constructors and the `TickerMode` wrapper (both survive the lift) and greps all of `lib/` for the
  deleted Phase-6 symbols (`CalendarScreen`, `CalendarPage`, `calendarPageProvider`, `PopScope`,
  `tabSettings`, `NavigationBar(`, `NavigationDestination(`, `navigationBarTheme:`). 07-03 correctly
  warns that comments count.
- The `BqSettingsGearRow` extraction is real (`lib/core/widgets/bq_settings_gear_row.dart`) and is
  untouched by the lift, which the plans' `git diff --stat -- lib/core/widgets/` gate protects.
- `planner_screen_test.dart`'s tab-preservation group builds a **fresh** container per case, so the
  lifted app-lifetime provider cannot leak state between the pumps and turn a preservation test
  green for the wrong reason.

Every other cited path and line I sampled resolves: `platform_config_test.dart`'s two strippers at
:24 and :31, `regimen_editor_screen.dart:819` = `_EditorFooter`, `lookupAppLocalizations` at
`app_localizations.dart:1054` and synchronous, `settings_screen_test.dart`'s glob at :89-99 and gates
to :1032 in a 1033-line file, plus all 17 read_first files across the six plans.

## Coverage — PASS

| ROADMAP criterion | Plans | Verdict |
|---|---|---|
| 1 — one grouped notification naming a count; tap opens Сьогодні | 07-01 (shape + wire), 07-02 (tier), 07-03 (tap, warm + cold), 07-04 (copy) | covered |
| 2 — nothing on an off-day, paused regimen, deleted supplement, out-of-range course day | 07-01/07-02 (`isActiveOn` is the sole decision), 07-06 (soft-delete behaviourally) | covered |
| 3 — no exact-alarm permission; iOS budget holds at any stack size | 07-01 (exact-set manifest gate + budget in the pure plan), 07-02 (repeats-first ordering), 07-06 (end-to-end budget) | covered |
| 4 — asked at first save; denied = normal and silent | 07-05 (ask after pop, once per install), 07-04 (enabled check gates everything) | covered |
| 5 — re-derives on create/edit/pause/delete, resume, DST | 07-01 (DST boundary), 07-02 (`reconcile`), 07-04 (six triggers, one per test), 07-06 (device pending set) | covered |
| 6 — Settings states allowed/not and opens OS settings; no numeral, toggle or detail | 07-05 task 3 | covered |

| Requirement | Plans claiming it |
|---|---|
| NOTIF-01 | 07-01, 07-02, 07-03, 07-04, 07-06 |
| NOTIF-02 | 07-01, 07-02, 07-06 |
| NOTIF-03 | 07-04, 07-05, 07-06 |
| NOTIF-04 | 07-01, 07-02, 07-04, 07-06 |
| NOTIF-05 | 07-05, 07-06 |

Nothing orphaned; no plan claims a criterion it cannot deliver. DECIDED-16 ("a locale change forces a
full re-issue") is delivered by UI-SPEC §7.2's own **resolution (a)** — the rendered-text comparison
in `reconcile` — which §7.2 lists as *recommended*, so 07-02's choice is inside the contract, not a
reinterpretation of it.

## Device-only honesty — PASS

07-06 is `autonomous: false`, routes nine items to `07-UAT.md` (delivery, Doze latency, lock-screen
rendering, the Android channel row and its in-place rename, both permission dialogs, denial,
cold tap after force-quit, reboot re-arming, and the platform ceiling as an explicit known unknown),
and states in-plan what the automated device test does **not** prove. 07-01's device statement
carries `verification: backstop` and says delivery belongs to UAT "never to a test". 07-06 task 1
also documents the two sign-off conditions it deliberately does not mechanise. This dimension is
handled better than the phase needed it to be — the only defect is that the automated half, as
written, cannot actually run (B5).

## Scope sanity — PASS

Three tasks per plan across all six, 4-12 files each, `estimate.tokens` 86k-112k with
`confidence: low` (fewer than three phases carry actuals, so the figures are not calibrated for this
project and the task/file counts carry more weight). 07-01 is the heaviest — a native build task
plus five new `lib/` files plus three test files — and is the one plan where a fourth task would have
been defensible, but its tracer role justifies the width. No split required.

## Verdict

**FAIL — do not execute.** Six BLOCKERS, each with a named plan file and a concrete change above.
Five of the six are single-paragraph edits; B5 is the only one that changes what a task does.

The plans are unusually strong on the dimensions this phase actually risks — FLAG-3 ordering as a
value rather than a comment, the seam from commit one, an honest device split, and six document
corrections of which all six are right. What they miss is concentrated in the gates: two gates that
contradict each other over the same window (B1), one whose scope is wider than its intent (B3), one
that will fail on the phase's own required literal (B2), one that asserts a false property (B4), one
that would pass while measuring nothing (B5), and one locked invariant with no gate at all (B6).
