/// Планувальник — the planner page (plans 04-01/04-02, UI-SPEC S6 / S6a /
/// S6b / S6c).
///
/// Structure, and who owns each region:
/// - fixed header (this file): the settings gear row, the title, the
///   segment-dependent subtitle and the Рік/Цикли `BqSegmented`.
/// - scroll body: two seams. `_CyclesBody` holds the gantt card today; plan
///   04-03 inserts the summary chip, load chart and week detail above it.
///   `_YearBody` holds its closing copy today; plan 04-04 inserts the peak
///   chip, year grid, legend and month detail into it.
///
/// The clock is never read in this file: `todayProvider` is the app's single
/// clock source and the models arrive already resolved through
/// `cyclesModelProvider` / `yearModelProvider`.
///
/// **Navigation-agnostic by design.** This screen does not know how it was
/// reached — no route, no page-index, no callback into a host. It is the
/// Календар destination of the app shell's `IndexedStack` (plan 06-03), which
/// replaced the DECIDED-1 page swap that used to render it inside the Calendar
/// tab; nothing in this file changed when that happened, and nothing here
/// would change if the shell changed again.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:boostque/core/domain/cycle_math.dart';
import 'package:boostque/core/l10n/l10n.dart';
import 'package:boostque/core/providers.dart';
import 'package:boostque/core/theme/tokens.dart';
import 'package:boostque/core/today_controller.dart';
import 'package:boostque/core/widgets/bq_segmented.dart';
import 'package:boostque/core/widgets/bq_settings_gear_row.dart';
import 'package:boostque/features/calendar/planner_gantt.dart';
import 'package:boostque/features/calendar/planner_load_chart.dart';
import 'package:boostque/features/calendar/planner_month_detail.dart';
import 'package:boostque/features/calendar/planner_providers.dart';
import 'package:boostque/features/calendar/planner_view_model.dart';
import 'package:boostque/features/calendar/planner_week_detail.dart';
import 'package:boostque/features/calendar/planner_year_grid.dart';

/// Screen horizontal padding — the same edge the Calendar screen runs down
/// (mockup lines 286, 294).
const double _screenPadding = 20;

/// Vertical gap between two Цикли cards (mockup lines 333, 352). Рік uses 14;
/// the two are mockup-exact per segment and deliberately not unified.
const double _cyclesCardGap = 12;
const double _yearCardGap = 14;

/// Year legend geometry (mockup lines 430-436).
const double _legendTopMargin = 14;
const double _legendInset = 2;
const double _legendRowGap = 10;
const double _legendColumnGap = 14;
const double _swatchHalfWidth = 9;
const double _swatchHeight = 7;
const double _swatchRadius = 4;
const double _swatchLabelGap = 6;
const double _legendLabelSize = 11.5;

/// The alpha the legend's light half carries — the same `4D` the planned
/// coverage bars use, which is the whole point of a two-tone swatch.
const double _plannedAlpha = 0.30;

/// Summary-chip geometry (mockup line 295).
const double _chipPadVertical = 12;
const double _chipPadHorizontal = 14;
const double _chipInnerGap = 9;
const double _chipBottomMargin = 16;

/// Segment indices, in the order the control renders them (mockup lines
/// 290-291). Цикли is index 1 and the default: its ~4-month window contains
/// today and answers PLAN-01, while Рік is the zoom-out.
const int _segYear = 0;
const int _segCycles = 1;

/// The planner screen — the shell's Календар destination (plan 06-03, NAV-02).
class PlannerScreen extends ConsumerWidget {
  const PlannerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final segment = ref.watch(plannerSegmentProvider);

    // Both selections belong to the SCREEN, for its whole lifetime — not to
    // the body that happens to be rendering one of them (Interaction Contract
    // 2). Switching segments unmounts a body, and these providers are
    // autoDispose per D-23: without a listener held HERE, the last widget
    // watching the selection goes away with the body and the user's pick is
    // silently reset on the way back. `listen` rather than `watch` on purpose
    // — the screen keeps them alive without rebuilding on every selection.
    ref.listen(selectedWeekProvider, (_, _) {});
    ref.listen(selectedMonthProvider, (_, _) {});

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _Header(),
            Expanded(
              child: segment == _segCycles
                  ? const _CyclesBody()
                  : const _YearBody(),
            ),
          ],
        ),
      ),
    );
  }
}

/// Fixed header, outside the scroll: the settings gear row, title,
/// segment-dependent subtitle, segmented control.
///
/// The `‹ Сьогодні` back control this doc used to announce was deleted with
/// the page swap (deletion inventory A) — the planner is a nav-bar destination
/// now, so there is nothing to go back TO. The gear row lands in exactly the
/// slot that control vacated, mirrored to the end side (06-UI-SPEC S11).
class _Header extends ConsumerWidget {
  const _Header();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final segment = ref.watch(plannerSegmentProvider);

    return Padding(
      padding: const EdgeInsetsDirectional.only(
        start: _screenPadding,
        end: _screenPadding,
        top: 6, // mockup line 286
        bottom: 14, // mockup line 286 — the header sits outside the scroll
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // The gear gets its OWN end-aligned row ABOVE the title, identical on
          // all three screens the nav bar reaches (UI-SPEC S11 / D-5). The row
          // holds NO text, so its extent is pure geometry and it cannot
          // overflow at any text scale, in any locale, in any direction.
          //
          // Do NOT "tidy" it into the row below, or into the title. The
          // rejected alternative — a bounded trailing group sharing a row with
          // the start-side control — is probably safe, but it makes the
          // header's overflow safety depend on a reader correctly re-deriving
          // "these children are not text" on every future edit, and the control
          // it would share a row with carries a LABEL. The dedicated row makes
          // it depend on nothing.
          const BqSettingsGearRow(),
          Text(
            l10n.plannerTitle,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 4), // mockup line 288
          Text(
            _subtitle(context, ref, segment: segment),
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: BqColors.textMuted),
          ),
          const SizedBox(height: 14), // mockup line 289
          BqSegmented(
            labels: [l10n.plannerSegYear, l10n.plannerSegCycles],
            selectedIndex: segment,
            onChanged: (index) =>
                ref.read(plannerSegmentProvider.notifier).select(index),
          ),
        ],
      ),
    );
  }

  /// The window (Цикли) or the year (Рік), named in the active locale.
  ///
  /// Derived from the clock alone, so it renders while the stack is still
  /// loading and while it is failing — the header never depends on data it
  /// does not need (S6c).
  ///
  /// Month names come from `intl` with the STANDALONE pattern letters: they
  /// stand here without a day number, which in Ukrainian means the nominative
  /// case ("серпень"), not the genitive one the format letters would give
  /// ("серпня"). See `test/l10n/month_names_test.dart`, which pins both the
  /// case rule and the reason a bare format pattern deceptively looks right
  /// (PF-4, L10N-04).
  String _subtitle(
    BuildContext context,
    WidgetRef ref, {
    required int segment,
  }) {
    final l10n = context.l10n;
    // The locale ALWAYS comes from the widget tree, never a literal tag: a
    // hardcoded 'uk' would silently ignore the user's language override.
    final locale = Localizations.localeOf(context).toString();
    final today = ref.watch(todayProvider);
    final year = DateFormat('y', locale);

    if (segment == _segYear) {
      // Always January-December of today's year, so the count is structural
      // rather than a magic literal (DECIDED-9).
      return l10n.plannerYearSubtitle(
        year.format(today),
        l10n.monthsCount(DateTime.monthsPerYear),
      );
    }

    final window = plannerWindow(today);
    final lastMonth = addMonths(window.start, 3);
    final month = DateFormat('LLLL', locale);

    if (lastMonth.year != window.start.year) {
      return l10n.plannerRangeSubtitleCrossYear(
        month.format(window.start),
        year.format(window.start),
        month.format(lastMonth),
        year.format(lastMonth),
      );
    }
    return l10n.plannerRangeSubtitle(
      month.format(window.start),
      month.format(lastMonth),
      year.format(window.start),
    );
  }
}

/// Цикли scroll body: the summary chip, the gantt, the load chart and the
/// week detail, closed by the disclaimer.
class _CyclesBody extends ConsumerWidget {
  const _CyclesBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _BodyScroll(
      children: _surface(
        context,
        ref,
        // Riverpod 3: pattern-match the AsyncValue; there is no null accessor.
        model: ref.watch(cyclesModelProvider),
        // Rows already exclude entries with no regimen (DECIDED-7), so an
        // empty row list IS the empty state: no stack at all, or no schedule
        // anywhere in it.
        isEmpty: (model) => model.rows.isEmpty,
        cards: (model) => [
          _CyclesSummaryChip(model: model),
          PlannerGantt(model: model),
          const SizedBox(height: _cyclesCardGap),
          // The chart's scale comes from the model, through here — the widget
          // holds no denominator of its own (plan 06-05). `scheduledCount`
          // equals `rows.length`, so the `isEmpty` gate above is exactly the
          // guarantee that the chart is never built with a zero ceiling.
          PlannerLoadChart(
            model: model,
            scheduledCount: model.scheduledCount,
          ),
          const SizedBox(height: _cyclesCardGap),
          // Inline, directly under the chart it is read against — never a
          // sheet, never a dialog (P-13).
          PlannerWeekDetail(model: model),
        ],
      ),
    );
  }
}

/// The Цикли summary chip: how many supplements overlap this week.
///
/// A plain count on a neutral chip — it is compared against nothing, and the
/// badge that used to name a limit beside it is deleted (06-UI-SPEC S13).
///
/// "This week" is the CALENDAR week containing today — which is exactly why
/// the buckets are full Monday weeks and not the mockup's window-aligned
/// sevens (DECIDED-3). It is deliberately NOT the selected week: the chip
/// summarises where the user is standing, not where they are looking.
class _CyclesSummaryChip extends StatelessWidget {
  const _CyclesSummaryChip({required this.model});

  final CyclesModel model;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    // "This week" is resolved ONCE, in the pure model — never re-derived here
    // beside the identical search the week-detail fallback runs. Two copies of
    // it can silently disagree, and a chip that quietly answers 0 because it
    // could not find today is worse than one that cannot happen (WR-02).
    final load = model.weeks[model.currentWeekIndex].load;

    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: _chipBottomMargin),
      child: Container(
        key: const ValueKey<String>('cycles-summary-chip'),
        padding: const EdgeInsetsDirectional.symmetric(
          vertical: _chipPadVertical,
          horizontal: _chipPadHorizontal,
        ),
        decoration: const BoxDecoration(
          color: BqColors.chip,
          borderRadius: BorderRadius.all(Radius.circular(BqRadii.button)),
        ),
        child: Row(
          children: [
            // A single flexible label: the limit badge that made this a
            // two-child row is deleted, and the colours are the app's neutral
            // chip pair (`stack_screen.dart:377-393`), at every load. There is
            // no threshold left for a colour to express (06-UI-SPEC S13).
            Expanded(
              child: Text(
                // The count is PRE-FORMATTED through its own plural key and
                // passed into the sentence (the cycleSummaryCyclic idiom).
                l10n.plannerThisWeek(l10n.substancesCount(load)),
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                  height: 1.35,
                  color: BqColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Рік scroll body: the peak chip, the grid, the legend and the month detail,
/// closed by the disclaimer alone.
///
/// The year footnote is deleted rather than neutralized (06-UI-SPEC S13): its
/// entire subject was the red month count and the limit it exceeded, and both
/// cease to exist in this phase. The Рік body now closes exactly as Цикли does.
class _YearBody extends ConsumerWidget {
  const _YearBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _BodyScroll(
      children: _surface(
        context,
        ref,
        model: ref.watch(yearModelProvider),
        // `entries` is already the regimen-bearing subset, the same filter
        // the gantt rows carry (DECIDED-7).
        isEmpty: (model) => model.entries.isEmpty,
        // Body order, exactly: peak chip, grid card, legend, month-detail
        // card — and then, from `_BodyScroll`, the closing disclaimer
        // (PLAN-04, unweakened by this phase).
        cards: (model) => [
          _YearPeakChip(model: model),
          PlannerYearGrid(model: model),
          _YearLegend(model: model),
          const SizedBox(height: _yearCardGap),
          // Inline, directly under the grid it is read against — never a
          // sheet, never a dialog (P-13).
          PlannerMonthDetail(model: model),
        ],
      ),
    );
  }
}

/// The Рік peak chip: which month of the year is densest, and how many
/// supplements overlap there.
///
/// A plain count on the app's neutral chip — the same treatment as the Цикли
/// summary chip, in both geometry AND colour, because there is no longer a
/// limit for the two to be asymmetric about (06-UI-SPEC S13). The DECIDED-6
/// asymmetry this doc used to announce is moot rather than reconciled; see the
/// decoration comment in [build].
class _YearPeakChip extends StatelessWidget {
  const _YearPeakChip({required this.model});

  final YearModel model;

  @override
  Widget build(BuildContext context) {
    // A year with no coverage at all has no peak to name (WR-04). Rendering
    // nothing is the same answer UI-SPEC S6c gives on the empty surface —
    // the chip is omitted because there is nothing to summarize — and it is
    // the only honest one: the alternative reads "the densest months,
    // including August — 0 substances".
    if (model.peakIndex < 0) return const SizedBox.shrink();

    final l10n = context.l10n;
    // The locale ALWAYS comes from the widget tree, never a literal tag.
    final locale = Localizations.localeOf(context).toString();
    final peak = model.months[model.peakIndex];
    final load = peak.load;

    // A STANDALONE full month name: it stands here without a day number,
    // which in Ukrainian means the nominative case (PF-4).
    final month = DateFormat('LLLL', locale).format(peak.month);

    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: _chipBottomMargin),
      child: Container(
        key: const ValueKey<String>('year-peak-chip'),
        padding: const EdgeInsetsDirectional.symmetric(
          vertical: _chipPadVertical,
          horizontal: _chipPadHorizontal,
        ),
        // The neutral chip pair at EVERY load — same as the Цикли summary
        // chip, and no longer "the same geometry, a different comparison":
        // there is no comparison left for the two to disagree about, so the
        // DECIDED-6 asymmetry is moot rather than reconciled (06-UI-SPEC S13).
        decoration: const BoxDecoration(
          color: BqColors.chip,
          borderRadius: BorderRadius.all(Radius.circular(BqRadii.button)),
        ),
        child: Row(
          children: [
            // A flexible sentence against a rigid trailing count — never two
            // rigid children (WR-04).
            Expanded(
              child: Text(
                model.peakTied ? l10n.peakMonthsTie(month) : l10n.peakMonth(month),
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                  height: 1.35,
                  color: BqColors.textSecondary,
                ),
              ),
            ),
            const SizedBox(width: _chipInnerGap),
            Text(
              l10n.substancesCount(load),
              maxLines: 1,
              softWrap: false,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w400,
                color: BqColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One two-tone swatch and name per supplement, closing with the
/// lighter-means-planned hint.
///
/// A `Wrap`, never a `Row`: a stack of a dozen supplements at a large text
/// scale must flow onto more lines, not overflow (PF-7).
class _YearLegend extends StatelessWidget {
  const _YearLegend({required this.model});

  final YearModel model;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Padding(
      padding: const EdgeInsetsDirectional.only(
        top: _legendTopMargin,
        start: _legendInset,
        end: _legendInset,
      ),
      child: Wrap(
        key: const ValueKey<String>('year-legend'),
        spacing: _legendColumnGap,
        runSpacing: _legendRowGap,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          for (final entry in model.entries)
            // A paused supplement has zero coverage in every month, so every
            // one of its bars is zero-width and silent: this legend entry is
            // the ONLY place the Рік segment names it at all. Without the
            // clause, assistive tech hears a name with nothing behind it and
            // no reason why (WR-01) — the word is the legend's own, not new
            // copy.
            _LegendSemantics(
              paused: entry.regimen?.paused ?? false,
              name: entry.supplement.name,
              child: Row(
                key: ValueKey<String>(
                  'year-legend-entry-${entry.supplement.id}',
                ),
                mainAxisSize: MainAxisSize.min,
                children: [
                  _TwoToneSwatch(color: Color(entry.supplement.colorValue)),
                  const SizedBox(width: _swatchLabelGap),
                  // FLEXIBLE, never rigid. The `Wrap` bounds each entry at the
                  // full body width and no further: a single long uk name
                  // ("Омега-3 риб'ячий жир концентрат") is wider than that on
                  // its own, so a rigid `Text` here overflowed the entry row
                  // by tens of pixels at EVERY text scale — the WR-04 defect
                  // class, caught by the 04-05 text-scale matrix. Flexible
                  // lets the name soft-wrap inside its own entry instead.
                  Flexible(
                    child: Text(
                      // The domain model carries no short name, so the legend
                      // names the supplement the way every other surface does.
                      entry.supplement.name,
                      style: const TextStyle(
                        fontSize: _legendLabelSize,
                        fontWeight: FontWeight.w400,
                        color: BqColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Text(
            l10n.yearLegendHint,
            style: const TextStyle(
              fontSize: _legendLabelSize,
              fontWeight: FontWeight.w400,
              color: BqColors.textFaint,
            ),
          ),
        ],
      ),
    );
  }
}

/// Speaks a paused supplement's state on the Рік legend, and stays out of the
/// way otherwise.
///
/// An active entry keeps the tree it already had — its name is already read as
/// plain text and a wrapper would only add a node. A paused one gets a label
/// that names the state the grid can only paint (WR-01); `excludeSemantics`
/// stops the name being announced twice.
class _LegendSemantics extends StatelessWidget {
  const _LegendSemantics({
    required this.paused,
    required this.name,
    required this.child,
  });

  final bool paused;
  final String name;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!paused) return child;
    return Semantics(
      label: context.l10n.yearLegendEntrySemantics(
        name,
        // The legend's own word, never a second vocabulary for one state.
        context.l10n.legendPaused,
      ),
      excludeSemantics: true,
      child: child,
    );
  }
}

/// A supplement's colour beside its planned tint — the legend's whole claim,
/// drawn rather than described.
class _TwoToneSwatch extends StatelessWidget {
  const _TwoToneSwatch({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.all(Radius.circular(_swatchRadius)),
      child: SizedBox(
        width: _swatchHalfWidth * 2,
        height: _swatchHeight,
        child: Row(
          children: [
            Expanded(child: ColoredBox(color: color)),
            Expanded(
              child: ColoredBox(color: color.withValues(alpha: _plannedAlpha)),
            ),
          ],
        ),
      ),
    );
  }
}

/// The three async surfaces both segments share (S6c).
///
/// A model that CARRIES an error renders fixed copy plus retry, whether or not
/// it is also loading; data with something to draw renders [cards]; data with
/// nothing to draw renders the empty block; loading with no error renders
/// nothing at all — no spinner, because a local-DB stream resolves within a
/// frame and a spinner would only flash (Phase-3 precedent).
///
/// "Has an error" beats "is loading" deliberately, and the arm order below is
/// the whole of that rule — see the first arm (A1 / P-9).
List<Widget> _surface<T>(
  BuildContext context,
  WidgetRef ref, {
  required AsyncValue<T> model,
  required bool Function(T) isEmpty,
  required List<Widget> Function(T) cards,
}) {
  return switch (model) {
    // Riverpod 3 reports a failing provider as an AsyncLoading that CARRIES
    // the error while it retries on its own backoff, so matching the error
    // SUBTYPE alone leaves this arm unreached for the whole ~38.2s backoff
    // window and the screen renders the blank loading surface instead of the
    // designed one (04-REVIEW.md CR-02). Match on the property, not the type.
    AsyncValue(hasError: true) => const [_PlannerError()],
    AsyncData(:final value) when isEmpty(value) => const [_EmptyPlanner()],
    AsyncData(:final value) => cards(value),
    _ => const <Widget>[],
  };
}

/// The shared scroll body: mockup-exact padding, and the same closing
/// disclaimer under every state.
class _BodyScroll extends StatelessWidget {
  const _BodyScroll({required this.children});

  /// Whatever the segment renders above its closing copy.
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsetsDirectional.only(
        start: _screenPadding,
        end: _screenPadding,
        bottom: 84, // clears the nav bar (Phase-2 rule, locked)
      ),
      children: [
        ...children,
        // Closes the body of BOTH segments, under EVERY state including the
        // empty and error ones — the requirement is unconditional, so the
        // widget is too (PLAN-04, DECIDED-8).
        _FaintNote(text: context.l10n.plannerDisclaimer),
      ],
    );
  }
}

/// The closing 11.5/1.5 `textFaint` line — the disclaimer, and nothing else
/// since the Year footnote above it was deleted (mockup line 374, 06-UI-SPEC
/// S13). Same shape as the Calendar screen's closing line, planner copy.
class _FaintNote extends StatelessWidget {
  const _FaintNote({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(
        top: BqSpace.md,
        start: BqSpace.xs,
        end: BqSpace.xs,
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w400,
          height: 1.5,
          color: BqColors.textFaint,
        ),
      ),
    );
  }
}

/// Empty planner (S6c): a title plus the body variant that matches the user's
/// actual situation.
///
/// A user who owns supplements is never told to go add one — the two variants
/// are the whole point of the block.
class _EmptyPlanner extends ConsumerWidget {
  const _EmptyPlanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final hasStack = switch (ref.watch(stackEntriesProvider)) {
      AsyncData(:final value) => value.isNotEmpty,
      // Until the stack resolves, assume it HAS entries: telling a user with a
      // full stack to go add a supplement would be actively misleading, and
      // this is the frame the empty block would flash in on the way to data.
      _ => true,
    };

    return Padding(
      padding: const EdgeInsetsDirectional.only(top: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l10n.emptyPlannerTitle,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              height: 1.3,
              color: BqColors.ink,
            ),
          ),
          const SizedBox(height: BqSpace.sm),
          Text(
            hasStack ? l10n.emptyPlannerBodyNoRegimen : l10n.emptyPlannerBody,
            style: const TextStyle(
              fontSize: 13,
              height: 1.5,
              color: BqColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

/// Error surface (S6c, T-04-09): the documented copy plus a retry that
/// re-subscribes. A raw exception or stack trace is NEVER placed in the tree.
class _PlannerError extends ConsumerWidget {
  const _PlannerError();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;

    return Padding(
      padding: const EdgeInsetsDirectional.only(top: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l10n.plannerLoadError,
            style: const TextStyle(
              fontSize: 13,
              height: 1.4,
              color: BqColors.textSecondary,
            ),
          ),
          const SizedBox(height: BqSpace.sm),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
              // The core graph's ONE named recovery path — the planner still
              // reaches `stackEntriesProvider` and `todayProvider` and nothing
              // else itself (Interaction Contract 6). Invalidating
              // `stackEntriesProvider` here instead would be a dead control:
              // it is a derivation with no subscription of its own, so
              // re-running it re-reads the same errored streams (CR-02).
              onPressed: () => retryStack(ref),
              child: Text(
                l10n.retry,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: BqColors.accent,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
