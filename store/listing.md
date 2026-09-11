# Store listing copy

English only for now — it is the app's primary language and its fallback.
Character limits are the store's, counted and noted.

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
Plan cycles, mark what you take
```
30 characters exactly.

**Promotional text** (170 max, editable without a new build)

```
Everything stays on your device. No account, no server, no sign-up. Set a schedule once, including on and off weeks, and VitoMy keeps the calendar for you.
```
152 characters.

**Description** (4000 max)

```
VitoMy plans what you take and keeps track of it.

Add what is in your stack, set when you take it, and see today's list ready to check off. Schedules can repeat with breaks built in — eight weeks on, four weeks off, or whatever pattern you actually follow — and the calendar works the cycle out for you.

WHAT IT DOES

Today — everything due today in one list, with the time beside it. Tap to mark it taken.

Cycles — every schedule laid out across the months as bars, so you can see at a glance which weeks are on, which are breaks, and where they overlap.

Year — twelve months at once, showing how much of each is covered.

Reminders — a local notification at each time you set. Reminders never name what you take, so nothing appears on your lock screen that you would not want a stranger to read.

YOUR DATA STAYS YOURS

There is no account and nothing to sign up for. The app has no network client at all — everything you enter is written to your own device and never leaves it. Delete the app and the data goes with it.

SEVEN LANGUAGES

English, Arabic, Spanish, French, Hindi, Ukrainian and Chinese, including full right-to-left layout.

VitoMy is a planner. It records what you decide to take and when. It does not suggest what to take, how much, or whether to take anything at all — those decisions are yours.
```

**Keywords** (100 max, comma-separated, no spaces after commas)

```
supplement,vitamin,stack,tracker,planner,cycle,schedule,reminder,routine,intake,log,habit,daily
```
94 characters.

**Support URL** — required, and the project has none yet. This is a blocker.
**Marketing URL** — optional; leave blank until vitomy.app has a page.
**Privacy Policy URL** — required. `docs/legal/privacy.md`, once hosted.

**Age rating** — the Terms of Use set eligibility at 18+, which is a contract
term, not a content rating. The App Store questionnaire asks about content;
answering it honestly gives 4+. Setting the store rating to 17+ to match the
Terms costs reach and is not what the questionnaire is asking. Worth a
deliberate decision rather than either default.

**App Privacy (nutrition label)** — **Data Not Collected**, every category.
True today and only today: the first release that adds RevenueCat, analytics
or crash reporting must change this label in the same release. That is
LEGAL-01 in `.planning/STATE.md`.

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
77 characters.

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

---

## The mark

Two colourways, both approved, both built: **3a** on ochre with navy and teal
capsules, **3b** on cream with navy and ochre. Geometry is identical — the V is
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

## Assets

| Asset | Where | Status |
|---|---|---|
| App icon 1024x1024 | `store/icon/<3a\|3b>/appstore-icon-1024.png` | Generated by `tool/make_icons.py` |
| Play icon 512x512 | `store/icon/<3a\|3b>/play-icon-512.png` | Generated |
| Icon legibility check | `store/icon/comparison-3a-3b.png` | Both colourways at 260/180/120/60/40 px |
| Feature graphic 1024x500 | Play, **required** | Not made yet |
| iPhone 6.9" screenshots | `store/screenshots/ios-6.9/` | Generated by `tool/make_screenshots.sh` |
| Play phone screenshots | min 2 | The iOS set works; Play accepts any phone aspect |
