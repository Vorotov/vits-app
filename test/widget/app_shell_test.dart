import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:boostque/app_shell.dart';
import 'package:boostque/core/l10n/l10n.dart';
import 'package:boostque/core/theme/theme.dart';
import 'package:boostque/main.dart';

/// D-27: the shell renders localized tab labels in en and uk, switches tabs,
/// and produces no overflow with the longest uk label ("Налаштування").
///
/// No real DB is touched — stub screens read nothing; the Drift provider is
/// lazy and never watched here.
void main() {
  setUp(() {
    // LocaleController loads its persisted override from SharedPreferences;
    // an empty store means "follow system" (English in the test environment).
    SharedPreferences.setMockInitialValues({});
  });

  Widget ukApp() {
    return ProviderScope(
      child: MaterialApp(
        locale: const Locale('uk'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: bqTheme(),
        home: const AppShell(),
      ),
    );
  }

  testWidgets('en: shell shows localized tab labels and switches tabs',
      (tester) async {
    await tester.pumpWidget(const ProviderScope(child: BoostqueApp()));
    await tester.pumpAndSettle();

    // Three en tab labels present; initial tab shows the Stack heading
    // (tab label + heading = 2 widgets).
    expect(find.text('Stack'), findsNWidgets(2));
    expect(find.text('Calendar'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);

    // Switch to Settings: its heading appears (2 widgets), Stack heading
    // hidden again (tab label only).
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    expect(find.text('Settings'), findsNWidgets(2));
    expect(find.text('Stack'), findsOneWidget);
  });

  testWidgets('uk: shell shows uk tab labels without overflow',
      (tester) async {
    await tester.pumpWidget(ukApp());
    await tester.pumpAndSettle();

    // E1 populated + overflow truths: all three uk labels render, and the
    // longest label ("Налаштування") causes no RenderFlex overflow.
    expect(find.text('Стек'), findsNWidgets(2));
    expect(find.text('Календар'), findsOneWidget);
    expect(find.text('Налаштування'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('uk: switching to Settings renders heading without overflow',
      (tester) async {
    await tester.pumpWidget(ukApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Налаштування'));
    await tester.pumpAndSettle();

    // E2 overflow truth: uk heading renders twice (tab label + heading),
    // no exception thrown.
    expect(find.text('Налаштування'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });
}
