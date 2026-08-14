import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:boostque/app_shell.dart';
import 'package:boostque/core/l10n/l10n.dart';
import 'package:boostque/core/l10n/locale_controller.dart';
import 'package:boostque/core/theme/theme.dart';

void main() {
  runApp(const ProviderScope(child: BoostqueApp()));
}

/// Root app widget: theme + l10n + locale resolution (D-10, D-11).
///
/// Locale resolution order: manual override from [localeControllerProvider]
/// (null lets the system locale flow through), then system uk/en matched
/// against [MaterialApp.supportedLocales], else English — `Locale('en')` is
/// listed FIRST so any unsupported system language falls back to it.
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
