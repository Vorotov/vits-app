# Roadmap: Boostque

## Overview

Boostque ships as five phases moving from a themed, localized, database-backed app skeleton to the complete daily supplement-tracking loop. Phase 1 builds the foundation everything else depends on (project shell, DST-safe cycle math, sync-ready local database) without yet exposing any tracked feature. Phase 2 lets a user build their supplement stack and configure regimens. Phase 3 delivers the core value — today's doses, grouped and checkable, correct across cycle boundaries — and is where the full plan-see-mark-taken loop first runs end-to-end on both iOS and Android. Phase 4 adds the Cycles gantt and Year matrix, the product's structural differentiator, once there's real regimen data to visualize. Phase 5 closes the loop on localization: verifying every screen built in Phases 2-4 is genuinely bilingual and wiring the in-app language override. Toolchain setup (CocoaPods/Java/Android SDK) is already complete and is not part of this roadmap.

## Phases

**Phase Numbering:**

- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [x] **Phase 1: Foundation** - Themed, localized app shell over a sync-ready local database with DST-safe cycle math, fully offline (completed 2026-08-14)
- [x] **Phase 2: Stack Management** - User builds their supplement stack and configures cyclic/course dosing regimens (completed 2026-08-15)
- [x] **Phase 3: Daily Tracking** - User sees and checks off today's doses; the core loop runs end-to-end on iOS and Android (completed 2026-08-15)
- [x] **Phase 4: Planner Views** - User sees cycle overlap and yearly coverage via the Cycles gantt and Year matrix (completed 2026-08-16)
- [ ] **Phase 5: Localization & Settings** - Every screen is verified bilingual; user can override the app language

## Phase Details

### Phase 1: Foundation

**Goal**: A themed, localized, three-tab app shell runs on both iOS and Android over a local, sync-ready database, with zero network dependency and DST-safe cycle math ready for later phases to build on.
**Depends on**: Nothing (first phase)
**Requirements**: DATA-01, DATA-02
**Success Criteria** (what must be TRUE):

  1. App launches on an iOS simulator and an Android emulator to a three-tab shell (Stack / Calendar / Settings) styled with the mockup's palette, radii, and typography — with no network permission requested and no login or account step anywhere
  2. Shell and tab labels render from the active locale (system-detected uk/en, English fallback) with no hardcoded strings, and Ukrainian text doesn't clip in any container
  3. A user's data survives an app reinstall via OS-level device backup, because the local database (UUID primary keys, createdAt/updatedAt, soft-delete columns on every table) is included in backups by default
  4. Automated tests prove the cycle-math layer computes correct active/inactive days across a DST transition and a year boundary, before any screen consumes it

**Plans**: 7/7 plans executed

Plans:

- [x] 01-01-PLAN.md — Tracer: scaffold at repo root, locked deps, bundled variable fonts, both-platform builds (wave 1)
- [x] 01-02-PLAN.md — Domain models + DST-safe cycle math, test-first (wave 2)
- [x] 01-03-PLAN.md — Design tokens + bqTheme() from the mockup palette (wave 2)
- [x] 01-04-PLAN.md — i18n infrastructure: gen-l10n, en/uk ARB, uk plurals, LocaleController (wave 2)
- [x] 01-05-PLAN.md — Sync-ready Drift schema (SyncColumns, unique keys, UTC storage, schema v1 snapshot) (wave 3)
- [x] 01-06-PLAN.md — Three-tab shell: AppShell + stubs + wired MaterialApp, en/uk widget tests (wave 3)
- [x] 01-07-PLAN.md — Repositories, idempotent dose materialization, Riverpod provider graph (wave 4)

**UI hint**: yes

### Phase 2: Stack Management

**Goal**: A user can build their supplement stack — add items from a bundled catalog or manually, edit and delete them — and configure exactly when and how much of each to take.
**Depends on**: Phase 1
**Requirements**: STACK-01, STACK-02, STACK-03, STACK-04, REGI-01, REGI-02, REGI-03, REGI-04
**Success Criteria** (what must be TRUE):

  1. User can add a supplement by searching a bundled, locale-aware catalog, or by entering a name and dose description manually
  2. User's stack renders as cards showing name, dose, color tag, status (active/paused/planned), and a schedule summary
  3. User can configure a cyclic regimen (start date, on-days/off-days in 7-day steps) or a one-time course (start and inclusive end date), each with 1-6 daily time slots carrying their own time and dose label
  4. User can pause and resume a regimen; a paused regimen produces no doses and shows a PAUSED status
  5. User can edit or delete a supplement; deleting soft-deletes it along with its regimen and any future doses

**Plans:** 5/5 plans complete

Plans:

- [x] 02-01-PLAN.md — Tracer: manual add → card via real DB, plus softDeleteCascade + watchDay pause/deletedAt filters (wave 1)
- [x] 02-02-PLAN.md — UI-SPEC token additions, bqTheme() form/picker/sheet sub-themes, BqSegmented (wave 1)
- [x] 02-03-PLAN.md — RegimenEditorController + RegimenDraft (PF-8 id reuse) and statusOf/scheduleSummaryOf pure helpers, unit-tested (wave 2)
- [x] 02-04-PLAN.md — Regimen editor screen: pickers, sliders, 28-bar preview, slots, pinned footer with save/pause/confirmed delete (wave 3)
- [x] 02-05-PLAN.md — Bundled catalog + cross-locale search, full stack cards/states, two-tab add sheet, editor navigation (wave 4)

**UI hint**: yes

### Phase 3: Daily Tracking

**Goal**: A user can see exactly what to take today (and browse recent days) and mark each dose taken or skipped with one tap — the daily loop that is Boostque's core value — running correctly end-to-end on both platforms.
**Depends on**: Phase 2
**Requirements**: TRACK-01, TRACK-02, TRACK-03, TRACK-04, DATA-03
**Success Criteria** (what must be TRUE):

  1. User sees today's doses grouped into time blocks (morning/day/evening/night) alongside a day-progress ring reflecting taken vs. total
  2. User can mark any dose taken or skipped with one tap, and undo the mark
  3. User can browse past and current-week days; unmarked past doses render as neutrally-framed "missed" in the view, while the underlying database row stays pending
  4. Doses appear only on days a regimen's cycle is actually active, verified correct across DST transitions and year boundaries
  5. The full plan-see-mark-taken loop — add a supplement, configure a cycle, see it on Today, check it off — builds and runs correctly on an iOS simulator/device and an Android emulator/device (targetSdk 36)

**Plans**: 5 plans

Plans:

- [x] 03-01-PLAN.md — Tracer: midnight-safe todayProvider + dayDosesProvider materialization choke point + tap-to-mark end-to-end, IN-06 closed (wave 1)
- [x] 03-02-PLAN.md — Pure day view-model (blocks, dose positions, missed/overdue, tags, ring counts) + DST/year-boundary chain proof (wave 1)
- [x] 03-03-PLAN.md — Token additions, full Phase-3 ARB set, DayProgressRing, fixed locale-formatted header (wave 2)
- [x] 03-04-PLAN.md — Time-block sections, five-state dose rows, guarded mark/undo, dose action sheet (wave 3)
- [x] 03-05-PLAN.md — Week strip + past-day browsing, missed-stays-pending, empty/error states, DATA-03 both-platform run (wave 4)

**UI hint**: yes

### Phase 4: Planner Views

**Goal**: A user can see the shape of their supplement schedule over time — overlapping cycles, concurrent load, and a full year of coverage — framed as an editorial tracking aid, never medical guidance.
**Depends on**: Phase 1, Phase 2
**Requirements**: PLAN-01, PLAN-02, PLAN-03, PLAN-04
**Success Criteria** (what must be TRUE):

  1. User can view a ~4-month Cycles gantt: one row per supplement, solid segments for active periods, lighter/hatched segments for planned periods, with a marker for today
  2. User can view a weekly concurrent-load chart against the editorial 5-substance line and tap a week to see its load, verdict, and active supplements
  3. User can view a 12-month Year matrix of per-supplement coverage bars (lighter = planned) and tap a month for a detail breakdown
  4. Every planner screen carries the educational-material disclaimer and presents the 5-substance limit as an editorial comfort rule, not a medical threshold

**Plans**: 5 plans

Plans:

- [x] 04-01-PLAN.md — Tracer: window math + pure planner projections + a reachable gantt, with the zero-write gate (wave 1)
- [x] 04-02-PLAN.md — Full Phase-4 ARB set (plurals, month case, copy-safety gate) + planner shell, empty/error, disclaimer on both segments (wave 2)
- [x] 04-03-PLAN.md — Цикли complete: gantt chrome, concurrent-load chart, inline week detail (wave 3)
- [x] 04-04-PLAN.md — Рік complete: year grid with computed extent, month detail, peak chip, footnote (wave 4)
- [x] 04-05-PLAN.md — Phase-close invariants: text-scale matrix, assistive-tech activation, read-only + PLAN-04 gates (wave 5)

**UI hint**: yes

### Phase 5: Localization & Settings

**Goal**: The whole app — every screen built in Phases 2 through 4 — is genuinely bilingual by default and instantly switchable by the user.
**Depends on**: Phase 2, Phase 3, Phase 4
**Requirements**: L10N-01, L10N-02, L10N-03, L10N-04
**Success Criteria** (what must be TRUE):

  1. Every screen displays correctly in Ukrainian with all four CLDR plural forms (one/few/many/other, including the 11-14 exception) and in English with correct singular/plural forms
  2. On first launch the app matches the device's system language when it's Ukrainian or English, and falls back to English for any other system language
  3. User can override the language in Settings; the change applies instantly across every open screen and persists across app restarts
  4. All dates, month names, and numbers throughout the app are locale-formatted, and adding a new language requires only one new ARB file with no code changes

**Plans**: 5 plans

Plans:

- [ ] 05-01-PLAN.md — Tracer: Settings screen + generated language picker, derived locale set, declared en fallback, flash-free persisted override (wave 1)
- [ ] 05-02-PLAN.md — Amendment A1: the designed error surface beats the Riverpod retry-loading state on all three async screens; A3 locale-aware sentence casing (wave 1)
- [ ] 05-03-PLAN.md — Criterion-4 gates: one-new-ARB-file contract, zero-hardcoded-strings, ARB parity + derived plural forms, system-language resolution (wave 2)
- [ ] 05-04-PLAN.md — Bilingual render matrix across app shell / stack / add-sheet / editor / calendar / dose sheet, plus pushed-route and open-sheet propagation (wave 2)
- [ ] 05-05-PLAN.md — Amendment A2 two-placeholder a11y key, carried-todo closure (LOCKED-FONT), phase gate + both-device backstops (wave 3)

**UI hint**: yes

## Progress

**Execution Order:**
Phases execute in numeric order: 1 → 2 → 3 → 4 → 5

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Foundation | 7/7 | Complete    | 2026-08-14 |
| 2. Stack Management | 5/5 | Complete    | 2026-08-15 |
| 3. Daily Tracking | 5/5 | Complete    | 2026-08-15 |
| 4. Planner Views | 5/5 | Complete    | 2026-08-16 |
| 5. Localization & Settings | 0/5 | Planned | - |
