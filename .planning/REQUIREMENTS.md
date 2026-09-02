# Requirements: Boostque

**Defined:** 2026-08-14
**Core Value:** A user can see exactly what to take today and check it off, with cycles and breaks computed correctly — the daily loop of plan → see → mark taken must always work.

## v1 Requirements

Requirements for initial release. Each maps to roadmap phases.

### Stack Management

- [x] **STACK-01**: User can add a supplement from a bundled, locale-aware catalog by searching its name
- [x] **STACK-02**: User can add a supplement manually with a name and dose description
- [x] **STACK-03**: User can view their stack as cards showing name, dose, color tag, status (active/paused/planned) and schedule summary
- [x] **STACK-04**: User can edit and delete a supplement; deleting removes its regimen and future doses (soft delete in DB)

### Regimen Scheduling

- [x] **REGI-01**: User can configure a cyclic regimen: start date, on-days and off-days (7-day steps, per mockup sliders), repeating until turned off
- [x] **REGI-02**: User can configure a one-time course with start and end dates (end inclusive)
- [x] **REGI-03**: User can define 1–6 daily time slots, each with its own time and dose label
- [x] **REGI-04**: User can pause and resume a regimen; paused regimens produce no doses and show ПАУЗА status

### Daily Tracking

- [x] **TRACK-01**: User sees today's doses grouped by time blocks (morning/day/evening/night) with a day-progress ring
- [x] **TRACK-02**: User can mark a dose taken or skipped with one tap and can undo the mark
- [x] **TRACK-03**: User can browse past and current week days; unmarked past doses render as "missed" — computed in the view (DB row stays pending), presented neutrally, never guilt-framed
- [x] **TRACK-04**: Doses appear only on days a regimen's cycle is active — correct across DST transitions and year boundaries (UTC date-only math, unit-tested)

### Planner Views

- [x] **PLAN-01**: User can view a Cycles gantt (~4-month window): one row per supplement, solid segments for active periods, hatched/lighter for planned, with a today marker
- [x] **PLAN-02**: User can view a weekly concurrent-load chart with the editorial 5-substance limit, tap a week for details (load, verdict, active supplements)
- [x] **PLAN-03**: User can view a Year matrix: 12 month cards with per-supplement coverage bars (lighter = planned), tap a month for details
- [x] **PLAN-04**: Planner screens carry the educational disclaimer and frame the 5-substance limit as editorial, not medical

### Localization

- [x] **L10N-01**: App ships in Ukrainian and English with correct plural forms (uk uses all CLDR forms: one/few/many/other, incl. 11–14 exception)
- [x] **L10N-02**: App follows the system language when supported, falling back to English
- [x] **L10N-03**: User can override the language in Settings; the change applies instantly and persists across restarts
- [x] **L10N-04**: All dates, month names and numbers are locale-formatted; zero hardcoded user-visible strings (new languages = one ARB file)

### Data & Platform

- [x] **DATA-01**: All data is stored locally on device; the app is fully functional offline with no accounts
- [x] **DATA-02**: Schema is sync-ready (UUID PKs, createdAt/updatedAt, soft deletes) and the database is included in OS-level backups by default
- [x] **DATA-03**: App builds and runs the full loop on both iOS (simulator/device) and Android (targetSdk 36)

## v2 Requirements

Deferred to future release. Tracked but not in current roadmap.

### Scheduling

- **FREQ-01**: User can schedule a dose on a weekly rhythm — specific weekdays ("Mon/Thu") or N times per week — not only every day of an on-week. Today `Regimen` is day-granular (`onDays`/`offDays` counted in days) and every on-day fires every `DoseSlot`, so "twice a week" cannot be expressed at all. Needs a new field on `Regimen`, a `cycle_math` change, and an editor control; the Cycles gantt and Year matrix both read off the same math and would follow for free.

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
| Quality scores | Mockup v0.1 explicitly excludes (this row originally also covered the onboarding flow; that half was revisited 2026-08-26 per the spec `docs/superpowers/specs/2026-08-26-boostque-onboarding-design.md` and shipped as ONBO-01..05 in v1.2 — quality scores stay out) |
| Treating the 5-substance limit as a safety threshold | It is an editorial tracking-comfort rule; presenting it as medical invites store-review and liability problems |

## Decisions Locked During Definition

- **Missed semantics (research gap closed):** an unmarked dose is displayed as "missed" when its date is strictly before today (device-local calendar day); the IntakeLog row itself stays `pending` — no schema change, no migration risk, and future streak features can reinterpret freely.
- **Backup/export:** v1 keeps OS-default backup inclusion ON (verified in DB phase); manual export is tracked as EXPT-01, an early v1.x fast-follow.

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| DATA-01 | Phase 1 | Complete |
| DATA-02 | Phase 1 | Complete |
| STACK-01 | Phase 2 | Complete |
| STACK-02 | Phase 2 | Complete |
| STACK-03 | Phase 2 | Complete |
| STACK-04 | Phase 2 | Complete |
| REGI-01 | Phase 2 | Complete |
| REGI-02 | Phase 2 | Complete |
| REGI-03 | Phase 2 | Complete |
| REGI-04 | Phase 2 | Complete |
| TRACK-01 | Phase 3 | Complete |
| TRACK-02 | Phase 3 | Complete |
| TRACK-03 | Phase 3 | Complete |
| TRACK-04 | Phase 3 | Complete |
| DATA-03 | Phase 3 | Complete |
| PLAN-01 | Phase 4 | Complete |
| PLAN-02 | Phase 4 | Complete |
| PLAN-03 | Phase 4 | Complete |
| PLAN-04 | Phase 4 | Complete |
| L10N-01 | Phase 5 | Complete |
| L10N-02 | Phase 5 | Complete |
| L10N-03 | Phase 5 | Complete |
| L10N-04 | Phase 5 | Complete |

**Coverage:**

- v1 requirements: 23 total (corrected from the earlier "22 total" count in this file — the enumerated IDs across all six categories total 23)
- Mapped to phases: 23
- Unmapped: 0 ✓

---
*Requirements defined: 2026-08-14*
*Last updated: 2026-08-14 after roadmap creation — full traceability mapped across 5 phases*


---

# Milestone v1.1 — Navigation, Notifications, Simplification

Source: `docs/superpowers/specs/2026-08-17-boostque-v1.1-design.md` (approved 2026-08-17).
Requested after the first hands-on session with the shipped v1 build.

## Navigation (NAV)

- [x] **NAV-01** — Bottom navigation is a slim custom bar (56dp base height, down from Material's fixed 80dp) whose height scales with the text scaler and never clips at 1.0/1.6/2.0
- [x] **NAV-02** — Three tabs: Стек, Сьогодні (today's doses plus week-strip browsing of recent days), Календар (the Цикли/Рік planner)
- [x] **NAV-03** — Settings is reachable from a top-right control on all three tabs and is no longer a tab; the v1 in-tab planner page-swap mechanism is removed

## Notifications (NOTIF)

- [ ] **NOTIF-01** — The user is reminded at each scheduled dose time, grouped one notification per time-of-day, only on days the regimen is active; tapping opens Сьогодні
- [ ] **NOTIF-02** — Reminders respect platform constraints: no exact-alarm permission on Android (inexact, policy-compliant), and scheduling stays within the iOS 64-request pending cap via the repeating/horizon two-tier plan
- [ ] **NOTIF-03** — Permission is requested at first regimen save, never at launch; the app is fully usable and silent when permission is denied
- [ ] **NOTIF-05** — Settings shows whether reminders are allowed and offers a control that opens the OS notification settings — the only recovery path after an iOS denial (owner decision 2026-08-17, DECIDED-9a; no magnitude, no toggle, no priming sheet)
- [ ] **NOTIF-04** — Reminders re-derive whenever regimens change (create/edit/pause/delete), on app resume, and remain correct across midnight and DST transitions

All five are **implemented and merged** — Phase 7's six plans executed on
2026-08-17 and the code, the pure plan and its gates live in `lib/notifications/`
and `test/notifications/`. The boxes stay open because what would close them is a
device pass that is not finished: Android's automated half is green (the OS was
observed holding a request the app derived), the iOS half is blocked on a human
tapping **Allow**, and the delivery entries have not been run. See
`.planning/phases/07-dose-reminders/07-UAT.md`.

## Experience (UX)

- [x] **UX-01** — A floating add-supplement button appears on all three tabs and nowhere else; the Stack screen's full-width add button is removed and its empty state repointed

## Planner (PLAN, continued)

- [x] **PLAN-05** — The planner presents concurrent weekly load without any limit, threshold, reference line, verdict or warning colour; the educational disclaimer remains

**Coverage:**

- v1.1 requirements: 10 total (NAV-01..03, NOTIF-01..05, UX-01, PLAN-05) — NOTIF-05 added 2026-08-17 by owner decision
- Mapped to phases: 10 (see ROADMAP.md phases 6-7)
- Unmapped: 0 ✓

*v1.1 requirements defined: 2026-08-17*

---

# v1.2 Requirements

Source: `docs/superpowers/specs/2026-08-26-boostque-onboarding-design.md` (approved 2026-08-31;
its D-1 and *Screens* sections superseded 2026-08-31 by the research pass recorded in that file's
*What shipped* section).
Amends the former "Onboarding flow, quality scores" Out-of-Scope row — this is that revisit; quality scores remain out.

## Onboarding (ONBO)

- [x] **ONBO-01** — On first launch the user sees a two-page introduction — the daily loop, then what the Календар answers — skippable from either page, in the resolved app language. *(Amended 2026-08-31: the spec's second page explained the cycle model. Nielsen Norman Group's 70-participant test found an intro deck left users rating the same tasks harder — 4.92 vs 5.49 of 7 — with no gain in success or speed, so the cycle explanation moved to where a cycle exists, ONBO-04. The calendar page stayed because no contextual hint can answer "why is there a calendar tab": a hint there fires only after the user has already opened it.)*
- [x] **ONBO-02** — Completing the introduction hands the user directly into adding their first supplement, through the app's single add entry point; cancelling that leaves the user on the Stack screen with onboarding already marked seen
- [x] **ONBO-03** — The introduction is shown once. A store that cannot be read or written never traps the user in it, and never blocks launch
- [x] **ONBO-04** — One-time inline hints explain a feature at the moment its subject first appears: the cycle idea inside the regimen editor's schedule panel while a cyclic schedule is on screen, and marking a dose on Сьогодні only on a day that actually has doses. Nothing is dimmed, blocked or focus-stolen; dismissing is one tap and permanent; an unreadable or corrupt store means every hint is already dismissed *(added 2026-08-31)*
- [x] **ONBO-05** — Settings carries a row, in every build, that brings the introduction and every dismissed hint back. It writes only the two first-run preference keys — supplements, regimens and intake history are untouched *(added 2026-08-31)*

## Daily Tracking (TRACK, continued)

Shipped during the v1.2 run with no prior requirement; recorded here so the behaviour is traceable.

- [x] **TRACK-05** — No dose on a day that has not arrived can be marked. A future day's rows are inert on every path — tap, long-press and the assistive-technology actions alike — and carry a neutral `planned` chip so an inert row never reads as a live one. Today is not future: a 21:00 dose stays markable at 10:00
- [x] **TRACK-06** — Every distinct dose time inside a time block carries its own label; the block label (Ранок / День / Вечір / Ніч) appears once. Doses sharing a minute share a heading, and the accent marks the next time actually due rather than the block's earliest

## Localization (L10N, continued)

- [x] **L10N-05** — The app ships in seven locales: English (the fallback), Ukrainian, Spanish, French, Arabic, Hindi and Chinese (Simplified). Each carries the plural categories CLDR requires of it, every screen renders one numeral system and one clock shape throughout, and the planner draws correctly under right-to-left. Adding an eighth is still one ARB file

**Coverage:**

- v1.2 requirements: 8 total (ONBO-01..05, TRACK-05, TRACK-06, L10N-05) — ONBO-04/05 added and ONBO-01 amended 2026-08-31 after the research pass; TRACK-05, TRACK-06 and L10N-05 recorded 2026-09-02 for work that shipped without one
- Mapped to phases: 8 (see ROADMAP.md phases 8-9)
- Unmapped: 0 ✓

## v1.2 Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| ONBO-01 | Phase 8 | Complete (amended) |
| ONBO-02 | Phase 8 | Complete |
| ONBO-03 | Phase 8 | Complete |
| ONBO-04 | Phase 8 | Complete |
| ONBO-05 | Phase 8 | Complete |
| TRACK-05 | Phase 3, amended in v1.2 | Complete |
| TRACK-06 | Phase 3, amended in v1.2 | Complete |
| L10N-05 | Phase 9 | Complete — one eyes-on Arabic RTL pass on a device still outstanding |

*v1.2 requirements defined: 2026-08-26; amended 2026-08-31; extended 2026-09-02*
