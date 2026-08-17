/// The Settings screen — full S7 contract (plan 05-01), replacing the Phase-1
/// stub.
///
/// NOT a tab. Since plan 06-03 this is a pushed `MaterialPageRoute` entered
/// from the gear row on Стек / Сьогодні / Календар, and it covers the nav bar
/// rather than being a destination on it (NAV-03, 06-UI-SPEC S12). That is why
/// it carries its own back control and ordinary body padding — both documented
/// where they are built, below.
///
/// v1 content is exactly: title, mono eyebrow, language card (DECIDED-1). No
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
/// `AsyncLoading` or `AsyncError`. A failed `shared_preferences` write is
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

import 'package:flutter/material.dart';

import 'package:boostque/core/l10n/l10n.dart';
import 'package:boostque/core/theme/theme.dart';
import 'package:boostque/core/theme/tokens.dart';
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
          ],
        ),
      ),
    );
  }
}
