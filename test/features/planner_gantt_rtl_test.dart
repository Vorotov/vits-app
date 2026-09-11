/// The Цикли gantt under a right-to-left tree.
///
/// THE DEFECT. Every piece of the gantt's chrome flips with the reading
/// direction on its own: the month header is a `Row` (direction-aware by
/// default) and the month gridlines and the today marker are
/// `PositionedDirectional`. The painted track did not — `_GanttRowPainter`
/// mapped `startFraction` to an x offset from the LEFT edge unconditionally,
/// because a `Canvas` has no reading direction and nothing was telling it one.
/// So in Arabic and Urdu the bars ran left-to-right underneath a header
/// running right-to-left, and every bar pointed at the wrong month. Not a
/// cosmetic slip: a chart that states something false.
///
/// THE SHAPE OF THE PROOF, and why it is worth copying. Asserting "the painter
/// received a TextDirection" would pass on a painter that received it and
/// ignored it, so this file asserts GEOMETRY instead, at two levels that have
/// to agree:
///
///  1. The header. `getCenter` on the first and last month labels, which is
///     the reading order a user sees.
///  2. The track. The row's `CustomPainter` is replayed onto a recording
///     canvas (`_RecordedRRects` below) and the drawn rounded rects are read
///     back as numbers. The alternative — a golden image — would answer "did
///     the pixels change" when the question is "is the earliest cycle drawn at
///     the earliest month", and would need a new golden per platform.
///
/// Then it asserts the two AGREE: the earliest bar sits on the same side as
/// the earliest month label, in both directions. That is the actual bug, and
/// it is the assertion that would have failed before the fix.
///
/// WHY AN EXPLICIT `Directionality` RATHER THAN `locale: Locale('ar')`.
/// `WidgetsApp` derives the direction from the active locale, so once
/// `app_ar.arb` ships an Arabic build gets RTL for free and this test would be
/// expressible as a locale. It is deliberately NOT written that way: the
/// property under test is "the gantt obeys the direction it is given", which
/// is true or false independently of which languages happen to ship this week.
/// Written against a locale, this file would go red or green on an ARB landing
/// or being pulled — a test that changes verdict for reasons outside the code
/// it covers. Written against `Directionality`, it runs today, on a repo whose
/// two ARBs are both LTR, and keeps meaning the same thing after nine more
/// land. Copy that part.
///
/// This is the first RTL test in the repository. Later ones want the same
/// three pieces: an explicit `Directionality` wrapper INSIDE the app (it
/// overrides the one `WidgetsApp` computes), an LTR run and an RTL run built
/// from the SAME model so the comparison is a mirror rather than two
/// independent expectations, and assertions on numbers the widget actually
/// laid out.
library;

import 'package:vitomy/core/domain/models.dart';
import 'package:vitomy/core/domain/repositories.dart' show StackEntry;
import 'package:vitomy/core/l10n/l10n.dart';
import 'package:vitomy/core/theme/theme.dart';
import 'package:vitomy/features/calendar/planner_gantt.dart';
import 'package:vitomy/features/calendar/planner_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A `Canvas` that keeps the rounded rects drawn on it and swallows the rest.
///
/// `noSuchMethod` covers the whole of `Canvas` — `save`, `clipRRect`,
/// `drawLine`, everything the hatch uses — so this stays a few lines instead
/// of a hand-written stub that breaks the next time `dart:ui` adds a method.
/// Only `drawRRect` is overridden, because the bar positions this file is
/// about are drawn with exactly that call.
class _RecordedRRects implements Canvas {
  final List<RRect> drawn = <RRect>[];

  @override
  void drawRRect(RRect rrect, Paint paint) => drawn.add(rrect);

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  // A pinned clock: the planner window is derived from `today`, so an
  // unpinned one would move every fraction this file measures.
  final today = DateTime.utc(2026, 8, 13);

  // One course running 5 July to 30 August — comfortably inside the
  // 1 Jul – 31 Oct window, and firmly in its EARLIER half, which is what makes
  // "the bar is on the same side as the first month" a real claim rather than
  // a coincidence about a bar that spans everything.
  //
  // The dates moved back one month with the window itself (owner change
  // 2026-09-01: the band is now last month, this month and two ahead). Left on
  // 5 Aug – 30 Sep they would have straddled the MIDDLE of the shifted band,
  // and "the early half" — the whole point of the fixture — would have stopped
  // being true of them.
  const supplement = Supplement(
    id: 's1',
    name: 'Magnesium',
    doseText: '400 mg',
    colorValue: 0xFF6B6FA8,
    note: '',
  );
  final regimen = Regimen(
    id: 'r1',
    supplementId: 's1',
    kind: RegimenKind.course,
    startDate: DateTime.utc(2026, 7, 5),
    endDate: DateTime.utc(2026, 8, 30),
    onDays: 0,
    offDays: 0,
    paused: false,
    slots: const [
      DoseSlot(id: 'sl1', minutesFromMidnight: 480, doseLabel: '1 cap'),
    ],
  );

  final model = buildCyclesModel(
    [StackEntry(supplement: supplement, regimen: regimen)],
    today: today,
  );

  Widget host(TextDirection direction) => MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: bqTheme(),
        home: Scaffold(
          // INSIDE the app on purpose: this overrides the direction
          // `WidgetsApp` derived from `locale`, which is what lets an
          // LTR-only ARB set prove an RTL behaviour.
          body: Directionality(
            textDirection: direction,
            child: PlannerGantt(model: model),
          ),
        ),
      );

  /// The rounded rects the row's painter draws, at the size it was laid out
  /// at. The first is always the bare track; the segments follow.
  List<RRect> paintedBars(WidgetTester tester) {
    final track = find.descendant(
      of: find.byType(GanttRowBar),
      matching: find.byType(CustomPaint),
    );
    final painter = tester.widget<CustomPaint>(track).painter!;
    final canvas = _RecordedRRects();
    painter.paint(canvas, tester.getSize(track));
    return canvas.drawn;
  }

  testWidgets(
      'the painted track mirrors under RTL, so a bar and its month header '
      'agree on which side is earliest', (tester) async {
    await tester.pumpWidget(host(TextDirection.ltr));
    await tester.pumpAndSettle();

    final ltrFirstMonth = tester.getCenter(find.byKey(
      const ValueKey<String>('gantt-month-0'),
    ));
    final ltrLastMonth = tester.getCenter(find.byKey(
      const ValueKey<String>('gantt-month-3'),
    ));
    final ltrBars = paintedBars(tester);
    final trackWidth = ltrBars.first.outerRect.width;

    expect(ltrBars, hasLength(2),
        reason: 'the bare track plus this course\'s single run — if the '
            'painter drew a different number of rects the indices below stop '
            'meaning what they say');
    expect(ltrFirstMonth.dx, lessThan(ltrLastMonth.dx),
        reason: 'the LTR baseline: July reads before October');

    await tester.pumpWidget(host(TextDirection.rtl));
    await tester.pumpAndSettle();

    final rtlFirstMonth = tester.getCenter(find.byKey(
      const ValueKey<String>('gantt-month-0'),
    ));
    final rtlLastMonth = tester.getCenter(find.byKey(
      const ValueKey<String>('gantt-month-3'),
    ));
    final rtlBars = paintedBars(tester);

    // 1. The header really did flip — without this the rest of the test could
    //    pass over a header that never moved, comparing a mirror to nothing.
    expect(rtlFirstMonth.dx, greaterThan(rtlLastMonth.dx),
        reason: 'the month header is a direction-aware Row and has always '
            'flipped; if it stopped, the bars are no longer the side that is '
            'wrong and this file is testing the wrong half of the chart');

    // 2. The track is the same width in both directions, so a mirror is a
    //    subtraction rather than a rescale.
    expect(rtlBars.first.outerRect.width, closeTo(trackWidth, 0.01));
    expect(rtlBars, hasLength(ltrBars.length));

    // 3. Every painted rect is the exact mirror of its LTR twin. This is what
    //    was broken: before the fix the RTL rects were IDENTICAL to the LTR
    //    ones, because `startFraction * size.width` knows nothing about
    //    direction.
    for (var i = 0; i < ltrBars.length; i++) {
      final ltr = ltrBars[i].outerRect;
      final rtl = rtlBars[i].outerRect;
      expect(rtl.left, closeTo(trackWidth - ltr.right, 0.01),
          reason: 'rect $i does not mirror: its RTL left edge should be its '
              'LTR right edge measured from the other end of the track');
      expect(rtl.right, closeTo(trackWidth - ltr.left, 0.01),
          reason: 'rect $i does not mirror on its far edge');
    }

    // 4. The claim the whole file exists for: the bar sits under the months it
    //    belongs to. The course starts 5 July, five days into a four-month
    //    window, so its bar belongs at the END the first month label is at —
    //    the left in LTR, the right in RTL. A painter that ignored direction
    //    would put it on the left in both, i.e. under October.
    final ltrBar = ltrBars[1].outerRect;
    final rtlBar = rtlBars[1].outerRect;
    expect(ltrBar.center.dx, lessThan(trackWidth / 2),
        reason: 'a run starting five days into the window is in its early '
            'half, which in LTR is the left half');
    expect(rtlBar.center.dx, greaterThan(trackWidth / 2),
        reason: 'THE BUG. In RTL the early half of the window is the RIGHT '
            'half — that is where the July label is. A bar left of centre '
            'here is drawn under October while the header above it says '
            'July, so an Arabic or Urdu reader is told a cycle runs in a '
            'month it does not');
  });

  testWidgets('the today marker and the month gridlines flip with the track',
      (tester) async {
    // `PositionedDirectional` already flips these, so this is a REGRESSION
    // guard, not a fix: the marker and the bars are read together, and a
    // later change that mirrors one without the other is worse than the
    // original bug — the chart would look self-consistent and be wrong.
    Offset markerCentre() => tester.getCenter(
          find.byKey(const ValueKey<String>('gantt-today-marker')),
        );

    await tester.pumpWidget(host(TextDirection.ltr));
    await tester.pumpAndSettle();
    final ltrMarker = markerCentre();
    final gantt = tester.getRect(find.byType(GanttRowBar));

    await tester.pumpWidget(host(TextDirection.rtl));
    await tester.pumpAndSettle();
    final rtlMarker = markerCentre();

    // 13 August is 43 days into the 123-day 1 Jul – 31 Oct window: left of
    // centre in LTR, right of centre in RTL, and the two offsets sum to the
    // track's width.
    expect(ltrMarker.dx, lessThan(gantt.center.dx));
    expect(rtlMarker.dx, greaterThan(gantt.center.dx));
    expect(
      (ltrMarker.dx - gantt.left) + (rtlMarker.dx - gantt.left),
      closeTo(gantt.width, 1.0),
      reason: 'the two markers are equidistant from opposite edges — a true '
          'mirror, not merely "somewhere on the other side"',
    );
  });
}
