/// The RevenueCat public SDK key, and the one mistake this file exists to make
/// unshippable.
///
/// ## Why a committed constant and not a secret
///
/// A RevenueCat SDK key is **public by design**: it is compiled into every
/// binary the store distributes, anyone can read it out of an IPA, and
/// RevenueCat's own documentation says to embed it. It authorizes reading an
/// offering and starting a purchase that the store itself then authenticates.
/// It is not the secret key, which lives only in the RevenueCat dashboard and
/// never enters this repository.
///
/// ## The mistake
///
/// RevenueCat also issues **Test Store keys**, prefixed `test_`. They route
/// every purchase to a simulator modal instead of to Apple, and their own
/// documentation is unambiguous: "Never submit an app to the App Store or
/// Google Play that is configured with a Test Store API key." A build shipped
/// with one takes no money and looks, from the inside, exactly like a build
/// that works. This repository was handed a `test_` key once, on 2026-09-22,
/// which is why the check below exists rather than a comment saying to be
/// careful.
///
/// `test/purchases/revenuecat_key_test.dart` rejects a `test_` prefix on every
/// ordinary run. `test_release/purchase_release_test.dart` additionally rejects
/// an EMPTY key, which is what makes forgetting to fill this in a red
/// pre-production gate rather than a silent ship of a screen that can never
/// sell anything.
library;

/// The iOS public SDK key, from the RevenueCat dashboard under Project
/// settings, API keys, the App Store app's **public** key.
///
/// Empty until it is filled in. Empty is a deliberate, gated state: the app
/// launches, the support screen reports that tips are unavailable, and the
/// release gate refuses the build.
const String revenueCatIosKey = '';

/// The Android public SDK key, prefixed `goog_`.
///
/// Empty and expected to stay empty for now. Android ships after the hackathon
/// (SHIP-01), and the Play billing side has its own twelve-testers clock to
/// start first.
const String revenueCatAndroidKey = '';
