/// The support screen: one paragraph and three tips.
///
/// ## Its own feature directory
///
/// Not a third file under `lib/features/settings/`. That feature's glob gate
/// applies every one of its assertions to every file it finds there, and those
/// assertions are about a settings screen. `lib/features/onboarding/` is the
/// precedent for a small feature owning its own directory.
///
/// ## What it renders while it does not know yet
///
/// Nothing. No spinner, no skeleton, no placeholder rows. The paragraph sits
/// alone until the offering lands, and then the tips appear under it.
///
/// This is the stance `_RemindersSection` already takes in Settings, written
/// down there and copied here on purpose: a row stating an unknown fact is
/// worse than no row, and the window is sub-perceptible in practice. Rendering
/// three placeholder rows would be worse than either, because the screen would
/// then flash three plausible-looking tips before replacing them with the word
/// "unavailable" on any device that cannot reach the store.
///
/// ## Where the prices come from
///
/// The store, already formatted. Nothing in this file or in the ARB files holds
/// a number, a currency symbol or a separator. The app ships in seven languages
/// and sells in every storefront Apple has; formatting money itself would be
/// wrong in most of them.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:vitomy/core/l10n/l10n.dart';
import 'package:vitomy/core/purchases/purchase_gateway.dart';
import 'package:vitomy/core/purchases/purchase_providers.dart';
import 'package:vitomy/core/purchases/tip_products.dart';
import 'package:vitomy/core/theme/tokens.dart';

/// The support screen, a pushed route reached from Settings.
class SupportScreen extends ConsumerWidget {
  const SupportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final state = ref.watch(supportControllerProvider);
    return Scaffold(
      body: SafeArea(
        // `ListView`, never a `Column`, for the reason the Settings screen
        // writes down: at textScaler 2.0 in several languages this content
        // exceeds the viewport, and a Column would overflow.
        child: ListView(
          padding: const EdgeInsetsDirectional.only(
            start: 20,
            end: 20,
            top: BqSpace.lg,
            bottom: BqSpace.lg,
          ),
          children: [
            const _BackRow(),
            Text(
              l10n.supportTitle,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: BqSpace.md),
            Text(
              l10n.supportBody,
              style: const TextStyle(
                fontSize: 15,
                height: 1.5,
                color: BqColors.textSecondary,
              ),
            ),
            const SizedBox(height: BqSpace.lg),
            ..._body(context, ref, state),
          ],
        ),
      ),
    );
  }

  /// Everything below the paragraph, which is a pure function of the phase.
  List<Widget> _body(BuildContext context, WidgetRef ref, SupportState state) {
    final l10n = context.l10n;
    switch (state.phase) {
      case SupportPhase.preparing:
        // Deliberately empty. See the library comment.
        return const <Widget>[];
      case SupportPhase.unavailable:
        return [
          Text(
            l10n.supportUnavailable,
            style: const TextStyle(fontSize: 14, color: BqColors.textMuted),
          ),
        ];
      case SupportPhase.thanks:
        return [
          Text(
            l10n.supportThanks,
            style: const TextStyle(fontSize: 15, color: BqColors.calm),
          ),
        ];
      case SupportPhase.offered:
      case SupportPhase.purchasing:
        return [
          // Ordered by this app's own list rather than by the offering's, so a
          // reordered dashboard cannot put the largest tip first. A product the
          // offering returns that this app does not know is skipped; a product
          // this app knows that the offering does not return simply does not
          // appear.
          for (final id in tipProductIds)
            if (_find(state.tips, id) case final tip?)
              _TipRow(
                tip: tip,
                label: _labelFor(l10n, id),
                // Every row goes inert while any purchase is in flight: two
                // system purchase sheets cannot be open at once. The controller
                // refuses a second call as well, so this is the visible half of
                // a rule that is already true.
                onTap: state.phase == SupportPhase.purchasing
                    ? null
                    : () => ref
                        .read(supportControllerProvider.notifier)
                        .buy(tip.id),
              ),
          if (state.failed)
            Padding(
              padding: const EdgeInsetsDirectional.only(top: BqSpace.sm),
              child: Text(
                l10n.supportFailed,
                // The warn palette, which this app gates to things that are
                // actionable right now. A payment that just failed is exactly
                // that: the user is looking at the screen and can try again.
                style: const TextStyle(fontSize: 14, color: BqColors.warn),
              ),
            ),
        ];
    }
  }

  static TipProduct? _find(List<TipProduct> tips, String id) {
    for (final tip in tips) {
      if (tip.id == id) return tip;
    }
    return null;
  }

  static String _labelFor(AppLocalizations l10n, String id) => switch (id) {
        tipSmallId => l10n.supportTipSmall,
        tipMediumId => l10n.supportTipMedium,
        _ => l10n.supportTipLarge,
      };
}

/// The pushed route's way out, the exact mirror of the row Settings carries.
///
/// It exists for the reason written down there: a pushed route with no back
/// affordance passes every widget test, because tests pop programmatically, and
/// strands the user on the first manual run on any device without a reliable
/// back gesture. The row holds NO text, so its extent is pure geometry and it
/// cannot overflow at any text scale, in any locale, in any direction.
class _BackRow extends StatelessWidget {
  const _BackRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        Semantics(
          button: true,
          label: context.l10n.navBack,
          excludeSemantics: true,
          // The action lives on THIS node as well as on the button:
          // `excludeSemantics` drops every descendant action, so without it the
          // control announces itself as a button no screen reader can activate
          // — and on a pushed route it is the only way out.
          onTap: () => Navigator.maybePop(context),
          child: IconButton(
            // `maybePop`, not `pop`: the screen must not assume it was pushed.
            onPressed: () => Navigator.maybePop(context),
            constraints: const BoxConstraints.tightFor(width: 44, height: 44),
            padding: EdgeInsets.zero,
            icon: const Icon(
              Icons.arrow_back_ios_new,
              size: 18,
              color: BqColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

/// One tip: its name, the store's own price, and a 44px target.
class _TipRow extends StatelessWidget {
  final TipProduct tip;
  final String label;

  /// `null` disables the row, which is what a purchase in flight does to all
  /// three.
  final VoidCallback? onTap;

  const _TipRow({required this.tip, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: BqSpace.sm),
      child: Semantics(
        button: true,
        enabled: enabled,
        // The label and the price read as one phrase, so a screen reader
        // announces what is being bought and for how much in a single
        // utterance rather than as two unrelated fragments.
        label: '$label, ${tip.priceString}',
        excludeSemantics: true,
        onTap: onTap,
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: BqColors.surface,
            border: Border.all(color: BqColors.cardBorder),
            borderRadius: BorderRadius.circular(BqRadii.card),
          ),
          child: InkWell(
            onTap: onTap,
            child: Padding(
              // The vertical inset the Settings rows use, which puts a
              // single-line row at 45px and grows with the text scaler rather
              // than clamping.
              padding: const EdgeInsetsDirectional.fromSTEB(16, 15, 16, 15),
              // `Wrap`, not `Row`, and this is a fix rather than a
              // preference. A Row with an Expanded label and a fixed price
              // overflowed by 85px at textScaler 2.0 in Ukrainian with an
              // Indonesian price string: the price alone was wider than the
              // space the label had been given, so Expanded handed the label a
              // negative extent. Prices come from a storefront this app does
              // not choose and cannot measure in advance, which is exactly the
              // case "no fixed-width text container" is about.
              //
              // With spaceBetween the single-line result is identical to the
              // Row it replaces — label at the start, price at the end — and
              // when the two no longer fit, the price drops to its own line
              // instead of painting over the edge.
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: BqSpace.sm,
                runSpacing: BqSpace.xs,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 15,
                      color: enabled ? BqColors.ink : BqColors.textDisabled,
                    ),
                  ),
                  Text(
                    tip.priceString,
                    style: TextStyle(
                      fontSize: 15,
                      color:
                          enabled ? BqColors.accent : BqColors.textDisabled,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
