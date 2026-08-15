# Phase 2: Stack Management - Research

**Researched:** 2026-08-14
**Domain:** Flutter feature UI — Stack screen, add-supplement flow, bundled locale-aware catalog, regimen editor (cyclic/course, 1–6 slots), pause/resume, cascade soft delete — over the Phase-1 domain/DB/provider foundation
**Confidence:** HIGH (all Phase-1 code and the mockup were read line-by-line this session; Flutter picker/SegmentedButton APIs fetched from api.flutter.dev this session; Riverpod-3 family syntax verified via riverpod.dev migration docs; a small number of copy/translation items flagged ASSUMED)

<user_constraints>
## User Constraints (no CONTEXT.md exists — sources: approved design spec `docs/superpowers/specs/2026-08-14-boostque-v1-design.md`, `.claude/CLAUDE.md`, Phase-1 locked decisions)

### Locked Decisions
- Flutter + Dart single codebase; Riverpod + Drift; UI depends on repository interfaces only (`SupplementRepository`/`RegimenRepository`/`IntakeRepository`) — Drift types never appear in `features/`
- Zero hardcoded user-visible strings (gen-l10n, en/uk ARBs, uk uses all four CLDR plural forms); locale-aware date/number formatting; no fixed-width text containers; `EdgeInsetsDirectional` only
- Date-only values normalized as `DateTime.utc(y,m,d)`; domain never reads the clock
- Soft delete only — no hard deletes anywhere (DATA-02); UUID PKs, createdAt/updatedAt on every row
- UUIDs minted via `const Uuid().v4()` at the repository/controller boundary, never in Drift defaults, never scattered in widget build methods
- Riverpod dispose policy (D-23): app-lifetime repo/stream providers NOT autoDispose; screen-scoped state MAY be autoDispose — recorded in `core/providers.dart`, do not re-litigate
- Token-only styling (D-07): all UI styled exclusively via `BqColors`/`BqRadii`/`BqSpace`/`bqTheme()` — no ad-hoc hex literals in feature code
- No new packages without strong justification (D-04); no google_fonts; never hand-pin intl
- Mockup `claude_design_mockup/Boostque v0.1.dc.html` is the authoritative visual reference (screens 01 and 05 for this phase)
- v1 scope: Stack + Calendar tabs (+ Settings shell); Advisor tab, camera/OCR label scanning, scores, subscriptions, notifications are OUT of v1

### Claude's Discretion
- Exact file organization inside `features/stack/`, widget decomposition, empty-state design (mockup shows none)
- English translations of mockup's Ukrainian copy (mockup is uk-only)
- Catalog storage format and entry count (research recommendation below)
- Whether to model the `fresh` ("ЩОЙНО ДОДАНО") status from the mockup or collapse it into planned/no-chip

### Deferred Ideas (OUT OF SCOPE)
- Camera · етикетка tab in the add sheet (SCAN-01, v2) — mockup shows it; v1 replaces it with manual entry
- Interaction notes/warnings in catalog entries ("1 взаємодія з вашим профілем", "перевірте з сертраліном") — naive interaction checking is explicitly never-ship (REQUIREMENTS Out of Scope)
- Quality scores (`score:` fields in mockup data), Free-plan banner / Boostque Plus, Радник/Профіль tabs
- Notifications, widgets, export, sync
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| STACK-01 | Add a supplement from a bundled, locale-aware catalog by searching its name | P-1 (catalog format: ARB-backed entries), P-2 (search matching), catalog content table extracted verbatim from mockup |
| STACK-02 | Add a supplement manually with name + dose description | P-3 (add sheet flow), PF-6 (bottom-sheet keyboard), validation rules V-1 |
| STACK-03 | Stack as cards: name, dose, color tag, status, schedule summary | P-4 (StackEntry → card mapping incl. status derivation and summary line), mockup card spec quoted |
| STACK-04 | Edit/delete supplement; delete soft-deletes regimen + future doses | P-8 (cascade soft delete repo API + transaction), PF-1 (log-revival trap), Edge Coverage |
| REGI-01 | Cyclic regimen: start date, on/off days in 7-day steps | P-6 (sliders 7–112/0–84 step 7), P-7 (pickers), P-9 (cycle preview strip from `isActiveOn`) |
| REGI-02 | One-time course, start + inclusive end | P-6/P-7; `isActiveOn` course branch already inclusive (verified below); validation V-1 |
| REGI-03 | 1–6 daily time slots, each with own time + dose label | P-5 (editor state), P-7 (TimeOfDay↔minutes), mockup slot spec (max 6, min 1, auto-sort) quoted |
| REGI-04 | Pause/resume; paused produces no doses, shows ПАУЗА | P-8 pause semantics (query-filter, NOT row mutation — see PF-1), `setPaused` already exists in repo |
</phase_requirements>

## Project Constraints (from CLAUDE.md)

- Follow GSD workflow for all file changes; tech stack and package set is locked (no `google_fonts`, no `sqlite3_flutter_libs`, no hand-pinned `intl`, `mocktail` not `mockito`)
- `flutter analyze` clean and `flutter test` green are exit criteria for every plan
- Custom-painted/plain-widget UI for bespoke layouts rather than generic packages (locked reasoning in "What NOT to Use": no `table_calendar`-style packages; `showDatePicker`/`showTimePicker` reserved for "the one place a genuine picker is needed — the Dosing Schedule editor's time-slot input" — i.e., THIS phase is that place)
- Bundle id placeholder `com.boostque.dev`; no store-release work in this phase

## Summary

Phase 2 needs **zero new packages** — every UI surface it requires (modal bottom sheet, segmented control, sliders with discrete divisions, date/time pickers, text form fields, JSON/const data) is in the Flutter SDK, and every persistence surface already exists in Phase-1 repositories except one: **cascade soft delete**. The single genuine API change this phase must make to Phase-1 code is adding a cascade-delete operation (supplement → regimen → slots → future *pending* IntakeLogs in one transaction) and a small filter fix in `watchDay`. Everything else is feature-layer code in `lib/features/stack/`.

Three research findings materially shape the plan. First, **pause must be implemented as a query-level filter, not a row mutation**: soft-deleting pending logs on pause would permanently block re-materialization on resume, because `ensureLogsForDay` uses `InsertMode.insertOrIgnore` against the unique `(slotId, date)` key — a soft-deleted row still occupies the key, so the insert is silently ignored and the resumed regimen produces no dose that day (PF-1). Delete may soft-delete future pending logs precisely because delete is permanent. Second, the **catalog should live in ARB files, not a JSON asset**: the locked i18n rule is "a new language = one new .arb file, no code changes," and gen-l10n's generated synchronous `lookupAppLocalizations(locale)` makes cross-locale search (typing "creatine" while in uk) trivially cheap — a JSON asset would break the one-ARB-per-language rule and reintroduce runtime parse risk (P-1). Third, **Riverpod 3 removed `FamilyNotifier`**: a per-supplement editor controller uses `Notifier` with a constructor argument and `NotifierProvider.autoDispose.family` — the older `build(arg)` override no longer exists (P-5).

The mockup (read line-by-line this session) pins down nearly every open number: slider ranges `min="7" max="112" step="7"` (on) and `min="0" max="84" step="7"` (off), slot cap 6 / floor 1 with auto-sort on edit, default slot times `['08:00','13:00','19:00','22:00','10:30','16:00']`, all four status chip labels with exact colors, and a 15-name catalog. The mockup also contains things v1 must *not* ship (camera tab, interaction warnings, scores, a supplement dropdown in the editor) — these are enumerated in PF-5 so the planner doesn't port them by accident.

**Primary recommendation:** Build in three slices — (1) repo delta: cascade soft delete + `watchDay` filters + tests; (2) Stack screen + add sheet + ARB catalog; (3) regimen editor + pause/delete wiring — with the shared `BqSegmented` control hand-built once (used again by Phase 4's Рік/Цикли toggle).

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Stack list rendering, cards, chips | Widget/UI (`features/stack`) | State (`stackEntriesProvider`, already built) | Pure consumption of the existing composed provider |
| Status + schedule-summary derivation | Domain-ish pure helpers (`features/stack` view-model fn or `core/domain`) | Widget | Pure function of `StackEntry` + explicit `today` param — unit-testable without widgets |
| Catalog data + search | Widget/UI (`features/stack/catalog.dart`) + gen-l10n (`core/l10n`) | — | Names/doseText are localized strings (ARB); ids/colors are const Dart |
| Add/edit supplement + regimen editor forms | Widget/UI + screen-scoped state (autoDispose Notifier or ConsumerStatefulWidget) | Repositories via `ref.read` | Ephemeral draft state; save crosses the repository interface only |
| Cascade soft delete, pause filtering | Data/Persistence (`core/db/drift_repositories.dart`) + interface change (`core/domain/repositories.dart`) | — | Multi-table transaction; only `core/db` may import Drift |
| Cycle preview strip (28 bars) | Widget/UI | Domain (`isActiveOn`) | Derive bar on/off from the draft `Regimen` via the single source of cycle truth |
| Date/time picking, locale formatting | Flutter SDK (`showDatePicker`/`showTimePicker`, `MaterialLocalizations`, `DateFormat`) | Theme (`bqTheme()` additions) | Locale flows from `MaterialApp` delegates already wired in Phase 1 |

## Standard Stack (delta)

### New packages required: NONE

Every capability maps to the SDK or already-installed packages [VERIFIED: pubspec deps read via Phase-1 code/docs this session]:

| Need | Use (already available) | Notes |
|------|------------------------|-------|
| Bottom sheet (add flow) | `showModalBottomSheet(isScrollControlled: true, ...)` | SDK. See PF-6 for keyboard inset handling |
| Segmented controls (Циклічно/Разовий курс; Пошук/Вручну) | Hand-built `BqSegmented` widget (see P-10) | SDK `SegmentedButton` exists [CITED: api.flutter.dev/flutter/material/SegmentedButton-class.html — `segments`, `selected`, `onSelectionChanged`, `showSelectedIcon`, `styleFrom`] but its M3 look (outlines + checkmark) fights the mockup's padded-pill design; ~30 lines of plain widgets match exactly |
| Sliders with 7-day steps | SDK `Slider(min, max, divisions)` | on: min 7, max 112, divisions 15; off: min 0, max 84, divisions 12 (mockup values, quoted in P-6) |
| Date pickers | `showDatePicker` | Has optional `locale` param; "defaults to the ambient locale provided by Localizations" [CITED: api.flutter.dev/flutter/material/showDatePicker.html]. Returns local `DateTime` → normalize with `dateOnly()` immediately (PF-2) |
| Time pickers | `showTimePicker` | Returns `TimeOfDay?`; 24-h display forced via `builder: (ctx, child) => MediaQuery(data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true), child: child!)` [CITED: api.flutter.dev/flutter/material/showTimePicker.html — builder "can be used to wrap the dialog widget to add inherited widgets like … MediaQuery"] |
| UUIDs for new supplement/regimen/slots | `uuid` (installed) | Minted in the save controller / repository boundary, never in `build()` |
| Locale-aware dates/numbers | `intl` `DateFormat` (installed, SDK-resolved) | e.g. `DateFormat.yMd(localeName)` → uk `14.08.2026` |
| Catalog | gen-l10n ARB entries + const Dart descriptor list | No asset pipeline needed (P-1) |

### Theme delta

`bqTheme()` currently defines only `textTheme` + `navigationBarTheme` [VERIFIED: lib/core/theme/theme.dart:17-73 grep this session — no datePickerTheme/timePickerTheme/inputDecorationTheme/sliderTheme/bottomSheetTheme entries exist]. This phase should extend `bqTheme()` with, at minimum: `inputDecorationTheme` (white fill, radius 11–12, hairline border per mockup fields), `sliderTheme` (accent active track — mockup `accent-color:#4A4E7C`), `datePickerTheme`/`timePickerTheme` (surface/accent from tokens), `bottomSheetTheme` (paper background, top radius ~26 per mockup sheet). All values from `BqColors`/`BqRadii` only (D-07).

## Package Legitimacy Audit

No packages added this phase. Existing dependency set unchanged from Phase 1's audit (all `OK`/approved). **Packages removed due to [SLOP] verdict:** none. **Packages flagged as suspicious [SUS]:** none. (`node`/`gsd-tools` still unavailable in this sandbox — no automated seam run; irrelevant since the install delta is empty.)

## Architecture Patterns

### System flow (this phase)

```
StackScreen (features/stack)
  ├─ watches stackEntriesProvider (exists, core/providers.dart:76-88)
  │     AsyncValue<List<StackEntry>> → cards (P-4)
  ├─ "Додати добавку" → AddSupplementSheet (showModalBottomSheet)
  │     ├─ tab Пошук: query → catalogSearch (P-2) over ARB catalog (P-1)
  │     ├─ tab Вручну: name + doseText form (V-1)
  │     └─ on pick/save: supplementRepo.upsert(new Supplement(uuid, ...))
  │           → push RegimenEditorScreen(supplementId)
  └─ tap card → RegimenEditorScreen(supplementId)
        ├─ loads regimenRepo.findForSupplement(supplementId)  ← reuse existing id! (PF-8)
        ├─ draft state: editor controller (P-5); pickers (P-7); preview strip (P-9)
        ├─ save → regimenRepo.upsert(draft Regimen)   (slot reconciliation already in Phase-1 impl)
        ├─ pause/resume → regimenRepo.setPaused(id, bool)
        └─ delete → supplementRepo.softDeleteCascade(supplementId, fromDay: today) (P-8) → pop
```

### P-1: Catalog as ARB-backed entries + const Dart descriptor list

**What:** The bundled catalog lives in two coordinated pieces:
1. **ARB keys** in `app_en.arb`/`app_uk.arb` — `catalogCreatineName`, `catalogCreatineDose`, etc. (localized, translator-owned, compile-time checked by gen-l10n).
2. **A const descriptor list** in `lib/features/stack/catalog.dart` — id, color, and *function references* to the gen-l10n getters:

```dart
// Pattern (names resolved through gen-l10n, per-locale, compile-checked):
class CatalogEntry {
  final String id;
  final Color color; // from BqSeriesColors or mockup PLAN color
  final String Function(AppLocalizations) name;
  final String Function(AppLocalizations) doseText;
  const CatalogEntry(this.id, this.color, this.name, this.doseText);
}

const _entries = <CatalogEntry>[ /* 15 entries, table below */ ];
```

**Why this beats a JSON asset** (the older superpowers plan's choice, superseded): the locked i18n rule is "a new language = one new .arb file, no code changes" — a JSON asset with `{"en":..,"uk":..}` maps breaks that rule and adds an async `rootBundle.loadString` + runtime `jsonDecode` failure mode for what is a ~15-row static list. gen-l10n additionally generates a **synchronous** `lookupAppLocalizations(Locale)` function in `app_localizations.dart` (it is what the generated delegate calls), so cross-locale search needs no async loading. Alternative (JSON asset) remains viable if the catalog is expected to grow into the hundreds or be remotely updated — it isn't in v1.

**Copy-on-add semantics (important):** selecting a catalog entry copies the *currently-active locale's* name/doseText into the `Supplement` row via `supplementRepo.upsert`. From that moment it is user data — switching the app language later must NOT rename supplements already in the stack. Document this in the plan so Phase 5's l10n verification doesn't misread it as a bug.

**Catalog content for v1** — extracted verbatim from the mockup [VERIFIED: claude_design_mockup/Boostque v0.1.dc.html:596-605 (`CATALOG`), 587-595 (`BASE_STACK`), 630-638 (`PLAN` colors)]. Mockup quotes:

```
CATALOG: 'Ашваганда KSM-66', 'Креатин моногідрат', 'Мелатонін 3 мг', 'NMN 250 мг',
         'Вітамін B12 метилкобаламін', 'Коензим Q10 убіквінол', 'Йод 150 мкг', 'Залізо бісглицинат'
BASE_STACK: 'Зверобій' (екстракт 300 мг · капсули), 'Магній бісглицинат' (400 мг · капсули),
         'Хондропротектор' (глюкозамін 500 + хондроїтин 400), 'Вітамін D3' (2000 МО · краплі),
         'Омега-3' (EPA 500 / DHA 250), 'Цинк піколінат' (15 мг · таблетки), 'Куркумін' (500 мг + піперин)
PLAN colors: Вітамін D3 #B08A2A · Омега-3 #2F3457 · Хондропротектор #3F7A6A ·
         Магній #6B6FA8 · Зверобій #C4685E · Цинк #2F7A85 · Куркумін #C07A3A
```

Recommended v1 catalog = union of the two lists (15 entries), colors from `PLAN` where given, remaining 8 assigned round-robin from `BqSeriesColors.palette`. English names/doseText are Claude-discretion translations [ASSUMED — mockup is uk-only; en renderings like "Creatine monohydrate", "5 g · powder" need user eyes at UAT]. **Strip every catalog `note`/`score`/`schedule` field from the mockup — they contain interaction claims and scores that are out of scope (see PF-5).**

### P-2: Catalog search matching

**What:** Case-insensitive substring match, across *both* shipped locales:

```dart
List<CatalogEntry> searchCatalog(String query, AppLocalizations active) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return _entries;                       // mockup shows full list for empty query
  final en = lookupAppLocalizations(const Locale('en')); // synchronous, generated by gen-l10n
  return _entries.where((e) =>
      e.name(active).toLowerCase().contains(q) ||
      e.name(en).toLowerCase().contains(q)).toList();
}
```

- Dart's `String.toLowerCase()` applies Unicode default case mappings, which correctly folds Ukrainian Cyrillic (А→а, Ї→ї, Є→є, І→і) — no locale-specific casing exceptions exist for uk (unlike Turkish dotless-ı) [ASSUMED — standard Dart/Unicode behavior, not re-verified against a spec this session; risk is nil for the Cyrillic range].
- Ukrainian needs no diacritic *stripping* — ї/й/є/і are distinct letters, not accents; do NOT write a diacritic-folding layer (Don't Hand-Roll).
- Matching against en in addition to the active locale lets a uk-locale user type latin ("creatine", "nmn", "b12") — mockup entries like `NMN 250 мг` mix scripts anyway.
- Mockup uses `contains`, not prefix match [VERIFIED: mockup line 707: `CATALOG.filter(c => !q || c.name.toLowerCase().includes(q))`] — keep `contains`.

### P-3: Add-supplement bottom sheet

**What:** `showModalBottomSheet(isScrollControlled: true, ...)` hosting: drag handle, title "Додати добавку" + "Закрити", a two-tab `BqSegmented` (Пошук у базі / Вручну — the mockup's second tab is camera, replaced per v1 scope), search field + result rows, or the manual form (name required, doseText). Selecting a result or saving the manual form: mint `const Uuid().v4()`, `supplementRepo.upsert(...)`, close sheet, push `RegimenEditorScreen(supplementId: id)`. Color auto-assigned round-robin: `BqSeriesColors.palette[stackCount % 8]` (discretion: least-used instead of round-robin).

Mockup visual spec for result rows [VERIFIED: mockup lines 139-147]: search input white/radius 11/padding 13-14; result card white/radius 12/padding 13-14, name w600 14, note muted 12, trailing accent "+". No-results copy must be REWRITTEN (mockup's mentions label scanning — v2; see PF-5).

### P-4: StackEntry → card mapping (status derivation + schedule summary)

**Inputs already exist:** `stackEntriesProvider` yields `AsyncValue<List<StackEntry>>` where `StackEntry { supplement, regimen? }` [VERIFIED: lib/core/providers.dart:76-88, lib/core/domain/repositories.dart:19-24]. `combineStackEntries` maps at most one regimen per supplement (last-created wins via `regimens.reversed`) [VERIFIED: repositories.dart:97-108].

**Status derivation** — pure function, `today` passed explicitly (domain never reads the clock):

```dart
enum StackStatus { fresh, active, paused, planned }
StackStatus statusOf(StackEntry e, DateTime today) {
  final r = e.regimen;
  if (r == null) return StackStatus.fresh;          // just added, no schedule yet
  if (r.paused) return StackStatus.paused;
  if (dateOnly(today).isBefore(dateOnly(r.startDate))) return StackStatus.planned;
  // course already ended → also 'planned'? No — see Edge Coverage E-4.
  return StackStatus.active;
}
```

Chip styling verbatim from mockup [VERIFIED: mockup lines 581-586]:

```
active:  { label: 'АКТИВНА',      fg: '#3F7A6A', bg: '#E8F1ED' }   → BqColors.calm / calmBg
paused:  { label: 'ПАУЗА',        fg: '#5C5C66', bg: '#F2F1EE' }   → textSecondary / chip
planned: { label: 'ЗАПЛАНОВАНО',  fg: '#4A4E7C', bg: '#EDEDF4' }   → accent / accentChipBg
fresh:   { label: 'ЩОЙНО ДОДАНО', fg: '#4A4E7C', bg: '#EDEDF4' }   → accent / accentChipBg
```

Card anatomy [VERIFIED: mockup lines 107-119]: white card radius 14, 4px-wide color bar (supplement.colorValue, opacity .85), name w600 15, doseText muted 12.5, chips row = status chip (JetBrains Mono 10.5) + schedule chip (neutral `chip` bg).

**Schedule summary line** — derive from the regimen, via ARB keys with ICU plurals (do NOT copy the mockup's naive `'N рази на день'`, which is wrong Ukrainian for N≥5 — see PF-7):
- cyclic: on/off weeks — reuse existing `weeksCount` plural key; e.g. `"8 тиж / 4 тиж · 3 слоти"` or the fuller mockup phrasing `"{on} прийому, потім {off} перерви"` [VERIFIED: mockup line 938 builds `nw(schedOn)+' прийому, потім '+…+' перерви'`]; offDays == 0 → `'без перерви'` [VERIFIED: mockup line 934]
- course: locale-formatted date range (`DateFormat.yMd`), e.g. `"14.08.2026 – 30.09.2026"`
- slot count: new plural key `slotsPerDay` (uk: `раз/рази/разів на день`, all four CLDR forms)

**Header summary** [VERIFIED: mockup line 856]: `'{total} добавка/добавки/добавок · {active} активна/активні/активних'` — needs a two-placeholder ARB key with plurals on both.

### P-5: Editor state — Riverpod 3 family syntax (FamilyNotifier is GONE)

**Finding:** Riverpod 3.0 **removed `FamilyNotifier`**. A parametrized Notifier now takes its argument through a constructor, and the provider is built with `.family` (optionally `.autoDispose`):

```dart
// [CITED: riverpod.dev/docs/3.0_migration — "replace FamilyNotifier with Notifier, remove the
//  parameter from build and add a constructor"; corroborated by riverpod.dev/docs/whats_new]
class RegimenEditorController extends Notifier<RegimenDraft> {
  RegimenEditorController(this.supplementId);
  final String supplementId;

  @override
  RegimenDraft build() { /* seed defaults; async-load existing via ref/future */ }

  void setKind(RegimenKind k) => state = state.copyWith(kind: k);
  void addSlot() { /* cap 6, default times, sort */ }
  Future<void> save() async { /* build Regimen, reuse ids, regimenRepo.upsert */ }
}

final regimenEditorProvider = NotifierProvider.autoDispose
    .family<RegimenEditorController, RegimenDraft, String>(
  RegimenEditorController.new,
);
```

`autoDispose` is correct here per the locked D-23 policy (screen-scoped state MAY be autoDispose). A `ConsumerStatefulWidget` with plain local state is an equally valid, simpler alternative for this single-screen form — either satisfies the constraints; the Notifier variant is more unit-testable (drive `setKind/addSlot/save` without pumping widgets). Recommend the Notifier variant. Manual (non-codegen) syntax only — no `riverpod_generator` in this project.

**Draft seeding defaults** [VERIFIED: mockup lines 673-674]: `schedMode: 'cyclic', schedOn: 56, schedOff: 28`, slots default `[{08:00}, {13:00}, {19:00}]` in the mockup demo; a NEW regimen should start with 1 slot at 08:00 (superpowers plan Task 9 test expects `slots.single.minutesFromMidnight == 8*60`) — planner's call, but pick one and test it. Next-slot defaults when adding [VERIFIED: mockup line 650]: `NEXT_SLOT = ['08:00','13:00','19:00','22:00','10:30','16:00']`, fallback `'21:00'`; slots auto-sort by time after add/edit [VERIFIED: mockup lines 678-685, 952-955].

### P-6: Sliders — exact mockup ranges

[VERIFIED: mockup lines 520 and 525, quoted verbatim]:

```html
<input type="range" min="7"  max="112" step="7" value="{{ schedOn }}">   <!-- Довжина циклу -->
<input type="range" min="0"  max="84"  step="7" value="{{ schedOff }}">  <!-- Перерва -->
```

Flutter mapping: `Slider(min: 7, max: 112, divisions: 15, value: onDays.toDouble(), ...)` and `Slider(min: 0, max: 84, divisions: 12, ...)`. Value labels: on → `weeksCount(onDays ~/ 7)`; off → `offDays == 0 ? l10n.noBreak : weeksCount(offDays ~/ 7)`. Note `onDays` can never be 0 through this UI (min 7) — the domain's `onDays <= 0 → inactive` branch stays a defensive guard only.

### P-7: Date/time pickers + TimeOfDay↔minutes

```dart
// Date (start / course end):
final picked = await showDatePicker(
  context: context,
  initialDate: current ?? today,          // must lie within first/last or it asserts (PF-2)
  firstDate: DateTime(2020), lastDate: DateTime(2035),
); // locale comes from MaterialApp's delegates automatically [CITED: api.flutter.dev showDatePicker —
   // "defaults to the ambient locale provided by Localizations"]
if (picked != null) controller.setStartDate(dateOnly(picked)); // ← normalize IMMEDIATELY (PF-2)

// Time slot:
final tod = await showTimePicker(
  context: context,
  initialTime: TimeOfDay(hour: m ~/ 60, minute: m % 60),
  builder: (ctx, child) => MediaQuery(
    data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true), child: child!),
); // [CITED: api.flutter.dev showTimePicker example — exactly this MediaQuery wrap]
if (tod != null) controller.setSlotTime(i, tod.hour * 60 + tod.minute);
```

Display formatting for slot times: `MaterialLocalizations.of(context).formatTimeOfDay(tod, alwaysUse24HourFormat: true)` to match the mockup's 24-h mono rendering (`08:00`), or honor `MediaQuery.alwaysUse24HourFormatOf(context)` if the planner prefers strict locale behavior — pick one and use it for BOTH the picker and the display so they never disagree (PF-3). Date display: `DateFormat.yMd(Localizations.localeOf(context).toString())` → uk `14.08.2026` matching mockup [VERIFIED: mockup line 508 shows `14.08.2026`].

### P-8: Cascade soft delete + pause semantics (the repo API delta)

**Current state** [VERIFIED: lib/core/db/drift_repositories.dart:60-65 — `DriftSupplementRepository.softDelete` stamps ONLY the supplements row; :166-171 — regimen softDelete only regimens row; :257-279 — `watchDay` filters `regimens.deletedAt.isNull() & supplements.deletedAt.isNull()` but has NO `intakeLogs.deletedAt` filter and NO `paused` filter].

**Delete (STACK-04):** add to `SupplementRepository` (interface in `core/domain/repositories.dart`, impl in `core/db`):

```dart
/// Soft-deletes the supplement, its regimen(s) and their slots, and every
/// PENDING IntakeLog dated [fromDay] (UTC date-only) or later — one transaction.
/// Past days and taken/skipped rows are never touched. [fromDay] is passed in
/// by the caller (dateOnly(DateTime.now())) — domain code never reads the clock.
Future<void> softDeleteCascade(String supplementId, {required DateTime fromDay});
```

Drift impl sketch: `db.transaction(() { stamp supplement; select regimen ids by supplementId where deletedAt null; stamp those regimens + their slots; update intakeLogs set deletedAt/updatedAt where regimenId in ids AND date >= fromDay AND status == pending; })`. `IntakeLogs` carries `regimenId` directly [VERIFIED: lib/core/db/database.dart:83-101 — `regimenId`, `slotId`, `date`, `status` columns, uniqueKeys `{slotId, date}`] so no join is needed for the log update. Soft-deleting logs is safe here — deletion is permanent, so the insertOrIgnore-revival trap (PF-1) cannot bite. Also add `intakeLogs.deletedAt.isNull()` to `watchDay`'s where-clause while touching this file (defense in depth + sync correctness).

**Pause (REGI-04):** `setPaused` already exists and `isActiveOn` already returns false for paused regimens [VERIFIED: lib/core/domain/cycle_math.dart:26-31 — `if (r.paused) return false;`], so no *future* doses materialize while paused. The remaining gap is **already-materialized pending rows** (e.g., user pauses at noon; today's rows exist). Handle by query filter, NOT row mutation: in `watchDay`, exclude rows where `regimens.paused == true AND intakeLogs.status == pending` — taken/skipped history stays visible, pending doses of a paused regimen vanish ("у календарі його не буде" [VERIFIED: mockup line 962]), and resume restores them instantly with zero writes. Phase 3 consumes this; implement + unit-test it now since REGI-04 is a Phase-2 requirement.

### P-9: Cycle preview strip (28 bars) via `isActiveOn`

Mockup renders 28 bars sampling 112 days at 4-day steps: `bg = (d % period) < schedOn ? accent : '#E4E3DD'` [VERIFIED: mockup lines 793-799]. In the app, don't re-derive modular arithmetic — build a throwaway draft `Regimen` (paused: false) from current form values and reuse the single source of truth:

```dart
final start = draft.startDate;
final bars = [ for (var i = 0; i < 28; i++)
  isActiveOn(draftRegimen, start.add(Duration(days: i * 4))) ]; // UTC date math — exact
```

Works unchanged for course mode (mockup hardcodes `d < 48` for the demo; the real strip should honor actual start/end). Bar colors: `BqColors.accent` / `BqColors.field`.

### P-10: Hand-built `BqSegmented`

Mockup segmented control [VERIFIED: mockup lines 500-503]: container `bg rgba(23,23,27,.09)`, radius 10 (`BqRadii.seg`), padding 2; segments padding 9-10, radius 8, active `bg #FFFFFF fg #17171B`, inactive `fg #5C5C66`, font 13–13.5 w500. SDK `SegmentedButton` renders M3 outlined segments with a selected checkmark — theming it to this look costs more than building it: a `Row` of two `Expanded` `GestureDetector`s inside a decorated container (~30 lines). Place it where Phase 4 can reuse it for the Рік/Цикли toggle (e.g., `lib/core/widgets/bq_segmented.dart` — discretion). Give it semantics (`Semantics(selected: ...)`/`MergeSemantics`) so it's accessible despite being custom.

### Anti-Patterns to Avoid

- **Soft-deleting IntakeLogs on pause** — permanently blocks re-materialization via insertOrIgnore (PF-1). Pause = query filter.
- **Creating a new regimen id on every editor save** — `findForSupplement` returns the *first* regimen; a fresh id per save accumulates ghost regimens (PF-8). Load-then-reuse the existing id.
- **Porting mockup content wholesale** — camera tab, interaction notes, scores, the editor's supplement `<select>` dropdown, Радник/Профіль tabs, Free-plan banner are all out of v1 scope (PF-5).
- **`StreamProvider.autoDispose` for the stack list** — the list providers already exist and are intentionally non-autoDispose (D-23); build screens on `stackEntriesProvider`, don't create parallel ones.
- **Formatting week/slot counts with string concatenation** — the mockup's own JS plural helper is 3-form (ru-style) and its `slotSummary` is grammatically wrong for uk at N≥5 (PF-7); every count goes through ICU plurals in ARB.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Date/time selection | Custom calendar/time widgets | `showDatePicker` / `showTimePicker` | Locale, a11y, keyboard input for free; CLAUDE.md explicitly reserves these SDK pickers for exactly this editor |
| Ukrainian search folding | Diacritic-stripping/transliteration layer | `trim().toLowerCase()` + `contains` | uk Cyrillic has no combining diacritics to strip; ї/є/і are letters; Unicode default case mapping suffices |
| Cross-locale catalog lookup | Async per-locale ARB loading or duplicate name tables | generated `lookupAppLocalizations(Locale)` (synchronous) | gen-l10n already generates it for the delegate; zero cost |
| Plural forms in summaries | Hand `if (n == 1)` logic | ICU plurals in ARB (`weeksCount` exists; add `slotsPerDay`, stack summary) | uk needs 4 CLDR forms incl. 11–14 exception — already proven by Phase-1 plural tests |
| Cycle preview math | Second modulo implementation in the widget | `isActiveOn` on a draft Regimen (P-9) | One source of cycle truth; DST-safety already unit-tested |
| Slot dedup/ordering on save | UI-side invariant juggling | Existing `RegimenRepository.upsert` slot reconciliation [VERIFIED: drift_repositories.dart:105-155 — transactional upsert + soft-delete of absent slots] | Already built and tested in Phase 1 |

## Validation Rules (V-1)

| Field | Rule | Enforced where |
|-------|------|----------------|
| Supplement name | non-empty after trim | Form (`TextFormField.validator` / disabled Save) — the only free-text hard requirement |
| doseText | optional, free text | Form only |
| onDays | 7..112, multiple of 7 | **By construction** (Slider divisions) + defensive domain assert (`onDays >= 0` exists [VERIFIED: models.dart:85]) |
| offDays | 0..84, multiple of 7 | By construction (Slider) |
| Course endDate | `!end.isBefore(start)` (end ≥ start; inclusive semantics already in `isActiveOn` [VERIFIED: cycle_math.dart:34-36 — `end != null && !d.isAfter(dateOnly(end))`]) | Form: constrain `showDatePicker(firstDate: startDate)` for the end picker AND clamp end when start moves past it |
| Slots | count 1..6; times unique per regimen recommended (duplicate times create two logs same minute — allowed by schema, confusing in UI) | By construction: "+" disabled at 6 [VERIFIED: mockup lines 950-952 — `canAddSlot: length < 6`], "−" disabled at 1 [VERIFIED: mockup lines 944-946 — `canRemove: length > 1`]; auto-sort after edit |
| minutesFromMidnight | 0..1439 | Domain assert exists [VERIFIED: models.dart:37-40]; TimeOfDay can't exceed it |

**Where validation lives:** structural constraints by widget construction (sliders, disabled buttons, picker ranges); the single free-text rule in the form; existing domain asserts stay as the defensive backstop. No validation framework, no new package.

## Common Pitfalls

### PF-1: The insertOrIgnore revival trap (pause must not soft-delete logs)
**What goes wrong:** If pausing soft-deletes pending IntakeLogs, resuming can never bring them back: `ensureLogsForDay` inserts with `InsertMode.insertOrIgnore` against unique `(slotId, date)` [VERIFIED: drift_repositories.dart:243-245, database.dart:97-100] — the soft-deleted row still holds the key, the insert is ignored, and the day silently shows no dose for the resumed regimen.
**Avoid:** Pause = query-level filter in `watchDay` (`paused AND pending` excluded); only permanent deletion (cascade) may stamp log rows. See P-8.
**Warning sign:** A test "pause → resume → ensureLogsForDay → watchDay" returns fewer doses than before the pause. Write exactly that test.

### PF-2: `showDatePicker` returns a LOCAL DateTime
**What goes wrong:** The picker resolves to a local-zone `DateTime`; storing it raw violates the `DateTime.utc(y,m,d)` date-only invariant and breaks cycle math near DST.
**Avoid:** `dateOnly(picked)` at the point of receipt, before it touches draft state. Also: `initialDate` must satisfy `firstDate <= initialDate <= lastDate` or the picker asserts — clamp when editing an old regimen.

### PF-3: Picker/display 12-h vs 24-h mismatch
**What goes wrong:** en locale defaults to 12-h AM/PM; the mockup's design language is 24-h mono (`08:00`). If the picker uses one convention and the slot row renders another, the screen looks broken in en.
**Avoid:** Decide once (recommend: force 24-h everywhere via the `builder` MediaQuery wrap + `formatTimeOfDay(..., alwaysUse24HourFormat: true)` — matches mockup and JetBrains Mono tabular layout); apply to both picker and display.

### PF-4: gen-l10n regeneration + uk plural completeness for every new key
**What goes wrong:** ~25 new ARB keys land this phase (list in Code Examples). A key added to `app_en.arb` but not `app_uk.arb` fails generation (or falls back per config); a uk plural missing `many` silently renders wrong at 5/11.
**Avoid:** Add to BOTH files in the same commit; every count-bearing key gets all four uk forms; extend the existing plural test (1, 2, 5, 11, 21 exemplars) to the new keys. Existing ARB has only 7 keys today [VERIFIED: lib/core/l10n/arb/app_en.arb — appTitle, tabStack, tabCalendar, tabSettings, disclaimerEducational, substancesCount, weeksCount].

### PF-5: Mockup content that must NOT ship in v1
The mockup is authoritative for *visuals*, not *scope*. Do not port: **camera tab** "Камера · етикетка" (mockup lines 135, 154-162 — SCAN-01 is v2; replace the second tab with manual entry); **no-results copy** (line 150 promises label scanning — rewrite); **catalog notes with interaction/medical claims** (lines 597-604: "1 взаємодія з вашим профілем", "перевірте з сертраліном", "обережно зі щитоподібною залозою" — liability, out of scope) and **`score` fields**; **the editor's supplement dropdown** (lines 488-497 — v1 arrives at the editor from a card; supplement context is read-only); **Радник/Профіль tabs** (v1 shell is Stack/Calendar/Settings, already built); **Free-plan banner** (line 94-99, `showFreeLimit` defaults false anyway).

### PF-6: Bottom sheet vs keyboard
**What goes wrong:** A default `showModalBottomSheet` sits under the keyboard; the search/name field gets hidden.
**Avoid:** `isScrollControlled: true` + wrap content with `Padding(padding: EdgeInsetsDirectional.only(bottom: MediaQuery.viewInsetsOf(context).bottom))` (directional padding per locked rule) and a scrollable body. Test on the smallest supported height.

### PF-7: The mockup's own plural bug — don't transliterate it
`slotSummary` in the mockup is `length === 1 ? '1 раз на день' : length + ' рази на день'` [VERIFIED: mockup line 949] — wrong for uk at 5-6 ("5 рази" should be "5 разів"), and its `plural()` helper is 3-form. ICU in ARB (one/few/many/other) fixes this for free; copy the *words*, not the logic.

### PF-8: One-regimen-per-supplement is an application invariant, not a DB constraint
`Regimens` has no unique key on `supplementId` [VERIFIED: database.dart:56-71]; `findForSupplement` returns the first match and `combineStackEntries` keeps one per supplement. The editor MUST: load `findForSupplement(supplementId)` → if present, reuse `regimen.id` (and existing slot ids for surviving slots) in the saved draft; only mint a new regimen UUID when none exists. Otherwise every save stacks another regimen row and materialization double-doses. Also note the accepted quirk: keeping a slot's id while changing its time retroactively changes the displayed time on past days (watchDay joins the live slot row) — acceptable for v1, worth a code comment.

### PF-9: Text input details for uk
Set `textCapitalization: TextCapitalization.sentences` and `keyboardType: TextInputType.text` on name/dose fields (Cyrillic keyboards honor capitalization hints); `textInputAction: TextInputAction.next/done`. No fixed-width containers around localized labels (locked rule) — chips and buttons must size to content.

## Code Examples

### New ARB keys (both files; uk copy verbatim from mockup where it exists)

```
stackTitle              "My stack" / "Мій стек"                       [mockup 81]
stackSummary            "{total,plural,…} · {active,plural,…}"        [mockup 856 — two plural placeholders]
supplementsLabel        "SUPPLEMENTS" / "ДОБАВКИ"                     [mockup 102]
addSupplement           "Add supplement" / "Додати добавку"           [mockup 88]
close                   "Close" / "Закрити"                           [mockup 131]
searchTab               "Search catalog" / "Пошук у базі"             [mockup 134]
manualTab               "Add manually" / "Вручну"                     (replaces camera tab — copy is discretion)
searchCatalogHint       "Name or active substance" / "Назва або діюча речовина"  [mockup 139]
noResultsCatalog        (REWRITE — no scanning promise)               [mockup 150 must not ship as-is]
nameLabel / doseLabel / save                                          (manual form)
statusActive/statusPaused/statusPlanned/statusFresh  "АКТИВНА/ПАУЗА/ЗАПЛАНОВАНО/ЩОЙНО ДОДАНО" [mockup 581-586]
scheduleTitle           "Dosing schedule" / "Розклад прийому"         [mockup 481]
pausedBadge             "PAUSED" / "НА ПАУЗІ"                         [mockup 483]
periodicityLabel        "PERIODICITY" / "ПЕРІОДИЧНІСТЬ"               [mockup 499]
cyclicTab / courseTab   "Cyclic"/"Циклічно" · "One-time course"/"Разовий курс"   [mockup 501-502]
startLabel / endLabel   "Start"/"Старт" · "End"/"Кінець"              [mockup 508-509, 514]
cycleLength / breakLabel "Cycle length"/"Довжина циклу" · "Break"/"Перерва"      [mockup 517, 522]
noBreak                 "no break" / "без перерви"                    [mockup 934]
cycleSummaryCyclic      "{on} прийому, потім {off} перерви — повторюється, поки не вимкнете" [mockup 938]
timeSlotsLabel          "DOSE TIMES" / "ЧАС ПРИЙОМУ"                  [mockup 537]
slotsPerDay             plural: "раз/рази/разів на день" (all 4 uk forms — NOT mockup's buggy version)
addTimeSlot             "+ Add time slot" / "+ Додати слот часу"      [mockup 549]
saveAndStart            "Add and start cycle" / "Додати й запустити цикл"        [mockup 960]
saveWhilePaused         "Save, cycle paused" / "Зберегти, цикл на паузі"         [mockup 960]
pause / resume          "Pause"/"Пауза" · "Resume cycle"/"Відновити цикл"        [mockup 958]
delete                  "Delete" / "Видалити"                         [mockup 557]
saveHintActive/saveHintPaused                                          [mockup 961-963]
catalog{Entry}Name / catalog{Entry}Dose  × 15 entries                 (P-1)
```

(uk strings [VERIFIED] at the cited mockup lines; en renderings [ASSUMED — Claude translations].)

### Cascade delete test skeleton (the highest-value new test)

```dart
test('softDeleteCascade hides supplement+regimen and future pending logs, keeps history', () async {
  final db = BoostqueDb.forTesting(NativeDatabase.memory());
  // seed: supplement s1, cyclic regimen r1 (start D-2, offDays 0), slot 08:00
  await intake.ensureLogsForDay(DateTime.utc(2026, 8, 12)); // past
  await intake.setStatus(pastLogId, DoseStatus.taken);
  await intake.ensureLogsForDay(DateTime.utc(2026, 8, 14)); // "today", pending
  await supplements.softDeleteCascade('s1', fromDay: DateTime.utc(2026, 8, 14));
  expect(await supplements.watchAll().first, isEmpty);
  expect(await regimens.watchAll().first, isEmpty);
  // past taken row untouched; today's pending row stamped:
  final past = await (db.select(db.intakeLogs)..where((t) => t.id.equals(pastLogId))).getSingle();
  expect(past.deletedAt, isNull);
});
```

## Edge Coverage

| # | Edge | Expected behavior |
|---|------|-------------------|
| E-1 | Pause at noon with today's rows materialized, then resume | Doses vanish from watchDay while paused, reappear on resume, statuses preserved (PF-1 test) |
| E-2 | Delete supplement that has taken/skipped history | History rows keep `deletedAt == null`; only `status == pending AND date >= fromDay` stamped; watchDay hides everything via parent filters anyway |
| E-3 | Edit regimen changing slot count 3→2 | Phase-1 reconciliation soft-deletes the removed slot; its past logs remain (join on slot has no deletedAt filter in watchDay — past display intact) [VERIFIED: drift_repositories.dart:259-263 — slot join is `innerJoin` without deletedAt condition] |
| E-4 | Course whose endDate is in the past | `isActiveOn` false → no new doses; card status currently derives ACTIVE (start ≤ today, not paused) — recommend deriving "finished course" as no-chip or ЗАПЛАНОВАНО-styled "завершено" [ASSUMED — mockup has no finished-course state; flag for discuss/UAT] |
| E-5 | offDays == 0 | "без перерви", always-on [VERIFIED: cycle_math.dart:39 — `if (r.offDays == 0) return true;`] |
| E-6 | Course end picker before start | Prevented by `firstDate: startDate` on the end picker; clamp end when start moves later |
| E-7 | Add supplement, kill app before configuring regimen | Supplement persists with `fresh` status, no regimen — legitimate state, card must render without a schedule chip |
| E-8 | Duplicate slot times (e.g., two 08:00) | Schema allows (different slotIds); recommend UI-level nudge or silent allow — discretion; never a crash |

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | `flutter_test` (SDK) + in-memory Drift (`BoostqueDb.forTesting(NativeDatabase.memory())`) — pattern established in Phase 1 |
| Config file | `analysis_options.yaml` exists (Phase 1) |
| Quick run command | `flutter test test/features/<file>_test.dart` |
| Full suite command | `flutter analyze && flutter test` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| STACK-01 | Search catalog (case-insensitive, cross-locale) returns entry; tapping adds supplement | unit + widget | `flutter test test/features/catalog_search_test.dart` / `stack_screen_test.dart` | ❌ Wave 0 |
| STACK-02 | Manual add: empty stack → sheet → name+dose → card appears | widget | `flutter test test/features/stack_screen_test.dart` | ❌ Wave 0 |
| STACK-03 | Card shows name, dose, color bar, correct status chip per derivation matrix, summary line | unit (statusOf/summary) + widget | `flutter test test/features/stack_status_test.dart` | ❌ Wave 0 |
| STACK-04 | Cascade: supplement+regimen hidden, future pending logs stamped, history kept | unit (repo) | `flutter test test/db/cascade_delete_test.dart` | ❌ Wave 0 |
| REGI-01 | Editor save cyclic 56/28 → repo returns kind cyclic, onDays 56, offDays 28, slots persisted | widget or controller unit | `flutter test test/features/regimen_editor_test.dart` | ❌ Wave 0 |
| REGI-02 | Course start/end inclusive persisted; end<start unreachable | widget/unit | same file | ❌ Wave 0 |
| REGI-03 | Slot add capped at 6, remove floored at 1, times sorted, dose labels kept | controller unit | `flutter test test/features/regimen_editor_test.dart` | ❌ Wave 0 |
| REGI-04 | pause→no pending doses in watchDay; resume→doses return; ПАУЗА chip renders | unit (repo, PF-1 scenario) + widget | `flutter test test/db/pause_filter_test.dart` | ❌ Wave 0 |
| (l10n) | New plural keys correct at 1/2/5/11/21 in uk | unit | extend `test/l10n/plurals_test.dart` | exists — extend |

### Sampling Rate
- Per task commit: the relevant single test file; per wave merge: `flutter analyze && flutter test`; phase gate: full suite green before `/gsd-verify-work`.

### Wave 0 Gaps
- [ ] `test/db/cascade_delete_test.dart`, `test/db/pause_filter_test.dart` — repo delta (build FIRST; screens depend on the new API)
- [ ] `test/features/stack_screen_test.dart`, `test/features/regimen_editor_test.dart`, `test/features/catalog_search_test.dart`, `test/features/stack_status_test.dart`
- [ ] Plural-test extension for new count keys
- No new fixtures framework needed; the in-memory-DB + ProviderScope-override harness from Phase 1 covers everything

## Security Domain

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2/V3/V4 Auth/Session/Access | No | Offline single-user app, unchanged |
| V5 Input Validation | Yes (only category active this phase) | V-1 rules above — structural widget constraints + one form validator + existing domain asserts. All persistence goes through Drift's parameterized builder (no raw SQL anywhere in the delta), so free-text name/dose cannot inject |
| V6 Cryptography | No | Unencrypted SQLite remains the documented, accepted v1 trade-off |

Threat notes: the cascade delete is the one destructive-ish action added — it is soft-delete-only by construction (no Drift delete statement may appear; grep-check stays valid) and must sit behind an explicit confirmation dialog (destructive `risk`-colored button per mockup line 557; recommend a confirm dialog since there is no undo surface in v1 — discretion).

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Flutter SDK 3.47 / Dart 3.13 | everything | ✓ (Phase 1 shipped and tested against it) | 3.47.0 | — |
| `node` (gsd-tools seams) | automated research seams | ✗ [VERIFIED this session: unavailable per sandbox constraint] | — | Manual verification performed (as in Phase 1) |
| Network (research session only) | api.flutter.dev / riverpod.dev fetches | ✓ | — | N/A for the shipped app |

No blocking gaps.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | English catalog names/doseText translations (mockup is uk-only) | P-1 | Cosmetic; caught at UAT; one-line ARB fixes |
| A2 | Dart `toLowerCase()` handles uk Cyrillic correctly with default Unicode mappings | P-2 | Nil in practice; a failing search test would catch it instantly |
| A3 | Riverpod 3 `NotifierProvider.autoDispose.family` composes with constructor-arg Notifiers exactly as `.family` does | P-5 | Low — migration doc shows `.family` + constructor pattern; if autoDispose chaining differs, fall back to plain `.family` (D-23 permits either) or ConsumerStatefulWidget |
| A4 | Mockup spelling "Зверобій" is intended copy (standard uk is "Звіробій") | Catalog | Copy decision for the user at UAT; data-only change |
| A5 | Finished-course card status (E-4) has no mockup reference; proposed treatment is invented | Edge Coverage | Product-taste risk; flag in discuss/verify |
| A6 | New-regimen default = 1 slot at 08:00 (vs mockup demo's 3 slots) | P-5 | UX preference only; either passes requirements |

## Open Questions (RESOLVED — all four answered by the approved 02-UI-SPEC and lifted into plans)

1. **Confirmation UX for delete** — RESOLVED: confirm dialog required (02-UI-SPEC Copywriting Contract `deleteConfirmTitle`/`deleteConfirmBody`; implemented in 02-04 T2).
2. **Finished-course status label** (E-4/A5) — RESOLVED: ЗАВЕРШЕНО chip in planned styling (`statusFinished`, D10; 02-03/02-05); en copy flagged for UAT.
3. **Manual-entry tab copy** — RESOLVED: "Вручну" tab + `addManualSupplement` CTA (Copywriting Contract row; 02-05); confirm wording at UAT.
4. **Empty-stack state** — RESOLVED: `emptyStackTitle`/`emptyStackBody` below the still-visible CTA (UI Consideration #1; 02-05).

## Sources

### Primary (HIGH confidence)
- Project code read line-by-line this session: `lib/core/domain/{models,cycle_math,repositories}.dart`, `lib/core/db/{database,drift_repositories}.dart`, `lib/core/providers.dart`, `lib/core/theme/tokens.dart`, `lib/features/stack/stack_screen.dart`, `lib/core/l10n/arb/app_en.arb` — all line citations above refer to these reads
- `claude_design_mockup/Boostque v0.1.dc.html` — full 991-line read this session; all mockup line citations verbatim
- [api.flutter.dev — showDatePicker](https://api.flutter.dev/flutter/material/showDatePicker.html), [showTimePicker](https://api.flutter.dev/flutter/material/showTimePicker.html), [SegmentedButton](https://api.flutter.dev/flutter/material/SegmentedButton-class.html) — fetched this session, quoted above
- `.planning/phases/01-foundation/01-RESEARCH.md` — Riverpod 3 Notifier/StreamProvider syntax, insertOrIgnore semantics, gen-l10n config (same-day verification carried forward)

### Secondary (MEDIUM confidence)
- [riverpod.dev/docs/3.0_migration](https://riverpod.dev/docs/3.0_migration) + [riverpod.dev/docs/whats_new](https://riverpod.dev/docs/whats_new) (via WebSearch summary this session) — FamilyNotifier removal, constructor-arg family pattern
- `docs/superpowers/plans/2026-08-14-boostque-v1.md` Tasks 8–9 — screen structures, ARB key naming, test skeletons (superseded where Phase-1 outcomes differ: no `google_fonts`, ARB catalog over JSON asset, `Provider<AsyncValue>` composition over `StreamProvider` combine helper)

### Tertiary (LOW confidence)
- gen-l10n's generated `lookupAppLocalizations` being synchronous and public in the output file — standard generator behavior, not re-verified against 3.47's generator output this session; if the symbol is private in the generated file, fall back to `AppLocalizations.delegate.load` (async) or duplicate en names in the descriptor list

## Metadata

**Confidence breakdown:**
- Repo/domain integration (cascade, pause, invariants): HIGH — every claim cites read code with line ranges
- Mockup extraction (ranges, copy, colors, limits): HIGH — verbatim quotes from a full read
- Flutter form/picker APIs: HIGH — fetched from api.flutter.dev this session
- Riverpod 3 family syntax: MEDIUM-HIGH — official migration doc via search summary, not a direct page fetch
- Copy/translation decisions: LOW by nature (flagged ASSUMED, cheap to fix)

**Research date:** 2026-08-14
**Valid until:** ~30 days (Flutter SDK APIs and mockup are stable; Riverpod syntax stable within 3.x)
