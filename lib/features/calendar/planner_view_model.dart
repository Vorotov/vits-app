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

  /// The row's true active runs in the window, in chronological order. Kept
  /// alongside the painted fractions because the week buckets need DATES: a
  /// fraction cannot answer "is this supplement active in that week".
  final List<DateRun> runs;

  /// Painted bands, in chronological order. EMPTY is a valid, meaningful
  /// state: a paused regimen keeps its row and shows a bare track, which is
  /// the design's own way of saying "paused" (DECIDED-7).
  final List<GanttSegment> segments;

  /// How many runs fall in the window — spoken by the row's semantics label,
  /// where the painted bands are invisible.
  int get runCount => runs.length;

  /// Whether this row's regimen is paused.
  ///
  /// The design says "paused" with a BARE TRACK (DECIDED-7) — paint, and
  /// nothing else. Carried on the model so the row's semantics label can say
  /// it in words too: without this, a paused supplement announces a schedule
  /// and zero periods, which is indistinguishable from one that is simply
  /// off-cycle for the whole window (WR-01).
  bool get paused => entry.regimen?.paused ?? false;

  const GanttRow({
    required this.entry,
    required this.runs,
    required this.segments,
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

  /// The load-chart buckets, one per full Monday week touching the window.
  final List<WeekLoad> weeks;

  /// Index into [weeks] of the bucket CONTAINING today.
  ///
  /// The ONE place "this week" is resolved. The summary chip and the
  /// week-detail's follow-today fallback both read it, so they cannot drift
  /// apart or answer the question differently (WR-02) — the same way
  /// [todayIndex] is the one place today's column lives.
  ///
  /// Always a valid index: today is inside the window by construction and the
  /// buckets cover the whole window, so the search never fails.
  final int currentWeekIndex;

  const CyclesModel({
    required this.windowStart,
    required this.windowEndExclusive,
    required this.span,
    required this.todayIndex,
    required this.months,
    required this.rows,
    required this.weeks,
    required this.currentWeekIndex,
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

  final buckets = weekBuckets(window.start, window.endExclusive);

  // The buckets are full Monday weeks, so bucket 0 may begin up to six days
  // BEFORE the window and the last may end up to six days AFTER it (DECIDED-3)
  // — and the axis labels name those actual dates. A load scanned over the
  // window alone would therefore answer a different question than the label
  // asks, and the first/last column would under-report (CR-01). Concurrency is
  // scanned over the buckets' own span; the PAINTED geometry stays
  // window-scoped, because a run lying entirely before the window collapses to
  // startFraction == endFraction == 0 and the painter would still draw it at
  // its 2px floor.
  final scanFrom = buckets.isEmpty ? window.start : buckets.first.start;
  final scanTo = buckets.isEmpty ? lastDay : buckets.last.endInclusive;

  final rows = <GanttRow>[];
  final loadRows = <GanttRow>[];
  for (final entry in entries) {
    final regimen = entry.regimen;
    if (regimen == null) continue;
    final windowRuns = activeRuns(regimen, window.start, lastDay);
    rows.add(GanttRow(
      entry: entry,
      runs: windowRuns,
      segments: ganttSegments(windowRuns, window.start, window.span, today),
    ));
    loadRows.add(GanttRow(
      entry: entry,
      runs: activeRuns(regimen, scanFrom, scanTo),
      // Never painted: this row exists only to answer the bucket question.
      segments: const [],
    ));
  }

  final t = dateOnly(today);
  // Today is inside the window, and the buckets cover the window, so this
  // search always finds a bucket. The `< 0` guard is the ONE place that
  // invariant is written down; every reader takes the index as given (WR-02).
  final currentWeek =
      buckets.indexWhere((b) => !b.start.isAfter(t) && !b.endInclusive.isBefore(t));

  return CyclesModel(
    windowStart: window.start,
    windowEndExclusive: window.endExclusive,
    span: window.span,
    todayIndex: t.difference(window.start).inDays,
    months: List.unmodifiable(months),
    rows: List.unmodifiable(rows),
    weeks: weekLoads(loadRows, buckets),
    currentWeekIndex: currentWeek < 0 ? 0 : currentWeek,
  );
}

/// One 7-day bucket of the load chart. Both bounds are date-only UTC and
/// [endInclusive] is, as the name says, inclusive.
class WeekBucket {
  /// Monday of the week.
  final DateTime start;

  /// Sunday of the same week — always six days after [start].
  final DateTime endInclusive;

  const WeekBucket({required this.start, required this.endInclusive});
}

/// Full Monday weeks covering the window (DECIDED-3).
///
/// Runs from `mondayOfWeek(windowStart)` through the week containing the
/// window's last day — 18 or 19 buckets, every one exactly 7 days.
///
/// This DELIBERATELY deviates from the mockup's window-aligned `i * 7`
/// arithmetic, for two reasons. Monday-first weeks are locked in every locale
/// (the week strip's rule), and the summary chip literally says "this week",
/// which can only mean the calendar week containing today if the buckets ARE
/// calendar weeks.
///
/// Clamping the first bucket short instead was rejected: a month starting on a
/// Sunday would produce a one-day bucket whose bar is honestly low but reads,
/// beside seventeen seven-day bars, as a lie. The accepted consequence is that
/// the first bucket may begin up to six days before the window and the last may
/// end up to six days after it, so the axis labels show the ACTUAL bucket dates.
List<WeekBucket> weekBuckets(DateTime windowStart, DateTime windowEndExclusive) {
  final last = dateOnly(windowEndExclusive).subtract(const Duration(days: 1));
  final buckets = <WeekBucket>[];
  for (var monday = mondayOfWeek(windowStart);
      !monday.isAfter(last);
      monday = monday.add(const Duration(days: 7))) {
    buckets.add(WeekBucket(
      start: monday,
      endInclusive: monday.add(const Duration(days: 6)),
    ));
  }
  return List.unmodifiable(buckets);
}

/// The supplements concurrently active in one bucket.
class WeekLoad {
  /// The week this load describes.
  final WeekBucket bucket;

  /// Entries active on at least one day of [bucket], in stack order.
  final List<StackEntry> entries;

  /// How many supplements overlap this week.
  int get load => entries.length;

  const WeekLoad({required this.bucket, required this.entries});
}

/// Concurrent load per bucket (P-6).
///
/// A supplement counts ONCE per bucket if it is active on ANY day of it —
/// never once per active day. That is what makes the number "how many things
/// am I taking at the same time" rather than "how many doses".
///
/// [rows] must carry runs scanned over AT LEAST the span [buckets] covers,
/// which is wider than the planner window at both ends (DECIDED-3). Passing
/// window-scoped rows silently zeroes the days the first and last bucket hold
/// outside it — the CR-01 defect.
List<WeekLoad> weekLoads(List<GanttRow> rows, List<WeekBucket> buckets) {
  return List.unmodifiable([
    for (final bucket in buckets)
      WeekLoad(
        bucket: bucket,
        entries: List.unmodifiable([
          for (final row in rows)
            if (row.runs.any((r) => _overlaps(r, bucket.start,
                bucket.endInclusive)))
              row.entry,
        ]),
      ),
  ]);
}

/// Whether run [r] shares at least one day with the inclusive range [a]..[b].
bool _overlaps(DateRun r, DateTime a, DateTime b) =>
    !r.start.isAfter(b) && !r.end.isBefore(a);

/// The editorial tracking-comfort rule (PLAN-04) — **not a medical
/// threshold**, and never to be described as one anywhere in the app.
///
/// Five is the count above which the user's own tracking gets hard: it is our
/// editorial default for legibility, not a safety limit, not a norm and not a
/// dose ceiling. Both numbers live here once, so moving a boundary is a
/// one-line, test-caught edit — and the copy honours that: every sentence that
/// names either number takes it PRE-FORMATTED through a plural key, so the
/// Ukrainian declines with the value instead of being frozen at five (WR-05).
///
/// The two chips read this rule ASYMMETRICALLY, on purpose (DECIDED-6): the
/// week summary chip warns at a load greater than OR EQUAL to
/// [editorialLimit], while the year peak chip warns only ABOVE it. A week
/// sitting exactly at the limit is worth a nudge, because the user can still
/// move a start date; a month that merely touches it for a few days is not.
/// Transcribed deliberately — do not "fix" the asymmetry.
const int editorialLimit = 5;

/// The upper bound of the comfort band (PLAN-04) — see [editorialLimit].
const int comfortLoad = 3;

/// Structured week verdict — the renderer switches exhaustively (sealed,
/// Dart 3) and maps each case to an ARB key and a colour pair itself, so no
/// copy lives here.
sealed class LoadVerdict {
  const LoadVerdict();
}

/// At or below [comfortLoad]: easy to keep track of.
class ComfortVerdict extends LoadVerdict {
  const ComfortVerdict();
}

/// Above the comfort band but at or below [editorialLimit].
class LimitVerdict extends LoadVerdict {
  const LimitVerdict();
}

/// Above [editorialLimit]. Carries [load] because the copy names the number.
class OverLimitVerdict extends LoadVerdict {
  /// The week's concurrent load.
  final int load;

  const OverLimitVerdict(this.load);
}

/// Resolves the three editorial bands for [load].
LoadVerdict verdictOf(int load) => load <= comfortLoad
    ? const ComfortVerdict()
    : load <= editorialLimit
        ? const LimitVerdict()
        : OverLimitVerdict(load);

/// The coverage fraction at or above which a month reads as fully covered
/// (mockup line 842). The ONE place this boundary lives.
const double fullMonthFraction = 0.85;

/// One supplement's coverage of one month in the Year matrix.
class MonthCell {
  /// Covered days over the month's real length, 0..1.
  final double frac;

  /// Whether every covered day of the month is still in the future.
  final bool planned;

  const MonthCell({required this.frac, required this.planned});

  /// Whether the month reads as fully covered (mockup's `frac >= 0.85`).
  bool get full => frac >= fullMonthFraction;
}

/// Coverage of the month starting at [monthStart] by [runs] (P-10).
///
/// A run's days count as planned when the run itself is planned — its first
/// day is strictly after [today], the same DECIDED-4 rule the gantt uses — or
/// when the whole month lies after today. The cell is `planned` only when ALL
/// of its coverage is: one already-started day is enough to make the month
/// read as "taking", which is the honest reading.
MonthCell monthCellFor(
  List<DateRun> runs,
  DateTime monthStart,
  int monthLen,
  DateTime today,
) {
  final start = dateOnly(monthStart);
  final end = start.add(Duration(days: monthLen - 1));
  final t = dateOnly(today);
  final monthIsFuture = start.isAfter(t);

  var days = 0;
  var plannedDays = 0;
  for (final run in runs) {
    if (!_overlaps(run, start, end)) continue;
    final from = run.start.isBefore(start) ? start : run.start;
    final to = run.end.isAfter(end) ? end : run.end;
    final overlap = to.difference(from).inDays + 1;
    days += overlap;
    if (monthIsFuture || run.start.isAfter(t)) plannedDays += overlap;
  }

  return MonthCell(
    frac: monthLen <= 0 ? 0 : days / monthLen,
    planned: days > 0 && plannedDays == days,
  );
}

/// One month column of the Year matrix.
class YearMonth {
  /// First day of the month, date-only UTC.
  final DateTime month;

  /// The month's real length — from `daysInMonth`, never a table (PF-3).
  final int days;

  /// One cell per entry of [YearModel.entries], in the same order.
  final List<MonthCell> cells;

  /// How many entries cover any part of this month at all.
  final int load;

  const YearMonth({
    required this.month,
    required this.days,
    required this.cells,
    required this.load,
  });
}

/// Everything the Рік segment renders (DECIDED-9).
class YearModel {
  /// The rendered year — always today's, January through December, no paging.
  final int year;

  /// The twelve month columns, in calendar order.
  final List<YearMonth> months;

  /// The regimen-bearing entries, in `stackEntriesProvider` order.
  final List<StackEntry> entries;

  /// Index into [months] of the busiest month.
  final int peakIndex;

  /// Whether more than one month shares the peak load — the copy says
  /// "densest months, including …" rather than naming one when it does.
  final bool peakTied;

  const YearModel({
    required this.year,
    required this.months,
    required this.entries,
    required this.peakIndex,
    required this.peakTied,
  });
}

/// Builds the Рік model for today's calendar year (DECIDED-9).
///
/// The Цикли window may cross into the next year while this stays on the
/// current one — the two views intentionally show different spans, and the
/// subtitle says which. Month lengths come from `daysInMonth`, never a table.
YearModel buildYearModel(
  List<StackEntry> entries, {
  required DateTime today,
}) {
  final t = dateOnly(today);
  final yearStart = DateTime.utc(t.year, 1, 1);
  final yearEnd = DateTime.utc(t.year, 12, 31);

  final kept = <StackEntry>[];
  final runsPerEntry = <List<DateRun>>[];
  for (final entry in entries) {
    final regimen = entry.regimen;
    if (regimen == null) continue;
    kept.add(entry);
    runsPerEntry.add(activeRuns(regimen, yearStart, yearEnd));
  }

  final months = <YearMonth>[];
  for (var m = 0; m < 12; m++) {
    final monthStart = DateTime.utc(t.year, m + 1, 1);
    final length = daysInMonth(monthStart);
    final cells = [
      for (final runs in runsPerEntry)
        monthCellFor(runs, monthStart, length, t),
    ];
    months.add(YearMonth(
      month: monthStart,
      days: length,
      cells: List.unmodifiable(cells),
      load: cells.where((c) => c.frac > 0).length,
    ));
  }

  // Peak: the highest load, ties broken toward the month nearest the current
  // one — the reader's attention belongs on the crowding they are closest to.
  final peakLoad =
      months.fold<int>(0, (best, m) => m.load > best ? m.load : best);
  final tiedIndices = [
    for (var m = 0; m < months.length; m++)
      if (months[m].load == peakLoad) m,
  ];
  final currentMonth = t.month - 1;
  var peakIndex = tiedIndices.first;
  for (final i in tiedIndices) {
    if ((i - currentMonth).abs() < (peakIndex - currentMonth).abs()) {
      peakIndex = i;
    }
  }

  return YearModel(
    year: t.year,
    months: List.unmodifiable(months),
    entries: List.unmodifiable(kept),
    peakIndex: peakIndex,
    peakTied: tiedIndices.length > 1,
  );
}
