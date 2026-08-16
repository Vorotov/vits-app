/// System-language resolution and the English fallback, as BEHAVIOUR
/// (plan 05-03 task 3, L10N-02, 05-RESEARCH P-3 / PF-1 / E-3 / E-4).
///
/// L10N-02 — "the app follows the system language when supported, falling back
/// to English" — is a claim about what the framework DOES with the device's
/// locale preference list, not about what `l10n.yaml` says. So every case here
/// drives the real resolver: the device preference list is set on the test
/// platform dispatcher, a `MaterialApp` is pumped with
/// `AppLocalizations.supportedLocales` and the generated delegates, and the
/// assertion is on the RENDERED copy. Asserting on a `Locale` object instead
/// would pass in the world where resolution is right and delivery is broken.
///
/// The multi-entry case is the one that earns its keep. Android and iOS both
/// hand the app an ordered LIST of preferred languages, and the framework's
/// `basicLocaleListResolution` walks the whole list. A hand-rolled
/// `localeResolutionCallback` sees only the first entry unless its author
/// remembered the plural form — which is precisely why this app has none, and
/// why the absence deserves a test.
///
/// The English fallback is asserted BY NAME rather than as "the first
/// supported locale": those are the same sentence only while English happens
/// to sort first (PF-1). The declaration that keeps them the same thing is
/// gated in `new_language_contract_test.dart`.
///
/// PF-8 note for anyone extending this file: these cases pump a `MaterialApp`,
/// so date symbols arrive through the global delegates. A pure `intl`
/// assertion added here — a bare `DateFormat(...)` with no widget tree — would
/// need `initializeDateFormatting(locale)` in `setUpAll` first, or it silently
/// asserts against English month names (see `month_names_test.dart`).
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:boostque/core/l10n/l10n.dart';

/// Locale-distinctive copy: `tabStack` reads 'Stack' in English and 'Стек' in
/// Ukrainian, so the rendered string names the delivered language without any
/// further interpretation.
const englishCopy = 'Stack';
const ukrainianCopy = 'Стек';

/// The app under test, reduced to what resolution needs: supported locales,
/// the generated delegates, and a screen that renders one localized string.
///
/// Deliberately NO `locale:` argument — that is the manual override, and this
/// file is about what happens when there is none.
Widget resolvingApp() {
  return MaterialApp(
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    home: Builder(builder: (context) => Text(context.l10n.tabStack)),
  );
}

void main() {
  late TestWidgetsFlutterBinding binding;

  setUpAll(() {
    binding = TestWidgetsFlutterBinding.ensureInitialized();
  });

  tearDown(() {
    // Reset, or the previous case's device stays configured for the next one
    // and a green run proves nothing about the case it claims to cover.
    binding.platformDispatcher.clearLocalesTestValue();
  });

  testWidgets(
      'a device set to a language the app does not ship renders ENGLISH, not '
      'merely the first supported locale (L10N-02, E-3, PF-1)', (tester) async {
    tester.platformDispatcher.localesTestValue = const [Locale('de', 'DE')];

    await tester.pumpWidget(resolvingApp());

    expect(
      find.text(englishCopy),
      findsOneWidget,
      reason: 'MaterialApp falls back to supportedLocales.first. Naming '
          'English here rather than "the first entry" is the whole point: the '
          'two are the same claim only while the declared ordering in '
          'l10n.yaml puts English first, and a German-speaking user must not '
          'be shown Ukrainian because someone added an ARB alphabetically '
          'ahead of en',
    );
    expect(find.text(ukrainianCopy), findsNothing);
  });

  testWidgets(
      'the framework walks the WHOLE device preference list, not just its '
      'first entry (L10N-02, P-3)', (tester) async {
    // The realistic shape of a bilingual user's phone: an unsupported first
    // choice, then Ukrainian, then English.
    tester.platformDispatcher.localesTestValue = const [
      Locale('de', 'DE'),
      Locale('uk', 'UA'),
      Locale('en', 'US'),
    ];

    await tester.pumpWidget(resolvingApp());

    expect(
      find.text(ukrainianCopy),
      findsOneWidget,
      reason: 'basicLocaleListResolution matches the device list in order and '
          'takes the first supported entry — here Ukrainian, in second place. '
          'A hand-rolled localeResolutionCallback reads only the first '
          'preference and would strand this user in English, which is why the '
          'app has none',
    );
    expect(find.text(englishCopy), findsNothing);
  });

  testWidgets(
      'a device set to a supported language renders it directly (L10N-02, E-4)',
      (tester) async {
    tester.platformDispatcher.localesTestValue = const [Locale('uk', 'UA')];

    await tester.pumpWidget(resolvingApp());

    expect(
      find.text(ukrainianCopy),
      findsOneWidget,
      reason: 'a country subtag the app ships no ARB for (uk_UA vs uk) must '
          'still match on the language code — otherwise every real Ukrainian '
          'device, which reports uk_UA, would fall back to English',
    );
  });

  testWidgets('and an English device renders English (L10N-02)',
      (tester) async {
    tester.platformDispatcher.localesTestValue = const [Locale('en', 'GB')];

    await tester.pumpWidget(resolvingApp());

    expect(find.text(englishCopy), findsOneWidget);
    expect(find.text(ukrainianCopy), findsNothing);
  });
}
