/// The vocabulary gate over the published legal documents.
///
/// `docs/legal/privacy.md` and `docs/legal/terms.md` are the texts the store
/// listings link to. The brief for them is stricter than for app copy: the
/// app is a well-being product and the documents must carry no health or
/// medical vocabulary at all. Every reference document they were drawn from
/// states "not medical advice" in medical words, so the pull toward that
/// phrasing is constant and a later edit will reintroduce it by reflex. This
/// gate is what stops that.
///
/// Why it lives in `test_release/` and not `test/`: the documents change
/// rarely, the check reads files outside `lib/`, and a hit is editorial, the
/// same reasoning as `copy_safety_all_locales_test.dart` next door.
///
/// The set of documents is DERIVED: every `.md` in `docs/legal/` whose name
/// does not start with a date is a published document. Research notes carry
/// a date prefix and discuss the banned words on purpose, so they must not be
/// swept. A new published document is covered the day it lands.
///
/// The stem list is NOT the ARB gate's `limitVocabulary`: "limitation of
/// liability", "limited licence" and "exceed" are unavoidable legal English
/// and say nothing about doses. The two lists guard different claims.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Patterns that must not appear in a published legal document, matched
/// case-insensitively as regular expressions. Most are bare stems; one carries
/// a word boundary because the stem is a substring of ordinary legal English.
/// Each entry names the reason it is here.
const legalForbiddenStems = <String>[
  'health', // the category the app must not claim; product names allowlisted
  'medic', // medical, medicine, medication
  'doctor',
  'physician',
  'pharmac', // pharmacist, pharmaceutical, pharmacology
  'clinic', // clinical
  'diagnos',
  'therap', // therapy, therapeutic
  'treat', // treat, treatment; also blocks "treated as" — rephrase it
  r'\bcure', // whole-word: 'secure' and 'obscure' are not claims
  'disease',
  'illness',
  'condition', // "conditions" also blocks "terms and conditions" — we say Terms of Use
  'symptom',
  'patient',
  'prescri', // prescribe, prescription
  'drug',
  'dietary', // the FDA/DSHEA seller's term; we sell nothing
  'nutrition',
  'wellness', // the reference documents' word; the brief's word is well-being
  'overdose',
  'interaction', // the pharmacological claim the ARB gate also bans
  'fat-soluble',
  'side effect',
  'toxic',
  'safe', // safe, safety, safeguard — a claim about the reader's body, or a word that sounds like one
  'injur', // injury, injuries — even inside a liability carve-out
  'risk', // "at your own risk" is standard legal English; we say "responsibility"
];

/// Exact phrases removed from the text before scanning. Each is a proper noun
/// for a thing the documents say the app does NOT touch. Nothing else may be
/// allowlisted without saying why here.
const legalAllowlist = <String>[
  'Apple Health',
  'Health Connect',
];

/// Placeholders the documents may contain. A bracketed token outside this set
/// is a typo that would ship into the published text as-is.
const knownPlaceholders = <String>{
  '[APP_NAME]',
  '[CONTACT_EMAIL]',
  '[WEBSITE_URL]',
  '[LAST_UPDATED]',
  '[NOMINAL_SUM]',
  '[WEBSITE_DATA]',
};

final _datePrefix = RegExp(r'^\d{4}-\d{2}-\d{2}');
final _placeholder = RegExp(r'\[[A-Z_]+[^\]]*\]');
final _htmlComment = RegExp(r'<!--.*?-->', dotAll: true);

/// Runs at load time, so it may not `expect`: an `expect` outside a test body
/// fails the whole file with an OutsideTestException. The assertions about
/// the set live in the first test below.
List<File> _publishedDocuments() {
  final dir = Directory('docs/legal');
  if (!dir.existsSync()) return const [];
  return dir
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.md'))
      .where((f) => !_datePrefix.hasMatch(f.uri.pathSegments.last))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));
}

void main() {
  test('the published set is exactly the privacy policy and the terms', () {
    final names = _publishedDocuments().map((f) => f.uri.pathSegments.last);
    expect(names, ['privacy.md', 'terms.md'],
        reason: 'a new published document must be added here on purpose, '
            'a dated research note must never lose its date prefix, and an '
            'empty set means the gate guards nothing, which is a failure');
  });

  for (final file in _publishedDocuments()) {
    final name = file.uri.pathSegments.last;

    test('$name carries no health or medical vocabulary', () {
      // Comments are author notes, not published text; strip them first so a
      // note naming a banned word cannot trip its own gate.
      var text = file.readAsStringSync().replaceAll(_htmlComment, '');
      for (final phrase in legalAllowlist) {
        text = text.replaceAll(phrase, '');
      }
      final hits = <String>[];
      final lines = text.split('\n');
      final patterns = [
        for (final stem in legalForbiddenStems)
          RegExp(stem, caseSensitive: false),
      ];
      for (var i = 0; i < lines.length; i++) {
        for (final pattern in patterns) {
          if (pattern.hasMatch(lines[i])) {
            final stem = pattern.pattern;
            hits.add('$name:${i + 1} contains "$stem": ${lines[i].trim()}');
          }
        }
      }
      expect(hits, isEmpty,
          reason: 'a published legal document may not describe the app in '
              'health or medical terms, in any phrasing. Rephrase; do not '
              'allowlist.\n${hits.join('\n')}');
    });

    test('$name uses only known placeholders', () {
      final text = file.readAsStringSync().replaceAll(_htmlComment, '');
      final found = _placeholder
          .allMatches(text)
          .map((m) => m.group(0)!)
          .map((p) => p.contains(':') ? '${p.substring(0, p.indexOf(':'))}]' : p)
          .toSet();
      expect(found.difference(knownPlaceholders), isEmpty,
          reason: 'an unknown bracketed token would ship as-is');
    });
  }
}
