/// The app shell's selected destination, as app-lifetime state (plan 07-03,
/// NOTIF-01).
///
/// This is the ONE writer of the destination the shell renders: the bar's
/// callback and the tapped-reminder handler are its only two callers.
///
/// It lives in `core/` for the same reason the calendar clock does
/// (`core/today_controller.dart`): more than one layer consumes it — the shell
/// renders it and the notification layer's tap handler moves it — and `core`
/// must never import `features`. It is app-lifetime (NOT autoDispose) per the
/// D-23 dispose policy recorded once in `core/providers.dart`: it is one `int`
/// that has to survive for as long as the shell does, which is the session.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Index of the Стек destination — the destination the app opens on when
/// nothing gives it a reason to open on another.
///
/// The shell's index-to-screen mapping is POSITIONAL (0 Стек / 1 Сьогодні /
/// 2 Календар), so this is a claim about which screen the user first reads.
const stackTabIndex = 0;

/// The destination the app OPENS on.
///
/// A seam with a plain default, so nothing in this file has to know why a
/// launch might want another destination. `main()` overrides it; every test and
/// every bare container gets [stackTabIndex].
final initialTabIndexProvider = Provider<int>((ref) => stackTabIndex);

/// The selected destination index.
class SelectedTabController extends Notifier<int> {
  @override
  int build() {
    // READ, never watch. This is a LAUNCH ANSWER, not a subscription: watching
    // it would rebuild this notifier — and reset the destination — whenever the
    // seed re-resolved, yanking the tab out from under a user who is looking at
    // it. It is read exactly once, when the session's first reader arrives.
    return ref.read(initialTabIndexProvider);
  }

  /// Selects [index], ignoring a write of the value already held.
  ///
  /// The idempotence is not micro-optimization. The bar calls this for EVERY
  /// press, including a press on the already-selected destination, and the
  /// accessibility contract asserts that re-activating the selected destination
  /// is a harmless no-op (`app_shell_test.dart`, WR-02). Dropping the equal
  /// write here is what keeps that true now that the index is shared state
  /// rather than a `State` field.
  void select(int index) {
    if (index == state) return;
    state = index;
  }
}

/// The shell's selected destination — app-lifetime, NOT autoDispose (D-23).
final selectedTabProvider =
    NotifierProvider<SelectedTabController, int>(SelectedTabController.new);
