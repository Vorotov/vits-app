/// Window and month-length proofs for the planner (plan 04-01, PF-3, P-4).
///
/// Pure unit tests in the `cycle_math_test.dart` style: no widgets, no
/// providers, no clock — every date is an explicit UTC date-only fixture.
///
/// `core/domain` carries a build-breaking-warnings bar in this project
/// precisely because date math is bug-prone, so these are load-bearing, not
/// defensive: the gantt's month labels, its gridlines and the Year matrix's
/// coverage denominators are all laid out from exactly these numbers.
library;

import 'package:boostque/core/domain/cycle_math.dart';
import 'package:boostque/features/calendar/planner_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('plannerWindow — [first of this month, +4 months)', () {
    test('starts on the first of today\'s month, whatever day it is', () {
      final w = plannerWindow(DateTime.utc(2026, 8, 13));
      expect(w.start, DateTime.utc(2026, 8, 1));
      expect(w.endExclusive, DateTime.utc(2026, 12, 1));
    });

    test('August 2026 spans 122 days (the mockup figure, 31+30+31+30)', () {
      expect(plannerWindow(DateTime.utc(2026, 8, 13)).span, 122);
    });

    test('February 2027 spans 120 — the SHORTEST four-month window', () {
      final w = plannerWindow(DateTime.utc(2027, 2, 10));
      expect(w.start, DateTime.utc(2027, 2, 1));
      expect(w.endExclusive, DateTime.utc(2027, 6, 1));
      expect(w.span, 120, reason: '28+31+30+31 — never assume 122 (P-4)');
    });

    test('July 2027 spans 123 — the LONGEST four-month window', () {
      final w = plannerWindow(DateTime.utc(2027, 7, 4));
      expect(w.span, 123, reason: '31+31+30+31 — never assume 122 (P-4)');
    });

    test('a window opened on the last day of the month still starts on the 1st',
        () {
      final w = plannerWindow(DateTime.utc(2026, 8, 31));
      expect(w.start, DateTime.utc(2026, 8, 1));
      expect(w.span, 122);
    });
  });

  group('daysInMonth — computed, never a table (PF-3)', () {
    test('February 2028 is 29 days (leap)', () {
      expect(daysInMonth(DateTime.utc(2028, 2, 5)), 29);
    });

    test('February 2027 is 28 days', () {
      expect(daysInMonth(DateTime.utc(2027, 2, 5)), 28);
    });

    test('the 30/31-day months', () {
      expect(daysInMonth(DateTime.utc(2026, 8, 1)), 31);
      expect(daysInMonth(DateTime.utc(2026, 9, 1)), 30);
      expect(daysInMonth(DateTime.utc(2026, 12, 31)), 31);
    });
  });

  group('firstOfMonth / addMonths', () {
    test('firstOfMonth normalizes any day to its month start, date-only UTC',
        () {
      expect(firstOfMonth(DateTime.utc(2026, 8, 13, 23, 59)),
          DateTime.utc(2026, 8, 1));
    });

    test('addMonths carries the year without hand-written carry arithmetic',
        () {
      expect(addMonths(DateTime.utc(2026, 11, 20), 4),
          DateTime.utc(2027, 3, 1));
      expect(addMonths(DateTime.utc(2026, 12, 1), 4), DateTime.utc(2027, 4, 1));
    });
  });

  group('mondayOfWeek — promoted from week_strip.dart (DECIDED-3, A4)', () {
    test('a Monday is its own week start', () {
      expect(mondayOfWeek(DateTime.utc(2026, 8, 10)),
          DateTime.utc(2026, 8, 10));
    });

    test('a Sunday belongs to the week that STARTED six days earlier', () {
      expect(mondayOfWeek(DateTime.utc(2026, 8, 16)),
          DateTime.utc(2026, 8, 10));
    });

    test('crossing a month boundary backwards is fine', () {
      // 1 August 2026 is a Saturday; its Monday is 27 July.
      expect(mondayOfWeek(DateTime.utc(2026, 8, 1)), DateTime.utc(2026, 7, 27));
    });
  });

  group('the twelve start months — every window, not just the mockup\'s', () {
    // 2026 is a common year, 2028 a leap year: running both proves the span is
    // read off the calendar rather than off a table.
    for (final year in [2026, 2028]) {
      for (var month = 1; month <= 12; month++) {
        test('a window opened in $month/$year spans the true sum of its four '
            'month lengths', () {
          final w = plannerWindow(DateTime.utc(year, month, 15));

          var expected = 0;
          for (var i = 0; i < 4; i++) {
            expected += daysInMonth(addMonths(w.start, i));
          }

          expect(w.span, expected);
          expect(w.span, inInclusiveRange(120, 123),
              reason: 'a four-month window is never outside 120..123 days');
          expect(w.start, DateTime.utc(year, month, 1));
        });
      }
    }

    test('October, November and December windows cross into the next year',
        () {
      for (final month in [10, 11, 12]) {
        final w = plannerWindow(DateTime.utc(2026, month, 5));
        expect(w.endExclusive.year, 2027,
            reason: 'month $month + 4 lands in the next year');

        final model = buildCyclesModel(const [], today: DateTime.utc(2026, month, 5));
        final crossing = model.months.where((m) => m.month.year == 2027);
        expect(crossing, isNotEmpty);
        // The columns are consecutive months, carried across the year change.
        for (var i = 1; i < model.months.length; i++) {
          expect(model.months[i].month,
              addMonths(model.months[i - 1].month, 1));
        }
      }
    });

    test('a leap-year February column is 29 days wide', () {
      // A window opened in December 2027 covers Dec, Jan, Feb 2028, Mar.
      final model = buildCyclesModel(const [], today: DateTime.utc(2027, 12, 1));
      final february =
          model.months.firstWhere((m) => m.month == DateTime.utc(2028, 2, 1));
      expect(february.days, 29);
      expect(model.span, 31 + 31 + 29 + 31);
    });
  });

  group('month-column fractions — what the labels and gridlines lay out from',
      () {
    for (final year in [2026, 2028]) {
      for (var month = 1; month <= 12; month++) {
        test('$month/$year: fractions are positive and sum to 1.0', () {
          final model =
              buildCyclesModel(const [], today: DateTime.utc(year, month, 9));

          expect(model.months, hasLength(4));
          for (final m in model.months) {
            expect(m.fraction, greaterThan(0),
                reason: 'a zero-width month column would collapse a label');
            expect(m.days, greaterThan(0));
          }
          expect(
            model.months.fold<double>(0, (sum, m) => sum + m.fraction),
            closeTo(1.0, 1e-9),
            reason: 'the four columns tile the window exactly — a shortfall '
                'would misplace every gridline after it',
          );
        });
      }
    }
  });
}
