/// Month-case pinning for the planner's header, peak chip and month labels
/// (plan 04-02, PF-4, L10N-04, T-04-08).
///
/// Ukrainian declines month names, and `intl` carries BOTH cases for uk:
///   - standalone (`LLLL`, `DateSymbols.STANDALONEMONTHS`) — nominative,
///     "серпень": correct for a month that stands without a day number
///   - format (`MMMM`, `DateSymbols.MONTHS`) — genitive, "серпня": correct
///     only beside a day number, "13 серпня"
///
/// Every month name on the planner — the Цикли subtitle, the peak-month chip,
/// the month-detail title, the gantt month header, the year-grid card label —
/// stands without a day number, so all of them render through the STANDALONE
/// letters. This is a correctness rule, not a style preference.
///
/// **The trap this file exists to pin.** `intl` falls back to the standalone
/// form when the month is the ONLY field in the pattern, so a bare
/// `DateFormat('MMMM', 'uk')` accidentally renders the nominative and a test
/// comparing the two bare patterns would prove nothing. Add any other field —
/// exactly what a "just put the year in the same DateFormat" refactor of the
/// subtitle would do — and `MMMM` immediately yields the genitive: "серпня
/// 2026" where the design says "серпень 2026". That inequality is asserted
/// below, and it is the one that actually protects the screen.
///
/// The pinned uk strings also guard the other half of L10N-04: an
/// implementation that fell back to English, or to a hardcoded month table,
/// fails here.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/date_symbols.dart';
import 'package:intl/intl.dart';

void main() {
  // Without this the uk symbols are never loaded and `DateFormat` silently
  // falls back to the default locale — every assertion below would then be
  // testing English.
  setUpAll(() async {
    await initializeDateFormatting('uk');
    await initializeDateFormatting('en');
  });

  // A day inside the Цикли window the planner tests pin their clock to, and
  // the month that closes that window.
  final august = DateTime.utc(2026, 8, 13);
  final november = DateTime.utc(2026, 11, 30);

  group('uk month case', () {
    test('the standalone pattern renders the nominative form the planner '
        'needs', () {
      expect(DateFormat('LLLL', 'uk').format(august), 'серпень',
          reason: 'the Цикли subtitle reads "серпень — листопад 2026"');
      expect(DateFormat('LLLL', 'uk').format(november), 'листопад');
    });

    test('the format pattern renders the genitive form, which is correct ONLY '
        'beside a day number', () {
      expect(DateFormat('d MMMM', 'uk').format(august), '13 серпня');
      expect(DateFormat('d MMMM', 'uk').format(november), '30 листопада');
    });

    test('standalone and format outputs for the same date DIFFER once the '
        'pattern carries a second field (PF-4)', () {
      final standalone = DateFormat('LLLL y', 'uk').format(august);
      final formatCase = DateFormat('MMMM y', 'uk').format(august);

      expect(standalone, 'серпень 2026');
      expect(formatCase, 'серпня 2026');
      expect(standalone, isNot(formatCase),
          reason: 'this is the whole PF-4 rule: composing the subtitle with '
              'MMMM would ship "серпня 2026", which is wrong Ukrainian for a '
              'month standing on its own');
    });

    test('the two cases are genuinely distinct in the locale data — a bare '
        '"MMMM" only LOOKS safe because intl falls back to the standalone '
        'form for a single-field pattern', () {
      final uk = dateTimeSymbolMap()['uk'] as DateSymbols;

      expect(uk.STANDALONEMONTHS[7], 'серпень');
      expect(uk.MONTHS[7], 'серпня');
      expect(uk.STANDALONEMONTHS[7], isNot(uk.MONTHS[7]));
      // The single-field fallback, pinned so nobody "simplifies" the planner
      // to MMMM on the strength of this coincidence.
      expect(DateFormat('MMMM', 'uk').format(august),
          DateFormat('LLLL', 'uk').format(august));
    });

    test('the abbreviated pair: uk carries one abbreviation for both cases, '
        'and it keeps its trailing period', () {
      expect(DateFormat('LLL', 'uk').format(august), 'серп.',
          reason: 'the gantt month header and the month-card label render '
              'this string, uppercased by the widget');
      expect(DateFormat('MMM', 'uk').format(august), 'серп.');
      // Uppercasing goes through the intl output, never a hardcoded literal.
      expect(DateFormat('LLL', 'uk').format(august).toUpperCase(), 'СЕРП.');
    });
  });

  group('en month case', () {
    test('standalone and format forms coincide — the rule is a no-op in en, '
        'which is exactly why it has to be pinned in uk', () {
      expect(DateFormat('LLLL y', 'en').format(august), 'August 2026');
      expect(DateFormat('MMMM y', 'en').format(august), 'August 2026');
    });
  });
}
