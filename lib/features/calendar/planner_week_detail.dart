/// The inline week-detail card for the Цикли segment (plan 04-03, UI-SPEC S6a
/// item 4, P-7, P-13, DECIDED-8).
///
/// ALWAYS present in the scroll flow, immediately below the load chart, and
/// never a modal sheet: the user is comparing this card against the chart
/// directly above it, and a sheet would cover the very thing being compared
/// (P-13). Selecting a different week re-renders it in place.
///
/// ## What the colours and words mean here
///
/// `warn` means "at our editorial limit" and `risk` means "above our editorial
/// limit" — never unsafe, never an error, never a destructive control
/// (PLAN-04). The over-limit note ships TRUNCATED after its referral clause;
/// the mockup's trailing pharmacological clause is a claim this product cannot
/// support and must never be restored (M2, DECIDED-8). The copy lives in the
/// ARB files exactly as plan 04-02 wrote it — this file only chooses a key.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:boostque/core/l10n/l10n.dart';
import 'package:boostque/core/theme/theme.dart';
import 'package:boostque/core/theme/tokens.dart';
import 'package:boostque/features/calendar/planner_providers.dart';
import 'package:boostque/features/calendar/planner_view_model.dart';

/// Card padding (mockup line 352 `padding:17px`).
const double _cardPadding = 17;

/// Range → meta gap and header ↔ chip gap (mockup lines 353-354).
const double _rangeMetaGap = 4;
const double _headerChipGap = 10;

/// Verdict chip (mockup line 355 `padding:6px 8px`). `.04em` of 9.5px is 0.38
/// logical pixels.
const double _chipPadVertical = 6;
const double _chipPadHorizontal = 8;
const double _chipSize = 9.5;
const double _chipTracking = 0.38;

/// Pip row (mockup lines 357-359).
const double _pipTopMargin = 14;
const double _pipGap = 5;
const double _pipHeight = 9;
const double _pipRadius = 5;
const double _pipBorder = 1;

/// Name chips (mockup lines 362-364).
const double _chipsTopMargin = 14;
const double _chipsGap = 6;
const double _nameChipPadVertical = 6;
const double _nameChipPadHorizontal = 9;
const double _nameChipSize = 11.5;

/// The verdict note (mockup line 367 `margin-top:14px`).
const double _noteTopMargin = 14;

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
    final load = week.load;

    // A day number is present, so the FORMAT (genitive) month case is the
    // correct one here — the opposite of the gantt's standalone header (PF-4).
    final range = DateFormat.MMMd(locale);
    final free = editorialLimit - load;

    // ONE exhaustive switch over the sealed verdict, in the shape the day
    // block's tag chip uses: a future case is a compile error here rather
    // than a silently missing chip.
    final (String verdict, String note, Color fg, Color bg) =
        switch (verdictOf(load)) {
      ComfortVerdict() => (
          l10n.verdictComfort,
          l10n.weekNoteComfort,
          BqColors.calm,
          BqColors.calmBg,
        ),
      LimitVerdict() => (
          l10n.verdictLimit,
          l10n.weekNoteLimit,
          BqColors.warn,
          BqColors.warnBg,
        ),
      OverLimitVerdict(:final load) => (
          l10n.verdictOverLimit,
          // The count is PRE-FORMATTED through its own plural key and passed
          // into the sentence, which is already truncated in the ARB and must
          // not be re-extended here (M2, DECIDED-8).
          l10n.weekNoteOverLimit(l10n.cyclesCount(load)),
          BqColors.risk,
          BqColors.riskBg,
        ),
    };

    return Container(
      key: const ValueKey<String>('week-detail-card'),
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
          Row(
            children: [
              // A flexible text column against a rigid trailing chip — never
              // three rigid children, which is how a header overflows (WR-04).
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${range.format(week.bucket.start)} – '
                      '${range.format(week.bucket.endInclusive)}',
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w600,
                        height: 1.25,
                        color: BqColors.ink,
                      ),
                    ),
                    const SizedBox(height: _rangeMetaGap),
                    Text(
                      // " · " is a separator glyph, the sanctioned literal
                      // exception — both halves are ARB copy.
                      '${l10n.weekLoadLabel(load, editorialLimit)} · '
                      '${free > 0 ? l10n.weekFreeSlots(free) : l10n.weekNoFreeSlots}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        height: 1.4,
                        color: BqColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: _headerChipGap),
              Container(
                key: const ValueKey<String>('week-verdict-chip'),
                padding: const EdgeInsetsDirectional.symmetric(
                  vertical: _chipPadVertical,
                  horizontal: _chipPadHorizontal,
                ),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius:
                      const BorderRadius.all(Radius.circular(BqRadii.chip)),
                ),
                child: Text(
                  verdict,
                  maxLines: 1,
                  softWrap: false,
                  style: BqText.mono(
                    size: _chipSize,
                    weight: FontWeight.w500,
                    color: fg,
                    letterSpacing: _chipTracking,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: _pipTopMargin),
          _SlotPips(load: load),
          const SizedBox(height: _chipsTopMargin),
          Wrap(
            key: const ValueKey<String>('week-name-chips'),
            spacing: _chipsGap,
            runSpacing: _chipsGap,
            children: [
              // Zero names means an EMPTY Wrap and nothing else: a week with
              // no cycles is a normal week, not an empty state.
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
          const SizedBox(height: _noteTopMargin),
          Text(
            note,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              height: 1.6,
              color: BqColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// `max(limit, load)` equal-flex pips.
///
/// An over-limit week therefore shows its excess as pips that ran PAST the
/// row, which is the visual half of the same statement the note makes in
/// words. `risk` here means "past our editorial limit", never "unsafe".
class _SlotPips extends StatelessWidget {
  const _SlotPips({required this.load});

  final int load;

  @override
  Widget build(BuildContext context) {
    final count = math.max(editorialLimit, load);

    return Row(
      children: [
        for (var i = 0; i < count; i++) ...[
          if (i > 0) const SizedBox(width: _pipGap),
          Expanded(
            child: Container(
              key: ValueKey<String>('week-pip-$i'),
              height: _pipHeight,
              decoration: BoxDecoration(
                color: i >= editorialLimit
                    ? BqColors.risk
                    : i < load
                        ? BqColors.accent
                        : BqColors.surface,
                border: Border.all(
                  color: i >= editorialLimit
                      ? BqColors.risk
                      : i < load
                          ? BqColors.accent
                          : BqColors.checkBorder,
                  width: _pipBorder,
                ),
                borderRadius:
                    const BorderRadius.all(Radius.circular(_pipRadius)),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
