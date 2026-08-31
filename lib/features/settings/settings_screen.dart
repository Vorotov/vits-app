/// The Settings screen — full S7 contract (plan 05-01), replacing the Phase-1
/// stub.
///
/// NOT a tab. Since plan 06-03 this is a pushed `MaterialPageRoute` entered
/// from the gear row on Стек / Сьогодні / Календар, and it covers the nav bar
/// rather than being a destination on it (NAV-03, 06-UI-SPEC S12). That is why
/// it carries its own back control and ordinary body padding — both documented
/// where they are built, below.
///
/// Content is: title, mono eyebrow, language card (DECIDED-1), and — since plan
/// 07-05 — a second section stating whether the operating system allows this app
/// to post dose reminders, with one control opening the system's own
/// notification settings (NOTIF-05, DECIDED-9a). That section carries no
/// numeral, no toggle, no quiet-hours control, no per-slot choice and no
/// schedule detail; all of those remain deferred, and the honest statement of
/// the reminder horizon — which wants a magnitude — belongs to the deferred
/// notification-settings screen. A state row needs no number, which is exactly
/// what makes it fit on this screen.
///
/// There is still no
/// version/About line (it would need a package, or a hardcoded string that
/// drifts from pubspec — a lie on the one screen whose whole job is to be
/// truthful about configuration) and no educational disclaimer: PLAN-04 binds
/// the disclaimer to the PLANNER surfaces, and Settings is not one of them.
/// (It is deliberately not bound to "screens that assert an editorial limit" —
/// PLAN-05 deleted that entire layer and the rewritten `plannerDisclaimer`
/// asserts no limit at all, so a rationale resting on one would be a lie
/// about a screen this file does not even own.)
///
/// The screen has NO async surface and NO error surface, and none may be added
/// (DECIDED-8): `AppLocalizations.supportedLocales` is a compile-time const and
/// `LocaleController` is a synchronous `Notifier`, so nothing here can be in
/// `AsyncLoading` or `AsyncError`. The permission answer added in plan 07-05 is
/// inherently a future, and it is held as a plain three-valued boolean for
/// exactly this reason: while it is not yet known the section renders NOTHING —
/// not a placeholder, not a dimmed row, not a spinner. An absent row is not a
/// loading surface, and a row stating an unknown fact would be a lie on the one
/// screen whose whole job is to be truthful about configuration. Every failure
/// on that path is absorbed and reported by the controller, which lives in
/// `core` precisely so that this screen keeps no error surface at all.
/// A failed `shared_preferences` write is
/// deliberately silent — the language visibly took effect, and an error banner
/// about a setting that worked is worse than the self-correcting quiet.
/// Selecting IS the commit: no Save, no Apply, no snackbar, no restart prompt
/// (DECIDED-7).
///
/// `ListView`, never a `Column`: at textScaler 2.0 with several languages the
/// content exceeds the viewport and a `Column` would overflow. No `AppBar` —
/// the title lives in the body, matching the app's three bar-reachable
/// screens: Стек, Сьогодні and Календар. (The third peer this doc used to name
/// was the old combined calendar screen, deleted in plan 06-03 when the Today
/// page was promoted out of it — its symbol is deliberately not written here,
/// because `shell_invariants_test.dart` greps lib/ for it, comments included.)
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:boostque/core/l10n/l10n.dart';
import 'package:boostque/core/notifications/notification_permission.dart';
import 'package:boostque/core/theme/theme.dart';
import 'package:boostque/core/theme/tokens.dart';
import 'package:boostque/features/onboarding/first_run_hints.dart';
import 'package:boostque/features/onboarding/onboarding_controller.dart';
import 'package:boostque/features/settings/language_picker.dart';

/// The Settings screen (UI-SPEC S7).
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          // 20px horizontal padding is the screen-body value every other
          // screen uses. The bottom is ORDINARY body padding, not the >= 84px
          // nav-bar clearance the three bar-reachable screens carry: Settings
          // is a pushed route that covers the bar (UI-SPEC S12), so there is
          // nothing under it to clear and 84 would only be dead space.
          padding: const EdgeInsetsDirectional.only(
            start: 20,
            end: 20,
            top: BqSpace.lg,
            bottom: BqSpace.lg,
          ),
          children: [
            // The pushed route's way out (UI-SPEC S12). It exists because a
            // pushed route with no back affordance passes every widget test —
            // tests pop programmatically — and strands the user on the first
            // manual run on any device without a reliable back gesture
            // (research PF-6).
            //
            // Its own start-aligned row, the exact mirror of the gear row the
            // three bar-reachable screens carry: the row holds NO text, so its
            // extent is pure geometry and it cannot overflow at any text scale,
            // in any locale, in any direction (D-5).
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Semantics(
                  button: true,
                  label: l10n.navBack,
                  excludeSemantics: true,
                  // The action lives on THIS node, not only on the IconButton
                  // below it: `excludeSemantics: true` drops every descendant
                  // action, so without this the control would announce itself
                  // as a button VoiceOver / TalkBack cannot activate — and on
                  // a pushed route it is the only way out (WR-02).
                  onTap: () => Navigator.maybePop(context),
                  child: IconButton(
                    // `maybePop`, not `pop`, for the same reason the regimen
                    // editor's chevron uses it (regimen_editor_screen.dart:221):
                    // the screen must not assume it was pushed.
                    onPressed: () => Navigator.maybePop(context),
                    // A bounded, text-free 44x44 box — >= 44pt guidance, and it
                    // cannot grow with the text scaler.
                    constraints: const BoxConstraints.tightFor(
                      width: 44,
                      height: 44,
                    ),
                    padding: EdgeInsets.zero,
                    // Glyph, size and colour verbatim from
                    // regimen_editor_screen.dart:221-226.
                    icon: const Icon(
                      Icons.arrow_back_ios_new,
                      size: 18,
                      color: BqColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
            // One key, two placements: the gear's semantics label on every
            // bar-reachable screen and this title, so the control and its
            // destination can never disagree.
            Text(
              l10n.settingsTitle,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 18),
            // Stored uppercase in the ARB, never toUpperCase()'d at runtime —
            // side-stepping locale-independent casing entirely (PF-6).
            Semantics(
              header: true,
              child: Text(
                l10n.settingsLanguageTitle,
                style: BqText.mono(
                  size: 10.5,
                  color: BqColors.textMuted,
                  letterSpacing: 0.63,
                ),
              ),
            ),
            const SizedBox(height: 10),
            // The card carries zero padding of its own: the rows own all
            // inset, so the 1px hairline dividers run full-bleed and the list
            // reads as one continuous control group (DECIDED-5).
            Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: BqColors.surface,
                border: Border.all(color: BqColors.cardBorder),
                borderRadius: BorderRadius.circular(BqRadii.card),
              ),
              child: const LanguagePicker(),
            ),
            const _RemindersSection(),
            const _ShowIntroAgainRow(),
          ],
        ),
      ),
    );
  }
}

/// Whether the operating system allows this app to post dose reminders, and the
/// one way back into its own settings (NOTIF-05, DECIDED-9a).
///
/// A private widget in this file rather than a third file under the settings
/// feature, deliberately: sign-off condition 25 forbids a new file under
/// `lib/features/`, and the owner decision that added this row did not lift it.
/// The feature's own source glob expects exactly these two files.
///
/// **The whole section renders nothing at all while the answer is unknown**, and
/// the reasoning is written here because "why does this sometimes not render?"
/// is the first question a reader will have. The answer is a future; an async
/// value on this screen would be the loading surface its own gates forbid; and a
/// row stating an unknown fact would be worse than no row. The window is
/// sub-perceptible in practice — the answer resolves a microtask after this
/// mounts, and this is a pushed route the user reaches deliberately.
///
/// It is stateful for one reason: it is the ONLY reader of the permission value,
/// so it is what asks for a fresh one when it appears. Building the controller
/// costs no platform round trip on its own, which is what lets the reminder sync
/// watch the same controller purely as a trigger.
///
/// It reaches the permission primitives ONLY through named controller methods.
/// That is not style: it is what keeps the plugin's own primitive names
/// resolving nowhere under `lib/features/`, which is a locked invariant a later
/// plan turns into a standing gate.
class _RemindersSection extends ConsumerStatefulWidget {
  const _RemindersSection();

  @override
  ConsumerState<_RemindersSection> createState() => _RemindersSectionState();
}

class _RemindersSectionState extends ConsumerState<_RemindersSection> {
  @override
  void initState() {
    super.initState();
    // No string, no formatter and no inherited widget is read here — only the
    // controller, and only to ask it for a fresh answer. Nothing is cached, so
    // nothing can outlive a language change.
    unawaited(ref.read(notificationPermissionProvider.notifier).refresh());
  }

  @override
  Widget build(BuildContext context) {
    final allowed = ref.watch(notificationPermissionProvider);
    if (allowed == null) return const SizedBox.shrink();
    final l10n = context.l10n;
    return Column(
      // The section is one child of the body list, so it has to stretch its own
      // children the way the list stretches its direct ones.
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 18),
        // Eyebrow-then-card, the same structure the language section uses, so
        // the screen reads as one list of two sections rather than a list plus
        // an afterthought. Stored uppercase in the ARB, never toUpperCase()'d.
        Semantics(
          header: true,
          child: Text(
            l10n.settingsRemindersTitle,
            style: BqText.mono(
              size: 10.5,
              color: BqColors.textMuted,
              letterSpacing: 0.63,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: BqColors.surface,
            border: Border.all(color: BqColors.cardBorder),
            borderRadius: BorderRadius.circular(BqRadii.card),
          ),
          child: Column(
            children: [
              _StateRow(
                label: allowed
                    ? l10n.settingsRemindersAllowed
                    : l10n.settingsRemindersBlocked,
              ),
              const Divider(
                height: 1,
                thickness: 1,
                color: BqColors.hairline,
              ),
              _OpenSystemSettingsRow(
                label: l10n.settingsRemindersOpenSystem,
                // Offered in BOTH states: it is the only route back after a
                // refusal on iOS and after a second refusal on Android, and a
                // user who allowed reminders may still want to reach them.
                onTap: () => unawaited(
                  ref
                      .read(notificationPermissionProvider.notifier)
                      .openSystemSettings(),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The statement half of the row: a fact, never a control.
///
/// It carries no tap target and no semantics node of its own — it is text, and
/// assistive technology reads text. Row metrics are the language rows' verbatim,
/// so the two cards cannot drift apart.
class _StateRow extends StatelessWidget {
  const _StateRow({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 52),
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          vertical: 14,
          horizontal: 14,
        ),
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          // Wraps: no maxLines, no overflow, no fixed width.
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 15,
              height: 1.3,
              color: BqColors.ink,
            ),
          ),
        ),
      ),
    );
  }
}

/// The control half: the one thing on this screen that leaves the app.
///
/// The recipe is the language picker's, not an invention: the semantics node
/// carries its OWN tap action because `excludeSemantics` drops every descendant
/// action, and the bounded row keeps the target big enough without growing with
/// the text scaler.
class _OpenSystemSettingsRow extends StatelessWidget {
  const _OpenSystemSettingsRow({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      button: true,
      label: label,
      onTap: onTap,
      child: ExcludeSemantics(
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 52),
            child: Padding(
              padding: const EdgeInsetsDirectional.symmetric(
                vertical: 14,
                horizontal: 14,
              ),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 15,
                    height: 1.3,
                    fontWeight: FontWeight.w600,
                    color: BqColors.accent,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Puts the first-run intro and every dismissed hint back, then leaves
/// Settings so the intro is the next thing on screen.
///
/// Present in EVERY build, debug and release alike. It started as a
/// debug-only testing affordance, but gating it meant the only way to see the
/// intro again on a real device was deleting the app — which deletes the
/// user's stack with it. A row that costs no data is worth having in the
/// shipped build too: "show me that again" is an ordinary thing to want from
/// a settings screen, and it destroys nothing.
///
/// It writes nothing but the two first-run keys. Supplements, regimens and
/// intake logs are untouched — this is not a reset of the app.
///
/// A private widget in this file, not a third file under the settings
/// feature: sign-off condition 25 forbids one, and the feature's source glob
/// expects exactly two files.
class _ShowIntroAgainRow extends ConsumerWidget {
  const _ShowIntroAgainRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(top: BqSpace.lg),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: BqColors.surface,
          border: Border.all(color: BqColors.cardBorder),
          borderRadius: BorderRadius.circular(BqRadii.card),
        ),
        child: InkWell(
          onTap: () async {
            // Hints first, then the intro: flipping the intro flag rebuilds
            // the gate under this route, and doing it last means the whole
            // reset has already landed when it does.
            await ref.read(firstRunHintsProvider.notifier).reset();
            await ref.read(onboardingSeenProvider.notifier).reset();
            if (!context.mounted) return;
            // Leaving Settings reveals the gate's new branch — the intro.
            Navigator.of(context).pop();
          },
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 15, 16, 15),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    context.l10n.debugResetOnboarding,
                    style: const TextStyle(fontSize: 15, color: BqColors.ink),
                  ),
                ),
                const Icon(
                  Icons.refresh,
                  size: 18,
                  color: BqColors.textSecondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
