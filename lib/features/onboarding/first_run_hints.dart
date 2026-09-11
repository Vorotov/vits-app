/// One-time contextual hints (v1.2, path A).
///
/// The research this replaces a card deck with: NN/g's 70-participant test
/// found that reading an intro tutorial left users rating the SAME tasks
/// harder (4.92 vs 5.49 of 7) with no gain in success or speed — a deck makes
/// a simple app feel complicated. Coach marks fired in sequence at session
/// start fail for the same reason: the explanation arrives before the user
/// has any need for it.
///
/// So there is no tour here. Each hint is a plain inline card that appears
/// ONCE, at the moment its subject first appears on screen, and disappears
/// for good when dismissed. Nothing is dimmed, nothing is blocked, nothing
/// steals focus — a hint the user ignores costs them one glance.
///
/// Storage mirrors the seen-flag controller's stance exactly: `.get()` with a
/// type check, never `getStringList` (CR-01), and any unreadable or corrupt
/// store means EVERY hint is already seen — a hint that cannot be dismissed
/// permanently would reappear forever, which is worse than never showing it.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:vitomy/core/providers.dart';

/// The hints this app knows how to show. Ids are stable storage values, never
/// rendered, so they are never translated.
enum BqHint {
  /// In the regimen editor, beside the on/off week sliders: what a cycle is.
  /// The one genuinely unobvious idea in the product, explained where it
  /// lives rather than on a screen the user saw before they had a regimen.
  cycle('hint_cycle'),

  /// On Сьогодні, above the first day that actually has doses: that a row is
  /// tappable. Shown only once a supplement exists, so it arrives when the
  /// action it describes is possible.
  markDose('hint_mark_dose');

  const BqHint(this.id);

  final String id;
}

/// The ids already seen. A hint renders only while its id is absent.
class FirstRunHints extends Notifier<Set<String>> {
  static const _prefsKey = 'first_run_hints_seen';

  @override
  Set<String> build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    // An unopenable store cannot remember a dismissal, so every hint would
    // come back on every launch — treat them all as seen (the seen-flag
    // controller's D-5 reasoning, applied to a set).
    if (prefs == null) return BqHint.values.map((h) => h.id).toSet();
    final stored = prefs.get(_prefsKey);
    if (stored == null) return <String>{};
    // `getStringList` is an unguarded downcast; a value of the wrong type
    // under this key would throw inside this build and park the provider in
    // a permanent error state (CR-01). Wrong type means dismiss everything
    // rather than loop.
    if (stored is! List) return BqHint.values.map((h) => h.id).toSet();
    return stored.whereType<String>().toSet();
  }

  bool shouldShow(BqHint hint) => !state.contains(hint.id);

  /// Dismisses [hint] for good. The in-memory set updates first so the card
  /// disappears on this frame; a failed write costs one re-show on the next
  /// launch and is reported, never surfaced.
  Future<void> dismiss(BqHint hint) async {
    if (state.contains(hint.id)) return;
    final next = {...state, hint.id};
    state = next;
    final prefs = ref.read(sharedPreferencesProvider);
    if (prefs == null) return;
    try {
      final persisted = await prefs.setStringList(_prefsKey, next.toList());
      if (!persisted) {
        throw StateError('the hint store rejected the write');
      }
    } catch (error, stack) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stack,
          library: 'vitomy',
          context: ErrorDescription('persisting a dismissed first-run hint'),
        ),
      );
    }
  }

  /// Brings every hint back — the debug-build companion to
  /// `OnboardingController.reset`.
  Future<void> reset() async {
    state = <String>{};
    await ref.read(sharedPreferencesProvider)?.remove(_prefsKey);
  }
}

final firstRunHintsProvider =
    NotifierProvider<FirstRunHints, Set<String>>(FirstRunHints.new);

/// Whether [hint] should still be rendered, read off the STATE.
///
/// A widget must reach the answer through this, never through
/// `ref.watch(firstRunHintsProvider.notifier).shouldShow(...)`: watching the
/// notifier rebuilds only when the notifier INSTANCE changes, so dismissing a
/// hint updated the set and left the card on screen. Taking the set as the
/// argument makes the dependency the thing that actually changes.
bool showsHint(Set<String> dismissed, BqHint hint) =>
    !dismissed.contains(hint.id);
