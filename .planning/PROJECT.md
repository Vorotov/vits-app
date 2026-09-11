# VitoMy

## What This Is

VitoMy is a mobile supplement stack planner and tracker for iOS and Android, built as a single Flutter codebase. Users define the supplements they take, schedule doses — including week-based on/off cycles and one-time courses — and track intake in a calendar with Today, Cycles, and Year views. The visual design exists as an approved HTML mockup (`claude_design_mockup/VitoMy v0.1.dc.html`, 5 screens, Ukrainian-first).

## Core Value

A user can see exactly what to take today and check it off, with cycles and breaks computed correctly — the daily loop of plan → see → mark taken must always work.

## Requirements

### Validated

(None yet — ship to validate)

### Active

- [ ] User can manage their supplement stack (add from bundled catalog or manually, edit, delete)
- [ ] User can configure a dosing regimen per supplement: cyclic (on-days/off-days) or one-time course, with multiple time slots per day, pause/resume
- [ ] User sees today's doses grouped by time and can mark each taken/skipped, with day progress
- [ ] User can browse a Cycles planner (gantt of regimens over ~4 months, weekly concurrent-load chart, week detail)
- [ ] User can browse a Year planner (12-month matrix of regimen coverage, month detail)
- [ ] App ships in Ukrainian and English: system-language detection plus in-app language picker; architecture supports adding languages by adding one translation file
- [ ] All data stored locally on device (no accounts, no network)

### Out of Scope

- Advisor tab (Радник) — future version; mockup v0.1 explicitly excludes it
- Camera label scanning / OCR — future version
- Home-screen widgets & dose notifications — future version; v1 materializes dose rows in DB so these can be added without schema change
- Cloud sync / accounts / backend — future version; v1 architecture is backend-ready (repositories, UUIDs, timestamps, soft deletes) but ships local-only
- Interactions/risk scoring, quality scores — excluded by mockup v0.1 assumptions
- Monetization (VitoMy Plus, free-plan limits) — future version
- Onboarding flow — future version

## Context

- Repo root is the Flutter project home; currently contains the design mockup (`claude_design_mockup/`) and approved planning docs.
- **Authoritative design:** `claude_design_mockup/VitoMy v0.1.dc.html` — palette (accent #4A4E7C indigo, paper #F7F6F3, ink #17171B, calm/warn/risk #3F7A6A/#B07A22/#A8443C), fonts Instrument Sans + JetBrains Mono, 5 screens: My Stack, Calendar/Today, Planner Cycles, Planner Year, Dosing Schedule editor.
- **Approved design spec:** `docs/superpowers/specs/2026-08-14-vitomy-v1-design.md`
- **Approved task-level implementation plan:** `docs/superpowers/plans/2026-08-14-vitomy-v1.md` (14 tasks, TDD, exact interfaces) — planning agents should treat it as strong input.
- Copy vocabulary (from mockup): цикл, перерва, слот, прийнято, одночасно; never promise health effects; every screen with recommendations carries "educational material, not medical advice" disclaimer.
- Dev machine: macOS, Xcode 26.5 installed, Flutter 3.47.0/Dart 3.13 installed via Homebrew; CocoaPods/Java/Android SDK still to install (plan Task 0).

## Constraints

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

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Flutter over React Native/Expo | User preference after trade-off discussion (pixel-consistent rendering, cohesive toolchain) | — Pending |
| Local-only v1, backend-ready architecture | Ship fast without server costs; repositories + sync-ready columns keep the door open | — Pending |
| Mockup v0.1 (not the larger v1 file) is authoritative | User choice; v0.1 scope matches v1 exactly | — Pending |
| Dose occurrences materialized as DB rows | Future widgets/notifications read "today's doses" without running app logic | — Pending |
| Multi-language from day one (uk + en, extensible) | User requirement; retrofitting i18n is far costlier than starting with it | — Pending |
| 5-substance concurrent limit is editorial, not medical | From mockup copy; shown with disclaimer | — Pending |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd-transition`):
1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to log? → Add to Key Decisions
5. "What This Is" still accurate? → Update if drifted

**After each milestone** (via `/gsd-complete-milestone`):
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-08-14 after initialization*
