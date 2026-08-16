# Phase 5: Localization & Settings - Research

**Researched:** 2026-08-16
**Domain:** Flutter i18n completion + a Settings screen with no mockup — auditing 164 existing ARB keys for parity and uk CLDR plural coverage, closing the three concrete code-level violations of "a new language = one new ARB file, no code changes", building the language picker (native names, System default), making the override instant and flash-free across restarts, and clearing the three Phase-2/3/4 todos that were deferred to this phase
**Confidence:** HIGH for the audit results and the criterion-4 gap list (every claim is a file+line read this session with the value quoted verbatim, including four reads inside the installed Flutter SDK and riverpod 3.4.2 sources); HIGH for the Riverpod auto-retry root cause (traced to the exact `triggerRetry` return in `riverpod-3.4.2/lib/src/core/element.dart`); MEDIUM for the Settings screen's visual design (the mockup has no Settings screen at all — its third tab is `Радник`, so the screen must be composed from existing tokens and needs a UI-SPEC); the font decision is deliberately left as a user call with both options costed

<user_constraints>
## User Constraints (no CONTEXT.md exists — sources: approved design spec `docs/superpowers/specs/2026-08-14-boostque-v1-design.md`, `.claude/CLAUDE.md`, REQUIREMENTS.md, ROADMAP.md Phase 5, `.planning/STATE.md` Pending Todos, and the Phase-1..4 locked decisions)

### Locked Decisions
- **gen-l10n with ARB files, zero hardcoded user-visible strings.** "Flutter's official **gen-l10n** with ARB files: `app_uk.arb`, `app_en.arb`. Zero hardcoded user-visible strings anywhere — enforced from the first commit. A new language = one new `.arb` file, no code changes." [VERIFIED: docs/superpowers/specs/2026-08-14-boostque-v1-design.md:83-85]
- **ICU plurals with the full Ukrainian form set.** CLAUDE.md Constraints: "ICU plurals (Ukrainian one/few/many)"; ROADMAP Phase 5 criterion 1 requires "all four CLDR plural forms (one/few/many/other, including the 11-14 exception)" [VERIFIED: .planning/ROADMAP.md:131]
- **Locale resolution:** "follow system language when supported; otherwise fall back to English. A settings-screen language picker stores a manual override locally and switches the app instantly." [VERIFIED: docs/superpowers/specs/2026-08-14-boostque-v1-design.md:88-90]
- **All dates/months/numbers through `intl` with the active locale — never hand-built strings.** [VERIFIED: docs/superpowers/specs/2026-08-14-boostque-v1-design.md:91-92]
- **Layout rules:** "no fixed-width text containers (translations change length); direction-neutral padding (`EdgeInsetsDirectional`) so a future RTL language works without rework." [VERIFIED: docs/superpowers/specs/2026-08-14-boostque-v1-design.md:93-95]
- **`shared_preferences` has exactly one job in this app** — the manual language override. "Exactly one use in this app: persisting the manual language-override choice from the settings screen (`features/settings`). Do not use it for anything that belongs in Drift" [VERIFIED: .claude/CLAUDE.md, Supporting Libraries]
- **`intl` stays unpinned** — "never hand-set an `intl` version constraint; always let SDK resolution pick it" [VERIFIED: .claude/CLAUDE.md, Version Compatibility]; `pubspec.yaml:47` reads `intl: any` with the comment "version is deliberately unpinned so flutter_localizations (SDK) owns resolution — never hand-pin (locked decision)" [VERIFIED: pubspec.yaml:45-47]
- **Fonts are bundled via the plain `fonts:` declaration; `google_fonts` is never-use** — "this is a fully offline, no-network app — `google_fonts`'s default behavior is to fetch font files over HTTP at first use" [VERIFIED: .claude/CLAUDE.md, What NOT to Use]
- **`settings/` is the language picker and nothing more in v1** — "settings/     # language picker (grows later: profile, export, etc.)" [VERIFIED: docs/superpowers/specs/2026-08-14-boostque-v1-design.md:56]
- **Three-tab shell (Stack / Calendar / Settings)** [VERIFIED: .planning/ROADMAP.md:31]; the mockup's third tab is `Радник`, which is out of scope [VERIFIED: claude_design_mockup/Boostque v0.1.dc.html:176]
- **Token-only styling, no ad-hoc hex literals anywhere** [VERIFIED: lib/core/theme/tokens.dart:5-7]
- **Riverpod dispose policy (D-23)** recorded once in `lib/core/providers.dart:5-11`; `localeControllerProvider` is deliberately NOT autoDispose — "App-lifetime state — intentionally NOT autoDispose" [VERIFIED: lib/core/l10n/locale_controller.dart:49-52]
- **Zero new packages.** The stack is closed; this phase needs none.

### Claude's Discretion
- The Settings screen's visual composition (the mockup has no Settings screen — see P-6 and Open Question 1)
- Whether the language picker is a plain checked list, a radio group, or a bottom sheet
- Where the "System default" entry sits in the list (first vs. last) and how it is labelled
- File decomposition inside `features/settings/`
- Whether the flash-free bootstrap (P-4) ships in v1 or is deferred (the trade-off is costed in P-4)
- The exact shape of the two new source-globbing gate tests (V-2, V-3)

### Deferred Ideas (OUT OF SCOPE)
- Any Settings content beyond the language picker — profile, export/import (EXPT-01 is v1.x), notifications (NOTF-01 is v2), theme switching, units [VERIFIED: docs/superpowers/specs/2026-08-14-boostque-v1-design.md:56; .planning/REQUIREMENTS.md:57-70]
- Actually shipping a third language. Criterion 4 is a **structural** claim ("adding a new language *requires* only one new ARB file"), proven by a test, not by shipping `app_pl.arb`
- RTL layout work beyond the direction-neutral padding already in place — no RTL language ships in v1 (see E-9)
- Widening the gantt label column or the load-chart week columns — both were measured and **accepted for v1** at Phase-4 UAT (see the third carried todo, resolved in P-9)
- Renaming supplements already in the user's stack when the language changes. Catalog copy-on-add is settled: "switching the app language later must NOT rename supplements already in the stack (Phase 5: this is intended behavior, not a bug)" [VERIFIED: lib/features/stack/catalog.dart:12-15]
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| L10N-01 | App ships in Ukrainian and English with correct plural forms (uk uses all CLDR forms one/few/many/other, incl. the 11–14 exception) | A-1 (ARB audit: 164/164 parity, 10/10 plural keys carry all four uk forms — already satisfied), P-8 (the bilingual render matrix that proves it screen-by-screen), V-1, E-1, E-2 |
| L10N-02 | App follows the system language when supported, falling back to English | P-3 (resolution chain traced through `basicLocaleListResolution`), **PF-1** (the alphabetical-ordering trap that silently moves the fallback), E-3, E-4 |
| L10N-03 | User can override the language in Settings; the change applies instantly and persists across restarts | P-4 (persistence + flash-free bootstrap), P-5 (instant propagation, verified against `IndexedStack` + pushed routes + open sheets), P-6/P-7 (the picker), PF-3, PF-4, E-5, E-6, E-7 |
| L10N-04 | All dates, month names and numbers are locale-formatted; zero hardcoded user-visible strings (new languages = one ARB file) | A-2 (grep audit: zero hardcoded strings found), **P-1** (the three concrete code changes criterion 4 needs), **P-2** (the self-referential `languageName` key — the only picker design that keeps criterion 4 true), V-2/V-3 (the two gates), PF-2, PF-5, PF-6, E-8 |
</phase_requirements>

## Project Constraints (from CLAUDE.md)

Actionable directives the planner must honor in every task of this phase:

1. **Zero new packages.** No `flutter_localized_locales`, no `easy_localization`, no `intl_utils`, no `google_fonts`. The one legitimate bundle change this phase may propose is a **font asset**, which is not a package — it is still a user decision (see P-10).
2. **`intl` stays unpinned.** Never add a version constraint; re-run `flutter pub get` after any SDK bump.
3. **Locale-aware formatting via `intl` for every date, month name and number.** No hand-built strings, no hardcoded month tables.
4. **`dart analyze` warnings are build-breaking for `core/domain`.** This phase adds nothing to `core/domain`; hold the same bar for `core/l10n`.
5. **Hand-written Riverpod providers, not `@riverpod` codegen** — the codebase is uniformly hand-written (`lib/core/providers.dart`, `lib/core/l10n/locale_controller.dart`). Stay consistent.
6. **Bundled fonts via the plain `fonts:` declaration**; `BqText.mono()` is the only mono accessor [VERIFIED: lib/core/theme/theme.dart:128-146].
7. **Token-only styling.** The Settings screen must be built from `BqColors`/`BqRadii`/`BqSpace`/`BqText` — no new hex literals. No new tokens are needed (see P-6).
8. **`shared_preferences` for the language override only.** Nothing else may be added to it in this phase.

## Summary

The headline finding is that **L10N-01 and the "zero hardcoded strings" half of L10N-04 are already substantially satisfied, and the real work of this phase is elsewhere.** The ARB audit is clean: `app_en.arb` and `app_uk.arb` each carry exactly 164 message keys with **zero** keys present in one file and missing from the other; all 10 plural-bearing keys (`substancesCount`, `weeksCount`, `stackSummary`, `slotsPerDay`, `ringSemantics`, `monthsCount`, `cyclesCount`, `periodsCount`, `slotsCount`, `substancesLimitCount`) declare `one`/`few`/`many`/`other` in uk and `one`/`other` in en [VERIFIED by parsing both ARB files this session — see A-1]. A repository-wide grep for literal strings in widget positions (`Text('…')`, `label:`/`tooltip:`/`hintText:`/`labelText:`/`semanticsLabel:` with a literal) returns **one hit**, and it is a composition of two localized values, not a hardcoded string: `label: '${l10n.addSupplement}: ${entry.name(l10n)}'` [VERIFIED: lib/features/stack/add_supplement_sheet.dart:356]. Every date, month name and weekday already flows through `intl.DateFormat` with `Localizations.localeOf(context).toString()` at 17 call sites across 9 files, and the direction-neutrality claim holds under grep: there is not a single `EdgeInsets.only(left:/right:)`, `EdgeInsets.fromLTRB`, `Alignment.centerLeft`-family, `Positioned(left:/right:)` or `BorderRadius.only` anywhere in `lib/` (the one `BorderRadiusDirectional.only` at `planner_load_chart.dart:327` is the directional variant).

**What is actually broken is criterion 4, and it breaks in three specific, small places.** First, `LocaleController` hardcodes the shipped language set: `static const supportedLanguageCodes = {'en', 'uk'};` [VERIFIED: lib/core/l10n/locale_controller.dart:17] — drop in `app_pl.arb` and the picker can persist `pl` but the controller will sanitize it back to "follow system" on the next launch. Second, and more insidious, is **PF-1**: gen-l10n emits `supportedLocales` in *alphabetical* order, `MaterialApp`'s resolver falls back to `supportedLocales.first` when nothing matches [VERIFIED: `final Locale resolvedLocale = matchesLanguageCode ?? matchesCountryCode ?? supportedLocales.first;` — flutter/lib/src/widgets/app.dart:237], and English is currently the fallback only by the accident of `en` < `uk`. Adding `app_de.arb` would silently move the app's English fallback to German with no code change and no test failure — the exact failure mode criterion 4 is supposed to prevent. The fix is one line of `l10n.yaml` (`preferred-supported-locales: [en]`), a verified gen-l10n option [VERIFIED: flutter_tools/lib/src/commands/generate_localizations.dart:79-89]. Third, the language picker does not exist yet, and the obvious way to build it — an ARB key per language, `languageNameUk`/`languageNamePl`, plus a code map — violates criterion 4 on the first new language. The design that does not is a **self-referential key**: each ARB declares its own native name under the same key `languageName`, resolved through the generated `lookupAppLocalizations(locale)` (synchronous, already used in-repo at `lib/features/stack/catalog.dart:158`), so a new ARB brings its own display name with it (P-2).

The three carried todos resolve cleanly. The **Riverpod-3 auto-retry defect** is fully root-caused: `triggerRetry` returns `AsyncLoading<ValueT>._(…, error: (err: error, stack: stackTrace, retrying: true))` while a retry is pending [VERIFIED: riverpod-3.4.2/lib/src/core/element.dart:791-795], which makes `isReloading` true, and `AsyncValue.when`'s `skipLoadingOnReload` defaults to `false` [VERIFIED: riverpod-3.4.2/lib/src/core/async_value.dart:243], so the `loading:` branch wins over `error:`. With `defaultRetry`'s 10 retries at 200 ms doubling to a 6400 ms cap, the designed error surface appears **~38.2 seconds** after the failure. The fix is not to disable retry — it is to make "has an error" beat "is loading" at the three surfaces (P-9). The **Instrument Sans Cyrillic gap** is confirmed at the source: the upstream Google Fonts metadata declares `subsets: "latin", "latin-ext", "menu"` only [VERIFIED: google/fonts ofl/instrumentsans/METADATA.pb], so there is no font-file update that fixes it, and my own cmap parse of the bundled TTF confirms `Ц ц ї і І Ї є ґ` are all absent while JetBrains Mono carries every one of them. That is a genuine user decision with two defensible answers, both costed in P-10. The **gantt/tap-target measurements** need no action here (P-11).

**Primary recommendation:** Treat this phase as *four small structural fixes plus one new screen plus two gates*, not as a translation phase. Land the criterion-4 fixes first (`preferred-supported-locales`, controller derives its language set from `AppLocalizations.supportedLocales`, self-referential `languageName`), because they are what the phase's hardest success criterion is actually about; then build the Settings screen; then add the two source-globbing gate tests (no-hardcoded-string, ARB-parity + `languageName`-present) modelled directly on the existing `planner_copy_safety_test.dart` / `planner_invariants_test.dart` precedents; then extend the both-locale render matrix to the Phase-2/3 screens, which currently have **zero** English render coverage (`stack_screen_test.dart` en=0, `regimen_editor_test.dart` en=0, `app_shell_test.dart` en=0, `calendar_screen_test.dart` en=1 of 61).

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| The set of shipped languages | **ARB files** (`lib/core/l10n/arb/*.arb`) → generated `AppLocalizations.supportedLocales` | — | Generated from the files on disk; this is the single source that makes "one new ARB file" true. Nothing else may enumerate languages (P-1) |
| Fallback-language choice | `l10n.yaml` (`preferred-supported-locales`) | — | The fallback is `supportedLocales.first`; ordering must be declared, never inherited from alphabetization (PF-1) |
| System-language matching | Flutter framework (`basicLocaleListResolution` inside `WidgetsApp`) | — | Already correct and already handles the full system locale *list*; do not write a `localeResolutionCallback` (Don't Hand-Roll) |
| Manual override state | `LocaleController` (`Notifier<Locale?>`, app-lifetime) | — | Already exists and is already wired into `MaterialApp.locale`; needs three edits, not a rewrite |
| Override persistence | `shared_preferences` key `app_locale` | — | Locked; one key, one job |
| Native language names | **each ARB's own `languageName` key**, read via `lookupAppLocalizations(locale)` | — | The only design where a new ARB needs no code change (P-2) |
| "System default" label | ARB key in the *active* locale | — | It is UI chrome, not a language name |
| Locale-formatted dates/months/numbers | `intl.DateFormat` at the widget layer, keyed off `Localizations.localeOf(context)` | — | 17 existing call sites already do this; date symbols for every language arrive automatically (P-3) |
| Instant propagation of a locale change | `MaterialApp.locale` ← `ref.watch(localeControllerProvider)` | `IndexedStack` keeps all three tabs mounted | Already wired [VERIFIED: lib/main.dart:27]; the work is proving it, not building it (P-5) |
| Settings screen UI | `features/settings/` widgets built from existing tokens | — | No mockup exists; needs a UI-SPEC (Open Question 1) |
| Async error surfacing | the three screen surfaces (`stack_screen`, `calendar_screen`, `planner_screen`) | — | The retry defect is a rendering-rule bug at the surfaces, not a provider-configuration bug (P-9) |
| Cyrillic glyph coverage | `pubspec.yaml` `fonts:` + `assets/fonts/` | `ThemeData.fontFamily` | A bundle decision, not a code decision — and a user call (P-10) |

## Standard Stack (delta)

### New packages required: NONE

| Need | Already available | Evidence |
|------|-------------------|----------|
| ARB → Dart codegen, on every `flutter pub get` | gen-l10n via `l10n.yaml` + `flutter: generate: true` | [VERIFIED: l10n.yaml (full contents quoted in P-1); pubspec.yaml:75-77 `generate: true` with the comment "without it gen-l10n never runs on `flutter pub get`"] |
| Generated locale list | `AppLocalizations.supportedLocales` | [VERIFIED: lib/core/l10n/gen/app_localizations.dart:93-96] `static const List<Locale> supportedLocales = <Locale>[ Locale('en'), Locale('uk'), ];` |
| Synchronous per-locale message lookup (for native names) | `lookupAppLocalizations(Locale)` | [VERIFIED: lib/core/l10n/gen/app_localizations.dart:1108-1123] — a generated `switch (locale.languageCode)` that grows with each ARB; already used at lib/features/stack/catalog.dart:158 |
| Delegate list incl. Material/Cupertino/Widgets globals | `AppLocalizations.localizationsDelegates` | [VERIFIED: lib/core/l10n/gen/app_localizations.dart:86-92] |
| Date symbols for *every* supported language | `flutter_localizations` loads them all at once | [VERIFIED: flutter_localizations/lib/src/utils/date_localizations.dart:17-30, called from material_localizations.dart:735 — see P-3] |
| Override persistence | `shared_preferences` 2.5.5, legacy sync-after-init API (not deprecated in 2.5.5) | [VERIFIED: pubspec.lock resolves `shared_preferences 2.5.5`; no `@Deprecated` on `SharedPreferences` in that version] |
| Sentence-casing a locale-formatted weekday | `intl`'s `toBeginningOfSentenceCase` | [VERIFIED: intl-0.20.3/lib/intl.dart:607] `T toBeginningOfSentenceCase<T extends String?>(T input, [String? locale])` |
| Both-locale × text-scale widget matrix harness | the Phase-4 idiom | [VERIFIED: test/features/planner_screen_test.dart:2585] `for (final locale in const ['uk', 'en']) {` |
| Source-globbing gate-test precedent | `planner_invariants_test.dart` | [VERIFIED: test/features/planner_invariants_test.dart:83-85] `final dir = Directory('lib/features/calendar');` … `.listSync()` |
| ARB-read-off-disk gate precedent | `planner_copy_safety_test.dart` | [VERIFIED: test/l10n/planner_copy_safety_test.dart:14-20, 75-85] |

**Explicitly rejected for this phase (restated because a localization phase is exactly where they get reached for):** `easy_localization`, `slang`, `intl_utils`, `flutter_localized_locales`, `google_fonts`, `flutter_i18n`. The project's locked choice is Flutter's first-party gen-l10n, and it is already installed and working. No task in this phase may add a dependency.

### Bundle delta (NOT a package — but flag it loudly)

| Change | Size delta | Status |
|---|---|---|
| Replace `assets/fonts/InstrumentSans[wdth,wght].ttf` (194,336 B on disk) with `Manrope[wght].ttf` (165,420 B) | **−28,916 B** | **USER DECISION — see P-10** |
| …or with `Inter[opsz,wght].ttf` (876,576 B) | **+682,240 B** | alternative |
| …or ship nothing and keep platform fallback for Cyrillic | 0 B | the mockup-faithful option |
| No change | — | JetBrains Mono already covers full Ukrainian Cyrillic — verified, no action |

## Package Legitimacy Audit

Not applicable — this phase installs no external packages. No registry lookups were required and no package name in this document originates from a search engine or from training memory; every "already available" entry above was read out of `pubspec.lock`, the local pub cache, or the installed Flutter SDK this session. The only externally-sourced artifacts considered are **font files from the `google/fonts` OFL repository**, and their subsets and byte sizes were read from that repository directly (`METADATA.pb` + HTTP `Content-Length`), not inferred.

**Packages removed due to [SLOP] verdict:** none
**Packages flagged as suspicious [SUS]:** none

---

## Audit Results (the reality check the phase brief asked for)

### A-1: ARB parity and plural coverage — CLEAN

Both files parsed this session with `json.load`:

| Measure | `app_en.arb` | `app_uk.arb` |
|---|---|---|
| Message keys (non-`@`) | **164** | **164** |
| Keys in en missing from uk | — | **0** |
| Keys in uk missing from en | **0** | — |
| `@`-metadata blocks | 164 (every key documented) | 0 (correct — metadata lives in the template only) |
| Plural-bearing keys | 10 | 10 |
| uk keys carrying all of `one`/`few`/`many`/`other` | — | **10 of 10** |
| `DateTime`-typed ARB placeholders | **0** | 0 |

The ten plural keys and their uk forms: `substancesCount`, `weeksCount`, `stackSummary`, `slotsPerDay`, `ringSemantics`, `monthsCount`, `cyclesCount`, `periodsCount`, `slotsCount`, `substancesLimitCount` — each `[few, many, one, other]` in uk and `[one, other]` in en.

**Count-bearing keys that deliberately carry no plural** (all eight verified as correct by reading the uk text — each is either a bare numeral pair or a "N of M" construction where the noun is supplied by a separate, properly-declined plural key):

| Key | en | uk | Verdict |
|---|---|---|---|
| `slotIntervalNote` | `Smallest interval — {h} h {m} min.` | `Найменший інтервал — {h} год {m} хв.` | OK — `год`/`хв` are invariant abbreviations |
| `blockProgress` | `{done} of {total}` | `{done} з {total}` | OK — bare numerals, documented as such in the ARB metadata |
| `doseCycleChip` | `dose {n} of {m}` | `доза {n} з {m}` | OK — `доза` agrees with the leading singular, not with `{n}` |
| `limitBadge` | `limit {max}` | `межа {max}` | OK |
| `loadAxisLegend` | `limit {max} · comfort {comfort}` | `межа {max} · комфорт {comfort}` | OK |
| `weekLoadLabel` | `{load} of {max}` | `{load} з {max}` | OK — `max` is a **pre-formatted `slotsCount` string**, declined by its own plural key |
| `weekFreeSlots` | `{n} free — you can plan a start` | `Вільно {n} — можна планувати старт` | OK — the uk phrasing puts the invariant adverb first, deliberately avoiding agreement |
| `monthMeta` | `{count} · limit {max}` | `{count} · межа {max}` | OK — `count` is a **pre-formatted `substancesCount` string** |

**Conclusion: L10N-01 needs no new translation work.** What it needs is *proof at the screen level* (P-8) plus the two new keys the Settings screen introduces.

### A-2: Hardcoded user-visible strings — NONE FOUND

Four independent greps across `lib/` excluding `lib/core/l10n/gen/`:

1. `Text(` followed by a string literal — **0 hits**.
2. `semanticsLabel|tooltip|hintText|labelText|helperText|errorText|label|title|message` followed by `: '…'` — **1 hit**, `lib/features/stack/add_supplement_sheet.dart:356`: `label: '${l10n.addSupplement}: ${entry.name(l10n)}',` — a composition of two localized values. Not a violation; it is however a **concatenation**, which is a mild i18n smell (word order is not translator-controllable). Low priority; noted in PF-6.
3. All string literals ≥3 chars in `lib/` — every remaining hit is one of: a `ValueKey`/test key (`'month-card-$index'`), an assertion message, a font family name (`'Instrument Sans'`, `'JetBrains Mono'`), a hex/token comment, a `DateFormat` pattern (`'LLLL'`, `'EEEE, d MMMM'`), a `dart:`/package import, a Drift column name, or the `'app_locale'` prefs key. **Zero user-visible literals.**
4. Direction-neutrality: `EdgeInsets.only(left:|right:)` — 0; `EdgeInsets.fromLTRB` — 0; `Alignment.(center|top|bottom)(Left|Right)` — 0; `Positioned(left:|right:)` — 0; `TextAlign.left|right` — 0; `BorderRadius.only` — 0 (only `BorderRadiusDirectional.only` at `planner_load_chart.dart:327`). **The spec's direction-neutral-padding claim holds under grep.**

**Conclusion: the "zero hardcoded strings" half of L10N-04 currently holds.** It has no mechanical gate protecting it, which is the gap (V-2).

### A-3: Bilingual render coverage — the real gap

| Test file | `testWidgets` count | Renders in uk | Renders in en |
|---|---|---|---|
| `test/features/stack_screen_test.dart` | 11 | yes | **0** |
| `test/features/regimen_editor_test.dart` | 10 | yes | **0** |
| `test/widget/app_shell_test.dart` | 4 | yes | **0** |
| `test/features/calendar_screen_test.dart` | 61 | yes | **1** |
| `test/features/planner_screen_test.dart` | 60 | yes | parameterized `['uk','en']` matrix ✓ |

Only Phase 4 built a locale matrix. Criterion 1 says "**every** screen displays correctly in Ukrainian … and in English" — five screens/sheets have never been rendered in English by any test: Stack, the add-supplement sheet, the regimen editor, the dose action sheet, and the app shell.

---

## Architecture Patterns

### System flow (this phase)

```
                     ┌──────────────────────────────────────────┐
   device system     │  lib/core/l10n/arb/*.arb   (N files)     │
   locale LIST       │  each declares its own `languageName`    │
        │            └──────────────────┬───────────────────────┘
        │                  flutter pub get │ (generate: true)
        │                                  ▼
        │            ┌──────────────────────────────────────────┐
        │            │ gen/app_localizations.dart               │
        │            │  • supportedLocales  (ORDER = fallback!) │
        │            │  • lookupAppLocalizations(Locale)        │
        │            └──────────────────┬───────────────────────┘
        │                               │
        ▼                               ▼
┌───────────────────┐        ┌──────────────────────────┐
│ basicLocaleList   │◀───────│  MaterialApp             │
│ Resolution        │        │   locale: ref.watch(     │──┐
│ (framework)       │        │     localeControllerProv)│  │
└─────────┬─────────┘        └──────────────────────────┘  │
          │ no match → supportedLocales.first              │
          ▼                                                │
   ┌──────────────┐                                        │
   │ Localizations│  rebuilds EVERYTHING below it:         │
   │   (widget)   │  IndexedStack tabs, pushed routes,     │
   └──────┬───────┘  open modal sheets, dialogs            │
          │                                                │
   ┌──────┴──────────────────────────────┐                 │
   │ Stack │ Calendar │ Settings ────────┼─── picker taps ─┘
   └───────┴──────────┴──────────────────┘   setLocale(Locale?|null)
                                                    │
                                            ┌───────▼────────┐
                                            │ shared_prefs   │
                                            │ 'app_locale'   │
                                            └────────────────┘
```

---

### P-1: Make criterion 4 literally true — the three edits

Criterion 4 is *"adding a new language requires only one new ARB file with no code changes."* Three things in the tree today make that false. Each fix is small; each must land.

**Edit 1 — declare the fallback explicitly (this is the dangerous one).** Current `l10n.yaml`, verbatim:

```yaml
arb-dir: lib/core/l10n/arb
template-arb-file: app_en.arb
output-dir: lib/core/l10n/gen
output-localization-file: app_localizations.dart
output-class: AppLocalizations
synthetic-package: false
nullable-getter: false
```

There is no `preferred-supported-locales`, so gen-l10n emits the locale list "in alphabetical order" [VERIFIED: flutter_tools/lib/src/commands/generate_localizations.dart:79-89, help text: *"By default, the tool will generate the supported locales list in alphabetical order. Use this flag if you would like to default to a different locale."*]. Today that produces `Locale('en'), Locale('uk')` — English first, so English is the fallback, by luck. The framework's resolver ends with:

```dart
// When there is no languageCode-only match. Fallback to matching countryCode only. Country
// fallback only applies on iOS. When there is no countryCode-only match, we return first
// supported locale.
final Locale resolvedLocale = matchesLanguageCode ?? matchesCountryCode ?? supportedLocales.first;
```
[VERIFIED: /opt/homebrew/share/flutter/packages/flutter/lib/src/widgets/app.dart:234-237]

Add to `l10n.yaml`:
```yaml
preferred-supported-locales:
  - en
untranslated-messages-file: l10n-untranslated.json
```

`untranslated-messages-file` is the second half of the same protection: gen-l10n **does not fail** on a key missing from a non-template ARB — it falls back to the template's English message and only warns. Writing the warning to a file makes it assertable (V-3) [VERIFIED: flutter_tools/lib/src/commands/generate_localizations.dart:61-70].

**Edit 2 — the controller must stop enumerating languages.** Today, verbatim:

```dart
  static const _prefsKey = 'app_locale';

  /// Language codes the app ships translations for.
  static const supportedLanguageCodes = {'en', 'uk'};
```
[VERIFIED: lib/core/l10n/locale_controller.dart:14-17]

Replace the constant with a derivation from the generated list (keeping the T-01-07 sanitization behaviour that `locale_controller_test.dart:53-62` already pins):

```dart
/// Language codes the app ships translations for — DERIVED, never listed.
/// Adding `app_pl.arb` regenerates `AppLocalizations.supportedLocales`, and
/// this set follows with no edit here (L10N-04, criterion 4).
static final Set<String> supportedLanguageCodes = {
  for (final l in AppLocalizations.supportedLocales) l.languageCode,
};
```

**Edit 3 — the picker must not enumerate languages either.** See P-2.

**How to test the claim rather than assert it (V-3).** A test that only checks `supportedLanguageCodes == {'en','uk'}` proves nothing. The gate that proves criterion 4 reads the ARB directory off disk and asserts the *derivations agree with the filesystem*:

```dart
// test/l10n/new_language_contract_test.dart
test('every app_*.arb on disk is a supported locale, carries a languageName, '
     'and en is the fallback — the "one new ARB file" contract', () {
  final arbs = Directory('lib/core/l10n/arb')
      .listSync()
      .whereType<File>()
      .map((f) => RegExp(r'app_([a-z]{2,3})\.arb$').firstMatch(f.path)?.group(1))
      .whereType<String>()
      .toList()
    ..sort();

  expect(arbs, isNotEmpty, reason: 'the glob must actually resolve files');

  // 1. The generated list is the filesystem, not a hand-kept list.
  expect(
    AppLocalizations.supportedLocales.map((l) => l.languageCode).toList()..sort(),
    arbs,
  );

  // 2. The controller derives, it does not enumerate.
  expect(LocaleController.supportedLanguageCodes, arbs.toSet());

  // 3. The English fallback is DECLARED, not alphabetical (PF-1).
  expect(AppLocalizations.supportedLocales.first, const Locale('en'),
      reason: 'MaterialApp falls back to supportedLocales.first; without '
              'preferred-supported-locales in l10n.yaml, adding app_de.arb '
              'would silently make German the fallback');

  // 4. Every ARB brings its own native display name (P-2).
  for (final code in arbs) {
    final name = lookupAppLocalizations(Locale(code)).languageName;
    expect(name, isNotEmpty);
  }

  // 5. Every ARB is one of the languages flutter_localizations covers (E-8).
  for (final code in arbs) {
    expect(kMaterialSupportedLanguages, contains(code),
        reason: 'GlobalMaterialLocalizations.load asserts isSupported(locale); '
                'a language outside that set needs a custom delegate — i.e. a '
                'code change, which criterion 4 forbids');
  }
});
```

A second, stronger variant is worth the twenty extra lines: **synthesize a third locale in the test** by writing `lib/core/l10n/arb/app_pl.arb` to a temp copy of the arb dir and running `flutter gen-l10n` against it — but that shells out and is slow. The assertions above catch every *code-shaped* violation, which is what criterion 4 is about. Recommend the fast version; note the shell-out variant in the plan as optional.

---

### P-2: The language picker — the self-referential `languageName` key

This is the single design decision that decides whether criterion 4 survives.

| Option | Adding `app_pl.arb` requires | Verdict |
|---|---|---|
| **A.** One key per language in every ARB (`languageNameEn`, `languageNameUk`) + a `switch (code)` in the picker | edit **every** existing ARB (add `languageNamePl`) **and** the picker's switch | **Violates criterion 4** |
| **B. Self-referential key: every ARB declares its own name under the key `languageName`** | nothing — the new ARB carries `"languageName": "Polski"` | **✔ Use this** |
| C. `flutter_localized_locales` / a `LocaleNames` lookup package | a new dependency | Forbidden (zero new packages) |
| D. `Locale.toLanguageTag()` / raw code (`uk`, `en`) | nothing | Works, but shows `uk` instead of `Українська` — poor UX |

Option B in full:

```jsonc
// app_en.arb
"languageName": "English",
"@languageName": {
  "description": "This language's OWN name, in this language. Every ARB file declares its own — the picker never enumerates languages, so a new app_xx.arb needs no code change (L10N-04, criterion 4)."
},
"languageSystem": "System default",
"@languageSystem": { "description": "Language-picker entry meaning: follow the device language. Rendered in the ACTIVE locale, not in any particular language." },
"settingsLanguageTitle": "Language",
"@settingsLanguageTitle": { "description": "Settings section heading above the language picker" },

// app_uk.arb
"languageName": "Українська",
"languageSystem": "Системна",
"settingsLanguageTitle": "Мова",
```

Note the asymmetry, and it is deliberate: **`languageName` is read through `lookupAppLocalizations(otherLocale)`, `languageSystem` is read through `context.l10n`.** A language's name is written in that language; "System default" is chrome, written in the language the user is currently reading.

```dart
// features/settings/language_picker.dart — enumerate from the GENERATED list.
final options = <Locale?>[null, ...AppLocalizations.supportedLocales];

String labelFor(BuildContext context, Locale? locale) => locale == null
    ? context.l10n.languageSystem                    // active locale
    : lookupAppLocalizations(locale).languageName;   // that locale's own name
```

`lookupAppLocalizations` is synchronous and generated, and it grows with every ARB:

```dart
AppLocalizations lookupAppLocalizations(Locale locale) {
  switch (locale.languageCode) {
    case 'en': return AppLocalizationsEn();
    case 'uk': return AppLocalizationsUk();
  }
  throw FlutterError(...);
}
```
[VERIFIED: lib/core/l10n/gen/app_localizations.dart:1108-1123]

Calling it with a locale drawn from `AppLocalizations.supportedLocales` can never hit the throw — the two are generated from the same input. The in-repo precedent is `lib/features/stack/catalog.dart:158`: `final AppLocalizations _en = lookupAppLocalizations(const Locale('en'));`

**Do not sort the option list by name.** Keep generated order (which `preferred-supported-locales` now controls), so the list is stable and the fallback language reads first — and so a locale-sensitive `compareTo` never enters the picture.

---

### P-3: System-language resolution and date symbols — already correct, do not touch

**Language matching.** `MaterialApp` with no `localeResolutionCallback`/`localeListResolutionCallback` uses the framework's `basicLocaleListResolution` over `WidgetsBinding.instance.platformDispatcher.locales` — the device's whole *preference list*, not just the first entry. A device set to `[de-DE, uk-UA, en-US]` correctly resolves to `uk`. Writing a custom callback would almost certainly be worse (Don't Hand-Roll). The fallback path is `supportedLocales.first` [VERIFIED: widgets/app.dart:234-237, quoted in P-1], which is why PF-1/Edit-1 matters.

One subtlety in the same three lines, worth a sentence in the UI-SPEC and nothing more: *"Country fallback only applies on iOS"* — on iOS a `matchesCountryCode` can resolve before the `supportedLocales.first` fallback. It cannot select an unsupported language, so it cannot break L10N-02.

**Date symbols for a new language — free.** `GlobalMaterialLocalizations.load` calls `util.loadDateIntlDataIfNotLoaded()` [VERIFIED: flutter_localizations/lib/src/material_localizations.dart:732-735], which is:

```dart
void loadDateIntlDataIfNotLoaded() {
  if (!_dateIntlDataInitialized) {
    date_localizations.dateSymbols.forEach((String locale, intl.DateSymbols symbols) {
      assert(date_localizations.datePatterns.containsKey(locale));
      date_symbol_data_custom.initializeDateFormattingCustom(
        locale: locale,
        symbols: symbols,
        patterns: date_localizations.datePatterns[locale],
      );
    });
    _dateIntlDataInitialized = true;
  }
}
```
[VERIFIED: /opt/homebrew/share/flutter/packages/flutter_localizations/lib/src/utils/date_localizations.dart:17-30]

It initializes symbols for **every** locale in the bundled table (≈140 entries), not just the active one — on the first `GlobalMaterialLocalizations.load` of the app. So the app's 17 `DateFormat(pattern, locale)` call sites keep working for any new ARB language with **zero** code changes. This is the strongest single piece of evidence that criterion 4's "dates and month names" half is already structurally satisfied. (In *tests* the symbols are not loaded unless a widget pumps a `MaterialApp` with the global delegates — which is exactly why `test/l10n/month_names_test.dart:38-41` calls `initializeDateFormatting('uk')` explicitly. Keep that pattern for any new pure-`intl` test.)

**The boundary of the claim (document it, do not fix it):** `GlobalMaterialLocalizations.load` opens with `assert(isSupported(locale))` and `isSupported` is `kMaterialSupportedLanguages.contains(locale.languageCode)` — an 82-language set [VERIFIED: flutter_localizations/lib/src/l10n/generated_material_localizations.dart:46518ff, parsed this session: 82 entries; `pl`, `uk`, `tr`, `ar`, `he` all present]. A new ARB for a language *outside* that set gets no Material widget strings and trips a debug assert. Criterion 4 should therefore be stated precisely in the UI-SPEC: **"one new ARB file, for any of the 82 languages `flutter_localizations` covers."** That is not a defect; it is the honest shape of the guarantee, and V-3 assertion 5 pins it.

---

### P-4: Persistence, first launch, and the override flash

Current behaviour, verbatim:

```dart
  @override
  Locale? build() {
    _load();
    return null; // null = follow system until the async load settles
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_prefsKey);
    if (code != null && supportedLanguageCodes.contains(code)) {
      state = Locale(code);
    }
  }
```
[VERIFIED: lib/core/l10n/locale_controller.dart:19-35]

Two defects, one certain and one a judgement call.

**Certain (fix it): `setLocale` persists before it switches.**

```dart
  Future<void> setLocale(Locale? locale) async {
    final prefs = await SharedPreferences.getInstance();
    if (locale == null) { await prefs.remove(_prefsKey); }
    else { await prefs.setString(_prefsKey, locale.languageCode); }
    state = locale;
  }
```
[VERIFIED: lib/core/l10n/locale_controller.dart:38-46]

The UI does not change until a platform-channel round-trip **and** a disk write complete. Criterion 3 says "applies **instantly**". Set state first, persist after:

```dart
Future<void> setLocale(Locale? locale) async {
  state = locale;                       // criterion 3: instant, synchronous
  final prefs = await SharedPreferences.getInstance();
  if (locale == null) {
    await prefs.remove(_prefsKey);
  } else {
    await prefs.setString(_prefsKey, locale.languageCode);
  }
}
```
This is strictly better: the write is idempotent and the in-memory state is the source of truth for the frame. (If the write throws, the user sees the new language and the *next* launch reverts — acceptable and honest; the alternative is a UI that stalls on disk.)

**Judgement call (recommend fixing, cost it in the plan): the first-launch flash.** `build()` returns `null` and `_load()` fills it in asynchronously. For a user who has set an override, **every cold start renders at least one frame in the system language before flipping** to the stored one. It costs nothing for the majority who never override, and it is a visible flicker for exactly the users who exercised criterion 3.

*Option A (recommended) — seed synchronously in `main()`:*

```dart
// main.dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(ProviderScope(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    child: const BoostqueApp(),
  ));
}

// core/providers.dart (or core/l10n/)
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('overridden in main() and in tests'),
);
```
`LocaleController.build()` then reads `ref.watch(sharedPreferencesProvider).getString(_prefsKey)` **synchronously** and returns the right locale on frame 1. Cost: `main()` becomes async; every test that builds a bare `ProviderScope`/`ProviderContainer` and reaches the locale controller must supply the override. `SharedPreferences.setMockInitialValues` still works — the existing four tests in `locale_controller_test.dart` adapt in a few lines.

*Option B — keep the async load, accept the flash.* Zero risk, zero work; the flash is the cost. If the plan is tight, this is a legitimate v1 answer, but it should be a recorded decision rather than an omission.

**Invalid/removed stored codes.** Already handled and already tested: a stored `'de'` sanitizes to `null` (follow system) [VERIFIED: lib/core/l10n/locale_controller.dart:32 `if (code != null && supportedLanguageCodes.contains(code))`; pinned by test/l10n/locale_controller_test.dart:53-62]. After Edit 2 (P-1) the check follows the ARB set automatically, so *removing* `app_uk.arb` from a future build degrades a stored `uk` to "follow system" rather than crashing — the correct behaviour, worth one added test (E-7).

---

### P-5: Instant propagation — what actually rebuilds

`MaterialApp.locale` is already `ref.watch(localeControllerProvider)` [VERIFIED: lib/main.dart:27]. `MaterialApp` builds a `Localizations` widget **above** its `Navigator`, so a locale change rebuilds:

| Surface | Rebuilds? | Why |
|---|---|---|
| The three tabs | **Yes, all three** | `IndexedStack` keeps every child mounted — "builds and KEEPS every child mounted — only painting is suppressed — so all three screens are alive from app launch on every tab" [VERIFIED: lib/app_shell.dart:38-45]. Switching back to a tab shows it already re-localized |
| Pushed routes (the regimen editor) | Yes | Routes live in the `Navigator` below `Localizations` |
| Open modal bottom sheets (`add_supplement_sheet`, `dose_action_sheet`) | Yes | Their routes are in the same `Navigator`'s overlay |
| `showDatePicker` / `showTimePicker` | Yes | Same, and they read `MaterialLocalizations` for their own chrome |
| `DateFormat` instances built in `build()` | Yes | All 17 call sites construct the formatter inside `build()` from `Localizations.localeOf(context)` — none are cached in fields |
| Anything cached in `initState` | n/a | **Grep confirms no `initState` in `lib/features/` reads `l10n`, `DateFormat`, or `context`** — the classic pitfall is absent today (keep it that way: PF-4) |

**No `key` on `MaterialApp` and no manual `setState` are needed.** The only real risk is a *future* widget caching a formatted string; PF-4 and the V-2 gate cover it.

One propagation nuance to state in the UI-SPEC: the user's own data is never re-localized. Catalog entries copy the current locale's name at add-time by design [VERIFIED: lib/features/stack/catalog.dart:11-15]. Switching to English will not rename "Магній" in an existing stack. This is intended and should be said out loud at UAT so it is not filed as a bug.

---

### P-6: The Settings screen — there is no mockup

**Verified absence, not an oversight in my search.** The mockup is 991 lines. Greping it case-insensitively for `settings|налашт|мова|language|укра|english` returns three hits, all false positives: two CSS `font-feature-settings:'tnum'` declarations (lines 211, 229) and one occurrence of the word `налаштувань` inside a regimen-editor sentence (line 963). The mockup's third nav destination is **`Радник`** (Advisor), not Settings [VERIFIED: claude_design_mockup/Boostque v0.1.dc.html:176, 269, 383, 463] — Settings replaced it in the v1 three-tab decision. So: **no verbatim copy, no verbatim layout exists to extract for this screen.** The planner must produce a `05-UI-SPEC.md` composing the screen from the established design language, and the copy is newly authored (and therefore `[ASSUMED]` until UAT).

What exists today is the Phase-1 stub — a localized heading and nothing else:

```dart
class SettingsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsetsDirectional.only(
            start: BqSpace.lg, end: BqSpace.lg, top: BqSpace.lg),
          child: Text(context.l10n.tabSettings,
              style: Theme.of(context).textTheme.headlineSmall),
        ),
      ),
    );
  }
}
```
[VERIFIED: lib/features/settings/settings_screen.dart:8-29] — the docstring says "nothing else renders until Phase 5".

**No new design tokens are required.** Every ingredient exists: `BqColors.paper` (screen), `BqColors.surface`/`surfaceAlt` (card), `BqColors.cardBorder`, `BqColors.hairline` (row divider), `BqColors.accent` (selected check), `BqColors.ink`/`textSecondary`/`textMuted`, `BqRadii.card` 14 / `panel` 16, `BqSpace.*`, `BqText.mono()` for a mono eyebrow, and the `supplementsLabel`-style mono eyebrow idiom from `stack_screen.dart:109-117`.

**Recommended v1 content (minimal, matching the spec's "language picker" scope):**

1. Screen title — reuse `tabSettings` (`Налаштування` / `Settings`), `headlineSmall`, matching the Stack screen's title treatment.
2. A mono eyebrow `settingsLanguageTitle` (`МОВА` / `LANGUAGE`) in the `supplementsLabel` style.
3. A single card containing one row per option: `System default`, then each supported language by its own native name, with a trailing check on the active one. Rows separated by a `BqColors.hairline` divider, `EdgeInsetsDirectional` padding, minimum 48px row height (a real tap target — the Phase-4 UAT's 14px-wide columns are the cautionary tale).
4. Nothing else. **Optionally** a faint app-version line at the bottom; flag as a UAT question rather than assuming it.

**Do not use `BqSegmented`** for the picker: it is a fixed-width horizontal control ("supports any number of segments (2+)" [VERIFIED: lib/core/widgets/bq_segmented.dart:21-23]) and a language list grows vertically and carries long native names. A checked list scales; a segmented control does not.

---

### P-7: How "System default" is represented

Three questions the UI-SPEC must answer explicitly:

1. **State model.** `null` already means "follow system" in `LocaleController` [VERIFIED: lib/core/l10n/locale_controller.dart:11-13, 20]. Keep it. The option list is `<Locale?>[null, ...AppLocalizations.supportedLocales]`.
2. **Label.** `context.l10n.languageSystem` — rendered in the *active* locale, so a Ukrainian-reading user sees `Системна` and an English-reading user sees `System default`. **Recommended refinement:** append the resolved language in parentheses, e.g. `Системна (Українська)` — built by composing `languageSystem` with `lookupAppLocalizations(Localizations.localeOf(context)).languageName`, not by a new ARB key per combination. Flag as `[ASSUMED]` — a UAT copy question.
3. **Position.** First in the list. It is the default state, and putting it first means the list's ordering never depends on a locale-sensitive string sort.

---

### P-8: Proving "every screen is bilingual" — the render matrix

Criterion 1 is a claim about *screens*, so the proof must render screens. The Phase-4 idiom is already in the tree and should simply be extended:

```dart
for (final locale in const ['uk', 'en']) {
  testWidgets('$locale: <screen> renders with no layout exception', (tester) async {
    await tester.pumpWidget(app(container, locale: locale));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
```
[VERIFIED idiom: test/features/planner_screen_test.dart:2585-2600, whose helper takes `String locale = 'uk'` and builds `MaterialApp(locale: Locale(locale), localizationsDelegates: AppLocalizations.localizationsDelegates, supportedLocales: AppLocalizations.supportedLocales, …)` — test/features/planner_screen_test.dart:133-150]

**Golden files are the wrong tool here** and should be explicitly rejected in the plan: they are platform- and font-dependent (and this phase may change the font), they would need regeneration on every copy tweak, and they answer "does it look identical" rather than "does it render correctly in this language". The assertions that carry weight are:

- `expect(tester.takeException(), isNull)` at textScaler 1.0 and 1.6 — catches the overflow class that Phase 3 shipped twice (the Phase-4 review's CR-01/WR-04)
- a locale-distinctive string is present (`find.text('Стек')` vs `find.text('Stack')`) — catches "rendered, but in the wrong language"
- **no Ukrainian-only characters appear while `en` is active** — a cheap, high-value regex assertion (`RegExp(r'[Ѐ-ӿ]')` over the rendered `Text` widgets) that catches a forgotten literal that grep might miss inside an interpolation

**Screens/sheets the matrix must cover** (the A-3 gap list): `AppShell` (3 tab labels), `StackScreen` (populated + empty + error), `AddSupplementSheet` (both tabs), `RegimenEditorScreen` (cyclic + course), `CalendarScreen` day view (populated + empty), `DoseActionSheet`, `PlannerScreen` (already covered), and the new `SettingsScreen`.

---

### P-9: The Riverpod-3 auto-retry defect — root cause and fix

**Carried todo (b), from `.planning/STATE.md:80` and 04-REVIEW.md:127.** Root-caused this session against the installed `riverpod 3.4.2` source.

When a provider's build throws, `ProviderElement` calls `triggerRetry`, which returns:

```dart
    if (retrying) {
      return AsyncLoading<ValueT>._(
        value._loading ?? (progress: 0),
        value: value._value,
        error: (err: error, stack: stackTrace, retrying: true),
      );
    }

    return AsyncError(error, stackTrace, retrying: false);
```
[VERIFIED: ~/.pub-cache/hosted/pub.dev/riverpod-3.4.2/lib/src/core/element.dart:790-797]

So while a retry is pending the state is an **`AsyncLoading` that carries an error** — `hasError` is true (`bool get hasError => _error != null;` [VERIFIED: riverpod-3.4.2/lib/src/core/async_value.dart:125]) and `isReloading` is true (`bool get isReloading => _hasState && isLoading && this is AsyncLoading;` [VERIFIED: async_value.dart:97]). `AsyncValue.when` then does:

```dart
    if (isLoading) {
      bool skip;
      if (isRefreshing) { skip = skipLoadingOnRefresh; }
      else if (isReloading) { skip = skipLoadingOnReload; }
      else { skip = false; }
      if (!skip) return loading();
    }
    if (hasError && (!hasValue || !skipError)) {
      return error(this.error!, stackTrace!);
    }
```
[VERIFIED: async_value.dart:242-267] — with `bool skipLoadingOnReload = false` as the default [VERIFIED: async_value.dart:243].

**Therefore `loading()` wins and `error()` is never reached during the retry window.** How long is that window? `defaultRetry`:

```dart
  static Duration? defaultRetry(
    int retryCount, Object error, {
    int maxRetries = 10,
    Duration maxDelay = const Duration(milliseconds: 6400),
    Duration minDelay = const Duration(milliseconds: 200),
  }) {
    if (retryCount >= maxRetries) return null;
    if (error is ProviderException || error is Error) return null;
    final delay = minDelay * math.pow(2, retryCount).toInt();
    if (delay > maxDelay) return maxDelay;
    return delay;
  }
```
[VERIFIED: riverpod-3.4.2/lib/src/core/provider_container.dart:981-995]

200 + 400 + 800 + 1600 + 3200 + 6400×5 = **38,200 ms**. The designed error surface and its retry button appear roughly **38 seconds** after a Drift failure. Note also `if (error is ProviderException || error is Error) return null;` — a Dart `Error` (e.g. `StateError`) is *not* retried and surfaces at once; Drift throws `Exception` subtypes, so the app's real failure mode is the 38-second one.

**The three affected surfaces:**

| Site | Current shape | Why it blanks |
|---|---|---|
| `lib/features/calendar/planner_screen.dart:608-613` | `switch (model) { AsyncError() => …, AsyncData(…) => …, _ => const <Widget>[] }` | An `AsyncLoading`-carrying-an-error matches neither arm → falls to `_` → **empty list** |
| `lib/features/stack/stack_screen.dart:103-155` | `entries.when(data:, loading: () => const <Widget>[], error:)` | `loading:` returns an empty list |
| `lib/features/calendar/calendar_screen.dart:312-370` | `widget.doses.when(data:, loading: <hold last list>, error:)` | Holds the previous day's rows behind an `IgnorePointer` — less bad, still not the error surface |

**Recommended fix — make "has an error" beat "is loading", at all three sites.** Keep auto-retry: it genuinely self-heals a transient failure, and disabling it throws that away.

```dart
// planner_screen.dart — hasError first (Riverpod 3 reports a retrying failure
// as AsyncLoading-carrying-an-error; matching AsyncError() alone blanks the
// screen for ~38s of backoff — 04-REVIEW.md CR-02 note).
return switch (model) {
  AsyncValue(hasError: true) => const [_PlannerError()],
  AsyncData(:final value) when isEmpty(value) => const [_EmptyPlanner()],
  AsyncData(:final value) => cards(value),
  _ => const <Widget>[],
};
```

```dart
// stack_screen.dart / calendar_screen.dart — one named argument each.
entries.when(
  skipLoadingOnReload: true,   // <- the fix
  data: (list) => …,
  loading: () => const <Widget>[],
  error: (_, _) => <Widget>[ /* documented copy + retry */ ],
)
```

**Rejected alternative:** `ProviderScope(retry: (count, error) => null)` — the parameter is real (`const ProviderScope({ super.key, this.overrides = const [], this.observers, this.retry, required this.child });` [VERIFIED: flutter_riverpod-3.4.2/lib/src/core/provider_scope.dart:75-81]) but it is a blunt global that removes self-healing everywhere to fix a rendering rule at three call sites. Per-provider `retry:` is likewise a heavier change than the surfaces need. Use the global/per-provider `retry` override **only in tests**, which `test/features/planner_screen_test.dart:883` already does: `retry: (retryCount, error) => null,`.

**The test that proves the fix** must run with auto-retry **enabled** (the existing CR-02 test disables it, which is why it passes today and did not catch this):

```dart
testWidgets('a failing stream shows the error surface immediately, not after '
            "Riverpod's ~38s retry backoff", (tester) async {
  final container = ProviderContainer(overrides: [/* seed the stream error */]);
  // NOTE: no `retry:` override — default backoff is live, which is the point.
  await tester.pumpWidget(app(container));
  await tester.pump();                       // one frame, not pumpAndSettle
  expect(find.text(l10n.stackLoadError), findsOneWidget);
  expect(find.text(l10n.retry), findsOneWidget);
});
```
Use `tester.pump()`, never `pumpAndSettle()` — with retry timers live, `pumpAndSettle` would either time out or silently wait out the backoff and pass for the wrong reason.

---

### P-10: The Instrument Sans Cyrillic gap — a costed user decision

**Carried todo (a), from `.planning/STATE.md:79`.** Independently re-verified this session by parsing the bundled TTFs' `cmap` tables directly:

| Font (bundled) | `A` | `a` | `Ц` | `ц` | `ї` | `і` | `І` | `Ї` | `є` | `ґ` |
|---|---|---|---|---|---|---|---|---|---|---|
| `InstrumentSans[wdth,wght].ttf` | ✓ | ✓ | **✗** | **✗** | **✗** | **✗** | **✗** | **✗** | **✗** | **✗** |
| `JetBrainsMono[wght].ttf` | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |

And there is no newer file that fixes it — upstream declares `subsets: "latin", "latin-ext", "menu"` only [VERIFIED: https://raw.githubusercontent.com/google/fonts/main/ofl/instrumentsans/METADATA.pb]. Instrument Sans will never carry Cyrillic.

Consequences today: `ThemeData(fontFamily: 'Instrument Sans')` [VERIFIED: lib/core/theme/theme.dart:27] applies to every non-mono string in the app; Ukrainian letters therefore render from the platform fallback (SF on iOS, Roboto on Android) while Latin letters and **digits** in the same line render from Instrument Sans. There is no `fontFamilyFallback` anywhere in `lib/` (grep: 0 hits), so the mixing is the engine's per-glyph default. All mono text is unaffected — JetBrains Mono covers full Ukrainian.

| Option | Bundle delta | Mockup fidelity | Notes |
|---|---|---|---|
| **1. Keep the fallback (status quo)** | 0 B | **Highest.** The approved HTML mockup was itself rendered in a browser where Instrument Sans has no Cyrillic — the Ukrainian screens the user approved *are* the fallback rendering | Latin/digit glyphs and Cyrillic glyphs come from different families within a line (`Омега-3`, `5 мг`), with different x-heights and advance widths. Rendering also differs between iOS and Android |
| **2. Swap primary to `Manrope[wght].ttf`** | **165,420 B**, i.e. **−28,916 B vs today** | Changes what every Ukrainian screen looks like vs. the approved mockup | Cyrillic + cyrillic-ext + greek + latin + latin-ext + vietnamese [VERIFIED: google/fonts ofl/manrope/METADATA.pb]; single `wght` axis (simpler than the current `wdth,wght`); one consistent family everywhere. Visually a geometric grotesque — noticeably different letterforms from Instrument Sans |
| **3. Swap primary to `Inter[opsz,wght].ttf`** | 876,576 B, **+682,240 B** | Same caveat as 2; Inter is closer to a neutral grotesque | Cyrillic/greek/vietnamese [VERIFIED: google/fonts ofl/inter/METADATA.pb], axes `opsz 14–32`, `wght 100–900`. Subsettable to latin+cyrillic with `pyftsubset` if the size matters — but subsetting adds a build step the project does not have |
| 4. `Noto Sans` | 2,049,096 B | — | Rejected on size alone |
| 5. Keep Instrument Sans + add a Cyrillic family via `fontFamilyFallback` | +Cyrillic family size | — | **Worst of both:** still mixes two families inside a line (digits from the primary, Cyrillic from the fallback) *and* pays the bundle cost. Do not recommend |

Sizes are HTTP `Content-Length` from `raw.githubusercontent.com/google/fonts/main/…`, measured this session. Flutter does **not** tree-shake text fonts (`--tree-shake-icons` covers icon fonts only), so the whole file ships [ASSUMED — well-established Flutter behaviour, not re-verified against the SDK source this session].

**Recommendation:** put this in front of the user as a `checkpoint:human-verify` task with options 1 and 2 as the real candidates, defaulting to **option 1 (keep the fallback)** if the user does not want to spend the decision — because it is the mockup-faithful answer and costs nothing, and swapping the primary family is a whole-app visual change landing in the final phase of v1. Whichever is chosen, record it as a locked decision so it is not re-litigated in v1.x. If option 2 or 3 is chosen, the change is mechanical: one `.ttf` + its OFL text under `assets/fonts/`, one `fonts:` family entry in `pubspec.yaml`, one string in `theme.dart:27`, plus a re-run of the Phase-4 text-scale matrix (different metrics ⇒ different intrinsic widths ⇒ the gantt truncation measurements change).

---

### P-11: The gantt/tap-target measurements — no action needed here

**Carried todo (c), from `.planning/STATE.md:81`.** Both items were measured, recorded, and **accepted for v1** at Phase-4 UAT:

> "MEASURED: 2 of 9 names ellipsize at scale 1.0 … This is designed truncation, not clipping — but whether the gantt's label column should be wider is a genuine design call for the user." [VERIFIED: .planning/phases/04-planner-views/04-UAT.md:21]
> "MEASURED hit-test box per column: 14.00 x 53.00 logical px … Accepted for v1; widening the columns or adding a week stepper is a possible Phase-5/v2 refinement." [VERIFIED: .planning/phases/04-planner-views/04-UAT.md:25]
> "Gantt label truncation (test 2) and 14px week columns (test 3) accepted for v1 with measurements recorded." [VERIFIED: .planning/phases/04-planner-views/04-UAT.md:53]

Neither is a localization defect and neither blocks any Phase-5 success criterion. **Recommendation: no task.** Two caveats for the plan:

- **Conditional re-measurement.** If P-10 changes the primary font, the 156.0px allotted / 183.1px intrinsic gantt measurements are invalidated and the Phase-4 text-scale matrix must be re-run. Make this an explicit dependency of the font task, not a separate item.
- **The new Settings rows must not repeat the 14px mistake.** Minimum 48px row height, full-width `HitTestBehavior.opaque` targets (P-6).

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---|---|---|---|
| Matching the device language against supported locales | A `localeResolutionCallback` / `localeListResolutionCallback` | The framework default (`basicLocaleListResolution`) | It already walks the whole system preference list, handles script/country subtags, and does the `supportedLocales.first` fallback. A hand-rolled callback would need `preferredLocales` (plural) handling to be as good — and would move the fallback out of `l10n.yaml` where PF-1's fix lives |
| Native language names for the picker | A `Map<String,String>` of codes → names, or a `switch (languageCode)` | The self-referential `languageName` ARB key + `lookupAppLocalizations` (P-2) | Any map or switch is the code change criterion 4 forbids |
| Month/weekday names, week ranges, day numbers | A month-name table, or `MMMM` where `LLLL` is meant | `intl.DateFormat` with the active locale | Already the house rule; uk needs the standalone (`LLLL`) case, pinned by `test/l10n/month_names_test.dart` — and `MMMM` *looks* safe in a one-field pattern, which is the whole trap that file exists to document |
| Sentence-casing a formatted weekday | `_capitalizeFirst()` (`lib/features/calendar/calendar_screen.dart:232-236`) | `intl`'s `toBeginningOfSentenceCase(value, locale)` [VERIFIED: intl-0.20.3/lib/intl.dart:607] | The hand-rolled version uses locale-independent Unicode default casing. Correct for uk/en, wrong for e.g. Turkish `i`→`İ` — exactly the class of bug criterion 4 invites. Low-risk one-line swap; recommended, not required |
| Pluralization | Any `if (n == 1)` / `count > 4 ? …` in Dart | ICU `plural` in ARB | Already done everywhere; the gate keeps it that way |
| Detecting missing translations | Diffing ARB files by eye at review | `untranslated-messages-file` + a test asserting it is empty (V-3) | gen-l10n silently falls back to the template's English message — a reviewer sees the diff once, the test sees every commit |
| Persisting the override | A settings table in Drift | `shared_preferences`, key `app_locale` | Locked decision; and the locale is needed before the DB is opened |
| Fetching fonts | `google_fonts` | Plain `fonts:` asset declaration | Locked: offline app, no network |

---

## Validation Rules

**V-1 — Plural correctness is asserted at 1 / 2 / 5 / 11 / 21 for every uk plural key.** Five probes, not two: `one` (1, 21), `few` (2), `many` (5), and the **11–14 exception** (11). The existing `test/l10n/plurals_test.dart` already does this for six keys; the rule is that **every** plural key gets the five-probe treatment, including the two new ones if the Settings screen adds any (it should not need to).

**V-2 — No hardcoded user-visible string may enter `lib/`.** A source-globbing test over `lib/**.dart` excluding `lib/core/l10n/gen/`, modelled on `test/features/planner_invariants_test.dart:83-120` (which strips comments before matching — do the same, and assert the glob resolved a non-trivial file count so an empty glob can never pass silently). Flag: a string literal appearing as the first positional argument to `Text(` or as the value of `label:`/`tooltip:`/`hintText:`/`labelText:`/`helperText:`/`errorText:`/`semanticsLabel:`. Allowlist by explicit constant, not by regex looseness: `DateFormat` patterns, `ValueKey`/`Key` strings, font family names, `assert` messages.

**V-3 — The "one new ARB file" contract is asserted structurally.** The five assertions in P-1: generated locale list ≡ ARB files on disk; controller set ≡ ARB files on disk; `supportedLocales.first == Locale('en')`; every ARB has a non-empty `languageName`; every ARB language is in `kMaterialSupportedLanguages`. Plus: `l10n-untranslated.json` is absent or empty.

**V-4 — Every screen renders in both locales at textScaler 1.0 and 1.6 with no layout exception**, and while `en` is active no Cyrillic character (`[Ѐ-ӿ]`) appears in the rendered tree.

**V-5 — The error surface is reachable within one frame of a provider failure**, with Riverpod's default retry live (P-9).

**V-6 — Locale changes propagate to a pushed route and to an open modal sheet.** One widget test that opens the regimen editor (pushed route) and one that opens the add-supplement sheet, flips `localeControllerProvider`, pumps, and asserts the visible copy changed language.

---

## Common Pitfalls

### PF-1: The English fallback is alphabetical, not declared — adding any language before `en` silently moves it
**What goes wrong:** `MaterialApp` falls back to `supportedLocales.first`; gen-l10n emits that list alphabetically. Add `app_de.arb` and German becomes the fallback for every unmatched system language, with no code change, no warning, and no failing test.
**Why it happens:** the current correct behaviour is a coincidence of `en` < `uk`. `lib/main.dart:17-18` even documents the intent — "`Locale('en')` is listed FIRST so any unsupported system language falls back to it" — but nothing *enforces* the ordering.
**How to avoid:** `preferred-supported-locales: [en]` in `l10n.yaml`, plus V-3's `expect(AppLocalizations.supportedLocales.first, const Locale('en'))`.
**Warning signs:** a new ARB whose code sorts before `en` (`af`, `ar`, `bg`, `cs`, `de`…) — i.e. most of them.

### PF-2: A missing key in a non-template ARB does not fail the build
**What goes wrong:** `app_pl.arb` omits `weekNoFreeSlots`; gen-l10n emits the English message for it and the Polish app shows one English sentence in the middle of a screen.
**Why it happens:** gen-l10n's designed behaviour is fall-back-and-warn, and the warning scrolls past in `flutter pub get` output.
**How to avoid:** `untranslated-messages-file: l10n-untranslated.json` + a test asserting the file is absent or `{}`.
**Warning signs:** any `flutter pub get` line mentioning untranslated messages.

### PF-3: Persisting before switching makes "instant" a lie
**What goes wrong:** `setLocale` awaits a platform channel and a disk write before `state = locale`, so the tap-to-repaint latency includes I/O.
**How to avoid:** assign state first, persist after (P-4).
**Warning signs:** a widget test that needs `await tester.pumpAndSettle()` (rather than a single `pump`) to see the new language.

### PF-4: A widget that caches a formatted string outliving the locale change
**What goes wrong:** `late final String _title = DateFormat.yMMMM(...).format(day)` in a `State` field, or an `l10n` read in `initState`. The locale flips, the widget rebuilds, the field does not.
**Why it happens:** `initState` runs once; `Localizations` changes are delivered via `didChangeDependencies` and `build`.
**How to avoid:** construct formatters and read `context.l10n` **inside `build`** — the current codebase does this at all 17 `DateFormat` sites and has **zero** `initState` reads of `l10n`/`DateFormat`/`context` (verified by grep). Keep it that way; the V-2 gate can be extended with an `initState`-body check.
**Warning signs:** `late final` + `DateFormat`/`l10n` in the same class.

### PF-5: Composing sentences by concatenating localized fragments
**What goes wrong:** `'${l10n.addSupplement}: ${entry.name(l10n)}'` [VERIFIED: lib/features/stack/add_supplement_sheet.dart:356] hardcodes word order and the `: ` separator across all languages.
**Why it happens:** it reads naturally in en and uk, so it never bites — until it does.
**How to avoid:** an ARB key with two placeholders. The codebase already has the right idiom elsewhere: `weekLoadLabel`'s metadata says *"`max` is a pre-formatted `slotsCount` string — the count is declined by its own plural key and passed in finished, the `cycleSummaryCyclic` idiom."*
**Priority:** low — one site, semantics label only. Worth fixing while the phase is in the file.

### PF-6: `toUpperCase()` / `toLowerCase()` without a locale
**What goes wrong:** four `toUpperCase()` sites on `intl`-produced month/weekday abbreviations (`planner_year_grid.dart:163`, `planner_month_detail.dart:120`, `planner_gantt.dart:155`, `week_strip.dart:278`) and `_capitalizeFirst` (`calendar_screen.dart:232-236`) use Dart's locale-independent Unicode default casing.
**Why it happens:** correct for uk and en, so nothing surfaces in v1.
**How to avoid:** swap `_capitalizeFirst` for `intl`'s `toBeginningOfSentenceCase(value, locale)`. Leave the four `toUpperCase()` sites alone in v1 (they operate on already-uppercased-safe abbreviations) but note the constraint in the UI-SPEC.
**Warning signs:** the first ARB for a language with special casing rules (`tr`, `az`, `lt`).

### PF-7: `pumpAndSettle` in any test touching a failing provider
**What goes wrong:** Riverpod's retry `Timer`s keep the scheduler busy; `pumpAndSettle` either times out or waits out ~38 s of backoff and then passes for the wrong reason.
**How to avoid:** `tester.pump()` with an explicit frame count, or an explicit `retry: (_, _) => null` override when the retry is *not* what is under test (the existing precedent is `test/features/planner_screen_test.dart:883`).

### PF-8: Testing `DateFormat` in a pure test without loading symbols
**What goes wrong:** `DateFormat('LLLL', 'uk')` silently formats in the default locale and the assertion tests English while claiming to test Ukrainian.
**Why it happens:** in the app, symbols arrive via `GlobalMaterialLocalizations`; in a pure `test()` with no widget pump, nothing loads them.
**How to avoid:** the existing pattern — `await initializeDateFormatting('uk')` in `setUpAll` [VERIFIED: test/l10n/month_names_test.dart:38-41, whose comment says "Without this the uk symbols are never loaded and `DateFormat` silently falls back to the default locale — every assertion below would then be testing English"].

### PF-9: A new ARB for a language `flutter_localizations` does not cover
**What goes wrong:** `GlobalMaterialLocalizations.load` opens with `assert(isSupported(locale))`; outside the 82-language `kMaterialSupportedLanguages` set the app asserts in debug and has untranslated Material chrome in release.
**How to avoid:** V-3 assertion 5 states the boundary as a test rather than leaving it to be discovered.

### PF-10: Assuming `flutter test` regenerates localizations
**What goes wrong:** you add `languageName` to both ARBs, run `flutter test`, and the getter does not exist.
**How to avoid:** gen-l10n runs on `flutter pub get` / `flutter run` (via `generate: true`), not on `flutter test`. Run `flutter gen-l10n` (or `flutter pub get`) after every ARB edit. Worth one line in the plan's per-task verification.

---

## Code Examples

### The three new ARB keys (template + uk)

```jsonc
// lib/core/l10n/arb/app_en.arb  — template, metadata required
"languageName": "English",
"@languageName": {
  "description": "This language's own name, written in this language. EVERY app_*.arb declares its own value under this same key; the picker resolves it via lookupAppLocalizations(locale), so adding a new ARB file needs no code change (L10N-04 criterion 4). Never translate this key — each file's value is its own language's endonym."
},
"languageSystem": "System default",
"@languageSystem": {
  "description": "Language-picker option meaning 'follow the device language'. Rendered in the ACTIVE locale (via context.l10n), unlike languageName."
},
"settingsLanguageTitle": "Language",
"@settingsLanguageTitle": {
  "description": "Mono eyebrow above the language list on the Settings screen, in the supplementsLabel style"
}
```
```jsonc
// lib/core/l10n/arb/app_uk.arb — no metadata (template owns it)
"languageName": "Українська",
"languageSystem": "Системна",
"settingsLanguageTitle": "Мова"
```

### The picker body (enumerates nothing)

```dart
class _LanguageList extends ConsumerWidget {
  const _LanguageList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final current = ref.watch(localeControllerProvider);
    // System default first, then the GENERATED list — never a literal list.
    final options = <Locale?>[null, ...AppLocalizations.supportedLocales];

    return Column(
      children: [
        for (final (i, locale) in options.indexed) ...[
          if (i > 0) const Divider(height: 1, color: BqColors.hairline),
          _LanguageRow(
            label: locale == null
                ? l10n.languageSystem
                : lookupAppLocalizations(locale).languageName,
            selected: locale?.languageCode == current?.languageCode,
            onTap: () => ref
                .read(localeControllerProvider.notifier)
                .setLocale(locale),
          ),
        ],
      ],
    );
  }
}
```

### `LocaleController` after the three edits (P-1 Edit 2, P-4)

```dart
class LocaleController extends Notifier<Locale?> {
  static const _prefsKey = 'app_locale';

  /// Language codes the app ships translations for — DERIVED from the ARB
  /// files via the generated list, never enumerated here. Adding
  /// `app_pl.arb` regenerates `supportedLocales` and this set follows with
  /// no edit in this file (L10N-04, criterion 4).
  static final Set<String> supportedLanguageCodes = {
    for (final l in AppLocalizations.supportedLocales) l.languageCode,
  };

  @override
  Locale? build() {
    // Synchronous seed — the stored override is applied on frame 1, so a user
    // who set an override never sees a system-language frame first (P-4).
    final code = ref.watch(sharedPreferencesProvider).getString(_prefsKey);
    // Stored value is untrusted local input (threat T-01-07). Anything not in
    // the shipped ARB set means "follow system" — never crash resolution.
    return (code != null && supportedLanguageCodes.contains(code))
        ? Locale(code)
        : null;
  }

  /// Sets the manual override. `null` clears it (follow system).
  Future<void> setLocale(Locale? locale) async {
    state = locale;                       // criterion 3: instant, before I/O
    final prefs = ref.read(sharedPreferencesProvider);
    if (locale == null) {
      await prefs.remove(_prefsKey);
    } else {
      await prefs.setString(_prefsKey, locale.languageCode);
    }
  }
}
```

### The error-surface fix (P-9)

```dart
// lib/features/calendar/planner_screen.dart
List<Widget> _surface<T>(BuildContext context, WidgetRef ref, {
  required AsyncValue<T> model,
  required bool Function(T) isEmpty,
  required List<Widget> Function(T) cards,
}) {
  return switch (model) {
    // hasError FIRST. Riverpod 3 reports a failing provider as an
    // AsyncLoading that CARRIES the error while it retries on its own
    // backoff (element.dart triggerRetry). Matching `AsyncError()` alone
    // leaves this arm unreached for ~38s of defaultRetry, during which the
    // screen renders the blank loading surface instead of the designed
    // error surface (04-REVIEW.md CR-02 note).
    AsyncValue(hasError: true) => const [_PlannerError()],
    AsyncData(:final value) when isEmpty(value) => const [_EmptyPlanner()],
    AsyncData(:final value) => cards(value),
    _ => const <Widget>[],
  };
}
```

### The bilingual render matrix (extend, don't invent)

```dart
for (final locale in const ['uk', 'en']) {
  for (final scale in const <double>[1.0, 1.6]) {
    testWidgets('$locale @$scale: the Stack screen renders with no layout '
        'exception and no wrong-language text', (tester) async {
      usePhoneSurface(tester);
      final container = makeContainer();
      await seedPopulatedStack(container);
      await tester.pumpWidget(app(container, locale: locale, textScaler:
          TextScaler.linear(scale)));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull, reason: overflowReason);
      expect(find.text(locale == 'uk' ? 'Стек' : 'Stack'), findsWidgets);
      if (locale == 'en') {
        final cyrillic = RegExp(r'[Ѐ-ӿ]');
        for (final t in tester.widgetList<Text>(find.byType(Text))) {
          final data = t.data;
          if (data != null) {
            expect(cyrillic.hasMatch(data), isFalse,
                reason: 'a Cyrillic string reached the tree while en was '
                        'active: "$data" — a literal escaped the ARB');
          }
        }
      }
    });
  }
}
```

---

## Edge Coverage

| # | Edge | Expected behavior |
|---|------|-------------------|
| E-1 | uk counts at 1 / 2 / 5 / 11 / 21 for all 10 plural keys | `one` / `few` / `many` / `many` (11–14 exception) / `one`. Already pinned for 6 keys in `plurals_test.dart`; extend to all 10 |
| E-2 | en counts at 0 / 1 / 2 | `other` / `one` / `other` — English `0` takes `other` ("0 substances"), which reads correctly |
| E-3 | Device language is `de` (unsupported), no override | Falls back to `supportedLocales.first`. **Must assert this is `en`, not merely "the first entry"** (PF-1) |
| E-4 | Device preference list is `[de-DE, uk-UA, en-US]`, no override | Resolves to `uk` — the framework walks the whole list, not just `[0]` |
| E-5 | Override set to `en` on a `uk` device, then app restarted | Launches in `en` on frame 1 (with P-4 option A) or after one frame (option B) |
| E-6 | Override cleared (`System default`) on an `en` device with a stored `uk` | Prefs key removed; app immediately renders `en`; next launch follows system |
| E-7 | Stored `app_locale` holds a code that is no longer shipped (`de`, or `uk` after removing its ARB) | Sanitized to `null` → follow system. Never a crash, never a `lookupAppLocalizations` throw. Already tested for `de` (`locale_controller_test.dart:53-62`); add the removed-ARB case |
| E-8 | A new ARB is added for a language outside `kMaterialSupportedLanguages` | Material/Cupertino chrome untranslated and `GlobalMaterialLocalizations.load` asserts in debug. Documented boundary of criterion 4, pinned by V-3 assertion 5 |
| E-9 | RTL language added later | Padding and radii are already direction-neutral (A-2 grep: zero LTR-hardcoded sites). **Not** covered: the four `CustomPainter`s (`planner_gantt`, `planner_load_chart`, `day_progress_ring`, `regimen_editor`'s dashed border) paint time left-to-right in raw canvas coordinates. Out of scope for v1; record as a known constraint so a future RTL phase is not surprised |
| E-10 | Language switched while a modal bottom sheet is open | Sheet content re-localizes in place — its route is below `MaterialApp`'s `Localizations` (V-6) |
| E-11 | Language switched while the regimen editor (a pushed route) is open | Same; plus its `showDatePicker`/`showTimePicker` chrome follows, via `GlobalMaterialLocalizations` |
| E-12 | Language switched while a supplement added from the catalog is in the stack | The stored name does **not** change — copy-on-add is intended behaviour [VERIFIED: lib/features/stack/catalog.dart:11-15]. State it at UAT |
| E-13 | Catalog search in `en` while the ARB set has grown to 3 languages | Search still matches active-locale names + English names [VERIFIED: lib/features/stack/catalog.dart:167-176]. Adding a language needs no change here — the third language's names are searchable when it is active |
| E-14 | textScaler 1.6 with the longest uk strings on the new Settings screen | No layout exception; rows grow, no fixed heights. The list is the newest surface and therefore the least proven |
| E-15 | Rapid repeated taps on picker rows | Each `setLocale` sets state synchronously and awaits its own write; last write wins. No queue, no lock needed |
| E-16 | Locale change while a Drift stream is mid-error (retry backoff live) | The error surface stays visible and re-renders in the new language (this is where P-9 and P-5 intersect) |

---

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | `flutter_test` (SDK) + in-memory Drift + `ProviderScope` overrides — the harness proven in Phases 1–4 |
| Config file | `analysis_options.yaml` (exists; `include: package:flutter_lints/flutter.yaml`) |
| Quick run command | `flutter test test/l10n/` (the whole l10n group is fast — 4 files, 693 lines today) |
| Full suite command | `flutter gen-l10n && flutter analyze && flutter test` |

**Note the added first step.** Every other phase could run `flutter analyze && flutter test`; this phase edits ARB files, and `flutter test` does **not** run gen-l10n (PF-10). The phase gate command must regenerate first.

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| L10N-01 | All 10 uk plural keys at 1/2/5/11/21 | unit | `flutter test test/l10n/plurals_test.dart` | exists — extend (6 of 10 covered) |
| L10N-01 | en/uk ARB key parity; every `@`-block present in the template | unit (reads ARB off disk) | `flutter test test/l10n/arb_parity_test.dart` | ❌ Wave 0 |
| L10N-01 | Every screen renders in uk AND en at scale 1.0/1.6, no layout exception, no wrong-language text | widget matrix | `flutter test test/features/ test/widget/` | partial — planner only; **stack / editor / add-sheet / shell / settings = Wave 0** |
| L10N-02 | Unsupported system language → `en`; `supportedLocales.first == Locale('en')` | unit | `flutter test test/l10n/new_language_contract_test.dart` | ❌ Wave 0 |
| L10N-02 | System preference list `[de, uk, en]` resolves to `uk` | widget (`platformDispatcher.localesTestValue`) | `flutter test test/l10n/locale_resolution_test.dart` | ❌ Wave 0 |
| L10N-03 | Tapping a picker row changes visible copy within one `pump` | widget | `flutter test test/features/settings_screen_test.dart` | ❌ Wave 0 |
| L10N-03 | Override persists: set → rebuild container → still applied | unit | `flutter test test/l10n/locale_controller_test.dart` | exists — extend |
| L10N-03 | Change propagates to a pushed route and to an open bottom sheet | widget | `settings_screen_test.dart` / `regimen_editor_test.dart` | ❌ Wave 0 |
| L10N-03 | Removed/invalid stored code → follow system, no crash | unit | `locale_controller_test.dart` | exists — extend (E-7 second case) |
| L10N-04 | Zero hardcoded user-visible strings in `lib/` | source-glob gate | `flutter test test/l10n/no_hardcoded_strings_test.dart` | ❌ Wave 0 |
| L10N-04 | The "one new ARB file" contract (V-3's five assertions) | unit | `flutter test test/l10n/new_language_contract_test.dart` | ❌ Wave 0 |
| L10N-04 | `l10n-untranslated.json` absent or empty | unit | same file | ❌ Wave 0 |
| L10N-04 | uk standalone month case (`LLLL` → `серпень`) | unit | `flutter test test/l10n/month_names_test.dart` | exists ✓ |
| (P-9) | Error surface within one frame with default retry live | widget | `flutter test test/features/planner_screen_test.dart test/features/stack_screen_test.dart test/features/calendar_screen_test.dart` | exists — add one test per surface |
| (P-10) | If the font changes: the Phase-4 text-scale matrix still passes | widget | `flutter test test/features/planner_screen_test.dart` | exists — re-run, conditional on the font decision |

### Sampling Rate
- **Per task commit:** the single relevant test file — `flutter test test/l10n/<file>_test.dart` or `flutter test test/features/settings_screen_test.dart`. Under 30 s each. **After any ARB edit, prefix with `flutter gen-l10n`.**
- **Per wave merge:** `flutter gen-l10n && flutter analyze && flutter test`.
- **Phase gate:** full suite green before `/gsd-verify-work`, plus a manual both-locale walkthrough on one iOS and one Android device (this phase's central claim is visual and per-screen; the matrix proves "no exception", a human proves "reads correctly").

### Wave 0 Gaps
- [ ] `test/l10n/arb_parity_test.dart` — key parity + template metadata completeness (extends the `planner_copy_safety_test.dart` read-ARB-off-disk idiom)
- [ ] `test/l10n/new_language_contract_test.dart` — the five criterion-4 assertions (V-3) **build this first; it is what the phase's hardest criterion means**
- [ ] `test/l10n/no_hardcoded_strings_test.dart` — the source-glob gate (V-2), modelled on `planner_invariants_test.dart:83-120`
- [ ] `test/l10n/locale_resolution_test.dart` — system-list resolution + `en` fallback
- [ ] `test/features/settings_screen_test.dart` — picker rendering, selection, instant switch, propagation to a pushed route and an open sheet
- [ ] Extend `test/l10n/plurals_test.dart` (4 remaining plural keys) and `test/l10n/locale_controller_test.dart` (E-7 second case, P-4 ordering)
- [ ] Extend `test/features/stack_screen_test.dart`, `test/features/regimen_editor_test.dart`, `test/widget/app_shell_test.dart`, `test/features/calendar_screen_test.dart` with the `for (final locale in const ['uk','en'])` matrix
- [ ] One error-surface-under-live-retry test per async surface (P-9)
- No new fixture framework: reuse the in-memory-DB + `ProviderScope` override harness and the Phase-2/3/4 seeding helpers. **If P-4 option A is chosen, every harness that reaches the locale controller needs a `sharedPreferencesProvider` override** — budget that as a mechanical edit across the test helpers.

---

## Security Domain

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | No | Offline single-user app, unchanged |
| V3 Session Management | No | No sessions |
| V4 Access Control | No | No multi-user surface |
| V5 Input Validation | **Yes — one input** | The `app_locale` value read from `SharedPreferences` is **untrusted local input** (editable on a rooted device or via a modified backup). It is already allowlist-validated against the shipped language set, and that behaviour is already pinned by a test [VERIFIED: lib/core/l10n/locale_controller.dart:28-34, comment "Stored value is untrusted local input (threat T-01-07)"; test/l10n/locale_controller_test.dart:53-62]. **Do not weaken this to a `Locale(code)` passthrough while making it dynamic** — the allowlist must follow the ARB set, not disappear. An unvalidated code would reach `lookupAppLocalizations`, which throws `FlutterError` on an unknown language (`app_localizations.dart:1117-1122`) → a crash loop at launch that the user cannot escape without reinstalling |
| V6 Cryptography | No | Unencrypted SQLite remains the accepted v1 trade-off |

**Threat notes (STRIDE):** the only meaningful category is *Denial of Service via tampered local state* — a malformed `app_locale` that crashes locale resolution before any UI is reachable. The allowlist is the control, and the "removed ARB" case (E-7) is its untested half. No network I/O, no process spawning, no new data at rest (one short language code). The Settings screen accepts **no free-text input at all** — every interaction is a tap on a bounded list.

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Flutter SDK 3.47 / Dart 3.13 | everything | ✓ | `Flutter 3.47.0 • channel stable • revision 4cf2416426 (2026-08-11)` (verified via `flutter --version`); `sdk: ^3.13.0` [pubspec.yaml:22] | — |
| `flutter gen-l10n` | every ARB edit | ✓ | bundled | `flutter pub get` (also triggers it via `generate: true`) |
| `intl` (unpinned, SDK-resolved) | dates, months, plurals | ✓ | 0.20.3 [VERIFIED: pubspec.lock] | — |
| `flutter_localizations` (SDK) | Material chrome + date symbols for all locales | ✓ | SDK | — |
| `shared_preferences` | override persistence | ✓ | 2.5.5 [VERIFIED: pubspec.lock] | — |
| `flutter_riverpod` | locale controller, surfaces | ✓ | 3.4.2 [VERIFIED: pubspec.lock] | — |
| Existing test harness (in-memory Drift + ProviderScope) | all new tests | ✓ | Phases 1–4 | — |
| `node` / gsd-tools seams | automated research seams | ✗ (sandbox constraint, as in Phases 1–4) | — | Manual verification performed; SDK and pub-cache sources read directly |
| Network (for font evaluation only) | P-10 sizes/subsets | ✓ | — | — |
| iOS simulator / Android emulator | both-locale visual walkthrough | ✓ per Phase-3 DATA-03 run | — | Physical devices |
| A Cyrillic-capable font file | only if P-10 option 2/3 is chosen | ✓ (OFL, `google/fonts`) | Manrope 165,420 B · Inter 876,576 B | Option 1 (keep fallback) needs nothing |

**No blocking gaps.** The only conditional dependency is a font file, and only if the user picks that option.

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | The Settings screen's v1 content is the language picker only (plus title/eyebrow), matching the spec's "settings/ # language picker" scope | P-6 | Scope-level; adding an About/version line later is additive. **UAT question** |
| A2 | All Settings copy (`languageSystem`, `settingsLanguageTitle`, and any empty/help text) is newly authored — the mockup has no Settings screen | P-6 | Copy quality only; UAT will correct wording. The *structure* (a checked list) is what matters |
| A3 | "System default" reads better with the resolved language appended — `Системна (Українська)` | P-7 | Cosmetic; one ARB composition either way. **UAT question** |
| A4 | P-4 option A (synchronous prefs seed in `main()`) is worth the test-harness churn it causes | P-4 | If the churn is worse than expected, fall back to option B and record the one-frame flash as accepted. Reversal is cheap and local |
| A5 | Flutter does not tree-shake text fonts, so a swapped family ships whole | P-10 | If wrong, the Inter option gets cheaper; the recommendation (option 1 or 2) does not change |
| A6 | Manrope's letterforms are acceptably close to the approved mockup's feel | P-10 | Purely visual; the user decides. This is precisely why P-10 is a checkpoint, not a task |
| A7 | Swapping `_capitalizeFirst` for `toBeginningOfSentenceCase` is safe for uk/en output today | Don't Hand-Roll / PF-6 | The existing `month_names_test.dart` assertions would catch a regression immediately; if the outputs differ, keep the hand-rolled version and document why |
| A8 | The Cyrillic-in-`en` regex assertion (`[Ѐ-ӿ]`) will not produce false positives | P-8 | If a legitimate proper noun in English copy ever needs Cyrillic, allowlist that key explicitly rather than deleting the assertion |
| A9 | A fast structural test (V-3) proves criterion 4 adequately, without shelling out to `flutter gen-l10n` against a synthetic third ARB | P-1 | If the planner wants belt-and-braces, the shell-out variant is a strictly-additive second test |
| A10 | No new design tokens are needed for the Settings screen | P-6 | If the UI-SPEC wants a distinct row background, one token addition under a `// --- Phase-5 additions ---` banner follows the existing convention |
| A11 | `preferred-supported-locales` accepts a bare language code (`en`) as well as `en_US` | P-1 | The help text's example uses `en_US`; if a bare code misbehaves, use `en` → verify the generated list and adjust. Caught immediately by V-3 assertion 3 |

---

## Open Questions

1. **What does the Settings screen look like?** (P-6, A1, A2)
   - What we know: the mockup has **no** Settings screen — its third tab is `Радник` [VERIFIED: mockup:176]. The Phase-1 stub renders only a localized heading and its own docstring says "nothing else renders until Phase 5". Every needed token already exists.
   - What's unclear: card vs. plain list, whether a title bar matches the Stack screen's treatment, whether an About/version line belongs in v1.
   - Recommendation: produce a `05-UI-SPEC.md` composing the screen from the Stack screen's title + mono-eyebrow + card idiom; keep it to the language picker; raise the About line at UAT.

2. **Does the flash-free bootstrap (P-4 option A) ship in v1?** (A4)
   - What we know: the flash affects only users who set an override, on every cold start. Option A removes it and makes the controller synchronous and simpler to reason about; it costs a `sharedPreferencesProvider` override in every test harness that reaches the controller.
   - Recommendation: ship it — the churn is mechanical and this is the last v1 phase, so the harness edits are paid once. If the plan is tight, option B is defensible; record the choice either way.

3. **Font: keep the platform Cyrillic fallback, or swap the primary family?** (P-10, A6) — **USER DECISION**
   - What we know: Instrument Sans will never have Cyrillic (upstream subsets are `latin`, `latin-ext`, `menu`). The approved mockup was itself rendered with that fallback, so option 1 is the mockup-faithful answer. Manrope is Cyrillic-complete and **smaller** than the current file (165,420 B vs 194,336 B); Inter is Cyrillic-complete and 4.5× larger. JetBrains Mono already covers Ukrainian, so all mono text is fine either way.
   - Recommendation: `checkpoint:human-verify` early in the phase, defaulting to option 1 if the user does not want to decide. If a swap is chosen, the Phase-4 text-scale matrix must be re-run in the same wave (different metrics ⇒ different truncation measurements).

4. **Should the `add_supplement_sheet.dart:356` concatenated semantics label become a two-placeholder ARB key?** (PF-5)
   - What we know: it is the only string concatenation of localized fragments in the codebase, it is a semantics label, and it reads correctly in both shipped languages.
   - Recommendation: fix it while the phase is in the i18n files — it is a two-line change and it makes the "zero hardcoded structure" claim complete. Not blocking.

---

## Sources

### Primary (HIGH confidence)
- Project code read line-by-line this session: `lib/main.dart`, `lib/app_shell.dart`, `lib/core/l10n/{l10n,locale_controller}.dart`, `lib/core/l10n/gen/app_localizations.dart`, `lib/core/l10n/arb/{app_en,app_uk}.arb` (both fully parsed programmatically), `lib/core/providers.dart`, `lib/core/theme/{theme,tokens}.dart`, `lib/features/settings/settings_screen.dart`, `lib/features/stack/{catalog,stack_screen}.dart`, `lib/features/calendar/{planner_screen,calendar_screen}.dart`, `l10n.yaml`, `pubspec.yaml`, `pubspec.lock`, `analysis_options.yaml` — every `[VERIFIED: path:lines]` tag refers to these reads, with the cited values quoted verbatim
- Tests read this session: `test/l10n/{plurals,month_names,locale_controller,planner_copy_safety}_test.dart`, `test/features/{planner_screen,planner_invariants}_test.dart` (harness + matrix idioms)
- **Installed Flutter SDK 3.47.0** (`/opt/homebrew/share/flutter`), read directly: `packages/flutter/lib/src/widgets/app.dart:151-239` (`basicLocaleListResolution`, `supportedLocales.first` fallback); `packages/flutter_localizations/lib/src/utils/date_localizations.dart:17-30` (loads date symbols for ALL locales at once); `packages/flutter_localizations/lib/src/material_localizations.dart:726-745` (`isSupported` assert + `loadDateIntlDataIfNotLoaded` call site); `packages/flutter_localizations/lib/src/l10n/generated_material_localizations.dart:46518ff` (`kMaterialSupportedLanguages`, 82 entries, parsed); `packages/flutter_tools/lib/src/commands/generate_localizations.dart:55-200` (`untranslated-messages-file`, `preferred-supported-locales`, `required-resource-attributes`, `nullable-getter` semantics)
- **Installed pub cache**, read directly: `riverpod-3.4.2/lib/src/core/element.dart:764-797` (`triggerRetry`), `riverpod-3.4.2/lib/src/core/async_value.dart:74-127, 236-267` (`hasError`, `isReloading`, `when`), `riverpod-3.4.2/lib/src/core/provider_container.dart:978-995` (`defaultRetry`), `flutter_riverpod-3.4.2/lib/src/core/provider_scope.dart:75-115` (`retry` parameter), `intl-0.20.3/lib/intl.dart:607` (`toBeginningOfSentenceCase`), `shared_preferences-2.5.5` (no deprecation on the legacy API)
- **Bundled font files**, `cmap` tables parsed directly this session (formats 4 and 12) — `assets/fonts/InstrumentSans[wdth,wght].ttf` and `assets/fonts/JetBrainsMono[wght].ttf`
- `claude_design_mockup/Boostque v0.1.dc.html` — full-file search for any Settings/language surface (991 lines; three hits, all false positives) and the nav destinations at lines 174-176, 267-269, 381-383, 461-463
- `.planning/REQUIREMENTS.md` (L10N-01..04, Out of Scope, locked decisions), `.planning/ROADMAP.md:124-137` (Phase 5 goal + 4 criteria), `.planning/STATE.md:77-81` (the three carried todos, verbatim), `.planning/phases/04-planner-views/04-REVIEW.md:125-156` (CR-02 + the auto-retry note), `.planning/phases/04-planner-views/04-UAT.md:21,25,53` (the accepted measurements), `.claude/CLAUDE.md`, `docs/superpowers/specs/2026-08-14-boostque-v1-design.md:82-95`

### Secondary (MEDIUM confidence)
- `https://raw.githubusercontent.com/google/fonts/main/ofl/{instrumentsans,manrope,inter}/METADATA.pb` — declared subsets and filenames, fetched this session. Authoritative for the fonts' own metadata; MEDIUM only because the repository's `main` branch can move
- Font byte sizes from HTTP `Content-Length` on `raw.githubusercontent.com` — measured this session, subject to the same branch caveat
- `.planning/phases/04-planner-views/04-RESEARCH.md` — house conventions this document mirrors (section shape, provenance tagging, gate-test style)

### Tertiary (LOW confidence)
- A general web search for Instrument Sans's Cyrillic support returned an aggregator page claiming the font "includes support for Cyrillic … Arabic, Simplified Chinese, Japanese, Korean, and Devanagari" — **this is wrong**, and it is recorded here only as a caution: it was contradicted both by the upstream `METADATA.pb` and by my own cmap parse of the shipped file. Font-coverage claims from search results were not used anywhere in this document
- "Flutter does not tree-shake text fonts" (A5) — training knowledge, not re-verified against the SDK build pipeline this session

## Metadata

**Confidence breakdown:**
- ARB audit (parity, plural forms, count-bearing keys) and hardcoded-string audit: **HIGH** — both ARB files were parsed programmatically this session and four independent greps were run over `lib/`; the numbers (164/164, 0 missing, 10/10 four-form) are measurements, not estimates
- Criterion-4 gap list and its three fixes: **HIGH** — each gap is a quoted line of source, and each fix is traced to a verified SDK option or generated symbol (`preferred-supported-locales` help text, `supportedLocales.first` fallback line, `lookupAppLocalizations` body)
- Date-symbol availability for a new language: **HIGH** — traced from `GlobalMaterialLocalizations.load` into `loadDateIntlDataIfNotLoaded`, quoted in full
- Riverpod auto-retry root cause, timing, and fix: **HIGH** — the exact `AsyncLoading`-with-error return, the `when` precedence, and `defaultRetry`'s constants were all read from the installed 3.4.2 sources; the 38.2 s figure is arithmetic over those constants
- Instant-propagation analysis: **HIGH** for the mechanism (`Localizations` above `Navigator`, `IndexedStack` mounts all tabs, no `initState` caching in the tree today); the propagation tests (V-6) exist to convert it from analysis to proof
- Font gap and options: **HIGH** for the facts (cmap parse + upstream subsets + measured byte sizes); the *choice* is deliberately left to the user
- Settings screen design: **MEDIUM** — no mockup exists; the structure is derived from in-repo idioms and the copy is newly authored (A1, A2, A3)
- RTL-readiness: **HIGH** for the widget layer (grep-clean), **explicitly unresolved** for the four `CustomPainter`s (E-9)

**Research date:** 2026-08-16
**Valid until:** 2026-09-15 (30 days — Flutter 3.47 is current stable, the dependency set is locked and pinned in `pubspec.lock`, and nothing here depends on a fast-moving package. The one time-sensitive item is the `google/fonts` `main`-branch metadata, which should be re-checked if the font decision is deferred)
