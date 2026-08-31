/// The first-launch intro — ONE page (v1.2, path A).
///
/// It was two pages with a dot indicator until the onboarding research pass:
/// NN/g's 70-participant test found a card deck left users rating the same
/// tasks HARDER (4.92 vs 5.49 of 7) with no gain in success or speed, and the
/// second page's subject — cycles — now appears as a contextual hint inside
/// the schedule editor, where a cycle actually exists. What survives here is
/// the one thing a hint cannot do: say what the product is before the user
/// has touched anything.
///
/// So this screen names the app, shows what a day looks like, and offers the
/// single next action. Skip stays, because an intro the user cannot leave is
/// the worst version of this pattern.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:boostque/core/l10n/l10n.dart';
import 'package:boostque/core/theme/tokens.dart';
import 'package:boostque/features/onboarding/onboarding_controller.dart';
import 'package:boostque/features/onboarding/onboarding_illustrations.dart';
import 'package:boostque/features/onboarding/onboarding_page.dart';

class OnboardingScreen extends ConsumerWidget {
  const OnboardingScreen({super.key});

  void _skip(WidgetRef ref) {
    // Fire-and-forget by design — see the library doc.
    ref.read(onboardingSeenProvider.notifier).markSeen(openAddFlow: false);
  }

  void _start(WidgetRef ref) {
    ref.read(onboardingSeenProvider.notifier).markSeen(openAddFlow: true);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return Scaffold(
      backgroundColor: BqColors.paper,
      body: SafeArea(
        child: Column(
          children: [
            // Skip — trailing edge, ≥44px box on every page (D-8).
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(0, 4, 12, 0),
                child: TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: BqColors.textSecondary,
                    minimumSize: const Size(44, 44),
                    textStyle: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  onPressed: () => _skip(ref),
                  child: Text(l10n.onboardingSkip),
                ),
              ),
            ),
            Expanded(
              child: OnboardingPage(
                title: l10n.onboardingPage1Title,
                body: l10n.onboardingPage1Body,
                illustration: const OnboardingDosesIllustration(),
              ),
            ),
            // Primary CTA — the single next action, pinned above the bottom SafeArea, full width of
            // the content column; the accent-fill treatment is the regimen
            // editor's save button, radius 13 mockup-exact override included.
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(24, 16, 24, 12),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: BqColors.accent,
                    foregroundColor: BqColors.surface,
                    overlayColor: BqColors.accentPressed,
                    padding:
                        const EdgeInsetsDirectional.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(13),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onPressed: () => _start(ref),
                  child: Text(l10n.onboardingAddFirst),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
