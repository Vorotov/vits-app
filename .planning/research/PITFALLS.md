# Pitfalls Research

**Domain:** Local-first Flutter tracking app with recurring/cyclic schedules (supplement stack planner), full i18n (uk/en), iOS + Android store release
**Researched:** 2026-08-14
**Confidence:** MEDIUM-HIGH (official Apple/Google policy pages = HIGH; Flutter/Drift/Riverpod community sources = MEDIUM; UX/domain pitfalls extrapolated from adjacent habit-tracker research = MEDIUM-LOW)

## Critical Pitfalls

### Pitfall 1: Local wall-clock date arithmetic breaks cycle math across DST

**What goes wrong:**
Cycle rules ("2 weeks on, 1 week off, repeat") are computed by adding `Duration(days: n)` to a local (non-UTC) `DateTime`. Twice a year, the local day is 23 or 25 hours long because of a DST transition. Adding 24-hour `Duration`s to a local `DateTime` on those days silently lands on the wrong calendar date, shifts week boundaries by one day, or duplicates/skips a dose day. Naive `addDays`/`addMonths` on local wall time misbehaves across DST boundaries.

**Why it happens:**
Dart's `DateTime` is either UTC or "local" (device timezone), and arithmetic on the local variant is timezone-aware — a `Duration` add does not mean "same wall-clock time next day," it means "add exactly N*24h," which is wrong on DST-transition days. Developers who test only in one timezone (often UTC, e.g. CI runners) never see the bug.

**How to avoid:**
Normalize every date used in cycle math to `DateTime.utc(y, m, d)` (already decided in PROJECT.md constraints) and do all interval/week arithmetic in that space, never mixing in local `DateTime`. Never call `DateTime.now()` (local) inside domain cycle-math functions — pass in an already-normalized UTC "today" from the caller. Keep cycle math in `core/domain` as pure functions with no `DateTime.now()` calls, so tests fully control the input date.

**Warning signs:**
- Any function in `core/domain` calls `DateTime.now()` directly instead of receiving a date parameter.
- Cycle math uses `date.add(Duration(days: n))` on a non-UTC `DateTime`.
- Unit tests for cycle math only cover one timezone / no DST-boundary dates (e.g., nothing testing the last Sunday of March or October).

**Phase to address:**
The phase that implements `core/domain` cycle math (dose generation, week-range activation) — before any UI consumes it.

---

### Pitfall 2: Destructive or untested Drift schema migrations

**What goes wrong:**
A schema change ships without a corresponding migration step, or with a hand-written migration that was never run against a real on-device database with existing rows. Users upgrading the app lose data (table dropped/recreated) or the app crashes on launch because the migration doesn't match the exported schema.

**Why it happens:**
Drift's code generator only sees the *current* schema; without exported schema snapshots there is nothing to diff or test migrations against. Developers often bump code but forget to bump `schemaVersion`, or write `MigrationStrategy.onUpgrade` logic that was only exercised on a fresh install (where `onCreate` runs instead of `onUpgrade`), so the upgrade path is silently unverified.

**How to avoid:**
Use Drift's schema export/`make-migrations` tooling from the very first schema change (even during pre-release iteration) so there's a paper trail of every version. Increment `schemaVersion` on every table/column change. Add a migration test that constructs a database at each prior schema version with representative seed rows and asserts data survives the upgrade — not just that the upgrade "runs without throwing."

**Warning signs:**
- `schemaVersion` unchanged despite a table/column edit in the same commit.
- No `drift_dev` schema snapshot files checked into the repo.
- Migration logic only ever tested via fresh app install during development (simulator/emulator gets wiped between test runs).

**Phase to address:**
The phase that stands up the Drift database/tables — establish the schema-export + migration-test discipline before the first post-v1 schema change is needed (which is soon, since v1 already anticipates future widgets/notifications/sync columns).

---

### Pitfall 3: Riverpod autoDispose / stream lifecycle mistakes

**What goes wrong:**
Two related failure modes: (a) a non-`autoDispose` provider watches an `autoDispose` provider, which keeps the auto-disposing provider alive forever (defeats its purpose, leaks the underlying Drift stream subscription); (b) an `autoDispose` `StreamProvider` watching a Drift query gets disposed and re-created repeatedly as widgets mount/unmount during navigation (e.g., switching between Today/Cycles/Year tabs), causing the same query to re-subscribe on every tab switch and, in pathological cases, rebuild the widget tree in a loop.

**Why it happens:**
Riverpod's dependency rule ("`.autoDispose` can only be watched from another `.autoDispose` scope, or explicitly kept alive") is easy to violate accidentally, especially when a screen-level provider composes several repository-backed stream providers. Calendar-style apps that re-subscribe to date-ranged queries per screen are especially prone to this because navigation between Today/Cycles/Year naturally mounts/unmounts the underlying providers.

**How to avoid:**
Decide per-provider, deliberately: repository-level Drift stream providers that back long-lived data (the supplement list, the active regimens) should generally not be `autoDispose` — they're cheap to keep warm and the calendar tabs share them. Screen-scoped providers (e.g., "doses for this specific visible date range") can be `autoDispose`, but must not be watched from a non-`autoDispose` ancestor. Where a provider needs to survive brief unmounts (tab switching) without living forever, use `ref.keepAlive()` with an explicit timeout/`ref.onDispose` link instead of leaving it un-disposed by default.

**Warning signs:**
- Riverpod dev-tools/logs show the same Drift stream provider re-initializing every time the user switches calendar tabs.
- A provider is marked `autoDispose` but is watched from `main.dart`/an app-level provider that isn't.
- Widget rebuild counts spike when navigating between Today/Cycles/Year without any underlying data change.

**Phase to address:**
The phase that wires repositories to Riverpod providers and the phase that builds the Calendar tab (Today/Cycles/Year) — decide the autoDispose policy once, in the repository-provider phase, so screen phases just consume it consistently.

---

### Pitfall 4: ICU plural mishandling for Ukrainian, and gen-l10n's nested-plural limitation

**What goes wrong:**
Ukrainian (like Russian) has plural categories `one`/`few`/`many`/`other` selected by the last two digits of the number, with an irregular exception where numbers ending in 11–14 use `many` even though they end in a digit that would otherwise select `few`/`one` (e.g. "1 речовина", "2 речовини", "5 речовин", "11 речовин" — not "11 речовина"). A developer who writes only `one`/`other` in the ARB `plural` block (the pattern that works for English) silently mis-pluralizes every Ukrainian count ending in 2–4 or 11–14. Separately, Flutter's `gen_l10n` tool does not support nested plurals/selects in one message (e.g., "N supplements, M taken today" as a single interpolated string) — this is a known open Flutter tooling gap, not a bug in the app.

**Why it happens:**
CLDR defines up to six plural categories; most languages the team has prior experience with (English) only exercise `one`/`other`, so the `few`/`many` branches get forgotten or copy-pasted incorrectly. The nested-plural gap is not obvious until someone tries to write a compound pluralized string and the generator rejects it or produces wrong output.

**How to avoid:**
For every ARB `plural` entry, always write all four forms Ukrainian needs (`one`, `few`, `many`, `other`) — never just `one`/`other`. Validate with real Ukrainian count nouns during translation review, specifically testing 1, 2, 5, 11, 21, 22, 25 (the numbers that exercise every branch, including the 11–14 exception). Do not attempt a single ARB message with two independent pluralized quantities — split into two separate translated strings/widgets composed in code instead of relying on gen-l10n nested plural support.

**Warning signs:**
- Any ARB `plural` block that only defines `one` and `other` for a string that will be used with uk locale.
- UI review only ever spot-checks the number "1" or "5" for Ukrainian, not the 11–14 exception range.
- A single ARB message tries to interpolate two different countable quantities.

**Phase to address:**
The i18n/l10n setup phase (ARB file structure, translation review checklist) and re-verified in every phase that adds a new pluralized string (Stack, Calendar).

---

### Pitfall 5: Missing or incomplete iOS Privacy Manifest blocks App Store submission

**What goes wrong:**
Since privacy manifest enforcement began in 2025, Apple's App Store Connect rejects uploads (`ITMS-91061` and similar errors) when the app or any *transitive* third-party SDK dependency lacks a `PrivacyInfo.xcprivacy` declaring its use of "required reason" APIs (e.g., UserDefaults, file timestamps, disk space). Flutter apps are especially exposed because common plugins (`device_info_plus`, `package_info_plus`, `path_provider`, `sqflite`/native SQLite wrappers used under Drift) pull in native code that touches these APIs, and the manifest can be missing or shadowed when packaged inside a Flutter iOS framework.

**Why it happens:**
This is enforced late — at App Store Connect upload time — long after development is otherwise "done," so teams that don't check it until the first real submission attempt get blocked right before a release, with no warning during local builds or TestFlight-only workflows.

**How to avoid:**
Treat the privacy manifest as a release-readiness checklist item from the first phase that adds native plugins (device info, path/file access, the native SQLite driver Drift uses), not something deferred to a "ship" phase. Run an actual archive + App Store Connect validation upload early (even to a throwaway/test app record) well before the intended release date, so any missing-manifest error surfaces with time to fix it. Audit every plugin dependency's own privacy manifest status (check plugin changelogs/issue trackers), and add the app-level `PrivacyInfo.xcprivacy` for the app's own required-reason API usage.

**Warning signs:**
- No `PrivacyInfo.xcprivacy` file anywhere in the iOS project by the time the release-prep phase starts.
- Never having done a real "Validate App" / upload pass in App Store Connect before the intended release week.
- Using plugins pinned to older versions without checking whether that version ships a privacy manifest.

**Phase to address:**
Should be checked incrementally as native plugins are added (Stack/Calendar phases), with a dedicated verification step in the release-prep phase — do not leave this to discovery at actual submission time.

---

### Pitfall 6: Missing Android target SDK deadline (targetSdk 36 required from Aug 31, 2026)

**What goes wrong:**
Google Play requires new apps and app updates to target **Android 16 (API level 36)** starting **August 31, 2026** (existing apps must target at least API 35 to remain visible to new users on newer OS versions). An app built against an older `compileSdkVersion`/`targetSdkVersion` — which is easy to end up with with older Flutter/Gradle templates or unmaintained plugin transitive requirements — will be rejected at submission (or lose Play Store discoverability for existing installs) after that date. Given the project's current date, this deadline is imminent for any release planned in the second half of 2026.

**Why it happens:**
Android SDK/Gradle/AGP versions in a Flutter project are often left at whatever the `flutter create` template pinned at project start, and Flutter plugin authors sometimes lag behind the newest Android API before it's officially required, so "it built and ran on my device" hides an outdated `targetSdkVersion`.

**How to avoid:**
Set `targetSdkVersion`/`compileSdkVersion` to the latest available (API 36 track) as soon as Flutter/Android tooling supports it, not just before submission. Add a release-readiness check that confirms the Play Console "Target API level" requirement is met before any planned submission date. Track this explicitly if release is planned close to or after Aug 31, 2026 — request the Nov 1, 2026 extension proactively if a hard deadline is at risk, don't discover the requirement at upload time.

**Warning signs:**
- `android/app/build.gradle` targetSdkVersion pinned to a value set at `flutter create` time and never revisited.
- No line item in release planning that checks current Google Play API-level policy against the target ship date.

**Phase to address:**
Release-prep phase, verified again immediately before submission since the policy has a hard calendar deadline independent of the project's own schedule.

---

### Pitfall 7: App Store review scrutiny for health/wellness-adjacent apps and medical-advice wording

**What goes wrong:**
Apps that present health-related information — even "educational" supplement scheduling — can be flagged under Apple's stricter health-app guidelines (1.4.1 and related) if copy reads as diagnostic/treatment advice, if it implies measurement accuracy the app doesn't have, or if health claims/sources aren't disclosed. Apps have been rejected or re-classified as "medical" even when the developer considered them wellness-only, forcing a resubmission cycle. Apple expects apps offering health guidance to remind users to consult a doctor and, where claims are made, to cite credible sources.

**Why it happens:**
The line between "tracking tool" and "medical app" is judged subjectively by App Review, and copy that reads as neutral to a developer (dosage names, "cycle," "concurrent load" warnings) can read as medical guidance to a reviewer, especially when paired with visual severity cues (the mockup's calm/warn/risk color coding for concurrent substance counts).

**How to avoid:**
Keep the existing project convention (never promise health effects; every recommendation-adjacent screen carries an "educational material, not medical advice" disclaimer) consistent and visible on every screen that shows dosing/scheduling guidance, not just one onboarding screen. Avoid wording that implies the app assesses interaction risk or safety (the mockup's "5-substance concurrent limit" must stay framed as editorial/organizational, not a safety threshold) — PROJECT.md already flags this as editorial-only, keep that framing consistent in all UI copy and store listing text. When writing the App Store description/metadata, avoid words like "safe," "effective," "recommended dose," or "risk" in ways that imply clinical validation.
Note: interactions/risk scoring is explicitly out of scope for v1 per PROJECT.md — this pitfall is about copy/tone even for the simpler v1 feature set (color-coded concurrent-dose counts, cycle warnings), not about the deferred Advisor feature.

**Warning signs:**
- Screens or store copy using words like "safe," "risk," "recommended," "warning" without a disclaimer nearby.
- Concurrent-dose color coding (calm/warn/risk) described anywhere as a safety assessment rather than a visual organizer.
- No disclaimer visible on the screens that actually show dosing guidance (only on a one-time onboarding screen, which v1 doesn't even have).

**Phase to address:**
UI copy/content review pass in the Stack and Calendar phases (wherever dosing/cycle guidance is rendered), and again in the release-prep phase when writing App Store metadata/screenshots.

---

### Pitfall 8: No backup path for a local-only data store

**What goes wrong:**
With no accounts, no network, and all data in an on-device SQLite file, an app uninstall, device loss/replacement, or (on iOS) a user who has iCloud backup for apps disabled results in **total, irrecoverable loss** of the user's entire supplement history and cycle configuration — potentially months of tracked data. This is a well-documented pain point for local-first apps generally (data loss after reinstall is a recurring complaint theme in habit-tracker reviews).

**Why it happens:**
"Local-first, no backend" is the correct v1 scope decision (explicitly chosen in PROJECT.md to ship fast without server costs), but it's easy to treat "no cloud sync" and "no backup at all" as the same decision when they aren't — a local export/import file is not a backend and doesn't compromise the "no accounts, no network" constraint.

**How to avoid:**
This is explicitly out of scope for v1 per PROJECT.md, which is a reasonable scope cut — but the roadmap should flag it as a near-term follow-up (e.g., a JSON/file export the user can manually save via the OS share sheet, or piggybacking on the OS's own app-data backup — iOS's default iCloud device backup and Android's Auto Backup already cover app-local SQLite databases unless explicitly excluded). Verify at minimum that the app does **not** opt out of the platform's default backup-inclusion behavior (Android `android:allowBackup`, iOS's default app-data backup) unless there's a specific reason to exclude the database — that's a near-zero-cost safety net that requires no v1 architecture change.

**Warning signs:**
- `android:allowBackup="false"` set without a documented reason.
- iOS project excludes the database file from backup (`NSURLIsExcludedFromBackupKey`) without a documented reason.
- No mention of export/backup anywhere in the roadmap even as a fast-follow milestone.

**Phase to address:**
Verify default OS backup inclusion during the Drift/database setup phase (near-zero cost, do it once). Flag manual export/import as a candidate early fast-follow milestone rather than deferring indefinitely, given it directly protects the "months of tracked data" the app's core value depends on.

---

## Technical Debt Patterns

Shortcuts that seem reasonable but create long-term problems.

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|-----------------|------------------|
| Storing/comparing dates as local (non-UTC) `DateTime` "for now, fix later" | Slightly less normalization code up front | DST bugs surface months later, often only for users in DST-observing regions, hard to reproduce and root-cause after the fact | Never — the UTC-normalization convention is already in PROJECT.md; enforce it from the first commit |
| Hand-writing Drift migrations without schema snapshots during early iteration | Faster to prototype schema changes | No safety net once real user data exists; retrofitting snapshot discipline after several unsnapshotted migrations is much harder than starting with it | Only acceptable pre-first-release, on schemas with zero real user data — must be fixed before v1 ships |
| Querying Drift tables directly from a widget/screen instead of through the repository interface, "just this once" | Saves writing a repository method | Breaks the backend-ready architecture PROJECT.md commits to; each violation is another place a future sync/backend implementation must special-case | Never — repository boundary is a stated architectural constraint, not a style preference |
| Hardcoding a string during development instead of adding an ARB entry ("I'll localize it later") | Faster to iterate on a screen | Strings get shipped un-localized because "later" never has a dedicated pass; violates the "zero hardcoded strings from first commit" rule already set | Never in this project — the constraint is explicit and enforced from day one, not a v1-only guideline |
| Testing cycle math only against "today" in the developer's local timezone | Simpler test setup | DST and cross-timezone bugs ship undetected; CI running in UTC masks the exact bug class this domain most needs to catch | Never for `core/domain` — every cycle-math test must control the input date explicitly, including DST-boundary dates |

## Integration Gotchas

Common mistakes specific to this app's "integrations" — platform SDKs and store pipelines rather than external APIs (there are no backend integrations in v1).

| Integration | Common Mistake | Correct Approach |
|-------------|-----------------|-------------------|
| `intl` package locale data | Using `DateFormat`/`NumberFormat` for a non-default locale without awaiting `initializeDateFormatting(locale)` first — throws `LocaleDataException` at runtime, often only reproducible for the non-English locale | Call and await `initializeDateFormatting()` for every supported locale during app startup, before any date/number formatting widget builds |
| App Store Connect submission pipeline | Discovering privacy-manifest or metadata rejections for the first time during the actual release submission | Run a real "Validate App"/archive-and-upload pass to a test App Store Connect record early, well before the planned release date |
| Google Play Console policy requirements | Assuming the `targetSdkVersion` set at project creation is still current at ship time | Re-check the Play Console target API level requirement against the actual planned submission date each time release is scheduled, not just once at project start |
| CocoaPods / native plugin builds on macOS | Assuming plugin native builds (Drift's `sqlite3_flutter_libs`, `path_provider`, etc.) work identically across Xcode/CocoaPods versions without a clean build check | Verify a clean `pod install` + release-mode build on the actual release Xcode/CocoaPods version, not just debug-mode incremental builds |

## Performance Traps

Patterns that work with a handful of test regimens but degrade as a user's real stack (or the Cycles/Year views' date ranges) grows.

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|-----------------|
| One Drift stream subscription per row in a `ListView` (e.g., one `watch()` per visible dose or per visible regimen bar) instead of one stream for the whole visible range | Janky scrolling in Cycles/Year views, excessive rebuild counts, growing subscription count in Riverpod devtools | Merge into a single `Stream<List<...>>` per screen/date-range (one query returning all rows needed for the visible window) and derive per-item widgets from that one list in memory | Becomes visible once a user has more than a handful of supplements/regimens — Cycles view already spans ~4 months and Year view spans 12 months of computed cells, so this matters from v1, not just at scale |
| Building the full Gantt/Year grid as one large, ungrouped widget tree instead of lazily building only visible date cells | Frame drops opening the Cycles/Year tabs, especially on older/mid-range Android devices | Use `ListView.builder`/`SliverList`/virtualized rendering for the timeline axis so only visible weeks/months are built; keep heavy grid painting in a `CustomPainter` rather than one widget per cell | Becomes noticeable as regimen count and the ~4-month/12-month view spans are exercised with realistic data, not just 1-2 demo supplements |
| Generating (materializing) `IntakeLog` dose-occurrence rows far into the future eagerly on every app start | Slow cold start, growing table size, migration/backfill complexity when a regimen's cycle rule is edited retroactively | Generate rows for a bounded near horizon (e.g., a few weeks) plus lazily on-demand when a user browses further into Cycles/Year, and clearly define what happens to already-materialized rows when a regimen is edited (regenerate forward from edit date, never silently duplicate) | Becomes a real cost once regimens accumulate and users browse the full Year view; also directly affects migration complexity (Pitfall 2) since materialized rows must survive schema changes |
| Rebuilding the entire calendar screen on every `ref.watch` when only one date's status changed (e.g., marking a single dose taken) | Whole-day-list flicker/rebuild when tapping "mark as taken" on one row | Scope providers/selectors to the smallest unit that changed (per-dose or per-day selector) rather than watching the entire month/cycle list from every row widget | Becomes visible as soon as a day has more than a few dose rows — the mark-taken interaction is the single most frequent action in the app |

## Security Mistakes

Domain-specific concerns for an on-device health-adjacent data store (not general web/app security).

| Mistake | Risk | Prevention |
|---------|------|------------|
| Storing supplement/dosing history in an unencrypted SQLite file with no at-rest protection | On a lost/stolen unlocked device, or on a rooted/jailbroken device, another app or person can read the user's full supplement/health history | For v1 this may be an acceptable local-first trade-off, but document it as a conscious decision; consider SQLCipher or platform-provided file protection (iOS Data Protection classes) if health-data sensitivity warrants it, especially before adding notifications/widgets that could leak content on lock screen |
| Excluding the database from OS-level backup "to be safe" without realizing it removes the only backup this app will have (see Pitfall 8) | Total data loss on device replacement, framed by the developer as a "security" choice but actually a data-loss risk | Default to including the DB in standard OS backups (which are already protected by the OS's own encryption/account security) unless there's a specific compliance reason not to |
| Soft-deleted rows (`deletedAt`) never actually purged, retaining full supplement/dose history indefinitely even after a user "deletes" a supplement | Growing on-device dataset that outlives the user's intent to remove it; matters if/when export or a future backend sync surfaces "deleted" data unexpectedly | Define a retention/purge policy for soft-deleted rows even in v1 (e.g., hard-delete after N days, or exclude soft-deleted rows from any future export) so "delete" behaves the way the user expects locally, independent of the sync-readiness rationale for having soft deletes at all |

## UX Pitfalls

| Pitfall | User Impact | Better Approach |
|---------|-------------|-------------------|
| Guilt-based streak/compliance framing (red X, broken-streak shaming) for missed doses | Documented pattern in habit-tracker research: guilt-inducing mechanics drive abandonment; users disengage rather than re-engage after a missed dose | Present missed/skipped doses neutrally (the mockup's calm/warn/risk palette should communicate load, not moral failure); make catching up frictionless, no punitive reset language |
| Fixed-width text containers that truncate or wrap awkwardly once translated into Ukrainian (typically 15-25% longer than English for UI labels) | Clipped labels, ugly wraps, or truncated cycle descriptions ("Т27–44 · цикл 2/2" style strings) in the language the app is Ukrainian-first for | Already a stated constraint (no fixed-width text containers); verify it in practice by reviewing every screen in Ukrainian specifically, not just English, since uk is the primary/first-tested language per the mockup |
| Cycle notation ("Т27–44 · цикл 2/2") assumed self-explanatory without the user having internalized ISO week numbering | Users unfamiliar with ISO week numbers may not understand what "Т27" means relative to "this week" | Pair week-number notation with a relative/date anchor somewhere in the same view (e.g., date range or "starts in 3 days") so the notation is decodable without prior ISO-week knowledge |
| Copy that reads as safety/efficacy guidance (see Pitfall 7) drifting in from casual UI text added late in a phase, outside the initial mockup-derived copy | Erodes both App Store review safety (Pitfall 7) and user trust if the app appears to make claims it doesn't substantiate | Treat the mockup's approved vocabulary (цикл, перерва, слот, прийнято, одночасно, "educational material, not medical advice") as the copy contract for any new string, not just a one-time reference |

## "Looks Done But Isn't" Checklist

- [ ] **Cycle math:** Often correct for arbitrary "today" in the developer's timezone, but untested across a DST transition or year boundary — verify unit tests explicitly cover DST-transition dates and Dec 31 → Jan 1 / week-52/53 rollovers.
- [ ] **Drift migrations:** Often "working" only because the emulator/simulator was reinstalled fresh between test runs (so `onCreate` ran, not `onUpgrade`) — verify by installing an older build, adding data, then installing the upgraded build over it without uninstalling.
- [ ] **Locale switching:** Often tested only via cold start with the device set to the target locale — verify the in-app language picker works for a live switch mid-session (all open screens' text updates, `intl` date formatting updates, no `LocaleDataException`).
- [ ] **Ukrainian plurals:** Often verified only for count "1" — verify counts 2, 5, 11, 21, 22, 25 render the correct CLDR-required form (`few`/`many`/`other` boundary and the 11–14 exception).
- [ ] **iOS release readiness:** Often assumed fine because debug builds run on a device — verify an actual App Store Connect "Validate App"/upload pass succeeds (privacy manifest, bundle ID, target SDK) well before the intended release date.
- [ ] **Android release readiness:** Often assumed fine because `flutter build apk` succeeds locally — verify `targetSdkVersion` meets the current Google Play policy requirement for the actual planned submission date.
- [ ] **Repository boundary:** Often "mostly" respected but with one or two screens querying Drift DAOs directly for convenience — verify no widget/provider imports `core/db` directly outside the repository implementations.
- [ ] **Data backup:** Often assumed "fine, it's local-first by design" without checking whether `allowBackup`/backup-exclusion flags were set (possibly by a boilerplate template) to something that actually removes the OS-level safety net.

## Recovery Strategies

| Pitfall | Recovery Cost | Recovery Steps |
|---------|----------------|------------------|
| DST bug found in shipped cycle math | MEDIUM | Domain logic is pure/pluggable per architecture (repository pattern, pure `core/domain` functions) — patch the pure function, add the missing DST-boundary test case, ship a patch release; no schema change needed since cycle rules are stored as parameters, not precomputed dates |
| Destructive migration already shipped, users lost data | HIGH | No true recovery for already-lost data; damage control is a patch release with a corrected migration path plus, going forward, adopting the schema-snapshot/migration-test discipline retroactively for all future changes |
| Missing iOS privacy manifest discovered at submission | LOW–MEDIUM | Identify the flagged SDK/plugin via the ITMS error, add or update to a version with a compliant manifest, or add the app-level manifest declaring the required-reason API usage; re-submit — typically a 1-2 day fix, not an architecture change |
| Android targetSdk deadline missed | LOW | Bump `targetSdkVersion`/`compileSdkVersion`, resolve any resulting Android 16 behavior-change breakages (permissions, background execution changes), re-test, re-submit; mechanical but requires a real device/OS-version regression pass |
| App Store rejects for "medical app" classification | MEDIUM | Revise flagged copy to remove implied clinical claims, strengthen "educational, not medical advice" disclaimer visibility, respond to the reviewer with the specific wording change; typically resolvable within the same review cycle without an architecture change |
| Riverpod provider leak/rebuild loop found post-release | LOW–MEDIUM | Isolated to the specific provider's `autoDispose`/`keepAlive` configuration; fix and ship a patch — does not require broader architectural change if the repository boundary was respected |

## Pitfall-to-Phase Mapping

How roadmap phases should address these pitfalls.

| Pitfall | Prevention Phase | Verification |
|---------|-------------------|----------------|
| DST/timezone cycle-math bugs | Domain/cycle-math phase (`core/domain`) | Unit tests explicitly parametrized over DST-transition dates and year/week-52-53 boundaries; no `DateTime.now()` inside domain functions |
| Destructive/untested Drift migrations | Database/Drift setup phase | Schema-export tooling wired in from the first migration; a migration test that seeds data at an old schema version and asserts survival after upgrade |
| Riverpod autoDispose/lifecycle mistakes | Repository-to-Riverpod wiring phase (and re-checked in Calendar tab phase) | A documented per-provider autoDispose policy; devtools check that switching Today/Cycles/Year tabs doesn't cause repeated stream re-subscription |
| Ukrainian ICU plural mishandling / nested-plural gap | i18n/l10n setup phase, re-checked in Stack and Calendar phases | Every ARB `plural` block reviewed for all four uk forms; UI-copy review specifically tests counts 1, 2, 5, 11 |
| Missing iOS privacy manifest | Incrementally in any phase adding native plugins; hard-gated in release-prep phase | A real App Store Connect validate/upload pass completed before the intended release date, not just before submission day |
| Android targetSdk 36 deadline | Release-prep phase, re-verified immediately pre-submission | Play Console target API level check against the actual planned ship date |
| Health-app review / medical-advice copy scrutiny | UI-copy phases (Stack, Calendar) and release-prep (store metadata) | Every dosing/cycle-guidance screen and the store listing text reviewed against the "educational, not medical advice" convention |
| No backup path for local-only data | Database setup phase (verify default backup inclusion); flagged as fast-follow milestone | Confirm `allowBackup`/backup-exclusion flags left at OS defaults; roadmap includes an export/import milestone soon after v1 |
| Calendar/Gantt performance at realistic data volume | Calendar tab phase (Today/Cycles/Year) | Manual test with a realistic stack (10+ supplements, mixed cyclic/continuous regimens) rendered across the full 4-month/12-month view, on a mid-range Android device, checking for dropped frames |
| Dose-occurrence materialization/backfill consistency | Domain phase (generation rules) and Database phase (regeneration on regimen edit) | Test editing a regimen's cycle rule after doses are already materialized; verify forward regeneration doesn't duplicate or orphan past `IntakeLog` rows |

## Sources

- [Migrations - Drift!](https://drift.simonbinder.eu/migrations/) — official Drift docs (HIGH)
- [Stream queries - Drift!](https://drift.simonbinder.eu/dart_api/streams/) — official Drift docs (HIGH)
- [question about stream queries performance in ListView · Issue #574 · simolus3/drift](https://github.com/simolus3/drift/issues/574) — maintainer/community discussion (MEDIUM)
- [Automatic disposal | Riverpod](https://riverpod.dev/docs/concepts2/auto_dispose) — official Riverpod docs (HIGH)
- [AutoDisposeStreamProvider rebuilds the widget tree and reinvoces itself endlessly · rrousselGit/riverpod · Discussion #1078](https://github.com/rrousselGit/riverpod/discussions/1078) — maintainer/community discussion (MEDIUM)
- [Add support for multiple/nested plurals and selects in gen_l10n tool · Issue #86906 · flutter/flutter](https://github.com/flutter/flutter/issues/86906) — official Flutter issue tracker (HIGH for confirming the limitation exists)
- [Unicode CLDR Plural Rules 2026: Categories, Examples & ICU](https://intlpull.com/blog/cldr-plural-rules-complete-guide-2026) — third-party summary of CLDR rules (MEDIUM)
- [DateTime - Add/Subtract - Around Daylight Savings Time Change · Issue #138069 · flutter/flutter](https://github.com/flutter/flutter/issues/138069) — official Flutter issue tracker (HIGH)
- [DateTime and Daylight Saving Time in Dart | Pinch.nl](https://medium.com/pinch-nl/datetime-and-daylight-saving-time-in-dart-9c9468633b5d) — practitioner write-up (MEDIUM)
- [DateFormat Crash - Locale data has not been initialized · Issue #15741 · flutter/flutter](https://github.com/flutter/flutter/issues/15741) — official Flutter issue tracker (HIGH)
- [App Review Guidelines - Apple Developer](https://developer.apple.com/app-store/review/guidelines/) — official Apple policy (HIGH)
- [Clarification needed: wellness-only app flagged as medical (Guideline 1.4.1) - Apple Developer Forums](https://developer.apple.com/forums/thread/807508) — official Apple developer forum (HIGH for policy application context)
- [Privacy manifest (PrivacyInfo.xcprivacy): what Apple actually requires — Vedran Burojevic](https://vburojevic.dev/blog/ios-privacy-manifest-requirements/) — practitioner write-up (MEDIUM)
- [[Bug]: ITMS-91061 Missing iOS privacy manifest via transitive dependency · Issue #3749 · fluttercommunity/plus_plugins](https://github.com/fluttercommunity/plus_plugins/issues/3749) — official Flutter community plugin issue tracker (HIGH for confirming the failure mode)
- [Target API level requirements for Google Play apps - Play Console Help](https://support.google.com/googleplay/android-developer/answer/11926878) — official Google Play policy (HIGH)
- [I Tested 10 Habit Trackers in 30 Days. 8 Broke Me the Same Way. — Medium](https://medium.com/@wardtylerd/i-tested-10-habit-trackers-in-30-days-8-broke-me-the-same-way-9803ea20b228) — practitioner/anecdotal (LOW-MEDIUM, used only for UX-pitfalls framing, not as authoritative)
- [Why Local-First Software Is the Future and its Limitations — RxDB](https://rxdb.info/articles/local-first-future.html) — practitioner/vendor write-up (MEDIUM)
- Project-internal: `/Users/dima/supplements/.planning/PROJECT.md` and `/Users/dima/supplements/docs/superpowers/specs/2026-08-14-vitomy-v1-design.md` (already-decided constraints referenced throughout, e.g. UTC date normalization, repository pattern, i18n rules)

---
*Pitfalls research for: local-first Flutter supplement tracker with cyclic scheduling and i18n*
*Researched: 2026-08-14*
