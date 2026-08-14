# Boostque v1 — Design Spec

**Date:** 2026-08-14
**Status:** Approved scope, pending final spec review

## What we're building

Boostque is a supplement stack planner and tracker for iOS and Android. The
user defines their supplement stack, schedules doses (including week-based
on/off cycles), and tracks intake in a calendar with Day / Cycles / Year
views. The visual design already exists as an HTML mockup in
`claude_design_mockup/`.

## Decisions made

| Decision | Choice |
|---|---|
| Framework | Flutter + Dart, single codebase for iOS and Android |
| v1 scope | Stack tab + Calendar tab only |
| Data | Local-only, on device; no accounts, no backend |
| Languages | Full i18n from day one: system-language detection plus an in-app language picker. Ships with Ukrainian and English; architecture supports adding any number of languages later by adding one translation file each |

**Out of scope for v1** (planned for later, kept in mind architecturally):
Advisor tab (Радник), camera label scanning, home-screen widgets, dose
reminders/notifications, cloud sync/backup, Boostque Plus monetization.
Widgets and notifications influence one v1 choice: dose occurrences are
materialized in the database (see Data model) so a future widget or
notification scheduler can read "today's doses" without running app logic.

## Architecture

- **State management:** Riverpod.
- **Database:** Drift (typed, reactive SQLite). Calendar screens subscribe to
  queries and re-render automatically on data changes.
- **Structure:** feature-first.

```
lib/
  core/
    db/          # Drift database, tables, DAOs
    l10n/        # generated localizations (gen-l10n), locale controller
    theme/       # design tokens + ThemeData from the mockup
    domain/      # pure Dart: cycle math, dose generation (no UI, no DB imports)
  features/
    stack/       # supplement list, add/edit supplement + regimen
    calendar/    # Day / Cycles / Year views, mark-as-taken
    settings/    # language picker (grows later: profile, export, etc.)
  app.dart       # MaterialApp, routing, locale resolution
  main.dart
```

Each feature contains its own screens, providers, and view logic. `core/domain`
is the most bug-prone logic (cycle math) and is kept pure Dart so it is
trivially unit-testable.

## Data model

Three tables; all calendar views are computed projections, never stored.

- **Supplement** — name, dose amount, dose unit, color tag (mockup legend
  colors), optional notes.
- **Regimen** — belongs to a supplement: list of times of day, cycle rule:
  either *continuous* ("постійно, без циклів") or *cycled* — start date,
  weeks on, weeks off, number of repeats (renders like "Т27–44 · цикл 2/2").
- **IntakeLog** — one row per dose occurrence: regimen id, date, time,
  status (pending / taken / skipped). Rows are generated ahead for the near
  horizon and lazily for browsed dates.

Cycle math (which ISO weeks each regimen is active, which doses fall on a
given day) lives in `core/domain` as pure functions.

## Localization

- Flutter's official **gen-l10n** with ARB files: `app_uk.arb`, `app_en.arb`.
  Zero hardcoded user-visible strings anywhere — enforced from the first
  commit. A new language = one new `.arb` file, no code changes.
- ICU plural rules in ARB handle Ukrainian's three plural forms
  (1 речовина / 2 речовини / 5 речовин) correctly.
- Locale resolution: follow system language when supported; otherwise fall
  back to English. A settings-screen language picker stores a manual
  override locally and switches the app instantly.
- All dates, month names, week ranges, and numbers are formatted via `intl`
  with the active locale — never hand-built strings.
- Layout rules: no fixed-width text containers (translations change length);
  direction-neutral padding (`EdgeInsetsDirectional`) so a future RTL
  language works without rework.

## Design port

The mockup's palette, typography (Instrument Sans, JetBrains Mono — bundled
as assets), spacing, and corner radii become a single design-tokens file
feeding one `ThemeData`. Screens are rebuilt in Flutter widgets to match the
mockup visually.

## Testing

- **Unit tests (the bulk):** cycle math and dose generation in
  `core/domain` — week-range activation, repeats, edge cases around year
  boundaries and DST; plural forms for both shipped locales.
- **Widget tests:** Stack list flow (add/edit supplement), Day view flow
  (mark dose as taken).
- UI fidelity is checked visually against the mockup.

## Environment

Development on macOS. Xcode 26.5 already installed. Flutter SDK via
Homebrew; CocoaPods, Java (Temurin), and Android command-line tools to be
installed during setup.
