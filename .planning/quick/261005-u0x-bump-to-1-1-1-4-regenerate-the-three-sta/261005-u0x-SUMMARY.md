---
phase: quick-261005-u0x
plan: 01
subsystem: release
tags: [release, store-assets, demo, version]
status: complete
requires: [quick-261005-nc6]
provides:
  - "pubspec version 1.1.1+4, a build number App Store Connect has not seen"
  - "listing screenshots that match the shipped regimen editor"
  - "a demo walkthrough that films all three of 261005-nc6's changes"
affects:
  - pubspec.yaml
  - integration_test/demo_video_test.dart
  - store/screenshots/
tech-stack:
  added: []
  patterns: []
key-files:
  created: []
  modified:
    - pubspec.yaml
    - integration_test/demo_video_test.dart
    - store/screenshots/ios-6.9/*.png
    - store/screenshots/ios-6.5/*.png
    - store/screenshots/android-phone/*.png
    - .planning/STATE.md
decisions:
  - "1.1.1+4, a patch: 261005-nc6 reordered a block, corrected a wrong button label and added one entry point into an existing screen — nothing newly promised to a user"
  - "The Android listing set was regenerated too, through tool/make_screenshots_android.sh, because the plan's own files_modified named android-phone/05-schedule.png and the iOS script cannot touch it"
  - "The demo's back beat asserts the editor is GONE rather than that TodayScreen is present — the route under a pushed one stays in the tree"
metrics:
  duration: ~35 min
  completed: 2026-10-05
  tasks: 3
  commits: 3
actuals:
  tokens: 9000
  tasks: 3
  commits: 3
---

# Quick task 261005-u0x: 1.1.1+4, regenerated screenshots, a demo that films the sheet

The three mechanical changes that let quick task 261005-nc6's UI work go to App
Store Connect and show up in the Devpost recording: a new version record, a
listing set photographed from the app as it is now, and a demo beat for the
dose sheet.

## Tasks

| Task | Name | Commit |
|---|---|---|
| 1 | Bump the version to 1.1.1+4 | `deeb126` |
| 2 | Demo walkthrough films the dose sheet and the schedule | `8d0cf91` |
| 3 | Regenerate the listing screenshots | `f84894b` |

## What changed

**`pubspec.yaml`** — `version: 1.1.0+3` → `version: 1.1.1+4`, nothing else in the
file. `flutter pub get` re-resolved with no dependency movement (`pubspec.lock`
unchanged).

**`integration_test/demo_video_test.dart`** — scene 3 kept its tap beat and gained
a long-press one on the same row: hold on the sheet, tap `Open dosing schedule`,
hold on the `RegimenEditorScreen` that arrives, go back. A `_longPress` helper
mirrors `_tap`'s shape (`ensureVisible` → `_pump 4` → gesture → `_pump 10`), so
the two beats on one row are paced identically. The row is the past dose
`_markPastDosesExceptOne` leaves pending, which is what gives it a long press at
all.

**`store/screenshots/`** — 14 files rewritten by the two capture scripts.

## Which screenshot files actually moved

The script rewrites the whole set, not just `05-schedule`, because the seed stack
is dated relative to the day of capture:

| Set | Files rewritten |
|---|---|
| `ios-6.9/` | all five (01-stack, 02-today, 03-cycles, 04-year, 05-schedule) |
| `ios-6.5/` | all five — derived from the 6.9-inch capture by the same script |
| `android-phone/` | four — 02-today, 03-cycles, 04-year, 05-schedule |

`android-phone/01-stack.png` came back byte-identical and is not in the commit:
nothing on the stack list carries a date.

## The regenerated editor frame

Read back from the committed PNGs, not inferred from an exit code. Both
`ios-6.9/05-schedule.png` (1320x2868) and `android-phone/05-schedule.png`
(1080x1920) show, top to bottom: the `Creatine` header, **DOSE TIMES** with the
09:00 slot and `+ Add time slot`, then **PERIODICITY** with the Cyclic /
One-time course segment and the start date, and a footer whose primary button
reads **Save**. That is the new block order and the new label, both of them.

## Verification

| Gate | Result |
|---|---|
| `flutter analyze` | `No issues found! (ran in 4.0s)` |
| `flutter test` | `All tests passed!` — **1178** |
| `flutter test test_release/` | `All tests passed!` — **48** |
| `grep -n '^version' pubspec.yaml` | `19:version: 1.1.1+4` |
| `integration_test/store_screenshots_test.dart` on device | `All tests passed!`, iOS and Android |

## Deviations from Plan

**1. [Rule 2 — missing critical work] The Android listing set was regenerated too**

The plan's action step named only `tool/make_screenshots.sh`, which captures
`ios-6.9` and derives `ios-6.5` — it cannot touch `android-phone`. But the plan's
own `files_modified` and its first truth name
`store/screenshots/android-phone/05-schedule.png`, and that file was exactly as
stale as the other two. Booted the `play_shots` AVD (1080x1920, the only profile
Play's 9:16 rule admits) and ran `tool/make_screenshots_android.sh`, the
documented counterpart script. Still generated, never hand-edited. Emulator shut
down afterwards.

**2. [Doc accuracy] The sheet shows three rows, not four**

The plan asked to "hold on the sheet long enough to read the four rows". The
sheet can never render four: the three mark rows are filtered by the DECIDED-2
transition table, so exactly one of them is always absent — `taken` suppresses
`markTaken`, `pending` suppresses `undoMark`. Three rows is the maximum. The
demo long-presses a row the preceding tap left `taken`, so the sheet shows
`Mark skipped`, `Undo` and `Open dosing schedule`. The scene comment says that
rather than repeating the plan's number.

**3. [Scope] One sentence in STATE.md Current Position was corrected**

It read "the three 05-schedule store screenshots are now stale and logged as a
new open Release row", which this task makes false. Extended rather than left
contradicting the table below it.

## Known Stubs

None.

## Threat Flags

None — no new network surface, no new permission, no new dependency. The only
Dart change is to an `integration_test/` tool that never enters `lib/`.

## Notes for the orchestrator

- `.planning/STATE.md` is **modified and uncommitted**, as instructed. The
  Release row quick task 261005-nc6 opened is closed in it, naming this task and
  `f84894b`.
- The closed row carries one live fact forward: **the App Store Connect and Play
  Console uploads are not done.** They are not deferred either — they ride with
  the 1.1.1 (4) submission these screenshots were regenerated for.
- `tool/make_demo_video.sh` was deliberately **not** run here.
- Nothing was pushed; the repo has no remote.

## Self-Check: PASSED

- `pubspec.yaml` version line: FOUND (`version: 1.1.1+4`)
- `integration_test/demo_video_test.dart` `_longPress` helper: FOUND
- 14 screenshot files in `f84894b`: FOUND
- Commits `deeb126`, `8d0cf91`, `f84894b`: all FOUND in `git log`
