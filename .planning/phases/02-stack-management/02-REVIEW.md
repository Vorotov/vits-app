---
phase: 02-stack-management
reviewed: 2026-08-15T14:30:36Z
depth: standard
files_reviewed: 22
files_reviewed_list:
  - lib/features/stack/stack_screen.dart
  - lib/features/stack/add_supplement_sheet.dart
  - lib/features/stack/regimen_editor_screen.dart
  - lib/features/stack/regimen_editor_controller.dart
  - lib/features/stack/stack_status.dart
  - lib/features/stack/catalog.dart
  - lib/core/db/drift_repositories.dart
  - lib/core/domain/repositories.dart
  - lib/core/theme/tokens.dart
  - lib/core/theme/theme.dart
  - lib/core/widgets/bq_segmented.dart
  - lib/core/l10n/arb/app_en.arb
  - lib/core/l10n/arb/app_uk.arb
  - test/db/cascade_delete_test.dart
  - test/db/pause_filter_test.dart
  - test/features/stack_screen_test.dart
  - test/features/regimen_editor_controller_test.dart
  - test/features/regimen_editor_test.dart
  - test/features/stack_status_test.dart
  - test/features/catalog_search_test.dart
  - test/widget/bq_segmented_test.dart
  - test/theme/theme_test.dart
findings:
  critical: 1
  warning: 4
  info: 6
  total: 11
status: issues_found
fixes:
  fixed_at: 2026-08-15T14:42:51Z
  scope: critical_warning
  fixed: [CR-01, WR-01, WR-02, WR-03, WR-04]
  tests_after_fixes: 162
---

# Phase 2: Code Review Report

**Reviewed:** 2026-08-15T14:30:36Z
**Depth:** standard
**Files Reviewed:** 22
**Status:** issues_found

## Summary

Reviewed all Phase-2 (Stack Management) sources: the Stack screen, add-supplement sheet, regimen editor (screen + controller), status/summary derivation, ARB catalog, the repository delta (`softDeleteCascade` + `watchDay` pause/deletedAt filters), theme/token additions, `BqSegmented`, both ARB files, and all new tests. `flutter analyze` is clean; the full suite (154 tests) passes.

The hard invariants from research are honored and verified against code:

- **PF-1 (pause never stamps logs):** `watchDay` excludes only `paused AND pending` via query filter (`drift_repositories.dart:329-336`); `softDeleteCascade` is the only log-stamping path, scoped to `status == pending AND date >= fromDay` (`drift_repositories.dart:107-116`). The pause round-trip test asserts zero raw-row mutation.
- **PF-8 (regimen id reuse):** `save()` resolves `draft.regimenId → findForSupplement re-check → new UUID` and stores resolved ids back into the draft (`regimen_editor_controller.dart:305-345`) — correct for sequential saves; see CR-01 for the concurrent case.
- **PF-2/PF-3:** every picker result goes through `dateOnly()` before the controller (`regimen_editor_screen.dart:461`, controller re-normalizes at `327-330`); 24-h is forced on both picker and display.
- **28-bar preview:** code samples `start + i*4` days (`regimen_editor_screen.dart:557`), matching RESEARCH P-9's 4-day sampling of a 112-day window — the `*4` is in both the plan and the code; no discrepancy.
- **i18n:** no hardcoded user-visible strings found (only separator glyphs `·`, `–`, `+`, `−` live in code, as the S1 contract permits); all four uk plural forms present on every count key and asserted at 1/2/5/11/21.
- **Soft-delete only:** no Drift delete statement exists anywhere in `lib/core/db/`.

The findings that remain are concurrency/robustness gaps: none of the async save/add/delete buttons is guarded against double-activation, which on the editor save path can defeat PF-8 and create ghost regimen rows (double-dosing downstream).

## Critical Issues

### CR-01: Double-tap on the editor save button races `save()` and can create duplicate regimen rows (PF-8 violation → double-dosed materialization)

**File:** `lib/features/stack/regimen_editor_screen.dart:832,913-916` (and `lib/features/stack/regimen_editor_controller.dart:305-345`)
**Status:** fixed — commit `394a63f` (both layers: single-flight `save()` in the controller + `_saving` guard in a now-stateful `_EditorFooter`; regression tests: concurrent-save unit test + double-tap widget test)
**Issue:** `_save` is wired directly to `onPressed` with no in-flight guard. Two rapid taps start two concurrent `save()` calls. For a fresh regimen (`draft.regimenId == null`), both calls run the save-time `findForSupplement` re-check *before* either upsert commits, so both get `null`, both mint a fresh UUID, and two regimen rows are persisted for one supplement. `combineStackEntries`/`findForSupplement` then show one regimen while `ensureLogsForDay` iterates **all** regimens — the hidden ghost regimen materializes a second set of doses per slot per day (exactly the "materialization double-doses" failure PF-8 warns about, threat T-02-05). Additionally, both invocations run `Navigator.maybePop`; the second fires while the footer's element may still be mounted during the exit transition and can pop the Stack route underneath the editor.
**Fix:**
```dart
// In the controller — make save single-flight:
Future<void>? _saveInFlight;
Future<void> save() => _saveInFlight ??= _doSave().whenComplete(() => _saveInFlight = null);

// And/or in _EditorFooter (convert to a StatefulWidget or hold a ValueNotifier):
onPressed: _saving ? null : () async {
  setState(() => _saving = true);
  try { await controller.save(); } finally { if (mounted) setState(() => _saving = false); }
  if (context.mounted) await Navigator.of(context).maybePop();
},
```
Either layer alone closes the duplicate-row race; the UI guard additionally prevents the double `maybePop`.

## Warnings

### WR-01: Double-tap in the add sheet creates duplicate supplements and corrupts navigation

**File:** `lib/features/stack/add_supplement_sheet.dart:87-94,99-112,116-135,276-279`
**Status:** fixed — commit `ca69b0b` (`_busy` guard on both add paths, manual save button disabled while busy; double-tap catalog-row widget test)
**Issue:** `_addFromCatalog` and `_saveManual` have no in-flight guard, and every catalog result row is a bare `GestureDetector`. Two quick taps (same row, two different rows, or the manual save button) mint two UUIDs and upsert two supplement rows. Worse, `_popThenPushEditor` then runs twice on the same navigator: the first pops the sheet and pushes the editor; the second (the sheet state is still `mounted` during the exit transition) pops **the editor** and pushes a second editor — leaving a stray supplement in the stack and a confusing route stack.
**Fix:** Add a `bool _busy = false;` field in `_AddSupplementSheetState`; set it at the top of both save paths (`if (_busy) return; _busy = true;`) and never reset it on the success path (the sheet is disposed). Optionally disable the manual save button while busy.

### WR-02: Editor crashes (Slider assertion) if a persisted regimen carries onDays/offDays outside the slider ranges

**File:** `lib/features/stack/regimen_editor_controller.dart:193-209` (surfaces at `lib/features/stack/regimen_editor_screen.dart:315-334`)
**Status:** fixed — commit `5e9c7a1` (`_clampDays` at the `_draftFrom` seed boundary: snap to the 7-day grid, clamp onDays 7..112 / offDays 0..84; unit tests for 0→7, 200→84, 60→63, 10→7)
**Issue:** `_draftFrom` copies `onDays`/`offDays` from the DB verbatim; the cyclic panel then builds `Slider(value: draft.onDays.toDouble(), min: 7, max: 112)` and `Slider(value: draft.offDays.toDouble(), min: 0, max: 84)`. Any regimen row whose values fall outside those ranges — the Drift column default is `onDays = 0` (`database.dart:68`), and rows written by tests, a future sync backend, or any non-editor writer are unconstrained (the domain assert only requires `>= 0`) — throws `'value' must be between 'min' and 'max'` and red-screens the editor, making that supplement uneditable and undeletable through the UI.
**Fix:** Clamp at the seed boundary in `_draftFrom`:
```dart
onDays: r.onDays.clamp(7, 112),
offDays: r.offDays.clamp(0, 84),
```
(Values were already only representable in 7-step increments through this UI, so clamping is lossless for editor-written rows.)

### WR-03: `build()` silently seeds defaults when `stackEntriesProvider` is not `AsyncData`, and a subsequent save clobbers the stored regimen's settings

**File:** `lib/features/stack/regimen_editor_controller.dart:160-173`
**Status:** fixed — commit `2cc0600` (`_seedWasBlind` flag: a blind-seeded save that would clobber an existing regimen re-seeds the draft from the store and throws `StateError` — surfaced by the WR-04 SnackBar; unit tests for refuse+re-seed+retry and the fresh-save path)
**Issue:** The synchronous seed pattern-matches only `AsyncData`; on `AsyncLoading`/`AsyncError` it returns `_defaults()` and never re-seeds (the read is one-shot, not reactive). If the editor is ever opened before the stack graph is warm, the user of a supplement that *has* a regimen sees the default form (56/28 cyclic, 1 slot at 08:00); pressing save then reuses the correct regimen id (the `findForSupplement` re-check) but **overwrites its real settings with the defaults**, and slot reconciliation soft-deletes all existing slots. Today both entry points (card tap requires `AsyncData`; add-flow supplements have no regimen) make this unreachable, but nothing enforces that invariant for future callers (deep links, state restoration, Phase 3+ navigation).
**Fix:** Make the fallback safe rather than silent — e.g. seed from the repository when the provider is not ready:
```dart
// in build(), after the AsyncData branch fails:
assert(ref.read(stackEntriesProvider) is AsyncData<List<StackEntry>>,
    'RegimenEditor opened before the stack graph is warm (UI-SPEC #17)');
```
plus (belt-and-suspenders) have `save()` skip the destructive overwrite when `draft.regimenId == null` **and** the re-check finds an existing regimen whose draft was never seeded from it — or simply re-seed via `_draftFrom(found)` before applying the draft in that branch.

### WR-04: No error handling on any async persistence path — a failed save/add/delete is silent and becomes an unhandled async exception

**File:** `lib/features/stack/regimen_editor_screen.dart:832,913-916,938-944`; `lib/features/stack/add_supplement_sheet.dart:109,132`
**Status:** fixed — commit `213aad4` (new `saveFailed` ARB key in both locales; try/catch + SnackBar on editor save, delete-dialog confirm, and both sheet add paths — screen stays open, buttons re-enable; failing-repo widget test)
**Issue:** `controller.save()`, `deleteSupplement()`, and both sheet upserts are awaited without try/catch, and the returned futures from `onPressed` closures are unawaited by the framework. If Drift throws (disk full, corrupted file, future schema issue), the user gets no feedback: the editor still pops as if saved (`_save` proceeds to `maybePop` only on success — good — but the error itself surfaces nowhere), and the exception escapes to the zone handler. The UI-SPEC defines an error surface only for stack *load*; write failures have none.
**Fix:** Wrap the awaits and surface a minimal failure signal (SnackBar with an existing-style ARB key, staying on screen so no data is silently lost):
```dart
try {
  await controller.save();
} catch (_) {
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.saveError)));
  }
  return; // do not pop — the draft is still on screen
}
```
(Requires one new ARB key in both files, e.g. `saveError`.)

## Info

### IN-01: Screen re-derives slot-cap logic instead of using the controller's tested getters

**File:** `lib/features/stack/regimen_editor_screen.dart:62-63` (vs `regimen_editor_controller.dart:219-222`)
**Issue:** `canAdd`/`canRemove` are recomputed as `draft.slots.length < RegimenEditorController.maxSlots` etc., duplicating the invariant that `canAddSlot`/`canRemoveSlot` already encode; the getters have zero production callers.
**Fix:** Use `controller.canAddSlot`/`controller.canRemoveSlot` (or delete the getters and keep the methods' internal checks).

### IN-02: `RegimenRepository.setPaused` has no production caller after this phase

**File:** `lib/core/domain/repositories.dart:81`; `lib/core/db/drift_repositories.dart:210-215`
**Issue:** Pause/resume ships through `togglePause()` + `save()`/`upsert` (matching the mockup's save-carries-pause CTA), so `setPaused` is now exercised only by tests — a quiet divergence from the RESEARCH system-flow sketch ("pause/resume → regimenRepo.setPaused").
**Fix:** Keep it (Phase 3+ may pause from the calendar), but note the divergence in the phase SUMMARY so it isn't flagged as dead code later.

### IN-03: `BqSegmented` uses `EdgeInsets` instead of `EdgeInsetsDirectional`

**File:** `lib/core/widgets/bq_segmented.dart:51,66`
**Issue:** The locked project rule is direction-neutral/`EdgeInsetsDirectional` padding. The values here (`all(2)`, `symmetric(vertical: 9)`) are symmetric so behavior is identical in RTL, but it breaks the codebase-wide convention every other Phase-2 file follows.
**Fix:** Swap to `EdgeInsetsDirectional.all(2)` / `EdgeInsetsDirectional.symmetric(vertical: 9)`.

### IN-04: Dash inconsistency between the course chip and the course summary

**File:** `lib/features/stack/stack_screen.dart:388` (vs `lib/core/l10n/arb/app_uk.arb:43`)
**Issue:** The schedule chip renders the course range with an en dash (`'$startText – ${fmt.format(end)}'`, code literal) while `courseSummaryRange` in the ARB uses an em dash (`{start} — {end}`). Same data, two separators.
**Fix:** Pick one (the UI-SPEC S1 example uses "–") and align — ideally by moving the chip range into an ARB key so the separator is translator-owned too.

### IN-05: `addSlot`'s 21:00 fallback is unreachable

**File:** `lib/features/stack/regimen_editor_controller.dart:150-153,257-270`
**Issue:** `nextSlotDefaults` has exactly `maxSlots` (6) entries; all six can only be "used" when six slots exist, at which point `canAddSlot` is false — so `orElse: () => fallbackSlotMinutes` can never fire. Harmless mockup parity, but it is dead code and its doc comment ("when every default is taken") describes an impossible state.
**Fix:** Keep as a defensive guard but fix the comment, or drop `fallbackSlotMinutes`.

### IN-06: Card statuses go stale across midnight

**File:** `lib/features/stack/stack_screen.dart:43`
**Issue:** `today = dateOnly(DateTime.now())` is captured per build; if the app sits open across midnight, planned→active and active→finished transitions don't render until something else triggers a rebuild.
**Fix:** Acceptable for v1; when Phase 3 introduces a "today" ticker/provider for the calendar, consume it here too.

### IN-07: Search matches names only, while the hint promises "name or active substance"

**File:** `lib/features/stack/catalog.dart:167-176` (vs `app_uk.arb:26` `searchCatalogHint`)
**Issue:** `searchCatalog` checks `e.name(...)` only (RESEARCH P-2, mockup parity), but the hint copy says "Назва або діюча речовина". Typing a substance that lives in `doseText` (e.g. "глюкозамін" for Хондропротектор) finds nothing and shows the no-results state.
**Fix:** Either also match `doseText` in the filter (one extra `||` clause) or soften the hint copy at UAT.

---

_Reviewed: 2026-08-15T14:30:36Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
