/// The frame-1 gate (spec D-2): a widget branch, not a pushed route.
///
/// This is the third frame-1 seed in the codebase, after the locale seed and
/// the notification launch payload — one recognizable pattern. Keeping the
/// Navigator out of it means `AppShell`'s "no route is ever popped"
/// invariants are untouched: when onboarding finishes, the tree SWAPS, and
/// there is no onboarding route underneath the shell to leak back to.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:boostque/app_shell.dart';
import 'package:boostque/features/onboarding/onboarding_controller.dart';
import 'package:boostque/features/onboarding/onboarding_screen.dart';
import 'package:boostque/features/stack/add_supplement_sheet.dart';

class OnboardingGate extends ConsumerWidget {
  const OnboardingGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(onboardingSeenProvider)
        ? const _FirstAddLauncher(child: AppShell())
        : const OnboardingScreen();
  }
}

/// Consumes the first-add one-shot exactly once, in a post-frame callback,
/// and opens the app's single add entry point (D-10) — the same
/// [showAddSupplementSheet] the FAB calls.
///
/// A stateful widget on purpose: `initState` runs once per mount, and the
/// one-shot's `consume()` disarms in the same call, so neither a rebuild of
/// this widget nor a second mount can open a second sheet. A cold start with
/// the flag already seen mounts this branch with the one-shot unarmed —
/// `consume()` answers false and nothing opens.
class _FirstAddLauncher extends ConsumerStatefulWidget {
  const _FirstAddLauncher({required this.child});

  final Widget child;

  @override
  ConsumerState<_FirstAddLauncher> createState() => _FirstAddLauncherState();
}

class _FirstAddLauncherState extends ConsumerState<_FirstAddLauncher> {
  @override
  void initState() {
    super.initState();
    // Post-frame: the sheet needs a laid-out Navigator, and opening it
    // mid-build would be an exception. `mounted` is checked because the
    // callback outlives this State if the tree is torn down on frame 1.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (ref.read(pendingFirstAddProvider.notifier).consume()) {
        showAddSupplementSheet(context);
      }
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
