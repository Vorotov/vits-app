---
gsd_state_version: 1.0
milestone: v1.2
milestone_name: Onboarding, Languages & the Release Gate
current_phase: 9
status: milestone_shipped_pending_device_pass
stopped_at: "Phase 9 shipped (fc7bfd3); no phase in flight"
last_updated: "2026-09-02T00:00:00Z"
last_activity: 2026-09-01
last_activity_desc: "Phase 9 complete — seven locales, cross-locale defect fixes, test_release/ gate, planner window shifted"
progress:
  total_phases: 9
  completed_phases: 8
  total_plans: 40
  completed_plans: 40
current_phase_name: Languages & the Release Gate
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
Last activity: 2026-09-01 — planner window shifted and its fixtures moved (`fc7bfd3`)

Progress: [██████████] 9 phases, 8 closed — Phase 7 (Dose Reminders) is executed but not closed

**What a future session most needs to know, in one place:**

- **Everything is built.** v1 (Phases 1-5), v1.1 (6-7) and v1.2 (8-9) are all
  implemented and merged on `main`. The working tree is clean and the repo has
  **no remote** — never push.
- **Two suites, not one.** `flutter test` runs `test/` only, and stays uk+en.
  `flutter test test_release/` is the pre-production gate: the medical-claim
  vocabulary scan and the whole-screen render sweep, both across all seven
  locales, Arabic under real RTL. Run it before a production build; nothing
  else runs it. Counts as recorded at `fc7bfd3`: 1089 in `test/`, 41 in
  `test_release/` — treat them as a marker, not a contract; measure before
  quoting.
- **The only open work is human-only.** No code is waiting on a decision. Four
  items need a person at a device or an account — listed under *Waiting on a
  human* below, and in the Deferred Items table.
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

**SHIP-01 — RevenueCat plus a developer tip, for Shipaton 2026. In flight.
Hard deadline 30 September 2026, 11:45pm PDT.**

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
3. Final app name and bundle id — `app.vitomy` becomes permanent the
   moment the App Store Connect record is created.

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
- **Release builds are still debug-signed.** Asserted by
  `test/platform_config_test.dart` so it cannot be forgotten. Harmless until
  distribution, blocking at it.
- **The bundle id is still `app.vitomy`** and the app name is undecided.
  Both must be settled before a first store release.
- **Arabic RTL has never been seen by a human on a device.** The
  `test_release/` sweep proves the tree laid out right-to-left and threw no
  layout exception; it cannot tell you whether the screen reads well.
- **The app's offline claim is about to narrow.** SHIP-01 adds the first
  network-capable dependency the app has ever had. The honest replacement claim
  is that supplement data never leaves the device and the only traffic is the
  purchase; `docs/legal/privacy.md` still says the app does not connect to the
  internet at all.

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
4. **A public URL for `docs/legal/privacy.md`.** Both stores require a privacy
   policy link and Apple additionally requires a Support URL; neither field is
   optional, and the project has no site yet.

Closed 2026-09-11: the signing keystore, and the app name and bundle id.

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
| Legal | Governing law and forum absent from `terms.md`; `[CONTACT_EMAIL]` and `[NOMINAL_SUM]` still placeholders (`[APP_NAME]` filled 2026-09-11, the website references were removed) | Owner-only; add with the legal entity | 2026-09-07 |
| Copy | `saveAndStart` ("Add and start cycle") is the regimen editor's primary CTA on BOTH the add path and the EDIT path — editing an existing schedule offers to add it. Unconditional at `regimen_editor_screen.dart:903`, wrong in all seven languages. Found 2026-09-11 while reviewing a store screenshot | Open — needs a second ARB key in 7 files plus a conditional; not a correctness bug | 2026-09-11 |
| Review | 6 Info-level review findings and 4 lower-severity security items | Documented, deliberately unfixed; none affect correctness or privacy | 2026-08-16 |

## Session Continuity

Last session: 2026-09-11 — store-readiness pass. The app is now **VitoMy**,
bundle id `app.vitomy`, renamed end to end including the Dart package. Release
builds are signed with a real upload key and refuse to fall back to the debug
keystore. Both platforms have a real app icon, generated by `tool/make_icons.py`
from the design tokens. `tool/make_screenshots.sh` plus
`integration_test/store_screenshots_test.dart` produce the listing screenshots
from the running app on a 6.9" simulator.
Stopped at: working tree clean, no phase in flight.
Resume file: None — start from *Current Position* above, then
`.planning/phases/07-dose-reminders/07-UAT.md` if a device is available.

**Reminders for whoever picks this up:** the repo has **no remote** — never
push. `flutter test` does not run `test_release/`; run that separately before a
production build.
