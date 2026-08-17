---
status: complete
phase: 06-shell-simplification
source: [06-VERIFICATION.md, 06-REVIEW.md]
started: 2026-08-17T00:00:00Z
updated: 2026-08-17T00:00:00Z
---

## Current Test

[complete]

## Tests

### 1. P1 — DATA-03 core loop must not regress across the shell restructure
expected: `integration_test/data03_loop_test.dart` still passes on iOS and Android after Phase 6
result: **pass, after fixing the test** — green on iPhone 17 simulator (iOS 26.5) and Android
emulator-5554 (API 36). It did NOT pass as submitted, and the failures were real test defects
rather than app defects. Two of them, both fixed in `db444e3`:

- **`ensureVisible` is wrong inside a paged viewport.** The past-day step swipes the week strip
  back one page and taps a day cell. `_tap`'s `tester.ensureVisible` aligns its target to the
  viewport's LEADING edge, which inside the strip's `PageView` dragged an already-visible cell
  from x=238..292 to x=-127..-72 and let page snapping settle back to the week it started on;
  the tap then landed on nothing and the selected day never changed. Measured directly with a
  throwaway probe, not inferred. **Latent since v1**: `pastDay` only needs the swipe when today
  is a Monday (any other weekday's past day is in the same Monday-first week), and 2026-08-17 is
  the first Monday this branch has ever run on. Replaced with `_tapWeekCell`, which asserts the
  cell really is on screen — so a missed swipe reports itself distinctly — and taps it in place.
- **A populated device hides the new card.** `find.text(supplementName)` never matches when
  earlier runs' supplements push the new card below the fold of a lazily-built list. This file
  runs against the user's real database by design, so "passes only on a wiped device" would not
  be a regression test. It now scrolls to the card.

Timeouts in this file now dump the on-screen text. That is what made the first failure
diagnosable in one run instead of one run per hypothesis, and it is kept for the next one.

### 2. P1 — L10N device backstops must not regress across the shell restructure
expected: `integration_test/l10n_device_test.dart` still passes on iOS and Android after Phase 6
result: **pass, after fixing the test** — green on both devices. Three defects, all direct
consequences of NAV-03 that the phase's own retargeting of this file missed (`db444e3`):

- **The nav bar is offstage behind the pushed Settings route.** Settings stopped being a
  destination in 06-02, so while it is open the shell beneath it is mounted but offstage — and
  `find.byType` skips offstage widgets by default. Every locale and label read routed through
  `BqNavBar` threw `Bad state: No element` the moment Settings opened. The helpers are now
  explicitly offstage-tolerant, with the reason recorded at the seam: the shell staying mounted
  is precisely what "returns to the tab you were on" rests on.
- **Two steps walked from Settings straight to a tab**, which a pushed route cannot serve. Added
  `_leaveSettings`.
- **After popping back, the destination is still selected**, so the bar renders its FILLED glyph
  and the outlined-icon finder cannot match. In v1 this could not arise — visiting the Settings
  tab always deselected whatever preceded it. Added a selection-agnostic `_goToTab`.

The file also still drove the full-width "Add supplement" CTA that 06-04 deleted. Its ABSENCE on
a non-empty stack is now the assertion (UX-01), and the sheet is opened through the FAB.

### 3. SC1 visual half — the slim bar at accessibility text scales
expected: the bar is visibly slimmer than v1's, renders Стек / Сьогодні / Календар, and neither
clips nor overflows at text scale 1.0 / 1.6 / 2.0 in both locales
result: pass on measured evidence. 56.0 / 63.2 / 68.0 dp against v1's ~91dp (Material
`NavigationBar`'s fixed 80 plus the shell's `top: 10` padding and a border that added to
layout), with 18dp of slack at every scale because `Icon` does not follow the text scaler.
Asserted by PAINTED extent (`tester.getSize`), not merely "the widget builds", across all six
locale × scale cells.
**Not covered:** physical hardware. Simulator and emulator only — the bar next to a real iPhone
home indicator and real Android gesture-nav is a human check, carried below.

### 4. SC3 — Settings opens and returns without disturbing the tab
expected: the gear opens Settings from every tab and returns to the tab it was opened from
result: pass, and now proven on device as a side effect of test 2: the l10n run opens Settings
from Календар, switches language, pops, and lands back on the planner re-rendered in the new
language. That is exactly the human check 06-06 flagged as outstanding, so it is closed by
execution rather than by eye.

### 5. Review-fix pass — 2 Critical, 6 Warning, 5 Info
expected: every Critical and Warning fixed, each behavioural fix proven by a test that fails
first
result: **pass — all 13 addressed, 797 tests passing (up from 780; 17 added, none edited),
analyzer clean.** Every behavioural fix was confirmed red first; the recorded failure messages
are in each commit. Both Criticals were contracted behaviours silently absent at runtime while
the whole suite was green:

- **CR-01** (`02ee3ee`) — no `Material` inside `BqNavBar`, so `InkResponse` registered its ink on
  the Scaffold's root Material and the splash painted BEHIND the bar's own opaque fill. Press
  feedback was invisible on every destination at every scale. Red evidence: `Found 0 widgets with
  type "Material" descending from widgets with type "BqNavBar"`.
- **CR-02** (`5a5e06b`) — `loadScaleCaption` got a third of the axis row and needed ~1.6× that, so
  the self-scaling chart's ceiling was still invisible — the exact state 06-UI-SPEC D-4 argued
  against, plus a dangling ellipsis. Red at all four cells (390pt × {1.0, 1.6} × {uk, en}) on
  `didExceedMaxLines`.

**A defect the review missed, found at the spot it was looking** (`c4e0483`): the bar's `Row` used
default `CrossAxisAlignment.center`, so each destination got a loose height constraint and the
shrink-wrapped `Column` occupied 38dp inside the 56dp bar. A 9dp strip along the top and another
along the bottom looked like the destination and hit-tested to nothing — confirmed by probing a
tap at `bar.top + 3`, which reached no destination. Three contracts said otherwise (the UI-SPEC
spacing table's "full-height", S8's "opaque over the whole `Expanded` cell", and the widget's own
comment). Red: cell height `Expected: within <0.01> of <56.0> / Actual: <38.0>`.

The review was also wrong about WR-05's *mechanism* — `MainAxisAlignment.center` on a
`MainAxisSize.min` Column is a no-op; the centring was the Row's. Writing the review's suggested
doc verbatim would have replaced one durable lie with another.

**PLAN-05 held in only one of two shipped languages** (`092dede`): `limitVocabulary` carried only
Ukrainian stems while the loop reading it ran over both locales. Verified rather than inferred —
the gate as written passed 8/8 against English copy reading *"full bar = your limit — 5 at once
exceeds the threshold"*.

### 6. Device regression after the fix pass
expected: the shell changes — especially the nav bar's layout fix — break neither device test
result: pass. Both tests re-run on both platforms AFTER all 13 fixes: iPhone 17 simulator
(iOS 26.5) and Android emulator-5554 (API 36), 4/4 green. The nav-bar constraint change was the
one most likely to disturb them, which is why they were re-run rather than assumed.

## Summary

total: 6
passed: 6
issues: 0
pending: 0
skipped: 0
blocked: 0

## Gaps

Carried forward, none blocking:

- **Physical hardware still untested.** The 56dp bar and the FAB have been measured and rendered
  at 1.0/1.6/2.0 on a simulator and an emulator, never held in a hand. Measurement is not
  looking at it. Delivered as an APK for the owner to check.
- **The load chart has not been read against a real multi-supplement stack.** Whether a full bar
  actually reads as "my whole stack overlaps here" is a judgement only the stack's owner can
  make. The caption's legibility is now a measured test (CR-02), but the fix trades truncation
  for wrapping, so the Цикли card is slightly taller at textScaler >= 1.6 — worth a glance
  alongside backstop #21.
- **Release builds are still debug-signed** — pre-release blocker, asserted in
  `test/platform_config_test.dart` so it cannot be forgotten, and needs a keystore only the
  project owner can create.
- Info-level review findings are recorded in `06-REVIEW.md`; those deliberately left unfixed
  will be named there with a reason.
