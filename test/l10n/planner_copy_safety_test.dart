/// The PLAN-04 copy gate (plan 04-02, T-04-06, 04-UI-SPEC "Forbidden
/// vocabulary").
///
/// The liability surface of this phase is editorial, not technical: nothing on
/// the planner may describe the 5-substance limit as safe, normal, a medical
/// standard or an overdose threshold. That rule is enforced HERE, over the
/// actually-loaded localizations of BOTH locales, rather than by a reviewer
/// reading the ARB diff — a reviewer sees this commit once, this test sees
/// every commit after it.
///
/// Loaded through the delegate with no widget pump (01-RESEARCH Pattern 6).
library;

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
/// form appears legitimately INSIDE shipped copy: `weekNoteOverLimit` reads
/// "Варто зсунути старт частини з них". A case-insensitive match would fail
/// on correct, approved copy and the gate would be deleted as noisy — which is
/// precisely how a real gate stops protecting anything.
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
];

/// Terms permitted ONLY inside `plannerDisclaimer`'s own negation.
///
/// The disclaimer's whole job is to say the limit is "не медичний норматив" /
/// "not a medical standard"; the words are forbidden everywhere else, because
/// anywhere else they would assert what the disclaimer denies.
const negationOnlyVocabulary = <String>[
  'норма', // also catches "норматив"
  'medical standard',
];

/// Keys allowed to carry [negationOnlyVocabulary].
const negationBearingKeys = <String>{'plannerDisclaimer'};

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
  plural('cyclesCount', l10n.cyclesCount);
  plural('periodsCount', l10n.periodsCount);

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
    'limitBadge': l10n.limitBadge(5),
    'legendTaking': l10n.legendTaking,
    'legendPlanned': l10n.legendPlanned,
    'legendPaused': l10n.legendPaused,
    'loadChartTitle': l10n.loadChartTitle,
    'loadChartMeta': l10n.loadChartMeta,
    'loadAxisLegend': l10n.loadAxisLegend(5, 3),
    'weekLoadLabel': l10n.weekLoadLabel(4, 5),
    'weekFreeSlots': l10n.weekFreeSlots(1),
    'weekNoFreeSlots': l10n.weekNoFreeSlots,
    'verdictComfort': l10n.verdictComfort,
    'verdictLimit': l10n.verdictLimit,
    'verdictOverLimit': l10n.verdictOverLimit,
    'weekNoteComfort': l10n.weekNoteComfort,
    'weekNoteLimit': l10n.weekNoteLimit,
    'weekNoteOverLimit': l10n.weekNoteOverLimit('C'),
    'peakMonth': l10n.peakMonth('M'),
    'peakMonthsTie': l10n.peakMonthsTie('M'),
    'yearLegendHint': l10n.yearLegendHint,
    'monthMeta': l10n.monthMeta('N', 5),
    'monthStateTaking': l10n.monthStateTaking,
    'monthStatePlanned': l10n.monthStatePlanned,
    'monthStatePartial': l10n.monthStatePartial,
    'monthEmpty': l10n.monthEmpty,
    'emptyPlannerTitle': l10n.emptyPlannerTitle,
    'emptyPlannerBody': l10n.emptyPlannerBody,
    'emptyPlannerBodyNoRegimen': l10n.emptyPlannerBodyNoRegimen,
    'plannerLoadError': l10n.plannerLoadError,
    'plannerDisclaimer': l10n.plannerDisclaimer,
    'yearFootnote': l10n.yearFootnote(5),
    'ganttRowSemantics': l10n.ganttRowSemantics('N', 'S', 'P'),
    'ganttRowSemanticsPaused': l10n.ganttRowSemanticsPaused('N', 'S', 'P'),
    'yearLegendEntrySemantics': l10n.yearLegendEntrySemantics('N', 'P'),
    'weekBarSemantics': l10n.weekBarSemantics('R', 'L'),
    'monthCardSemantics': l10n.monthCardSemantics('M', 'C'),
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

      test('names a medical standard ONLY to deny it, and only in the '
          'disclaimer', () {
        final hits = <String>[];
        copy.forEach((key, value) {
          // Plural samples are keyed "name(n)"; strip the sample suffix.
          final arbKey = key.split('(').first;
          if (negationBearingKeys.contains(arbKey)) return;
          for (final term in negationOnlyVocabulary) {
            if (_contains(value, term)) hits.add('$key contains "$term"');
          }
        });

        expect(hits, isEmpty,
            reason: 'PLAN-04: "норма/норматив" / "medical standard" may '
                'appear only inside plannerDisclaimer\'s own negation. '
                'Anywhere else the word asserts exactly what the disclaimer '
                'denies. Offenders: $hits');
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

  test('the over-limit note ships truncated — the fat-soluble clause is '
      'never restored (M2, PF-5)', () async {
    final uk = await AppLocalizations.delegate.load(const Locale('uk'));
    expect(uk.weekNoteOverLimit('2 цикли'), endsWith('із лікарем.'),
        reason: 'the mockup sentence continues with a pharmacological claim '
            'about fat-soluble forms; if the truncation ever reads oddly the '
            'final sentence is REWRITTEN, never re-extended');
  });
}
