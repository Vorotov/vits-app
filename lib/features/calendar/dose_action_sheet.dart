/// Dose action sheet — the labelled alternative to the tap gesture
/// (plan 03-04, UI-SPEC S5, DECIDED-2).
///
/// This file NEVER writes and NEVER navigates. It resolves to a
/// [DoseSheetResult] — either a [DoseSheetMark] carrying the status `DoseRow`
/// should write, or a [DoseSheetOpenSchedule] asking `DoseRow` to push the
/// schedule editor — or to null when the sheet is dismissed. `DoseRow` then
/// acts, through the same guarded write path a tap uses, which is what keeps
/// the status write to exactly one call site in the whole app (T-03-12) and
/// now keeps the navigation to one too.
///
/// [DoseStatus] deliberately gained no member for the new outcome: it is a
/// domain enum persisted by Drift, and "the user wants to leave this screen"
/// has no business being representable in a column value. Hence a result type
/// of the sheet's own (quick task 261005-nc6).
///
/// The three MARK rows render only when valid for the row's current status,
/// per the DECIDED-2 transition table: no disabled row, no no-op row, and
/// nothing destructively styled — Phase 3 destroys nothing, every mark is
/// reversible. The schedule row is the one UNCONDITIONAL action here, because
/// unlike a mark it can never be a no-op: the destination exists whatever the
/// dose's status is. It sits last, behind a larger `BqSpace.md` gap, since the
/// mark rows answer "what happened to this dose" and this one leaves the
/// screen — the gap carries that split without introducing the separator rule
/// this sheet does not have.
library;

import 'package:flutter/material.dart';

import 'package:vitomy/core/domain/models.dart';
import 'package:vitomy/core/domain/repositories.dart';
import 'package:vitomy/core/l10n/clock_format.dart';
import 'package:vitomy/core/l10n/l10n.dart';
import 'package:vitomy/core/theme/theme.dart';
import 'package:vitomy/core/theme/tokens.dart';

/// What the sheet resolved to. Sealed, so `DoseRow` switches exhaustively and
/// a future action cannot be added here without the call site noticing.
sealed class DoseSheetResult {
  const DoseSheetResult();
}

/// The user chose a mark: `DoseRow` writes [status] through its single gate.
final class DoseSheetMark extends DoseSheetResult {
  const DoseSheetMark(this.status);

  /// The target status, derived by the sheet from the CURRENTLY rendered one.
  final DoseStatus status;
}

/// The user asked for this supplement's dosing schedule: `DoseRow` navigates.
/// Carries no payload — the row already holds the supplement.
final class DoseSheetOpenSchedule extends DoseSheetResult {
  const DoseSheetOpenSchedule();
}

/// Opens the dose action sheet for [dose] and resolves to what the user chose,
/// or null when the sheet is dismissed without choosing.
Future<DoseSheetResult?> showDoseActionSheet(
  BuildContext context,
  DayDose dose,
) {
  // Phase-2 `bottomSheetTheme` supplies the paper fill, the sheet radius and
  // the scrim barrier — reused unchanged, no new sub-theme (UI-SPEC).
  return showModalBottomSheet<DoseSheetResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: BqColors.paper,
    builder: (_) => _DoseActionSheet(dose: dose),
  );
}

class _DoseActionSheet extends StatelessWidget {
  const _DoseActionSheet({required this.dose});

  final DayDose dose;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    // Through the app's single clock formatter, so this sheet and the row it
    // was opened from can never print the same dose time differently.
    final time = formatClock(context, dose.slot.minutesFromMidnight);

    return SafeArea(
      top: false,
      child: Padding(
        // Phase-2 sheet padding, verbatim.
        padding: const EdgeInsetsDirectional.only(
          top: 10,
          start: 20,
          end: 20,
          bottom: 26,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: BqColors.dragHandle,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: BqSpace.md),
            // The title is DATA — the supplement's own name, not a key.
            Text(
              dose.supplement.name,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: BqColors.ink,
              ),
            ),
            const SizedBox(height: BqSpace.xs),
            Text(
              // The dose label is optional and often empty, so the separator
              // is part of the STRING, not of the layout: interpolating an
              // empty label left "08:00 · " with a dangling middle dot on the
              // sheet while the row guarded exactly this case (WR-07).
              dose.slot.doseLabel.isEmpty
                  ? l10n.doseSheetSubtitleTimeOnly(time)
                  : l10n.doseSheetSubtitle(time, dose.slot.doseLabel),
              style: BqText.mono(
                size: 11.5,
                color: BqColors.textMuted,
                weight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: BqSpace.md),
            // DECIDED-2 sheet columns. A row that would be a no-op is absent,
            // never present-and-disabled.
            if (dose.status != DoseStatus.taken)
              _SheetAction(
                label: l10n.markTaken,
                result: const DoseSheetMark(DoseStatus.taken),
              ),
            if (dose.status != DoseStatus.skipped) ...[
              if (dose.status != DoseStatus.taken)
                const SizedBox(height: BqSpace.sm),
              _SheetAction(
                label: l10n.markSkipped,
                result: const DoseSheetMark(DoseStatus.skipped),
              ),
            ],
            if (dose.status != DoseStatus.pending) ...[
              const SizedBox(height: BqSpace.sm),
              _SheetAction(
                label: l10n.undoMark,
                result: const DoseSheetMark(DoseStatus.pending),
              ),
            ],
            // Unconditional, and last: see the library doc comment. The wider
            // gap is the only thing marking the change of intent — no rule,
            // no heading.
            const SizedBox(height: BqSpace.md),
            _SheetAction(
              label: l10n.openSchedule,
              result: const DoseSheetOpenSchedule(),
            ),
          ],
        ),
      ),
    );
  }
}

/// One sheet action: 14/600 ink, >= 48px tall, no separator rule.
///
/// Popping with [result] is all it does — the write, or the navigation, both
/// happen in `DoseRow`. One widget for all four rows, so the tap target and
/// the RTL alignment cannot differ between them.
class _SheetAction extends StatelessWidget {
  const _SheetAction({required this.label, required this.result});

  final String label;
  final DoseSheetResult result;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.of(context).pop(result),
      child: Container(
        constraints: const BoxConstraints(minHeight: 48),
        alignment: AlignmentDirectional.centerStart,
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: BqColors.ink,
          ),
        ),
      ),
    );
  }
}
