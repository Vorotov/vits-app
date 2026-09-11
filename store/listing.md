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

**Support URL** — required, and still a blocker. App Store Connect takes a URL
here, not an address: a `mailto:` is rejected, so `support@vitomy.app` does not
close this field. It needs a page.
**Marketing URL** — optional; leave blank until vitomy.app has a page.
**Privacy Policy URL** — required. `docs/legal/privacy.md`, once hosted.
**App Review contact** — `support@vitomy.app`. This one is private to Apple and
is a separate field from the public Support URL.

**Age rating** — the Terms of Use set eligibility at 18+, which is a contract
term, not a content rating. The App Store questionnaire asks about content;
answering it honestly gives 4+. Setting the store rating to 17+ to match the
Terms costs reach and is not what the questionnaire is asking. Worth a
deliberate decision rather than either default.

**App Privacy (nutrition label)** — **Data Not Collected**, every category.
True today and only today: the first release that adds RevenueCat, analytics
or crash reporting must change this label in the same release. That is
LEGAL-01 in `.planning/STATE.md`.

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

---

## Google Play

**App name** (30 max)

```
VitoMy: Supplement Planner
```

**Short description** (80 max)

```
Plan your supplement cycles, get reminders, mark what you take. All on-device.
```
78 characters.

**Full description** (4000 max) — the App Store description above works
verbatim. Play renders plain text with line breaks, so the section headings
stay readable as they are.

**Data safety form** — declare **no data collected and no data shared**. The
app has no network client, and the release manifest carries no INTERNET
permission (`test/platform_config_test.dart` asserts it). Answer "No" to
collection, which removes the encryption-in-transit and deletion-request
questions entirely.

**Permissions to explain** — `RECEIVE_BOOT_COMPLETED` only, so scheduled
reminders survive a restart. No exact-alarm permission is declared.

**Content rating (IARC)** — the questionnaire is about content, same reasoning
as Apple's above.

**Privacy policy URL** — required. Same blocker.

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

`pubspec.yaml` is at `1.0.0+1`. **Play rejects an upload whose versionCode is
not higher than every previous one**, so the second upload needs
`flutter build appbundle --release --build-number=2`, or a bump to the `+N` in
pubspec.

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
| Feature graphic 1024x500 | Play, **required** | Not made yet |
| iPhone 6.9" screenshots | `store/screenshots/ios-6.9/` | Captured by `tool/make_screenshots.sh`; goes in the 6.9-inch card only |
| iPhone 6.5" screenshots | `store/screenshots/ios-6.5/` | Derived from the 6.9-inch set by `tool/make_screenshots.sh`; ASC's default iPhone card |
| Play phone screenshots | min 2 | The iOS set works; Play accepts any phone aspect |
