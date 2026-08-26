---
name: boostque-design
description: Use when designing or building ANY user-visible Flutter UI in the Boostque app — new screens, widgets, copy, colours, spacing, or edits to existing ones. Encodes the design system, the machine-enforced rules, and the copy constraints that carry liability.
---

# Boostque design

The visual language is not yours to invent. It exists, it is transcribed
from an approved artefact, and most of it is enforced by tests that will
fail your commit. Read this before writing a widget.

## Where the truth lives

| Thing | File | Status |
|---|---|---|
| The approved design | `claude_design_mockup/Boostque v0.1.dc.html` | 5 screens, Ukrainian-first. The source every token cites. |
| Colours, radii, spacing | `lib/core/theme/tokens.dart` | The only place a hex literal may appear. |
| `ThemeData` | `lib/core/theme/theme.dart` | Built exclusively from tokens; contains zero hex literals itself. |
| Shared widgets | `lib/core/widgets/` | `BqNavBar`, `BqAddFab`, `BqSegmented`, `BqSettingsGearRow`. |
| Copy | `lib/core/l10n/arb/app_en.arb` (template, carries `@` metadata) and `app_uk.arb` | |

Read `tokens.dart` before choosing a colour. It is ~220 lines and every
token carries a doc comment naming its mockup line. If what you need is
not there, see **Adding a token** below — do not reach for a hex.

## Rules a test already enforces

Breaking one of these is a failing build, not a review comment. The test
is named so you can read what it actually checks rather than guess.

- **Token-only colour.** No hex literal outside `tokens.dart`.
  → `test/theme/theme_test.dart` pins every token to its mockup value.
- **Zero hardcoded user-visible strings.** No translatable literal in a
  `Text(`, `label:`, `tooltip:`, `hintText:`, `semanticsLabel:`, `title:`…
  → `test/l10n/no_hardcoded_strings_test.dart`, a source-glob gate over `lib/`.
- **Full ARB parity, all four Ukrainian CLDR plural forms** (one/few/many/
  other, including the 11–14 exception). Plural-bearing keys are found by
  parsing the template, not from a hand-list.
  → `test/l10n/arb_parity_test.dart`.
- **A new language is one ARB file and no code change.** No
  `switch (languageCode)` anywhere; the shipped language set is derived
  from the arb directory, not written down.
  → `test/l10n/new_language_contract_test.dart`.
- **Casing goes through `bqUpperCase`.** Dart's `toUpperCase()` is not
  locale-aware and this app has four uppercased labels.
  → `test/l10n/casing_test.dart`.
- **No safety / interaction / pharmacological vocabulary in planner copy,
  in either locale** — and since PLAN-05, no naming of a limit, threshold,
  verdict or reference line, because the planner no longer has one.
  → `test/l10n/planner_copy_safety_test.dart`.

## Rules nothing enforces — these are on you

- **Direction-neutral padding.** Use `EdgeInsetsDirectional`. Plain
  `EdgeInsets` is allowed only where it is genuinely neutral — `.zero`,
  `.all()`, `.symmetric(vertical:)`. Never `.only()`, `.fromLTRB()` or
  `.symmetric(horizontal:)`. `lib/` currently holds 57 directional uses
  and 5 neutral ones; keep that record clean.
- **No fixed-width text containers.** Ukrainian runs ~30% longer than
  English and both must fit. Flex, wrap, or let it grow — never clamp a
  width and never let a label ellipsize as a layout strategy.
- **Every new screen renders at textScaler 1.0, 1.6 and 2.0 in both
  locales with no overflow.** This is the single most common defect in
  this codebase's review history. Add the test with the screen, not after.
  Copy the shape from the `bilingual render matrix` group in
  `test/features/today_screen_test.dart`.
- **Minimum 44px tap targets**, and no dead strip inside a row that looks
  tappable but hit-tests to nothing (a real Phase 6 defect: destinations
  shrink-wrapped to 38dp inside a 56dp bar).
- **Accessibility parity.** Anything reachable by gesture must also be a
  labelled `CustomSemanticsAction` — and if you remove the gesture, remove
  the action with it, or the screen-reader path becomes a way to do what
  the tap cannot.
- **No elevation.** This app has none, anywhere, in any state. A shadow
  you add is the first one in the product.

## Copy constraints

These carry liability, not taste.

- **Never medical.** No claim about safety, efficacy, interaction, or
  risk. The 5-substance concept was editorial and has been deleted
  entirely (PLAN-05) — do not reintroduce the vocabulary.
- **Never guilt-framed.** An unmarked dose is stated neutrally
  (`не позначено` / "not marked" — deliberately not "skipped", because the
  app does not know what happened). No streak shaming, no red for a missed
  day, no aggressive reminders. Cycle-off weeks must never read as failure.
- **Warn palette is today-gated.** `BqColors.warn*` may only render for
  something actually actionable right now. A past or future day gets
  neutral treatment.
- **Ukrainian first.** Write the Ukrainian copy as the real copy; English
  is the template file but not the design language.

## Adding a token

1. Find the value in the mockup HTML and note its line number.
2. Add it to the right `abstract final class` in `tokens.dart` with a doc
   comment citing that line and what it styles.
3. Pin it in `test/theme/theme_test.dart`.
4. Only then reference it.

If the mockup has no such value, say so in the doc comment
("Claude's-discretion addition") and justify it. Several tokens already
do this honestly; silent invention is the thing to avoid.

## Before you build a new widget

Check `lib/core/widgets/` and the feature directories first — this
codebase prefers reusing a component over a near-duplicate. Bespoke
layouts (the gantt, the year matrix, the week strip) are hand-built from
`Row`/`Stack`/`CustomPaint` on purpose; do not reach for a charting or
calendar package to replace one.

## Checklist

- [ ] Every colour is a `BqColors` reference
- [ ] Every user-visible string is an ARB key, in both locales
- [ ] Ukrainian plurals carry all four forms
- [ ] Padding is directional; no fixed-width text container
- [ ] Renders clean at 1.0 / 1.6 / 2.0 in uk and en, with a test
- [ ] Tap targets ≥ 44px, no dead strips
- [ ] Gesture actions have semantics equivalents
- [ ] Copy makes no medical claim and assigns no blame
- [ ] `flutter analyze` clean, full suite green
