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
import 'package:boostque/core/notifications/notification_copy.dart';
import 'package:boostque/core/notifications/notification_locale.dart';
import 'package:boostque/core/notifications/notification_plan.dart';
import 'package:boostque/core/notifications/notification_providers.dart';
import 'package:boostque/core/notifications/notification_scheduler.dart';
import 'package:boostque/core/notifications/notification_sync.dart';
import 'package:boostque/core/providers.dart';
import 'package:boostque/core/today_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'recording_scheduler.dart';

/// The day every fixture below is anchored on, and the wall clock it is read
/// with — 09:00, so a 09:00 slot is exactly AT now and a 10:00 slot is after it.
final today = DateTime.utc(2026, 8, 17);
final tomorrow = DateTime.utc(2026, 8, 18);
DateTime wallClock = DateTime(2026, 8, 17, 9);

const uk = Locale('uk');
const en = Locale('en');

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
  }) async {
    container = build(ready: ready, realBootstrap: realBootstrap);
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

    test('no blanket clear exists anywhere in the app', () {
      for (final file in Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))) {
        expect(
          file.readAsStringSync().contains('cancelAll'),
          isFalse,
          reason: '${file.path}: a blanket clear also dismisses reminders that '
              'were delivered and not yet acted on, and leaves a window in '
              'which nothing at all is scheduled.',
        );
      }
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
}
