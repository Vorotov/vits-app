---
gsd_state_version: 1.0
milestone: v1.2
milestone_name: Progress
current_phase: 9
current_phase_name: Languages & the Release Gate
status: milestone_shipped_pending_device_pass
stopped_at: Phase 9 shipped (fc7bfd3); no phase in flight
last_updated: "2026-09-13T09:57:22.430Z"
last_activity: 2026-09-11
last_activity_desc: "Completed quick task 260911-mms: App Store listing: fix the 31-char subtitle and refresh promotional text, description and keywords in store/listing.md with ASO rationale; document the 6.5-inch ASC slot; make tool/make_screenshots.sh derive the 6.5-inch set; commit store/screenshots/ios-6.5"
progress:
  total_phases: 2
  completed_phases: 0
  total_plans: 0
  completed_plans: 0
  percent: 0
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-08-14)

**Core value:** A user can see exactly what to take today and check it off, with cycles and breaks computed correctly — the daily loop of plan → see → mark taken must always work.
**Current focus:** nothing in flight. What is left is human-only (see *Waiting on a human*).

## Current Position

Milestone: v1.2 — shipped 2026-09-01
Phase: 9 (Languages & the Release Gate) — complete
Plan: none in flight
Last activity: 2026-10-05 - Completed quick task 261005-nc6: dose times moved above
periodicity in the regimen editor, the editor's primary button now says Save when
editing an existing regimen, and the Today dose action sheet gained an Open dosing
schedule row. Three open Deferred Items closed; the three 05-schedule store
screenshots are now stale and logged as a new open Release row.

**VitoMy 1.0 has been public on the App Store since 2026-09-21** (verified
2026-09-25 against the public lookup API, which still reports 1.0 — so 1.1.0 is
not released yet, whatever its state in App Store Connect).

Progress: [██████████] 9 phases, 8 closed — Phase 7 (Dose Reminders) is executed but not closed

**What a future session most needs to know, in one place:**

- **Everything is built.** v1 (Phases 1-5), v1.1 (6-7) and v1.2 (8-9) are all
  implemented and merged on `main`. The working tree is clean and the repo has
  **no remote** — never push.

- **Two suites, not one.** `flutter test` runs `test/` only, and stays uk+en.
  `flutter test test_release/` is the pre-production gate: the medical-claim
  vocabulary scan and the whole-screen render sweep, both across all seven
  locales, Arabic under real RTL. Run it before a production build; nothing
  else runs it. Counts measured at `d7e82fc`: **1108** in `test/`, **46** in
  `test_release/` — treat them as a marker, not a contract; measure before
  quoting.

- **The only open work is human-only.** No code is blocked on a decision.
  Three items need a person at a device or an account — listed under *Waiting on
  a human* below, and in the Deferred Items table. The URL blocker is closed:
  `https://vitomy.app/privacy` and `/support` went live 2026-09-12.

- **Store assets are generated, never hand-edited.** `tool/make_icons.py`
  builds every icon size for both platforms from one geometry;
  `tool/make_screenshots.sh` drives
  `integration_test/store_screenshots_test.dart` on a 6.9" simulator and
  collects the listing screenshots. Copy for both consoles is in
  `store/listing.md`. Editing a PNG by hand is how that stops being true.

- **SHIP-01 is the one piece of code work queued** — RevenueCat plus a
  developer tip for Shipaton, under *Pending Todos*.

- **One spec is partly superseded.** The onboarding spec
  (`docs/superpowers/specs/2026-08-26-vitomy-onboarding-design.md`) describes
  two explain screens and no contextual help. That is what was approved, not
  what shipped. Its *What shipped* section, at the end of the file, is the app.

## Performance Metrics

**Velocity:**

- Plans written and executed: 40 across Phases 1-8. Phase 9 shipped as direct
  commits with no plan file, which is why the plan count and the phase count
  disagree.

- Durations were only ever recorded for 01-01 (~40 min active). Nothing since
  then was timed, so the averages this table used to carry were arithmetic over
  one sample; they are removed rather than extrapolated.

**By Phase:**

| Phase | Plans | Status |
|-------|-------|--------|
| 1. Foundation | 7 | Complete 2026-08-14 |
| 2. Stack Management | 5 | Complete 2026-08-15 |
| 3. Daily Tracking | 5 | Complete 2026-08-15 (amended in v1.2) |
| 4. Planner Views | 5 | Complete 2026-08-16 (amended in v1.2) |
| 5. Localization & Settings | 5 | Complete 2026-08-16 |
| 6. Shell & Simplification | 6 | Complete 2026-08-17 |
| 7. Dose Reminders | 6 | Executed 2026-08-17 — device pass unfinished |
| 8. Onboarding | 1 | Complete 2026-08-31 — redesigned mid-phase |
| 9. Languages & the Release Gate | 0 (direct commits) | Complete 2026-09-01 |

## Accumulated Context

### Decisions

Decisions are logged in PROJECT.md Key Decisions table. The ones a session
picking this up now has to know:

**v1.2, onboarding (2026-08-31)**

- **Path A: no overlays, no spotlight, no blocking.** The two explain screens of
  the spec's D-1 were built, then read against the research rather than shipped
  on the strength of the decision. NN/g's 70-participant test found an intro
  tutorial left participants rating the *same* tasks harder — 4.92 against 5.49
  of 7 — with no gain in task success or speed. Coach marks fired at session
  start fail identically: the explanation arrives before the user needs it.

- **What replaced it:** a two-page intro (page 1 the daily loop, page 2 what the
  Календар answers) plus one-time inline hints at the moment their subject first
  appears — the cycle idea in the regimen editor's schedule panel, marking a
  dose on Сьогодні only on a day that has doses.

- **The calendar page earned its place** because no contextual hint can answer
  "why is there a calendar tab": a hint there only fires once the user has
  already opened Календар.

- **The Settings restore row ships in every build**, not just debug. It writes
  only the two first-run preference keys; the alternative was deleting the app,
  which takes the user's stack with it.

- The spec is now partly wrong and says so: see its *What shipped* section.

**v1.2, languages (2026-09-01)**

- **Six languages, not nine** — the owner's phrasing, and worth unpacking so a
  later session does not mis-count it: seven locales ship (en the fallback, uk,
  es, fr, ar, hi, zh), which is six languages besides English. Nine new ones
  were in flight and the gates were hardened for all nine; Portuguese, Russian,
  Bengali and Urdu were then cut. Their forbidden-vocabulary stem lists were
  captured in that session's history; their ARB files were never written, so
  nothing of them is in the repository.

- **No new fonts are bundled.** Instrument Sans covers 343 codepoints, Latin
  only — it has no Cyrillic, so Ukrainian has always rendered through the
  platform's own font, exactly as the approved mockup does. The new scripts do
  the same. Bundling CJK alone would add 10+ MB for one language.

- **The heavy checks run before a production build, not on every edit.** The
  all-locale vocabulary scan and the all-locale render sweep live in
  `test_release/`, a sibling directory — not a `@Tags` annotation and not a
  `dart_test.yaml` filter, because either of those can be switched off by
  editing one line in a file nobody reads at review time.

- **One clock shape, pinned rather than asked for.** CLDR gives Spanish `H:mm`
  and every other shipped locale `HH:mm`, so `alwaysUse24HourFormat` produced a
  ragged column in es. The pattern is now fixed in one place; the locale still
  chooses the digits.

**v1.2, corrections to shipped phases (2026-09-01)**

- **The planner window is `[first of LAST month, +4 months)`** (owner change).
  Same four-month width, band shifted back one month, so today sits strictly
  inside it with history behind the marker — and a January clock now opens the
  window in the previous year.

- **A future day refuses every mark**, on the tap path and the
  assistive-technology path alike. Today is not future: a 21:00 dose is still
  markable at 10:00.

- **Every distinct dose time inside a block carries its own label**; the block
  label appears once, and the accent marks the next time actually due rather
  than the block's earliest.

**Earlier, still standing**

- Foundation, domain math, DB and app shell were bundled into a single Phase 1;
  L10N verification was deferred to Phase 5 because "zero hardcoded strings" and
  full plural coverage cannot be honestly checked before every screen exists.

- `intl` is never hand-pinned — SDK resolution picks it via
  `flutter_localizations`.

- One variable-font TTF per family under `assets/fonts/`, one pubspec entry
  each, no `weight:` fanning.

- UI depends on repository interfaces only; Drift is one implementation.

### Pending Todos

**SHIP-01 — RevenueCat plus a developer tip, for Shipaton 2026. Code complete
and uploaded 2026-09-22; nothing left in this repository. Hard deadline
30 September 2026, 11:45pm PDT, and Devpost requires the app to be PUBLIC in
the store by then, not merely submitted — so the last useful submission date is
around the 26th, allowing one review cycle and no rejection.**

*Built 2026-09-22*, plan `docs/superpowers/plans/2026-09-22-vitomy-developer-tip.md`:
the `PurchaseGateway` seam and its no-op, the provider graph with a
three-valued readiness enum, `RevenueCatGateway` behind it as the one importer
of `purchases_flutter`, nine ARB keys in all seven languages, the support
screen under `lib/features/support/` with its row in Settings, and four source
gates keeping the narrowed privacy claim true. `flutter test` is 1167 green.

*Closed 2026-09-22:* the Paid Apps Agreement, the iOS SDK key
(`appl_tHaMLJaZlflFHRMyAJkHdeMbadm`, verified against the live service — a
throwaway integration test configured the real SDK with it and `configure()`
returned), the three consumables in App Store Connect, and the RevenueCat app
record. `flutter test test_release/` is 48 green. **Build 1.1.0 (3) uploaded
2026-09-22**, Delivery UUID `e8aa6193-8be1-476a-a72d-ddaf21b1b8af`.

*What the owner still has to do, in order:*

1. **Create the 1.1.0 version record in App Store Connect, spelled exactly
   `1.1.0`.** The build is `1.1.0` from pubspec, and a record spelled `1.1`
   does not list it in the build picker. That trap already cost time on 1.0.
2. **Install the TestFlight build on a real iPhone and open Settings, Support.**
   This is the only honest pre-review check that the offering resolves: a
   simulator has no access to the live App Store API, so `getOfferings()`
   returns CONFIGURATION_ERROR there however correct the dashboard is. A
   TestFlight purchase runs in sandbox against the tester's own Apple ID, so
   no sandbox-tester account has to be created. If the three tips show with
   prices, App Review sees them too; if the screen says unavailable, the
   dashboard is not finished and a rejection cycle has been avoided. Newly
   created products can take up to 24 hours to become fetchable.
3. ~~Redeploy the site before hitting Submit.~~ **Done 2026-09-22.**
   `https://vitomy.app/privacy` now carries the tip section and no longer
   claims the app stays off the internet. The rsync dry run showed zero
   deletions and zero additions, with content changing in exactly one file, so
   the App Store button a parallel session had put live was not disturbed;
   both neighbouring sites on the box still answer 200.
4. Flip the Apple privacy label, which `store/listing.md` now states.
5. Submit, then **watch for the App Review reply**. The reviewer tests the
   purchase, so an unconfigured offering is a rejection rather than a quiet
   failure.

Full research, with every version, quote and citation:
`docs/research/2026-09-09-revenuecat-shipaton.md`. Read §6 through §9 before
starting — what follows is a pointer, not a substitute.

*Decided:*

- **iOS only.** Google Play's 12-testers-for-14-days rule plus up to 7 days of
  production review does not fit the window. Android follows after the
  hackathon.

- **One consumable tip** ("support the developer"), not a subscription. Apple
  permits developer tips outright (guideline 3.1.1) and an in-app purchase is
  not obliged to deliver anything, so this needs no entitlement, no feature
  gate, no Restore control and no reinstall edge case. Shipaton requires only
  "at least one in-app or web purchase".

- The word is **support** or **tip**, never **donate**: 3.2.2(iv) bans in-app
  fundraising for charities and pushes such apps to collect outside the app.

- RevenueCat Paywalls do not support consumables, so the tip screen is
  hand-built from the design tokens with `purchases_flutter` alone.

*Blocking, and none of it is code:*

1. Apple Developer Program enrolment.
2. **Paid Apps Agreement, banking and tax forms.** No in-app purchase can be
   tested even in the sandbox until the bank status reads Clear, and the tax
   forms appear only after the agreement is signed. It looks like paperwork; it
   is a dependency.

3. ~~Final app name and bundle id~~ — **closed 2026-09-11**: VitoMy,
   `app.vitomy`. It becomes permanent the moment the App Store Connect record
   is created, so do not create that record casually.

*Code shape — all three follow patterns already in this tree:*

- `Purchases.configure()` runs behind the first frame from a bootstrap provider
  shaped like `notificationBootstrapProvider`. Its completion flag is
  load-bearing, not decoration: calling any SDK method while configure is still
  in flight throws `There is no singleton instance`.

- A `PurchaseGateway` interface in `lib/core/purchases/` (not `core/domain/`,
  which imports nothing outside `dart:core`), plugin-backed implementation
  overridden in `main()` the way `notificationSchedulerProvider` is, so no test
  ever touches a method channel.

- Tip copy in all seven ARB files.

*Required regardless of what is sold:*

- **`test/platform_config_test.dart` will stay GREEN while its claim stops
  being true.** `purchases-android`'s library manifest declares `INTERNET` and
  `ACCESS_NETWORK_STATE` and they merge in at build time, but the test reads
  the *source* manifests under `android/app/src/*/`. Fix it in the same commit
  that adds the dependency; do not leave it passing.

- LEGAL-01 below: both legal documents and the store privacy labels change in
  the same release. Apple label becomes Purchases → Purchase History, purposes
  Analytics and App Functionality, not linked to identity.

- A new gate asserting the app never sets RevenueCat subscriber attributes, so
  "your supplement data never leaves the device" stays true by construction
  rather than by intention.

**Closed, kept because two are still load-bearing constraints:**

- Instrument Sans Cyrillic gap → LOCKED: keep the platform fallback. The
  approved HTML mockup renders Cyrillic through browser fallback, so matching
  the design means keeping it. Gated in `test/` so it cannot change silently.
  Revisiting invalidates the Phase-4 gantt truncation measurements and requires
  re-running the text-scale matrix. **Reaffirmed 2026-09-01** when five more
  languages landed: the same reasoning now covers Arabic, Devanagari and CJK.

- Riverpod 3 auto-retry error surface → FIXED: errors beat the retry-loading
  state, so a failing local DB shows the designed error surface immediately.

- Gantt label truncation at 14px week columns → accepted for v1 with
  measurements in `04-UAT.md`; revisit only on user feedback.

### Blockers/Concerns

- **Phase 7 is executed but not closed.** Every plan ran and every automated
  gate is green; what is missing is device evidence that a reminder actually
  arrives. Android's automated half passed on emulator-5554; the iOS half is
  blocked on a human tapping Allow. Do not read the unchecked NOTIF boxes in
  REQUIREMENTS.md as "not built".

- ~~Release builds are still debug-signed.~~ **Fixed 2026-09-11** (`ecd3c00`).
  A 4096-bit upload key lives outside the repo at
  `~/keys/vitomy-upload-keystore.jks`, named by the gitignored
  `android/key.properties`. A release build with no key.properties now throws
  instead of falling back, and `test/platform_config_test.dart`'s five signing
  tests guard both directions.

- ~~The bundle id is a placeholder and the app name is undecided.~~
  **Closed 2026-09-11**: **VitoMy**, `app.vitomy`.

- **Play wants a rising versionCode.** `pubspec.yaml` is at `1.0.0+2` (build 2 is the iPhone-only iOS upload of 2026-09-11; the Play internal-testing bundle was built at +1) and the
  first internal-testing upload consumes versionCode 1. Every later upload
  needs a higher one: `flutter build appbundle --release --build-number=N`, or
  bump the `+N` in pubspec.

- **Arabic RTL has never been seen by a human on a device.** The
  `test_release/` sweep proves the tree laid out right-to-left and threw no
  layout exception; it cannot tell you whether the screen reads well.

- ~~The app's offline claim is about to narrow.~~ **Done 2026-09-22.** Both
  legal documents were rewritten in the same commit that added the dependency,
  which is what LEGAL-01 asks for. `privacy.md` now carries an "If you leave a
  tip" section naming RevenueCat as a processor, and `terms.md` gained a
  section 5 on tips and purchases (sections 5 to 21 renumbered to 6 to 22, and
  the one cross-reference updated).

  **The site is deliberately NOT redeployed yet.** `https://vitomy.app/privacy`
  renders from that markdown at build time, so publishing now would put a
  policy describing a tip in front of everyone running 1.0.0, which has no
  purchases in it. The trigger is the submission of the tip build: the policy
  has to be live before Apple reviews it, and not meaningfully before that.
  One command when the moment comes, from `site/`: `npm run deploy`.

### Quick Tasks Completed

| # | Description | Date | Commit | Directory |
|---|-------------|------|--------|-----------|
| 260911-mms | App Store listing: fix the 31-char subtitle and refresh promotional text, description and keywords in store/listing.md with ASO rationale; document the 6.5-inch ASC slot; make tool/make_screenshots.sh derive the 6.5-inch set; commit store/screenshots/ios-6.5 | 2026-09-11 | f18a84e, f097461, 82350a7 | [260911-mms-app-store-listing-fix-the-31-char-subtit](./quick/260911-mms-app-store-listing-fix-the-31-char-subtit/) |
| 2 | Tighten the App Store description in store/listing.md: no 'runs a stack', more supplement/vitamin wording, languages and data sections removed (owner request) | 2026-09-11 | fc79674 | — |
| 3 | Google Play listing assets and copy (feature graphic, 1080x1920 phone screenshots, texts); iOS 1.0 iPhone-only, pubspec 1.0.0+2, platform_config_test assertion (commits 92d185f, 77f649b, 204cc28) | 2026-09-11 | 204cc28 | — |
| 4 | App Review notes: the six-point reply to Apple's 2.1 Information Needed letter, in store/listing.md | 2026-09-13 | 1c1d9bf | — |
| 261005-nc6 | Three UI updates: dose times above periodicity in the regimen editor; the editor's primary button says Save when editing an existing regimen; the Today dose action sheet gained an Open dosing schedule row | 2026-10-05 | 5b6858a, 9b33e6a | [261005-nc6-move-dose-times-above-periodicity-rename](./quick/261005-nc6-move-dose-times-above-periodicity-rename/) |

## Waiting on a human

Nothing here is waiting on code. Each of these needs the owner, at a device or
an account:

1. **Tap Allow on the iPhone** (07-UAT entry 0, iOS half) — there is no shell
   route: `xcrun simctl privacy` has no notifications service, and driving the
   prompt from a harness leaves `requestPermission()` returning null. Everything
   in 07-UAT entries 1-8 and 10 is blocked behind it.

2. **Look at Arabic on a device**, right-to-left, once.
3. **Apple Developer Program enrolment**, then the **Paid Apps Agreement with
   banking and tax forms** — the second blocks even a sandbox purchase, and the
   tax forms only appear once the agreement is signed. Neither is code.

Closed 2026-09-11: the signing keystore, and the app name and bundle id.
Closed 2026-09-12: the public URL both stores require. `https://vitomy.app`
serves the privacy policy and the support page; see `SITE-01` below.

## Deferred Items

Items acknowledged and carried forward rather than done:

| Category | Item | Status | Deferred At |
|----------|------|--------|-------------|
| Reminders | 07-UAT entry 0 (iOS half) — a human must tap Allow; no shell equivalent exists | Open — human-only | 2026-08-17 |
| Reminders | 07-UAT entries 1-8 and 10 — delivery, Doze latency, lock-screen rendering, the Android channel row, the two permission dialogs, denial, tap destination, reboot re-arming, the autumn DST overlap | Open — blocked on entry 0 | 2026-08-17 |
| Release | Real signing keystore; Android release builds were debug-signed | **Closed 2026-09-11** — `~/keys/vitomy-upload-keystore.jks`, and a missing key.properties now fails the build instead of falling back | 2026-08-16 |
| Release | Final app name and bundle id | **Closed 2026-09-11** — **VitoMy**, `app.vitomy`, reverse-DNS of the owned domain vitomy.app; renamed throughout in `27172da` | 2026-08-16 |
| Localization | Eyes-on Arabic RTL pass on a device | Open — owner-only | 2026-09-01 |
| Localization | Portuguese, Russian, Bengali, Urdu — stem lists captured, ARB files never written | Cut mid-flight; re-openable, one ARB file each | 2026-09-01 |
| Planner | Gantt label truncation at 14px week columns | Accepted for v1; measurements in `04-UAT.md` | 2026-08-16 |
| Scheduling | FREQ-01 — weekly-rhythm dosing ("Mon/Thu", N times per week) | v2 backlog | 2026-08-31 |
| Data | EXPT-01 — export/import | v2 backlog, early fast-follow | 2026-08-14 |
| Release | Android release, after Shipaton — the Play 12-testers-for-14-days clock can start any time; `purchases_ui_flutter` would raise minSdk 21 → 24 and `MainActivity` must extend `FlutterFragmentActivity` | Deferred past 2026-09-30 | 2026-09-09 |
| Legal | LEGAL-01 — the release that adds analytics, crash reporting or a subscription must extend `docs/legal/privacy.md` + `terms.md` (clause bank in `docs/legal/2026-09-07-privacy-and-terms-research.md` §7) and update both store privacy labels in the same release | Standing; blocks any SDK addition | 2026-09-07 |
| Legal | Governing law and forum absent from `terms.md`; `[NOMINAL_SUM]` still a placeholder (`[APP_NAME]` and `[CONTACT_EMAIL]` filled 2026-09-11, the website references were removed; `[LAST_UPDATED]` was filled in `privacy.md` on 2026-09-11 for the site and remains only in `terms.md`) | Owner-only; the sum comes with the legal entity, the date with publication | 2026-09-07 |
| Site | `SITE-01` **done and live 2026-09-12**: `https://vitomy.app` serves the landing, `/privacy` and `/support`, behind Cloudflare with the origin refusing every non-Cloudflare address. Astro in `site/`, spec and plan under `docs/superpowers/`, 53 gates, Lighthouse 100 across the board. The Apple half of the launch-day switch is live (`stores.apple.url` and the official badge); `stores.google.url` stays null until Android ships. `/terms` stays unemitted until `[NOMINAL_SUM]` is filled | Closed; reopen only for the launch-day switches | 2026-09-12 |
| Copy | `saveAndStart` ("Add and start cycle") is the regimen editor's primary CTA on BOTH the add path and the EDIT path — editing an existing schedule offers to add it. Unconditional at `regimen_editor_screen.dart:903`, wrong in all seven languages. Found 2026-09-11 while reviewing a store screenshot | **Closed 2026-10-05** (`5b6858a`, quick task 261005-nc6) — one new ARB key `saveChanges` in all seven files, each value the save verb already opening that same file's `saveWhilePaused`, plus a three-way footer conditional on `draft.regimenId != null`. The paused branch deliberately did NOT split and the save HINT got no edit variant; both non-changes are argued in the `_EditorFooter` doc comment | 2026-09-11 |
| UX | The time-slots block sits below periodicity and the cycle sliders in the regimen editor (`regimen_editor_screen.dart`, the `timeSlotsLabel` section around line 142). Times are the field a person edits most often and it is the one they have to scroll to. Move it higher in the form | **Closed 2026-10-05** (`5b6858a`, quick task 261005-nc6) — DOSE TIMES now sits directly under the supplement header, PERIODICITY follows, the 22px section gap is the same single widget it was before the swap, and `BqHint.cycle` travelled down with the sliders it explains. Render matrix re-run: all seven locales at 1.0 / 1.6 / 2.0, no layout exception, order holding under Arabic RTL. A `.dy` comparison in `test/features/regimen_editor_test.dart` is the only thing standing between the fix and a silent revert | 2026-09-18 |
| UX | No way into the supplement or schedule editor from the daily dose sheet (`lib/features/calendar/dose_action_sheet.dart`). Tapping a dose on Today offers marking only, so correcting a time or a name means going back to the Stack tab. Add an edit entry point to that sheet | **Closed 2026-10-05** (`9b33e6a`, quick task 261005-nc6) — an unconditional `openSchedule` row last in the sheet, plus the matching `CustomSemanticsAction`, both going through one private method so gesture and screen reader cannot drift. The sheet now resolves to a sealed `DoseSheetResult`, so `DoseStatus` (a Drift-persisted domain enum) gained no UI-only member and `DoseRow` stays the single write AND navigation site. **A FUTURE dose row still has no path in**, and that is deliberate: it has no long press at all, and giving it one would mean the sheet learning the row state and suppressing its mark rows, which reopens the single-write-path guarantee. The editor stays reachable from Стек and from any non-future row of the same supplement. The row names the SCHEDULE, not the supplement, because the destination's supplement header is read-only (PF-5) | 2026-09-18 |
| Release | The three committed `05-schedule.png` store screenshots — `store/screenshots/ios-6.5/`, `ios-6.9/` and `android-phone/` — show the OLD editor block order and the OLD `saveAndStart` button label. `integration_test/store_screenshots_test.dart:205-219` photographs the regimen editor over a stack seeded WITH regimens, so quick task 261005-nc6 invalidated all three at once. **The live App Store listing is out of date, not broken** — a stale screenshot shows a real screen from a previous version, it does not misrepresent a feature that no longer exists. Deliberately NOT regenerated in that task: it needs a 6.9" simulator erased and pinned through `tool/make_screenshots.sh`, then a listing pass in both consoles, which is its own operation | Open — owner-only, needs a simulator run plus a listing update; batch it with the next store submission rather than on its own | 2026-10-05 |
| Copy | The developer-tip screen's copy needs a rewrite — `supportTitle`, `supportBody` and the three tip labels, rendered by `lib/features/support/support_screen.dart`. Asked for 2026-09-25 while the 1.1.0 resubmission was in flight; the replacement wording is not decided yet | Open — one key set across 7 ARB files. Two constraints survive any rewrite: "donate"/"donation" may never appear (Apple 3.2.2(iv) — the screen says "tip"/"support"), and no medical or guilt-framed register, which `test_release/copy_safety_all_locales_test.dart` holds | 2026-09-25 |
| Review | 6 Info-level review findings and 4 lower-severity security items | Documented, deliberately unfixed; none affect correctness or privacy | 2026-08-16 |

## Session Continuity

Last session: 2026-09-22 — the developer tip, SHIP-01, built and uploaded.
Everything it touched is in the SHIP-01 entry under *Pending Todos*; the short
version is that the app now sells three consumable tips that unlock nothing,
`purchases_flutter` is its first network-capable dependency ever, and both
legal documents plus the live site changed in the same release because
LEGAL-01 requires it.

Stopped at: working tree clean, no phase in flight, build 1.1.0 (3) sitting in
App Store Connect. **The public store still served 1.0 on 2026-09-25**, so the
tip release has not shipped.

Resume file: None — start from *Current Position* above, then SHIP-01.

**Reminders for whoever picks this up:**

- The repo has **no remote** — never push.
- `flutter test` does not run `test_release/`; run that separately before a
  production build. It is the only thing that notices an empty RevenueCat key.
- **A simulator cannot verify a purchase.** It has no access to the live App
  Store API, so an empty offering there says nothing about the dashboard. The
  only honest pre-review check is a TestFlight build on a real phone.
- The Shipaton deadline is **30 September 2026** and Devpost requires the app
  to be public in a store by then, not merely submitted. As of 2026-09-25 that
  is five days, and an App Review cycle is two to three.
- Two older items still wait on a person: the iOS notification UAT needs
  somebody to tap Allow on a device, and Arabic has never been read
  right-to-left by human eyes on a phone.
