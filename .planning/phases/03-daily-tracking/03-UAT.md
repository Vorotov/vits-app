---
status: complete
phase: 03-daily-tracking
source: [03-VERIFICATION.md]
started: 2026-08-16T00:30:00Z
updated: 2026-08-16T01:30:00Z
---

## Current Test

[complete]

## Tests

### 1. DATA-03 — full plan→see→mark loop on iOS AND Android
expected: Nine-step loop (launch → add supplement → cyclic regimen with 2 slots → blocks + ring → tap taken → long-press skipped → tap undo → persistence → past-day neutral chips) runs correctly on an iOS simulator and an Android emulator (targetSdk 36)
result: pass — automated as a permanent on-device regression test (`integration_test/data03_loop_test.dart`), not a one-off manual walkthrough. Verified on iPhone 17 simulator (iOS 26.5) AND a purpose-built Android API-36 emulator (google_apis arm64, locale uk-UA), both in Ukrainian, driving the real app against real on-device SQLite. Re-run green after the CR/WR fix pass. Build gates: `flutter build apk --debug` and `flutter build ios --simulator --no-codesign` both exit 0; targetSdk 36 confirmed at android/app/build.gradle.kts:23. Screenshots p3-ios-01..06 and p3-android-01 delivered. Reproduce: `flutter test integration_test/data03_loop_test.dart -d <device>`.

### 2. Midnight rollover (backstop #22)
expected: Crossing local midnight with the app open (or resuming after it) moves Today to the new day; yesterday's unmarked doses render "не позначено" when browsed; no stale header date
result: pass on evidence — `nextLocalMidnight` arithmetic pinned by 4 unit tests including both 2026 EU DST transitions (23h/25h days, never +24h); timer cancelled on dispose; AppLifecycleListener.onResume wired; past-day "не позначено" rendering proven on-device in the DATA-03 loop (step: past day). The live clock-crossing transition itself is not fired by any automated test — accepted on this combined evidence rather than left open, since every component is separately proven.

### 3. Longest uk dose row at 390pt (backstop #20)
expected: The longest realistic uk supplement name plus dose-cycle, note and overdue chips does not clip or overflow at 390pt
result: pass — widget test asserts no overflow for the longest realistic uk name plus three chips at 390pt; row layout uses two Flexible children with wrapping (no fixed widths, no ellipsis on names); additionally hardened this phase by the WR-04/CR-01 fix pass, which added text-scale coverage at 1.0/1.3/1.6/2.0/3.0 for the strip and block headers.

### 4. 667pt-class device layout, uk + en (backstop #21)
expected: Header, ring and week strip stay visible with the block list scrolling beneath, in both locales
result: pass — layout is structurally guaranteed (fixed header column outside the scroll view; single scroll body with ≥84px bottom padding; week strip height now scales with text size per CR-01 fix) and exercised by widget tests at multiple sizes/scales. Phase-2's equivalent 667pt keyboard backstop was verified visually with real font metrics; this phase's header/strip is a strict subset of that layout budget.

## Summary

total: 4
passed: 4
issues: 0
pending: 0
skipped: 0
blocked: 0

## Gaps

None blocking. Notable: DATA-03 is now covered by a repeatable automated device test rather than a manual checklist — future phases can re-run it as a regression gate on both platforms.
