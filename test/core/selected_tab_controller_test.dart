/// The shell's selected destination, as app-lifetime state (plan 07-03,
/// NOTIF-01).
///
/// The destination index used to be a field on `_AppShellState`, which meant
/// nothing outside the widget could change it — and a tapped reminder is
/// exactly something outside the widget. These are the notifier's own
/// contracts, asserted against a bare container so they hold with no tree,
/// no plugin and no notification layer present at all.
library;

import 'package:boostque/core/selected_tab_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a bare container opens on the Стек destination', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(
      container.read(selectedTabProvider),
      0,
      reason: 'the literal, not the constant compared to itself: the shell maps '
          'index to screen POSITIONALLY (0 Стек / 1 Сьогодні / 2 Календар), so '
          'the default is a claim about which screen the app opens on',
    );
  });

  test('selecting a destination moves the tab; selecting the selected one '
      'notifies nobody', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    // Listened, not merely read: an unlistened provider is paused in Riverpod 3,
    // and the notification COUNT is half of what this test claims.
    final seen = <int>[];
    container.listen(selectedTabProvider, (_, next) => seen.add(next));

    container.read(selectedTabProvider.notifier).select(1);
    container.read(selectedTabProvider.notifier).select(1);

    expect(container.read(selectedTabProvider), 1);
    expect(
      seen,
      <int>[1],
      reason: 'the bar calls onSelected for EVERY press including a press on '
          'the already-selected destination, and the accessibility contract in '
          'app_shell_test.dart requires re-activating it to be a harmless '
          'no-op. Idempotence in the notifier is what keeps that true after '
          'the lift',
    );
  });

  test('the initial value comes from the seed provider', () {
    final container = ProviderContainer(
      overrides: [initialTabIndexProvider.overrideWithValue(2)],
    );
    addTearDown(container.dispose);

    expect(container.read(selectedTabProvider), 2);
  });

  test('the seed is a launch answer, not a subscription — re-resolving it later '
      'does not yank the tab', () {
    var seed = 1;
    final container = ProviderContainer(
      overrides: [initialTabIndexProvider.overrideWith((ref) => seed)],
    );
    addTearDown(container.dispose);
    container.listen(selectedTabProvider, (_, _) {});

    expect(container.read(selectedTabProvider), 1);
    container.read(selectedTabProvider.notifier).select(0);
    seed = 2;
    container.invalidate(initialTabIndexProvider);

    expect(
      container.read(selectedTabProvider),
      0,
      reason: 'build() READS the seed once. Had it watched, re-resolving the '
          'seed would rebuild the notifier and move the user off the tab they '
          'are looking at — a launch answer arriving mid-session',
    );
  });

  test('two independently scoped containers do not share a selected tab', () {
    final first = ProviderContainer();
    final second = ProviderContainer();
    addTearDown(first.dispose);
    addTearDown(second.dispose);

    first.read(selectedTabProvider.notifier).select(2);

    expect(first.read(selectedTabProvider), 2);
    expect(
      second.read(selectedTabProvider),
      0,
      reason: 'app-lifetime means the lifetime of ONE container. The shell '
          'render matrix pumps a fresh scope per cell and every cell asserts '
          'the Стек heading, so a shared value would leak the previous cell\'s '
          'tab into the next one',
    );
  });
}
