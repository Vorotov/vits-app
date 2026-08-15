# Phase 2: Stack Management - Pattern Map

**Mapped:** 2026-08-15
**Files analyzed:** 18 new/modified files
**Analogs found:** 15 / 18 (3 partial/none — bespoke UI with no Phase-1 precedent; RESEARCH.md carries their patterns)

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `lib/features/stack/stack_screen.dart` (rewrite) | screen/component | reactive read (provider→list) | `lib/features/stack/stack_screen.dart` (stub, imports/scaffold) + `test/providers_test.dart` (AsyncValue consumption) | exact (same file) |
| `lib/features/stack/add_supplement_sheet.dart` (new) | component (modal form) | request-response (form→repo write) | `lib/features/settings/settings_screen.dart` (screen skeleton) | role-match |
| `lib/features/stack/catalog.dart` (new) | config/data (const descriptors) | static lookup | `lib/core/theme/tokens.dart` (const descriptor style) | role-match |
| `lib/features/stack/regimen_editor_screen.dart` (new) | screen/component | form→repo write | `lib/features/settings/settings_screen.dart` (skeleton) + RESEARCH P-5/P-7 | role-match |
| `lib/features/stack/regimen_editor_controller.dart` (new) | state controller (Notifier) | screen-scoped draft state | `lib/core/l10n/locale_controller.dart` | exact (only Notifier in codebase) |
| `lib/features/stack/stack_status.dart` (new, statusOf + summary helpers) | domain-ish pure helpers | transform | `lib/core/domain/repositories.dart` `combineStackEntries` (pure fn style) | exact |
| `lib/core/widgets/bq_segmented.dart` (new) | component (custom control) | request-response (callback) | none (bespoke) — see RESEARCH P-10 | none |
| `lib/core/theme/theme.dart` (extend) | config (theme) | — | itself | exact |
| `lib/core/domain/repositories.dart` (add `softDeleteCascade`) | interface | — | itself (existing method docs) | exact |
| `lib/core/db/drift_repositories.dart` (cascade + watchDay filters) | repository impl | CRUD/transaction | itself (`DriftRegimenRepository.upsert` transaction, `softDelete`, `watchDay`) | exact |
| `lib/core/l10n/arb/app_en.arb` + `app_uk.arb` (~25 keys) | config (i18n) | — | themselves (`weeksCount` plural key) | exact |
| `test/db/cascade_delete_test.dart` (new) | test | — | `test/db/repositories_test.dart` | exact |
| `test/db/pause_filter_test.dart` (new) | test | — | `test/db/repositories_test.dart` | exact |
| `test/features/stack_screen_test.dart` (new) | widget test | — | `test/widget/app_shell_test.dart` + `test/providers_test.dart` (db override) | exact |
| `test/features/regimen_editor_test.dart` (new) | widget/controller test | — | `test/widget/app_shell_test.dart` | role-match |
| `test/features/catalog_search_test.dart` (new) | unit test | — | `test/l10n/plurals_test.dart` (delegate.load pattern) | exact |
| `test/features/stack_status_test.dart` (new) | unit test | — | `test/domain/cycle_math_test.dart` style (pure fn) | role-match |
| `test/l10n/plurals_test.dart` (extend) | test | — | itself | exact |

## Pattern Assignments

### `lib/features/stack/stack_screen.dart` (screen, reactive list)

**Analog:** current stub `lib/features/stack/stack_screen.dart` (lines 1-29) for imports/scaffold conventions; consume `stackEntriesProvider` per `lib/core/providers.dart:76-88`.

**Imports + scaffold pattern** (stack_screen.dart:1-27) — package-absolute imports, `EdgeInsetsDirectional`, `context.l10n`, token-only styling:
```dart
import 'package:flutter/material.dart';

import 'package:boostque/core/l10n/l10n.dart';
import 'package:boostque/core/theme/tokens.dart';

// body:
Padding(
  padding: const EdgeInsetsDirectional.only(
    start: BqSpace.lg, end: BqSpace.lg, top: BqSpace.lg),
  child: Text(context.l10n.tabStack,
      style: Theme.of(context).textTheme.headlineSmall),
)
```
Note: feature files use `package:boostque/...` absolute imports; `core/` internals use relative imports. Follow that split.

**Provider consumption pattern** — `stackEntriesProvider` is `Provider<AsyncValue<List<StackEntry>>>` (providers.dart:76-88). Widget becomes `ConsumerWidget`, reads `ref.watch(stackEntriesProvider)` and switches on `AsyncValue.when(data/loading/error)`. Do NOT create new stream providers (D-23 — providers.dart:1-22 doc comment is the policy record).

**Mono/chip text style** — `BqText.mono(...)` from `lib/core/theme/theme.dart:75-93` (JetBrains Mono, tabular figures) for status chips and time labels.

### `lib/features/stack/add_supplement_sheet.dart` + `regimen_editor_screen.dart` (components/forms)

**Analog (skeleton only):** `lib/features/settings/settings_screen.dart:1-29` — same import style, `SafeArea` + `EdgeInsetsDirectional`, l10n via `context.l10n`. No form/bottom-sheet precedent exists in the codebase; use RESEARCH.md P-3/P-6/P-7/PF-6 code verbatim (showModalBottomSheet isScrollControlled, showDatePicker→`dateOnly()` immediately, showTimePicker 24-h MediaQuery wrap, Slider divisions 15/12).

**Repo access pattern:** via `ref.read(supplementRepoProvider)` / `ref.read(regimenRepoProvider)` (providers.dart:42-57) — interfaces only, never Drift types in `features/`.

**UUID minting pattern** (drift_repositories.dart:234): `id: const Uuid().v4()` — mint in the save controller/repo boundary, never in `build()` and never in Drift defaults.

### `lib/features/stack/regimen_editor_controller.dart` (Notifier state)

**Analog:** `lib/core/l10n/locale_controller.dart` — the codebase's only Riverpod-3 Notifier. Copy its shape (lines 13-52):
```dart
class LocaleController extends Notifier<Locale?> {
  @override
  Locale? build() { _load(); return null; }        // seed sync, async-settle later
  Future<void> setLocale(Locale? locale) async { ...; state = locale; }
}
final localeControllerProvider =
    NotifierProvider<LocaleController, Locale?>(LocaleController.new);
```
Differences for the editor: constructor-arg family per RESEARCH P-5 (`NotifierProvider.autoDispose.family<RegimenEditorController, RegimenDraft, String>(RegimenEditorController.new)`) — autoDispose is allowed for screen-scoped state (D-23, recorded in providers.dart:1-10). The `build()`-seeds-then-async-loads pattern in LocaleController is exactly how the editor should seed defaults then load `findForSupplement` (PF-8: reuse existing regimen/slot ids).

### `lib/features/stack/stack_status.dart` (pure helpers)

**Analog:** `combineStackEntries` in `lib/core/domain/repositories.dart:97-108` — top-level pure function, no clock reads, collection-for style:
```dart
List<StackEntry> combineStackEntries(
  List<Supplement> supplements, List<Regimen> regimens) {
  final bySupplement = <String, Regimen>{
    for (final r in regimens.reversed) r.supplementId: r,
  };
  return [
    for (final s in supplements)
      StackEntry(supplement: s, regimen: bySupplement[s.id]),
  ];
}
```
`statusOf(StackEntry e, DateTime today)` follows this shape with `today` passed explicitly (analog: `isActiveOn(Regimen r, DateTime day)` in `lib/core/domain/cycle_math.dart` — domain never reads the clock; use `dateOnly()` from cycle_math for comparisons).

### `lib/features/stack/catalog.dart` (const descriptors)

**Analog (style):** `lib/core/theme/tokens.dart:79-90` — `abstract final class` holding a const, index-stable list:
```dart
abstract final class BqSeriesColors {
  static const List<Color> palette = [ Color(0xFFB08A2A), ... ]; // 8, do not reorder
}
```
Use `BqSeriesColors.palette[stackCount % 8]` for auto-assigned colors. CatalogEntry class + `lookupAppLocalizations` search per RESEARCH P-1/P-2 (no codebase analog — new pattern, code in RESEARCH).

### `lib/core/db/drift_repositories.dart` — `softDeleteCascade` + `watchDay` filters

**Analog: itself.** Three existing excerpts to compose:

Soft-delete stamp pattern (lines 60-65):
```dart
Future<void> softDelete(String id) async {
  final now = DateTime.now().toUtc();
  await (db.update(db.supplements)..where((t) => t.id.equals(id))).write(
    SupplementsCompanion(deletedAt: Value(now), updatedAt: Value(now)),
  );
}
```

Multi-table transaction pattern (lines 105-155, `DriftRegimenRepository.upsert`): `db.transaction(() async { ... })` wrapping select-then-write with one `now` captured up front; conditional soft-delete via `..where((t) => t.regimenId.equals(r.id) & t.deletedAt.isNull() & ...)` then `.write(...Companion(deletedAt: Value(now), updatedAt: Value(now)))` (lines 145-154). The cascade is exactly this shape across supplements → regimens → regimenSlots → intakeLogs (`status.equals` pending + `date.isBiggerOrEqualValue(fromDay)`; `IntakeLogs` has `regimenId` directly — no join needed).

`watchDay` where-clause to extend (lines 273-275):
```dart
..where(db.intakeLogs.date.equals(utcDay) &
    db.regimens.deletedAt.isNull() &
    db.supplements.deletedAt.isNull())
```
Add: `& db.intakeLogs.deletedAt.isNull()` and the pause filter `& (db.regimens.paused.equals(false) | db.intakeLogs.status.equalsValue(domain.DoseStatus.pending).not())` (pause = query filter, PF-1; check how `status` is mapped — it's a Drift type converter column, use the same comparison style as line 273 with the converter). Keep file header rules (lines 1-15): no Drift delete statement anywhere; every mutation bumps `updatedAt`.

### `lib/core/domain/repositories.dart` — interface addition

**Analog: itself.** Doc-comment style for the new method mirrors lines 53-55/74-76 ("Soft delete: stamps `deletedAt`, never removes the row (DATA-02)"). Add `Future<void> softDeleteCascade(String supplementId, {required DateTime fromDay});` to `SupplementRepository` with the RESEARCH P-8 doc comment (fromDay passed by caller — domain never reads the clock). File stays pure Dart: imports only `models.dart`.

### `lib/core/theme/theme.dart` — theme extensions

**Analog: itself** (lines 17-72). Extend `bqTheme()`'s `ThemeData(...)` with `inputDecorationTheme`, `sliderTheme`, `datePickerTheme`, `timePickerTheme`, `bottomSheetTheme` — every value from `BqColors`/`BqRadii` only (the file's own header, lines 1-10, states the zero-hex-literal rule). Follow the existing sub-theme style, e.g. `navigationBarTheme` (lines 50-70) with `WidgetStateProperty.resolveWith` for state-dependent colors.

### ARB files — ~25 new keys

**Analog:** `lib/core/l10n/arb/app_en.arb` `weeksCount` (lines 32-40) for plural keys:
```json
"weeksCount": "{count, plural, one{{count} week} other{{count} weeks}}",
"@weeksCount": {
  "description": "Count of weeks in a planner range",
  "placeholders": { "count": { "type": "int" } }
}
```
uk file mirrors with all four CLDR forms (one/few/many/other — see `app_uk.arb` weeksCount). Every key added to BOTH files in the same commit (PF-4); `@`-metadata with description on every key. Key list + uk copy in RESEARCH "Code Examples". Run `flutter gen-l10n` (output in `lib/core/l10n/gen/`, `nullable-getter: false` per `l10n.dart:9-11`).

## Shared Patterns

### Repo test harness (in-memory Drift)
**Source:** `test/db/repositories_test.dart:14-50`
**Apply to:** `cascade_delete_test.dart`, `pause_filter_test.dart`
```dart
setUp(() {
  db = BoostqueDb.forTesting(NativeDatabase.memory());
  supps = DriftSupplementRepository(db);
  regs = DriftRegimenRepository(db);
  intake = DriftIntakeRepository(db);
});
tearDown(() => db.close());
// fixtures: const s1 = Supplement(id: 's1', name: 'Магній', ...);
// Regimen r1({slots}) => Regimen(id: 'r1', supplementId: 's1',
//   kind: RegimenKind.cyclic, startDate: DateTime.utc(2026, 8, 1), ...);
```
Soft-delete survival is proven with raw table reads (lines 100-103): `final raw = await db.select(db.supplements).get(); expect(raw.single.deletedAt, isNotNull);` — copy this for "history rows keep deletedAt == null / pending rows stamped" assertions.

### Provider-graph test harness (db override + polling)
**Source:** `test/providers_test.dart:18-43`
**Apply to:** widget tests needing a live DB (`stack_screen_test.dart`, `regimen_editor_test.dart`)
```dart
container = ProviderContainer(overrides: [
  dbProvider.overrideWith((ref) {
    final db = BoostqueDb.forTesting(NativeDatabase.memory());
    ref.onDispose(db.close);
    return db;
  }),
]);
// keep graph alive: final sub = container.listen(stackEntriesProvider, (_, _) {});
// poll AsyncData with `if (value case AsyncData(value: final data) when ...)`
```
For widget tests, the same override goes into `ProviderScope(overrides: [...])`.

### Widget test app wrapper (locale + theme)
**Source:** `test/widget/app_shell_test.dart:16-33`
**Apply to:** all new widget tests
```dart
SharedPreferences.setMockInitialValues({}); // in setUp (LocaleController loads prefs)
ProviderScope(
  child: MaterialApp(
    locale: const Locale('uk'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: bqTheme(),
    home: const AppShell(), // or the screen under test
  ),
)
```
Overflow assertion pattern: `expect(tester.takeException(), isNull);` after pumping uk (longest strings).

### Plural test pattern (no widget pump)
**Source:** `test/l10n/plurals_test.dart:18-29`
**Apply to:** plural-test extension for `slotsPerDay`, `stackSummary`; also `catalog_search_test.dart` (synchronous alternative: `lookupAppLocalizations(const Locale('en'))`)
```dart
l10n = await AppLocalizations.delegate.load(const Locale('uk'));
expect(l10n.weeksCount(11), '11 тижнів'); // exemplars: 1, 2, 5, 11, 21
```

### Clock/date discipline
**Source:** `lib/core/db/drift_repositories.dart` (every mutation: `final now = DateTime.now().toUtc();` captured once at the boundary) + `dateOnly()` in `lib/core/domain/cycle_math.dart`
**Apply to:** cascade impl, editor save, `statusOf` callers (pass `dateOnly(DateTime.now())` in from the widget layer, never inside domain helpers). Picker results normalized via `dateOnly(picked)` immediately (PF-2).

### File-header doc comment convention
Every non-trivial lib file opens with a `///` library doc explaining its rules and citing decision IDs (see drift_repositories.dart:1-15, providers.dart:1-22, tokens.dart:1-8), followed by `library;`. New files (catalog.dart, controllers, cascade docs) should follow this.

## No Analog Found

| File | Role | Data Flow | Reason |
|------|------|-----------|--------|
| `lib/core/widgets/bq_segmented.dart` | component | callback | No custom controls exist yet (`lib/core/widgets/` doesn't exist — create it). Build per RESEARCH P-10 (~30 lines: decorated container, Row of Expanded GestureDetectors, `Semantics(selected: ...)`). Style from tokens: bg via hairline-ish overlay, `BqRadii.seg`, active `BqColors.surface`/`ink`, inactive `textSecondary`. |
| Bottom-sheet + picker wiring | component | form | No sheets/pickers in Phase 1; RESEARCH P-3/P-7/PF-6 contain the exact SDK code (cited from api.flutter.dev). |
| Cycle preview strip | component | transform | Bespoke; RESEARCH P-9 — drive 28 bars off `isActiveOn(draftRegimen, ...)`, colors `BqColors.accent`/`BqColors.field`. |

## Metadata

**Analog search scope:** `lib/` (all 21 files listed), `test/` (all 10 files); read in full: stack/settings screens, providers.dart, drift_repositories.dart, repositories.dart, tokens.dart, theme.dart, locale_controller.dart, l10n.dart, app_en.arb, plurals_test.dart; partial: repositories_test.dart, providers_test.dart, app_shell_test.dart
**Files scanned:** 31
**Pattern extraction date:** 2026-08-15
