/// Screen-scoped calendar state (plan 03-01, P-3, D-23).
///
/// autoDispose here is the screen-scoped half of the D-23 dispose policy
/// recorded in `core/providers.dart`: this is Calendar-tab state, not
/// app-lifetime state (the clock itself lives in `core/today_controller.dart`).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:boostque/core/domain/cycle_math.dart';
import 'package:boostque/core/today_controller.dart';

/// The day the user is browsing, or `null` to follow today.
///
/// `null` means "follow today" rather than storing today's concrete date
/// (03-RESEARCH P-3): sitting on today across midnight then auto-advances
/// instead of silently stranding the user on yesterday, while an explicit
/// past-day selection intentionally stays put — the user chose it.
class SelectedDayController extends Notifier<DateTime?> {
  @override
  DateTime? build() => null;

  /// Browses [day] (normalized — every family key must be `dateOnly()`, PF-1).
  void select(DateTime day) => state = dateOnly(day);

  /// Clears the selection back to "follow today".
  void followToday() => state = null;
}

/// Calendar day selection; autoDispose per D-23 (screen-scoped state).
final selectedDayProvider =
    NotifierProvider.autoDispose<SelectedDayController, DateTime?>(
  SelectedDayController.new,
);

/// The day the Calendar tab currently renders: the explicit selection, or
/// today when following.
///
/// Every `dayDosesProvider` key in the app originates here (or, from plan
/// 03-03 on, from the week strip, which selects through
/// [SelectedDayController.select]) — so keys are `dateOnly()`-normalized by
/// construction.
final resolvedDayProvider = Provider.autoDispose<DateTime>(
  (ref) => ref.watch(selectedDayProvider) ?? ref.watch(todayProvider),
);
