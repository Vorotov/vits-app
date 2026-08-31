/// The two-page first-launch intro (spec D-1, D-8, ONBO-01).
///
/// Chrome contract, constant across pages:
/// - Skip: top trailing, every page (D-8) — sets the same seen flag as the
///   final CTA and opens NO sheet;
/// - two-dot indicator above the CTA — decorative, excluded from semantics,
///   because the CTA label already states position;
/// - one full-width primary CTA pinned above the bottom SafeArea: «Далі» on
///   page 1, «Додати першу добавку» on page 2;
/// - no explicit back control: swiping right returns to page 1, and Skip is
///   the escape — two controls for leaving one screen is the D6 mistake the
///   FAB decision already corrected.
///
/// Both `markSeen` calls are fire-and-forget: the state flip inside is
/// synchronous (the gate swaps branch on this frame) and the disk write's
/// failure handling lives in the controller, not here.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:boostque/core/l10n/l10n.dart';
import 'package:boostque/core/theme/tokens.dart';
import 'package:boostque/features/onboarding/onboarding_controller.dart';
import 'package:boostque/features/onboarding/onboarding_illustrations.dart';
import 'package:boostque/features/onboarding/onboarding_page.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _page = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _skip() {
    // Fire-and-forget by design — see the library doc.
    ref.read(onboardingSeenProvider.notifier).markSeen(openAddFlow: false);
  }

  void _primaryAction() {
    if (_page == 0) {
      _pageController.animateToPage(
        1,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    } else {
      ref.read(onboardingSeenProvider.notifier).markSeen(openAddFlow: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final lastPage = _page == 1;
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
                  onPressed: _skip,
                  child: Text(l10n.onboardingSkip),
                ),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (page) => setState(() => _page = page),
                children: [
                  OnboardingPage(
                    title: l10n.onboardingPage1Title,
                    body: l10n.onboardingPage1Body,
                    illustration: const OnboardingDosesIllustration(),
                  ),
                  OnboardingPage(
                    title: l10n.onboardingPage2Title,
                    body: l10n.onboardingPage2Body,
                    illustration: const OnboardingCycleIllustration(),
                  ),
                ],
              ),
            ),
            // Two-dot indicator — decorative (the CTA label states position),
            // so a screen reader never hears it.
            ExcludeSemantics(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < 2; i++) ...[
                    if (i > 0) const SizedBox(width: BqSpace.sm),
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _page == i ? BqColors.accent : BqColors.field,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // Primary CTA — pinned above the bottom SafeArea, full width of
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
                  onPressed: _primaryAction,
                  child: Text(
                    lastPage ? l10n.onboardingAddFirst : l10n.onboardingNext,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
