import 'package:flutter/material.dart';

import 'package:boostque/core/l10n/l10n.dart';
import 'package:boostque/core/theme/tokens.dart';

/// Phase 1 stub for the Stack tab: the localized heading IS the designed
/// state (UI-SPEC Visual Focal Point) — nothing else renders until Phase 2.
class StackScreen extends StatelessWidget {
  const StackScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsetsDirectional.only(
            start: BqSpace.lg,
            end: BqSpace.lg,
            top: BqSpace.lg,
          ),
          child: Text(
            context.l10n.tabStack,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
        ),
      ),
    );
  }
}
