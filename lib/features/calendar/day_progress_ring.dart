/// Day-progress ring — the Calendar screen's visual focal point
/// (plan 03-03, mockup screen 02 lines 210-211, UI-SPEC E4 / M10 / DECIDED-7).
///
/// M10: the mockup draws this as a CSS `conic-gradient`. It is reproduced here
/// as a hard-edged `CustomPaint` arc rather than through the Material circular
/// progress indicator, whose rounded stroke caps, leading gap and implicit
/// animation all fight the drawn design — and Interaction Contract 9 forbids
/// the ring animating at all in v1.
///
/// The ring counts `taken` against EVERY dose of the day, with `skipped`
/// counted as not-taken (mockup formula line 716); those counts come from the
/// tested `dayRingCounts` helper in `day_view_model.dart`, never from a local
/// recount.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:vitomy/core/l10n/l10n.dart';
import 'package:vitomy/core/theme/theme.dart';
import 'package:vitomy/core/theme/tokens.dart';

/// Outer box of the ring (mockup line 210).
const double _ringBox = 46;

/// Track stroke width — 46px outer minus the 36px inner disc (lines 210-211).
const double _ringStroke = 5;

/// Diameter of the stroked circle: the stroke straddles this path, so the
/// painted band runs from 36px to 46px across.
const double _ringDiameter = _ringBox - _ringStroke;

/// A day's taken/total progress as a hard-edged arc with a mono counter.
///
/// The CALLER decides the `total == 0` case, not this widget: at zero total the
/// header omits the ring entirely (DECIDED-7 — a "0/0" ring is meaningless
/// chrome, and the empty-day copy carries the message instead). The assert
/// below makes that contract impossible to regress silently.
class DayProgressRing extends StatelessWidget {
  const DayProgressRing({super.key, required this.taken, required this.total})
      : assert(
          total > 0,
          'DayProgressRing must not be constructed at total == 0 — the '
          'caller omits it entirely on an empty day (DECIDED-7).',
        );

  /// Doses of the day whose status is `taken`.
  final int taken;

  /// Every dose of the day; `skipped` counts toward this, not toward [taken].
  final int total;

  @override
  Widget build(BuildContext context) {
    // The locale ALWAYS comes from the widget tree, never a literal tag, and
    // the formatter is built INSIDE build so a locale change re-derives it
    // (PF-4). `planner_year_grid.dart` already formats its month load exactly
    // this way; the ring interpolated raw ASCII digits instead, so the
    // codebase disagreed with its own "numerals are locale-formatted" rule
    // (WR-07).
    final locale = Localizations.localeOf(context).toString();
    final number = NumberFormat.decimalPattern(locale);

    return Semantics(
      // A bare canvas is invisible to screen readers, so the counts are
      // restated as a localized label (UI-SPEC Layout & i18n Rules).
      label: context.l10n.ringSemantics(taken, total),
      // The counter Text is visual chrome for the same two numbers: without
      // excluding it, the label reads out as "2 з 5 доз прийнято, 2/5".
      excludeSemantics: true,
      child: SizedBox(
        width: _ringBox,
        height: _ringBox,
        child: CustomPaint(
          painter: _RingPainter(fraction: (taken / total).clamp(0.0, 1.0)),
          child: Center(
            // "/" is a separator glyph, the sanctioned string-literal
            // exception — it is not translatable copy.
            child: Text(
              '${number.format(taken)}/${number.format(total)}',
              style: BqText.mono(size: 12, color: BqColors.calm),
            ),
          ),
        ),
      ),
    );
  }
}

/// `field` track under a `calm` progress arc, both butt-capped so the arc's
/// leading edge is as hard as the mockup's conic gradient.
class _RingPainter extends CustomPainter {
  const _RingPainter({required this.fraction});

  /// Progress in 0..1 — the ONLY thing this painter draws from, which is why
  /// the repaint check below compares nothing else (Interaction Contract 9).
  final double fraction;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: _ringDiameter,
      height: _ringDiameter,
    );
    final track = Paint()
      ..color = BqColors.field
      ..style = PaintingStyle.stroke
      ..strokeWidth = _ringStroke;
    canvas.drawCircle(rect.center, _ringDiameter / 2, track);

    if (fraction <= 0) return;
    final arc = Paint()
      ..color = BqColors.calm
      ..style = PaintingStyle.stroke
      ..strokeWidth = _ringStroke
      ..strokeCap = StrokeCap.butt;
    canvas.drawArc(
      rect,
      // Twelve o'clock, sweeping clockwise (Flutter's zero angle is 3 o'clock
      // and positive sweeps run clockwise).
      -math.pi / 2,
      2 * math.pi * fraction,
      false,
      arc,
    );
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) =>
      oldDelegate.fraction != fraction;
}
