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
/// This file paints ONLY the rows. Month labels, month gridlines, the today
/// marker and the legend are plan 04-02's, and land around these rows without
/// changing them.
///
/// `_RingPainter`'s discipline is carried over verbatim: `shouldRepaint`
/// compares only what is actually painted.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:boostque/core/theme/tokens.dart';
import 'package:boostque/features/calendar/planner_view_model.dart';

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

/// The gantt card: one [GanttRowBar] per regimen-bearing stack entry.
class PlannerGantt extends StatelessWidget {
  const PlannerGantt({super.key, required this.model});

  /// The derived Цикли model — never built in `build()` (PF-10).
  final CyclesModel model;

  @override
  Widget build(BuildContext context) {
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
        borderRadius:
            const BorderRadius.all(Radius.circular(BqRadii.panel)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < model.rows.length; i++) ...[
            if (i > 0) const SizedBox(height: _rowGap),
            GanttRowBar(row: model.rows[i]),
          ],
        ],
      ),
    );
  }
}

/// One supplement's row: its name above its painted track.
class GanttRowBar extends StatelessWidget {
  const GanttRowBar({super.key, required this.row});

  /// The row's entry and its painted bands.
  final GanttRow row;

  @override
  Widget build(BuildContext context) {
    final name = row.entry.supplement.name;

    return MergeSemantics(
      child: Semantics(
        // The painted bands are invisible to assistive tech; for now the row
        // announces its supplement. The fuller label — schedule summary plus
        // period count — lands with its ARB keys in plan 04-02.
        label: name,
        excludeSemantics: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
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

      canvas.save();
      canvas.clipRRect(rrect);
      canvas.drawRRect(rrect, Paint()..color = BqColors.plannedHatchWeak);
      final hatch = Paint()
        ..color = BqColors.plannedHatchStrong
        ..strokeWidth = 4;
      // 4px on / 4px off diagonal strokes (mockup line 647), clipped to the
      // segment so the hatch never bleeds onto the track.
      for (var x = left - size.height;
          x < left + width + size.height;
          x += 8) {
        canvas.drawLine(
          Offset(x, size.height),
          Offset(x + size.height, 0),
          hatch,
        );
      }
      canvas.restore();

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
