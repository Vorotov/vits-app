/// Widget tests for the onboarding gate and the first-add one-shot handoff
/// (spec D-2, D-7, D-10, ONBO-02): which branch renders, the full walk from
/// first launch to the open add sheet, and that the sheet can never open
/// twice or on a cold start.
///
/// Harness notes, inherited from `app_shell_test.dart`: the shell branch
/// mounts the real `AppShell`, which keeps a midnight timer alive — so
/// bounded `pump` loops, never `pumpAndSettle`, and the tree is torn down
/// inside each test body so Drift's stream-close timers fire before
/// flutter_test's pending-timer check.
library;

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
import 'package:boostque/features/onboarding/onboarding_gate.dart';
import 'package:boostque/features/onboarding/onboarding_screen.dart';

void main() {
  late SharedPreferences prefs;

  Future<void> seedPrefs(Map<String, Object> values) async {
    SharedPreferences.setMockInitialValues(values);
    prefs = await SharedPreferences.getInstance();
  }

  Widget gateApp() {
    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        dbProvider.overrideWith((ref) {
          final db = BoostqueDb.forTesting(NativeDatabase.memory());
          ref.onDispose(db.close);
          return db;
        }),
      ],
      child: MaterialApp(
        locale: const Locale('uk'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: bqTheme(),
        home: const OnboardingGate(),
      ),
    );
  }

  /// Bounded frame pumping (PF-7): the shell's midnight timer makes
  /// `pumpAndSettle` a hang or a lie.
  Future<void> pumpFrames(WidgetTester tester, [int frames = 20]) async {
    for (var i = 0; i < frames; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
  }

  Future<void> flushTearDown(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 10));
    await tester.pump(const Duration(milliseconds: 10));
  }

  testWidgets('unseen: onboarding renders, no shell', (tester) async {
    await seedPrefs({});
    await tester.pumpWidget(gateApp());
    await pumpFrames(tester);

    expect(find.byType(OnboardingScreen), findsOneWidget);
    expect(find.byType(AppShell), findsNothing);

    await flushTearDown(tester);
  });

  testWidgets('seen: shell renders, no onboarding, and NO sheet opens',
      (tester) async {
    await seedPrefs({'onboarding_seen': true});
    await tester.pumpWidget(gateApp());
    await pumpFrames(tester);

    expect(find.byType(AppShell), findsOneWidget);
    expect(find.byType(OnboardingScreen), findsNothing);
    // A cold start never has the one-shot armed (spec: force-quit
    // mid-onboarding must not produce a surprise sheet next launch).
    expect(find.text('Вручну'), findsNothing);

    await flushTearDown(tester);
  });

  testWidgets(
      'the full first launch: intro → CTA → shell with the add sheet '
      'open exactly once', (tester) async {
    await seedPrefs({});
    await tester.pumpWidget(gateApp());
    await pumpFrames(tester);

    await tester.tap(find.text('Додати першу добавку'));
    await pumpFrames(tester);

    expect(find.byType(AppShell), findsOneWidget);
    expect(find.byType(OnboardingScreen), findsNothing);
    // The add sheet is open: both of its segmented tabs are on stage, once.
    expect(find.text('Вручну'), findsOneWidget);
    expect(find.text('Пошук у базі'), findsOneWidget);
    // The flag persisted, whatever happens to the sheet (D-7).
    expect(prefs.getBool('onboarding_seen'), isTrue);

    await flushTearDown(tester);
  });

  testWidgets('Skip lands on the shell with NO sheet', (tester) async {
    await seedPrefs({});
    await tester.pumpWidget(gateApp());
    await pumpFrames(tester);

    await tester.tap(find.text('Пропустити'));
    await pumpFrames(tester);

    expect(find.byType(AppShell), findsOneWidget);
    expect(find.text('Вручну'), findsNothing);
    expect(prefs.getBool('onboarding_seen'), isTrue);

    await flushTearDown(tester);
  });

  testWidgets('cancelling the first-add sheet leaves seen true — no re-show',
      (tester) async {
    await seedPrefs({});
    await tester.pumpWidget(gateApp());
    await pumpFrames(tester);

    await tester.tap(find.text('Додати першу добавку'));
    await pumpFrames(tester);
    expect(find.text('Вручну'), findsOneWidget);

    // Dismiss the modal sheet: pop it off the root navigator (the barrier
    // region is not reliably hittable under isScrollControlled at test
    // surface size, so this pops the same route the barrier tap would).
    tester.state<NavigatorState>(find.byType(Navigator).first).pop();
    await pumpFrames(tester);

    expect(find.text('Вручну'), findsNothing);
    expect(find.byType(AppShell), findsOneWidget);
    expect(find.byType(OnboardingScreen), findsNothing);
    expect(prefs.getBool('onboarding_seen'), isTrue);

    await flushTearDown(tester);
  });

  testWidgets('a rebuilt shell branch cannot open a second sheet',
      (tester) async {
    await seedPrefs({});
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        dbProvider.overrideWith((ref) {
          final db = BoostqueDb.forTesting(NativeDatabase.memory());
          ref.onDispose(db.close);
          return db;
        }),
      ],
    );
    Widget app() => UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            locale: const Locale('uk'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: bqTheme(),
            home: const OnboardingGate(),
          ),
        );

    await tester.pumpWidget(app());
    await pumpFrames(tester);
    await tester.tap(find.text('Додати першу добавку'));
    await pumpFrames(tester);
    expect(find.text('Вручну'), findsOneWidget);

    // Dismiss, then force the gate subtree to rebuild against the SAME
    // container (the one-shot's state survives; only its armed-ness matters).
    tester.state<NavigatorState>(find.byType(Navigator).first).pop();
    await pumpFrames(tester);
    await tester.pumpWidget(app());
    await pumpFrames(tester);

    expect(find.text('Вручну'), findsNothing);

    // Manual teardown, INSIDE the body: an uncontrolled scope does not
    // dispose its container on unmount, and disposing it from addTearDown
    // would close the db after flutter_test's pending-timer check — the
    // exact hang the flushTearDown idiom exists to prevent.
    await tester.pumpWidget(const SizedBox());
    container.dispose();
    await tester.pump(const Duration(milliseconds: 10));
    await tester.pump(const Duration(milliseconds: 10));
  });
}
