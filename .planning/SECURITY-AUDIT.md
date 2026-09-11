---
audit: v1 pre-release security and privacy
scope: whole codebase (lib/, android/, ios/, pubspec)
asvs_level: 1
block_on: high
threats_registered: 80
threats_open: 2
verdict: OPEN_THREATS
date: 2026-08-16
---

# VitoMy v1 — Security and Privacy Audit

Retroactive audit of the whole v1 codebase against the STRIDE registers declared
across all five phase plans, plus six directed checks (offline claim, data at
rest, injection, tampered local state, privacy/logging, platform config).

**Verdict: OPEN_THREATS — 2 blocking.** Both are release-mechanics gaps, not
application-logic flaws. The application code itself is clean: no network
surface, no raw SQL, no logging of personal data, no telemetry.

---

## Offline claim: PROVEN

The "fully offline, local-only" claim holds. Evidence, each independently
verified by source read rather than by documentation:

| Claim | Evidence |
|-------|----------|
| No network code in the app | `grep -rE "dart:io\|dart:html\|package:http\|HttpClient\|Socket\|WebSocket\|http://\|https://\|InternetAddress\|Uri\." lib --include='*.dart'` → **zero matches** outside generated l10n |
| No telemetry / analytics / crash SDK | `grep -rniE "analytics\|telemetry\|sentry\|crashlytics\|firebase\|amplitude\|mixpanel\|posthog" lib android/app/src ios/Runner pubspec.yaml` → **zero matches** |
| No network permission in the shipped Android app | `android/app/src/main/AndroidManifest.xml` declares **no `uses-permission` at all**. `INTERNET` appears only in `src/debug/` and `src/profile/` manifests (Flutter template; merged into debug/profile variants only, never release) |
| No network-capable dependency | 16 direct deps in `pubspec.lock`: drift, drift_flutter, path_provider, shared_preferences, uuid, flutter_riverpod, intl, cupertino_icons, flutter_localizations + 7 dev. No HTTP client, no socket package. `shelf`/`web_socket_channel`/`http_parser` are present only transitively under `build_runner`/`test`/`flutter_driver` (dev toolchain, not linked into the app) |
| No native network code | `ios/Runner/AppDelegate.swift`, `SceneDelegate.swift`, `android/.../MainActivity.kt` are unmodified templates. Only registered plugins: `shared_preferences_*`, `path_provider_*`, `jni`/`jni_flutter` (sqlite3 FFI), `integration_test` (dev — see F-3) |
| iOS ATS not weakened | `ios/Runner/Info.plist` contains **no `NSAppTransportSecurity` key** — secure defaults stand |
| Android cleartext not enabled | No `android:usesCleartextTraffic`, no `networkSecurityConfig`. targetSdk 36 ⇒ cleartext off by default |

**Residual caveat:** the claim is proven for *today's* tree, but there is **no
automated regression gate** that keeps it true (see F-8). Threat T-01-02 declared
"automated grep gate" as its mitigation; that gate exists nowhere in `test/`.

---

## Findings by severity

### HIGH — blocking

**F-1 — Release builds are signed with the debug keystore.**
`android/app/build.gradle.kts:36`

```kotlin
release {
    // TODO: Add your own signing config for the release build.
    signingConfig = signingConfigs.getByName("debug")
}
```

The Android debug keystore is a well-known, publicly-distributed key (alias
`androiddebugkey`, password `android`). Anything built through this config can
be re-signed by anyone, which defeats APK update integrity and lets a third
party publish a "same app" that Android will accept as an in-place update for
sideloaded installs. Play Store rejects debug-signed uploads, so this cannot
reach Play — but it can reach a direct/sideload distribution, and it is a
release blocker either way. **Not present in any phase threat register** — this
is new attack surface with no threat mapping.

*Fix:* create a real release `signingConfig` backed by a keystore held outside
the repo (and confirm `android/local.properties` / keystore paths stay
gitignored — currently clean, nothing secret is tracked).

**F-2 — RESOLVED after this audit was written (see correction below). Originally: T-05-10 has no mitigating evidence (declared blocking human check, not run).**

> **CORRECTION (orchestrator, 2026-08-16):** this finding is STALE. The cold-start backstop WAS subsequently closed with real device evidence, recorded in `.planning/phases/05-localization-settings/05-UAT.md` test 3 and committed as `integration_test/l10n_device_test.dart` (`f2c5a65`), which launches through the real `app.main()` entry point. Evidence: (a) in-test, a fresh `main()` with `en` stored paints English on shell frame 1 and the loop fails if any Ukrainian frame paints first; (b) on iOS, the app itself wrote `flutter.app_locale => en` to its plist, then a rebuilt real app installed and launched → English, with a wiped-container control → Ukrainian; (c) on Android, a real picker tap wrote `flutter.app_locale=uk`, `am force-stop` confirmed the process gone via `ps -A`, and relaunch → Ukrainian, with the `en` direction also proven. T-05-10 is MITIGATED. Remaining honest gap: physical hardware was not used (simulator + emulator only).
`.planning/phases/05-localization-settings/05-VERIFICATION.md:178, 237, 346`

Phase 5 introduced an async `main()` that resolves `SharedPreferences` before
`runApp()`. `lib/main.dart:17-35` guards it with try/catch and degrades to
"follow system", which is the right shape — but the phase's own verification
document states the physical-device cold-start backstop (P3 / Backstop 15) was
**not run**, and says explicitly: *"If skipped, threat T-05-10 has no mitigating
evidence."* `integration_test/data03_loop_test.dart` cannot substitute — it
pumps `VitomyApp` directly and never calls `main()`. A failure here is a
deterministic launch hang, not a degraded feature.

*Fix:* run P2/Backstop 14 and P3/Backstop 15 on a physical iOS and a physical
Android device and record the result before shipping.

### MEDIUM — non-blocking (tracked)

**F-3 — `integration_test` plugin is registered in the checked-in plugin registrants.**
`android/app/src/main/java/io/flutter/plugins/GeneratedPluginRegistrant.java:20`,
`ios/Runner/GeneratedPluginRegistrant.m:22`

Both registrants currently register `IntegrationTestPlugin`, which comes from a
`dev_dependency`. Flutter regenerates these at build time and excludes dev
dependencies from release builds, so the release artifact is *expected* to be
clean — but the committed state does not prove it. This is a test-harness
surface that must not ship.

*Fix:* build a release artifact and confirm `IntegrationTestPlugin` is absent
(`unzip -p app-release.apk classes*.dex | strings | grep -i integrationtest`,
and the equivalent for the IPA).

**F-4 — Tampered database rows are not validated in release builds.**
`lib/core/domain/models.dart:37-40, 85-86`; `lib/core/db/drift_repositories.dart:241-245`

Threat T-01-04 declares range validation on `DoseSlot.minutesFromMidnight`
(0..1439) and `Regimen.onDays/offDays` (>= 0). The validation exists — but it is
implemented with `assert()`, which **Dart strips from release builds**.
`_groupRows` constructs `domain.DoseSlot` straight from a database row with no
other check, so a tampered or corrupt row (rooted device, edited backup,
restored-from-backup inconsistency) reaches cycle math unvalidated in release.
Same pattern applies to the `dayDosesProvider` key backstop (T-03-03,
`lib/core/providers.dart:110`) and the progress-ring constructor (T-03-09).

The asymmetry is notable: tampered **shared_preferences** *is* properly
validated and tested (`lib/core/l10n/locale_controller.dart:60-71`; type check
plus an allowlist derived from the generated locale list;
`test/l10n/locale_controller_test.dart:197` feeds `7`, `true`, `3.5`,
`['uk']`). Tampered **database rows** get no equivalent treatment.

*Fix (post-v1 acceptable):* clamp or reject out-of-range values at the
repository read boundary, where the untrusted-storage boundary actually is.

**F-5 — No recovery path or test for a corrupted database file.**
`lib/core/db/database.dart:118`; `lib/core/providers.dart:37-41`

`grep -rniE "corrupt|SqliteException|DatabaseCorrupt" lib test integration_test`
finds **nothing in `lib/`**. A corrupt `vitomy.sqlite` (the realistic vector is
a restored Android Auto Backup captured mid-write, since the DB is backed up by
design and no `BackupAgent` quiesces it) surfaces as a stream error. The three
error arms then render "could not load" + Retry — forever, with no reset path.
The app has no `MigrationStrategy`, so a tampered `user_version` also throws on
open. Behaviour is fail-safe (no crash, no data leak) but the user is stuck.

Related: a tampered `IntakeLogs.status` int outside the enum range raises a
`RangeError` from drift's `intEnum` read on the same path.

*Fix:* decide and document a recovery story (detect corruption on open → offer
a "start fresh" path), and add a regression test that opens a deliberately
truncated file.

**F-6 — No store privacy disclosure prepared for the deliberate backup decision.**
`ios/Runner/` has no `PrivacyInfo.xcprivacy`; no Play Data-safety draft in repo.

The DATA-02 decision (data *should* ride OS backups so it survives reinstall) is
implemented correctly and is defensible — see the assessment below — but it is
the half that requires disclosure. Health-adjacent data (which supplements a
named person takes, and when) leaves the device inside the user's Google/Apple
backup. Both stores require this to be declared.

*Fix:* prepare the Play Data-safety form and the App Store App Privacy answers,
and add an app-level `PrivacyInfo.xcprivacy` (the app collects nothing; the
plugins ship their own manifests, so this is a declaration, not a code change).

### LOW — non-blocking

**F-7 — No length limit on any free-text field.**
`lib/features/stack/add_supplement_sheet.dart:271, 406, 413`;
`lib/features/stack/regimen_editor_screen.dart:642`

No `maxLength`, no `inputFormatters` on supplement name, dose text, or dose
label. A pasted multi-megabyte string is persisted and then flows into every
render, every semantics label, and the gantt layout on every subsequent launch.
Single-user local app, so this is self-inflicted only — but it is unbounded
untrusted input reaching persistence.

**F-8 — The platform-config invariants have no regression gate.**
Threats T-01-02 and T-01-10 both declare "automated grep gate" as their
mitigation. `grep -rniE "INTERNET|allowBackup|NSURLIsExcludedFromBackup" test/`
returns **nothing**. The gates were one-shot plan-execution checks, not committed
tests. The source-level gate pattern *is* used elsewhere and works well
(`test/l10n/no_hardcoded_strings_test.dart`,
`test/features/planner_invariants_test.dart` read and scan real source files) —
it was simply never applied to `android/` and `ios/`.

*Fix:* one test file that asserts the release manifest has no `uses-permission`,
that `pubspec.yaml` gains no networking package, and that no
`allowBackup="false"` / `NSURLIsExcludedFromBackupKey` appears.

**F-9 — App content is not excluded from screenshots or task-switcher snapshots.**
No `FLAG_SECURE`, no `excludeFromRecents`, no iOS snapshot blur. Supplement
names are visible in the OS app switcher and in any screenshot. Reasonable
default for this product; listed so it is a decision rather than an oversight.

**F-10 — Two end-of-life packages sit in the transitive graph.**
`pubspec.lock`: `sqlcipher_flutter_libs 0.7.0+eol`, `sqlite3_flutter_libs
0.6.0+eol`. Both are the author's deliberate EOL placeholders (drift 2.32+ bundles
SQLite via native build hooks); neither appears in
`.flutter-plugins-dependencies`, so neither contributes native code. Informational —
but `sqlcipher_flutter_libs` in the graph should not be mistaken for
encryption-at-rest being present. It is not (T-01-11, accepted).

**F-11 — Placeholder identity not yet resolved.** `applicationId = "app.vitomy"`
(`android/app/build.gradle.kts:19`) and `PRODUCT_BUNDLE_IDENTIFIER = app.vitomy`
(`ios/Runner.xcodeproj/project.pbxproj:387`). Known and tracked in CLAUDE.md
constraints; repeated here because it is irreversible after first store release.

**F-12 — SQLite foreign keys are not enforced.** No `PRAGMA foreign_keys = ON`
anywhere; drift does not enable it by default. The `.references()` clauses in
`lib/core/db/database.dart` are therefore declarative only. Integrity, not
security — and the soft-delete-everywhere design means nothing currently relies
on cascade enforcement.

---

## Directed check results

### 1. Offline — PROVEN
See the evidence table above.

### 2. Data at rest — appropriate location, backup decision defensible with disclosure

`lib/core/db/database.dart:118` → `driftDatabase(name: 'vitomy')` →
`drift_flutter` resolves `<getApplicationDocumentsDirectory()>/vitomy.sqlite`.

- **iOS:** app `Documents/`. Verified **not** user-exposed: `Info.plist` sets
  neither `UIFileSharingEnabled` nor `LSSupportsOpeningDocumentsInPlace`, so the
  file is invisible to the Files app and to iTunes file sharing. Protected by
  the default `NSFileProtectionCompleteUntilFirstUserAuthentication`.
- **Android:** internal app data (`app_flutter/`), not external storage — not
  readable by other apps.
- **Temp files:** `drift_flutter` points `sqlite3.tempDirectory` at the app cache
  dir, so scratch files stay inside the sandbox.
- **Encryption at rest:** none (T-01-11, explicitly accepted for v1). Both
  platforms provide full-disk encryption tied to the device passcode, which is
  the meaningful control for a local-only app with no accounts.

**On the deliberate "include in OS backups" decision (DATA-02):** implemented
exactly as worded — no `android:allowBackup="false"`, no
`NSURLIsExcludedFromBackupKey` anywhere. What it exposes:

- **Android:** Auto Backup to the user's Google Drive. Since Android 9 this is
  end-to-end encrypted with a key derived from the device screen-lock secret, so
  Google cannot read it. Low exposure.
- **iOS:** iCloud Backup, encrypted at rest with Apple-held keys unless the user
  has enabled Advanced Data Protection. So on iOS, supplement history is
  readable by Apple (and by anyone who compels Apple) for most users. Higher
  exposure than the Android side.

**Assessment: defensible.** Losing a complete supplement history on device
replacement is a real product failure, the alternative (opt out of backups with
no export and no sync) is worse for the user, and the data is low-sensitivity
relative to the convenience gained. The decision is *not* complete, though: it
needs the store privacy disclosures (F-6), and it carries an unhandled failure
mode — a live-DB backup can restore inconsistently, and there is no corruption
recovery (F-5). Backup inclusion is currently **implicit** (relying on the
Android default of `allowBackup=true` and the absence of exclusions). Consider
making it explicit with `android:allowBackup="true"` plus an
`android:dataExtractionRules` file, so a future template regeneration cannot
silently reverse a deliberate decision.

### 3. Injection and untrusted input — CLEAN

- `grep -rE "customStatement|customSelect|customUpdate|customInsert|rawQuery" lib`
  → **zero matches**. No raw SQL anywhere.
- Every query in `lib/core/db/drift_repositories.dart` (431 lines) uses drift's
  typed builder — `db.select(...)..where((t) => t.id.equals(x))`,
  `insertOnConflictUpdate(...Companion(...))`, `batch(...insertAll(..., mode:
  InsertMode.insertOrIgnore))`. All values bind as parameters.
- **Semantics labels:** user text reaches `Semantics(label:)` (e.g.
  `lib/features/calendar/dose_row.dart:233` `dose.supplement.note`,
  `lib/features/calendar/planner_gantt.dart:440`). Labels are plain Dart strings
  with no markup interpreter behind them — no injection surface.
- **ARB interpolation:** gen-l10n compiles placeholders to plain Dart string
  interpolation at build time — `lib/core/l10n/gen/app_localizations_uk.dart:663`
  is literally `return '$name, $schedule, $periods';`. User text is a value, never
  a format string. No ICU re-parsing of user input.
- **Search:** `lib/features/stack/catalog.dart:167-176` uses
  `String.contains` on a trimmed, lowercased query. `grep -rn "RegExp(" lib` →
  **zero matches**, so no ReDoS surface.

Only gap: unbounded input length (F-7).

### 4. Tampered local state — partially covered

| Vector | Status |
|--------|--------|
| Tampered `app_locale` value (wrong type) | **Covered.** `locale_controller.dart:60` uses `.get()` not `.getString()` specifically to avoid an unguarded `as String?` downcast, then `stored is String ? stored : null`. Tested with `7`, `true`, `3.5`, `['uk']` at `test/l10n/locale_controller_test.dart:197` |
| Locale code that no longer exists | **Covered.** `_localesByTag` is derived from `AppLocalizations.supportedLocales`, so an unshipped code returns `null` → follow system, never reaching `lookupAppLocalizations`'s throw. Tested at `test/features/settings_screen_test.dart:461` |
| Unopenable preferences store | **Covered.** `lib/main.dart:17-35` catches, reports, and starts with `prefs = null`; `sharedPreferencesProvider` is deliberately nullable. Tested by `test/l10n/cold_start_degradation_test.dart` — which pointedly refuses to mock the store into working |
| Tampered database **row values** | **NOT covered** — F-4 (asserts stripped in release) |
| Corrupt / truncated database **file** | **NOT covered** — F-5 (no detection, no recovery, no test) |

### 5. Privacy — nothing leaves the device, nothing logged

- `grep -rE "\bprint\(|debugPrint|developer\.log" lib` → **zero real matches**
  (the only hits are `catalog(`, `AlertDialog(` substrings). No personal data is
  logged anywhere.
- `logStatements` is never enabled on the drift database, so SQL and bound
  variables are not written to the platform log.
- Two `FlutterError.reportError` call sites exist (`lib/main.dart:29`,
  `lib/core/l10n/locale_controller.dart:130`). Both report infrastructure
  failures only — a preferences plugin error and a
  `StateError('the language store rejected the write')`. Neither carries
  supplement names, doses, or intake history.
- **Error surfaces leak nothing.** All three verified by source read:
  `lib/features/stack/stack_screen.dart:122` renders `l10n.stackLoadError` +
  Retry; `lib/features/calendar/calendar_screen.dart:332` renders
  `l10n.dayLoadError` + Retry; `lib/features/calendar/planner_screen.dart:618`
  → `_PlannerError` renders `l10n.plannerLoadError` + Retry. No exception
  object, no stack trace, no SQL fragment reaches the widget tree.
  `lib/features/calendar/dose_row.dart:94` uses a bare `catch (_)` and shows the
  fixed `markFailed` copy.
- Screenshots / task-switcher: see F-9.

### 6. Platform config — clean, two gaps

| Item | Finding |
|------|---------|
| Exported components | Only `MainActivity` (`AndroidManifest.xml:8`), which must be exported to launch. No exported services, receivers, or providers. `android:taskAffinity=""` is set — this is the StrandHogg task-hijack hardening, correctly present |
| Deep links | **None.** No `VIEW` intent filter, no custom URL scheme, no `CFBundleURLTypes`, no associated domains, no iOS entitlements file at all |
| Cleartext traffic | Off by default (targetSdk 36); not overridden |
| iOS ATS | Not weakened — no `NSAppTransportSecurity` key |
| Permissions (release) | **Zero.** Only the Flutter-template `<queries>` for `ACTION_PROCESS_TEXT` |
| Backup flags | No exclusions — deliberate per DATA-02; implicit rather than explicit (see check 2) |
| Signing | **F-1 — debug keystore.** Blocker |
| Privacy manifest | **F-6 — absent.** Store-submission item |
| Debuggable / minify | `android:debuggable` correctly unset (false in release). Minify/shrink not enabled — not a security requirement, but obfuscation is cheap defence-in-depth for a local DB schema |

---

## Threat register verification

80 unique threats declared across 24 phase plans, ASVS L1, `block_on: high`.

**Verification method.** Security-material threats (injection, information
disclosure, tampering of user data, untrusted-input handling, supply chain,
platform config) were each verified by locating the actual mitigating code —
these are the ones cited with file:line above. The register also contains a
large population of design-integrity, copy-framing, and layout-robustness
threats (T-01-06, T-03-11, T-04-04/06/07/08/11/12/13/16/17/18/19/22/23/24,
T-05-08/09/11 and similar). Those were verified at ASVS-L1 depth — the declared
gate exists as a committed test (`test/l10n/planner_copy_safety_test.dart`,
`test/features/planner_invariants_test.dart`, `test/l10n/arb_parity_test.dart`,
`test/l10n/no_hardcoded_strings_test.dart`, the text-scale matrices) and the
suite is green at 693/693. They are recorded CLOSED on that basis, not on a
line-by-line trace.

**High-severity threats verified individually:**

| Threat | Disposition | Status | Evidence |
|--------|-------------|--------|----------|
| T-01-SC / T-05-SC | mitigate | CLOSED | `pubspec.lock` direct deps = exactly the 16 approved packages; no unapproved or lookalike entry |
| T-02-01 (cascade delete) | mitigate | CLOSED | `drift_repositories.dart:75-121` single transaction; `grep "db.delete(\|deleteWhere\|deleteAll("` → **no hard delete anywhere** |
| T-02-02 (pause revival) | mitigate | CLOSED | Query-level filter; `test/db/pause_filter_test.dart` |
| T-03-01 / T-03-07 (re-materialization) | mitigate | CLOSED | `drift_repositories.dart:298` `InsertMode.insertOrIgnore`; no upsert mode in `ensureLogsForDay` |
| T-03-02 (double-apply) | mitigate | CLOSED | `dose_row.dart:86-104` `_busy` re-entry guard; `next` computed from the rendered status at `:109` |
| T-03-05 / T-03-12 (unauthorized status write) | mitigate | CLOSED | `grep -rl "setStatus" lib/features` → **exactly one file**, `dose_row.dart` |
| T-03-06 / T-03-15 (divergent truth) | mitigate | CLOSED | `isActiveOn` is the single decision point, called only from `ensureLogsForDay` |
| T-04-01 / T-04-21 (planner read-only) | mitigate | CLOSED | `grep "ensureLogsForDay\|intakeRepo" lib/features/calendar/planner_*.dart` → only a comment; gated by `test/features/planner_invariants_test.dart:155-158` |
| T-05-01 (locale → lookup crash) | mitigate | CLOSED | `locale_controller.dart:60-71` allowlist derived from generated `supportedLocales` |
| T-01-09 / T-02-03 / T-02-06 (injection) | mitigate / accept | CLOSED | No raw SQL; typed builder + Companions throughout |
| T-05-10 (async main on device) | mitigate | **CLOSED** | F-2 superseded — closed by `integration_test/l10n_device_test.dart` (real `main()`) plus genuine force-stop relaunch evidence on both platforms; see the correction note above |

**Accepted risks (logged here — this file is the accepted-risks log):**

| Threat | Severity | Accepted rationale |
|--------|----------|--------------------|
| T-01-11 | low | Unencrypted SQLite at rest. ASVS L1 scope, no hand-rolled crypto; platform full-disk encryption is the control. Revisit with SQLCipher only if requirements change |
| T-02-03 / T-02-06 | low | Free-text injection — no raw SQL exists for it to reach |
| T-03-10 / T-04-05 | low | Semantics labels expose the user's own data on the user's own device; nothing leaves it |
| T-03-SC / T-04-SC | high | No package-install task in those phases; dependency delta empty. Verified: `pubspec.lock` direct set unchanged from Phase 1 |
| T-05-05 | low | Rapid picker taps — last write wins, idempotent, bounded by human tap rate |
| T-05-06 | medium | Riverpod auto-retry backoff retained; the error surface renders from frame one, so the window is no longer user-visible |
| F-9 | low | App content visible in screenshots and the task switcher — accepted for this product |
| F-10 | low | EOL transitive placeholders contribute no native code |
| F-12 | low | FK enforcement unused by the soft-delete design |

**Unregistered flags (new attack surface with no threat mapping):** F-1
(release signing), F-3 (dev plugin in registrant), F-6 (privacy disclosure),
F-7 (input length), F-9 (screenshots), F-11 (placeholder identity).

---

## Pre-release checklist

Blocking:

- [ ] **Replace the debug signing config** with a real release keystore, stored
      outside the repo (F-1)
- [ ] **Run the physical-device backstops** — P2/Backstop 14 (bilingual
      walkthrough) and P3/Backstop 15 (cold start after force-quit) on a real
      iOS device and a real Android device; record the result (F-2)

Before store submission:

- [ ] Verify `IntegrationTestPlugin` is absent from the release APK and IPA (F-3)
- [ ] Complete the Play Data-safety form and App Store App Privacy answers,
      declaring that supplement/intake data is stored locally and included in
      OS backups; add `ios/Runner/PrivacyInfo.xcprivacy` (F-6)
- [ ] Decide the final app name and bundle id; replace `app.vitomy` in
      `android/app/build.gradle.kts:19` and `ios/.../project.pbxproj` (F-11)

Recommended before v1.1:

- [ ] Validate or clamp database row values at the repository read boundary, so
      the guarantee survives release-mode assert stripping (F-4)
- [ ] Add corrupt-database detection with a user-facing recovery path, plus a
      regression test against a truncated file (F-5)
- [ ] Add `maxLength` to name, dose, and dose-label inputs (F-7)
- [ ] Add a platform-config gate test: no `uses-permission` in the release
      manifest, no networking package in `pubspec.yaml`, no backup opt-out (F-8)
- [ ] Make the backup decision explicit — `android:allowBackup="true"` plus a
      `dataExtractionRules` file — so a template regeneration cannot reverse it
- [ ] Consider enabling R8/minify with obfuscation for the release build
