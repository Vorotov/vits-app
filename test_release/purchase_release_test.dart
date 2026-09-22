/// What must be true before a build that can take money is uploaded.
///
/// This lives in `test_release/` rather than in `test/` for the reason the
/// README gives: an empty `revenueCatIosKey` is the CORRECT state of the tree
/// between the day the purchase layer lands and the day the dashboard hands
/// over the real key. A red everyday suite through that window would teach
/// everyone to ignore a red everyday suite.
///
/// The prefix checks that guard against shipping a Test Store key run on every
/// `flutter test`, in `test/purchases/revenuecat_key_test.dart`. What is added
/// here is the one assertion that only makes sense at the release boundary:
/// there has to be a key at all.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:vitomy/core/purchases/revenuecat_key.dart';

void main() {
  test('the iOS SDK key is filled in', () {
    expect(
      revenueCatIosKey,
      isNotEmpty,
      reason: 'lib/core/purchases/revenuecat_key.dart still holds the empty '
          'placeholder. A build shipped like this launches fine and reports '
          'that tips are unavailable forever, which is the honest rendering of '
          'a misconfiguration and is indistinguishable, from the outside, from '
          'a store outage. Paste the PUBLIC iOS key (appl_...) from the '
          'RevenueCat dashboard: Project settings, API keys.',
    );
  });

  test('the Android SDK key is deliberately absent', () {
    // Not an oversight and not a placeholder left behind. Android ships after
    // the hackathon (SHIP-01): Play requires twelve testers opted in for
    // fourteen continuous days before a personal account may apply for
    // production access, and that clock has not been started. When it is, this
    // assertion is the one to invert.
    expect(revenueCatAndroidKey, isEmpty);
  });
}
