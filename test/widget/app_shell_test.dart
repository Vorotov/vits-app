import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:boostque/app_shell.dart';
import 'package:boostque/core/db/database.dart' show BoostqueDb;
import 'package:boostque/core/l10n/l10n.dart';
import 'package:boostque/core/providers.dart';
import 'package:boostque/core/theme/theme.dart';
import 'package:boostque/features/calendar/calendar_providers.dart';
import 'package:boostque/main.dart';

/// D-27: the shell renders localized tab labels in en and uk, switches tabs,
/// and produces no overflow with the longest uk label ("Налаштування").
///
/// Since plan 02-01 the Stack tab watches [stackEntriesProvider], so every
/// shell test overrides [dbProvider] with an in-memory database (D-19) and
/// flushes Drift's stream-close timers before the test ends.
void main() {
  late SharedPreferences prefs;

  setUp(() async {
    // LocaleController reads its persisted override from SharedPreferences;
    // an empty store means "follow system" (English in the test environment).
    // Since plan 05-01 that read is SYNCHRONOUS, through
    // sharedPreferencesProvider — which throws unless overridden — so the
    // instance is resolved here and handed to every scope below.
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  ProviderScope scoped(Widget child) {
    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        dbProvider.overrideWith((ref) {
          final db = BoostqueDb.forTesting(NativeDatabase.memory());
          ref.onDispose(db.close);
          return db;
        }),
      ],
      child: child,
    );
  }

  Widget ukApp() {
    return scoped(
      MaterialApp(
        locale: const Locale('uk'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: bqTheme(),
        home: const AppShell(),
      ),
    );
  }

  /// Tears the tree down inside the test body so Drift's stream-close
  /// zero-duration timers fire before flutter_test's pending-timer check.
  Future<void> flushTearDown(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 10));
    await tester.pump(const Duration(milliseconds: 10));
  }

  testWidgets('en: shell shows localized tab labels and switches tabs',
      (tester) async {
    await tester.pumpWidget(scoped(const BoostqueApp()));
    await tester.pumpAndSettle();

    // Three en tab labels present; initial tab shows the Stack screen
    // heading (stackTitle, since plan 02-01).
    expect(find.text('Stack'), findsOneWidget);
    expect(find.text('My stack'), findsOneWidget);
    expect(find.text('Calendar'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);

    // Switch to Settings: its heading appears (2 widgets), Stack heading
    // hidden again (tab label only).
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    expect(find.text('Settings'), findsNWidgets(2));
    expect(find.text('Stack'), findsOneWidget);
    expect(find.text('My stack'), findsNothing);

    await flushTearDown(tester);
  });

  testWidgets('uk: shell shows uk tab labels without overflow',
      (tester) async {
    await tester.pumpWidget(ukApp());
    await tester.pumpAndSettle();

    // E1 populated + overflow truths: all three uk labels render plus the
    // Stack heading, and the longest label ("Налаштування") causes no
    // RenderFlex overflow.
    expect(find.text('Стек'), findsOneWidget);
    expect(find.text('Мій стек'), findsOneWidget);
    expect(find.text('Календар'), findsOneWidget);
    expect(find.text('Налаштування'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await flushTearDown(tester);
  });

  testWidgets('uk: the minute ticker runs only while the Calendar tab is the '
      'visible one (WR-05)', (tester) async {
    final container = ProviderContainer(overrides: [
      // AppShell mounts the Settings tab even while the Stack tab is visible
      // (IndexedStack), and its language picker reaches LocaleController —
      // so this container needs the prefs seed too (P-4 Option A).
      sharedPreferencesProvider.overrideWithValue(prefs),
      dbProvider.overrideWith((ref) {
        final db = BoostqueDb.forTesting(NativeDatabase.memory());
        ref.onDispose(db.close);
        return db;
      }),
    ]);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        locale: const Locale('uk'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: bqTheme(),
        home: const AppShell(),
      ),
    ));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }

    expect(container.exists(nowMinutesProvider), isFalse,
        reason: 'the app opens on the Stack tab — an IndexedStack mounts the '
            'Calendar too, but no periodic clock may run for it');

    await tester.tap(find.text('Календар'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(container.exists(nowMinutesProvider), isTrue,
        reason: 'the visible calendar needs the minute of day for its current '
            'block and overdue treatments');

    await tester.tap(find.text('Стек'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(container.exists(nowMinutesProvider), isFalse,
        reason: 'leaving the tab cancels the subscription again');

    await flushTearDown(tester);
    container.dispose();
    await tester.pump(const Duration(milliseconds: 10));
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

    await flushTearDown(tester);
  });
}
