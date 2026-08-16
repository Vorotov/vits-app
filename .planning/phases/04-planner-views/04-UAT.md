---
status: complete
phase: 04-planner-views
source: [04-VERIFICATION.md]
started: 2026-08-16T04:30:00Z
updated: 2026-08-16T05:10:00Z
---

## Current Test

[complete]

## Tests

### 1. DATA-03 device re-check (core loop must not regress)
expected: `integration_test/data03_loop_test.dart` still passes on iOS and Android after the planner work
result: pass — re-run green on iPhone 17 simulator AND Android API-36 emulator both BEFORE and AFTER the CR/WR fix pass (four device runs total). `flutter analyze` clean, 547/547 unit+widget tests green.

### 2. Backstop #22 — gantt legibility with long uk names
expected: 7+ long Ukrainian names at 390pt read correctly; hatched planned vs solid active segments distinguishable
result: pass with a recorded UX note. No layout exception at scale 1.0 or 1.6; both segment kinds render; no name box ever exceeds its constraints. MEASURED: 2 of 9 names ellipsize at scale 1.0 ("Вітамін B12 метилкобаламін" 183.1px intrinsic vs 156.0px allotted; "Родіола рожева екстракт" 162.3 vs 156.0), 8 of 9 at scale 1.6; mono schedule hints truncate harder ("30.11.202…"). This is designed truncation, not clipping — but whether the gantt's label column should be wider is a genuine design call for the user. Evidence: p4-cycles-uk.png, p4-cycles-scale16-uk.png.

### 3. Backstop #23 — week-column tap ergonomics (18-19 columns)
expected: selecting a specific week is achievable in practice; mis-taps obvious and correctable
result: pass with a recorded measurement. MEASURED hit-test box per column: 14.00 x 53.00 logical px — the horizontal dimension is below the 44px guideline, reported as measured and NOT weakened. Mitigation verified: the whole column height is the target (HitTestBehavior.opaque), and columns 0, 9 and 18 each selected correctly from a tap 2px below the column top, far above the bar itself. Selection is also instantly correctable (tapping another column just re-selects). Accepted for v1; widening the columns or adding a week stepper is a possible Phase-5/v2 refinement.

### 4. Backstop #24 — midnight rollover with the planner open
expected: today marker moves; a run starting "today" flips from planned to active; no stale state
result: pass — driven deterministically through todayProvider (the app's one sanctioned clock seam), not faked: before the tick the seeded 2026-08-14 course renders planned:true; after advancing to 2026-08-14 it flips to planned:false and the today marker moves 67.79 -> 70.41 logical px (exactly one day of a 122-day window). Zero IntakeLog rows created across the rollover; no exception.

### 5. System back returns to Today (verification's PRESENT_BEHAVIOR_UNVERIFIED item)
expected: system back from the planner returns to Today, stays in the Calendar tab, does not exit the app
result: pass — closed with a real test rather than a manual check (commit aaadd47). Drives an actual platform `popRoute` message through SystemChannels.navigation against the real AppShell; asserts Today returns, planner widgets leave the tree, nav index stays 1, AND that no SystemNavigator.pop was sent (the half a tree assertion cannot see). Non-vacuity confirmed by temporarily flipping canPop and observing both tests fail.

### 6. Visual fidelity vs mockup screens 03/04
expected: Cycles gantt + load chart + week detail and Year grid + month detail match the mockup
result: pass — screenshots delivered (p4-cycles-uk, p4-loadchart-uk, p4-weekdetail-uk, p4-year-uk, p4-monthdetail-uk, p4-cycles-scale16-uk). All values are mockup-verbatim per the approved UI-SPEC; PLAN-04 framing verified present on both segments (footnote above disclaimer on Рік). Two open cosmetic notes for the user: the Year legend's two-tone swatches are hard to distinguish next to names, and a month wholly in the future labels running courses as «заплановано» (correct per the model, but a copy judgement call).

## Summary

total: 6
passed: 6
issues: 0
pending: 0
skipped: 0
blocked: 0

## Gaps

None blocking. Carried forward:
- Instrument Sans has NO Cyrillic glyphs (cmap-verified twice, Phases 2 and 4) — uk text falls back to Roboto/SF on device. Font decision belongs to Phase 5 (already in STATE.md todos).
- Riverpod 3 auto-retries a failed provider and reports the interim state as loading, so a failing local DB shows the planner's blank surface rather than the designed error surface until backoff ends. Found during the CR-02 fix, documented in 04-REVIEW.md, deliberately out of scope for Phase 4.
- Gantt label truncation (test 2) and 14px week columns (test 3) accepted for v1 with measurements recorded.
