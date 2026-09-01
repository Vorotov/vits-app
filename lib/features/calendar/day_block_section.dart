/// One time block of the rendered day: its header row and its dose rows
/// (plan 03-04, UI-SPEC S4 "Scroll body", DECIDED-1 / DECIDED-6).
///
/// Everything this widget draws is decided by the pure helpers in
/// `day_view_model.dart` — it never groups, never resolves a tag and never
/// reads the clock itself; `nowMinutes` and `viewingToday` arrive as
/// parameters. Empty blocks never reach here: `groupIntoBlocks` omits them.
///
/// The header carries NO time since v1.2. It used to print one — the block's
/// earliest real slot time — which is only ever right for a block whose doses
/// all share a minute: a morning holding 08:20 and 09:05 filed both rows under
/// an "08:20" heading that was false for the second one. The blocks are wide
/// (Ранок alone is 00:00-11:59), so the block is the coarse container and the
/// TIME is the fine one; each distinct minute now prints its own small heading
/// above its own rows (`groupByTime`), while the block label still appears
/// exactly once. The header's two remaining text children each carry a
/// one-half-of-row ceiling and ellipsize, so no combination of a long label, a
/// long tag and a large accessibility text scale can overflow the row — the
/// divider between them absorbs the slack, but it was never what made the row
/// safe (WR-04).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:boostque/core/domain/repositories.dart';
import 'package:boostque/core/l10n/clock_format.dart';
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
  /// non-today view, so no accented time can appear off today. Since v1.2 it
  /// no longer decides the accent by itself: it only opens the door for
  /// `accentedTimeMinutes`, which picks WHICH of this block's times leads.
  final bool isCurrentBlock;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final today = ref.watch(todayProvider);

    final groups = groupByTime(block.doses);
    // At most ONE time on the whole day renders accented, and never off today
    // — see `accentedTimeMinutes` for why the accent moved from the block's
    // earliest time to the next time actually due.
    final accented = accentedTimeMinutes(
      groups,
      isCurrentBlock: isCurrentBlock,
      nowMinutes: nowMinutes,
    );

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
          // Every text-bearing child of the header gets a hard ceiling of a
          // fraction of the row (WR-04). `Expanded` on the divider protects
          // the DIVIDER, not the row: non-flexible children overflowed by 65px
          // at textScaler 2.0, and a long enough label or tag did the same at
          // scale 1.0. Ceilings that sum to the row width minus its gaps make
          // that arithmetically impossible, while leaving the mockup layout
          // untouched at scale 1.0 — every child is far below its ceiling
          // there, so the divider still absorbs all the slack. Dropping the
          // time from this row left two text children and two gaps, so the
          // share is a half rather than the old third; the arithmetic, not the
          // number, is what keeps the row safe.
          LayoutBuilder(
            builder: (context, constraints) {
              const gaps = 20.0; // the two 10px gaps
              final ceiling = constraints.maxWidth.isFinite
                  ? ((constraints.maxWidth - gaps) / 2).clamp(0.0, 4000.0)
                  : double.infinity;
              return Row(
                children: [
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
          for (final (g, group) in groups.indexed) ...[
            // Groups after the first get a wider gap than the 7px between
            // sibling rows, so a time label binds visually to the rows BELOW
            // it rather than floating between two groups. Claude's-discretion
            // spacing: the mockup only ever drew one time per block, so it has
            // no value for this.
            if (g > 0) const SizedBox(height: 12),
            _TimeLabel(
              minutes: group.minutes,
              accented: group.minutes == accented,
            ),
            const SizedBox(height: 7),
            for (final (i, dose) in group.doses.indexed) ...[
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
        ],
      ),
    );
  }
}

/// The heading above the rows scheduled at one exact minute (v1.2).
///
/// Keeps the type the block header used to print the time in — mono 13, the
/// same call shape as the Phase-2 slot rows — so both screens still render a
/// time identically and this reads as the old header time moved down, not as a
/// new kind of label. 24-hour everywhere (UI-SPEC locked).
///
/// The string is `MaterialLocalizations.formatTimeOfDay`, i.e. locale data,
/// not copy: there is nothing here for a translator to write, so this widget
/// adds no ARB key. It is deliberately NOT width-constrained — the column
/// stretches it to the full body width and it holds five glyphs, so it has
/// room to grow at any accessibility text scale.
class _TimeLabel extends StatelessWidget {
  const _TimeLabel({required this.minutes, required this.accented});

  /// Minutes since midnight, straight from the group's real slot time.
  final int minutes;

  /// Whether this is the day's ONE accented time (`accentedTimeMinutes`).
  final bool accented;

  @override
  Widget build(BuildContext context) {
    return Text(
      formatClock(context, minutes),
      style: BqText.mono(
        size: 13,
        color: accented ? BqColors.accent : BqColors.ink,
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
