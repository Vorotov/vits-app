/// Re-deriving the scheduled set whenever the things it depends on change
/// (NOTIF-04, and NOTIF-03's silent half).
///
/// Every platform call the app makes comes from here, and every one of them
/// comes out of `reconcile` — nothing in this file schedules or cancels outside
/// its result. The pure plan decides WHICH reminders should exist; this decides
/// WHEN to ask, and applies the difference.
///
/// **This file cannot learn a supplement name either.** It reads the regimens
/// stream, never the supplement repository and never the paired-stack provider,
/// so the count-only body is enforced by an absent capability rather than by
/// review (07-UI-SPEC § 2).
library;

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:boostque/core/domain/models.dart';
import 'package:boostque/core/notifications/notification_constants.dart';
import 'package:boostque/core/notifications/notification_copy.dart';
import 'package:boostque/core/notifications/notification_locale.dart';
import 'package:boostque/core/notifications/notification_plan.dart';
import 'package:boostque/core/notifications/notification_providers.dart';
import 'package:boostque/core/notifications/tz_conversion.dart';
import 'package:boostque/core/providers.dart';
import 'package:boostque/core/today_controller.dart';

/// How long a burst of triggers is collapsed into one application.
///
/// The editor writes a regimen and its slots in ONE transaction, but the stream
/// underneath can emit more than once — and each application is dozens of
/// platform round trips plus another window in which the scheduled set is
/// half-updated. Long enough to swallow a save's fan-out, short enough that a
/// user cannot perceive it.
const notificationSyncDebounce = Duration(milliseconds: 300);

/// Watches every trigger, debounces, and applies one reconciled difference.
///
/// Its state is a COUNT of completed applications rather than nothing at all,
/// so a test can observe progress by listening and polling instead of by
/// sleeping — an unlistened provider is paused in this version of Riverpod, and
/// a test that merely builds a container would observe nothing.
class NotificationSync extends Notifier<int> {
  Timer? _debounce;
  AppLifecycleListener? _lifecycle;
  bool _inFlight = false;
  int _applications = 0;

  @override
  int build() {
    ref.onDispose(() {
      _debounce?.cancel();
      _debounce = null;
      _lifecycle?.dispose();
      _lifecycle = null;
    });

    // The sixth trigger, and the one that cannot arrive through the provider
    // graph. `TodayController` carries the same listener for the same reason,
    // recorded there: timers are suspended while the app is backgrounded, so a
    // resume may arrive days after the last scheduled tick.
    _lifecycle = AppLifecycleListener(onResume: () => unawaited(_onResume()));

    // LISTENED, not watched, and the difference is load-bearing: watching would
    // re-run this build on every trigger, and `ref.onDispose` fires on a
    // recompute as well as on a disposal — so the debounce timer would be torn
    // down and rebuilt on every emission, and the application count would have
    // to survive a rebuild to mean anything.
    //
    // These four cover every trigger but one. A regimen created, edited,
    // paused, resumed or deleted all reach the regimens stream, because the
    // supplement delete cascade soft-deletes the regimen too. The day rolling
    // over reaches the calendar clock. A language change reaches the resolved
    // locale — a trigger the approved spec's own list omits, and without which
    // a user who switches language keeps the old language's reminders for as
    // long as the horizon, silently. The bootstrap flag is here because it is
    // the precondition: the first application must happen when it flips, not
    // before. Resume is the sixth, and it arrives through the lifecycle
    // listener rather than through the graph.
    ref.listen(notificationBootstrapProvider, (_, _) => _request());
    ref.listen(regimensStreamProvider, (_, _) => _request());
    ref.listen(todayProvider, (_, _) => _request());
    ref.listen(notificationLocaleProvider, (_, _) => _request());

    _request();
    return _applications;
  }

  /// Re-resolves the device's zone, then asks for an application — always.
  ///
  /// **The zone first, because the instants are built from the local location.**
  /// Applying a difference against a stale zone would arm every remaining
  /// reminder at the old offset, which is precisely what a user who has just
  /// flown somewhere would notice.
  ///
  /// A read that throws is reported and absorbed, and the zone already set is
  /// kept: a wrong zone costs correct reminder times, and this path may never
  /// be able to fail a resume.
  ///
  /// **This is also what tops up the horizon**, and therefore the mechanism
  /// behind the phase's one honest limitation: reminders for cycling regimens
  /// and courses are armed only a limited distance ahead, so they depend on the
  /// app being opened occasionally — roughly a week of silence for a typical
  /// cycling stack before they lapse. That limitation is deliberately NOT
  /// surfaced anywhere in this milestone, and **no tail reminder announces it**.
  /// A tail reminder would convert a silent degradation into a scheduled
  /// interruption whose only call to action is "open the app", aimed precisely
  /// at the users who have stopped opening it — and it would post a non-dose
  /// message on a channel whose own description promises dose reminders. It is
  /// recorded here, beside the code that causes the limitation, so nobody
  /// re-litigates it as a small addition.
  Future<void> _onResume() async {
    if (!ref.mounted) return;
    final readZone = ref.read(deviceZoneReaderProvider);
    if (readZone != null) {
      try {
        setLocalZoneIfChanged(await readZone());
      } catch (error, stack) {
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: error,
            stack: stack,
            library: 'boostque',
            context: ErrorDescription('re-resolving the device time zone'),
          ),
        );
      }
    }
    if (!ref.mounted) return;
    _request();
  }

  /// Asks for an application, at the end of the debounce window.
  void _request() {
    _debounce?.cancel();
    _debounce = Timer(notificationSyncDebounce, _apply);
  }

  /// Builds the plan, renders it, reconciles it against what the platform is
  /// holding, and applies the difference.
  Future<void> _apply() async {
    if (!ref.mounted || _inFlight) return;

    // The precondition, read as a VALUE. Nothing may be scheduled before the
    // timezone database is loaded: before setLocalLocation runs, a zoned value
    // comes out as UTC silently and every reminder is off by the device offset.
    // A flag read is a precondition a reader can see, where an ordering comment
    // is a promise a refactor can break.
    if (!ref.read(notificationBootstrapProvider)) return;

    final locale = ref.read(notificationLocaleProvider);
    if (locale == null) return;

    final List<Regimen> regimens;
    switch (ref.read(regimensStreamProvider)) {
      case AsyncData(value: final data):
        regimens = data;
      case _:
        return;
    }

    _inFlight = true;
    try {
      final scheduler = ref.read(notificationSchedulerProvider);
      // The single gate that makes a denied permission SILENT rather than a
      // stream of failing platform calls. Not "try and swallow the failures":
      // that is dozens of failures per trigger and a log full of noise, for an
      // app that is meant to look identical either way.
      if (await scheduler.isEnabled() != true) return;
      if (!ref.mounted) return;

      // Both the day and the minute come from the app's ONE calendar clock.
      // The minute is derived from the same injectable wall-clock function
      // `TodayController` holds, never from a bare `DateTime.now()`, for two
      // concrete reasons. First, that controller's own doc calls it "the ONE
      // wall-clock read in the app", and this codebase treats its doc comments
      // as load-bearing. Second, the test harness's fake clock controls timers
      // but never `DateTime.now()` — with a bare read, the tested boundary
      // "today's slots at or before now are dropped" becomes unpinnable from
      // this file's own tests and the "a slot exactly at now" case goes back to
      // being a race.
      //
      // Deliberately NOT the calendar tab's minute ticker: it lives in a
      // feature `core` may not import, it is autoDispose, and it re-emits every
      // sixty seconds — watching it would turn this into a once-a-minute
      // rescheduler.
      final day = ref.read(todayProvider);
      final wall = ref.read(todayProvider.notifier).now();
      final planned = planNotifications(
        regimens: regimens,
        today: day,
        nowMinutesFromMidnight: wall.hour * 60 + wall.minute,
        horizonDays: notificationHorizonDays,
        budget: notificationBudget,
      );

      final title = notificationTitle(locale);
      final desired = <DesiredNotification>[
        for (final entry in planned)
          DesiredNotification(
            notification: entry,
            title: title,
            body: notificationBody(
              locale: locale,
              doseCount: entry.doseCount,
              minutesFromMidnight: entry.minutesFromMidnight,
            ),
          ),
      ];

      final difference = reconcile(
        desired: desired,
        pending: await scheduler.pending(),
      );
      if (!ref.mounted) return;

      // Cancel BEFORE schedule, so a re-issued id is never momentarily
      // registered twice. `reconcile` deliberately encodes no ordering because
      // it is the caller's decision; this is the caller making it.
      for (final id in difference.toCancel) {
        await scheduler.cancel(id: id);
      }
      for (final entry in difference.toSchedule) {
        final notification = entry.notification;
        // The scheduling SHAPE comes from the planned entry's own tier. A
        // repeat and a one-shot are separate methods on the seam precisely so
        // that "a course must never repeat" is structurally true rather than
        // dependent on a conditional argument at a call site.
        if (notification.repeatsDaily) {
          await scheduler.scheduleDaily(
            id: notification.id,
            minutesFromMidnight: notification.minutesFromMidnight,
            title: entry.title,
            body: entry.body,
          );
        } else {
          await scheduler.scheduleOnce(
            id: notification.id,
            day: notification.day!,
            minutesFromMidnight: notification.minutesFromMidnight,
            title: entry.title,
            body: entry.body,
          );
        }
      }

      _applications++;
      if (ref.mounted) state = _applications;
    } catch (error, stack) {
      // One failing application may not kill the controller: the next trigger
      // re-derives from what the platform actually holds, and `reconcile` is
      // self-correcting, so an interrupted application repairs itself with no
      // persisted "we were in the middle of something" flag. Reported to the
      // crash logger and never to the user — the failure stance the whole app
      // takes for reminders (CR-02).
      //
      // Per-CALL absorption is deliberately NOT duplicated here: the seam owns
      // it, and a past instant is skipped there rather than thrown.
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stack,
          library: 'boostque',
          context: ErrorDescription('applying the dose-reminder difference'),
        ),
      );
    } finally {
      _inFlight = false;
    }
  }
}

/// App-lifetime (D-23): the triggers arrive whenever the app is alive, and the
/// root app widget watches this so its listeners are registered at all — an
/// unlistened provider is paused.
final notificationSyncProvider =
    NotifierProvider<NotificationSync, int>(NotificationSync.new);
