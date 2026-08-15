/// Pure proofs for the planner's derivations (plan 04-01, PF-1, PF-6,
/// DECIDED-4/7).
///
/// Fixture builders follow `cycle_math_test.dart` / `day_view_model_test.dart`:
/// local `cyclic(...)` / `course(...)` helpers, every date a UTC date-only
/// value, no widgets and no clock — `today` is always an explicit argument.
library;

import 'package:boostque/core/domain/models.dart';
import 'package:boostque/core/domain/repositories.dart';
import 'package:boostque/features/calendar/planner_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

/// A cyclic regimen; defaults to the 14-on/14-off cadence the window cases use.
Regimen cyclic({
  String id = 'r1',
  String supplementId = 's1',
  int on = 14,
  int off = 14,
  bool paused = false,
  DateTime? start,
}) =>
    Regimen(
      id: id,
      supplementId: supplementId,
      kind: RegimenKind.cyclic,
      startDate: start ?? DateTime.utc(2026, 8, 1),
      endDate: null,
      onDays: on,
      offDays: off,
      paused: paused,
      slots: const [],
    );

/// A one-time course. A null [end] is the PF-11 case: it contributes nothing.
Regimen course({
  String id = 'r2',
  String supplementId = 's2',
  DateTime? start,
  DateTime? end,
}) =>
    Regimen(
      id: id,
      supplementId: supplementId,
      kind: RegimenKind.course,
      startDate: start ?? DateTime.utc(2026, 8, 1),
      endDate: end,
      onDays: 0,
      offDays: 0,
      paused: false,
      slots: const [],
    );

Supplement supp(String id, String name) => Supplement(
      id: id,
      name: name,
      doseText: '400 мг',
      colorValue: 0xFF6B6FA8,
      note: '',
    );

void main() {
  final today = DateTime.utc(2026, 8, 13);
  final windowStart = DateTime.utc(2026, 8, 1);
  final windowLast = DateTime.utc(2026, 11, 30);
  const span = 122;

  group('activeRuns — the ONLY activity decision in the planner (PF-1)', () {
    test('a 14-on/14-off cycle coalesces into the exact cadence', () {
      final runs = activeRuns(cyclic(), windowStart, windowLast);

      // 1 Aug + 28k for each cycle start; each run is 14 days inclusive.
      expect(runs.first.start, DateTime.utc(2026, 8, 1));
      expect(runs.first.end, DateTime.utc(2026, 8, 14));
      expect(runs[1].start, DateTime.utc(2026, 8, 29));
      expect(runs[1].end, DateTime.utc(2026, 9, 11));
      expect(runs[2].start, DateTime.utc(2026, 9, 26));
      expect(runs[2].end, DateTime.utc(2026, 10, 9));

      for (final r in runs) {
        expect(r.end.difference(r.start).inDays, lessThanOrEqualTo(13),
            reason: 'no run may exceed the 14-day on-phase');
        expect(r.start.isAfter(r.end), isFalse);
      }
    });

    test('the final run is clipped to the window\'s last day', () {
      final runs = activeRuns(cyclic(), windowStart, windowLast);
      expect(runs.last.end, isNot(isNull));
      expect(runs.last.end.isAfter(windowLast), isFalse,
          reason: 'a run may never extend past the scanned window');
      // 21 Nov starts the fifth on-phase, which would run to 4 Dec unclipped.
      expect(runs.last.start, DateTime.utc(2026, 11, 21));
      expect(runs.last.end, windowLast);
    });

    test('a paused regimen produces no runs at all (DECIDED-7)', () {
      expect(activeRuns(cyclic(paused: true), windowStart, windowLast),
          isEmpty);
    });

    test('a course with a null endDate produces no runs (PF-11)', () {
      expect(activeRuns(course(end: null), windowStart, windowLast), isEmpty);
    });

    test('a course with an end date produces exactly one run', () {
      final runs = activeRuns(
        course(start: DateTime.utc(2026, 9, 1), end: DateTime.utc(2026, 9, 10)),
        windowStart,
        windowLast,
      );
      expect(runs, hasLength(1));
      expect(runs.single.start, DateTime.utc(2026, 9, 1));
      expect(runs.single.end, DateTime.utc(2026, 9, 10));
    });

    test('a one-day run survives as a run of equal start and end (PF-6)', () {
      final runs = activeRuns(
        course(start: DateTime.utc(2026, 9, 5), end: DateTime.utc(2026, 9, 5)),
        windowStart,
        windowLast,
      );
      expect(runs, hasLength(1));
      expect(runs.single.start, runs.single.end);
    });

    test('the returned list is unmodifiable', () {
      final runs = activeRuns(cyclic(), windowStart, windowLast);
      expect(
        () => runs.add(DateRun(start: windowStart, end: windowStart)),
        throwsUnsupportedError,
      );
    });
  });

  group('ganttSegments — a run is planned as a WHOLE (DECIDED-4)', () {
    test('a run starting strictly after today is planned', () {
      final runs = [
        DateRun(start: DateTime.utc(2026, 8, 14), end: DateTime.utc(2026, 8, 20))
      ];
      expect(ganttSegments(runs, windowStart, span, today).single.planned,
          isTrue);
    });

    test('a run starting ON today is active, not planned', () {
      final runs = [DateRun(start: today, end: DateTime.utc(2026, 8, 20))];
      expect(ganttSegments(runs, windowStart, span, today).single.planned,
          isFalse);
    });

    test('a run already in progress stays active, tail included', () {
      final runs = [
        DateRun(start: DateTime.utc(2026, 8, 1), end: DateTime.utc(2026, 9, 30))
      ];
      final seg = ganttSegments(runs, windowStart, span, today).single;
      expect(seg.planned, isFalse,
          reason: 'the future tail of a started cycle is NOT hatched — '
              'it agrees with the Stack tab\'s statusOf');
    });

    test('fractions place a run at its true offset, end-inclusive', () {
      final runs = [
        DateRun(start: DateTime.utc(2026, 8, 1), end: DateTime.utc(2026, 8, 1))
      ];
      final seg = ganttSegments(runs, windowStart, span, today).single;
      expect(seg.startFraction, 0.0);
      expect(seg.endFraction, closeTo(1 / span, 1e-9),
          reason: 'a one-day run closes at the END of that day');
      expect(seg.endFraction, greaterThan(seg.startFraction),
          reason: 'a one-day run is never a zero-width band (PF-6)');
    });

    test('no run means no segment', () {
      expect(ganttSegments(const [], windowStart, span, today), isEmpty);
    });
  });

  group('buildCyclesModel', () {
    final magnesium = supp('s1', 'Магній');
    final creatine = supp('s2', 'Креатин');

    test('keeps stack order and excludes entries with no regimen (DECIDED-7)',
        () {
      final model = buildCyclesModel(
        [
          StackEntry(supplement: magnesium, regimen: cyclic()),
          StackEntry(supplement: creatine), // fresh — no regimen
        ],
        today: today,
      );

      expect(model.rows, hasLength(1));
      expect(model.rows.single.entry.supplement.id, 's1');
    });

    test('a paused regimen KEEPS its row and carries zero segments', () {
      final model = buildCyclesModel(
        [
          StackEntry(supplement: magnesium, regimen: cyclic()),
          StackEntry(
            supplement: creatine,
            regimen: cyclic(id: 'r2', supplementId: 's2', paused: true),
          ),
        ],
        today: today,
      );

      expect(model.rows, hasLength(2), reason: 'a paused row is never hidden');
      expect(model.rows[0].entry.supplement.id, 's1');
      expect(model.rows[1].entry.supplement.id, 's2');
      expect(model.rows[1].segments, isEmpty);
      expect(model.rows[1].runCount, 0);
    });

    test('carries the derived window, never an assumed 122', () {
      final model = buildCyclesModel(const [], today: DateTime.utc(2027, 2, 10));
      expect(model.windowStart, DateTime.utc(2027, 2, 1));
      expect(model.windowEndExclusive, DateTime.utc(2027, 6, 1));
      expect(model.span, 120);
    });

    test('month columns come from real month lengths and sum to 1.0', () {
      final model = buildCyclesModel(const [], today: today);
      expect(model.months.map((m) => m.days), [31, 30, 31, 30]);
      expect(
        model.months.fold<double>(0, (sum, m) => sum + m.fraction),
        closeTo(1.0, 1e-9),
      );
    });

    test('todayIndex is today\'s offset into the window', () {
      expect(buildCyclesModel(const [], today: today).todayIndex, 12,
          reason: '13 August is the 13th day, index 12');
    });
  });

  group('weekBuckets — full Monday weeks (DECIDED-3)', () {
    final buckets =
        weekBuckets(windowStart, DateTime.utc(2026, 12, 1));

    test('starts on the Monday on or before the window start', () {
      // 1 August 2026 is a Saturday; its Monday is 27 July.
      expect(buckets.first.start, DateTime.utc(2026, 7, 27));
    });

    test('ends with the week containing the window\'s last day', () {
      expect(buckets.last.start.isAfter(windowLast), isFalse);
      expect(buckets.last.endInclusive.isBefore(windowLast), isFalse);
    });

    test('EVERY bucket is exactly 7 days — no clamped short first week', () {
      for (final b in buckets) {
        expect(b.endInclusive.difference(b.start).inDays, 6,
            reason: 'a one-day bar beside seventeen seven-day bars is an '
                'honest number that reads as a lie');
      }
    });

    test('the Aug-to-Nov window produces 18 or 19 buckets', () {
      expect(buckets.length, anyOf(18, 19));
    });

    test('buckets are contiguous and strictly ordered', () {
      for (var i = 1; i < buckets.length; i++) {
        expect(buckets[i].start,
            buckets[i - 1].endInclusive.add(const Duration(days: 1)));
      }
    });
  });

  group('weekLoads — a supplement counts ONCE per bucket (P-6)', () {
    final magnesium = supp('s1', 'Магній');
    final creatine = supp('s2', 'Креатин');
    final buckets = weekBuckets(windowStart, DateTime.utc(2026, 12, 1));

    /// The bucket holding [day].
    int bucketOf(DateTime day) =>
        buckets.indexWhere((b) => !b.start.isAfter(day) && !b.endInclusive.isBefore(day));

    test('one active day in a bucket counts once, not once per active day',
        () {
      final model = buildCyclesModel(
        [
          StackEntry(
            supplement: magnesium,
            // A single day: Wednesday 2 September 2026.
            regimen: course(
              start: DateTime.utc(2026, 9, 2),
              end: DateTime.utc(2026, 9, 2),
            ),
          ),
        ],
        today: today,
      );
      final loads = weekLoads(model.rows, buckets);

      final hit = loads[bucketOf(DateTime.utc(2026, 9, 2))];
      expect(hit.load, 1);
      expect(hit.entries.single.supplement.id, 's1');
    });

    test('a supplement active on no day of a bucket contributes zero', () {
      final model = buildCyclesModel(
        [
          StackEntry(
            supplement: magnesium,
            regimen: course(
              start: DateTime.utc(2026, 9, 2),
              end: DateTime.utc(2026, 9, 2),
            ),
          ),
        ],
        today: today,
      );
      final loads = weekLoads(model.rows, buckets);

      expect(loads[bucketOf(DateTime.utc(2026, 10, 20))].load, 0);
      expect(loads[bucketOf(DateTime.utc(2026, 10, 20))].entries, isEmpty);
    });

    test('a paused regimen contributes zero to EVERY bucket (DECIDED-7)', () {
      final model = buildCyclesModel(
        [
          StackEntry(supplement: magnesium, regimen: cyclic(paused: true)),
        ],
        today: today,
      );
      final loads = weekLoads(model.rows, buckets);

      expect(loads.every((w) => w.load == 0), isTrue);
    });

    test('concurrent supplements stack, in stack order', () {
      final model = buildCyclesModel(
        [
          StackEntry(
            supplement: magnesium,
            regimen: course(
              start: DateTime.utc(2026, 9, 1),
              end: DateTime.utc(2026, 9, 30),
            ),
          ),
          StackEntry(
            supplement: creatine,
            regimen: course(
              id: 'r3',
              supplementId: 's2',
              start: DateTime.utc(2026, 9, 1),
              end: DateTime.utc(2026, 9, 30),
            ),
          ),
        ],
        today: today,
      );
      final loads = weekLoads(model.rows, buckets);

      final week = loads[bucketOf(DateTime.utc(2026, 9, 15))];
      expect(week.load, 2);
      expect(week.entries.map((e) => e.supplement.id), ['s1', 's2']);
    });

    test('there is exactly one WeekLoad per bucket', () {
      final loads = weekLoads(const [], buckets);
      expect(loads, hasLength(buckets.length));
    });
  });

  group('verdictOf — three editorial bands, both sides of each boundary', () {
    test('the boundaries live in exactly one place', () {
      expect(comfortLoad, 3);
      expect(editorialLimit, 5);
    });

    test('load 0 and 3 are comfort', () {
      expect(verdictOf(0), isA<ComfortVerdict>());
      expect(verdictOf(3), isA<ComfortVerdict>());
    });

    test('load 4 and 5 are at the limit', () {
      expect(verdictOf(4), isA<LimitVerdict>());
      expect(verdictOf(5), isA<LimitVerdict>());
    });

    test('load 6 is over the limit and CARRIES the load', () {
      final v = verdictOf(6);
      expect(v, isA<OverLimitVerdict>());
      expect((v as OverLimitVerdict).load, 6);
    });
  });

  group('monthCellFor — coverage, fullness and the planned rule (P-10)', () {
    test('the fullness boundary: 0.84 is not full, 0.85 is', () {
      expect(const MonthCell(frac: 0.84, planned: false).full, isFalse);
      expect(const MonthCell(frac: 0.85, planned: false).full, isTrue);
      expect(fullMonthFraction, 0.85);
    });

    test('coverage days are summed against the month\'s REAL length', () {
      final cell = monthCellFor(
        [
          DateRun(
            start: DateTime.utc(2026, 9, 1),
            end: DateTime.utc(2026, 9, 15),
          ),
        ],
        DateTime.utc(2026, 9, 1),
        30,
        today,
      );
      expect(cell.frac, closeTo(15 / 30, 1e-9));
      expect(cell.full, isFalse);
    });

    test('a run overlapping the month edges is clipped to the month', () {
      final cell = monthCellFor(
        [
          DateRun(
            start: DateTime.utc(2026, 8, 20),
            end: DateTime.utc(2026, 10, 5),
          ),
        ],
        DateTime.utc(2026, 9, 1),
        30,
        today,
      );
      expect(cell.frac, closeTo(1.0, 1e-9));
      expect(cell.full, isTrue);
    });

    test('a month whose WHOLE coverage starts after today is planned', () {
      final cell = monthCellFor(
        [
          DateRun(
            start: DateTime.utc(2026, 10, 1),
            end: DateTime.utc(2026, 10, 10),
          ),
        ],
        DateTime.utc(2026, 10, 1),
        31,
        today,
      );
      expect(cell.planned, isTrue);
    });

    test('any already-started coverage makes the month NOT planned', () {
      final cell = monthCellFor(
        [
          // Started before today and still running.
          DateRun(
            start: DateTime.utc(2026, 8, 1),
            end: DateTime.utc(2026, 8, 20),
          ),
          // Plus a later, planned run in the same month.
          DateRun(
            start: DateTime.utc(2026, 8, 25),
            end: DateTime.utc(2026, 8, 28),
          ),
        ],
        DateTime.utc(2026, 8, 1),
        31,
        today,
      );
      expect(cell.planned, isFalse);
    });

    test('zero coverage is neither full nor planned', () {
      final cell = monthCellFor(const [], DateTime.utc(2026, 9, 1), 30, today);
      expect(cell.frac, 0);
      expect(cell.full, isFalse);
      expect(cell.planned, isFalse,
          reason: 'planned requires coverage to exist at all');
    });
  });

  group('buildYearModel — always today\'s year, Jan to Dec (DECIDED-9)', () {
    final magnesium = supp('s1', 'Магній');
    final creatine = supp('s2', 'Креатин');
    final vitaminD = supp('s3', 'Вітамін D3');

    test('returns exactly 12 months of today\'s year', () {
      final model = buildYearModel(const [], today: today);
      expect(model.year, 2026);
      expect(model.months, hasLength(12));
      expect(model.months.first.month, DateTime.utc(2026, 1, 1));
      expect(model.months.last.month, DateTime.utc(2026, 12, 1));
    });

    test('February is 29 days long in a leap year', () {
      final leap = buildYearModel(const [], today: DateTime.utc(2028, 6, 1));
      expect(leap.months[1].days, 29);
      expect(buildYearModel(const [], today: DateTime.utc(2027, 6, 1))
          .months[1].days, 28);
    });

    test('a February coverage fraction uses 29 as its denominator in a leap '
        'year', () {
      final model = buildYearModel(
        [
          StackEntry(
            supplement: magnesium,
            regimen: course(
              start: DateTime.utc(2028, 2, 1),
              end: DateTime.utc(2028, 2, 29),
            ),
          ),
        ],
        today: DateTime.utc(2028, 1, 1),
      );
      expect(model.months[1].cells.single.frac, closeTo(1.0, 1e-9));
    });

    test('excludes entries with no regimen from both the entry list and the '
        'cells (DECIDED-7)', () {
      final model = buildYearModel(
        [
          StackEntry(supplement: magnesium, regimen: cyclic()),
          StackEntry(supplement: vitaminD),
        ],
        today: today,
      );
      expect(model.entries, hasLength(1));
      expect(model.entries.single.supplement.id, 's1');
      for (final m in model.months) {
        expect(m.cells, hasLength(1));
      }
    });

    test('a paused regimen keeps its column but contributes zero coverage',
        () {
      final model = buildYearModel(
        [StackEntry(supplement: magnesium, regimen: cyclic(paused: true))],
        today: today,
      );
      expect(model.entries, hasLength(1));
      for (final m in model.months) {
        expect(m.cells.single.frac, 0);
        expect(m.load, 0);
      }
    });

    test('month load counts entries with any coverage at all', () {
      final model = buildYearModel(
        [
          StackEntry(
            supplement: magnesium,
            regimen: course(
              start: DateTime.utc(2026, 9, 1),
              end: DateTime.utc(2026, 9, 2),
            ),
          ),
          StackEntry(
            supplement: creatine,
            regimen: course(
              id: 'r3',
              supplementId: 's2',
              start: DateTime.utc(2026, 9, 20),
              end: DateTime.utc(2026, 9, 25),
            ),
          ),
        ],
        today: today,
      );
      expect(model.months[8].load, 2, reason: 'both cover part of September');
      expect(model.months[7].load, 0);
    });

    test('the peak is the busiest month, untied when it stands alone', () {
      final model = buildYearModel(
        [
          StackEntry(
            supplement: magnesium,
            regimen: course(
              start: DateTime.utc(2026, 10, 1),
              end: DateTime.utc(2026, 10, 31),
            ),
          ),
          StackEntry(
            supplement: creatine,
            regimen: course(
              id: 'r3',
              supplementId: 's2',
              start: DateTime.utc(2026, 10, 5),
              end: DateTime.utc(2026, 10, 20),
            ),
          ),
        ],
        today: today,
      );
      expect(model.peakIndex, 9, reason: 'October');
      expect(model.peakTied, isFalse);
    });

    test('a regimen starting AFTER the window still contributes month cells '
        'inside the calendar year (E-8)', () {
      // The window is Aug..Nov 2026; this course starts in December.
      final entry = StackEntry(
        supplement: magnesium,
        regimen: course(
          start: DateTime.utc(2026, 12, 5),
          end: DateTime.utc(2026, 12, 20),
        ),
      );

      final cycles = buildCyclesModel([entry], today: today);
      expect(cycles.rows.single.segments, isEmpty,
          reason: 'nothing of it falls inside the four-month window');

      final year = buildYearModel([entry], today: today);
      expect(year.months[11].cells.single.frac, greaterThan(0),
          reason: 'December is still inside the rendered calendar year');
      expect(year.months[11].cells.single.planned, isTrue);
      expect(year.months[11].load, 1);
    });

    test('a tied peak breaks toward the month nearest today AND reports the '
        'tie', () {
      final model = buildYearModel(
        [
          StackEntry(
            supplement: magnesium,
            // Equal load in March and September; today is in August, so
            // September is nearer.
            regimen: course(
              start: DateTime.utc(2026, 3, 1),
              end: DateTime.utc(2026, 3, 31),
            ),
          ),
          StackEntry(
            supplement: creatine,
            regimen: course(
              id: 'r3',
              supplementId: 's2',
              start: DateTime.utc(2026, 9, 1),
              end: DateTime.utc(2026, 9, 30),
            ),
          ),
        ],
        today: today,
      );
      expect(model.peakTied, isTrue);
      expect(model.peakIndex, 8, reason: 'September is nearer to August');
    });
  });

  group('regimen-shape edges — the planner\'s observable consequence', () {
    final magnesium = supp('s1', 'Магній');

    test('offDays zero produces ONE continuous run to the window edge', () {
      final model = buildCyclesModel(
        [StackEntry(supplement: magnesium, regimen: cyclic(on: 30, off: 0))],
        today: today,
      );

      final row = model.rows.single;
      expect(row.runs, hasLength(1),
          reason: 'an always-on cycle never breaks');
      expect(row.runs.single.start, windowStart);
      expect(row.runs.single.end, windowLast);
      expect(row.segments.single.startFraction, 0.0);
      expect(row.segments.single.endFraction, closeTo(1.0, 1e-9),
          reason: 'one full-width segment (UI-SPEC E2 zero-one-many)');
    });

    test('onDays zero produces NO run at all', () {
      final model = buildCyclesModel(
        [StackEntry(supplement: magnesium, regimen: cyclic(on: 0, off: 14))],
        today: today,
      );

      expect(model.rows.single.runs, isEmpty);
      expect(model.rows.single.segments, isEmpty,
          reason: 'a bare track, and the row is still there');
      expect(model.weeks.every((w) => w.load == 0), isTrue);
    });

    test('a one-day run paints a real, non-empty segment (PF-6, E2)', () {
      final model = buildCyclesModel(
        [
          StackEntry(
            supplement: magnesium,
            regimen: course(
              start: DateTime.utc(2026, 9, 5),
              end: DateTime.utc(2026, 9, 5),
            ),
          ),
        ],
        today: today,
      );

      final seg = model.rows.single.segments.single;
      expect(seg.endFraction - seg.startFraction, closeTo(1 / span, 1e-9));
      expect(seg.endFraction, greaterThan(seg.startFraction),
          reason: 'the painter\'s 2px floor is the second guard; the model '
              'must not hand it a zero-width band in the first place');
      expect(model.rows.single.runCount, 1);
    });

    test('a course with a null end contributes nothing ANYWHERE (PF-11)', () {
      final entry =
          StackEntry(supplement: magnesium, regimen: course(end: null));

      final cycles = buildCyclesModel([entry], today: today);
      expect(cycles.rows, hasLength(1), reason: 'the row is never hidden');
      expect(cycles.rows.single.segments, isEmpty);
      expect(cycles.weeks.every((w) => w.load == 0), isTrue);

      final year = buildYearModel([entry], today: today);
      expect(year.entries, hasLength(1));
      expect(year.months.every((m) => m.load == 0), isTrue);
    });

    test('a paused regimen contributes zero to loads AND cells, while keeping '
        'both its row and its column (DECIDED-7)', () {
      final entry =
          StackEntry(supplement: magnesium, regimen: cyclic(paused: true));

      final cycles = buildCyclesModel([entry], today: today);
      expect(cycles.rows, hasLength(1));
      expect(cycles.weeks.every((w) => w.load == 0), isTrue);

      final year = buildYearModel([entry], today: today);
      expect(year.entries, hasLength(1));
      expect(year.months.every((m) => m.cells.single.frac == 0), isTrue);
    });

    test('an entry with no regimen appears in NEITHER model', () {
      final entries = [StackEntry(supplement: magnesium)];

      expect(buildCyclesModel(entries, today: today).rows, isEmpty);
      final year = buildYearModel(entries, today: today);
      expect(year.entries, isEmpty);
      expect(year.months.every((m) => m.cells.isEmpty), isTrue);
    });
  });
}
