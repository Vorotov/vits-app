/// Планувальник — the planner page (plans 04-01/04-02, UI-SPEC S6 / S6a /
/// S6b / S6c).
///
/// Structure, and who owns each region:
/// - fixed header (this file): the `‹ Сьогодні` back control, the title, the
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
/// reached — no route, no page-index, no callback into the Calendar tab. The
/// DECIDED-1 page swap lives entirely in `calendar_screen.dart` +
/// `calendar_providers.dart`, so replacing it with a nested `Navigator` later
/// touches neither this file nor the model.
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
import 'package:boostque/features/calendar/calendar_providers.dart';
import 'package:boostque/features/calendar/planner_gantt.dart';
import 'package:boostque/features/calendar/planner_providers.dart';

/// Screen horizontal padding — the same edge the Calendar screen runs down
/// (mockup lines 286, 294).
const double _screenPadding = 20;

/// Segment indices, in the order the control renders them (mockup lines
/// 290-291). Цикли is index 1 and the default: its ~4-month window contains
/// today and answers PLAN-01, while Рік is the zoom-out.
const int _segYear = 0;
const int _segCycles = 1;

/// The editorial comfort rule this product applies — never a medical
/// threshold. Named once here; every surface that mentions it reads this.
const int _editorialLimit = 5;

/// The planner page, rendered inside the Calendar tab (DECIDED-1).
class PlannerScreen extends ConsumerWidget {
  const PlannerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final segment = ref.watch(plannerSegmentProvider);

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

/// Fixed header, outside the scroll: back control, title, segment-dependent
/// subtitle, segmented control.
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
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
              onPressed: () =>
                  ref.read(calendarPageProvider.notifier).showToday(),
              // "‹" is a separator/navigation glyph, the sanctioned
              // string-literal exception — it is not translatable copy, and it
              // keeps this screen free of the icon font the Phase-3 contract
              // deliberately never introduced.
              child: Text(
                '‹ ${l10n.backToToday}',
                style: const TextStyle(fontSize: 13, color: BqColors.accent),
              ),
            ),
          ),
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

/// Цикли scroll body: the gantt card, closed by the disclaimer.
///
/// A seam — plan 04-03 inserts the summary chip, the load chart and the week
/// detail above the gantt without touching the async surfaces below.
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
        cards: (model) => [PlannerGantt(model: model)],
      ),
    );
  }
}

/// Рік scroll body: the year footnote above the disclaimer.
///
/// A seam — plan 04-04 inserts the peak chip, the year grid, the legend and
/// the month detail above the footnote.
class _YearBody extends ConsumerWidget {
  const _YearBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _BodyScroll(
      // Rendered ABOVE the closing disclaimer, never instead of it: the
      // mockup's Year footnote carries no editorial framing of the limit, and
      // PLAN-04 needs both (M9, DECIDED-8).
      footnote: context.l10n.yearFootnote(_editorialLimit),
      children: _surface(
        context,
        ref,
        model: ref.watch(yearModelProvider),
        // `entries` is already the regimen-bearing subset, the same filter
        // the gantt rows carry (DECIDED-7).
        isEmpty: (model) => model.entries.isEmpty,
        cards: (model) => const <Widget>[],
      ),
    );
  }
}

/// The three async surfaces both segments share (S6c).
///
/// Data with something to draw renders [cards]; data with nothing to draw
/// renders the empty block; an error renders fixed copy plus retry; loading
/// renders nothing at all — no spinner, because a local-DB stream resolves
/// within a frame and a spinner would only flash (Phase-3 precedent).
List<Widget> _surface<T>(
  BuildContext context,
  WidgetRef ref, {
  required AsyncValue<T> model,
  required bool Function(T) isEmpty,
  required List<Widget> Function(T) cards,
}) {
  return switch (model) {
    AsyncError() => const [_PlannerError()],
    AsyncData(:final value) when isEmpty(value) => const [_EmptyPlanner()],
    AsyncData(:final value) => cards(value),
    _ => const <Widget>[],
  };
}

/// The shared scroll body: mockup-exact padding, and the same closing
/// disclaimer under every state.
class _BodyScroll extends StatelessWidget {
  const _BodyScroll({required this.children, this.footnote});

  /// Whatever the segment renders above its closing copy.
  final List<Widget> children;

  /// Optional line rendered directly above the closing disclaimer.
  final String? footnote;

  @override
  Widget build(BuildContext context) {
    final note = footnote;

    return ListView(
      padding: const EdgeInsetsDirectional.only(
        start: _screenPadding,
        end: _screenPadding,
        bottom: 84, // clears the nav bar (Phase-2 rule, locked)
      ),
      children: [
        ...children,
        if (note != null) ...[
          _FaintNote(text: note),
          const SizedBox(height: 8), // mockup lines 454, 374
        ],
        // Closes the body of BOTH segments, under EVERY state including the
        // empty and error ones — the requirement is unconditional, so the
        // widget is too (PLAN-04, DECIDED-8).
        _FaintNote(text: context.l10n.plannerDisclaimer),
      ],
    );
  }
}

/// The closing 11.5/1.5 `textFaint` line — the disclaimer, and the Year
/// footnote that sits above it (mockup lines 374, 454). Same shape as the
/// Calendar screen's closing line, with the planner's own copy.
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
              // The ONLY provider the planner may reach for here: it reads
              // `stackEntriesProvider` and `todayProvider` and nothing else
              // from the core graph (Interaction Contract 6).
              onPressed: () => ref.invalidate(stackEntriesProvider),
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
