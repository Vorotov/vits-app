<!-- GSD:project-start source:PROJECT.md -->

## Project

**Boostque**

Boostque is a mobile supplement stack planner and tracker for iOS and Android, built as a single Flutter codebase. Users define the supplements they take, schedule doses — including week-based on/off cycles and one-time courses — and track intake in a calendar with Today, Cycles, and Year views. The visual design exists as an approved HTML mockup (`claude_design_mockup/Boostque v0.1.dc.html`, 5 screens, Ukrainian-first).

**Core Value:** A user can see exactly what to take today and check it off, with cycles and breaks computed correctly — the daily loop of plan → see → mark taken must always work.

### Constraints

- **Tech stack**: Flutter + Dart single codebase — decided after comparing with React Native/Expo; user's explicit choice
- **State/DB**: Riverpod + Drift (SQLite) — reactive typed queries feed calendar views
- **Architecture**: UI depends on repository interfaces only (`SupplementRepository`/`RegimenRepository`/`IntakeRepository`); Drift is one implementation — keeps future backend/sync possible without touching screens
- **Sync-ready data**: UUID primary keys, createdAt/updatedAt, soft deletes on every table
- **i18n**: gen-l10n with ARB files; zero hardcoded user-visible strings; ICU plurals (Ukrainian one/few/many); locale-aware date/number formatting; no fixed-width text containers; direction-neutral padding (RTL-ready)
- **Dates**: date-only values normalized as `DateTime.utc(y,m,d)` — DST safety for cycle math
- **Bundle id**: placeholder `com.boostque.dev` — final app name and bundle id must be decided before first store release

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

Conventions not yet established. Will populate as patterns emerge during development.
<!-- GSD:conventions-end -->

<!-- GSD:architecture-start source:ARCHITECTURE.md -->

## Architecture

Architecture not yet mapped. Follow existing patterns found in the codebase.
<!-- GSD:architecture-end -->

<!-- GSD:skills-start source:skills/ -->

## Project Skills

No project skills found. Add skills to any of: `.claude/skills/`, `.agents/skills/`, `.cursor/skills/`, `.github/skills/`, or `.codex/skills/` with a `SKILL.md` index file.
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
