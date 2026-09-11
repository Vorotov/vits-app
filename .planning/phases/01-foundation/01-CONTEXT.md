# Phase 1: Foundation - Context

**Gathered:** 2026-08-14
**Status:** Ready for planning
**Source:** PRD Express Path (docs/superpowers/specs/2026-08-14-vitomy-v1-design.md)

<domain>
## Phase Boundary

A themed, localized, three-tab app shell (Stack / Calendar / Settings) running on iOS and Android over a local, sync-ready Drift database, fully offline, with DST-safe cycle math implemented and unit-tested before any screen consumes it. No feature screens yet — Phases 2–5 build those on this foundation. Covers DATA-01, DATA-02.

</domain>

<decisions>
## Implementation Decisions

### Project scaffold
- Flutter project at the repo root: `flutter create --project-name vitomy --org app.vitomy --platforms ios,android .`
- Bundle id placeholder `app.vitomy` on both platforms (final id is a pre-release open item)
- Android targetSdk 36 (SDK 36 already installed; Play deadline 2026-08-31)
- Toolchain (CocoaPods, JDK, Android SDK 36) is ALREADY installed — `flutter doctor` is green; do not re-plan environment setup

### Dependencies (versions verified on pub.dev 2026-08-14)
- flutter_riverpod ^3.4.2, drift ^2.34.3, drift_flutter ^0.3.1, uuid ^4.6.0, shared_preferences ^2.5.5
- dev: drift_dev ^2.34.5, build_runner ^2.16.0, flutter_lints, mocktail (NOT mockito — avoids extra codegen)
- Do NOT add sqlite3_flutter_libs (bundled by Drift ≥2.32); do NOT hand-pin intl (let flutter_localizations resolve it)
- Do NOT use google_fonts (runtime HTTP fetch is wrong for offline app) — bundle Instrument Sans (400/500/600/700) and JetBrains Mono (400/500) as local .ttf assets declared in pubspec `fonts:`

### Design tokens & theme (from claude_design_mockup/VitoMy v0.1.dc.html)
- Single tokens file `lib/core/theme/tokens.dart` + `bqTheme()` in `lib/core/theme/theme.dart`
- Palette: canvas #EAE9E4, paper #F7F6F3 (scaffold bg), surface #FFFFFF, surfaceAlt #FBFBF9, chip #F2F1EE, field #E4E3DD, ink #17171B, textSecondary #5C5C66, textMuted #8E8E99, textFaint #A0A0A9, accent #4A4E7C, accentPressed #3D4169, accentChipBg #EDEDF4, calm #3F7A6A/#E8F1ED, warn #B07A22/#FAF1E0, risk #A8443C/#F8EBE8
- Series palette for supplement color tags: B08A2A, 2F3457, 3F7A6A, 6B6FA8, C4685E, 2F7A85, C07A3A, 4A4E7C
- Radii: card 14, panel 16, button 12, chip 5, segmented control 10
- All later UI uses ONLY these tokens

### i18n infrastructure
- gen-l10n with l10n.yaml: arb-dir `lib/core/l10n/arb`, template `app_en.arb`, output-dir `lib/core/l10n/gen`, synthetic-package false, nullable-getter false
- Ship `app_en.arb` + `app_uk.arb` seeded with shell strings (tab labels, app title) and plural exemplars (`substancesCount`, `weeksCount`) using ALL FOUR uk CLDR forms (one/few/many/other incl. 11–14 exception); unit-test counts 1, 2, 5, 11, 21
- LocaleController (Riverpod Notifier, SharedPreferences key `app_locale`): null = follow system; MaterialApp resolves system uk/en with English fallback
- `context.l10n` extension; zero hardcoded user-visible strings; EdgeInsetsDirectional for horizontal padding; no fixed-width text containers

### Domain layer (pure Dart, lib/core/domain/)
- Models: Supplement, Regimen (kind cyclic|course, startDate, endDate?, onDays, offDays, paused, slots), DoseSlot (minutesFromMidnight, doseLabel), enums RegimenKind/DoseStatus
- `dateOnly()` normalizes to `DateTime.utc(y,m,d)`; NEVER local midnight; never DateTime.now() inside domain functions
- `isActiveOn(Regimen, DateTime)`: paused→false; before start→false; course→inclusive end; cyclic→(day−start) % (on+off) < on; off=0 → always on
- Time types stay separate: date-only UTC (calendar day) vs minutesFromMidnight (wall clock) vs createdAt/updatedAt (true UTC instants)
- EXIT CRITERION: unit tests prove correct active/inactive days across a DST transition AND a year boundary

### Database (Drift, lib/core/db/)
- Tables: Supplements, Regimens, RegimenSlots, IntakeLogs; SyncColumns mixin on every table: TEXT UUID id PK, createdAt, updatedAt, deletedAt nullable (soft delete)
- IntakeLogs unique key (slotId, date); date stored as UTC-midnight DateTime; status int = DoseStatus.index
- `VitomyDb.forTesting(NativeDatabase.memory())` + `VitomyDb.open()` via driftDatabase(name: 'vitomy')
- Export drift schema snapshot (`drift_schema_v1.json`) at schema version 1 — migration discipline starts now
- Verify DB file lives in default app-documents location included in OS backups (DATA-02); document this in code comment
- Repository interfaces (SupplementRepository, RegimenRepository, IntakeRepository) in core/domain; Drift implementations in core/db; `ensureLogsForDay` idempotent materialization; StackEntry/DayDose view models; Riverpod providers in core/providers.dart
- Riverpod policy decided once here: repository-level StreamProviders NOT autoDispose; screen-scoped state may be autoDispose; document in providers file

### App shell
- `AppShell` with IndexedStack + NavigationBar: three tabs Stack/Calendar/Settings (stub screens with localized headers, mockup header style: 25px w600 letterSpacing −0.5)
- Tab bar styling per mockup: surfaceAlt background, accent selected, textFaint unselected
- No network permission anywhere; no accounts/login

### Testing
- flutter_test; in-memory Drift for repo tests; widget test proves shell renders localized tab labels in en and uk
- `flutter analyze` clean and `flutter test` green are phase exit criteria

### Claude's Discretion
- Exact file organization inside features/ stubs, icon choices for tabs, minor widget structure
- How to source .ttf files (download from Google Fonts GitHub/fontsource at build-prep time, commit into assets/fonts/)
- Wave decomposition for parallel execution

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Design & spec
- `docs/superpowers/specs/2026-08-14-vitomy-v1-design.md` — approved v1 design spec (architecture, data model, i18n, testing)
- `docs/superpowers/plans/2026-08-14-vitomy-v1.md` — approved task-level implementation plan; Tasks 1–7 map to this phase (Task 0 toolchain DONE; ignore its google_fonts references — superseded by bundled fonts decision)
- `claude_design_mockup/VitoMy v0.1.dc.html` — authoritative visual design (palette, typography, 5 screens)

### Research
- `.planning/research/STACK.md` — verified package versions and what NOT to use
- `.planning/research/ARCHITECTURE.md` — component boundaries, Riverpod/Drift patterns, time-type separation
- `.planning/research/PITFALLS.md` — DST math, Drift migrations, autoDispose, uk plurals, release gates

</canonical_refs>

<specifics>
## Specific Ideas

- Mockup fonts: Instrument Sans weights 400/500/600/700; JetBrains Mono 400/500 (from mockup CSS Google Fonts URL)
- Plural test exemplars: uk — 1 речовина / 2 речовини / 5 речовин / 11 речовин / 21 речовина; 21 тиждень
- Cycle math test exemplars: cyclic 56on/28off from 2026-08-14 → day 55 active, day 56–83 off, day 84 active; course end 2026-09-30 inclusive; cycle crossing 2026→2027 year boundary

</specifics>

<deferred>
## Deferred Ideas

- Feature screens (Stack, Calendar, planners, regimen editor) — Phases 2–4
- Full-app localization verification and language picker — Phase 5
- Notifications, widgets, export, sync — post-v1 (REQUIREMENTS.md v2)

</deferred>

---

*Phase: 01-foundation*
*Context gathered: 2026-08-14 via PRD Express Path*
