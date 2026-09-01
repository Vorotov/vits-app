/// The medical-claim vocabulary gate, across EVERY shipped language.
///
/// WHY THIS IS NOT IN `test/`. `test/l10n/planner_copy_safety_test.dart` runs
/// on every `flutter test` and covers uk + en, which is what a developer
/// editing copy needs to hear about within seconds. This file loads all seven
/// ARBs through the delegate, renders the whole planner/onboarding/hint
/// surface once per language, and scans it against six vocabulary lists. It is
/// slower, and — more importantly — it goes red for a REVIEW reason (a
/// translator's word choice) rather than a code reason, which is not a signal
/// anyone should get mid-edit. The owner's decision: it runs before a
/// production build, and nowhere else.
///
/// The split is a DIRECTORY, not a tag and not a `dart_test.yaml` filter.
/// `flutter test` with no arguments runs `test/` only, so this file is skipped
/// by construction; `flutter test test_release/` runs it. A tag or a config
/// entry can be silently switched off by editing one line in a file nobody
/// reads at review time — a sibling directory cannot.
///
/// WHAT IS DERIVED AND WHAT IS TYPED. The locale list is derived from the ARB
/// directory and cross-checked against `AppLocalizations.supportedLocales`, so
/// an eighth language is swept the day its ARB lands, with no edit here. The
/// per-language stem lists cannot be derived from anything — they are
/// editorial judgement supplied by the translators — so a new language also
/// trips [everyShippedLocaleHasItsOwnStems] below, which is the reminder to
/// commission them. Both halves are deliberate: the new language is covered
/// immediately by [universalVocabulary], and the gate still says out loud that
/// the language-specific half is missing.
library;

import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:boostque/core/l10n/gen/app_localizations.dart';

// The uk + en lists and the surface renderer are IMPORTED, not retyped. The
// fast gate is the source of truth for those two languages, and a copy here
// would be a second list to keep in sync — the failure mode where a stem is
// added to one file and forgotten in the other, and both gates report green.
//
// `show` is load-bearing: the imported library declares its own `main()`, and
// naming exactly what is used keeps that out of this file's scope.
import '../test/l10n/planner_copy_safety_test.dart'
    show forbiddenVocabulary, isPlannerKey, plannerCopy;

/// The directory the ARBs live in — the single source of the locale list.
const String arbDir = 'lib/core/l10n/arb';

/// Every language tag with an ARB on disk, derived rather than typed.
List<String> shippedLocaleTags() {
  final pattern = RegExp(r'^app_([a-zA-Z]{2,3}(?:_[A-Za-z0-9]+)?)\.arb$');
  final tags = <String>[];
  for (final entity in Directory(arbDir).listSync()) {
    final match = pattern.firstMatch(entity.uri.pathSegments.last);
    if (match != null) tags.add(match.group(1)!);
  }
  tags.sort();
  return tags;
}

/// Vocabulary applied to EVERY language, whatever it is.
///
/// This is the fast gate's own uk + en list, reused verbatim. Two reasons it
/// belongs on all seven surfaces rather than only on its own two:
///
///  1. `gen-l10n` does not fail on a key missing from a non-template ARB — it
///     falls back to the ENGLISH template message and writes a line to
///     `l10n-untranslated.json`. So English limit vocabulary can surface in
///     any language's rendered tree, and only an English scan of that tree
///     catches it.
///  2. A newly added language with no stem list of its own is still swept by
///     something, instead of being swept by nothing until a human notices.
const List<String> universalVocabulary = forbiddenVocabulary;

/// Per-language stems, supplied by the translators, transcribed verbatim.
///
/// Matching follows the fast gate's convention exactly: case-sensitive where
/// the stem is capitalized, case-insensitive otherwise. Stems are word STEMS,
/// matched as substrings, so they cover inflection without a morphology
/// engine — which also means every entry has to be chosen so it cannot fire on
/// correct copy. Where a stem could, the note beside it says what it was
/// narrowed to avoid.
const Map<String, List<String>> vocabularyByLanguage = <String, List<String>>{
  'es': <String>[
    'sobredosis',
    'sobrepas', // sobrepasa / sobrepasar / sobrepasado
    // Both halves are needed and neither contains the other: `excede` has no
    // `exces` in it, and `exceso` has no `exced`.
    'exced', // excede / exceder / excedido
    'exces', // exceso / excesivo / excesiva
    'límit', // límite / límites — accented, so it never fires on English
    'umbral',
    'máxim', // máximo / máxima
    'interacc', // interacción / interacciones / interactúa
    'liposolubl',
    'tóxic', // tóxico / tóxica / toxicidad is `toxicidad`, see below
    'demasiad', // demasiado / demasiada / demasiados
    // A DELIBERATE leading space. Bare `segur` matches `asegúrate` and
    // `asegurar` — "make sure you…" — which legitimate instructional copy may
    // well use, and a stem that fires on correct copy is a stem someone
    // deletes. With the space it still catches ` seguro`, ` segura`,
    // ` seguridad` as standalone words, which is the claim being banned.
    ' segur',
  ],
  'fr': <String>[
    'surdos', // surdose / surdosage
    'dépass', // dépasse / dépasser / dépassement
    'excès',
    'seuil',
    'maximal', // maximale / maximales
    // In FULL, not `interacti`: that stem would fire on `interactif`, which
    // describes a control, not a drug interaction.
    'interaction',
    'liposolubl',
    'toxi', // toxique / toxicité
    'danger', // danger / dangereux / dangereuse
    'trop de',
    'sécurit', // sécurité / sécuritaire
    'recommand', // recommandé / recommandation — a dosage recommendation
  ],
  'hi': <String>[
    'सुरक्ष', // सुरक्षित / सुरक्षा
    'ओवरडो', // ओवरडोज़ — the nukta form varies, so the stem stops before it
    'विषाक्त',
    'सीमा',
    'सीमित',
    'अधिकतम',
    // A PHRASE, on purpose. Bare अधिक ("more") is ordinary everyday copy and
    // must never be a stem; `से अधिक` is the comparative "more than X", which
    // is how a limit gets stated.
    'से अधिक',
    // Nukta-independent on purpose: ज़्यादा may be written with or without the
    // nukta (ज़ vs ज), so the stem starts after it and matches both.
    'यादा',
    'परस्पर', // परस्पर क्रिया — interaction
    'इंटरैक्शन',
    'घुलनशील', // वसा में घुलनशील — fat-soluble
    'मानक', // चिकित्सा मानक — medical standard
  ],
  'ar': <String>[
    'جرعة زائدة', // overdose
    'تسمم', // toxicity
    'الحد الأقصى', // the maximum
    'تجاوز', // exceeded
    'يتجاوز', // exceeds
    'عتبة', // threshold
    // The PAIRED drug sense only. Bare تداخل means "overlap", which is exactly
    // what the planner's concurrent-load chart legitimately describes.
    'تداخل دوائي',
    'ذائب في الدهون', // fat-soluble
    'المعيار الطبي', // the medical standard
    'آمن', // safe
    // NOTE: the bare word حد ("limit") is NOT in this list. It is matched by
    // [boundaryVocabularyByLanguage] below instead, because as a substring it
    // fires on correct copy.
  ],
  'zh': <String>[
    // No inflection to stem: whole terms are the right granularity.
    '过量',
    '中毒',
    '上限',
    '超过',
    '超标',
    '阈值',
    '相互作用',
    '脂溶性',
    '医学标准',
    '安全剂量',
    '最大剂量',
    '不宜过多',
  ],
};

/// Arabic word-boundary letters: everything that can be part of an Arabic
/// word, EXCLUDING the diacritics `ً-ْ` and `ٰ`.
///
/// Excluding the diacritics is the point — `حدٌ` is still the word حد with a
/// tanwin on it, so a diacritic must not count as "another letter follows".
/// Tatweel (`ـ`) IS included, since it joins letters within a word.
const String _arabicWordChar = r'ؠ-يٮ-ۓۮۯ'
    r'ۺ-ۿ';

/// Stems that must match on a WORD BOUNDARY rather than as a substring.
///
/// Only Arabic needs this today, and it needs it badly. `حد` ("limit") is a
/// two-letter word that occurs inside a great many unrelated words:
/// `أحدها` ("one of them"), `واحدة` ("one"), `حديث` ("recent") — and, right
/// now, inside this app's own shipped `statusFresh` string `مضاف حديثًا`
/// ("recently added"). A naive `contains` fires on all four. Verified: with
/// substring matching, `حد` hits three shipped Arabic strings, every one of
/// them correct copy.
///
/// Dart's `\b` cannot express this. `\b` is defined against `\w`, which is
/// `[A-Za-z0-9_]`, so every Arabic letter is a non-word character and `\b`
/// would fire between any two of them. The boundary is therefore written out
/// as explicit lookaround over the Arabic letter block.
///
/// The `(?:[وفبكل]?ال)?` prefix is not decoration. Arabic writes its definite
/// article and its one-letter conjunctions and prepositions ATTACHED, so "the
/// limit" is `الحد` and "and the limit" is `والحد` — both one orthographic
/// word, both blocked by a plain boundary, and both exactly the phrasing a
/// limit claim would use. Allowing that prefix and nothing else keeps
/// `أحدها`, `واحدة`, `الحديث`, `الحدث` and `الحدود` out: none of them is
/// `[وفبكل]?ال` + `حد` + a word boundary.
final Map<String, List<RegExp>> boundaryVocabularyByLanguage =
    <String, List<RegExp>>{
  'ar': <RegExp>[
    RegExp('(?<![$_arabicWordChar])(?:[وفبكل]?ال)?حد(?![$_arabicWordChar])'),
  ],
};

/// True when [value] contains [term], case-sensitively for a capitalized term
/// and case-insensitively otherwise.
///
/// DUPLICATED from `planner_copy_safety_test.dart`, where the same function is
/// private (`_contains`) and so cannot be imported. Making it public there
/// would edit a gate file for this file's convenience; the convention is four
/// lines and is documented in both places, so the copy is the cheaper of the
/// two mistakes. If it ever diverges, the two gates disagree about `Зсунути`
/// and that shows up as a test failure, not as silence.
bool contains(String value, String term) {
  final firstRune = term.runes.first;
  final capitalized = String.fromCharCode(firstRune) !=
      String.fromCharCode(firstRune).toLowerCase();
  return capitalized
      ? value.contains(term)
      : value.toLowerCase().contains(term.toLowerCase());
}

void main() {
  final tags = shippedLocaleTags();

  test('the locale list is DERIVED from the ARB directory and matches what '
      'the app actually ships', () {
    // A derivation that silently resolved to nothing would make every sweep
    // below vacuously green, which is worse than no gate.
    expect(tags, isNotEmpty,
        reason: 'no ARB files found under $arbDir — the derivation broke, and '
            'a gate that sweeps zero languages passes for the wrong reason');

    final supported = AppLocalizations.supportedLocales
        .map((l) => l.toLanguageTag().replaceAll('-', '_'))
        .toList()
      ..sort();
    expect(tags, supported,
        reason: 'the ARB directory and AppLocalizations.supportedLocales '
            'disagree. Either an ARB landed without a codegen run, or a '
            'language is shipped that this gate never sees. Re-run '
            '`flutter gen-l10n`; do not relax this list');
  });

  test('every shipped locale has its own stem list', () {
    // Not derivable: stems are editorial judgement about one language's
    // morphology, and no amount of reading the ARB produces them. This test is
    // the commission notice — a new language is already swept by
    // [universalVocabulary], but the language-specific half is missing until
    // someone writes it.
    final missing = tags
        .where((t) => !vocabularyByLanguage.containsKey(t))
        .where((t) => t != 'uk' && t != 'en')
        .toList();
    expect(missing, isEmpty,
        reason: 'these languages ship with no medical-claim vocabulary of '
            'their own: $missing. The sweep below still runs over them with '
            'the shared English/Ukrainian list, so they are not unscanned — '
            'but the claim a translator is most likely to introduce is one '
            'phrased in their own language, and nothing here can see it. Ask '
            'the translator for the stems and add them to '
            'vocabularyByLanguage');
  });

  for (final tag in tags) {
    group('$tag planner/onboarding/hint copy', () {
      late Map<String, String> copy;

      setUpAll(() async {
        copy = plannerCopy(await AppLocalizations.delegate.load(Locale(tag)));
      });

      test('renders a non-empty surface (the sweep is not vacuous)', () {
        expect(copy, isNotEmpty);
        // The keys come from the fast gate's own renderer, which is itself
        // gated against the ARB. This only guards the load path: a locale that
        // failed to load would hand back an empty map and every sweep below
        // would pass on nothing.
        expect(copy.values.where((v) => v.trim().isNotEmpty), isNotEmpty);
      });

      test('carries no medical-claim vocabulary, in any language\'s words',
          () {
        final hits = <String>[];
        final stems = <String>[
          ...universalVocabulary,
          ...?vocabularyByLanguage[tag],
        ];
        copy.forEach((key, value) {
          for (final term in stems) {
            if (contains(value, term)) hits.add('$key contains "$term"');
          }
          for (final pattern in boundaryVocabularyByLanguage[tag] ?? const []) {
            if (pattern.hasMatch(value)) {
              hits.add('$key matches /${pattern.pattern}/');
            }
          }
        });

        expect(hits, isEmpty,
            reason: 'no copy in ANY shipped language may name a safety, '
                'interaction or pharmacological claim, or a dose limit the '
                'product does not have. A claim is a claim in Spanish too, '
                'and a store reviewer reads the language they installed. Fix '
                'the ARB. If a stem is genuinely wrong — it fires on correct '
                'copy — say so out loud when you change it, and say what '
                'replaced it; a stem quietly deleted to turn this green is '
                'how a gate stops being one. Offenders: $hits');
      });
    });
  }

  group('the stem lists themselves', () {
    test('the Arabic word-boundary stem does NOT fire on correct copy, and '
        'the substring form WOULD', () {
      // This is the one stem in the file whose correctness is not obvious by
      // reading it, so it is asserted rather than asserted-about-in-a-comment.
      // `مضاف حديثًا` is `statusFresh`, shipped right now.
      final boundary = boundaryVocabularyByLanguage['ar']!.single;
      for (final correct in const <String>[
        'مضاف حديثًا', // statusFresh — "recently added"
        'افتح أحدها في تبويب «المجموعة»', // emptyPlannerBodyNoRegimen
        'التقويم يرى كل شيء دفعة واحدة', // onboardingPage2Title
        'حديث', // "recent"
        'الحديث', // "the modern" — the article is allowed, the suffix is not
        'الحدث', // "the event"
        'الحدود', // "the borders"
      ]) {
        expect(boundary.hasMatch(correct), isFalse,
            reason: 'the boundary stem fired on correct Arabic copy: '
                '"$correct"');
        expect(correct.contains('حد'), isTrue,
            reason: 'this case only proves something if the naive substring '
                'form WOULD have fired on it — "$correct" no longer contains '
                'the bare stem, so it is no longer a control');
      }

      for (final forbidden in const <String>[
        'حد أقصى للجرعة', // "a maximum dose limit"
        'تحت الحد', // with the attached definite article
        'والحد اليومي', // with a conjunction on top of the article
        'حدٌ يومي', // with a tanwin — a diacritic is not "another letter"
      ]) {
        expect(boundary.hasMatch(forbidden), isTrue,
            reason: 'the boundary stem missed a real limit claim: '
                '"$forbidden"');
      }
    });

    test('every stem list is non-empty and free of duplicates', () {
      vocabularyByLanguage.forEach((tag, stems) {
        expect(stems, isNotEmpty, reason: '$tag has an empty stem list');
        expect(stems.toSet().length, stems.length,
            reason: '$tag repeats a stem, which doubles its hit report and '
                'usually means two people added the same word');
      });
    });

    test('the surface swept here is the SAME surface the fast gate defines',
        () {
      // The imported renderer is gated against the ARB inside the fast suite.
      // This only proves the import still resolves to the planner surface, so
      // a rename in `test/` that quietly narrows the surface fails here too
      // rather than shrinking this gate in silence.
      expect(isPlannerKey('plannerTitle'), isTrue);
      expect(isPlannerKey('onboardingPage1Body'), isTrue);
      expect(isPlannerKey('hintCycle'), isTrue);
      expect(isPlannerKey('tabStack'), isFalse);
    });
  });
}
