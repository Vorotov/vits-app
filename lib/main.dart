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
  final prefs = await SharedPreferences.getInstance();
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
