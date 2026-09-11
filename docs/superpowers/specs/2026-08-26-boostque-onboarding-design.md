# VitoMy onboarding — design

**Date:** 2026-08-26
**Status:** approved for planning — **built as written, then partly superseded
on 2026-08-31.** D-1 and the *Screens* section no longer describe the shipped
app. Nothing below is edited: it is the record of what was approved on
2026-08-26. What replaced it, and the evidence that forced it, is the last
section of this file, *What shipped*.
**Milestone:** v1.2
**Supersedes:** the REQUIREMENTS.md "Out of Scope" row *"Onboarding flow,
quality scores — Mockup v0.1 explicitly excludes; revisit post-v1"*. This
document is that revisit. The row is amended, not silently contradicted.

## Problem

A first-time user launches VitoMy into an empty Stack screen. Nothing
explains what the app is for, and — more importantly — nothing explains
the one thing that makes it different from a checklist: **cycles**, the
on/off week arithmetic the whole planner is built around. The app is also
inert until at least one supplement exists, so the first impression is a
blank screen with a floating `+`.

Onboarding closes both: it says what this is, it names the cycle idea, and
it hands the user directly into adding their first supplement.

## Non-goals

- **No permission priming.** Notification permission is requested at first
  regimen save and never at launch (NOTIF-03), and Settings is the only
  place reminder state is discussed (NOTIF-05, owner decision 2026-08-17).
  Onboarding does not mention reminders, does not request permission, and
  adds no toggle. Owner-confirmed 2026-08-26.
- **No language picker.** System language already resolves (L10N-02) and
  Settings carries the override (L10N-03). A picker here duplicates it.
- **No account, no tour overlay, no coach marks, no progress gamification.**
- **No quality scores.** The other half of the Out-of-Scope row stays out.

## Decisions

| # | Decision | Rationale |
|---|---|---|
| **D-1** | Two explain screens, then the add-supplement handoff. | Owner choice 2026-08-26. Shorter is the point; the third "reminders" screen was dropped to keep NOTIF-05 intact without reinterpretation. |
| **D-2** | Onboarding is a **gate widget**, not a pushed route. | Third frame-1 seed in this codebase after the locale seed and the launch payload; one recognizable pattern. Keeps the Navigator out of it, so `AppShell`'s "no route is ever popped" invariants are untouched. |
| **D-3** | Seen-flag persisted in `SharedPreferences`, key `onboarding_seen`. | Exactly the role the stack doc assigns it: one small persisted setting. Not Drift — this is not user data and must not sync. |
| **D-4** | Read the flag off the instance `main()` already resolves. | `main()` is gated at **exactly two awaits before `runApp`** by two tests (`notification_bootstrap_test.dart` needle gate, `notification_routing_test.dart` counted gate). Reusing the resolved instance costs zero additional awaits, so onboarding paints on frame one with no launch regression. |
| **D-5** | A store that could not be opened means **already seen**. | `main()` already degrades rather than blocking launch (CR-02). Treating an unreadable store as *unseen* re-runs onboarding on every cold start with no way to dismiss it permanently — a loop is worse than a first-time user missing the intro once. |
| **D-6** | Read via `.get()` and type-check, never `.getBool()`. | `getBool` is an unguarded `as bool?` downcast in shared_preferences 2.5.x. A non-bool under this key throws inside the provider build, parking it in a permanent error state and bricking launch across restarts — the exact CR-01 defect already fixed in `LocaleController`. The type of untrusted storage is as untrusted as its content. |
| **D-7** | The flag is set when the user **leaves the last screen**, whether or not a supplement is added. | Re-showing onboarding because the user cancelled the add sheet punishes a legitimate choice. An empty stack is recoverable; a loop is not. |
| **D-8** | Skip is available on every page. | Non-negotiable for an intro screen. It sets the same flag and lands on the shell without opening the add sheet. |
| **D-9** | Illustrations are built from the app's own surfaces using existing tokens — no bundled image assets. | Teaches the real UI rather than a generic graphic, adds no binary assets, and stays inside the token-only rule with no new tokens. |
| **D-10** | The add-supplement handoff goes through the existing `showAddSupplementSheet(context)`. | The FAB's entry point. One way to open the add flow, not two. |

## Architecture

```
main()
  └─ prefs (already resolved, 0 new awaits)
      └─ VitomyApp / MaterialApp
          └─ OnboardingGate            <- new
              ├─ onboardingSeen == false  ->  OnboardingScreen
              └─ onboardingSeen == true   ->  _FirstAddLauncher(child: AppShell)
```

### Files

**Create — `lib/features/onboarding/`**

| File | Responsibility |
|---|---|
| `onboarding_controller.dart` | `OnboardingController extends Notifier<bool>` — the persisted seen flag, seeded synchronously from `sharedPreferencesProvider` per D-4/D-5/D-6. Exposes `markSeen({required bool openAddFlow})`. Also declares `pendingFirstAddProvider`, the in-memory one-shot. |
| `onboarding_gate.dart` | The gate of D-2. Watches the controller; returns onboarding or the shell branch. Contains `_FirstAddLauncher`, a `ConsumerStatefulWidget` mounted only on the shell branch that consumes `pendingFirstAddProvider` once in a post-frame callback and calls `showAddSupplementSheet`. |
| `onboarding_screen.dart` | The two-page `PageView`, the page indicator, Skip, and the primary CTA. Owns all navigation between pages. |
| `onboarding_page.dart` | One page's layout: illustration slot, title, body. No page-specific logic. |
| `onboarding_illustrations.dart` | The two token-built illustrations (D-9). |

**Modify**

| File | Change |
|---|---|
| `lib/main.dart` | One line: `VitomyApp`'s `home:` (line 171) becomes `OnboardingGate` instead of `AppShell`. Nothing above `runApp` changes — the await count is unchanged and its two gates stay green. |
| `lib/core/l10n/arb/app_en.arb`, `app_uk.arb` | New copy keys (below). |
| `.planning/REQUIREMENTS.md` | Amend the Out-of-Scope row; add the ONBO requirements. |
| `.planning/ROADMAP.md` | Add Phase 8. |

`AppShell` itself is **not modified**. That is a deliberate constraint: its
notification-tap listener carries invariants documented at length, and this
feature has no business near them.

### State

```dart
// Persisted. false = show onboarding.
final onboardingSeenProvider =
    NotifierProvider<OnboardingController, bool>(OnboardingController.new);

// In-memory, not persisted. Set true only by the final CTA; consumed exactly
// once by _FirstAddLauncher. A cold start never has it set, so a user who
// force-quits mid-onboarding does not get an add sheet on next launch.
final pendingFirstAddProvider =
    NotifierProvider<PendingFirstAdd, bool>(PendingFirstAdd.new);

class PendingFirstAdd extends Notifier<bool> {
  @override
  bool build() => false;
  void arm() => state = true;
  /// Returns whether it was armed, and disarms in the same call — so a
  /// rebuild cannot observe it twice.
  bool consume() { final armed = state; state = false; return armed; }
}
```

`markSeen({required bool openAddFlow})` writes the pref, then sets
`pendingFirstAddProvider` if requested, then flips its own state — in that
order, so the gate cannot rebuild before the one-shot is armed.

**Write-failure stance:** if persisting the flag throws, the in-memory state
still flips and the user proceeds to the app. Onboarding will reappear on the
next launch, which is a mild annoyance; blocking the user inside onboarding
because a disk write failed is not acceptable. The failure is reported to the
crash logger via `FlutterError.reportError`, matching `main()`'s stance — not
surfaced to the user, who can do nothing about it.

## Screens

Both pages: illustration, then title, then body. Each page is independently
scrollable (`SingleChildScrollView`) so textScaler 2.0 cannot overflow —
this is the codebase's most frequent review defect and is designed out
rather than tested for afterwards.

Chrome, constant across pages:
- **Skip** — top, trailing edge, `TextButton`, `textSecondary`. ≥44px box.
- **Page indicator** — two dots above the CTA. `accent` for the current
  page, `field` for the other. Decorative: excluded from semantics, since
  the CTA label already states position.
- **Primary CTA** — pinned above the bottom `SafeArea`, full width of the
  content column. Page 1: *Далі* / *Next*. Page 2: *Додати першу добавку* /
  *Add your first supplement*.
- **Back** — swiping right returns to page 1; page 1 has no back. No
  explicit back control, because Skip is the escape and two controls for
  leaving one screen is the D6 mistake the FAB decision already corrected.

### Page 1 — what this is

- **Title (uk):** «Ваш стек, день за днем»
- **Body (uk):** «Плануйте, що приймати, і відмічайте прийняте — Сьогодні
  показує лише те, що потрібно саме сьогодні.»
- **Illustration:** a miniature of two real dose rows — one `taken` (calm
  fill, ✓, struck name), one `pending` (empty circle). Built from the same
  tokens `dose_row.dart` uses.

### Page 2 — the cycle idea

- **Title (uk):** «Цикли й перерви»
- **Body (uk):** «Задайте тижні прийому та перерви — застосунок сам
  порахує, у які дні доза потрібна, а в які ні.»
- **Illustration:** a small horizontal week strip, alternating solid
  `accent` blocks (on-weeks) and `plannedHatch*` blocks (off-weeks), using
  the gantt's existing tokens.

English copy is the template file and is written to the same meaning, not
transliterated. Ukrainian is the design language (skill rule).

### Copy safety

No string on either page makes a safety, efficacy, interaction or
pharmacological claim, names a limit or threshold, or assigns blame. "Цикли
й перерви" describes scheduling, not physiology. The planner copy gate
(`planner_copy_safety_test.dart`) is scoped to planner keys; this spec
requires the onboarding keys be added to its coverage so the same
vocabulary ban applies here.

### New ARB keys

`onboardingSkip`, `onboardingNext`, `onboardingAddFirst`,
`onboardingPage1Title`, `onboardingPage1Body`, `onboardingPage2Title`,
`onboardingPage2Body`, `onboardingIllustrationSemantics1`,
`onboardingIllustrationSemantics2`.

None are plural-bearing, so the four-form Ukrainian requirement does not
apply to any of them; ARB parity does, and is enforced automatically.

## Testing

| Level | What |
|---|---|
| Unit | Controller seeds `false` on an empty store, `true` on a stored `true`, `true` on a **null store** (D-5), and `true` on a **non-bool value** without throwing (D-6). Persist failure still flips in-memory state and reports (the write-failure stance under **State**). |
| Widget — gate | Unseen shows onboarding and no `AppShell`; seen shows `AppShell` and no onboarding; flipping the flag swaps the branch within one pump. |
| Widget — flow | Skip from page 1 and from page 2 both mark seen and open **no** sheet. The final CTA marks seen and opens the add sheet **exactly once**. Cancelling that sheet leaves seen `true` (D-7). A re-pump after completion never shows onboarding again. |
| Widget — one-shot | `pendingFirstAddProvider` is consumed once: a rebuild of the shell branch does not open a second sheet. A cold start with seen `true` opens no sheet. |
| l10n | Onboarding added to the bilingual × textScaler render matrix: uk and en at 1.0 / 1.6 / 2.0, both pages, zero layout exceptions. Onboarding keys added to the copy-safety vocabulary gate. |
| Launch invariants | The two `main()` await gates stay green — the change is `home:` only. Asserted by the existing tests continuing to pass, called out explicitly in verification. |

## Requirements added

- **ONBO-01** — On first launch the user sees a two-screen introduction
  explaining the daily loop and the cycle model, skippable from either
  screen, in the resolved app language.
- **ONBO-02** — Completing the introduction hands the user directly into
  adding their first supplement, through the app's single add entry point;
  cancelling that leaves the user on the Stack screen with onboarding
  already marked seen.
- **ONBO-03** — The introduction is shown once. A store that cannot be read
  or written never traps the user in it, and never blocks launch.

## Risks

| Risk | Handling |
|---|---|
| The gate adds a frame-1 branch to a launch path with two enforced await gates. | The flag reads off the already-resolved store; the change is the single `home:` line at `main.dart:171`. Verification names the two gates explicitly. |
| Illustrations built from real surfaces could drift from the real widgets. | Accepted. They are miniatures using shared tokens, not copies of the widgets — if a dose row is restyled, the miniature reads as slightly dated, not broken. A test would over-couple two things that are allowed to differ. |
| An empty stack after a cancelled add sheet is still an empty first impression. | Accepted and out of scope. The Stack empty state already exists (`emptyStackTitle`/`emptyStackBody`) and points at the FAB. |


---

# What shipped

**Written 2026-09-02, after Phase 8 shipped.** Everything above is left exactly
as it was approved on 2026-08-26, because it was built that way first — the
deck exists in `056ccf0`..`6d6f512`. This section records what replaced part of
it on 2026-08-31, and the evidence that forced the replacement. Where the two
disagree, this section is the app.

## What forced it

The deck was built, then read against the research rather than shipped on the
strength of D-1. Nielsen Norman Group's 70-participant test of app intros found
that participants who read an intro tutorial rated the **same** tasks *harder*
afterwards — 4.92 against 5.49 of 7 — with no gain in task success and no gain
in speed. NN/g's coach-mark guidance fails the same way for the same reason: a
sequence fired at session start explains things before the user has any use for
them.

The finding is not "intros are bad". It is that explanation detached from the
moment of need makes a simple product feel complicated — which is the exact
risk for an app whose one non-obvious idea (cycles) cannot even be acted on
until the user is inside a regimen editor.

Owner decision 2026-08-31: **path A** — no overlays, no spotlight, no dimming,
no blocking, no sequence. The intro shrinks to what only an intro can say, and
everything else moves to the moment its subject appears.

## Decision delta

| Superseded | What shipped instead | Why |
|---|---|---|
| **D-1** — two explain screens: the daily loop, then the cycle model. | **D-1a** — two pages: page 1 the daily loop, **page 2 what the Календар answers**. The cycle model is not in the intro at all. | The research above. It went two pages → one (`677b582`) → two again (`b49f4e7`), and the count kept being revisited because the real question was *which* page earns its place, not how many. |
| **Screens § Page 2 — the cycle idea**, with the on/off week-strip illustration. | **Page 2 — the calendar.** Title: «Календар бачить усе разом» / "The calendar sees it all at once". Body names the three questions the planner answers — where you are in each cycle, what overlaps with what, when the next break starts. Illustration: three supplements whose on-weeks partly overlap (`OnboardingCalendarIllustration`). | A contextual hint cannot answer "why is there a calendar tab": a hint on Календар only fires once the user opens Календар, and nothing before that point gives them a reason to. This is the one thing the intro can say that no hint reaches. |
| *(nothing — this is new)* | **D-11** — two one-time **inline contextual hints**, rendered by `BqHintCard` (`lib/core/widgets/bq_hint_card.dart`), state in `lib/features/onboarding/first_run_hints.dart`. | Path A. The card takes its place in the layout: nothing is dimmed, nothing is blocked, nothing steals focus, and dismissing is one tap and permanent. A hint the user ignores costs one glance. |
| | **D-12** — each hint appears where and when its subject first appears. `BqHint.cycle` renders inside the regimen editor's schedule panel, and only while the draft is cyclic — the sliders that define a cycle are on screen. `BqHint.markDose` renders on Сьогодні, and only on a day whose dose list is non-empty. | An explanation of marking a dose on a day with no doses describes an action the user cannot take; an explanation of cycles before a regimen exists is the deck's failure in miniature. |
| | **D-13** — hint storage repeats D-5/D-6 exactly: `.get()` with a type check, never `getStringList`; an unreadable store, or a value of the wrong type, means **every hint is already dismissed**. | Same reasoning as D-5, applied to a set: a hint whose dismissal cannot be remembered returns forever, which is worse than never showing it. |
| | **D-14** — a Settings row restores the intro **and** every dismissed hint, **in every build**. It writes only the two first-run preference keys; supplements, regimens and intake logs are untouched. | It was `kDebugMode`-gated on `9f14fcc` and shipped everywhere on `fa67879`: the only other way to see the intro again on a real device is deleting the app, and that takes the user's stack with it. "Show me that again" is an ordinary thing to want from a settings screen. |

**The *Non-goals* list survives intact.** The hints are not coach marks: no
overlay, no spotlight, no sequence, and nothing fires at session start. Each is
an inline note beside the thing it describes.

**D-2 through D-10 all still hold**, unchanged and in the shipped code: the
gate widget, the `onboarding_seen` key, zero extra awaits before `runApp`,
seen-wins degradation, `.get()` over `getBool()`, the flag set on leaving
whether or not a supplement is added, Skip on every page, token-built
illustrations with no bundled assets, and the single `showAddSupplementSheet`
entry point.

## Files, as built

Beyond the *Files* table above:

| File | Status |
|---|---|
| `lib/features/onboarding/first_run_hints.dart` | New. `BqHint` (`cycle`, `markDose`), the `FirstRunHints` notifier over the persisted id set, and `showsHint(dismissed, hint)`. |
| `lib/core/widgets/bq_hint_card.dart` | New. The accent-tinted inline note with a real 44px dismiss target. A core widget, not an onboarding one: two features render it. |
| `lib/features/calendar/today_screen.dart` | Modified — renders the `markDose` hint **inside** the day body's `ListView`. |
| `lib/features/stack/regimen_editor_screen.dart` | Modified — renders the `cycle` hint at the top of the schedule panel. |
| `lib/features/settings/settings_screen.dart` | Modified — `_ShowIntroAgainRow`, a private widget in the same file. |

`AppShell` is still not modified. The constraint held.

**New ARB keys beyond the spec's list:** `hintDismiss`, `hintCycle`,
`hintMarkDose`, `debugResetOnboarding` (the Settings row — the key name is a
leftover from when the row was debug-only; the row itself ships everywhere).
`onboardingPage2Title`, `onboardingPage2Body` and
`onboardingIllustrationSemantics2` survived the redesign as keys and were
rewritten for the calendar. All of them sit under the copy-safety vocabulary
gate, which since 2026-09-01 runs across all seven shipped locales in
`test_release/copy_safety_all_locales_test.dart`.

**One divergence worth naming:** the *State* section above says `markSeen`
writes the pref, then arms the one-shot, then flips its state. The shipped
order is arm → flip → write: the flip must not precede the arm (the gate would
rebuild into the shell branch and consume an unarmed one-shot), and the write
must not precede the flip (the user would wait on a disk write to leave a
screen). The invariant the spec was protecting is the one that shipped.

## Two defects the redesign surfaced

- **The hints did not disappear when dismissed.** Both call sites watched
  `firstRunHintsProvider.notifier`, which rebuilds only when the notifier
  *instance* changes; dismissing updated the set and left the card on screen.
  Both now go through `showsHint(ref.watch(firstRunHintsProvider), …)` — the
  set, which is the thing that actually changes. Caught by the hint suite
  before any device saw it.
- **The `markDose` hint overflowed Сьогодні by 8px at textScaler 2.0.** It sat
  in the screen's fixed column above the day body, which does not scroll, and a
  longer sentence from the copy pass made it two lines. It now lives inside the
  day body's scrollable list, so a longer translation cannot reintroduce the
  same defect on the app's most-used screen.

## Requirements delta

- **ONBO-01** is amended in REQUIREMENTS.md: the second page explains the
  calendar, not the cycle model.
- **ONBO-04** (the contextual hints) and **ONBO-05** (the Settings restore row)
  are added there. ONBO-02 and ONBO-03 shipped as written.
