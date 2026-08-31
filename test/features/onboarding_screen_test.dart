/// Widget tests for the two-page onboarding screen (spec Screens section,
/// ONBO-01): flow through both pages, the Skip and CTA contracts, and the
/// bilingual render matrix at every supported text scale.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:boostque/core/l10n/l10n.dart';
import 'package:boostque/core/providers.dart';
import 'package:boostque/core/theme/theme.dart';
import 'package:boostque/features/onboarding/onboarding_controller.dart';
import 'package:boostque/features/onboarding/onboarding_screen.dart';

import '../support/locale_matrix.dart';

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  /// The screen alone under a pinned locale and scale — no shell, no db, so
  /// `pumpAndSettle` is safe here (nothing keeps a session-long timer).
  Widget screenApp({
    String locale = 'uk',
    TextScaler? textScaler,
    ProviderContainer? container,
  }) {
    final app = MaterialApp(
      locale: Locale(locale),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: bqTheme(),
      builder: (context, child) => textScaler == null
          ? child!
          : MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: textScaler),
              child: child!,
            ),
      home: const OnboardingScreen(),
    );
    if (container != null) {
      return UncontrolledProviderScope(container: container, child: app);
    }
    return ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: app,
    );
  }

  ProviderContainer makeContainer() {
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);
    return container;
  }

  testWidgets('page 1 renders title, body, Далі and Пропустити',
      (tester) async {
    await tester.pumpWidget(screenApp());
    await tester.pumpAndSettle();

    expect(find.text('Ваш стек, день за днем'), findsOneWidget);
    expect(find.text('Далі'), findsOneWidget);
    expect(find.text('Пропустити'), findsOneWidget);
    // Page 2 is not on stage yet.
    expect(find.text('Додати першу добавку'), findsNothing);
  });

  testWidgets('Далі advances to page 2 with the add-first CTA',
      (tester) async {
    await tester.pumpWidget(screenApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Далі'));
    await tester.pumpAndSettle();

    expect(find.text('Цикли й перерви'), findsOneWidget);
    expect(find.text('Додати першу добавку'), findsOneWidget);
    expect(find.text('Далі'), findsNothing);
  });

  testWidgets('Skip marks seen and never arms the one-shot', (tester) async {
    final container = makeContainer();
    await tester.pumpWidget(screenApp(container: container));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Пропустити'));
    await tester.pumpAndSettle();

    expect(container.read(onboardingSeenProvider), isTrue);
    expect(container.read(pendingFirstAddProvider), isFalse);
    expect(prefs.getBool('onboarding_seen'), isTrue);
  });

  testWidgets('the final CTA marks seen AND arms the one-shot',
      (tester) async {
    final container = makeContainer();
    await tester.pumpWidget(screenApp(container: container));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Далі'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Додати першу добавку'));
    await tester.pumpAndSettle();

    expect(container.read(onboardingSeenProvider), isTrue);
    expect(container.read(pendingFirstAddProvider), isTrue);
  });

  group('render matrix — both pages, both locales, every scale', () {
    for (final locale in bqLocaleMatrix) {
      for (final scale in bqTextScaleMatrix) {
        testWidgets('$locale @ ${scale}x renders both pages clean',
            (tester) async {
          await tester.pumpWidget(screenApp(
            locale: locale,
            textScaler: TextScaler.linear(scale),
          ));
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull, reason: overflowReason);
          if (locale == 'en') expectNoCyrillicWhileEn(tester);

          final next = locale == 'uk' ? 'Далі' : 'Next';
          await tester.tap(find.text(next));
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull, reason: overflowReason);
          if (locale == 'en') expectNoCyrillicWhileEn(tester);
        });
      }
    }
  });
}
