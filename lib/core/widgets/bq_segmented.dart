/// Hand-built segmented pill control (02-RESEARCH.md P-10).
///
/// The SDK [SegmentedButton]'s M3 look (outlined segments + selected
/// checkmark) fights the mockup's padded-pill design, so this is a plain
/// decorated container with a `Row` of tappable segments.
///
/// TOKEN-ONLY RULE (D-07): all styling comes from `BqColors` / `BqRadii`;
/// the only literals are the mockup-exact paddings and the 13.5/w500 segment
/// label typography locked in 02-UI-SPEC (Typography "Segment label",
/// Spacing "Segmented container padding").
library;

import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// A stateless segmented control: a pill container with one active segment.
///
/// Reused by the add-supplement sheet tabs, the regimen editor's
/// Циклічно/Разовий курс toggle, and Phase 4's Рік/Цикли toggle — supports
/// any number of segments (2+). Labels size to content: no fixed widths, so
/// long uk labels never overflow (each segment is [Expanded] and the text
/// wraps center-aligned if needed).
class BqSegmented extends StatelessWidget {
  const BqSegmented({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onChanged,
  });

  /// Segment labels, in display order.
  final List<String> labels;

  /// Index of the currently active segment.
  final int selectedIndex;

  /// Called with the tapped segment's index.
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      // The mockup's segmented container fill is rgba(23,23,27,.09) — the
      // same value as the `cardBorder` token (02-UI-SPEC Token Additions);
      // that token is intentionally reused here as the container fill.
      decoration: const BoxDecoration(
        color: BqColors.cardBorder,
        borderRadius: BorderRadius.all(Radius.circular(BqRadii.seg)),
      ),
      padding: const EdgeInsets.all(2),
      child: Row(
        children: [
          for (int i = 0; i < labels.length; i++)
            Expanded(
              child: MergeSemantics(
                child: Semantics(
                  selected: i == selectedIndex,
                  button: true,
                  label: labels[i],
                  excludeSemantics: true,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onChanged(i),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      decoration: BoxDecoration(
                        color: i == selectedIndex
                            ? BqColors.surface
                            : Colors.transparent,
                        borderRadius: const BorderRadius.all(
                          Radius.circular(BqRadii.segInner),
                        ),
                      ),
                      child: Text(
                        labels[i],
                        textAlign: TextAlign.center,
                        // Segment label: 13.5/w500 unified (02-UI-SPEC
                        // Typography — locked simplification). Family
                        // inherits from the ambient theme (Instrument Sans).
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w500,
                          color: i == selectedIndex
                              ? BqColors.ink
                              : BqColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
