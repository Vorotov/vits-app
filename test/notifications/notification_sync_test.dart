/// The sync: one debounced application of one reconciled difference, and the
/// triggers that cause it (NOTIF-03's silent half, NOTIF-04).
///
/// Everything here runs against a MOCKED seam and a mocked regimen stream, not
/// a real database — what is under test is the triggers and the difference,
/// never persistence. The clock is the app's own injectable wall-clock read, so
/// the "a slot exactly at now" boundary is pinnable here rather than being a
/// race.
///
/// The bootstrap is a test double returning a fixed readiness answer, so these
/// tests observe what the SYNC did and nothing the bootstrap did. The one place
/// the real bootstrap is used is the language-change trigger, which is exactly
/// the case where the two have to move together.
library;

import 'dart:async';
import 'dart:io';

import 'package:boostque/core/domain/models.dart';
import 'package:boostque/core/l10n/gen/app_localizations.dart';
import 'package:boostque/core/notifications/notification_constants.dart';
import 'package:boostque/core/notifications/notification_copy.dart';
import 'package:boostque/core/notifications/notification_locale.dart';
import 'package:boostque/core/notifications/notification_permission.dart';
import 'package:boostque/core/notifications/notification_plan.dart';
import 'package:boostque/core/notifications/notification_providers.dart';
import 'package:boostque/core/notifications/notification_scheduler.dart';
import 'package:boostque/core/notifications/notification_sync.dart';
import 'package:boostque/core/notifications/tz_conversion.dart';
import 'package:boostque/core/providers.dart';
import 'package:boostque/core/today_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:timezone/timezone.dart' as tz;

import 'recording_scheduler.dart';

/// The day every fixture below is anchored on, and the wall clock it is read
/// with — 09:00, so a 09:00 slot is exactly AT now and a 10:00 slot is after it.
final today = DateTime.utc(2026, 8, 17);
final tomorrow = DateTime.utc(2026, 8, 18);
DateTime wallClock = DateTime(2026, 8, 17, 9);

const uk = Locale('uk');
const en = Locale('en');

/// The app's primary audience's zone, and one seven hours west of it.
const kyiv = 'Europe/Kyiv';
const newYork = 'America/New_York';

/// Delivers a real platform lifecycle message, the way the engine does.
///
/// `WidgetsBinding.handleAppLifecycleStateChanged` is `@protected`; the channel
/// is the supported test seam. Taken verbatim from `today_provider_test.dart`,
/// which drives the OTHER lifecycle listener in this app the same way.
Future<void> sendLifecycle(WidgetTester tester, AppLifecycleState state) async {
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    'flutter/lifecycle',
    const StringCodec().encodeMessage(state.toString()),
    (_) {},
  );
}

/// The calendar clock with its day pinned and its wall clock injected.
///
/// Subclassed rather than mocked so the sync reads the SAME `now` seam
/// production reads — the one `TodayController`'s own doc calls the one
/// wall-clock read in the app.
class FixedToday extends TodayController {
  FixedToday(this._day, {super.now});

  DateTime _day;

  @override
  DateTime build() => _day;

  /// Rolls the calendar day over, the way the midnight timer does.
  void rollTo(DateTime day) {
    _day = day;
    state = day;
  }
}

/// A bootstrap whose readiness answer is fixed, so the sync's precondition can
/// be driven without running the real one.
class FixedBootstrap extends NotificationBootstrap {
  FixedBootstrap({required this.ready});

  final bool ready;

  @override
  bool build() => ready;
}

DoseSlot slot(int minutes) =>
    DoseSlot(id: 'sl-$minutes', minutesFromMidnight: minutes, doseLabel: '1');

/// A two-day course: tier B by construction (a course can never be promoted to
/// a repeat), and short enough that every scheduled call can be asserted by
/// name.
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
      startDate: start ?? today,
      endDate: end ?? tomorrow,
      onDays: 0,
      offDays: 0,
      paused: paused,
      slots: slots,
    );

/// A regimen that runs every day from its start with no break — the one shape
/// the pure plan promotes to a single repeating request.
Regimen daily({String id = 'd1', List<DoseSlot> slots = const []}) => Regimen(
      id: id,
      supplementId: 's-$id',
      kind: RegimenKind.cyclic,
      startDate: today,
      endDate: null,
      onDays: 30,
      offDays: 0,
      paused: false,
      slots: slots,
    );

void main() {
  late RecordingScheduler scheduler;
  late FixedToday clock;
  late ProviderContainer container;
  late List<Regimen> regimens;
  late void Function(List<Regimen>) emit;

  /// Builds the container. [ready] drives the bootstrap precondition;
  /// [realBootstrap] swaps the double for the real notifier, which is what the
  /// language-change case needs.
  ProviderContainer build({
    bool ready = true,
    bool realBootstrap = false,
    Future<String> Function()? zoneReader,
  }) {
    late final StreamController<List<Regimen>> regimenStream;
    regimenStream = StreamController<List<Regimen>>.broadcast();
    // A FRESH list per emission, because a Drift query builds one per result
    // and because Riverpod compares states: re-emitting the identical list
    // instance produces an equal AsyncData, no listener fires at all, and a
    // debounce test written that way would pass without a debounce existing.
    emit = (list) => regimenStream.add(List<Regimen>.of(list));
    clock = FixedToday(today, now: () => wallClock);
    return ProviderContainer(
      overrides: [
        notificationSchedulerProvider.overrideWithValue(scheduler),
        timeZoneLoaderProvider.overrideWithValue(() async {}),
        if (zoneReader != null)
          deviceZoneReaderProvider.overrideWithValue(zoneReader),
        todayProvider.overrideWith(() => clock),
        regimensStreamProvider.overrideWith((ref) {
          ref.onDispose(regimenStream.close);
          return regimenStream.stream;
        }),
        if (!realBootstrap)
          notificationBootstrapProvider
              .overrideWith(() => FixedBootstrap(ready: ready)),
      ],
    );
  }

  // The copy layer formats the time fragment, and the formatting data for a
  // locale has to have been loaded before it can. In the app that is free: the
  // resolved locale is only ever reported by a tree that has ALREADY loaded
  // that locale's material localizations, and loading them is what initializes
  // the formatting symbols. A container test loads no localizations, so it does
  // it here — the same set-up the copy tests and the month-name tests carry.
  setUpAll(() async {
    for (final locale in AppLocalizations.supportedLocales) {
      await initializeDateFormatting(locale.toString());
    }
  });

  setUp(() {
    scheduler = RecordingScheduler();
    wallClock = DateTime(2026, 8, 17, 9);
    regimens = const <Regimen>[];
  });

  tearDown(() => container.dispose());

  /// Advances past the debounce window and drains the application.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(notificationSyncDebounce);
    await tester.pump();
  }

  /// Mounts the container, keeps the sync alive the way the root app widget
  /// does, and reports a locale.
  Future<void> start(
    WidgetTester tester, {
    Locale? locale = uk,
    bool ready = true,
    bool realBootstrap = false,
    Future<String> Function()? zoneReader,
  }) async {
    container = build(
      ready: ready,
      realBootstrap: realBootstrap,
      zoneReader: zoneReader,
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const SizedBox.shrink(),
      ),
    );
    container.listen(notificationSyncProvider, (_, _) {});
    container.listen(notificationBootstrapProvider, (_, _) {});
    if (locale != null) {
      container.read(notificationLocaleProvider.notifier).report(locale);
    }
    emit(regimens);
    await settle(tester);
  }

  int applications() => container.read(notificationSyncProvider);

  group('the precondition and the permission gate', () {
    testWidgets('nothing at all is called while the bootstrap flag is false',
        (tester) async {
      regimens = [
        course(slots: [slot(600)])
      ];
      await start(tester, ready: false);

      expect(
        scheduler.calls,
        isEmpty,
        reason: 'before setLocalLocation runs, a zoned value silently comes out '
            'as UTC and every reminder is off by the device offset. The flag is '
            'a value a reader can see, where an ordering comment is a promise a '
            'refactor can break.',
      );
      expect(applications(), 0);
    });

    testWidgets('nothing at all is called while no locale has been observed',
        (tester) async {
      regimens = [
        course(slots: [slot(600)])
      ];
      await start(tester, locale: null);

      expect(scheduler.calls, isEmpty,
          reason: 'there is no language to build the text in.');
    });

    testWidgets('a denied permission produces zero schedule and zero cancel '
        'calls', (tester) async {
      scheduler.enabled = false;
      scheduler.held = [const PendingNotification(id: 42)];
      regimens = [
        course(slots: [slot(600)])
      ];
      await start(tester);

      expect(
        scheduler.mutations,
        isEmpty,
        reason: 'not "tries and swallows the failures" — that is dozens of '
            'failing platform calls per trigger. The app stays fully functional '
            'and silent.',
      );
    });

    testWidgets('an unanswerable permission check — the third real state — '
        'likewise produces nothing', (tester) async {
      scheduler.enabled = null;
      regimens = [
        course(slots: [slot(600)])
      ];
      await start(tester);

      expect(scheduler.mutations, isEmpty);
    });
  });

  group('the applied difference', () {
    testWidgets('exactly the desired one-shots are scheduled, with the rendered '
        'copy, and nothing is cancelled against an empty pending set',
        (tester) async {
      regimens = [
        course(slots: [slot(600)])
      ];
      await start(tester);

      final expected = <int>[
        notificationIdFor(day: today, minutesFromMidnight: 600),
        notificationIdFor(day: tomorrow, minutesFromMidnight: 600),
      ];
      expect(
        scheduler.mutations.map((c) => c.method).toList(),
        <String>[scheduleOnceCall, scheduleOnceCall],
      );
      expect(scheduler.mutations.map((c) => c.id).toList(), expected);
      expect(scheduler.mutations.map((c) => c.day).toList(),
          <DateTime>[today, tomorrow]);
      expect(scheduler.mutations.map((c) => c.minutesFromMidnight).toList(),
          <int>[600, 600]);
      for (final call in scheduler.mutations) {
        expect(call.title, notificationTitle(uk));
        expect(
          call.body,
          notificationBody(
            locale: uk,
            doseCount: 1,
            minutesFromMidnight: 600,
          ),
        );
      }
      expect(applications(), 1);
    });

    testWidgets('a promoted minute is scheduled through the REPEAT method, '
        'chosen from the entry\'s own tier', (tester) async {
      regimens = [
        daily(slots: [slot(600)])
      ];
      await start(tester);

      expect(
        scheduler.mutations.map((c) => c.method).toSet(),
        <String>{scheduleDailyCall},
        reason: 'a repeat and a one-shot are separate methods on the seam '
            'precisely so that "a course must never repeat" is structurally '
            'true rather than dependent on a conditional argument.',
      );
      expect(scheduler.mutations.single.id,
          notificationIdFor(day: null, minutesFromMidnight: 600));
      expect(scheduler.mutations.single.day, isNull);
    });

    testWidgets('a pending request that is no longer desired is cancelled by '
        'id, before anything is scheduled', (tester) async {
      scheduler.held = const [PendingNotification(id: 4242)];
      regimens = [
        course(slots: [slot(600)])
      ];
      await start(tester);

      expect(scheduler.mutations.first.method, cancelCall);
      expect(scheduler.mutations.first.id, 4242);
      expect(
        scheduler.mutations.where((c) => c.method == cancelCall).length,
        1,
        reason: 'cancelling by id is the difference between a re-derivation the '
            'user cannot perceive and one that eats a delivered reminder they '
            'were about to act on. There is no blanket clear anywhere.',
      );
    });

    testWidgets('a second application against an unchanged world issues no '
        'schedule and no cancel at all', (tester) async {
      regimens = [
        course(slots: [slot(600)])
      ];
      await start(tester);
      // What the platform now holds is exactly what was just scheduled.
      scheduler.held = scheduler.mutations
          .map((c) => PendingNotification(
                id: c.id!,
                title: c.title,
                body: c.body,
              ))
          .toList();
      scheduler.calls.clear();

      emit(regimens);
      await settle(tester);

      expect(applications(), 2, reason: 'the second application did happen');
      expect(
        scheduler.mutations,
        isEmpty,
        reason: 'the difference is empty, so nothing crosses the platform '
            'channel. Only the two READS — the permission check and the pending '
            'list — happen, and they are what make the emptiness knowable.',
      );
      expect(
        scheduler.calls.map((c) => c.method).toList(),
        <String>[isEnabledCall, pendingCall],
      );
    });

    testWidgets('a one-shot the adapter skips does not abort the rest of the '
        'batch', (tester) async {
      // The real adapter returns early for an instant that has already passed
      // between planning and scheduling — a real race on a 09:05 resume with a
      // 09:00 slot. This recorder mimics that shape exactly: it returns
      // normally and schedules nothing.
      scheduler.skipIds = {
        notificationIdFor(day: today, minutesFromMidnight: 600),
      };
      regimens = [
        course(slots: [slot(600)])
      ];
      await start(tester);

      expect(scheduler.mutations.map((c) => c.id).toList(), <int>[
        notificationIdFor(day: tomorrow, minutesFromMidnight: 600),
      ]);
      expect(applications(), 1);
    });
  });

  group('the wall clock the plan is built against', () {
    testWidgets('today\'s slots at or before the injected minute of day are '
        'dropped, and the later ones kept', (tester) async {
      regimens = [
        course(slots: [slot(480), slot(540), slot(600)])
      ];
      await start(tester);

      final todaysMinutes = scheduler.mutations
          .where((c) => c.day == today)
          .map((c) => c.minutesFromMidnight)
          .toList();
      expect(
        todaysMinutes,
        <int>[600],
        reason: 'the clock is pinned at 09:00, so 08:00 is past and 09:00 is '
            'exactly AT now — both dropped, because an instant already in the '
            'past makes the plugin throw rather than degrade. This is only '
            'pinnable because the sync reads the app\'s one injected wall '
            'clock; the fake-async zone controls timers but never '
            'DateTime.now().',
      );
      final tomorrowsMinutes = scheduler.mutations
          .where((c) => c.day == tomorrow)
          .map((c) => c.minutesFromMidnight)
          .toList();
      expect(tomorrowsMinutes, <int>[480, 540, 600]);
    });
  });

  group('the debounce', () {
    testWidgets('three emissions inside the window produce ONE application',
        (tester) async {
      regimens = [
        course(slots: [slot(600)])
      ];
      await start(tester);
      scheduler.calls.clear();

      // Real elapsed time between the emissions, each gap strictly INSIDE the
      // window. Pumping without a duration would advance no clock at all and
      // the test would pass against a zero-length debounce — verified by
      // mutating the delay to Duration.zero and watching this stay green.
      const inside = Duration(milliseconds: 100);
      emit(regimens);
      await tester.pump(inside);
      emit(regimens);
      await tester.pump(inside);
      emit(regimens);
      await tester.pump(inside);

      expect(
        applications(),
        1,
        reason: 'the window has not closed yet, so nothing has been applied '
            'from this burst at all.',
      );

      await settle(tester);

      expect(
        applications(),
        2,
        reason: 'one save writes a regimen and its slots in one transaction, '
            'but the stream can emit more than once — and each application is '
            'dozens of platform round trips and another window in which the '
            'scheduled set is half-updated.',
      );
      expect(scheduler.calls.where((c) => c.method == pendingCall).length, 1);
    });
  });

  group('the six triggers, one at a time', () {
    // One test per trigger rather than one sweep that fires everything and
    // counts once: a combined test cannot tell WHICH trigger broke, and a
    // trigger that silently stopped working is the failure mode this whole plan
    // exists to prevent.
    late Regimen base;

    setUp(() {
      base = course(slots: [slot(600)]);
      regimens = [base];
    });

    /// Fires [trigger] against a settled sync and returns how many applications
    /// it caused.
    Future<int> applicationsFrom(
      WidgetTester tester,
      Future<void> Function() trigger,
    ) async {
      final before = applications();
      await trigger();
      await settle(tester);
      return applications() - before;
    }

    testWidgets('a regimen created', (tester) async {
      await start(tester);
      expect(
        await applicationsFrom(tester, () async {
          emit([base, course(id: 'c2', slots: [slot(700)])]);
        }),
        1,
      );
    });

    testWidgets('a regimen edited', (tester) async {
      await start(tester);
      expect(
        await applicationsFrom(tester, () async {
          emit([course(slots: [slot(660)])]);
        }),
        1,
      );
    });

    testWidgets('a regimen paused', (tester) async {
      await start(tester);
      expect(
        await applicationsFrom(tester, () async {
          emit([course(paused: true, slots: [slot(600)])]);
        }),
        1,
      );
    });

    testWidgets('a regimen deleted — which is also how a deleted SUPPLEMENT '
        'arrives, because the cascade soft-deletes its regimen too',
        (tester) async {
      await start(tester);
      expect(
        await applicationsFrom(tester, () async => emit(const <Regimen>[])),
        1,
      );
    });

    testWidgets('the day rolling over', (tester) async {
      await start(tester);
      expect(
        await applicationsFrom(tester, () async => clock.rollTo(tomorrow)),
        1,
      );
    });

    testWidgets('the app resuming', (tester) async {
      await start(tester);
      expect(
        await applicationsFrom(tester, () async {
          await sendLifecycle(tester, AppLifecycleState.inactive);
          await sendLifecycle(tester, AppLifecycleState.resumed);
        }),
        1,
        reason: 'timers are suspended while the app is backgrounded, so a '
            'resume may arrive days after the last scheduled tick — and it is '
            'the only moment a timezone change made while backgrounded can be '
            'noticed.',
      );
    });

    testWidgets('the language changing — one application AND one channel '
        'refresh', (tester) async {
      // The one case that uses the REAL bootstrap, because the reschedule and
      // the channel rewrite have to move together here.
      await start(tester, realBootstrap: true);
      final channelsBefore =
          scheduler.calls.where((c) => c.method == ensureChannelCall).length;

      final applied = await applicationsFrom(tester, () async {
        container.read(notificationLocaleProvider.notifier).report(en);
      });

      expect(applied, 1);
      expect(
        scheduler.calls.where((c) => c.method == ensureChannelCall).length,
        channelsBefore + 1,
      );
      expect(scheduler.calls.last.method, isNot(ensureChannelCall));
      final refresh =
          scheduler.calls.lastWhere((c) => c.method == ensureChannelCall);
      expect(refresh.name, notificationChannelName(en));
      expect(refresh.description, notificationChannelDescription(en));
      // And the text that is now armed is the NEW language's — the whole point
      // of the trigger, and invisible to an id-only diff.
      expect(
        scheduler.mutations.last.title,
        notificationTitle(en),
      );
    });
  });

  group('a permission answer as a trigger (plan 07-05)', () {
    testWidgets('a grant re-derives the scheduled set with no further user '
        'action', (tester) async {
      regimens = [
        course(slots: [slot(600)])
      ];
      await start(tester);
      final before = applications();

      // The answer arrives — from the ask at the first save, or from a resume
      // after the user switched reminders on in the operating system's own
      // settings. Either way it is a TRIGGER: the sync still makes its own
      // fresh check as the GATE, because permission can be revoked while the
      // app is backgrounded and only a fresh read can see that.
      await container.read(notificationPermissionProvider.notifier).refresh();
      await settle(tester);

      expect(applications(), before + 1,
          reason: 'without this trigger a granted permission would schedule '
              'nothing until the next save, day rollover, resume or language '
              'change — the feature would look broken for as long as the user '
              'left the app alone.');
    });
  });

  group('a resume, and a timezone the user flew into', () {
    setUpAll(() async {
      await initTimeZones(readDeviceZone: () async => kyiv);
    });

    // The local location is PROCESS-global — that is the whole point of the
    // boundary — so a test that changes it leaks into the next one. Pinned back
    // here so these tests are independent of their order.
    setUp(() => setLocalZoneIfChanged(kyiv));

    Future<void> resume(WidgetTester tester) async {
      await sendLifecycle(tester, AppLifecycleState.inactive);
      await sendLifecycle(tester, AppLifecycleState.resumed);
      await settle(tester);
    }

    testWidgets('a zone identifier that has not changed leaves the local '
        'location alone', (tester) async {
      regimens = [
        course(slots: [slot(600)])
      ];
      await start(tester, zoneReader: () async => kyiv);
      await resume(tester);

      expect(localZoneIdentifier, kyiv);
    });

    testWidgets('a zone identifier that HAS changed is set before anything is '
        'applied, and the instants move with it', (tester) async {
      regimens = [
        course(slots: [slot(600)])
      ];
      var zone = kyiv;
      await start(tester, zoneReader: () async => zone);

      // Capture the instant the ADAPTER would build, at the moment the schedule
      // call happens. A test that only asserted the location was set would pass
      // against a sync that then scheduled from a cached conversion.
      final instants = <tz.TZDateTime>[];
      scheduler.onSchedule = (call) => instants.add(
            instantFor(
              day: call.day!,
              minutesFromMidnight: call.minutesFromMidnight!,
            ),
          );

      zone = newYork;
      await resume(tester);

      expect(localZoneIdentifier, newYork);
      expect(instants, isNotEmpty);
      expect(instants.first.location.name, newYork);
      expect(
        instants.first.timeZoneOffset,
        const Duration(hours: -4),
        reason: 'applying a difference against a stale zone would arm every '
            'remaining reminder at the old offset — seven hours out, in this '
            'case.',
      );
    });

    testWidgets('a zone read that throws is reported and absorbed, and the '
        'difference is still applied against the zone already set',
        (tester) async {
      regimens = [
        course(slots: [slot(600)])
      ];
      await start(
        tester,
        zoneReader: () async => throw StateError('no zone'),
      );
      final before = applications();

      await resume(tester);

      expect(tester.takeException(), isA<StateError>());
      expect(applications(), before + 1,
          reason: 'a wrong zone costs correct reminder times; this path may '
              'never be able to fail a resume.');
      expect(localZoneIdentifier, kyiv);
    });

    testWidgets('a day-later resume tops up the far edge of the horizon and '
        'cancels what fell off it', (tester) async {
      // A course long enough to outrun the horizon, so the window genuinely
      // slides rather than merely re-deriving the same set.
      regimens = [
        course(end: today.add(const Duration(days: 40)), slots: [slot(600)])
      ];
      await start(tester, zoneReader: () async => kyiv);

      final firstDay = notificationIdFor(day: today, minutesFromMidnight: 600);
      final newEdge = notificationIdFor(
        day: today.add(const Duration(days: 30)),
        minutesFromMidnight: 600,
      );
      expect(scheduler.mutations.map((c) => c.id), contains(firstDay));
      expect(scheduler.mutations.map((c) => c.id), isNot(contains(newEdge)));

      // What the platform now holds, and then: a day passes with the app shut.
      scheduler.held = scheduler.mutations
          .map((c) => PendingNotification(id: c.id!, title: c.title, body: c.body))
          .toList();
      scheduler.calls.clear();
      clock.rollTo(tomorrow);
      await resume(tester);

      expect(
        scheduler.mutations
            .where((c) => c.method == scheduleOnceCall)
            .map((c) => c.id),
        contains(newEdge),
        reason: 'the horizon is topped up on resume — this is the mechanism '
            'behind the phase\'s one honest limitation, that reminders for '
            'cycling regimens and courses are armed only a limited distance '
            'ahead and depend on the app being opened occasionally.',
      );
      expect(
        scheduler.mutations
            .where((c) => c.method == cancelCall)
            .map((c) => c.id),
        contains(firstDay),
        reason: 'the day that fell out of the window is cancelled by id.',
      );
    });

    testWidgets('a resume after the container is gone is inert, and throws '
        'nothing', (tester) async {
      regimens = [
        course(slots: [slot(600)])
      ];
      await start(tester, zoneReader: () async => kyiv);
      container.dispose();
      scheduler.calls.clear();

      await sendLifecycle(tester, AppLifecycleState.inactive);
      await sendLifecycle(tester, AppLifecycleState.resumed);
      await tester.pump(notificationSyncDebounce);
      await tester.pump();

      expect(scheduler.calls, isEmpty);
      expect(
        tester.takeException(),
        isNull,
        reason: 'a resume arriving after the container is gone reaches a '
            'disposed ref, and reading one throws.',
      );
      // Stated plainly, because it is the limit of what this test proves: it
      // CANNOT distinguish "the listener was disposed" from "the mounted guard
      // held", and both are present. Deleting the disposal leaves this green —
      // verified. The disposal itself is carried by the source gate below.
      //
      // The tearDown disposes the container again; that is idempotent.
    });
  });

  group('source gates — the facts no run of this suite can carry', () {
    String source(String path) => File(path).readAsStringSync();

    test('the sync cannot learn a supplement name', () {
      for (final capability in const [
        'SupplementRepository',
        'stackEntriesProvider',
        'supplementsStreamProvider',
      ]) {
        expect(
          source('lib/core/notifications/notification_sync.dart')
              .contains(capability),
          isFalse,
          reason: 'the sync can reach $capability. A capability that does not '
              'exist cannot leak a health-adjacent name onto a lock screen; '
              'the count-only body is a security control, not a copy choice.',
        );
      }
    });

    test('nothing in the notification layer reads a bare wall clock', () {
      for (final file in Directory('lib/core/notifications')
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))) {
        final stripped = file
            .readAsStringSync()
            .split('\n')
            .where((line) => !line.trimLeft().startsWith('//'))
            .join('\n');
        expect(
          RegExp(r'(^|[^A-Za-z.])DateTime\.now').hasMatch(stripped),
          isFalse,
          reason: '${file.path} reads the wall clock directly. The app has ONE '
              'wall-clock read, injected on TodayController, and the fake clock '
              'in tests controls timers but never DateTime.now() — a bare read '
              'makes the "a slot exactly at now" boundary unpinnable. The '
              'pattern deliberately spares the timezone package\'s own '
              'TZDateTime.now, which the adapter legitimately uses for its '
              'past-instant guard.',
        );
      }
    });

    test('there is ONE lifecycle listener, and the disposal callback disposes '
        'it', () {
      final sync = source('lib/core/notifications/notification_sync.dart');
      // CONSTRUCTIONS, not occurrences: the nullable field declaration names
      // the type too, so the plan's "exactly one occurrence" criterion cannot
      // hold for any listener that is held in order to be disposed —
      // `today_controller.dart` has the same two.
      expect(
        RegExp(r'AppLifecycleListener\(').allMatches(sync).length,
        1,
        reason: 'a second listener would be a second opinion about what a '
            'resume means.',
      );
      final onDispose = sync.substring(
        sync.indexOf('ref.onDispose('),
        sync.indexOf('});', sync.indexOf('ref.onDispose(')),
      );
      expect(
        onDispose.contains('_lifecycle?.dispose()'),
        isTrue,
        reason: 'this is a SOURCE gate on purpose. No behavioural test in this '
            'file can carry the claim: `_onResume` returns immediately on an '
            'unmounted ref, so a leaked listener is indistinguishable from a '
            'disposed one from the outside. Deleting the disposal was tried and '
            'left the whole file green.',
      );
    });

    test('the root app widget keeps the sync alive', () {
      final stripped = source('lib/main.dart')
          .split('\n')
          .where((line) => !line.trimLeft().startsWith('//'))
          .join('\n')
          .replaceAll(RegExp(r'\s+'), '');
      expect(
        stripped.contains('ref.watch(notificationSyncProvider)'),
        isTrue,
        reason: 'an unlistened provider is PAUSED in this version of Riverpod, '
            'so without this watch the sync\'s trigger listeners are never '
            'registered and production silently schedules nothing — with every '
            'test in this file still green, because they hold it open '
            'themselves.',
      );
    });
  });

  group('an application already in flight (the dropped-edit race)', () {
    // Reported from a real device: set a dose to 08:00, edit it to 09:00, save
    // — the app shows 09:00 everywhere afterwards, but the phone keeps firing
    // at 08:00. Every layer beneath this one was verified correct while chasing
    // it: the repository updates the slot in place, a live `watchDay`
    // subscriber re-emits the new time, and `reconcile` cancels an id it no
    // longer wants. What was wrong was above them — the application carrying
    // the edit was never run.
    //
    // The window only exists when the seam takes time to answer, which on a
    // device it always does (every call is a platform round-trip) and in a host
    // test it never does. That is why the whole phase shipped green.
    testWidgets('an edit that lands during one is applied, not dropped',
        (tester) async {
      regimens = [
        daily(slots: [slot(480)])
      ];
      await start(tester);

      final oldId = notificationIdFor(day: null, minutesFromMidnight: 480);
      final newId = notificationIdFor(day: null, minutesFromMidnight: 540);
      expect(
        scheduler.calls
            .where((c) => c.method == scheduleDailyCall)
            .map((c) => c.id),
        contains(oldId),
        reason: 'precondition: the 08:00 repeat is armed',
      );

      // The operating system is now holding it, which is what makes the stale
      // reminder cancellable at all.
      scheduler.held = [
        PendingNotification(
          id: oldId,
          title: notificationTitle(uk),
          body: notificationBody(
              locale: uk, doseCount: 1, minutesFromMidnight: 480),
          payload: doseTapPayload,
        ),
      ];
      scheduler.calls.clear();

      // A routine trigger — a resume, a permission refresh, a midnight roll —
      // starts an application, which parks on the platform.
      scheduler.pendingGate = Completer<void>();
      emit(regimens);
      await settle(tester);

      // WHILE it is parked, the user saves 08:00 -> 09:00. That application
      // reads its regimens at its own start, so the parked one cannot carry
      // this edit.
      regimens = [
        daily(slots: [slot(540)])
      ];
      emit(regimens);
      await settle(tester);

      // The platform answers.
      scheduler.pendingGate!.complete();
      scheduler.pendingGate = null;
      await settle(tester);
      await settle(tester);

      expect(
        scheduler.calls
            .where((c) => c.method == scheduleDailyCall)
            .map((c) => c.id),
        contains(newId),
        reason: 'the 09:00 reminder the user actually asked for must be armed; '
            'without coalescing, the edit\'s application is discarded on the '
            'in-flight check and never retried, so this is empty',
      );
      expect(
        scheduler.calls.where((c) => c.method == cancelCall).map((c) => c.id),
        contains(oldId),
        reason: 'and the 08:00 one the user moved away from must be gone — it '
            'is the one that keeps firing on the phone while every screen in '
            'the app shows 09:00',
      );
    });

    testWidgets('a burst during one application costs ONE re-derivation',
        (tester) async {
      regimens = [
        daily(slots: [slot(480)])
      ];
      await start(tester);
      final before = applications();

      scheduler.pendingGate = Completer<void>();
      emit(regimens);
      await settle(tester);

      // Five more triggers arrive while the first is parked.
      for (var i = 0; i < 5; i++) {
        emit(regimens);
        await settle(tester);
      }

      scheduler.pendingGate!.complete();
      scheduler.pendingGate = null;
      await settle(tester);
      await settle(tester);

      // The parked one, plus exactly one coalesced re-derivation for the five.
      expect(applications() - before, 2,
          reason: 'one remembered request is enough however many triggers '
              'arrive: the re-run reads current state and reconciles against '
              'what the platform holds, so it repairs all of them at once');
    });
  });
}
