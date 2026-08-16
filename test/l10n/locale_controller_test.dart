/// `LocaleController`'s unit contract after plan 05-01: the synchronous seed,
/// the state-first ordering, and both sanitization cases.
///
/// The absence of `pumpEventQueue()` in most tests below is itself the claim —
/// a stored override is present on the FIRST read, not one microtask later,
/// which is what removes the cold-start language flash (P-4 Option A).
library;

import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:boostque/core/l10n/l10n.dart';
import 'package:boostque/core/l10n/locale_controller.dart';
import 'package:boostque/core/providers.dart';

void main() {
  /// Seeds the mock store and builds a container over the resolved instance.
  ///
  /// `sharedPreferencesProvider` throws when it is not overridden, so this is
  /// now the only way to reach the controller — a harness that forgets fails
  /// loudly instead of silently losing the user's override.
  Future<ProviderContainer> makeContainer(Map<String, Object> stored) async {
    SharedPreferences.setMockInitialValues(stored);
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('stored uk override is present on the FIRST read — no async settle',
      () async {
    final container = await makeContainer({'app_locale': 'uk'});

    expect(
      container.read(localeControllerProvider),
      const Locale('uk'),
      reason: 'the seed is synchronous: an async load would return null here '
          'and flip a microtask later, which on a real cold start is one '
          'painted frame in the wrong language',
    );
  });

  test('empty prefs means null state (follow system)', () async {
    final container = await makeContainer({});

    expect(container.read(localeControllerProvider), isNull);
  });

  test('setLocale persists app_locale; setLocale(null) removes it', () async {
    final container = await makeContainer({});
    final controller = container.read(localeControllerProvider.notifier);

    await controller.setLocale(const Locale('en'));
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('app_locale'), 'en');
    expect(container.read(localeControllerProvider), const Locale('en'));

    await controller.setLocale(null);
    expect(prefs.getString('app_locale'), isNull);
    expect(container.read(localeControllerProvider), isNull);
  });

  test('setLocale sets state BEFORE the persist future completes (PF-3)',
      () async {
    final container = await makeContainer({});
    final controller = container.read(localeControllerProvider.notifier);

    // Deliberately not awaited: the state must already be the new locale on
    // the line after the call, because that is the frame the user sees.
    final persisted = controller.setLocale(const Locale('uk'));
    expect(
      container.read(localeControllerProvider),
      const Locale('uk'),
      reason: 'persisting first would put a platform-channel round-trip and a '
          'disk write in front of the repaint, which makes "applies '
          'instantly" a lie on a slow device',
    );

    await persisted;
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('app_locale'), 'uk',
        reason: 'state-first must not mean write-never — the next launch '
            'depends on this landing');
  });

  test('unsupported stored value is sanitized to null/system (T-01-07)',
      () async {
    final container = await makeContainer({'app_locale': 'de'});

    expect(container.read(localeControllerProvider), isNull);
  });

  test(
      'a stored code whose ARB was removed in a later build degrades to '
      'follow-system rather than crashing (E-7, T-05-02)', () async {
    // 'zz' stands in for a code that WAS shipped and no longer is: the
    // allowlist follows the ARB files, so dropping app_uk.arb from a future
    // build would take exactly this path for a stored 'uk'.
    final container = await makeContainer({'app_locale': 'zz'});

    expect(
      container.read(localeControllerProvider),
      isNull,
      reason: 'an unvalidated code would reach the generated '
          'lookupAppLocalizations throw at MaterialApp build time — an '
          'unrecoverable launch crash, not a cosmetic fallback (T-05-01)',
    );
  });

  test(
      'a write that FAILS is swallowed and reported, never left to the zone '
      '(WR-04, DECIDED-8)', () async {
    // The call site fires this future and forgets it (`unawaited`), so an
    // escaping error would become an unhandled root-zone error — printed in
    // release, an outright failure in any test that happens to be pumping.
    // "Deliberately not surfaced" has to mean swallowed HERE.
    final prefs = _RejectingPrefs();
    when(() => prefs.get(any())).thenReturn(null);
    when(() => prefs.setString(any(), any()))
        .thenThrow(Exception('storage is full'));
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    final reported = <FlutterErrorDetails>[];
    final previous = FlutterError.onError;
    FlutterError.onError = reported.add;
    addTearDown(() => FlutterError.onError = previous);

    await expectLater(
      container
          .read(localeControllerProvider.notifier)
          .setLocale(const Locale('uk')),
      completes,
      reason: 'the future must complete normally: the caller does not await '
          'it, so an error escaping here has nowhere to go but the zone',
    );

    expect(
      container.read(localeControllerProvider),
      const Locale('uk'),
      reason: 'state-first (PF-3): the language the user just tapped is the '
          'truth for the session even when the disk refuses it',
    );
    expect(
      reported,
      hasLength(1),
      reason: 'silent to the USER (DECIDED-8) is not the same as invisible to '
          'a crash logger — a store that refuses writes is a real device fault',
    );
  });

  test('a REJECTED write (setString answering false) is reported too (WR-04)',
      () async {
    final prefs = _RejectingPrefs();
    when(() => prefs.get(any())).thenReturn(null);
    when(() => prefs.setString(any(), any())).thenAnswer((_) async => false);
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    final reported = <FlutterErrorDetails>[];
    final previous = FlutterError.onError;
    FlutterError.onError = reported.add;
    addTearDown(() => FlutterError.onError = previous);

    await container
        .read(localeControllerProvider.notifier)
        .setLocale(const Locale('uk'));

    expect(
      reported,
      hasLength(1),
      reason: "a `false` return has the same consequence as a throw — the next "
          'launch reverts — so dropping it would hide half the failure mode',
    );
  });

  test(
      'a wrong-TYPED stored value sanitizes to follow-system rather than '
      'throwing at root-build time (CR-01, T-01-07)', () async {
    // The value under this key is untrusted in its TYPE as well as its
    // content: `SharedPreferences.getString` is an unguarded `as String?`
    // downcast, so a non-String value throws a TypeError INSIDE build() —
    // which BoostqueApp.build watches, so the provider parks in a permanent
    // error state and the root widget cannot be rebuilt into health. That is
    // a bricked launch that survives restarts, not a cosmetic fallback.
    for (final tampered in <Object>[7, true, 3.5, <String>['uk']]) {
      final container = await makeContainer({'app_locale': tampered});

      expect(
        container.read(localeControllerProvider),
        isNull,
        reason: 'a stored ${tampered.runtimeType} must degrade to '
            'follow-system exactly like an unsupported code does',
      );
    }
  });

  test(
      'the allowlist equals the generated supportedLocales language codes — '
      'derived, never enumerated (L10N-04, criterion 4)', () {
    expect(
      LocaleController.supportedLanguageCodes,
      AppLocalizations.supportedLocales.map((l) => l.languageCode).toSet(),
      reason: 'the file that owns sanitization must follow the ARB files: a '
          'hand-kept set would reject a newly added language, so "one new ARB '
          'file, no code changes" would silently stop being true',
    );
  });
}

/// A store that answers reads but refuses writes — the DECIDED-8 failure.
class _RejectingPrefs extends Mock implements SharedPreferences {}
