# Project Research Summary

**Project:** Boostque
**Domain:** Local-first Flutter mobile app — supplement stack planner/adherence tracker (iOS + Android)
**Researched:** 2026-08-14
**Confidence:** HIGH

## Executive Summary

Boostque is a local-first Flutter app for planning and tracking cyclic supplement regimens, built on an already-locked architecture (Riverpod + Drift/SQLite + repository pattern + pure-Dart domain math + feature-first folders + gen-l10n uk/en). This research confirms every locked decision is the industry-standard shape for this app class, and fills in the concrete package versions (Riverpod 3.4.2, Drift 2.34.3, drift_flutter 0.3.1, uuid, build_runner-driven codegen) needed to start building on the dev machine's Flutter 3.47/Dart 3.13. There are no architectural surprises here — the biggest value of this research round is confirming the plan is sound and surfacing the sharp edges (DST-safe date math, ICU plural correctness for Ukrainian, Drift migration discipline, Riverpod autoDispose lifecycle) that must be handled correctly from the very first phase that touches them, because they're expensive to retrofit later.

On features, v1's scope (stack management, cyclic + one-time regimens, Today view, Cycles gantt, Year matrix, uk+en i18n, local-only storage) matches or exceeds table stakes across the competitor set (Medisafe, MyTherapy, SuppCo, Round Health, etc.), and the Cycles/Year visualizations are a genuine, defensible differentiator no competitor offers — protect them from scope-cutting. One near-zero-cost gap surfaced: the Today view should support browsing past dates with a "missed" state so v1 doesn't ship without basic dose history, since Cycles/Year already need the date-ranged queries this requires. Notifications are correctly deferred but should be the first post-v1 addition, since the "materialized dose row" data model already makes it cheap.

The main risks are not architectural but disciplinary and operational: (1) domain-layer cycle math must be pure, UTC-normalized, and tested across DST/year boundaries from day one; (2) Drift schema/migration hygiene (schema snapshots, migration tests) must start with the very first schema change, not be deferred; (3) Ukrainian ICU plurals need all four CLDR forms (one/few/many/other), not just one/other; (4) release-readiness items (iOS privacy manifest, Android targetSdk 36 by Aug 31 2026, health-app copy review) need to be tracked incrementally per-phase rather than discovered at submission time; (5) local-only storage needs a documented decision to leave OS-level backup inclusion at defaults (or ship export) so a device loss doesn't erase months of tracked data. None of these require architecture changes — all are process/discipline items to bake into the relevant phase's definition of done.

## Key Findings

### Recommended Stack

Flutter 3.47.0 / Dart 3.13.0 (already installed) with flutter_riverpod ^3.4.2 (code-gen style via riverpod_annotation/riverpod_generator), drift ^2.34.3 + drift_flutter ^0.3.1 for a typed reactive SQLite layer (no longer needs sqlite3_flutter_libs as a direct dependency since Drift 2.32+ bundles SQLite natively), uuid ^4.6.0 for sync-ready UUID primary keys, and shared_preferences ^2.5.5 for the one settings value (manual locale override). Testing uses mocktail (not mockito, to avoid a third build_runner codegen pass) plus flutter_test/integration_test. Do not hand-pin `intl` — let `flutter_localizations` (SDK) resolve it, since a manual pin is a well-documented source of `pub get` failures. Custom-build the Cycles gantt and Year matrix as plain Flutter widgets/CustomPaint rather than forcing them into a generic charting or calendar package — no such package fits this app's bespoke layouts.

**Core technologies:**
- Flutter 3.47 / Dart 3.13 — app framework, already installed, ships Dart 3 records/pattern-matching well-suited to domain math
- flutter_riverpod ^3.4.2 (+ riverpod_generator) — state management, Notifier/AsyncNotifier for commands, StreamProvider for reactive reads
- drift ^2.34.3 + drift_flutter ^0.3.1 — typed reactive SQLite ORM and Flutter DB-opening helper, officially recommended combo
- uuid ^4.6.0 — UUID v4 primary keys, required by the sync-ready data model
- mocktail — repository interface mocking in tests without extra codegen

### Expected Features

v1 scope already matches or beats the competitor set (Medisafe, MyTherapy, SuppCo, Round Health, Dose Streak, Zareva, DoseNote et al.) on every table-stakes item. The Cycles gantt + weekly load chart and the 12-month Year matrix are structural differentiators no competitor reviewed has. uk+en i18n is also a real differentiator versus an almost entirely English-only competitor set.

**Must have (table stakes) — already in v1 scope:**
- Add/edit/delete tracked items with dose + unit; flexible scheduling (cycles, multi-slot, on/off); daily "today" grouped-by-time view with one-tap mark taken; taken/skipped/(computed) missed tri-state; pause/resume regimens; bundled/searchable catalog; educational-only disclaimer language; day-progress indicator
- **Recommended addition (near-zero cost):** past-date browsing in Today view + a visually distinct "missed" state for unmarked past doses — closes the one table-stakes gap, reuses Cycles/Year's date-ranged query machinery

**Should have (competitive, correctly deferred to v1.x):**
- Dose notifications — highest-priority post-v1 addition; cheap because IntakeLog rows are already materialized
- Home-screen widgets — second priority, more native platform work per OS
- Streaks/adherence visualization — must be cycle-aware (never penalize intentional "off" weeks)
- Export dose history (CSV/PDF) — lower priority for a supplement (vs. prescription) app

**Defer (v2+ or indefinitely):**
- Camera/barcode scanning — low urgency at typical small stack sizes
- Interaction/risk scoring + Advisor tab — high liability, do not build a cheap/naive version ever
- Cloud sync/accounts — architecture already supports adding later without rework
- Caregiver/"med-friend" alerts — audience mismatch, not recommended even long-term
- Monetization — needs validated user base first

### Architecture Approach

Locked architecture (feature-first folders; UI never touches DB; repository interfaces in `core/domain` implemented by Drift classes in `core/db`; pure-Dart cycle/planner math with zero Flutter/DB imports; materialized `IntakeLog` rows for anything with independent mutable state vs. pure on-the-fly projections for Cycles/Year) is validated as the textbook shape for this app class — no changes recommended. UUID PKs + createdAt/updatedAt/soft-deletedAt columns are the correct and sufficient "sync-ready" surface for a future last-write-wins sync layer; full CRDTs would be premature complexity. Dates must stay split into a UTC-normalized calendar-day field and a separate timezone-independent `minutesFromMidnight` field, never a combined `DateTime`.

**Major components:**
1. `core/domain` (pure Dart) — cycle math, planner math, repository interfaces, domain models; zero Flutter/DB imports, the single most heavily unit-tested layer
2. `core/db` (Drift) — schema, migrations, repository implementations; the *only* place Drift is imported
3. Riverpod providers (`core/providers.dart` + per-feature) — StreamProvider for reactive reads, Notifier/AsyncNotifier for commands/editors
4. `features/*` (stack, calendar, settings) — vertical-slice screens consuming providers only, no direct DB/domain-math calls
5. Materialization path — `ensureLogsForDay` idempotently inserts pending IntakeLog rows on a `(slotId, date)` unique key, the seam that will enable notifications/widgets later at near-zero cost

### Critical Pitfalls

1. **DST-unsafe local-timezone date arithmetic in cycle math** — normalize every date to `DateTime.utc(y,m,d)`, never call `DateTime.now()` inside `core/domain` functions, and unit-test explicitly across DST-transition and year-boundary dates.
2. **Untested/destructive Drift schema migrations** — export schema snapshots from the very first schema change, bump `schemaVersion` on every table/column edit, and test migrations against seeded data at prior versions, not just fresh installs.
3. **Riverpod autoDispose/lifecycle mistakes** — decide a deliberate per-provider autoDispose policy once (repository-level streams generally not autoDispose; screen-scoped ones can be) rather than accidentally leaking or re-subscribing Drift streams on every tab switch.
4. **Ukrainian ICU plural mishandling** — always write all four CLDR forms (one/few/many/other) in ARB plural blocks and test counts 1, 2, 5, 11, 21, 22, 25; gen-l10n also can't nest two pluralized quantities in one message — split into separate strings.
5. **Release-gate surprises (iOS privacy manifest, Android targetSdk 36 by Aug 31 2026, health-app review scrutiny)** — treat these as incremental checklist items from the phase that first adds native plugins / dosing-guidance copy, not something discovered at submission time; also verify OS-level backup inclusion isn't accidentally disabled, since local-only storage has no other data-loss safety net.

## Implications for Roadmap

Based on combined research, the dependency-correct build order (also independently confirmed by the already-approved implementation plan) is:

### Phase 1: Toolchain, Design Tokens & i18n Foundation
**Rationale:** No data dependencies; everything else needs a themed, localized shell to render into.
**Delivers:** Project scaffold, lint config (flutter_lints + riverpod_lint), design tokens/ThemeData, ARB file structure with correct uk plural forms wired end-to-end.
**Addresses:** uk+en i18n table-stakes requirement.
**Avoids:** Pitfall 4 (ICU plural mishandling) — get the ARB conventions right before any pluralized string ships.

### Phase 2: Domain Models & Pure Cycle/Planner Math
**Rationale:** Everything else (materialization, Cycles/Year projections) depends on this layer's correctness; build and exhaustively unit-test it before any UI consumes it, per Architecture's build-order finding.
**Delivers:** `core/domain` models, `cycle_math.dart`, `planner_math.dart`, repository interfaces — zero Flutter/DB imports.
**Avoids:** Pitfall 1 (DST-unsafe date math) — DST-boundary and year-boundary test cases required as exit criteria.

### Phase 3: Drift Database & Repositories
**Rationale:** Depends on domain models (table shapes) but not on UI; must be solid before any screen is built against it (Architecture build order step 4-5).
**Delivers:** Drift schema (`SyncColumns` mixin: UUID pk, createdAt/updatedAt/deletedAt), Drift-backed repository implementations, `ensureLogsForDay` materialization logic.
**Avoids:** Pitfall 2 (untested migrations) — schema-export/migration-test discipline established from the first schema version, not deferred. Also verify OS-default backup inclusion here (Pitfall 8).

### Phase 4: App Shell & Riverpod Wiring
**Rationale:** Can proceed in parallel with Phase 3 once tokens/i18n exist; establishes the provider composition pattern (StreamProvider vs. Notifier) once so screen phases just consume it.
**Delivers:** Navigation shell, repository-to-provider wiring, documented autoDispose policy.
**Avoids:** Pitfall 3 (Riverpod lifecycle mistakes) — decide the policy here, not ad hoc per screen.

### Phase 5: Stack Management (catalog + manual add/edit/delete, regimen editor)
**Rationale:** Earliest feature screen since Calendar/Cycles/Year have nothing to show without at least one supplement+regimen existing.
**Delivers:** Stack tab, bundled catalog seed data, dosing-regimen editor (cyclic + one-time, multi-slot, pause/resume).
**Implements:** Repository interface segregation pattern (Pattern 1 from ARCHITECTURE.md).
**Addresses:** Table-stakes stack management + regimen scheduling features.

### Phase 6: Today / Calendar View (mark taken/skipped + recommended history-lite)
**Rationale:** Depends on Phase 5 data existing; is the core daily-use loop.
**Delivers:** Today view with progress ring, taken/skipped/missed states, and — per Features research — past-date navigation so unmarked past doses render as "missed" rather than leaving a table-stakes gap.
**Addresses:** Table-stakes daily tracking + the recommended history-lite addition.
**Avoids:** UX Pitfall (guilt-based framing) — missed/skipped must render neutrally, not punitively.

### Phase 7: Cycles Planner & Year Planner
**Rationale:** Pure projections built on Phase 2's math and Phase 5's regimen data; the product's core differentiator, sequenced after the daily loop works since it's higher implementation cost (HIGH per Features prioritization matrix).
**Delivers:** Gantt view (regimens as bars across a ~4-month window with week gridlines) and 12-month coverage matrix, both hand-built widgets per Stack research (no generic chart/calendar package fits).
**Addresses:** The two structural differentiators versus every competitor reviewed — protect from scope-cutting.
**Avoids:** Performance Trap (per-row stream subscriptions, ungrouped widget trees) — merge into one stream per visible range, virtualize rendering.

### Phase 8: Settings & Locale Switching
**Rationale:** Low-risk, mostly independent; can slot in whenever convenient once locale controller pattern exists.
**Delivers:** Language picker, `shared_preferences`-backed manual override.
**Avoids:** Integration gotcha — must await `initializeDateFormatting()` per locale before any date-format widget builds; verify live in-session locale switching, not just cold-start.

### Phase 9: Release Prep (iOS + Android submission readiness)
**Rationale:** Must happen last but needs to be tracked incrementally throughout, not discovered at submission.
**Delivers:** iOS privacy manifest validated via a real App Store Connect "Validate App" pass; Android targetSdk 36 compliance (deadline Aug 31, 2026); health-app copy review across all dosing/cycle-guidance screens and store metadata.
**Avoids:** Pitfalls 5, 6, 7 (privacy manifest, targetSdk deadline, medical-app review scrutiny).

### Phase Ordering Rationale

- Domain math and the repository/materialization seam are the two riskiest, most bug-prone pieces and also what everything else depends on — building and testing them before any pixel is drawn is both dependency-correct and risk-reduction-correct (per Architecture's own build-order analysis, which independently converges with the already-approved implementation plan).
- i18n/ARB conventions and design tokens are cheap to get right first and expensive to retrofit across every screen later (Ukrainian text is 15-25% longer than English; fixed-width containers must be avoided from day one).
- Cycles/Year (the core differentiator) is sequenced after the daily Today-view loop because it's the highest implementation cost and depends on the same domain math and regimen data the Today view also needs — shipping the daily loop first de-risks the differentiator's foundation.
- Release-prep items are process gates, not code — they belong incrementally in every phase that adds native plugins or dosing-guidance copy, with a final hard-gate pass at the end, per PITFALLS.md's explicit phase mapping.

### Research Flags

Phases likely needing deeper research during planning (`--research-phase`):
- **Phase 2 (Domain/cycle math):** DST-safe date arithmetic and cycle-boundary edge cases are subtle; worth a focused research pass on Dart `DateTime.utc` interval math patterns before implementation.
- **Phase 3 (Drift database):** Migration/schema-snapshot tooling specifics (`drift_dev schema dump`, `MigrationStrategy.onUpgrade` patterns) benefit from fresh docs at implementation time.
- **Phase 7 (Cycles/Year planners):** No dominant package exists for these bespoke gantt/matrix layouts; the exact `CustomPainter`/virtualization approach for 12-month rendering at 60fps on mid-range Android warrants its own research pass.
- **Phase 9 (Release prep):** iOS privacy manifest requirements and Android targetSdk policy details change frequently and should be re-verified against current Apple/Google policy immediately before submission, not just planned from this research.

Phases with standard, well-documented patterns (skip research-phase):
- **Phase 1 (Toolchain/tokens/i18n):** Standard Flutter project setup and gen-l10n ARB conventions are well-documented.
- **Phase 4 (App shell/Riverpod wiring):** Riverpod 3.x StreamProvider/Notifier patterns are stable and well-documented in official docs.
- **Phase 5 (Stack management):** Standard CRUD + form-editor screen, no novel patterns.
- **Phase 8 (Settings/locale):** Standard `shared_preferences` + `AppLocalizations` pattern.

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | All package versions verified live against pub.dev; architectural framing verified against official Riverpod/Drift/Flutter docs |
| Features | MEDIUM-HIGH | Based on public app-store listings/marketing pages/comparison articles for ~15 competitor apps; no hands-on trials or primary user research — quantitative claims are directional |
| Architecture | MEDIUM-HIGH | Project-specific decisions are locked/HIGH from the approved spec+plan; general Flutter/Riverpod/Drift best-practice claims are web-search-sourced MEDIUM confidence |
| Pitfalls | MEDIUM-HIGH | Apple/Google official policy pages are HIGH; Flutter/Drift/Riverpod community sources are MEDIUM; UX/domain pitfalls extrapolated from adjacent habit-tracker research are MEDIUM-LOW |

**Overall confidence:** HIGH

### Gaps to Address

- **Skip vs. Missed semantics** (Features research): the exact rule for when an unmarked past dose becomes "missed" (auto-computed at what cutoff, vs. staying "pending" indefinitely) needs to be decided during Phase 2/6 planning — it gates both the recommended history-lite addition and any future streak feature, and should not require a later data-model migration.
- **Field-level vs. row-level LWW granularity** (Architecture research): row-level `updatedAt` is sufficient for v1's single-device use, but if `Regimen.upsert` (which replaces all slots wholesale) needs slot-level timestamps for a future multi-device sync milestone, that decision is explicitly deferred — flag for whichever future milestone actually builds sync, not v1.
- **Backup/export decision** (Pitfalls research): v1 correctly excludes cloud sync, but the roadmap should explicitly decide (not by default/omission) whether to flag manual JSON export as an early v1.x fast-follow, since local-only + accidental backup-exclusion is a realistic total-data-loss risk.
- **Competitor research recency/verification**: Feature research is based on marketing pages and app-store listings, not hands-on app trials — treat feature-parity claims as directional guidance for prioritization, not as verified user behavior data.

## Sources

### Primary (HIGH confidence)
- pub.dev direct WebFetch — flutter_riverpod 3.4.2, drift 2.34.3, drift_flutter 0.3.1, drift_dev 2.34.5, build_runner 2.16.0, uuid 4.6.0, and other pinned package versions
- Drift setup docs (drift.simonbinder.eu/setup/), migrations docs, stream queries docs — official
- Riverpod migrating 2.0→3.0, getting started, automatic disposal docs (riverpod.dev) — official
- Flutter 3.47.0 release notes (docs.flutter.dev) — official
- App Review Guidelines (developer.apple.com) — official
- Target API level requirements (support.google.com/googleplay) — official
- flutter/flutter GitHub issues #138069 (DST DateTime), #15741 (locale data init), #86906 (nested plurals) — official issue tracker
- Internal: `/Users/dima/supplements/.planning/PROJECT.md`, `docs/superpowers/specs/2026-08-14-boostque-v1-design.md`, `docs/superpowers/plans/2026-08-14-boostque-v1.md`

### Secondary (MEDIUM confidence)
- Competitor app-store listings and comparison articles (Medisafe, MyTherapy, SuppCo, Round Health, Dose Streak, Zareva, DoseNote, JanusMed, etc.) — see FEATURES.md for full list
- Practitioner write-ups on Riverpod 3.0 patterns, Drift migrations, DST/timezone handling, iOS privacy manifests — see ARCHITECTURE.md and PITFALLS.md source lists
- flutter/flutter issues #162568, #164688, #169591, #168903 (intl/flutter_localizations pin conflicts) — community-reported, corroborating pattern

### Tertiary (LOW confidence)
- Flutter Gems / GitHub gantt-chart package search — used only to confirm no dominant package exists, supporting the hand-build recommendation
- "I Tested 10 Habit Trackers in 30 Days" (Medium, anecdotal) — used only for UX-pitfall framing (guilt-based streak mechanics), not as authoritative data
- rrousselGit/riverpod #3313 — historical 2.x-era issue, kept as a documented gotcha pattern, not confirmed reproducible on current versions

---
*Research completed: 2026-08-14*
*Ready for roadmap: yes*
