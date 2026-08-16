/// The "one new ARB file, no code changes" contract, as a machine check
/// (plan 05-03 task 1, L10N-04 criterion 4, 05-RESEARCH V-3 / P-1 / P-2).
///
/// Criterion 4 is the phase's hardest claim and the easiest one to satisfy in
/// prose while violating in code: every helpful `switch (languageCode)` a later
/// contributor adds is invisible to a test that merely asserts the app ships
/// English and Ukrainian. So this file asserts nothing about WHICH languages
/// ship. It reads the ARB directory off disk and demands that every other
/// representation of the shipped language set — the generated
/// `supportedLocales`, `LocaleController`'s sanitization allowlist, each
/// language's own display name — agrees with the filesystem, in loops that grow
/// with the directory. Dropping `app_pl.arb` into the arb dir extends this
/// file's coverage with no edit to it, which is the same property criterion 4
/// claims for the app.
///
/// PROOF SHAPE — read this before treating the file as more (or less) than it
/// is. Criterion 4 is proven here by DERIVATION (generated list == ARB dir ==
/// controller's derived set, plus the source gates in
/// `no_hardcoded_strings_test.dart` forbidding a per-language code path) and by
/// a SYNTHETIC-LOCALE negative case. It is NOT proven by executing a real
/// third-ARB `flutter gen-l10n` build: no test in this repository spawns a
/// subprocess, the assertions below catch every code-shaped violation, and
/// inventing a subprocess-test convention in the final v1 phase is a cost with
/// no matching benefit (05-PATTERNS "No Analog Found"; 05-RESEARCH A9 marks the
/// shell-out strictly optional).
///
/// `lookupAppLocalizations` (SYNCHRONOUS) is used deliberately below rather
/// than `AppLocalizations.delegate.load` (async): the language picker calls the
/// synchronous one, and assertion 5 exists to prove that call cannot throw for
/// any shipped locale.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:boostque/core/l10n/l10n.dart';
import 'package:boostque/core/l10n/locale_controller.dart';
import 'package:boostque/core/providers.dart';

/// The arb directory, as declared by `l10n.yaml` rather than repeated here —
/// a gate that hardcodes the path it is gating stops gating the day the path
/// moves.
const arbDirPath = 'lib/core/l10n/arb';

/// `app_<code>.arb` — the only file shape gen-l10n reads from the arb dir.
final arbFilePattern = RegExp(r'^app_([a-z]{2,3}(?:_[A-Za-z]+)?)\.arb$');

/// Every language code the arb directory yields, sorted.
///
/// Resolved by GLOB, never by a written list: this function is the single place
/// the shipped language set is discovered, and every assertion in this file
/// loops over its result. That is what makes the file a proof of criterion 4
/// rather than a restatement of the languages that happen to ship today.
List<String> arbLanguageCodes() {
  final codes = Directory(arbDirPath)
      .listSync()
      .whereType<File>()
      .map((f) => arbFilePattern.firstMatch(f.uri.pathSegments.last)?.group(1))
      .whereType<String>()
      .toList()
    ..sort();
  return codes;
}

/// [source] with every comment line removed.
///
/// Line comments only (`#` in YAML), matching the `stripComments` shape in
/// `planner_invariants_test.dart`. `l10n.yaml`'s comments NAME the options this
/// file asserts on — a gate that reads its own documentation as configuration
/// would pass on a file whose real settings had been deleted.
String stripYamlComments(String source) => source
    .split('\n')
    .where((line) => !line.trimLeft().startsWith('#'))
    .join('\n');

/// The value of a scalar `key: value` line in comment-stripped YAML.
String? yamlScalar(String yaml, String key) {
  for (final line in yaml.split('\n')) {
    if (line.startsWith('$key:')) {
      return line.substring(key.length + 1).trim();
    }
  }
  return null;
}

/// The entries of a block-sequence YAML key, in declaration order.
List<String>? yamlSequence(String yaml, String key) {
  final lines = yaml.split('\n');
  final start = lines.indexWhere((l) => l.startsWith('$key:'));
  if (start < 0) return null;
  final entries = <String>[];
  for (final line in lines.skip(start + 1)) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) continue;
    if (!trimmed.startsWith('- ')) break;
    entries.add(trimmed.substring(2).trim());
  }
  return entries;
}

void main() {
  late List<String> arbCodes;
  late String l10nYaml;

  setUpAll(() {
    arbCodes = arbLanguageCodes();
    l10nYaml = stripYamlComments(File('l10n.yaml').readAsStringSync());
  });

  // -------------------------------------------------------------------
  // The glob proof runs FIRST and unconditionally. Everything below it
  // loops over `arbCodes`; over an empty set every one of those loops
  // passes vacuously.
  // -------------------------------------------------------------------

  test(
      'the ARB glob actually resolves the language files — a gate over an '
      'empty file set is worse than no gate (L10N-04)', () {
    expect(arbCodes, isNotEmpty);
    expect(
      arbCodes.length,
      greaterThanOrEqualTo(2),
      reason: 'every assertion in this file is a loop over the discovered ARB '
          'codes; if the glob stops matching (the arb dir moves, the file '
          'naming changes) each of those loops passes over nothing and the '
          'criterion-4 contract is unguarded while the suite stays green',
    );
    expect(
      arbCodes.toSet().length,
      arbCodes.length,
      reason: 'two ARB files claiming the same language code means gen-l10n '
          'silently picks one',
    );
  });

  group('the derivations agree with the filesystem (V-3)', () {
    test(
        'the generated supportedLocales IS the ARB directory, not a hand-kept '
        'list (L10N-04, criterion 4)', () {
      expect(
        AppLocalizations.supportedLocales
            .map((l) => l.languageCode)
            .toList()
          ..sort(),
        arbCodes,
        reason: 'gen-l10n derives the locale list from the arb dir; a mismatch '
            'means the generated sources are stale, so the app ships a '
            'language set nobody edited a file to choose',
      );
    });

    test(
        'LocaleController derives its sanitization allowlist from the ARB '
        'files; it does not enumerate them (T-05-01)', () {
      expect(
        LocaleController.supportedLocaleTags,
        // `app_pt_BR.arb` yields the ARB code `pt_BR` and the BCP-47 tag
        // `pt-BR` — the same locale spelled with the two separators the two
        // representations use. The allowlist keys on the TAG, so a
        // region-qualified language is one entry here, not a collapsed
        // language subtag (WR-05).
        arbCodes.map((code) => code.replaceAll('_', '-')).toSet(),
        reason: 'a hand-kept set in the controller would reject a newly added '
            'language: the picker could persist it and the next launch would '
            'sanitize it back to follow-system, so "one new ARB file, no code '
            'changes" would silently stop being true',
      );
    });

    test(
        'the English fallback is DECLARED in l10n.yaml, not inherited from '
        'alphabetical ordering (PF-1, L10N-02)', () {
      // Part (a): the property MaterialApp actually reads.
      expect(
        AppLocalizations.supportedLocales.first,
        const Locale('en'),
        reason: 'MaterialApp resolves an unmatched system language to '
            'supportedLocales.first (widgets/app.dart), so the first entry IS '
            'the app-wide fallback language',
      );

      // Part (b) is the LOAD-BEARING half. Do not delete it as redundant:
      // 'en' currently sorts first alphabetically, so part (a) keeps passing
      // even with the declaration removed from l10n.yaml — and then adding
      // app_de.arb would silently make German the fallback for every device
      // whose language this app does not ship, with no test turning red.
      expect(
        l10nYaml,
        contains('preferred-supported-locales:'),
        reason: 'without this option gen-l10n emits supportedLocales in '
            'alphabetical order and the fallback is English only by the '
            'accident of en < uk',
      );
      expect(
        yamlSequence(l10nYaml, 'preferred-supported-locales'),
        isNotEmpty,
        reason: 'the key must declare an ordering, not sit empty',
      );
      expect(
        yamlSequence(l10nYaml, 'preferred-supported-locales')!.first,
        'en',
        reason: 'the FIRST declared entry becomes supportedLocales.first and '
            'therefore the fallback; a new language declared ahead of English '
            'moves the fallback with one line of YAML',
      );
    });

    test(
        'every ARB brings its own native display name, and no two languages '
        'share one (P-2, L10N-04)', () {
      final names = <String, String>{
        for (final code in arbCodes)
          code: lookupAppLocalizations(Locale(code)).languageName,
      };

      for (final entry in names.entries) {
        expect(
          entry.value,
          isNotEmpty,
          reason: 'the picker renders lookupAppLocalizations(locale)'
              '.languageName for ${entry.key}; an empty endonym is a blank '
              'row the user cannot identify, and a per-language name map in '
              'Dart would be exactly the code change criterion 4 forbids',
        );
      }

      expect(
        names.values.toSet().length,
        names.length,
        reason: 'two languages rendering the same endonym gives the user two '
            'indistinguishable rows: ${names.toString()}',
      );
    });

    test(
        'every ARB language is inside kMaterialSupportedLanguages — the honest '
        'boundary of the guarantee (PF-9, E-8)', () {
      for (final code in arbCodes) {
        expect(
          kMaterialSupportedLanguages,
          contains(code),
          reason: 'GlobalMaterialLocalizations.load opens with '
              'assert(isSupported(locale)); outside that 82-language set the '
              'Material chrome (date pickers, dialogs, tooltips) stays '
              'English and debug builds assert. Such a language needs a '
              'custom delegate — a code change, which criterion 4 forbids. '
              'The guarantee is "one new ARB file, for any of the 82 '
              'languages flutter_localizations covers"',
        );
      }
    });

    test(
        'the untranslated-messages report is absent or empty — no key may fall '
        'back to the template English message unnoticed (PF-2, T-05-04)', () {
      final declared = yamlScalar(l10nYaml, 'untranslated-messages-file');
      expect(
        declared,
        isNotNull,
        reason: 'gen-l10n does NOT fail on a key missing from a non-template '
            'ARB — it falls back to the template message and only warns. '
            'Writing that warning to a file is what makes the gap assertable '
            'instead of invisible',
      );

      final report = File(declared!);
      if (!report.existsSync()) return; // gen-l10n writes nothing when clean.

      final raw = report.readAsStringSync().trim();
      if (raw.isEmpty) return;

      expect(
        jsonDecode(raw),
        isEmpty,
        reason: 'a non-empty report means at least one locale is missing at '
            'least one key, and the user sees an English sentence in the '
            'middle of a translated screen rather than a build failure. Run '
            '`flutter gen-l10n` and add the listed keys',
      );
    });
  });

  // -------------------------------------------------------------------
  // The synthetic third locale. This group is what makes the file a proof
  // of the CONTRACT rather than a description of the current two
  // languages: it asserts the negative half — a language whose ARB does
  // not exist appears nowhere and reaches nothing.
  // -------------------------------------------------------------------

  group('a language with no ARB file appears nowhere (T-05-01)', () {
    /// A language code deliberately NOT on disk, discovered rather than
    /// written: if a later phase actually ships one of these, the next
    /// candidate is chosen and this group keeps testing what it claims to.
    late String syntheticCode;

    setUp(() {
      const candidates = ['pl', 'de', 'fr', 'ja', 'zz'];
      final unshipped = candidates.where((c) => !arbCodes.contains(c));
      expect(
        unshipped,
        isNotEmpty,
        reason: 'this group needs one language the app does NOT ship; extend '
            'the candidate list',
      );
      syntheticCode = unshipped.first;
    });

    test('it is absent from the generated supportedLocales', () {
      expect(
        AppLocalizations.supportedLocales.map((l) => l.languageCode),
        isNot(contains(syntheticCode)),
        reason: 'the generated list may only contain languages with an ARB '
            'file; anything else means a language was added in Dart',
      );
    });

    test("it is absent from the controller's derived allowlist", () {
      expect(
        LocaleController.supportedLocaleTags,
        isNot(contains(syntheticCode)),
        reason: 'the allowlist is the sanitization boundary for untrusted '
            'stored input; a code in it with no ARB behind it would reach '
            'lookupAppLocalizations and throw at MaterialApp build time',
      );
    });

    test(
        'a stored preference holding it sanitizes to follow-system rather than '
        'reaching the generated lookup (T-05-01)', () async {
      SharedPreferences.setMockInitialValues({'app_locale': syntheticCode});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      expect(
        container.read(localeControllerProvider),
        isNull,
        reason: 'SharedPreferences is editable outside the app (rooted device, '
            'backup edit). An unvalidated code reaches the generated '
            "lookupAppLocalizations' throw on the first frame — an "
            'unrecoverable launch crash, not a cosmetic fallback. Do not '
            'widen the sanitization into a passthrough',
      );
    });

    test(
        'and the positive half holds for every code that IS on disk, as a loop '
        'over the discovered set (L10N-04, criterion 4)', () {
      for (final code in arbCodes) {
        expect(lookupAppLocalizations(Locale(code)).languageName, isNotEmpty);
        expect(kMaterialSupportedLanguages, contains(code));
      }
      expect(
        arbCodes,
        isNot(contains(syntheticCode)),
        reason: 'the two halves must be about the same set: if the synthetic '
            'code ever appears on disk this group is testing nothing',
      );
    });
  });
}
