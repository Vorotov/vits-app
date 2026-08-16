---
phase: 05-localization-settings
verified: 2026-08-16T04:16:03Z
status: human_needed
score: 43/45 must-haves verified
behavior_unverified: 0
overrides_applied: 0
milestone_sweep: 23/23 v1 requirements delivered by shipped code (L10N-01..04 pending only the two device backstops)
human_verification:
  - test: "P2 / Backstop 14 — on a PHYSICAL iOS device and a PHYSICAL Android device, walk Українська → English → System default at the device's own text-size setting, reading every screen built in Phases 2-4 (app shell, Stack, add-supplement sheet, regimen editor, Calendar day + week strip + dose action sheet, Цикли gantt + load chart + week detail, Рік matrix + month detail, Settings)."
    expected: "Every screen follows the switch, no clipped or overlapping text at the device's own text size, and the locked mixed-family Cyrillic rendering (Instrument Sans Latin/digits + platform Cyrillic fallback) is acceptable at ship quality on BOTH platforms. Rendering WILL differ between iOS (SF fallback) and Android (Roboto fallback) — that is expected and locked; the question is whether each is independently acceptable."
    why_human: "Ship-quality visual judgment of a mixed-family text rendering cannot be asserted programmatically. `tester.takeException() == null` proves no layout exception, not that a line reads well. Declared `verification: backstop` in 05-05-PLAN.md — abstains without explicit human evidence."
    evidence_required: "Result per platform, naming the screens walked and any defect found, with device model and OS version."
    note: "State at UAT so it is NOT filed as a bug (E-12): supplement names already in the stack do NOT re-localize. A catalog entry copies the active locale's name onto the Supplement row at add-time; from that moment it is user data. Asserted as intended behaviour by test/features/stack_screen_test.dart:971."
  - test: "P3 / Backstop 15 — on a PHYSICAL device: (a) with the language picker open, tap a row; (b) force-quit the app, then cold-start it."
    expected: "(a) No perceptible lag and no flash — the state-first ordering in LocaleController.setLocale keeps the SharedPreferences write off the repaint path. (b) The stored language is on the FIRST painted frame, with no system-language frame before it."
    why_human: "This is the ONLY evidence covering the async main() bootstrap. This phase made main() async and injected a SharedPreferences instance — exactly the change class that breaks a real launch while every widget test stays green. integration_test/data03_loop_test.dart pumps BoostqueApp directly (lines 76/328) and never calls main(), so P1 cannot substitute. The widget-level restart test (settings_screen_test.dart:245) tears down and rebuilds the app tree over the same store — it proves the seed is synchronous, not that the real process bootstrap is. Declared `verification: backstop` in 05-05-PLAN.md. If skipped, threat T-05-10 (severity high) has NO mitigating evidence at all."
    evidence_required: "Both observations, per platform, with device model and OS version."
  - test: "Visual half of ROADMAP SC1 — read the Ukrainian screens on device and confirm all four plural forms read naturally in context (1 / 2 / 5 / 11 / 21 substances, weeks, cycles, slots, doses)."
    expected: "Ukrainian declensions read correctly in the rendered sentence, not merely in the ARB. Covered incidentally by P2's walkthrough."
    why_human: "plurals_test.dart proves the correct CLDR form is SELECTED and rendered for 10 keys at 1/2/5/11/21; whether the resulting Ukrainian sentence reads naturally in its surrounding copy is an editorial judgment. Fold into P2 rather than running separately."
warnings:
  - id: W1
    severity: warning
    statement: "The 05-05 must-have truth 'the codebase's only concatenation of localized fragments is gone' is inaccurate as literally worded. Three Dart-side concatenations of localized fragments remain."
    sites:
      - "lib/features/stack/schedule_summary_text.dart:48-51 — '${l10n.weeksCount(on)} / ${l10n.noBreak | l10n.weeksCount(off)}$tail'"
      - "lib/features/stack/schedule_summary_text.dart:43 — ' · ${l10n.slotsPerDay(slotCount)}'"
      - "lib/features/calendar/planner_week_detail.dart:153-154 — '${l10n.weekLoadLabel(...)} · ${l10n.weekFreeSlots(free) | l10n.weekNoFreeSlots}'"
    assessment: "NOT a blocker. All three are glyph-separated ENUMERATIONS (` · `, ` / `) where word order carries no grammar, each carries an in-code rationale ('only the separators live in code'; '\" · \" is a separator glyph, the sanctioned literal exception'), and none affects a ROADMAP success criterion. The operative A2 deliverable — addSupplementCatalogSemantics as a single two-placeholder ARB key, both locales pinned off the semantics tree, protected by a source gate — is fully delivered and wired. Considered marking the truth FAILED and did not: the artifact landed, the gate exists, and only the universal-quantifier framing overstates. Recorded here so the record is auditable."
    residual_risk: "The 05-05 PF-5 source gate is scoped to lib/features/stack/add_supplement_sheet.dart only. A new concatenation elsewhere in lib/ is ungated. Candidate v1.x: widen the `${l10n.` gate to all of lib/ with a named allowlist for the three sanctioned separator sites."
  - id: W2
    severity: warning
    statement: "Four `.toUpperCase()` call sites apply Dart's locale-INDEPENDENT Unicode default casing to locale-formatted month/weekday labels — the same failure class Amendment A3 fixed for sentence-casing, left unaddressed for uppercasing."
    sites:
      - "lib/features/calendar/planner_year_grid.dart:163 — DateFormat('LLL', locale).format(...).toUpperCase()"
      - "lib/features/calendar/planner_month_detail.dart:120 — DateFormat('LLLL', locale)...toUpperCase()"
      - "lib/features/calendar/week_strip.dart:278 — DateFormat.E(locale).format(day).toUpperCase()"
      - "lib/features/calendar/planner_gantt.dart:155 — DateFormat('LLL', locale).format(...).toUpperCase()"
    assessment: "NOT a blocker for v1. Zero impact on the two shipped languages: en and uk uppercase identically under Unicode default mappings. It is a genuine scope limit on criterion 4's 'no code changes' guarantee for a FUTURE tr/az ARB, where `nisan` must uppercase to `NİSAN` and Dart's default yields `NISAN`. No plan claimed to fix these — 05-02's A3 truth is scoped to sentence-casing and is satisfied — so this is a newly-surfaced residual, not a missed must-have."
    residual_risk: "Recorded as the honest boundary of criterion 4 alongside the kMaterialSupportedLanguages boundary that new_language_contract_test.dart already pins. Candidate v1.x: route through an intl locale-aware upper-casing helper, or move the uppercase presentation into the ARB as 05-01's settingsLanguageTitle already does."
  - id: W3
    severity: info
    statement: ".planning/STATE.md 'Pending Todos' still lists all three carried todos (Instrument Sans Cyrillic gap, Riverpod auto-retry, gantt truncation / 14px week columns) as open. All three are CLOSED as written decisions in 05-05-SUMMARY.md and two are held by tests."
    assessment: "Documentation drift only, zero code impact. STATE.md should be updated at phase sign-off."
  - id: W4
    severity: info
    statement: "`flutter gen-l10n` emits a deprecation notice: 'The argument \"synthetic-package\" no longer has any effect and should be removed.' l10n.yaml:6 still declares `synthetic-package: false`."
    assessment: "Cosmetic. Exit code 0, generated output correct and byte-identical to what is committed. One-line cleanup for v1.x."
---

# Phase 5: Localization & Settings Verification Report

**Phase Goal:** The whole app — every screen built in Phases 2 through 4 — is genuinely bilingual by default and instantly switchable by the user.
**Verified:** 2026-08-16T04:16:03Z
**Status:** human_needed
**Re-verification:** No — initial verification
**Milestone context:** FINAL v1 phase. A milestone-level requirement sweep is included below.

## Independently Re-Run Evidence

Every command below was executed by this verifier in its own process. SUMMARY.md claims were not accepted as evidence.

| Command | Claimed | Observed | Status |
|---|---|---|---|
| `flutter analyze` | 0 issues | `No issues found! (ran in 2.3s)`, exit 0 | ✓ CONFIRMED |
| `flutter test` | 676 passing, 0 failing | `00:10 +676: All tests passed!`, exit 0 | ✓ CONFIRMED |
| `flutter gen-l10n` | exit 0, no diff | exit 0; `git status --porcelain` shows only an untracked `claude_design_mockup/.thumbnail` — zero diff to tracked generated sources | ✓ CONFIRMED |
| Phase gate `flutter gen-l10n && flutter analyze && flutter test` (PF-10) | green | green in that order | ✓ CONFIRMED |
| `git diff --stat 23aab9c HEAD -- pubspec.yaml lib/core/theme/ assets/fonts/` | EMPTY | EMPTY | ✓ CONFIRMED (LOCKED-FONT held across the whole phase) |
| Debt-marker scan (`TODO\|FIXME\|XXX\|TBD\|HACK\|PLACEHOLDER`) over `lib/` + phase test files | none added | **zero matches** | ✓ CONFIRMED |
| `skip:` scan over `test/` | no skipped tests | **zero matches** | ✓ CONFIRMED |
| Commits `f244b11 52d957a 6b3e59f 7d8ff17 f38d6de 054845b 93721fb 6f1e9ef 1f97c06 f72d2db a616b88 82c7cd7 69d1a00 10ab779 82f80a7` | all present | all present in `git log` | ✓ CONFIRMED |

**VALIDATION.md per-task map:** the map contains a single generic row (`L10N-01..04`, automated command `flutter test`, "✅ infra exists / ⬜ pending"). That command was re-run and is green. The map was never filled in per-task by the planner — a process gap, not a code gap; the four plans' own `<verify><automated>` blocks carried the real per-task commands and every one is represented in the suite.

## Goal Achievement

### ROADMAP Success Criteria

| # | Criterion | Status | Evidence |
|---|---|---|---|
| 1 | Every screen displays correctly in Ukrainian with all four CLDR plural forms (one/few/many/other, incl. the 11-14 exception) and in English with correct singular/plural | ✓ VERIFIED (visual half → P2) | Bilingual render matrix groups in **5** suites — `app_shell_test.dart:195`, `stack_screen_test.dart:640`, `regimen_editor_test.dart:673`, `calendar_screen_test.dart:2965`, plus `planner_screen_test.dart`'s uk×en text-scale matrix from Phase 4 — covering app shell, Stack, add-supplement sheet, regimen editor, Calendar day, dose action sheet, Цикли, Рік. Each case asserts a locale-distinctive string (right language, not just rendered), `takeException()` null at textScaler 1.0/1.6, and — while en is active — `expectNoCyrillicWhileEn` with a single named allowlist entry (`Українська`). Plurals: **10 plural keys** in both ARBs, all four uk forms present on every one; `plurals_test.dart` probes rendered output at 1/2/5/**11**/21 for each (11-14 exception explicit on 8 keys). `arb_parity_test.dart:78` derives required categories from intl's own CLDR rules (`Intl.plural` over 0-100 ∪ {other}) rather than a transcribed table. |
| 2 | On first launch the app matches the device's system language when it's Ukrainian or English, and falls back to English for any other system language | ✓ VERIFIED | `locale_resolution_test.dart` drives the REAL resolver (`platformDispatcher.localesTestValue` → `basicLocaleListResolution` → rendered copy `Stack`/`Стек`, no `locale:` argument) across 4 cases: `de_DE` → English; `[de_DE, uk_UA, en_US]` → **Ukrainian** (proves the whole preference LIST is walked, not just entry 0); `uk_UA` → Ukrainian (country-subtag match on language code); `en_GB` → English. `tearDown` clears the test value so no case inherits the previous device. |
| 3 | User can override the language in Settings; the change applies instantly across every open screen and persists across app restarts | ✓ VERIFIED (real cold start → P3) | **Instant:** `settings_screen_test.dart:197` taps a row and asserts, after **exactly one `tester.pump()`**, the Settings body, the screen title AND the `NavigationBar` destination outside the screen — in both directions (en→uk→en). `:489` re-localizes a **pushed route** (regimen editor) in one pump; `:529` re-localizes an **open bottom sheet** (add-supplement) in one pump. `calendar_screen_test.dart:3141` re-localizes an open dose action sheet in one pump. **Persists:** `:245` writes `app_locale=uk`, tears the tree down to a `SizedBox`, boots a fresh scope over the same store, and asserts the Ukrainian nav bar **before any additional pump** — an async seed would render one English frame first. `:283` proves System default REMOVES the key rather than storing a code. Key wire confirmed in source: `main.dart:42` `locale: ref.watch(localeControllerProvider)`. |
| 4 | All dates, month names, and numbers throughout the app are locale-formatted, and adding a new language requires only one new ARB file with no code changes | ✓ VERIFIED (see reasoning below) | See the dedicated Criterion-4 section. |

### Criterion 4 — scrutinized, as instructed

**Half A — locale formatting.** VERIFIED by direct source inspection, not by SUMMARY claim. Every one of the **9** `DateFormat(...)` call sites in `lib/` passes `locale`, and the single `NumberFormat.decimalPattern(locale)` does too. In both async screens the locale is read from the widget tree (`Localizations.localeOf(context).toString()`), never a literal tag — `calendar_screen.dart:131`, `planner_screen.dart:194`. Amendment A3 landed: `calendar_screen.dart:142` sentence-cases through `toBeginningOfSentenceCase(value, locale)` with the threaded locale, and the retired `_capitalizeFirst` helper is gone. `no_hardcoded_strings_test.dart` additionally gates `.toString()` inside a `Text(` argument. Residual: **W2** (four `.toUpperCase()` sites) — see Warnings.

**Half B — "one new ARB file, no code changes."** 05-03-SUMMARY.md is explicit that this is proven by **derivation plus a synthetic-locale negative case, NOT by executing a real third-ARB `flutter gen-l10n` build**. My independent judgment on whether the criterion is genuinely met on that evidence:

*What the derivation actually proves* (I read `new_language_contract_test.dart` in full and re-ran the greps rather than trusting the summary):

1. `AppLocalizations.supportedLocales` ≡ the ARB directory read off disk by glob (test asserts equality, not membership).
2. `LocaleController.supportedLanguageCodes` ≡ the same disk set — and the controller genuinely derives it (`locale_controller.dart:23-25` is a comprehension over `supportedLocales`, no literal).
3. The picker's option list is `[null, ...AppLocalizations.supportedLocales]` (`language_picker.dart:50`), labels from `lookupAppLocalizations(locale).languageName` — that locale's OWN ARB. Row count asserted as `1 + supportedLocales.length`; row 2's label asserted to be `supportedLocales.first`'s own endonym (a name-sorted list would look right and still fail).
4. **My own independent grep of `lib/` (excluding generated l10n) found ZERO language-code literals, ZERO endonym literals, and ZERO `switch`/`Map` keyed on `languageCode`.** The only `'uk'` occurrences are inside comments; the only `Locale('en')` is `catalog.dart:158`, the cross-locale English search index, which points at the DECLARED fallback rather than at a shipped-language list.
5. Two source gates in `settings_screen_test.dart` (`:695`, `:714`) forbid a language code, an endonym, or a locale-keyed switch/Map from ever re-entering `lib/features/settings/`, each preceded by a prove-the-glob assertion.
6. `untranslated-messages-file` is asserted absent-or-empty, closing gen-l10n's one silent failure mode (a missing key falling back to the template English message with only a warning).
7. `kMaterialSupportedLanguages` membership pins the HONEST boundary of the guarantee rather than overclaiming it.
8. The synthetic-locale group derives an unshipped code (first candidate not on disk, so it self-corrects if one ships) and proves the negative half: absent from the generated list, absent from the controller's allowlist, and a tampered stored preference holding it sanitizes to `null` instead of reaching `lookupAppLocalizations`'s throw at MaterialApp build time.
9. Plural requirements are probed from intl's CLDR rules, so a new ARB brings its own plural obligations with it rather than inheriting a hand-kept table.

*What it does not prove:* that `flutter gen-l10n` against a real third ARB succeeds end-to-end and the app renders in that language.

**Verdict: criterion 4 is genuinely met on this evidence, for the guarantee as honestly bounded.** Reasoning: the unproven step is *Flutter tooling behaviour*, not this repository's code, and every repository-side link in the chain is derived-from-disk and continuously gated. A one-off subprocess `gen-l10n` shell-out would in fact be **weaker** evidence — it would prove one language once, at one commit, while the derivation gates every representation on every run and grows automatically with the ARB directory. Introducing the repository's first subprocess-spawning test convention in the final v1 phase would also be a genuine cost against a benefit already covered. The counter-argument I weighed and rejected: a derivation can agree with itself while all three representations are wrong together — but assertion 1 anchors the chain to the **filesystem**, which is the one thing gen-l10n also reads, so they cannot drift in lockstep.

**Bounded, not absolute.** The guarantee holds for any of the 82 `kMaterialSupportedLanguages`, given (a) the new ARB supplies every key, and (b) the language tolerates Dart's locale-independent uppercasing at four presentation sites (**W2**) and glyph-separated enumeration order at three (**W1**). Those two limits are recorded above so the boundary is auditable rather than implied.

### Per-Plan `must_haves.truths`

#### 05-01 — Settings screen, generated language picker, derived locale set (14 truths)

| # | Truth (UI Consideration) | Status | Evidence |
|---|---|---|---|
| 1 | Card renders exactly `1 + supportedLocales.length` rows, System default first, generated order, 1px `BqColors.hairline` dividers (#1) | ✓ VERIFIED | `language_picker.dart:50` options list; `:54-60` divider at `index > 0` with `color: BqColors.hairline`, `thickness: 1`. Test `settings_screen_test.dart:309` asserts `findsNWidgets(1 + supportedLocales.length)` and row 2 == `supportedLocales.first`'s own endonym. |
| 2 | Card can never be empty; no empty state authored (#2) | ✓ VERIFIED | Template ARB is a build requirement, so `supportedLocales` is never empty; `new_language_contract_test.dart:122` asserts `arbCodes.length >= 2`. No empty-state widget exists under `lib/features/settings/`. |
| 3 | No async surface — no spinner/shimmer/skeleton anywhere under `lib/features/settings/` (#3) | ✓ VERIFIED | Source gate `settings_screen_test.dart:725` forbids `ProgressIndicator`, `Shimmer`, `Skeleton`, `AsyncLoading` across both files, over comment-stripped source, behind a prove-the-glob assertion. Structurally true: `supportedLocales` is a compile-time const, `LocaleController` is a synchronous `Notifier`. |
| 4 | No error surface may be authored; failed prefs write is silent; `setLocale` is state-first (#4, DECIDED-8) | ✓ VERIFIED | Source gate `:743` forbids `Error`, `retry`, `catch (`, `onError`. `locale_controller.dart:52-58` sets `state` BEFORE awaiting the prefs write; `locale_controller_test.dart:68` pins that ordering (PF-3). |
| 5 | Row count derived, not written; no language code / endonym / switch / Map under `lib/features/settings/` (#5) | ✓ VERIFIED | Gates `:695` and `:714`. Independently re-grepped `lib/` — zero hits outside comments. |
| 6 | Exactly one row checked at all times; a tampered/removed code sanitizes to null and checks System default (#6, T-05-01) | ✓ VERIFIED | `language_picker.dart:67` compares by `languageCode` so a sanitized `null` checks the System row. `locale_controller.dart:40-42` allowlist-gates the stored value. Tests `:426`, `:439`, `:450` cover no-override / shipped-code / tampered-code, each asserting exactly one check. `new_language_contract_test.dart:328` proves the tampered path returns `null` rather than reaching the generated lookup's throw. |
| 7 | Row label `Expanded` and WRAPS — no maxLines/ellipsis/fixed width; `ConstrainedBox(minHeight: 52)` never `SizedBox`; check mark non-flexible (#7) | ✓ VERIFIED | `language_picker.dart:109-136` — `ConstrainedBox(minHeight: 52)`, `Expanded(child: Text(label, ...))` with no `maxLines` and no `overflow`, trailing glyph outside the `Expanded`. Test `:596` asserts null `maxLines` and wrapping at textScaler 2.0. Comment documents the 47.5px computation that makes the floor load-bearing. |
| 8 | Title uses theme `headlineSmall` verbatim; eyebrow `BqText.mono(10.5, textMuted, 0.63)` verbatim; both wrap; eyebrow carries `Semantics(header: true)` (#8) | ✓ VERIFIED | `settings_screen.dart:51-68` matches verbatim. Test `:404`. Font-size gate `:797` restricts sizes to {25, 15, 10.5} and forbids hex color literals. |
| 9 | Tap applies within one frame across this screen, nav bar, both other tabs, pushed route and open sheet; no snackbar/dialog/Save/restart; already-selected row is a no-op (#9, DECIDED-7) | ✓ VERIFIED | Tests `:197` (screen + nav bar + tabs, one pump, both directions), `:472` (no-op on selected row), `:489` (pushed route), `:529` (open sheet). Key wire: `main.dart:42`. |
| 10 | Row IS the semantics node — `inMutuallyExclusiveGroup`, `checked`, label, `onTap` on the row, subtree `ExcludeSemantics`-wrapped; check glyph carries no semantics; selection legible without color | ✓ VERIFIED | `language_picker.dart:100-108` exactly that shape; `button: true` deliberately unset. Non-color channels: glyph presence + `FontWeight.w400 → w600` (`:131-133`). |
| 11 | textScaler 1.0/1.6/2.0 in both locales throws no layout exception; while en is active no Cyrillic in any rendered Text except `languageName` (#11) | ✓ VERIFIED | Test loop `:567` over `['uk','en'] × [1.0, 1.6, 2.0]`; `:619` and `:643` run the Cyrillic sweep with the single named allowlist entry `Українська` (`test/support/locale_matrix.dart:54`). |
| 12 | No risk/warn/calm token, no disclaimer, no numeral, no date, no free-text input, no DB write under `lib/features/settings/`; the whole write surface is one prefs key (#13) | ✓ VERIFIED | Gates `:756` (no `DateFormat`/`NumberFormat`/`Intl.plural`), `:767` (no `BqColors.risk|warn|calm`, no `disclaimerEducational`), `:785` (no `drift`/`database.dart`/`Repository`/`repositories`). Confirmed by reading both source files. |
| 13 | L10N-03: a stored override survives a full app-tree restart and is applied on the first painted frame — no system-language frame first | ✓ VERIFIED | `locale_controller.dart:31` reads prefs synchronously in `build()`; `main.dart:16-19` resolves the store before `runApp` and overrides the provider. Test `:245` asserts before any extra pump. Real-process cold start → **P3**. |
| 14 | L10N-02: `supportedLocales.first == Locale('en')` because `l10n.yaml` DECLARES it, not because 'en' sorts first (PF-1) | ✓ VERIFIED | `l10n.yaml:10-11` `preferred-supported-locales: [en]`. `new_language_contract_test.dart:171` asserts BOTH halves and the summary records a red-confirmation where deleting the declaration left part (a) passing and failed only part (b) — exactly the vacuity the truth names. |

#### 05-02 — Amendment A1 error surface, A3 locale-aware casing (5 truths)

| # | Truth | Status | Evidence |
|---|---|---|---|
| 1 | On Stack, Calendar-day and Planner the designed error copy + retry control are on screen WITHIN ONE FRAME of a provider failure, with Riverpod's default retry live; empty/populated surfaces unchanged (#12, A1) | ✓ VERIFIED | `planner_screen.dart:618` `AsyncValue(hasError: true)` as the FIRST switch arm; `stack_screen.dart:111` and `calendar_screen.dart:319` `skipLoadingOnReload: true`. The load-bearing find: `providers.dart:182,184` — `stackEntriesProvider`'s **derived merge** was collapsing a retrying failure into a plain `AsyncLoading` with `hasError: false`, so no downstream rendering rule could have worked. Fixed with a documented rationale at the merge point. One error-surface-under-live-retry test per surface: `stack_screen_test.dart:533`, `calendar_screen_test.dart:2749`, `planner_screen_test.dart:940`. |
| 2 | L10N-01: each of the three error surfaces renders its localized copy correctly in BOTH uk and en | ✓ VERIFIED | `calendar_screen_test.dart:2768` is locale-parameterized; `planner_screen_test.dart` runs the ERROR surface at uk and en across all three text scales (observed in the re-run log, tests +652/+656/+660/+664/+668/+672). |
| 3 | Auto-retry stays ENABLED in production; the change is the rendering rule, not the provider config | ✓ VERIFIED | Zero `retry:` occurrences under `lib/`; the only retry override in the repo is the pre-existing CR-02 recovery test. The new tests run with real retry timers live. |
| 4 | L10N-04: sentence-casing goes through intl's `toBeginningOfSentenceCase` with the ACTIVE locale, not locale-independent Unicode default casing (A3, PF-6) | ✓ VERIFIED | `calendar_screen.dart:142-145` — `toBeginningOfSentenceCase(DateFormat('EEEE', locale).format(day), locale)` with `locale` threaded from `Localizations.localeOf(context)` at `:131`. `_capitalizeFirst` is gone. (Scope note: this truth is about SENTENCE-casing and is satisfied; uppercasing at four other sites is **W2**.) |
| 5 | No raw exception or stack-trace text ever enters the widget tree on any of the three surfaces (T-05-03) | ✓ VERIFIED | `find.textContaining('boom-from-drift')` → `findsNothing` at `stack_screen_test.dart:589` and `calendar_screen_test.dart:2835`. Reinforced by the `_isDiagnosticMessage` allowlist rationale in the hardcoded-strings gate. |

#### 05-03 — Criterion-4 gates (8 truths)

| # | Truth | Status | Evidence |
|---|---|---|---|
| 1 | Criterion 4 PROVEN BY A TEST via a synthetic third locale, not restated in prose | ✓ VERIFIED | `new_language_contract_test.dart:291-362`, read in full. See the Criterion-4 section for my independent assessment of the derivation-vs-subprocess proof shape. |
| 2 | English fallback proven DECLARED, not alphabetical — BOTH assertions present | ✓ VERIFIED | `:171-207`, both parts, with the load-bearing half explicitly annotated "Do not delete as redundant". |
| 3 | Every ARB language inside `kMaterialSupportedLanguages` (PF-9, E-8) | ✓ VERIFIED | `:236`, a loop over the discovered set with a rationale naming `GlobalMaterialLocalizations.load`'s assert. |
| 4 | gen-l10n's untranslated-messages output absent or empty (PF-2) | ✓ VERIFIED | `:254`; `l10n.yaml:16` declares the filename; re-ran `flutter gen-l10n` and confirmed a clean regeneration. |
| 5 | L10N-04: no hardcoded user-visible string may enter `lib/` — source gate over comment-stripped source with a named const allowlist, one rationale per entry, never a loosened regex | ✓ VERIFIED | `no_hardcoded_strings_test.dart` (646 lines). Read the **9-entry** allowlist in full (`:353-421`): generated Drift output, import paths, DateFormat skeletons, `ValueKey`/`Key`, the two bundled font families, diagnostic messages, stable domain ids, the single prefs key, `Locale('xx')` tags. Each is narrowly predicated on an enclosing-call identifier or an exact value — none is a wildcard. Gate runs in BOTH directions (widget-position AND whole-`lib/` classification) plus a dead-entry check at `:559` that keeps the allowlist from accumulating unused permissions. I spot-audited the widest entry (`_isStableDomainId` allowing `CatalogEntry`) against `catalog.dart` — entries carry only stable ids and function references; every display name comes from an ARB getter. Honest. |
| 6 | L10N-01: ARB key parity is a gate, and every plural-bearing key in a Ukrainian ARB carries all four CLDR forms — derived from disk, never from a hand-kept list | ✓ VERIFIED | `arb_parity_test.dart`; plural keys found by parsing the template's VALUES for an ICU `plural` construct (`grep -c 'substancesCount'` on that file is 0); required categories derived at `:78` from `Intl.plural` over 0-100 ∪ {other}. Confirmed on disk: 10 plural keys in each ARB, all four forms on every uk entry. |
| 7 | L10N-02: the framework resolves the whole device preference LIST, and an unsupported system language resolves to English | ✓ VERIFIED | `locale_resolution_test.dart:89` — the multi-entry case, asserted on rendered copy. |
| 8 | Every glob-driven gate asserts a non-trivial file count before running | ✓ VERIFIED | Present in `new_language_contract_test.dart:122`, `no_hardcoded_strings_test.dart` (40 files, ≥20 proven), `settings_screen_test.dart:679`, and the LOCKED-FONT fallback scan. |

#### 05-04 — Bilingual render matrix (7 truths)

| # | Truth | Status | Evidence |
|---|---|---|---|
| 1 | L10N-01: EVERY screen/sheet from Phases 2-4 renders in uk AND en — app shell, Stack, add-supplement sheet, regimen editor, Calendar day, dose action sheet | ✓ VERIFIED | `bilingual render matrix (L10N-01)` groups confirmed in all 4 target suites (`app_shell_test.dart:195`, `stack_screen_test.dart:640`, `regimen_editor_test.dart:673`, `calendar_screen_test.dart:2965`), plus the planner's Phase-4 uk×en matrix. Dose action sheet covered at `calendar_screen_test.dart` matrix case "the dose action sheet in $locale at textScaler $scale". |
| 2 | Each covered screen renders at textScaler 1.0 and 1.6 in both locales with `takeException()` null | ✓ VERIFIED | Matrix loops `for (locale in ['uk','en']) for (scale in [1.0, 1.6])`. **This gate was load-bearing:** it caught two real `RenderFlex` overflows in the regimen editor (`_SliderRow` up to 126px, DOSE-TIMES header 77-84px) in BOTH languages at 1.6, fixed by replacing `Spacer` with `Expanded` + `SizedBox` (`regimen_editor_screen.dart:128`, `:502`, commit `82c7cd7`). Confirmed the fix is in the shipped source. |
| 3 | Each screen proven to be in the RIGHT language — a locale-distinctive string asserted per locale | ✓ VERIFIED | Every matrix case asserts a locale-specific ARB string; a screen rendering wholly in the fallback fails. |
| 4 | While en is active, no Cyrillic in any rendered Text; exceptions are named allowlist entries, never a relaxed regex (A8) | ✓ VERIFIED | `test/support/locale_matrix.dart:69` `expectNoCyrillicWhileEn`, called at 10 sites across 4 suites; the allowlist is ONE const list with exactly one entry (`Українська`) and a written rationale; matching is exact whole-string, never substring. |
| 5 | L10N-03: switching the locale re-localizes an open modal bottom sheet AND a pushed route in place, within a single pump | ✓ VERIFIED | `settings_screen_test.dart:489` (pushed regimen editor), `:529` (open add-supplement sheet), `calendar_screen_test.dart:3141` (open dose action sheet) — each `await tester.pump(); // exactly one frame`. |
| 6 | Golden-file snapshots explicitly rejected as the proof mechanism | ✓ VERIFIED | Zero `golden` references anywhere in `test/` (case-insensitive). Rationale recorded in the plan. |
| 7 | Supplement names already in the stack do NOT re-localize; asserted as intended (E-12) and stated at UAT | ✓ VERIFIED | `stack_screen_test.dart:971` asserts copy-on-add is intended behaviour; `catalog.dart:11-14` documents the semantics; carried into P2's UAT note above. |

#### 05-05 — Close-out (5 truths + 2 backstops)

| # | Truth | Status | Evidence |
|---|---|---|---|
| 1 | L10N-04: the codebase's only concatenation of localized fragments is gone; the add-supplement a11y label comes from a single two-placeholder ARB key (A2, PF-5) | ✓ VERIFIED (deliverable) — ⚠️ **W1** on the framing | `addSupplementCatalogSemantics: "{action}: {name}"` present in **both** ARBs (`app_en.arb:926` with template metadata for both placeholders, `app_uk.arb:167`); call site `add_supplement_sheet.dart:361`; zero `${l10n.` in that file. Both languages' word order pinned off the **semantics tree** (`Додати добавку: Креатин моногідрат` / `Add supplement: Creatine monohydrate`) as written-out literals, asserted by label SEGMENT because the whole catalog row publishes one merged node. Source gate keeps it from regressing. **However**, my own grep found three other `${l10n.` concatenations elsewhere in `lib/` — see W1. |
| 2 | The A2 change is a semantics label only — no visible pixel change | ✓ VERIFIED | `git diff --stat` for `add_supplement_sheet.dart` across the phase is 10 lines; the diff is the label construction only. No matrix case regressed. |
| 3 | LOCKED-FONT closed as a locked decision — platform Cyrillic fallback kept, no font file added/replaced, `fontFamily` unchanged, no `fontFamilyFallback` | ✓ VERIFIED | `git diff --stat 23aab9c HEAD -- pubspec.yaml lib/core/theme/ assets/fonts/` → **EMPTY across the whole phase** (re-run by me). Three source-read gates in `stack_screen_test.dart:882+`: pubspec declares exactly `[Instrument Sans, JetBrains Mono]` with the two exact asset paths; **zero** `fontFamilyFallback` anywhere under `lib/` (scan widened beyond the plan's `lib/core/theme/`, strictly stronger, behind a non-empty-glob assertion); theme names exactly the two bundled families. `pubspec.yaml:97-103` confirmed by direct read. Each gate's `reason:` names the re-measurement cost of reversal. |
| 4 | The Phase-4 auto-retry todo is closed by 05-02; gantt-truncation and 14px-week-column measurements remain accepted for v1 | ✓ VERIFIED | Auto-retry closure verified independently under 05-02 truth 1 (including the `providers.dart` merge fix the research had missed). The other two are unchanged Phase-4 measurements, accepted in `04-UAT.md:21` / `:25` / `:53`; neither is a localization defect and neither blocks a Phase-5 criterion. ⚠️ **W3**: `.planning/STATE.md` still lists all three as open todos — documentation drift. |
| 5 | The phase gate command is `flutter gen-l10n && flutter analyze && flutter test`, not the earlier phases' two-step (PF-10) | ✓ VERIFIED | Re-run by me in that order: gen-l10n exit 0 with zero diff to tracked generated sources, analyze 0 issues, 676/676. The PF-10 hazard is real and correctly named — `flutter test` does not regenerate localizations, so a suite run without step 1 can be green against stale generated code. ⚠️ **W4**: gen-l10n emits a `synthetic-package` deprecation notice (cosmetic, exit 0). |
| B14 | Backstop — whole-app bilingual walkthrough on PHYSICAL iOS + Android devices | ? UNVERIFIED → **HUMAN (P2)** | `verification: backstop`. Abstains without explicit human evidence per the honest-verifier rule. Not run, not simulated, not inferred. Routed with its evidence requirements. |
| B15 | Backstop — no lag/flash on tap; cold start shows the stored language on the first painted frame | ? UNVERIFIED → **HUMAN (P3)** | `verification: backstop`. **Cannot be substituted by anything cheaper:** it is the only evidence covering the async `main()` bootstrap this phase introduced. `integration_test/data03_loop_test.dart` pumps `BoostqueApp` directly (lines 76/328) and never calls `main()`. If skipped, threat T-05-10 has no mitigating evidence. |

**Score:** 43/45 truths verified (0 present-behavior-unverified; 2 backstops routed to human verification)

### Required Artifacts

| Artifact | Expected | Status | Details |
|---|---|---|---|
| `lib/features/settings/settings_screen.dart` | Full S7 screen, no async/error surface | ✓ VERIFIED | 87 lines, substantive, imported by `app_shell.dart`, wired into the tab shell. `ListView` (not `Column`) per the textScaler-2.0 rationale. |
| `lib/features/settings/language_picker.dart` | Derived option list, semantics on the row | ✓ VERIFIED | 159 lines, imported and used by `settings_screen.dart:80`. |
| `lib/core/l10n/locale_controller.dart` | Synchronous `Notifier`, derived allowlist, state-first `setLocale` | ✓ VERIFIED | 66 lines; watched by `main.dart:42`, read by `language_picker.dart:45,71`. |
| `lib/core/providers.dart` (`sharedPreferencesProvider`) | Throws unless overridden | ✓ VERIFIED | `:54-58`; overridden in `main.dart:19` and in every test harness reaching `LocaleController`. |
| `lib/core/l10n/arb/app_en.arb` + `app_uk.arb` | `languageName`, `languageSystem`, `settingsLanguageTitle`, `addSupplementCatalogSemantics` | ✓ VERIFIED | All present in both files; parity gated. |
| `l10n.yaml` | `preferred-supported-locales`, `untranslated-messages-file` | ✓ VERIFIED | `:10-11`, `:16`; both asserted by `new_language_contract_test.dart`. |
| `test/l10n/new_language_contract_test.dart` | Criterion-4 gate | ✓ VERIFIED | 364 lines, 11 tests. Read in full. |
| `test/l10n/no_hardcoded_strings_test.dart` | Zero-hardcoded-strings gate | ✓ VERIFIED | 646 lines, 8 tests, 9-entry named allowlist, bidirectional. |
| `test/l10n/arb_parity_test.dart` | Parity + derived plurals | ✓ VERIFIED | 294 lines, 6 tests. |
| `test/l10n/locale_resolution_test.dart` | L10N-02 as behaviour | ✓ VERIFIED | 139 lines, 4 tests, rendered-copy assertions. |
| `test/support/locale_matrix.dart` | Shared A8 allowlist + named reasons | ✓ VERIFIED | 79 lines; library with no `main()`; imported by 4 suites. |
| `test/features/settings_screen_test.dart` | Full S7 contract | ✓ VERIFIED | 25+ testWidgets/tests across 5 groups plus 8 source-invariant gates. |
| `test/l10n/locale_controller_test.dart` | Rewritten for the synchronous contract | ✓ VERIFIED | 126 lines, 7 tests including the PF-3 ordering pin. |

No artifact is a stub. No artifact is orphaned. Zero `TODO`/`FIXME`/`XXX`/`TBD`/`HACK`/`PLACEHOLDER` markers in any file touched by this phase. Zero skipped tests in the repository.

### Key Link Verification

| From | To | Via | Status | Details |
|---|---|---|---|---|
| `main.dart` | `localeControllerProvider` | `MaterialApp.locale: ref.watch(...)` | ✓ WIRED | `main.dart:42`. The single wire that makes one tap re-localize every mounted tab, pushed route and open sheet — proven by 4 one-pump propagation tests. |
| `LocaleController.supportedLanguageCodes` | `AppLocalizations.supportedLocales` | comprehension, no literal | ✓ WIRED | `locale_controller.dart:23-25`; equality to the on-disk ARB set gated. |
| `sharedPreferencesProvider` | `main()` + every test harness | `overrideWithValue(prefs)` | ✓ WIRED | `main.dart:16-19`; six harnesses closed in 05-01 (two discovered mid-execution via `AppShell`'s `IndexedStack` mounting the Settings tab). The provider throws a named `UnimplementedError` if missed — loud, not silent. |
| `language_picker` options | `[null, ...supportedLocales]` + `lookupAppLocalizations(locale).languageName` | derived list | ✓ WIRED | `language_picker.dart:50,62-64`. |
| `stackEntriesProvider` merge | downstream screen error surfaces | `skipLoadingOnReload: true` on BOTH merges | ✓ WIRED | `providers.dart:182,184`. Without this the error never reaches any screen, regardless of rendering rule. |
| `toBeginningOfSentenceCase` | `Localizations.localeOf(context)` | threaded locale argument | ✓ WIRED | `calendar_screen.dart:131,142-145`. |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|---|---|---|---|---|
| `language_picker.dart` | `options` | `AppLocalizations.supportedLocales` (generated from the ARB directory) | Yes — asserted equal to the on-disk file set | ✓ FLOWING |
| `language_picker.dart` | row `label` | `lookupAppLocalizations(locale).languageName` / `l10n.languageSystem` | Yes — per-locale ARB, non-empty and unique asserted | ✓ FLOWING |
| `language_picker.dart` | `current` (checked row) | `ref.watch(localeControllerProvider)` → SharedPreferences `app_locale`, allowlist-sanitized | Yes — round-trip proven | ✓ FLOWING |
| `settings_screen.dart` | title / eyebrow | `l10n.tabSettings` / `l10n.settingsLanguageTitle` | Yes | ✓ FLOWING |
| `stack_screen` / `calendar_screen` / `planner_screen` | error surface copy | ARB keys via the `hasError` arm fed by `stackEntriesProvider` | Yes — exercised with real retry timers live | ✓ FLOWING |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|---|---|---|---|
| Full suite green under the phase gate | `flutter gen-l10n && flutter analyze && flutter test` | gen-l10n exit 0 / no tracked diff; `No issues found!`; `+676: All tests passed!` | ✓ PASS |
| Generated sources are current, not stale (PF-10) | `flutter gen-l10n; git status --porcelain` | only an untracked mockup thumbnail | ✓ PASS |
| LOCKED-FONT held across the whole phase | `git diff --stat 23aab9c HEAD -- pubspec.yaml lib/core/theme/ assets/fonts/` | EMPTY | ✓ PASS |
| No per-language code path in `lib/` | grep for `'uk'` / `'en'` / `languageCode` / locale-keyed switch, excluding generated l10n | zero outside comments; one `Locale('en')` fallback index | ✓ PASS |
| All date/number formatting is locale-threaded | grep all `DateFormat(` / `NumberFormat` call sites | 9/9 `DateFormat` + 1/1 `NumberFormat` pass `locale` | ✓ PASS |
| uk ARB carries all four CLDR forms on every plural key | grep `, plural,` and `many{` in `app_uk.arb` | 10 plural keys, all four forms on each | ✓ PASS |
| No debt markers introduced | grep `TODO\|FIXME\|XXX\|TBD\|HACK\|PLACEHOLDER` over `lib/` + phase tests | zero | ✓ PASS |
| No skipped tests | grep `skip:` over `test/` | zero | ✓ PASS |
| DATA-03 on-device regression, BOTH platforms (P1) | `flutter test integration_test/data03_loop_test.dart -d <device>` | **PASSED** on iPhone 17 simulator (iOS 26.5) and Android `emulator-5554` (API 36), run by the orchestrator after this phase's merge | ✓ PASS (orchestrator-supplied evidence) |
| P2 — physical-device bilingual walkthrough | manual | not run | ? SKIP → human |
| P3 — physical-device switch feel + cold start | manual | not run | ? SKIP → human |

### Probe Execution

No `scripts/*/tests/probe-*.sh` exist in this repository and no PLAN or SUMMARY declares a probe. Probe execution: **N/A**. The equivalent contract for this project is the phase gate command, re-run above.

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|---|---|---|---|---|
| L10N-01 | 05-02, 05-03, 05-04, 05-05 | uk + en with correct plural forms (all CLDR forms incl. 11-14) | ✓ SATISFIED | Bilingual matrix in 5 suites; 10 plural keys × 4 uk forms; `plurals_test.dart` at 1/2/5/11/21; derived-category parity gate; Cyrillic-leak sweep. Ship-quality visual half → P2. |
| L10N-02 | 05-01, 05-03 | System language when supported, English fallback | ✓ SATISFIED | 4 behavioural resolution cases incl. the whole-preference-list walk; declared (not alphabetical) fallback double-asserted. |
| L10N-03 | 05-01, 05-04, 05-05 | Override in Settings, applies instantly, persists across restarts | ✓ SATISFIED | One-pump propagation across screen / nav bar / tabs / pushed route / open sheet / open dose sheet; app-tree restart applied on the first painted frame. Real-process cold start → P3. |
| L10N-04 | 05-01, 05-02, 05-03, 05-05 | Locale-formatted dates/months/numbers; zero hardcoded strings; new language = one ARB file | ✓ SATISFIED (bounded) | 9/9 `DateFormat` + `NumberFormat` locale-threaded; A3 sentence-casing through intl; bidirectional hardcoded-strings gate with a 9-entry named allowlist; criterion-4 derivation + synthetic-locale negative case. Boundaries recorded as W1/W2. |

**Orphaned requirements:** none. REQUIREMENTS.md maps exactly L10N-01..04 to Phase 5, and all four are claimed by plans in this phase.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|---|---|---|---|---|
| `lib/features/stack/schedule_summary_text.dart` | 43, 48-51 | Localized fragments joined by a Dart-hardcoded ` · ` / ` / ` separator | ⚠️ Warning (W1) | Word order not translator-controllable for these enumerations. Glyph-separated, in-code rationale present, no criterion affected. |
| `lib/features/calendar/planner_week_detail.dart` | 153-154 | Same pattern | ⚠️ Warning (W1) | Same. Comment names it "the sanctioned literal exception". |
| `lib/features/calendar/planner_year_grid.dart` | 163 | `.toUpperCase()` on a locale-formatted month | ⚠️ Warning (W2) | Locale-independent casing; no impact on en/uk, a scope limit for a future tr/az ARB. |
| `lib/features/calendar/planner_month_detail.dart` | 120 | Same | ⚠️ Warning (W2) | Same. |
| `lib/features/calendar/week_strip.dart` | 278 | Same | ⚠️ Warning (W2) | Same. |
| `lib/features/calendar/planner_gantt.dart` | 155 | Same | ⚠️ Warning (W2) | Same. |
| `lib/features/calendar/planner_screen.dart` | 146 | `'‹ ${l10n.backToToday}'` — hardcoded leading chevron | ℹ️ Info | Direction-neutral padding is used elsewhere; a literal `‹` prefix would sit on the wrong side under RTL. RTL is not a v1 language. |
| `.planning/STATE.md` | 76-81 | Three closed todos still listed as pending | ℹ️ Info (W3) | Documentation drift; update at sign-off. |
| `l10n.yaml` | 6 | Deprecated `synthetic-package: false` | ℹ️ Info (W4) | Cosmetic; gen-l10n exits 0. |

**Blockers: none.** Zero debt markers, zero stubs, zero placeholder values, zero skipped tests, zero orphaned artifacts, zero broken key links.

## Milestone v1 Requirement Sweep

Final-phase sanity pass over all **23** v1 requirements. Each was checked against shipped code, not against the REQUIREMENTS.md checkbox.

| ID | Requirement | Checkbox | Shipped-code evidence | Verdict |
|---|---|---|---|---|
| STACK-01 | Add from a bundled locale-aware catalog by searching its name | [x] | `lib/features/stack/catalog.dart` — 15 `CatalogEntry` descriptors carrying stable ids + ARB-getter references (no name literals); `searchCatalog(query, active)` matches the active locale's names AND the English index (`_en`) so a uk user can type latin. `test/features/catalog_search_test.dart`. | ✓ DELIVERED |
| STACK-02 | Add manually with a name and dose description | [x] | `lib/features/stack/add_supplement_sheet.dart` (two-tab sheet, manual tab); covered by the bilingual matrix in `stack_screen_test.dart`. | ✓ DELIVERED |
| STACK-03 | Stack as cards: name, dose, color tag, status, schedule summary | [x] | `lib/features/stack/stack_screen.dart` + `stack_status.dart` (`statusOf`) + `schedule_summary_text.dart` (`scheduleSummaryText`); `test/features/stack_status_test.dart`. | ✓ DELIVERED |
| STACK-04 | Edit/delete; delete removes regimen and future doses (soft delete) | [x] | `drift_repositories.dart` `softDeleteCascade`; `test/db/cascade_delete_test.dart`. | ✓ DELIVERED |
| REGI-01 | Cyclic regimen: start date, on/off days in 7-day steps, repeating | [x] | `regimen_editor_controller.dart` + `regimen_editor_screen.dart` (sliders, 28-bar preview); `core/domain/cycle_math.dart`. | ✓ DELIVERED |
| REGI-02 | One-time course, end inclusive | [x] | `CourseSummary` in `stack_status.dart`; `_courseRange` in `schedule_summary_text.dart:59`; cycle-math course branch. | ✓ DELIVERED |
| REGI-03 | 1-6 daily time slots, each with its own time and dose label | [x] | `regimen_editor_controller.dart:144` `static const int maxSlots = 6`; `:247` `canAddSlot`; `:284` refuses at the cap. `test/features/regimen_editor_controller_test.dart`. | ✓ DELIVERED |
| REGI-04 | Pause/resume; paused produces no doses and shows PAUSED | [x] | `drift_repositories.dart:212` `setPaused`; `watchDay` hides a paused regimen's PENDING doses while keeping recorded history; `test/db/pause_filter_test.dart`. | ✓ DELIVERED |
| TRACK-01 | Today's doses grouped by time block + day-progress ring | [x] | `day_block_section.dart`, `day_progress_ring.dart`, `day_view_model.dart` (`dayRingCounts`); `test/features/day_view_model_test.dart`. | ✓ DELIVERED |
| TRACK-02 | Mark taken/skipped with one tap; undo | [x] | `IntakeRepository.setStatus(logId, DoseStatus)` (`repositories.dart:103`); `dose_action_sheet.dart`, `dose_row.dart`; guarded mark/undo tested in `calendar_screen_test.dart`. | ✓ DELIVERED |
| TRACK-03 | Browse past/current-week days; unmarked past = "missed" in view, DB row stays pending | [x] | `day_view_model.dart:105-110` — the ONE `isMissed` rule, computed in the view; `week_strip.dart`; missed-stays-pending asserted in the calendar suite. | ✓ DELIVERED |
| TRACK-04 | Doses only on active cycle days; correct across DST and year boundaries | [x] | `core/domain/cycle_math.dart` with UTC date-only normalization; `test/domain/cycle_math_test.dart` carries 6 DST / year-boundary references. | ✓ DELIVERED |
| PLAN-01 | ~4-month Cycles gantt, solid/lighter segments, today marker | [x] | `planner_gantt.dart`, `planner_view_model.dart`, `test/domain/planner_window_test.dart`. | ✓ DELIVERED |
| PLAN-02 | Weekly concurrent-load chart vs the editorial 5-substance line; tap a week | [x] | `planner_load_chart.dart`, `planner_week_detail.dart`; verdict/load/active-supplements in `planner_screen_test.dart`. | ✓ DELIVERED |
| PLAN-03 | 12-month Year matrix with coverage bars; tap a month | [x] | `planner_year_grid.dart`, `planner_month_detail.dart`. | ✓ DELIVERED |
| PLAN-04 | Educational disclaimer on every planner screen; 5-substance limit framed as editorial | [x] | `planner_screen.dart:626` — disclaimer under EVERY state; `planner_screen_test.dart:863` asserts it is unconditional and closes the error surface too; `test/l10n/planner_copy_safety_test.dart` gates the copy. | ✓ DELIVERED |
| L10N-01 | uk + en with correct plural forms (all CLDR incl. 11-14) | [ ] | This phase. See Requirements Coverage. | ✓ DELIVERED (visual half → P2) |
| L10N-02 | System language when supported, English fallback | [ ] | This phase. | ✓ DELIVERED |
| L10N-03 | Override in Settings, instant, persists across restarts | [ ] | This phase. | ✓ DELIVERED (real cold start → P3) |
| L10N-04 | Locale-formatted dates/months/numbers; zero hardcoded strings; new language = one ARB file | [ ] | This phase. | ✓ DELIVERED (bounded by W1/W2) |
| DATA-01 | Local-only storage, fully offline, no accounts | [x] | No HTTP/network package in `pubspec.yaml`; no auth or account code path anywhere in `lib/`; Drift + SQLite only. | ✓ DELIVERED |
| DATA-02 | Sync-ready schema (UUID PKs, createdAt/updatedAt, soft deletes) + included in OS backups by default | [x] | `core/db/database.dart` — `TextColumn get id` (UUID), `createdAt`, `updatedAt`, nullable `deletedAt` on every table. Backup: **no `android:allowBackup="false"` opt-out anywhere in `AndroidManifest.xml`** (Android default is `true`), and no iOS `isExcludedFromBackup` exclusion — inclusion is by default, exactly as worded. `test/db/database_test.dart`, `repositories_test.dart`. | ✓ DELIVERED |
| DATA-03 | Builds and runs the full loop on both iOS and Android (targetSdk 36) | [x] | `integration_test/data03_loop_test.dart`. **Re-run after this phase's merge and PASSED on both platforms** — iPhone 17 simulator (iOS 26.5) and Android `emulator-5554` (API 36). | ✓ DELIVERED |

**Sweep result: 23/23 v1 requirements are genuinely delivered by shipped code. Zero requirements are checked off in REQUIREMENTS.md without a corresponding implementation.** The 19 pre-Phase-5 checkboxes each map to substantive, wired source plus dedicated tests. The four L10N boxes are still unchecked and should be checked at sign-off, after P2 and P3 return evidence.

Milestone housekeeping to complete at sign-off (documentation only, no code impact):
- Check L10N-01..04 in `.planning/REQUIREMENTS.md` and flip their Traceability rows from `Pending` to `Complete`.
- Mark Phase 5 complete in `.planning/ROADMAP.md` (currently `0/5 · Planned` while all five plans have merged) and tick its five plan checkboxes.
- Clear the three resolved todos from `.planning/STATE.md` (W3).

## Human Verification Required

### 1. P2 / Backstop 14 — whole-app bilingual walkthrough on PHYSICAL devices

**Test:** On a physical iOS device and a physical Android device, walk Українська → English → System default at the **device's own text-size setting**, reading every screen built in Phases 2-4: app shell, Stack, add-supplement sheet (both tabs), regimen editor, Calendar day + week strip + dose action sheet, Цикли gantt + load chart + week detail, Рік matrix + month detail, and Settings.
**Expected:** Every screen follows the switch; no clipped or overlapping text at the device's own text size; the locked mixed-family Cyrillic rendering is acceptable at ship quality on both platforms.
**Why human:** Ship-quality visual judgment of a mixed-family rendering. `takeException() == null` proves no layout exception, not that a line reads well. Declared `verification: backstop`.
**Evidence required:** Result per platform, naming the screens walked and any defect found, with device model and OS version.
**Say-so-it-is-not-filed-as-a-bug (E-12):** supplement names already in the stack do NOT re-localize — copy-on-add is intended and asserted by test.
**Also expected and locked (LOCKED-FONT):** Ukrainian looks different on iOS (SF fallback) than Android (Roboto fallback), and Cyrillic letters sit on a slightly different baseline than the digits beside them. This is the rendering the approved mockup itself had.
**Also unchanged from Phase 4 and accepted:** gantt labels truncate for the two longest Ukrainian names; week columns are 14px wide horizontally (full 53px height is tappable).

### 2. P3 / Backstop 15 — the feel of the switch, and the cold start, on a PHYSICAL device

**Test:** (a) With the language picker open, tap a row. (b) Force-quit the app, then cold-start it.
**Expected:** (a) No perceptible lag and no flash. (b) The stored language is on the FIRST painted frame, with no system-language frame before it.
**Why human:** The ONLY evidence covering the async `main()` bootstrap this phase introduced. `integration_test/data03_loop_test.dart` pumps `BoostqueApp` directly and never calls `main()`; the widget-level restart test rebuilds the tree over the same store and cannot reach the real process bootstrap. If skipped, threat T-05-10 (severity high) has no mitigating evidence at all.
**Evidence required:** Both observations, per platform, with device model and OS version.

### 3. Visual half of ROADMAP SC1 — Ukrainian plural copy in context

**Test:** While walking P2, read the Ukrainian plural-bearing copy in context (substances, weeks, cycles, periods, slots, months, doses) at counts that hit each form.
**Expected:** The declensions read naturally in the surrounding sentence, not merely correctly per the CLDR table.
**Why human:** Editorial judgment. `plurals_test.dart` proves the correct form is selected and rendered at 1/2/5/11/21 for all 10 keys; only a reader can judge whether the sentence reads well. Fold into P2 rather than running separately.

**Already closed — P1 / DATA-03 (recorded as evidence, not as an open item):** the on-device regression `flutter test integration_test/data03_loop_test.dart` was re-run by the orchestrator after this phase's merge and **PASSED on both platforms** — iPhone 17 simulator (iOS 26.5) and Android `emulator-5554` (API 36). The final v1 loop gate is green.

## Gaps Summary

**No gaps.** No truth failed, no artifact is missing or a stub, no key link is unwired, and no blocker anti-pattern exists. `flutter analyze` reports 0 issues and all 676 tests pass under the phase's own gate command, all independently re-run by this verifier.

The phase goal — *the whole app is genuinely bilingual by default and instantly switchable by the user* — is achieved in the codebase to the limit of what automation can prove:

- **Bilingual by default** is real and gated, not asserted. Six previously English-uncovered surfaces now render in both languages at two text scales with a rendered Cyrillic-leak sweep behind a one-entry named allowlist. The matrix earned its keep by finding two genuine `RenderFlex` overflows (up to 126px) in the regimen editor that would have been clipped labels in release.
- **Instantly switchable** is proven at the frame level: one `tester.pump()` re-localizes the Settings body, the nav bar outside it, a pushed route, an open bottom sheet, and an open dose action sheet. The single wire (`MaterialApp.locale ← ref.watch(localeControllerProvider)`) is confirmed in source.
- **Criterion 4** is met on derivation-plus-synthetic-negative evidence, which I judge to be stronger than the subprocess build the plan deliberately declined — my reasoning is recorded in full above, along with the two honest boundaries (W1, W2) I surfaced independently of any SUMMARY.
- **The three carried todos are genuinely closed**, two of them held in place by source-read tests whose `reason:` strings name the re-work cost of reversal. LOCKED-FONT is confirmed by an empty phase-wide diff over `pubspec.yaml`, `lib/core/theme/` and `assets/fonts/`.
- **Execution honesty is high.** 05-02 found and fixed a defect (`stackEntriesProvider` swallowing the error at the derived merge) that the phase research had missed entirely and that would have made the A1 fix cosmetic. 05-05 explicitly refused to simulate the device work and recorded it as PENDING with per-item evidence requirements. 05-03 recorded its proof shape as a limitation rather than as a claim. Those are the marks of a phase whose SUMMARYs can be checked against reality — and they were.

Status is `human_needed`, not `passed`, for exactly the reason the phase itself named: the two `verification: backstop` truths require physical devices, and one of them (P3's cold start) is the sole evidence for the async `main()` bootstrap this phase introduced. Those are the last two items standing between this codebase and v1 sign-off.

---

_Verified: 2026-08-16T04:16:03Z_
_Verifier: Claude (gsd-verifier)_
