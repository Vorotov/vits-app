# Boostque Onboarding (Phase 8) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** First launch shows a two-page intro (daily loop, cycle idea) that hands the user into adding their first supplement; shown exactly once, skippable, never able to trap or block launch.

**Architecture:** A gate widget replaces `AppShell` as `MaterialApp.home`. The gate watches a persisted seen-flag seeded synchronously off the `SharedPreferences` instance `main()` already resolves (zero new awaits — the two launch gates stay green). The finished-CTA path arms an in-memory one-shot that the shell branch consumes once in a post-frame callback to open the existing add-supplement sheet. `AppShell` itself is not modified.

**Tech Stack:** Flutter 3.47, Riverpod 3 manual Notifiers (no codegen), shared_preferences, gen-l10n ARB.

**Spec:** `docs/superpowers/specs/2026-08-26-boostque-onboarding-design.md`

## Global Constraints

- Zero hardcoded user-visible strings — every string through ARB (`no_hardcoded_strings_test` gate); ARB parity enforced.
- Token-only colours from `BqColors` (`theme_test` gate); no elevation; `EdgeInsetsDirectional` only (plain `EdgeInsets` allowed only as `.zero` / `.all()` / `.symmetric(vertical:)`).
- `main()` stays at exactly two awaits before `runApp` (needle gate `test/notifications/notification_bootstrap_test.dart`, counted gate `test/notifications/notification_routing_test.dart`).
- Prefs reads via `.get()` + type check, never `.getBool()` (CR-01). A null store (could not open) means **seen** (D-5). Write failures flip in-memory state anyway and go to `FlutterError.reportError`, never the user.
- No mention of reminders/permissions anywhere in onboarding (NOTIF-05). No safety/efficacy/limit vocabulary (copy gate).
- Never `await` a Drift stream subscription's `cancel()`; never `pumpAndSettle` against the shell's live midnight timer — use bounded `pump` loops.
- Ukrainian is the design language; en written to the same meaning.
- Commit to local main; **repo has no remote — never push**.

---

### Task 1: OnboardingController + PendingFirstAdd (state)

**Files:**
- Create: `lib/features/onboarding/onboarding_controller.dart`
- Test: `test/features/onboarding_controller_test.dart`

**Interfaces:**
- Consumes: `sharedPreferencesProvider` (`Provider<SharedPreferences?>`, `lib/core/providers.dart:62`).
- Produces: `onboardingSeenProvider` (`NotifierProvider<OnboardingController, bool>`; `markSeen({required bool openAddFlow})`), `pendingFirstAddProvider` (`NotifierProvider<PendingFirstAdd, bool>`; `arm()`, `consume()`).

- [ ] **Step 1: Write the failing tests**

`test/features/onboarding_controller_test.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:boostque/core/providers.dart';
import 'package:boostque/features/onboarding/onboarding_controller.dart';

void main() {
  ProviderContainer scoped(SharedPreferences? prefs) {
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('onboardingSeenProvider seed', () {
    test('empty store seeds false — first launch shows onboarding', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      expect(scoped(prefs).read(onboardingSeenProvider), isFalse);
    });

    test('stored true seeds true', () async {
      SharedPreferences.setMockInitialValues({'onboarding_seen': true});
      final prefs = await SharedPreferences.getInstance();
      expect(scoped(prefs).read(onboardingSeenProvider), isTrue);
    });

    test('null store (could not open) seeds true — D-5, no loop', () {
      expect(scoped(null).read(onboardingSeenProvider), isTrue);
    });

    test('non-bool stored value seeds true without throwing — D-6', () async {
      SharedPreferences.setMockInitialValues({'onboarding_seen': 'yes'});
      final prefs = await SharedPreferences.getInstance();
      expect(scoped(prefs).read(onboardingSeenProvider), isTrue);
    });
  });

  group('markSeen', () {
    test('persists true and flips state', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = scoped(prefs);
      await container
          .read(onboardingSeenProvider.notifier)
          .markSeen(openAddFlow: false);
      expect(container.read(onboardingSeenProvider), isTrue);
      expect(prefs.getBool('onboarding_seen'), isTrue);
    });

    test('openAddFlow arms the one-shot BEFORE the flag flips', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = scoped(prefs);
      var armedWhenFlagFlipped = false;
      container.listen(onboardingSeenProvider, (_, seen) {
        if (seen) {
          armedWhenFlagFlipped = container.read(pendingFirstAddProvider);
        }
      });
      await container
          .read(onboardingSeenProvider.notifier)
          .markSeen(openAddFlow: true);
      expect(armedWhenFlagFlipped, isTrue,
          reason: 'the gate must never rebuild before the one-shot is armed');
    });

    test('a null store still flips in-memory state — never blocks', () async {
      final container = scoped(null);
      await container
          .read(onboardingSeenProvider.notifier)
          .markSeen(openAddFlow: false);
      expect(container.read(onboardingSeenProvider), isTrue);
    });
  });

  group('PendingFirstAdd', () {
    test('consume returns true once, then false — a rebuild cannot observe it twice',
        () {
      final container = scoped(null);
      final oneShot = container.read(pendingFirstAddProvider.notifier);
      expect(oneShot.consume(), isFalse);
      oneShot.arm();
      expect(oneShot.consume(), isTrue);
      expect(oneShot.consume(), isFalse);
    });
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/features/onboarding_controller_test.dart`
Expected: compile error — `onboarding_controller.dart` does not exist.

- [ ] **Step 3: Implement**

`lib/features/onboarding/onboarding_controller.dart`:

```dart
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:boostque/core/providers.dart';

/// The persisted "onboarding shown" flag (spec D-3..D-7, ONBO-03).
///
/// Seed semantics, in the order the build checks them:
/// - a NULL store is a store that could not be opened this launch (CR-02);
///   there is no way to remember a dismissal, so re-showing would loop on
///   every cold start with no permanent escape — seen (D-5);
/// - an absent key is a first launch — not seen;
/// - `get` (Object?), never `getBool`: `getBool` is an unguarded `as bool?`
///   downcast (shared_preferences 2.5.x), so a non-bool under this key would
///   throw INSIDE this build, park the provider in a permanent error state
///   and brick the launch across restarts (the CR-01 defect class). A
///   non-bool means the store was edited outside the app; treating it as
///   NOT seen risks the same permanent re-show loop as D-5, so it means
///   seen (D-6).
class OnboardingController extends Notifier<bool> {
  static const _prefsKey = 'onboarding_seen';

  @override
  bool build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    if (prefs == null) return true; // D-5: an unopenable store never loops.
    final stored = prefs.get(_prefsKey);
    if (stored == null) return false; // first launch
    return stored is bool ? stored : true; // D-6: corrupt value never loops.
  }

  /// Leaves onboarding for good — from Skip on either page or the final CTA
  /// (D-7: set regardless of whether a supplement gets added).
  ///
  /// Order is load-bearing: the one-shot is armed BEFORE the flag flips, so
  /// the gate cannot rebuild into the shell branch and consume an unarmed
  /// one-shot. State flips before the disk write completes, matching the
  /// LocaleController stance: the user proceeds instantly; a failed write
  /// costs one re-shown onboarding on the next launch and is reported to the
  /// crash logger, never surfaced (the spec's write-failure stance).
  Future<void> markSeen({required bool openAddFlow}) async {
    if (openAddFlow) ref.read(pendingFirstAddProvider.notifier).arm();
    state = true;
    final prefs = ref.read(sharedPreferencesProvider);
    if (prefs == null) return; // D-5's cost model: next launch re-shows.
    try {
      final persisted = await prefs.setBool(_prefsKey, true);
      if (!persisted) {
        throw StateError('the onboarding store rejected the write');
      }
    } catch (error, stack) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stack,
          library: 'boostque',
          context: ErrorDescription('persisting the onboarding seen flag'),
        ),
      );
    }
  }
}

/// App-lifetime state — intentionally NOT autoDispose, like the locale
/// controller (D-23 dispose policy in core providers).
final onboardingSeenProvider =
    NotifierProvider<OnboardingController, bool>(OnboardingController.new);

/// In-memory, never persisted. Armed only by the final CTA; consumed exactly
/// once by the gate's shell branch. A cold start never has it set, so a user
/// who force-quits mid-onboarding does not get an add sheet on next launch.
final pendingFirstAddProvider =
    NotifierProvider<PendingFirstAdd, bool>(PendingFirstAdd.new);

class PendingFirstAdd extends Notifier<bool> {
  @override
  bool build() => false;

  void arm() => state = true;

  /// Returns whether it was armed, and disarms in the same call — so a
  /// rebuild cannot observe it twice.
  bool consume() {
    final armed = state;
    state = false;
    return armed;
  }
}
```

- [ ] **Step 4: Run to verify it passes**

Run: `flutter test test/features/onboarding_controller_test.dart`
Expected: all pass.

- [ ] **Step 5: Commit**

```bash
git add lib/features/onboarding/onboarding_controller.dart test/features/onboarding_controller_test.dart
git commit -m "feat(onboarding): seen-flag controller and first-add one-shot"
```

### Task 2: ARB copy + copy-safety gate coverage

**Files:**
- Modify: `lib/core/l10n/arb/app_uk.arb`, `lib/core/l10n/arb/app_en.arb` (append 9 keys before the closing `}`)
- Modify: `test/l10n/planner_copy_safety_test.dart` (extend the vocabulary gate to onboarding keys)

**Interfaces:**
- Produces: `l10n.onboardingSkip`, `onboardingNext`, `onboardingAddFirst`, `onboardingPage1Title`, `onboardingPage1Body`, `onboardingPage2Title`, `onboardingPage2Body`, `onboardingIllustrationSemantics1`, `onboardingIllustrationSemantics2` — all plain getters, none plural-bearing.

- [ ] **Step 1: Append the uk keys** (after `doseChannelDescription`, keeping valid JSON):

```json
  "onboardingSkip": "Пропустити",
  "onboardingNext": "Далі",
  "onboardingAddFirst": "Додати першу добавку",
  "onboardingPage1Title": "Ваш стек, день за днем",
  "onboardingPage1Body": "Плануйте, що приймати, і відмічайте прийняте — Сьогодні показує лише те, що потрібно саме сьогодні.",
  "onboardingPage2Title": "Цикли й перерви",
  "onboardingPage2Body": "Задайте тижні прийому та перерви — застосунок сам порахує, у які дні доза потрібна, а в які ні.",
  "onboardingIllustrationSemantics1": "Приклад списку доз: одну відмічено, одна очікує",
  "onboardingIllustrationSemantics2": "Приклад циклу: тижні прийому чергуються з перервами"
```

- [ ] **Step 2: Append the en keys** (template file; each with an `@key` description naming where it renders — match the file's existing convention):

```json
  "onboardingSkip": "Skip",
  "onboardingNext": "Next",
  "onboardingAddFirst": "Add your first supplement",
  "onboardingPage1Title": "Your stack, day by day",
  "onboardingPage1Body": "Plan what to take and mark what you've taken — Today shows only what's needed today.",
  "onboardingPage2Title": "Cycles and breaks",
  "onboardingPage2Body": "Set on-weeks and breaks — the app works out which days need a dose and which don't.",
  "onboardingIllustrationSemantics1": "Example dose list: one marked taken, one pending",
  "onboardingIllustrationSemantics2": "Example cycle: on-weeks alternate with breaks"
```

- [ ] **Step 3: Regenerate** — `flutter gen-l10n`, then `flutter analyze` (clean).

- [ ] **Step 4: Extend the copy gate.** In `test/l10n/planner_copy_safety_test.dart`: add `'onboarding'` to `plannerKeyPrefixes` (with a comment: the spec extends the same vocabulary ban to onboarding copy) and add the nine getters to the `plannerCopy` map:

```dart
    'onboardingSkip': l10n.onboardingSkip,
    'onboardingNext': l10n.onboardingNext,
    'onboardingAddFirst': l10n.onboardingAddFirst,
    'onboardingPage1Title': l10n.onboardingPage1Title,
    'onboardingPage1Body': l10n.onboardingPage1Body,
    'onboardingPage2Title': l10n.onboardingPage2Title,
    'onboardingPage2Body': l10n.onboardingPage2Body,
    'onboardingIllustrationSemantics1': l10n.onboardingIllustrationSemantics1,
    'onboardingIllustrationSemantics2': l10n.onboardingIllustrationSemantics2,
```

- [ ] **Step 5: Run the l10n gates**

Run: `flutter test test/l10n/`
Expected: all pass (parity, no-hardcoded-strings, copy safety incl. new keys).

- [ ] **Step 6: Commit**

```bash
git add lib/core/l10n/arb/ lib/core/l10n/gen/ test/l10n/planner_copy_safety_test.dart
git commit -m "feat(onboarding): copy in both locales, under the vocabulary gate"
```

### Task 3: Illustrations + page layout

**Files:**
- Create: `lib/features/onboarding/onboarding_illustrations.dart`, `lib/features/onboarding/onboarding_page.dart`

**Interfaces:**
- Consumes: `BqColors` tokens (`surfaceAlt`, `cardBorder`, `inputBorder`, `accent`, `paper`, `ink`, `textSecondary`, `plannedHatchStrong`), `context.l10n`.
- Produces: `OnboardingDosesIllustration` (const, no params), `OnboardingCycleIllustration` (const, no params), `OnboardingPage({required String title, required String body, required Widget illustration})`.

Key points (D-9): illustrations are token-built widgets, no assets, **no text** — supplement names render as rounded bars so nothing needs localizing; each is wrapped in `Semantics(label: <its semantics key>, child: ExcludeSemantics(...))`. Doses illustration: a card (`surfaceAlt` fill, `cardBorder` border, radius `BqRadii` card value) holding two mini rows — row 1 "taken": `accent`-filled circle with a white ✓ glyph drawn via `Icon(Icons.check)`? **No — no Material icon glyphs elsewhere in the codebase for the check; the real dose row paints its own glyph. Use a `Text('✓')`-free approach: a small `CustomPaint`-free container with a rotated-borders checkmark is overkill — use `Text('✓', style: ...)` only if `no_hardcoded_strings_test` permits glyphs; the real `dose_row.dart` renders its glyph the same way, so mirror exactly what `dose_row.dart` does for its taken glyph** and a name-bar with a strikethrough line (a 2px `ink`-toned `Container` overlaid via `Stack`); row 2 "pending": `paper`-filled circle with `inputBorder` border and an unstruck bar. Cycle illustration: the same card holding a `Row` of six equal `Expanded` blocks alternating `accent` (on-week) and `plannedHatchStrong` (off-week), radius `BqRadii.chip`, height ~28.

`OnboardingPage`: `SingleChildScrollView` (spec: each page independently scrollable so textScaler 2.0 cannot overflow) → `Column`: illustration, 32 gap, title (`textTheme.headlineMedium`-equivalent from `bqTheme`, `ink`), 12 gap, body (`textSecondary`), all padded `EdgeInsetsDirectional.fromSTEB(24, 24, 24, 24)`.

- [ ] **Step 1:** Check how `dose_row.dart` renders its taken glyph (`grep -n "✓\|glyph" lib/features/calendar/dose_row.dart`) and mirror that exact mechanism for the miniature.
- [ ] **Step 2:** Implement both files per above.
- [ ] **Step 3:** `flutter analyze` — clean. (Render coverage lands with the screen tests in Task 4; no standalone test file for pure-layout widgets, matching house style where leaf widgets are covered through their screen.)
- [ ] **Step 4: Commit**

```bash
git add lib/features/onboarding/onboarding_illustrations.dart lib/features/onboarding/onboarding_page.dart
git commit -m "feat(onboarding): token-built pages and illustrations"
```

### Task 4: OnboardingScreen (flow)

**Files:**
- Create: `lib/features/onboarding/onboarding_screen.dart`
- Test: `test/features/onboarding_screen_test.dart`

**Interfaces:**
- Consumes: `onboardingSeenProvider.notifier.markSeen({required bool openAddFlow})` (Task 1), `OnboardingPage`/illustrations (Task 3), the nine l10n getters (Task 2).
- Produces: `OnboardingScreen` (const ConsumerStatefulWidget).

Layout: `Scaffold(backgroundColor: BqColors.paper)` → `SafeArea` → `Column`: top row with `Spacer` + Skip `TextButton` (`textSecondary`, min 44px tap box, `padding: EdgeInsetsDirectional...`); `Expanded(PageView(controller, children: [page1, page2], onPageChanged: setState currentPage))`; two-dot indicator (`accent` current / `field` other, wrapped in `ExcludeSemantics` — decorative, D-8 rationale); primary CTA (`FilledButton`-free — mirror whatever button treatment `regimen_editor_screen.dart` uses for its save action) full-width, label `onboardingNext` on page 1 → `animateToPage(1, 300ms, Curves.easeOut)`, `onboardingAddFirst` on page 2 → `markSeen(openAddFlow: true)` fire-and-forget (`unawaited`). Skip on any page → `markSeen(openAddFlow: false)` fire-and-forget. Swiping back to page 1 allowed (PageView default); no explicit back control.

- [ ] **Step 1: Write the failing widget tests** — harness: `ProviderScope(overrides: [sharedPreferencesProvider.overrideWithValue(prefs)], child: MaterialApp(locale, delegates, supportedLocales, theme: bqTheme(), home: const OnboardingScreen()))`. Tests: (a) page 1 shows title «Ваш стек, день за днем», CTA «Далі», Skip «Пропустити»; (b) tapping «Далі» lands on page 2 («Цикли й перерви», CTA «Додати першу добавку»); (c) Skip flips `onboardingSeenProvider` true and does NOT arm `pendingFirstAddProvider`; (d) final CTA flips the flag AND arms the one-shot; (e) uk/en × 1.0/1.6/2.0 on both pages: pump, swipe to page 2, `expect(tester.takeException(), isNull, reason: overflowReason)`, and `expectNoCyrillicWhileEn` in en cases (import `../support/locale_matrix.dart`).
- [ ] **Step 2:** Run — fails (screen missing).
- [ ] **Step 3:** Implement the screen.
- [ ] **Step 4:** Run — passes. Also `flutter test test/l10n/no_hardcoded_strings_test.dart`.
- [ ] **Step 5: Commit** `feat(onboarding): two-page intro screen`

### Task 5: OnboardingGate + first-add launcher

**Files:**
- Create: `lib/features/onboarding/onboarding_gate.dart`
- Test: `test/features/onboarding_gate_test.dart`

**Interfaces:**
- Consumes: `onboardingSeenProvider`, `pendingFirstAddProvider.notifier.consume()`, `OnboardingScreen`, `AppShell` (`lib/app_shell.dart` — NOT modified), `showAddSupplementSheet(BuildContext)` (`lib/features/stack/add_supplement_sheet.dart:40`).
- Produces: `OnboardingGate` (const ConsumerWidget) — the new `MaterialApp.home`.

```dart
class OnboardingGate extends ConsumerWidget {
  const OnboardingGate({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(onboardingSeenProvider)
        ? const _FirstAddLauncher(child: AppShell())
        : const OnboardingScreen();
  }
}

class _FirstAddLauncher extends ConsumerStatefulWidget { /* holds child */ }
// initState: WidgetsBinding.instance.addPostFrameCallback((_) {
//   if (!mounted) return;
//   if (ref.read(pendingFirstAddProvider.notifier).consume()) {
//     showAddSupplementSheet(context);
//   }
// });
// build => widget.child;
```

- [ ] **Step 1: Write the failing tests** — harness needs the shell branch to mount `AppShell`, so reuse the `app_shell_test.dart` scoped pattern: override `sharedPreferencesProvider` AND `dbProvider` (in-memory `BoostqueDb.forTesting(NativeDatabase.memory())` with `ref.onDispose(db.close)`), `home: const OnboardingGate()`; bounded `pump` loops, never `pumpAndSettle` (shell midnight timer), and the `flushTearDown` idiom. Tests: (a) empty store → OnboardingScreen present, no `AppShell`; (b) stored true → `AppShell` present, no onboarding, and **no sheet opens** (cold start never has the one-shot); (c) walking the real flow — pump gate unseen, tap through to final CTA → shell appears AND the add sheet is open exactly once (find the sheet's segmented tabs); (d) Skip → shell appears and NO sheet; (e) after (c), rebuilding the shell branch (e.g. `tester.pumpWidget` same tree again) opens no second sheet — one-shot consumed.
- [ ] **Step 2:** Run — fails.
- [ ] **Step 3:** Implement the gate file.
- [ ] **Step 4:** Run — passes.
- [ ] **Step 5: Commit** `feat(onboarding): gate widget and one-shot first-add handoff`

### Task 6: Wire into main(), docs, full verification

**Files:**
- Modify: `lib/main.dart:171` — `home: const AppShell()` → `home: const OnboardingGate()` (+ import swap; `AppShell` import may drop if now unused in main.dart)
- Modify: `.planning/REQUIREMENTS.md` — Out-of-Scope row: onboarding leaves it (cite the spec as the revisit; quality scores stay out); add ONBO-01..03; traceability rows → Phase 8
- Modify: `.planning/ROADMAP.md` — add Phase 8 (Onboarding, v1.2)

- [ ] **Step 1:** Make the `home:` swap.
- [ ] **Step 2:** Run the launch-invariant gates FIRST: `flutter test test/notifications/notification_bootstrap_test.dart test/notifications/notification_routing_test.dart` — both green (the change is `home:` only; await count untouched).
- [ ] **Step 3:** Full suite: `flutter test` (background, bounded wait) — everything green; `flutter analyze` clean.
- [ ] **Step 4:** Docs edits (REQUIREMENTS, ROADMAP).
- [ ] **Step 5: Commit** `feat(onboarding): show the intro gate on first launch (Phase 8)`

## Self-Review notes

- Spec coverage: D-1..D-10 → Tasks 4/5 (D-1,2,8,9,10), Task 1 (D-3..D-7); testing table rows all mapped (unit→T1, gate/flow/one-shot→T4/T5, l10n matrix→T4, launch invariants→T6); ONBO-01..03→T6 docs; copy safety→T2.
- Type consistency: `markSeen({required bool openAddFlow})`, `consume() -> bool`, `OnboardingPage({title, body, illustration})` used identically across tasks.
- Deviation from spec, deliberate: spec's `markSeen` prose says "writes the pref, then arms, then flips"; the pref write is async, so the implemented order is arm → flip → persist, which preserves the sentence's actual constraint (one-shot armed before the gate can rebuild) and matches the LocaleController state-first stance the same spec cites for write failures.
