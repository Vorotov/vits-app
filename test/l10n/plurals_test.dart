import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:boostque/core/l10n/gen/app_localizations.dart';

// Plural-form tests loaded via AppLocalizations.delegate.load — no widget
// pump needed (01-RESEARCH.md Pattern 6).
//
// uk CLDR plural rules (unicode.org CLDR chart, cited in 01-RESEARCH.md):
//   one:  v=0 and i%10=1 and i%100!=11        → 1, 21
//   few:  v=0 and i%10=2..4 and i%100!=12..14 → 2
//   many: v=0 and i%10=0|5..9 or i%100=11..14 → 5, 11 (the 11-14 exception)
void main() {
  group('uk plurals', () {
    late AppLocalizations l10n;

    setUpAll(() async {
      l10n = await AppLocalizations.delegate.load(const Locale('uk'));
    });

    test('substancesCount covers all four CLDR forms incl. 11-14 exception',
        () {
      expect(l10n.substancesCount(1), '1 речовина'); // one
      expect(l10n.substancesCount(2), '2 речовини'); // few
      expect(l10n.substancesCount(5), '5 речовин'); // many
      expect(l10n.substancesCount(11), '11 речовин'); // many (11-14 exception)
      expect(l10n.substancesCount(21), '21 речовина'); // one (i%10=1)
    });

    test('weeksCount covers all four CLDR forms incl. 11-14 exception', () {
      expect(l10n.weeksCount(1), '1 тиждень'); // one
      expect(l10n.weeksCount(2), '2 тижні'); // few
      expect(l10n.weeksCount(5), '5 тижнів'); // many
      expect(l10n.weeksCount(11), '11 тижнів'); // many (11-14 exception)
      expect(l10n.weeksCount(21), '21 тиждень'); // one (i%10=1)
    });
  });

  group('en plurals', () {
    late AppLocalizations l10n;

    setUpAll(() async {
      l10n = await AppLocalizations.delegate.load(const Locale('en'));
    });

    test('substancesCount uses one/other', () {
      expect(l10n.substancesCount(1), '1 substance');
      expect(l10n.substancesCount(2), '2 substances');
      expect(l10n.substancesCount(21), '21 substances');
    });

    test('weeksCount uses one/other', () {
      expect(l10n.weeksCount(1), '1 week');
      expect(l10n.weeksCount(21), '21 weeks');
    });
  });
}
