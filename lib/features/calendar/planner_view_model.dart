/// Pure planner derivation for the Цикли / Рік screens (plan 04-01, P-1, P-4,
/// P-5, P-8, DECIDED-4/7).
///
/// Top-level pure functions in the `day_view_model.dart` style: `today`
/// arrives as an explicit parameter and every date comparison goes through
/// [dateOnly] — this file NEVER reads the clock. It imports only the three
/// pure domain libraries: no UI framework, no l10n, no persistence, so no
/// materializing path is reachable from here at all (T-04-01, the Phase-3
/// WR-06 lesson at year scale).
///
/// Activity is decided in exactly ONE place: [activeRuns] asks `isActiveOn`
/// day by day. The cycle formula is never restated here — that is the whole
/// point of the file (PF-1).
///
/// No user-visible strings: the renderer maps each shape to an ARB key itself.
library;

import 'package:boostque/core/domain/cycle_math.dart';
import 'package:boostque/core/domain/models.dart';
import 'package:boostque/core/domain/repositories.dart';

/// A maximal run of consecutive days on which a regimen is active.
///
/// Both bounds are INCLUSIVE, date-only UTC values. A single active day is a
/// run whose [start] and [end] are equal — never an empty or zero-length
/// value, so a one-day course survives into the model intact (PF-6).
class DateRun {
  /// First active day of the run, date-only UTC.
  final DateTime start;

  /// Last active day of the run, date-only UTC and INCLUSIVE.
  final DateTime end;

  const DateRun({required this.start, required this.end});
}

/// Coalesces `isActiveOn` over [from]..[toInclusive] into maximal runs.
///
/// The ONLY activity decision in the planner. Re-deriving the cycle formula
/// here is the pitfall this function exists to prevent (PF-1): a later change
/// to `isActiveOn` — a new regimen kind, a new pre-start rule, a new pause
/// semantic — must reach the planner and the Today screen at the same instant,
/// and a day scan is the only shape that guarantees it.
///
/// Linear in the window length. The caller runs it once per regimen inside a
/// Provider, never inside `build()` (PF-10).
///
/// A paused regimen, a course with a null end date and a regimen starting past
/// the window all yield an empty list — none of them is special-cased here,
/// because `isActiveOn` already answers all three.
List<DateRun> activeRuns(Regimen r, DateTime from, DateTime toInclusive) {
  final runs = <DateRun>[];
  final start = dateOnly(from);
  final last = dateOnly(toInclusive);
  DateTime? openFrom;
  DateTime? openTo;
  // `add(const Duration(days: 1))` is exact here because `d` is a UTC
  // date-only value: every day is precisely 24h in UTC.
  for (var d = start; !d.isAfter(last); d = d.add(const Duration(days: 1))) {
    if (isActiveOn(r, d)) {
      openFrom ??= d;
      openTo = d;
    } else if (openFrom != null) {
      runs.add(DateRun(start: openFrom, end: openTo!));
      openFrom = null;
      openTo = null;
    }
  }
  if (openFrom != null) runs.add(DateRun(start: openFrom, end: openTo!));
  return List.unmodifiable(runs);
}

/// One painted band of a gantt row, as fractions of the window.
///
/// [startFraction] and [endFraction] are in 0..1 of the window span, so the
/// painter needs no dates and the model needs no pixels.
class GanttSegment {
  /// Left edge, 0..1 of the window span.
  final double startFraction;

  /// Right edge, 0..1 of the window span. Always greater than
  /// [startFraction] — a one-day run is a real, non-empty band.
  final double endFraction;

  /// Whether the whole run begins after today (DECIDED-4).
  final bool planned;

  const GanttSegment({
    required this.startFraction,
    required this.endFraction,
    required this.planned,
  });
}

/// Projects [runs] onto the window as painted fractions (DECIDED-4).
///
/// A run is `planned` as a WHOLE exactly when its first day is strictly after
/// [today]; every other run is active, including one already in progress whose
/// tail extends past today. Splitting a running cycle at today was rejected
/// because `statusOf` on the Stack tab returns `planned` on precisely the same
/// condition — so a supplement's first hatched segment and its ЗАПЛАНОВАНО
/// stack chip can never disagree.
List<GanttSegment> ganttSegments(
  List<DateRun> runs,
  DateTime windowStart,
  int span,
  DateTime today,
) {
  if (span <= 0) return List.unmodifiable(const <GanttSegment>[]);
  final start = dateOnly(windowStart);
  final t = dateOnly(today);
  return List.unmodifiable([
    for (final run in runs)
      GanttSegment(
        // Clamped to the window on both sides: a run may legitimately begin
        // before the window or end after it, and the painted band is the part
        // that falls inside.
        startFraction:
            (run.start.difference(start).inDays / span).clamp(0.0, 1.0),
        // The end bound is INCLUSIVE, so the band closes at the END of that
        // day — index + 1, not index.
        endFraction:
            ((run.end.difference(start).inDays + 1) / span).clamp(0.0, 1.0),
        planned: run.start.isAfter(t),
      ),
  ]);
}

/// One month column of the gantt header.
class MonthColumn {
  /// First day of the month, date-only UTC.
  final DateTime month;

  /// The month's real length in days — never a table lookup (PF-3).
  final int days;

  /// This month's share of the window span. The four fractions sum to 1.0.
  final double fraction;

  const MonthColumn({
    required this.month,
    required this.days,
    required this.fraction,
  });
}

/// One gantt row: a stack entry and its painted runs.
class GanttRow {
  /// The supplement and its regimen, straight from `stackEntriesProvider`.
  final StackEntry entry;

  /// Painted bands, in chronological order. EMPTY is a valid, meaningful
  /// state: a paused regimen keeps its row and shows a bare track, which is
  /// the design's own way of saying "paused" (DECIDED-7).
  final List<GanttSegment> segments;

  /// How many runs fall in the window — spoken by the row's semantics label,
  /// where the painted bands are invisible.
  final int runCount;

  const GanttRow({
    required this.entry,
    required this.segments,
    required this.runCount,
  });
}

/// Everything the Цикли segment renders, derived once per (stack, today) pair.
class CyclesModel {
  /// First day of the window, date-only UTC.
  final DateTime windowStart;

  /// One day past the window's last day, date-only UTC.
  final DateTime windowEndExclusive;

  /// Window length in days — 120..123, never assumed to be 122 (P-4).
  final int span;

  /// Today's 0-based offset into the window. Today is inside the window by
  /// construction, so the marker always has a place to render.
  final int todayIndex;

  /// The four month columns, in chronological order.
  final List<MonthColumn> months;

  /// One row per regimen-bearing stack entry, in `stackEntriesProvider` order.
  final List<GanttRow> rows;

  const CyclesModel({
    required this.windowStart,
    required this.windowEndExclusive,
    required this.span,
    required this.todayIndex,
    required this.months,
    required this.rows,
  });
}

/// Builds the Цикли model for [today] from the stack in its own order.
///
/// Entries with no regimen are excluded: there is no schedule to draw and no
/// coverage to compute, and they stay fully visible on the Stack tab
/// (DECIDED-7). Entries whose regimen has no active day in the window are
/// KEPT, with zero segments.
CyclesModel buildCyclesModel(
  List<StackEntry> entries, {
  required DateTime today,
}) {
  final window = plannerWindow(today);
  final lastDay = window.endExclusive.subtract(const Duration(days: 1));

  final months = <MonthColumn>[];
  for (var i = 0; i < 4; i++) {
    final monthStart = addMonths(window.start, i);
    final length = daysInMonth(monthStart);
    months.add(MonthColumn(
      month: monthStart,
      days: length,
      fraction: length / window.span,
    ));
  }

  final rows = <GanttRow>[];
  for (final entry in entries) {
    final regimen = entry.regimen;
    if (regimen == null) continue;
    final runs = activeRuns(regimen, window.start, lastDay);
    rows.add(GanttRow(
      entry: entry,
      segments: ganttSegments(runs, window.start, window.span, today),
      runCount: runs.length,
    ));
  }

  return CyclesModel(
    windowStart: window.start,
    windowEndExclusive: window.endExclusive,
    span: window.span,
    todayIndex: dateOnly(today).difference(window.start).inDays,
    months: List.unmodifiable(months),
    rows: List.unmodifiable(rows),
  );
}
