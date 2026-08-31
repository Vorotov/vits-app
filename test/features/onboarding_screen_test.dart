/// Widget tests for the two-page intro (v1.2 path A, ONBO-01): what each page
/// renders, the Skip and CTA contracts, and the bilingual render matrix at
/// every supported text scale.
///
/// The page count has moved twice — see the screen's own library doc for why.
/// The mechanics of cycles are NOT here: they are a contextual hint in the
/// regimen editor, covered by first_run_hints_test.dart.
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

  testWidgets('page 1 renders the product line, Далі and Пропустити',
      (tester) async {
    await tester.pumpWidget(screenApp());
    await tester.pumpAndSettle();

    expect(find.text('Ваш стек, день за днем'), findsOneWidget);
    expect(find.text('Далі'), findsOneWidget);
    expect(find.text('Пропустити'), findsOneWidget);
    expect(find.text('Додати першу добавку'), findsNothing,
        reason: 'the CTA names the NEXT tap, and on page 1 that is a page '
            'turn — a button promising to add a supplement that instead '
            'scrolls is the label lying about itself');
  });

  testWidgets('page 2 is the calendar page and carries the add-first CTA',
      (tester) async {
    await tester.pumpWidget(screenApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Далі'));
    await tester.pumpAndSettle();

    expect(find.text('Календар бачить усе разом'), findsOneWidget);
    expect(find.text('Додати першу добавку'), findsOneWidget);
    expect(find.text('Далі'), findsNothing);
    expect(find.text('Пропустити'), findsOneWidget,
        reason: 'Skip is on EVERY page (D-8) — an intro whose escape hatch '
            'disappears on the last page is the pattern at its worst');
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

  testWidgets('the CTA marks seen AND arms the one-shot',
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

          await tester.tap(find.text(locale == 'uk' ? 'Далі' : 'Next'));
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull, reason: overflowReason);
          if (locale == 'en') expectNoCyrillicWhileEn(tester);
        });
      }
    }
  });
}
