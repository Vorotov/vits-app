<!-- GSD:project-start source:PROJECT.md -->

## Project

**VitoMy**

VitoMy is a mobile supplement stack planner and tracker for iOS and Android, built as a single Flutter codebase. Users define the supplements they take, schedule doses — including week-based on/off cycles and one-time courses — and track intake in a calendar with Today, Cycles, and Year views. The visual design exists as an approved HTML mockup (`claude_design_mockup/VitoMy v0.1.dc.html`, 5 screens, Ukrainian-first).

**Core Value:** A user can see exactly what to take today and check it off, with cycles and breaks computed correctly — the daily loop of plan → see → mark taken must always work.

### Constraints

- **Tech stack**: Flutter + Dart single codebase — decided after comparing with React Native/Expo; user's explicit choice
- **State/DB**: Riverpod + Drift (SQLite) — reactive typed queries feed calendar views
- **Architecture**: UI depends on repository interfaces only (`SupplementRepository`/`RegimenRepository`/`IntakeRepository`); Drift is one implementation — keeps future backend/sync possible without touching screens
- **Sync-ready data**: UUID primary keys, createdAt/updatedAt, soft deletes on every table
- **i18n**: gen-l10n with ARB files; zero hardcoded user-visible strings; ICU plurals (Ukrainian one/few/many); locale-aware date/number formatting; no fixed-width text containers; direction-neutral padding (RTL-ready)
- **Dates**: date-only values normalized as `DateTime.utc(y,m,d)` — DST safety for cycle math
- **App name and bundle id**: **VitoMy**, `app.vitomy` — reverse-DNS of the
  project's domain vitomy.app, decided 2026-09-11. Permanent from the moment
  the App Store Connect and Play Console records are created; changing it later
  means a new app, not an update.

<!-- GSD:project-end -->

<!-- GSD:stack-start source:research/STACK.md -->

## Technology Stack

## Locked Decisions (context, not re-litigated)

## Recommended Stack

### Core Technologies

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| Flutter SDK | 3.47.0 (already installed) | App framework | Current stable channel; ships Dart 3.13, Impeller-by-default on desktop, and — notably for this project — Flutter 3.47 "unpins SDK package dependencies," which removes the long-standing hard version pin `flutter_localizations` placed on `intl` (see Version Compatibility). No reason to pin to an older release. |
| Dart SDK | 3.13.0 (bundled with Flutter 3.47) | Language | Ships with Flutter 3.47; use Dart 3 records/pattern-matching in `core/domain` cycle-math code — a good fit for pure, value-typed functions with no external deps. |
| flutter_riverpod | ^3.4.2 | State management | Riverpod 3.0 is the current stable major (no longer beta/rc). Confirms the project's locked choice. Bring in `riverpod` transitively; do not add it directly for a Flutter-only app. |
| drift | ^2.34.3 | Typed reactive SQLite ORM | Confirms the project's locked choice. 2.32+ bundles SQLite itself via the `sqlite3` package's native build hooks, so `sqlite3_flutter_libs` is no longer needed as a direct dependency (fewer moving parts, one less thing to go stale). |
| drift_flutter | ^0.3.1 | Flutter-specific DB opening helper for Drift | Handles picking a correct on-device file path per platform (`getApplicationDocumentsDirectory()`) and wires up native SQLite for you — the officially recommended way to open a Drift database in a Flutter app. Requires `path_provider` alongside it. |

### Supporting Libraries

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| path_provider | ^2.1.6 | Resolve platform app-documents directory | Required by `drift_flutter`'s default `driftDatabase(...)` constructor — pull it in even though nothing in app code calls it directly. |
| riverpod_annotation | ^4.0.6 | `@riverpod` annotations | Pair with `riverpod_generator` (below) — use code-gen providers (`@riverpod` functions/classes) instead of hand-written `Provider`/`NotifierProvider` boilerplate. Since `build_runner` is already a hard dependency for Drift's codegen, adding Riverpod's generator costs nothing extra in tooling and removes a class of manual-provider mistakes (forgetting `autoDispose`, mistyped generic params). |
| uuid | ^4.6.0 | UUID v4 generation | Required by the locked "sync-ready data" decision — every table's primary key is a UUID string, not an autoincrement int. Use `const Uuid().v4()` in repository `create()` methods only (never in Drift table defaults, so it stays swappable/testable). |
| intl | resolved automatically, do not hand-pin (see below) | Locale-aware date/number formatting, ICU plurals | Used both by generated `gen-l10n` code and directly in `core/domain`/`features/calendar` for week-range labels ("Т27–44"), month names, and day-progress counts. Let `flutter_localizations` (SDK) dictate the version — see Version Compatibility. |
| shared_preferences | ^2.5.5 | Small persisted key-value settings | Exactly one use in this app: persisting the manual language-override choice from the settings screen (`features/settings`). Do not use it for anything that belongs in Drift (supplement/regimen/intake data) — it has no query capability and no reactivity. |
| flutter_lints | ^6.0.0 | Official Dart/Flutter lint rule set | Baseline lints from the Flutter team; enable in `analysis_options.yaml` from commit 1. |
| riverpod_lint | ^3.1.8 (dev) | Riverpod-specific static analysis (paired with `custom_lint` ^0.8.1) | Catches Riverpod-specific mistakes (missing `ref.watch` in generated providers, unused providers, sync/async return-type mismatches) that generic lints can't see. Requires a `custom_lint` plugin entry in `analysis_options.yaml`. |
| mocktail | ^1.0.5 | Mocking for widget/unit tests | Mock the three repository interfaces (`SupplementRepository`/`RegimenRepository`/`IntakeRepository`) in widget tests so screen logic is tested independently of Drift. Null-safety-native, no code generation required (unlike `mockito`), which matters since `build_runner` is already busy with Drift + Riverpod codegen. |

### Development Tools

| Tool | Purpose | Notes |
|------|---------|-------|
| build_runner | ^2.16.0 | Runs Drift's and Riverpod's code generators | One shared `build_runner` invocation drives both `drift_dev` and `riverpod_generator`. Use `dart run build_runner watch -d` during active development (`-d` deletes conflicting outputs automatically); `build_runner build` for CI/one-shot. |
| drift_dev | ^2.34.5 | Drift's generator (dev_dependency only) | Never import in app code — dev-only. Keep its version locked to the same minor line as `drift` itself (2.34.x with 2.34.x) to avoid generator/runtime schema mismatches. |
| flutter_lints + `dart analyze` | Static analysis | Run in CI; treat warnings as build-breaking for `core/domain` (the cycle-math code) given how bug-prone date math is. |
| flutter_test (bundled with SDK) | Unit + widget tests | No separate dependency needed — ships with the Flutter SDK. Use for the bulk of the test suite per the approved design spec (cycle math unit tests, Stack/Day-view widget tests). |
| integration_test (bundled with SDK) | End-to-end smoke test | Not required for v1 by the design spec, but worth reserving for a single "add supplement → see it in Today view" smoke test once the core loop stabilizes — optional, not blocking. |

## Installation

# Core

# intl: let Flutter resolve the version pinned by flutter_localizations — do not pass a version constraint

# Dev dependencies

## Alternatives Considered

| Recommended | Alternative | When to Use Alternative |
|-------------|-------------|-------------------------|
| Riverpod code-gen (`@riverpod` + `riverpod_generator`) | Hand-written `Provider`/`NotifierProvider` | If you want zero codegen for state (only Drift generates code) — valid, slightly more boilerplate, no functional downside for an app this size. Either is fully supported by Riverpod 3's official docs; this is a style choice, not a correctness one. |
| Custom-painted charts for the Cycles gantt + weekly concurrent-load bars | `fl_chart` (^1.2.0) | `fl_chart` is the most mature, actively maintained Flutter charting package (bar/line charts with theming) and is a reasonable fallback if hand-rolled `CustomPaint`/`Row`-of-bars widgets prove too slow to build. But the mockup's gantt (regimens as horizontal bars across a ~4-month timeline with week gridlines) and the year matrix don't map onto any general-purpose chart type — they're bespoke layouts, not X/Y series data. Recommend building them as plain Flutter widgets (`Row`/`Stack`/`CustomPaint`) sized directly off the design tokens, which also guarantees exact mockup fidelity that a generic charting library would fight against. |
| mocktail | mockito | `mockito` requires `build_runner`-based codegen for typed mocks; `mocktail` doesn't, and this project's `build_runner` pipeline is already carrying Drift + Riverpod codegen. Skip the extra generator surface. |
| Plain Flutter `fonts:` asset declaration for Instrument Sans + JetBrains Mono | `google_fonts` package (^8.2.1) | See "What NOT to Use" below — only reach for `google_fonts` if the font choice becomes a moving target during design iteration and you want to swap families without re-bundling `.ttf` files by hand. |

## What NOT to Use

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| `google_fonts` package for Instrument Sans/JetBrains Mono | The design spec already decided these two fonts are "bundled as assets," and this is a fully offline, no-network app — `google_fonts`'s default behavior is to fetch font files over HTTP at first use and cache them, which is actively wrong for a local-first app (network dependency, first-run jank, non-determinism in screenshot/golden tests). The package *can* be forced fully offline (`GoogleFonts.config.allowRuntimeFetching = false` + manually bundling the `.ttf` files under `assets/`), but at that point you're doing exactly the same work as the plain Flutter `fonts:` pubspec declaration with an extra dependency and an extra footgun (silent runtime fallback if a weight is missing) on top. Skip it. | Declare `Instrument Sans` and `JetBrains Mono` directly under `flutter: fonts:` in `pubspec.yaml`, with the specific weights the mockup uses (check the HTML mockup's `font-weight` usages) bundled as local `.ttf`/`.otf` assets in `assets/fonts/`. |
| `sqlite3_flutter_libs` as a direct dependency | Obsolete for current Drift: since Drift 2.32, `sqlite3`'s native build hooks bundle SQLite automatically, and `drift_flutter` wires this up. Adding it directly is redundant and is exactly the kind of extra dependency that goes stale and causes native-build breakage on Xcode/Gradle upgrades. | `drift` + `drift_flutter` alone. |
| Hand-pinning `intl` to a specific version (e.g., `intl: ^0.20.3`) in `pubspec.yaml` | `flutter_localizations` (the SDK package `gen-l10n` output imports) has historically hard-pinned an exact `intl` version, and mismatches between an app's own `intl` constraint and the SDK's produce a version-solving failure (`flutter_localizations from sdk depends on intl X, ... is forbidden`) — a very common, very confusing first-run error in Flutter i18n projects. Flutter 3.47 specifically works to unpin this, but don't fight the SDK's resolution by adding your own constraint. | Add `intl` with no version constraint (`flutter pub add intl`) and let `flutter pub get` resolve the version `flutter_localizations` requires; re-run `flutter pub get` (not a manual edit) whenever you bump the Flutter SDK. |
| `mockito` | Requires a second `build_runner`-driven codegen pass for mocks, on top of Drift's and Riverpod's — unnecessary generator surface and slower `build_runner` runs for no capability this app needs. | `mocktail` |
| A generic calendar/date-picker package (e.g. `table_calendar`) for the Cycles/Year planner screens | These screens are bespoke, non-standard layouts (a multi-month gantt with week gridlines; a 12-month coverage matrix) that don't match what "calendar" packages model (a single scrollable month grid of selectable days). Forcing the design into a generic calendar widget's API will fight the mockup's exact layout. | Build these views as plain Flutter widgets driven directly by the `core/domain` cycle-math output; reserve Flutter's built-in `showDatePicker`/`showTimePicker` for the one place a genuine picker is needed — the Dosing Schedule editor's time-slot input. |

## Stack Patterns by Variant

- No new *stack* packages needed now — the current data model (materialized `IntakeLog` rows) is the enabling piece, already covered by the locked Drift schema decision.
- When that phase arrives, research `flutter_local_notifications` (notifications) and `home_widget` (iOS/Android widgets) fresh at that time — versions move fast in that space and it's out of scope for v1's stack.
- The repository-interface pattern already isolates this; no client HTTP/serialization package (`dio`, `json_serializable`, etc.) is needed in v1. Pick those when the sync phase is actually scoped, not now — adding them speculatively just adds unused dependencies to audit.

## Version Compatibility

| Package A | Compatible With | Notes |
|-----------|-----------------|-------|
| Flutter 3.47.0 / Dart 3.13.0 | flutter_riverpod ^3.4.2, drift ^2.34.3, drift_flutter ^0.3.1 | All four verified current/compatible as of this research date — no known open incompatibilities. |
| flutter_localizations (SDK) | intl | Historically an *exact* pin (`flutter_localizations from sdk depends on intl X.Y.Z`), a frequent source of `pub get` version-solving failures across many Flutter releases (tracked in flutter/flutter#162568, #164688, #169591, #168903). Flutter 3.47's changelog specifically includes "unpin SDK package dependencies," loosening this — but treat it as still-fragile: never hand-set an `intl` version constraint; always let SDK resolution pick it, and re-resolve after every Flutter upgrade. |
| drift ^2.34.x | drift_dev ^2.34.x, drift_flutter ^0.3.1 | Keep `drift` and `drift_dev` on matching minor versions (both 2.34.x) — mismatched generator/runtime versions across a minor bump is Drift's most common "generated code doesn't match schema" bug report. `drift_flutter` versions independently (0.x) and is not required to match. |
| riverpod_generator ^4.0.8 | riverpod_annotation ^4.0.6, flutter_riverpod ^3.4.2 | Riverpod's 3.x/4.x-generator pairing (annotation package major version tracks the generator, not the runtime `flutter_riverpod` major) — a historical footgun in this ecosystem (an old, now-resolved riverpod_lint/flutter_test `vm_service` pin conflict is documented in rrousselGit/riverpod#3313 from the 2.x era). Not currently reproducible on the versions above, but if `flutter pub get` ever reports a `vm_service` conflict after adding `riverpod_lint`, that issue's workaround (temporarily drop `flutter_test` from dev_dependencies to resolve, then restore) is the known fix pattern. |
| build_runner ^2.16.0 | drift_dev ^2.34.5, riverpod_generator ^4.0.8 | One shared `build_runner` run drives both generators; no conflicts observed between them as of these versions. |

## Sources

- pub.dev (direct WebFetch, current-version confirmed HIGH confidence): [flutter_riverpod](https://pub.dev/packages/flutter_riverpod) 3.4.2, [drift](https://pub.dev/packages/drift) 2.34.3, [drift_flutter](https://pub.dev/packages/drift_flutter) 0.3.1, [drift_dev](https://pub.dev/packages/drift_dev) 2.34.5, [build_runner](https://pub.dev/packages/build_runner) 2.16.0, [google_fonts](https://pub.dev/packages/google_fonts) 8.2.1, [shared_preferences](https://pub.dev/packages/shared_preferences) 2.5.5, [uuid](https://pub.dev/packages/uuid) 4.6.0, [intl](https://pub.dev/packages/intl) 0.20.3, [riverpod_generator](https://pub.dev/packages/riverpod_generator) 4.0.8, [riverpod_lint](https://pub.dev/packages/riverpod_lint) 3.1.8, [custom_lint](https://pub.dev/packages/custom_lint) 0.8.1, [flutter_lints](https://pub.dev/packages/flutter_lints) 6.0.0, [mocktail](https://pub.dev/packages/mocktail) 1.0.5, [fl_chart](https://pub.dev/packages/fl_chart) 1.2.0
- [Drift setup docs](https://drift.simonbinder.eu/setup/) — official dependency list and `driftDatabase()` usage, confirms `sqlite3_flutter_libs` no longer needed since Drift 2.32
- [Riverpod migrating 2.0 → 3.0](https://riverpod.dev/docs/3.0_migration) and [Riverpod getting started](https://riverpod.dev/docs/introduction/getting_started) — confirms 3.0 is stable, documents code-gen vs manual provider setup as equally valid
- [Flutter 3.47.0 release notes](https://docs.flutter.dev/release/release-notes/release-notes-3.47.0) and [flutter.dev blog](https://flutter.dev/blog/whats-new-in-flutter-3-47) — confirms Dart 3.13 bundling, Impeller default, and "unpin SDK package dependencies" (intl fix)
- flutter/flutter GitHub issues [#162568](https://github.com/flutter/flutter/issues/162568), [#164688](https://github.com/flutter/flutter/issues/164688), [#169591](https://github.com/flutter/flutter/issues/169591), [#168903](https://github.com/flutter/flutter/issues/168903) — MEDIUM confidence, community-reported but corroborating pattern across many Flutter versions, on the `flutter_localizations`/`intl` pin issue
- rrousselGit/riverpod [#3313](https://github.com/rrousselGit/riverpod/issues/3313) — MEDIUM confidence, historical (2.x-era) `vm_service` pin conflict between `riverpod_lint`/`riverpod_generator` and `flutter_test`; kept as a documented gotcha pattern, not confirmed reproducible on current 3.x/4.x versions
- Flutter Gems / GitHub search on Gantt chart packages (`gantt_chart`, `legacy_gantt_chart`, `flutter_gantt`, `gantt_view`) — LOW confidence (small, low-adoption community packages); used only to confirm no dominant/canonical gantt package exists, supporting the recommendation to hand-build the Cycles/Year views instead

<!-- GSD:stack-end -->

<!-- GSD:conventions-start source:CONVENTIONS.md -->

## Conventions

Every rule below is one the code actually follows. Where a test enforces it,
the test is named; where nothing does, it says so. Counts were measured.

### Where a decision is written down

Load-bearing decisions live in **library-level doc comments on the file that
implements them**, not in a separate document: `lib/core/providers.dart` (the
Riverpod dispose policy), `lib/core/l10n/clock_format.dart` (why the time
pattern is pinned), `lib/core/domain/models.dart` (the time-type split),
`lib/features/onboarding/first_run_hints.dart` (why there is no tour),
`lib/core/db/database.dart` (the sync-ready column contract). Changing one of
those behaviours means changing its doc comment in the same commit. Comments
cite decision ids (D-nn), review findings (CR-nn / WR-nn) and plan numbers —
keep that habit; it is how a later reader finds the argument.

### Domain and dates

- `lib/core/domain/` (`models.dart`, `cycle_math.dart`, `repositories.dart`)
  imports nothing outside `dart:core`. No Flutter, no Drift, no I/O.
- Cycle math is **clock-free**: `isActiveOn(regimen, day)` is handed the day.
  The one sanctioned wall-clock read in the app is `TodayController.now`
  (`lib/core/today_controller.dart`, injectable so the midnight rollover is
  testable at all). Screens read `todayProvider`; nothing calls
  `DateTime.now()` per build.
- Date-only values are always `DateTime.utc(y, m, d)` via `dateOnly()`.
  `dayDosesProvider` and `dayDosesReadOnlyProvider` assert their family key is
  normalized — a non-normalized key silently forks the cache into a phantom
  day.
- Never derive "tomorrow" by adding 24 hours. `nextLocalMidnight()` builds
  `DateTime(y, m, d + 1)` so a 23- or 25-hour DST day absorbs correctly.
- Drift stores `DateTime` as ISO-8601 text
  (`build.yaml: store_date_time_values_as_text: true`) so UTC values read back
  with `isUtc == true`. Flipping that flag breaks date-only equality
  everywhere.

### Providers

- Providers are **hand-written** (`Provider`, `StreamProvider`,
  `NotifierProvider`). There is no `@riverpod` codegen in `lib/`, and neither
  `riverpod_generator` nor `riverpod_lint` is installed — whatever the stack
  section above recommends. `build_runner` drives Drift only.
- The dispose policy is decided once, in `lib/core/providers.dart`'s header:
  repository and stream providers are app-lifetime (NOT autoDispose);
  screen-scoped state may be autoDispose. Do not re-litigate it per provider.
- `sharedPreferencesProvider` is `Provider<SharedPreferences?>` whose body
  **throws unless overridden**. `main()` overrides it with the instance
  resolved before `runApp`; every test whose tree reaches it must do the same.
  The throw is the point — a missed harness fails loudly instead of silently
  losing the user's language override. The nullable type is also deliberate:
  `null` means the store could not be opened at all, which must cost the
  language override and nothing else.
- Combining two async sources uses an explicit **error → value → loading**
  precedence evaluated across BOTH sources (`stackEntriesProvider`), never a
  nested `when`. Riverpod 3 reports a failing stream as an `AsyncLoading` that
  carries the error, so a nested `when` discards an error sitting in whichever
  source is evaluated second.
- A retry path invalidates the **stream** providers, not the derivation
  (`retryStack`): invalidation propagates to dependents, never to
  dependencies, so a retry aimed at a derived `Provider` is a button that
  cannot work.

### Widgets watch STATE, never `.notifier`

Watch `ref.watch(someProvider)` when you render from its value.
`ref.watch(someProvider.notifier)` rebuilds only when the notifier INSTANCE
changes, which it does not. This shipped as a real defect: dismissing a
first-run hint updated the set and left the card on screen. The shape to copy
is `showsHint(ref.watch(firstRunHintsProvider), BqHint.markDose)` — the set is
the argument, so the dependency is the thing that actually changes — with
`.notifier` reached only through `ref.read` to call `dismiss()`.

### Reading untrusted SharedPreferences

One stance, followed by all three stores (`lib/core/l10n/locale_controller.dart`,
`lib/features/onboarding/first_run_hints.dart`,
`lib/features/onboarding/onboarding_controller.dart`):

1. Read with `prefs.get(key)` and type-check the result. Never
   `getString` / `getBool` / `getStringList` — they are unguarded downcasts, so
   a wrong-typed value throws inside `build()` and parks the provider in a
   permanent error state that survives restarts.
2. Sanitize against something DERIVED (the shipped locale tags come from
   `AppLocalizations.supportedLocales`; hint ids come from the `BqHint` enum).
   Never pass a stored value through.
3. Degrade toward the safe direction. An unopenable or corrupt store means
   "follow the system language" and "every hint already seen" — a hint that
   cannot be permanently dismissed would reappear forever, which is worse than
   never showing it.
4. Writes set in-memory state FIRST and persist after, so the change is on the
   next frame. A write failure is swallowed, reported via
   `FlutterError.reportError`, and never surfaced to the user — it costs one
   launch of amnesia. A `false` return from `setString` / `setStringList` /
   `remove` is reported exactly like a throw; letting either escape would make
   an unhandled root-zone error out of a stance whose whole point is silence.

Covered by `test/l10n/locale_controller_test.dart`,
`test/l10n/cold_start_degradation_test.dart`,
`test/features/first_run_hints_test.dart`,
`test/features/onboarding_controller_test.dart`.

### `main()` is gated at exactly two awaits

Only the `SharedPreferences` resolution and the notification launch-details
read may be awaited between `WidgetsFlutterBinding.ensureInitialized()` and
`runApp` — both because their answers must exist by frame one. Two tests
enforce it:

- `test/notifications/notification_routing_test.dart` — "EXACTLY two awaits sit
  between binding initialization and runApp" counts them.
- `test/notifications/notification_bootstrap_test.dart` — "no zone load, no
  plugin initialization and no channel creation appears before the first frame"
  is a needle gate over the same window.

Neither await may throw out of `main()`: both are wrapped, reported to the
crash logger and degraded, because an escaping error there means `runApp` is
never called and the user stares at the launch screen forever.

### i18n

Seven locales ship: **en** (the template ARB, the only file carrying `@`
metadata, and the fallback), **ar**, **es**, **fr**, **hi**, **uk**, **zh** —
177 keys each. `preferred-supported-locales: [en]` in `l10n.yaml` is what makes
English `supportedLocales.first`; without that line gen-l10n sorts
alphabetically and the fallback moves the day an earlier-sorting ARB lands.

Adding a language is **one ARB file and no code change**. There is no
`switch (languageCode)` anywhere; the shipped set is derived from the arb
directory in every representation that names it.

Gates in `test/l10n/`, all on the everyday `flutter test`:

| Gate | File |
|---|---|
| Full ARB key parity; metadata in the template only; each language's required plural categories derived from CLDR through `Intl.pluralLogic(useExplicitNumberCases: false)` — Arabic needs all six, Chinese only `other` | `arb_parity_test.dart` |
| Rendered plural output at 1 / 2 / 5 / 11 / 21 | `plurals_test.dart` |
| Zero hardcoded user-visible strings in `lib/`: a widget-position gate plus a classification gate over every literal that still has two or more letters once `$interpolations` are stripped | `no_hardcoded_strings_test.dart` |
| One ARB and no code change: generated list == arb dir == the controller's allowlist == the picker's display names | `new_language_contract_test.dart` |
| System-locale resolution and the English fallback, asserted on rendered copy rather than on a `Locale` object | `locale_resolution_test.dart` |
| Casing goes through `bqUpperCase` (Turkish/Azeri dotted-i is the one documented exception to Dart's locale-independent default) | `casing_test.dart` |
| Ukrainian standalone vs format month names — every planner month stands without a day number, so all of them need the nominative | `month_names_test.dart` |
| Zero-padded 24-hour clock in every shipped locale, UI and notification body | `clock_format_test.dart` |
| No safety / interaction / pharmacological vocabulary, and no naming of a limit, threshold or verdict, in planner copy (uk + en) | `planner_copy_safety_test.dart` |
| The preferences store fails and the app still launches | `cold_start_degradation_test.dart` |

One clock formatter: `formatClock(context, minutes)` and
`formatClockIn(locale, minutes)` in `lib/core/l10n/clock_format.dart`. The
pattern `HH:mm` is **pinned, not asked of CLDR**: `alwaysUse24HourFormat` only
chooses between a locale's 12- and 24-hour patterns, and Spanish's 24-hour
pattern is `H:mm`, which printed `8:00` beside `08:00` in the same column. The
locale is still passed, so a language whose numbering system is not Latin
renders its own digits — the SHAPE is fixed, the script is not.

Int placeholders declare `"format": "decimalPattern"` in the template so a raw
`$count` cannot put ASCII digits next to `NumberFormat`-rendered Arabic-Indic
ones on the same screen.

### The release-only gate

```
flutter test test_release/
```

Run it before a production build. Nothing else runs it: `flutter test` with no
arguments reads `test/` only, so the sibling directory IS the mechanism — a
tag or a config filter could be switched off in one line. 41 tests: the
medical-vocabulary sweep across all seven languages, and every main screen in
all seven languages at text scales 1.0 / 1.6 / 2.0, with Arabic under real
locale-derived RTL (the only whole-screen RTL coverage in the repository).
Read `test_release/README.md` before touching it; in particular, never turn a
red cell green by dropping a language, a scale or a vocabulary stem.

### Platform config is asserted, not documented

`test/platform_config_test.dart` pins what nothing else can see: no manifest
variant opts out of OS backup, the Android main manifest declares **exactly**
`RECEIVE_BOOT_COMPLETED`, INTERNET is declared by `debug` and `profile` and by
nothing else, no variant declares an exact-alarm permission, both plugin
receivers are declared non-exported, core-library desugaring is on with its
runtime, the iOS notification-centre delegate is wired and `Info.plist` stays
bare. Its `release signing` group is what the old debug-keystore blocker turned
into once that was fixed on 2026-09-11: release builds must use the `release`
signing config, all four of its values must come from the gitignored
`android/key.properties`, a missing key.properties must FAIL a release build
rather than fall back, no password literal may appear in the Gradle file, and
`git ls-files` must not track the keystore or its passwords. Do not weaken it;
the original blocker survived for months precisely because nothing failed.

### Testing

The suite is **1108 tests in `test/` plus 46 in `test_release/`** (measured, not
estimated) and `flutter analyze` is clean. Keep both true.

- Widget tests run against a real in-memory Drift database behind the
  repository providers, seeded through the repositories before the tree pumps.
  `mocktail` is available and used sparingly; the real database is the house
  default.
- **Never `pumpAndSettle` a tree that holds a live timer** — the Today screen's
  minute ticker, `TodayController`'s midnight `Timer` (which the app shell
  keeps alive for the whole session), or Drift's retry backoff. It either hangs
  to `flutter_test`'s 10-minute timeout or waits out the backoff and passes for
  the wrong reason. Use a bounded loop instead: `pumpUntil(tester, condition,
  what)` or a fixed `for` of `tester.pump(const Duration(milliseconds: 10))`.
  `pumpAndSettle` survives in a handful of app-shell and navigation tests only
  because no such timer is mounted in those trees; that is not permission.
- **Never `await` a Drift stream subscription's `cancel()`** inside a
  `testWidgets` body — it deadlocks against the fake-async zone. The house form
  is `// ignore: unawaited_futures` then `sub.cancel();`, followed by a pump.
- **Never `await stream.first`** (or any un-pumped Drift future) inside
  `testWidgets`, for the same reason: observe pump-driven through a `listen`.
  Plain `test()` bodies are outside the fake-async zone and do await `.first`
  freely (`test/db/schedule_edit_reconcile_test.dart`).
- Tear down explicitly: pump an empty tree, pump, `container.dispose()`, pump
  twice more (`tearDownTree` in `test/features/today_screen_test.dart`). A
  pending midnight timer otherwise fails the test at teardown.
- **Seed `SharedPreferences` in any test that pumps `VitomyApp` or a screen
  that reads first-run state**:
  `SharedPreferences.setMockInitialValues({'onboarding_seen': true, ...})`
  (add `'first_run_hints_seen'` when the screen carries a hint) and override
  `sharedPreferencesProvider`. Forget it and the intro or a hint card appears
  in the middle of an unrelated assertion.
  `test/features/first_run_hints_test.dart` is the one suite that deliberately
  does NOT seed them away.
- A new screen gets its bilingual render matrix at textScaler 1.0 / 1.6 / 2.0
  in the same commit, not after — copy the group shape from
  `test/features/today_screen_test.dart`. Shared assertion helpers live in
  `test/support/locale_matrix.dart`, the single deliberate exception to this
  repo's self-contained-test house style.
- Source gates strip comments before scanning, so a comment naming a forbidden
  token cannot trip its own gate. Follow that when you write one.
- Derive the thing under test (glob the ARB dir, parse the template, probe
  CLDR) rather than hand-listing it. A hand-list goes stale silently, which is
  the exact failure mode these gates exist to prevent.

### Design and UI

Anything user-visible goes through the `vitomy-design` skill
(`.claude/skills/vitomy-design/SKILL.md`): token-only colour, ARB-only copy,
directional padding, the copy constraints that carry liability. Load it before
writing a widget.
<!-- GSD:conventions-end -->

<!-- GSD:architecture-start source:ARCHITECTURE.md -->

## Architecture

### Layout

```
lib/
  main.dart                  entrypoint: the two-await pre-runApp window, the provider
                             overrides, MaterialApp, and the onboarding gate as `home`
  app_shell.dart             bottom-nav shell (Стек / Сьогодні / Календар); Settings is a
                             PUSHED route behind the gear, never a destination
  core/
    domain/                  PURE Dart — models.dart, cycle_math.dart, and the three
                             repository INTERFACES in repositories.dart
    db/                      database.dart (Drift schema) + drift_repositories.dart
    providers.dart           the Riverpod graph: db, three repositories, the two streams,
                             the derived stack list, day materialization
    today_controller.dart    the app's single calendar clock (midnight Timer + resume)
    selected_tab_controller.dart
    l10n/                    arb/ (7 files), gen/ (generated — never hand-edit),
                             l10n.dart, locale_controller.dart, clock_format.dart,
                             casing.dart
    theme/                   tokens.dart (the ONLY file with hex literals) + theme.dart
    widgets/                 BqNavBar, BqAddFab, BqSegmented, BqSettingsGearRow, BqHintCard
    notifications/           plan, scheduler, service, sync, copy, permission, locale
                             observer, tz conversion, providers
  features/
    stack/                   stack list, add-supplement sheet, catalog, regimen editor
    calendar/                today screen, week strip, dose row/sheet, and the planner
                             (gantt, year grid, load chart, week/month detail)
    onboarding/              two-page intro + gate, one-time contextual hints
    settings/                settings screen, language picker
```

**Dependency rule:** `features/` may import `core/`; `core/` may never import
`features/`. `todayProvider` lives in `core/` precisely because two features
consume it. UI and state code depend only on the interfaces in
`core/domain/repositories.dart`; the Drift implementations are wired in
`core/providers.dart` and nowhere else, which is what keeps a future backend
possible without touching a screen.

### Data flow

One direction, no imperative refresh anywhere:

```
Drift watch*() streams
  → SupplementRepository / RegimenRepository / IntakeRepository (interfaces)
    → supplementsStreamProvider, regimensStreamProvider
      → derived providers (stackEntriesProvider, dayDosesProvider, the planner
        window providers)
        → widgets
```

A regimen add / edit / pause / resume / delete re-emits on the regimens stream,
and every dependent re-runs — including the day materialization, so the day
rebuilds itself.

### Persistence contract (sync-ready)

Every table mixes in `SyncColumns`: a TEXT UUID primary key generated by the
repository (`Uuid().v4()`, never a database default), `createdAt` / `updatedAt`
true-UTC instants supplied explicitly by the writer, and a nullable `deletedAt`
for soft deletes. No auto-increment keys, no hard deletes. Every list query
orders by `createdAt` ascending with `id` as the lexicographic tiebreak — the
same rule that is already documented as the future last-write-wins sync
tiebreak. The schema is versioned under `drift_schemas/`. The database opens
through `drift_flutter`'s `driftDatabase(name:)` so it lands in the OS-backed
application-documents directory; that placement is what DATA-02's
"survives a reinstall via device backup" guarantee rests on, and
`test/platform_config_test.dart` asserts it.

### Materialization

`dayDosesProvider` is the single choke point: the ONLY production caller of
`ensureLogsForDay` (an idempotent insert-or-ignore, so re-running it on every
rebuild is free) and the only consumer of `watchDay`. `dayDosesReadOnlyProvider`
exists so the week strip's 4px dot can read the same rows without creating
them — reading that dot through the materializing provider once made a cosmetic
detail the app's biggest writer, growing the database with pager travel rather
than with user intent.

### Notifications

Local only. No network client, no serialization package, no endpoint anywhere
in the app — the release manifest carries no INTERNET permission and
`test/platform_config_test.dart` keeps it that way. `main()` reads the launch
payload before the first frame and does nothing else notification-shaped; the
timezone database load, the plugin's `initialize()` and the channel creation all
sit behind the first frame, started by `notificationBootstrapProvider`.
`VitomyApp` watches that provider and `notificationSyncProvider` purely to
keep them alive — an unlistened provider is PAUSED in this Riverpod version, so
without the watch production would silently schedule nothing with every test
still green. Scheduling uses `inexactAllowWhileIdle`: no exact-alarm
permission, roughly 10–15 minutes of doze jitter accepted as a stated cost,
which is why the reminder body restates the scheduled time.

### Locale resolution

`MaterialApp` resolves the locale from `AppLocalizations.supportedLocales`; the
app deliberately passes **no** `localeResolutionCallback` (a hand-rolled one
sees only the first entry of the device's ordered preference list).
`localeControllerProvider` supplies the manual override, seeded synchronously
so a stored language is on frame one. `NotificationLocaleObserver` sits in
`MaterialApp.builder` — inside the localizations it observes and wrapping every
route — so notification copy is built in the locale the UI is ACTUALLY
rendering, observed rather than re-derived.

### Design system

The visual language is transcribed from the approved mockup
(`claude_design_mockup/VitoMy v0.1.dc.html`) into `lib/core/theme/tokens.dart`,
which is the only file in the app permitted a hex literal; `theme.dart` is built
exclusively from it. The full set of rules — including the ones a test enforces
— is the `vitomy-design` skill.
<!-- GSD:architecture-end -->

<!-- GSD:skills-start source:skills/ -->

## Project Skills

- **vitomy-design** (`.claude/skills/vitomy-design/SKILL.md`) — the design
  system, the machine-enforced UI rules, and the copy constraints that carry
  liability. Load it before writing or editing ANY user-visible Flutter UI.
<!-- GSD:skills-end -->

<!-- GSD:workflow-start source:GSD defaults -->

## GSD Workflow Enforcement

Before using Edit, Write, or other file-changing tools, start work through a GSD command so planning artifacts and execution context stay in sync.

Use these entry points:

- `/gsd-quick` for small fixes, doc updates, and ad-hoc tasks
- `/gsd-debug` for investigation and bug fixing
- `/gsd-execute-phase` for planned phase work

Do not make direct repo edits outside a GSD workflow unless the user explicitly asks to bypass it.
<!-- GSD:workflow-end -->

<!-- GSD:profile-start -->

## Developer Profile

> Profile not yet configured. Run `/gsd-profile-user` to generate your developer profile.
> This section is managed by `generate-claude-profile` -- do not edit manually.
<!-- GSD:profile-end -->
