/// Widget tests for the ONE-page intro (v1.2 path A, ONBO-01): what it
/// renders, the Skip and CTA contracts, and the bilingual render matrix at
/// every supported text scale.
///
/// It was two pages until the onboarding research pass — see the screen's own
/// library doc for the evidence. The cycle explanation moved to a contextual
/// hint in the regimen editor, covered by first_run_hints_test.dart.
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

  testWidgets('renders the title, the body, the CTA and Skip — and no '
      'second page', (tester) async {
    await tester.pumpWidget(screenApp());
    await tester.pumpAndSettle();

    expect(find.text('Ваш стек, день за днем'), findsOneWidget);
    expect(find.text('Додати першу добавку'), findsOneWidget);
    expect(find.text('Пропустити'), findsOneWidget);

    // The deck is GONE, asserted as an absence: a Next control or a PageView
    // would mean the multi-page shape came back, which is the shape the
    // research pass removed.
    expect(find.text('Далі'), findsNothing);
    expect(find.byType(PageView), findsNothing,
        reason: 'one page, no swipe surface — a deck of one is still a deck');
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

    await tester.tap(find.text('Додати першу добавку'));
    await tester.pumpAndSettle();

    expect(container.read(onboardingSeenProvider), isTrue);
    expect(container.read(pendingFirstAddProvider), isTrue);
  });

  group('render matrix — both locales, every scale', () {
    for (final locale in bqLocaleMatrix) {
      for (final scale in bqTextScaleMatrix) {
        testWidgets('$locale @ ${scale}x renders clean', (tester) async {
          await tester.pumpWidget(screenApp(
            locale: locale,
            textScaler: TextScaler.linear(scale),
          ));
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull, reason: overflowReason);
          if (locale == 'en') expectNoCyrillicWhileEn(tester);
        });
      }
    }
  });
}
