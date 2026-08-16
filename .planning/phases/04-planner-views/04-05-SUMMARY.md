---
phase: 04-planner-views
plan: 05
subsystem: features/calendar (planner) + test
tags: [testing, accessibility, i18n, invariants, plan-04, text-scale, semantics]
status: complete
requires:
  - "04-04 (the finished planner: shell, gantt, load chart, week detail, year grid, month detail)"
  - "test/l10n/planner_copy_safety_test.dart (the ARB half of the PLAN-04 gate, from 04-02)"
  - "test/providers_planner_test.dart (the provider-level row-count regression, from 04-01/04-04)"
provides:
  - "test/features/planner_invariants_test.dart — the phase's executable invariant suite: source-level read-only / single-clock / token-only gates, the rendered-tree copy-exclusion gate, and the widget-tree row-count assertion"
  - "the 3-scale x 2-locale x 4-surface text-scale matrix and the assistive-technology activation cases in test/features/planner_screen_test.dart"
  - "three real layout fixes the matrix surfaced (year legend, month-detail header, month-detail row)"
affects:
  - "lib/features/calendar/planner_screen.dart (_YearLegend)"
  - "lib/features/calendar/planner_month_detail.dart (card header + _MonthRow)"
tech-stack:
  added: []
  patterns:
    - "day_block_section.dart's WR-04 remediation idiom (LayoutBuilder + ConstrainedBox ceiling) extended to the planner's two remaining rigid trailing labels"
    - "glob-resolved source-level gates over comment-stripped Dart sources, so a later planner file is covered automatically"
    - "assistive-technology ACTIVATION via tester.semantics.performAction, never a widget tap, as the binding proof of the WR-02 lesson"
key-files:
  created:
    - test/features/planner_invariants_test.dart
  modified:
    - test/features/planner_screen_test.dart
    - lib/features/calendar/planner_screen.dart
    - lib/features/calendar/planner_month_detail.dart
decisions:
  - "The excluded-content list is a single named constant at the top of planner_invariants_test.dart, matched case-sensitively for capitalized entries — the same rule the ARB gate already applies, so the two halves of PLAN-04 can never disagree about what a hit is"
  - "Three overflows found by the matrix were fixed in the widgets, never by relaxing an assertion; two of them via the codebase's own LayoutBuilder-ceiling idiom rather than a new pattern"
  - "The trailing labels WRAP rather than ellipsize: '3 речовини · межа 5' and 'частина місяця' are PLAN-04 / state content, and a truncation would read as a different claim"
  - "The source-level read-only gate was mutation-tested (a probe reference added, the gate observed red, the probe reverted) — a gate that has never failed is decoration"
metrics:
  duration: ~50 min
  completed: 2026-08-16
  tests_before: 489
  tests_after: 527
actuals:
  tokens: 13900
  tasks: 2
  commits: 3
---

# Phase 4 Plan 05: Text-Scale Matrix, Assistive-Tech Activation and the Invariant Suite Summary

The phase's standing invariants are now executable gates rather than acceptance-criterion greps: a 24-case text-scale matrix, semantics-action activation for every selectable node, and a source-plus-rendered-tree invariant suite that fails the build if the planner's read-only guarantee or its editorial framing regresses.

## What was built

**Task 1 — the text-scale matrix and assistive-technology activation** (`test/features/planner_screen_test.dart`, +27 tests, commit `50b5b6a`)

- **24 generated matrix cases**: three text scalers (1.0 / 1.6 / 2.0) crossed with two locales (uk / en) crossed with four surfaces (Цикли, Рік, empty, error), on a 390x844 phone surface.
- The fixture puts the layout under real pressure: **8 supplements with the longest uk names** in the catalogue, six overlapping courses plus one live 14/14 cycle and one paused cycle, producing **a load of 7 against an editorial limit of 5** in the week containing the pinned clock — so the over-bar, the extra free-slot pips and the longest verdict note are all in the tree while the matrix runs.
- Each case **sweeps the body to its end** (`bodyPosition(...).pixels == maxScrollExtent`) before asserting, because a `ListView` only builds what its viewport plus cache extent covers — at scaler 2.0 that is a minority of the cards. The sweep assertion is what stops the matrix passing vacuously.
- Each case then asserts `tester.takeException()` is null with a `reason:` naming the **release consequence** (a clipped label or a dropped bar in release, not debug stripes) rather than restating the assertion.
- **Accessibility half**: a week column and a month card are each **activated through `tester.semantics.performAction(...)`** — not `tester.tap` — with `hasAction(SemanticsAction.tap)` asserted first and the resulting selection asserted after, plus `isSemantics(isSelected: ...)` on both the newly-selected node and a sibling. This is the binding proof of WR-02: assistive technology does not tap widgets, and this codebase has already shipped a node that announced a button VoiceOver could not press.
- **Calendar header**: the S4-amendment action pair is asserted to render on **separate lines** at scaler 2.0 (`second.top >= first.bottom`) with no overflow — the amendment this phase made to the app's most-used screen.

**Task 2 — the invariant suite** (`test/features/planner_invariants_test.dart`, +11 tests, commit `b0aafb6`)

- *Source-level group*, over **glob-resolved** `lib/features/calendar/planner_*.dart` (never a hardcoded list of eight paths, so a ninth planner file is covered the day it lands), each file read **comment-stripped**:
  - no reference to `dayDosesProvider`, `dayDosesReadOnlyProvider`, `ensureLogsForDay`, `IntakeRepository` or `intakeRepoProvider`;
  - no direct wall-clock read (`DateTime.now(`, `DateTime.timestamp(`, `clock.now(`);
  - no raw colour literal, with `Colors\.` **anchored** so the sanctioned `BqColors.` source does not match it;
  - the pure view model's import list is **exactly** the three domain libraries, it restates no cycle-period arithmetic (`onDays` / `offDays` / `%`), and it holds no Cyrillic sentence;
  - a meta-gate asserting no planner file opens a block comment, so line-comment stripping is a *complete* comment strip and the gate is never half-blind.
- *Rendered-tree group*: the excluded-content list from the UI-SPEC "Mockup Deviations Locked for v1" table is asserted absent on **both segments in both locales**, above and below the fold, with the disclaimer asserted present on each; the gantt legend is asserted to carry exactly three entries (M1) and the tree to carry no `FloatingActionButton` (M4).
- *Row-count invariant through the real widget tree*: a rendered pass including one week selection and one month selection leaves the `IntakeLog` row count unchanged. The provider-level version already existed; this one closes the seam a grep cannot see (a transitive call) and the seam a row count cannot see (an unexercised import) — both halves are needed.
- **Every assertion carries a `reason:`** naming the invariant and its consequence, so a failure explains itself without anyone opening the plan.

## Deviations from Plan

### Auto-fixed Issues

The matrix did its job on its first run: it found **three real layout overflows**, all in shipped Phase-4 code, none of them previously visible to the suite. All three were fixed in the widget — no assertion was weakened.

**1. [Rule 1 - Bug] The year legend clipped every long supplement name, at EVERY text scale**
- **Found during:** Task 1, the Рік matrix (first failing case was scaler 1.0, uk)
- **Issue:** `_YearLegend` in `planner_screen.dart` builds one `Row(mainAxisSize: min)` per supplement inside a `Wrap`. The name `Text` was rigid, so a single long uk name ("Омега-3 риб'ячий жир концентрат") overflowed its entry row by 42-66px — at the DEFAULT text scale, not only at accessibility scales. The prior fixture's short names ("Добавка 0") had hidden it entirely.
- **Fix:** wrapped the name in `Flexible`, so it soft-wraps inside its own legend entry.
- **Files modified:** `lib/features/calendar/planner_screen.dart`
- **Commit:** `50b5b6a`

**2. [Rule 1 - Bug] The month-detail card header overflowed by 90px at scaler 2.0**
- **Found during:** Task 1, the Рік matrix at scaler 2.0
- **Issue:** `Expanded(title) + rigid meta` is overflow-proof only while the rigid child is narrower than the row. At scaler 2.0 the meta line ("3 речовини · межа 5") alone exceeds the 316px card width, `Expanded` gets zero, and the row overflows — the WR-04 defect class recurring with a different trigger.
- **Fix:** the codebase's own remediation idiom from `day_block_section.dart` — `LayoutBuilder` + `ConstrainedBox(maxWidth: ceiling)` at half the row width. Every label is far below that ceiling at scale 1.0, so the mockup layout is untouched there; above it the meta **wraps** (it is not ellipsized — the count and the limit are both PLAN-04 content).
- **Files modified:** `lib/features/calendar/planner_month_detail.dart`
- **Commit:** `50b5b6a`

**3. [Rule 1 - Bug] The month-detail rows overflowed by 40px at scaler 2.0**
- **Found during:** Task 1, the Рік matrix at scaler 2.0
- **Issue:** the same shape one level down — `Expanded(name column) + rigid state label`; at scaler 2.0 "частина місяця" alone is wider than the row.
- **Fix:** the same `LayoutBuilder` ceiling, at a third of the row width, with the state label wrapping rather than ellipsizing ("частина…" would read as a different claim about the month).
- **Files modified:** `lib/features/calendar/planner_month_detail.dart`
- **Commit:** `50b5b6a`

### Other notes

- **The plan's case-sensitivity trap was respected exactly.** `Зсунути` is matched case-sensitively in the excluded-content list because its lowercase form ships legitimately inside `weekNoteOverLimit` ("Варто зсунути старт частини з них"); a case-insensitive match would fire on approved copy. The helper mirrors the rule `planner_copy_safety_test.dart` already applies at the ARB layer.
- **`Colors\.` anchoring.** The plan's raw acceptance grep `grep -cE 'Color\(0x|Color\.fromARGB|Colors\.'` prints **86**, not 0 — every hit is `BqColors.`, the sanctioned token source, which the plan anticipated ("manually confirm any hits, if grep lacks PCRE lookahead"). Manually confirmed: `grep -oE '[A-Za-z]*Colors\.[a-zA-Z]+' | sort -u` yields only `BqColors.*`; the only `Color(` call in the whole planner is `Color(entry.supplement.colorValue)`, the user's own tag colour. The **anchored** form `'Color\(0x|Color\.fromARGB|(^|[^A-Za-z0-9_])Colors\.'` prints **0**, and that is the form the suite test uses.
- **The read-only gate was mutation-tested.** A probe reference to `intakeRepoProvider` was appended to `planner_providers.dart`, the gate was observed red (`Actual: ['lib/features/calendar/planner_providers.dart references intakeRepoProvider']`), and the probe was reverted with `git checkout -- <file>`. A gate that has never been seen to fail is decoration.
- **STATE.md / ROADMAP.md were not touched**, per the execution instructions for this worktree, and `gsd-tools` is unavailable here — the orchestrator owns those updates.

## Verification

| Check | Result |
|-------|--------|
| `flutter analyze` | **0 issues** |
| `flutter test` (full suite) | **527 / 527 passing** (Phase-3 baseline 290; wave-1-4 baseline 489; this plan +38) |
| `flutter test test/features/planner_screen_test.dart` | 77 passing (was 50) |
| `flutter test test/features/planner_invariants_test.dart` | 11 passing (new) |
| Matrix case count | 24 generated cases (plan floor: 16) |
| Read-only grep (comment-stripped) | 0 |
| Colour-literal grep (anchored) | 0 |

## Outstanding — NOT verified here

- **DATA-03 device re-check — PENDING.** `flutter test integration_test/data03_loop_test.dart` on an iOS device/simulator and an Android emulator, proving the planner did not regress the core plan-see-mark-taken loop. This executor runs in a worktree with **no device attached**; the plan explicitly designates this an orchestrator/human item and forbids faking it as an automated assertion. **It was not run.**
- **Human backstops before phase sign-off** (unchanged by this plan, still open):
  - **#22** — gantt legibility with a long-named uk stack on a simulator.
  - **#23** — picking a specific week among 18 columns on a physical device.
  - **#24** — crossing local midnight with the planner open (the automatable half — advancing the pinned clock — is already covered by the `cross-segment integration` group; the live/device-clock half is not).

Note that fixes 1-3 above changed rendered layout on the Рік segment, so backstop **#22**'s visual pass now covers slightly different output than the pre-plan build; the month-detail card and the year legend should be looked at specifically.

## Known Stubs

None. No placeholder, no `TODO`, no skipped test, and no unrun `<verify>` other than the DATA-03 device check recorded above (which is an explicit orchestrator/human item, not an executor omission).

## Threat Flags

None. This plan adds tests and three layout fixes; it introduces no network endpoint, no auth path, no file access and no schema change. The threat register's `mitigate` dispositions T-04-21 through T-04-24 are all now discharged by executable gates:

| Threat | Discharged by |
|--------|---------------|
| T-04-21 (read-only regression) | source-level gate over comment-stripped planner sources + rendered-tree row-count assertion |
| T-04-22 (editorial framing regression) | rendered-tree excluded-content gate in both locales, paired with the existing ARB-level gate |
| T-04-23 (unusable layout at accessibility settings) | the 24-case matrix — which found and forced the fixing of three real overflows |
| T-04-24 (control unreachable to assistive technology) | activation asserted through the semantics action for a week column and a month card |

## Self-Check: PASSED

- `test/features/planner_invariants_test.dart` — FOUND
- `test/features/planner_screen_test.dart` — FOUND
- `lib/features/calendar/planner_screen.dart` — FOUND
- `lib/features/calendar/planner_month_detail.dart` — FOUND
- commit `50b5b6a` — FOUND
- commit `b0aafb6` — FOUND
