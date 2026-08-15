/// Планувальник — the planner page (plan 04-01, UI-SPEC S6 / S6a).
///
/// Structure, and who owns each region:
/// - fixed header (this plan): the `‹ Сьогодні` back control above the
///   `plannerTitle`. The range subtitle and the Рік/Цикли `BqSegmented` are
///   plan 04-02's and slot in below the title without moving anything here.
/// - scroll body (this plan): the gantt card. The summary chip, the load
///   chart, the week-detail card and the disclaimer are plans 04-02/04-03's;
///   the Рік segment is plan 04-04's.
///
/// The clock is never read in this file: the model arrives already resolved
/// through `cyclesModelProvider`, which folds the app's single clock source
/// `todayProvider` into a pure derivation.
///
/// **Navigation-agnostic by design.** This screen does not know how it was
/// reached — no route, no page-index, no callback into the Calendar tab. The
/// DECIDED-1 page swap lives entirely in `calendar_screen.dart` +
/// `calendar_providers.dart`, so replacing it with a nested `Navigator` later
/// touches neither this file nor the model.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:boostque/core/l10n/l10n.dart';
import 'package:boostque/core/theme/tokens.dart';
import 'package:boostque/features/calendar/calendar_providers.dart';
import 'package:boostque/features/calendar/planner_gantt.dart';
import 'package:boostque/features/calendar/planner_providers.dart';

/// Screen horizontal padding — the same edge the Calendar screen runs down
/// (mockup lines 286, 294).
const double _screenPadding = 20;

/// The planner page, rendered inside the Calendar tab (DECIDED-1).
class PlannerScreen extends ConsumerWidget {
  const PlannerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: const [
            _Header(),
            Expanded(child: _PlannerBody()),
          ],
        ),
      ),
    );
  }
}

/// Fixed header, outside the scroll: back control above the screen title.
class _Header extends ConsumerWidget {
  const _Header();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;

    return Padding(
      padding: const EdgeInsetsDirectional.only(
        start: _screenPadding,
        end: _screenPadding,
        top: 6, // mockup line 286
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
        ],
      ),
    );
  }
}

/// Scrolling body: the gantt card.
class _PlannerBody extends ConsumerWidget {
  const _PlannerBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Riverpod 3: pattern-match the AsyncValue; there is no `valueOrNull`.
    final model = switch (ref.watch(cyclesModelProvider)) {
      AsyncData(:final value) => value,
      // Loading renders an empty body and NO spinner — a local-DB stream
      // resolves within a frame (Phase-3 precedent). The error branch renders
      // nothing rather than raw exception text; its documented copy and retry
      // land with the ARB set in plan 04-02.
      _ => null,
    };

    return ListView(
      padding: const EdgeInsetsDirectional.only(
        start: _screenPadding,
        end: _screenPadding,
        top: 14, // mockup line 294
        bottom: 84, // clears the nav bar (Phase-2 rule, locked)
      ),
      children: [
        if (model != null) PlannerGantt(model: model),
      ],
    );
  }
}
