/// The ONLY file in this project that imports `flutter_local_notifications`.
///
/// That quarantine is not a style preference. Under `flutter test` the plugin's
/// platform instance is a `static late` field with no default value and
/// `defaultTargetPlatform` is forced to android, so EVERY plugin call path throws
/// a `LateInitializationError` — not a `MissingPluginException`, not a silent
/// no-op. The plugin's own README claims the methods "will be mostly no-op" in a
/// host test; research ran it and they do not (07-RESEARCH §9.3, correction C-3).
/// Any widget tree that reaches un-seamed plugin code dies with an obscure error
/// naming an obfuscated field, which is why `NotificationScheduler` is a
/// first-commit requirement and not a later refactor.
///
/// Every signature this file calls is quoted in 07-RESEARCH §5 from the shipped
/// 22.3.0 archive. In 22.3.0 every parameter of `zonedSchedule` and `initialize`
/// is NAMED and `androidScheduleMode` has no default; the plugin's README still
/// ships a snippet mixing positional and named arguments that does not compile.
/// Do not write this from memory.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import 'package:vitomy/core/notifications/notification_constants.dart';
import 'package:vitomy/core/notifications/notification_scheduler.dart';
import 'package:vitomy/core/notifications/tz_conversion.dart';

/// The Android status-bar icon.
///
/// The only icon this project has. Android renders the status-bar icon as a
/// MONOCHROME SILHOUETTE, so a full-colour launcher icon becomes a white blob —
/// accepted for v1.1 because the app icon itself is still the Flutter default and
/// the bundle id is still a placeholder. A dedicated white-on-transparent 24dp
/// drawable joins the SAME pre-release checklist as the app name, the bundle id
/// and the app icon (DECIDED-18). The value must match the resources actually on
/// disk under `android/app/src/main/res/mipmap-*`, which is why it is a named
/// literal in the string gate's allowlist rather than free text.
const _androidSmallIcon = '@mipmap/ic_launcher';

/// The plugin-backed [NotificationScheduler]. Installed only by `main()`.
class PluginNotificationScheduler extends NotificationScheduler {
  PluginNotificationScheduler({FlutterLocalNotificationsPlugin? plugin})
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

  /// The channel copy the app last created the channel with.
  ///
  /// Held so the per-call notification details carry the SAME name the channel
  /// was created with and can never disagree with it. Research's suggested shared
  /// `const` details object cannot ship at all once the name is ARB copy: it
  /// would hardcode the name, trip the string gate, and let the two drift (U-2).
  String? _channelName;
  String? _channelDescription;

  @override
  Future<void> initialize({
    required void Function(String? payload) onTap,
  }) async {
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings(_androidSmallIcon),
        iOS: DarwinInitializationSettings(
          // The single highest-consequence defaults in this whole API. Each of
          // the three defaults to TRUE, and any one left alone fires the
          // one-and-only iOS system prompt at initialize() — that is, at launch
          // — which violates "asked at first regimen save, never at launch"
          // silently, with no second chance on that device ever (Pitfall 1).
          requestAlertPermission: false,
          requestSoundPermission: false,
          requestBadgePermission: false,
          // The five defaultPresent* flags in this same constructor keep their
          // true defaults DELIBERATELY, and they mean the opposite thing: a
          // reminder that fires while the app is open should still appear, and
          // the notification is also the record in the system's own list
          // (DECIDED-20). The two groups sit side by side; that adjacency is why
          // the flags above are also asserted by a source gate.
        ),
      ),
      onDidReceiveNotificationResponse: (response) => onTap(response.payload),
      // onDidReceiveBackgroundNotificationResponse is deliberately absent: it
      // exists for the background/action isolate, this app defines no
      // notification action buttons, and "tapping opens Сьогодні" is a
      // foreground concern.
    );
  }

  @override
  Future<void> ensureChannel({
    required String name,
    required String description,
  }) async {
    _channelName = name;
    _channelDescription = description;
    await _android?.createNotificationChannel(
      AndroidNotificationChannel(
        doseChannelId,
        name,
        description: description,
        importance: Importance.high,
      ),
    );
  }

  @override
  Future<List<PendingNotification>> pending() async {
    final requests = await _plugin.pendingNotificationRequests();
    return requests
        .map(
          (request) => PendingNotification(
            id: request.id,
            title: request.title,
            body: request.body,
            payload: request.payload,
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<void> scheduleOnce({
    required int id,
    required DateTime day,
    required int minutesFromMidnight,
    required String title,
    required String body,
  }) async {
    final instant = instantFor(day: day, minutesFromMidnight: minutesFromMidnight);
    // The plugin throws an ArgumentError for a past instant on exactly this
    // path, and there is a real race between planning and scheduling: today's
    // 09:00 slot is already past by the time a 09:05 resume syncs (Pitfall 4).
    if (!instant.isAfter(tz.TZDateTime.now(tz.local))) return;
    await _guarded(
      ErrorDescription('scheduling a one-shot dose reminder'),
      () => _plugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        payload: doseTapPayload,
        scheduledDate: instant,
        notificationDetails: _details(),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        // matchDateTimeComponents deliberately OMITTED: this is the shape a
        // course must never lose, and the plugin only writes the field when the
        // argument is non-null, so its absence is structural.
      ),
    );
  }

  @override
  Future<void> scheduleDaily({
    required int id,
    required int minutesFromMidnight,
    required String title,
    required String body,
  }) async {
    final first = nextDailyOccurrence(
      minutesFromMidnight: minutesFromMidnight,
      now: tz.TZDateTime.now(tz.local),
    );
    await _guarded(
      ErrorDescription('scheduling a repeating dose reminder'),
      () => _plugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        payload: doseTapPayload,
        scheduledDate: first,
        notificationDetails: _details(),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      ),
    );
  }

  @override
  Future<void> cancel({required int id}) => _plugin.cancel(id: id);

  @override
  Future<bool?> requestPermission() async {
    final android = _android;
    if (android != null) return android.requestNotificationsPermission();
    // Badge is not asked for, consistently with requestBadgePermission: false —
    // the app has no unread concept and a badge that only clears when the app is
    // opened is a persistent nagging surface.
    //
    // Never touched, and named here so nobody adds them: this class also carries
    // requestExactAlarmsPermission and requestFullScreenIntentPermission, and
    // both are Play-policy landmines for this app.
    return _darwin?.requestPermissions(alert: true, sound: true);
  }

  @override
  Future<bool?> isEnabled() async {
    final android = _android;
    if (android != null) return android.areNotificationsEnabled();
    return (await _darwin?.checkPermissions())?.isEnabled;
  }

  @override
  Future<void> openSystemSettings() async {
    final android = _android;
    if (android != null) {
      await android.openAppNotificationSettings();
      return;
    }
    await _darwin?.openAppNotificationSettings();
  }

  @override
  Future<String?> launchPayload() async {
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details == null || !details.didNotificationLaunchApp) return null;
    return details.notificationResponse?.payload;
  }

  /// Resolved with `?.` at every use because the resolution returns null
  /// off-platform.
  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  IOSFlutterLocalNotificationsPlugin? get _darwin =>
      _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();

  /// The platform details, built PER CALL.
  ///
  /// Visibility is set on every one because `AndroidNotificationChannel` has no
  /// visibility parameter at all, so a "set it once on the channel" shortcut
  /// produces PUBLIC lock-screen content (correction C-1).
  ///
  /// Honest about what it does and does not do: it ASKS the platform to conceal
  /// content on a secure lock screen, and whether it actually does depends on a
  /// user setting whose default is to show everything. **The count-only text is
  /// the actual privacy control**, on both platforms, and on iOS it is the only
  /// one — the plugin exposes no redaction placeholder. That is why a body
  /// carrying a number instead of a supplement name is a security control and not
  /// a copy preference.
  ///
  /// Nothing else is set: no accent colour, no badge number, no group key, no
  /// thread identifier, no interruption level. Each is a decided absence with a
  /// stated reason in the UI contract (DECIDED-18), and the point of writing them
  /// down was to stop them being added defensively.
  NotificationDetails _details() => NotificationDetails(
        android: AndroidNotificationDetails(
          doseChannelId,
          // The channel copy the app itself created. When the channel has not
          // been created yet the id stands in: the details' channelAction stays
          // at createIfNotExists, so an existing channel's real name is never
          // overwritten by this path anyway.
          _channelName ?? doseChannelId,
          channelDescription: _channelDescription,
          importance: Importance.high,
          visibility: NotificationVisibility.private,
          category: AndroidNotificationCategory.reminder,
        ),
        iOS: const DarwinNotificationDetails(),
      );

  /// Runs [call], reporting and absorbing anything it throws.
  ///
  /// One rejected instant must not abort a whole batch, and no scheduling failure
  /// is ever surfaced to the user: there is nothing they could do, and the app
  /// works (the `main.dart` failure stance, CR-02).
  ///
  /// [what] arrives already wrapped in an `ErrorDescription` rather than as a
  /// bare string, so the crash-report text sits in the position the string gate's
  /// diagnostic-message category actually names — the alternative was a new
  /// allowlist entry for a category that already exists.
  Future<void> _guarded(
    ErrorDescription what,
    Future<void> Function() call,
  ) async {
    try {
      await call();
    } catch (error, stack) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stack,
          library: 'vitomy',
          context: what,
        ),
      );
    }
  }
}
