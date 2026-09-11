# Architecture Research

**Domain:** Local-first Flutter mobile tracking app (supplement stack + dose scheduling/calendar)
**Researched:** 2026-08-14
**Confidence:** MEDIUM-HIGH (project-specific decisions are locked/HIGH from approved spec+plan; general Flutter/Riverpod/Drift best-practice claims are web-search-sourced, MEDIUM confidence — cross-check against official docs at implementation time)

## Standard Architecture

Local-first Flutter trackers (habit trackers, dose/medication trackers, fitness logs) converge on the same shape: **UI never touches the database directly**, a **repository layer** mediates all access, a **reactive local database** (Drift/SQLite is the dominant choice over sqflite/Hive/Isar for typed, reactive, migratable data) streams query results back to the UI, and **pure-Dart domain logic** (the thing most likely to have edge-case bugs — recurrence/cycle math, date arithmetic) is isolated with zero Flutter/DB imports so it's trivially unit-testable. VitoMy's locked decisions (feature-first folders, Riverpod, Drift-behind-repositories, pure-Dart cycle math, materialized dose rows, gen-l10n) are a textbook instance of this pattern, and this research validates and sharpens each of those choices rather than proposing alternatives.

### System Overview

```
┌──────────────────────────────────────────────────────────────────────┐
│  UI LAYER (features/*)                                                │
│  ┌────────────┐  ┌──────────────┐  ┌───────────────┐  ┌───────────┐  │
│  │ StackScreen│  │ CalendarScreen│  │ RegimenEditor │  │ Settings  │  │
│  │  (widgets) │  │ Today/Cycles/ │  │    Screen     │  │  Screen   │  │
│  │            │  │ Year views    │  │               │  │           │  │
│  └─────┬──────┘  └──────┬───────┘  └───────┬───────┘  └─────┬─────┘  │
│        │ ref.watch(provider)                │                │        │
├────────┴────────────────┴──────────────────┴────────────────┴────────┤
│  STATE / PROVIDER LAYER (Riverpod — core/providers.dart, per-feature)  │
│  ┌───────────────────┐ ┌────────────────────┐ ┌────────────────────┐ │
│  │ stackEntriesProvider│ │ dayDosesProvider   │ │ localeController   │ │
│  │ (StreamProvider,   │ │ (family, StreamPr.)│ │ (Notifier)         │ │
│  │  combines 2 streams)│ │ regimen editor     │ │                    │ │
│  └─────────┬──────────┘ │ (AsyncNotifier)     │ └────────────────────┘ │
│            │             └──────────┬─────────┘                       │
├────────────┴────────────────────────┴─────────────────────────────────┤
│  DOMAIN LAYER — pure Dart, no Flutter/DB imports (core/domain/)        │
│  ┌───────────────┐  ┌────────────────┐  ┌─────────────────────────┐  │
│  │ cycle_math.dart│  │ planner_math.dart│ │ repositories.dart        │  │
│  │ isActiveOn,    │  │ segmentsInWindow,│ │ (abstract interfaces:    │  │
│  │ isPlannedOn,   │  │ weekLoad,        │ │  Supplement/Regimen/     │  │
│  │ dateOnly       │  │ monthActiveFrac  │ │  IntakeRepository)        │  │
│  └───────────────┘  └────────────────┘  └───────────┬─────────────┘  │
├──────────────────────────────────────────────────────┴────────────────┤
│  DATA LAYER (core/db/) — one interface implementation                 │
│  ┌───────────────────────────────────────────────────────────────┐   │
│  │  DriftSupplementRepository / DriftRegimenRepository /           │   │
│  │  DriftIntakeRepository  →  VitomyDb (Drift over SQLite)       │   │
│  │  Tables: Supplements, Regimens, RegimenSlots, IntakeLogs        │   │
│  │  All: UUID pk, createdAt, updatedAt, deletedAt (soft delete)    │   │
│  └───────────────────────────────────────────────────────────────┘   │
└──────────────────────────────────────────────────────────────────────┘
```

### Component Responsibilities

| Component | Responsibility | Typical Implementation |
|-----------|----------------|-------------------------|
| Screens/widgets (`features/*`) | Render state, dispatch user intents | `ConsumerWidget`/`ConsumerStatefulWidget`, no business logic, no direct DB/domain-math calls |
| Providers (`core/providers.dart` + per-feature) | Bridge repositories to widget tree, own transient UI/edit state | `StreamProvider` for read-only reactive lists, `Notifier`/`AsyncNotifier` for editors and command state (Riverpod v3 idiom) |
| Repository interfaces (`core/domain/repositories.dart`) | Define the only contract UI/domain code may depend on | Abstract classes returning domain models (`Supplement`, `Regimen`, `DayDose`), never Drift row types |
| Repository implementations (`core/db/drift_repositories.dart`) | Translate domain calls into Drift queries; own dose materialization | Concrete classes implementing the interfaces, injected via `Provider<T>` |
| Domain/cycle math (`core/domain/cycle_math.dart`, `planner_math.dart`) | All date/cycle/course/gantt/load arithmetic | Pure functions/classes, zero `package:flutter` or `package:drift` imports — the single most heavily unit-tested layer |
| Drift database (`core/db/database.dart`) | Schema, migrations, low-level typed SQL | `@DriftDatabase` tables with a shared `SyncColumns` mixin (id/createdAt/updatedAt/deletedAt) |
| Locale controller (`core/l10n/locale_controller.dart`) | System-vs-manual locale state, persisted | `Notifier<Locale?>` + `SharedPreferences` |
| Theme/tokens (`core/theme/`) | Design tokens → `ThemeData`, consumed everywhere | Static const classes, no logic |

## Recommended Project Structure

This matches the locked spec/plan exactly — research confirms it's the correct shape for this app class (no changes recommended):

```
lib/
├── core/
│   ├── db/            # Drift database, tables, DAOs, Drift-backed repo impls
│   ├── domain/         # pure Dart: models, cycle_math, planner_math, repository INTERFACES
│   ├── l10n/           # ARB source + gen-l10n output, locale controller
│   ├── theme/          # design tokens + ThemeData
│   └── providers.dart  # cross-feature Riverpod wiring (db, repos, combined streams)
├── features/
│   ├── stack/          # supplement list, add/edit supplement + regimen editor
│   ├── calendar/        # Today / Cycles / Year views, mark-as-taken
│   └── settings/        # language picker (grows later)
├── app_shell.dart       # bottom navigation, IndexedStack of feature roots
├── app.dart             # MaterialApp, routing, locale resolution
└── main.dart
```

### Structure Rationale

- **`core/domain` has zero Flutter/DB imports.** This is the load-bearing rule of the whole architecture: cycle math and repository *interfaces* live here so they can be unit-tested at millisecond speed with no widget/database bootstrapping, and so `core/db` (Drift) can depend on `core/domain`, never the reverse.
- **`core/db` is the only place `import 'package:drift/drift.dart'` should appear.** If a screen or provider ever imports Drift generated types directly, that's the architecture's canary — it means a repository interface leaked its implementation detail.
- **`features/*` are vertical slices**, not `screens/`/`widgets/`/`providers/` horizontal folders — each feature owns its screens, feature-local widgets, and feature-local providers together, which keeps the four locked-scope features (stack, calendar, settings, and later advisor) independently addable/removable.
- **A `Repository` per aggregate, not per table.** `RegimenRepository` includes slots (regimen + its dose-time children) as one aggregate because they're always read/written together — this avoids N+1 provider composition and matches how the UI actually consumes the data (a regimen *is* its slots).

## Architectural Patterns

### Pattern 1: Repository interface segregation (Drift as a swappable implementation detail)

**What:** UI and domain code depend only on `SupplementRepository`/`RegimenRepository`/`IntakeRepository` abstract classes defined in `core/domain/`. Drift-backed classes implementing them live in `core/db/` and are the only things that import Drift.
**When to use:** Any local-first app that plans to add sync/backend later, or wants domain logic testable without a database.
**Trade-offs:** Small amount of interface/impl boilerplate up front; in exchange, a future `SyncedIntakeRepository` (or a repository that writes locally then queues a sync operation) can be swapped in behind `intakeRepoProvider` with **zero changes to any screen**. This is exactly the mechanism the project's "backend-ready" constraint requires, and it costs nothing extra in v1 beyond discipline.

**Example:**
```dart
abstract class IntakeRepository {
  Stream<List<DayDose>> watchDay(DateTime day);
  Future<void> ensureLogsForDay(DateTime day);
  Future<void> setStatus(String logId, DoseStatus status);
}
// Provider indirection is what makes the swap free later:
final intakeRepoProvider = Provider<IntakeRepository>(
  (ref) => DriftIntakeRepository(ref.watch(dbProvider)),
);
```

### Pattern 2: Riverpod v3 — Notifier/AsyncNotifier for commands, StreamProvider for reads

**What:** Riverpod 3.x's guidance (confirmed across current sources) consolidates around `Notifier`/`AsyncNotifier`/`StreamNotifier` replacing the old `StateNotifier`/`StateProvider` split; state is mutated only through methods on the notifier, never from outside. Pure read-only reactive data (calendar streams, stack list) is exposed as `StreamProvider`/`StreamProvider.family`, which auto-disposes and auto-rebuilds on Drift's underlying `.watch()` stream emitting.
**When to use:** `StreamProvider` for "subscribe to repository stream, render list" (stack list, day doses, cycles/year projections computed from a watched regimen list). `Notifier`/`AsyncNotifier` for anything with imperative steps or multi-field transient state (regimen editor form state, add-supplement sheet, locale controller).
**Trade-offs:** Mixing both provider kinds is correct here, not indecision — a pure derived list doesn't need notifier boilerplate, but a form with validation and a submit action does. The trap is putting *business logic* inside a `StreamProvider`'s transform closure — keep transforms (e.g., grouping doses by time-of-day block, computing gantt segments) as pure functions in `core/domain` and call them from the provider, so they're unit-testable independent of Riverpod.

**Example:**
```dart
final stackEntriesProvider = StreamProvider<List<StackEntry>>((ref) {
  final supplements = ref.watch(supplementRepoProvider).watchAll();
  final regimens = ref.watch(regimenRepoProvider).watchAll();
  return combineStackStreams(supplements, regimens); // pure combine helper, testable alone
});

class RegimenEditorController extends AsyncNotifier<RegimenDraft> {
  @override
  Future<RegimenDraft> build() async => RegimenDraft.initial();
  void setCycleLength(int days) => state = AsyncData(state.value!.copyWith(onDays: days));
  Future<void> save() async {
    final draft = state.value!;
    await ref.read(regimenRepoProvider).upsert(draft.toRegimen());
  }
}
```

### Pattern 3: Materialized occurrences over on-the-fly projection for the "today" read path

**What:** Rather than computing "what doses exist today" purely in memory on every screen build, `IntakeLog` rows are materialized into SQLite ahead of the near horizon (and lazily on-demand for browsed dates) via `ensureLogsForDay`, using `insertOrIgnore` on a `(slotId, date)` unique key so materialization is idempotent and safe to call repeatedly (e.g., on every app foreground, on every day-switch).
**When to use:** Any tracker where (a) a dose/task "occurrence" needs its own mutable status (taken/skipped) that must persist independent of the rule that generated it, and (b) future features (widgets, notifications, history stats) need to read "what happened on day X" without re-running recurrence logic.
**Trade-offs:** This is the one deliberate deviation from "the DB should never store computed data" — and it's the right one here, because status (taken/skipped) is not computed, it's user-entered fact that must survive independent of the regimen's cycle parameters changing later. Cycles/Year views, by contrast, are *pure projections* (gantt segments, week load, month coverage) computed from `Regimen` rows on the fly in `core/domain` — never materialized, because they have no independent mutable state. Getting this distinction right (materialize only what can be independently true/false; compute everything else) is the core data-modeling decision of this app class.

## Data Flow

### Write flow — user marks a dose taken

```
DoseRow (tap)
    ↓
ref.read(intakeRepoProvider).setStatus(logId, DoseStatus.taken)
    ↓
DriftIntakeRepository.setStatus → UPDATE intake_logs SET status=…, updatedAt=… WHERE id=…
    ↓
Drift's underlying stream query (watchDay) detects the table changed → re-emits
    ↓
dayDosesProvider (StreamProvider) rebuilds → TodayView repaints (progress ring, row checkmark)
```

### Write flow — user edits a regimen (cycle length, slots)

```
RegimenEditorController.save()
    ↓
regimenRepoProvider.upsert(Regimen) — Drift transaction:
    UPDATE/INSERT regimens row, DELETE existing regimen_slots for id, INSERT new slots
    ↓
regimensProvider stream re-emits → stackEntriesProvider recombines → StackScreen card updates
    ↓
Next ensureLogsForDay(today) call (on next Today-view mount/foreground) materializes
new pending IntakeLog rows for the new slots; it does NOT retroactively rewrite
already-materialized past-day logs (past history is immutable fact, not a live projection)
```

### Read flow — Cycles/Year planner (pure projection, nothing materialized)

```
CyclesView build
    ↓
ref.watch(regimensProvider) → List<Regimen> (from Drift stream)
    ↓
core/domain/planner_math.segmentsInWindow / weekLoad / monthActiveFraction
    (pure functions, called directly in the widget's build or a thin StreamProvider wrapper)
    ↓
Gantt bars / load chart / month matrix render — recomputed on every regimen change,
never stored
```

### Key data flows

1. **Command → Repository → Drift → Stream re-emit → Provider → Widget rebuild.** Every mutation in this app follows this one-directional loop; there is no separate "refresh" step because Drift's reactive `.watch()` queries make the loop automatic.
2. **Materialization is a side-effecting read**, not a write triggered by user action: `ensureLogsForDay` is called defensively (on view mount, day switch, app foreground) so the "today" read path always has rows to show, but it's idempotent (`insertOrIgnore`) so calling it redundantly is free and safe.
3. **Domain math is a pure function of `Regimen`/`day`**, called from both the materialization path (which slots to insert) and the planner projection path (which days to shade) — this is the single source of truth for "is this regimen active on day X," preventing the two views from ever disagreeing.

## Timezone / Date Correctness

Research on Flutter date handling confirms the locked decision (`DateTime.utc(y, m, d)` for every date-only value — dose dates, regimen start/end) is the correct pattern for this app class, with an important distinction to preserve going forward:

- **Calendar-date semantics vs. instant semantics are different problems.** "Which calendar day is a dose scheduled on" is a *calendar-date* value (no timezone attached, just y/m/d) — normalizing it to `DateTime.utc(y,m,d)` avoids the classic Dart bug where a local-midnight `DateTime` shifts by a day when serialized/compared across a DST transition or when the device timezone changes. This is exactly what the locked constraint already specifies.
- **If a real wall-clock instant is ever needed** (e.g., a v2 notification firing at "22:00 local time"), that is a *different* data type — store the IANA timezone identifier alongside the local time-of-day, not just a UTC instant, because "22:00" must track the user's local clock through DST changes, not a fixed UTC offset. This doesn't affect v1 (no notifications), but repository/table design should keep `minutesFromMidnight` (a local wall-clock offset, timezone-independent) separate from `date` (a UTC-normalized calendar day) exactly as the locked schema already does — don't collapse them into a single UTC `DateTime` later.
- **`createdAt`/`updatedAt` audit columns should remain true UTC instants** (`DateTime.now().toUtc()`), not date-only — they're timestamps for future sync/conflict resolution, a fundamentally different value type from the date-only fields above. The locked schema's `SyncColumns` mixin already gets this right by using `dateTime()` (instant) for those and a separate date-only convention for scheduling fields.

## Sync-Readiness Without Building Sync

Research into local-first sync (CRDTs vs. last-write-wins) confirms **last-write-wins (LWW) is the correct default to design for**, not full CRDTs, and that the locked schema (UUID PKs, `createdAt`/`updatedAt`, soft `deletedAt`) is precisely the LWW-ready shape:

- **CRDTs solve a problem this app doesn't have.** CRDTs earn their complexity for *concurrent multi-writer* editing (shared documents, collaborative lists) where two actors edit the same field simultaneously and neither write should be silently lost. VitoMy v1 is single-user, single-device; even a future "sync across your own two phones" scenario is dominated by one writer at a time. LWW field/row-level (`updatedAt` timestamp wins) is simple, well-understood, and sufficient — full CRDTs would be premature complexity with no corresponding user value.
- **What LWW needs, and what's already locked in:** (1) a stable identity that doesn't collide across devices → UUID PKs (not autoincrement ints) ✓ already locked; (2) a per-row `updatedAt` to compare on conflict → present on every table via `SyncColumns` ✓; (3) deletes that can be *propagated* rather than silently vanishing (a hard `DELETE` gives sync nothing to diff against) → soft `deletedAt` ✓ already locked, with the correct consequence that **every repository read query must filter `deletedAt IS NULL`** (already true in the plan's Drift queries).
- **One gap worth flagging for a later phase, not v1:** LWW at the *row* level (e.g., "last full edit to this Regimen wins") is coarser than field-level LWW ("only the `paused` field's own timestamp is compared"). The locked schema doesn't need field-level granularity now — row-level `updatedAt` is sufficient for a single-device app — but if a later milestone adds multi-device sync, revisit whether `Regimen.upsert` (which replaces all slots wholesale) needs slot-level timestamps too, since two devices editing different slots of the same regimen concurrently would otherwise clobber each other under row-level LWW. Not a v1 concern; flagging for the future sync milestone's own research.
- **No monotonic/logical clock is needed for v1** — plain wall-clock `updatedAt` timestamps are fine for a single-writer app; logical (Lamport/vector) clocks only start mattering once concurrent multi-device writes are real, which is explicitly out of scope.

## Offline Backup/Export Considerations (flagged for roadmap, not required in v1 per PROJECT.md scope)

Not in the locked v1 scope, but worth noting for roadmap sequencing since it's a near-certain fast-follow once users have real data in a local-only app with "no accounts, no network":

- The standard Flutter pattern is: close/checkpoint the Drift/SQLite connection (or use Drift's built-in export), copy the single `.sqlite` file via `path_provider`'s app-documents directory, and hand it to the OS share sheet or a chosen destination; restore is the inverse (copy file back, reopen `VitomyDb`).
- Because the schema already uses UUID PKs and soft deletes, a JSON export (rows → JSON, keyed by UUID) is also cheap to add later and is more portable across schema-version changes than a raw `.sqlite` file copy — worth keeping in mind if backup/export becomes a v1.x feature, but doesn't require any v1 architecture change.
- This has no bearing on the locked v1 architecture — repositories and the Drift schema already provide everything an export feature would need (typed queries per table, filtered by `deletedAt IS NULL` or not, depending on whether "export includes soft-deleted rows" is a future product decision).

## Drift Schema/Migration Practices to Adopt From Task 5 Onward

- **Export the schema after every version bump**, not just at the end: `dart run drift_dev schema dump lib/core/db/database.dart drift_schemas/` after the v1 schema lands, producing `drift_schema_v1.json`. This is cheap now and is what makes `schemaVersion` bumps in later milestones (e.g., adding a `deletedAt` index, or a future sync-metadata table) safe to test against real migration paths instead of only against a fresh in-memory DB.
- **`schemaVersion` starts at 1** (already in the plan) — bump it and add a step-wise `onUpgrade` migration (not a full DB wipe) the first time a v1.x feature needs a column added; Drift's `Migrator` API supports incremental `addColumn`/`createTable` calls keyed to `from`/`to` version pairs.
- **Composite unique keys as idempotency guards** (`IntakeLogs.uniqueKeys = [{slotId, date}]` with `insertOrIgnore`) is the correct mechanism for "materialize is safe to call repeatedly" — this pattern generalizes to any future materialized-row table.

## Anti-Patterns

### Anti-Pattern 1: Widgets or Notifiers importing Drift directly ("the repository is a suggestion")

**What people do:** Under time pressure, a screen calls `ref.watch(dbProvider).select(db.intakeLogs)...` directly because it's one line faster than going through `IntakeRepository`.
**Why it's wrong:** The instant this happens once, "swap Drift for a synced backend later without touching screens" becomes false, silently. It also means domain math and widget tests can no longer avoid a real database.
**Do this instead:** Enforce via review/lint (or a simple `grep -r "package:drift" lib/features` check in CI) that only `core/db/*.dart` imports Drift. Every other file goes through the three repository interfaces.

### Anti-Pattern 2: Storing computed calendar/planner projections in the database

**What people do:** Persisting "this regimen is active during weeks 3-6" as a row, because it feels like it'll be faster to query than recomputing.
**Why it's wrong:** Now there are two sources of truth (the regimen's cycle parameters, and the cached projection), and every edit to `onDays`/`offDays`/`paused` must remember to invalidate/recompute the cache — a classic cache-invalidation bug generator, and unnecessary at this data scale (a handful of regimens, cheap pure-function scans over a few hundred days).
**Do this instead:** Only materialize what has independent mutable state users can set directly (dose taken/skipped status). Everything else (gantt segments, week load, month coverage) is a pure function recomputed on read — exactly what the locked architecture already does.

### Anti-Pattern 3: Building CRDT-grade sync infrastructure "just in case," before there's a second writer

**What people do:** Reach for vector clocks, operation logs, or a merge framework in v1 because "sync is planned for later."
**Why it's wrong:** This app has zero concurrent writers in v1 (single device) and likely a single primary writer even after a future sync feature ships (one person's phone + maybe one backup device). Full CRDT machinery is speculative complexity that slows down v1 delivery for a problem that may never need more than row-level LWW.
**Do this instead:** What's already locked in — UUID PKs, `updatedAt` timestamps, soft deletes — is the complete "sync-ready" surface area needed today. Defer any actual conflict-resolution *algorithm* decision to the milestone that actually builds sync, when real requirements (single active device vs. true multi-device concurrent editing) are known.

### Anti-Pattern 4: Mixing UTC-instant and local-wall-clock date types in one column

**What people do:** Store a dose's "time of day" as a full `DateTime` (implicitly tied to a specific date and offset) instead of keeping "date" (UTC-normalized calendar day) and "time of day" (`minutesFromMidnight`, timezone-independent) as separate fields.
**Why it's wrong:** A `DateTime` for "22:00" silently bakes in an assumption about which day's DST offset applies; if the user travels or the device timezone changes, recurring "22:00" doses can appear to shift by an hour, or dates can flip across a day boundary during comparisons.
**Do this instead:** Keep the locked schema's split — `IntakeLogs.date` (UTC midnight, calendar identity) and `RegimenSlots.minutesFromMidnight` (local wall-clock offset, no timezone attached) — as two independent, narrowly-typed fields, never a combined `DateTime`.

## Scaling Considerations

This is a single-user, single-device, local-only app — "scaling" here means data volume over years of daily use on one phone, not concurrent users.

| Scale | Architecture Adjustments |
|-------|---------------------------|
| Day 1 – a few months of use (dozens of supplements/regimens, hundreds of intake logs) | No changes needed. SQLite handles this trivially; the current schema and pure-function planner math are more than fast enough. |
| Multi-year use (thousands of `IntakeLog` rows accumulated) | Add an index on `(IntakeLogs.date)` (and the existing `(slotId, date)` unique constraint already provides one) if Today/Cycles/Year queries show any lag; consider a periodic "archive old intake logs" job only if storage/perf ever becomes a real complaint — unlikely at mobile-app data volumes even after 10 years of daily use. |
| Future multi-device sync (out of current scope) | This is the point where the "backend-ready" repository indirection pays off: introduce a `SyncedIntakeRepository` (or a background sync service writing through the same Drift tables) behind the existing `intakeRepoProvider`, decide the conflict-resolution granularity (row vs. field-level LWW) then, with real requirements — no architecture rework needed in the UI/domain layers. |

### Scaling Priorities

1. **First (and likely only, within v1's lifetime) bottleneck:** `IntakeLog` table growth from years of daily materialized doses. Mitigated for free by the existing unique-key + date filtering; revisit only if profiling shows an issue.
2. **Second, hypothetical bottleneck:** a future sync layer's conflict-resolution granularity, deferred by design to the milestone that actually builds sync (see Sync-Readiness section above).

## Integration Points

### External Services

None in v1 — explicitly local-only, no accounts, no network (per `PROJECT.md` Out of Scope). No integration points to design for beyond keeping the repository seam clean.

### Internal Boundaries

| Boundary | Communication | Notes |
|----------|----------------|-------|
| `features/*` ↔ `core/domain` (repository interfaces) | Direct Dart interface calls via Riverpod providers | The only boundary UI code should ever cross to reach data; never `core/db` directly |
| `core/domain` (interfaces) ↔ `core/db` (Drift impls) | Interface implementation | `core/db` depends on `core/domain`'s models/interfaces; never the reverse — enforces the dependency arrow shown in the System Overview |
| `core/domain/cycle_math` & `planner_math` ↔ everything else | Pure function calls, no state | Called from both `core/db` (materialization) and `features/calendar` (projection rendering) — single source of truth for "is this regimen active on day X" |
| `features/*` ↔ `core/l10n` | `AppLocalizations` via `context.l10n` extension + `localeControllerProvider` | Every user-visible string crosses this boundary; zero hardcoded strings is enforced architecturally by having no other path to text |
| `app_shell.dart` ↔ `features/*` | `IndexedStack` + `NavigationBar`, no cross-feature imports | Features should not import each other's internals; the regimen editor is reached from `features/stack` via a route parameter (`supplementId`), not a shared provider between features |

## Suggested Build Order (dependency-driven)

This mirrors the already-approved implementation plan's task ordering, which independently arrived at the same dependency-correct sequence — strong convergent validation:

1. **Toolchain + project scaffold** — no dependencies.
2. **Design tokens/theme + i18n foundation** — no data dependencies; can be built in parallel with each other, both are prerequisites for any real screen.
3. **Domain models + cycle math (pure Dart)** — no dependencies on Drift or Riverpod; this is the layer to build and exhaustively unit-test *before* wiring any UI, since every other layer depends on its correctness (materialization logic and planner projections both call into it).
4. **Drift database schema** — depends on domain models (table shapes mirror them) but not on repositories yet.
5. **Repository interfaces + Drift implementations + dose materialization** — depends on both (3) and (4); this is the seam that makes everything above it swappable later, so it must be solid (well-tested) before any screen is built against it.
6. **App shell (navigation)** — depends on nothing but stubs; can start once (2) is done, in parallel with (3)-(5).
7. **Feature screens (Stack, Calendar/Today, Regimen editor, Cycles, Year, Settings)** — each depends on (3)+(5) being stable; Stack and the regimen editor are the earliest since Calendar/Cycles/Year have nothing to show without at least one supplement+regimen existing.
8. **Cross-cutting polish/verification** — depends on all of the above.

**Key ordering rationale:** domain math and the repository/materialization seam are the two riskiest, most bug-prone pieces (cycle boundary math, idempotent materialization) and also the two everything else depends on — building and unit-testing them first, before any pixel is drawn, is both the dependency-correct order and the risk-reduction-correct order.

## Sources

- [Understanding Flutter Riverpod 3.0 — Stanislav Sopov, Medium](https://stassop.medium.com/understanding-riverpod-providers-132ea7c72203)
- [How to use Notifier and AsyncNotifier with the new Flutter Riverpod Generator — Code with Andrea](https://codewithandrea.com/articles/flutter-riverpod-async-notifier/)
- [Riverpod Best Practices You're Probably Missing — DCM](https://dcm.dev/blog/2026/03/25/inside-riverpod-source-code-guide-dcm-rules/)
- [Riverpod 3.0 Key Changes and Practical Usage — CuroGom, Medium](https://curogom.dev/riverpod-3-0-key-changes-and-practical-usage-3a0c6957cbf1)
- [Database migration with Flutter Drift — Nicat Tagizada, Medium](https://medium.com/@tagizada.nicat/migration-with-flutter-drift-c9e21e905eeb)
- [drift | Dart package (pub.dev)](https://pub.dev/packages/drift)
- [Building Offline-First Flutter Apps with Drift — Flutter Studio](https://flutterstudio.dev/blog/offline-first-flutter-drift.html)
- [Safely Backing Up Sqlflite in Flutter — Soojeong Lee, Medium](https://medium.com/@soojlee0701/safely-backing-up-sqlflite-in-flutter-120718588dd5)
- [Offline-First Architecture in Flutter: SQLite Local Storage and Conflict Resolution — DEV Community](https://dev.to/anurag_dev/implementing-offline-first-architecture-in-flutter-part-1-local-storage-with-conflict-resolution-4mdl)
- [Offline-First Mobile Architecture: Building Apps That Work Without Internet — Askantech](https://www.askantech.com/offline-first-mobile-architecture-apps-without-internet/)
- [Advanced Syncing Algorithms for Collaborative Mobile Apps in 2026 — DEV Community](https://dev.to/devin-rosario/advanced-syncing-algorithms-for-collaborative-mobile-apps-in-2026-1a60)
- [Beyond Offline-First: The Nightmare of Data Synchronization & CRDTs — Engin Bolat, Medium](https://medium.com/@engin.bolat/beyond-offline-first-the-nightmare-of-data-synchronization-crdts-c69501a96c8d)
- [Handling Time Zones Correctly In Flutter Calendars And Scheduling — Vibe Studio](https://vibe-studio.ai/insights/handling-time-zones-correctly-in-flutter-calendars-and-scheduling)
- [Converting DateTime with IANA Timezone to UTC in Dart — Ataxan Rahimli, Medium](https://arahimli.medium.com/converting-datetime-with-iana-timezone-to-utc-in-dart-flutter-safe-way-eb5522142412)
- Project-internal (HIGH confidence, authoritative for this codebase): `docs/superpowers/specs/2026-08-14-vitomy-v1-design.md`, `docs/superpowers/plans/2026-08-14-vitomy-v1.md`, `.planning/PROJECT.md`

---
*Architecture research for: local-first Flutter supplement stack/dose tracker (iOS + Android)*
*Researched: 2026-08-14*
