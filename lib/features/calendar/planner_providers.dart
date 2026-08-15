/// Screen-scoped planner state (plan 04-01, D-23, PF-10).
///
/// autoDispose here is the screen-scoped half of the D-23 dispose policy
/// recorded once in `core/providers.dart`: this is planner state, not
/// app-lifetime state.
///
/// ## The planner is a READ-ONLY projection
///
/// This file reads `stackEntriesProvider` and `todayProvider` from the core
/// provider graph and NOTHING else — no `dayDosesProvider`, no
/// `dayDosesReadOnlyProvider`, no intake repository. Phase 3 already paid for
/// reading a calendar through the materializing path and had to introduce a
/// read-only variant as the fix (WR-06); at year scale even that variant is
/// wrong, because it would open hundreds of Drift subscriptions to answer a
/// question the regimen row already answers arithmetically. So no materializing
/// path is reachable from the planner at all, and a row-count regression test
/// holds that line (T-04-01).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:boostque/core/providers.dart';
import 'package:boostque/core/today_controller.dart';
import 'package:boostque/features/calendar/planner_view_model.dart';

/// The Цикли model: gantt rows over the current ~4-month window.
///
/// Derived and cached, invalidated for free — `stackEntriesProvider` re-emits
/// on any supplement/regimen add, edit, pause, resume or delete, and
/// `todayProvider` re-emits at local midnight.
///
/// **Riverpod's cache IS the memoization; there is no other** (PF-10). Calling
/// [buildCyclesModel] from a widget's `build` would re-run thousands of
/// `isActiveOn` checks on every frame the user scrolls.
final cyclesModelProvider =
    Provider.autoDispose<AsyncValue<CyclesModel>>((ref) {
  final today = ref.watch(todayProvider);
  return ref.watch(stackEntriesProvider).whenData(
        (entries) => buildCyclesModel(entries, today: today),
      );
});
