/// The inline week-detail card for the Цикли segment (plan 04-03, UI-SPEC S6a
/// item 4, P-7, P-13, DECIDED-8; reduced by 06-UI-SPEC S13 / D-6).
///
/// ALWAYS present in the scroll flow, immediately below the load chart, and
/// never a modal sheet: the user is comparing this card against the chart
/// directly above it, and a sheet would cover the very thing being compared
/// (P-13). Selecting a different week re-renders it in place.
///
/// ## What this card says, after PLAN-05
///
/// Range, how many supplements overlap in that week, and WHICH ones. Nothing
/// judges the number: there is no verdict chip, no slot-pip row, no free-slot
/// half of the meta line and no note. Everything deleted was an opinion about
/// the count, never the count itself — the card's remaining job is the one
/// question the chart above it cannot answer (06-UI-SPEC D-6).
///
/// The header therefore holds a SINGLE child, which retires this card's only
/// overflow risk outright rather than mitigating it (WR-04).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:boostque/core/l10n/l10n.dart';
import 'package:boostque/core/theme/tokens.dart';
import 'package:boostque/features/calendar/planner_providers.dart';
import 'package:boostque/features/calendar/planner_view_model.dart';

/// Card padding (mockup line 352 `padding:17px`).
const double _cardPadding = 17;

/// Range → meta gap (mockup line 353).
const double _rangeMetaGap = 4;

/// Name chips (mockup lines 362-364).
const double _chipsTopMargin = 14;
const double _chipsGap = 6;
const double _nameChipPadVertical = 6;
const double _nameChipPadHorizontal = 9;
const double _nameChipSize = 11.5;

/// The always-present detail for the selected week.
class PlannerWeekDetail extends ConsumerWidget {
  const PlannerWeekDetail({super.key, required this.model});

  /// The derived Цикли model — never built in `build()` (PF-10).
  final CyclesModel model;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    // The locale ALWAYS comes from the widget tree, never a literal tag.
    final locale = Localizations.localeOf(context).toString();
    final weeks = model.weeks;
    if (weeks.isEmpty) return const SizedBox.shrink();

    // The resolved index is already clamped to the model's own bucket list, so
    // a stale selection can never index past it (V5).
    final week = weeks[ref.watch(resolvedWeekIndexProvider)];

    // A day number is present, so the FORMAT (genitive) month case is the
    // correct one here — the opposite of the gantt's standalone header (PF-4).
    final range = DateFormat.MMMd(locale);

    return Container(
      key: const ValueKey<String>('week-detail-card'),
      padding: const EdgeInsetsDirectional.all(_cardPadding),
      decoration: BoxDecoration(
        color: BqColors.surface,
        border: Border.all(color: BqColors.cardBorder),
        borderRadius: const BorderRadius.all(Radius.circular(BqRadii.panel)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            // Exactly ONE child, forever: the trailing verdict chip that made
            // this row an overflow candidate is deleted, not shrunk (WR-04).
            children: [
              Expanded(
                child: Text(
                  '${range.format(week.bucket.start)} – '
                  '${range.format(week.bucket.endInclusive)}',
                  style: const TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w600,
                    height: 1.25,
                    color: BqColors.ink,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: _rangeMetaGap),
          Text(
            // A plain count, rendered directly through the shared plural key:
            // no denominator, no free-slot half, nothing to compare against.
            l10n.substancesCount(week.load),
            key: const ValueKey<String>('week-detail-meta'),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              height: 1.4,
              color: BqColors.textMuted,
            ),
          ),
          // A zero-cycle week is a normal week, not an empty state — so it
          // gets no empty-state treatment, and equally no hanging gap where
          // the deleted note used to sit. The chips and their top margin
          // appear together or not at all (06-UI-SPEC S13).
          if (week.entries.isNotEmpty) ...[
            const SizedBox(height: _chipsTopMargin),
            Wrap(
              key: const ValueKey<String>('week-name-chips'),
              spacing: _chipsGap,
              runSpacing: _chipsGap,
              children: [
                for (final entry in week.entries)
                  Container(
                    padding: const EdgeInsetsDirectional.symmetric(
                      vertical: _nameChipPadVertical,
                      horizontal: _nameChipPadHorizontal,
                    ),
                    decoration: const BoxDecoration(
                      color: BqColors.chip,
                      borderRadius:
                          BorderRadius.all(Radius.circular(BqRadii.chip)),
                    ),
                    child: Text(
                      entry.supplement.name,
                      style: const TextStyle(
                        fontSize: _nameChipSize,
                        fontWeight: FontWeight.w400,
                        color: BqColors.textSecondary,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
