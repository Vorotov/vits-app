import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:boostque/core/domain/repositories.dart';
import 'package:boostque/core/l10n/l10n.dart';
import 'package:boostque/core/providers.dart';
import 'package:boostque/core/theme/tokens.dart';
import 'package:boostque/features/stack/add_supplement_sheet.dart';

/// Stack tab (plan 02-01 tracer slice): heading, the full-width accent
/// "add supplement" CTA, and a minimal card list rendered live from
/// [stackEntriesProvider].
///
/// Full card anatomy (chips, status, schedule summary, empty state, error
/// surface) is owned by plan 02-05 — this screen intentionally renders only
/// the color bar + name + dose on each card.
class StackScreen extends ConsumerWidget {
  const StackScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(stackEntriesProvider);
    return Scaffold(
      body: SafeArea(
        child: ListView(
          // 20px horizontal padding is the UI-SPEC mockup-exact override for
          // screen bodies; bottom >= 84px clears the nav bar (UI-SPEC S1).
          padding: const EdgeInsetsDirectional.only(
            start: 20,
            end: 20,
            top: BqSpace.lg,
            bottom: 84,
          ),
          children: [
            Text(
              context.l10n.stackTitle,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: BqColors.accent,
                  foregroundColor: BqColors.surface,
                  overlayColor: BqColors.accentPressed,
                  padding: const EdgeInsetsDirectional.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(BqRadii.button),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onPressed: () => showAddSupplementSheet(context),
                child: Text(context.l10n.addSupplement),
              ),
            ),
            const SizedBox(height: BqSpace.md),
            // Loading renders header + CTA with an empty list area and NO
            // spinner (UI-SPEC UI Consideration #2); the documented error
            // surface (stackLoadError) arrives in plan 02-05.
            ...entries.when(
              data: (list) => [
                for (final (i, entry) in list.indexed) ...[
                  if (i > 0) const SizedBox(height: 9),
                  _StackCard(entry: entry),
                ],
              ],
              loading: () => const <Widget>[],
              error: (_, _) => const <Widget>[SizedBox.shrink()],
            ),
          ],
        ),
      ),
    );
  }
}

/// Minimal stack card: 4px color bar + name + dose text (plan 02-01 scope).
class _StackCard extends StatelessWidget {
  const _StackCard({required this.entry});

  final StackEntry entry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsetsDirectional.all(14),
      decoration: BoxDecoration(
        color: BqColors.surface,
        borderRadius: BorderRadius.circular(BqRadii.card),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 4,
              margin: const EdgeInsetsDirectional.only(end: 12),
              decoration: BoxDecoration(
                color: Color(entry.supplement.colorValue)
                    .withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.supplement.name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: BqColors.ink,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    entry.supplement.doseText,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: BqColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
