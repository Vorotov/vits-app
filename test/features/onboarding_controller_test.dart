/// Unit tests for the onboarding seen-flag controller and the first-add
/// one-shot (spec D-3..D-7, ONBO-03).
///
/// The seed cases mirror the LocaleController lessons: a null store means the
/// store could not be opened at all (CR-02), and a wrong-typed value must
/// never throw inside the provider build (CR-01) — both degrade to "seen",
/// because a re-show loop with no permanent escape is worse than one missed
/// intro.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vitomy/core/providers.dart';
import 'package:vitomy/features/onboarding/onboarding_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  ProviderContainer scoped(SharedPreferences? prefs) {
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('onboardingSeenProvider seed', () {
    test('empty store seeds false — first launch shows onboarding', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      expect(scoped(prefs).read(onboardingSeenProvider), isFalse);
    });

    test('stored true seeds true', () async {
      SharedPreferences.setMockInitialValues({'onboarding_seen': true});
      final prefs = await SharedPreferences.getInstance();
      expect(scoped(prefs).read(onboardingSeenProvider), isTrue);
    });

    test('null store (could not open) seeds true — D-5, no loop', () {
      expect(scoped(null).read(onboardingSeenProvider), isTrue);
    });

    test('non-bool stored value seeds true without throwing — D-6', () async {
      SharedPreferences.setMockInitialValues({'onboarding_seen': 'yes'});
      final prefs = await SharedPreferences.getInstance();
      expect(scoped(prefs).read(onboardingSeenProvider), isTrue);
    });
  });

  group('markSeen', () {
    test('persists true and flips state', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = scoped(prefs);
      await container
          .read(onboardingSeenProvider.notifier)
          .markSeen(openAddFlow: false);
      expect(container.read(onboardingSeenProvider), isTrue);
      expect(prefs.getBool('onboarding_seen'), isTrue);
    });

    test('skip path never arms the one-shot', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = scoped(prefs);
      await container
          .read(onboardingSeenProvider.notifier)
          .markSeen(openAddFlow: false);
      expect(container.read(pendingFirstAddProvider), isFalse);
    });

    test('openAddFlow arms the one-shot BEFORE the flag flips', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = scoped(prefs);
      var armedWhenFlagFlipped = false;
      container.listen(onboardingSeenProvider, (_, seen) {
        if (seen) {
          armedWhenFlagFlipped = container.read(pendingFirstAddProvider);
        }
      });
      await container
          .read(onboardingSeenProvider.notifier)
          .markSeen(openAddFlow: true);
      expect(
        armedWhenFlagFlipped,
        isTrue,
        reason: 'the gate must never rebuild before the one-shot is armed',
      );
    });

    test('a null store still flips in-memory state — never blocks', () async {
      final container = scoped(null);
      await container
          .read(onboardingSeenProvider.notifier)
          .markSeen(openAddFlow: false);
      expect(container.read(onboardingSeenProvider), isTrue);
    });
  });

  group('PendingFirstAdd', () {
    test(
        'consume returns true once, then false — a rebuild cannot observe it '
        'twice', () {
      final container = scoped(null);
      final oneShot = container.read(pendingFirstAddProvider.notifier);
      expect(oneShot.consume(), isFalse);
      oneShot.arm();
      expect(oneShot.consume(), isTrue);
      expect(oneShot.consume(), isFalse);
    });
  });
}
