# `test_release/` — the pre-release gate

Two checks that are worth running, and are not worth running on every edit.

```
flutter test test_release/
```

Run it **before a production build**. Nothing else runs it.

## Why these two are not in `test/`

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

## If a cell goes red

- **A vocabulary hit** is either a real copy problem or a bad stem. Fix the
  ARB. If the stem itself is wrong — it fires on correct copy — say so out
  loud when you change it, and say what replaced it. A stem quietly deleted to
  turn this green is how a gate stops being one.
- **A layout exception** is fixed by correcting the surface's computed extent
  or making the child flexible. Never by shrinking the text, and never by
  dropping a language or a scale from the matrix.
