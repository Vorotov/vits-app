import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:boostque/app_shell.dart';
import 'package:boostque/core/l10n/l10n.dart';
import 'package:boostque/core/l10n/locale_controller.dart';
import 'package:boostque/core/notifications/notification_locale.dart';
import 'package:boostque/core/notifications/notification_providers.dart';
import 'package:boostque/core/notifications/notification_scheduler.dart';
import 'package:boostque/core/notifications/notification_service.dart';
import 'package:boostque/core/notifications/tz_conversion.dart';
import 'package:boostque/core/providers.dart';
import 'package:boostque/core/selected_tab_controller.dart';
import 'package:boostque/core/theme/theme.dart';

Future<void> main() async {
  // The store is resolved BEFORE the first frame so [LocaleController] can
  // seed itself synchronously — a user with a stored language override never
  // sees a system-language frame on cold start (P-4 Option A).
  WidgetsFlutterBinding.ensureInitialized();
  SharedPreferences? prefs;
  try {
    prefs = await SharedPreferences.getInstance();
  } catch (error, stack) {
    // Resolving the store sits between `ensureInitialized()` and `runApp()`,
    // so an escaping error here means runApp is NEVER called: no Flutter UI is
    // attached, the user stares at the launch screen, and because the failure
    // is deterministic (plugin registration, a corrupt prefs file, an OEM
    // storage-permission denial) restarting does not help. This store carries
    // one cosmetic language override, so it may not hold the launch hostage:
    // degrade to "follow system" and start. Reported for the crash logger, not
    // to the user — there is nothing they could do, and the app works (CR-02).
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stack,
        library: 'boostque',
        context: ErrorDescription('resolving SharedPreferences in main()'),
      ),
    );
  }
  // The destination a tap launched the app into, resolved HERE for the same
  // reason and with the same failure stance as the store above: its answer has
  // to exist by frame 1, or the user watches Стек paint and then jump —
  // precisely the flash the stored-language seed already exists to remove
  // (`locale_controller.dart:41-43`, P-4 Option A). This codebase's frame-1
  // seeds are ONE pattern; a reader who recognizes the first should recognize
  // this one. It cannot move into the plugin's initialization callback either:
  // that callback is documented as unable to handle a launch-from-tap at all
  // (07-RESEARCH §8.6, DECIDED-12).
  final launchPayload = await _launchNotificationPayload();
  // NOTHING ELSE notification-related is added above this line, and that is a
  // checked fact twice over: a needle gate (test/notifications/
  // notification_bootstrap_test.dart) says the zone load, the plugin's
  // initialization and the channel creation may never appear in this window,
  // and a counted gate (test/notifications/notification_routing_test.dart) says
  // exactly two awaits may. The zone database is about a megabyte to parse and
  // initialize() plus the channel creation are two platform round trips; none of
  // them has a frame-1 dependency, so all three stay in the post-first-frame
  // path. The three overrides below merely INSTALL values — the provider bodies
  // are lazy and nothing runs here.
  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        launchNotificationPayloadProvider.overrideWithValue(launchPayload),
        notificationSchedulerProvider.overrideWith(_pluginScheduler),
        timeZoneLoaderProvider.overrideWithValue(initTimeZones),
      ],
      child: const BoostqueApp(),
    ),
  );
}

/// The payload of the notification that launched the app, or `null` — for any
/// reason at all, including a failure to ask.
///
/// A named function BELOW `main()` rather than three lines inside it, and the
/// placement is deliberate: the pre-`runApp` window holds the READ, while the
/// construction of the plugin-backed adapter stays out of it. The needle gate
/// over that window forbids constructing the adapter there because doing so
/// makes its `initialize()` the obvious next line for the next editor — and
/// `initialize()`, the zone load and the channel creation are exactly what
/// FLAG-3 keeps behind the first frame. This function asks ONE question and
/// returns; it initializes nothing and creates no channel.
///
/// The guard is the same one the preferences resolution carries, for the same
/// reason spelled out there: this window sits between binding initialization and
/// `runApp`, so an escaping error means `runApp` is NEVER called — no Flutter UI
/// attaches, the user stares at the launch screen, and because the failure is
/// deterministic, restarting does not help. **A notification tap must never be
/// able to prevent the app from starting.** Catch, report to the crash logger,
/// degrade to the default destination — an unreadable launch answer is no launch
/// answer, which is the state the app is in on every ordinary launch anyway.
Future<String?> _launchNotificationPayload() async {
  try {
    return await PluginNotificationScheduler().launchPayload();
  } catch (error, stack) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stack,
        library: 'boostque',
        context: ErrorDescription('reading the notification launch details'),
      ),
    );
    return null;
  }
}

/// The plugin-backed scheduler, constructed LAZILY by the provider rather than
/// eagerly in `main()`, so nothing plugin-shaped exists before the first frame.
///
/// A named top-level function rather than an inline closure so the override reads
/// as one contiguous `notificationSchedulerProvider.overrideWith(...)` that a
/// source gate — and a reviewer's grep — can find whatever the formatter does
/// with the line.
NotificationScheduler _pluginScheduler(Ref ref) => PluginNotificationScheduler();

/// Root app widget: theme + l10n + locale resolution (D-10, D-11).
///
/// Locale resolution order: manual override from [localeControllerProvider]
/// (null lets the system locale flow through), then system uk/en matched
/// against [MaterialApp.supportedLocales], else English — English is
/// `supportedLocales.first` because `preferred-supported-locales: [en]` in
/// `l10n.yaml` DECLARES it. Without that declaration gen-l10n emits the list
/// alphabetically and the fallback would move the day an earlier-sorting ARB
/// landed (PF-1, L10N-02).
class BoostqueApp extends ConsumerWidget {
  const BoostqueApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watching the bootstrap flag costs exactly ONE extra rebuild of this widget
    // when it flips. That is the price of the FLAG-3 ordering guarantee, and it
    // is cheaper than plumbing a ProviderContainer out of main() to drive the
    // bootstrap from there.
    //
    // It is watched only to keep the provider ALIVE for the app's lifetime: an
    // unlistened provider is paused in this version of Riverpod, so the
    // bootstrap's own listener on the resolved locale would never be
    // registered. The value itself is not read here.
    ref.watch(notificationBootstrapProvider);
    return MaterialApp(
      onGenerateTitle: (context) => context.l10n.appTitle,
      theme: bqTheme(),
      locale: ref.watch(localeControllerProvider),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      // The notification copy is built in the locale the UI is ACTUALLY
      // rendering, OBSERVED here rather than re-derived: reproducing
      // MaterialApp's own resolution would be a second copy of a rule whose
      // correctness depends on this file never passing a
      // localeResolutionCallback (DECIDED-15, the PF-1 defect shape).
      //
      // It sits in `builder` rather than in `home` so that it wraps the
      // navigator and therefore every route, while still being INSIDE the
      // localizations it observes. It reports from a post-frame callback, which
      // is what keeps the whole notification bootstrap behind the first frame
      // (FLAG-3): the resolved locale is what starts it.
      builder: (context, child) => NotificationLocaleObserver(child: child!),
      home: const AppShell(),
    );
  }
}
