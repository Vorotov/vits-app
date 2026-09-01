/// ARB parity, template metadata and the DERIVED plural-form gate
/// (plan 05-03 task 3, L10N-01, 05-RESEARCH V-1 / A-1 / E-1..E-4 / PF-2).
///
/// The phase audit measured these properties clean by hand: full key parity
/// between the template and Ukrainian, metadata in the template only, and every
/// plural-bearing key carrying all four Ukrainian CLDR forms. This file turns
/// that one-time measurement into a standing gate — a reviewer sees an ARB diff
/// once, this test sees every commit after it.
///
/// **Nothing here is hand-listed.** The ARB files are globbed, the key sets are
/// derived from their structure, and the plural-bearing keys are found by
/// PARSING the template's values for an ICU `plural` construct. A written list
/// of plural key names is exactly the artifact that goes stale the day key
/// eleven is added — and going stale silently is the whole failure mode this
/// gate exists to prevent.
///
/// **The required plural CATEGORIES are derived too**, from the CLDR rules
/// `intl` already ships: each language's categories are probed through
/// `Intl.plural` rather than transcribed into a table here. Ukrainian's
/// one/few/many (including the 11-14 exception) and English's one/other both
/// fall out of the same three lines, and a language added later brings its own
/// rules with it. `test/l10n/plurals_test.dart` probes the RENDERED output at
/// 1/2/5/11/21; this file gates the ARB STRUCTURE behind it. The two are
/// complementary — do not duplicate the probes here.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

/// The arb directory and the template file, as declared by `l10n.yaml`.
const arbDirPath = 'lib/core/l10n/arb';
const templateArbName = 'app_en.arb';

/// `app_<code>.arb` — the only file shape gen-l10n reads from the arb dir.
final arbFilePattern = RegExp(r'^app_([a-z]{2,3}(?:_[A-Za-z]+)?)\.arb$');

/// An ICU plural construct: `{count, plural, one{...} other{...}}`.
final icuPluralPattern = RegExp(r'\{\s*\w+\s*,\s*plural\s*,');

/// A declared CLDR category inside a plural construct.
final pluralCategoryPattern =
    RegExp(r'(?:^|[\s,])(zero|one|two|few|many|other)\s*\{');

/// Every ARB file in the arb directory, keyed by language code.
Map<String, File> arbFiles() {
  final entries = <String, File>{};
  for (final file in Directory(arbDirPath).listSync().whereType<File>()) {
    final match = arbFilePattern.firstMatch(file.uri.pathSegments.last);
    if (match != null) entries[match.group(1)!] = file;
  }
  return entries;
}

Map<String, dynamic> readArb(File file) =>
    jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;

/// The message keys of an ARB — everything that is not an `@`-prefixed
/// metadata block or an `@@`-prefixed global attribute.
Set<String> messageKeys(Map<String, dynamic> arb) =>
    arb.keys.where((k) => !k.startsWith('@')).toSet();

/// The `@key` metadata blocks of an ARB, excluding `@@` globals like
/// `@@locale`.
Set<String> metadataKeys(Map<String, dynamic> arb) =>
    arb.keys.where((k) => k.startsWith('@') && !k.startsWith('@@')).toSet();

/// The CLDR plural categories [languageCode] actually uses, derived from the
/// rules `intl` ships rather than transcribed into a table.
///
/// Integers 0-100 are probed because those are the counts this app renders
/// (substances, weeks, slots, cycles). `other` is added unconditionally: ICU
/// requires every plural message to declare it as the final fallback, and in
/// languages like Ukrainian no integer ever selects it — only fractions do, so
/// probing alone would wrongly conclude it is unnecessary.
///
/// ALL SIX CLDR categories are passed, not just the four Ukrainian and English
/// happen to need. `Intl.pluralLogic` resolves an undeclared category by
/// falling back (`zero ?? other`, `two ?? few ?? other`), so a probe that
/// omitted `zero:` and `two:` could never observe them: Arabic selects ZERO at
/// n=0 and TWO at n=2, yet the four-argument probe reported
/// `{one, few, many, other}` for it and this gate would have accepted an
/// Arabic ARB carrying no `zero{}` and no `two{}` — exactly the
/// silently-wrong grammar the file exists to catch.
///
/// `Intl.pluralLogic` with `useExplicitNumberCases: false`, NOT the friendlier
/// `Intl.plural`, is what makes that work. By default `intl` short-circuits —
/// "if there's an explicit case for the exact number, we use it. This is not
/// strictly in accord with the CLDR rules" (intl 0.20.3, `intl.dart:348-358`)
/// — and returns `zero`/`one`/`two` for n = 0/1/2 in EVERY language before it
/// ever consults a rule. Passing all six categories to `Intl.plural` therefore
/// reports `{zero, one, two, other}` for English and Chinese and
/// `{zero, one, two, few, many}` for Ukrainian: six arguments, and a probe
/// measuring `intl`'s convenience behaviour instead of CLDR. Only the flag
/// turns the short-circuit off, and only `pluralLogic` exposes it. The pins at
/// the bottom of this file hold the derivation to all of that.
Set<String> requiredPluralCategories(String languageCode) {
  final categories = <String>{'other'};
  for (var n = 0; n <= 100; n++) {
    categories.add(
      Intl.pluralLogic(
        n,
        locale: languageCode,
        zero: 'zero',
        one: 'one',
        two: 'two',
        few: 'few',
        many: 'many',
        other: 'other',
        useExplicitNumberCases: false,
      ),
    );
  }
  return categories;
}

/// The CLDR categories an ICU plural [value] declares.
Set<String> declaredPluralCategories(String value) => pluralCategoryPattern
    .allMatches(value)
    .map((m) => m.group(1)!)
    .toSet();

void main() {
  late Map<String, File> files;
  late Map<String, Map<String, dynamic>> arbs;
  late String templateCode;

  setUpAll(() {
    files = arbFiles();
    arbs = {for (final e in files.entries) e.key: readArb(e.value)};
    templateCode = arbFilePattern.firstMatch(templateArbName)!.group(1)!;
  });

  // -------------------------------------------------------------------
  // The glob proof runs FIRST: every gate below iterates over `arbs`.
  // -------------------------------------------------------------------

  test(
      'the ARB glob actually resolves the language files — a gate over an '
      'empty file set is worse than no gate (L10N-01)', () {
    expect(arbs, isNotEmpty);
    expect(
      arbs.length,
      greaterThanOrEqualTo(2),
      reason: 'parity is a claim about TWO OR MORE files; over a single file '
          'every comparison below is vacuously true and a half-translated '
          'language could ship with the suite green',
    );
    expect(
      arbs.keys,
      contains(templateCode),
      reason: 'the template ARB ($templateArbName) is the reference every '
          'other file is compared against; without it the gate has no baseline',
    );
    expect(
      arbs.values.every((arb) => messageKeys(arb).length > 100),
      isTrue,
      reason: 'each ARB carries well over a hundred message keys; a much '
          'smaller parse means a file was read but not understood',
    );
  });

  // -------------------------------------------------------------------
  // Key parity (L10N-01, T-05-04).
  // -------------------------------------------------------------------

  test(
      'every ARB declares exactly the template key set — no key missing, none '
      'extra (L10N-01, T-05-04)', () {
    final templateKeys = messageKeys(arbs[templateCode]!);

    for (final entry in arbs.entries) {
      if (entry.key == templateCode) continue;
      final keys = messageKeys(entry.value);
      final missing = templateKeys.difference(keys);
      final extra = keys.difference(templateKeys);

      expect(
        missing,
        isEmpty,
        reason: 'app_${entry.key}.arb is missing these keys, and gen-l10n does '
            "NOT fail on that — it falls back to the template's ENGLISH "
            'message, so the user reads one English sentence in the middle of '
            'a translated screen. Add: $missing',
      );
      expect(
        extra,
        isEmpty,
        reason: 'app_${entry.key}.arb declares keys the template does not, so '
            'nothing generates a getter for them and the translation is dead '
            'weight — usually a rename that landed in one file only. Either '
            'add them to $templateArbName or delete: $extra',
      );
    }
  });

  // -------------------------------------------------------------------
  // Metadata lives in the template, and only there (house convention).
  // -------------------------------------------------------------------

  test(
      'every template message key carries an @-block with a non-empty '
      'description (L10N-01)', () {
    final template = arbs[templateCode]!;
    final undocumented = <String>[];

    for (final key in messageKeys(template)) {
      final meta = template['@$key'];
      final description =
          meta is Map<String, dynamic> ? meta['description'] : null;
      if (description is! String || description.trim().isEmpty) {
        undocumented.add(key);
      }
    }

    expect(
      undocumented,
      isEmpty,
      reason: 'the description is the only context a translator gets: without '
          'it "Stack" is a data structure, a pile, or a supplement regimen, '
          'and nobody can tell which from the key name. Describe WHY the '
          'string exists, matching the register of the existing blocks. '
          'Missing: $undocumented',
    );
  });

  test('non-template ARBs carry no @-blocks — metadata lives in the template '
      'only (house convention)', () {
    for (final entry in arbs.entries) {
      if (entry.key == templateCode) continue;
      expect(
        metadataKeys(entry.value),
        isEmpty,
        reason: 'app_${entry.key}.arb duplicates description metadata. Two '
            'copies of a description drift, and gen-l10n reads only the '
            "template's — so the copy a translator actually edits is the one "
            'that stops being true',
      );
    }
  });

  // -------------------------------------------------------------------
  // The derived plural gate (L10N-01, E-1, E-2).
  // -------------------------------------------------------------------

  test(
      'every plural-bearing key declares every CLDR category its language '
      'requires (L10N-01, E-1)', () {
    final template = arbs[templateCode]!;

    // Derived by parsing the template's VALUES, never from a written list of
    // key names: key eleven is covered the day it lands.
    final pluralKeys = messageKeys(template)
        .where((k) =>
            template[k] is String && icuPluralPattern.hasMatch(template[k] as String))
        .toList()
      ..sort();

    expect(
      pluralKeys,
      isNotEmpty,
      reason: 'the app renders counted nouns on every screen; finding no ICU '
          'plural in the template means the parse failed, not that the app '
          'stopped counting',
    );

    for (final code in arbs.keys) {
      final required = requiredPluralCategories(code);
      for (final key in pluralKeys) {
        final value = arbs[code]![key];
        expect(
          value,
          isA<String>(),
          reason: 'app_$code.arb is missing the plural key "$key"',
        );
        expect(
          icuPluralPattern.hasMatch(value as String),
          isTrue,
          reason: 'app_$code.arb renders "$key" as a flat string while the '
              'template declares it plural: the count agrees with the noun in '
              'one language and not the other',
        );

        final declared = declaredPluralCategories(value);
        expect(
          declared,
          containsAll(required),
          reason: 'app_$code.arb: "$key" declares $declared but $code requires '
              '$required. A missing category silently falls back to `other`, '
              'so Ukrainian reads "5 речовини" instead of "5 речовин" — '
              'grammatically wrong in a way an English-speaking reviewer '
              'cannot see. The 11-14 exception (11 takes `many`, not `one`) is '
              'the form most often dropped',
        );
      }
    }
  });

  test(
      'the derived category sets match the CLDR rules the app depends on — '
      'the derivation itself is pinned (E-1, E-2)', () {
    expect(
      requiredPluralCategories('uk'),
      {'one', 'few', 'many', 'other'},
      reason: 'Ukrainian needs all four; if this derivation ever returns fewer '
          'the plural gate above silently stops requiring them and every ARB '
          'passes while the grammar breaks',
    );
    expect(
      requiredPluralCategories('en'),
      {'one', 'other'},
      reason: 'English needs exactly two; a derivation that returned more '
          'would demand forms the template has no reason to carry',
    );
    expect(
      requiredPluralCategories('ar'),
      {'zero', 'one', 'two', 'few', 'many', 'other'},
      reason: 'Arabic is the language that proves the probe passes ALL SIX '
          'category names. Its rule selects ZERO at 0 and TWO at 2, but '
          '`Intl.pluralLogic` falls back (`zero ?? other`, `two ?? few ?? '
          'other`) when a category is not passed — so a probe missing `zero:` '
          'or `two:` returns {one, few, many, other} here and the gate above '
          'stops requiring the two forms Arabic actually inflects. This pin, '
          'not a comment, is what keeps the probe complete',
    );
    expect(
      requiredPluralCategories('zh'),
      {'other'},
      reason: 'Chinese has exactly one form, and it is the opposite guard to '
          'Arabic: a derivation that over-reported would demand `one{}` and '
          '`few{}` blocks of a translator whose language has no such '
          'distinction, and the only way to satisfy it would be to write the '
          'same sentence six times',
    );
  });
}
