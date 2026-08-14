import 'package:flutter/material.dart';

import 'package:boostque/core/l10n/l10n.dart';
import 'package:boostque/core/theme/tokens.dart';
import 'package:boostque/features/calendar/calendar_screen.dart';
import 'package:boostque/features/settings/settings_screen.dart';
import 'package:boostque/features/stack/stack_screen.dart';

/// Three-tab app shell (D-24): [IndexedStack] over the Stack / Calendar /
/// Settings screens with a Material 3 [NavigationBar].
///
/// Styling comes from `bqTheme()`'s `navigationBarTheme` (surfaceAlt
/// background, accent selected, textFaint unselected, 10px/w500 labels —
/// D-25); this widget adds only the mockup-exact chrome the theme cannot
/// express: the 1px hairline top border (flat, elevation 0 — no Material
/// shadow) and the pixel-exact paddings (top 10, horizontal 22) from the
/// UI-SPEC spacing overrides. Those pixel values are intentionally hardcoded
/// here and NOT tokens (UI-SPEC spacing exemption).
///
/// Accepted deviations (recorded in 01-06-SUMMARY.md): the mockup's 66px
/// destination-column width and 24px home-indicator strip cannot be imposed
/// on the NavigationBar's flex layout; SafeArea/NavigationBar handle the home
/// indicator on device.
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
      body: IndexedStack(
        index: _selectedIndex,
        children: const [
          StackScreen(),
          CalendarScreen(),
          SettingsScreen(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: BqColors.surfaceAlt,
          border: Border(
            top: BorderSide(color: BqColors.hairline, width: 1),
          ),
        ),
        // Mockup-exact pixel overrides (UI-SPEC) — hardcoded here only.
        padding: const EdgeInsetsDirectional.only(top: 10, start: 22, end: 22),
        child: NavigationBar(
          selectedIndex: _selectedIndex,
          onDestinationSelected: (index) {
            setState(() => _selectedIndex = index);
          },
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.inventory_2_outlined),
              selectedIcon: const Icon(Icons.inventory_2),
              label: l10n.tabStack,
            ),
            NavigationDestination(
              icon: const Icon(Icons.calendar_today_outlined),
              selectedIcon: const Icon(Icons.calendar_today),
              label: l10n.tabCalendar,
            ),
            NavigationDestination(
              icon: const Icon(Icons.settings_outlined),
              selectedIcon: const Icon(Icons.settings),
              label: l10n.tabSettings,
            ),
          ],
        ),
      ),
    );
  }
}
