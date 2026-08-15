/// Unit tests for the bundled catalog + cross-locale search (plan 02-05,
/// STACK-01, RESEARCH P-1/P-2).
///
/// No widget pump: both locales are resolved through the generated
/// synchronous `lookupAppLocalizations` (02-PATTERNS.md "Plural test
/// pattern", synchronous alternative).
library;

import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:boostque/core/l10n/gen/app_localizations.dart';
import 'package:boostque/core/theme/tokens.dart';
import 'package:boostque/features/stack/catalog.dart';

void main() {
  final AppLocalizations uk = lookupAppLocalizations(const Locale('uk'));
  final AppLocalizations en = lookupAppLocalizations(const Locale('en'));

  group('kCatalogEntries', () {
    test('has exactly 15 entries with unique ids', () {
      expect(kCatalogEntries, hasLength(15));
      final ids = kCatalogEntries.map((e) => e.id).toSet();
      expect(ids, hasLength(15), reason: 'ids must be unique');
    });

    test('every entry resolves a non-empty name and doseText in BOTH locales',
        () {
      for (final entry in kCatalogEntries) {
        for (final l10n in [uk, en]) {
          expect(entry.name(l10n).trim(), isNotEmpty,
              reason: '${entry.id} name must be non-empty in both locales');
          expect(entry.doseText(l10n).trim(), isNotEmpty,
              reason: '${entry.id} doseText must be non-empty in both locales');
        }
      }
    });

    test('every color comes from BqSeriesColors.palette (token-only, D-07)',
        () {
      for (final entry in kCatalogEntries) {
        expect(BqSeriesColors.palette, contains(entry.color),
            reason: '${entry.id} color must be a palette token');
      }
    });
  });

  group('searchCatalog', () {
    test('empty query returns all 15 entries in declaration order', () {
      final result = searchCatalog('', uk);
      expect(result, hasLength(15));
      expect(
        result.map((e) => e.id).toList(),
        kCatalogEntries.map((e) => e.id).toList(),
        reason: 'declaration order preserved for the empty query',
      );
    });

    test('whitespace-only query returns all 15 entries', () {
      expect(searchCatalog('   ', uk), hasLength(15));
    });

    test('uk substring match: "креат" finds Креатин моногідрат', () {
      final result = searchCatalog('креат', uk);
      expect(result, hasLength(1));
      expect(result.single.id, 'creatine');
      expect(result.single.name(uk), 'Креатин моногідрат');
    });

    test('Cyrillic case-insensitivity: upper-case "КРЕАТ" also matches', () {
      final result = searchCatalog('КРЕАТ', uk);
      expect(result, hasLength(1));
      expect(result.single.id, 'creatine');
    });

    test('cross-locale: latin "creatine" matches via en names while uk is '
        'active', () {
      final result = searchCatalog('creatine', uk);
      expect(result.map((e) => e.id), contains('creatine'));
    });

    test('cross-locale: "b12" matches the B12 entry while uk is active', () {
      final result = searchCatalog('b12', uk);
      expect(result.map((e) => e.id), contains('b12'));
    });

    test('no match returns an empty list', () {
      expect(searchCatalog('zzzzzzz-not-a-supplement', uk), isEmpty);
    });
  });
}
