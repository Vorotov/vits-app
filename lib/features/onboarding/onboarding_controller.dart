/// State for the first-launch intro (spec D-3..D-7, ONBO-03): the persisted
/// seen-flag and the in-memory one-shot that hands the user into adding
/// their first supplement.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:vitomy/core/providers.dart';

/// The persisted "onboarding shown" flag.
///
/// Seed semantics, in the order the build checks them:
/// - a NULL store is a store that could not be opened this launch (CR-02):
///   a dismissal could never be remembered, so treating this as "not seen"
///   re-shows onboarding on every cold start with no permanent escape —
///   a loop is worse than a first-time user missing the intro once, so an
///   unopenable store means seen (D-5);
/// - an absent key is a first launch — not seen;
/// - `get` (Object?), never `getBool`: `getBool` is an unguarded `as bool?`
///   downcast (shared_preferences 2.5.x), so a non-bool under this key would
///   throw INSIDE this build, park the provider in a permanent error state
///   and brick the launch across restarts — the CR-01 defect class the
///   locale controller already fixed once. A non-bool means the store was
///   edited outside the app; "not seen" risks the same permanent re-show
///   loop as D-5, so it means seen (D-6).
class OnboardingController extends Notifier<bool> {
  static const _prefsKey = 'onboarding_seen';

  @override
  bool build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    if (prefs == null) return true; // D-5: an unopenable store never loops.
    final stored = prefs.get(_prefsKey);
    if (stored == null) return false; // First launch.
    return stored is bool ? stored : true; // D-6: a corrupt value never loops.
  }

  /// Leaves onboarding for good — from Skip on either page or the final CTA
  /// (D-7: set regardless of whether a supplement then gets added; an empty
  /// stack is recoverable, a re-show loop is not).
  ///
  /// Order is load-bearing: the one-shot is armed BEFORE the flag flips, so
  /// the gate cannot rebuild into the shell branch and consume an unarmed
  /// one-shot. State flips before the disk write completes, matching the
  /// locale controller's stance: the user proceeds instantly; a failed write
  /// costs one re-shown onboarding on the next launch, is reported to the
  /// crash logger and never surfaced — the user can do nothing about a disk
  /// write, and blocking them inside onboarding over one is not acceptable
  /// (the spec's write-failure stance).
  Future<void> markSeen({required bool openAddFlow}) async {
    if (openAddFlow) ref.read(pendingFirstAddProvider.notifier).arm();
    state = true;
    final prefs = ref.read(sharedPreferencesProvider);
    // No store to write to (CR-02): the session proceeds; only the next
    // launch cannot remember — the exact cost D-5 already accepts.
    if (prefs == null) return;
    try {
      final persisted = await prefs.setBool(_prefsKey, true);
      if (!persisted) {
        throw StateError('the onboarding store rejected the write');
      }
    } catch (error, stack) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stack,
          library: 'vitomy',
          context: ErrorDescription('persisting the onboarding seen flag'),
        ),
      );
    }
  }

  /// Puts the intro back, for testing it on a device without reinstalling
  /// (which would take the user's data with it). Reachable ONLY from the
  /// debug-build row in Settings.
  Future<void> reset() async {
    state = false;
    await ref.read(sharedPreferencesProvider)?.remove(_prefsKey);
  }
}

/// App-lifetime state — intentionally NOT autoDispose, like the locale
/// controller (the phase-wide dispose policy is documented in core
/// providers, D-23).
final onboardingSeenProvider =
    NotifierProvider<OnboardingController, bool>(OnboardingController.new);

/// In-memory, never persisted. Armed only by the final CTA; consumed exactly
/// once by the gate's shell branch. A cold start never has it set, so a user
/// who force-quits mid-onboarding does not get an add sheet on next launch.
final pendingFirstAddProvider =
    NotifierProvider<PendingFirstAdd, bool>(PendingFirstAdd.new);

class PendingFirstAdd extends Notifier<bool> {
  @override
  bool build() => false;

  void arm() => state = true;

  /// Returns whether it was armed, and disarms in the same call — so a
  /// rebuild cannot observe it twice.
  bool consume() {
    final armed = state;
    state = false;
    return armed;
  }
}
