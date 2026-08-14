# Requirements: Boostque

**Defined:** 2026-08-14
**Core Value:** A user can see exactly what to take today and check it off, with cycles and breaks computed correctly — the daily loop of plan → see → mark taken must always work.

## v1 Requirements

Requirements for initial release. Each maps to roadmap phases.

### Stack Management

- [ ] **STACK-01**: User can add a supplement from a bundled, locale-aware catalog by searching its name
- [ ] **STACK-02**: User can add a supplement manually with a name and dose description
- [ ] **STACK-03**: User can view their stack as cards showing name, dose, color tag, status (active/paused/planned) and schedule summary
- [ ] **STACK-04**: User can edit and delete a supplement; deleting removes its regimen and future doses (soft delete in DB)

### Regimen Scheduling

- [ ] **REGI-01**: User can configure a cyclic regimen: start date, on-days and off-days (7-day steps, per mockup sliders), repeating until turned off
- [ ] **REGI-02**: User can configure a one-time course with start and end dates (end inclusive)
- [ ] **REGI-03**: User can define 1–6 daily time slots, each with its own time and dose label
- [ ] **REGI-04**: User can pause and resume a regimen; paused regimens produce no doses and show ПАУЗА status

### Daily Tracking

- [ ] **TRACK-01**: User sees today's doses grouped by time blocks (morning/day/evening/night) with a day-progress ring
- [ ] **TRACK-02**: User can mark a dose taken or skipped with one tap and can undo the mark
- [ ] **TRACK-03**: User can browse past and current week days; unmarked past doses render as "missed" — computed in the view (DB row stays pending), presented neutrally, never guilt-framed
- [ ] **TRACK-04**: Doses appear only on days a regimen's cycle is active — correct across DST transitions and year boundaries (UTC date-only math, unit-tested)

### Planner Views

- [ ] **PLAN-01**: User can view a Cycles gantt (~4-month window): one row per supplement, solid segments for active periods, hatched/lighter for planned, with a today marker
- [ ] **PLAN-02**: User can view a weekly concurrent-load chart with the editorial 5-substance limit, tap a week for details (load, verdict, active supplements)
- [ ] **PLAN-03**: User can view a Year matrix: 12 month cards with per-supplement coverage bars (lighter = planned), tap a month for details
- [ ] **PLAN-04**: Planner screens carry the educational disclaimer and frame the 5-substance limit as editorial, not medical

### Localization

- [ ] **L10N-01**: App ships in Ukrainian and English with correct plural forms (uk uses all CLDR forms: one/few/many/other, incl. 11–14 exception)
- [ ] **L10N-02**: App follows the system language when supported, falling back to English
- [ ] **L10N-03**: User can override the language in Settings; the change applies instantly and persists across restarts
- [ ] **L10N-04**: All dates, month names and numbers are locale-formatted; zero hardcoded user-visible strings (new languages = one ARB file)

### Data & Platform

- [ ] **DATA-01**: All data is stored locally on device; the app is fully functional offline with no accounts
- [ ] **DATA-02**: Schema is sync-ready (UUID PKs, createdAt/updatedAt, soft deletes) and the database is included in OS-level backups by default
- [ ] **DATA-03**: App builds and runs the full loop on both iOS (simulator/device) and Android (targetSdk 36)

## v2 Requirements

Deferred to future release. Tracked but not in current roadmap.

### Reminders & Surfaces

- **NOTF-01**: User receives local notifications for scheduled doses (first post-v1 priority — materialized IntakeLog rows make this cheap)
- **WIDG-01**: User can see today's doses on a home-screen widget (iOS WidgetKit / Android widget)

### Insight & Data

- **HIST-01**: User can view full dose history and cycle-aware adherence (streaks that never penalize off-weeks)
- **EXPT-01**: User can export/import their data (JSON/CSV) — early fast-follow; mitigates local-only data-loss risk

### Growth

- **SCAN-01**: User can add a supplement by scanning its label (camera/OCR)
- **SYNC-01**: User can sync data across devices (accounts + backend; LWW on existing timestamps)
- **ADVI-01**: Advisor tab with properly-sourced interaction data (never a naive version)
- **MONE-01**: Boostque Plus subscription

## Out of Scope

Explicitly excluded. Documented to prevent scope creep.

| Feature | Reason |
|---------|--------|
| Naive/partial interaction checking | High liability; research verdict: never ship a lightweight version |
| Caregiver / "med-friend" alerts | Audience mismatch for supplement stackers; not recommended even long-term |
| Social sharing of health data | Privacy risk, no user value for this product |
| Guilt-based streaks / aggressive reminders | Documented alert-fatigue and uninstall driver; conflicts with cycle-off weeks |
| Auto-adjusting "smart" reminders | Opaque behavior erodes trust |
| Onboarding flow, quality scores | Mockup v0.1 explicitly excludes; revisit post-v1 |
| Treating the 5-substance limit as a safety threshold | It is an editorial tracking-comfort rule; presenting it as medical invites store-review and liability problems |

## Decisions Locked During Definition

- **Missed semantics (research gap closed):** an unmarked dose is displayed as "missed" when its date is strictly before today (device-local calendar day); the IntakeLog row itself stays `pending` — no schema change, no migration risk, and future streak features can reinterpret freely.
- **Backup/export:** v1 keeps OS-default backup inclusion ON (verified in DB phase); manual export is tracked as EXPT-01, an early v1.x fast-follow.

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| (populated by roadmap) | | |

**Coverage:**
- v1 requirements: 22 total
- Mapped to phases: 0
- Unmapped: 22 ⚠️ (pending roadmap)

---
*Requirements defined: 2026-08-14*
*Last updated: 2026-08-14 after initial definition*
