/// The inline month-detail card for the Рік segment (plan 04-04, UI-SPEC S6b
/// item 4, P-10, P-13).
///
/// ALWAYS present in the scroll flow, below the grid and its legend, and never
/// a modal sheet: the user is reading this card against the twelve cards
/// directly above it, and a sheet would cover the very thing being compared —
/// the same argument the week detail is built on (P-13).
///
/// A month with no coverage renders the empty-month sentence INSIDE this card
/// rather than collapsing it: a zero-coverage month is a normal, expected month
/// (a break between cycles), not an empty state of the screen.
///
/// The month title is an `intl` STANDALONE full month name — nominative in
/// Ukrainian ("серпень"), which the format pattern letters would get wrong
/// (PF-4, L10N-04). No month table lives here or anywhere else.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:boostque/core/domain/repositories.dart' show StackEntry;
import 'package:boostque/core/l10n/casing.dart';
import 'package:boostque/core/l10n/l10n.dart';
import 'package:boostque/core/theme/theme.dart';
import 'package:boostque/core/theme/tokens.dart';
import 'package:boostque/features/calendar/planner_providers.dart';
import 'package:boostque/features/calendar/planner_view_model.dart';
import 'package:boostque/features/stack/schedule_summary_text.dart';
import 'package:boostque/features/stack/stack_status.dart';

/// Card padding (mockup line 439).
const double _cardPadding = 16;

/// Header (mockup line 440).
const double _headerBottomMargin = 13;
const double _titleMetaGap = 10;
const double _titleSize = 11;

/// `.07em` of 11px is 0.77 logical pixels.
const double _titleTracking = 0.77;

/// Rows (mockup lines 444-449).
const double _rowGap = 13;
const double _dotSize = 9;
const double _dotRadius = 3;
const double _dotTopMargin = 4;
const double _dotTextGap = 11;
const double _nameHintGap = 3;
const double _textStateGap = 10;
const double _stateTopMargin = 2;

/// The alpha the row dot carries when the month's WHOLE coverage is still
/// planned (mockup line 849 `x.r.color + '80'`, i.e. 0x80/0xFF).
///
/// Deliberately heavier than the grid bar's 0.30: a 9×9 dot at 0.30 would read
/// as absent rather than as tinted.
const double _plannedDotAlpha = 0.50;

/// The always-present breakdown of the selected month.
class PlannerMonthDetail extends ConsumerWidget {
  const PlannerMonthDetail({super.key, required this.model});

  /// The derived Рік model — never built in `build()` (PF-10).
  final YearModel model;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    // The locale ALWAYS comes from the widget tree, never a literal tag.
    final locale = Localizations.localeOf(context).toString();
    if (model.months.isEmpty) return const SizedBox.shrink();

    // The resolved index is already clamped to the model's own month list, so
    // a stale selection can never index past it (V5).
    final month = model.months[ref.watch(resolvedMonthIndexProvider)];

    // Only supplements that actually touch the month, in stack order. A paused
    // regimen contributes no coverage and therefore no row (DECIDED-7).
    final rows = <({StackEntry entry, MonthCell cell})>[
      for (var i = 0; i < model.entries.length; i++)
        if (month.cells[i].frac > 0)
          (entry: model.entries[i], cell: month.cells[i]),
    ];

    return Container(
      key: const ValueKey<String>('month-detail-card'),
      padding: const EdgeInsetsDirectional.all(_cardPadding),
      decoration: BoxDecoration(
        color: BqColors.surface,
        border: Border.all(color: BqColors.cardBorder),
        borderRadius: const BorderRadius.all(Radius.circular(BqRadii.panel)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // A flexible title against a CEILED meta line. "Flexible + rigid"
          // is only overflow-proof while the rigid child is narrower than the
          // row; at textScaler 2.0 the meta line alone is wider than it, and
          // the header overflowed by 90px — the WR-04 defect class again,
          // caught by the 04-05 text-scale matrix. The remediation is
          // `day_block_section.dart`'s: a hard ceiling that the child is far
          // below at scale 1.0, so the mockup layout is untouched there, and
          // that the child WRAPS inside rather than overflows past.
          LayoutBuilder(
            builder: (context, constraints) {
              final ceiling = constraints.maxWidth.isFinite
                  ? (constraints.maxWidth - _titleMetaGap) / 2
                  : double.infinity;
              return Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Expanded(
                    child: Text(
                      // The month name is locale-FORMATTED by intl; the
                      // uppercasing is a separate step with its own single
                      // definition, because Dart's `toUpperCase()` is
                      // locale-independent and gets the Turkish/Azeri dotted i
                      // wrong (WR-03). Never a hardcoded uppercase string (M6).
                      bqUpperCase(
                        DateFormat('LLLL', locale).format(month.month),
                        locale,
                      ),
                      style: BqText.mono(
                        size: _titleSize,
                        weight: FontWeight.w600,
                        color: BqColors.ink,
                        letterSpacing: _titleTracking,
                      ),
                    ),
                  ),
                  const SizedBox(width: _titleMetaGap),
                  ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: ceiling),
                    child: Text(
                      // The count is PRE-FORMATTED through its own plural key
                      // and passed into the sentence (the cycleSummaryCyclic
                      // idiom). The ONE place the limit is defined is the pure
                      // model.
                      l10n.monthMeta(
                        l10n.substancesCount(rows.length),
                        editorialLimit,
                      ),
                      // WRAPS rather than ellipsizes: the count and the limit
                      // are both PLAN-04 content, and truncating either would
                      // hide the editorial framing this card exists to carry.
                      textAlign: TextAlign.end,
                      style: BqText.mono(
                        size: _titleSize,
                        weight: FontWeight.w400,
                        color: BqColors.textFaint,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: _headerBottomMargin),
          if (rows.isEmpty)
            Text(
              l10n.monthEmpty,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                height: 1.5,
                color: BqColors.textSecondary,
              ),
            )
          else
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0) const SizedBox(height: _rowGap),
              _MonthRow(index: i, entry: rows[i].entry, cell: rows[i].cell),
            ],
        ],
      ),
    );
  }
}

/// One supplement's line: its colour dot, its name and hint, and its state.
class _MonthRow extends StatelessWidget {
  const _MonthRow({
    required this.index,
    required this.entry,
    required this.cell,
  });

  final int index;
  final StackEntry entry;
  final MonthCell cell;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    // The Stack card's own words for this regimen, minus its daily-slot tail:
    // the planner is about time, not daily doses (M13).
    final hint = scheduleSummaryText(
      scheduleSummaryOf(entry),
      l10n: l10n,
      // The locale ALWAYS comes from the widget tree, never a literal tag.
      locale: Localizations.localeOf(context).toString(),
      withSlots: false,
    );

    // Planned FIRST, exactly as the mockup reads it (line 850): a month whose
    // whole coverage is still ahead says so, whether or not it is also full.
    final (String state, Color stateColor) = cell.planned
        ? (l10n.monthStatePlanned, BqColors.textFaint)
        : cell.full
            ? (l10n.monthStateTaking, BqColors.textSecondary)
            : (l10n.monthStatePartial, BqColors.textSecondary);

    // The supplement's OWN tag colour — the sanctioned data-not-literal colour
    // exception the Stack card already uses.
    final color = Color(entry.supplement.colorValue);

    // An expanded text column against a CEILED trailing state. A rigid state
    // is overflow-proof only while it is narrower than the row: at textScaler
    // 2.0 "частина місяця" alone is wider, and the row overflowed by 40px.
    // The ceiling is `day_block_section.dart`'s WR-04 remediation — a third of
    // the row, which every state label is far below at scale 1.0, so the
    // mockup layout is untouched there and the label wraps instead of
    // overflowing at accessibility scales.
    return LayoutBuilder(
      builder: (context, constraints) {
        final ceiling = constraints.maxWidth.isFinite
            ? (constraints.maxWidth - _dotSize - _dotTextGap - _textStateGap) /
                3
            : double.infinity;
        return Row(
          key: ValueKey<String>('month-detail-row-$index'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.only(top: _dotTopMargin),
              child: Container(
                width: _dotSize,
                height: _dotSize,
                decoration: BoxDecoration(
                  color: cell.planned
                      ? color.withValues(alpha: _plannedDotAlpha)
                      : color,
                  borderRadius:
                      const BorderRadius.all(Radius.circular(_dotRadius)),
                ),
              ),
            ),
            const SizedBox(width: _dotTextGap),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    entry.supplement.name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      height: 1.3,
                      color: BqColors.ink,
                    ),
                  ),
                  if (hint.isNotEmpty) ...[
                    const SizedBox(height: _nameHintGap),
                    Text(
                      hint,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w400,
                        height: 1.4,
                        color: BqColors.textMuted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: _textStateGap),
            Padding(
              padding: const EdgeInsetsDirectional.only(top: _stateTopMargin),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: ceiling),
                child: Text(
                  state,
                  // WRAPS rather than ellipsizes: "частина місяця" truncated to
                  // "частина…" would read as a different claim about the month.
                  textAlign: TextAlign.end,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w400,
                    color: stateColor,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
