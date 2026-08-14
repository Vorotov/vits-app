import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:boostque/core/l10n/locale_controller.dart';

void main() {
  ProviderContainer makeContainer() {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    return container;
  }

  test('stored uk override loads as Locale(uk) after async load settles',
      () async {
    SharedPreferences.setMockInitialValues({'app_locale': 'uk'});
    final container = makeContainer();

    container.read(localeControllerProvider); // trigger build + async load
    await pumpEventQueue();

    expect(container.read(localeControllerProvider), const Locale('uk'));
  });

  test('empty prefs means null state (follow system)', () async {
    SharedPreferences.setMockInitialValues({});
    final container = makeContainer();

    container.read(localeControllerProvider);
    await pumpEventQueue();

    expect(container.read(localeControllerProvider), isNull);
  });

  test('setLocale persists app_locale; setLocale(null) removes it', () async {
    SharedPreferences.setMockInitialValues({});
    final container = makeContainer();
    final controller = container.read(localeControllerProvider.notifier);
    await pumpEventQueue();

    await controller.setLocale(const Locale('en'));
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('app_locale'), 'en');
    expect(container.read(localeControllerProvider), const Locale('en'));

    await controller.setLocale(null);
    expect(prefs.getString('app_locale'), isNull);
    expect(container.read(localeControllerProvider), isNull);
  });

  test('unsupported stored value is sanitized to null/system (T-01-07)',
      () async {
    SharedPreferences.setMockInitialValues({'app_locale': 'de'});
    final container = makeContainer();

    container.read(localeControllerProvider);
    await pumpEventQueue();

    expect(container.read(localeControllerProvider), isNull);
  });
}
