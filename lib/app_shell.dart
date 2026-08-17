import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:boostque/core/l10n/l10n.dart';
import 'package:boostque/core/selected_tab_controller.dart';
import 'package:boostque/core/widgets/bq_add_fab.dart';
import 'package:boostque/core/widgets/bq_nav_bar.dart';
import 'package:boostque/features/calendar/planner_screen.dart';
import 'package:boostque/features/calendar/today_screen.dart';
import 'package:boostque/features/stack/stack_screen.dart';

/// Three-tab app shell (NAV-02, UI-SPEC S9): [IndexedStack] over the Стек /
/// Сьогодні / Календар screens with the hand-built [BqNavBar].
///
/// Settings is deliberately NOT a destination — it is a route pushed by the
/// gear that every one of these three screens carries (NAV-03, D-3), so the bar
/// holds only the three places the user actually lives in.
///
/// All of the bar's chrome, styling and — critically — its text-scale-aware
/// height now live in `bq_nav_bar.dart`, which documents why the SDK bar was
/// replaced (NAV-01, D-1). This widget owns only the index-to-screen mapping;
/// the index itself moved to `core/selected_tab_controller.dart` in plan 07-03
/// and the reason is worth stating, because "why is this in Riverpod when only
/// the shell uses it?" is a question a future reader will otherwise answer
/// wrongly and revert: a DELIVERED NOTIFICATION has to be able to select a
/// destination, and widget state is unreachable from outside the widget.
class AppShell extends ConsumerWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final selectedIndex = ref.watch(selectedTabProvider);
    return Scaffold(
      // [IndexedStack] builds and KEEPS every child mounted — only painting is
      // suppressed — so all three screens are alive from app launch on every
      // tab. [TickerMode] is how an offstage screen learns it is offstage
      // (WR-05): the Сьогодні tab reads it to stop watching the minute ticker
      // and to stop warming the visible week while nobody is looking at it,
      // which is what its autoDispose providers were documented to do and,
      // under a bare IndexedStack, never did.
      //
      // Keeping every child mounted is also what makes deep state survive a
      // tab switch BY CONSTRUCTION (Interaction Contract 6): the planner's
      // segment, week and month selections and the browsed day are all held by
      // autoDispose providers that, under the deleted page swap, died every
      // time the user returned to Today.
      body: IndexedStack(
        index: selectedIndex,
        children: [
          for (final (index, screen) in const <Widget>[
            StackScreen(),
            TodayScreen(),
            PlannerScreen(),
          ].indexed)
            TickerMode(enabled: index == selectedIndex, child: screen),
        ],
      ),
      // The app's single add affordance, mounted ONCE (UX-01, plan 06-04).
      // Because it lives on the ROOT Scaffold, "present on exactly the three
      // tabs and nowhere else" is structurally true: Settings is a pushed
      // route with its own Scaffold and cannot inherit this one's FAB, and no
      // per-screen `showFab` flag exists to get wrong.
      //
      // Position and nav-bar clearance are left to the Scaffold's default
      // end-float location on purpose. The Scaffold measures the REAL
      // bottomNavigationBar below, whose extent is `navBarHeightFor(scaler)`,
      // so the gap rises with the bar at every text scale for free. A
      // hand-written offset here would reproduce the exact defect class this
      // phase removes.
      floatingActionButton: const BqAddFab(),
      bottomNavigationBar: BqNavBar(
        selectedIndex: selectedIndex,
        // The bar is one of exactly two writers of the destination; the other
        // is the tapped-reminder handler. Both go through the same notifier,
        // which ignores a write of the index it already holds — so a press on
        // the selected destination stays the no-op the accessibility contract
        // requires (WR-02).
        onSelected: (index) =>
            ref.read(selectedTabProvider.notifier).select(index),
        destinations: [
          BqNavDestination(
            icon: Icons.inventory_2_outlined,
            selectedIcon: Icons.inventory_2,
            label: l10n.tabStack,
          ),
          BqNavDestination(
            // A calendar page with ONE marked day, against Календар's full
            // month grid below: the semantic split between the two tabs is
            // single day vs. span, which is exactly what they hold (D-2). The
            // localized labels remain the primary distinguisher; the glyphs
            // only have to stop being near-identical, which v1's
            // `calendar_today` pair made them.
            icon: Icons.today_outlined,
            selectedIcon: Icons.today,
            label: l10n.tabToday,
          ),
          BqNavDestination(
            icon: Icons.calendar_month_outlined,
            selectedIcon: Icons.calendar_month,
            label: l10n.tabCalendar,
          ),
        ],
      ),
    );
  }
}
