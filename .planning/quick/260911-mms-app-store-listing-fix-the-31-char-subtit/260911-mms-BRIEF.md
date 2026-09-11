# Brief for quick task 260911-mms — App Store listing copy + 6.5" screenshots

Everything below was researched and verified by the orchestrator on 2026-09-11.
The planner turns it into 1-3 tasks; the executor applies it VERBATIM where
copy is concerned (the copy has already passed the validator).

## Facts established

- App Store Connect (ASC) rejected `store/screenshots/ios-6.9/*.png`
  (1320x2868) in its default iPhone slot with: "Screenshots dimensions should
  be: 1242 × 2688px, 2688 × 1242px, 1284 × 2778px or 2778 × 1284px". ASC's
  default iPhone card is the **6.5" Display**; the 6.9" card (which accepts
  1320x2868, 1290x2796, 1260x2736) is only reachable through
  "View All Sizes in Media Manager". Apple's spec page
  (developer.apple.com/help/app-store-connect/reference/screenshot-specifications/)
  says a missing 6.5" set is filled by SCALING the 6.9" set — so a derived
  6.5" set is exactly what Apple would produce itself.
- The five 6.5" files already exist in `store/screenshots/ios-6.5/` (untracked),
  produced by: `sips -z 2790 1284 <file>` (scale to 1284 wide; 2868*1284/1320 =
  2789.8) then `sips -c 2778 1284 <file>` (centre crop, 6px off top and
  bottom; the two aspect ratios differ by 0.4%). Verified 1284x2778 each and
  visually checked (status bar and bottom nav intact).
- `store/listing.md` claims the Subtitle "Plan cycles, mark what you take" is
  "30 characters exactly". It is 31. ASC's field limit is 30, so it would be
  rejected. The rest of the counts in that file were right.
- Apple indexes ONLY app name + subtitle + keyword field for search (source:
  Apple's own https://developer.apple.com/app-store/search/ and the `aso`
  skill now installed at `.claude/skills/aso/SKILL.md`, from
  coreyhaines31/marketingskills). Description and promotional text are NOT
  indexed — they are conversion copy. Apple's keyword rules: 100 chars, commas
  with no spaces, never repeat a word that is already in the name, subtitle or
  category, no plural of a word already present (treated as a duplicate), no
  generic words ("app").
- The old keyword field repeated three words already indexed by the name and
  subtitle (supplement, planner, cycle) — 24 wasted characters.
- The tip-jar in-app purchase (SHIP-01, RevenueCat) is NOT in the code yet
  (`pubspec.yaml` has no `purchases_flutter`). Once it lands, the app will
  have a network client, so the old description sentence "The app has no
  network client at all — everything you enter is written to your own device
  and never leaves it" would become false in the store. The new description
  keeps only the claim that stays true: what you ENTER never leaves the
  device; no account; no ads; no subscription.
- `pill` and `dose` were deliberately left OUT of the keyword field: "pill
  reminder" is the medication-management category, which is exactly the
  reading (guideline 1.4.1, Health & Fitness) the whole listing is built to
  stay outside of. "dose" appears in the app's own UI ("dose 1 of 2") and is
  not banned by any gate, but it pulls the same direction, so it is not in the
  field either. Both are a one-line decision the owner can reverse.
- The vocabulary gates apply to store copy "by hand" (listing.md says so).
  `260911-mms-validate.py` in this directory derives the stems from
  `test_release/legal_copy_safety_test.dart` and
  `test/l10n/planner_copy_safety_test.dart`, checks every field's limit (chars
  and UTF-8 bytes), and checks the keyword rules above. Run it against
  `store/listing.md` after editing:
  `python3 .planning/quick/260911-mms-app-store-listing-fix-the-31-char-subtit/260911-mms-validate.py store/listing.md`
  It must print `RESULT: PASS`. (It parses the `**Label** ... ```block````
  layout listing.md already uses; keep that layout.)

## The copy (verbatim source: `260911-mms-COPY.md` in this directory)

| Field | New value | Count |
|---|---|---|
| App Name | `VitoMy: Supplement Planner` (unchanged) | 26 |
| Subtitle | `Vitamin tracker with reminders` | 30 |
| Promotional text | see COPY.md | 157 |
| Description | see COPY.md | 1383 |
| Keywords | `stack,cycle,schedule,routine,log,daily,creatine,protocol,biohacking,habit,intake,regimen,nootropics` | 99 |

Why the subtitle changed shape and not just length: the subtitle is the
second-heaviest indexed field. `Vitamin tracker with reminders` makes the
name+subtitle pair match "supplement tracker", "vitamin tracker", "supplement
reminders", "vitamin reminders" and "vitamin planner" — the mainstream queries
— and frees `cycle` for the keyword field. The fallback if the owner prefers
the descriptive tagline is `Plan cycles, mark what's taken` (30), in which
case `cycle` must leave the keyword field again and `vitamins,tracker,reminder`
go back in. Record both in listing.md.

## What to change

1. `store/listing.md`, Apple section:
   - Replace the Subtitle, Promotional text, Description and Keywords blocks
     and their counts with the values above, keeping the file's existing
     `**Label** (limit)` + fenced-block layout (the validator parses it).
   - Under Keywords, state the rules used (indexed fields; no repeats across
     name/subtitle/category; no plurals; pill/dose left out and why; the
     fallback subtitle and its keyword field).
   - Under Description, one short note: the "no network client" sentence was
     dropped ahead of RevenueCat (SHIP-01) so the description does not have
     to change in the same release as the App Privacy label does.
   - Add a **Screenshots** subsection: ASC's default iPhone card is 6.5"
     (1284x2778 / 1242x2688) → upload `store/screenshots/ios-6.5/`; the 6.9"
     originals in `store/screenshots/ios-6.9/` go into the 6.9" card via
     "View All Sizes in Media Manager" (optional — Apple scales 6.9" down for
     everything else if both are given, the 6.5" set is derived from them
     anyway). Only the first three screenshots show in search results.
   - Fix the sentence in the intro or wherever counts are claimed so nothing
     in the file states a wrong count.
2. `tool/make_screenshots.sh`: after the capture loop, derive the 6.5" set
   into `${OUT/ios-6.9/ios-6.5}` (fallback `${OUT}-6.5` when the out dir does
   not contain `ios-6.9`) with the two `sips` calls above, remove stale PNGs
   there first, and print both folders' dimensions at the end. Update the
   header comment: 1320x2868 is the 6.9" size, ASC's DEFAULT slot is 6.5",
   and the 6.5" set is derived rather than captured on a second simulator
   because Apple's own fallback is a scaled 6.9" image. Keep `set -euo
   pipefail`. Do not re-run the capture (it erases a simulator and takes
   minutes); the derived files already exist and are byte-identical to what
   the new step produces — verify that by running only the new derivation
   step on a copy in a temp dir, or by re-deriving into
   `store/screenshots/ios-6.5/` and confirming `git status` shows the same
   five files.
3. Commit `store/screenshots/ios-6.5/*.png` together with (1) and (2) in one
   or two atomic commits (assets + the script that generates them belong in
   the same commit; the copy can be its own commit).
4. Also update the CLAUDE.md "Store assets are generated" paragraph? NO —
   leave CLAUDE.md alone; `store/listing.md` and the script header carry it.

## Out of scope (do not do)

- No Dart test, no new gate, no CLAUDE.md edit, no change to the 6.9"
  captures, no change to `integration_test/store_screenshots_test.dart`, no
  localisation of the store copy.
- Do not touch `.agents/`, `.claude/skills/`, `skills-lock.json` (the owner's
  untracked skill installs).

## Addendum (after `git status` at 16:19)

- Commit `3030842` (made mid-session) gitignores the skill directories and
  tracks `skills-lock.json`. Installing the `aso` skill changed the tracked
  `skills-lock.json` (one new `"aso"` entry). Commit that change on its own as
  `chore: install the aso skill (coreyhaines31/marketingskills), lockfile only`
  — the skill directory itself is ignored. This REPLACES the earlier line
  saying not to touch `skills-lock.json`; `.agents/` and `.claude/skills/`
  stay untouched.
- Local `main` is 17 commits ahead of `origin/main`; do not push.
