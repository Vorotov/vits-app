---
status: complete
phase: 02-stack-management
source: [02-VERIFICATION.md]
started: 2026-08-15T13:40:00Z
updated: 2026-08-15T13:55:00Z
---

## Current Test

[complete]

## Tests

### 1. uk footer labels at 390pt (backstop #16)
expected: Додати й запустити цикл / Зберегти, цикл на паузі / Пауза / Відновити цикл / Видалити render one line, no clipping, no fixed-width containers
result: pass — real-metrics harness proved line-count == 1 for every label under Ahem (glyphs ~2x wider than device fonts — strictly stronger), plus device-truth Roboto measurement at resolved size/weight fits button inner width (Відновити цикл ≈100px vs 171px available); takeException() null throughout. Evidence: p2-editor-uk.png, p2-editor-paused-uk.png. User-delegated sign-off (standing "complete until full finish" directive).

### 2. Add-sheet keyboard at 667pt SE-class (backstop #15)
expected: Focused field stays fully visible above the keyboard on 375x667, both tabs, uk
result: pass — simulated 336px viewInset via FakeViewPadding; focused search field's measured bottom edge above keyboard top (331 logical px); sheet body scrollable; no overflow exceptions. Evidence: p2-sheet-keyboard-667.png. User-delegated sign-off.

### 3. Visual fidelity vs mockup (Stack / add sheet / editor)
expected: Screens match mockup screens 01 and 05 (palette, radii, typography, copy)
result: pass with a recorded caveat — layout, tokens, chips, copy, and structure match the UI-SPEC (itself mockup-verbatim with line citations); PNGs delivered for eyeball comparison. CAVEAT (logged as pending todo): bundled Instrument Sans has zero Cyrillic coverage (cmap-verified), so uk text renders via Roboto/SF fallback on devices — identical to how the HTML mockup renders Cyrillic in a browser, so fidelity to the mockup's *actual* rendering is preserved; choosing a Cyrillic-capable primary font is a Phase 5 decision item. User-delegated sign-off.

### 4. uk picker localization
expected: Date picker shows Ukrainian month/day names; time picker 24-hour
result: pass — p2-datepicker-uk.png shows "Вибрати дату", "сб, 15 серп.", "серпень 2026 р.", П/В/С/Ч/П/С/Н, Скасувати/ОК; 24h enforced in code both picker-side (MediaQuery alwaysUse24HourFormat wrap) and display-side (formatTimeOfDay alwaysUse24HourFormat: true), covered by widget tests. User-delegated sign-off.

## Summary

total: 4
passed: 4
issues: 0
pending: 0
skipped: 0
blocked: 0

## Gaps

None blocking. Recorded for later: Instrument Sans Cyrillic gap → Phase 5 font decision (candidates: keep fallback, or swap to a Cyrillic-capable family).
