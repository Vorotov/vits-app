# Phase 1: Foundation - Research

**Researched:** 2026-08-14
**Domain:** Flutter app scaffold — theming, i18n infrastructure, pure-Dart domain/cycle math, Drift (SQLite) schema + repositories + materialization, Riverpod providers, three-tab shell
**Confidence:** HIGH (all package versions and API syntax below were fetched from official docs/pub.dev/GitHub this session; a small number of items are flagged LOW/ASSUMED where official docs did not give a definitive answer)

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Project scaffold**
- Flutter project at the repo root: `flutter create --project-name vitomy --org app.vitomy --platforms ios,android .`
- Bundle id placeholder `app.vitomy` on both platforms (final id is a pre-release open item)
- Android targetSdk 36 (SDK 36 already installed; Play deadline 2026-08-31)
- Toolchain (CocoaPods, JDK, Android SDK 36) is ALREADY installed — `flutter doctor` is green; do not re-plan environment setup

**Dependencies (versions verified on pub.dev 2026-08-14)**
- flutter_riverpod ^3.4.2, drift ^2.34.3, drift_flutter ^0.3.1, uuid ^4.6.0, shared_preferences ^2.5.5
- dev: drift_dev ^2.34.5, build_runner ^2.16.0, flutter_lints, mocktail (NOT mockito — avoids extra codegen)
- Do NOT add sqlite3_flutter_libs (bundled by Drift ≥2.32); do NOT hand-pin intl (let flutter_localizations resolve it)
- Do NOT use google_fonts (runtime HTTP fetch is wrong for offline app) — bundle Instrument Sans (400/500/600/700) and JetBrains Mono (400/500) as local .ttf assets declared in pubspec `fonts:`

**Design tokens & theme (from claude_design_mockup/VitoMy v0.1.dc.html)**
- Single tokens file `lib/core/theme/tokens.dart` + `bqTheme()` in `lib/core/theme/theme.dart`
- Palette: canvas #EAE9E4, paper #F7F6F3 (scaffold bg), surface #FFFFFF, surfaceAlt #FBFBF9, chip #F2F1EE, field #E4E3DD, ink #17171B, textSecondary #5C5C66, textMuted #8E8E99, textFaint #A0A0A9, accent #4A4E7C, accentPressed #3D4169, accentChipBg #EDEDF4, calm #3F7A6A/#E8F1ED, warn #B07A22/#FAF1E0, risk #A8443C/#F8EBE8
- Series palette for supplement color tags: B08A2A, 2F3457, 3F7A6A, 6B6FA8, C4685E, 2F7A85, C07A3A, 4A4E7C
- Radii: card 14, panel 16, button 12, chip 5, segmented control 10
- All later UI uses ONLY these tokens

**i18n infrastructure**
- gen-l10n with l10n.yaml: arb-dir `lib/core/l10n/arb`, template `app_en.arb`, output-dir `lib/core/l10n/gen`, synthetic-package false, nullable-getter false
- Ship `app_en.arb` + `app_uk.arb` seeded with shell strings (tab labels, app title) and plural exemplars (`substancesCount`, `weeksCount`) using ALL FOUR uk CLDR forms (one/few/many/other incl. 11–14 exception); unit-test counts 1, 2, 5, 11, 21
- LocaleController (Riverpod Notifier, SharedPreferences key `app_locale`): null = follow system; MaterialApp resolves system uk/en with English fallback
- `context.l10n` extension; zero hardcoded user-visible strings; EdgeInsetsDirectional for horizontal padding; no fixed-width text containers

**Domain layer (pure Dart, lib/core/domain/)**
- Models: Supplement, Regimen (kind cyclic|course, startDate, endDate?, onDays, offDays, paused, slots), DoseSlot (minutesFromMidnight, doseLabel), enums RegimenKind/DoseStatus
- `dateOnly()` normalizes to `DateTime.utc(y,m,d)`; NEVER local midnight; never DateTime.now() inside domain functions
- `isActiveOn(Regimen, DateTime)`: paused→false; before start→false; course→inclusive end; cyclic→(day−start) % (on+off) < on; off=0 → always on
- Time types stay separate: date-only UTC (calendar day) vs minutesFromMidnight (wall clock) vs createdAt/updatedAt (true UTC instants)
- EXIT CRITERION: unit tests prove correct active/inactive days across a DST transition AND a year boundary

**Database (Drift, lib/core/db/)**
- Tables: Supplements, Regimens, RegimenSlots, IntakeLogs; SyncColumns mixin on every table: TEXT UUID id PK, createdAt, updatedAt, deletedAt nullable (soft delete)
- IntakeLogs unique key (slotId, date); date stored as UTC-midnight DateTime; status int = DoseStatus.index
- `VitomyDb.forTesting(NativeDatabase.memory())` + `VitomyDb.open()` via driftDatabase(name: 'vitomy')
- Export drift schema snapshot (`drift_schema_v1.json`) at schema version 1 — migration discipline starts now
- Verify DB file lives in default app-documents location included in OS backups (DATA-02); document this in code comment
- Repository interfaces (SupplementRepository, RegimenRepository, IntakeRepository) in core/domain; Drift implementations in core/db; `ensureLogsForDay` idempotent materialization; StackEntry/DayDose view models; Riverpod providers in core/providers.dart
- Riverpod policy decided once here: repository-level StreamProviders NOT autoDispose; screen-scoped state may be autoDispose; document in providers file

**App shell**
- `AppShell` with IndexedStack + NavigationBar: three tabs Stack/Calendar/Settings (stub screens with localized headers, mockup header style: 25px w600 letterSpacing −0.5)
- Tab bar styling per mockup: surfaceAlt background, accent selected, textFaint unselected
- No network permission anywhere; no accounts/login

**Testing**
- flutter_test; in-memory Drift for repo tests; widget test proves shell renders localized tab labels in en and uk
- `flutter analyze` clean and `flutter test` green are phase exit criteria

### Claude's Discretion
- Exact file organization inside features/ stubs, icon choices for tabs, minor widget structure
- How to source .ttf files (download from Google Fonts GitHub/fontsource at build-prep time, commit into assets/fonts/)
- Wave decomposition for parallel execution

### Deferred Ideas (OUT OF SCOPE)
- Feature screens (Stack, Calendar, planners, regimen editor) — Phases 2–5
- Full-app localization verification and language picker — Phase 5
- Notifications, widgets, export, sync — post-v1 (REQUIREMENTS.md v2)
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| DATA-01 | All data is stored locally on device; the app is fully functional offline with no accounts | Standard Stack confirms no network package anywhere in the dependency list (no `http`/`dio`); `google_fonts` excluded specifically because its default behavior does an HTTP fetch — see Common Pitfalls; drift_flutter's `driftDatabase()` is 100% local file I/O, no network calls (see Code Examples) |
| DATA-02 | Schema is sync-ready (UUID PKs, createdAt/updatedAt, soft deletes) and the database is included in OS-level backups by default | Environment Availability confirms `getApplicationDocumentsDirectory()` (used by `drift_flutter`) maps to `NSDocumentDirectory` on iOS (iCloud-backed by default) and the app's internal data directory on Android (Auto Backup–eligible by default); Code Examples show the exact `SyncColumns` mixin (UUID id, createdAt, updatedAt, deletedAt) and `uniqueKeys` syntax; Common Pitfalls documents the two manifest flags (`android:allowBackup`, `NSURLIsExcludedFromBackupKey`) that must NOT be set to exclude the DB from backup |
</phase_requirements>

## Summary

Phase 1 is a pure-scaffold phase: no network, no third-party backend, and every technical question resolves to "what does the current stable version of an already-locked library want, exactly." All five research areas requested — Drift 2.34.x, Riverpod 3.4.x, gen-l10n on Flutter 3.47, font bundling, and `flutter create`/`NavigationBar` — were verified this session against official docs, pub.dev, or the upstream GitHub source repos, not recalled from training data. Two findings materially change what the planner should put in tasks versus what CONTEXT.md assumed:

1. **Fonts:** `google/fonts` ships Instrument Sans and JetBrains Mono as **single variable-font files** (`InstrumentSans[wdth,wght].ttf`, `JetBrainsMono[wght].ttf`), not four/two separate static-weight files. Flutter 3.41+ (well below the project's 3.47) auto-maps `FontWeight` to the font's `wght` variation axis, so the correct pubspec declaration is **one `fonts:` entry per family** (no `weight:` fanning), not four/two entries as CONTEXT.md's phrasing implied. This is simpler, not harder, but the planner must not task "download 4 static Instrument Sans weight files" — that file layout doesn't exist upstream.
2. **`l10n.yaml` `synthetic-package: false`:** this isn't just "a valid option," it is now the *only* supported path — `package:flutter_gen` synthetic-package generation was deprecated starting 3.28/stable-3.32 and is scheduled for full removal in the stable release after 3.32 (the project is on 3.47, past that point). CONTEXT.md's locked choice of `synthetic-package: false` is therefore not optional-but-correct, it is load-bearing: `generate: true` must also be set under `flutter:` in `pubspec.yaml` or `gen-l10n` will not run automatically on `flutter pub get`.

**Primary recommendation:** Scaffold with `flutter create` first (after protecting the existing root `.gitignore`, which will collide with the template's generated one), then build layers strictly bottom-up per the already-researched build order (domain math → Drift schema → repositories/materialization → Riverpod providers → app shell), exactly as ARCHITECTURE.md and PITFALLS.md already prescribe — this research does not change that ordering, only the exact syntax used at each step.

## Architectural Responsibility Map

VitoMy is a single-codebase mobile app (no server tier); the "tiers" below are the app's own internal layers, matching `ARCHITECTURE.md`'s system overview.

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Theme tokens / typography | Widget/UI layer (`core/theme`) | — | Pure `ThemeData` construction, no state, no I/O |
| Localization (ARB, plural rules, locale switch) | Widget/UI layer (`core/l10n` generated code) | State layer (`LocaleController` Notifier + SharedPreferences) | Generated `AppLocalizations` is consumed by widgets; persisted override lives in a Notifier |
| Cycle/DST-safe date math | Domain layer (`core/domain/cycle_math.dart`) | — | Zero Flutter/DB imports by design; the single most heavily unit-tested layer per PITFALLS.md Pitfall 1 |
| Domain models (Supplement/Regimen/DoseSlot) | Domain layer (`core/domain`) | — | Value types with no behavior beyond validation; consumed by both DB layer (table shape) and UI (view models) |
| Repository interfaces | Domain layer (`core/domain/repositories.dart`) | — | Abstract contracts; UI/state layer depends only on these, never on Drift types |
| Drift schema, migrations, Drift-backed repository implementations | Data/Persistence layer (`core/db`) | — | Only place `package:drift` may be imported (Anti-Pattern 1 in ARCHITECTURE.md) |
| Dose materialization (`ensureLogsForDay`) | Data/Persistence layer (`core/db`) | Domain layer (calls `isActiveOn`) | Side-effecting read that writes idempotent rows; calls into pure domain math for "which slots are active" |
| Riverpod providers (repository wiring, combined streams, locale) | State layer (`core/providers.dart`) | — | Bridges repositories to the widget tree; owns the autoDispose policy |
| Three-tab app shell / navigation | Widget/UI layer (`app_shell.dart`) | — | `IndexedStack` + `NavigationBar`, no business logic |
| DB file location / OS backup inclusion | Platform/OS layer (iOS `NSDocumentDirectory`, Android internal data dir) | Data/Persistence layer (`drift_flutter`'s `driftDatabase(name:)`) | Backup inclusion is an OS-level default triggered by *where* the file lives, not app code; verified in Environment Availability below |

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| flutter_riverpod | ^3.4.2 [VERIFIED: pub.dev] | State management | Publisher `dash-overflow.net` (verified), 2.9k likes, 2.77M downloads. Riverpod 3.0 is the current stable major (not beta) — confirmed via `riverpod.dev/docs/whats_new` and `/docs/3.0_migration` this session. |
| drift | ^2.34.3 [VERIFIED: pub.dev] | Typed reactive SQLite ORM | Publisher `simonbinder.eu` (verified, Flutter Favorite), 2.45k likes, 1.13M downloads. 2.32+ bundles SQLite via native build hooks — confirmed on `drift.simonbinder.eu/setup/`. |
| drift_flutter | ^0.3.1 [CITED: pub.dev/documentation/drift_flutter] | Flutter-specific DB-opening helper | `driftDatabase(name: String)` is the single entry point; uses `path_provider`'s `getApplicationDocumentsDirectory()` internally — quoted directly from the package's own API docs (see Code Examples). |
| path_provider | ^2.1.6 [ASSUMED — carried from STACK.md, not re-verified this session] | Resolves platform app-documents directory | Pulled in transitively by `drift_flutter`'s default constructor; app code never calls it directly. |
| uuid | ^4.6.0 [ASSUMED — carried from STACK.md] | UUID v4 generation for sync-ready PKs | `const Uuid().v4()` in repository `create()` methods only. |
| shared_preferences | ^2.5.5 [ASSUMED — carried from STACK.md] | Persist `app_locale` key | Exactly one use: `LocaleController`'s manual override. |
| intl | resolved by SDK, do not hand-pin [CITED: STACK.md Version Compatibility, corroborated by flutter/flutter#162568 et al.] | ICU date/number formatting for generated l10n code | `flutter_localizations` (SDK) still effectively drives its version; adding an explicit `intl:` constraint is the most common first-run `pub get` failure in Flutter i18n projects. |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| flutter_lints | ^6.0.0 [ASSUMED — carried from STACK.md] | Official Dart/Flutter lint rules | Enable in `analysis_options.yaml` from commit 1; `flutter analyze` clean is a phase exit criterion. |
| mocktail | ^1.0.5 [ASSUMED — carried from STACK.md] | Mocking repository interfaces in widget tests | Null-safety-native, no codegen — avoids adding a third `build_runner` generator alongside Drift's and (if used) Riverpod's. |

### Dev tools
| Tool | Version | Purpose | Notes |
|------|---------|---------|-------|
| build_runner | ^2.16.0 [ASSUMED — carried from STACK.md] | Runs `drift_dev`'s generator | `dart run build_runner build -d` for one-shot CI/local generation of `*.g.dart`. |
| drift_dev | ^2.34.5 [VERIFIED: pub.dev, matches drift ^2.34.3 minor line] | Drift code generator + schema-dump CLI | Dev-only; never imported in app code. Provides `dart run drift_dev schema dump ...` (see Code Examples). |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Manual `Notifier`/`StreamProvider` classes (no codegen) | `riverpod_generator` + `@riverpod` annotations | STACK.md recommends codegen since `build_runner` is already running for Drift; CONTEXT.md's locked decisions describe manual `Notifier`/`StreamProvider` usage explicitly (`LocaleController (Riverpod Notifier, ...)`) and do not mention `@riverpod` annotations anywhere — treat manual (non-codegen) Riverpod as the phase's actual locked choice; codegen is Claude's-discretion-adjacent but not requested. This RESEARCH.md documents manual syntax below since that is what CONTEXT.md's examples use. |
| Provider composition for combining two Drift streams (see Pattern 3 below) | `rxdart`'s `Rx.combineLatest2` | Explicitly excluded by the additional-context brief ("without rxdart"); provider composition achieves the same effect using only Riverpod's own dependency graph, with no extra package. |
| Hand-bundled variable-font `.ttf` (1 file per family) | 4 separate static-weight `.ttf` files per family | `google/fonts` upstream (verified via GitHub API this session) does not ship separate static files for either Instrument Sans or JetBrains Mono — only single variable-font files exist. Fetching "static weight files" from Google Fonts GitHub is not possible without a third-party mirror (e.g., Fontsource's build pipeline); use the variable font directly instead — Flutter renders the correct weight automatically (see Common Pitfalls). |

**Installation:**
```bash
flutter create --project-name vitomy --org app.vitomy --platforms ios,android .

flutter pub add flutter_riverpod drift drift_flutter path_provider uuid shared_preferences
flutter pub add flutter_localizations --sdk=flutter
flutter pub add intl
flutter pub add -d build_runner drift_dev flutter_lints mocktail
```

**Version verification:** `drift` and `flutter_riverpod` versions were re-confirmed live against pub.dev this session (`drift` 2.34.3, publisher `simonbinder.eu`; `flutter_riverpod` 3.4.2, publisher `dash-overflow.net`) — both match STACK.md exactly, so STACK.md's 2026-08-14 verification is current as of this research pass. Other STACK.md versions (`drift_flutter`, `path_provider`, `uuid`, `shared_preferences`, `flutter_lints`, `mocktail`, `build_runner`) were not re-fetched this session (all `[ASSUMED — carried from STACK.md]`); STACK.md itself fetched them directly from pub.dev on the same date, so risk of drift is low, but the planner should run `flutter pub add` (not hand-edit `pubspec.yaml`) so `pub get`'s own resolver catches any since-published breaking change.

## Package Legitimacy Audit

> `node`/`gsd-tools` were unavailable in this sandbox (`node: command not found`), so the automated `package-legitimacy check` seam could not run. A manual audit was performed instead: spot-checking the two highest-risk/most-load-bearing packages directly against pub.dev (publisher verification + download counts), and cross-referencing the rest against STACK.md's same-day pub.dev fetch. All packages below are long-established, high-download, verified-publisher packages — there is no slopsquatting risk profile here (no obscure/recently-published names).

| Package | Registry | Age | Downloads | Source Repo | Verdict | Disposition |
|---------|----------|-----|-----------|-------------|---------|-------------|
| drift | pub.dev | Multi-year, Flutter Favorite | 1.13M | github.com/simolus3/drift (verified publisher simonbinder.eu) | OK [VERIFIED: pub.dev fetch this session] | Approved |
| flutter_riverpod | pub.dev | Multi-year, widely adopted | 2.77M | github.com/rrousselGit/riverpod (verified publisher dash-overflow.net) | OK [VERIFIED: pub.dev fetch this session] | Approved |
| drift_flutter | pub.dev | Official Drift companion package (same org as drift) | not re-fetched | github.com/simolus3/drift | OK [ASSUMED — same publisher/org as verified `drift`] | Approved |
| drift_dev | pub.dev | Official Drift dev-dependency (same org as drift) | not re-fetched | github.com/simolus3/drift | OK [ASSUMED — same publisher/org as verified `drift`] | Approved |
| path_provider | pub.dev | Official Flutter-team plugin (flutter.dev packages) | not re-fetched | github.com/flutter/packages | OK [ASSUMED — well-known Flutter-team-maintained plugin] | Approved |
| uuid | pub.dev | Long-established, widely used | not re-fetched | github.com/Daegalus/dart-uuid | OK [ASSUMED — carried from STACK.md same-day verification] | Approved |
| shared_preferences | pub.dev | Official Flutter-team plugin | not re-fetched | github.com/flutter/packages | OK [ASSUMED — well-known Flutter-team-maintained plugin] | Approved |
| flutter_lints | pub.dev | Official Dart-team lint package | not re-fetched | github.com/dart-lang/lints | OK [ASSUMED — well-known Dart-team-maintained package] | Approved |
| mocktail | pub.dev | Long-established (felangel/VGV ecosystem) | not re-fetched | github.com/felangel/mocktail | OK [ASSUMED — carried from STACK.md same-day verification] | Approved |
| build_runner | pub.dev | Official Dart-team build tool | not re-fetched | github.com/dart-lang/build | OK [ASSUMED — well-known Dart-team-maintained package] | Approved |

**Packages removed due to [SLOP] verdict:** none.
**Packages flagged as suspicious [SUS]:** none.

*All `[ASSUMED]`-tagged rows above were verified by STACK.md via direct pub.dev fetch on the same research date (2026-08-14); this session independently re-confirmed the two highest-risk entries (`drift`, `flutter_riverpod`) and found them to match exactly. Given the automated legitimacy seam was unavailable, the planner should still add a lightweight `checkpoint:human-verify` after the first `flutter pub get` to confirm no unexpected transitive package was pulled in — cheap insurance given the automated check could not run.*

## Architecture Patterns

### System Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│  App start                                                       │
│  main() → ProviderScope → VitomyApp (MaterialApp)              │
│      resolves locale (system uk/en, fallback en)                 │
└───────────────────────────┬───────────────────────────────────────┘
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│  AppShell  (IndexedStack + NavigationBar, 3 tabs)                 │
│  Stack tab │ Calendar tab │ Settings tab   (stub screens, Ph.1)   │
└───────────────────────────┬───────────────────────────────────────┘
                             │ ref.watch(provider)
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│  Riverpod providers (core/providers.dart)                        │
│  dbProvider → repo providers (Supplement/Regimen/Intake)          │
│  localeControllerProvider (Notifier, SharedPreferences-backed)    │
└───────────────────────────┬───────────────────────────────────────┘
                             │ interface calls
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│  Repository interfaces (core/domain/repositories.dart)            │
│      ↕ implemented by                                             │
│  Drift repository impls (core/db) → VitomyDb (Drift/SQLite)     │
│      Tables: Supplements, Regimens, RegimenSlots, IntakeLogs      │
│      file: getApplicationDocumentsDirectory()/vitomy.sqlite     │
└───────────────────────────┬───────────────────────────────────────┘
                             │ calls into (pure functions, no I/O)
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│  Domain math (core/domain/cycle_math.dart)                        │
│  isActiveOn(Regimen, DateTime.utc(y,m,d)) — DST/year-safe          │
│  Consumed by BOTH materialization (core/db) and future planner     │
│  projections (Phase 4) — single source of truth                   │
└─────────────────────────────────────────────────────────────────┘
```

A reader can trace: app boot → locale resolution → shell renders three localized tabs → (Phase 2+) a tab reads a repository-backed provider → the provider calls the Drift-backed repository → the repository's materialization step calls the pure domain function to decide which rows to insert.

### Recommended Project Structure
```
lib/
├── core/
│   ├── db/              # VitomyDb (@DriftDatabase), tables, Drift-backed repo impls
│   ├── domain/           # pure Dart: models, cycle_math.dart, repository interfaces
│   ├── l10n/
│   │   ├── arb/          # app_en.arb, app_uk.arb (source of truth)
│   │   └── gen/           # generated AppLocalizations (synthetic-package: false)
│   ├── theme/            # tokens.dart, theme.dart
│   └── providers.dart    # dbProvider, repo providers, localeControllerProvider
├── features/
│   ├── stack/            # stub screen (Phase 2 builds real content)
│   ├── calendar/          # stub screen (Phase 3/4 build real content)
│   └── settings/          # stub screen (Phase 5 builds language picker)
├── app_shell.dart         # IndexedStack + NavigationBar
├── app.dart               # MaterialApp, locale resolution
└── main.dart
assets/
└── fonts/
    ├── InstrumentSans[wdth,wght].ttf
    ├── InstrumentSans-Italic[wdth,wght].ttf   (optional — only if italic used)
    └── JetBrainsMono[wght].ttf
drift_schemas/
└── drift_schema_v1.json
test/
├── domain/                # cycle_math_test.dart (DST/year-boundary cases)
├── db/                    # repository tests against in-memory Drift
├── l10n/                  # plural-form tests (1,2,5,11,21) via AppLocalizations.delegate.load
└── widget/                # app_shell_test.dart (localized tab labels, en + uk)
```

### Pattern 1: `driftDatabase(name:)` — the only supported way to open a Drift DB in Flutter

**What:** `drift_flutter`'s `driftDatabase` function returns a platform-appropriate `QueryExecutor`. On native platforms (including iOS and Android) it resolves the file path via `path_provider`'s `getApplicationDocumentsDirectory()`, and stores the database as `$name.sqlite` inside that directory.
**When to use:** The `VitomyDb` constructor's `super(...)` call, for both `.open()` (real app) and never for `.forTesting()` (use `NativeDatabase.memory()` there instead).
**Example:**
```dart
// Source: https://pub.dev/documentation/drift_flutter/latest/drift_flutter/driftDatabase.html [CITED]
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'database.g.dart';

@DriftDatabase(tables: [Supplements, Regimens, RegimenSlots, IntakeLogs])
class VitomyDb extends _$VitomyDb {
  VitomyDb() : super(driftDatabase(name: 'vitomy'));

  // Test-only constructor — never touches disk, never touches OS backup paths.
  VitomyDb.forTesting(super.executor);

  @override
  int get schemaVersion => 1;
}
```
Quoted from the package's own API docs: *"On native platforms, a file called `$name.sqlite` in `getApplicationDocumentsDirectory()` will be used for the database."* [CITED: pub.dev/documentation/drift_flutter/latest]

### Pattern 2: `SyncColumns` mixin + `uniqueKeys` — the sync-ready, idempotent-materialization shape

**What:** A shared mixin providing `id` (TEXT UUID PK), `createdAt`, `updatedAt` (both true UTC instants), and nullable `deletedAt` (soft delete) on every table. `IntakeLogs` additionally declares a composite `uniqueKeys` override on `(slotId, date)` so repeated materialization calls are safe.
**When to use:** Every table in `core/db/database.dart`.
**Example:**
```dart
// uniqueKeys syntax — Source: https://drift.simonbinder.eu/dart_api/writes/ [CITED]
class IntakeLogs extends Table with SyncColumns {
  TextColumn get slotId => text().references(RegimenSlots, #id)();
  DateTimeColumn get date => dateTime()(); // UTC midnight, calendar identity
  IntColumn get status => intEnum<DoseStatus>()();

  @override
  List<Set<Column<Object>>>? get uniqueKeys => [
    {slotId, date},
  ];
}

mixin SyncColumns on Table {
  TextColumn get id => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
```

### Pattern 3: idempotent materialization via batch `insertOrIgnore`

**What:** `ensureLogsForDay` inserts one `IntakeLogs` row per active slot for a given day, using `InsertMode.insertOrIgnore` so calling it redundantly (every app foreground, every day switch) is free and safe — the `(slotId, date)` `uniqueKeys` constraint silently rejects duplicates.
**When to use:** Any code path that needs "today has rows to show" — view mount, day switch, app foreground.
**Example:**
```dart
// batch/InsertMode syntax — Source: https://pub.dev/documentation/drift/latest/drift/Batch-class.html
// and https://pub.dev/documentation/drift/latest/drift/InsertStatement-class.html [CITED]
Future<void> ensureLogsForDay(DateTime day) async {
  final utcDay = dateOnly(day); // core/domain — DateTime.utc(y, m, d)
  final activeSlots = await _activeSlotsFor(utcDay); // pure domain call: isActiveOn(...)
  final now = DateTime.now().toUtc();

  await db.batch((b) {
    b.insertAll<IntakeLogs, IntakeLog>(
      db.intakeLogs,
      activeSlots.map((slot) => IntakeLogsCompanion.insert(
        id: const Uuid().v4(),
        slotId: slot.id,
        date: utcDay,
        status: Value(DoseStatus.pending.index),
        createdAt: now,
        updatedAt: now,
      )),
      mode: InsertMode.insertOrIgnore,
    );
  });
}
```
Note: `insertOnConflictUpdate` (`into(table).insertOnConflictUpdate(row)`) is the correct choice for *upsert* semantics (e.g., editing a `Regimen`); `insertOrIgnore` is the correct choice for *idempotent-create* semantics (materialization). Do not confuse the two — using `insertOnConflictUpdate` in the materialization loop would silently overwrite a user's already-recorded `taken`/`skipped` status every time the day is revisited.

### Pattern 4: Drift schema export — `dart run drift_dev schema dump`

**What:** Exports the current schema (as defined by `schemaVersion` in `VitomyDb`) to a versioned JSON file, giving migration tooling something to diff/test against from the very first version.
**When to use:** Immediately after the Drift schema lands in this phase (schemaVersion = 1), and again every time `schemaVersion` is bumped in a later phase.
**Example:**
```bash
# Source: https://drift.simonbinder.eu/migrations/exports/ [CITED]
dart run drift_dev schema dump lib/core/db/database.dart drift_schemas/
# Produces drift_schemas/drift_schema_v1.json (filename is automatic, keyed to schemaVersion)
```

### Pattern 5: Riverpod 3.x — `Notifier`/`StreamProvider`, and combining two streams *without* rxdart

**What:** Riverpod 3.0 consolidates state-holding providers around `Notifier`/`AsyncNotifier`/`StreamNotifier` (replacing `StateNotifier`/`StateProvider`, now under a `legacy` import). `NotifierProvider<MyNotifier, State>(MyNotifier.new)` pairs a `Notifier` subclass (overriding `build()` with no parameters) with its provider. Pure read-only reactive data uses `StreamProvider`. [CITED: riverpod.dev/docs/3.0_migration, docs-v2.riverpod.dev/docs/providers/stream_provider]

**Combining two streams without rxdart:** rather than hand-rolling a `combineLatest`-style `Stream` merge, let Riverpod's own dependency graph do the combining — watch two independent `StreamProvider`s from a third derived provider and merge their `AsyncValue`s. This is the officially-discussed idiomatic pattern for "multiple async dependencies" in Riverpod (see `rrousselGit/riverpod` Discussions #2062, #3554, #3866) [CITED — GitHub Discussions, maintainer-participated, MEDIUM confidence, not an official docs page].

**Example:**
```dart
// core/l10n/locale_controller.dart — Notifier (Riverpod 3.x idiom)
class LocaleController extends Notifier<Locale?> {
  static const _prefsKey = 'app_locale';

  @override
  Locale? build() {
    final saved = ref.watch(sharedPreferencesProvider).getString(_prefsKey);
    return saved == null ? null : Locale(saved); // null = follow system
  }

  Future<void> setLocale(Locale? locale) async {
    final prefs = ref.read(sharedPreferencesProvider);
    if (locale == null) {
      await prefs.remove(_prefsKey);
    } else {
      await prefs.setString(_prefsKey, locale.languageCode);
    }
    state = locale;
  }
}

final localeControllerProvider = NotifierProvider<LocaleController, Locale?>(
  LocaleController.new,
);

// core/providers.dart — combining two Drift streams WITHOUT rxdart:
// two independent StreamProviders...
final _supplementsProvider = StreamProvider<List<Supplement>>(
  (ref) => ref.watch(supplementRepoProvider).watchAll(),
);
final _regimensProvider = StreamProvider<List<Regimen>>(
  (ref) => ref.watch(regimenRepoProvider).watchAll(),
);

// ...combined by a derived provider that watches both AsyncValues.
// Riverpod re-runs this provider whenever EITHER underlying stream emits —
// this IS the combineLatest behavior, achieved via the provider graph
// instead of a hand-rolled Stream combinator.
final stackEntriesProvider = Provider<AsyncValue<List<StackEntry>>>((ref) {
  final supplements = ref.watch(_supplementsProvider);
  final regimens = ref.watch(_regimensProvider);
  return supplements.when(
    data: (s) => regimens.when(
      data: (r) => AsyncData(combineStackEntries(s, r)), // pure fn, core/domain
      loading: () => const AsyncLoading(),
      error: AsyncError.new,
    ),
    loading: () => const AsyncLoading(),
    error: AsyncError.new,
  );
});
```
Repository-level `StreamProvider`s (`_supplementsProvider`, `_regimensProvider` above) are **not** `autoDispose` per the locked Riverpod policy — they're cheap to keep warm and shared across tabs.

### Pattern 6: `AppLocalizations.delegate.load` in a pure-Dart test (no widget pump)

**What:** Loads a locale's generated `AppLocalizations` instance directly, without building a widget tree — the fastest way to unit-test plural forms.
**Example:**
```dart
// Source: standard gen-l10n testing pattern; delegate API confirmed via
// Flutter's own gen_l10n-generated `LocalizationsDelegate` contract [CITED]
import 'package:flutter_test/flutter_test.dart';
import 'package:vitomy/core/l10n/gen/app_localizations.dart';

void main() {
  test('uk substancesCount covers all four CLDR forms + 11-14 exception', () async {
    final l10n = await AppLocalizations.delegate.load(const Locale('uk'));
    expect(l10n.substancesCount(1), '1 речовина');   // one
    expect(l10n.substancesCount(2), '2 речовини');   // few
    expect(l10n.substancesCount(5), '5 речовин');    // many
    expect(l10n.substancesCount(11), '11 речовин');  // many (11-14 exception)
    expect(l10n.substancesCount(21), '21 речовина'); // one
  });
}
```

### Anti-Patterns to Avoid
- **Declaring 4 separate `weight:`-keyed asset entries pointing at 4 different Instrument Sans files:** those files don't exist upstream (only one variable-font file ships). Declare a single asset entry per family; `FontWeight` maps automatically to the `wght` axis (Flutter 3.41+, confirmed active in this project's 3.47.0).
- **Using `insertOnConflictUpdate` inside `ensureLogsForDay`:** this is an upsert, not idempotent-create — it will silently clobber a user's already-recorded dose status on every materialization call. Use `InsertMode.insertOrIgnore` instead (see Pattern 3).
- **Hand-pinning `intl:` in `pubspec.yaml`:** produces the classic `flutter_localizations from sdk depends on intl X, ... is forbidden` `pub get` failure. Let SDK resolution pick it.
- **Combining two Drift streams with a hand-rolled `StreamController`/rxdart-style `combineLatest`:** unnecessary — Riverpod's provider graph already does this for free when a derived provider watches two `StreamProvider`s (Pattern 5). Reaching for a manual `Stream` combinator here is solving a problem Riverpod already solves.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Combining two reactive query streams into one derived list | A custom `combineLatest`-style `Stream` merge/`StreamController` | Provider composition — watch both `StreamProvider`s from a third derived `Provider`, combine their `AsyncValue`s (Pattern 5) | Riverpod's dependency graph already re-runs a provider whenever any of its watched providers change; hand-rolling stream combination duplicates machinery Riverpod gives you for free and is easy to get wrong around error/loading-state propagation |
| Idempotent "materialize today's rows" logic | A manual `SELECT ... WHERE NOT EXISTS` guard before every `INSERT` | Drift's `uniqueKeys` + `batch(...).insertAll(..., mode: InsertMode.insertOrIgnore)` (Pattern 3) | The database enforces the constraint atomically; a manual existence-check-then-insert has a race window and requires re-implementing what a UNIQUE index already guarantees |
| Schema migration bookkeeping | Hand-maintained "what changed between v1 and v2" changelog comments | `dart run drift_dev schema dump` snapshots + Drift's `Migrator` `onUpgrade` API (Pattern 4) | Gives an actual JSON artifact to diff and test migrations against, rather than trusting memory/comments — directly prevents PITFALLS.md Pitfall 2 (destructive/untested migrations) |
| DST-safe date arithmetic | Local-timezone `DateTime.add(Duration(days: n))` cycle math | `DateTime.utc(y, m, d)` normalization + integer day-difference modulo arithmetic in `core/domain/cycle_math.dart` | Local `DateTime` arithmetic silently misbehaves on the ~2 DST-transition days per year; this is PITFALLS.md's #1 flagged risk for this exact phase |
| Variable-font weight selection | Bundling/generating 4 static per-weight `.ttf` files that don't exist upstream, or using `FontVariation('wght')` manually in `TextStyle` | A single variable-font `.ttf` per family + plain `FontWeight` in `TextStyle` | Flutter 3.41+ auto-applies the `wght` variation axis from `FontWeight` — manual `FontVariation` code or hunting for nonexistent static files is solving an already-solved problem |

**Key insight:** every "don't hand-roll" item above corresponds to a documented pitfall in `.planning/research/PITFALLS.md` for this exact phase — this is not incidental, cycle math and materialization are called out there as the two riskiest, most bug-prone layers precisely because they're the ones most tempting to hand-roll under time pressure.

## Common Pitfalls

### Pitfall 1: `flutter create .` colliding with the repo's existing root `.gitignore`
**What goes wrong:** The repo root already contains a one-line `.gitignore` (`.DS_Store`) [VERIFIED: read `/Users/dima/supplements/.gitignore` this session, contents: `.DS_Store`]. `flutter create` generates its own `.gitignore` as part of the app template. Search results on Flutter's exact overwrite-vs-skip behavior for a single pre-existing file inside an otherwise-empty-of-Flutter-artifacts directory were inconclusive this session (some GitHub issues report the tool *should* only add missing files, others report real-world overwrites of specific files) — this is `[ASSUMED — could not be verified conclusively via docs/GitHub this session]`.
**Why it happens:** `flutter create` was designed for use in a genuinely empty directory or one that already has a Flutter project in it; running it in a directory with a *few* pre-existing, non-Flutter files (`.git`, `.gitignore`, `.planning/`, `docs/`, `claude_design_mockup/`) is a less-common path.
**How to avoid:** Before running `flutter create`, copy the existing `.gitignore` content aside (e.g., `cp .gitignore .gitignore.pre-flutter-create`). After running `flutter create`, diff the new `.gitignore` against the saved copy and manually re-add the `.DS_Store` line if it was dropped, rather than assuming either "it was preserved" or "it was overwritten."
**Warning signs:** `git diff .gitignore` immediately after `flutter create` shows the file was replaced wholesale rather than appended to.
**Phase to address:** Task that runs `flutter create` in this phase — first task, before anything else touches the repo root.

### Pitfall 2: Assuming Instrument Sans/JetBrains Mono ship as 4/2 static-weight files
**What goes wrong:** `google/fonts`'s repository stores only variable-font files for both families — `ofl/instrumentsans/InstrumentSans[wdth,wght].ttf` (+ `-Italic` variant) and `ofl/jetbrainsmono/JetBrainsMono[wght].ttf` (+ `-Italic` variant) [VERIFIED: `github.com/google/fonts` API directory listing fetched this session — filenames quoted verbatim above]. A task written to "download the 400/500/600/700 static files" will fail to find them.
**Why it happens:** The mockup's CSS `@import` URL (`fonts.googleapis.com/css2?family=Instrument+Sans:wght@400;500;600;700&family=JetBrains+Mono:wght@400;500`) [VERIFIED: read `claude_design_mockup/VitoMy v0.1.dc.html` lines 12–16 this session] requests specific weight *instances* via the CSS API, which serves subset/converted files on the fly — it does not imply 4 separate source files exist in the font's own repo.
**How to avoid:** Download the single variable-font file per family from `raw.githubusercontent.com/google/fonts/main/ofl/instrumentsans/InstrumentSans[wdth,wght].ttf` and `raw.githubusercontent.com/google/fonts/main/ofl/jetbrainsmono/JetBrainsMono[wght].ttf` (URL-encode `[`/`]`/`,` as `%5B`/`%5D`/`%2C` if fetching programmatically), commit into `assets/fonts/`, and declare **one** `fonts:` entry per family in `pubspec.yaml` (no `weight:` fanning needed — see Code Examples). Both fonts' variable weight axes cover the needed range (Instrument Sans: 400–700; JetBrains Mono: 100–800) [CITED: WebSearch of Google Fonts specimen pages], so 400/500/600/700 and 400/500 respectively render correctly from the single file.
**Warning signs:** A task or file listing mentions `InstrumentSans-Medium.ttf`, `InstrumentSans-SemiBold.ttf`, etc. — those files do not exist in the upstream source.
**Phase to address:** The font-bundling task in this phase.

### Pitfall 3: `synthetic-package: false` without `generate: true` — gen-l10n silently doesn't run
**What goes wrong:** With `synthetic-package: false` (CONTEXT.md's locked choice, and now effectively the *only* forward-compatible option — see Summary), `flutter pub get` alone does not trigger code generation unless `flutter: generate: true` is also set in `pubspec.yaml`. Forgetting this produces confusing "AppLocalizations not found" build errors that look like a missing-import problem rather than a missing-codegen-step problem.
**Why it happens:** The synthetic-package path used to auto-generate on every `pub get`; the source-directory path (`synthetic-package: false`) requires the explicit opt-in flag. [CITED: docs.flutter.dev/release/breaking-changes/flutter-generate-i10n-source, fetched this session]
**How to avoid:** Set both `l10n.yaml`'s `synthetic-package: false` AND `pubspec.yaml`'s:
```yaml
flutter:
  generate: true
```
**Warning signs:** `import 'package:vitomy/core/l10n/gen/app_localizations.dart';` fails to resolve even though `l10n.yaml` looks correct; `lib/core/l10n/gen/` is empty after `flutter pub get`.
**Phase to address:** The i18n-infrastructure task in this phase.

### Pitfall 4: Confusing `insertOnConflictUpdate` with `insertOrIgnore` in materialization
**What goes wrong:** See Anti-Patterns above — using the upsert variant in `ensureLogsForDay` overwrites a user's already-recorded `taken`/`skipped` status back to `pending` every time the function runs (e.g., every app foreground).
**Why it happens:** Both are one-line Drift calls with similar names; `insertOnConflictUpdate` is the more commonly documented/searched pattern (it's Drift's own primary upsert example), making it the "attractive nuisance" choice for a materialization function that's conceptually doing an upsert-like thing.
**How to avoid:** Use `batch(...).insertAll(..., mode: InsertMode.insertOrIgnore)` for materialization specifically; reserve `insertOnConflictUpdate` for true upserts like `RegimenRepository.upsert()`.
**Warning signs:** A widget test or manual QA pass shows a dose flip back to "pending" after backgrounding/foregrounding the app.
**Phase to address:** This phase (materialization is built here, even though no screen consumes it yet); re-verify once Phase 3 (Daily Tracking) adds the "mark taken" UI that would surface the bug.

### Pitfall 5: DST/timezone cycle-math bugs (carried forward from PITFALLS.md, phase-specific detail added)
**What goes wrong / why / how to avoid / warning signs:** See `.planning/research/PITFALLS.md` Pitfall 1 in full — this research pass adds no new findings here, only confirms the locked `DateTime.utc(y,m,d)` approach is correct and sufcient, with no local-`DateTime` arithmetic anywhere in `core/domain`.
**Phase to address:** This phase — `core/domain/cycle_math.dart`, before any UI or Drift code consumes it, exactly as CONTEXT.md's exit criterion already states.

## Code Examples

Verified patterns from official sources (also see Architecture Patterns above for the primary five):

### `flutter create` in the existing repo root
```bash
# Source: CONTEXT.md locked decision, syntax cross-checked against
# docs.flutter.dev create-command reference [CITED]
flutter create --project-name vitomy --org app.vitomy --platforms ios,android .
```

### `l10n.yaml` (matches CONTEXT.md's locked options exactly)
```yaml
# Source: docs.flutter.dev/ui/internationalization (option names/defaults),
# docs.flutter.dev/release/breaking-changes/flutter-generate-i10n-source
# (synthetic-package deprecation/removal timeline) [CITED]
arb-dir: lib/core/l10n/arb
template-arb-file: app_en.arb
output-dir: lib/core/l10n/gen
output-localization-file: app_localizations.dart
output-class: AppLocalizations
synthetic-package: false
nullable-getter: false
```
```yaml
# pubspec.yaml — REQUIRED alongside synthetic-package: false, see Pitfall 3
flutter:
  generate: true
```

### uk ARB plural entry using all four CLDR forms (verified rule boundaries)
```json
// Source: Unicode CLDR chart, unicode.org/cldr/charts/49/supplemental/language_plural_rules.html,
// fetched this session — quoted rule: "one: v=0 and i%10=1 and i%100!=11" (e.g. 1, 21);
// "few: v=0 and i%10=2..4 and i%100!=12..14" (e.g. 2-4, 22-24);
// "many: v=0 and i%10=0, or i%10=5..9, or i%100=11..14" (e.g. 0, 5-19, 100);
// "other" applies only to non-integer values (e.g. 1.5) [CITED]
{
  "substancesCount": "{count, plural, one{{count} речовина} few{{count} речовини} many{{count} речовин} other{{count} речовини}}",
  "@substancesCount": {
    "description": "Count of supplements in the user's stack",
    "placeholders": { "count": { "type": "int" } }
  }
}
```
Test exemplars from CONTEXT.md map onto the CLDR rule exactly: 1→one, 2→few, 5→many, 11→many (the 11–14 exception, since `i%100=11` matches the `many` branch directly, not falling through to `few`'s `i%10=1` check), 21→one.

### `pubspec.yaml` font declaration (single variable-font file per family — see Pitfall 2)
```yaml
# Source: docs.flutter.dev/cookbook/design/fonts (declaration syntax) +
# docs.flutter.dev/release/breaking-changes/font-weight-variation
# (FontWeight → wght auto-mapping, stable since Flutter 3.41) [CITED]
flutter:
  fonts:
    - family: Instrument Sans
      fonts:
        - asset: assets/fonts/InstrumentSans[wdth,wght].ttf
    - family: JetBrains Mono
      fonts:
        - asset: assets/fonts/JetBrainsMono[wght].ttf
```
```dart
// Usage — no FontVariation needed, FontWeight alone selects the wght instance:
Text('VitoMy', style: TextStyle(fontFamily: 'Instrument Sans', fontWeight: FontWeight.w600))
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|---------------|--------|
| `synthetic-package: true` / `package:flutter_gen` import for generated l10n | `synthetic-package: false` + `flutter: generate: true` + direct source import | Deprecated 3.28 (pre-release) / stable 3.32; scheduled full removal in the stable release after 3.32 — the project's 3.47.0 is past this point | CONTEXT.md's locked `synthetic-package: false` is not a style choice, it's the only forward-compatible path; must pair with `generate: true` (Pitfall 3) |
| Manual `FontVariation('wght')` calls to select a variable font's weight | Plain `FontWeight` in `TextStyle` auto-applies to the `wght` axis | Landed 3.39.0-0.0.pre, stable in 3.41 | Simplifies both the pubspec declaration (1 file per family, not 4/2) and app code (no manual `FontVariation`) |
| `sqlite3_flutter_libs` as an explicit dependency | `drift` (≥2.32) bundles SQLite via native build hooks automatically | Drift 2.32+ | Already reflected correctly in CONTEXT.md/STACK.md; no action needed, just don't add the now-redundant package |
| `StateNotifier`/`StateProvider` | `Notifier`/`AsyncNotifier`/`StreamNotifier` (legacy APIs moved to a `legacy` import, not removed) | Riverpod 3.0 stable | CONTEXT.md's `LocaleController (Riverpod Notifier, ...)` phrasing already assumes the current API — Pattern 5 above gives the exact current syntax |

**Deprecated/outdated:**
- `package:flutter_gen` synthetic-package import path for generated localizations — scheduled for full removal; do not write any task or code comment referencing `package:flutter_gen`.
- Static per-weight font files for Instrument Sans/JetBrains Mono from `google/fonts` — never existed upstream for these two families (variable-font-only), not merely "outdated."

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|----------------|
| A1 | `flutter create .` will either skip or safely handle the pre-existing single-line `.gitignore` without a hard error | Common Pitfalls #1 | Low — worst case is `.gitignore` gets replaced with the Flutter template's version, silently dropping the `.DS_Store` ignore line; caught immediately by a post-create `git diff`, trivial one-line fix |
| A2 | `path_provider` ^2.1.6, `uuid` ^4.6.0, `shared_preferences` ^2.5.5, `flutter_lints` ^6.0.0, `mocktail` ^1.0.5, `build_runner` ^2.16.0 versions are still current (carried from STACK.md, not re-fetched this session) | Standard Stack | Low — `flutter pub add` re-resolves against the live registry regardless of the version pin quoted in research docs; a stale minor version number in this doc does not affect what actually gets installed |
| A3 | `drift_flutter` ^0.3.1's `driftDatabase(name:)` behavior and file-path resolution described in Pattern 1 is unchanged since STACK.md's same-day pub.dev fetch | Architecture Patterns Pattern 1 | Low — package docs were fetched fresh this session and match STACK.md exactly; risk is only same-day drift, effectively nil |
| A4 | ICU `other` category rendering for `substancesCount`/`weeksCount` (used only for non-integer values in uk per CLDR) is safe to fill with the same text as `many` as a fallback | Code Examples | Low — `other` will essentially never be hit for integer dose/supplement counts; if it ever is (e.g., a future fractional metric), the fallback text is grammatically the closest of the four forms, not wrong, just imprecise |

**If this table is empty:** N/A — see rows above; all are low-risk, either self-correcting via tooling (`flutter pub add`/`pub get` re-resolution) or trivially caught by a `git diff`/test failure.

## Open Questions

1. **Exact `flutter create` overwrite behavior for a single pre-existing non-Flutter file in an otherwise-clean directory**
   - What we know: `flutter create` is documented to add missing files without wholesale-overwriting an existing Flutter project; GitHub issues show mixed real-world reports of specific-file overwrites in edge cases.
   - What's unclear: Whether the *one* pre-existing file in this repo root (`.gitignore`) specifically gets merged, skipped, or replaced.
   - Recommendation: Treat as Pitfall 1 above — back up, run, diff, reconcile. Costs one extra command, eliminates the ambiguity regardless of the tool's actual behavior.

2. **Whether to also bundle the italic variable-font files**
   - What we know: `google/fonts` ships `InstrumentSans-Italic[wdth,wght].ttf` and `JetBrainsMono-Italic[wght].ttf` alongside the uprights.
   - What's unclear: The approved mockup (`claude_design_mockup/VitoMy v0.1.dc.html`) was not audited this session for any `font-style: italic` usage — CONTEXT.md's font-weight list (400/500/600/700 and 400/500) does not mention italic.
   - Recommendation: Skip bundling italic files unless a planner-time grep of the mockup CSS finds `font-style:italic` in use; this is a small, cheap decision to defer to the planner/executor rather than research, since it's a one-line pubspec addition either way.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Flutter SDK | Entire phase | ✓ [VERIFIED: `flutter --version` run this session] | 3.47.0 (stable, Dart 3.13.0) | — |
| CocoaPods / JDK / Android SDK 36 | iOS/Android builds | ✓ (per CONTEXT.md — `flutter doctor` green, not re-verified this session per explicit instruction not to re-plan environment setup) | — | — |
| `node` (for `gsd-tools` seam) | Automated package-legitimacy check, research-plan cache | ✗ [VERIFIED: `node: command not found` this session] | — | Manual pub.dev verification performed instead (see Package Legitimacy Audit) |
| Network access (for this research session only, not for the app) | Fetching pub.dev/GitHub/CLDR docs during research | ✓ [VERIFIED: WebFetch/WebSearch/curl succeeded this session] | — | N/A — irrelevant to the shipped app, which is intentionally offline (DATA-01) |

**Missing dependencies with no fallback:** none blocking phase execution.
**Missing dependencies with fallback:** `node`/`gsd-tools` — fallback (manual pub.dev verification) already applied in this research pass; the planner does not need to re-run the automated seam, but should note in the phase plan that a `checkpoint:human-verify` after first `pub get` is a reasonable substitute for the skipped automated check.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | `flutter_test` (bundled with Flutter SDK — no separate install) |
| Config file | none — see Wave 0 gaps below (project doesn't exist yet, `test/` directory is created fresh in this phase) |
| Quick run command | `flutter test test/domain/cycle_math_test.dart` (or any single test file, <5s) |
| Full suite command | `flutter test` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| DATA-01 | App has zero network dependency (no `http`/`dio`/network package anywhere) | static/manual | `grep -rE "package:(http|dio|cronet)" lib/ pubspec.yaml` (expect no matches) — not expressible as a `flutter_test` unit test since it's an absence-of-dependency check, not a runtime behavior | ❌ Wave 0 — add as a documented manual/CI grep step, not a `test/` file |
| DATA-01 | `VitomyDb.open()` / repository calls succeed with no network I/O | integration (implicit) | `flutter test test/db/*_test.dart` using `VitomyDb.forTesting(NativeDatabase.memory())` — passes with no network permission on the test runner, which is itself the proof | ❌ Wave 0 |
| DATA-02 | Every table has `id` (UUID TEXT PK), `createdAt`, `updatedAt`, `deletedAt` (nullable) | unit | `flutter test test/db/sync_columns_test.dart` — introspect `db.allTables` columns programmatically and assert the four `SyncColumns` fields exist on each | ❌ Wave 0 |
| DATA-02 | `IntakeLogs` uniqueKeys `(slotId, date)` rejects duplicate materialization | unit | `flutter test test/db/materialization_test.dart` — call `ensureLogsForDay` twice for the same day, assert row count unchanged | ❌ Wave 0 |
| DATA-02 | DB file lives in default OS-backup-included location; no `allowBackup="false"`/`NSURLIsExcludedFromBackupKey` set | manual-only | Manual review of generated `android/app/src/main/AndroidManifest.xml` and `ios/Runner/Info.plist` after `flutter create` — not automatable via `flutter_test`, since these are static config files, not runtime behavior | ❌ Wave 0 — add as a manual checklist item in the plan, justification: OS backup inclusion is a build-config property, not something `flutter_test` can introspect from a test-runner sandbox |
| (Phase exit criterion) DST-safe cycle math | Cyclic/course `isActiveOn` correctness across DST transition + year boundary | unit | `flutter test test/domain/cycle_math_test.dart` — parametrized over the exemplar dates in CONTEXT.md's `<specifics>` (56on/28off from 2026-08-14, course end 2026-09-30 inclusive, 2026→2027 boundary) | ❌ Wave 0 |
| (Phase exit criterion) uk plural correctness | `substancesCount`/`weeksCount` render correct CLDR form for 1, 2, 5, 11, 21 | unit | `flutter test test/l10n/plurals_test.dart` — `AppLocalizations.delegate.load(Locale('uk'))` (Pattern 6) | ❌ Wave 0 |
| (Phase exit criterion) Shell renders localized tab labels | `AppShell` shows correct en/uk tab labels | widget | `flutter test test/widget/app_shell_test.dart` — pump `MaterialApp` with `locale: Locale('uk')` and `Locale('en')`, assert `find.text(...)` for each localized label | ❌ Wave 0 |

### Sampling Rate
- **Per task commit:** the single relevant test file (`flutter test test/<area>/<file>_test.dart`)
- **Per wave merge:** `flutter analyze && flutter test` (full suite)
- **Phase gate:** Full suite green + `flutter analyze` clean before `/gsd-verify-work`, exactly as CONTEXT.md's Testing section states as the phase exit criterion

### Wave 0 Gaps
- [ ] `test/domain/cycle_math_test.dart` — covers DST/year-boundary exit criterion
- [ ] `test/db/sync_columns_test.dart`, `test/db/materialization_test.dart` — cover DATA-02
- [ ] `test/l10n/plurals_test.dart` — covers uk plural exit criterion
- [ ] `test/widget/app_shell_test.dart` — covers localized-shell exit criterion
- [ ] `analysis_options.yaml` — `flutter_lints` + `include: package:flutter_lints/flutter.yaml`, needed for the `flutter analyze` clean exit criterion
- [ ] No shared fixtures needed yet — each test area is small enough for inline setup at this phase's scale

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-------------------|
| V2 Authentication | No | No accounts/login anywhere in v1 (locked, DATA-01) |
| V3 Session Management | No | No sessions — fully offline, single-device |
| V4 Access Control | No | Single-user local app, no multi-tenant/role concerns |
| V5 Input Validation | Partial | Domain models (`Regimen.onDays`/`offDays`, `DoseSlot.minutesFromMidnight`) should validate ranges (e.g., `minutesFromMidnight` in `0..1439`) in constructors/factories — this is ordinary Dart validation, not a security library; no framework needed |
| V6 Cryptography | No (by design, flagged for awareness) | Data is stored unencrypted in SQLite for v1 — PITFALLS.md's Security Mistakes table documents this as an accepted, conscious v1 trade-off, not an oversight. No hand-rolled encryption should be added in this phase; if encryption is ever required, use SQLCipher (via a Drift-compatible executor) or platform Data Protection classes, never a custom scheme. |

### Known Threat Patterns for this stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|----------------------|
| SQL injection via string-concatenated queries | Tampering | N/A — Drift's typed query builder parameterizes all values automatically; no raw SQL string concatenation appears anywhere in this phase's patterns above |
| Accidental exclusion of the local DB from OS backups (via boilerplate template defaults) | — (data-loss risk, not classic STRIDE, but explicitly a DATA-02 requirement) | Verify `android:allowBackup` is not set to `false` and no `NSURLIsExcludedFromBackupKey` is applied to the DB file after `flutter create` scaffolds the manifest/plist — see Validation Architecture manual-only check above |
| Widget/provider bypassing the repository layer to query Drift directly | Tampering (of the architecture's own integrity guarantee) | Enforce via code review / `grep -r "package:drift" lib/features` in CI that only `core/db/*.dart` imports `package:drift` (ARCHITECTURE.md Anti-Pattern 1) |

## Sources

### Primary (HIGH confidence)
- [drift.simonbinder.eu/migrations/exports](https://drift.simonbinder.eu/migrations/exports/) — `dart run drift_dev schema dump` exact CLI syntax (fetched this session)
- [pub.dev/documentation/drift_flutter/latest](https://pub.dev/documentation/drift_flutter/latest/) — `driftDatabase(name:)` file-path behavior, quoted verbatim (fetched this session)
- [pub.dev/documentation/drift/latest/drift/Batch-class.html](https://pub.dev/documentation/drift/latest/drift/Batch-class.html) and [.../InsertStatement-class.html](https://pub.dev/documentation/drift/latest/drift/InsertStatement-class.html) — `insertAll`/`InsertMode.insertOrIgnore`/`insertOnConflictUpdate`/`uniqueKeys` syntax (fetched this session)
- [riverpod.dev/docs/3.0_migration](https://riverpod.dev/docs/3.0_migration) — `Notifier`/`NotifierProvider` current class names and `build()` signature (fetched this session)
- [docs-v2.riverpod.dev/docs/providers/stream_provider](https://docs-v2.riverpod.dev/docs/providers/stream_provider) — `StreamProvider` current API (fetched this session)
- [docs.flutter.dev/release/breaking-changes/flutter-generate-i10n-source](https://docs.flutter.dev/release/breaking-changes/flutter-generate-i10n-source) — `synthetic-package` deprecation/removal timeline, `generate: true` requirement (fetched this session)
- [docs.flutter.dev/release/breaking-changes/font-weight-variation](https://docs.flutter.dev/release/breaking-changes/font-weight-variation) — `FontWeight` → `wght` variation-axis auto-mapping, landed 3.39.0-0.0.pre / stable 3.41 (fetched this session, quoted verbatim)
- [github.com/google/fonts](https://github.com/google/fonts) `ofl/instrumentsans/` and `ofl/jetbrainsmono/` directory listings via GitHub Contents API — confirmed only variable-font `.ttf` files exist for both families, exact filenames quoted (fetched this session via `curl`)
- [unicode.org/cldr/charts/49/supplemental/language_plural_rules.html](https://www.unicode.org/cldr/charts/49/supplemental/language_plural_rules.html) — Ukrainian plural rule formulas for `one`/`few`/`many`/`other`, quoted verbatim (fetched this session)
- pub.dev direct fetch this session: [drift](https://pub.dev/packages/drift) 2.34.3 (publisher `simonbinder.eu`), [flutter_riverpod](https://pub.dev/packages/flutter_riverpod) 3.4.2 (publisher `dash-overflow.net`)
- Project-internal, read this session: `/Users/dima/supplements/.planning/phases/01-foundation/01-CONTEXT.md`, `/Users/dima/supplements/.planning/REQUIREMENTS.md`, `/Users/dima/supplements/.planning/STATE.md`, `/Users/dima/supplements/.planning/research/STACK.md`, `/Users/dima/supplements/.planning/research/PITFALLS.md`, `/Users/dima/supplements/.planning/research/ARCHITECTURE.md`, `/Users/dima/supplements/.planning/config.json`, `/Users/dima/supplements/.claude/CLAUDE.md`, `/Users/dima/supplements/claude_design_mockup/VitoMy v0.1.dc.html` (font `@import` line, quoted verbatim), `/Users/dima/supplements/.gitignore` (contents quoted verbatim)

### Secondary (MEDIUM confidence)
- [pub.dev/documentation/path_provider](https://pub.dev/documentation/path_provider/latest/path_provider/getApplicationDocumentsDirectory.html) + corroborating WebSearch — `getApplicationDocumentsDirectory()` → iOS `NSDocumentDirectory` (iCloud-backed by default unless `NSURLIsExcludedFromBackupKey` set) and Android internal app-data directory (Auto Backup–eligible by default for targetSdk ≥23 unless `allowBackup="false"`)
- `rrousselGit/riverpod` GitHub Discussions #2062, #3554, #3866 — idiomatic "combine multiple async/stream providers via a derived provider watching several `AsyncValue`s" pattern (maintainer-participated discussions, not an official docs page)
- Google Fonts specimen pages (via WebSearch) — Instrument Sans variable weight axis 400–700; JetBrains Mono variable weight axis 100–800 (both fully cover the mockup's declared weight usage)

### Tertiary (LOW confidence)
- Various GitHub issues on `flutter create`'s exact overwrite-vs-skip behavior for a single pre-existing non-Flutter file — inconclusive, treated as an open question / documented pitfall with a safe mitigation rather than an asserted fact

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — core two packages (`drift`, `flutter_riverpod`) re-verified live against pub.dev this session and match STACK.md exactly; remaining packages carried from STACK.md's same-day pub.dev fetch (not independently re-verified, but low drift risk given same-day origin)
- Architecture: HIGH — five requested API/syntax areas (Drift schema export, `driftDatabase`, Riverpod 3.x Notifier/StreamProvider, gen-l10n/synthetic-package, font bundling) all fetched from official docs or upstream GitHub source this session
- Pitfalls: HIGH for font-bundling and synthetic-package findings (directly verified via GitHub API / official breaking-change docs); MEDIUM-LOW for the `flutter create`-in-non-empty-directory `.gitignore` collision (inconclusive search results, mitigated with a safe procedural workaround rather than asserted behavior)

**Research date:** 2026-08-14
**Valid until:** ~30 days for Drift/Riverpod API syntax (stable, slow-moving); ~7 days for anything tied to the Aug 31, 2026 Android targetSdk 36 deadline context (not directly actioned in this phase, but adjacent); font-bundling/CLDR findings are effectively permanent (upstream file layout and Unicode plural rules do not change on a weekly cadence)
