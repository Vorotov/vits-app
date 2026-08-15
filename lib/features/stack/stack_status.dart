/// Pure status + schedule-summary derivation for stack cards
/// (plan 02-03, P-4, E-4/D10, E-7).
///
/// Top-level pure functions in the `combineStackEntries` style: `today` is
/// passed explicitly and every date comparison goes through [dateOnly] —
/// this file NEVER reads the clock. No Flutter imports, no user-visible
/// strings: the wave-4 card renderer switches exhaustively over the sealed
/// [ScheduleSummary] hierarchy and maps to ARB keys itself.
///
/// Status semantics (P-4), in precedence order:
/// - no regimen -> [StackStatus.fresh] (E-7: just added, no schedule yet)
/// - paused -> [StackStatus.paused] (checked before any date logic, so a
///   paused planned/finished regimen still reads paused)
/// - today before startDate -> [StackStatus.planned]
/// - course with an inclusive endDate already past -> [StackStatus.finished]
///   (E-4/D10: the invented ЗАВЕРШЕНО treatment, confirmed at UAT)
/// - otherwise -> [StackStatus.active]
library;

import 'package:boostque/core/domain/cycle_math.dart';
import 'package:boostque/core/domain/models.dart';
import 'package:boostque/core/domain/repositories.dart';

/// Status chip category for a stack card (mockup chips + D10 finished).
enum StackStatus { fresh, active, paused, planned, finished }

/// Derives the card status for [e] on the calendar day of [today].
///
/// [today] is normalized via [dateOnly]; the widget layer reads the clock
/// and passes the normalized current day in — this file never does.
StackStatus statusOf(StackEntry e, DateTime today) {
  final r = e.regimen;
  if (r == null) return StackStatus.fresh;
  if (r.paused) return StackStatus.paused;

  final day = dateOnly(today);
  if (day.isBefore(dateOnly(r.startDate))) return StackStatus.planned;

  final end = r.endDate;
  if (r.kind == RegimenKind.course &&
      end != null &&
      day.isAfter(dateOnly(end))) {
    return StackStatus.finished;
  }
  return StackStatus.active;
}

/// Structured schedule summary for a stack card — the wave-4 renderer
/// switches exhaustively (sealed, Dart 3) and formats via ARB/ICU keys.
sealed class ScheduleSummary {
  const ScheduleSummary();
}

/// Cyclic regimen: on/off day counts plus the daily slot count.
class CyclicSummary extends ScheduleSummary {
  final int onDays;
  final int offDays;
  final int slotCount;

  const CyclicSummary({
    required this.onDays,
    required this.offDays,
    required this.slotCount,
  });
}

/// One-time course: inclusive date range plus the daily slot count.
/// Dates are UTC date-only values as stored on the regimen.
class CourseSummary extends ScheduleSummary {
  final DateTime start;
  final DateTime? end;
  final int slotCount;

  const CourseSummary({
    required this.start,
    required this.end,
    required this.slotCount,
  });
}

/// No regimen yet (fresh entry, E-7): the card renders no schedule chip.
class NoSummary extends ScheduleSummary {
  const NoSummary();
}

/// Derives the schedule summary for [e].
///
/// Paused regimens keep their summary — the status chip alone carries the
/// pause signal (UI-SPEC S1).
ScheduleSummary scheduleSummaryOf(StackEntry e) {
  final r = e.regimen;
  if (r == null) return const NoSummary();
  return switch (r.kind) {
    RegimenKind.cyclic => CyclicSummary(
        onDays: r.onDays,
        offDays: r.offDays,
        slotCount: r.slots.length,
      ),
    RegimenKind.course => CourseSummary(
        start: r.startDate,
        end: r.endDate,
        slotCount: r.slots.length,
      ),
  };
}
