/// Shared bilingual-assertion helpers for the Phase-5 render matrix
/// (plan 05-04, L10N-01, RESEARCH V-4 / A8, threat T-05-08).
///
/// Every other test file in this repository is self-contained, and that is
/// deliberate house style. This file is the one exception, for one reason: the
/// Cyrillic-leak allowlist below would otherwise be copied into four suites,
/// and a four-way copy of an allowlist is four places to get an exception
/// wrong — the entry added to three files and forgotten in the fourth is a
/// gate that has quietly stopped gating. The named consequence strings live
/// here for the same reason: a `reason:` that drifts between files stops
/// naming one defect class.
///
/// This is a LIBRARY, not a test — it declares no `main()`, so `flutter test`
/// never runs it on its own; it only compiles as part of the suites that
/// import it.
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// The consequence of a red `takeException()` case, named in device terms
/// rather than as a restatement of the assertion (the `overflowReason` idiom
/// from `planner_screen_test.dart`).
const String overflowReason =
    'a layout exception at an accessibility text scale is a clipped label or a '
    'dropped element in RELEASE — not debug stripes. This is the CR-01 / '
    'WR-04 defect class Phase 3 shipped twice, and the six surfaces in this '
    'matrix had ZERO English render coverage before plan 05-04; the fix is a '
    'computed extent or a flexible child, never a relaxed assertion';

/// The consequence of a Cyrillic character reaching the tree while English is
/// the active language.
const String cyrillicLeakReason =
    'a Cyrillic string reached the widget tree while en was active, so an '
    'English-speaking user is reading Ukrainian copy on a screen the ARB '
    'audit reported as fully translated. This is the failure mode grep cannot '
    'see — a literal that escaped the ARB INSIDE an interpolation still '
    'renders, and only a rendered sweep catches it (T-05-08)';

/// The single A8 allowlist: `Text` payloads that are legitimately Cyrillic
/// while English is the active language.
///
/// Matched by exact, whole-string equality, never as a substring and never by
/// loosening the regex — adding an entry here is a visible decision made in
/// ONE place, which is the entire reason this file exists. If a future screen
/// needs an exception, it gets a line below with its own rationale.
///
/// Entries:
/// 1. `Українська` — a language's own endonym. The language picker renders
///    every shipped language in its OWN script (`languageName`, P-2), so the
///    Ukrainian row reads "Українська" no matter which language is active;
///    translating it would defeat the point of an endonym.
/// 2. `Русский` — the same rule, for Russian. Correct copy, not a leak: once
///    `app_ru.arb` ships, any English-locale test that renders the picker sees
///    this row in Cyrillic and would trip the sweep on a string that is right.
///    Listed for the endonym reason ONLY — a Russian message anywhere outside
///    the picker is still a leak, and the sweep still catches it, because
///    matching is whole-string.
const List<String> cyrillicAllowlist = <String>['Українська', 'Русский'];

/// The text scales every render matrix in this repository sweeps.
///
/// Hoisted here from `app_shell_test.dart` by plan 06-01 for the same reason
/// the allowlist above lives here: a per-file literal is a per-file decision,
/// and the file that quietly omits a scale has a matrix that no longer covers
/// it. The 2.0 row is what NAV-01 needs — `navBarHeightFor` has to hold at the
/// worst realistic accessibility setting, not just at the 1.6 the Phase-5
/// matrix stopped at. 1.0 is the mockup-exact baseline; 1.6 and 2.0 are the
/// two scales the CR-01 / WR-04 defects actually reproduced at.
///
/// A cell that clips is fixed by correcting the surface's computed extent,
/// never by shrinking its text and never by dropping a row from this list.
const List<double> bqTextScaleMatrix = <double>[1.0, 1.6, 2.0];

/// The locales every render matrix sweeps: the Ukrainian-first default and the
/// English translation that had zero render coverage before plan 05-04.
const List<String> bqLocaleMatrix = <String>['uk', 'en'];

/// A character in the Cyrillic block, the V-4 leak probe.
final RegExp _cyrillic = RegExp(r'[Ѐ-ӿ]');

/// Asserts that no rendered `Text` in the current tree carries a Cyrillic
/// character, apart from the named [cyrillicAllowlist] entries.
///
/// Call this ONLY in cases where English is the active language — in a
/// Ukrainian case it would fail on every correct string.
///
/// WHAT THIS DOES NOT COVER. The name says Cyrillic and English, and both
/// halves are limits, not incidental detail:
///
/// * It runs only while `en` is active. Every shipped language is a possible
///   ACTIVE language and so a possible victim of a leak, and this sweep
///   inspects exactly one of them — a Ukrainian string surfacing on the
///   Spanish build is invisible here, and so is an English one surfacing
///   anywhere. Widening it is not a matter of relaxing this function: a
///   general sweep needs a per-language script expectation, which the ARBs do
///   not carry today.
/// * It detects Cyrillic and nothing else. Latin-script leaks between English
///   and Spanish, French or Portuguese are the likeliest of all — same script,
///   same alphabet, no probe possible — and Devanagari, Bengali, Arabic and
///   Han leaks are all equally undetected. Cyrillic is caught because it is
///   cheap to catch, not because it is the risk.
/// * With Russian shipped it can no longer tell a Ukrainian leak from correct
///   Russian: both are Cyrillic, the regex is one block, and the allowlist
///   matches whole strings, so `Русский` is exempt while a genuine Ukrainian
///   sentence on an English screen and a genuine Russian one are the same
///   signal to this code.
///
/// So: a green sweep means "no unexpected Cyrillic reached an English tree in
/// the cases that call it". It is not evidence that the screen is fully
/// translated, and it never was — that claim belongs to the ARB parity gate in
/// `test/l10n/arb_parity_test.dart`, which reads every file.
///
/// Note on user data: names the user typed or that were copied onto a
/// `Supplement` row at add-time are NOT localized copy and never re-localize
/// (E-12). Cases that seed such data therefore seed locale-neutral names, or
/// skip this sweep and say why — the sweep is about ARB-sourced chrome.
void expectNoCyrillicWhileEn(WidgetTester tester) {
  for (final text in tester.widgetList<Text>(find.byType(Text))) {
    final data = text.data ?? text.textSpan?.toPlainText();
    if (data == null || cyrillicAllowlist.contains(data)) continue;
    expect(
      _cyrillic.hasMatch(data),
      isFalse,
      reason: '$cyrillicLeakReason. Offending text: "$data"',
    );
  }
}
