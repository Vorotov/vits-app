---
phase: 01-foundation
plan: 05
subsystem: database
tags: [drift, sqlite, sync-ready, uuid, soft-delete, utc, schema-snapshot]

requires:
  - phase: 01-foundation (01-01)
    provides: Flutter scaffold with drift/drift_flutter/drift_dev dependencies and platform configs
  - phase: 01-foundation (01-02)
    provides: lib/core/domain/models.dart with RegimenKind/DoseStatus enums
provides:
  - SyncColumns mixin (TEXT UUID id PK, createdAt, updatedAt, nullable deletedAt) on all 4 tables
  - Drift tables Supplements, Regimens, RegimenSlots, IntakeLogs with generated database.g.dart
  - IntakeLogs composite unique key (slotId, date) enabling idempotent insert-or-ignore materialization
  - Text-based ISO-8601 datetime storage (build.yaml) so DateTime.utc round-trips with isUtc true
  - VitomyDb.forTesting(NativeDatabase.memory()) + VitomyDb.open() via driftDatabase(name 'vitomy')
  - drift_schemas/drift_schema_v1.json snapshot at schemaVersion 1
affects: [01-07 repositories, sync backend (future), all feature phases reading the DB]

actuals:
  tokens: 40500
  tasks: 2
  commits: 3

tech-stack:
  added: []
  patterns:
    - "SyncColumns mixin on every table — no client-side timestamp defaults; writers supply explicit UTC instants"
    - "store_date_time_values_as_text drift option — UTC-midnight calendar identity survives the database"
    - "Composite uniqueKeys (slotId, date) + InsertMode.insertOrIgnore for idempotent materialization"
    - "Schema snapshot per schemaVersion via dart run drift_dev schema dump"

key-files:
  created:
    - lib/core/db/database.dart
    - lib/core/db/database.g.dart
    - build.yaml
    - drift_schemas/drift_schema_v1.json
    - test/db/database_test.dart
  modified: []

key-decisions:
  - "Datetimes stored as ISO-8601 text (not unix timestamps) so DateTime.utc values read back with isUtc true — required for D-13/D-18 calendar identity"
  - "No client-side defaults on SyncColumns timestamps — repositories (01-07) own timestamp assignment, keeping tests deterministic"
  - "Enum columns via intEnum<RegimenKind>/intEnum<DoseStatus> stored as enum index (D-18)"

patterns-established:
  - "SyncColumns: every future table must mix it in (UUID TEXT PK, createdAt/updatedAt, soft delete)"
  - "Migration discipline: every schemaVersion bump adds a new drift_schemas/drift_schema_vN.json snapshot"
  - "OS-backup inclusion is a locked default: never set android:allowBackup=false or NSURLIsExcludedFromBackupKey"

requirements-completed: [DATA-02]

coverage:
  - id: D1
    description: "All 4 tables (Supplements, Regimens, RegimenSlots, IntakeLogs) carry SyncColumns: id/created_at/updated_at/deleted_at with primary key exactly {id}"
    requirement: DATA-02
    verification:
      - kind: unit
        ref: "test/db/database_test.dart#every table has id, created_at, updated_at, deleted_at and primary key exactly {id}"
        status: pass
    human_judgment: false
  - id: D2
    description: "IntakeLogs (slotId, date) composite unique key — duplicate insert with insert-or-ignore leaves exactly one row"
    requirement: DATA-02
    verification:
      - kind: unit
        ref: "test/db/database_test.dart#duplicate (slotId, date) with insert-or-ignore leaves one row"
        status: pass
    human_judgment: false
  - id: D3
    description: "DateTime values round-trip as UTC (date == DateTime.utc(2026,8,14) with isUtc true; createdAt exact instant) via text-based storage"
    requirement: DATA-02
    verification:
      - kind: unit
        ref: "test/db/database_test.dart#date reads back as DateTime.utc(2026, 8, 14) with isUtc true"
        status: pass
      - kind: unit
        ref: "test/db/database_test.dart#createdAt round-trips the exact UTC instant supplied"
        status: pass
    human_judgment: false
  - id: D4
    description: "Schema v1 snapshot exported (drift_schemas/drift_schema_v1.json) and OS-backup defaults locked by grep gates"
    requirement: DATA-02
    verification:
      - kind: other
        ref: "[ -s drift_schemas/drift_schema_v1.json ] && grep -qi intake_logs drift_schemas/drift_schema_v1.json"
        status: pass
      - kind: other
        ref: "! grep -q 'android:allowBackup=\"false\"' android/app/src/main/AndroidManifest.xml && ! grep -rq NSURLIsExcludedFromBackupKey ios/Runner/"
        status: pass
    human_judgment: false
  - id: D5
    description: "On-device vitomy.sqlite is created under the app-documents directory included in OS backups"
    requirement: DATA-02
    verification: []
    human_judgment: true
    rationale: "Plan-level <human-check>: requires running the app once on a device/simulator and inspecting the file location — cannot be asserted from unit tests"

duration: 4min
completed: 2026-08-14
status: complete
---

# Phase 1 Plan 05: Drift Database Schema Summary

**Sync-ready Drift schema: 4 tables sharing a SyncColumns mixin (UUID TEXT PKs, UTC timestamps, soft deletes), (slotId, date) unique key for idempotent materialization, ISO-8601-text datetime storage, and a schemaVersion-1 JSON snapshot**

## Performance

- **Duration:** 4 min
- **Started:** 2026-08-14T18:03:54Z
- **Completed:** 2026-08-14T18:07:53Z
- **Tasks:** 2
- **Files modified:** 5 created

## Accomplishments
- SyncColumns mixin applied to all 4 tables (Supplements, Regimens, RegimenSlots, IntakeLogs) — proven by a table-introspection test over `db.allTables`
- IntakeLogs composite `uniqueKeys` on (slotId, date): duplicate insert-or-ignore leaves exactly one row, making future `ensureLogsForDay` materialization idempotent
- `store_date_time_values_as_text: true` in build.yaml — `DateTime.utc(2026,8,14)` round-trips equal with `isUtc == true` (UTC-midnight calendar identity intact)
- `VitomyDb.forTesting` (in-memory) and `VitomyDb.open()` via `driftDatabase(name: 'vitomy')` with D-21 backup-inclusion doc comment at the open() site
- `drift_schemas/drift_schema_v1.json` exported at schemaVersion 1 — migration discipline starts now
- Automated gates confirm OS-backup defaults untouched (no `android:allowBackup="false"`, no `NSURLIsExcludedFromBackupKey`)

## Task Commits

Each task was committed atomically (Task 1 was TDD — RED then GREEN):

1. **Task 1 RED: failing schema tests** - `75ebe95` (test)
2. **Task 1 GREEN: SyncColumns + 4 tables + VitomyDb + codegen** - `cd9159a` (feat)
3. **Task 2: schema v1 snapshot + backup-default verification** - `a221d8f` (chore)

_No REFACTOR commit — GREEN implementation needed no cleanup._

## Files Created/Modified
- `lib/core/db/database.dart` - SyncColumns mixin, 4 tables, VitomyDb (forTesting/open, schemaVersion 1)
- `lib/core/db/database.g.dart` - generated Drift code (committed per plan)
- `build.yaml` - drift_dev option `store_date_time_values_as_text: true` with rationale comment
- `drift_schemas/drift_schema_v1.json` - schema snapshot keyed to schemaVersion 1
- `test/db/database_test.dart` - 6 tests: introspection, unique key, UTC round-trip (x2), soft delete, table census

## Decisions Made
- Followed plan as specified; enum columns typed via `intEnum<T>()` so generated companions accept `DoseStatus` values directly (stored as enum index per D-18)
- No client-side timestamp defaults on SyncColumns — repositories in 01-07 supply explicit UTC instants

## Deviations from Plan

None - plan executed exactly as written.

## TDD Gate Compliance

- RED gate: `test(01-05)` commit `75ebe95` — tests failed (compile error, schema absent) before implementation
- GREEN gate: `feat(01-05)` commit `cd9159a` — all 6 tests pass
- REFACTOR gate: not needed (no commit)

## Issues Encountered
None.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Plan 01-07 can build repositories against this schema without touching it: SyncColumns shape, unique key, and text-mode datetimes are locked and tested
- Outstanding phase-end human check (D5): run the app once on one platform and confirm `vitomy.sqlite` appears under the app-documents directory

## Self-Check: PASSED

- `lib/core/db/database.dart` — FOUND
- `lib/core/db/database.g.dart` — FOUND
- `build.yaml` — FOUND
- `drift_schemas/drift_schema_v1.json` — FOUND
- `test/db/database_test.dart` — FOUND
- Commits 75ebe95, cd9159a, a221d8f — FOUND in git log
- `flutter analyze` — 0 issues; full `flutter test` — 58 passed

---
*Phase: 01-foundation*
*Completed: 2026-08-14*
