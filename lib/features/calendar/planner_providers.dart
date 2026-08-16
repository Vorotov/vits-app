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

/// The Рік model: twelve month columns of today's calendar year.
///
/// Same derived shape as [cyclesModelProvider], and the same memoization
/// argument applies with more force: this one scans a full year per regimen,
/// which is precisely the work a materializing implementation would have paid
/// for in database rows (PF-2).
final yearModelProvider = Provider.autoDispose<AsyncValue<YearModel>>((ref) {
  final today = ref.watch(todayProvider);
  return ref.watch(stackEntriesProvider).whenData(
        (entries) => buildYearModel(entries, today: today),
      );
});

/// Which planner segment is showing: 0 = Рік, 1 = Цикли.
///
/// Defaults to **Цикли**: its ~4-month window contains today and answers
/// PLAN-01, the phase's primary criterion; Рік is the zoom-out.
class PlannerSegmentController extends Notifier<int> {
  @override
  int build() => 1;

  /// Selects a segment by index.
  void select(int index) => state = index;
}

/// The planner's segmented control; autoDispose per D-23.
final plannerSegmentProvider =
    NotifierProvider.autoDispose<PlannerSegmentController, int>(
  PlannerSegmentController.new,
);

/// The week bucket the user picked, IDENTIFIED BY ITS MONDAY, or `null` to
/// follow today.
///
/// `null` means "follow today" rather than storing today's concrete bucket —
/// the `SelectedDayController` idiom. Sitting on the current week across
/// midnight (or across a year rollover) then re-resolves instead of stranding
/// the selection on a bucket that has drifted into the past.
///
/// The pick is a DATE, never a list index (WR-03). The bucket list is rebuilt
/// from `todayProvider`, so at a month rollover the whole window slides forward
/// and every index shifts by roughly four weeks: a stored `7` would keep
/// indexing legally and start describing a completely different week without
/// the user touching anything. A Monday still means the same seven days after
/// the window moves — and when it moves out of the window entirely, the
/// resolver says so by falling back to "follow today" instead of retargeting.
class SelectedWeekController extends Notifier<DateTime?> {
  @override
  DateTime? build() => null;

  /// Selects the bucket beginning on [monday] — `WeekBucket.start`, a
  /// date-only UTC value.
  void select(DateTime monday) => state = monday;

  /// Clears the selection back to "follow today".
  void followToday() => state = null;
}

/// The picked week bucket; autoDispose per D-23.
final selectedWeekProvider =
    NotifierProvider.autoDispose<SelectedWeekController, DateTime?>(
  SelectedWeekController.new,
);

/// The week bucket actually rendered: the explicit pick, or the bucket
/// containing today when following.
///
/// Resolved by LOOKUP, so the returned index always names the week the user
/// actually chose, and a pick the current model no longer contains degrades to
/// following today rather than to a neighbour it never picked (WR-03). The
/// index is therefore in range by construction, not by clamping.
final resolvedWeekIndexProvider = Provider.autoDispose<int>((ref) {
  final model = switch (ref.watch(cyclesModelProvider)) {
    AsyncData(:final value) => value,
    _ => null,
  };
  if (model == null || model.weeks.isEmpty) return 0;

  final selected = ref.watch(selectedWeekProvider);
  if (selected != null) {
    final index =
        model.weeks.indexWhere((w) => w.bucket.start == selected);
    if (index >= 0) return index;
  }

  // "Follow today" reads the model's own answer rather than re-running the
  // search the summary chip also used to run: one derivation, one truth
  // (WR-02).
  return model.currentWeekIndex;
});

/// The month card the user picked, IDENTIFIED BY ITS FIRST DAY, or `null` to
/// follow today's month.
///
/// A date rather than an index for the same reason the week selection is one
/// (WR-03): the year model is today's calendar year, so on 1 January a stored
/// `11` silently stops meaning the December the user tapped and starts meaning
/// December of the NEW year.
class SelectedMonthController extends Notifier<DateTime?> {
  @override
  DateTime? build() => null;

  /// Selects the month beginning on [monthStart] — `YearMonth.month`, a
  /// date-only UTC value.
  void select(DateTime monthStart) => state = monthStart;

  /// Clears the selection back to "follow today".
  void followToday() => state = null;
}

/// The picked month card; autoDispose per D-23.
final selectedMonthProvider =
    NotifierProvider.autoDispose<SelectedMonthController, DateTime?>(
  SelectedMonthController.new,
);

/// The month actually rendered: the explicit pick, or today's month when
/// following — resolved by lookup for the same reason
/// [resolvedWeekIndexProvider] is.
final resolvedMonthIndexProvider = Provider.autoDispose<int>((ref) {
  final model = switch (ref.watch(yearModelProvider)) {
    AsyncData(:final value) => value,
    _ => null,
  };
  final months = model?.months ?? const [];
  final last = months.isEmpty ? 11 : months.length - 1;

  final selected = ref.watch(selectedMonthProvider);
  if (selected != null) {
    final index = months.indexWhere((m) => m.month == selected);
    if (index >= 0) return index;
  }
  return (ref.watch(todayProvider).month - 1).clamp(0, last);
});
