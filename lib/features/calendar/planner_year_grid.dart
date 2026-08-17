/// The Рік coverage matrix — twelve month cards (plan 04-04, UI-SPEC S6b
/// item 2, P-10, P-11, DECIDED-5, DECIDED-9).
///
/// ## Why the card extent is computed and never constant
///
/// A month card's height depends on TWO user-controlled inputs: the number of
/// gantt-eligible supplements (one 4px bar plus a 3px gap each) and the
/// accessibility text scale (the mono header line). Phase 3 shipped this exact
/// defect class twice — CR-01 (a hardcoded strip height that produced seven
/// bottom overflows at scale 1.6 and 2.0) and WR-04 (a rigid row that
/// overflowed horizontally) — so [monthCardExtentFor] follows the
/// `stripHeightFor` idiom: a fixed part, plus the scaler applied to the text
/// part, plus the bar extent. A fixed child aspect ratio on the grid delegate
/// would reproduce CR-01 precisely, and is the thing this file exists to avoid.
///
/// The extent is never capped (DECIDED-5): a "+N more" affordance would hide
/// exactly the cycle overlap this screen exists to show.
///
/// ## Read-only, like the rest of the planner
///
/// Nothing here reaches the intake path, and no model is derived in `build()` —
/// the [YearModel] arrives already cached from `yearModelProvider` (PF-10).
library;

import 'dart:math' as math;

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

/// Grid card padding (mockup line 414).
const double _cardPadding = 14;

/// Grid geometry (mockup line 414 `repeat(4,1fr); gap:8px`).
const int _columns = 4;
const double _gridSpacing = 8;

/// Month-card geometry (mockup line 416).
const double _monthPadTop = 9;
const double _monthPadHorizontal = 8;
const double _monthPadBottom = 10;
const double _borderUnselected = 1;
const double _borderSelected = 1.6;

/// Month-card header (mockup lines 417-419). `.04em` of 10.5px is 0.42
/// logical pixels.
const double _labelCountGap = 4;
const double _headerSize = 10.5;
const double _labelTracking = 0.42;

/// Coverage bars (mockup lines 421-423).
const double _barsTopMargin = 9;
const double _barGap = 3;
const double _barHeight = 4;
const double _barRadius = 2;

/// The minimum painted width of a non-empty bar, as a fraction of the track
/// (mockup line 840 `Math.max(Math.round(c.frac * 100), 22)`).
///
/// This floor is what keeps two days of coverage in a 31-day month visible
/// instead of a hairline. Rounding it away is a data-hiding bug, not a
/// cosmetic simplification (T-04-17).
const double _minBarFraction = 0.22;

/// The alpha a bar carries when the month's WHOLE coverage is still planned
/// (mockup line 841 `r.color + '4D'`, i.e. 0x4D/0xFF).
const double _plannedAlpha = 0.30;

/// The part of a month card's extent that does NOT follow the text scale: the
/// 9px/10px paddings, the 9px margin above the bar column, the selected card's
/// 1.6px borders, plus the slack the mockup's own card carries at scale 1.0.
///
/// Constant on purpose — none of these grow with the reader's text size.
const double _monthCardFixedExtent = 32;

/// The text-bearing header line at scale 1.0: one mono 10.5 label/count row
/// with its line box.
///
/// This is the ONLY part [monthCardExtentFor] scales, for the same reason
/// `stripHeightFor` scales only its two text lines: scaling the paddings and
/// the 4px bars too would grow the grid far past the content it has to hold,
/// while scaling nothing at all clips the header — the CR-01 defect.
const double _monthCardHeaderTextExtent = 16;

/// The main-axis extent one month card needs, for [scaler] and [rowCount]
/// coverage bars.
///
/// Grid children need a resolved extent rather than a measured one, so this is
/// computed the way `week_strip.dart`'s `stripHeightFor` computes the strip's:
/// fixed part + scaled text part + content extent. [rowCount] is the number of
/// gantt-eligible supplements; zero is well defined and simply contributes no
/// bar extent.
double monthCardExtentFor(TextScaler scaler, int rowCount) =>
    _monthCardFixedExtent +
    scaler.scale(_monthCardHeaderTextExtent) +
    (rowCount <= 0
        ? 0.0
        : rowCount * _barHeight + (rowCount - 1) * _barGap);

/// The painted width of one coverage bar, as a fraction of its track.
///
/// Verbatim from the mockup (line 840): nothing at zero coverage, the whole
/// track at or above [fullMonthFraction], otherwise the coverage fraction
/// FLOORED at [_minBarFraction].
double _barWidthFactor(MonthCell cell) {
  if (cell.frac <= 0) return 0;
  if (cell.full) return 1;
  return math.max((cell.frac * 100).round() / 100, _minBarFraction);
}

/// The twelve-cell coverage matrix for today's calendar year.
class PlannerYearGrid extends ConsumerWidget {
  const PlannerYearGrid({super.key, required this.model});

  /// The derived Рік model — never built in `build()` (PF-10).
  final YearModel model;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The locale ALWAYS comes from the widget tree, never a literal tag.
    final locale = Localizations.localeOf(context).toString();
    // STANDALONE abbreviations: a month name standing without a day number is
    // nominative in Ukrainian ("СІЧ"), which the format letters would get
    // wrong (PF-4, L10N-04).
    final label = DateFormat('LLL', locale);
    final selected = ref.watch(resolvedMonthIndexProvider);

    return Container(
      key: const ValueKey<String>('year-grid-card'),
      padding: const EdgeInsetsDirectional.all(_cardPadding),
      decoration: BoxDecoration(
        color: BqColors.surface,
        border: Border.all(color: BqColors.cardBorder),
        borderRadius: const BorderRadius.all(Radius.circular(BqRadii.panel)),
      ),
      child: GridView.builder(
        padding: EdgeInsets.zero,
        // The grid lives INSIDE the page's own scroll view: it shrink-wraps to
        // its twelve cells and never scrolls itself.
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: model.months.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: _columns,
          mainAxisSpacing: _gridSpacing,
          crossAxisSpacing: _gridSpacing,
          mainAxisExtent: monthCardExtentFor(
            MediaQuery.textScalerOf(context),
            model.entries.length,
          ),
        ),
        itemBuilder: (context, index) => _MonthCard(
          index: index,
          month: model.months[index],
          entries: model.entries,
          // intl formats the name, `bqUpperCase` cases it: Dart's
          // `toUpperCase()` is locale-independent (WR-03).
          label: bqUpperCase(label.format(model.months[index].month), locale),
          locale: locale,
          selected: index == selected,
        ),
      ),
    );
  }
}

/// One month of the matrix: its header line above one track per supplement.
class _MonthCard extends ConsumerWidget {
  const _MonthCard({
    required this.index,
    required this.month,
    required this.entries,
    required this.label,
    required this.locale,
    required this.selected,
  });

  /// 0 = January.
  final int index;
  final YearMonth month;
  final List<StackEntry> entries;

  /// The uppercased standalone abbreviation, already localized.
  final String label;
  final String locale;
  final bool selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;

    // The month's first day, never the card's position: the grid is today's
    // calendar year, and on 1 January index 11 stops meaning the December the
    // user tapped (WR-03).
    void select() =>
        ref.read(selectedMonthProvider.notifier).select(month.month);

    return MergeSemantics(
      child: Semantics(
        button: true,
        selected: selected,
        label: l10n.monthCardSemantics(
          label,
          l10n.substancesCount(month.load),
        ),
        excludeSemantics: true,
        // The action lives on THIS node, not on the InkWell below it:
        // `excludeSemantics` drops every descendant action, so without this a
        // card would announce itself as a button that VoiceOver / TalkBack
        // could not activate (WR-02).
        onTap: select,
        child: Material(
          key: ValueKey<String>('month-card-$index'),
          // Fill and border are the ONLY things selection changes.
          color: selected ? BqColors.monthSelectedBg : BqColors.surfaceAlt,
          shape: RoundedRectangleBorder(
            side: BorderSide(
              color: selected ? BqColors.accent : BqColors.cardBorder,
              width: selected ? _borderSelected : _borderUnselected,
            ),
            // A month cell in a year matrix IS a calendar cell — the exact
            // semantic `dayCell` was minted for. No third 11px token.
            borderRadius:
                const BorderRadius.all(Radius.circular(BqRadii.dayCell)),
          ),
          child: InkWell(
            onTap: select,
            // The whole card is the tap target — a 4px bar must never define
            // it (Interaction Contract 8). `InkResponse` already hit-tests
            // OPAQUE over its full box (ink_well.dart:1418), which is exactly
            // the behavior the week strip spells out on its `GestureDetector`;
            // month cards comfortably exceed the 44pt guidance, so they need
            // no further mitigation.
            customBorder: const RoundedRectangleBorder(
              borderRadius:
                  BorderRadius.all(Radius.circular(BqRadii.dayCell)),
            ),
            child: Padding(
              padding: const EdgeInsetsDirectional.only(
                top: _monthPadTop,
                start: _monthPadHorizontal,
                end: _monthPadHorizontal,
                bottom: _monthPadBottom,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      // A flexible label against a rigid count — never two
                      // rigid children, which is how a header overflows
                      // (WR-04). A long localized abbreviation truncates
                      // rather than growing the card.
                      Flexible(
                        child: Text(
                          label,
                          key: ValueKey<String>('month-$index-label'),
                          maxLines: 1,
                          softWrap: false,
                          overflow: TextOverflow.ellipsis,
                          style: BqText.mono(
                            size: _headerSize,
                            weight: FontWeight.w600,
                            color: BqColors.ink,
                            letterSpacing: _labelTracking,
                          ),
                        ),
                      ),
                      const SizedBox(width: _labelCountGap),
                      Text(
                        NumberFormat.decimalPattern(locale).format(month.load),
                        key: ValueKey<String>('month-$index-count'),
                        maxLines: 1,
                        softWrap: false,
                        style: BqText.mono(
                          size: _headerSize,
                          weight: FontWeight.w500,
                          // `textFaint` at EVERY load: the count states how
                          // many supplements overlap in this month and says
                          // nothing about whether that is a lot (06-UI-SPEC
                          // S13). The footnote that used to explain a red
                          // number is deleted along with the red number.
                          color: BqColors.textFaint,
                          letterSpacing: 0,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: _barsTopMargin),
                  // A track per gantt-eligible supplement, in stack order,
                  // WHETHER OR NOT it covers this month — otherwise cards in
                  // the same row would not be the same height.
                  for (var j = 0; j < entries.length; j++) ...[
                    if (j > 0) const SizedBox(height: _barGap),
                    _CoverageBar(
                      monthIndex: index,
                      rowIndex: j,
                      entry: entries[j],
                      cell: month.cells[j],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One supplement's coverage of one month: a filled bar inside its track.
class _CoverageBar extends StatelessWidget {
  const _CoverageBar({
    required this.monthIndex,
    required this.rowIndex,
    required this.entry,
    required this.cell,
  });

  final int monthIndex;
  final int rowIndex;
  final StackEntry entry;
  final MonthCell cell;

  @override
  Widget build(BuildContext context) {
    // The supplement's OWN tag colour — the sanctioned data-not-literal colour
    // exception the Stack card already uses.
    final color = Color(entry.supplement.colorValue);

    return Container(
      key: ValueKey<String>('month-$monthIndex-track-$rowIndex'),
      height: _barHeight,
      decoration: const BoxDecoration(
        color: BqColors.yearBarTrack,
        borderRadius: BorderRadius.all(Radius.circular(_barRadius)),
      ),
      child: FractionallySizedBox(
        alignment: AlignmentDirectional.centerStart,
        widthFactor: _barWidthFactor(cell),
        heightFactor: 1,
        child: DecoratedBox(
          key: ValueKey<String>('month-$monthIndex-bar-$rowIndex'),
          decoration: BoxDecoration(
            // Lighter means planned — the legend under the grid says so.
            color: cell.planned
                ? color.withValues(alpha: _plannedAlpha)
                : color,
            borderRadius:
                const BorderRadius.all(Radius.circular(_barRadius)),
          ),
        ),
      ),
    );
  }
}
