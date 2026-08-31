/// One onboarding page's layout: illustration, title, body. No page-specific
/// logic — the screen owns navigation, this file owns arrangement.
///
/// The page is independently scrollable (spec): at textScaler 2.0 the copy
/// grows past small screens, and a scroll view designs the overflow out
/// rather than leaving it for the render matrix to catch.
library;

import 'package:flutter/material.dart';

import 'package:boostque/core/theme/tokens.dart';

class OnboardingPage extends StatelessWidget {
  const OnboardingPage({
    super.key,
    required this.title,
    required this.body,
    required this.illustration,
  });

  final String title;
  final String body;
  final Widget illustration;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsetsDirectional.fromSTEB(24, 24, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          illustration,
          const SizedBox(height: 32),
          Text(
            title,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: BqColors.ink,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            body,
            style: const TextStyle(
              fontSize: 15,
              height: 1.45,
              color: BqColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
