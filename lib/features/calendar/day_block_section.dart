/// One time block of the rendered day: its header row and its dose rows
/// (plan 03-04, UI-SPEC S4 "Scroll body", DECIDED-1 / DECIDED-6).
///
/// Everything this widget draws is decided by the pure helpers in
/// `day_view_model.dart` — it never groups, never resolves a tag and never
/// reads the clock itself; `nowMinutes` and `viewingToday` arrive as
/// parameters. Empty blocks never reach here: `groupIntoBlocks` omits them.
///
/// The header time is the block's EARLIEST REAL slot time (M5): printing the
/// mockup's 08:00 anchor above a 09:30-only morning would be false
/// information. The header's three text children each carry a one-third-of-row
/// ceiling and ellipsize, so no combination of a long label, a long tag and a
/// large accessibility text scale can overflow the row — the divider between
/// them absorbs the slack, but it was never what made the row safe (WR-04).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:boostque/core/domain/repositories.dart';
import 'package:boostque/core/l10n/l10n.dart';
import 'package:boostque/core/theme/theme.dart';
import 'package:boostque/core/theme/tokens.dart';
import 'package:boostque/core/today_controller.dart';
import 'package:boostque/features/calendar/day_view_model.dart';
import 'package:boostque/features/calendar/dose_row.dart';

/// A non-empty time block: header row, 9px, its dose rows 7px apart, 18px
/// below the whole section (UI-SPEC spacing overrides).
class DayBlockSection extends ConsumerWidget {
  const DayBlockSection({
    super.key,
    required this.block,
    required this.dayDoses,
    required this.day,
    required this.viewingToday,
    required this.nowMinutes,
    required this.isCurrentBlock,
  });

  /// The block to render, already grouped by `groupIntoBlocks`.
  final DayBlock block;

  /// The whole day's dose list — the ONLY correct input for the
  /// `доза n з m` chip's denominator (PF-6).
  final List<DayDose> dayDoses;

  /// The resolved day being rendered (`dateOnly()` UTC).
  final DateTime day;

  /// Whether [day] is today; gates every warn-colored treatment (TRACK-03).
  final bool viewingToday;

  /// Minutes since local midnight, from `nowMinutesProvider`.
  final int nowMinutes;

  /// Whether this block is `currentBlockIndex` — already null on any
  /// non-today view, so the accent time can never appear off today.
  final bool isCurrentBlock;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final today = ref.watch(todayProvider);

    final tod = TimeOfDay(
      hour: block.earliestMinutes ~/ 60,
      minute: block.earliestMinutes % 60,
    );
    // 24-hour everywhere (UI-SPEC locked), same call shape as the Phase-2
    // slot rows so both screens print a time identically.
    final timeText = MaterialLocalizations.of(context)
        .formatTimeOfDay(tod, alwaysUse24HourFormat: true);

    final label = switch (block.blockIndex) {
      0 => l10n.blockMorning,
      1 => l10n.blockDay,
      2 => l10n.blockEvening,
      _ => l10n.blockNight,
    };

    return Padding(
      // Block bottom margin (mockup line 227).
      padding: const EdgeInsetsDirectional.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Every text-bearing child of the header gets a hard ceiling of one
          // third of the row (WR-04). `Expanded` on the divider protects the
          // DIVIDER, not the row: three non-flexible children overflowed by
          // 65px at textScaler 2.0, and a long enough label or tag did the
          // same at scale 1.0. Three ceilings that sum to the row width minus
          // its gaps make that arithmetically impossible, while leaving the
          // mockup layout untouched at scale 1.0 — every child is far below
          // its ceiling there, so the divider still absorbs all the slack.
          LayoutBuilder(
            builder: (context, constraints) {
              const gaps = 30.0; // the three 10px gaps
              final ceiling = constraints.maxWidth.isFinite
                  ? ((constraints.maxWidth - gaps) / 3).clamp(0.0, 4000.0)
                  : double.infinity;
              return Row(
                children: [
                  ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: ceiling),
                    child: Text(
                      timeText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: BqText.mono(
                        size: 13,
                        color: isCurrentBlock ? BqColors.accent : BqColors.ink,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: ceiling),
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        color: BqColors.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: SizedBox(
                      height: 1,
                      child: ColoredBox(color: BqColors.cardBorder),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: ceiling),
                    child: _BlockTagChip(
                      tag: blockTagOf(
                        block,
                        viewingToday: viewingToday,
                        nowMinutes: nowMinutes,
                      ),
                      blockIndex: block.blockIndex,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 9),
          for (final (i, dose) in block.doses.indexed) ...[
            if (i > 0) const SizedBox(height: 7),
            DoseRow(
              dose: dose,
              dayDoses: dayDoses,
              day: day,
              today: today,
              viewingToday: viewingToday,
              nowMinutes: nowMinutes,
            ),
          ],
        ],
      ),
    );
  }
}

/// The block-header tag chip: mono 11/400, radius `BqRadii.chip`, padding 4/7.
///
/// The label and both colors come from ONE exhaustive switch over the sealed
/// [BlockTag] hierarchy, in the `_StatusChip` record-destructuring style — so a
/// future tag case is a compile error here rather than a silently missing chip.
class _BlockTagChip extends StatelessWidget {
  const _BlockTagChip({required this.tag, required this.blockIndex});

  final BlockTag tag;
  final int blockIndex;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final (String label, Color fg, Color bg) = switch (tag) {
      AllTakenTag() => (l10n.blockAllTaken, BqColors.calm, BqColors.calmBg),
      AllMarkedTag() => (
          l10n.blockAllMarked,
          BqColors.textSecondary,
          BqColors.chip,
        ),
      // The ONLY warn-colored branch in this file, and `blockTagOf` emits
      // ProgressTag exclusively when `viewingToday` is true — so a past day
      // can never render an amber tag (DECIDED-5 / TRACK-03).
      ProgressTag(:final done, :final total) => (
          l10n.blockProgress(done, total),
          BqColors.warn,
          BqColors.warnBg,
        ),
      MealTag() => (
          switch (blockIndex) {
            0 => l10n.blockTagBreakfast,
            1 => l10n.blockTagLunch,
            2 => l10n.blockTagDinner,
            _ => l10n.blockTagSleep,
          },
          BqColors.textMuted,
          BqColors.chip,
        ),
    };
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(
        vertical: 4,
        horizontal: 7,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(BqRadii.chip),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: BqText.mono(size: 11, color: fg, weight: FontWeight.w400),
      ),
    );
  }
}
