/// A [NotificationScheduler] that records exactly what it was asked to do and
/// touches no plugin.
///
/// Shared by the copy/locale wiring tests and the sync tests, which assert
/// against the SAME recorder — a test that counted calls would pass while the
/// wrong notification was scheduled, so every call is recorded with its
/// arguments and the assertions compare those.
///
/// `notification_bootstrap_test.dart` carries its own smaller recorder from plan
/// 07-01. It is deliberately left alone: it is the gate file for the FLAG-3
/// window, and editing a gate to reuse a helper is how a gate stops being one.
library;

import 'dart:async';

import 'package:boostque/core/notifications/notification_scheduler.dart';

/// One call the seam received, flattened to the fields a test asserts on.
class SchedulerCall {
  SchedulerCall({
    required this.method,
    this.id,
    this.day,
    this.minutesFromMidnight,
    this.title,
    this.body,
    this.name,
    this.description,
  });

  /// Which seam method was called.
  final String method;

  /// The notification id, for the three calls that carry one.
  final int? id;

  /// The calendar day, for a one-shot only.
  final DateTime? day;

  /// The wall-clock minute, for the two scheduling calls.
  final int? minutesFromMidnight;

  /// The rendered title handed to the platform.
  final String? title;

  /// The rendered body handed to the platform.
  final String? body;

  /// The channel name, for a channel call.
  final String? name;

  /// The channel description, for a channel call.
  final String? description;
}

/// Method names, so a test never spells one as a bare literal twice.
const scheduleOnceCall = 'scheduleOnce';
const scheduleDailyCall = 'scheduleDaily';
const cancelCall = 'cancel';
const pendingCall = 'pending';
const ensureChannelCall = 'ensureChannel';
const initializeCall = 'initialize';
const isEnabledCall = 'isEnabled';
const requestPermissionCall = 'requestPermission';
const openSystemSettingsCall = 'openSystemSettings';

class RecordingScheduler extends NotificationScheduler {
  RecordingScheduler({this.enabled = true});

  /// The answer [isEnabled] gives. `null` is the third real state — a platform
  /// that cannot say, which every not-permitted assertion covers alongside
  /// `false`.
  bool? enabled;

  /// What the platform is currently holding. A test sets this to drive
  /// reconciliation against a non-empty pending set.
  List<PendingNotification> held = const <PendingNotification>[];

  /// Every call, in order.
  final List<SchedulerCall> calls = <SchedulerCall>[];

  /// When set, [pending] parks on it, holding one application in flight for as
  /// long as the test wants. The seam's other calls answer instantly in a host
  /// test, so without this the in-flight window has zero width and the
  /// coalescing behaviour around it cannot be observed at all.
  Completer<void>? pendingGate;

  /// Run after a [scheduleOnce] or [scheduleDaily] is recorded, so a test can
  /// capture what the SERVICE would have derived at that exact moment (the
  /// instant, in the zone current when the call happened).
  void Function(SchedulerCall call)? onSchedule;

  /// What [requestPermission] throws instead of answering, when set.
  ///
  /// The permission request is the one seam call that genuinely does throw in
  /// the wild — an app running where no notification plugin is registered dies
  /// on a `LateInitializationError` rather than no-opping (07-RESEARCH C-3).
  Object? requestFailure;

  /// Run at the moment [requestPermission] is recorded, so a test can observe
  /// what the rest of the app looked like AT that moment — which is the only
  /// way to assert that the editor route had already left the screen.
  void Function()? onRequestPermission;

  /// Ids this recorder silently skips, exactly as the real adapter skips an
  /// instant that has already passed: it returns normally and schedules
  /// nothing, rather than throwing.
  Set<int> skipIds = const <int>{};

  /// The calls that changed what the platform holds.
  List<SchedulerCall> get mutations => calls
      .where((c) =>
          c.method == scheduleOnceCall ||
          c.method == scheduleDailyCall ||
          c.method == cancelCall)
      .toList(growable: false);

  @override
  Future<void> initialize({
    required void Function(String? payload) onTap,
  }) async {
    calls.add(SchedulerCall(method: initializeCall));
  }

  @override
  Future<void> ensureChannel({
    required String name,
    required String description,
  }) async {
    calls.add(SchedulerCall(
      method: ensureChannelCall,
      name: name,
      description: description,
    ));
  }

  @override
  Future<List<PendingNotification>> pending() async {
    calls.add(SchedulerCall(method: pendingCall));
    // Parks the application here when a test has armed the gate, recreating the
    // only thing a host test otherwise cannot have: a platform that takes real
    // time to answer. Null by default, so every existing test is unaffected.
    final gate = pendingGate;
    if (gate != null) await gate.future;
    return held;
  }

  @override
  Future<void> scheduleOnce({
    required int id,
    required DateTime day,
    required int minutesFromMidnight,
    required String title,
    required String body,
  }) async {
    if (skipIds.contains(id)) return;
    final call = SchedulerCall(
      method: scheduleOnceCall,
      id: id,
      day: day,
      minutesFromMidnight: minutesFromMidnight,
      title: title,
      body: body,
    );
    calls.add(call);
    onSchedule?.call(call);
  }

  @override
  Future<void> scheduleDaily({
    required int id,
    required int minutesFromMidnight,
    required String title,
    required String body,
  }) async {
    if (skipIds.contains(id)) return;
    final call = SchedulerCall(
      method: scheduleDailyCall,
      id: id,
      minutesFromMidnight: minutesFromMidnight,
      title: title,
      body: body,
    );
    calls.add(call);
    onSchedule?.call(call);
  }

  @override
  Future<void> cancel({required int id}) async {
    calls.add(SchedulerCall(method: cancelCall, id: id));
  }

  @override
  Future<bool?> requestPermission() async {
    calls.add(SchedulerCall(method: requestPermissionCall));
    onRequestPermission?.call();
    final failure = requestFailure;
    if (failure != null) throw failure;
    return enabled;
  }

  @override
  Future<bool?> isEnabled() async {
    calls.add(SchedulerCall(method: isEnabledCall));
    return enabled;
  }

  @override
  Future<void> openSystemSettings() async {
    calls.add(SchedulerCall(method: openSystemSettingsCall));
  }

  @override
  Future<String?> launchPayload() async => null;
}
