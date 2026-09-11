---
name: vitomy-design
description: Use when designing or building ANY user-visible Flutter UI in the VitoMy app — new screens, widgets, copy, colours, spacing, or edits to existing ones. Encodes the design system, the machine-enforced rules, and the copy constraints that carry liability.
---

# VitoMy design

The visual language is not yours to invent. It exists, it is transcribed
from an approved artefact, and most of it is enforced by tests that will
fail your commit. Read this before writing a widget.

## Where the truth lives

| Thing | File | Status |
|---|---|---|
| The approved design | `claude_design_mockup/VitoMy v0.1.dc.html` | 5 screens, Ukrainian-first. The source every token cites. |
| Colours, radii, spacing | `lib/core/theme/tokens.dart` | The only place a hex literal may appear. |
| `ThemeData` | `lib/core/theme/theme.dart` | Built exclusively from tokens; contains zero hex literals itself. |
| Shared widgets | `lib/core/widgets/` | `BqNavBar`, `BqAddFab`, `BqSegmented`, `BqSettingsGearRow`, `BqHintCard`. |
| Copy | `lib/core/l10n/arb/` — seven files, 177 keys each | `app_en.arb` is the template and the only one carrying `@` metadata. |
| Clock times | `lib/core/l10n/clock_format.dart` | One formatter for every time the app shows. |

Read `tokens.dart` before choosing a colour. It is ~220 lines and every
token carries a doc comment naming its mockup line. If what you need is
not there, see **Adding a token** below — do not reach for a hex.

## Seven languages, and English is the source

The app ships **en, ar, es, fr, hi, uk, zh**. `app_en.arb` is the template:
it carries the `@` metadata, every other file is a translation of it, and
translation length budgets are measured against the English string.
English is also the fallback for any unsupported system language —
`preferred-supported-locales: [en]` in `l10n.yaml` is what makes it
`supportedLocales.first`, and without that line gen-l10n sorts
alphabetically and the fallback silently moves.

Ukrainian is still the mockup's language and a first-class shipped locale;
the fast copy gate and most render matrices in `test/` run uk + en. But new
copy is written in the template first, and the other six follow.

Adding a language is **one ARB file and no code change**. Never write a
`switch (languageCode)`.

### Three of the seven have no letter case

Arabic, Hindi and Chinese have no upper/lower distinction at all. Twelve
keys are stored ALL CAPS in the English and Ukrainian ARBs —
`supplementsLabel`, `periodicityLabel`, `timeSlotsLabel`, `loadChartTitle`,
`pausedBadge`, the five `status*` chips, `settingsLanguageTitle`,
`settingsRemindersTitle` — and the app never uppercases them at runtime, so
in those three languages they arrive as ordinary text. **The mono
small-caps eyebrow carries no typographic signal there.** Weight, size and
colour are the only differentiators left on those rows. If a layout's
readability depends on an eyebrow reading as an eyebrow, it is broken in
three of seven languages — give it a second cue.

(Separately, four *date* labels — the week strip's weekday abbreviation, the
gantt month header, the year-grid card label and the month-detail title —
are uppercased at runtime, and only through `bqUpperCase`.)

### No new fonts are bundled

`pubspec.yaml` declares exactly two families: `Instrument Sans` and
`JetBrains Mono`, as local variable-font assets. Neither covers Arabic,
Devanagari or Han, so those scripts render in the **platform's own
typeface** — with its own metrics, its own line height and its own idea of
what a "mono" fallback is. Do not add a font to fix this without a decision;
do not build a layout that only works at Instrument Sans's metrics.

## Arabic ships, so RTL is real

Direction-neutral padding is no longer aspirational. `WidgetsApp` derives
the reading direction from the active locale, so an Arabic build is
genuinely right-to-left and every `.only()` or `.symmetric(horizontal:)`
you write is a visible bug in a shipped language.

`lib/` currently holds **66 `EdgeInsetsDirectional` uses and 6 genuinely
neutral plain ones** — four `EdgeInsets.zero`, one `EdgeInsets.all(2)`, one
`EdgeInsets.symmetric(vertical: 9)`. That record is clean; keep it clean.
Nothing enforces it.

**The one painter that had to be mirrored.** Chrome built from `Row`,
`PositionedDirectional` and directional padding flips for free. A `Canvas`
does not — it has no reading direction and nothing hands it one. The Цикли
gantt's `_GanttRowPainter` (`lib/features/calendar/planner_gantt.dart`)
mapped `startFraction` to an offset from the left edge unconditionally, so
in Arabic the bars ran left-to-right underneath a right-to-left header and
every bar pointed at the wrong month — a chart stating something false, not
a cosmetic slip. It now takes the `TextDirection` from `Directionality`,
mirrors the x mapping inside the painter (not via a `Transform`, which would
flip the hatch and any future glyph too), mirrors the 45° hatch, passes the
same flag to the legend swatch, and compares direction in `shouldRepaint`.

`test/features/planner_gantt_rtl_test.dart` proves it, and is written to be
copied: an explicit `Directionality` inside the app (so the test does not
change verdict when an ARB lands or is pulled), the same model pumped both
ways, and assertions on **geometry** replayed onto a recording canvas rather
than on a golden image. If you write a `CustomPainter` that positions
anything horizontally, it needs the same treatment and the same shape of
test.

## One-time hints, never a tour

`BqHintCard` (`lib/core/widgets/bq_hint_card.dart`) plus `BqHint` /
`firstRunHintsProvider` (`lib/features/onboarding/first_run_hints.dart`).

**The research, because it decides the rule.** NN/g's 70-participant test
found that reading an intro tutorial left users rating the *same* tasks
harder (4.92 vs 5.49 of 7) with no gain in success or speed — a deck makes a
simple app feel complicated. Coach marks fired in sequence at session start
fail for the same reason: the explanation arrives before the user has any
need for it.

So:

- A hint appears **at the moment its subject first appears on screen**, and
  only then. `BqHint.cycle` renders beside the on/off week sliders in the
  regimen editor; `BqHint.markDose` renders above a day that actually has
  doses, which means only once a supplement exists.
- It is an **inline card in the layout**, not an overlay. It dims nothing,
  blocks nothing, steals no focus and pushes nothing off screen. It is
  accent-tinted so it reads as an annotation rather than as content to act
  on.
- It appears **once**. Dismissing is permanent, and the dismiss control is a
  real 44px target with a `Semantics` label.
- **Never chain hints into a sequence.** Two hints firing one after another
  is the deck this design replaced.
- Put the card inside the screen's scrolling body, not a fixed column above
  it. A longer translation of a hint once overflowed the Today screen's
  fixed header by 8px at textScaler 2.0.

Read the hint's visibility off the **state**:
`showsHint(ref.watch(firstRunHintsProvider), BqHint.markDose)`. Watching
`.notifier` rebuilds only when the notifier instance changes — that shipped
as a real defect where dismissing a hint updated the set and left the card
on screen.

## One clock format

Every time the app displays is zero-padded 24-hour, in every language.
Call `formatClock(context, minutesFromMidnight)` — or `formatClockIn(locale,
…)` where you hold a `Locale` rather than a `BuildContext`. Never
`MaterialLocalizations.formatTimeOfDay`, never a bare `DateFormat.Hm`.

`alwaysUse24HourFormat` only picks between the 12- and 24-hour patterns CLDR
holds for a locale; it does not make them agree. Spanish's is `H:mm`, so
`08:00` rendered as `8:00` on the Today screen, in the dose sheet, in the
regimen editor and in the notification body while every neighbouring time
kept its zero. The pattern is therefore **pinned, not asked for**. The
locale is still passed, so a language whose numbering system is not Latin
renders its own digits — the shape is fixed, the script is not.

## Rules a test already enforces

Breaking one of these is a failing build, not a review comment. The test is
named so you can read what it actually checks rather than guess.

- **Token-only colour.** No hex literal outside `tokens.dart`.
  → `test/theme/theme_test.dart` pins every token to its mockup value.
- **Zero hardcoded user-visible strings.** No translatable literal in a
  `Text(`, `label:`, `tooltip:`, `hintText:`, `semanticsLabel:`, `title:`…
  → `test/l10n/no_hardcoded_strings_test.dart`, a source-glob gate over `lib/`.
- **Full ARB key parity, and every language's own CLDR plural categories** —
  derived by probing `Intl.pluralLogic`, not hand-listed, so Arabic needs all
  six (zero/one/two/few/many/other), Ukrainian four and Chinese only `other`.
  → `test/l10n/arb_parity_test.dart`; rendered output at 1/2/5/11/21 in
  `test/l10n/plurals_test.dart`.
- **A new language is one ARB file and no code change.** No
  `switch (languageCode)` anywhere; the shipped set is derived from the arb
  directory in every representation that names it.
  → `test/l10n/new_language_contract_test.dart`.
- **English is the fallback, by name.** → `test/l10n/locale_resolution_test.dart`.
- **Casing goes through `bqUpperCase`.** Dart's `toUpperCase()` is not
  locale-aware; Turkish/Azeri dotted-i is the one handled exception.
  → `test/l10n/casing_test.dart`.
- **Every displayed time is zero-padded 24-hour, in every shipped locale**,
  UI and notification body alike.
  → `test/l10n/clock_format_test.dart`, looping `supportedLocales`.
- **Ukrainian month names use the standalone (nominative) form** — every
  planner month stands without a day number.
  → `test/l10n/month_names_test.dart`.
- **No safety / interaction / pharmacological vocabulary in planner copy,
  and no naming of a limit, threshold, verdict or reference line** (PLAN-05
  deleted the limit, so copy may not name one).
  → `test/l10n/planner_copy_safety_test.dart` for uk + en on every run;
  `test_release/copy_safety_all_locales_test.dart` for all seven, against
  per-language stem lists, before a release.
- **Every main screen renders in all seven languages at textScaler 1.0 /
  1.6 / 2.0 with no layout exception** — Stack, Today, both planner segments,
  Settings — with Arabic under real locale-derived RTL.
  → `test_release/locale_matrix_all_test.dart` (`flutter test test_release/`,
  run before a production build).
- **The gantt track mirrors under RTL and agrees with its month header.**
  → `test/features/planner_gantt_rtl_test.dart`.
- **The FAB and the nav bar carry zero elevation in every state.**
  → `test/theme/theme_test.dart`, `test/core/widgets/bq_add_fab_test.dart`.
- **The nav bar's destinations and the settings gear are ≥44px.**
  → `test/core/widgets/bq_nav_bar_test.dart`,
  `test/core/widgets/bq_settings_gear_row_test.dart`.

## Rules nothing enforces — these are on you

- **Direction-neutral padding.** Use `EdgeInsetsDirectional`. Plain
  `EdgeInsets` is allowed only where it is genuinely neutral — `.zero`,
  `.all()`, `.symmetric(vertical:)`. Never `.only()`, `.fromLTRB()` or
  `.symmetric(horizontal:)`. Counts above; no gate.
- **Any horizontal geometry you compute yourself** — a `CustomPainter`, an
  `Offset`, a `Transform`, a manual `left:` — must read `Directionality.of`.
  The gantt is the only painter that has been through this.
- **No fixed-width text containers.** Ukrainian runs ~30% longer than
  English; Hindi and Arabic have their own outliers, and non-Latin scripts
  render in the platform font with different metrics. Flex, wrap, or let it
  grow — never clamp a width and never let a label ellipsize as a layout
  strategy.
- **Every new screen renders at textScaler 1.0, 1.6 and 2.0 in both locales
  with no overflow.** This is the single most common defect in this
  codebase's review history. The release matrix covers the five main screens
  only — sheets, the regimen editor and the planner detail sheets are
  explicitly not in it (see `test_release/README.md`). Add the test with the
  screen, not after; copy the shape from the `bilingual render matrix` group
  in `test/features/today_screen_test.dart`.
- **Minimum 44px tap targets** everywhere, not only where a test says so, and
  no dead strip inside a row that looks tappable but hit-tests to nothing (a
  real Phase 6 defect: destinations shrink-wrapped to 38dp inside a 56dp bar).
- **Accessibility parity.** Anything reachable by gesture must also be a
  labelled `CustomSemanticsAction` — and if you remove the gesture, remove the
  action with it, or the screen-reader path becomes a way to do what the tap
  cannot.
- **No elevation.** The FAB and nav bar are pinned; nothing gates the rest.
  This app has no elevation anywhere, in any state. A shadow you add is the
  first one in the product.

## Copy constraints

These carry liability, not taste.

- **Never medical.** No claim about safety, efficacy, interaction, or risk.
  The 5-substance concept was editorial and has been deleted entirely
  (PLAN-05) — do not reintroduce the vocabulary. This survives translation:
  each language's copy avoids its own physiological register, not just the
  English words. Hindi uses "भार" (the measurement word) rather than "बोझ" (a
  burden the body carries); Chinese avoids 疗程, the ordinary word for a
  course of *treatment*, and any word for strain. When you commission or
  write a translation, say in the commit which word you avoided and why.
- **Never guilt-framed.** An unmarked dose is stated neutrally (`не
  позначено` / "not marked" — deliberately not "skipped", because the app does
  not know what happened). No streak shaming, no red for a missed day, no
  aggressive reminders. Cycle-off weeks must never read as failure. An
  overdue chip describes the clock, never a consequence.
- **Warn palette is today-gated.** `BqColors.warn*` may only render for
  something actually actionable right now. A past or future day gets neutral
  treatment.
- **Address the user impersonally.** No first-person plural, no passive
  voice where an active clause fits. Prose em dashes were removed from the
  whole ARB set; dashes that separate a date range stay, and `·` is a house
  separator.
- **Never compose a sentence from localized fragments.** Word order differs.
  One key, one sentence.

## Adding a token

1. Find the value in the mockup HTML and note its line number.
2. Add it to the right `abstract final class` in `tokens.dart` with a doc
   comment citing that line and what it styles.
3. Pin it in `test/theme/theme_test.dart`.
4. Only then reference it.

If the mockup has no such value, say so in the doc comment
("Claude's-discretion addition") and justify it. Several tokens already do
this honestly; silent invention is the thing to avoid.

## Before you build a new widget

Check `lib/core/widgets/` and the feature directories first — this codebase
prefers reusing a component over a near-duplicate. Bespoke layouts (the
gantt, the year matrix, the week strip) are hand-built from
`Row`/`Stack`/`CustomPaint` on purpose; do not reach for a charting or
calendar package to replace one.

Note also that a widget test which pumps a screen holding first-run state
must seed `SharedPreferences` (`onboarding_seen`, `first_run_hints_seen`)
and override `sharedPreferencesProvider`, or the intro or a hint card turns
up inside an unrelated assertion. And never `pumpAndSettle` a tree
containing the app shell or the Today screen — a live midnight `Timer` makes
it hang or pass for the wrong reason. Both rules are in `.claude/CLAUDE.md`
under Conventions → Testing.

## Checklist

- [ ] Every colour is a `BqColors` reference
- [ ] Every user-visible string is an ARB key, in all seven files
- [ ] Each language carries its own CLDR plural categories
- [ ] Every displayed time goes through `formatClock` / `formatClockIn`
- [ ] Padding is directional; any painter reads `Directionality.of`
- [ ] No fixed-width text container; nothing depends on Instrument Sans metrics
- [ ] Nothing depends on an ALL-CAPS label reading as an eyebrow
- [ ] Renders clean at 1.0 / 1.6 / 2.0 in uk and en, with a test
- [ ] Tap targets ≥ 44px, no dead strips, no elevation
- [ ] Gesture actions have semantics equivalents
- [ ] A hint, if any, appears where its subject does — once, inline, dismissible
- [ ] Copy makes no medical claim and assigns no blame, in every language
- [ ] `flutter analyze` clean, `flutter test` green, `flutter test test_release/` green before a release
