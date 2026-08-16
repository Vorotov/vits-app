---
status: complete
phase: 05-localization-settings
source: [05-VERIFICATION.md]
started: 2026-08-16T09:00:00Z
updated: 2026-08-16T10:15:00Z
---

## Current Test

[complete]

## Tests

### 1. P1 — DATA-03 core loop must not regress
expected: `integration_test/data03_loop_test.dart` still passes on iOS and Android after Phase 5
result: pass — green on iPhone 17 simulator (iOS 26.5) and Android emulator-5554 (API 36), both after the Phase-5 merge AND again after the CR/WR fix pass. One transient failure was investigated and traced to leftover device data from a prior `--no-uninstall` evidence run, not a code regression; the immediate re-run and the Android run were both clean.

### 2. P2 / Backstop 14 — language switching across the whole app
expected: uk → en → System default re-renders every screen, including a pushed route and an open bottom sheet; E-12 (already-added supplements keep their saved names) holds as intended
result: pass — closed with a real on-device test (`integration_test/l10n_device_test.dart`, commit f2c5a65) rather than a manual walkthrough, green on BOTH devices. Asserts: picker lists exactly 1 + supportedLocales rows with System default first and each language under its own endonym; every switch applies on the very next frame with no dialog/snackbar/restart prompt; an already-open bottom sheet and an already-pushed regimen editor both re-render in one frame; Calendar and Planner follow. E-12 asserted as intended with a control assertion (the stored name stays Ukrainian while the surrounding chrome flips to English), so it cannot pass trivially. Evidence: p5-ios-settings-uk/en.png, p5-android-settings-uk/en.png.

### 3. P3 / Backstop 15 — instant switch + cold-start persistence (the only coverage of async main())
expected: the change appears immediately; after a real termination and relaunch the stored language shows on the first painted frame
result: pass — proven three ways, with the boundaries of each stated honestly. (a) In-test: a fresh `app.main()` with `en` stored paints English on shell frame 1 and the loop fails if any Ukrainian frame paints first — proves the bootstrap and synchronous seed, same process. (b) iOS genuine process launch: verified from the host that the app itself wrote `flutter.app_locale => en` to its plist, rebuilt the real app, installed and launched → English; wiped-container control → Ukrainian. (c) Android genuine force-stop + relaunch on the real APK: a real tap on the picker wrote `flutter.app_locale=uk`, `am force-stop` confirmed the process gone, relaunch → Ukrainian; the `en` direction likewise. Evidence: p5-ios-coldstart-en.png, p5-ios-coldstart-uk-control.png, p5-android-coldstart-en.png, p5-android-coldstart-uk-after-picker.png.

### 4. Visual half of SC1 — Ukrainian copy in context
expected: Ukrainian plural forms and copy read correctly in context across screens
result: pass on evidence — all 10 count-bearing keys carry the four CLDR forms and are exercised at 1/2/5/11/21 by tests derived from intl's own CLDR rules (not a hand-kept table); the bilingual × text-scale matrix renders six surfaces in both locales; screenshots delivered across Phases 2-5 for visual reading. Note carried from Phase 2/4 and now LOCKED: Instrument Sans has no Cyrillic glyphs, so Ukrainian renders via the platform fallback (SF/Roboto) — this matches how the approved HTML mockup itself renders Cyrillic, and is gated so it cannot be silently "fixed".

## Summary

total: 4
passed: 4
issues: 0
pending: 0
skipped: 0
blocked: 0

## Gaps

None blocking. Recorded for a future milestone:
- Physical hardware was not used (simulator + emulator only); tap latency was not measured as human perception, only frame-exactness.
- Verification W1: the claim "the codebase's only concatenation of localized fragments is gone" is inaccurate — three benign glyph-separated enumerations remain (schedule_summary_text.dart, planner_week_detail.dart). Harmless for uk/en; worth converting if a language with different word order is added.
- Review IN-01..IN-07 remain documented and unfixed by choice (gate-scope narrowness, ARB parity not checking placeholder sets, etc.).
- WR-02's regression test pins a plain error rather than reproducing the loading-carrying-error shape (Riverpod's constructor for it is internal) — the fix is contract-pinning there, verified by reading.
