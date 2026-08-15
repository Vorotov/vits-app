/// Dose action sheet — the labelled alternative to the tap gesture
/// (plan 03-04, UI-SPEC S5, DECIDED-2).
///
/// This file NEVER writes. It returns the chosen [DoseStatus] (or null when
/// dismissed) and `DoseRow` applies it through the same guarded write path a
/// tap uses — which is what keeps the status write to exactly one call site in
/// the whole app (T-03-12).
///
/// Only actions that are valid for the row's current status are rendered, per
/// the DECIDED-2 transition table: no disabled row, no no-op row, and nothing
/// destructively styled — Phase 3 destroys nothing, every mark is reversible.
library;

import 'package:flutter/material.dart';

import 'package:boostque/core/domain/models.dart';
import 'package:boostque/core/domain/repositories.dart';
import 'package:boostque/core/l10n/l10n.dart';
import 'package:boostque/core/theme/theme.dart';
import 'package:boostque/core/theme/tokens.dart';

/// Opens the dose action sheet for [dose] and resolves to the status the user
/// chose, or null when the sheet is dismissed without choosing.
Future<DoseStatus?> showDoseActionSheet(BuildContext context, DayDose dose) {
  // Phase-2 `bottomSheetTheme` supplies the paper fill, the sheet radius and
  // the scrim barrier — reused unchanged, no new sub-theme (UI-SPEC).
  return showModalBottomSheet<DoseStatus>(
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
    final tod = TimeOfDay(
      hour: dose.slot.minutesFromMidnight ~/ 60,
      minute: dose.slot.minutesFromMidnight % 60,
    );
    final time = MaterialLocalizations.of(context)
        .formatTimeOfDay(tod, alwaysUse24HourFormat: true);

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
              l10n.doseSheetSubtitle(time, dose.slot.doseLabel),
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
              _SheetAction(label: l10n.markTaken, result: DoseStatus.taken),
            if (dose.status != DoseStatus.skipped) ...[
              if (dose.status != DoseStatus.taken)
                const SizedBox(height: BqSpace.sm),
              _SheetAction(label: l10n.markSkipped, result: DoseStatus.skipped),
            ],
            if (dose.status != DoseStatus.pending) ...[
              const SizedBox(height: BqSpace.sm),
              _SheetAction(label: l10n.undoMark, result: DoseStatus.pending),
            ],
          ],
        ),
      ),
    );
  }
}

/// One sheet action: 14/600 ink, >= 48px tall, no separator rule.
///
/// Popping with [result] is all it does — the write happens in `DoseRow`.
class _SheetAction extends StatelessWidget {
  const _SheetAction({required this.label, required this.result});

  final String label;
  final DoseStatus result;

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
