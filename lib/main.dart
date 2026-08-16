import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:boostque/app_shell.dart';
import 'package:boostque/core/l10n/l10n.dart';
import 'package:boostque/core/l10n/locale_controller.dart';
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
  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const BoostqueApp(),
    ),
  );
}

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
    return MaterialApp(
      onGenerateTitle: (context) => context.l10n.appTitle,
      theme: bqTheme(),
      locale: ref.watch(localeControllerProvider),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: const AppShell(),
    );
  }
}
