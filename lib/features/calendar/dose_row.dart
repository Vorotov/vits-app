/// One materialized dose row — the five exhaustive visual states and the
/// app's ONLY `setStatus` call site (plan 03-04, UI-SPEC S4 row table,
/// DECIDED-2/3/5, T-03-02 / T-03-12 / T-03-13 / T-03-14).
///
/// Exactly one of five states renders per row, resolved in a fixed order from
/// the pure helpers: missed -> taken -> skipped -> overdue -> pending. Overdue
/// and missed are mutually exclusive by construction — `isOverdue` is gated on
/// the view being today and `isMissed` on the day being strictly before today.
///
/// The destructive palette is never referenced in this file (Phase 3 adds no
/// destructive action), and the warn palette is reachable only from the overdue
/// branch, which is already today-gated (TRACK-03 neutrality mandate).
///
/// Writes: `_apply` is the single guarded gate. It refuses re-entry while a
/// write is in flight, computes nothing itself (callers pass the target status
/// derived from the CURRENTLY rendered one), never rolls back optimistically —
/// the day stream is the source of truth — and surfaces a failure instead of
/// swallowing it (the WR-04 lesson).
library;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:boostque/core/domain/models.dart';
import 'package:boostque/core/domain/repositories.dart';
import 'package:boostque/core/l10n/l10n.dart';
import 'package:boostque/core/providers.dart';
import 'package:boostque/core/theme/theme.dart';
import 'package:boostque/core/theme/tokens.dart';
import 'package:boostque/features/calendar/day_view_model.dart';

/// The five exhaustive row states of the S4 table. No sixth combination may
/// render, and no two may render at once.
enum _RowState { missed, taken, skipped, overdue, pending }

/// A single dose row: one tap applies the DECIDED-2 tap transition, one long
/// press opens the labelled action sheet (wired in Task 3 of this plan).
class DoseRow extends ConsumerStatefulWidget {
  const DoseRow({
    super.key,
    required this.dose,
    required this.dayDoses,
    required this.day,
    required this.today,
    required this.viewingToday,
    required this.nowMinutes,
  });

  /// The dose this row renders.
  final DayDose dose;

  /// The whole day's dose list — the `доза n з m` denominator source, grouped
  /// by regimen id and NEVER read off `regimen.slots` (PF-6).
  final List<DayDose> dayDoses;

  /// The resolved day being rendered.
  final DateTime day;

  /// The app's single clock day.
  final DateTime today;

  /// Whether [day] is [today]; gates every warn-colored treatment.
  final bool viewingToday;

  /// Minutes since local midnight, from `nowMinutesProvider`.
  final int nowMinutes;

  @override
  ConsumerState<DoseRow> createState() => _DoseRowState();
}

class _DoseRowState extends ConsumerState<DoseRow> {
  /// In-flight guard (PF-4 / the CR-01 lesson): while this row's write is
  /// pending it swallows further gestures, so a rapid double tap ends
  /// deterministically at `taken` instead of oscillating back to `pending`.
  /// Deliberately NOT surfaced as a spinner — the write is single-digit ms and
  /// a flashing spinner would be worse than no feedback at all.
  bool _busy = false;

  /// Pressed-state flag driving the accent row border (Interaction 10).
  bool _pressed = false;

  /// The ONE place in the app that writes a [DoseStatus].
  Future<void> _apply(DoseStatus next) async {
    if (_busy) return;
    // Resolved BEFORE the await so no BuildContext survives the async gap.
    final messenger = ScaffoldMessenger.of(context);
    final failureText = context.l10n.markFailed;
    setState(() => _busy = true);
    try {
      await ref.read(intakeRepoProvider).setStatus(widget.dose.logId, next);
    } catch (_) {
      // No rollback: nothing was ever optimistically applied, so the row is
      // already showing the truth. The user is told the write did not land.
      messenger.showSnackBar(SnackBar(content: Text(failureText)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// The tap column of the DECIDED-2 transition table, computed from the
  /// CURRENTLY rendered status — never from a value captured earlier (PF-4).
  Future<void> _onTap() => _apply(
        widget.dose.status == DoseStatus.taken
            ? DoseStatus.pending
            : DoseStatus.taken,
      );

  /// Resolution order is the whole guarantee that exactly one state renders.
  _RowState _resolveState() {
    final dose = widget.dose;
    if (isMissed(dose, viewedDay: widget.day, today: widget.today)) {
      return _RowState.missed;
    }
    if (dose.status == DoseStatus.taken) return _RowState.taken;
    if (dose.status == DoseStatus.skipped) return _RowState.skipped;
    if (isOverdue(
      dose,
      viewingToday: widget.viewingToday,
      nowMinutes: widget.nowMinutes,
    )) {
      return _RowState.overdue;
    }
    return _RowState.pending;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final dose = widget.dose;
    final state = _resolveState();

    // The S4 row-state table, verbatim and exhaustive.
    final visual = switch (state) {
      _RowState.taken => (
          circleFill: BqColors.calm,
          circleBorder: BqColors.calm,
          glyph: '✓',
          glyphColor: BqColors.surface,
          nameColor: BqColors.textMuted,
          struck: true,
          rowFill: BqColors.surfaceAlt,
          rowBorder: BqColors.cardBorder,
        ),
      _RowState.skipped => (
          circleFill: BqColors.chip,
          circleBorder: BqColors.inputBorder,
          glyph: '−',
          glyphColor: BqColors.textSecondary,
          nameColor: BqColors.textMuted,
          struck: true,
          rowFill: BqColors.surfaceAlt,
          rowBorder: BqColors.cardBorder,
        ),
      // Overdue differs from pending by the row border alone — today only,
      // and `isOverdue` is what gates that.
      _RowState.overdue => (
          circleFill: BqColors.surface,
          circleBorder: BqColors.checkBorder,
          glyph: null,
          glyphColor: BqColors.ink,
          nameColor: BqColors.ink,
          struck: false,
          rowFill: BqColors.surface,
          rowBorder: BqColors.warnBorder,
        ),
      // A missed dose keeps the LIVE pending visual (DECIDED-3): no warn, no
      // strikethrough, no dead-grey name — marking it late is a legitimate
      // correction and the row stays tappable.
      _RowState.missed || _RowState.pending => (
          circleFill: BqColors.surface,
          circleBorder: BqColors.checkBorder,
          glyph: null,
          glyphColor: BqColors.ink,
          nameColor: BqColors.ink,
          struck: false,
          rowFill: BqColors.surface,
          rowBorder: BqColors.cardBorder,
        ),
    };

    final stateChip = switch (state) {
      _RowState.overdue => (l10n.overdueLabel, BqColors.warn, BqColors.warnBg),
      _RowState.skipped => (
          l10n.skippedLabel,
          BqColors.textSecondary,
          BqColors.chip,
        ),
      _RowState.missed => (
          l10n.notMarkedLabel,
          BqColors.textSecondary,
          BqColors.chip,
        ),
      _RowState.taken || _RowState.pending => null,
    };

    final position = doseCyclePosition(widget.dayDoses, dose);
    final chips = <Widget>[
      // Persistent chips first, in fixed order, then the state chip.
      if (position.m > 1)
        _RowChip(
          label: l10n.doseCycleChip(position.n, position.m),
          fg: BqColors.textSecondary,
          bg: BqColors.chip,
          mono: true,
        ),
      if (dose.supplement.note.isNotEmpty)
        _RowChip(
          label: dose.supplement.note,
          fg: BqColors.textSecondary,
          bg: BqColors.chip,
        ),
      if (stateChip != null)
        _RowChip(label: stateChip.$1, fg: stateChip.$2, bg: stateChip.$3),
    ];

    // Accessibility parity (DECIDED-2): every action the sheet offers is also
    // a labelled custom action here, filtered by the same transition table —
    // nothing on this row is reachable by gesture alone.
    final actions = <CustomSemanticsAction, VoidCallback>{
      if (dose.status != DoseStatus.taken)
        CustomSemanticsAction(label: l10n.markTaken): () =>
            _apply(DoseStatus.taken),
      if (dose.status != DoseStatus.skipped)
        CustomSemanticsAction(label: l10n.markSkipped): () =>
            _apply(DoseStatus.skipped),
      if (dose.status != DoseStatus.pending)
        CustomSemanticsAction(label: l10n.undoMark): () =>
            _apply(DoseStatus.pending),
    };

    return MergeSemantics(
      child: Semantics(
        container: true,
        customSemanticsActions: actions,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _onTap,
          onTapDown: (_) => setState(() => _pressed = true),
          onTapUp: (_) => setState(() => _pressed = false),
          onTapCancel: () => setState(() => _pressed = false),
          child: Container(
            // 13/14 row padding; the whole row is the tap target and is
            // >= 50px tall by construction (Interaction 8).
            padding: const EdgeInsetsDirectional.symmetric(
              vertical: 13,
              horizontal: 14,
            ),
            decoration: BoxDecoration(
              color: visual.rowFill,
              border: Border.all(
                color: _pressed ? BqColors.accentBorder : visual.rowBorder,
              ),
              borderRadius: BorderRadius.circular(BqRadii.doseRow),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _DoseCircle(
                  fill: visual.circleFill,
                  border: visual.circleBorder,
                  glyph: visual.glyph,
                  glyphColor: visual.glyphColor,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          // Both children flex, so no name and no amount can
                          // overflow the row however long they are — the name
                          // wraps instead, with no fixed width anywhere.
                          Flexible(
                            child: Text(
                              dose.supplement.name,
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w500,
                                height: 1.3,
                                color: visual.nameColor,
                                decoration: visual.struck
                                    ? TextDecoration.lineThrough
                                    : null,
                                decorationColor: visual.nameColor,
                              ),
                            ),
                          ),
                          if (dose.slot.doseLabel.isNotEmpty)
                            Flexible(
                              child: Padding(
                                padding: const EdgeInsetsDirectional.only(
                                  start: 7,
                                ),
                                child: Text(
                                  dose.slot.doseLabel,
                                  style: BqText.mono(
                                    size: 11.5,
                                    color: BqColors.textFaint,
                                    weight: FontWeight.w400,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      if (chips.isNotEmpty) ...[
                        const SizedBox(height: 7),
                        Wrap(spacing: 6, runSpacing: 6, children: chips),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The 24px state circle: 1.8px border, optional 12/600 glyph.
///
/// Not independently focusable — the row is one merged semantics target, and
/// this widget contributes no semantics of its own beyond its glyph text.
class _DoseCircle extends StatelessWidget {
  const _DoseCircle({
    required this.fill,
    required this.border,
    required this.glyph,
    required this.glyphColor,
  });

  final Color fill;
  final Color border;
  final String? glyph;
  final Color glyphColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: fill,
        border: Border.all(color: border, width: 1.8),
      ),
      child: glyph == null
          ? null
          : Text(
              glyph!,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: glyphColor,
              ),
            ),
    );
  }
}

/// A dose-row chip: radius `BqRadii.chip`, padding 4/7, mono for the numeral
/// chip and Instrument for the prose ones (UI-SPEC Typography).
class _RowChip extends StatelessWidget {
  const _RowChip({
    required this.label,
    required this.fg,
    required this.bg,
    this.mono = false,
  });

  final String label;
  final Color fg;
  final Color bg;
  final bool mono;

  @override
  Widget build(BuildContext context) {
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
        style: mono
            ? BqText.mono(size: 11, color: fg, weight: FontWeight.w400)
            : TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w400,
                color: fg,
              ),
      ),
    );
  }
}
