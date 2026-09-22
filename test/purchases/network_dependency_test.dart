/// The claim `test/platform_config_test.dart` can no longer make.
///
/// That file reads the SOURCE manifests under `android/app/src/`. It cannot see
/// the merged manifest a build produces, and since `purchases_flutter` landed
/// its own library manifest brings `INTERNET` and `ACCESS_NETWORK_STATE` in
/// automatically. Both of that file's INTERNET assertions stayed green through
/// the change. Left alone, they would have gone on advertising a fully offline
/// app while the app stopped being one, which is the precise failure shape this
/// repository keeps a list of: a test that keeps passing and stops meaning
/// anything.
///
/// So the claim moved here, and it is narrower and checkable. The app's privacy
/// position is no longer "no network at all". It is:
///
/// > Supplement data never leaves the device. The only network traffic is the
/// > purchase, and it carries none of it.
///
/// The first sentence is held by `test/purchases/purchase_privacy_test.dart`.
/// The second sentence is held HERE, by asserting that exactly one dependency
/// in this project can open a socket, and naming it. A second one arriving is
/// the event that would make the sentence false, and a dependency list is the
/// only place it would be visible before it shipped.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Packages that can reach the network, of those this project depends on.
///
/// A deny-list of KNOWN network packages would be worse than useless: it can
/// only ever name what somebody remembered. This instead reads the declared
/// dependency set and subtracts the ones audited as local-only, so a package
/// nobody has classified fails the gate by default and has to be looked at.
const auditedLocalOnly = <String>{
  'flutter',
  'flutter_localizations',
  'cupertino_icons',
  'flutter_riverpod',
  'drift',
  'drift_flutter',
  'path_provider',
  'uuid',
  'shared_preferences',
  'intl',
  'flutter_local_notifications',
  'timezone',
  'flutter_timezone',
};

/// The direct dependencies declared in `pubspec.yaml`.
///
/// Parsed rather than hand-listed, and deliberately only the DIRECT ones: a
/// transitive dependency is the business of the package that pulled it in,
/// while a direct one is a decision somebody made in this repository.
Set<String> declaredDependencies() {
  final lines = File('pubspec.yaml').readAsLinesSync();
  final deps = <String>{};
  var inside = false;
  for (final line in lines) {
    if (line.startsWith('dependencies:')) {
      inside = true;
      continue;
    }
    // Comments are skipped BEFORE the end-of-block test, and that order is the
    // whole subtlety here: pubspec.yaml carries a comment at column zero
    // INSIDE the dependency block (the note explaining why intl is unpinned).
    // Treating it as a top-level key ends the scan early and silently drops
    // every dependency below it, which is how the first draft of this gate
    // reported five packages and passed its own self-proof.
    if (line.trimLeft().startsWith('#')) continue;
    // Any other top-level key ends the block.
    if (inside && line.isNotEmpty && !line.startsWith(' ')) break;
    if (!inside) continue;
    final match = RegExp(r'^  ([a-z0-9_]+):').firstMatch(line);
    if (match != null) deps.add(match.group(1)!);
  }
  return deps;
}

void main() {
  test('the dependency block resolves — a gate over an empty set is worse than '
      'no gate', () {
    final declared = declaredDependencies();
    expect(
      declared.length,
      greaterThanOrEqualTo(10),
      reason: 'parsing pubspec.yaml produced $declared, which is too small to '
          'be the real dependency block. The parser broke and every assertion '
          'below is scanning nothing',
    );
    expect(declared, contains('drift'));
    expect(declared, contains('flutter_riverpod'));
  });

  test('exactly one dependency can reach the network, and it is the purchase '
      'SDK', () {
    final unaudited = declaredDependencies().difference(auditedLocalOnly);
    expect(
      unaudited,
      <String>{'purchases_flutter'},
      reason: 'the app tells its users that supplement data never leaves the '
          'device and that the only network traffic is the purchase. Every '
          'dependency above is audited as local-only, so anything else in '
          '$unaudited is either a second way out of the device — which makes '
          'that sentence false and requires docs/legal/privacy.md to change in '
          'the SAME release, per LEGAL-01 — or a new local-only package that '
          'belongs in the audited set with a reason. Decide which, here, in '
          'the diff that adds it',
    );
  });

  test('the paywall UI package is absent, and staying absent', () {
    expect(
      declaredDependencies(),
      isNot(contains('purchases_ui_flutter')),
      reason: 'RevenueCat Paywalls do not support consumable products, and the '
          'app sells three consumables. The package would also raise Android '
          'minSdk from 21 to 24 and force MainActivity to extend '
          'FlutterFragmentActivity, both of which are real costs for a screen '
          'it cannot draw. The support screen is hand-built from the design '
          'tokens (SHIP-01, decided 2026-09-22)',
    );
  });
}
