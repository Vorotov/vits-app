/// The concurrent-load chart for the Цикли segment (plan 04-03, UI-SPEC S6a
/// item 3, P-9, DECIDED-2/3/10).
///
/// Eighteen or nineteen counted bars are not X/Y series data, so this is plain
/// widgets — a `Row` of `Expanded` columns — with exactly one painter, for the
/// dashed reference line. No charting package may be added (CLAUDE.md "What
/// NOT to Use" rejects `fl_chart` by name).
///
/// ## What the colours mean here
///
/// `warn` means "at our editorial limit" and `risk` means "above our editorial
/// limit". Neither ever means unsafe, and neither marks a destructive control
/// — this screen has none (PLAN-04, the UI-SPEC's over-limit clause). The
/// dashed line is the COMFORT reference, never a safety threshold, and it is
/// the only line drawn: the limit needs no ink because it is already
/// structural, being exactly where the main bar caps and the over-bar starts
/// (DECIDED-2).
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

/// Gap between two week columns (mockup line 338 `gap:3px`).
const double _columnGap = 3;

/// Full height of the main bar at the editorial limit (mockup line 905
/// `Math.round(Math.min(w.load, MAX_SLOTS) / MAX_SLOTS * 38)`).
const double _barFullHeight = 38;

/// Bar corner radius (mockup lines 342-343 `border-radius:2px`).
const double _barRadius = 2;

/// The zero-load stub (DECIDED-3, M8): a column with no pixels reads as a gap
/// in the chart and gives its tap target no visible anchor.
const double _zeroStubHeight = 2;

/// Height of the dashed reference line above the chart baseline (mockup line
/// 339 `bottom:22.8px`) — 0.6 x 38px, which is exactly the comfort load.
const double _thresholdOffset = 22.8;

/// Dash geometry of that line (mockup line 339, `0 4px` on / `4px 8px` off).
const double _dashOn = 4;
const double _dashOff = 4;
const double _thresholdWidth = 1;

/// Header and axis type (mockup lines 335-336, 347). `.06em` of 10.5px is
/// 0.63 logical pixels.
const double _titleSize = 10.5;
const double _titleTracking = 0.63;
const double _axisSize = 10;

/// The load chart card: a header, the columns under their comfort reference,
/// and an axis row carrying the real bucket bounds.
class PlannerLoadChart extends ConsumerWidget {
  const PlannerLoadChart({super.key, required this.model});

  /// The derived Цикли model — never built in `build()` (PF-10).
  final CyclesModel model;

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
            child: Stack(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < weeks.length; i++) ...[
                      if (i > 0) const SizedBox(width: _columnGap),
                      Expanded(
                        child: _WeekColumn(
                          index: i,
                          week: weeks[i],
                          selected: i == selected,
                        ),
                      ),
                    ],
                  ],
                ),
                // ONE dashed line, and it sits at the comfort height. Drawn
                // last so it reads over the bars, exactly as the mockup's
                // absolutely-positioned rule does.
                const PositionedDirectional(
                  key: ValueKey<String>('load-threshold'),
                  start: 0,
                  end: 0,
                  bottom: _thresholdOffset,
                  height: _thresholdWidth,
                  child: CustomPaint(painter: _ThresholdLinePainter()),
                ),
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
                // Names both numbers and nothing else — "межа" and "комфорт"
                // are the ONLY labels either reference gets (DECIDED-2).
                text: l10n.loadAxisLegend(editorialLimit, comfortLoad),
                align: TextAlign.center,
              ),
              _AxisLabel(
                text: weeks.isEmpty
                    ? ''
                    : axis.format(weeks.last.bucket.endInclusive),
                align: TextAlign.end,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// One third of the axis row. Three `Expanded` children rather than three
/// rigid ones, so a long localized date truncates instead of overflowing.
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
  });

  final int index;
  final WeekLoad week;
  final bool selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toString();
    final range = DateFormat.MMMd(locale);
    final load = week.load;

    // Verbatim from the mockup (lines 904-906): the main bar is the load
    // capped at the limit, and everything above the limit becomes a
    // proportional over-bar. `risk` here means "above OUR editorial limit".
    final mainHeight =
        (math.min(load, editorialLimit) / editorialLimit * _barFullHeight)
            .roundToDouble();
    final overHeight = load > editorialLimit
        ? ((load - editorialLimit) / editorialLimit * _barFullHeight)
            .roundToDouble()
        : 0.0;
    final Color barColor = load <= comfortLoad
        ? BqColors.loadBar
        : load <= editorialLimit
            ? BqColors.warn
            : BqColors.risk;

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
        // Same pre-formatted slot count the week-detail card renders (WR-05).
        l10n.weekLoadLabel(load, l10n.slotsCount(editorialLimit)),
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
                // No `top`, so the bars keep their intrinsic height and an
                // extreme over-limit week grows upward instead of throwing.
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (overHeight > 0)
                      Container(
                        key: ValueKey<String>('load-over-$index'),
                        height: overHeight,
                        decoration: const BoxDecoration(
                          color: BqColors.risk,
                          borderRadius: BorderRadiusDirectional.only(
                            topStart: Radius.circular(_barRadius),
                            topEnd: Radius.circular(_barRadius),
                          ),
                        ),
                      ),
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
                        decoration: BoxDecoration(
                          color: barColor,
                          borderRadius: const BorderRadius.all(
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

/// The 4px-on / 4px-off comfort reference.
///
/// There is no dashed-line drawing anywhere else in this codebase, so this is
/// written straight from the spec: a 1px horizontal run of alternating dashes
/// in `thresholdDash`.
class _ThresholdLinePainter extends CustomPainter {
  const _ThresholdLinePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = BqColors.thresholdDash
      ..strokeWidth = size.height;
    final y = size.height / 2;
    for (var x = 0.0; x < size.width; x += _dashOn + _dashOff) {
      canvas.drawLine(
        Offset(x, y),
        Offset(math.min(x + _dashOn, size.width), y),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_ThresholdLinePainter oldDelegate) => false;
}
