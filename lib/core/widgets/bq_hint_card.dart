/// The one-time contextual hint card (v1.2, path A).
///
/// Deliberately NOT an overlay: it takes its place in the layout, pushes
/// nothing off screen, dims nothing and blocks nothing. A hint the user does
/// not want costs one glance and one tap, and the tap is permanent.
///
/// Visually it is an accent-tinted note, distinct from both cards and form
/// fields so it reads as an annotation rather than as content the user has
/// to act on — the "make hints obviously different from real UI" rule.
library;

import 'package:flutter/material.dart';

import 'package:vitomy/core/l10n/l10n.dart';
import 'package:vitomy/core/theme/tokens.dart';

class BqHintCard extends StatelessWidget {
  const BqHintCard({super.key, required this.text, required this.onDismiss});

  final String text;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(14, 12, 8, 12),
      decoration: BoxDecoration(
        color: BqColors.accentChipBg,
        border: Border.all(color: BqColors.accentBorder),
        borderRadius: const BorderRadius.all(Radius.circular(BqRadii.card)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                height: 1.45,
                color: BqColors.ink,
              ),
            ),
          ),
          const SizedBox(width: BqSpace.sm),
          // A real 44px target, not a decorative glyph: dismissing is the
          // only thing this card asks of anyone.
          Semantics(
            button: true,
            label: l10n.hintDismiss,
            child: InkWell(
              onTap: onDismiss,
              borderRadius: const BorderRadius.all(Radius.circular(22)),
              child: const SizedBox(
                width: 44,
                height: 44,
                child: Icon(
                  Icons.close,
                  size: 18,
                  color: BqColors.textSecondary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
