---
phase: 02-stack-management
plan: 05
subsystem: stack-ui
status: complete
requirements: [STACK-01, STACK-02, STACK-03, STACK-04, REGI-04]
tasks: 3/3
dependency-graph:
  requires: ["02-01", "02-02", "02-03", "02-04"]
  provides:
    - "lib/features/stack/catalog.dart: CatalogEntry + kCatalogEntries (15) + searchCatalog cross-locale matcher"
    - "lib/features/stack/stack_screen.dart: full S1 card anatomy, summary header, empty/loading/error states, card-tap navigation"
    - "lib/features/stack/add_supplement_sheet.dart: BqSegmented search/manual tabs, catalog result rows, add-then-push-editor flow"
  affects: ["phase-03 calendar (statusOf consumers)", "phase-05 l10n verification (copy-on-add note)"]
tech-stack:
  added: []
  patterns:
    - "ARB-backed catalog with locale-resolving function descriptors (P-1)"
    - "cross-locale search via synchronous lookupAppLocalizations (P-2)"
key-files:
  created:
    - lib/features/stack/catalog.dart
    - test/features/catalog_search_test.dart
  modified:
    - lib/features/stack/stack_screen.dart
    - lib/features/stack/add_supplement_sheet.dart
    - lib/core/l10n/arb/app_en.arb
    - lib/core/l10n/arb/app_uk.arb
    - lib/core/l10n/gen/ (regenerated, committed)
    - test/features/stack_screen_test.dart
    - test/l10n/plurals_test.dart
decisions:
  - "kCatalogEntries is a top-level final List.unmodifiable, not const — Dart closures over gen-l10n getters cannot be const; acceptance greps (15 constructions, palette-only colors) hold"
  - "lookupAppLocalizations confirmed public in the generated file — no RESEARCH tertiary fallback needed"
  - "loading/error header renders title + CTA without the stackSummary row (counts unknown until first data event; consistent with the no-spinner rule #2)"
  - "CourseSummary with null end renders the start date alone (no dash placeholder)"
metrics:
  duration: "~9 min"
  completed: "2026-08-15"
actuals:
  tokens: 21000
  tasks: 3
  commits: 4
---

# Phase 2 Plan 05: Catalog, Full Stack Screen & Two-Tab Add Sheet Summary

15-entry ARB-backed locale-aware catalog with cross-locale search, the complete S1 stack-card anatomy with all five list states, and the two-tab add sheet wiring both add paths into the regimen editor — closing the whole Phase-2 user loop.

## What Was Built

### Task 1 — Bundled catalog (commit 1382c90, TDD)
- `CatalogEntry` (id, palette-token color, locale-resolving `name`/`doseText` functions) + `kCatalogEntries`: the mockup CATALOG 8 (round-robin palette indices 0–7) followed by BASE_STACK 7 with their mockup PLAN palette indices (D3 0, Омега-3 1, Хондропротектор 2, Магній 3, Зверобій 4, Цинк 5, Куркумін 6). No hex literals — `grep 'Color(0x'` prints nothing.
- 30 `catalog{Id}Name`/`catalog{Id}Dose` ARB keys in BOTH locales; uk names verbatim from the mockup (incl. the "Зверобій" spelling, A4); uk doses from BASE_STACK where given, neutral invented form/dose for the CATALOG 8; en renderings flagged UAT-reviewable in @-metadata (A1). Every mockup note/score/schedule field stripped — the liability grep (`взаємодія|сертралін|щитоподібн`) prints 0 (PF-5/D4, threat T-02-07 mitigated).
- `searchCatalog`: trim + toLowerCase + contains over the active locale's names AND the en names via the public synchronous `lookupAppLocalizations(const Locale('en'))`; no diacritic-stripping layer. RED first (10 tests failed to load), then GREEN.

### Task 2 — Full Stack screen (commit 12f1049)
- Header: `stackTitle` + `stackSummary(total, active)` 4px below in body-13 textMuted; active counts `statusOf == active`. `stackSummary` is a single two-plural ICU key, uk matrix proven at (1,1)/(2,2)/(5,5)/(11,11)/(21,21) plus a mixed (5,1) case.
- `_StackCard`: surface + 1px cardBorder + radius 14 + padding 14; 4px color bar (.85 opacity); wrapping name 15/w600 and doseText 12.5; `Wrap` chips row (6px gaps). Whole card taps into `RegimenEditorScreen(supplementId)` (STACK-04 edit path).
- `_StatusChip`: mono 10.5/w500, exact mockup labels/colors — АКТИВНА calm/calmBg, ПАУЗА textSecondary/chip, ЗАПЛАНОВАНО + ЩОЙНО ДОДАНО + D10 ЗАВЕРШЕНО accent/accentChipBg (STACK-03, REGI-04).
- `_ScheduleChip`: cyclic = `weeksCount(on)` / (`noBreak` | `weeksCount(off)`) · `slotsPerDay(n)`; course = `DateFormat.yMd` range · `slotsPerDay(n)` — all words from ARB, only separators in code; absent for `NoSummary` (fresh entry, #6); paused keeps its chip.
- States: empty renders `emptyStackTitle`/`emptyStackBody` below the still-visible CTA with the eyebrow omitted (#1); loading keeps header + CTA, NO spinner (#2); error renders `stackLoadError` + retry that invalidates both stream providers — never exception text (#3, T-02-08); bottom padding 84px (#4).

### Task 3 — Two-tab add sheet (commit 956b610)
- `BqSegmented` [Пошук у базі / Вручну] below the header — the manual tab replaces the mockup camera tab (D1); no camera/scanning code path or copy exists.
- Search tab: theme-driven input (hint `searchCatalogHint`), live `searchCatalog` filtering; result rows (surface, radius 12, 1px cardBorder, 13/14 padding, 10px gaps) with wrapping name 14/w600 in a `Flexible`, doseText 12 2px below, and a never-wrapping trailing "+" 20/w500 accent carrying a `Semantics` label (addSupplement + entry name) (#10). Empty query lists all 15 (#8); no matches renders the rewritten `noResultsCatalog` (#9/D3).
- Row tap: copy-on-add — the CURRENT locale's name/doseText snapshot into the Supplement row (P-1, code comment for Phase 5), catalog color kept, UUID at the save boundary, upsert, pop, push `RegimenEditorScreen`. Manual save keeps round-robin color and follows the same pop-then-push exit.
- PF-6 keyboard inset handling intact for both tabs (backstop #15 remains an on-simulator phase sign-off item).

## Verification

- `flutter analyze`: 0 issues.
- `flutter test`: **154/154 green** (base 134 preserved + 20 new: 10 catalog unit, 8 stack-screen widget, 2 plural).
- Widget-proven: tab switch in place, search-add-navigates (+ card with catalog name and dose after returning), no-results copy, manual-add-navigates, empty/fresh/paused/active states, D10 chip mapping via statusOf, card-tap navigation, takeException null in uk throughout.
- Acceptance greps: 15 CatalogEntry constructions; no `Color(0x` in catalog/stack_screen; ≥30 `catalog` occurrences in app_en.arb with uk parity (gen-l10n enforces); liability grep 0.

## Deviations from Plan

**1. [Rule 3 - Blocking] `kCatalogEntries` is `final List.unmodifiable`, not `const`**
- **Found during:** Task 1
- **Issue:** Dart closures capturing gen-l10n getters (`(l) => l.catalogCreatineName`) cannot appear in a const list literal.
- **Fix:** top-level `final` unmodifiable list; behaviorally identical (in-memory, synchronous, immutable — UI-SPEC #17 intent preserved).
- **Commit:** 1382c90

**2. [Rule 1 - Bug-prevention] Tracer test updated for the new sheet default tab**
- **Found during:** Task 3
- **Issue:** the 02-01 tracer test assumed the manual form was the sheet's only content; the search tab is now the default.
- **Fix:** the test switches to Вручну first and now also asserts the manual path lands on RegimenEditorScreen (per the plan's test spec).
- **Commit:** 956b610

No other deviations — plan executed as written. No auth gates.

## Known Stubs

None — all rendered data is wired to the repositories or the const catalog; no placeholder values, TODOs, or unwired components in the plan's files.

## Threat Flags

None — no new surface beyond the plan's `<threat_model>`; both registered mitigations (T-02-07 liability-content strip, T-02-08 error-copy-only) are grep/widget-enforced.

## Manual Backstops for Phase Sign-off (unchanged from plan)

- UI-SPEC #15: sheet vs keyboard at 667pt, uk+en, on a simulator.
- UI-SPEC #16: uk footer labels at 390pt (owned by plan 02-04).
- Visual fidelity vs mockup screens 01/05 in uk.

## Commits

| Task | Commit | Description |
|------|--------|-------------|
| 1 | 1382c90 | Catalog: 15 entries, 30 ARB keys, cross-locale search (TDD) |
| 2 | 12f1049 | Full Stack screen: anatomy, chips, states, navigation |
| 3 | 956b610 | Two-tab add sheet + editor push wiring |

## Self-Check: PASSED

- All four key files exist on disk (catalog.dart, stack_screen.dart, add_supplement_sheet.dart, catalog_search_test.dart).
- All three task commits present in git log (1382c90, 12f1049, 956b610).
- `flutter analyze` 0 issues; `flutter test` 154/154 green.
