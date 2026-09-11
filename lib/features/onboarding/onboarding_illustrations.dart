/// The onboarding illustrations (spec D-9): miniatures built from the
/// app's own surfaces with existing tokens — no bundled image assets, no new
/// tokens, and no text, so nothing here needs localizing.
///
/// They teach the real UI: what a dose row looks like ticked and unticked,
/// and the shape the Cycles gantt draws. Miniatures that SHARE tokens with the
/// real widgets, not copies of them —
/// if a dose row is restyled they read as slightly dated, not broken (the
/// spec's accepted drift risk).
///
/// Each is decorative to a screen reader: the visual tree is excluded and one
/// ARB sentence replaces it.
library;

import 'package:flutter/material.dart';

import 'package:vitomy/core/l10n/l10n.dart';
import 'package:vitomy/core/theme/tokens.dart';

/// Page 1: two mini dose rows — one taken (accent circle, ✓, struck name
/// bar), one pending (empty circle, plain bar). Names are rounded bars, not
/// words: an illustration with a fake supplement name would need translating
/// and would read as a recommendation.
class OnboardingDosesIllustration extends StatelessWidget {
  const OnboardingDosesIllustration({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: context.l10n.onboardingIllustrationSemantics1,
      child: ExcludeSemantics(
        child: _IllustrationCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              _MiniDoseRow(taken: true),
              SizedBox(height: 8),
              _MiniDoseRow(taken: false),
            ],
          ),
        ),
      ),
    );
  }
}

/// Page 2: three stacked rows of alternating on/off blocks — the shape the
/// Cycles gantt actually draws, so what the user meets on Календар is
/// already familiar. Each row is one supplement; where the solid blocks line
/// up vertically is where two things are taken in the same weeks, which is
/// the whole reason the screen exists.
class OnboardingCalendarIllustration extends StatelessWidget {
  const OnboardingCalendarIllustration({super.key});

  /// Three deliberately different rhythms, so the rows do NOT line up into a
  /// grid: overlap has to be visible as a coincidence between rows, not as a
  /// pattern the drawing imposes. `true` is an on-week.
  static const _rows = <List<bool>>[
    [true, true, false, true, true, false],
    [true, false, false, true, false, false],
    [true, true, true, false, true, true],
  ];

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: context.l10n.onboardingIllustrationSemantics2,
      child: ExcludeSemantics(
        child: _IllustrationCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var row = 0; row < _rows.length; row++) ...[
                if (row > 0) const SizedBox(height: 6),
                Row(
                  children: [
                    for (var week = 0; week < _rows[row].length; week++) ...[
                      if (week > 0) const SizedBox(width: 4),
                      Expanded(
                        child: Container(
                          height: 18,
                          decoration: BoxDecoration(
                            color: _rows[row][week]
                                ? BqColors.accent
                                : BqColors.plannedHatchWeak,
                            borderRadius:
                                BorderRadius.circular(BqRadii.chip),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The frame an illustration sits in: the app's card surface.
class _IllustrationCard extends StatelessWidget {
  const _IllustrationCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsetsDirectional.all(16),
      decoration: BoxDecoration(
        color: BqColors.surfaceAlt,
        border: Border.all(color: BqColors.cardBorder),
        borderRadius: BorderRadius.circular(BqRadii.card),
      ),
      child: child,
    );
  }
}

/// One miniature dose row. The ✓ glyph and its 12/600 style are the real
/// dose row's own glyph mechanism, mirrored (dose_row.dart), so the two stay
/// recognizably the same thing.
class _MiniDoseRow extends StatelessWidget {
  const _MiniDoseRow({required this.taken});

  final bool taken;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: BqColors.paper,
        border: Border.all(color: BqColors.cardBorder),
        borderRadius: BorderRadius.circular(BqRadii.doseRow),
      ),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: taken ? BqColors.accent : BqColors.paper,
              border: taken ? null : Border.all(color: BqColors.inputBorder),
              shape: BoxShape.circle,
            ),
            child: taken
                ? const Text(
                    '✓',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: BqColors.surface,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          // The "name": a rounded bar. Struck through when taken, exactly the
          // treatment the real row gives a taken supplement's name.
          Expanded(
            child: SizedBox(
              height: 14,
              child: Stack(
                alignment: AlignmentDirectional.centerStart,
                children: [
                  Container(
                    height: 10,
                    width: taken ? 96 : 128,
                    decoration: BoxDecoration(
                      color: BqColors.field,
                      borderRadius: BorderRadius.circular(BqRadii.chip),
                    ),
                  ),
                  if (taken)
                    Container(
                      height: 2,
                      width: 108,
                      color: BqColors.textSecondary,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
