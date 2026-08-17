/// Which dose reminders should exist — the whole correctness surface of Phase 7
/// (NOTIF-01, NOTIF-02's budget half).
///
/// Pure, in the `planner_view_model.dart` sense: this library imports the two
/// pure domain libraries and the notification constants, and nothing else. No
/// timezone, no plugin, no Flutter, no clock. `today` and the current minute of
/// day both arrive as parameters, which is what lets the "a slot exactly at now"
/// boundary be a test rather than a race.
///
/// Activity is decided in exactly ONE place: [isActiveOn], asked day by day. The
/// cycle formula, the course range and the pause rule are never restated here —
/// `planner_view_model.dart:38-50` records that as a defect class this codebase
/// has already fixed once (PF-1), and a second copy would let the notification
/// set and the Today screen disagree about the same day.
library;

import 'package:boostque/core/domain/cycle_math.dart';
import 'package:boostque/core/domain/models.dart';

/// One reminder the app wants the operating system to be holding.
///
/// One per (active day, minute of day) carrying a dose COUNT — never one per
/// supplement (NOTIF-01).
class PlannedNotification {
  /// Stable cross-process id, from [notificationIdFor].
  final int id;

  /// The calendar day this reminder fires on, date-only UTC; `null` means it is
  /// a daily repeat with no single day.
  ///
  /// "Repeats daily" is DERIVED from this being null ([repeatsDaily]) rather
  /// than stored as a second field, so the two can never disagree.
  final DateTime? day;

  /// Wall-clock time of day, minutes since midnight. Timezone-free.
  final int minutesFromMidnight;

  /// How many doses are due at this time of day. Never zero — a time with no
  /// active doses produces no notification at all, which is why the body copy
  /// has no zero state.
  final int doseCount;

  const PlannedNotification({
    required this.id,
    required this.day,
    required this.minutesFromMidnight,
    required this.doseCount,
  });

  /// Whether this is a repeating request rather than a single instance.
  bool get repeatsDaily => day == null;

  // Deliberately no toString() override. A debug-only field dump is still a
  // literal carrying words under lib/, and the classification gate would need a
  // fourth allowlisted value to explain it — an exemption bought for nicer test
  // output. The tests here assert against explicit field projections instead.
}

/// Every reminder that should exist over the next [horizonDays] from [today].
///
/// One entry per (day, minute) with the number of doses due then. Ordered by day
/// and then by minute, and truncated to [budget] from the TAIL — both are
/// contractual, not incidental. An instant already in the past makes the plugin
/// throw rather than degrade, so today's slots at or before
/// [nowMinutesFromMidnight] are dropped; and truncating the tail keeps the
/// nearest reminders, which are the ones the user will actually be around for.
///
/// Every notification here is a one-shot instance. The daily-repeat promotion
/// for times where every contributing regimen runs daily is an iOS-budget
/// optimization, not a layer, and it lands in plan 07-02.
///
/// A paused regimen, a course with no end date and a regimen starting after the
/// window all fall out for free, because [isActiveOn] already answers all three.
/// None of them is special-cased.
List<PlannedNotification> planNotifications({
  required List<Regimen> regimens,
  required DateTime today,
  required int nowMinutesFromMidnight,
  required int horizonDays,
  required int budget,
}) {
  final start = dateOnly(today);
  final planned = <PlannedNotification>[];
  for (var offset = 0; offset < horizonDays; offset++) {
    // Exact on UTC date-only values: every day is precisely 24h in UTC.
    final day = start.add(Duration(days: offset));
    final counts = <int, int>{};
    for (final regimen in regimens) {
      if (!isActiveOn(regimen, day)) continue;
      for (final slot in regimen.slots) {
        if (offset == 0 && slot.minutesFromMidnight <= nowMinutesFromMidnight) {
          continue;
        }
        counts.update(
          slot.minutesFromMidnight,
          (count) => count + 1,
          ifAbsent: () => 1,
        );
      }
    }
    final minutes = counts.keys.toList()..sort();
    for (final minute in minutes) {
      planned.add(
        PlannedNotification(
          id: notificationIdFor(day: day, minutesFromMidnight: minute),
          day: day,
          minutesFromMidnight: minute,
          doseCount: counts[minute]!,
        ),
      );
    }
  }
  return List.unmodifiable(
    planned.length <= budget ? planned : planned.sublist(0, budget),
  );
}

/// The stable id for a reminder at [minutesFromMidnight] on [day].
///
/// `day == null` derives the id of the tier-A daily repeat at that time, which
/// can therefore never collide with a one-shot at the same minute.
///
/// A hand-written FNV-1a over `"tier|hhmm|yyyy-mm-dd"`, masked to the 32-bit
/// positive range the platform requires. Deliberately NOT Dart's own hash: this
/// id is a persisted cross-process key that the operating system holds on our
/// behalf between launches, and `hashCode` is not guaranteed stable across SDK
/// versions or platforms.
///
/// The fire TIME has to be folded in because the pending-request records the
/// platform hands back carry no scheduled time at all (07-RESEARCH §5.6):
/// without it, a slot moved from one hour to another is indistinguishable from
/// an unchanged one, and reconciliation would leave the old reminder armed
/// forever.
int notificationIdFor({
  required DateTime? day,
  required int minutesFromMidnight,
}) {
  final hour = (minutesFromMidnight ~/ 60).toString().padLeft(2, '0');
  final minute = (minutesFromMidnight % 60).toString().padLeft(2, '0');
  final buffer = StringBuffer(day == null ? 'A|' : 'B|')
    ..write(hour)
    ..write(minute);
  if (day != null) {
    buffer
      ..write('|')
      ..write(day.year.toString().padLeft(4, '0'))
      ..write('-')
      ..write(day.month.toString().padLeft(2, '0'))
      ..write('-')
      ..write(day.day.toString().padLeft(2, '0'));
  }
  return _fnv1a(buffer.toString());
}

/// FNV-1a, 32-bit, masked to the positive range. Ten lines, no dependency.
int _fnv1a(String key) {
  var hash = 0x811c9dc5;
  for (final byte in key.codeUnits) {
    hash = (hash ^ byte) & 0xffffffff;
    hash = (hash * 0x01000193) & 0xffffffff;
  }
  return hash & 0x7fffffff;
}
