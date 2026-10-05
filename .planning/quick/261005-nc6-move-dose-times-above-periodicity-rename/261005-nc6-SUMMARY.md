---
phase: quick-261005-nc6
plan: 01
subsystem: regimen-editor, today-calendar, l10n
status: complete
tags: [ux, copy, i18n, accessibility, deferred-items]
requires:
  - RegimenDraft.regimenId (already existed — no controller change)
  - DayDose.supplement (already carried the editor's family argument)
provides:
  - saveChanges ARB key, seven languages
  - openSchedule ARB key, seven languages
  - DoseSheetResult sealed type (DoseSheetMark / DoseSheetOpenSchedule)
  - calendar -> regimen editor navigation
affects:
  - store/screenshots/{ios-6.5,ios-6.9,android-phone}/05-schedule.png (now stale)
tech-stack:
  added: []
  patterns:
    - "Dart 3 sealed class + exhaustive switch as a UI result type, so a domain enum does not absorb a navigation outcome"
    - "Navigator captured before the async gap, matching _apply's ScaffoldMessenger stance"
key-files:
  created: []
  modified:
    - lib/features/stack/regimen_editor_screen.dart
    - lib/features/calendar/dose_action_sheet.dart
    - lib/features/calendar/dose_row.dart
    - lib/core/l10n/arb/app_{en,uk,es,fr,ar,hi,zh}.arb
    - lib/core/l10n/gen/ (regenerated, committed)
    - test/features/regimen_editor_test.dart
    - test/features/today_screen_test.dart
    - .planning/STATE.md
decisions:
  - "D-1: one new save key, not two — the paused branch stays saveWhilePaused on both paths"
  - "D-2: the save hint gets no edit variant; saveHintActive describes what this save does, which does not change"
  - "D-3: the new sheet action names the SCHEDULE, not the supplement — the destination's supplement header is read-only (PF-5)"
  - "D-4: every non-English value composed from words already present in that locale's own ARB file"
  - "D-5: a future dose row stays completely inert; the schedule is deliberately unreachable from it"
  - "D-6: the new action goes last, behind a BqSpace.md gap, no separator rule"
metrics:
  duration: ~45 min
  completed: 2026-10-05
  tests_before: 1167
  tests_after: 1178
  release_gate: 48
actuals:
  tokens: 62000
  tasks: 3
  commits: 2
---

# Quick Task 261005-nc6: Dose Times Above Periodicity, Save on the Edit Path, a Way into the Schedule — Summary

Three UI defects somebody had already written down in STATE.md and nobody had
closed: the regimen editor buried its most-edited field below two sliders, its
primary button offered to add a cycle that was already running, and the daily
dose sheet had no route into the schedule it describes.

## What Changed

### Task 1 — `5b6858a` `feat(editor): put dose times above periodicity, and say Save when editing`

**The reorder.** DOSE TIMES (eyebrow + per-day count + slot rows + add-slot
button + interval note) moved ahead of PERIODICITY (eyebrow + cyclic/course
segmented + periodicity panel), verbatim — every comment, every `Expanded`,
every token gap travelled with its widget, including the long comment above the
`Expanded(child: _Eyebrow(...))` that fixes a measured 77-84px overflow at
textScaler 1.6. The single `const SizedBox(height: 22)` between the blocks was
the separator before the move and is the separator after, so the gap count did
not change. `BqHint.cycle` travelled DOWN with the sliders because it renders
inside `_PeriodicityPanel` — which is where the design rule wants it, beside the
subject it explains.

**The label.** `_EditorFooterState.build`'s two-way
`draft.paused ? saveWhilePaused : saveAndStart` became a three-way: paused →
`saveWhilePaused` (both paths, unchanged); otherwise `draft.regimenId != null` →
`saveChanges`; otherwise `saveAndStart`. The create-vs-edit signal already
existed — `RegimenEditorController._draftFrom` sets `regimenId` from the
persisted `r.id` and `_defaults()` leaves it null — so the controller needed no
change.

**The copy.** `saveChanges` in all seven files, `@saveChanges` in `app_en.arb`
only. Each non-English value is the save verb already opening that same file's
`saveWhilePaused`: Зберегти, Guardar, Enregistrer, حفظ, सहेजें, 保存.

**The gates.** Nothing in `test/features/regimen_editor_test.dart` asserted
vertical position, so the reorder had nothing holding it. Nine new tests: the
eyebrow `.dy` comparison in uk and en at textScaler 1.0 and 1.6 (four), the edit
label over a seeded regimen and the create label over a bare supplement in both
locales (four), and one proving the paused branch did not split.

### Task 2 — `9b33e6a` `feat(today): open the dosing schedule from the dose action sheet`

**The result type.** `showDoseActionSheet` returned `Future<DoseStatus?>`, and
`DoseStatus` is a domain enum Drift persists — so a navigation outcome had
nowhere to go that was not a fabricated column value. The sheet now resolves to
a sealed `DoseSheetResult`: `DoseSheetMark(DoseStatus)` or
`DoseSheetOpenSchedule()`. `lib/core/domain/` is byte-identical to before this
task. `DoseRow._onLongPress` switches on it exhaustively, so a fifth action
cannot be added to the sheet without the call site refusing to compile.

**The row.** Last in the sheet's `Column`, behind a `const SizedBox(height:
BqSpace.md)`, and unconditional — unlike the three mark rows it can never be a
no-op. Reuses `_SheetAction`, so the 48px minimum height and the
`AlignmentDirectional.centerStart` come for free and no padding was added.

**The navigation.** `DoseRow` captures `Navigator.of(context)` BEFORE awaiting
the sheet (the stance `_apply` already takes with its `ScaffoldMessenger`), then
pushes `RegimenEditorScreen(supplementId: widget.dose.supplement.id)` in the
route shape `add_supplement_sheet.dart:98-106` uses. `features/calendar`
importing `features/stack` was already house practice (`planner_gantt.dart`,
`planner_month_detail.dart`), so no exception was needed.

**Accessibility parity.** A fourth `CustomSemanticsAction` carrying the same
`openSchedule` label, gated on the row STATE only and never on `dose.status`,
calling the same private `_openSchedule` method the gesture path calls.

**The copy.** `openSchedule` in all seven files, `@openSchedule` in
`app_en.arb` only. Each non-English value is that locale's own open verb from
`settingsRemindersOpenSystem` carrying that locale's own `scheduleTitle` noun,
authored as one whole string and never composed at runtime. The Hindi verb is
final, matching its donor's word order rather than front-shifted to match
English.

### Task 3 — gates and STATE.md (uncommitted here; the orchestrator commits docs)

Three Deferred Items rows closed in place with this task's date and commit, and
one new open `Release` row recording the stale store screenshots.

## Verification — real output, run on this tree

| Gate | Result |
|---|---|
| `flutter analyze` | **No issues found!** (3.1s) |
| `flutter test` | **1178 tests, all passed** — 1167 baseline + 11 new (9 editor, 2 today) |
| `flutter test test_release/` | **48 tests, all passed** |
| `git diff test_release/` | empty — nothing weakened, no language, scale or vocabulary stem dropped |

Manual reads of the plan's `<verification>` section:

- **Seven-file ARB parity, measured:** all seven files print **188** non-metadata
  keys (186 before, plus `saveChanges` and `openSchedule`).
- **Metadata in the template only:** `grep -l '"@openSchedule"\|"@saveChanges"'`
  returns `app_en.arb` and nothing else.
- **The domain is untouched:** `git diff --name-only 7ea8e35 HEAD -- lib/core/`
  lists only the seven ARB files and the seven regenerated `gen/` files.
  `domain/models.dart`, `domain/repositories.dart`, `providers.dart` and
  `theme/` are unchanged.
- **No hex literal, no non-directional padding** was introduced — the diff grep
  for `0x[0-9A-Fa-f]{6,8}|EdgeInsets.only|EdgeInsets.fromLTRB|EdgeInsets.symmetric(horizontal`
  over added lines returns nothing.
- **The write path is still singular:** the only `setStatus` call in `lib/` is
  `dose_row.dart:112`.

### Two extra checks, run as throwaways and deleted

Neither the regimen editor nor the dose sheet is in the `test_release/` locale
matrix (`test_release/README.md` says so explicitly), so passing 48 is not
evidence either surface renders in Hindi. Both were checked directly and the
scratch files were removed rather than committed:

- **The dose sheet:** all seven locales × textScaler 1.0 / 1.6 / 2.0 × all three
  `DoseStatus` values — **63 permutations, all green**, no overflow with the
  fourth row present.
- **The reordered editor:** all seven locales × 1.0 / 1.6 / 2.0 — **21
  permutations, all green**, with the eyebrow `.dy` order asserted in each,
  including Arabic under its real locale-derived RTL.

## Deviations from Plan

**One, and it is a fix the plan's own grounding predicted.**

**[Rule 1 — Bug in the prescribed test] The edit-label test seeded a regimen and
pumped the editor in the same breath, which rendered the CREATE label.**

- **Found during:** Task 1, first run of the new tests (2 failed).
- **Issue:** `RegimenEditorController.build` is a one-shot `ref.read` of
  `stackEntriesProvider` and never re-seeds. Upserting the regimen and then
  pumping gives the editor an `AsyncLoading` snapshot, so the draft is a WR-03
  blind seed with a null `regimenId` — the assertion found `saveAndStart`. The
  plan anticipated the class of problem ("keep the stack graph warm the way
  `makeContainer` already does, or `regimenId` will be null from a blind seed
  and the test will assert the wrong branch for the wrong reason"); the `listen`
  in `makeContainer` keeps the provider alive but does not make the stream
  arrive before the first pump.
- **Fix:** a `pumpEditorOverSeededRegimen` helper that upserts, pumps a
  throwaway tree, waits until `stackEntriesProvider` actually CARRIES a regimen
  for `s1`, and only then pumps the editor. The wait is a separate step with its
  own failing `expect`, not a longer loop around the assertion, so a future
  regression in the seeding path fails as "the graph never warmed" rather than
  as "the label is wrong". It also models production honestly: both v1 entry
  points open the editor over a warm stack graph.
- **Files modified:** `test/features/regimen_editor_test.dart` (test only — no
  production code changed).
- **Commit:** `5b6858a`.

Nothing else departed from the plan. All six plan decisions (D-1 through D-6)
were implemented as written, and the two deliberate non-changes (D-2's absent
hint variant, D-5's inert future row) are argued in the doc comments of the
files that implement them, per the repo's rule that load-bearing decisions live
beside the code.

## The consequence recorded rather than fixed

`integration_test/store_screenshots_test.dart:205-219` photographs the regimen
editor as `05-schedule` over a stack seeded WITH regimens, so **both** Task 1
changes land in that frame. These three committed PNGs now show the old block
order and the old button label:

- `store/screenshots/ios-6.5/05-schedule.png`
- `store/screenshots/ios-6.9/05-schedule.png`
- `store/screenshots/android-phone/05-schedule.png`

They were **not** regenerated here. Doing it right means erasing a 6.9"
simulator, pinning its status bar, running `tool/make_screenshots.sh` and then a
listing pass in both consoles — its own operation, not a tail on a UI fix, and
editing a PNG by hand is precisely how "store assets are generated, never
hand-edited" stops being true. **The live App Store listing is out of date, not
broken:** a stale screenshot shows a real screen from a previous version; it does
not advertise a feature that no longer exists. Recorded as a new open
`Release` row in `.planning/STATE.md`, flagged owner-only and worth batching with
the next store submission.

## Known Stubs

None. Every surface this task touched is wired to real data through the existing
providers; no placeholder values, no "coming soon" copy, no component left
receiving an empty list.

## Self-Check: PASSED

- `lib/features/stack/regimen_editor_screen.dart` — FOUND
- `lib/features/calendar/dose_action_sheet.dart` — FOUND
- `lib/features/calendar/dose_row.dart` — FOUND
- all seven `lib/core/l10n/arb/app_*.arb` — FOUND, 188 keys each
- `test/features/regimen_editor_test.dart` — FOUND, 43 tests green
- `test/features/today_screen_test.dart` — FOUND, 111 tests green
- commit `5b6858a` — FOUND in `git log`
- commit `9b33e6a` — FOUND in `git log`
- the two throwaway check files — ABSENT, as intended (`git status` clean apart
  from the planning directory)
