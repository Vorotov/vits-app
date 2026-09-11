/// The settings gear control, in one place (06-UI-SPEC S11 / D-5).
///
/// S11 justifies the gear's shape as "one reviewable pattern covers all three
/// instead of three bespoke placements" — but plan 06-03 shipped three
/// byte-identical copies of the row plus three copies of the push helper, so a
/// fix to the semantics wiring or the 44x44 constraint had to be made three
/// times and could drift between them (IN-01). This widget is that one
/// reviewable pattern, actually being one.
///
/// It takes NOTHING. The label comes from `context.l10n` and the destination is
/// fixed, so there is no argument a call site could get wrong and no per-screen
/// variant to configure. Three call sites, one line each.
///
/// WHAT STAYS AT THE CALL SITE: *why the row is separate on that screen*. Each
/// of Стек / Сьогодні / Календар has its own reason not to tidy the gear into
/// its title row — Сьогодні's title row must keep exactly two children (the
/// WR-04 lesson), Календар's would share a row with a control that carries a
/// LABEL — and those belong next to the header they constrain, not in here.
///
/// TOKEN-ONLY RULE (D-07): the one colour is `BqColors.textSecondary`. The
/// 44 / 20 literals are the S11 recipe's component pixels, hardcoded in the one
/// widget that owns them — which is now genuinely one widget.
library;

import 'package:flutter/material.dart';

import 'package:vitomy/core/l10n/l10n.dart';
import 'package:vitomy/core/theme/tokens.dart';
import 'package:vitomy/features/settings/settings_screen.dart';

/// Pushes Settings as a full-screen route, covering the nav bar (UI-SPEC S12).
void _openSettings(BuildContext context) => Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
    );

/// An end-aligned row holding exactly one 44x44 settings gear.
///
/// The row holds NO text, so its extent is pure geometry and it cannot overflow
/// at any text scale, in any locale, in any direction — which is the whole
/// reason the gear gets a row of its own rather than a slot in a title row
/// (D-5). Sits ABOVE the screen's title, inside the screen's existing 20px
/// header padding.
class BqSettingsGearRow extends StatelessWidget {
  const BqSettingsGearRow({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Semantics(
          button: true,
          // One key, two placements: this label and the Settings screen title,
          // so the control and its destination can never disagree.
          label: context.l10n.settingsTitle,
          excludeSemantics: true,
          // The action lives on THIS node, not only on the IconButton below
          // it: `excludeSemantics: true` drops every descendant action, so
          // without this the gear announces itself as a button VoiceOver /
          // TalkBack cannot press, while passing every coordinate-tap test
          // (WR-02).
          onTap: () => _openSettings(context),
          child: IconButton(
            onPressed: () => _openSettings(context),
            // A bounded, text-free box: >= 44pt guidance, and it cannot grow
            // with the text scaler.
            constraints: const BoxConstraints.tightFor(width: 44, height: 44),
            padding: EdgeInsets.zero,
            icon: const Icon(
              // Outlined only: the gear is never "selected", so the filled
              // variant has no state to express.
              Icons.settings_outlined,
              size: 20,
              color: BqColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}
