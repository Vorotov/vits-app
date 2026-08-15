/// Calendar tab — Phase-3 tracer slice (plan 03-01, UI-SPEC S4).
///
/// This slice renders exactly one proven path end-to-end: the resolved day
/// flows into [dayDosesProvider], which materializes that day's IntakeLog rows
/// and streams them back; each dose renders as a tappable row whose tap
/// persists `taken` (and, tapped again, `pending`) through
/// `IntakeRepository.setStatus`, with the stream — never local optimistic
/// state — driving the re-render (Interaction Contracts 1/3).
///
/// Deliberately NOT here, owned by later plans: the day-progress ring and
/// header subtitle (03-02), the week strip and day browsing (03-03), the
/// mockup-exact row anatomy, time blocks, chips and the action sheet (03-04),
/// and the empty/error surfaces plus the disclaimer (03-05).
///
/// The clock is never read in this file: the day comes from
/// [resolvedDayProvider], which follows the app's single clock source
/// `todayProvider` (03-01, IN-06).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:boostque/core/domain/models.dart';
import 'package:boostque/core/domain/repositories.dart';
import 'package:boostque/core/l10n/l10n.dart';
import 'package:boostque/core/providers.dart';
import 'package:boostque/core/theme/theme.dart';
import 'package:boostque/core/theme/tokens.dart';
import 'package:boostque/features/calendar/calendar_providers.dart';

/// The Calendar screen ("Сьогодні", mockup screen 02, UI-SPEC S4).
class CalendarScreen extends ConsumerWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final doses = ref.watch(dayDosesProvider(ref.watch(resolvedDayProvider)));
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
            Text(
              l10n.calendarTitleToday,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            ...doses.when(
              data: (list) => <Widget>[
                for (final (i, dose) in list.indexed) ...[
                  // 7px between rows (UI-SPEC S4); the first row clears the
                  // heading.
                  SizedBox(height: i == 0 ? BqSpace.md : 7),
                  _DoseRow(dose: dose),
                ],
              ],
              // Loading: empty list area, NO spinner — the local-DB stream
              // resolves within a frame and a spinner would flash.
              loading: () => const <Widget>[],
              // The documented error surface (`dayLoadError` + retry) is owned
              // by plan 03-05; rendering nothing is the interim state.
              error: (_, _) => const <Widget>[SizedBox.shrink()],
            ),
          ],
        ),
      ),
    );
  }
}

/// One materialized dose: tap toggles `pending <-> taken`.
///
/// The mockup-exact row anatomy (`BqRadii.doseRow`, chips, strike-through,
/// skipped/missed/overdue states) arrives in plan 03-04; this slice carries
/// the tap contract and token-only placeholder decoration.
class _DoseRow extends ConsumerStatefulWidget {
  const _DoseRow({required this.dose});

  final DayDose dose;

  @override
  ConsumerState<_DoseRow> createState() => _DoseRowState();
}

class _DoseRowState extends ConsumerState<_DoseRow> {
  /// In-flight guard (PF-4 / the CR-01 lesson): while this row's `setStatus`
  /// write is pending it swallows further gestures, so a rapid double tap ends
  /// deterministically at `taken` instead of oscillating back to `pending`.
  bool _busy = false;

  Future<void> _toggle() async {
    if (_busy) return;
    // `next` is computed from the CURRENTLY rendered status, never from a
    // value captured earlier (PF-4).
    final next = widget.dose.status == DoseStatus.taken
        ? DoseStatus.pending
        : DoseStatus.taken;
    setState(() => _busy = true);
    try {
      await ref.read(intakeRepoProvider).setStatus(widget.dose.logId, next);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final taken = widget.dose.status == DoseStatus.taken;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _toggle,
      child: Container(
        // 13/14 row padding (UI-SPEC S4 row anatomy).
        padding: const EdgeInsetsDirectional.fromSTEB(14, 13, 14, 13),
        decoration: BoxDecoration(
          color: BqColors.surface,
          border: Border.all(color: BqColors.cardBorder),
          borderRadius: BorderRadius.circular(BqRadii.card),
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
                  color: taken ? BqColors.calm : BqColors.inputBorder,
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
                  color: BqColors.ink,
                ),
              ),
            ),
            if (widget.dose.slot.doseLabel.isNotEmpty) ...[
              const SizedBox(width: 7),
              Text(
                widget.dose.slot.doseLabel,
                style: BqText.mono(size: 11.5, color: BqColors.textFaint),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
