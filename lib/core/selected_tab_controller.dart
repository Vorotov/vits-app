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

import 'package:boostque/core/notifications/notification_constants.dart';

/// Index of the Стек destination — the destination the app opens on when
/// nothing gives it a reason to open on another.
///
/// The shell's index-to-screen mapping is POSITIONAL (0 Стек / 1 Сьогодні /
/// 2 Календар), so this is a claim about which screen the user first reads.
const stackTabIndex = 0;

/// The payload of the notification that LAUNCHED the app, when one did.
///
/// `null` — "the app was not launched from a tap" — everywhere except `main()`,
/// which resolves the real answer before `runApp` and installs it as an
/// override (DECIDED-12). A plain `Provider` rather than a notifier because it
/// is answered once per process and never changes.
///
/// The value is UNTRUSTED: the operating system persists it across app updates
/// and can replay one an older build wrote. It is stored raw here and validated
/// where it is used, by the one predicate the warm path uses too.
final launchNotificationPayloadProvider = Provider<String?>((ref) => null);

/// The destination the app OPENS on.
///
/// Derived from the launch payload through [isKnownNotificationPayload] — the
/// SAME whitelist and the SAME destination index the warm tap handler applies,
/// so the cold path and the warm path cannot come to disagree about what a
/// valid payload is. An unknown string, a stale one and a null all resolve to
/// [stackTabIndex], with nothing surfaced to the user (DECIDED-13).
///
/// The dependency is on `notification_constants.dart`, which imports nothing at
/// all — this file reaches a pure value, not the notification machinery.
final initialTabIndexProvider = Provider<int>(
  (ref) =>
      isKnownNotificationPayload(ref.watch(launchNotificationPayloadProvider))
          ? todayTabIndex
          : stackTabIndex,
);

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
