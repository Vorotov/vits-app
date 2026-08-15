/// One materialized dose row — the app's ONLY `setStatus` call site
/// (plan 03-04, UI-SPEC S4 row table).
///
/// Promoted out of `calendar_screen.dart` so the block sections can construct
/// it; the five exhaustive visual states, the chip stack and the action-sheet
/// gesture land in Task 2 of this plan. The tap contract and the in-flight
/// guard are carried over unchanged from the tracer slice.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:boostque/core/domain/models.dart';
import 'package:boostque/core/domain/repositories.dart';
import 'package:boostque/core/providers.dart';
import 'package:boostque/core/theme/theme.dart';
import 'package:boostque/core/theme/tokens.dart';

/// A single dose row: tap toggles `pending <-> taken`.
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

  /// The whole day's dose list — the `доза n з m` denominator source (PF-6).
  final List<DayDose> dayDoses;

  /// The resolved day being rendered.
  final DateTime day;

  /// The app's single clock day.
  final DateTime today;

  /// Whether [day] is [today].
  final bool viewingToday;

  /// Minutes since local midnight.
  final int nowMinutes;

  @override
  ConsumerState<DoseRow> createState() => _DoseRowState();
}

class _DoseRowState extends ConsumerState<DoseRow> {
  /// In-flight guard (PF-4 / the CR-01 lesson): while this row's write is
  /// pending it swallows further gestures, so a rapid double tap ends
  /// deterministically at `taken` instead of oscillating back to `pending`.
  bool _busy = false;

  Future<void> _apply(DoseStatus next) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ref.read(intakeRepoProvider).setStatus(widget.dose.logId, next);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// The tap transition (DECIDED-2), computed from the CURRENTLY rendered
  /// status — never from a value captured earlier (PF-4).
  Future<void> _onTap() => _apply(
        widget.dose.status == DoseStatus.taken
            ? DoseStatus.pending
            : DoseStatus.taken,
      );

  @override
  Widget build(BuildContext context) {
    final taken = widget.dose.status == DoseStatus.taken;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _onTap,
      child: Container(
        // 13/14 row padding (UI-SPEC S4 row anatomy).
        padding: const EdgeInsetsDirectional.symmetric(
          vertical: 13,
          horizontal: 14,
        ),
        decoration: BoxDecoration(
          color: BqColors.surface,
          border: Border.all(color: BqColors.cardBorder),
          borderRadius: BorderRadius.circular(BqRadii.doseRow),
        ),
        child: Row(
          children: [
            // 24px check circle; filled `calm` once taken (UI-SPEC S4).
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: taken ? BqColors.calm : BqColors.surface,
                border: Border.all(
                  color: taken ? BqColors.calm : BqColors.checkBorder,
                  width: 1.8,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                widget.dose.supplement.name,
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w500,
                  height: 1.3,
                  color: BqColors.ink,
                ),
              ),
            ),
            if (widget.dose.slot.doseLabel.isNotEmpty) ...[
              const SizedBox(width: 7),
              Text(
                widget.dose.slot.doseLabel,
                style: BqText.mono(
                  size: 11.5,
                  color: BqColors.textFaint,
                  weight: FontWeight.w400,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
