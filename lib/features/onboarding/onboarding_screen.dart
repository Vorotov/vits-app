/// The first-launch intro — two pages (v1.2, path A).
///
/// It went two pages -> one -> two again, and the reasoning matters because
/// the count is the thing that keeps getting revisited. NN/g's
/// 70-participant test found a LONG card deck left users rating the same
/// tasks HARDER (4.92 vs 5.49 of 7) with no gain in success or speed, so the
/// original deck was cut to a single page. What the cut also removed was the
/// answer to "why is there a calendar tab" — a question no contextual hint
/// reaches, because the user has to open Календар before a hint there can
/// fire, and nothing before that point gives them a reason to.
///
/// So the shape now is: one page for what the app IS, one for what the
/// calendar answers, then the single next action. That is two pages, not a
/// deck, and the mechanics of cycles still live where a cycle exists — the
/// contextual hint in the schedule editor.
///
/// Skip stays on both pages, because an intro the user cannot leave is the
/// worst version of this pattern.
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
  static const _pageCount = 2;

  final PageController _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _onLastPage => _page == _pageCount - 1;

  /// Both exits write the same flag (D-7). Skip opens no add sheet; the CTA
  /// on the last page does. Neither is awaited: the state flip inside is
  /// synchronous, so the gate swaps branch on this frame, and the disk
  /// write's failure handling belongs to the controller.
  void _leave({required bool openAddFlow}) {
    ref.read(onboardingSeenProvider.notifier).markSeen(openAddFlow: openAddFlow);
  }

  void _primaryAction() {
    if (_onLastPage) {
      _leave(openAddFlow: true);
      return;
    }
    _controller.animateToPage(
      _page + 1,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      backgroundColor: BqColors.paper,
      body: SafeArea(
        child: Column(
          children: [
            // Skip — trailing edge, on every page (D-8), with a real 44px box.
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
                  onPressed: () => _leave(openAddFlow: false),
                  child: Text(l10n.onboardingSkip),
                ),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _controller,
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
                    illustration: const OnboardingCalendarIllustration(),
                  ),
                ],
              ),
            ),
            // Dots. Decorative: the CTA label already states position, so a
            // screen reader hears the button and not a pair of circles.
            ExcludeSemantics(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < _pageCount; i++) ...[
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
            // the content column. Its label always names what the next tap
            // does, which is why the dots can stay decorative. The accent
            // fill and the mockup-exact radius 13 are the regimen editor's
            // save button, reused rather than re-invented.
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(24, 16, 24, 12),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: BqColors.accent,
                    foregroundColor: BqColors.surface,
                    overlayColor: BqColors.accentPressed,
                    padding: const EdgeInsetsDirectional.symmetric(vertical: 15),
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
                    _onLastPage ? l10n.onboardingAddFirst : l10n.onboardingNext,
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
