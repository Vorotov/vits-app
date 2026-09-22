# `test_release/` — the pre-release gate

Four checks that are worth running, and are not worth running on every edit.

```
flutter test test_release/
```

Run it **before a production build**. Nothing else runs it.

## Why these are not in `test/`

`flutter test` with no arguments runs `test/` and nothing else, so this
directory is skipped by construction on the everyday loop — and picked up by
the command above. That is the whole mechanism. It is a directory rather than a
`@Tags` annotation or a `dart_test.yaml` filter on purpose: a tag or a config
entry can be switched off by editing one line in a file nobody reads at review
time, and a sibling directory cannot.

The everyday suite keeps covering `uk` and `en` exactly as it did before — the
fast copy gate (`test/l10n/planner_copy_safety_test.dart`) and the twenty-four
`['uk','en']` render loops across `test/` are untouched.

## What lives here

**`copy_safety_all_locales_test.dart`** — the medical-claim vocabulary gate,
across **all seven** shipped languages. It renders the whole
planner/onboarding/hint surface through the delegate once per language and
scans it against a per-language stem list supplied by that language's
translator, plus the shared uk/en list imported from the fast gate. It is slow,
and it goes red for an *editorial* reason (a translator's word choice), which is
not a signal anyone should get mid-edit.

The locale list is derived from `lib/core/l10n/arb/`, so an eighth language is
swept the day its ARB lands. Its stem list is not derivable — a separate test
here says so out loud when one is missing.

**`legal_copy_safety_test.dart`** — the same idea over the published legal
documents, `docs/legal/privacy.md` and `docs/legal/terms.md`: no health or
medical vocabulary in any phrasing, and only known placeholders. The set of
documents is derived (every undated `.md` in `docs/legal/`), so a research
note keeps its date prefix or it gets swept. Its stem list is deliberately
not the ARB gate's limit vocabulary: "limitation of liability" is legal
English, not a dose claim.

**`locale_matrix_all_test.dart`** — every main screen, in all seven languages,
at text scales 1.0 / 1.6 / 2.0: Stack, Today, the planner in both segments
(Цикли and Рік, each scrolled far enough to build the cards below the fold),
and the pushed Settings route. It asserts one thing — no layout exception —
because in a release build an overflow is a clipped label, not a debug stripe.

Arabic runs under **real RTL**: `WidgetsApp` derives the reading direction from
the locale, and the sweep asserts the tree it laid out was actually
right-to-left. This is the only whole-screen RTL coverage in the repository.

Not covered by the sweep, stated here so nobody assumes otherwise: the
onboarding screens and first-run hints (suppressed by the seeded preferences —
they have their own suites in `test/features/`), the regimen editor, the
add-supplement sheet, the dose action sheet, and the planner's week and month
detail sheets.

## `purchase_release_test.dart`

Two assertions about the release that sells something.

**The iOS SDK key is filled in.** `lib/core/purchases/revenuecat_key.dart`
ships with an empty placeholder, and empty is a legitimate state of the tree:
the app launches, the support screen says tips are unavailable, and nothing
crashes. That is precisely why it belongs here and not in `test/`. A build
uploaded with an empty key looks, from every angle a debug run can see, exactly
like a build that works — and from the outside, a permanently unavailable tip
screen is indistinguishable from a store outage. This is the one gate that
catches it, and it catches it at the only moment worth catching it.

The prefix checks that refuse a `test_`-prefixed RevenueCat Test Store key run
on every ordinary `flutter test`, in `test/purchases/revenuecat_key_test.dart`.
They are not here, because they are cheap and because shipping one is a
disaster rather than an oversight.

**The Android key is deliberately absent.** Not a placeholder left behind:
Android ships after the hackathon, and Play's twelve-testers-for-fourteen-days
clock has not been started. When it is, this is the assertion to invert.

## If a cell goes red

- **A vocabulary hit** is either a real copy problem or a bad stem. Fix the
  ARB. If the stem itself is wrong — it fires on correct copy — say so out
  loud when you change it, and say what replaced it. A stem quietly deleted to
  turn this green is how a gate stops being one.
- **A layout exception** is fixed by correcting the surface's computed extent
  or making the child flexible. Never by shrinking the text, and never by
  dropping a language or a scale from the matrix.
