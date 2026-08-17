/// Which dose reminders should exist, and what must change for the platform to
/// be holding them — the whole correctness surface of Phase 7 (NOTIF-01,
/// NOTIF-02's budget half, NOTIF-04).
///
/// Pure, in the `planner_view_model.dart` sense: this library imports the two
/// pure domain libraries and the seam's pending-request value type, and nothing
/// else — and each of those three is itself import-free or domain-only. No
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
// The seam's PENDING-REQUEST value type only, and it is pure: this file imports
// nothing that imports anything (`notification_scheduler.dart` has no imports
// at all). `reconcile` compares against the platform's own record, so it has to
// name the type the platform's record arrives as.
import 'package:boostque/core/notifications/notification_scheduler.dart';

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
/// Two tiers, and which one a minute of day lands in is decided ONCE, here:
///
/// - **A repeat.** A minute is promoted to a single repeating request exactly
///   when EVERY regimen contributing a slot at that minute will run every day
///   from [today] onward ([runsEveryDayFrom]). It emits one entry with a null
///   day and the count of contributing slots, and NOTHING else for that minute.
///   It costs one pending request no matter how long the app runs, and never
///   lapses.
/// - **One-shots.** Every other minute gets one entry per active day in the
///   horizon, exactly as before.
///
/// The promotion is computed per MINUTE over the whole regimen set, never per
/// regimen, because the notification is per minute. A minute is a shared
/// surface: a repeat carries a single frozen dose count, so it is truthful only
/// when the set of doses at that minute is the same every day. So a minute that
/// even one cycling-with-breaks regimen or one course touches falls back
/// wholesale rather than promoting the daily half and one-shotting the rest —
/// which would also mean two notifications at the same minute, two buzzes at
/// once, the thing the whole grouping decision exists to prevent. A contributor
/// that will never actually fire (suspended, or already over) also blocks the
/// promotion: the fallback is always CORRECT, merely more expensive, so being
/// conservative here can only cost requests, never truthfulness.
///
/// Ordering is contractual, not incidental: every repeat first, by minute; then
/// the one-shots by day and then by minute; and [budget] applied to the TAIL.
/// That ordering is the ONLY mechanism protecting the repeats from truncation,
/// and it is worth saying what it buys. A repeat never lapses and costs one
/// request forever, while a one-shot beyond the horizon is a reminder that
/// simply stops. Given a fixed ceiling, spending it on the entries that never
/// lapse is strictly better, and truncating from the far future keeps the
/// reminders the user will actually be present for. This is also why the budget
/// is enforced HERE and not in the platform adapter: the platform's behaviour at
/// its own ceiling is described differently by two credible sources
/// (07-RESEARCH R-11), and a plan that never reaches the ceiling never has to
/// know which is right.
///
/// An instant already in the past makes the plugin throw rather than degrade, so
/// today's slots at or before [nowMinutesFromMidnight] are dropped — one-shots
/// ONLY. A promoted minute earlier than the current minute is still emitted,
/// because a repeat's first fire is computed by the platform from the time
/// components and the adapter's next-occurrence helper, not from an instant this
/// function chose.
///
/// A suspended regimen, a course with no end date and a regimen starting after
/// the window all fall out of the one-shot walk for free, because [isActiveOn]
/// already answers all three. None of them is special-cased.
List<PlannedNotification> planNotifications({
  required List<Regimen> regimens,
  required DateTime today,
  required int nowMinutesFromMidnight,
  required int horizonDays,
  required int budget,
}) {
  final start = dateOnly(today);

  // Pass 1 — the tier question, asked per minute over the whole set. The
  // question itself is never re-derived here: it is `runsEveryDayFrom`, which
  // lives beside the activity rule whose shape it mirrors.
  final repeatCounts = <int, int>{};
  final blocked = <int>{};
  for (final regimen in regimens) {
    final everyDay = runsEveryDayFrom(regimen, start);
    for (final slot in regimen.slots) {
      if (everyDay) {
        repeatCounts.update(
          slot.minutesFromMidnight,
          (count) => count + 1,
          ifAbsent: () => 1,
        );
      } else {
        blocked.add(slot.minutesFromMidnight);
      }
    }
  }
  final promoted = repeatCounts.keys.toSet()..removeAll(blocked);

  final planned = <PlannedNotification>[];
  for (final minute in promoted.toList()..sort()) {
    planned.add(
      PlannedNotification(
        id: notificationIdFor(day: null, minutesFromMidnight: minute),
        day: null,
        minutesFromMidnight: minute,
        doseCount: repeatCounts[minute]!,
      ),
    );
  }

  // Pass 2 — one-shots, for every minute the promotion did not take.
  for (var offset = 0; offset < horizonDays; offset++) {
    // Exact on UTC date-only values: every day is precisely 24h in UTC.
    final day = start.add(Duration(days: offset));
    final counts = <int, int>{};
    for (final regimen in regimens) {
      if (!isActiveOn(regimen, day)) continue;
      for (final slot in regimen.slots) {
        if (promoted.contains(slot.minutesFromMidnight)) continue;
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

/// A planned reminder together with the text that WILL be scheduled for it.
///
/// The pairing exists because the id cannot carry the text and the reconciler
/// has to compare both — see [reconcile]. Rendering the copy is the caller's
/// job (it needs a locale, and this library has none); deciding what to do with
/// the difference is this library's.
class DesiredNotification {
  /// What to schedule.
  final PlannedNotification notification;

  /// The title as it will be handed to the platform, already localized.
  final String title;

  /// The body as it will be handed to the platform, already localized.
  final String body;

  const DesiredNotification({
    required this.notification,
    required this.title,
    required this.body,
  });

  /// The id of [notification] — never a second, independent id.
  int get id => notification.id;
}

/// What must change for the platform to be holding [desired] instead of
/// [pending]: ids to cancel, entries to schedule.
///
/// Four rules, and nothing else:
///
/// 1. a matched id whose title AND body both match is satisfied, and appears in
///    neither output;
/// 2. a matched id whose text differs is cancelled AND re-scheduled;
/// 3. a pending id that is not desired is cancelled;
/// 4. a desired id that is not pending is scheduled.
///
/// **Rule 2 is the one worth explaining, because implementing past it is
/// silent.** Ids are derived from tier, time and date, and they carry NO locale
/// (see [notificationIdFor]). A language change therefore produces an identical
/// desired id set, so an id-only set difference computes an empty diff and does
/// nothing at all — the notifications keep their old-language text for up to the
/// whole horizon, with nothing but a test able to notice (07-UI-SPEC
/// DECIDED-16). Comparing the text is also self-correcting in a second way
/// worth having on its own: it repairs a re-derivation that was interrupted
/// halfway through, with no special-case trigger and no persisted "we were in
/// the middle of something" flag. The alternative the UI contract also permits —
/// treating a language change as a distinguished trigger that forces a full
/// cancel-and-reschedule — was NOT chosen: it needs that trigger to be plumbed
/// correctly forever, whereas comparing what is actually there needs nothing to
/// be remembered.
///
/// Comparing the text is possible only because the platform's pending-request
/// record happens to carry the title and body ([PendingNotification], from
/// 07-RESEARCH §5.6). The same record carries no scheduled TIME, which is the
/// same fact seen from the other side — it is why the fire time has to be folded
/// into the id instead.
///
/// The payload is deliberately not compared: the whole app has exactly one
/// payload token, so it cannot differ between two records the current build
/// wrote, and a record an older build wrote is cancelled by rule 3 anyway.
///
/// **There is no instruction to clear everything, in any input combination** —
/// including an empty [desired] against a large [pending], which returns every
/// pending id as an individual cancellation. A blanket clear also dismisses
/// reminders that were delivered and that the user has not acted on yet, and it
/// leaves a window in which nothing at all is scheduled. Cancelling by id is not
/// merely tidier: it is the difference between a re-derivation the user cannot
/// perceive and one that eats a notification they were about to act on.
///
/// Pure, and deliberately imposes no I/O ordering. Cancels before schedules, or
/// interleaved, is the caller's concern, and the caller has a reason to prefer
/// one; encoding an order here would only be something to work around.
({Set<int> toCancel, List<DesiredNotification> toSchedule}) reconcile({
  required List<DesiredNotification> desired,
  required List<PendingNotification> pending,
}) {
  final held = <int, PendingNotification>{
    for (final p in pending) p.id: p,
  };
  final wanted = <int>{for (final d in desired) d.id};

  final toCancel = <int>{};
  final toSchedule = <DesiredNotification>[];

  for (final d in desired) {
    final current = held[d.id];
    if (current != null && current.title == d.title && current.body == d.body) {
      continue; // rule 1
    }
    if (current != null) toCancel.add(d.id); // rule 2
    toSchedule.add(d); // rules 2 and 4
  }
  for (final p in pending) {
    if (!wanted.contains(p.id)) toCancel.add(p.id); // rule 3
  }

  return (toCancel: toCancel, toSchedule: toSchedule);
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
