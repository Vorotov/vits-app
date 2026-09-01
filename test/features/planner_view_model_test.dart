/// Pure proofs for the planner's derivations (plan 04-01, PF-1, PF-6,
/// DECIDED-4/7).
///
/// Fixture builders follow `cycle_math_test.dart` / `day_view_model_test.dart`:
/// local `cyclic(...)` / `course(...)` helpers, every date a UTC date-only
/// value, no widgets and no clock — `today` is always an explicit argument.
library;

import 'dart:math' as math;

import 'package:boostque/core/domain/cycle_math.dart' show plannerWindow;
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

  // DERIVED, never restated. These three used to be written out as 1 Aug /
  // 30 Nov / 122 — the window `plannerWindow` returned for this clock before
  // the owner moved the band back a month (2026-09-01: last month, this month
  // and two ahead). A one-line product change then contradicted three literals
  // that no longer described anything, and the pure-function tests below went
  // red for a reason none of them is about. Read off the window itself and the
  // NEXT shift cannot lie to this file; only the assertions that genuinely
  // name a date have to move with it.
  //
  // For the pinned 13 August clock that is 1 Jul – 31 Oct 2026, span 123
  // (31+31+30+31), with today at index 43.
  final window = plannerWindow(today);
  final windowStart = window.start;
  final windowLast = window.endExclusive.subtract(const Duration(days: 1));
  final span = window.span;

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
      // 24 Oct starts the fourth on-phase of a cycle that began 1 August,
      // which would run to 6 Nov unclipped. (It was 21 Nov -> 4 Dec against
      // the old Aug..Nov window; the regimen did not move, the window's last
      // day did.)
      expect(runs.last.start, DateTime.utc(2026, 10, 24));
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
      // A one-day run ON the window's first day — the position that makes
      // startFraction 0.0 a real assertion. Written as `windowStart` rather
      // than as a date, because that position is the whole fixture.
      final runs = [DateRun(start: windowStart, end: windowStart)];
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
      // A February clock opens the window in JANUARY: Jan..Apr 2027 =
      // 31+28+31+30 = 120 days. Before the shift the same clock produced
      // Feb..May, which also sums to 120 — the same span from four different
      // months, which is exactly why the BOUNDS are asserted here and not the
      // number alone. Still never the mockup's 122.
      final model = buildCyclesModel(const [], today: DateTime.utc(2027, 2, 10));
      expect(model.windowStart, DateTime.utc(2027, 1, 1));
      expect(model.windowEndExclusive, DateTime.utc(2027, 5, 1));
      expect(model.span, 120);
    });

    test('month columns come from real month lengths and sum to 1.0', () {
      final model = buildCyclesModel(const [], today: today);
      // Jul, Aug, Sep, Oct — the shifted window's own four months.
      expect(model.months.map((m) => m.days), [31, 31, 30, 31]);
      expect(
        model.months.fold<double>(0, (sum, m) => sum + m.fraction),
        closeTo(1.0, 1e-9),
      );
    });

    test('todayIndex is today\'s offset into the window', () {
      expect(buildCyclesModel(const [], today: today).todayIndex, 43,
          reason: '13 August is the 44th day of a window that opens on '
              '1 July, index 43 — the whole of that first month is now '
              'history behind the marker, which is what the owner asked for');
    });

    test('currentWeekIndex names the bucket CONTAINING today, in the model '
        'and nowhere else (WR-02)', () {
      final model = buildCyclesModel(const [], today: today);
      final bucket = model.weeks[model.currentWeekIndex].bucket;

      expect(bucket.start.isAfter(today), isFalse);
      expect(bucket.endInclusive.isBefore(today), isFalse);
      // 13 August 2026 is a Thursday; its Monday is 10 August, which is the
      // seventh full Monday week of a window whose buckets open on 29 June
      // (1 July 2026 is a Wednesday).
      expect(bucket.start, DateTime.utc(2026, 8, 10));
      expect(model.currentWeekIndex, 6);
    });

    // WHAT THIS TEST USED TO PROVE, AND WHY IT CANNOT ANY MORE. With a window
    // that opened at today's month it pinned today (2 August 2026, a Sunday)
    // inside BUCKET 0 — the bucket that begins six days before a window
    // starting 1 August — and asserted the summary chip reported a load earned
    // entirely on those pre-window days. That edge is now unreachable by
    // construction: the window opens on the first of LAST month (owner change
    // 2026-09-01), so today is never fewer than 28 days into the band and the
    // chip's own bucket can no longer leave the window at either end.
    //
    // The spill itself is still real and still proven — the group below drives
    // bucket 0 and the last bucket directly, which is where CR-01 lives now.
    // What survives HERE is the half the chip can still hit: its number is a
    // claim about a WHOLE Monday week, including the days of that week which
    // fall in a different month column from today's, which is exactly what an
    // implementation that clipped the week to the month would under-report.
    test('currentWeekIndex names the FULL Monday week the chip is standing '
        'in, days in the previous month column included (WR-02, CR-01)', () {
      // 2 August 2026 is a Sunday, so the week the chip names runs
      // 27 July – 2 August: five of its seven days sit in the window's JULY
      // column and only two in August. The course is active on exactly those
      // five, so a load of 1 can only come from counting them.
      final model = buildCyclesModel(
        [
          StackEntry(
            supplement: supp('s1', 'Магній'),
            regimen: course(
              start: DateTime.utc(2026, 7, 27),
              end: DateTime.utc(2026, 7, 31),
            ),
          ),
        ],
        today: DateTime.utc(2026, 8, 2),
      );

      expect(model.currentWeekIndex, greaterThan(0),
          reason: 'today can no longer fall in bucket 0 — the window opens a '
              'month before it, which is the note above made executable');
      expect(model.weeks[model.currentWeekIndex].bucket.start,
          DateTime.utc(2026, 7, 27));
      expect(model.weeks[model.currentWeekIndex].load, 1,
          reason: 'the chip says "Цього тижня одночасно N речовин" about the '
              'calendar week it is standing in — all seven days of it');
    });
  });

  group('weekBuckets — full Monday weeks (DECIDED-3)', () {
    final buckets = weekBuckets(windowStart, window.endExclusive);

    test('starts on the Monday on or before the window start', () {
      // 1 July 2026 is a Wednesday; its Monday is 29 June.
      expect(buckets.first.start, DateTime.utc(2026, 6, 29));
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

    test('the Jul-to-Oct window produces 18 or 19 buckets', () {
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
    final buckets = weekBuckets(windowStart, window.endExclusive);

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

  group('week buckets that spill past the window count their OWN days '
      '(DECIDED-3, CR-01)', () {
    final magnesium = supp('s1', 'Магній');

    // The window for this clock is 1 лип – 31 жов. 1 July 2026 is a Wednesday,
    // so bucket 0 runs 29 чер – 5 лип — two days of it lie BEFORE the window —
    // and the last bucket runs 26 жов – 1 лис, one day of it AFTER. DECIDED-3
    // accepts those bounds and mandates that the axis label shows the ACTUAL
    // bucket dates, which makes the load a claim about those dates. Scanning
    // activity over the window alone answers a different question than the
    // label asks.
    //
    // The spill is narrower than the six days the old Aug..Nov window happened
    // to give (1 August was a Saturday), because how far a Monday week hangs
    // off a month boundary is a property of the calendar, not of the fixture.
    // Two days and one day are still a spill, and the courses below are seeded
    // to live on exactly those days and nowhere else.
    final earlyAugust = DateTime.utc(2026, 8, 2);

    test('a course active only on the PRE-window days of bucket 0 counts', () {
      final model = buildCyclesModel(
        [
          StackEntry(
            supplement: magnesium,
            // 29–30 June: bucket 0's pre-window days, and ONLY those. The
            // fixture moved back with the window (it was 27–31 July against a
            // band opening 1 August); left where it was it would sit inside
            // the window and prove nothing about the spill.
            regimen: course(
              start: DateTime.utc(2026, 6, 29),
              end: DateTime.utc(2026, 6, 30),
            ),
          ),
        ],
        today: earlyAugust,
      );

      final first = model.weeks.first;
      expect(first.bucket.start, DateTime.utc(2026, 6, 29));
      expect(first.bucket.endInclusive, DateTime.utc(2026, 7, 5));
      expect(first.load, 1,
          reason: 'the bucket is LABELLED 29 чер – 5 лип, so its load is a '
              'claim about those seven days — the supplement is genuinely '
              'active on two of them, both before the window opens');
      expect(first.entries.single.supplement.id, 's1',
          reason: 'the week detail lists the names behind the number, so an '
              'absent entry is a supplement the card silently denies');
    });

    test('a course active only on the POST-window days of the last bucket '
        'counts', () {
      final model = buildCyclesModel(
        [
          StackEntry(
            supplement: magnesium,
            // 1 November is the last bucket's ONLY post-window day; the
            // course starts there and runs on past the chart.
            regimen: course(
              start: DateTime.utc(2026, 11, 1),
              end: DateTime.utc(2026, 11, 20),
            ),
          ),
        ],
        today: earlyAugust,
      );

      final last = model.weeks.last;
      expect(last.bucket.start, DateTime.utc(2026, 10, 26));
      expect(last.bucket.endInclusive, DateTime.utc(2026, 11, 1));
      expect(last.load, 1,
          reason: 'the course overlaps exactly one of that bucket\'s seven '
              'days, and that one day is outside the window');
    });

    test('the PAINTED geometry stays window-scoped — a run lying entirely '
        'outside the window paints nothing', () {
      final model = buildCyclesModel(
        [
          StackEntry(
            supplement: magnesium,
            // The same 29–30 June course as the first case: inside bucket 0,
            // outside the window.
            regimen: course(
              start: DateTime.utc(2026, 6, 29),
              end: DateTime.utc(2026, 6, 30),
            ),
          ),
        ],
        today: earlyAugust,
      );

      expect(model.rows, hasLength(1), reason: 'the row itself is never hidden');
      expect(model.rows.single.runs, isEmpty,
          reason: 'widening the gantt row\'s own runs would collapse a '
              'before-the-window run to startFraction == endFraction == 0 and '
              'the painter would still draw it at its 2px floor, at the very '
              'left edge — a band the user does not have');
      expect(model.rows.single.segments, isEmpty);
    });

    test('a bucket fully inside the window is unchanged by the wider scan', () {
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
        today: earlyAugust,
      );

      final hit = model.weeks.firstWhere((w) =>
          !w.bucket.start.isAfter(DateTime.utc(2026, 9, 2)) &&
          !w.bucket.endInclusive.isBefore(DateTime.utc(2026, 9, 2)));
      expect(hit.load, 1);
      expect(model.weeks.where((w) => w.load > 0), hasLength(1),
          reason: 'one active day still touches exactly one bucket');
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

    test('a year with ZERO coverage has NO peak at all (WR-04)', () {
      // Every entry keeps its row (DECIDED-7) but contributes zero load — a
      // stack whose regimens are all paused, or all start after this year.
      final model = buildYearModel(
        [
          StackEntry(supplement: magnesium, regimen: cyclic(paused: true)),
          StackEntry(
            supplement: creatine,
            regimen: cyclic(id: 'r3', supplementId: 's2', paused: true),
          ),
        ],
        today: today,
      );

      expect(model.entries, hasLength(2),
          reason: 'paused entries keep their columns (DECIDED-7), so the '
              'screen-level empty state does NOT fire here');
      expect(model.months.every((m) => m.load == 0), isTrue);
      expect(model.peakIndex, lessThan(0),
          reason: '"no peak" must be REPRESENTABLE. Folding the peak from a '
              'seed of 0 ties all twelve months at zero and resolves to the '
              'current one, so the chip claims "the densest months, including '
              'August — 0 substances" for a year with no coverage (WR-04)');
      expect(model.peakTied, isFalse,
          reason: 'twelve months tied at zero is not a tie worth reporting');
    });
  });

  group('regimen-shape edges — the planner\'s observable consequence', () {
    final magnesium = supp('s1', 'Магній');

    test('offDays zero produces ONE continuous run to the window edge', () {
      final model = buildCyclesModel(
        [
          StackEntry(
            supplement: magnesium,
            // Started ON the window's first day: that is the position the
            // fixture holds, and the only one from which a full-width segment
            // is the correct answer. It moved back a month with the window
            // (the helper's default 1 August is now a month INTO the band).
            regimen: cyclic(on: 30, off: 0, start: windowStart),
          ),
        ],
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

  // The load chart's denominator (plan 06-05, spec §3.1). The chart scales its
  // bars against this number, so its relationship to the week loads is an
  // INVARIANT the model owes the widget — not an assumption the widget makes.
  group('scheduledCount — the load chart\'s ceiling', () {
    test('equals the number of supplements when every one carries a schedule',
        () {
      final model = buildCyclesModel(
        [
          StackEntry(supplement: supp('s1', 'Магній'), regimen: cyclic()),
          StackEntry(
            supplement: supp('s2', 'Креатин'),
            regimen: cyclic(id: 'r2', supplementId: 's2'),
          ),
          StackEntry(
            supplement: supp('s3', 'Омега-3'),
            regimen: course(
              id: 'r3',
              supplementId: 's3',
              end: DateTime.utc(2026, 9, 1),
            ),
          ),
        ],
        today: today,
      );

      expect(model.scheduledCount, 3);
    });

    test('a supplement with no schedule does not raise the ceiling', () {
      final model = buildCyclesModel(
        [
          StackEntry(supplement: supp('s1', 'Магній'), regimen: cyclic()),
          StackEntry(supplement: supp('s2', 'Креатин')), // fresh — no regimen
        ],
        today: today,
      );

      expect(model.scheduledCount, 1);
      expect(model.scheduledCount, model.rows.length,
          reason: 'the ceiling counts exactly the rows the loads are drawn '
              'from — the same collection, never a second filter');
    });

    test('a paused supplement is counted exactly as the week loads count it '
        '— it keeps its row, so it keeps its place in the ceiling', () {
      final model = buildCyclesModel(
        [
          StackEntry(supplement: supp('s1', 'Магній'), regimen: cyclic()),
          StackEntry(
            supplement: supp('s2', 'Креатин'),
            regimen: cyclic(id: 'r2', supplementId: 's2', paused: true),
          ),
        ],
        today: today,
      );

      expect(model.scheduledCount, 2);
      expect(model.weeks.every((w) => w.load <= model.scheduledCount), isTrue);
    });

    test('a stack where exactly one supplement is scheduled has ceiling 1, '
        'and an active week reaches it', () {
      final model = buildCyclesModel(
        [
          StackEntry(supplement: supp('s1', 'Магній'), regimen: cyclic()),
        ],
        today: today,
      );

      expect(model.scheduledCount, 1);
      // A full bar for a stack of one is CORRECT: the chart's question is
      // "how much of my stack is running at once", and the answer is "all of
      // it" (spec §3.1). It is not a limit being hit.
      expect(model.weeks.any((w) => w.load == model.scheduledCount), isTrue);
    });

    test('a stack where nothing carries a schedule has ceiling 0', () {
      final model = buildCyclesModel(
        [
          StackEntry(supplement: supp('s1', 'Магній')),
          StackEntry(supplement: supp('s2', 'Креатин')),
        ],
        today: today,
      );

      expect(model.scheduledCount, 0,
          reason: 'the zero case is the one a later reader is most likely to '
              'get wrong; the empty state must not be what hides it');
    });

    test('an empty stack has ceiling 0', () {
      expect(buildCyclesModel(const [], today: today).scheduledCount, 0);
    });

    test('load <= scheduledCount holds for EVERY bucket of generated stacks',
        () {
      // Deterministic pseudo-random stacks: cadence, start offset, pause flag
      // and schedule-bearing-ness all vary, so the invariant is proven over a
      // space of models rather than one hand-picked fixture.
      final rand = math.Random(20260817);
      for (var trial = 0; trial < 40; trial++) {
        final size = rand.nextInt(9); // 0..8 supplements
        final entries = <StackEntry>[];
        for (var i = 0; i < size; i++) {
          final s = supp('s$i', 'S$i');
          final hasRegimen = rand.nextInt(4) > 0; // ~1 in 4 has no schedule
          if (!hasRegimen) {
            entries.add(StackEntry(supplement: s));
            continue;
          }
          final start = DateTime.utc(2026, 7, 1)
              .add(Duration(days: rand.nextInt(120)));
          entries.add(StackEntry(
            supplement: s,
            regimen: rand.nextBool()
                ? cyclic(
                    id: 'r$i',
                    supplementId: 's$i',
                    on: 1 + rand.nextInt(30),
                    off: rand.nextInt(30),
                    paused: rand.nextInt(5) == 0,
                    start: start,
                  )
                : course(
                    id: 'r$i',
                    supplementId: 's$i',
                    start: start,
                    end: start.add(Duration(days: rand.nextInt(60))),
                  ),
          ));
        }

        final model = buildCyclesModel(entries, today: today);
        for (final week in model.weeks) {
          expect(week.load, lessThanOrEqualTo(model.scheduledCount),
              reason: 'trial $trial: a bucket load exceeded the ceiling, so '
                  'the chart could draw a bar above full height');
        }
      }
    });
  });
}
