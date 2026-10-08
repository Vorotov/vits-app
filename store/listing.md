# Store listing copy

English only for now — it is the app's primary language and its fallback.
Character limits are the store's, counted and noted; the validator named
under Keywords checks them.

Two constraints run through all of it, and neither is stylistic:

- **No health or medical vocabulary.** The app is a well-being product. The
  same rule that `test_release/legal_copy_safety_test.dart` enforces over
  `docs/legal/` applies here by hand: no *health*, *medical*, *dose safety*,
  *interaction*, *dietary*, *wellness*, *risk*, *supplement advice*. The
  listing describes a planner, never an outcome.
- **No claim the app does not make.** It plans, it reminds, it records. It
  does not recommend, evaluate or warn.

---

## Category

**Lifestyle**, on both stores. Not Health & Fitness.

This is a decision, not a default. Health & Fitness is where a reviewer looks
for claims about the user's body, and it is the category App Review reads
guideline 1.4.1 (physical harm) against. Everything about this product — the
legal documents, the copy gates, the deleted five-substance limit — was built
to sit outside that reading. Filing it under Health & Fitness would undo that
in one dropdown.

Play secondary tags: Organization, Planning.

---

## Apple App Store

**App Name** (30 max)

```
VitoMy: Supplement Planner
```
26 characters. The bare `VitoMy` is also fine if you would rather keep the
name clean; the longer form is worth more in search.

**Subtitle** (30 max)

```
Vitamin tracker with reminders
```
30 characters. The subtitle is the second-heaviest indexed field after the
name, so it is search copy, not a tagline: paired with `VitoMy: Supplement
Planner` it matches "supplement tracker", "vitamin tracker", "supplement
reminders", "vitamin reminders" and "vitamin planner" — the mainstream
queries — and frees `cycle` for the keyword field. The fallback, for an owner
who prefers the descriptive line, is `Plan cycles, mark what's taken` (30). In
that case `cycle` must leave the keyword field — the subtitle then carries
"cycles", and Apple treats the plural as a duplicate — and
`vitamins,tracker,reminder` go back in. The naive result is 119 characters, so
it needs a cut; one that passes the validator is
`stack,schedule,routine,log,daily,creatine,protocol,habit,intake,regimen,vitamins,tracker,reminder`
(97; drops `biohacking` and `nootropics`). Any other cut must be re-run
through the validator.

**Promotional text** (170 max, editable without a new build)

```
Set each schedule once, on and off weeks included, and VitoMy keeps the calendar for you. No account, no server, no sign-up. Everything stays on your device.
```
157 characters.

**Description** (4000 max)

```
VitoMy is a supplement planner. Add your supplements and vitamins, set when you take them, and check them off each day. Schedules can repeat with breaks built in, and the calendar works the cycles out for you.

WHAT IT DOES

Today. Every supplement due today in one list, with the time beside it. Tap to mark it taken.

Cycles. Each supplement schedule laid out across the months as bars: which weeks are on, which are breaks, and where supplements overlap.

Year. Twelve months at once, showing how much of each month is covered.

Reminders. A local notification for each supplement at the times you set. Reminders never name the supplement, so nothing appears on your lock screen that you would not want a stranger to read.

SCHEDULES THAT MATCH HOW YOU TAKE SUPPLEMENTS

Daily vitamins with no end date. A course of a supplement that ends on a set date. Eight weeks on and four weeks off. Whatever pattern you follow, set it once and VitoMy keeps the calendar.

VitoMy is a planner. It records which supplements you decide to take and when. It does not suggest what to take, how much, or whether to take anything at all. Those decisions are yours.
```
1150 characters. Tightened on 2026-09-11 at the owner's request: no
"runs a stack", the supplement/vitamin wording carried through every
section, and the languages and data sections dropped. The on-device claim
now lives only in the promotional text, which is editable without a build —
so when the RevenueCat tip jar (SHIP-01) adds a network client, the field
that has to change is the one that can change without a release.

**Keywords** (100 max, comma-separated, no spaces after commas)

```
stack,cycle,schedule,routine,log,daily,creatine,protocol,biohacking,habit,intake,regimen,nootropics
```
99 characters, 13 terms. Apple indexes only the app name, the subtitle and
the keyword field for search (Apple's App Store search page, and the `aso`
skill at `.claude/skills/aso/SKILL.md`); the description and promotional text
are conversion copy, not indexed. The rules applied: 100 characters, commas
with no spaces, never repeat a word already in the name, subtitle or category
(Lifestyle), no plural of a word already present (a duplicate to Apple), no
generic words such as "app". The previous field repeated supplement, planner
and cycle — 24 wasted characters. `pill` and `dose` are left out on purpose:
"pill reminder" is the medication-management reading (guideline 1.4.1, Health
& Fitness) the whole listing is built to stay outside of; "dose" is in the
app's own UI and no gate bans it, but it pulls the same direction. Both are a
one-line decision the owner can reverse. `python3
.planning/quick/260911-mms-app-store-listing-fix-the-31-char-subtit/260911-mms-validate.py
store/listing.md` checks the limits in characters and UTF-8 bytes, the keyword
rules above, and the vocabulary stems derived from
`test_release/legal_copy_safety_test.dart` and
`test/l10n/planner_copy_safety_test.dart`; it must print `RESULT: PASS`.

**Support URL** — `https://vitomy.app/support`. Live since 2026-09-12. App
Store Connect takes a URL here, not an address: a `mailto:` is rejected, which
is why `support@vitomy.app` could never close this field on its own.
**Marketing URL** — optional. `https://vitomy.app` if you want it filled.
**Privacy Policy URL** — `https://vitomy.app/privacy`, rendered at build time
from `docs/legal/privacy.md` so the page and the document cannot drift.
**App Review contact** — `support@vitomy.app`. This one is private to Apple and
is a separate field from the public Support URL.

**Age rating** — the Terms of Use set eligibility at 18+, which is a contract
term, not a content rating. The App Store questionnaire asks about content;
answering it honestly gives 4+. Setting the store rating to 17+ to match the
Terms costs reach and is not what the questionnaire is asking. Worth a
deliberate decision rather than either default.

**In-app purchase review screenshots** — App Store Connect will not let a
product be submitted without a screenshot showing where it appears in the app,
and the app cannot show a real price until the product exists. That circle is
broken by `tool/make_iap_screenshot.sh`, which pumps the REAL support screen
with the price fetch stubbed at the three prices being configured, and writes
`store/screenshots/iap-review/tip-review.png` at 1320x2868. **One image goes
in all three products' Review Screenshot fields**: the three tips share a
screen, and what Apple asks for is where the purchase appears. Re-run it if
the prices or the copy change, or the picture starts describing something that
is not for sale.

**App Privacy (nutrition label)** — **Purchases, Purchase History**, purposes
**Analytics** and **App Functionality**, **not linked to identity**, and
nothing else in any other category.

It was "Data Not Collected" until 2026-09-22, and the note here said that was
true only until RevenueCat landed. It has landed, so the label changes with
this release: the developer tip means purchase and receipt history reaches
RevenueCat as our processor. "Not linked to identity" is correct and is worth
keeping correct: the app uses RevenueCat's anonymous ids only, never calls
`logIn`, and never sets a subscriber attribute, which
`test/purchases/purchase_privacy_test.dart` holds. The day an advertising
integration is enabled, Device ID joins the label.

Nothing else moves. No analytics SDK, no crash-reporting SDK and no
advertising SDK ships, and `test/purchases/network_dependency_test.dart`
asserts there is exactly one network-capable dependency in the whole project.

**App Review notes** (App Review Information → Notes, and the Resolution
Center reply) — the first submission, build 1.0.0 (2) on 2026-09-13, came back
with Guideline 2.1 "Information Needed – New App Submission": the form letter
Apple sends developer accounts with little review history, not a finding
about the app. It asks for six things, answered below in Apple's order. The
screen recording (item 1) is captured on a physical iPhone on the current iOS,
starting at launch, and attached to the reply; the text goes into the Notes
field as well, which Apple asks for so later submissions skip the letter.
Keep it true: item 4 says "no network requests at all", which the RevenueCat
tip jar (SHIP-01) will falsify — rewrite it in the same release.

```
Answers to the "Information Needed – New App Submission" request, in the same order.

1. Screen recording: attached, captured on a physical iPhone running the current iOS. It starts at launch and shows the typical flow: the two intro pages, adding a supplement with a schedule (eight weeks on, four weeks off, one time per day), the Today list, marking a dose taken, the Cycles and Year views on the Calendar tab, and Settings. The app has no account or registration, no user-generated content that is shared with anyone, and no paid content or in-app purchases in this build.

2. Purpose and target audience: VitoMy is a planner and log for supplements and vitamins. Users enter what they take, set when they take it (every day, on set dates, or in on/off cycles measured in weeks), and check items off each day; the calendar works out which weeks are on and which are breaks. It is for adults who take several supplements on schedules and want one place to see what is due today and when each cycle pauses. The app records the user's own decisions. It does not suggest what to take, how much, or whether to take anything, and it makes no claims about outcomes.

3. Setup and access: no login, no credentials, no sample files. Install and open. The first launch shows two intro pages; tap through them. On the Stack tab, tap + to add a supplement (a name and a schedule are all that is required). The Today tab lists what is due and marks items taken with one tap; the Calendar tab holds the Cycles and Year views. Reminders are local notifications; the permission prompt appears when the first reminder time is saved, and every feature works if it is declined.

4. External services, tools and platforms: none. The app has no server, no account system, no analytics, no advertising, no payment processor and no AI service. It makes no network requests at all; all data is stored in a local SQLite database on the device and never leaves it. Reminders use iOS local notifications only (no push notifications, no APNs).

5. Regional differences: none. The app functions identically in every region. The interface follows the device language and is localised into English, Arabic, Spanish, French, Hindi, Ukrainian and Chinese; features and content are the same in all of them.

6. Regulated industry or protected material: not applicable. The app provides no advice or recommendations of any kind, sells nothing, contains no third-party or licensed material, does not use HealthKit, and reads no external data. Every piece of content is entered by the user.
```

**Screenshots** — App Store Connect's default iPhone card is the 6.5-inch
Display, which accepts 1284x2778 or 1242x2688 and rejected the 1320x2868
captures with "Screenshots dimensions should be: 1242 × 2688px, 2688 × 1242px,
1284 × 2778px or 2778 × 1284px". Upload `store/screenshots/ios-6.5/` there, in
file order: 01-stack, 02-today, 03-cycles, 04-year, 05-schedule. The 6.9-inch
originals in `store/screenshots/ios-6.9/` (1320x2868) go into the 6.9-inch
card, reachable only through "View All Sizes in Media Manager" — optional,
because Apple's screenshot specification fills a missing 6.5-inch set by
scaling the 6.9-inch set, and the 6.5-inch files ARE that scaling:
`tool/make_screenshots.sh` derives them by resizing to 1284 wide (2790 high)
and centre-cropping 6px off top and bottom to 2778, the two aspect ratios
differing by 0.4%. Only the first three screenshots show in search results, so
the order carries the pitch. Both sets are generated; never hand-edit a PNG.

**iPhone-only** (decided 2026-09-11) — App Store Connect demanded iPad
13-inch screenshots because build 1 declares `TARGETED_DEVICE_FAMILY` as both
families, Flutter's default. Nothing in the app has ever been laid out or
tested for a tablet — every render sweep in `test/` and `test_release/` is
phone-sized — and App Review tests on an iPad when the binary claims it. So
1.0 ships iPhone-only: `TARGETED_DEVICE_FAMILY = 1` on all three Runner
configurations, `pubspec.yaml` at `1.0.0+2` (build 1 is already uploaded and
iPad-capable, and neither App Store Connect nor Play accepts a reused build
number), and `test/platform_config_test.dart` asserts the value. Once build 2
is selected for the version, the iPad screenshot slot disappears; build 1
stays in TestFlight, unused. iPad users can still install the iPhone build in
compatibility mode. Revisit when tablet layouts and a tablet render sweep
exist.

**Creative assets** (optional) — the redesigned product page has two slots,
**Header** and **Search Results**. Header takes 21:9 at 3840x1646 or 16:9 at
5244x2950; Search Results takes 3:2 between 1920x1280 and 3840x2560, or the
same 16:9 5244x2950. The specifications overlap on exactly one size, so **one
master at 5244x2950 fills both** — Apple's own recommendation, and the reason
`store/creative/universal-5244x2950.png` is a single file rather than two.
Generated by `python3 tool/make_store_header.py`: the V mark (3b) on the left,
the wordmark and the one-line tagline "Plan supplement cycles." on the right,
on the paper token, set in the bundled Instrument Sans. Regenerate, never edit
the PNG.

Apple crops the 16:9 master down to each slot's ratio, and the two crops cut
on different axes: the 21:9 crop keeps the full width and leaves 2248 px of
height (76.2%), the 3:2 crop keeps the full height and leaves 4425 px of
width (84.4%). Only the 4425x2248 intersection survives both, so that is the
box the generator asserts the block into — vertical being the tighter of the
two is why the composition is horizontal rather than stacked. **Alpha is
refused**: the file is 24-bit RGB from the start, the same rule as the Play
feature graphic.

Both slots may be left empty, in which case Apple falls back to the
screenshots. This asset is an improvement to the listing, not a prerequisite
for submitting it. Uploading is a manual App Store Connect step (App
Information → Creative assets); nothing in the repo pushes it.

---

## Google Play

**App name** (30 max)

```
VitoMy - Supps & Vits Tracker
```
29 characters — the owner's own entry in Play Console. The alternative is
`VitoMy: Supplement Tracker` (26), the higher-search-volume form; the choice is
the owner's.

**Short description** (80 max)

```
Supplement & vitamin tracker: plan cycles, set reminders, mark what you take.
```
77 characters. Play indexes this field, so it carries the search terms rather
than a tagline.

**Full description** (4000 max) — the App Store description above, verbatim,
1150 characters. Play indexes the full description, so its supplement-and-vitamin
density is the point. Play renders plain text with line breaks, so the ALL-CAPS
section headings stay readable as they are.

**Feature graphic** (1024x500, required) —
`store/feature/feature-graphic-1024x500.png`, generated by
`python3 tool/make_feature_graphic.py`: the V mark (3b) on the left, the
wordmark and the two-line tagline "Plan supplement cycles." / "Get reminders.
Mark what you take." on the right, on the paper token, set in the bundled
Instrument Sans. Play's rules, and how the layout meets them: JPEG or 24-bit
PNG with no alpha (the canvas is RGB from the start); focal point central (the
block is kept inside the central 86% of the width); no store badges, no
ranking or price claims; tagline small. Regenerate, never edit the PNG.

**Phone screenshots** (2-8) — `store/screenshots/android-phone/01-stack.png`
through `05-schedule.png`, 1080x1920, uploaded in file order (the same order
as the iOS set). Play's rule: JPEG or 24-bit PNG, each side 320-3840 px, the
long side at most twice the short side, and four or more at 1080 px or above
for promotion eligibility. The iOS captures (1284x2778 is 2.16:1, 1320x2868
is 2.17:1) fail the 2:1 rule, and so does every modern phone AVD profile (a
Pixel 7 is 1080x2400), so the set is captured by
`tool/make_screenshots_android.sh` on a purpose-made AVD, `play_shots` —
Pixel 2 profile, 1080x1920 at 420 dpi, exactly 9:16 — from the same
`integration_test/store_screenshots_test.dart` the iOS set uses, with SystemUI
demo mode pinning the status bar (9:41, full battery, wifi only). The recipe
for creating the AVD is in that script's header. Tablet screenshots (7-inch
and 10-inch) are optional on Play and are not provided.

**Data safety form** — declare **no data collected and no data shared**. The
app has no network client, and the release manifest carries no INTERNET
permission (`test/platform_config_test.dart` asserts it). Answer "No" to
collection, which removes the encryption-in-transit and deletion-request
questions entirely.

**Permissions to explain** — `RECEIVE_BOOT_COMPLETED` only, so scheduled
reminders survive a restart. No exact-alarm permission is declared.

**Content rating (IARC)** — the questionnaire is about content, same reasoning
as Apple's above.

**Privacy policy URL** — `https://vitomy.app/privacy`. Same page Apple gets.

**Data safety** — **Purchase history**, collected, **not** shared, encrypted in
transit, and not deletable on request because it is Apple's and RevenueCat's
record of a payment rather than ours. Mirrors the Apple label above, and
changes with it. Play's form is only reached when Android ships, which is
after the hackathon.

**Contact email** — `support@vitomy.app`. Play shows this publicly on the
listing and it is the one required contact field, so Play needs no support
page; only Apple does.

---

## The mark

Two colourways were approved and both are built. **3b** ships — cream ground,
navy and ochre capsules; those two are `BqSeriesColors.palette[7]` and
`palette[0]`, the app's own supplement-tag colours, so the icon and the
interface read as one product. **3a** (ochre ground, navy and teal) is kept
built and is one command away: `python3 tool/make_icons.py 3a`. Geometry is identical — the V is
two capsules sharing a pivot raised to 88% of their own length, which is what
closes the arms into one mark instead of two objects leaning together.

Source: Claude Design project `dce8f720-1a6a-4152-90c2-6a6a76a471ac`, file
`VitoMy Icon.dc.html`, turn 3. `tool/make_icons.py` transcribes that document's
CSS constants directly, so the design moving means four numbers change and
nothing else does.

One number is derived rather than transcribed. The document puts the pivot at
0.88 of the capsule's length; the centre of the capsule's bottom cap is at
`(h - w/2)/h` = 0.8645. Rotating about a point 2.6 units off that centre swings
each cap sideways, the two caps miss each other, and the back capsule shows as a
crescent under the front one at the bottom of the V — clearly visible above
about 120px. On the cap centre, the rotation maps that circle onto itself, both
capsules end in the same disc, and the V closes to one point.
`store/icon/tip-before-after.png` is the comparison.

The colours are the app's own supplement-tag palette, lightened for a mark that
has to survive 40px: `#4b5079` is `BqSeriesColors.palette[7]`, `#b98a2e` is
`palette[0]`, `#3f7d8c` is `palette[5]`, `#f6f3ec` is `BqColors.paper`. They are
deliberately not snapped to the token values — an icon is brand, not UI, and
tokens.dart stays the only place a hex literal may appear in Dart.

A note worth keeping on the record: the mark is legibly a capsule, which is the
one shape this product otherwise avoids. That is a positioning risk rather than
a rule — nothing in the guidelines forbids it, and supplement trackers use pill
iconography routinely. It is mitigated by keeping the category Lifestyle and the
copy free of claims, both of which the rest of this file already does.

## Uploading a build

The bundle is `build/app/outputs/bundle/release/app-release.aab`, produced by
`flutter build appbundle --release`. It is ~62MB, and ~92MB of its uncompressed
158MB is `BUNDLE-METADATA` — native debug symbols and the ProGuard map, which
Play keeps for crash symbolication and never ships to a device. The download
size the console reports after upload is the real one.

Build 1 (`1.0.0+1`) has been uploaded to App Store Connect and is
iPad-capable. **Neither store accepts a reused build number**, so
`pubspec.yaml` moves to `1.0.0+2` for the iPhone-only build — see the
iPhone-only note in the Apple section — and every later upload bumps the `+N`
again or passes `--build-number=N`.

On the first upload Play offers Play App Signing — accept it. Google then holds
the real signing key and `~/keys/vitomy-upload-keystore.jks` is only the upload
key, which Google can reset if it is lost. The real one it could not.

### First internal testing release

Release name (internal only, 50 max):

```
1.0.0 (1) first internal build
```

Release notes — the language tags are part of the field:

```
<en-US>
First internal build.

Add what you take, set a schedule with on and off weeks, and check doses off on Today. Cycles and Year show how the schedules line up across the months.

Reminders are local and never name what you take. Everything stays on the device: no account, no server.

Known issue: the schedule editor's save button reads "Add and start cycle" even when you are editing a schedule that already exists.
</en-US>
```

The known issue is named on purpose. This is an internal track; a tester who
knows costs less than a bug report that rediscovers it.

Internal testing takes up to 100 testers, is not subject to the
12-testers-for-14-days rule that gates closed testing, and does not wait on
review. The full store listing — feature graphic, screenshots, descriptions —
is a production requirement, not an internal-testing one. The privacy policy
URL is not: Play asks for a link, and an address does not substitute.

## Assets

| Asset | Where | Status |
|---|---|---|
| App icon 1024x1024 | `store/icon/3b/appstore-icon-1024.png` | Ships. Generated by `tool/make_icons.py` |
| Play icon 512x512 | `store/icon/3b/play-icon-512.png` | Ships |
| Icon legibility check | `store/icon/comparison-3a-3b.png` | Both colourways at 260/180/120/60/40 px |
| Feature graphic 1024x500 | `store/feature/feature-graphic-1024x500.png` | Ships. Generated by `tool/make_feature_graphic.py` |
| ASC creative 5244x2950 | `store/creative/universal-5244x2950.png` | Built, not yet uploaded. Generated by `tool/make_store_header.py`; one 16:9 master fills both the Header and Search Results slots |
| iPhone 6.9" screenshots | `store/screenshots/ios-6.9/` | Captured by `tool/make_screenshots.sh`; goes in the 6.9-inch card only |
| iPhone 6.5" screenshots | `store/screenshots/ios-6.5/` | Derived from the 6.9-inch set by `tool/make_screenshots.sh`; ASC's default iPhone card |
| Play phone screenshots | `store/screenshots/android-phone/` | Five at 1080x1920 (9:16), captured by `tool/make_screenshots_android.sh` on the `play_shots` AVD; the iOS sets fail Play's 2:1 rule |
