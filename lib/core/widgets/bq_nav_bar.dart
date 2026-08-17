/// Hand-built bottom navigation bar (06-UI-SPEC S8, NAV-01).
///
/// WHY THIS IS NOT THE SDK `NavigationBar` — the accurate rationale (D-1).
/// The SDK bar's height *is* themeable: `navigation_bar.dart:281` resolves
/// `height ?? navigationBarTheme.height ?? defaults.height!`, so a
/// `NavigationBarThemeData(height: 56)` would have compiled. Two things it
/// still could not do:
///
/// 1. **A themed height would still clip.** The resolved height lands in a
///    hard `SizedBox` (`navigation_bar.dart:298`) wrapped around a
///    destination stack whose LABEL does grow with the text scaler. That is
///    the CR-01 defect class this codebase has already paid for twice —
///    `week_strip.dart:59-79` documents seven bottom overflows at scale 1.6
///    and 2.0, and `planner_year_grid.dart` records the same lesson at the
///    year grid.
/// 2. **The height has to be a FUNCTION, not a value.** No `ThemeData` field
///    accepts a `double Function(TextScaler)`, and that is exactly the shape
///    NAV-01 requires. [navBarHeightFor] is that function.
///
/// Because the bar is hand-built, `bqTheme()` no longer carries a
/// bottom-navigation sub-theme at all: the label's 10 / accent-or-textFaint
/// styling and the icon colour pair live in this file, where the widget that
/// reads them lives. A sub-theme that styles nothing is worse than none — the
/// next reader edits it and sees no change (T-06-01).
///
/// PRESS FEEDBACK is [InkResponse], chosen deliberately over the load chart's
/// opacity idiom (precedent: `planner_year_grid.dart`'s month card). Both are
/// precedented here; this bar is the app's primary navigation control and
/// tapping the ALREADY-SELECTED destination must still feel like it
/// registered, which an opacity change tied to selection cannot express. Not
/// to be "unified" with the chart later.
///
/// SEMANTICS ROLES: the container carries `SemanticsRole.tabBar` and each
/// destination `SemanticsRole.tab`, so assistive tech announces "tab 2 of 3"
/// rather than three unrelated buttons. `button: true, selected: …` is kept
/// alongside the roles — that pair is what every other bespoke control here
/// uses (`bq_segmented.dart`, `week_strip.dart`) and it is what the tests
/// assert, so the roles are an addition, never a substitution.
///
/// TOKEN-ONLY RULE (D-07): every colour comes from `BqColors`. The only
/// literals are the mockup-exact 22px horizontal padding and the 10 / 1.2
/// label typography — the UI-SPEC spacing exemption recorded at
/// `tokens.dart:212-216`. The v1 66px destination-column width and 24px
/// home-indicator strip from that same exemption are DELETED, not reproduced:
/// a fixed-width column is a fixed-width text container, and the home
/// indicator is [SafeArea]'s job.
library;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../theme/tokens.dart';

/// The part of the bar's height that does NOT follow the text scale: the 22px
/// icon box, the 4px icon-to-label gap, and 18px of vertical slack.
///
/// The widget applies NO vertical padding of its own. The slack is what is
/// left over inside `SizedBox(height: navBarHeightFor(scaler))` once the icon,
/// the gap and the label's line box are laid out, and the destination
/// `Column`'s `MainAxisAlignment.center` distributes it EVENLY — 9 above and 9
/// below at scale 1.0, 7.5/7.5 at 2.0. It is not an 8/10 asymmetry; an earlier
/// version of this doc said it was, and nothing in the widget ever wrote those
/// two numbers (WR-05). Anyone editing these constants reasons from this
/// decomposition, so it has to be the real one.
///
/// v1's `top: 10` padding on the shell's outer `Container` is folded in here —
/// leaving it outside would double-count and miss the 56dp target.
const double _navBarFixedExtent = 44;

/// The label's type, in the two numbers the extent formula and the [TextStyle]
/// BOTH read, so they can no longer disagree (IN-04).
const double _navBarLabelFontSize = 10;
const double _navBarLabelHeight = 1.2;

/// Height reserved for the bar's content, for [scaler].
///
/// 56.0 at scale 1.0 (NAV-01, down from v1's 80dp), ~63 at 1.6, 68.0 at 2.0 —
/// strictly increasing. The `stripHeightFor` (`week_strip.dart:78`) /
/// `monthCardExtentFor` (`planner_year_grid.dart`) idiom, transcribed: a
/// top-level function so the extent is unit-testable without pumping a widget.
///
/// Only the label passes through the scaler. [Icon] takes its size from
/// [IconThemeData] and does NOT follow the text scaler, so multiplying the
/// whole 56 would over-reserve at every scale above 1.0 — which is why the
/// extent is SPLIT rather than scaled as a whole.
///
/// The FONT SIZE is scaled and the line-height multiple applied afterwards,
/// never the other way round (IN-04). [TextScaler.scale] takes a font size,
/// and the platform scalers Android 14+ supplies are non-linear — they
/// compress larger sizes more — so `scale(12)` is not `1.2 * scale(10)` and
/// feeding it a 12px LINE BOX under-reserves exactly when the scale is
/// largest, which is when the 18px of slack is thinnest.
double navBarHeightFor(TextScaler scaler) =>
    _navBarFixedExtent +
    scaler.scale(_navBarLabelFontSize) * _navBarLabelHeight;

/// One destination's immutable content: its glyph pair and its ARB label.
///
/// Labels arrive already localized — this widget never reaches for
/// `context.l10n` itself, so it stays a pure function of its arguments and is
/// testable without a localization delegate.
@immutable
class BqNavDestination {
  const BqNavDestination({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });

  /// Glyph shown while this destination is not the selected one.
  final IconData icon;

  /// Glyph shown while this destination is selected.
  final IconData selectedIcon;

  /// The destination's localized label — the ARB string, not a literal.
  final String label;
}

/// The app's bottom navigation bar: a flat surfaceAlt strip with a 1px
/// hairline top border and one [Expanded] cell per destination.
///
/// Stateless by design — the selected index is the shell's state and comes
/// back out through [onSelected]. Renders synchronously on the first frame
/// from its arguments alone: there is no async source here, so no spinner,
/// skeleton or error surface exists in this file.
class BqNavBar extends StatelessWidget {
  const BqNavBar({
    super.key,
    required this.destinations,
    required this.selectedIndex,
    required this.onSelected,
  });

  /// Destinations in display order.
  final List<BqNavDestination> destinations;

  /// Index of the currently selected destination.
  final int selectedIndex;

  /// Called with the activated destination's index — including when it is
  /// already the selected one (see the press-feedback note above).
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    // [DecoratedBox], not [Container]: a `Border` inside a Container's
    // decoration is PADDING — it insets the child and adds its width to the
    // laid-out height, so the bar measured 57dp rather than the 56dp NAV-01
    // specifies. `DecoratedBox` paints the same hairline without consuming
    // layout, which keeps the painted extent exactly
    // `navBarHeightFor(scaler) + bottom safe-area inset` — the equality the
    // text-scale matrix asserts per cell. The 1px hairline paints over the top
    // of the vertical slack that is already inside the extent.
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: BqColors.surfaceAlt,
        border: Border(top: BorderSide(color: BqColors.hairline, width: 1)),
      ),
      // The InkResponses below need a Material of their own to paint into.
      // Without one they reach the nearest ancestor — the Scaffold's root
      // Material — and `_RenderInkFeatures.paint` draws every ink feature
      // BEFORE its child subtree, so the splash lands underneath this
      // DecoratedBox's fully opaque `surfaceAlt` fill: press feedback nobody
      // can see, on every destination, at every scale (CR-01). The v1
      // `NavigationBar` supplied this layer itself; the hand-built
      // replacement has to.
      //
      // `MaterialType.transparency` adds no colour, no elevation and no
      // layout, so the 56dp painted extent above is untouched.
      child: Material(
        type: MaterialType.transparency,
        child: Padding(
          // Mockup-exact horizontal override (UI-SPEC spacing exemption).
          // Direction-neutral: no left/right inset may enter this file.
          padding: const EdgeInsetsDirectional.only(start: 22, end: 22),
          // INSIDE the decorated box, never around it: the fill and the
          // hairline must reach the physical screen edge while the three touch
          // targets sit above the home indicator.
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: navBarHeightFor(MediaQuery.textScalerOf(context)),
              child: Semantics(
                container: true,
                explicitChildNodes: true,
                role: SemanticsRole.tabBar,
                child: Row(
                  // STRETCH, not the default centre. Without it the Row hands
                  // each destination a LOOSE height constraint, the
                  // shrink-wrapped Column below takes only its content's 38dp,
                  // and the Row centres that inside the 56dp bar — leaving a
                  // 9dp strip along the top and another along the bottom that
                  // look like the destination and hit-test to nothing. The
                  // UI-SPEC spacing table contracts this cell as "full-height",
                  // S8 as "opaque over the whole Expanded cell, never the
                  // glyph", and the comment in `_destination` says the same;
                  // all three were false. Stretch is also what makes the
                  // Column's `MainAxisAlignment.center` do the vertical
                  // centring the extent decomposition describes, instead of
                  // being a no-op on a min-sized Column.
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (int i = 0; i < destinations.length; i++)
                      Expanded(child: _destination(i)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _destination(int i) {
    final BqNavDestination destination = destinations[i];
    final bool selected = i == selectedIndex;
    final Color color = selected ? BqColors.accent : BqColors.textFaint;

    return MergeSemantics(
      child: Semantics(
        button: true,
        selected: selected,
        label: destination.label,
        role: SemanticsRole.tab,
        excludeSemantics: true,
        // The action lives on THIS node, not only on the InkResponse below
        // it: `excludeSemantics` drops every descendant action, so without
        // this a destination announced itself as a button that VoiceOver /
        // TalkBack could not activate — and switching tabs is the app's
        // primary affordance. A coordinate tap passes either way, which is
        // exactly why this line is easy to lose (WR-02).
        onTap: () => onSelected(i),
        child: InkResponse(
          onTap: () => onSelected(i),
          // The whole Expanded cell is the tap target — a 22dp glyph must
          // never define it (Interaction Contract 8). `InkResponse`
          // hit-tests OPAQUE across its full box, which is the behaviour
          // the week strip spells out on its `GestureDetector`.
          containedInkWell: false,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                selected ? destination.selectedIcon : destination.icon,
                size: 22,
                color: color,
              ),
              const SizedBox(height: 4), // icon-to-label gap, in the extent
              Text(
                destination.label,
                textAlign: TextAlign.center,
                // A one- or two-word tab label is single-line by nature:
                // wrapping one at a large text scale would grow the cell by
                // a whole line and clip it (CR-01), so the line COUNT is
                // pinned and only the line HEIGHT follows the scaler — which
                // is what navBarHeightFor reserves. There is deliberately no
                // shrink-to-fit backstop here (the v1 spec's is void): the
                // label renders at its true 10sp size at every scale, and a
                // clipped cell means the extent constants are wrong.
                maxLines: 1,
                softWrap: false,
                // The same two constants navBarHeightFor reserves against, so
                // the reserved extent and the painted line box cannot drift
                // apart (IN-04).
                style: TextStyle(
                  fontSize: _navBarLabelFontSize,
                  height: _navBarLabelHeight,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
