/// Pure-Dart domain value models for VitoMy (D-12).
///
/// This library imports nothing outside `dart:core`. No Flutter, no Drift,
/// no I/O — the domain layer stays framework-free by design.
///
/// Time-type separation (D-15):
/// - Date-only values (`Regimen.startDate`, `Regimen.endDate`) are calendar
///   days, always normalized as `DateTime.utc(y, m, d)` — never local
///   midnight.
/// - `DoseSlot.minutesFromMidnight` is a wall-clock time of day (0..1439),
///   independent of time zone.
/// - True UTC instants (createdAt/updatedAt) live in the persistence layer,
///   not on these models.
library;

/// How a regimen schedules its active days.
enum RegimenKind { cyclic, course }

/// Status of a single materialized dose occurrence.
enum DoseStatus { pending, taken, skipped }

/// A single time-of-day dose slot within a regimen.
class DoseSlot {
  /// UUID of this slot.
  final String id;

  /// Wall-clock time of day, minutes since midnight. Valid range 0..1439.
  final int minutesFromMidnight;

  /// User-facing label for the dose (e.g. "5 g").
  final String doseLabel;

  const DoseSlot({
    required this.id,
    required this.minutesFromMidnight,
    required this.doseLabel,
  }) : assert(
          minutesFromMidnight >= 0 && minutesFromMidnight <= 1439,
          'minutesFromMidnight must be in 0..1439',
        );
}

/// A dosing regimen for one supplement: either a repeating on/off cycle or
/// a one-time course with an inclusive end date.
class Regimen {
  /// UUID of this regimen.
  final String id;

  /// UUID of the supplement this regimen belongs to.
  final String supplementId;

  /// Cyclic (on/off pattern) or course (fixed date range).
  final RegimenKind kind;

  /// First active calendar day. Date-only value: always `DateTime.utc(y,m,d)`,
  /// never local midnight (D-15).
  final DateTime startDate;

  /// Last active calendar day (inclusive) for [RegimenKind.course] regimens;
  /// null otherwise. Date-only value: always `DateTime.utc(y,m,d)` (D-15).
  final DateTime? endDate;

  /// Number of consecutive active days per cycle (cyclic only). Must be >= 0.
  final int onDays;

  /// Number of consecutive break days per cycle (cyclic only). Must be >= 0.
  final int offDays;

  /// Paused regimens are never active regardless of date.
  final bool paused;

  /// Time-of-day dose slots for active days.
  final List<DoseSlot> slots;

  const Regimen({
    required this.id,
    required this.supplementId,
    required this.kind,
    required this.startDate,
    required this.endDate,
    required this.onDays,
    required this.offDays,
    required this.paused,
    required this.slots,
  })  : assert(onDays >= 0, 'onDays must be >= 0'),
        assert(offDays >= 0, 'offDays must be >= 0');
}

/// A supplement in the user's stack.
class Supplement {
  /// UUID of this supplement.
  final String id;

  /// Display name.
  final String name;

  /// Human-readable dose description (e.g. "5 g", "2 capsules").
  final String doseText;

  /// ARGB color int used as the supplement's tag color in charts.
  final int colorValue;

  /// Free-form user note.
  final String note;

  const Supplement({
    required this.id,
    required this.name,
    required this.doseText,
    required this.colorValue,
    required this.note,
  });
}
