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
  group('plannerWindow — [first of LAST month, +4 months)', () {
    test('starts on the first of the month BEFORE today\'s, whatever day it is',
        () {
      final w = plannerWindow(DateTime.utc(2026, 8, 13));
      expect(w.start, DateTime.utc(2026, 7, 1),
          reason: 'owner change 2026-09-01: the window is last month, this '
              'month and two ahead. A planner that begins at today\'s month '
              'cannot show the break the user is currently coming out of, '
              'which is exactly the context a cycle needs to be read in');
      expect(w.endExclusive, DateTime.utc(2026, 11, 1));
    });

    test('today always has a WHOLE month of band behind it', () {
      // The property the shift exists for. `start.isBefore(today)` was true
      // under the old window too, so asserting only that would leave this
      // test green if the shift were reverted — it has to name the month.
      for (final month in List.generate(12, (i) => i + 1)) {
        final today = DateTime.utc(2027, month, 15);
        final w = plannerWindow(today);
        expect(w.start, addMonths(firstOfMonth(today), -1), reason: '$today');
        expect(w.endExclusive.isAfter(today), isTrue, reason: '$today');
        // At least 28 days of history, whatever the previous month's length.
        expect(today.difference(w.start).inDays, greaterThanOrEqualTo(28 + 14),
            reason: '$today: a full previous month plus the day-of-month');
      }
    });

    test('a January today opens the window in the PREVIOUS year', () {
      final w = plannerWindow(DateTime.utc(2027, 1, 20));
      expect(w.start, DateTime.utc(2026, 12, 1),
          reason: 'the year boundary is the case the subtitle has a separate '
              'cross-year string for, and stepping back a month is what makes '
              'it reachable in January rather than never');
      expect(w.endExclusive, DateTime.utc(2027, 4, 1));
    });

    test('a window opened in August 2026 spans 123 days (31+31+30+31)', () {
      expect(plannerWindow(DateTime.utc(2026, 8, 13)).span, 123,
          reason: 'Jul..Oct, not the Aug..Nov 122 the mockup drew — the span '
              'follows the real month lengths of the SHIFTED window');
    });

    test('March 2027 spans 120 — the SHORTEST four-month window', () {
      final w = plannerWindow(DateTime.utc(2027, 3, 10));
      expect(w.start, DateTime.utc(2027, 2, 1));
      expect(w.endExclusive, DateTime.utc(2027, 6, 1));
      expect(w.span, 120, reason: '28+31+30+31 — never assume 122 (P-4)');
    });

    test('August 2027 spans 123 — the LONGEST four-month window', () {
      final w = plannerWindow(DateTime.utc(2027, 8, 4));
      expect(w.start, DateTime.utc(2027, 7, 1));
      expect(w.span, 123, reason: '31+31+30+31 — never assume 122 (P-4)');
    });

    test('a window opened on the last day of the month still starts on a 1st',
        () {
      final w = plannerWindow(DateTime.utc(2026, 8, 31));
      expect(w.start, DateTime.utc(2026, 7, 1));
      expect(w.span, 123);
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
          // The window opens on the first of the month BEFORE this one, so
          // a January today steps back into December of the previous year.
          expect(w.start, addMonths(DateTime.utc(year, month, 1), -1));
        });
      }
    }

    test('November and December windows cross into the next year', () {
      for (final month in [11, 12]) {
        final w = plannerWindow(DateTime.utc(2026, month, 5));
        expect(w.endExclusive.year, 2027,
            reason: 'month $month: the window ends in the next year');
      }
    });
  });

  group('month-column fractions — what the labels and gridlines lay out from',
      () {
    // Restored after the window shift: this group was dropped when the file's
    // tail was rewritten, and the only trace was an "unused import" warning
    // that got silenced instead of investigated. It asserts something the
    // span sweep above does NOT — that the four columns TILE the window with
    // no gap, which is what every gridline after a shortfall depends on.
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

    test('a leap February column carries 29 days inside the cycles model', () {
      // The window opened in March 2028 starts in February — the leap month
      // is a real column, not an edge case reached only by daysInMonth().
      final model = buildCyclesModel(const [],
          today: DateTime.utc(2028, 3, 9));
      final february =
          model.months.firstWhere((m) => m.month == DateTime.utc(2028, 2, 1));
      expect(february.days, 29);
      expect(model.span, 29 + 31 + 30 + 31);
    });
  });
}
