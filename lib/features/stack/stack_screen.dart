/// Stack tab — full S1 contract (plan 02-05; tracer slice was plan 02-01).
///
/// Renders the complete card anatomy from [stackEntriesProvider]: color bar,
/// wrapping name/dose, status chip (tested `statusOf`), schedule-summary chip
/// (tested `scheduleSummaryOf`), plus the summary header, ДОБАВКИ eyebrow,
/// and all five list states per UI-SPEC UI Considerations #1-#7:
/// - empty: `emptyStackTitle`/`emptyStackBody` directly under the header, with
///   the body pointing at the shell's floating + — this screen carries no add
///   button of its own since plan 06-04 — eyebrow omitted (#1)
/// - loading: header with an empty list area, NO spinner (#2)
/// - error: `stackLoadError` + retry (provider invalidate) — raw exception
///   text is never user-visible (#3, threat T-02-08)
/// - populated: scrollable list, 9px gaps, bottom padding >= 84px (#4)
/// - fresh entry: ЩОЙНО ДОДАНО chip and NO schedule chip — never a
///   placeholder dash (#6); chips live in a `Wrap` (#7)
///
/// Card tap pushes [RegimenEditorScreen] (STACK-04 edit path). The day comes
/// from `todayProvider` — the app's single calendar clock, shared with the
/// Calendar tab so both refresh together at midnight instead of each reading
/// the clock per build (plan 03-01, closes 02-REVIEW IN-06) — and is passed
/// into the pure `statusOf`; domain helpers never read the clock.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:boostque/core/domain/repositories.dart';
import 'package:boostque/core/l10n/l10n.dart';
import 'package:boostque/core/providers.dart';
import 'package:boostque/core/theme/theme.dart';
import 'package:boostque/core/theme/tokens.dart';
import 'package:boostque/core/today_controller.dart';
import 'package:boostque/core/widgets/bq_settings_gear_row.dart';
import 'package:boostque/features/stack/regimen_editor_screen.dart';
import 'package:boostque/features/stack/schedule_summary_text.dart';
import 'package:boostque/features/stack/stack_status.dart';

/// The Stack screen ("Мій стек", mockup screen 01, UI-SPEC S1).
class StackScreen extends ConsumerWidget {
  const StackScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(stackEntriesProvider);
    final l10n = context.l10n;
    final today = ref.watch(todayProvider);
    return Scaffold(
      body: SafeArea(
        child: ListView(
          // 20px horizontal padding is the UI-SPEC mockup-exact override for
          // screen bodies; bottom >= 84px clears the nav bar (UI-SPEC #4).
          padding: const EdgeInsetsDirectional.only(
            start: 20,
            end: 20,
            top: BqSpace.lg,
            bottom: 84,
          ),
          children: [
            // The gear gets its OWN end-aligned row ABOVE the title, identical
            // on all three screens the nav bar reaches (UI-SPEC S11 / D-5). The
            // row holds NO text, so its extent is pure geometry and it cannot
            // overflow at any text scale, in any locale, in any direction.
            //
            // Do NOT "tidy" it into a title row. The rejected alternative — a
            // bounded trailing group beside the title — is probably safe, but
            // it makes the header's overflow safety depend on a reader
            // correctly re-deriving "these children are not text" on every
            // future edit; the dedicated row makes it depend on nothing.
            const BqSettingsGearRow(),
            Text(
              l10n.stackTitle,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            // Summary 4px below the heading (S1 header contract). While the
            // streams warm up (loading/error) the counts are unknown — the
            // row is simply absent, matching the no-spinner loading rule.
            if (entries case AsyncData(value: final list)) ...[
              const SizedBox(height: BqSpace.xs),
              Text(
                l10n.stackSummary(
                  list.length,
                  list
                      .where((e) => statusOf(e, today) == StackStatus.active)
                      .length,
                ),
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: BqColors.textMuted,
                ),
              ),
            ],
            // The 18px gap below the summary now runs straight into the list:
            // the full-width accent add button that used to sit here — and its
            // trailing gap — are deleted (UX-01, plan 06-04). Adding is the
            // shell's floating + , identical on all three tabs, so this screen
            // has no add affordance and no accent-filled block of its own.
            const SizedBox(height: 18),
            // "Has an error" beats "is loading", matched on the PROPERTY and
            // in this arm order — the same shape the planner's `_surface` uses
            // (`planner_screen.dart:618`), so the two screens cannot drift into
            // rendering a failure differently (A1 / P-9, 04-REVIEW.md CR-02).
            //
            // This is the screen's OWN protection and it holds whatever
            // `stackEntriesProvider` hands over, including Riverpod 3's
            // "AsyncLoading that carries an error while it retries" shape. The
            // derivation's error-before-value-before-loading precedence
            // (`providers.dart`) is a second, independent layer; before
            // 05-REVIEW WR-02 this screen passed `skipLoadingOnReload: true` to
            // `when` instead, which could never change the outcome here (that
            // flag is only consulted when `isReloading` is true, and every
            // value the derivation returns is freshly constructed with no
            // previous state attached) while its comment claimed the error
            // surface depended on it.
            ...switch (entries) {
              // Error: documented copy + retry only — never exception text
              // (#3, T-02-08).
              AsyncValue(hasError: true) => <Widget>[
                  Text(
                    l10n.stackLoadError,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: BqColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: BqSpace.sm),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: TextButton(
                      // The same named recovery path the planner's retry uses,
                      // so the two screens can never drift into recovering
                      // differently (CR-02).
                      onPressed: () => retryStack(ref),
                      child: Text(
                        l10n.retry,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: BqColors.accent,
                        ),
                      ),
                    ),
                  ),
                ],
              // Empty state directly under the header; the ДОБАВКИ eyebrow is
              // omitted when the list is empty (#1).
              AsyncData(value: final list) when list.isEmpty =>
                const <Widget>[_EmptyStackState()],
              AsyncData(value: final list) => <Widget>[
                  // Mono eyebrow, 10px above the list (S1).
                  Text(
                    l10n.supplementsLabel,
                    style: BqText.mono(
                      size: 10.5,
                      color: BqColors.textMuted,
                      letterSpacing: 0.63,
                    ),
                  ),
                  const SizedBox(height: 10),
                  for (final (i, entry) in list.indexed) ...[
                    if (i > 0) const SizedBox(height: 9),
                    _StackCard(entry: entry, today: today),
                  ],
                ],
              // Loading: empty list area, NO spinner — the local-DB stream
              // resolves within a frame; a spinner would flash (#2).
              _ => const <Widget>[],
            },
          ],
        ),
      ),
    );
  }
}

/// Empty-stack state (UI-SPEC #1): title + body, with nothing above them but
/// the header. The single next-step affordance is the shell's floating + ,
/// which the body names as an ACTION rather than as a screen corner — so the
/// sentence stays true under RTL and if the button ever moves (plan 06-04).
class _EmptyStackState extends StatelessWidget {
  const _EmptyStackState();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsetsDirectional.only(top: BqSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.emptyStackTitle,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              height: 1.3,
              color: BqColors.ink,
            ),
          ),
          const SizedBox(height: BqSpace.xs),
          Text(
            l10n.emptyStackBody,
            style: const TextStyle(
              fontSize: 13,
              height: 1.4,
              color: BqColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

/// Full stack card (S1 anatomy): color bar + wrapping name/dose + `Wrap`
/// chips row; the whole card is the tap target into the editor (STACK-04).
class _StackCard extends StatelessWidget {
  const _StackCard({required this.entry, required this.today});

  final StackEntry entry;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final summary = scheduleSummaryOf(entry);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) =>
              RegimenEditorScreen(supplementId: entry.supplement.id),
        ),
      ),
      child: Container(
        padding: const EdgeInsetsDirectional.all(14),
        decoration: BoxDecoration(
          color: BqColors.surface,
          border: Border.all(color: BqColors.cardBorder),
          borderRadius: BorderRadius.circular(BqRadii.card),
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 4,
                margin: const EdgeInsetsDirectional.only(end: 12),
                decoration: BoxDecoration(
                  color: Color(entry.supplement.colorValue)
                      .withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name and dose wrap — no fixed width, no ellipsis (#7).
                    Text(
                      entry.supplement.name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                        color: BqColors.ink,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      entry.supplement.doseText,
                      style: const TextStyle(
                        fontSize: 12.5,
                        height: 1.4,
                        color: BqColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Chips in a Wrap so overflowing rows break to a new
                    // line (#7); a fresh entry gets NO schedule chip —
                    // never a placeholder dash (#6).
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _StatusChip(status: statusOf(entry, today)),
                        if (summary is! NoSummary)
                          _ScheduleChip(summary: summary),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Status chip (P-4 table verbatim + D10): mono 10.5/w500, radius
/// `BqRadii.chip`, padding 5/7. Semantic status colors are NOT accent
/// budget: АКТИВНА uses calm/calmBg, ПАУЗА textSecondary/chip.
class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final StackStatus status;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final (String label, Color fg, Color bg) = switch (status) {
      StackStatus.active => (l10n.statusActive, BqColors.calm, BqColors.calmBg),
      StackStatus.paused => (
          l10n.statusPaused,
          BqColors.textSecondary,
          BqColors.chip,
        ),
      StackStatus.planned => (
          l10n.statusPlanned,
          BqColors.accent,
          BqColors.accentChipBg,
        ),
      StackStatus.fresh => (
          l10n.statusFresh,
          BqColors.accent,
          BqColors.accentChipBg,
        ),
      // D10: finished renders the ЗАПЛАНОВАНО-styled treatment.
      StackStatus.finished => (
          l10n.statusFinished,
          BqColors.accent,
          BqColors.accentChipBg,
        ),
    };
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(
        vertical: 5,
        horizontal: 7,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(BqRadii.chip),
      ),
      child: Text(
        label,
        style: BqText.mono(size: 10.5, color: fg, letterSpacing: 0.3),
      ),
    );
  }
}

/// Schedule-summary chip: Instrument 11.5, `textSecondary` on `chip`.
/// All words come from ARB keys — only separators live in code (S1).
/// Paused regimens keep their summary; the status chip alone carries the
/// pause signal.
class _ScheduleChip extends StatelessWidget {
  const _ScheduleChip({required this.summary});

  final ScheduleSummary summary;

  @override
  Widget build(BuildContext context) {
    // One composition, shared with the planner's gantt row hint, so the two
    // tabs can never describe the same regimen differently (M13). The card
    // keeps the daily-slot tail; the planner drops it.
    final text = scheduleSummaryText(
      summary,
      l10n: context.l10n,
      locale: Localizations.localeOf(context).toString(),
      withSlots: true,
    );
    if (text.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(
        vertical: 5,
        horizontal: 8,
      ),
      decoration: BoxDecoration(
        color: BqColors.chip,
        borderRadius: BorderRadius.circular(BqRadii.chip),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11.5,
          height: 1.3,
          color: BqColors.textSecondary,
        ),
      ),
    );
  }
}
