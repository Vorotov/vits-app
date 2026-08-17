/// The whole correctness surface of Phase 7, tested as pure Dart.
///
/// `planNotifications` decides WHICH notifications should exist. Nothing below
/// needs a clock, a timezone, a plugin or a widget — `today` and
/// `nowMinutesFromMidnight` arrive as parameters, which is what makes the "a
/// slot exactly at now" boundary a test rather than a race.
library;

import 'package:boostque/core/domain/models.dart';
import 'package:boostque/core/notifications/notification_plan.dart';
import 'package:flutter_test/flutter_test.dart';

DoseSlot slot(int minutes, {String id = 'sl'}) =>
    DoseSlot(id: '$id-$minutes', minutesFromMidnight: minutes, doseLabel: '1');

Regimen cyclic({
  String id = 'r1',
  int on = 5,
  int off = 2,
  bool paused = false,
  DateTime? start,
  List<DoseSlot> slots = const [],
}) =>
    Regimen(
      id: id,
      supplementId: 's-$id',
      kind: RegimenKind.cyclic,
      startDate: start ?? DateTime.utc(2026, 8, 16),
      endDate: null,
      onDays: on,
      offDays: off,
      paused: paused,
      slots: slots,
    );

Regimen course({
  String id = 'c1',
  DateTime? start,
  DateTime? end,
  bool paused = false,
  List<DoseSlot> slots = const [],
}) =>
    Regimen(
      id: id,
      supplementId: 's-$id',
      kind: RegimenKind.course,
      startDate: start ?? DateTime.utc(2026, 8, 16),
      endDate: end ?? DateTime.utc(2026, 8, 18),
      onDays: 0,
      offDays: 0,
      paused: paused,
      slots: slots,
    );

/// The plan for [regimens], with the horizon and budget wide enough not to bind
/// unless a test says so.
List<PlannedNotification> planFor(
  List<Regimen> regimens, {
  DateTime? today,
  int nowMinutesFromMidnight = -1,
  int horizonDays = 30,
  int budget = 60,
}) =>
    planNotifications(
      regimens: regimens,
      today: today ?? DateTime.utc(2026, 8, 16),
      nowMinutesFromMidnight: nowMinutesFromMidnight,
      horizonDays: horizonDays,
      budget: budget,
    );

void main() {
  final today = DateTime.utc(2026, 8, 16);

  group('activity is decided by isActiveOn and nothing else', () {
    test('a 5-on/2-off cycle yields notifications only on its five active days',
        () {
      // 2026-08-16 is the start day, so days 0..4 are on and 5..6 are off.
      final plan = planFor([cyclic(slots: [slot(540)])], horizonDays: 14);

      expect(plan, hasLength(10));
      final days = plan.map((p) => p.day!.day).toList();
      expect(days, <int>[16, 17, 18, 19, 20, 23, 24, 25, 26, 27]);
      expect(plan.every((p) => p.minutesFromMidnight == 540), isTrue);
      expect(plan.every((p) => p.doseCount == 1), isTrue);
    });

    test('a course covers its start day and its INCLUSIVE end day, and stops',
        () {
      final plan = planFor(
        [
          course(
            start: DateTime.utc(2026, 8, 16),
            end: DateTime.utc(2026, 8, 18),
            slots: [slot(540)],
          ),
        ],
        horizonDays: 10,
      );

      expect(plan.map((p) => p.day!.day), <int>[16, 17, 18]);
    });

    test('a paused regimen yields nothing at all', () {
      expect(planFor([cyclic(paused: true, slots: [slot(540)])]), isEmpty);
      expect(planFor([course(paused: true, slots: [slot(540)])]), isEmpty);
    });

    test('a regimen with no slots yields nothing', () {
      expect(planFor([cyclic()]), isEmpty);
    });

    test('a course with no end date yields nothing — isActiveOn already says so',
        () {
      final open = Regimen(
        id: 'c-open',
        supplementId: 's',
        kind: RegimenKind.course,
        startDate: today,
        endDate: null,
        onDays: 0,
        offDays: 0,
        paused: false,
        slots: [slot(540)],
      );
      expect(planFor([open]), isEmpty);
    });

    test('a regimen starting after the horizon yields nothing', () {
      final plan = planFor(
        [cyclic(start: DateTime.utc(2026, 10, 1), slots: [slot(540)])],
        horizonDays: 7,
      );
      expect(plan, isEmpty);
    });

    test('a regimen starting mid-horizon starts contributing on its start day',
        () {
      final plan = planFor(
        [
          cyclic(
            start: DateTime.utc(2026, 8, 19),
            on: 30,
            off: 0,
            slots: [slot(540)],
          ),
        ],
        horizonDays: 7,
      );
      expect(plan.map((p) => p.day!.day), <int>[19, 20, 21, 22]);
    });
  });

  group('grouping — one notification per (day, minute), carrying a COUNT', () {
    test('three regimens at the same minute on the same day yield ONE with count 3',
        () {
      final plan = planFor(
        [
          cyclic(id: 'a', on: 30, off: 0, slots: [slot(480, id: 'a')]),
          cyclic(id: 'b', on: 30, off: 0, slots: [slot(480, id: 'b')]),
          cyclic(id: 'c', on: 30, off: 0, slots: [slot(480, id: 'c')]),
        ],
        horizonDays: 1,
      );

      expect(
        plan,
        hasLength(1),
        reason: 'one notification per time-of-day, never one per supplement — '
            'the phase\'s defining shape (NOTIF-01).',
      );
      expect(plan.single.doseCount, 3);
      expect(plan.single.minutesFromMidnight, 480);
      expect(plan.single.day, today);
    });

    test('two slots at different minutes yield two notifications, each counted',
        () {
      final plan = planFor(
        [
          cyclic(
            id: 'a',
            on: 30,
            off: 0,
            slots: [slot(480, id: 'a'), slot(1080, id: 'a')],
          ),
          cyclic(id: 'b', on: 30, off: 0, slots: [slot(1080, id: 'b')]),
        ],
        horizonDays: 1,
      );

      expect(plan, hasLength(2));
      expect(plan[0].minutesFromMidnight, 480);
      expect(plan[0].doseCount, 1);
      expect(plan[1].minutesFromMidnight, 1080);
      expect(plan[1].doseCount, 2);
    });

    test('a count never includes a regimen inactive on that particular day', () {
      // The daily regimen contributes every day; the 1-on/6-off one only on the
      // 16th. So the 16th has 2 doses at 08:00 and the 17th has 1.
      final plan = planFor(
        [
          cyclic(id: 'daily', on: 30, off: 0, slots: [slot(480, id: 'd')]),
          cyclic(id: 'rare', on: 1, off: 6, slots: [slot(480, id: 'r')]),
        ],
        horizonDays: 2,
      );

      expect(plan, hasLength(2));
      expect(plan[0].doseCount, 2);
      expect(plan[1].doseCount, 1);
    });

    test('every emitted notification is a one-shot in this plan', () {
      final plan = planFor([cyclic(on: 30, off: 0, slots: [slot(540)])]);
      expect(plan.every((p) => p.day != null), isTrue);
      expect(plan.every((p) => !p.repeatsDaily), isTrue);
    });

    test('the emitted order is by day, then by minute', () {
      final plan = planFor(
        [
          cyclic(
            on: 30,
            off: 0,
            slots: [slot(1320), slot(60), slot(720)],
          ),
        ],
        horizonDays: 2,
      );

      expect(
        plan.map((p) => '${p.day!.day}/${p.minutesFromMidnight}'),
        <String>['16/60', '16/720', '16/1320', '17/60', '17/720', '17/1320'],
      );
    });
  });

  group('the now boundary — nothing already past is ever planned', () {
    test("today's slots at or before now are absent; later ones are present", () {
      final plan = planFor(
        [
          cyclic(
            on: 30,
            off: 0,
            slots: [slot(480), slot(720), slot(1080)],
          ),
        ],
        horizonDays: 1,
        nowMinutesFromMidnight: 720,
      );

      expect(
        plan.map((p) => p.minutesFromMidnight),
        <int>[1080],
        reason: 'a slot exactly AT now is already past by the time the schedule '
            'call crosses the channel, and the plugin throws for a past instant '
            'rather than degrading (Pitfall 4).',
      );
    });

    test('the now boundary applies to today only, never to a later day', () {
      final plan = planFor(
        [cyclic(on: 30, off: 0, slots: [slot(480)])],
        horizonDays: 3,
        nowMinutesFromMidnight: 720,
      );
      expect(plan.map((p) => p.day!.day), <int>[17, 18]);
    });
  });

  group('the budget — enforced HERE so no platform behaviour is load-bearing',
      () {
    test('the returned length equals the budget exactly when the stack exceeds it',
        () {
      final plan = planFor(
        [
          cyclic(
            on: 30,
            off: 0,
            slots: [slot(480), slot(720), slot(1080)],
          ),
        ],
        horizonDays: 30,
        budget: 60,
      );

      expect(plan, hasLength(60));
    });

    test('truncation drops the FURTHEST-FUTURE instances first', () {
      final plan = planFor(
        [
          cyclic(
            on: 30,
            off: 0,
            slots: [slot(480), slot(1080)],
          ),
        ],
        horizonDays: 30,
        budget: 5,
      );

      expect(
        plan.map((p) => '${p.day!.day}/${p.minutesFromMidnight}'),
        <String>['16/480', '16/1080', '17/480', '17/1080', '18/480'],
        reason: 'the nearest reminders are the ones the user will actually be '
            'around for; dropping the head would silence today.',
      );
    });

    test('a budget of zero yields nothing rather than throwing', () {
      expect(planFor([cyclic(slots: [slot(540)])], budget: 0), isEmpty);
    });

    test('the horizon binds when it is the tighter of the two', () {
      final plan = planFor(
        [cyclic(on: 30, off: 0, slots: [slot(540)])],
        horizonDays: 3,
        budget: 60,
      );
      expect(plan, hasLength(3));
    });
  });

  group('notificationIdFor — a persisted cross-process key', () {
    test('is stable across calls and pinned against golden integers', () {
      // Goldens computed independently (FNV-1a 32-bit over the key string,
      // masked to the positive range) rather than read back from this
      // implementation, so a change of derivation cannot silently re-key every
      // pending notification the operating system is holding for us.
      expect(
        notificationIdFor(day: DateTime.utc(2026, 8, 16), minutesFromMidnight: 540),
        1937468571,
      );
      expect(
        notificationIdFor(day: DateTime.utc(2026, 8, 16), minutesFromMidnight: 600),
        982251745,
      );
      expect(
        notificationIdFor(day: DateTime.utc(2026, 8, 17), minutesFromMidnight: 540),
        1920690952,
      );
      expect(notificationIdFor(day: null, minutesFromMidnight: 540), 770972947);
      expect(
        notificationIdFor(day: DateTime.utc(2026, 8, 16), minutesFromMidnight: 0),
        1424878326,
      );
      expect(
        notificationIdFor(day: DateTime.utc(2026, 8, 16), minutesFromMidnight: 1439),
        1161732961,
      );
    });

    test('the same inputs give the same id twice', () {
      final first =
          notificationIdFor(day: DateTime.utc(2026, 8, 16), minutesFromMidnight: 540);
      final second =
          notificationIdFor(day: DateTime.utc(2026, 8, 16), minutesFromMidnight: 540);
      expect(first, second);
    });

    test('the same slot moved to another minute gets a different id', () {
      expect(
        notificationIdFor(day: DateTime.utc(2026, 8, 16), minutesFromMidnight: 540),
        isNot(notificationIdFor(
            day: DateTime.utc(2026, 8, 16), minutesFromMidnight: 600)),
        reason: 'the pending-request records the platform hands back carry no '
            'scheduled time at all (07-RESEARCH §5.6), so without the time in '
            'the id a slot moved 09:00 -> 10:00 is indistinguishable from an '
            'unchanged one and the old reminder stays armed forever.',
      );
    });

    test('the same minute on a different day gets a different id', () {
      expect(
        notificationIdFor(day: DateTime.utc(2026, 8, 16), minutesFromMidnight: 540),
        isNot(notificationIdFor(
            day: DateTime.utc(2026, 8, 17), minutesFromMidnight: 540)),
      );
    });

    test('a daily repeat and a one-shot at the same minute never collide', () {
      expect(
        notificationIdFor(day: null, minutesFromMidnight: 540),
        isNot(notificationIdFor(
            day: DateTime.utc(2026, 8, 16), minutesFromMidnight: 540)),
      );
    });

    test('every id over a wide sweep stays in the 32-bit positive range', () {
      for (var d = 0; d < 40; d++) {
        for (final minute in const [0, 1, 59, 540, 720, 1438, 1439]) {
          final id = notificationIdFor(
            day: DateTime.utc(2026, 8, 16).add(Duration(days: d)),
            minutesFromMidnight: minute,
          );
          expect(id, greaterThanOrEqualTo(0));
          expect(id, lessThanOrEqualTo(0x7fffffff));
        }
      }
    });

    test('the ids inside a plan are unique', () {
      final plan = planFor(
        [
          cyclic(
            on: 30,
            off: 0,
            slots: [slot(480), slot(720), slot(1080)],
          ),
        ],
        horizonDays: 20,
        budget: 60,
      );
      expect(plan.map((p) => p.id).toSet(), hasLength(plan.length));
    });

    test('each planned notification carries the id its own fields derive', () {
      final plan = planFor(
        [cyclic(on: 30, off: 0, slots: [slot(540)])],
        horizonDays: 1,
      );
      expect(
        plan.single.id,
        notificationIdFor(day: today, minutesFromMidnight: 540),
      );
    });
  });
}
