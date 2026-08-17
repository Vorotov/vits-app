/// Calendar tab — the Today screen's permanent frame (UI-SPEC S4), plus the
/// planner page swapped in over it (plan 04-01, DECIDED-1).
///
/// This file owns the whole page swap: `calendarPageProvider` decides which
/// page renders, the Today header's action `Wrap` opens the planner, and a
/// `PopScope` sends system back to Today. `PlannerScreen` itself is
/// navigation-agnostic, so moving to a nested `Navigator` later touches only
/// this file (UI-SPEC S4-amendment).
///
/// The Today page itself lives in `today_screen.dart` as [TodayScreen]; this
/// file only decides whether it or the planner is on screen.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:boostque/features/calendar/calendar_providers.dart';
import 'package:boostque/features/calendar/planner_screen.dart';
import 'package:boostque/features/calendar/today_screen.dart';

/// The Calendar tab: the Today page, or the planner page swapped in over it
/// (DECIDED-1).
///
/// A page SWAP, not a `Navigator.push`: the app shell is an `IndexedStack` and
/// a root-level push would cover the `NavigationBar` the mockup deliberately
/// keeps visible on both planner screens. System back returns to Today rather
/// than leaving the tab.
class CalendarScreen extends ConsumerWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(calendarPageProvider) == CalendarPage.planner) {
      return PopScope(
        // The pop is intercepted rather than allowed: there is no route to pop
        // here, so letting it through would leave the Calendar tab (or the
        // app) instead of returning to Today.
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          ref.read(calendarPageProvider.notifier).showToday();
        },
        child: const PlannerScreen(),
      );
    }
    return const TodayScreen();
  }
}
