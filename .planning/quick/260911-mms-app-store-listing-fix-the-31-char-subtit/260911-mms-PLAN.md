---
phase: quick-260911-mms
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - store/listing.md
  - tool/make_screenshots.sh
  - store/screenshots/ios-6.5/01-stack.png
  - store/screenshots/ios-6.5/02-today.png
  - store/screenshots/ios-6.5/03-cycles.png
  - store/screenshots/ios-6.5/04-year.png
  - store/screenshots/ios-6.5/05-schedule.png
  - skills-lock.json
autonomous: true
requirements: [QUICK-260911-mms]

estimate:
  tokens: 45000
  raw_tokens: 45000
  tasks: 3
  confidence: low

must_haves:
  truths:
    - "`python3 .planning/quick/260911-mms-app-store-listing-fix-the-31-char-subtit/260911-mms-validate.py store/listing.md` prints `RESULT: PASS` with Subtitle 30, Promotional text 157, Description 1383, Keywords 99 chars / 13 terms, no keyword problems, vocabulary gate clean"
    - "The five fenced blocks under **App Name**, **Subtitle**, **Promotional text**, **Description**, **Keywords** in store/listing.md are byte-identical to the blocks in 260911-mms-COPY.md"
    - "No count claimed anywhere in store/listing.md is wrong: the stale 31/152/94/77 claims are gone and the Play short description says 78"
    - "store/listing.md tells the uploader which folder goes in which App Store Connect card (6.5-inch default card takes store/screenshots/ios-6.5/; 6.9-inch card via View All Sizes in Media Manager takes ios-6.9/), that the 6.5-inch set is derived, and that only the first three screenshots show in search"
    - "`tool/make_screenshots.sh --derive-only <copy-of-ios-6.9>` reproduces all five committed store/screenshots/ios-6.5/*.png byte-for-byte, without touching a simulator"
    - "All five store/screenshots/ios-6.5/*.png are tracked, 1284x2778, and were committed in the same commit as the script change that generates them"
    - "skills-lock.json's aso entry is its own commit with subject exactly `chore: install the aso skill (coreyhaines31/marketingskills), lockfile only`"
    - "Every commit made by this task ends with the two attribution lines; nothing was pushed; .gitignore, site/, .claude/agents/ and .planning/ were not staged"
  artifacts:
    - "store/listing.md — Apple section carries the new copy, per-field counts, subtitle fallback, keyword rules, the RevenueCat note under Description, a **Screenshots** subsection, and an Assets row for the 6.5-inch set"
    - "tool/make_screenshots.sh — header explains 6.9 vs 6.5 and why the 6.5-inch set is derived; derivation step after the capture; `--derive-only [out-dir]` mode; dimension report for both folders"
    - "store/screenshots/ios-6.5/01-stack.png .. 05-schedule.png — 1284x2778 each, tracked"
  key_links:
    - "listing.md **Screenshots** subsection names store/screenshots/ios-6.5/ as the 6.5-inch upload and tool/make_screenshots.sh as what produces it"
    - "The `**Label** (limit)` line + blank line + fenced block layout is what 260911-mms-validate.py parses; break the layout and the validator reports MISSING"
    - "The two sips calls in the script (`sips -z 2790 1284`, then `sips -c 2778 1284`, height before width) are exactly what produced the existing PNGs — the byte-identity check in Task 2 depends on that argument order"
---

<objective>
Make the App Store listing uploadable and search-tuned, and put the 6.5-inch screenshot set under generation like every other store asset.

Three things are wrong or missing today: the Subtitle in `store/listing.md` is 31 characters against a 30 limit (App Store Connect rejects it); the keyword field wastes 24 characters repeating words already indexed from the name and subtitle; and App Store Connect's DEFAULT iPhone card is the 6.5-inch Display, which rejected the 1320x2868 captures with "Screenshots dimensions should be: 1242 x 2688px, 2688 x 1242px, 1284 x 2778px or 2778 x 1284px". The five 6.5-inch files already exist (derived by hand, verified byte-identical to what the planned script step produces) but are untracked and nothing generates them.

Purpose: a listing that ASC accepts on first upload, copy that matches the mainstream queries ("supplement tracker", "vitamin tracker", "vitamin reminders"), a description that stays true when the RevenueCat tip jar (SHIP-01) lands, and a `tool/make_screenshots.sh` that owns the 6.5-inch set so "store assets are generated, never hand-edited" stays true.

Output: three commits on `main` (listing copy; script + five PNGs; skills-lock.json), nothing pushed.

Tracer-first decomposition does not apply here: this task has no runtime layers (markdown, a shell script, five PNGs, a lockfile). The split follows the orchestrator's suggested three tasks.
</objective>

<execution_context>
@$HOME/.claude/gsd-core/workflows/execute-plan.md
@$HOME/.claude/gsd-core/templates/summary.md
</execution_context>

<context>
@.planning/quick/260911-mms-app-store-listing-fix-the-31-char-subtit/260911-mms-BRIEF.md
@.planning/quick/260911-mms-app-store-listing-fix-the-31-char-subtit/260911-mms-COPY.md
@.planning/quick/260911-mms-app-store-listing-fix-the-31-char-subtit/260911-mms-validate.py
@store/listing.md
@tool/make_screenshots.sh
@.claude/CLAUDE.md
</context>

<non_negotiables>
Read these before the first edit. Each one was checked by the planner against the real tree on 2026-09-11.

1. **The copy is final.** The five fenced blocks in `260911-mms-COPY.md` go into `store/listing.md` byte-for-byte. Do not reword, do not "fix" punctuation, do not re-introduce em dashes or curly quotes (the new copy is pure ASCII: 1383 chars = 1383 bytes; the old description was not). Task 1's verify compares the blocks programmatically and fails on a single differing byte.

2. **Rationale prose is free; blocks are not.** The validator scans only the five fenced blocks; no Dart test reads `store/listing.md` (`test_release/legal_copy_safety_test.dart` scans `docs/legal/` only). So the explanatory text under Keywords may say "pill" and "dose"; the blocks may not gain a single word.

3. **Never run the simulator capture.** `tool/make_screenshots.sh` without `--derive-only` erases a simulator and takes minutes. The 6.9-inch originals in `store/screenshots/ios-6.9/` are tracked and must not change (`git status --porcelain -- store/screenshots/ios-6.9` must stay empty throughout).

4. **Stage by explicit path only.** The working tree carries a SEPARATE, in-progress website subproject that is not part of this task: ` M .gitignore`, `?? site/`, `?? .claude/agents/`. Plus `?? .planning/quick/` (the orchestrator commits planning docs). Never `git add -A`, `git add .`, `git commit -a`, or `git stash`. Every commit below names its files.

5. **Commit trailers.** Every commit message ends with exactly these two lines, consecutive, last:
   `Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>`
   `Claude-Session: https://claude.ai/code/session_01CXDjVs9cVBqfTyk5u8cDVV`
   The reliable way is a message file in the scratchpad passed with `git commit -F`; multiple `-m` flags insert blank lines between arguments, so if you use `-m`, both trailer lines must be inside ONE `-m` argument. Subject lines follow the repo's style: lowercase, `type(scope): what and why`, no trailing period.

6. **No push.** `main` is ahead of `origin/main` by 17 commits and stays local. No `git push`, no `git fetch --prune`, nothing that touches the remote.

7. **Out of scope, do not touch:** `CLAUDE.md`, `integration_test/store_screenshots_test.dart`, `tool/l10n_screenshot_watcher.sh`, anything under `lib/`, `test/`, `test_release/`, `docs/`, `.agents/`, `.claude/skills/`, `.gitignore`, `site/`, `.claude/agents/`, `ROADMAP.md`, `STATE.md`. No Dart tests, no new gates, no localisation of store copy.
</non_negotiables>

<tasks>

<task type="auto">
  <name>Task 1: Apply the validated App Store copy to store/listing.md, with the ASO rationale, the RevenueCat note, a Screenshots subsection, and correct counts</name>
  <files>store/listing.md</files>
  <read_first>
    - .planning/quick/260911-mms-app-store-listing-fix-the-31-char-subtit/260911-mms-COPY.md (the five blocks to paste)
    - .planning/quick/260911-mms-app-store-listing-fix-the-31-char-subtit/260911-mms-BRIEF.md (Facts established + What to change, item 1)
    - store/listing.md (current layout; keep it)
  </read_first>
  <action>
Edit `store/listing.md` in place with scoped Edit calls (never a whole-file rewrite). Keep the file's existing shape: a `**Label** (limit)` line, one blank line, a fenced block, then the count line and prose. The validator's regex requires the fence to follow the label line with nothing but newlines between them, so never put prose between a label line and its fence.

**A. The four copy blocks (Apple section).** Replace the BODY of the fenced blocks under `**Subtitle**`, `**Promotional text**`, `**Description**` and `**Keywords**` with the corresponding block bodies from `260911-mms-COPY.md`, verbatim. `**App Name**` is unchanged (`VitoMy: Supplement Planner`, 26). The new values, for orientation only — paste from COPY.md, not from here: Subtitle `Vitamin tracker with reminders`; Keywords `stack,cycle,schedule,routine,log,daily,creatine,protocol,biohacking,habit,intake,regimen,nootropics`; Promotional text and Description are multi-sentence and live only in COPY.md. The Description keeps its paragraph breaks and its three ALL-CAPS section headings exactly as in COPY.md.

**B. Counts.** Every count the file claims must be a number the validator prints. Under Subtitle write `30 characters.` and drop the old qualifier word that followed the number (the old line asserted a 31-char string was thirty). Under Promotional text write `157 characters.` (the old line claimed 152 for a string that was 155). Under Keywords write `99 characters, 13 terms.` (the old line claimed 94 for 95). Under Description add `1383 characters.` after the block (there was no count line; add one so all four fields read the same way). In the Google Play section, the Short description count line claims 77; the string is 78 (measured, both chars and UTF-8 bytes) — change it to `78 characters.`; the string itself does not change. Leave `26 characters.` under App Name. Do not write the word "characters" immediately after 31, 152, 94 or 77 anywhere in the file — Task 1's verify greps for exactly those stale pairs.

**C. Rationale under Subtitle** (one short paragraph after the count line). The subtitle is the second-heaviest indexed field after the name, so it is search copy, not a tagline: paired with `VitoMy: Supplement Planner` it now matches "supplement tracker", "vitamin tracker", "supplement reminders", "vitamin reminders" and "vitamin planner" — the mainstream queries — and frees `cycle` for the keyword field. Record the fallback for an owner who prefers the descriptive line: subtitle `Plan cycles, mark what's taken` (30), in which case `cycle` must leave the keyword field (the subtitle then carries "cycles", and Apple treats the plural as a duplicate) and `vitamins,tracker,reminder` go back in; the naive result is 119 chars, so it needs a cut — one that passes the validator is `stack,schedule,routine,log,daily,creatine,protocol,habit,intake,regimen,vitamins,tracker,reminder` (97; drops `biohacking` and `nootropics`). Present both fallback strings as inline code (backticks), NOT as fenced blocks, and say any other cut must be re-run through the validator.

**D. Note under Description** (one or two sentences after the count line). The old sentence claiming the app has no network client at all was dropped ahead of the RevenueCat tip jar (SHIP-01): once a purchases SDK lands the app does have a network client, and the description should not have to change in the same release as the App Privacy label does. What remains — what you enter never leaves the device; no account; no ads; no subscription — stays true after a one-time tip.

**E. Rules under Keywords** (a short paragraph or list after the count line). State what was applied: Apple indexes only the app name, the subtitle and the keyword field for search (source: Apple's App Store search page and the `aso` skill at `.claude/skills/aso/SKILL.md`); description and promotional text are conversion copy, not indexed. Field rules: 100 characters, commas with no spaces, never repeat a word already in the name, subtitle or category (Lifestyle), no plural of a word already present (a duplicate to Apple), no generic words such as "app". The previous field repeated supplement, planner and cycle — 24 wasted characters. `pill` and `dose` are left out on purpose: "pill reminder" is the medication-management reading (guideline 1.4.1, Health & Fitness) the whole listing is built to stay outside of; "dose" is in the app's own UI and no gate bans it, but it pulls the same direction — a one-line decision the owner can reverse. Point at the validator: `.planning/quick/260911-mms-app-store-listing-fix-the-31-char-subtit/260911-mms-validate.py store/listing.md` checks the limits in chars and UTF-8 bytes, the keyword rules above, and the vocabulary stems derived from `test_release/legal_copy_safety_test.dart` and `test/l10n/planner_copy_safety_test.dart`; it must print `RESULT: PASS`. Optionally extend the intro sentence "Character limits are the store's, counted and noted." to mention that the validator checks them.

**F. Screenshots subsection.** Add a `**Screenshots**` bold-label paragraph (no fenced block) at the end of the Apple App Store section — after the App Privacy paragraph, before the `---` that precedes Google Play. Content: App Store Connect's default iPhone card is the 6.5-inch Display, which accepts 1284x2778 or 1242x2688 and rejected the 1320x2868 captures with the exact message quoted in the brief; upload `store/screenshots/ios-6.5/` there, in file order (01-stack, 02-today, 03-cycles, 04-year, 05-schedule). The 6.9-inch originals in `store/screenshots/ios-6.9/` (1320x2868) go into the 6.9-inch card, reachable only through "View All Sizes in Media Manager" — optional, because Apple's screenshot specification says a missing 6.5-inch set is filled by scaling the 6.9-inch set, and the 6.5-inch files ARE that scaling: `tool/make_screenshots.sh` derives them by resizing to 1284 wide (2790 high) and centre-cropping 6px off top and bottom to 2778, the two aspect ratios differing by 0.4%. Only the first three screenshots show in search results, so the order carries the pitch. Both sets are generated; never hand-edit a PNG.

**G. Assets table.** Add a row for the 6.5-inch set: `store/screenshots/ios-6.5/`, status "Derived from the 6.9-inch set by `tool/make_screenshots.sh`; ASC's default iPhone card". Amend the 6.9-inch row's status so it says the folder is captured by the script and goes in the 6.9-inch card only.

**H. Verify, then commit.** Run the verify command below until it passes. Then `git add store/listing.md` (that path only), confirm `git diff --cached --name-only` prints exactly `store/listing.md`, and commit with subject `docs(store): fix the 31-character subtitle and recut the App Store copy for search`, a body of two or three sentences (subtitle was 31 against ASC's 30; keywords stop repeating indexed words; description drops the no-network-client claim ahead of SHIP-01; the 6.5-inch card is documented), and the two trailer lines from non_negotiables item 5.
  </action>
  <verify>
    <automated>cd /Users/dima/supplements && Q=.planning/quick/260911-mms-app-store-listing-fix-the-31-char-subtit && python3 "$Q/260911-mms-validate.py" store/listing.md | tee /dev/stderr | grep -q '^RESULT: PASS$' && python3 -c 'import re,sys;F=chr(96)*3;f=lambda p:{l:re.search(r"\*\*"+re.escape(l)+r"\*\*[^\n]*\n+"+F+r"\n(.*?)\n"+F,open(p).read(),re.S).group(1) for l in ["App Name","Subtitle","Promotional text","Description","Keywords"]};a=f(sys.argv[1]);b=f(sys.argv[2]);d=[l for l in a if a[l]!=b[l]];print("BLOCKS IDENTICAL" if not d else "BLOCKS DIFFER: %s"%d);raise SystemExit(1 if d else 0)' store/listing.md "$Q/260911-mms-COPY.md" && ! grep -nE '\b(31|152|94|77) characters|characters exactly' store/listing.md && grep -q '78 characters' store/listing.md && grep -q '^\*\*Screenshots\*\*' store/listing.md && grep -q 'store/screenshots/ios-6.5/' store/listing.md && grep -qi 'View All Sizes in Media Manager' store/listing.md && grep -qi "Plan cycles, mark what's taken" store/listing.md && grep -q 'SHIP-01' store/listing.md && git diff --quiet -- store/listing.md && [ "$(git show --format= --name-only HEAD)" = "store/listing.md" ] && [ "$(git log -1 --format=%B | tail -2)" = "$(printf 'Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>\nClaude-Session: https://claude.ai/code/session_01CXDjVs9cVBqfTyk5u8cDVV')" ] && echo TASK1_OK</automated>
  </verify>
  <done>The validator prints RESULT: PASS (Subtitle 30, Promotional text 157, Description 1383, Keywords 99 / 13 terms, no keyword problems, vocabulary clean); the five blocks are byte-identical to COPY.md; no stale count remains and the Play short description says 78; the Subtitle fallback, keyword rules, RevenueCat note, Screenshots subsection and 6.5-inch Assets row are present; the change is committed alone under the stated subject with the two trailer lines.</done>
</task>

<task type="auto">
  <name>Task 2: Make tool/make_screenshots.sh derive the 6.5-inch set, prove it reproduces the existing files byte-for-byte, and commit script and PNGs together</name>
  <files>tool/make_screenshots.sh, store/screenshots/ios-6.5/01-stack.png, store/screenshots/ios-6.5/02-today.png, store/screenshots/ios-6.5/03-cycles.png, store/screenshots/ios-6.5/04-year.png, store/screenshots/ios-6.5/05-schedule.png</files>
  <read_first>
    - tool/make_screenshots.sh (44 lines; the capture flow, the watcher/trap, the final dimension loop)
    - .planning/quick/260911-mms-app-store-listing-fix-the-31-char-subtit/260911-mms-BRIEF.md (Facts established, bullets 1-2; What to change, item 2)
  </read_first>
  <action>
Edit `tool/make_screenshots.sh` with scoped Edit calls. It stays `#!/bin/bash` with `set -euo pipefail` and `cd "$(dirname "$0")/.."` exactly as they are; the simulator erase/boot, status-bar override, watcher, trap and `flutter test` lines are not changed.

**A. Header comment.** Rewrite the usage and explanation at the top so it says: usage `tool/make_screenshots.sh [udid] [out-dir]` to capture, and `tool/make_screenshots.sh --derive-only [out-dir]` to rebuild only the derived set from an existing capture; the iPhone 17 Pro Max renders 1320x2868, which is the 6.9-inch size; App Store Connect's DEFAULT iPhone card is the 6.5-inch Display (1284x2778 or 1242x2688) and rejects 1320x2868 there, while the 6.9-inch card is only reachable via "View All Sizes in Media Manager"; the 6.5-inch set is DERIVED from the 6.9-inch captures — resized to 1284 wide (2790 high; 2868 x 1284 / 1320 = 2789.8) then centre-cropped to 2778 (6px off top and bottom; the two aspect ratios differ by 0.4%) — rather than captured on a second simulator, because Apple's own fallback for a missing 6.5-inch set is a scaled 6.9-inch image, so the derived set is what Apple would produce itself. Keep the existing sentence about why the simulator is erased.

**B. `--derive-only` mode.** If the first argument is `--derive-only`: shift it off, remember the mode in a variable, take `OUT` from the next argument (default `store/screenshots/ios-6.9`), do NOT compute `UDID` and do NOT call `xcrun` at all, and fail with a clear message if `$OUT` holds no PNGs (`compgen -G "$OUT/*.png" >/dev/null` is a clean test under `set -u`). Otherwise the existing `UDID`/`OUT` handling stays as it is. Skip the whole capture block (from the `echo "==> simulator ..."` line through `trap - EXIT`) in derive-only mode; a small `if` around it, or a `capture` function called only when not in derive-only mode — either is fine, keep it readable. This mode exists so the derived set can be rebuilt, and this task's verify can be run, without erasing a simulator.

**C. Derivation step (both modes), after the capture and before the report.** Compute the derived folder: if `$OUT` contains `ios-6.9`, `DERIVED="${OUT/ios-6.9/ios-6.5}"`; otherwise `DERIVED="${OUT%/}-6.5"`. Guard `[ "$DERIVED" != "$OUT" ]` before anything destructive (the `rm -f` below must never point at the captures). `mkdir -p "$DERIVED"`, then `rm -f "$DERIVED"/*.png` to clear stale files, then for every `"$OUT"/*.png`: copy it to `"$DERIVED"/$(basename "$f")` and run `sips -z 2790 1284` and then `sips -c 2778 1284` on the copy, each with stdout sent to `/dev/null` (sips echoes the path on every call). Write the four numbers literally in the two sips calls — no variables — and put a one-line comment on each call: sips takes HEIGHT then WIDTH for both `-z` and `-c`, which is the trap; `-z 2790 1284` is 1284 wide by 2790 high, `-c 2778 1284` is a centred crop to 1284x2778. Under `set -e` a failing sips aborts the script, which is the behaviour we want.

**D. Report.** Replace the final `==> captured:` loop with one that prints the dimensions of every PNG in `$OUT` under a heading naming it as the captured 6.9-inch set, then of every PNG in `$DERIVED` under a heading naming it as the derived 6.5-inch set — a small function taking a label and a directory keeps it to one loop body. In derive-only mode both folders exist, so the same report runs.

**E. Verify without a simulator.** Run `bash -n tool/make_screenshots.sh`. Then copy `store/screenshots/ios-6.9/*.png` into a scratchpad directory named `.../t2/ios-6.9`, run `tool/make_screenshots.sh --derive-only <that absolute path>` (the script `cd`s to the repo root, so the path must be absolute), and `cmp` each of the five resulting `.../t2/ios-6.5/*.png` against the untracked `store/screenshots/ios-6.5/*.png`. All five must be byte-identical — the planner confirmed on 2026-09-11 that these two sips calls reproduce the existing files exactly. If any file differs, the script is wrong (almost certainly the height/width order in a sips call): fix the script; never replace or regenerate the PNGs in `store/screenshots/ios-6.5/`. Confirm `git status --porcelain -- store/screenshots/ios-6.9` is empty.

**F. Commit script and PNGs together.** `git add tool/make_screenshots.sh store/screenshots/ios-6.5/` — those two paths only; `git diff --cached --name-only` must list exactly six files. Commit with subject `feat(store): derive the 6.5-inch screenshot set for App Store Connect's default iPhone slot`, a body saying ASC's default card rejected 1320x2868, that the 6.5-inch set is the same scaling Apple would apply to a missing set, that the five PNGs are the script's output and byte-identical to a fresh `--derive-only` run, and the two trailer lines from non_negotiables item 5.
  </action>
  <verify>
    <automated>cd /Users/dima/supplements && S=/private/tmp/claude-501/-Users-dima-supplements/f357f886-2f8b-4db3-80eb-d46dfa236e6b/scratchpad/t2-verify && bash -n tool/make_screenshots.sh && grep -q 'set -euo pipefail' tool/make_screenshots.sh && grep -q -- '--derive-only' tool/make_screenshots.sh && grep -q 'sips -z 2790 1284' tool/make_screenshots.sh && grep -q 'sips -c 2778 1284' tool/make_screenshots.sh && grep -q 'ios-6.9/ios-6.5' tool/make_screenshots.sh && rm -rf "$S" && mkdir -p "$S/ios-6.9" && cp store/screenshots/ios-6.9/*.png "$S/ios-6.9/" && tool/make_screenshots.sh --derive-only "$S/ios-6.9" >/dev/null && for f in 01-stack 02-today 03-cycles 04-year 05-schedule; do cmp "$S/ios-6.5/$f.png" "store/screenshots/ios-6.5/$f.png" || { echo "DIFFERS $f"; exit 1; }; [ "$(sips -g pixelWidth -g pixelHeight "store/screenshots/ios-6.5/$f.png" | awk '/pixel/{printf "%s ", $2}')" = "1284 2778 " ] || { echo "WRONG SIZE $f"; exit 1; }; done && [ -z "$(git status --porcelain -- store/screenshots/ios-6.9)" ] && [ "$(git ls-files store/screenshots/ios-6.5 | wc -l | tr -d ' ')" = "5" ] && [ "$(git show --format= --name-only HEAD | wc -l | tr -d ' ')" = "6" ] && git show --format= --name-only HEAD | grep -q '^tool/make_screenshots.sh$' && git diff --quiet -- tool/make_screenshots.sh && [ "$(git log -1 --format=%B | tail -2)" = "$(printf 'Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>\nClaude-Session: https://claude.ai/code/session_01CXDjVs9cVBqfTyk5u8cDVV')" ] && echo TASK2_OK</automated>
  </verify>
  <done>`tool/make_screenshots.sh --derive-only` on a scratch copy of the 6.9-inch set produces five files byte-identical to store/screenshots/ios-6.5/*.png, without any simulator or xcrun call; the header documents the 6.9/6.5 split and the derivation rationale; the 6.9-inch captures are untouched; script plus the five 1284x2778 PNGs are one commit under the stated subject with the two trailer lines.</done>
</task>

<task type="auto">
  <name>Task 3: Commit the skills-lock.json change (aso skill) as its own chore commit</name>
  <files>skills-lock.json</files>
  <read_first>
    - .planning/quick/260911-mms-app-store-listing-fix-the-31-char-subtit/260911-mms-BRIEF.md (Addendum)
  </read_first>
  <action>
No content edit. The working tree already carries the change: `git diff -- skills-lock.json` adds exactly one entry, `"aso"` with source `coreyhaines31/marketingskills`, sourceType `github`, skillPath `skills/aso/SKILL.md`, and a computedHash — six added lines and nothing removed. Confirm that is all the diff contains; if it contains anything else, stop and report rather than commit.

`git add skills-lock.json` — that path only. `git diff --cached --name-only` must print exactly `skills-lock.json`. Do not stage `.agents/` or `.claude/skills/*` (ignored since commit 3030842; the lockfile is the tracked record), and do not stage `.gitignore`, `site/`, `.claude/agents/` or `.planning/` (see non_negotiables item 4).

Commit with the subject EXACTLY `chore: install the aso skill (coreyhaines31/marketingskills), lockfile only`, a one- or two-sentence body (the skill directory itself is ignored by the rule from 3030842; the lockfile records the GitHub source and a content hash so the set is reproducible and an upstream change is visible; it is the ASO reference the listing copy was written against), and the two trailer lines from non_negotiables item 5.

Afterwards `git status --porcelain` must show nothing from this task: no ` M skills-lock.json`, no ` M store/listing.md`, no ` M tool/make_screenshots.sh`, no `?? store/screenshots/ios-6.5/`. What remains — ` M .gitignore`, `?? .claude/agents/`, `?? site/`, `?? .planning/quick/` — belongs to the website subproject and the orchestrator, and is left exactly as found. Do not push.
  </action>
  <verify>
    <automated>cd /Users/dima/supplements && [ "$(git log -1 --format=%s)" = "chore: install the aso skill (coreyhaines31/marketingskills), lockfile only" ] && [ "$(git show --format= --name-only HEAD)" = "skills-lock.json" ] && git show HEAD -- skills-lock.json | grep -qE '^\+ +"aso": \{' && git show HEAD -- skills-lock.json | grep -q 'coreyhaines31/marketingskills' && [ "$(git show HEAD -- skills-lock.json | grep -c '^-[^-]')" = "0" ] && [ "$(git log -1 --format=%B | tail -2)" = "$(printf 'Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>\nClaude-Session: https://claude.ai/code/session_01CXDjVs9cVBqfTyk5u8cDVV')" ] && [ -z "$(git status --porcelain -- skills-lock.json store tool)" ] && [ "$(git rev-list --count origin/main..main)" -ge 20 ] && git status -sb | head -1 | grep -q 'ahead' && ! git status -sb | head -1 | grep -q 'behind' && echo TASK3_OK</automated>
  </verify>
  <done>HEAD is a commit touching only skills-lock.json, with the exact mandated subject and the two trailer lines, adding the aso entry and removing nothing; store/, tool/ and skills-lock.json are clean; main is at least 20 ahead of origin/main and nothing was pushed.</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| store copy → App Store Connect | Text a reviewer reads against guideline 1.4.1; the vocabulary gates exist so nothing health-shaped crosses here |
| script → filesystem | `tool/make_screenshots.sh` deletes `*.png` in the derived folder before regenerating |
| working tree → git history | Three commits on a tree that also holds an unrelated in-progress subproject |

## STRIDE Threat Register

| Threat ID | Category | Component | Severity | Disposition | Mitigation Plan |
|-----------|----------|-----------|----------|-------------|-----------------|
| T-quick-01 | Tampering | `rm -f "$DERIVED"/*.png` in make_screenshots.sh | medium | mitigate | DERIVED is derived from OUT by substitution or by a `-6.5` suffix and guarded with `[ "$DERIVED" != "$OUT" ]` before the delete; the 6.9-inch captures are tracked and Task 2's verify asserts they are unchanged |
| T-quick-02 | Tampering | listing copy drifting from the validated text | medium | mitigate | Task 1's verify compares all five blocks byte-for-byte against COPY.md and re-runs the validator (limits, keyword rules, 46 vocabulary stems derived from the two Dart tests) |
| T-quick-03 | Tampering | unrelated working-tree changes (.gitignore, site/, .claude/agents/) leaking into a commit | medium | mitigate | explicit-path staging only; every verify asserts the exact file list of HEAD |
| T-quick-04 | Information disclosure | commit reaching the remote before the owner intends | low | mitigate | no push instruction; Task 3's verify asserts main is still ahead of origin/main |
| T-quick-SC | Tampering | npm/pip/cargo installs | low | accept | no package installs in this task; the aso skill was installed by the owner before this task and only its lockfile record is committed |
</threat_model>

<verification>
After all three tasks:

- `python3 .planning/quick/260911-mms-app-store-listing-fix-the-31-char-subtit/260911-mms-validate.py store/listing.md` prints `RESULT: PASS`.
- `git log --oneline -3` shows, newest first: the `chore: install the aso skill ...` commit, the `feat(store): derive the 6.5-inch screenshot set ...` commit, the `docs(store): fix the 31-character subtitle ...` commit; each `git show --format= --name-only` matches its task (1 file / 6 files / 1 file).
- `git log -3 --format=%B | grep -c '^Claude-Session: https://claude.ai/code/session_01CXDjVs9cVBqfTyk5u8cDVV$'` prints 3.
- `git status --porcelain` shows only ` M .gitignore`, `?? .claude/agents/`, `?? site/`, `?? .planning/quick/`.
- `git rev-list --count origin/main..main` is at least 20.
</verification>

<success_criteria>
- App Store Connect will accept every Apple text field in `store/listing.md` (all within limit; keyword field obeys Apple's rules) and the copy is exactly the validated COPY.md text.
- The listing tells the uploader where each screenshot set goes and why the 6.5-inch set exists.
- `tool/make_screenshots.sh` owns the 6.5-inch set end to end, can rebuild it without a simulator, and the committed PNGs are provably its output.
- The aso lockfile change is isolated in its own commit with the mandated subject.
- Nothing outside the task's files changed or was committed; nothing was pushed.
</success_criteria>

<output>
Create `.planning/quick/260911-mms-app-store-listing-fix-the-31-char-subtit/260911-mms-SUMMARY.md` when done, with `status: complete` in its frontmatter. Do not commit it — the orchestrator commits planning docs.
</output>
