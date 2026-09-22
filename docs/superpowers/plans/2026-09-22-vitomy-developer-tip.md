# Developer Tip Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Sell three consumable developer tips through RevenueCat, from a
screen reached out of Settings, and keep every privacy claim the app makes
true in the same release.

**Architecture:** A `PurchaseGateway` interface in `lib/core/purchases/` with a
no-op default and one plugin-backed implementation overridden in `main()`, a
bootstrap provider that runs `Purchases.configure()` behind the first frame and
exposes a completion flag, and a hand-built support screen. No entitlement, no
feature gate, no Restore control, no paywall UI package. Shaped so an
auto-renewing subscription can be added on top later without rewriting the seam.

**Tech Stack:** Flutter 3.47 / Dart 3.13, `purchases_flutter` 10.11.0,
Riverpod 3 hand-written providers, gen-l10n ARB.

**Spec:** `docs/research/2026-09-09-revenuecat-shipaton.md` sections 3, 4, 5 and
6, plus the SHIP-01 decisions in `.planning/STATE.md`. Read section 4 before
Task 2 and section 5 before Task 6.

## Global Constraints

- **Three consumables, no entitlement.** `app.vitomy.tip.small` 0.99,
  `app.vitomy.tip.medium` 1.99, `app.vitomy.tip.large` 4.99 (lowered from
  2.99 / 4.99 / 9.99 on 2026-09-22, at the owner's call). Nothing in the app
  unlocks. The `vitomy_supps_vits_tracker_pro` entitlement and the Monthly and
  Yearly products exist in the RevenueCat dashboard and are deliberately unused.
- **No `purchases_ui_flutter`.** RevenueCat Paywalls do not support consumables,
  and the package raises Android minSdk to 24 and requires
  `FlutterFragmentActivity`. The screen is hand-built from the design tokens.
- **The words "donate" and "donation" never appear**, in code, copy, ARB files
  or store metadata. Apple guideline 3.2.2(iv). The word is "support" or "tip".
- **Never a price literal in Dart or ARB.** Prices are read from the store
  through `Package.storeProduct.priceString`, already localized and already
  currency-correct.
- **No health or medical vocabulary** anywhere in the new copy.
  `test_release/legal_copy_safety_test.dart` and
  `test/l10n/planner_copy_safety_test.dart` both run over it.
- **No em dash or en dash** in ARB copy or in legal markdown.
- **No hex literal outside `tokens.dart`.** Colour comes from `BqColors`.
- **Line comments only.** This codebase writes no block comments and a gate
  asserts it.
- **Directional padding only.** `EdgeInsetsDirectional`, never `.only()` on a
  plain `EdgeInsets`. Arabic ships.
- **Every user-visible string is an ARB key in all seven files**, 177 keys
  today, and each language carries its own CLDR plural categories.
- `flutter analyze` clean, `flutter test` green, `flutter test test_release/`
  green before the build. The two suites do not see each other.
- The repo has **no remote**. Commit locally, never push.

---

### Task 1: The seam, its value types and the no-op

**Files:**
- Create: `lib/core/purchases/purchase_gateway.dart`
- Test: `test/purchases/purchase_gateway_test.dart`

**Interfaces:**
- Consumes: nothing.
- Produces: `abstract class PurchaseGateway` with
  `Future<void> configure()`, `Future<List<TipProduct>> tips()`,
  `Future<TipPurchaseResult> buy(String productId)`;
  `class TipProduct { final String id; final String priceString; }`;
  `enum TipPurchaseResult { bought, cancelled, failed }`;
  `class NoopPurchaseGateway extends PurchaseGateway`.

The seam speaks **product ids and already-formatted price strings**, never
RevenueCat types. That is what keeps `purchases_flutter` importable from exactly
one file, the same rule `NotificationScheduler` holds for the notification
plugin. `TipPurchaseResult` distinguishes `cancelled` from `failed` because a
user who backs out of the sheet must see nothing at all, while a genuine failure
earns a message.

- [ ] **Step 1: Write the failing test**

```dart
test('the no-op gateway offers nothing and buys nothing', () async {
  const gateway = NoopPurchaseGateway();
  await gateway.configure();
  expect(await gateway.tips(), isEmpty);
  expect(await gateway.buy('app.vitomy.tip.small'), TipPurchaseResult.failed);
});
```

- [ ] **Step 2: Run it and watch it fail**

Run: `flutter test test/purchases/purchase_gateway_test.dart`
Expected: FAIL, `NoopPurchaseGateway` is not defined.

- [ ] **Step 3: Write the interface, the value types and the no-op**

The no-op returns `failed` rather than `bought` for the same reason
`NoopNotificationScheduler` does nothing rather than pretending: a forgotten
override in `main()` must not look like a working purchase in production.

- [ ] **Step 4: Run the test and watch it pass**

- [ ] **Step 5: Commit**

```bash
git add lib/core/purchases/purchase_gateway.dart test/purchases/purchase_gateway_test.dart
git commit -m "feat(purchases): the gateway seam, its value types and the no-op"
```

---

### Task 2: The graph, and the bootstrap behind the first frame

**Files:**
- Create: `lib/core/purchases/purchase_providers.dart`
- Test: `test/purchases/purchase_providers_test.dart`

**Interfaces:**
- Consumes: `PurchaseGateway`, `TipProduct`, `TipPurchaseResult` from Task 1.
- Produces: `purchaseGatewayProvider` (`Provider<PurchaseGateway>`, defaults to
  `NoopPurchaseGateway`), `purchaseBootstrapProvider`
  (`NotifierProvider<PurchaseBootstrap, bool>` whose value is "configure has
  completed"), `tipProductsProvider`
  (`FutureProvider<List<TipProduct>>` that returns empty while the bootstrap
  flag is false).

**The completion flag is load-bearing, not decoration.** Calling any SDK method
while `configure()` is still in flight throws `There is no singleton instance`
(purchases-flutter issues #1090 and #1187). `tipProductsProvider` watches the
flag and returns empty until it flips, and the support screen's buy button is
disabled while the list is empty. That is the whole race, closed structurally.

Configure runs from a post-first-frame callback the way
`notificationBootstrapProvider` does, for the same reason: it is a network round
trip with no frame-1 dependency.

- [ ] **Step 1: Write the failing tests**

```dart
test('tips stay empty until the bootstrap flag flips', () async {
  final container = ProviderContainer(overrides: [
    purchaseGatewayProvider.overrideWithValue(recorder),
  ]);
  addTearDown(container.dispose);
  expect(container.read(tipProductsProvider).value, isEmpty);
  expect(recorder.tipsCalls, 0,
      reason: 'asking the SDK for offerings before configure completes is the '
          'documented way to get "There is no singleton instance"');
  await container.read(purchaseBootstrapProvider.notifier).bootstrap();
  expect(container.read(purchaseBootstrapProvider), isTrue);
});

test('a configure failure leaves the flag false and reports, never throws',
    () async { /* recorder throws on configure */ });
```

- [ ] **Step 2: Run them and watch them fail**

- [ ] **Step 3: Write the providers**

The catch around `configure()` takes the same stance `NotificationBootstrap`
does and for the same reason spelled out there: a subsystem carrying one feature
may not hold the launch hostage. A tip that cannot be offered costs a tip.

- [ ] **Step 4: Run the tests and watch them pass**

- [ ] **Step 5: Commit**

---

### Task 3: The plugin-backed gateway, the dependency, and the manifest gate that would have gone quietly false

**Files:**
- Create: `lib/core/purchases/revenuecat_gateway.dart`
- Modify: `pubspec.yaml`, `lib/main.dart`
- Modify: `test/platform_config_test.dart:157-260`
- Test: `test/purchases/network_dependency_test.dart`

**Interfaces:**
- Consumes: `PurchaseGateway` from Task 1, `purchaseGatewayProvider` from Task 2.
- Produces: `class RevenueCatGateway extends PurchaseGateway`, the ONLY file in
  `lib/` permitted to import `package:purchases_flutter`.

**The trap this task exists to not fall into.** `purchases-android`'s own
library manifest declares `INTERNET` and `ACCESS_NETWORK_STATE`, and they merge
into the built manifest automatically. `test/platform_config_test.dart` reads
the **source** manifests under `android/app/src/*/`, so the day this dependency
lands, an Android release build ships with INTERNET while both of that file's
INTERNET assertions stay green. The gate keeps passing and stops meaning
anything. Rewrite its expectation **and its stated reason** in this commit, and
add the new gate below so the claim is still guarded by something.

- [ ] **Step 1: Write the failing network-dependency gate**

```dart
test('exactly one network-capable dependency, named', () {
  // Parsed out of pubspec.yaml, not hand-listed. The app's privacy claim is
  // now "supplement data never leaves the device and the only traffic is the
  // purchase". A second network package arriving is what would make that
  // false, and this is the only place it would be visible.
  expect(networkCapableDependencies(), <String>{'purchases_flutter'});
});
```

- [ ] **Step 2: Run it and watch it fail**

- [ ] **Step 3: Add the dependency**

```bash
flutter pub add purchases_flutter
```

Do NOT add `purchases_ui_flutter`. See Global Constraints.

- [ ] **Step 4: Write `RevenueCatGateway`**

`configure()` calls `Purchases.setLogLevel(LogLevel.info)` then
`Purchases.configure(PurchasesConfiguration(apiKey))`. `tips()` reads
`getOfferings()`, takes `current`, maps `availablePackages` to `TipProduct` with
`storeProduct.priceString` verbatim. `buy()` calls `purchasePackage` and maps
`PurchasesErrorHelper.getErrorCode(e)`: `purchaseCancelledError` becomes
`cancelled`, everything else `failed`.

**It never calls `setAttributes`, never calls `logIn`, and never passes a
supplement, regimen or intake value into any SDK call.** Task 5 turns that into
a gate.

- [ ] **Step 5: Override the gateway in `main()`**

Alongside the five overrides already there, as a named top-level function the
way `_pluginScheduler` is, so a source gate and a reviewer's grep both find it.
**No new `await` may appear above `runApp`** — two tests count and needle that
window.

- [ ] **Step 6: Rewrite the manifest assertions honestly**

Both the forbidden-permission map and the `internetVariants` set equality. The
new expectation names `purchases_flutter` as the reason INTERNET is now in the
merged manifest, and says what is still true: the app declares none of it
itself, and no other network dependency exists.

- [ ] **Step 7: Run everything**

Run: `flutter test && flutter analyze`
Expected: green, with the rewritten assertions passing for the new stated reason.

- [ ] **Step 8: Commit**

---

### Task 4: Tip copy, in all seven ARB files

**Files:**
- Modify: `lib/core/l10n/arb/app_en.arb` (template, the only file with `@`
  metadata), then `app_ar.arb`, `app_es.arb`, `app_fr.arb`, `app_hi.arb`,
  `app_uk.arb`, `app_zh.arb`
- Test: `test/l10n/arb_parity_test.dart` already covers this; no new test file.

**Interfaces:**
- Produces: `settingsSupportTitle`, `supportTitle`, `supportBody`,
  `supportTipSmall`, `supportTipMedium`, `supportTipLarge`, `supportThanks`,
  `supportUnavailable`, `supportFailed`. Nine keys, 177 becomes 186 per file.

Write the template first; the other six are translations of it. In the commit
message, name the word each language avoided and why, the way the planner copy
commits do. No "donate" in any language, including its natural translation.

- [ ] **Step 1: Write the English template with `@` metadata**
- [ ] **Step 2: Run the parity gate and watch it fail for the six others**

Run: `flutter test test/l10n/arb_parity_test.dart`
Expected: FAIL, six files short nine keys each.

- [ ] **Step 3: Translate into the other six**
- [ ] **Step 4: Run the parity, plurals and copy-safety gates**

Run: `flutter test test/l10n/`
Expected: green.

- [ ] **Step 5: Commit**

---

### Task 5: The support screen, and its row in Settings

**Files:**
- Create: `lib/features/support/support_screen.dart`
- Modify: `lib/features/settings/settings_screen.dart` (a row beside
  `_ShowIntroAgainRow`)
- Test: `test/features/support_screen_test.dart`

**Interfaces:**
- Consumes: `tipProductsProvider`, `purchaseBootstrapProvider` from Task 2, the
  nine ARB keys from Task 4.

**Its own feature directory, not `lib/features/settings/`.** That feature's glob
gate in `test/features/settings_screen_test.dart` applies every one of its
assertions to every file it finds, and the tip screen is not a settings screen.
`lib/features/onboarding/` is the precedent for a small feature owning its
directory.

Three tips as a column of rows, each a 44px-minimum target showing the label and
the store's own price string. No price in the code. While the list is empty the
rows render disabled with `supportUnavailable`, which is also the honest state
on a device that has never been online. A successful purchase replaces the list
with `supportThanks` and nothing is persisted: a consumable tip is an event, not
a setting, and storing "has tipped" would create a reinstall asymmetry for no
gain.

- [ ] **Step 1: Write the failing render matrix**

The bilingual matrix at textScaler 1.0 / 1.6 / 2.0, copied in shape from the
`bilingual render matrix` group in `test/features/today_screen_test.dart`. Seed
`SharedPreferences` with `onboarding_seen` and `first_run_hints_seen` or the
intro appears in the middle of the assertion.

- [ ] **Step 2: Run it and watch it fail**
- [ ] **Step 3: Build the screen from the tokens**

Load the `vitomy-design` skill first. No elevation, pill radius on the tip rows,
`BqColors` only, `EdgeInsetsDirectional` only.

- [ ] **Step 4: Add the Settings row and its semantics**
- [ ] **Step 5: Run the widget tests and the hardcoded-strings gate**

Run: `flutter test test/features/ test/l10n/no_hardcoded_strings_test.dart`

- [ ] **Step 6: Commit**

---

### Task 6: The privacy gate that keeps the claim true by construction

**Files:**
- Test: `test/purchases/purchase_privacy_test.dart`

**Interfaces:**
- Consumes: every file under `lib/core/purchases/` and `lib/features/support/`.

Modelled on `test/notifications/notification_privacy_test.dart`, which proves a
PROPERTY rather than an absence of capability. Four source gates over the
comment-stripped sources:

1. No file under `lib/` names `setAttributes`, `setEmail`, `setDisplayName`,
   `setPhoneNumber`, `setPushToken` or any `setAttribute`-prefixed symbol.
   Subscriber attributes are the only place app data could reach RevenueCat's
   systems, and they hold nothing unless something sets them.
2. No file under `lib/core/purchases/` imports `core/db/`, `core/domain/` or
   any repository or supplement-stream provider. The purchase layer has no
   reachable path to a supplement name.
3. `package:purchases_flutter` resolves in exactly one file,
   `revenuecat_gateway.dart`.
4. No file under `lib/features/` imports `purchases_flutter`.

Each gate proves its glob first. A gate over an empty file set is worse than no
gate.

- [ ] **Step 1: Write the four gates, each preceded by its glob self-proof**
- [ ] **Step 2: Run and watch all five pass**
- [ ] **Step 3: Commit**

---

### Task 7: Both legal documents, both store labels, and the site

**Files:**
- Modify: `docs/legal/privacy.md` (five sections, listed below)
- Modify: `docs/legal/terms.md` (a purchases section, which does not exist)
- Modify: `store/listing.md` (the Apple privacy label)
- Modify: `.planning/STATE.md` (LEGAL-01, SHIP-01)
- Redeploy: `site/` — `/privacy` renders from `docs/legal/privacy.md` at build
  time, so the published policy is stale until `npm run deploy` runs.

**This ships with the binary or the policy is false.** LEGAL-01 has said so
since 2026-09-07. The sections that go stale the moment Task 3 lands, from
research section 5:

- privacy "The short version" — the no-internet sentence
- privacy "What we receive" — currently "Through the App: nothing"
- privacy "What we do not do" — currently "no advertising or tracking SDK"
- privacy "International transfers" — currently "we transfer nothing"
- privacy "Third-party services" — RevenueCat named as a processor
- terms — a purchases section covering a one-off, non-refundable tip that
  unlocks nothing

The replacement claim is narrower and still true: supplement data never leaves
the device, and the only network traffic is the purchase, which carries none of
it. Task 6 is what keeps that sentence honest.

The Apple label moves from "Data Not Collected" to Purchases, Purchase History,
purposes Analytics and App Functionality, **not linked to identity**, which is
correct while the app uses anonymous IDs only.

Clause bank: `docs/legal/2026-09-07-privacy-and-terms-research.md` section 7.

- [ ] **Step 1: Rewrite the five privacy sections**
- [ ] **Step 2: Add the terms purchases section**
- [ ] **Step 3: Run the legal copy gate**

Run: `flutter test test_release/legal_copy_safety_test.dart`
Expected: green. It checks vocabulary, not accuracy, which is why LEGAL-01
exists and why a human reads the diff.

- [ ] **Step 4: Update `store/listing.md` and `.planning/STATE.md`**
- [ ] **Step 5: Rebuild and redeploy the site**

```bash
export PATH=/Users/dima/.nvm/versions/node/v24.16.0/bin:$PATH
cd site && npm test && npm run deploy
```

- [ ] **Step 6: Commit**

---

### Task 8: Build, version, and the evidence

**Files:**
- Modify: `pubspec.yaml` version line

- [ ] **Step 1: Bump to `1.1.0+3`**

Build 2 was the iPhone-only iOS upload of 2026-09-11. A minor bump, not a
patch: the release adds a user-facing feature.

- [ ] **Step 2: Run both suites and the analyzer**

```bash
flutter analyze && flutter test && flutter test test_release/
```

- [ ] **Step 3: Capture the support screen for the App Store Connect review
      screenshot** each in-app purchase needs.

- [ ] **Step 4: Commit**
