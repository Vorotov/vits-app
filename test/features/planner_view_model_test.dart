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
}
