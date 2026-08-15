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

    test('slotsPerDay covers all four CLDR forms incl. 11-14 exception '
        '(NOT the mockup 2-form bug, PF-7)', () {
      expect(l10n.slotsPerDay(1), '1 раз на день'); // one
      expect(l10n.slotsPerDay(2), '2 рази на день'); // few
      expect(l10n.slotsPerDay(5), '5 разів на день'); // many
      expect(l10n.slotsPerDay(11), '11 разів на день'); // many (11-14)
      expect(l10n.slotsPerDay(21), '21 раз на день'); // one (i%10=1)
    });

    test('stackSummary declines BOTH plural placeholders correctly at '
        '1/2/5/11/21 (UI-SPEC #5)', () {
      expect(l10n.stackSummary(1, 1), '1 добавка · 1 активна'); // one/one
      expect(l10n.stackSummary(2, 2), '2 добавки · 2 активні'); // few/few
      expect(l10n.stackSummary(5, 5), '5 добавок · 5 активних'); // many/many
      expect(l10n.stackSummary(11, 11), '11 добавок · 11 активних'); // 11-14
      expect(l10n.stackSummary(21, 21), '21 добавка · 21 активна'); // one
      // Mixed forms: the placeholders decline independently.
      expect(l10n.stackSummary(5, 1), '5 добавок · 1 активна');
    });

    test('ringSemantics declines `доза` after «з» at 1/2/5/11/21 (PF-8)', () {
      expect(l10n.ringSemantics(0, 1), '0 з 1 дози прийнято'); // one
      expect(l10n.ringSemantics(1, 2), '1 з 2 доз прийнято'); // few
      expect(l10n.ringSemantics(3, 5), '3 з 5 доз прийнято'); // many
      expect(l10n.ringSemantics(4, 11), '4 з 11 доз прийнято'); // many (11-14)
      expect(l10n.ringSemantics(21, 21), '21 з 21 дози прийнято'); // one
    });

    test('blockProgress and doseCycleChip interpolate bare numerals', () {
      expect(l10n.blockProgress(1, 3), '1 з 3');
      expect(l10n.doseCycleChip(2, 3), 'доза 2 з 3');
    });

    test('monthsCount covers all four CLDR forms incl. 11-14 exception', () {
      expect(l10n.monthsCount(1), '1 місяць'); // one
      expect(l10n.monthsCount(2), '2 місяці'); // few
      expect(l10n.monthsCount(5), '5 місяців'); // many
      expect(l10n.monthsCount(11), '11 місяців'); // many (11-14 exception)
      expect(l10n.monthsCount(21), '21 місяць'); // one (i%10=1)
    });

    test('cyclesCount covers all four CLDR forms incl. 11-14 exception', () {
      expect(l10n.cyclesCount(1), '1 цикл'); // one
      expect(l10n.cyclesCount(2), '2 цикли'); // few
      expect(l10n.cyclesCount(5), '5 циклів'); // many
      expect(l10n.cyclesCount(11), '11 циклів'); // many (11-14 exception)
      expect(l10n.cyclesCount(21), '21 цикл'); // one (i%10=1)
    });

    test('periodsCount covers all four CLDR forms incl. 11-14 exception', () {
      expect(l10n.periodsCount(1), '1 період'); // one
      expect(l10n.periodsCount(2), '2 періоди'); // few
      expect(l10n.periodsCount(5), '5 періодів'); // many
      expect(l10n.periodsCount(11), '11 періодів'); // many (11-14 exception)
      expect(l10n.periodsCount(21), '21 період'); // one (i%10=1)
    });

    test('planner sentence keys take PRE-FORMATTED counts, never a nested '
        'plural block', () {
      // The composition convention: the count is declined once, by its own
      // plural key, then passed in as a finished string.
      expect(
        l10n.plannerThisWeek(l10n.substancesCount(5)),
        'Цього тижня одночасно 5 речовин',
      );
      expect(
        l10n.weekNoteOverLimit(l10n.cyclesCount(2)),
        'Цього тижня перетинаються 2 цикли. Варто зсунути старт частини з '
        'них або обговорити такий обсяг із лікарем.',
      );
      expect(
        l10n.plannerYearSubtitle('2026', l10n.monthsCount(12)),
        '2026 · 12 місяців',
      );
      expect(
        l10n.monthMeta(l10n.substancesCount(1), 5),
        '1 речовина · межа 5',
      );
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

    test('slotsPerDay uses one/other', () {
      expect(l10n.slotsPerDay(1), '1 time per day');
      expect(l10n.slotsPerDay(2), '2 times per day');
    });

    test('stackSummary uses one/other on both placeholders', () {
      expect(l10n.stackSummary(1, 1), '1 supplement · 1 active');
      expect(l10n.stackSummary(2, 0), '2 supplements · 0 active');
    });

    test('ringSemantics uses one/other on total', () {
      expect(l10n.ringSemantics(0, 1), '0 of 1 dose taken');
      expect(l10n.ringSemantics(1, 2), '1 of 2 doses taken');
      expect(l10n.ringSemantics(5, 21), '5 of 21 doses taken');
    });

    test('blockProgress and doseCycleChip interpolate bare numerals', () {
      expect(l10n.blockProgress(1, 3), '1 of 3');
      expect(l10n.doseCycleChip(2, 3), 'dose 2 of 3');
    });

    test('monthsCount uses one/other', () {
      expect(l10n.monthsCount(1), '1 month');
      expect(l10n.monthsCount(2), '2 months');
      expect(l10n.monthsCount(21), '21 months');
    });

    test('cyclesCount uses one/other', () {
      expect(l10n.cyclesCount(1), '1 cycle');
      expect(l10n.cyclesCount(2), '2 cycles');
      expect(l10n.cyclesCount(21), '21 cycles');
    });

    test('periodsCount uses one/other', () {
      expect(l10n.periodsCount(1), '1 period');
      expect(l10n.periodsCount(2), '2 periods');
      expect(l10n.periodsCount(21), '21 periods');
    });
  });
}
