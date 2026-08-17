/// The seam between the app and the operating system's scheduler.
///
/// The FOURTH interface in this codebase that exists so the layer above it can be
/// tested without the thing below it — the three repository interfaces
/// (`SupplementRepository`/`RegimenRepository`/`IntakeRepository`) are its model,
/// in shape and in spirit.
///
/// Here the seam is not a preference, it is a requirement. Under `flutter test`
/// the plugin's platform instance is a `static late` field with NO default and
/// `defaultTargetPlatform` is forced to android, so every plugin call path throws
/// a `LateInitializationError` rather than no-opping — the plugin's own README
/// says the opposite and research ran it (07-RESEARCH §9.3, correction C-3). Any
/// widget tree that reaches un-seamed plugin code dies with an obscure error
/// naming an obfuscated field.
///
/// Two shaping decisions, written down because both are load-bearing:
///
/// 1. **One-shot and daily are separate methods, not one method with a flag.**
///    "A course must never repeat" is then structurally true at the boundary
///    instead of depending on a conditional argument nobody can see at the call
///    site.
/// 2. **The seam speaks WALL CLOCK** — a date-only day plus a minute of day —
///    and never a zoned value. So no test that mocks it needs the timezone
///    database loaded, and the conversion stays in the single tested place that
///    owns it (`tz_conversion.dart`).
///
/// Some members have no production caller until a later plan. They are declared
/// here anyway: the interface IS the architecture, and adding to it later is how
/// the tracer would stop being one.
library;

/// A reminder the platform is currently holding on the app's behalf.
///
/// The seam's own value type rather than the plugin's, so nothing above this file
/// has to import the plugin to read a pending list. It carries the same four
/// fields the platform hands back — and, notably, NO scheduled time, which is
/// exactly why the fire time has to be folded into the id
/// (`notificationIdFor`).
///
/// The title and body are readable, which is what makes a stale-copy reconcile
/// possible after a language change (DECIDED-16 resolution (a)).
class PendingNotification {
  /// The notification's id, as the app derived it.
  final int id;

  /// The title the platform is holding, in whatever locale it was scheduled in.
  final String? title;

  /// The body the platform is holding.
  final String? body;

  /// The routing payload.
  final String? payload;

  const PendingNotification({
    required this.id,
    this.title,
    this.body,
    this.payload,
  });
}

/// Everything the app asks of the operating system's notification scheduler.
abstract class NotificationScheduler {
  const NotificationScheduler();

  /// Prepares the platform side and registers the tap handler.
  ///
  /// [onTap] receives the raw payload, which is UNTRUSTED — the operating system
  /// persists it across app updates and can replay one an older build wrote.
  /// Validation belongs to the caller, by equality against the one known token.
  Future<void> initialize({required void Function(String? payload) onTap});

  /// Creates or UPDATES the Android channel's user-visible copy.
  ///
  /// Both strings are ARB copy the operating system renders in its own settings,
  /// so they arrive already localized. Safe and intended to repeat: Android
  /// updates the name and description of an existing channel id, which is what
  /// makes a locale change reach the channel without re-versioning its id
  /// (DECIDED-14).
  Future<void> ensureChannel({
    required String name,
    required String description,
  });

  /// Everything the platform is currently holding for this app.
  Future<List<PendingNotification>> pending();

  /// Arms ONE reminder, on [day] at [minutesFromMidnight]. Never repeats.
  Future<void> scheduleOnce({
    required int id,
    required DateTime day,
    required int minutesFromMidnight,
    required String title,
    required String body,
  });

  /// Arms a reminder that repeats every day at [minutesFromMidnight].
  Future<void> scheduleDaily({
    required int id,
    required int minutesFromMidnight,
    required String title,
    required String body,
  });

  /// Cancels one reminder by id. There is deliberately no cancel-everything:
  /// that also dismisses delivered-but-unacted reminders and leaves a window
  /// with nothing scheduled.
  Future<void> cancel({required int id});

  /// Asks the platform for permission to post notifications.
  ///
  /// Nullable because the plugin's own methods are, and the third state is real:
  /// the platform answers null off-platform, and NEITHER platform can
  /// distinguish "denied" from "never asked" (07-RESEARCH §6.1, §6.2).
  Future<bool?> requestPermission();

  /// Whether the app can post notifications right now. Nullable for the same
  /// reason as [requestPermission].
  Future<bool?> isEnabled();

  /// Opens the operating system's own notification settings for this app — the
  /// only route back on iOS after a denial, and after a double denial on
  /// Android.
  Future<void> openSystemSettings();

  /// The payload of the notification that launched the app, when one did.
  ///
  /// A separate read because the tap callback registered by [initialize] is
  /// documented as unable to handle the launch case.
  Future<String?> launchPayload();
}

/// A scheduler that does nothing, and is the DEFAULT.
///
/// This is what makes it impossible for a widget test to reach the plugin by
/// accident — see the library doc on why that matters. Both permission answers
/// are `null`, never `false`: a `false` would make a settings row claim, in every
/// widget test, that reminders are blocked.
class NoopNotificationScheduler extends NotificationScheduler {
  const NoopNotificationScheduler();

  @override
  Future<void> initialize({
    required void Function(String? payload) onTap,
  }) async {}

  @override
  Future<void> ensureChannel({
    required String name,
    required String description,
  }) async {}

  @override
  Future<List<PendingNotification>> pending() async =>
      const <PendingNotification>[];

  @override
  Future<void> scheduleOnce({
    required int id,
    required DateTime day,
    required int minutesFromMidnight,
    required String title,
    required String body,
  }) async {}

  @override
  Future<void> scheduleDaily({
    required int id,
    required int minutesFromMidnight,
    required String title,
    required String body,
  }) async {}

  @override
  Future<void> cancel({required int id}) async {}

  @override
  Future<bool?> requestPermission() async => null;

  @override
  Future<bool?> isEnabled() async => null;

  @override
  Future<void> openSystemSettings() async {}

  @override
  Future<String?> launchPayload() async => null;
}
