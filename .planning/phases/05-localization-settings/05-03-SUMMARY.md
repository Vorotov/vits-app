---
phase: 05-localization-settings
plan: 03
subsystem: l10n-gates
tags: [i18n, testing, source-gate, criterion-4, L10N-01, L10N-02, L10N-04]
status: complete

requires:
  - 05-01 (l10n.yaml preferred-supported-locales + untranslated-messages-file, derived LocaleController.supportedLanguageCodes, languageName ARB key, sharedPreferencesProvider)
provides:
  - "criterion-4 structural gate (test/l10n/new_language_contract_test.dart)"
  - "zero-hardcoded-strings source gate (test/l10n/no_hardcoded_strings_test.dart)"
  - "ARB parity + derived plural-form gate (test/l10n/arb_parity_test.dart)"
  - "system-language resolution behaviour proof (test/l10n/locale_resolution_test.dart)"
affects:
  - "any future phase adding a language, an ARB key, or a user-visible string in lib/"

tech-stack:
  added: []
  patterns:
    - "glob + prove-the-glob before any gate (house rule from planner_invariants_test.dart)"
    - "comment-stripped source before matching, with a self-assertion that no block comments exist"
    - "named const allowlist with a one-line rationale per entry, never a loosened regex"
    - "derive the gated set from disk/CLDR rather than from a hand-kept list"

key-files:
  created:
    - test/l10n/new_language_contract_test.dart
    - test/l10n/no_hardcoded_strings_test.dart
    - test/l10n/arb_parity_test.dart
    - test/l10n/locale_resolution_test.dart
  modified: []

decisions:
  - "Criterion 4 is proven by DERIVATION plus a synthetic-locale negative case, not by a subprocess gen-l10n build against a real third ARB (05-PATTERNS No-Analog recommendation; RESEARCH A9 marks the shell-out optional). No test in this repo spawns a process and none does now."
  - "A 'hardcoded user-visible string' is defined as a literal with two or more letters remaining after its $interpolations are removed. That is sharper than 'a literal appears in a Text()': it exempts Text('${l10n.x} · ') (every word came from an ARB) while catching Text('Cycles') and Text('Цикли') alike."
  - "The zero-hardcoded-strings gate runs in BOTH directions: the widget-position gate plus a classification gate requiring every translatable literal anywhere in lib/ to match a named allowlist category — so a literal cannot hide by sitting one call away from a Text()."
  - "Required CLDR plural categories are probed from intl's own rules (Intl.plural over integers 0-100, union {other}) rather than transcribed into a language table, so a new ARB brings its own plural requirements with it."
  - "l10n.yaml stays the declared source for the arb path, the template name and the untranslated report filename; the gates read it rather than repeating its values."

metrics:
  duration: ~35 min
  completed: 2026-08-16
  tests_added: 29
  suite_total: 619

actuals:
  tokens: 14050
  tasks: 3
  commits: 4
---

# Phase 5 Plan 03: Localization Gates Summary

Four new `test/l10n/` gates that make the phase's structural claims fail on violation: criterion 4 proven against a synthetic third locale, zero-hardcoded-strings enforced over comment-stripped `lib/` sources with a named 9-entry allowlist, ARB parity with plural categories derived from CLDR, and system-language resolution proven by rendered copy.

## What was built

| File | Tests | Gate |
|---|---|---|
| `test/l10n/new_language_contract_test.dart` | 11 | V-3 — the "one new ARB file" contract |
| `test/l10n/no_hardcoded_strings_test.dart` | 8 | V-2 — zero hardcoded user-visible strings, PF-4, numeric formatting |
| `test/l10n/arb_parity_test.dart` | 6 | V-1 — key parity, template metadata, derived plural forms |
| `test/l10n/locale_resolution_test.dart` | 4 | L10N-02 — resolution and fallback as behaviour |

Suite: **590 → 619 tests, all green. `flutter analyze`: no issues.**
`git diff --stat pubspec.yaml lib/ l10n.yaml` for this plan is **empty** — it adds tests only, and no packages (T-05-SC).

### Task 1 — the criterion-4 contract

Reads the ARB directory off disk and asserts every other representation agrees with it: the generated `supportedLocales`, `LocaleController.supportedLanguageCodes`, and each language's own `languageName` (via the SYNCHRONOUS `lookupAppLocalizations`, the call the picker makes). `kMaterialSupportedLanguages` membership pins the honest boundary of the guarantee (PF-9/E-8), and the declared `untranslated-messages-file` is asserted absent or empty (PF-2).

The `languageName` and `kMaterialSupportedLanguages` assertions are loops over the discovered set — `grep -c "'uk'"` on the file is **0**; no shipped language code appears as a loop bound. A synthetic-locale group derives an unshipped code (first candidate not on disk) and asserts the negative half: absent from the generated list, absent from the controller's derived set, and a stored preference holding it sanitizes to `null` rather than reaching the generated `lookupAppLocalizations` throw (T-05-01).

**Proof shape (record for verify-work / UAT).** Criterion 4 is proven here by DERIVATION — generated list ≡ ARB dir ≡ controller's derived set, plus the Task-2 source gates forbidding a per-language code path — and by the synthetic-locale negative case. It is NOT proven by executing a real third-ARB `flutter gen-l10n` build. No test in this repository spawns a subprocess, and this plan deliberately did not introduce the convention in the final v1 phase.

### Task 2 — the zero-hardcoded-strings gate

Globs `lib/**.dart` excluding `lib/core/l10n/gen/` (40 files, proven ≥20 before any gate), strips line comments with the repository's `stripComments` shape, and asserts no block comment and no triple-quoted string exists so both scanners are complete.

Two directions:
1. **Widget position** — no translatable literal as a `Text(` argument or as the value of `label:`/`tooltip:`/`hintText:`/`labelText:`/`helperText:`/`errorText:`/`semanticsLabel:`/`title:`/`message:`.
2. **Classification** — every translatable literal *anywhere* in `lib/` must match a named allowlist entry, and every entry must still match something (a dead entry is a standing permission nobody re-examines).

Literal context is resolved by walking backwards over a MASKED copy of the source (literal contents blanked) to find the enclosing call identifier, so a bracket inside one literal cannot mislabel the next one.

Plus the PF-4 companion (no `initState` body and no `late final` field under `lib/features/` reads `l10n`, `DateFormat`, `NumberFormat` or `context`) and the numeric gate (no `.toString()` inside a `Text(` argument).

**The A2 site was already fixed in wave 1 — the gate found zero violations on arrival**, as expected. The regex was not widened and no allowlist entry was added for it.

### Task 3 — parity, plurals, resolution

`arb_parity_test.dart` reports key differences as two named sets (missing / extra) rather than a bare boolean. Plural-bearing keys are found by parsing the template's VALUES for an ICU `plural` construct — `grep -c 'substancesCount'` on the file is **0**. Required categories per language are probed from `intl`'s own CLDR rules (integers 0-100, union `{other}` because ICU mandates it and no Ukrainian integer selects it), yielding `uk → {one, few, many, other}` and `en → {one, other}`; the derivation itself is pinned by a test, so it cannot silently start requiring less.

`locale_resolution_test.dart` drives `basicLocaleListResolution` through a pumped `MaterialApp` with no `locale:` argument, asserting on rendered copy (`Stack` / `Стек`) and clearing `platformDispatcher.localesTestValue` in `tearDown`.

## Red-confirmation results (every gate proven load-bearing)

| Temporary violation | Result | Restored |
|---|---|---|
| Deleted `preferred-supported-locales:` from `l10n.yaml`, re-ran gen-l10n | **RED** — 1 failure. Part (a) `supportedLocales.first == en` still PASSED (English still sorts first); only part (b), the declaration assertion, failed. Exactly the PF-1 vacuity the plan predicted. | yes, `git checkout --` + gen-l10n |
| Added `const Text('Language settings')` to `lib/features/settings/settings_screen.dart` | **RED** — widget-position gate and classification gate both failed | yes |
| Added `Text(DateTime.now().year.toString())` to the same file | **RED** — numeric `.toString()` gate failed | yes (same revert) |
| Removed `many{...}` from `substancesCount` in `app_uk.arb` | **RED** — `declares {one, few, other} but uk requires {other, many, one, few}` | yes |
| Removed the `weeksCount` key from `app_uk.arb` | **RED** — `app_uk.arb is missing these keys ... Add: {weeksCount}` | yes, + gen-l10n, `l10n-untranslated.json` back to `{}` |

## Deviations from Plan

**1. [Rule 3 — blocking] One extra allowlist entry beyond the six categories the plan named**

- **Found during:** Task 2, first run of the classification gate.
- **Issue:** `lib/features/stack/catalog.dart:158` holds `lookupAppLocalizations(const Locale('en'))` — the English-name index that lets a Ukrainian-locale user find "creatine" by typing latin (P-2). The literal `'en'` carries two letters, so the classification gate flagged it, and none of the six named categories (DateFormat patterns, keys, font families, assertion messages, Drift names, the prefs key) describes a language tag.
- **Fix:** added a seventh named entry, `language tags inside Locale('xx')`, with the rationale that a BCP-47 subtag names a language rather than being a word in one, and that the site points at the DECLARED fallback language rather than at a shipped-language list — adding an ARB file requires no edit there, so it is not the per-language code path criterion 4 forbids. The flagging patterns were NOT widened.
- **Files modified:** `test/l10n/no_hardcoded_strings_test.dart`
- **Commit:** 6f1e9ef

**2. [scope note, not a deviation] The classification gate is broader than the plan's literal wording**

The plan's `<action>` specifies flagging literals in widget positions, then names an allowlist covering categories (Drift column names, import paths, assertion messages) that can never appear in a widget position. Implementing only the widget-position scan would have made the mandated allowlist dead code — and, as the plan itself argues, an allowlist that classifies nothing is not a discipline. The gate therefore also runs the audit's third grep (A-2 item 3) mechanically: every translatable literal in `lib/`, wherever it sits, must match a named category. Generated Drift output (`*.g.dart`) stays inside the glob and is covered by one named entry rather than a silent exclusion, so the proven file count stays honest.

**3. [housekeeping] `refactor(05-03)` follow-up commit f72d2db**

Two flagging patterns (`\bText\s*\(` and the identifier-character class) were still inlined at their use sites, against Task 2's acceptance criterion that the flagging patterns be named constants. Hoisted to `textConstructorPattern` / `identifierCharPattern` at the top of the file. No behaviour change; the gate's 8 tests pass identically before and after.

## Known Stubs

None.

## Threat Flags

None. This plan adds no runtime surface: four test files, zero packages, zero changes under `lib/`.

Threat register coverage: T-05-01 (synthetic-locale group, Task 1), T-05-04 (untranslated report + full key parity, Tasks 1 and 3), T-05-07 (`kMaterialSupportedLanguages` gate, Task 1), T-05-SC (no dependency line added — verified by an empty `git diff --stat pubspec.yaml`).

## Notes for the next plan

- `flutter test` does NOT run gen-l10n (PF-10). Any ARB edit must be followed by `flutter gen-l10n` before the l10n gates mean anything; the red-confirmations above each needed it.
- `l10n-untranslated.json` is gitignored and regenerates on every gen-l10n run; Task 1's assertion treats "absent" and "`{}`" as equally clean.
- If a future phase adds a language outside `kMaterialSupportedLanguages`, Task 1 goes red by design — the fix is a decision (custom Material delegate) rather than a relaxed assertion.

## Self-Check: PASSED

- `test/l10n/new_language_contract_test.dart` — FOUND
- `test/l10n/no_hardcoded_strings_test.dart` — FOUND
- `test/l10n/arb_parity_test.dart` — FOUND
- `test/l10n/locale_resolution_test.dart` — FOUND
- Commits 93721fb, 6f1e9ef, 1f97c06, f72d2db — all FOUND in `git log`
- `flutter analyze`: No issues found
- `flutter test`: 619 tests, all passed
