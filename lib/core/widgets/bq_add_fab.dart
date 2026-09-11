/// The app's single add-supplement affordance (UX-01, 06-UI-SPEC S10).
///
/// A thin, semantics-correct wrapper over the SDK [FloatingActionButton] —
/// this is the one SDK widget Phase 6 adds, and the first FAB in the app. The
/// v1 spec explicitly *rejected* a FAB (02-UI-SPEC D6) because the Stack
/// screen already carried a full-width «Додати добавку» button and two
/// affordances for one action on a 390pt screen is worse than either alone.
/// The approved v1.1 spec §4 reverses that by satisfying D6's stated reason
/// the other way round: the BUTTON is deleted, not the FAB.
///
/// Mounted ONCE, on `AppShell`'s root [Scaffold] (`app_shell.dart`). That is
/// what makes "exactly the three tabs and nowhere else" a structural fact
/// rather than a flag anyone can get wrong: Settings is a pushed route with
/// its own [Scaffold] and can never inherit this one's FAB, and no per-screen
/// `showFab` boolean exists. The clearance above the nav bar is *measured* by
/// the [Scaffold] from the real `bottomNavigationBar`, never written here — a
/// hand-written offset — a 16px gap above a 56dp bar, hardcoded — would
/// reproduce the exact clipping class this phase exists to remove (CR-01).
///
/// Colours live in `floatingActionButtonTheme` (`theme.dart`) and nowhere
/// else — this file carries [Icons.add] and not a single `BqColors`
/// reference (D-07).
library;

import 'package:flutter/material.dart';

import 'package:vitomy/core/l10n/l10n.dart';
import 'package:vitomy/features/stack/add_supplement_sheet.dart';

/// The floating «Додати добавку» control mounted on the shell's [Scaffold].
class BqAddFab extends StatefulWidget {
  const BqAddFab({super.key});

  @override
  State<BqAddFab> createState() => _BqAddFabState();
}

class _BqAddFabState extends State<BqAddFab> {
  /// Second-sheet guard (T-06-09).
  ///
  /// `showAddSupplementSheet` has no guard of its own — the sheet's `_busy`
  /// flag (`add_supplement_sheet.dart:70`) short-circuits its two ADD paths so
  /// a double tap cannot mint two supplements, which is a different claim. Two
  /// activations of THIS control would push two modal routes, and dismissing
  /// one would leave the user staring at an identical second one. So the guard
  /// belongs here, on the control that can be activated twice.
  ///
  /// Deliberately not `setState`: nothing about the FAB's appearance changes,
  /// and rebuilding mid-activation would only churn the semantics tree.
  bool _sheetOpen = false;

  void _open() {
    if (_sheetOpen) return;
    _sheetOpen = true;
    try {
      showAddSupplementSheet(context).whenComplete(() => _sheetOpen = false);
    } catch (_) {
      // The flag is raised BEFORE the call and is lowered only by the
      // `whenComplete` that same expression registers — so a synchronous
      // throw out of the opener skips the registration and latches the guard
      // FOREVER (WR-01). `showModalBottomSheet` throws exactly like that when
      // this context has no navigator, which happens during a route swap.
      //
      // A guard that can latch is worse than no guard at all: this FAB lives
      // on the shell's root Scaffold and is never disposed, so the app's ONLY
      // add affordance would be silently dead until relaunch, with no state
      // change a user or a test could observe. Reset on the failure edge and
      // rethrow — the failure itself is still a bug worth surfacing, it just
      // must not be a permanent one.
      _sheetOpen = false;
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      // The same key the deleted full-width button carried: the affordance
      // changed, the promise did not. The label is never painted — the glyph
      // is all a sighted user sees — so this node is the only thing that
      // tells a screen-reader user what the disc does.
      label: context.l10n.addSupplement,
      excludeSemantics: true,
      // The action lives on THIS node, not only on the button below it:
      // `excludeSemantics: true` drops every descendant action, so without
      // this the FAB announces itself as a button VoiceOver / TalkBack cannot
      // press, while passing every coordinate-tap test (WR-02). Both handlers
      // call the same opener.
      onTap: _open,
      child: FloatingActionButton(
        onPressed: _open,
        // The SDK's hover-label argument is deliberately left unset: the
        // semantics boundary above would drop it anyway, and this app paints
        // no such labels anywhere.
        child: const Icon(Icons.add),
      ),
    );
  }
}
