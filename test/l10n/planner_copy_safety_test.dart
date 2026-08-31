/// The PLAN-04 copy gate (plan 04-02, T-04-06, 04-UI-SPEC "Forbidden
/// vocabulary").
///
/// The liability surface of this phase is editorial, not technical: no planner
/// copy may make a safety, interaction or pharmacological claim. Since PLAN-05
/// (phase 06) the gate is STRICTER still — no planner copy may name a limit at
/// all, because the planner no longer has one to name. Both halves are
/// enforced HERE, over the actually-loaded localizations of BOTH locales,
/// rather than by a reviewer reading the ARB diff — a reviewer sees this
/// commit once, this test sees every commit after it.
///
/// Loaded through the delegate with no widget pump (01-RESEARCH Pattern 6).
library;

import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:boostque/core/l10n/gen/app_localizations.dart';

/// Vocabulary that may never appear in planner copy, in either locale.
///
/// ONE place to extend. Sourced verbatim from 04-UI-SPEC "Forbidden
/// vocabulary (PLAN-04)" plus the never-ship control labels of PF-5/M3.
///
/// **Matching is CASE-SENSITIVE where an entry is capitalized, and that is
/// load-bearing.** `Зсунути` is the mockup's "Зсунути цикл" button — a
/// schedule mutation on a read-only screen that must never ship. Its lowercase
/// form is an ordinary verb that approved copy could legitimately use in a
/// sentence (`weekNoteOverLimit`, deleted in phase 06, read "Варто зсунути
/// старт частини з них"). A case-insensitive match would fail on correct copy
/// and the gate would be deleted as noisy — which is precisely how a real gate
/// stops protecting anything.
///
/// **Phase 06 widened this list and did NOT shrink it (PLAN-05).** The limit
/// stems of [limitVocabulary] are spread in at the end because the planner no
/// longer HAS a limit: there is no verdict, no badge, no reference line and no
/// threshold colour left for copy to name, so a sentence naming one describes a
/// product that does not exist. `норма` moved here out of the deleted negation
/// exemption — the rewritten disclaimer denies nothing, so nothing needs
/// permission to say it. The fat-soluble pair stays even though the sentence it
/// guarded is deleted: the guarantee outlives the sentence it was attached to.
const forbiddenVocabulary = <String>[
  // uk — 04-UI-SPEC
  'безпечн', // безпечна / безпечну / безпечний норма
  'передозування',
  'перевищено безпечну',
  'взаємодія', // M1: the `є взаємодія` legend entry never ships
  'жиророзчин', // M2: the truncated over-limit clause never returns
  'Зсунути', // M3, capitalized: the button label, not the verb in a sentence
  'Порівняти', // M3, capitalized: idem
  // en — the same claims, translated
  'overdose',
  'fat-soluble',
  'Shift cycle',
  'Compare weeks',
  'medical standard',
  // 06-UI-SPEC, PLAN-05: the limit vocabulary itself, SPREAD rather than
  // re-typed. The doc on [limitVocabulary] calls itself a subset of this list;
  // spreading is what makes that structurally true instead of a claim two
  // literals have to keep agreeing on.
  ...limitVocabulary,
];

/// The PLAN-05 subset of [forbiddenVocabulary], named on its own so the absence
/// of limit vocabulary is a stated guarantee rather than entries buried in a
/// longer list.
///
/// **BOTH locales, because the gate loops over both.** This list held only
/// Ukrainian stems while the loop that reads it ran over uk AND en, so English
/// limit copy was completely unenforced: an en string reading "over your limit"
/// or "exceeds the threshold" would have shipped green. `forbiddenVocabulary`'s
/// own English entries are about overdose and medical claims, none of which is
/// limit vocabulary, so nothing else covered it either.
///
/// The English stems are the same four ideas the Ukrainian ones cover — a
/// boundary, crossing it, the boundary's technical name, and the verdict a
/// reader would draw — not a translation word for word.
const limitVocabulary = <String>[
  // uk
  'меж', // межа / межі / межу / перевищення межі — every declined form
  'перевищ', // перевищення / перевищує
  'норма', // норма / норматив — no longer exempt anywhere
  // en
  'limit', // limit / limits / limited / unlimited
  'exceed', // exceed / exceeds / exceeded
  'threshold',
  'maximum', // deliberately not 'max': "max" is a substring of nothing here
  // today, but it is one keystroke from matching a supplement's dose text
  'too many', // the verdict a limit invites, with no limit named
];

/// True when [value] contains [term], case-sensitively for a capitalized term
/// and case-insensitively otherwise.
bool _contains(String value, String term) {
  final firstRune = term.runes.first;
  final capitalized =
      String.fromCharCode(firstRune) != String.fromCharCode(firstRune)
          .toLowerCase();
  return capitalized
      ? value.contains(term)
      : value.toLowerCase().contains(term.toLowerCase());
}

/// The planner's ARB surface, by key prefix — ONE list to extend.
///
/// The gate below reads the template ARB off disk and demands that every key
/// matching this filter is rendered into [plannerCopy]. A hand-written map
/// alone silently stops covering the copy a later phase adds — the exact
/// failure mode this file's own docstring claims not to have (WR-04). The
/// sibling gate in `planner_invariants_test.dart` globs its source files for
/// the same reason.
const plannerKeyPrefixes = <String>[
  'planner',
  'legend',
  'loadChart',
  'loadAxis',
  'loadScale',
  'week',
  'verdict',
  'peak',
  'year',
  'month',
  'emptyPlanner',
  'gantt',
  // Not planner copy, but under the same ban: the onboarding spec
  // (2026-08-26) extends this gate's vocabulary rules to every onboarding
  // key, because an intro screen is exactly where a well-meaning rewrite
  // would sneak in an efficacy promise. Same mechanism, wider surface.
  'onboarding',
];

/// Planner-rendered keys no prefix catches, because they are SHARED with
/// another surface and named for what they count, not for where they appear.
const plannerKeysExact = <String>{
  'substancesCount',
  'periodsCount',
  'disclaimerEducational',
};

/// Whether [key] names copy the planner renders.
bool isPlannerKey(String key) =>
    plannerKeysExact.contains(key) ||
    plannerKeyPrefixes.any((prefix) => key.startsWith(prefix));

/// Every planner-facing string, keyed by its ARB key.
///
/// Plural keys are sampled at 1 / 2 / 5 so a forbidden word hiding in a single
/// CLDR form cannot slip through the one form a spot check would render.
Map<String, String> plannerCopy(AppLocalizations l10n) {
  final sample = <String, String>{};
  void plural(String key, String Function(int) render) {
    for (final n in const [1, 2, 5]) {
      sample['$key($n)'] = render(n);
    }
  }

  plural('monthsCount', l10n.monthsCount);
  plural('periodsCount', l10n.periodsCount);
  plural('substancesCount', l10n.substancesCount);
  plural('weeksCount', l10n.weeksCount);

  return {
    ...sample,
    'plannerTitle': l10n.plannerTitle,
    'disclaimerEducational': l10n.disclaimerEducational,
    'plannerSegYear': l10n.plannerSegYear,
    'plannerSegCycles': l10n.plannerSegCycles,
    'plannerRangeSubtitle': l10n.plannerRangeSubtitle('A', 'B', '2026'),
    'plannerRangeSubtitleCrossYear':
        l10n.plannerRangeSubtitleCrossYear('A', '2026', 'B', '2027'),
    'plannerYearSubtitle': l10n.plannerYearSubtitle('2026', 'M'),
    'plannerThisWeek': l10n.plannerThisWeek('N'),
    'legendTaking': l10n.legendTaking,
    'legendPlanned': l10n.legendPlanned,
    'legendPaused': l10n.legendPaused,
    'loadChartTitle': l10n.loadChartTitle,
    'loadChartMeta': l10n.loadChartMeta,
    'loadScaleCaption': l10n.loadScaleCaption,
    'peakMonth': l10n.peakMonth('M'),
    'peakMonthsTie': l10n.peakMonthsTie('M'),
    'yearLegendHint': l10n.yearLegendHint,
    'monthStateTaking': l10n.monthStateTaking,
    'monthStatePlanned': l10n.monthStatePlanned,
    'monthStatePartial': l10n.monthStatePartial,
    'monthEmpty': l10n.monthEmpty,
    'emptyPlannerTitle': l10n.emptyPlannerTitle,
    'emptyPlannerBody': l10n.emptyPlannerBody,
    'emptyPlannerBodyNoRegimen': l10n.emptyPlannerBodyNoRegimen,
    'plannerLoadError': l10n.plannerLoadError,
    'plannerDisclaimer': l10n.plannerDisclaimer,
    'ganttRowSemantics': l10n.ganttRowSemantics('N', 'S', 'P'),
    'ganttRowSemanticsPaused': l10n.ganttRowSemanticsPaused('N', 'S', 'P'),
    'yearLegendEntrySemantics': l10n.yearLegendEntrySemantics('N', 'P'),
    'weekBarSemantics': l10n.weekBarSemantics('R', 'L'),
    'monthCardSemantics': l10n.monthCardSemantics('M', 'C'),
    'onboardingSkip': l10n.onboardingSkip,
    'onboardingNext': l10n.onboardingNext,
    'onboardingAddFirst': l10n.onboardingAddFirst,
    'onboardingPage1Title': l10n.onboardingPage1Title,
    'onboardingPage1Body': l10n.onboardingPage1Body,
    'onboardingPage2Title': l10n.onboardingPage2Title,
    'onboardingPage2Body': l10n.onboardingPage2Body,
    'onboardingIllustrationSemantics1': l10n.onboardingIllustrationSemantics1,
    'onboardingIllustrationSemantics2': l10n.onboardingIllustrationSemantics2,
  };
}

void main() {
  for (final tag in const ['uk', 'en']) {
    group('$tag planner copy', () {
      late AppLocalizations l10n;
      late Map<String, String> copy;

      setUpAll(() async {
        l10n = await AppLocalizations.delegate.load(Locale(tag));
        copy = plannerCopy(l10n);
      });

      test('reads EVERY planner key in the ARB — new copy cannot arrive '
          'unchecked (WR-04)', () {
        final arb = jsonDecode(
          File('lib/core/l10n/arb/app_en.arb').readAsStringSync(),
        ) as Map<String, dynamic>;
        final arbKeys = arb.keys
            .where((k) => !k.startsWith('@'))
            .where(isPlannerKey)
            .toSet();

        // A filter that matched nothing would make every assertion below
        // vacuously true, which is worse than no gate at all.
        expect(arbKeys.length, greaterThanOrEqualTo(35),
            reason: 'the prefix filter stopped resolving the planner surface. '
                '35 is the MEASURED planner-key count after phase 06 deleted '
                'the sixteen limit keys (was 51 against a floor of 40) — '
                're-derived from the ARB, never guessed downward (T-06-17)');

        // Plural samples are keyed "name(n)"; the ARB knows only "name".
        final covered = copy.keys.map((k) => k.split('(').first).toSet();
        expect(arbKeys.difference(covered), isEmpty,
            reason: 'a planner ARB key exists that the PLAN-04 gate never '
                'renders, so nothing scans it for forbidden vocabulary and '
                'nothing says so. Add it to plannerCopy() — a reviewer sees '
                'one commit, this test sees every commit after it');
        expect(covered.difference(arbKeys), isEmpty,
            reason: 'plannerCopy() renders a key the filter does not consider '
                'planner copy: either the key was renamed or the prefix list '
                'needs the new name, and a stale entry here hides the gap');
      });

      test('carries no forbidden vocabulary (PLAN-04)', () {
        final hits = <String>[];
        copy.forEach((key, value) {
          for (final term in forbiddenVocabulary) {
            if (_contains(value, term)) hits.add('$key contains "$term"');
          }
        });

        expect(hits, isEmpty,
            reason: 'PLAN-04: no planner copy may describe the 5-substance '
                'limit as safe, normal, a medical standard or an overdose '
                'threshold, and no interaction or pharmacological claim may '
                'ship. Copy that does is a store-review rejection and a '
                'liability problem, not a wording nitpick — fix the ARB, '
                'never this list. Offenders: $hits');
      });

      test('carries NO limit vocabulary at all, in any key, including the '
          'disclaimer (PLAN-05)', () {
        // The Phase-4 gate above exempted plannerDisclaimer from "норма" so
        // it could DENY a medical standard. Phase 06 deleted that exemption
        // with the sentence that needed it: the planner has no limit, so no
        // key — not even the disclaimer — has anything to deny. There is no
        // allowlist here on purpose; an unused permission is an invitation.
        final hits = <String>[];
        copy.forEach((key, value) {
          for (final term in limitVocabulary) {
            if (_contains(value, term)) hits.add('$key contains "$term"');
          }
        });

        expect(hits, isEmpty,
            reason: 'PLAN-05: the planner shows weekly concurrent load with '
                'no reference line, no verdict, no badge and no threshold — '
                'so copy naming a limit describes a product that does not '
                'exist. Fix the ARB, never this list. Offenders: $hits');
      });

      test('the disclaimer itself still frames the limit as editorial', () {
        // The gate above proves what the copy does NOT say; this proves the
        // half of PLAN-04 that has to be positively present.
        expect(l10n.plannerDisclaimer, isNotEmpty);
        expect(l10n.plannerDisclaimer.length,
            greaterThan(l10n.disclaimerEducational.length),
            reason: 'plannerDisclaimer carries the editorial framing of the '
                '5-substance limit ON TOP of the educational sentence — the '
                'bare disclaimerEducational cannot stand in for it '
                '(DECIDED-8)');
        expect(
          l10n.plannerDisclaimer.contains(l10n.disclaimerEducational),
          isTrue,
          reason: 'the disclaimer closes with the same educational sentence '
              'the rest of the app uses',
        );
      });
    });
  }

  // The standalone "the over-limit note ships truncated" test is deleted with
  // its key: `weekNoteOverLimit` no longer exists, so the test could not
  // compile. Its guarantee is NOT lost — the `жиророзчин` / `fat-soluble`
  // entries stay in [forbiddenVocabulary] above, which is what actually keeps
  // the pharmacological clause from returning, in any key, in either locale.
}
