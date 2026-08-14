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
