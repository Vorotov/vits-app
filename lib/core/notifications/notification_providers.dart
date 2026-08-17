/// The notification layer's Riverpod graph: the mockable seam, the one platform
/// read it cannot fake, and the bootstrap whose ORDERING is a checked fact.
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:boostque/core/l10n/gen/app_localizations.dart';
import 'package:boostque/core/notifications/notification_constants.dart';
import 'package:boostque/core/notifications/notification_scheduler.dart';

/// The seam every later plan mocks.
///
/// **Defaults to the no-op implementation**, and is overridden in `main()` with
/// the plugin-backed one. This is the OPPOSITE choice from
/// `sharedPreferencesProvider`'s deliberate throw (`providers.dart:62`), and the
/// reason is the one that matters most in this phase: a throwing default would
/// break every existing test that pumps the root app widget, while a no-op
/// default makes it impossible for any test to reach the plugin by accident —
/// which is mandatory, because every plugin call path throws a
/// `LateInitializationError` under `flutter test`.
///
/// The cost of that choice is real and is paid for by a test: a forgotten
/// override means production silently schedules nothing, so a source gate asserts
/// `main()` installs it.
final notificationSchedulerProvider = Provider<NotificationScheduler>(
  (ref) => const NoopNotificationScheduler(),
);

/// Loads the timezone database and resolves the device's zone.
///
/// Injected rather than called directly, for the same reason and with the same
/// cost as the scheduler above: the device-zone read is a platform-channel round
/// trip that would throw in every widget test. `main()` installs
/// `initTimeZones`; the default is **null**, which means "nothing to bootstrap"
/// and is the honest answer in a bare container — a test that has installed
/// nothing has bootstrapped nothing, and [NotificationBootstrap] reports
/// not-ready rather than claiming a zone database it never loaded.
final timeZoneLoaderProvider = Provider<Future<void> Function()?>(
  (ref) => null,
);

/// Whether the notification layer is ready to be asked for anything.
///
/// `false` until the timezone database is loaded, the plugin is initialized and
/// the Android channel is created. Later plans read this as their PRECONDITION
/// rather than trusting an ordering comment: nothing may build an instant or
/// schedule anything while it is false, because before `setLocalLocation` runs a
/// zoned value comes out as UTC silently and every reminder is off by the device
/// offset.
final notificationBootstrapProvider =
    NotifierProvider<NotificationBootstrap, bool>(NotificationBootstrap.new);

/// Runs the notification bootstrap AFTER the first frame, and reports when it is
/// done.
///
/// **The ordering is binding, not stylistic (07-UI-CHECK FLAG-3).** Only a
/// launch-details read has a first-frame dependency, and it is not in this plan at
/// all. The zone database is roughly a megabyte of data to parse; the plugin's
/// initialization and the channel creation are platform-channel round trips. The
/// existing cold-start guarantee asserts the shell paints on frame ONE — a frame
/// count, not a time budget — so moving any of this ahead of the first frame would
/// leave the entire suite green and every cold start slower.
///
/// [bootstrap] is therefore called from a post-FIRST-frame callback in
/// `main.dart`, with the locale the tree is actually rendering.
class NotificationBootstrap extends Notifier<bool> {
  Locale? _locale;
  bool _zonesLoaded = false;
  bool _pluginInitialized = false;
  bool _inFlight = false;

  @override
  bool build() => false;

  /// Loads what has not been loaded, then (re)writes the channel copy for
  /// [locale].
  ///
  /// [locale] is the locale the UI is ACTUALLY rendering, observed from the widget
  /// tree — never re-derived by reproducing `MaterialApp`'s resolution algorithm,
  /// which would be a second copy of a rule whose correctness depends on
  /// `main.dart` never passing a `localeResolutionCallback` (DECIDED-15, the PF-1
  /// defect shape).
  ///
  /// Idempotent per locale, and deliberately NOT idempotent across locales: a
  /// language change re-applies the channel's name and description with the id
  /// unchanged, which is exactly what Android's `createNotificationChannel` is
  /// specified to do for an existing id (DECIDED-14). Rescheduling the
  /// notifications themselves on a language change is a later plan's.
  Future<void> bootstrap({required Locale locale}) async {
    // The caller is a post-frame callback, so the container may already be gone
    // by the time it runs (a test that replaces one scope with another).
    if (!ref.mounted) return;
    final loadTimeZones = ref.read(timeZoneLoaderProvider);
    if (loadTimeZones == null) return;
    if (_inFlight) return;
    if (_locale == locale && state) return;
    _inFlight = true;
    try {
      if (!_zonesLoaded) {
        await loadTimeZones();
        _zonesLoaded = true;
      }
      final scheduler = ref.read(notificationSchedulerProvider);
      if (!_pluginInitialized) {
        await scheduler.initialize(onTap: _handleTap);
        _pluginInitialized = true;
      }
      final copy = lookupAppLocalizations(locale);
      await scheduler.ensureChannel(
        name: copy.doseChannelName,
        description: copy.doseChannelDescription,
      );
      _locale = locale;
      if (ref.mounted) state = true;
    } catch (error, stack) {
      // Reminders are the only thing a failure here costs, and the flag stays
      // false so nothing downstream will try to schedule against a half-built
      // platform. The same stance main() takes for the preferences store: a
      // subsystem that carries one feature may not hold the launch hostage, and
      // there is nothing the user could do about it anyway (CR-02).
      //
      // This catch is not defensive padding. Without it, the app running in an
      // environment with no notification plugin registered — every host test
      // that drives the real main() — dies on an UNHANDLED
      // `LateInitializationError: Field '_instance@…' has not been initialized`,
      // because the plugin's platform instance is a static late field with no
      // default (07-RESEARCH C-3). Verified by reproducing exactly that.
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stack,
          library: 'boostque',
          context: ErrorDescription('bootstrapping dose reminders'),
        ),
      );
    } finally {
      _inFlight = false;
    }
  }

  /// Handles a tap on a delivered reminder.
  ///
  /// The whitelist is here from the first commit even though there is nothing to
  /// route to yet: the operating system persists the payload and can replay one an
  /// older build wrote, so validating BEFORE a destination exists means no build
  /// can ever route on an unvalidated payload. Setting the tab and resetting the
  /// browsed day is plan 07-03's.
  void _handleTap(String? payload) {
    if (!isKnownNotificationPayload(payload)) return;
  }
}
