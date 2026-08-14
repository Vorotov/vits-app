---
phase: 01-foundation
plan: 06
subsystem: ui
tags: [flutter, material3, navigationbar, riverpod, gen-l10n, i18n]

requires:
  - phase: 01-foundation (plan 01-01)
    provides: Flutter scaffold, pubspec dependencies, minimal main.dart
  - phase: 01-foundation (plan 01-03)
    provides: BqColors/BqSpace tokens and bqTheme() with navigationBarTheme + headlineSmall
  - phase: 01-foundation (plan 01-04)
    provides: gen-l10n ARB keys (appTitle, tabStack/tabCalendar/tabSettings), context.l10n extension, localeControllerProvider
provides:
  - AppShell — IndexedStack + NavigationBar three-tab shell (Stack / Calendar / Settings)
  - Three localized stub screens (heading-only designed Phase 1 state)
  - Fully-wired BoostqueApp: bqTheme() + AppLocalizations delegates + locale resolution (override → system → en fallback)
  - Widget tests proving en + uk labels, tab switching, and overflow-free uk rendering
affects: [02-stack-management, 03-calendar, 04-planners, 05-settings-l10n]

actuals:
  tokens: 2400
  tasks: 2
  commits: 3

tech-stack:
  added: []
  patterns:
    - "Feature screens live in lib/features/<name>/<name>_screen.dart and consume only tokens/theme + context.l10n"
    - "Shell chrome the theme cannot express (hairline border, mockup pixel paddings) is hardcoded in AppShell only, never tokens"

key-files:
  created:
    - lib/app_shell.dart
    - lib/features/stack/stack_screen.dart
    - lib/features/calendar/calendar_screen.dart
    - lib/features/settings/settings_screen.dart
    - test/widget/app_shell_test.dart
  modified:
    - lib/main.dart

key-decisions:
  - "FittedBox backstop realized as theme equivalence: NavigationDestination.label is a String (cannot wrap in FittedBox), so the shrink-to-fit contract is met by the theme's 10px/w500 labelTextStyle + the uk overflow widget test + the visual uk simulator check at phase sign-off"
  - "Mockup 66px destination-column width and 24px home-indicator strip accepted as deviations — Material NavigationBar flex layout cannot impose them; SafeArea/NavigationBar handle the home indicator on device"
  - "localizationsDelegates supplied via generated AppLocalizations.localizationsDelegates (bundles delegate + GlobalMaterial/Cupertino/Widgets), identical set to listing the four delegates manually"

patterns-established:
  - "Tab shell pattern: IndexedStack preserves per-tab state; NavigationBar styling flows from bqTheme(), widget adds only hairline top border + mockup paddings via EdgeInsetsDirectional"
  - "Stub screen pattern: Scaffold → SafeArea → EdgeInsetsDirectional padding → single Text styled with textTheme.headlineSmall"

requirements-completed: [DATA-01]

coverage:
  - id: D1
    description: "App launches to a three-tab shell (Stack / Calendar / Settings) via AppShell with IndexedStack + NavigationBar; stub screens show localized headings in the 25px/w600/-0.5 heading style"
    requirement: DATA-01
    verification:
      - kind: unit
        ref: "test/widget/app_shell_test.dart#en: shell shows localized tab labels and switches tabs"
        status: pass
    human_judgment: false
  - id: D2
    description: "uk locale renders Стек/Календар/Налаштування with no RenderFlex overflow (E1/E2 overflow truths), including after switching to the Settings tab"
    verification:
      - kind: unit
        ref: "test/widget/app_shell_test.dart#uk: shell shows uk tab labels without overflow"
        status: pass
      - kind: unit
        ref: "test/widget/app_shell_test.dart#uk: switching to Settings renders heading without overflow"
        status: pass
    human_judgment: false
  - id: D3
    description: "Grep gates hold: no literal Text strings, no direction-ambiguous EdgeInsets, no Drift imports in lib/features/"
    verification:
      - kind: other
        ref: "! grep -rEq \"Text\\('\" lib/features/ lib/app_shell.dart && ! grep -rq 'EdgeInsets\\.only\\|EdgeInsets\\.symmetric\\|EdgeInsets\\.fromLTRB' lib/app_shell.dart lib/features/ && ! grep -rq 'package:drift' lib/features/"
        status: pass
    human_judgment: false
  - id: D4
    description: "Tab bar and stub headers visually match mockup screen 01's footer on iOS + Android simulators; uk 'Налаштування' label renders un-clipped (UI-SPEC backstop)"
    verification: []
    human_judgment: true
    rationale: "Visual mockup-fidelity comparison and simulator rendering require human eyes at phase sign-off (plan <human-check>)"

duration: 3min
completed: 2026-08-14
status: complete
---

# Phase 1 Plan 06: App Shell Summary

**Three-tab localized shell (Stack/Calendar/Settings) via IndexedStack + NavigationBar, wired into MaterialApp with bqTheme(), gen-l10n delegates, and override→system→en locale resolution**

## Performance

- **Duration:** 3 min
- **Started:** 2026-08-14T18:05:08Z
- **Completed:** 2026-08-14T18:07:31Z
- **Tasks:** 2
- **Files modified:** 6

## Accomplishments

- AppShell: IndexedStack over three stub screens + NavigationBar with the mockup's flat hairline top border (BqColors.hairline, 1px, elevation 0 from theme) and mockup-exact paddings (top 10, start/end 22, EdgeInsetsDirectional, hardcoded per UI-SPEC exemption); UI-SPEC icon set (inventory_2 / calendar_today / settings, outlined→filled)
- Three heading-only stub screens (the designed Phase 1 state) using context.l10n + textTheme.headlineSmall, no fixed-width text containers
- BoostqueApp rewritten as ConsumerWidget: `theme: bqTheme()`, `locale: ref.watch(localeControllerProvider)` (null = system), `supportedLocales: [en, uk]` en-first fallback, `onGenerateTitle` via appTitle ARB key — zero literal user-visible strings
- Widget tests (TDD): en labels + tab switching, uk labels (Стек/Календар/Налаштування) with overflow guard, uk tab-switch overflow guard — all green; full suite 55 tests green, `flutter analyze` 0 issues

## Task Commits

1. **Task 1: AppShell + three stub screens** - `9431132` (feat)
2. **Task 2 RED: failing widget tests** - `eb975fc` (test)
3. **Task 2 GREEN: wire BoostqueApp** - `fa0a8dc` (feat)

## Files Created/Modified

- `lib/app_shell.dart` - AppShell StatefulWidget: IndexedStack + NavigationBar, hairline border, mockup paddings
- `lib/features/stack/stack_screen.dart` - Stack stub (localized heading only)
- `lib/features/calendar/calendar_screen.dart` - Calendar stub (localized heading only)
- `lib/features/settings/settings_screen.dart` - Settings stub (localized heading only)
- `lib/main.dart` - BoostqueApp ConsumerWidget wiring theme + l10n + locale
- `test/widget/app_shell_test.dart` - en/uk label, switching, and overflow widget tests

## Decisions Made

- **FittedBox equivalence (recorded per plan instruction):** `NavigationDestination.label` accepts only a String, so the UI-SPEC `FittedBox(fit: BoxFit.scaleDown)` backstop is realized as the theme's 10px/w500 `labelTextStyle` (shrink-to-fit equivalent) + the uk overflow widget test + the visual uk simulator check at phase sign-off.
- **Accepted deviations from mockup pixel spec (per plan instruction):** the 66px destination-column width and 24px home-indicator bar height cannot be imposed on Material's NavigationBar flex layout; SafeArea/NavigationBar handle the home indicator on device.
- Used generated `AppLocalizations.localizationsDelegates` (identical to hand-listing delegate + the three Global delegates).

## Deviations from Plan

None - plan executed exactly as written. (The 66px column / 24px home-indicator items above are deviations from the mockup that the plan itself pre-authorized and instructed to record here.)

## Known Stubs

- `lib/features/stack/stack_screen.dart` — heading-only stub, **intentional**: the designed Phase 1 empty state per UI-SPEC; replaced by the real Stack screen in Phase 2.
- `lib/features/calendar/calendar_screen.dart` — heading-only stub, **intentional**; replaced by the real Calendar/Today screen in Phase 3.
- `lib/features/settings/settings_screen.dart` — heading-only stub, **intentional**; replaced by the real Settings screen in Phase 5.

These stubs ARE the plan's goal (E2 truths); they do not block plan completion.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- The visible product of Phase 1 is assembled: launching the app shows the themed, bilingual three-tab shell (ROADMAP success criteria 1–2).
- Remaining phase-level backstop: visual uk simulator check (`Налаштування` un-clipped) + mockup comparison at phase sign-off (`<human-check>` in plan verification).
- No network permission requested; no login/account surface exists anywhere (DATA-01).

## Self-Check: PASSED

All 7 created/modified files exist on disk; all 3 task commits (9431132, eb975fc, fa0a8dc) present in git log.

---
*Phase: 01-foundation*
*Completed: 2026-08-14*
