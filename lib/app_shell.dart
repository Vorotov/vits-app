import 'package:flutter/material.dart';

import 'package:boostque/core/l10n/l10n.dart';
import 'package:boostque/core/widgets/bq_nav_bar.dart';
import 'package:boostque/features/calendar/calendar_screen.dart';
import 'package:boostque/features/settings/settings_screen.dart';
import 'package:boostque/features/stack/stack_screen.dart';

/// Three-tab app shell (D-24): [IndexedStack] over the Stack / Calendar /
/// Settings screens with the hand-built [BqNavBar].
///
/// All of the bar's chrome, styling and — critically — its text-scale-aware
/// height now live in `bq_nav_bar.dart`, which documents why the SDK bar was
/// replaced (NAV-01, D-1). This widget owns only the selected index and the
/// index-to-screen mapping.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      // [IndexedStack] builds and KEEPS every child mounted — only painting is
      // suppressed — so all three screens are alive from app launch on every
      // tab. [TickerMode] is how an offstage screen learns it is offstage
      // (WR-05): the Calendar tab reads it to stop watching the minute ticker
      // and to stop warming the visible week while nobody is looking at it,
      // which is what its autoDispose providers were documented to do and,
      // under a bare IndexedStack, never did.
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          for (final (index, screen) in const <Widget>[
            StackScreen(),
            CalendarScreen(),
            SettingsScreen(),
          ].indexed)
            TickerMode(enabled: index == _selectedIndex, child: screen),
        ],
      ),
      bottomNavigationBar: BqNavBar(
        selectedIndex: _selectedIndex,
        onSelected: (index) {
          setState(() => _selectedIndex = index);
        },
        destinations: [
          BqNavDestination(
            icon: Icons.inventory_2_outlined,
            selectedIcon: Icons.inventory_2,
            label: l10n.tabStack,
          ),
          BqNavDestination(
            icon: Icons.calendar_today_outlined,
            selectedIcon: Icons.calendar_today,
            label: l10n.tabCalendar,
          ),
          BqNavDestination(
            icon: Icons.settings_outlined,
            selectedIcon: Icons.settings,
            label: l10n.tabSettings,
          ),
        ],
      ),
    );
  }
}
