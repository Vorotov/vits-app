/// The language card's contents — 05-UI-SPEC S7, DECIDED-1..8.
///
/// The option list is `[null, ...AppLocalizations.supportedLocales]` and
/// nothing else: no language code, no endonym literal, no `switch`/`Map` over
/// locales, no fixed row count. Dropping `app_pl.arb` into the ARB directory
/// adds a row and its label with zero change in this file — that is criterion
/// 4 ("adding a new language requires only one new ARB file"), and it is a
/// LAYOUT constraint as much as a string one: nothing here may be sized,
/// ordered or spaced per language.
///
/// The label asymmetry is the design (P-2): a non-null option is labelled from
/// `lookupAppLocalizations(locale).languageName` — that locale's OWN ARB, so a
/// language's name is written in that language — while the null option reads
/// `context.l10n.languageSystem`, because it names a MODE, not a language, and
/// therefore belongs in whatever language the user is currently reading.
///
/// Rejected alternative: `BqSegmented`. It is a fixed-width horizontal control
/// (`bq_segmented.dart:21-23`); a language list grows vertically and
/// unboundedly and carries long endonyms, so a segmented control would either
/// clip them or force a per-language width — both criterion-4 violations
/// (DECIDED-2). `RadioListTile`/`ListTile` were rejected too: their Material
/// paddings and fixed `minVerticalPadding` fight the text-scale rule and would
/// need a fresh `ListTileTheme` to match the card idiom (DECIDED-3).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:boostque/core/l10n/l10n.dart';
import 'package:boostque/core/l10n/locale_controller.dart';
import 'package:boostque/core/theme/tokens.dart';

/// The mutually-exclusive language option list (S7).
///
/// Renders `1 + AppLocalizations.supportedLocales.length` rows separated by
/// full-bleed 1px hairline dividers (DECIDED-5). Exactly one row is checked at
/// all times: a stored code outside the shipped set sanitizes to `null` in
/// [LocaleController] and checks the System-default row (T-05-01).
class LanguagePicker extends ConsumerWidget {
  const LanguagePicker({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final current = ref.watch(localeControllerProvider);
    // System default FIRST, always — it is the default state, and putting it
    // first means the order never depends on a locale-sensitive string sort.
    // The rest in GENERATED order, which `preferred-supported-locales` in
    // l10n.yaml controls. Never sorted by display name.
    final options = <Locale?>[null, ...AppLocalizations.supportedLocales];

    return Column(
      children: [
        for (final (index, locale) in options.indexed) ...[
          if (index > 0)
            const Divider(
              height: 1,
              thickness: 1,
              color: BqColors.hairline,
            ),
          _LanguageRow(
            label: locale == null
                ? l10n.languageSystem
                : lookupAppLocalizations(locale).languageName,
            // Compared by languageCode so a sanitized-to-null stored value
            // checks the System row and exactly one row is ever checked.
            selected: locale?.languageCode == current?.languageCode,
            // Idempotent on the already-selected row (Interaction Contract 2):
            // not a toggle-off, not an error.
            onTap: () =>
                ref.read(localeControllerProvider.notifier).setLocale(locale),
          ),
        ],
      ],
    );
  }
}

/// One language option.
///
/// Semantics live ON this row, never on a descendant (the WR-02 lesson):
/// `inMutuallyExclusiveGroup` + `checked` is what makes VoiceOver/TalkBack
/// announce "selected/not selected" rather than "button", which is why
/// `button: true` is deliberately unset. The check glyph carries no semantics
/// of its own — `checked` already says it, and announcing a bare "✓" would
/// double-speak the state.
class _LanguageRow extends StatelessWidget {
  const _LanguageRow({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      inMutuallyExclusiveGroup: true,
      checked: selected,
      label: label,
      onTap: onTap,
      child: ExcludeSemantics(
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            // minHeight, never a fixed height: 14 + 15x1.3 + 14 = 47.5px at
            // scale 1.0, so this floor is load-bearing at EVERY scale rather
            // than a safety net — and at scale 2.0 the row must be free to
            // grow past it as the label wraps (CR-01/WR-04).
            constraints: const BoxConstraints(minHeight: 52),
            child: Padding(
              padding: const EdgeInsetsDirectional.symmetric(
                vertical: 14,
                horizontal: 14,
              ),
              child: Row(
                children: [
                  Expanded(
                    // Wraps: no maxLines, no overflow, no fixed width. A long
                    // endonym at an accessibility text scale flows onto a
                    // second line and the row grows with it.
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.3,
                        fontWeight:
                            selected ? FontWeight.w600 : FontWeight.w400,
                        color: BqColors.ink,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Unselected rows render NOTHING here — not a transparent
                  // placeholder — so the label simply gets the full width.
                  // Selection is legible without color: glyph presence plus
                  // the 400 -> 600 weight are two non-color channels.
                  if (selected)
                    const Text(
                      '✓',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: BqColors.accent,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
