/// Gantt card for the Цикли segment (plan 04-01, UI-SPEC S6a item 2, P-8).
///
/// The track and its segments are `CustomPaint`, not Material widgets, for the
/// same reason `DayProgressRing` is: the drawn design has no widget
/// equivalent. A planned segment is a diagonal 4px-on/4px-off hatch clipped
/// inside a rounded rect — `Container` decorations cannot express it, and no
/// charting or gantt package may be added (CLAUDE.md "What NOT to Use"
/// rejects `fl_chart` / `gantt_chart` / `table_calendar` by name). One painter
/// per row also avoids N nested `Positioned` widgets per row.
///
/// Around the rows sit the card's chrome: a mono month-label row sized to the
/// months' REAL day counts, 1px rules at the real month boundaries, the single
/// today line, and a three-entry legend. Every one of those positions is
/// arithmetic on the already-resolved model — this file computes no dates.
///
/// `_RingPainter`'s discipline is carried over verbatim: `shouldRepaint`
/// compares only what is actually painted.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:boostque/core/l10n/l10n.dart';
import 'package:boostque/core/theme/theme.dart';
import 'package:boostque/core/theme/tokens.dart';
import 'package:boostque/features/calendar/planner_view_model.dart';
import 'package:boostque/features/stack/schedule_summary_text.dart';
import 'package:boostque/features/stack/stack_status.dart';

/// Height of a row's track (mockup line 316 `height:11px`).
const double _trackHeight = 11;

/// Corner radius of the track and of every segment on it (mockup line 316
/// `border-radius:6px`).
const double _trackRadius = 6;

/// Vertical gap between rows (mockup line 311 `gap:13px`).
const double _rowGap = 13;

/// Gap between a row's name line and its track (mockup line 313
/// `margin-bottom:6px`).
const double _nameGap = 6;

/// Gap between a row's name and its schedule hint (mockup line 312 `gap:8px`).
const double _nameHintGap = 8;

/// Card padding (mockup line 300 `padding:16px 14px 14px`).
const double _cardPadTop = 16;
const double _cardPadHorizontal = 14;
const double _cardPadBottom = 14;

/// Narrowest a segment may ever paint.
///
/// A one-day run in a 122-day window is 0.82 of a percent — under 3px on a
/// ~340px track, and rounding can collapse it to nothing at all. A cycle the
/// user really has must never render as an empty track (PF-6).
const double _minSegmentWidth = 2;

/// Gap between the month-label row and the chart (mockup line 301
/// `margin-bottom:9px`).
const double _monthRowGap = 9;

/// Width of a gridline and of the today marker (mockup lines 305-308
/// `width:1px`).
const double _ruleWidth = 1;

/// Month-label type (mockup line 301 `400 10.5px mono`, `letter-spacing:.05em`
/// — .05em of 10.5px is 0.525 logical pixels).
const double _monthLabelSize = 10.5;
const double _monthLabelTracking = 0.525;

/// Legend geometry (mockup lines 325-329): 15px above a 1px rule, 13px below
/// it, a `Wrap` with 12px gaps, and 14x8 radius-4 swatches 6px from a label.
const double _legendTopMargin = 15;
const double _legendRulePadding = 13;
const double _legendGap = 12;
const double _swatchWidth = 14;
const double _swatchHeight = 8;
const double _swatchRadius = 4;
const double _swatchLabelGap = 6;
const double _legendLabelSize = 11;

/// The gantt card: the month scale, the painted rows under their gridlines and
/// today marker, and the three-entry legend.
class PlannerGantt extends StatelessWidget {
  const PlannerGantt({super.key, required this.model});

  /// The derived Цикли model — never built in `build()` (PF-10).
  final CyclesModel model;

  @override
  Widget build(BuildContext context) {
    // Isolates the painted rows from the load chart below: selecting a week
    // changes opacities down there and must not cost a repaint up here
    // (Interaction Contract 12).
    return RepaintBoundary(
      child: Container(
        padding: const EdgeInsetsDirectional.only(
          top: _cardPadTop,
          start: _cardPadHorizontal,
          end: _cardPadHorizontal,
          bottom: _cardPadBottom,
        ),
        decoration: BoxDecoration(
          color: BqColors.surface,
          border: Border.all(color: BqColors.cardBorder),
          borderRadius:
              const BorderRadius.all(Radius.circular(BqRadii.panel)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            _MonthScale(months: model.months),
            const SizedBox(height: _monthRowGap),
            _RowsWithRules(model: model),
            const _GanttLegend(),
          ],
        ),
      ),
    );
  }
}

/// The mono month header, each label as wide as its month's REAL day count.
///
/// `Expanded(flex: days)` is the whole of PF-3: a four-month window is 120 to
/// 123 days long, so a fixed quarter per column would misplace every boundary
/// under it by up to a day and a half. The flex weights ARE the day counts, so
/// the header and the gridlines below can never disagree.
class _MonthScale extends StatelessWidget {
  const _MonthScale({required this.months});

  final List<MonthColumn> months;

  @override
  Widget build(BuildContext context) {
    // The locale ALWAYS comes from the widget tree, never a literal tag.
    final locale = Localizations.localeOf(context).toString();
    // STANDALONE pattern letters: a month abbreviation standing alone without
    // a day number is nominative in Ukrainian ("серп."), which `MMM` would
    // silently render as the genitive instead (PF-4).
    final format = DateFormat('LLL', locale);

    return Row(
      children: [
        for (var i = 0; i < months.length; i++)
          Expanded(
            flex: months[i].days,
            child: Text(
              // Locale-aware uppercasing of intl output — never a hardcoded
              // uppercase string and never a month table (M6).
              format.format(months[i].month).toUpperCase(),
              key: ValueKey<String>('gantt-month-$i'),
              // A two-to-five character abbreviation is single-line by nature;
              // wrapping one at a large text scale would grow the header by a
              // whole line for nothing (the week strip's rule).
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              style: BqText.mono(
                size: _monthLabelSize,
                weight: FontWeight.w400,
                color: BqColors.textMuted,
                letterSpacing: _monthLabelTracking,
              ),
            ),
          ),
      ],
    );
  }
}

/// The row column under its month gridlines and the today marker.
///
/// A `LayoutBuilder` reads the available width ONCE and every fraction becomes
/// pixels there. A fractionally-sized widget cannot express "left offset plus
/// width" inside a stack cleanly, while a positioned child at a computed pixel
/// offset is exact — and testable (P-8).
class _RowsWithRules extends StatelessWidget {
  const _RowsWithRules({required this.model});

  final CyclesModel model;

  @override
  Widget build(BuildContext context) {
    // Cumulative day fractions of the INTERIOR month boundaries: three of them
    // for a four-month window, at real month lengths.
    final boundaries = <double>[];
    var accumulated = 0.0;
    for (var i = 0; i < model.months.length - 1; i++) {
      accumulated += model.months[i].fraction;
      boundaries.add(accumulated);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        return Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < model.rows.length; i++) ...[
                  if (i > 0) const SizedBox(height: _rowGap),
                  GanttRowBar(row: model.rows[i]),
                ],
              ],
            ),
            for (var i = 0; i < boundaries.length; i++)
              PositionedDirectional(
                key: ValueKey<String>('gantt-gridline-$i'),
                start: boundaries[i] * width,
                top: 0,
                bottom: 0,
                width: _ruleWidth,
                child: const ColoredBox(color: BqColors.hairline),
              ),
            // Today is inside the window BY CONSTRUCTION, so this line always
            // has a place to render and needs no absent branch (P-4).
            PositionedDirectional(
              key: const ValueKey<String>('gantt-today-marker'),
              start: (model.todayIndex + 0.5) / model.span * width,
              top: 0,
              bottom: 0,
              width: _ruleWidth,
              child: const ColoredBox(color: BqColors.todayMarker),
            ),
          ],
        );
      },
    );
  }
}

/// Three entries under a hairline rule — and only three.
///
/// The mockup's fourth entry ("є взаємодія") asserts an interaction claim this
/// product does not make, so it does not ship (M1). Three IS the contract.
class _GanttLegend extends StatelessWidget {
  const _GanttLegend();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Padding(
      padding: const EdgeInsetsDirectional.only(top: _legendTopMargin),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            height: _ruleWidth,
            child: ColoredBox(color: BqColors.hairline),
          ),
          const SizedBox(height: _legendRulePadding),
          Wrap(
            spacing: _legendGap,
            runSpacing: _legendGap,
            children: [
              _LegendEntry(
                slug: 'taking',
                label: l10n.legendTaking,
                swatch: const DecoratedBox(
                  decoration: BoxDecoration(
                    color: BqColors.accent,
                    borderRadius:
                        BorderRadius.all(Radius.circular(_swatchRadius)),
                  ),
                ),
              ),
              _LegendEntry(
                slug: 'planned',
                label: l10n.legendPlanned,
                swatch: CustomPaint(
                  painter: const _HatchSwatchPainter(),
                  child: const DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border.fromBorderSide(
                        BorderSide(color: BqColors.plannedBorder),
                      ),
                      borderRadius:
                          BorderRadius.all(Radius.circular(_swatchRadius)),
                    ),
                  ),
                ),
              ),
              _LegendEntry(
                slug: 'paused',
                label: l10n.legendPaused,
                // A paused row IS a bare track, which is why this swatch and
                // the track share the one `chip` value (UI-SPEC token table).
                swatch: const DecoratedBox(
                  decoration: BoxDecoration(
                    color: BqColors.chip,
                    borderRadius:
                        BorderRadius.all(Radius.circular(_swatchRadius)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// One legend swatch and its label.
class _LegendEntry extends StatelessWidget {
  const _LegendEntry({
    required this.slug,
    required this.label,
    required this.swatch,
  });

  /// Stable identity for the widget test that pins the entry COUNT.
  final String slug;
  final String label;
  final Widget swatch;

  @override
  Widget build(BuildContext context) {
    return Row(
      key: ValueKey<String>('gantt-legend-$slug'),
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(width: _swatchWidth, height: _swatchHeight, child: swatch),
        const SizedBox(width: _swatchLabelGap),
        Text(
          label,
          style: const TextStyle(
            fontSize: _legendLabelSize,
            fontWeight: FontWeight.w400,
            color: BqColors.textMuted,
          ),
        ),
      ],
    );
  }
}

/// The planned hatch: 4px on, 4px off (mockup line 647).
///
/// The only two bare numbers this file used to carry, written out twice — in
/// the legend swatch and in the painted segment.
const double _hatchStroke = 4;
const double _hatchPeriod = _hatchStroke * 2;

/// Fills [rrect] with the planned ink: the weak wash under 4px-on/4px-off
/// diagonals, clipped so the hatch never bleeds past the shape.
///
/// ONE definition, two callers. The legend's whole job is to say "this ink
/// means planned", so the swatch and the segment are a correctness pair rather
/// than a duplication: written twice, changing the stroke in one leaves the
/// legend describing something the chart no longer draws (WR-06).
void _paintHatch(Canvas canvas, RRect rrect) {
  final bounds = rrect.outerRect;
  canvas.save();
  canvas.clipRRect(rrect);
  canvas.drawRRect(rrect, Paint()..color = BqColors.plannedHatchWeak);
  final hatch = Paint()
    ..color = BqColors.plannedHatchStrong
    ..strokeWidth = _hatchStroke;
  // The diagonals start one height to the left and end one height past the
  // right edge, so the clipped shape is covered corner to corner.
  for (var x = bounds.left - bounds.height;
      x < bounds.right + bounds.height;
      x += _hatchPeriod) {
    canvas.drawLine(
      Offset(x, bounds.bottom),
      Offset(x + bounds.height, bounds.top),
      hatch,
    );
  }
  canvas.restore();
}

/// The planned swatch's hatch — the same ink the planned segments carry, at
/// swatch scale, from the same helper.
class _HatchSwatchPainter extends CustomPainter {
  const _HatchSwatchPainter();

  @override
  void paint(Canvas canvas, Size size) {
    _paintHatch(
      canvas,
      RRect.fromRectAndRadius(
        Offset.zero & size,
        const Radius.circular(_swatchRadius),
      ),
    );
  }

  @override
  bool shouldRepaint(_HatchSwatchPainter oldDelegate) => false;
}

/// One supplement's row: its name above its painted track.
class GanttRowBar extends StatelessWidget {
  const GanttRowBar({super.key, required this.row});

  /// The row's entry and its painted bands.
  final GanttRow row;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final name = row.entry.supplement.name;
    // The Stack card's own words for this regimen, minus its daily-slot tail:
    // the planner is about time, not daily doses. Composing a second
    // description here is exactly how the two tabs would drift apart (M13).
    final hint = scheduleSummaryText(
      scheduleSummaryOf(row.entry),
      l10n: l10n,
      // The locale ALWAYS comes from the widget tree, never a literal tag.
      locale: Localizations.localeOf(context).toString(),
      withSlots: false,
    );

    return MergeSemantics(
      child: Semantics(
        // The painted bands are invisible to assistive tech, so the row speaks
        // what the canvas is carrying: its schedule and how many runs of it
        // fall inside the window — or, for a paused regimen, the one word the
        // bare track stands for. "0 періодів" alone cannot distinguish a
        // paused supplement from one that is merely off-cycle all window
        // (WR-01); the word comes from the legend's own key, never new copy.
        label: row.paused
            ? l10n.ganttRowSemanticsPaused(name, hint, l10n.legendPaused)
            : l10n.ganttRowSemantics(
                name,
                hint,
                l10n.periodsCount(row.runCount),
              ),
        excludeSemantics: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Two flexible children and nothing rigid: at any text scale the
            // label truncates instead of overflowing, and the NAME keeps
            // layout priority because it is what identifies the row (WR-04).
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Flexible(
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      height: 1.3,
                      color: BqColors.ink,
                    ),
                  ),
                ),
                if (hint.isNotEmpty) ...[
                  const SizedBox(width: _nameHintGap),
                  Flexible(
                    child: Text(
                      hint,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: BqText.mono(
                        size: 10.5,
                        weight: FontWeight.w400,
                        color: BqColors.textFaint,
                      ).copyWith(height: 1.3),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: _nameGap),
            SizedBox(
              height: _trackHeight,
              child: CustomPaint(
                painter: _GanttRowPainter(segments: row.segments),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A `chip` track carrying solid active and hatched planned segments.
class _GanttRowPainter extends CustomPainter {
  const _GanttRowPainter({required this.segments});

  /// Fractional left/right pairs plus their kind — the ONLY thing this painter
  /// draws from, which is why [shouldRepaint] compares nothing else. The list
  /// arrives from the cached model, so a new list means a genuinely new model.
  final List<GanttSegment> segments;

  @override
  void paint(Canvas canvas, Size size) {
    final track = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(_trackRadius),
    );
    // An empty segment list paints exactly this and stops — a bare track is
    // how the design shows a paused row (DECIDED-7).
    canvas.drawRRect(track, Paint()..color = BqColors.chip);

    for (final s in segments) {
      final left = s.startFraction * size.width;
      final width = math.max(
        _minSegmentWidth,
        (s.endFraction - s.startFraction) * size.width,
      );
      final rrect = RRect.fromRectAndRadius(
        Rect.fromLTWH(left, 0, width, size.height),
        const Radius.circular(_trackRadius),
      );

      if (!s.planned) {
        canvas.drawRRect(rrect, Paint()..color = BqColors.accent);
        continue;
      }

      // The same ink, from the same helper, as the legend's planned swatch —
      // the legend cannot describe a hatch the chart does not draw (WR-06).
      _paintHatch(canvas, rrect);

      canvas.drawRRect(
        rrect.deflate(0.5),
        Paint()
          ..color = BqColors.plannedBorder
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    }
  }

  @override
  bool shouldRepaint(_GanttRowPainter oldDelegate) =>
      oldDelegate.segments != segments;
}
