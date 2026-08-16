/// The app's single uppercase definition (`bqUpperCase`, 05-REVIEW WR-03).
///
/// The four uppercased labels in the app — the week strip's weekday
/// abbreviation, the gantt month header, the year-grid card label and the
/// month-detail title — all pass through this one function, so the properties
/// asserted here are the properties every one of them has.
///
/// What this file is really pinning is the difference between "locale-aware
/// FORMATTING" (intl's job, already covered by month_names_test.dart) and
/// "locale-aware CASING", which Dart has no API for at all: `toUpperCase()`
/// applies the default Unicode mapping regardless of language. Before WR-03
/// four call sites relied on that mapping and two of them were documented as
/// doing the opposite.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:boostque/core/l10n/casing.dart';

void main() {
  test('the shipped locales get the default Unicode mapping', () {
    expect(bqUpperCase('серп.', 'uk'), 'СЕРП.');
    expect(bqUpperCase('Aug', 'en'), 'AUG');
    expect(bqUpperCase('mon', 'en_US'), 'MON');
  });

  test('Turkish and Azeri get the dotted-i pair right (the one exception)', () {
    // The mapping Dart's default gets wrong: in tr/az the dotted and dotless
    // i are separate letters, so `i` uppercases to `İ` and `ı` to `I`. The
    // default collapses both onto `I`, which spells a different word.
    expect(bqUpperCase('i', 'tr'), 'İ');
    expect(bqUpperCase('ı', 'tr'), 'I');
    expect(bqUpperCase('i', 'az'), 'İ');
    expect(bqUpperCase('ı', 'az_AZ'), 'I');

    expect(
      'i'.toUpperCase(),
      isNot('İ'),
      reason: 'the premise: this is what all four call sites did before, and '
          'it is why the casing step needed a definition of its own rather '
          'than a comment claiming intl provided one',
    );
  });

  test('the rest of a tr/az word still uppercases normally', () {
    expect(bqUpperCase('nisan', 'tr'), 'NİSAN');
    expect(bqUpperCase('ocak', 'tr'), 'OCAK');
  });

  test('a language whose subtag merely starts with the same letters is not '
      'caught by accident', () {
    // Locale strings arrive as the ACTIVE locale (`uk`, `en_US`, ...), so the
    // prefix test has to be read as a language-subtag test, not a substring
    // one: nothing that merely contains "tr" may take the exception branch.
    expect(bqUpperCase('interstellar', 'en'), 'INTERSTELLAR');
  });
}
