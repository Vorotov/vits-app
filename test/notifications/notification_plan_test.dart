/// The whole correctness surface of Phase 7, tested as pure Dart.
///
/// `planNotifications` decides WHICH notifications should exist. Nothing below
/// needs a clock, a timezone, a plugin or a widget — `today` and
/// `nowMinutesFromMidnight` arrive as parameters, which is what makes the "a
/// slot exactly at now" boundary a test rather than a race.
library;

import 'package:vitomy/core/domain/models.dart';
import 'package:vitomy/core/notifications/notification_constants.dart';
import 'package:vitomy/core/notifications/notification_plan.dart';
import 'package:vitomy/core/notifications/notification_scheduler.dart';
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

/// A regimen that runs every day from its start with no break, ever — the one
/// shape `runsEveryDayFrom` promotes to a repeat.
Regimen daily({
  String id = 'd1',
  DateTime? start,
  List<DoseSlot> slots = const [],
}) =>
    cyclic(id: id, on: 30, off: 0, start: start, slots: slots);

/// A regimen active on every day any test here looks at, but NOT promotable,
/// because it has a break — 60 days out, past every horizon in this file.
///
/// The tier-B tests below were written against `off: 0` when plan 07-01 had no
/// tier A and every entry was a one-shot. Their CLAIMS are about the one-shot
/// path — the day walk, the ordering by day, the now boundary, truncation from
/// the far future — and each one is preserved verbatim; only the fixture moved,
/// so that the subject of the test is still the tier the test is about. Using
/// `off: 0` there now would silently test the repeat path under a one-shot name.
Regimen tierB({
  String id = 'b1',
  DateTime? start,
  List<DoseSlot> slots = const [],
}) =>
    cyclic(id: id, on: 60, off: 1, start: start, slots: slots);

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
          tierB(id: 'a', slots: [slot(480, id: 'a')]),
          tierB(id: 'b', slots: [slot(480, id: 'b')]),
          tierB(id: 'c', slots: [slot(480, id: 'c')]),
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
          tierB(id: 'a', slots: [slot(480, id: 'a'), slot(1080, id: 'a')]),
          tierB(id: 'b', slots: [slot(1080, id: 'b')]),
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

    test('every notification a tier-B regimen emits is a one-shot', () {
      final plan = planFor([tierB(slots: [slot(540)])]);
      expect(plan.every((p) => p.day != null), isTrue);
      expect(plan.every((p) => !p.repeatsDaily), isTrue);
    });

    test('the emitted order is by day, then by minute', () {
      final plan = planFor(
        [
          tierB(slots: [slot(1320), slot(60), slot(720)]),
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
          tierB(slots: [slot(480), slot(720), slot(1080)]),
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
        [tierB(slots: [slot(480)])],
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
          tierB(slots: [slot(480), slot(720), slot(1080)]),
        ],
        horizonDays: 30,
        budget: 60,
      );

      expect(plan, hasLength(60));
    });

    test('truncation drops the FURTHEST-FUTURE instances first', () {
      final plan = planFor(
        [
          tierB(slots: [slot(480), slot(1080)]),
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
        [tierB(slots: [slot(540)])],
        horizonDays: 3,
        budget: 60,
      );
      expect(plan, hasLength(3));
    });
  });

  group('tier A — the minutes that cost one pending request forever', () {
    test('one daily regimen with one slot yields exactly ONE entry, a repeat',
        () {
      final plan = planFor([daily(slots: [slot(540)])], horizonDays: 30);

      expect(
        plan,
        hasLength(1),
        reason: 'one repeating request covers the whole horizon and never '
            'lapses — the entire point of the tier split (NOTIF-02).',
      );
      expect(plan.single.repeatsDaily, isTrue);
      expect(plan.single.day, isNull);
      expect(plan.single.minutesFromMidnight, 540);
      expect(plan.single.doseCount, 1);
      expect(plan.single.id, notificationIdFor(day: null, minutesFromMidnight: 540));
    });

    test('two daily regimens at the SAME minute yield one repeat with count 2',
        () {
      final plan = planFor([
        daily(id: 'a', slots: [slot(480, id: 'a')]),
        daily(id: 'b', slots: [slot(480, id: 'b')]),
      ]);

      expect(plan, hasLength(1));
      expect(plan.single.repeatsDaily, isTrue);
      expect(plan.single.doseCount, 2);
    });

    test('two daily regimens at different minutes yield two repeats and no '
        'one-shots', () {
      final plan = planFor([
        daily(id: 'a', slots: [slot(480, id: 'a')]),
        daily(id: 'b', slots: [slot(1080, id: 'b')]),
      ]);

      expect(plan.map((p) => p.minutesFromMidnight), <int>[480, 1080]);
      expect(plan.every((p) => p.repeatsDaily), isTrue);
    });

    test('a daily and a cycling-with-breaks regimen at the SAME minute yield '
        'one-shots and NO repeat', () {
      // The case a wrong promotion gets silently wrong: a repeat carries ONE
      // frozen dose count, so promoting this minute would under-report the
      // count on the cycling regimen's on-days and over-report it on its
      // off-days, forever, with nothing to notice.
      final plan = planFor(
        [
          daily(id: 'd', slots: [slot(480, id: 'd')]),
          cyclic(id: 'rare', on: 1, off: 6, slots: [slot(480, id: 'r')]),
        ],
        horizonDays: 7,
      );

      expect(plan.any((p) => p.repeatsDaily), isFalse);
      expect(
        plan.map((p) => '${p.day!.day}:${p.doseCount}'),
        <String>['16:2', '17:1', '18:1', '19:1', '20:1', '21:1', '22:1'],
      );
    });

    test('a daily regimen and a course sharing a minute: one-shots only', () {
      final plan = planFor(
        [
          daily(id: 'd', slots: [slot(480, id: 'd')]),
          course(
            id: 'c',
            start: DateTime.utc(2026, 8, 16),
            end: DateTime.utc(2026, 8, 17),
            slots: [slot(480, id: 'c')],
          ),
        ],
        horizonDays: 3,
      );

      expect(plan.any((p) => p.repeatsDaily), isFalse);
      expect(
        plan.map((p) => '${p.day!.day}:${p.doseCount}'),
        <String>['16:2', '17:2', '18:1'],
      );
    });

    test('a daily and a cycling regimen at DIFFERENT minutes: the two tiers '
        'coexist in one plan', () {
      final plan = planFor(
        [
          daily(id: 'd', slots: [slot(480, id: 'd')]),
          cyclic(id: 'rare', on: 1, off: 6, slots: [slot(1080, id: 'r')]),
        ],
        horizonDays: 7,
      );

      expect(plan, hasLength(2));
      expect(plan[0].repeatsDaily, isTrue);
      expect(plan[0].minutesFromMidnight, 480);
      expect(plan[1].repeatsDaily, isFalse);
      expect(plan[1].minutesFromMidnight, 1080);
      expect(plan[1].day, DateTime.utc(2026, 8, 16));
    });

    test('a daily regimen starting TOMORROW yields one-shots, not a repeat', () {
      final plan = planFor(
        [daily(start: DateTime.utc(2026, 8, 17), slots: [slot(540)])],
        horizonDays: 4,
      );

      expect(
        plan.any((p) => p.repeatsDaily),
        isFalse,
        reason: 'a repeat armed today would start firing before the regimen '
            'begins; it is promoted on its start date by the ordinary '
            're-derivation.',
      );
      expect(plan.map((p) => p.day!.day), <int>[17, 18, 19]);
    });

    test('a promoted minute contributes ZERO one-shots', () {
      final plan = planFor(
        [
          daily(id: 'd', slots: [slot(480, id: 'd')]),
          cyclic(id: 'rare', on: 1, off: 6, slots: [slot(1080, id: 'r')]),
        ],
        horizonDays: 30,
      );

      expect(
        plan.where((p) => p.day != null && p.minutesFromMidnight == 480),
        isEmpty,
        reason: 'leaving the one-shots in place as a backstop would double '
            'every reminder at that minute, on every day, and spend exactly '
            'the budget the promotion was meant to save.',
      );
    });

    test('a promoted minute already past NOW today is still emitted', () {
      final plan = planFor(
        [daily(slots: [slot(480)])],
        horizonDays: 3,
        nowMinutesFromMidnight: 720,
      );

      expect(
        plan.single.repeatsDaily,
        isTrue,
        reason: "a repeat's first fire is computed by the platform from the "
            'time components, not from an instant this function chose, so only '
            'a one-shot can be in the past.',
      );
    });

    test('every repeat sorts ahead of every one-shot', () {
      final plan = planFor(
        [
          daily(id: 'd', slots: [slot(1380, id: 'd')]),
          cyclic(id: 'rare', on: 20, off: 1, slots: [slot(60, id: 'r')]),
        ],
        horizonDays: 3,
      );

      expect(plan.first.repeatsDaily, isTrue);
      expect(
        plan.skip(1).every((p) => !p.repeatsDaily),
        isTrue,
        reason: 'even a 23:00 repeat outranks a 01:00 one-shot today — the '
            'ordering is by tier first, and it is the ONLY thing protecting '
            'tier A from truncation.',
      );
    });
  });

  group('the budget can never drop a repeat', () {
    List<PlannedNotification> mixedStack({required int budget}) => planFor(
          [
            daily(id: 'd', slots: [slot(480, id: 'd')]),
            cyclic(
              id: 'b',
              on: 60,
              off: 1,
              slots: [slot(600, id: 'b'), slot(720, id: 'b'), slot(840, id: 'b')],
            ),
          ],
          horizonDays: 30,
          budget: budget,
        );

    test('a stack whose one-shots alone exhaust the budget keeps every repeat',
        () {
      final unbudgeted = mixedStack(budget: 10000);
      final budgeted = mixedStack(budget: 60);

      expect(unbudgeted, hasLength(91)); // 1 repeat + 90 one-shots
      expect(budgeted, hasLength(60));
      expect(
        budgeted.where((p) => p.repeatsDaily).length,
        unbudgeted.where((p) => p.repeatsDaily).length,
        reason: 'a repeat never lapses and costs one request forever, while a '
            'one-shot beyond the horizon is a reminder that simply stops — '
            'given a fixed ceiling, spending it on the entries that never '
            'lapse is strictly better.',
      );
      expect(budgeted.first.repeatsDaily, isTrue);
    });

    test('the surviving one-shots are the NEAREST ones', () {
      final plan = mixedStack(budget: 5);
      expect(
        plan.map((p) => p.repeatsDaily
            ? 'repeat/${p.minutesFromMidnight}'
            : '${p.day!.day}/${p.minutesFromMidnight}'),
        <String>['repeat/480', '16/600', '16/720', '16/840', '17/600'],
      );
    });

    test('a stack whose REPEATS alone exceed the budget keeps the earliest '
        'minutes of the day', () {
      // Unreachable with the app's six-slots-per-regimen cap and a plausible
      // stack — and tested anyway, because "unreachable" is a claim about
      // today's product, not a property of this function.
      final plan = planFor(
        [
          daily(slots: [
            slot(60),
            slot(120),
            slot(180),
            slot(240),
            slot(300),
            slot(360),
            slot(420),
            slot(480),
          ]),
        ],
        budget: 5,
      );

      expect(plan, hasLength(5));
      expect(plan.every((p) => p.repeatsDaily), isTrue);
      expect(plan.map((p) => p.minutesFromMidnight), <int>[60, 120, 180, 240, 300]);
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
          tierB(slots: [slot(480), slot(720), slot(1080)]),
        ],
        horizonDays: 20,
        budget: 60,
      );
      expect(plan.map((p) => p.id).toSet(), hasLength(plan.length));
    });

    test('each planned notification carries the id its own fields derive', () {
      final plan = planFor(
        [tierB(slots: [slot(540)])],
        horizonDays: 1,
      );
      expect(
        plan.single.id,
        notificationIdFor(day: today, minutesFromMidnight: 540),
      );
    });
  });

  group('reconcile — the difference, including the one the ids cannot see', () {
    /// A desired entry at [minute], with the text already rendered.
    DesiredNotification want(
      int minute, {
      DateTime? day,
      String title = 'Час прийому',
      String body = '1 прийом',
    }) =>
        DesiredNotification(
          notification: PlannedNotification(
            id: notificationIdFor(day: day, minutesFromMidnight: minute),
            day: day,
            minutesFromMidnight: minute,
            doseCount: 1,
          ),
          title: title,
          body: body,
        );

    /// The platform's record of [d], as it would report it after scheduling.
    PendingNotification held(DesiredNotification d) => PendingNotification(
          id: d.id,
          title: d.title,
          body: d.body,
          payload: doseTapPayload,
        );

    test('desired and pending identical, ids AND text: an empty diff both ways',
        () {
      final desired = [want(480, day: today), want(600)];
      final diff = reconcile(
        desired: desired,
        pending: desired.map(held).toList(),
      );

      expect(diff.toCancel, isEmpty);
      expect(diff.toSchedule, isEmpty);
    });

    test('an id in desired and absent from pending is scheduled, and nothing '
        'is cancelled', () {
      final diff = reconcile(
        desired: [want(480, day: today)],
        pending: const [],
      );

      expect(diff.toCancel, isEmpty);
      expect(diff.toSchedule.single.notification.minutesFromMidnight, 480);
    });

    test('an id in pending and absent from desired is cancelled, and nothing '
        'is scheduled', () {
      final stale = want(480, day: today);
      final diff = reconcile(desired: const [], pending: [held(stale)]);

      expect(diff.toCancel, <int>{stale.id});
      expect(diff.toSchedule, isEmpty);
    });

    test('THE LOCALE CASE: the same id with the same title but a different '
        'body is cancelled AND re-scheduled', () {
      // The single test that would fail if someone later "simplified" the
      // comparison back to ids. A language change produces an IDENTICAL desired
      // id set — ids carry no locale — so an id-only diff is empty and the
      // notifications keep their old-language text for the whole horizon,
      // silently, with nothing but this able to notice.
      final ukrainian = want(480, day: today, body: '3 прийоми');
      final english = want(480, day: today, body: '3 doses');

      final diff = reconcile(desired: [english], pending: [held(ukrainian)]);

      expect(diff.toCancel, <int>{english.id});
      expect(diff.toSchedule.single.body, '3 doses');
      expect(
        diff.toSchedule.single.id,
        english.id,
        reason: 'the id is unchanged — which is exactly why the text has to be '
            'what is compared.',
      );
    });

    test('a different title and the same body: the same result', () {
      final before = want(480, day: today, title: 'Час прийому');
      final after = want(480, day: today, title: 'Time to take');

      final diff = reconcile(desired: [after], pending: [held(before)]);

      expect(diff.toCancel, <int>{after.id});
      expect(diff.toSchedule.single.title, 'Time to take');
    });

    test('a pending id the plan has never produced is cancelled, not ignored',
        () {
      // A leftover from an older build with a different id scheme.
      const leftover = PendingNotification(
        id: 12345,
        title: 'from an older build',
        body: 'with a different id scheme',
      );
      final diff = reconcile(
        desired: [want(480, day: today)],
        pending: [leftover],
      );

      expect(diff.toCancel, <int>{12345});
      expect(diff.toSchedule, hasLength(1));
    });

    test('the schedule list carries the FULL planned entry, not just an id', () {
      final diff = reconcile(desired: [want(480)], pending: const []);
      final scheduled = diff.toSchedule.single.notification;

      expect(scheduled.repeatsDaily, isTrue);
      expect(scheduled.minutesFromMidnight, 480);
      expect(scheduled.doseCount, 1);
      expect(
        scheduled.id,
        notificationIdFor(day: null, minutesFromMidnight: 480),
        reason: 'so the caller needs no second lookup and cannot mismatch one.',
      );
    });

    test('an empty desired set against a large pending set cancels every id '
        'INDIVIDUALLY', () {
      final held0 = List.generate(
        40,
        (i) => held(want(i * 30, day: today.add(Duration(days: i)))),
      );

      final diff = reconcile(desired: const [], pending: held0);

      expect(diff.toCancel, held0.map((p) => p.id).toSet());
      expect(diff.toCancel, hasLength(40));
      expect(
        diff.toSchedule,
        isEmpty,
        reason: 'and there is no third field asking to clear everything: a '
            'blanket clear also dismisses delivered reminders the user has not '
            'acted on, and leaves a window with nothing scheduled.',
      );
    });

    test('IDEMPOTENCE: applying the diff and running it again gives an empty '
        'diff', () {
      final pending = [
        held(want(480, day: today)), // survives untouched
        held(want(600, day: today, body: 'старий текст')), // stale text
        held(want(720, day: today)), // no longer desired
      ];
      final desired = [
        want(480, day: today),
        want(600, day: today, body: 'новий текст'),
        want(1080, day: today), // brand new
      ];

      final first = reconcile(desired: desired, pending: pending);
      expect(first.toCancel, hasLength(2)); // the stale one and the dropped one
      expect(first.toSchedule, hasLength(2)); // the stale one and the new one

      // Apply it, exactly as the caller will: drop the cancelled, add the
      // scheduled with the text that was actually sent.
      final applied = <PendingNotification>[
        ...pending.where((p) => !first.toCancel.contains(p.id)),
        ...first.toSchedule.map(held),
      ];

      final second = reconcile(desired: desired, pending: applied);
      expect(
        second.toCancel,
        isEmpty,
        reason: 'a plan that keeps asking for something already scheduled '
            'turns every resume into dozens of platform round trips.',
      );
      expect(second.toSchedule, isEmpty);
    });
  });
}
