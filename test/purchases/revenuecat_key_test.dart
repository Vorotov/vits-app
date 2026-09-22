/// The key gate, which exists because of a specific near miss.
///
/// On 2026-09-22 this repository was handed
/// `test_jLgmNDtrHrGQDpyxLCwBYgGQaAY` as "my API key". It is a RevenueCat Test
/// Store key. Those route every purchase to a simulator modal and take no
/// money, and RevenueCat's own documentation is blunt about it: "Never submit
/// an app to the App Store or Google Play that is configured with a Test Store
/// API key."
///
/// What makes it worth a gate rather than a note is the failure mode. A build
/// carrying one launches, shows the tips, opens a sheet, reports success and
/// charges nobody. It looks, from the inside and from a simulator, exactly like
/// a build that works. Nothing else in this repository would have caught it.
///
/// The prefix check runs on every `flutter test`. The non-empty check lives in
/// `test_release/` instead, because an empty key is the correct state of this
/// tree until the real one is pasted in, and a red suite in the meantime would
/// teach everyone to ignore it.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vitomy/core/purchases/revenuecat_key.dart';

void main() {
  test('no Test Store key is committed', () {
    for (final entry in <String, String>{
      'revenueCatIosKey': revenueCatIosKey,
      'revenueCatAndroidKey': revenueCatAndroidKey,
    }.entries) {
      expect(
        entry.value.startsWith('test_'),
        isFalse,
        reason: '${entry.key} is a RevenueCat Test Store key. A build '
            'configured with one takes no money while looking, from the '
            'inside, exactly like a build that works, and RevenueCat forbids '
            'submitting it to either store. Use the PUBLIC platform key from '
            'the dashboard: appl_ for the App Store, goog_ for Play.',
      );
    }
  });

  test('a non-empty iOS key has the App Store prefix', () {
    if (revenueCatIosKey.isEmpty) return;
    expect(
      revenueCatIosKey.startsWith('appl_'),
      isTrue,
      reason: 'the iOS public SDK key is prefixed appl_. A goog_ key here '
          'configures the SDK against the wrong platform and every offering '
          'comes back empty, which the support screen renders as the honest '
          'but entirely misleading "unavailable"',
    );
  });

  test('a non-empty Android key has the Play prefix', () {
    if (revenueCatAndroidKey.isEmpty) return;
    expect(revenueCatAndroidKey.startsWith('goog_'), isTrue);
  });

  test('the key lives in its own file and nowhere else', () {
    // A key pasted into the gateway, into main(), or into a screen is how the
    // two assertions above stop covering the value the app actually ships.
    // Scoped to the literal prefixes so an ordinary word cannot trip it.
    final offenders = <String>[];
    for (final file in Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))) {
      if (file.path.endsWith('core/purchases/revenuecat_key.dart')) continue;
      final source = file
          .readAsLinesSync()
          .where((line) => !line.trimLeft().startsWith('//'))
          .join('\n');
      for (final prefix in const ['appl_', 'goog_']) {
        if (source.contains("'$prefix") || source.contains('"$prefix')) {
          offenders.add('${file.path} carries a $prefix literal');
        }
      }
    }
    expect(
      offenders,
      isEmpty,
      reason: 'the SDK key is declared once, in '
          'lib/core/purchases/revenuecat_key.dart, so that the gates above '
          'cover the value that actually ships. Offenders: $offenders',
    );
  });
}
