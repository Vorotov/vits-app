# RevenueCat for Shipaton 2026 — research

Date: 2026-09-09. Researched against pub.dev, revenuecat.com/docs, the
purchases-flutter and purchases-android repositories, the Shipaton Devpost
rules, and Google Play's testing-requirements policy page. Repo facts were
read from this tree, not remembered.

## 1. The clock, and what it forces

Shipaton 2026 submissions close **30 September 2026, 11:45pm PDT** — 21 days
from today. Judging runs 1–13 October; winners 21 October. Submissions go
through Devpost.

Two rules decide the shape of the work:

- The app must be **fully published** on the App Store, Google Play or the
  Samsung Galaxy Store by the deadline. TestFlight and internal testing are
  named and excluded.
- The app must use **the RevenueCat SDK to power at least one in-app or web
  purchase**. Installing the SDK is not enough; a paywall backed by a
  configured product is the stated minimum.

VitoMy passes the rule that disqualifies most existing projects: a project
may predate the submission period, but its **first public store release** must
happen inside it. VitoMy has never shipped, so the existing codebase is an
asset rather than a disqualification.

**Android is out of reach.** Personal Play developer accounts created after
13 November 2023 must run closed testing with 12 testers opted in
*continuously* for 14 days before they may apply for production access, and
that application then takes up to 7 more days. 14 + 7 = 21, landing exactly on
the deadline with zero slack, and only if twelve testers were opted in today
against a build that is not in closed testing. RevenueCat's own prep guide told
entrants to be in closed testing by 1 September. That window is closed.

So: **ship iOS only.** The rules are satisfied by one eligible store. The Play
14-day clock can start in parallel any time and land after the hackathon.

This makes **Apple Developer Program enrolment the critical path.** First
submissions from new accounts commonly take 3–7 days rather than the usual
24–48 hours, each rejection costs another cycle, and identity verification on a
new individual account can stall for days. Nothing else in this document
matters if that has not been started.

## 2. Packages

| Package | Version | Notes |
|---|---|---|
| `purchases_flutter` | 10.11.0 (published 2026-09-03) | MIT, verified publisher revenuecat.com |
| `purchases_ui_flutter` | 10.11.0 | RevenueCat Paywalls; depends on `purchases_flutter: ^10.11.0` |

Constraints: Dart `>=3.4.0 <4.0.0`, Flutter `>=3.22.0`. This tree is Flutter
3.47 / Dart 3.13 — comfortably inside.

**Neither package uses code generation.** No builder, no `build.yaml`, no
generator dev-dependency. The existing `build_runner` pipeline stays
Drift-only, which is one of the few integration risks that turns out not to
exist.

Platform floors:

- iOS **13.0** for the SDK (the package README; the docs installation page
  still says 11.0 and is stale), **15.0** for Paywalls and for Offline
  Entitlements, both of which need StoreKit 2. This tree already sets
  `IPHONEOS_DEPLOYMENT_TARGET = 15.0` in all three build configurations, so
  every floor is already met. There is no committed Podfile; Flutter generates
  one and the Xcode deployment target governs.
- Android minSdk **21** for the SDK, **24** for `purchases_ui_flutter`. Not
  blocking an iOS-only ship, but it raises the app's floor whenever Android
  follows.
- Neither plugin needs core library desugaring, so the
  `flutter_local_notifications` desugaring setup is untouched.
- Android Paywalls additionally require `MainActivity` to extend
  **`FlutterFragmentActivity`**. This tree's `MainActivity.kt` extends
  `FlutterActivity`. A one-line change, needed only when Android ships.

## 3. Where the code goes

Three insertion points, and the codebase already has a precedent for each.

### 3.1 Configuration goes behind the first frame

`Purchases.configure()` is async and must be awaited before any other SDK
call, but **nothing requires it before the first frame.** It must not go in
`main()`: two tests gate that window at exactly two awaits
(`notification_routing_test.dart` counts them,
`notification_bootstrap_test.dart` is a needle gate over the same window).

The shape to copy is `notificationBootstrapProvider`
(`lib/core/notifications/notification_providers.dart`): a `Notifier<bool>` that
runs from a post-first-frame callback and reports when it is done, watched by
`VitomyApp` purely to keep it alive because an unlistened provider is paused
in this Riverpod version. A `purchasesBootstrapProvider` with the same
structure is the right answer, and its `bool` state is not decoration — see
the race below.

### 3.2 The SDK sits behind an interface

Every `Purchases.*` call is a method channel, so in `flutter test` it throws
`MissingPluginException`. RevenueCat publishes no Flutter test harness.

This repo already solved that class of problem twice: the three repository
interfaces in `core/domain/repositories.dart` with Drift as one
implementation, and `NotificationScheduler` with `PluginNotificationScheduler`
wired through a provider override in `main()`. A `PurchaseGateway` interface in
`lib/core/purchases/` with a RevenueCat-backed implementation, overridden in
`main()` the way `notificationSchedulerProvider` is, keeps `Purchases` out of
every widget tree and lets the 1104-test suite stay green without touching a
channel.

It does **not** belong in `core/domain/` — that directory imports nothing
outside `dart:core`, and the gateway needs the plugin's types at its
implementation edge. `core/purchases/`, mirroring `core/notifications/`, is
the correct home.

### 3.3 Entitlement state is watched as state, never as a notifier

A `Notifier<bool>` (or a small sealed state, if "loading" needs to be
distinguishable from "not subscribed") fed by
`Purchases.addCustomerInfoUpdateListener`. Widgets watch the **value**.
`ref.watch(provider.notifier)` rebuilds only when the notifier instance
changes, which it does not — that exact mistake already shipped once in this
app with the first-run hints and left a dismissed card on screen.

## 4. Four traps

**The configure race is real, not theoretical.** Calling `getOfferings()` or
`getCustomerInfo()` while an async `configure()` is still in flight throws
`UninitializedPropertyAccessException: There is no singleton instance`.
It is reported against purchases-flutter twice (issues #1090, #1187) and has
its own error page at errors.rev.cat/configuring-sdk. This is precisely why the
bootstrap provider should expose a completion flag and why the paywall entry
point must be unreachable until it flips.

**The anonymous ID does not survive reinstall.** RevenueCat generates a random
App User ID prefixed `$RCAnonymousID:` — random, *not* derived from a device
identifier — held in the SDK's local cache. Deleting the app clears it and the
next launch gets a new one. That creates an asymmetry worth designing around:
this app's DATA-02 guarantee is that the user's data survives a reinstall
through the OS backup, so after a reinstall their supplements come back and
their subscription does not, until they tap Restore.

**Anonymous restore covers auto-renewing subscriptions only.** For an
anonymous user, RevenueCat re-reads the store receipt and attaches
auto-renewing subscriptions; consumables and non-renewing subscriptions need a
custom App User ID, which this app has no way to produce without an account
system. **This decides the product**: a one-time "lifetime unlock"
non-consumable would leave reinstalling users stranded. Sell an auto-renewing
subscription.

A visible **Restore** control is also required in practice. Apple's guideline
3.1.1 is worded as "should", but reviewers reject subscription apps that lack
one, and it is the natural companion to the reinstall gap above. It belongs in
Settings, next to `_ShowIntroAgainRow`.

**`platform_config_test.dart` will stay green while its claim stops being
true.** `purchases-android`'s own library manifest declares
`android.permission.INTERNET` and `android.permission.ACCESS_NETWORK_STATE`,
and `com.android.vending.BILLING` is embedded in the Play Billing AAR. All
three merge in automatically; you never declare them. (The RevenueCat Flutter
installation page still instructs you to add BILLING by hand — that is stale,
contradicted by purchases-android #637.)

The test reads the **source** manifests under `android/app/src/*/`, not the
merged manifest the build produces. So the day the plugin lands, an Android
release build ships with INTERNET while both of that file's INTERNET
assertions stay green — the gate keeps passing and stops meaning anything.
This is the same failure shape as the needle gate defeated by a named helper
in the "tests that are wrong" list. The honest fix is to assert against the
merged manifest under `build/app/intermediates/merged_manifests/`, or, if that
is too build-dependent for a unit test, to rewrite the assertion's expectation
and its stated reason in the same commit that adds the dependency. Do not let
it sit green.

## 5. What the network changes

Nothing in the SDK works without a network on a device that has never been
online: configure, offerings, purchases and receipt validation all need
`api.revenuecat.com`. **Offline Entitlements** then covers later launches
automatically, with no opt-in code — the SDK computes entitlements on-device
from store data when RevenueCat is unreachable — but only for subscriptions,
only on iOS 15+/StoreKit 2 or Google Play, and only after at least one launch
with servers reachable to download the product-to-entitlement mapping.
CustomerInfo is cached locally and refreshed when older than five minutes.

The first-ever-offline launch throwing is an inference from that precondition,
not a documented case; treat it as a real path and gate the paywall behind
your own error state. RevenueCat also does not document what the paywall does
when offerings cannot be fetched at all — the documented fallback (a default
paywall listing the offering's packages) covers only the case where an offering
exists but has no paywall configured.

### What must change in the app's story

The claim "the App does not connect to the internet" becomes false. The
narrower claim that replaces it is still unusual and still true:

> Your supplement data never leaves your device. The only network traffic is
> your subscription, and it carries none of it.

That is testable in the same way the notification privacy rule is. RevenueCat's
**subscriber attributes** are the only place app data could leak into their
system — they contain nothing unless you set them — so a gate asserting the app
never calls `setAttributes` (and never passes a supplement, regimen or intake
value into any SDK call) keeps the claim honest by construction. Worth writing
alongside `test/notifications/notification_privacy_test.dart`.

### Data collected, and the store labels

By default RevenueCat collects **purchase and receipt history only**, plus
IDFV and the IP address it uses to infer country. It does **not** collect IDFA
unless an attribution integration is explicitly enabled. Subscriber attributes
hold only what you put in them. RevenueCat is a processor; you are the
controller (their DPA and GDPR pages exist for this).

- **Apple App Privacy**: declare Purchases → **Purchase History**, purposes
  Analytics *and* App Functionality, **Linked to identity: No** while the app
  uses anonymous IDs only. Device ID only if an advertising integration is
  added later.
- **Google Play Data safety**: declare **Purchase history**, collected, not
  shared, encrypted in transit.

Both flip from today's honest "Data Not Collected".

### The legal documents

`docs/legal/privacy.md` and `docs/legal/terms.md` were written to describe a
build with no SDKs and no subscription, and `.planning/STATE.md` carries this
as LEGAL-01: the release that adds analytics or a subscription must extend
both documents and both store labels **in the same release**. The clause bank
for the subscription and third-party sections is
`docs/legal/2026-09-07-privacy-and-terms-research.md` §7 (Pawmi ToS §11 and
the BetterMe auto-renewal notice). The sections that go stale on day one:

- privacy "The short version" — the no-internet sentence
- privacy "What we receive" — currently "Through the App: nothing"
- privacy "What we do not do" — currently "no advertising or tracking SDK"
- privacy "International transfers" — currently "we transfer nothing"
- privacy "Third-party services" — RevenueCat as a named processor
- terms — a subscription section, which today does not exist at all

`test_release/legal_copy_safety_test.dart` will keep the new text clean of
health vocabulary; nothing checks it for accuracy, which is why LEGAL-01 exists.

## 6. What to sell — a tip is enough, and it is the cheap path

The Shipaton requirement is generic. Verbatim: entrants must "create a working
software application that uses the RevenueCat SDK to power **at least one
in-app or web purchase**, or that serves ads through RevenueCat Ads." Nothing
on the rules page requires the purchase to unlock anything, to be recurring, or
to gate a feature. **A single consumable tip satisfies it.**

### Apple permits developer tips explicitly

Guideline 3.1.1, verbatim: "Apps may use in-app purchase currencies to enable
customers to 'tip' the developer or digital content providers in the app." And
an in-app purchase is not obliged to deliver anything — 3.1.1's "features or
functionality" sentence is conditional ("**If** you want to unlock features or
functionality within your app… you must use in-app purchase"). It compels IAP
when you unlock; it does not compel unlocking.

Three conditions come with that:

- **It must go through IAP.** The non-IAP carve-out in 3.2.1(vii) is for gifts
  from one *user to another user*, not to the app's own developer, and 3.1.3's
  reader/person-to-person/physical-goods categories do not cover it. Rejections
  in this area cluster entirely on money leaving through an external link — a
  "Buy Me a Coffee" link and a Safari donation hand-off are both documented
  rejections. An IAP tip jar being rejected *for being a tip jar* has no
  corroborated case.
- **The copy is load-bearing.** 3.2.2(iv) bans collecting funds for charities
  and fundraisers inside the app unless you are an approved nonprofit; such
  apps "must be free on the App Store and may only collect funds outside of the
  app." So the word is **support** or **tip**, never **donate** or
  **donation**. This app already treats copy as something that carries
  liability; this is the same discipline pointed at a different guideline.
- **Consumable is the product type**, because a tip should be repeatable.
  Consumables are not restorable, which means 3.1.1's restore expectation
  ("for any *restorable* in-app purchases") does not apply — **no Restore
  control is needed**, and the anonymous-ID reinstall problem from §4
  disappears with it. The only cost is attribution: a re-installing tipper is
  counted as a new customer. The revenue still records.

### What this removes from the build

Against the subscription plan, a tip jar deletes: the entitlement state
provider, every feature gate, the Restore row, the reinstall edge case, and all
the widget tests that would have had to cover a locked and unlocked planner.
What remains is the bootstrap provider, the gateway interface, and one screen.

Two things it does **not** remove: everything in §5 (the INTERNET merge, the
`platform_config_test.dart` fix, the legal documents, the privacy labels) is
identical either way, because they follow from the SDK existing at all.

### What it costs

- **RevenueCat Paywalls do not support consumables.** RevenueCat staff
  confirmed this and no changelog entry since adds it, so `purchases_ui_flutter`
  is out and the tip screen is hand-built with `purchases_flutter` plus an
  offering. For this app that is a gain rather than a loss: the screen is built
  from the design tokens like everything else, which is the right answer for
  the Design Award anyway.
- **No entitlement, deliberately.** RevenueCat's own guidance is that attaching
  a consumable to an entitlement makes it "report that entitlement as unlocked
  (forever), even after one purchase." A tip gets an offering and a package and
  no entitlement.
- **The judge clause reads oddly.** The rules require that "the app must either
  offer a free trial or the Entrant must include a promo code for judges to
  unlock the in-app purchase and test all premium features." With no premium
  features this is moot rather than unsatisfiable — the whole app is free — but
  it presupposes gating, and the rules do not say how it is scored when there
  is nothing to unlock. Worth a sentence in the Devpost write-up saying so
  plainly rather than leaving a judge to wonder.
- Monetization-judged categories (HAMM) are out. The two realistic targets,
  the Design Award and #BuildInPublic, do not judge the business model.

### The alternative, if a real product is wanted

Pro unlocks the Cycles and Year planner; Stack, Today, marking doses and
reminders stay free. It keeps CLAUDE.md's stated Core Value free and gates the
part that is genuinely differentiated and already built. It must be an
**auto-renewing subscription** (§4: anonymous restore covers nothing else), and
it brings back the entitlement provider, the gates, the Restore row and their
tests.

**Avoid either way: a cap on how many supplements can be added.** This app
deliberately removed a five-substance editorial limit for liability reasons,
and `test/l10n/planner_copy_safety_test.dart` bans the words *limit*, *exceed*,
*threshold*, *maximum* and *too many* from its copy. A free-tier cap would
reintroduce exactly that vocabulary in an app about supplement intake, where
"you have reached your limit" reads as a claim about the user's body rather
than their plan. The gate would catch the words; it would not catch the idea.

## 7. The hidden schedule blocker: Paid Apps Agreement

Nothing can be sold — and **no in-app purchase can even be tested in the
sandbox** — until the Paid Apps Agreement is in effect, banking information is
entered, and tax forms are filed in App Store Connect. The order is forced: the
tax forms only appear after the agreement is signed, and the bank account has
to reach "Clear" status before purchases work.

Activation is reported at roughly 24 hours once everything is complete
(secondary source; Apple publishes no SLA), but bank verification and the tax
form are the parts that stretch to days, and a non-US filer's W-8 is the usual
delay. **This is day-one work, in parallel with Developer Program enrolment.**
It is easy to miss because it looks like paperwork rather than a dependency,
and it silently blocks every sandbox purchase test.

## 8. A 21-day shape

Ordered by what blocks what, not by effort.

1. **Today, in parallel**: (a) Apple Developer Program enrolment, if not
   already done; (b) the Paid Apps Agreement, banking and tax forms from §7;
   (c) decide the app name and bundle id — `app.vitomy` becomes permanent
   the moment the App Store Connect record is created, and the `.dev` suffix
   would be stuck on a shipping product.
2. Create the App Store Connect record and the consumable tip product (or the
   subscription group and its introductory trial, if going that route).
   Configure the RevenueCat project, product, package and offering. No
   entitlement for a tip.
3. Add `purchases_flutter`. Write the `PurchaseGateway` interface, the
   RevenueCat implementation, and the bootstrap provider. Override the gateway
   in `main()`.
4. Build the support screen from the design tokens, reached from Settings
   alongside `_ShowIntroAgainRow`. Copy in all seven ARB files, and the word is
   "support", never "donate".
5. Fix `platform_config_test.dart` honestly, and add the no-attributes privacy
   gate. Keep `flutter test` and `flutter test test_release/` green.
6. Update both legal documents, `.planning/STATE.md` LEGAL-01, and the Apple
   privacy label. These ship with the binary or the policy is false.
7. Icon at 1024×1024, at least one screenshot at 1179×2556 with no device
   frame, demo video under two minutes on YouTube or Vimeo, Devpost write-up.
8. Submit with slack for at least one rejection cycle.

## 9. Open decisions

1. App name and bundle id. Blocking step 2, and irreversible.
2. Tip jar or the planner subscription. Recommendation: tip, on this timeline.
3. Tip tiers and prices, if a tip.
4. Whether to start the Play closed-testing clock now in parallel, so Android
   can follow shortly after the hackathon rather than months later.

## Sources

Shipaton: [Devpost rules](https://revenuecat-shipaton-2026.devpost.com/rules),
[Devpost overview](https://revenuecat-shipaton-2026.devpost.com/),
[prep guide](https://revenuecat.github.io/codelabs/shipaton-2026-prep.html),
[Play testing requirements](https://support.google.com/googleplay/android-developer/answer/14151465).

SDK: [purchases_flutter](https://pub.dev/packages/purchases_flutter),
[purchases_ui_flutter](https://pub.dev/packages/purchases_ui_flutter),
[configuring the SDK](https://www.revenuecat.com/docs/getting-started/configuring-sdk),
[identifying customers](https://www.revenuecat.com/docs/customers/identifying-customers),
[restoring purchases](https://www.revenuecat.com/docs/getting-started/restoring-purchases),
[customer info](https://www.revenuecat.com/docs/customers/customer-info),
[offline entitlements](https://www.revenuecat.com/blog/engineering/introducing-offline-entitlements),
[Apple App Privacy](https://www.revenuecat.com/docs/platform-resources/apple-platform-resources/apple-app-privacy),
[Play Data safety](https://www.revenuecat.com/docs/platform-resources/google-platform-resources/google-plays-data-safety),
[Paywalls](https://www.revenuecat.com/docs/tools/paywalls),
[purchases-android manifest](https://github.com/RevenueCat/purchases-android/blob/main/purchases/src/main/AndroidManifest.xml),
[purchases-android #637](https://github.com/RevenueCat/purchases-android/issues/637),
[purchases-flutter #1090](https://github.com/RevenueCat/purchases-flutter/issues/1090),
[App Store Review Guidelines](https://developer.apple.com/app-store/review/guidelines/),
[in-app purchase types](https://developer.apple.com/help/app-store-connect/reference/in-app-purchase-types/),
[receiving payments](https://developer.apple.com/help/app-store-connect/getting-paid/overview-of-receiving-payments),
[non-subscription purchases](https://www.revenuecat.com/docs/platform-resources/non-subscriptions),
[entitlements](https://www.revenuecat.com/docs/getting-started/entitlements).

## Confidence notes

- Apple Developer Program enrolment duration is not confirmed from a primary
  Apple source; the 3–7 day first-review figure comes from third-party
  reporting.
- "RevenueCat Paywalls are not required by the rules" is inferred from the
  rules not mentioning them, not from an explicit exemption.
- The first-ever-launch-offline failure of `getCustomerInfo()` follows from
  the offline-entitlements precondition rather than from an explicit statement.
- The claim that `platform_config_test.dart` stays green was read off that
  file's use of the source manifest directory, and should be confirmed by
  running it once the dependency is added.
