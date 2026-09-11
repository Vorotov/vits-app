---
phase: 05-localization-settings
plan: 05
subsystem: i18n-closeout
tags: [i18n, a11y, semantics, fonts, locked-decision, phase-gate]
status: complete

requires:
  - 05-01 (the A2 code half — the two-placeholder ARB key and the call site)
  - 05-03 (the zero-hardcoded-strings and ARB-parity gates the new key passes)
  - 05-04 (the bilingual add-supplement-sheet harness this plan's cases reuse)
provides:
  - "The repository's last concatenation of localized fragments is gone AND cannot come back: a source gate rejects `${l10n.` in the add-supplement sheet, and both languages' word order for the affected a11y label is pinned off the semantics tree"
  - "LOCKED-FONT enforced by three source-read gates (pubspec families, no fontFamilyFallback under lib/, theme families) — a quiet font change is now a red test with a named cost"
  - "The Phase-5 automated gate result: gen-l10n + analyze + 676 tests green"
affects:
  - Any future change to pubspec.yaml's fonts: block or lib/core/theme/theme.dart
  - Any future ARB key that would otherwise be assembled from two localized fragments in Dart

tech-stack:
  added: []
  patterns:
    - "Assert a merged Semantics node's label by SEGMENT (`label.split('\\n')`), not by whole-node equality — a row that is one tap target publishes one node carrying every child's text"
    - "Write the expected localized sentence out as a LITERAL in the test; rebuilding it from the same l10n call the widget makes pins nothing"
    - "Source-read gates for 'change nothing' decisions, each `reason:` naming the downstream re-work the change would force"

key-files:
  created: []
  modified:
    - test/features/stack_screen_test.dart

decisions:
  - "LOCKED-FONT closed as a locked decision: keep the platform Cyrillic fallback, no font file added or swapped, no fontFamilyFallback"
  - "The Phase-4 Riverpod auto-retry todo is closed by plan 05-02's rendering-rule change; auto-retry stays enabled in production"
  - "The Phase-4 gantt-truncation and 14px week-column measurements remain ACCEPTED for v1, unchanged"
  - "The A2 a11y label is announced as part of the row's MERGED semantics node (name, dose, then the sentence) — recorded as observed behaviour, not changed in this plan"

metrics:
  duration: ~35 min
  completed: 2026-08-16
  tests_before: 670
  tests_after: 676

actuals:
  tokens: 8400
  tasks: 3
  commits: 3
---

# Phase 5 Plan 05: Phase Close-Out — A2 Pinned, Three Todos Closed, Gates Run Summary

The catalog add affordance's accessibility sentence is now pinned in both languages off the semantics tree and protected by a source gate; the three carried todos are closed as written decisions with the two "change nothing" ones held in place by tests; and the phase's own gate command (`flutter gen-l10n && flutter analyze && flutter test`) is green at 676 tests with zero analyzer issues.

## What Was Built

### Task 1 — A2's test half (commit `10ab779`)

**The precondition held.** A2's code half landed in 05-01 Task 1 as the wave-ordering note required, and was verified on arrival rather than re-implemented:

- `grep -v "^\s*//" lib/features/stack/add_supplement_sheet.dart | grep -c '\${l10n\.'` → **0**
- `app_en.arb:926` and `app_uk.arb:167` both carry `addSupplementCatalogSemantics` (`"{action}: {name}"`), template metadata describes both placeholders.

Added to `test/features/stack_screen_test.dart`:

- Two widget cases (uk, en) that open the add-supplement sheet, scope to the Creatine catalog row, and read the published `SemanticsNode` for the trailing "+". Each asserts the exact expected sentence — `Додати добавку: Креатин моногідрат` / `Add supplement: Creatine monohydrate` — written out as a **literal**, plus `isSemantics(isButton: true)`, plus the absence of the *other* language's sentence in the same label.
- One source gate asserting the sheet contains no `${l10n.` after comment stripping. This is the failure mode 05-03's no-hardcoded-strings gate structurally cannot see: `'${l10n.a}: ${l10n.b}'` reduces to `": "` once interpolations are stripped, which is not a translatable literal, so that gate passes it.

### Task 2 — the LOCKED-FONT gates (commit `82f80a7`)

Three source-read tests in the same file, all sharing one named consequence string:

| Gate | Asserts |
|---|---|
| `pubspec.yaml declares exactly two font families, unchanged` | families == `[Instrument Sans, JetBrains Mono]` and assets == the two `assets/fonts/…ttf` paths — a third family, or a swapped file behind an unchanged name, is red |
| `no fontFamilyFallback anywhere under lib/` | comment-stripped scan of every `.dart` under `lib/` (excluding generated l10n), with a non-empty-glob assertion so an empty scan can never pass silently |
| `the theme uses the bundled families and nothing else` | `theme.dart`'s first `fontFamily:` is `Instrument Sans`, and the set of families it names is exactly the two pubspec bundles |

Scope note: the plan asked for the fallback scan over `lib/core/theme/`; it is run over all of `lib/` instead. A `fontFamilyFallback` added in a feature widget violates LOCKED-FONT just as much as one in the theme, and the wider scan is strictly stronger at no cost (P-10 measured 0 hits repo-wide).

### Task 3 — the phase gate (this document)

Ran the phase's own gate command in order. Results in **Verification** below. The on-device work is **not** run here — see **What Remains PENDING**.

---

## Locked Decisions — the three carried todos, CLOSED

### 1. Font (Phase-2 carried todo, `STATE.md:79`) — CLOSED as LOCKED-FONT: keep the platform Cyrillic fallback

**Verdict:** change nothing. `ThemeData(fontFamily: 'Instrument Sans')` stays exactly as it is (`lib/core/theme/theme.dart:27`); no font file is added, swapped or re-subset; no `fontFamilyFallback` is introduced.

**Evidence (two independent confirmations):**
- Upstream Google Fonts metadata for Instrument Sans declares `subsets: "latin", "latin-ext", "menu"` only — there is no newer file that fixes this, so no font-file *update* can ever close the gap.
- A direct `cmap` parse of the bundled `assets/fonts/InstrumentSans[wdth,wght].ttf` confirms `Ц ц ї і І Ї є ґ` are **all absent**, while `assets/fonts/JetBrainsMono[wght].ttf` carries every one of them.
- **The decisive one:** the approved HTML mockup was itself rendered in a browser where Instrument Sans has no Cyrillic. *The Ukrainian screens the user approved ARE this fallback rendering.* Keeping it is the mockup-faithful answer; changing the font is what would deviate from the approved design.

**Accepted consequences (not defects — do not file these as bugs):**
- Mixed-family lines: within `Омега-3` or `5 мг`, the Latin letters **and the digits** come from Instrument Sans while the Cyrillic letters come from the platform family, with different x-heights and advance widths.
- Rendering differs between iOS (SF fallback) and Android (Roboto fallback). Same build, two different-looking Ukrainian screens; both are correct.
- All mono text is unaffected — JetBrains Mono covers full Ukrainian Cyrillic (cmap-verified).

**The four forbidden remediations, and why each is a contract violation rather than an improvement:**

| Remediation | Why it is forbidden |
|---|---|
| Swap the primary to **Manrope** (−28,916 B) | Cheapest on bundle size, but it changes what *every* Ukrainian screen looks like versus the mockup the user approved. A whole-app visual change landing in the last phase of v1 |
| Swap the primary to **Inter** (+682,240 B) | Same fidelity objection, plus a large bundle cost, plus subsetting would add a build step this project does not have |
| Add **Noto Sans** (+2,049,096 B) | Rejected on size alone |
| Add a **`fontFamilyFallback`** family | The worst option: it still mixes two families inside a single line (digits from the primary, Cyrillic from the fallback) **and** pays the bundle cost — it buys nothing over the platform fallback the app already gets for free. (`google_fonts` is separately a never-use: this is an offline app.) |

**Cost of reversing this decision later:** the Phase-4 gantt truncation measurements (156.0px allotted / 183.1px intrinsic for `Вітамін B12 метилкобаламін`) are invalidated, because different metrics mean different intrinsic widths, and the entire bilingual text-scale matrix must be re-run. Any future font change must be a deliberate decision with that re-measurement work budgeted. That cost is now written into the `reason:` of each of the three gates above, so whoever turns them red reads it at the moment they do.

### 2. Riverpod auto-retry (Phase-4 carried todo, `STATE.md:80`) — CLOSED by plan 05-02

**Root cause:** while a retry is pending, Riverpod 3's `triggerRetry` returns `AsyncLoading` carrying `(error, stack, retrying: true)`, which makes `isReloading` true; `AsyncValue.when`'s `skipLoadingOnReload` defaults to `false`, so the `loading:` branch beat the `error:` branch. With `defaultRetry`'s 10 retries at 200 ms doubling to a 6400 ms cap, the designed error surface appeared **~38.2 seconds** after the failure — until then the user saw a blank surface.

**Fix (05-02):** make "has an error" beat "is loading" as a rendering rule at the three async surfaces — `stack_screen.dart`, `calendar_screen.dart`, `planner_screen.dart` — plus, found during execution, at the **derived merge** in `lib/core/providers.dart`, which was swallowing the error before any screen could see it.

**Auto-retry was deliberately KEPT ENABLED.** Disabling retry was the other candidate and was rejected: retry is the right production behaviour for a transient local-DB failure, and the defect was never in the retry policy — it was in which branch the surface rendered. Zero `retry:` occurrences exist under `lib/`; the only retry override in the repo is in the pre-existing CR-02 recovery test. The 05-02 error-surface tests run with the real retry timers live, so the rule is proven under the conditions that produced the bug.

### 3. Gantt label truncation and 14px week columns (Phase-4 carried todo, `STATE.md:81`) — remains ACCEPTED for v1

**Verdict:** change nothing, measurements unchanged from Phase-4 UAT.

- **Gantt labels:** 2 of 9 long Ukrainian names ellipsize at scale 1.0 (`Вітамін B12 метилкобаламін` 183.1px intrinsic vs 156.0px allotted; `Родіола рожева екстракт` 162.3 vs 156.0), 8 of 9 at scale 1.6. This is *designed truncation, not clipping* — no name box ever exceeds its constraints and no layout exception occurs. Whether the label column should be wider is a genuine design call for the user, not a defect (04-UAT.md:21).
- **Week columns:** hit-test box measured at 14.00 × 53.00 logical px. The horizontal dimension is below the 44px guideline and is reported as measured, not weakened. The full column height is the target (`HitTestBehavior.opaque`), columns 0/9/18 each selected correctly from a tap 2px below the column top, and a mis-tap is instantly correctable by tapping another column (04-UAT.md:25).

**Neither is a localization defect and neither blocks any Phase-5 success criterion** — they are legibility/ergonomics measurements on Phase-4 surfaces, recorded and accepted (04-UAT.md:53). Widening the gantt label column or adding a week stepper remains a possible v1.x refinement.

**The new Settings rows deliberately do not repeat the 14px mistake:** every language row is full-width with `HitTestBehavior.opaque` and is held at **≥52px** tall by a load-bearing `ConstrainedBox(minHeight: 52)` — load-bearing because the row's own padding + line box computes to 47.5px at scale 1.0, i.e. under 52 without it.

---

## Verification

### Automated — the phase gate command

Run in order, because this phase edits ARB files and `flutter test` does **not** run gen-l10n (PF-10); a suite run without the first step can be green against stale generated code.

| Step | Result |
|---|---|
| `flutter gen-l10n` | exit 0. Produced **no diff** — the generated sources committed in waves 1-3 are current (`git status` clean afterwards) |
| `flutter analyze` | **No issues found!** (0 issues) |
| `flutter test` | **+676: All tests passed!** — 0 failures |

**Test count against the baselines:** 547 at Phase-4 close → 670 entering this plan (waves 1-3 of Phase 5) → **676** now. The +6 are this plan's: 2 bilingual semantics cases, 1 PF-5 source gate, 3 LOCKED-FONT gates.

### Cross-phase no-change verification (T-05-SC / T-05-11)

```
git diff --stat 23aab9c HEAD -- pubspec.yaml lib/core/theme/ assets/fonts/   → EMPTY
```

`23aab9c` is the last commit before any Phase-5 work. Empty across the **whole phase**, not just this plan: zero new packages (the deliberately-rejected `package_info_plus` never entered), zero new design tokens, zero font changes. The rejected-package record stands in UI-SPEC DECIDED-1.

### Human / on-device

**Not run in this execution** — see the next section. No human-check result is recorded as passed, and none is simulated.

---

## What Remains PENDING (for the orchestrator)

Three items. Each needs a device identifier and a platform version recorded beside its result; a backstop with no recorded evidence is an unverified backstop.

### P1 — DATA-03 on-device regression, BOTH platforms *(blocking)*

- **Command:** `flutter test integration_test/data03_loop_test.dart -d <device>` — once against an iOS device or simulator, once against an Android device or emulator (the same two platforms Phase 3 used).
- **Available in this environment at execution time:** `emulator-5554` (sdk gphone64 arm64, Android 16 / API 36) and `FA55ED0D-2F18-4153-BCA5-8AE96B1E637E` (iPhone 17 simulator, iOS 26.5). Not run here: this executor is sandboxed and forbidden from running `integration_test/`.
- **Evidence required:** pass/fail plus both device identifiers and platform versions.
- **Why it is the final v1 gate:** the loop it walks (plan → see → mark taken) is the product's core value, and it runs against the real on-device database.

### P2 — Backstop 14: the whole-app bilingual walkthrough, on a PHYSICAL iOS device and a PHYSICAL Android device *(blocking)*

- Walk Українська → English → System default at the **device's own text-size setting**, reading every screen from Phases 2-4 in both languages.
- Look for: clipped or overlapping text; a screen that did not follow the switch; whether the locked mixed-family Cyrillic rendering is acceptable at ship quality on **both** platforms (it will look different on each — that is expected, the question is whether each is acceptable).
- **Evidence required:** result per platform, naming the screens walked and any defect found, with device model and OS version.
- **State at UAT so it is not filed as a bug (E-12):** supplement names already in the stack do **not** re-localize. A catalog entry copies the active locale's name onto the `Supplement` row at add-time, and from that moment it is user data. Renaming a user's supplements because they changed the app language would be the actual bug. This is asserted by a test in `stack_screen_test.dart`.

### P3 — Backstop 15: the feel of the switch, on a PHYSICAL device *(blocking)*

- With the picker open, tap a row: confirm **no perceptible lag and no flash** (the state-first ordering keeps the disk write off the repaint path).
- Force-quit, then cold-start: confirm the stored language is on the **first painted frame**, with no system-language frame before it.
- **Evidence required:** both observations, per platform, with device model and OS version.
- **Why this one cannot be traded for anything cheaper — recorded per the plan's acceptance criterion (T-05-10):** *Backstop 15's physical cold start is the ONLY evidence covering the async `main()` bootstrap.* This phase made `main()` async and injected a `SharedPreferences` instance — exactly the class of change that breaks a real launch while every widget test stays green. `integration_test/data03_loop_test.dart` pumps `VitomyApp` **directly** (lines 76/328) and never calls `main()`, so P1 proves the loop regression only and cannot substitute here. Neither can any widget test.

---

## Deviations from Plan

### Auto-fixed / adjusted during execution

**1. [Rule 1 — wrong assumption about the semantics tree] The A2 label is published on the row's MERGED node, not on a node of its own**

- **Found during:** Task 1, first run of the uk case.
- **Issue:** the assertion `node.label == 'Додати добавку: Креатин моногідрат'` failed with the actual label `'Креатин моногідрат\n5 г · порошок\nДодати добавку: Креатин моногідрат'`. The whole catalog row is one tap target, so the `Semantics(button: true, excludeSemantics: true)` annotation on the "+" merges into the row's node alongside the name and dose `Text`s rather than forming a separate node.
- **Fix:** assert on the label **segment** (`node.label.split('\n')` contains the expected sentence) instead of on whole-node equality. This keeps the check exact about the part A2 owns — the ARB sentence, its word order and its separator — without freezing whatever else the row announces. The comparison against the *other* language was likewise moved from a tree-wide `find.bySemanticsLabel` (which matches a node label WHOLE, so it would have reported "not found" in both locales and proven nothing) to a `contains` check on this node's own label.
- **Files modified:** `test/features/stack_screen_test.dart`. **Commit:** `10ab779`.
- **Observation, deliberately NOT changed:** the merged announcement repeats the supplement name ("name, dose, Add supplement: name"). Mildly redundant for a screen-reader user, but restructuring the row's semantics is a UI/a11y design change to code locked in wave 1, well outside this plan's "semantics label only, no visible change" scope. Recorded here for UAT and for a possible v1.x pass.

**2. [Scope widening, strictly stronger] The `fontFamilyFallback` scan covers all of `lib/`, not only `lib/core/theme/`**

- Rationale in Task 2 above. The acceptance criterion ("no `fontFamilyFallback` appears anywhere under `lib/core/theme/`") is satisfied as a strict subset.

**3. [Added beyond the letter of Task 1] A PF-5 source gate**

- Task 1's acceptance criteria asked only for the two-locale semantics assertion, but its `<done>` states "the repository contains zero concatenations of localized fragments". A two-locale assertion proves that is true *today*; the source gate is what keeps it true. Added because the 05-03 hardcoded-strings gate provably cannot catch this pattern (reasoning recorded in the test's `reason:`).

### Not a deviation, but worth stating

Task 3's on-device and backstop work was **not executed and not simulated**. This executor runs sandboxed with an explicit instruction not to run `integration_test/`, and the backstops require *physical* devices, which are not reachable from here regardless. Recorded as PENDING above with the evidence each needs, rather than as a partial pass.

---

## For UAT

- **Existing supplement names do not change language.** Intended (E-12) — see P2 above.
- **Ukrainian text will look slightly different on iOS than on Android**, and Cyrillic letters sit on a marginally different baseline than the digits beside them. Intended and locked (LOCKED-FONT) — this is the rendering the approved mockup itself had.
- **Gantt labels still truncate for the two longest Ukrainian names**, and week columns are still 14px wide. Unchanged from Phase 4, accepted for v1, revisit if UAT asks.

## Known Stubs

None. No placeholder values, no TODO/FIXME added, no test skipped, and every `<verify><automated>` in this plan was run to completion. The only unrun verification is Task 3's `<human-check>`, which is device-gated and recorded above as PENDING rather than as done.

## Self-Check: PASSED

- `test/features/stack_screen_test.dart` — FOUND (modified, +230 lines across two commits)
- `.planning/phases/05-localization-settings/05-05-SUMMARY.md` — FOUND
- Commit `10ab779` — FOUND
- Commit `82f80a7` — FOUND
- `flutter analyze` → 0 issues; `flutter test` → 676 passing, 0 failing (both re-run after the final commit)

## Notes for the Next Plan / Phase Sign-Off

Phase 5 has no further plans. Before sign-off, the three PENDING items above must be run and their evidence recorded. If Backstop 15's cold start is skipped, threat **T-05-10** (async `main()` on a real device launch, severity high) has **no** mitigating evidence at all — nothing else in the suite touches `main()`.
