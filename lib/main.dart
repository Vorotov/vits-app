import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:boostque/app_shell.dart';
import 'package:boostque/core/l10n/l10n.dart';
import 'package:boostque/core/l10n/locale_controller.dart';
import 'package:boostque/core/notifications/notification_providers.dart';
import 'package:boostque/core/notifications/notification_scheduler.dart';
import 'package:boostque/core/notifications/notification_service.dart';
import 'package:boostque/core/notifications/tz_conversion.dart';
import 'package:boostque/core/providers.dart';
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
  // NOTHING notification-related is added above this line, and that is a checked
  // fact (07-UI-CHECK FLAG-3, asserted by test/notifications/
  // notification_bootstrap_test.dart). The zone database is about a megabyte to
  // parse and the plugin's initialize() plus the channel creation are two
  // platform round trips; only a launch-details read has a frame-1 dependency,
  // and it is not in this plan. Both overrides below merely INSTALL
  // implementations — the provider bodies are lazy and nothing runs here.
  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        notificationSchedulerProvider.overrideWith(_pluginScheduler),
        timeZoneLoaderProvider.overrideWithValue(initTimeZones),
      ],
      child: const BoostqueApp(),
    ),
  );
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
    ref.watch(notificationBootstrapProvider);
    final bootstrap = ref.read(notificationBootstrapProvider.notifier);
    return MaterialApp(
      onGenerateTitle: (context) => context.l10n.appTitle,
      theme: bqTheme(),
      locale: ref.watch(localeControllerProvider),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      builder: (context, child) {
        // The notification copy is built in the locale the UI is ACTUALLY
        // rendering, OBSERVED here rather than re-derived: reproducing
        // MaterialApp's own resolution would be a second copy of a rule whose
        // correctness depends on this file never passing a
        // localeResolutionCallback (DECIDED-15, the PF-1 defect shape).
        //
        // Post-frame, never during build: this is the whole of the notification
        // bootstrap, and FLAG-3 permits none of it before the first frame is on
        // screen.
        final observed = Localizations.localeOf(context);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          bootstrap.bootstrap(locale: observed);
        });
        return child!;
      },
      home: const AppShell(),
    );
  }
}
