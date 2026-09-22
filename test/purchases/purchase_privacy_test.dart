/// What keeps the app's narrowed privacy claim true by construction.
///
/// Before 2026-09-22 the claim was simple and absolute: the app does not
/// connect to the internet. `purchases_flutter` ended that. The replacement is
/// narrower and has to be defended rather than merely asserted:
///
/// > Supplement data never leaves the device. The only network traffic is the
/// > purchase, and it carries none of it.
///
/// The second half — that there is exactly one way out of the device — is held
/// by `network_dependency_test.dart`. This file holds the first half, four
/// ways.
///
/// ## Why subscriber attributes are the whole risk
///
/// By default RevenueCat receives purchase and receipt history, the IDFV and
/// the IP address it infers a country from. It receives no app data at all.
/// **Subscriber attributes are the one channel through which app data could
/// reach their systems**, and they hold nothing unless something puts it there:
/// `setAttributes`, `setEmail`, `setDisplayName`, `setPhoneNumber`. There is no
/// accident that fills them. So "the app never sets one" is both the entire
/// control and a thing a source gate can prove.
///
/// ## Why the reachability gates matter as much as the attribute gate
///
/// `notification_privacy_test.dart` makes the same argument in its own header
/// and is the model here: a gate proving a capability is absent TODAY is worth
/// less than one proving the path does not exist. If the purchase layer cannot
/// see a repository, a supplement stream or a Drift table, then no future
/// helper — a debug label, a "richer" error report, an analytics hook somebody
/// adds in a hurry — can carry a supplement name into an SDK call, because
/// there is nothing to carry.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Every Dart file under [dir], comment-stripped.
///
/// Comments are stripped so that a comment naming a forbidden symbol cannot
/// trip its own gate. This file's own header names all four attribute setters,
/// and the header of `revenuecat_gateway.dart` names them too: without this,
/// the most carefully documented file in the layer would be the one that fails.
Map<String, String> _strippedSourcesUnder(String dir) {
  final root = Directory(dir);
  if (!root.existsSync()) return const <String, String>{};
  return <String, String>{
    for (final file in root
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart')))
      file.path: file
          .readAsLinesSync()
          .where((line) {
            final trimmed = line.trimLeft();
            return !trimmed.startsWith('//');
          })
          .join('\n'),
  };
}

List<String> _filesNaming(Map<String, String> sources, String needle) => [
      for (final entry in sources.entries)
        if (entry.value.contains(needle)) entry.key,
    ];

void main() {
  late Map<String, String> purchases;
  late Map<String, String> features;
  late Map<String, String> lib;

  setUpAll(() {
    purchases = _strippedSourcesUnder('lib/core/purchases');
    features = _strippedSourcesUnder('lib/features');
    lib = _strippedSourcesUnder('lib');
  });

  group('the globs resolve — a gate over an empty file set is worse than no '
      'gate', () {
    test('the purchase layer resolves, and holds the file that imports the '
        'SDK', () {
      expect(purchases, isNotEmpty);
      expect(
        purchases.keys.any((p) => p.endsWith('revenuecat_gateway.dart')),
        isTrue,
        reason: 'the one file that imports purchases_flutter must be in the '
            'set, or the containment gate below is scanning nothing',
      );
    });

    test('the feature tree resolves, and holds the support screen', () {
      expect(features.length, greaterThanOrEqualTo(10));
      expect(
        features.keys.any((p) => p.endsWith('support_screen.dart')),
        isTrue,
      );
    });

    test('lib resolves whole', () {
      expect(lib.length, greaterThanOrEqualTo(30));
    });
  });

  group('no app data can reach RevenueCat', () {
    test('nothing in lib/ sets a subscriber attribute', () {
      const setters = <String, String>{
        'setAttributes': 'the bulk attribute setter',
        'setEmail': 'a reserved attribute',
        'setDisplayName': 'a reserved attribute',
        'setPhoneNumber': 'a reserved attribute',
        'setPushToken': 'a reserved attribute',
      };
      final hits = <String>[];
      setters.forEach((needle, what) {
        for (final path in _filesNaming(lib, needle)) {
          hits.add('$path names $needle ($what)');
        }
      });
      expect(
        hits,
        isEmpty,
        reason: 'subscriber attributes are the ONE channel through which this '
            'app could put data into RevenueCat\'s systems, and they hold '
            'nothing unless something sets one. The privacy policy says '
            'supplement data never leaves the device; this is what makes that '
            'a property of the code rather than an intention. If an attribute '
            'is genuinely needed, docs/legal/privacy.md changes in the SAME '
            'release, per LEGAL-01. Offenders: $hits',
      );
    });

    test('the app never identifies a user to RevenueCat', () {
      // `logIn` would replace the anonymous id with one this app chose, which
      // is the other way an identifier could cross. There is no account system
      // to derive one from, so nothing legitimate needs it.
      final hits = _filesNaming(lib, 'Purchases.logIn');
      expect(hits, isEmpty,
          reason: 'the app has no accounts and uses RevenueCat\'s anonymous '
              'ids only, which is what lets the Apple privacy label say '
              '"not linked to identity". Offenders: $hits');
    });
  });

  group('the purchase layer cannot see app data', () {
    test('no file under lib/core/purchases/ reaches the database or the '
        'domain', () {
      const forbidden = <String, String>{
        'core/db/': 'the Drift database, where every supplement name lives',
        'core/domain/': 'the domain models and the repository interfaces',
        'core/providers.dart': 'the graph that exposes both',
        'supplementsStreamProvider': 'the live list of supplement names',
        'stackEntriesProvider': 'the same list, derived',
        'SupplementRepository': 'the interface that reads them',
      };
      final hits = <String>[];
      forbidden.forEach((needle, what) {
        for (final path in _filesNaming(purchases, needle)) {
          hits.add('$path reaches $needle ($what)');
        }
      });
      expect(
        hits,
        isEmpty,
        reason: 'this is the reachability half, and it is the half that '
            'survives a refactor. The attribute gate above proves nothing '
            'sets an attribute today; this proves that a file which wanted to '
            'put a supplement name into one has nowhere to get it from. '
            'Offenders: $hits',
      );
    });
  });

  group('the plugin stays behind its seam', () {
    test('purchases_flutter is imported by exactly one file', () {
      final importers = _filesNaming(lib, 'package:purchases_flutter');
      expect(
        importers,
        ['lib/core/purchases/revenuecat_gateway.dart'],
        reason: 'the same containment notification_service.dart holds over its '
            'plugin, and for the same two reasons: every plugin call throws '
            'under flutter test, and a seam that leaks its implementation\'s '
            'types stops being a seam the first time a widget reads one',
      );
    });

    test('no file under lib/features/ imports the purchase plugin', () {
      final hits = _filesNaming(features, 'purchases_flutter');
      expect(hits, isEmpty,
          reason: 'the support screen reads TipProduct and calls the '
              'controller. A screen that imported the SDK could open a '
              'purchase sheet outside the state machine that serializes them. '
              'Offenders: $hits');
    });

    test('no file under lib/features/ reads CustomerInfo or an entitlement',
        () {
      const forbidden = ['CustomerInfo', 'EntitlementInfo', 'entitlements'];
      final hits = <String>[];
      for (final needle in forbidden) {
        hits.addAll(_filesNaming(features, needle));
      }
      expect(
        hits,
        isEmpty,
        reason: 'the app sells three consumables that unlock nothing. An '
            'entitlement read in a screen is the first line of a feature gate, '
            'and a feature gate is a product decision that belongs in a spec '
            'rather than in a widget. Offenders: $hits',
      );
    });
  });
}
