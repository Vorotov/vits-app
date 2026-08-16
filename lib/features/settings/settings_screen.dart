/// Settings tab — full S7 contract (plan 05-01), replacing the Phase-1 stub.
///
/// v1 content is exactly: title, mono eyebrow, language card (DECIDED-1). No
/// version/About line (it would need a package, or a hardcoded string that
/// drifts from pubspec — a lie on the one screen whose whole job is to be
/// truthful about configuration) and no educational disclaimer (PLAN-04 binds
/// it to planner screens, where an editorial limit is actually asserted).
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
/// the title lives in the body, matching Stack, Calendar and Planner.
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
          // screen uses; bottom >= 84px clears the nav bar (locked Phase 2).
          padding: const EdgeInsetsDirectional.only(
            start: 20,
            end: 20,
            top: BqSpace.lg,
            bottom: 84,
          ),
          children: [
            // One key, two placements: the nav destination and this title, so
            // the tab and its screen can never disagree.
            Text(
              l10n.tabSettings,
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
