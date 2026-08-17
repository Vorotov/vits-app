/// Screen-scoped calendar state (plan 03-01, P-3, D-23).
///
/// autoDispose here is the screen-scoped half of the D-23 dispose policy
/// recorded in `core/providers.dart`: this is Сьогодні-tab state, not
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
///
/// Note the shell keeps the Сьогодні screen mounted on every tab, so this
/// never actually disposes while the app is running (WR-05) — the browsed day
/// therefore survives a tab round trip, which is the behavior the user expects
/// anyway.
final selectedDayProvider =
    NotifierProvider.autoDispose<SelectedDayController, DateTime?>(
  SelectedDayController.new,
);

/// The day the Сьогодні tab currently renders: the explicit selection, or
/// today when following.
///
/// Every `dayDosesProvider` key in the app originates here (or, from plan
/// 03-03 on, from the week strip, which selects through
/// [SelectedDayController.select]) — so keys are `dateOnly()`-normalized by
/// construction.
final resolvedDayProvider = Provider.autoDispose<DateTime>(
  (ref) => ref.watch(selectedDayProvider) ?? ref.watch(todayProvider),
);

/// Minutes elapsed since LOCAL midnight, re-emitted once a minute (P-5).
///
/// This is the second and last sanctioned clock read in the app: the calendar
/// *date* still comes only from `core/today_controller.dart`, and this provider
/// deliberately produces a minute-of-day integer — never a date — so no code
/// path can derive "which day it is" from it.
///
/// Calendar-scoped, therefore autoDispose (D-23). autoDispose alone does NOT
/// make that true under the app shell: `IndexedStack` keeps the Сьогодні screen
/// mounted on every tab, so a provider watched unconditionally in `build` would
/// live from app launch forever (WR-05). What actually cancels the periodic
/// subscription is the screen's `TickerMode` gate — `_DayBody` stops watching
/// this provider while the tab is offstage, and autoDispose then tears the
/// timer down. Keep the two together: dropping the gate silently re-arms a
/// timer nobody is looking at. The first value is emitted immediately, so the
/// current-block header and the overdue treatment are correct on the first
/// frame that has data.
///
/// A block boundary can therefore be up to a minute late. That latency is
/// intentional: a per-second tick would rebuild the whole day list sixty times
/// more often to move one header's color, and nothing on this screen is
/// second-accurate.
final nowMinutesProvider = StreamProvider.autoDispose<int>((ref) async* {
  yield _minuteOfDay();
  yield* Stream<void>.periodic(const Duration(minutes: 1))
      .map((_) => _minuteOfDay());
});

/// Local wall-clock minute of day, 0..1439.
int _minuteOfDay() {
  final now = DateTime.now();
  return now.hour * 60 + now.minute;
}
