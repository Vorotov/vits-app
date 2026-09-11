/// The concurrent-load chart for the Цикли segment (plan 04-03, UI-SPEC S6a
/// item 3, P-9, DECIDED-3/10; neutralized by plan 06-05, spec §3.1).
///
/// Eighteen or nineteen counted bars are not X/Y series data, so this is plain
/// widgets — a `Row` of `Expanded` columns, and now no painter at all. No
/// charting package may be added (CLAUDE.md "What NOT to Use" rejects
/// `fl_chart` by name).
///
/// ## The chart states a shape, not a verdict
///
/// Every bar carries the single neutral bar token at every height: one colour,
/// no reference line and no over-segment, because there is no longer a limit
/// to be over. What the chart shows is the PROFILE of the window — where the
/// user's stack bunches up and where it thins out — and the reader is left to
/// decide what to make of it.
///
/// The scale is the user's own stack: a bar's height is its week's load over
/// [CyclesModel.scheduledCount]. A full-width caption under the axis bounds
/// says so in words (`loadScaleCaption`), because a self-scaling chart whose
/// denominator is invisible invites the reader to invent one — most likely a
/// limit.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:vitomy/core/l10n/l10n.dart';
import 'package:vitomy/core/theme/theme.dart';
import 'package:vitomy/core/theme/tokens.dart';
import 'package:vitomy/features/calendar/planner_providers.dart';
import 'package:vitomy/features/calendar/planner_view_model.dart';

/// Card padding (mockup line 333 `padding:16px 14px 14px`).
const double _cardPadTop = 16;
const double _cardPadHorizontal = 14;
const double _cardPadBottom = 14;

/// Header row → chart gap (mockup line 334 `margin-bottom:12px`).
const double _headerGap = 12;

/// Height of the drawn chart area (mockup line 338 `height:46px`).
const double _chartHeight = 46;

/// Headroom above the chart, folded INTO each column's tap target.
///
/// A column is only about 15px wide on a 390pt screen, which is inherently
/// below the 44pt guidance and not fixable without changing the chart's
/// information density. It earns its target from height instead: 46 + 7 = 53px
/// of opaque, hit-testable column (DECIDED-10). The same 7px is what the
/// mockup puts between the chart and its axis row (line 347).
const double _chartHeadroom = 7;

/// Gap between the chart and the axis-label row (mockup line 347
/// `margin-top:7px`).
const double _axisGap = 7;

/// Gap between the axis bounds and the scale caption on its own row (CR-02).
/// Hairline by intent: the caption reads as a continuation of the axis, not as
/// a fourth block in the card.
const double _captionGap = 2;

/// Gap between two week columns (mockup line 338 `gap:3px`).
const double _columnGap = 3;

/// Full height of a bar — drawn when the week's load equals the ceiling
/// (mockup line 905's 38px, kept; its denominator is what changed).
const double _barFullHeight = 38;

/// Bar corner radius (mockup lines 342-343 `border-radius:2px`).
const double _barRadius = 2;

/// The zero-load stub (DECIDED-3, M8): a column with no pixels reads as a gap
/// in the chart and gives its tap target no visible anchor.
const double _zeroStubHeight = 2;

/// Header and axis type (mockup lines 335-336, 347). `.06em` of 10.5px is
/// 0.63 logical pixels.
const double _titleSize = 10.5;
const double _titleTracking = 0.63;
const double _axisSize = 10;

/// The load chart card: a header, the week columns, and an axis row carrying
/// the real bucket bounds around the scale caption.
class PlannerLoadChart extends ConsumerWidget {
  const PlannerLoadChart({
    super.key,
    required this.model,
    required this.scheduledCount,
  });

  /// The derived Цикли model — never built in `build()` (PF-10).
  final CyclesModel model;

  /// The bars' denominator: how many supplements carry a schedule, passed in
  /// from the screen off [CyclesModel.scheduledCount].
  ///
  /// The chart neither computes nor defaults it. A scale living in a widget is
  /// a magic number waiting to be mistaken for a rule, and the invariant that
  /// makes the geometry safe — `load <= scheduledCount` — is only provable
  /// where both numbers are derived, which is the model.
  final int scheduledCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    // The locale ALWAYS comes from the widget tree, never a literal tag.
    final locale = Localizations.localeOf(context).toString();
    // Both bounds carry a day number, so the FORMAT (genitive) month case is
    // the correct one here — unlike the gantt's standalone header (PF-4).
    final axis = DateFormat.MMMd(locale);
    final selected = ref.watch(resolvedWeekIndexProvider);
    final weeks = model.weeks;

    return Container(
      padding: const EdgeInsetsDirectional.only(
        top: _cardPadTop,
        start: _cardPadHorizontal,
        end: _cardPadHorizontal,
        bottom: _cardPadBottom,
      ),
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
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: Text(
                  l10n.loadChartTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: BqText.mono(
                    size: _titleSize,
                    weight: FontWeight.w500,
                    color: BqColors.textMuted,
                    letterSpacing: _titleTracking,
                  ),
                ),
              ),
              const SizedBox(width: BqSpace.sm),
              Flexible(
                child: Text(
                  l10n.loadChartMeta,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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
          ),
          const SizedBox(height: _headerGap),
          SizedBox(
            height: _chartHeight + _chartHeadroom,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < weeks.length; i++) ...[
                  if (i > 0) const SizedBox(width: _columnGap),
                  Expanded(
                    child: _WeekColumn(
                      index: i,
                      week: weeks[i],
                      selected: i == selected,
                      scheduledCount: scheduledCount,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: _axisGap),
          Row(
            children: [
              _AxisLabel(
                text: weeks.isEmpty
                    ? ''
                    : axis.format(weeks.first.bucket.start),
                align: TextAlign.start,
              ),
              _AxisLabel(
                text: weeks.isEmpty
                    ? ''
                    : axis.format(weeks.last.bucket.endInclusive),
                align: TextAlign.end,
              ),
            ],
          ),
          const SizedBox(height: _captionGap),
          // REPLACED, never removed: the bars scale against the user's own
          // scheduled stack, and a scale the reader cannot see is a scale the
          // reader will guess at. The caption states what a full bar means and
          // judges nothing.
          //
          // Its OWN full-width row, under the two bounds rather than wedged
          // between them (CR-02). As a third equal slot it got 107 of the
          // card's 322 logical pixels and ellipsized in both locales on every
          // phone — «повний стовпчик …» — while the two date labels each used
          // under half of theirs. A truncated ceiling statement leaves the
          // ceiling exactly as invisible as deleting the caption would (D-4).
          //
          // `maxLines: 2` and no `overflow`: this is a caption, not a data
          // label, so it may wrap. At a large text scale wrapping is the
          // correct outcome and truncation never is.
          Text(
            l10n.loadScaleCaption,
            textAlign: TextAlign.center,
            maxLines: 2,
            style: BqText.mono(
              size: _axisSize,
              weight: FontWeight.w400,
              color: BqColors.textFaint,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

/// One half of the axis row: the window's start bound or its end bound.
///
/// Two `Expanded` children rather than two rigid ones, so a long localized
/// date truncates instead of overflowing. The scale caption is deliberately
/// NOT one of these — it gets its own full-width row below, because a caption
/// competing with a date for a third of the card is a caption nobody can read
/// (CR-02).
class _AxisLabel extends StatelessWidget {
  const _AxisLabel({required this.text, required this.align});

  final String text;
  final TextAlign align;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Text(
        text,
        textAlign: align,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: BqText.mono(
          size: _axisSize,
          weight: FontWeight.w400,
          color: BqColors.textFaint,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

/// One week: an opaque full-height tap target holding its bars.
class _WeekColumn extends ConsumerWidget {
  const _WeekColumn({
    required this.index,
    required this.week,
    required this.selected,
    required this.scheduledCount,
  });

  final int index;
  final WeekLoad week;
  final bool selected;

  /// The bars' denominator — see [PlannerLoadChart.scheduledCount].
  final int scheduledCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toString();
    final range = DateFormat.MMMd(locale);
    final load = week.load;

    // The week's load over the scheduled stack, times the full-bar height.
    //
    // No cap, no clamp, no clipping and no over-segment — and none is missing.
    // `load` counts the SCHEDULED supplements overlapping this week and
    // [scheduledCount] counts all of them, both from the same collection, so
    // `load <= scheduledCount` holds by construction (asserted in
    // planner_view_model_test.dart over generated stacks). A bar therefore can
    // never exceed `_barFullHeight`, and a second bar above it would be
    // drawing a state that cannot occur.
    //
    // The two edge values are correct by design, not bugs to be guarded:
    //
    //  * ceiling 1 — a stack of one draws a FULL bar in every week that one
    //    supplement is active. The chart's question is "how much of my stack
    //    is running at once"; the answer is "all of it". Nothing is being
    //    exceeded.
    //  * ceiling 0 — nothing carries a schedule, so the planner renders its
    //    existing empty state and this chart is never built. The division is
    //    unreachable, which is why there is no zero guard here: a guard would
    //    be dead code implying the empty state might not hold.
    final mainHeight =
        (load / scheduledCount * _barFullHeight).roundToDouble();

    // The bucket's Monday, never the column's position: the bucket list is
    // rebuilt from the clock, and an index outlives the list it indexed
    // (WR-03).
    void select() =>
        ref.read(selectedWeekProvider.notifier).select(week.bucket.start);

    return Semantics(
      button: true,
      selected: selected,
      label: l10n.weekBarSemantics(
        '${range.format(week.bucket.start)} – '
        '${range.format(week.bucket.endInclusive)}',
        // The count itself, pre-formatted and declined by its own plural key
        // (WR-05). It names no denominator, because there is no limit to
        // measure the week against — "4 з 4 речовин" would be a tautology.
        l10n.substancesCount(load),
      ),
      excludeSemantics: true,
      // The action lives on THIS node, not on the GestureDetector below it:
      // `excludeSemantics` drops every descendant action, so without this a
      // column would announce itself as a button that VoiceOver / TalkBack
      // could not activate (WR-02).
      onTap: select,
      child: GestureDetector(
        // The whole column is the tap target — the painted bar must never
        // define it, or a short bar would be nearly unhittable (DECIDED-10).
        behavior: HitTestBehavior.opaque,
        onTap: select,
        child: Opacity(
          // The opacity change IS the press feedback; no ripple
          // (Interaction Contract 11).
          opacity: selected ? 1.0 : 0.5,
          child: Stack(
            key: ValueKey<String>('load-week-$index'),
            children: [
              PositionedDirectional(
                start: 0,
                end: 0,
                bottom: 0,
                // No `top`: the bar keeps its intrinsic height, and it cannot
                // outgrow the chart area because it cannot outgrow full
                // height.
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (load == 0)
                      Container(
                        key: ValueKey<String>('load-stub-$index'),
                        height: _zeroStubHeight,
                        decoration: const BoxDecoration(
                          color: BqColors.field,
                          borderRadius: BorderRadius.all(
                            Radius.circular(_barRadius),
                          ),
                        ),
                      )
                    else
                      Container(
                        key: ValueKey<String>('load-main-$index'),
                        height: mainHeight,
                        decoration: const BoxDecoration(
                          // ONE bar colour, at every height. The bar's height
                          // is the whole message; colour would add a verdict
                          // the chart no longer makes.
                          color: BqColors.loadBar,
                          borderRadius: BorderRadius.all(
                            Radius.circular(_barRadius),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
