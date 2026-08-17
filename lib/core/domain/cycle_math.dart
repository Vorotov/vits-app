/// DST-safe cycle math for Boostque regimens (D-13, D-14).
///
/// Pure Dart: imports only the domain models. Never reads the current wall
/// clock — callers pass the day to evaluate (D-13). All day arithmetic runs
/// on UTC-normalized date-only values, where `Duration.inDays` is exact
/// (no fractional 23h/25h DST days).
library;

import 'models.dart';

/// Normalizes any [DateTime] to its calendar day as `DateTime.utc(y, m, d)`.
///
/// Uses the y/m/d fields of the input as-is — a local wall-clock value maps
/// to the UTC calendar day with the same date fields, never local midnight
/// (D-13).
DateTime dateOnly(DateTime d) => DateTime.utc(d.year, d.month, d.day);

/// Whether regimen [r] is active on calendar day [day] (D-14).
///
/// Semantics, in order:
/// - paused -> false
/// - before startDate -> false
/// - course -> active through the inclusive endDate; null endDate -> false
/// - cyclic -> onDays <= 0 -> false; offDays == 0 -> always on;
///   otherwise `(day - start) % (onDays + offDays) < onDays`
bool isActiveOn(Regimen r, DateTime day) {
  if (r.paused) return false;

  final d = dateOnly(day);
  final start = dateOnly(r.startDate);
  if (d.isBefore(start)) return false;

  switch (r.kind) {
    case RegimenKind.course:
      final end = r.endDate;
      return end != null && !d.isAfter(dateOnly(end));
    case RegimenKind.cyclic:
      if (r.onDays <= 0) return false;
      if (r.offDays == 0) return true;
      final period = r.onDays + r.offDays;
      // Exact on UTC date-only values: every day is precisely 24h in UTC.
      final dayIndex = d.difference(start).inDays;
      return dayIndex % period < r.onDays;
  }
}

/// Whether regimen [r] will be active on EVERY day from [day] onward, forever.
///
/// The tier-A predicate of the notification plan (07-RESEARCH §8.1): a time of
/// day whose every contributing regimen answers true here can be armed as one
/// repeating request instead of one request per day.
///
/// True only for a cyclic regimen that is not paused, has a positive on-day
/// count, has a zero off-day count, and whose start date is not after [day]. A
/// cyclic regimen ignores its end date, so the end date plays no part; a course
/// always answers false, because it has a last day and a repeat does not.
///
/// The start-date condition is not belt-and-braces. A daily regimen starting
/// next week satisfies every other condition TODAY, and promoting it would arm a
/// repeating request that begins firing before the regimen begins. It becomes
/// promotable on its start date, at which point the ordinary re-derivation picks
/// it up — which is why nothing else is needed to handle it.
///
/// **This lives here, and not in `lib/core/notifications/`, for one reason:** it
/// mirrors two of the guard conditions inside [isActiveOn]'s cyclic arm (`onDays
/// <= 0` and `offDays == 0`) plus its pause and pre-start guards, so it is
/// coupled to that function's internals in a way no amount of care at a distance
/// can protect. One screenful below the thing it mirrors, a future change to the
/// activity rule — a new regimen kind, a new pre-start rule, a new pause
/// semantic — is made by someone looking straight at the predicate that depends
/// on it. The same reasoning `planner_view_model.dart` records for having exactly
/// one activity decision point applies to having exactly one PLACE where that
/// decision's shape is mirrored. `cycle_math_test.dart`'s two property tests
/// walk 400 days over a generated regimen set to assert the mirror holds.
bool runsEveryDayFrom(Regimen r, DateTime day) {
  if (r.paused) return false;
  if (dateOnly(r.startDate).isAfter(dateOnly(day))) return false;
  switch (r.kind) {
    case RegimenKind.course:
      return false;
    case RegimenKind.cyclic:
      return r.onDays > 0 && r.offDays == 0;
  }
}

/// The Monday of [day]'s week, as a date-only UTC value.
///
/// Pure arithmetic on the UTC calendar day — `subtract` on a UTC value can
/// never be bitten by a DST transition (the project's date-only rule).
///
/// Lives here, not in `week_strip.dart`, because the planner's week buckets
/// need the same Monday-first rule (04-UI-SPEC DECIDED-3) and a feature file
/// must never import another feature's widget file.
DateTime mondayOfWeek(DateTime day) {
  final d = dateOnly(day);
  return d.subtract(Duration(days: d.weekday - DateTime.monday));
}

/// First day of [d]'s month, date-only UTC.
DateTime firstOfMonth(DateTime d) => DateTime.utc(d.year, d.month, 1);

/// [months] whole months after [d]'s month start, date-only UTC.
///
/// The UTC constructor normalizes month overflow (month 13 becomes January of
/// the next year), so no year carry is written by hand here (PF-3).
DateTime addMonths(DateTime d, int months) =>
    DateTime.utc(d.year, d.month + months, 1);

/// Number of days in the month of [d].
///
/// Day 0 of the NEXT month is the last day of this one, so the calendar itself
/// answers the leap-year question — which is why this codebase carries no
/// month-length table anywhere (PF-3).
int daysInMonth(DateTime d) => DateTime.utc(d.year, d.month + 1, 0).day;

/// The planner window: `[first of today's month, +4 months)` (04-RESEARCH P-4).
///
/// [span] is derived from the two real month boundaries and is **120..123
/// days** depending on the start month (Feb..May 2027 = 120; Jul..Oct = 123).
/// Never assume the mockup's 122 — that is the Aug..Nov figure only, and
/// hardcoding it would misplace every gridline in eight months of the year.
({DateTime start, DateTime endExclusive, int span}) plannerWindow(
  DateTime today,
) {
  final start = firstOfMonth(today);
  final endExclusive = addMonths(start, 4);
  return (
    start: start,
    endExclusive: endExclusive,
    // Exact on UTC date-only values: every day is precisely 24h in UTC.
    span: endExclusive.difference(start).inDays,
  );
}
