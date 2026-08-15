/// Regimen editor screen (plan 02-04, mockup screen 05, UI-SPEC S3).
///
/// A thin view over the tested wave-2 [RegimenEditorController]: every
/// interaction mutates the already-tested `RegimenDraft` — this file is
/// layout + wiring + copy, not logic.
///
/// Invariants honored here:
/// - PF-2: every `showDatePicker` result is normalized with [dateOnly]
///   BEFORE it reaches the controller.
/// - PF-3: 24-hour time on BOTH sides — the picker is wrapped in a
///   `MediaQuery(alwaysUse24HourFormat: true)` builder and the slot-row
///   display uses `formatTimeOfDay(..., alwaysUse24HourFormat: true)`.
/// - PF-5: read-only supplement header — no dropdown.
/// - P-9: the 28-bar preview strip derives from [isActiveOn] over a
///   throwaway draft Regimen; no second modular-math implementation.
/// - UI-SPEC #12: slot count clamped 1–6 by construction (disabled controls,
///   never hidden); course end unpickable before start (`firstDate`).
/// - UI-SPEC #18: the body is ONE scroll view; the footer is pinned via
///   `bottomNavigationBar` and never scrolls away.
/// - D-07 token-only styling: no raw color literals; the only hardcoded
///   pixel values are the mockup-exact overrides enumerated in 02-UI-SPEC.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:boostque/core/domain/cycle_math.dart';
import 'package:boostque/core/domain/models.dart';
import 'package:boostque/core/domain/repositories.dart';
import 'package:boostque/core/l10n/l10n.dart';
import 'package:boostque/core/providers.dart';
import 'package:boostque/core/theme/theme.dart';
import 'package:boostque/core/theme/tokens.dart';
import 'package:boostque/core/widgets/bq_segmented.dart';
import 'package:boostque/features/stack/regimen_editor_controller.dart';

/// The Dosing Schedule editor for one supplement (REGI-01..04, STACK-04).
class RegimenEditorScreen extends ConsumerWidget {
  const RegimenEditorScreen({super.key, required this.supplementId});

  /// The supplement whose regimen is edited (family arg, P-5).
  final String supplementId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(regimenEditorProvider(supplementId));
    final controller = ref.read(regimenEditorProvider(supplementId).notifier);
    final l10n = context.l10n;

    // Read-only supplement context header (PF-5: no dropdown). The stack
    // graph is warm when the editor opens; while it streams in, the header
    // simply waits — no loading UI is invented (UI-SPEC #17).
    StackEntry? entry;
    if (ref.watch(stackEntriesProvider)
        case AsyncData(value: final List<StackEntry> list)) {
      for (final e in list) {
        if (e.supplement.id == supplementId) entry = e;
      }
    }

    final canAdd = draft.slots.length < RegimenEditorController.maxSlots;
    final canRemove = draft.slots.length > RegimenEditorController.minSlots;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _TopBar(paused: draft.paused),
            Expanded(
              // ONE scroll view above the pinned footer (UI-SPEC #18).
              child: SingleChildScrollView(
                padding: const EdgeInsetsDirectional.only(
                  // Mockup-exact editor body padding (UI-SPEC S3).
                  start: 20,
                  end: 20,
                  top: 18,
                  bottom: BqSpace.lg,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (entry != null) ...[
                      Text(
                        entry.supplement.name,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          height: 1.3,
                          color: BqColors.ink,
                        ),
                      ),
                      if (entry.supplement.doseText.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          entry.supplement.doseText,
                          style: const TextStyle(
                            fontSize: 12,
                            height: 1.5,
                            color: BqColors.textMuted,
                          ),
                        ),
                      ],
                      // Section gap (editor) — mockup-exact 22px.
                      const SizedBox(height: 22),
                    ],
                    _Eyebrow(text: l10n.periodicityLabel),
                    const SizedBox(height: 11),
                    BqSegmented(
                      labels: [l10n.cyclicTab, l10n.courseTab],
                      selectedIndex: draft.kind == RegimenKind.cyclic ? 0 : 1,
                      onChanged: (i) => controller.setKind(
                        i == 0 ? RegimenKind.cyclic : RegimenKind.course,
                      ),
                    ),
                    const SizedBox(height: 11),
                    _PeriodicityPanel(
                      draft: draft,
                      controller: controller,
                      supplementId: supplementId,
                    ),
                    const SizedBox(height: 22),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        _Eyebrow(text: l10n.timeSlotsLabel),
                        const Spacer(),
                        Text(
                          l10n.slotsPerDay(draft.slots.length),
                          style: BqText.mono(
                            size: 11,
                            color: BqColors.textFaint,
                            weight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 11),
                    for (final (i, slot) in draft.slots.indexed) ...[
                      if (i > 0) const SizedBox(height: 7),
                      _SlotRow(
                        index: i,
                        slot: slot,
                        canRemove: canRemove,
                        controller: controller,
                      ),
                    ],
                    const SizedBox(height: BqSpace.sm),
                    _AddSlotButton(canAdd: canAdd, controller: controller),
                    const SizedBox(height: 11),
                    Text(
                      _intervalText(l10n, draft.slots),
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.5,
                        color: BqColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _EditorFooter(
        draft: draft,
        controller: controller,
        supplementName: entry?.supplement.name ?? '',
      ),
    );
  }

  /// Neutral interval helper: smallest gap between adjacent sorted slots
  /// (UI-SPEC D8 — no absorption/mineral advice).
  static String _intervalText(AppLocalizations l10n, List<DraftSlot> slots) {
    if (slots.length < 2) return l10n.slotIntervalSingle;
    var smallest = 1440;
    for (var i = 1; i < slots.length; i++) {
      final gap =
          slots[i].minutesFromMidnight - slots[i - 1].minutesFromMidnight;
      if (gap < smallest) smallest = gap;
    }
    return l10n.slotIntervalNote(smallest ~/ 60, smallest % 60);
  }
}

/// Editor top bar: back chevron, title, trailing НА ПАУЗІ badge when paused,
/// hairline bottom border (UI-SPEC S3).
class _TopBar extends StatelessWidget {
  const _TopBar({required this.paused});

  final bool paused;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: BqColors.hairline)),
      ),
      padding: const EdgeInsetsDirectional.only(
        start: BqSpace.sm,
        end: 20,
        top: BqSpace.xs,
        bottom: BqSpace.xs,
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.maybePop(context),
            icon: const Icon(
              Icons.arrow_back_ios_new,
              size: 18,
              color: BqColors.textSecondary,
            ),
          ),
          Expanded(
            // Flexible, not fixed-width: the trailing badge keeps its
            // intrinsic size and the title yields — never a Row overflow.
            child: Text(
              l10n.scheduleTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                height: 1.0,
                color: BqColors.ink,
              ),
            ),
          ),
          if (paused)
            Container(
              padding: const EdgeInsetsDirectional.symmetric(
                vertical: 6,
                horizontal: 8,
              ),
              decoration: const BoxDecoration(
                color: BqColors.chip,
                borderRadius: BorderRadius.all(Radius.circular(BqRadii.chip)),
              ),
              child: Text(
                l10n.pausedBadge,
                style: BqText.mono(
                  size: 9.5,
                  color: BqColors.textSecondary,
                  letterSpacing: 0.38,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Mono eyebrow label (ПЕРІОДИЧНІСТЬ / ЧАС ПРИЙОМУ).
class _Eyebrow extends StatelessWidget {
  const _Eyebrow({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: BqText.mono(
        size: 10.5,
        color: BqColors.textMuted,
        letterSpacing: 0.63,
      ),
    );
  }
}

/// The surface panel: date fields + sliders (cyclic) or start/end date
/// fields (course), followed by the 28-bar preview strip and summary.
class _PeriodicityPanel extends StatelessWidget {
  const _PeriodicityPanel({
    required this.draft,
    required this.controller,
    required this.supplementId,
  });

  final RegimenDraft draft;
  final RegimenEditorController controller;
  final String supplementId;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Container(
      width: double.infinity,
      // Mockup-exact panel padding 17 (UI-SPEC spacing override).
      padding: const EdgeInsetsDirectional.all(17),
      decoration: BoxDecoration(
        color: BqColors.surface,
        border: Border.all(color: BqColors.cardBorder),
        borderRadius: const BorderRadius.all(Radius.circular(BqRadii.panel)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (draft.kind == RegimenKind.cyclic) ...[
            _DateField(
              label: l10n.startLabel,
              date: draft.startDate,
              firstDate: DateTime(2020),
              onPicked: controller.setStartDate,
            ),
            const SizedBox(height: BqSpace.md),
            _SliderRow(
              label: l10n.cycleLength,
              valueLabel: l10n.weeksCount(draft.onDays ~/ 7),
              value: draft.onDays.toDouble(),
              min: 7,
              max: 112,
              divisions: 15,
              onChanged: (v) => controller.setOnDays(v.round()),
            ),
            const SizedBox(height: 14),
            _SliderRow(
              label: l10n.breakLabel,
              valueLabel: draft.offDays == 0
                  ? l10n.noBreak
                  : l10n.weeksCount(draft.offDays ~/ 7),
              value: draft.offDays.toDouble(),
              min: 0,
              max: 84,
              divisions: 12,
              onChanged: (v) => controller.setOffDays(v.round()),
            ),
          ] else
            Row(
              children: [
                Expanded(
                  child: _DateField(
                    label: l10n.startLabel,
                    date: draft.startDate,
                    firstDate: DateTime(2020),
                    onPicked: controller.setStartDate,
                  ),
                ),
                // Mockup-exact 9px gap between Старт and Кінець.
                const SizedBox(width: 9),
                Expanded(
                  child: _DateField(
                    label: l10n.endLabel,
                    date: draft.endDate ?? draft.startDate,
                    // E-6/V-1: the end date is unpickable before the start.
                    firstDate: draft.startDate,
                    onPicked: controller.setEndDate,
                  ),
                ),
              ],
            ),
          const SizedBox(height: BqSpace.md),
          _CyclePreviewStrip(draft: draft, supplementId: supplementId),
          const SizedBox(height: 10),
          Text(
            _summaryText(l10n, context),
            style: const TextStyle(
              fontSize: 12,
              height: 1.5,
              color: BqColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  String _summaryText(AppLocalizations l10n, BuildContext context) {
    if (draft.kind == RegimenKind.cyclic) {
      final on = l10n.weeksCount(draft.onDays ~/ 7);
      return draft.offDays == 0
          ? l10n.cycleSummaryCyclicNoBreak(on)
          : l10n.cycleSummaryCyclic(on, l10n.weeksCount(draft.offDays ~/ 7));
    }
    return l10n.courseSummaryRange(
      _formatDate(context, draft.startDate),
      _formatDate(context, draft.endDate ?? draft.startDate),
    );
  }
}

/// Locale-aware date rendering (uk `14.08.2026` — UI-SPEC i18n rules).
String _formatDate(BuildContext context, DateTime date) =>
    DateFormat.yMd(Localizations.localeOf(context).toString()).format(date);

/// Label + tappable value box opening `showDatePicker`; the picked value is
/// normalized with [dateOnly] BEFORE reaching the controller (PF-2).
class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.date,
    required this.firstDate,
    required this.onPicked,
  });

  final String label;
  final DateTime date;
  final DateTime firstDate;
  final ValueChanged<DateTime> onPicked;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11.5, color: BqColors.textMuted),
        ),
        const SizedBox(height: 7),
        GestureDetector(
          onTap: () => _pick(context),
          child: Container(
            width: double.infinity,
            // Mockup-exact date-field padding 12/13 (UI-SPEC S3).
            padding: const EdgeInsetsDirectional.symmetric(
              vertical: 12,
              horizontal: 13,
            ),
            decoration: BoxDecoration(
              border: Border.all(color: BqColors.inputBorder),
              borderRadius:
                  const BorderRadius.all(Radius.circular(BqRadii.input)),
            ),
            child: Text(
              _formatDate(context, date),
              style: BqText.mono(
                size: 14,
                color: BqColors.ink,
                letterSpacing: 0,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _pick(BuildContext context) async {
    final lastDate = DateTime(2035);
    // initialDate must lie within first/last or the picker asserts (PF-2).
    var initial = date;
    if (initial.isBefore(firstDate)) initial = firstDate;
    if (initial.isAfter(lastDate)) initial = lastDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: firstDate,
      lastDate: lastDate,
    );
    // Normalize IMMEDIATELY at receipt — pickers return LOCAL DateTimes
    // (PF-2); the draft only ever holds UTC date-only values.
    if (picked != null) onPicked(dateOnly(picked));
  }
}

/// Slider row: label 13/400 ink + mono 13/500 accent value, slider below.
class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.label,
    required this.valueLabel,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
  });

  final String label;
  final String valueLabel;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 13, color: BqColors.ink),
            ),
            const Spacer(),
            Text(
              valueLabel,
              style: BqText.mono(
                size: 13,
                color: BqColors.accent,
                letterSpacing: 0,
              ),
            ),
          ],
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: divisions,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

/// The 28-bar cycle preview strip (E4/UI-SPEC #14): bar `i` samples day
/// `start + i*4` through [isActiveOn] on a throwaway draft Regimen with
/// `paused: false` — never a second modular-math implementation (P-9).
class _CyclePreviewStrip extends StatelessWidget {
  const _CyclePreviewStrip({required this.draft, required this.supplementId});

  /// Number of bars — fixed for both modes (mockup lines 528-531).
  static const int barCount = 28;

  final RegimenDraft draft;
  final String supplementId;

  @override
  Widget build(BuildContext context) {
    final preview = Regimen(
      id: 'preview',
      supplementId: supplementId,
      kind: draft.kind,
      startDate: draft.startDate,
      endDate: draft.kind == RegimenKind.course ? draft.endDate : null,
      onDays: draft.onDays,
      offDays: draft.offDays,
      paused: false,
      slots: const [],
    );
    return Row(
      children: [
        for (var i = 0; i < barCount; i++) ...[
          if (i > 0) const SizedBox(width: 2),
          Expanded(
            child: Container(
              key: ValueKey('cycle-preview-bar-$i'),
              height: 8,
              decoration: BoxDecoration(
                color: isActiveOn(
                  preview,
                  draft.startDate.add(Duration(days: i * 4)),
                )
                    ? BqColors.accent
                    : BqColors.field,
                borderRadius: const BorderRadius.all(Radius.circular(2)),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// One time-slot row: tappable 24-h time, inline dose-label input, and the
/// minus control (disabled — never hidden — at the 1-slot floor).
class _SlotRow extends StatelessWidget {
  const _SlotRow({
    required this.index,
    required this.slot,
    required this.canRemove,
    required this.controller,
  });

  final int index;
  final DraftSlot slot;
  final bool canRemove;
  final RegimenEditorController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tod = TimeOfDay(
      hour: slot.minutesFromMidnight ~/ 60,
      minute: slot.minutesFromMidnight % 60,
    );
    // 24-h display, matching the picker's convention (PF-3).
    final timeText = MaterialLocalizations.of(context)
        .formatTimeOfDay(tod, alwaysUse24HourFormat: true);
    return Container(
      // Mockup-exact slot-row padding 11/13 (UI-SPEC spacing override).
      padding: const EdgeInsetsDirectional.symmetric(
        vertical: 11,
        horizontal: 13,
      ),
      decoration: BoxDecoration(
        color: BqColors.surface,
        border: Border.all(color: BqColors.cardBorder),
        borderRadius: const BorderRadius.all(Radius.circular(BqRadii.button)),
      ),
      child: Row(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _pickTime(context, tod),
            child: Text(
              timeText,
              style: BqText.mono(
                size: 15,
                color: BqColors.ink,
                letterSpacing: 0,
              ),
            ),
          ),
          const SizedBox(width: 11),
          Flexible(
            fit: FlexFit.tight,
            // The input itself scrolls horizontally on one line — no fixed
            // width, no ellipsis on the editable field (UI-SPEC #20).
            child: TextFormField(
              key: ValueKey('slot-dose-$index-${slot.minutesFromMidnight}'),
              initialValue: slot.doseLabel,
              onChanged: (v) => controller.setSlotDoseLabel(index, v),
              maxLines: 1,
              textCapitalization: TextCapitalization.sentences,
              keyboardType: TextInputType.text,
              textInputAction: TextInputAction.done,
              style: const TextStyle(
                fontSize: 12.5,
                color: BqColors.textMuted,
              ),
              decoration: const InputDecoration(
                border: InputBorder.none,
                filled: false,
                isDense: true,
                contentPadding: EdgeInsetsDirectional.zero,
              ),
            ),
          ),
          const SizedBox(width: 11),
          Semantics(
            button: true,
            enabled: canRemove,
            label: l10n.removeSlot(timeText),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: canRemove ? () => controller.removeSlot(index) : null,
              // Padded hit target >= 44px around the 28px visual circle
              // (UI-SPEC Interaction Contract 6).
              child: SizedBox(
                width: 44,
                height: 44,
                child: Center(
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: const BoxDecoration(
                      color: BqColors.chip,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '−',
                        style: TextStyle(
                          fontSize: 16,
                          height: 1.0,
                          color: canRemove
                              ? BqColors.textMuted
                              : BqColors.iconDisabled,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickTime(BuildContext context, TimeOfDay current) async {
    final tod = await showTimePicker(
      context: context,
      initialTime: current,
      // One 24-h convention on both picker and display (PF-3).
      builder: (ctx, child) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (tod != null) controller.setSlotTime(index, tod.hour * 60 + tod.minute);
  }
}

/// "+ Додати слот часу" dashed button; hard-disabled (never hidden) at the
/// 6-slot cap (UI-SPEC #12).
class _AddSlotButton extends StatelessWidget {
  const _AddSlotButton({required this.canAdd, required this.controller});

  final bool canAdd;
  final RegimenEditorController controller;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: canAdd,
      child: GestureDetector(
        onTap: canAdd ? controller.addSlot : null,
        child: CustomPaint(
          painter: _DashedBorderPainter(
            color: canAdd ? BqColors.accentBorder : BqColors.hairline,
          ),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsetsDirectional.symmetric(vertical: 12),
            child: Center(
              child: Text(
                context.l10n.addTimeSlot,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                  height: 1.0,
                  color: canAdd ? BqColors.accent : BqColors.textDisabled,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 1px dashed rounded-rect border (mockup line 549).
class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Offset.zero & size,
          const Radius.circular(BqRadii.button),
        ),
      );
    const dash = 5.0;
    const gap = 4.0;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(metric.extractPath(distance, distance + dash), paint);
        distance += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// Pinned editor footer: save, pause/resume, confirmed delete, save hint
/// (UI-SPEC S3 footer contract; Interaction Contracts 5 and 7).
///
/// Together with the top-bar badge, the save-button label, the pause-button
/// label, and the save hint flip as ONE paused state (UI-SPEC #13). Видалити
/// never deletes directly — its only direct effect is opening the
/// confirmation dialog; the cascade call lives solely in the dialog's
/// confirm handler (UI-SPEC #19, threat T-02-04).
class _EditorFooter extends StatefulWidget {
  const _EditorFooter({
    required this.draft,
    required this.controller,
    required this.supplementName,
  });

  final RegimenDraft draft;
  final RegimenEditorController controller;
  final String supplementName;

  @override
  State<_EditorFooter> createState() => _EditorFooterState();
}

class _EditorFooterState extends State<_EditorFooter> {
  /// In-flight save guard (CR-01): while a save runs, the button is
  /// disabled AND [_save] short-circuits re-entry, so a double tap can
  /// neither race two `save()` calls (PF-8 ghost-regimen threat T-02-05)
  /// nor run `Navigator.maybePop` twice under the exit transition.
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final draft = widget.draft;
    return Container(
      decoration: const BoxDecoration(
        color: BqColors.surfaceAlt,
        border: Border(top: BorderSide(color: BqColors.hairline)),
      ),
      padding: EdgeInsetsDirectional.only(
        top: 12,
        bottom: 12 + MediaQuery.paddingOf(context).bottom,
        start: 20,
        end: 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Row 1: the primary save button — the one always-visible accent
          // fill; radius 13 is the mockup-exact non-token override.
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: BqColors.accent,
                foregroundColor: BqColors.surface,
                overlayColor: BqColors.accentPressed,
                padding: const EdgeInsetsDirectional.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
                textStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onPressed: _saving ? null : () => _save(context),
              child: Text(
                draft.paused ? l10n.saveWhilePaused : l10n.saveAndStart,
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Row 2: pause/resume secondary + delete destructive.
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: _outlinedStyle(
                    foreground: BqColors.ink,
                    border: BqColors.inputBorder,
                    pressed: BqColors.chip,
                  ),
                  onPressed: widget.controller.togglePause,
                  child: Text(draft.paused ? l10n.resume : l10n.pause),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  style: _outlinedStyle(
                    foreground: BqColors.risk,
                    border: BqColors.riskBorder,
                    pressed: BqColors.riskBg,
                  ),
                  // Opening the dialog is this button's ONLY direct effect
                  // (UI-SPEC #19).
                  onPressed: () => _confirmDelete(context),
                  child: Text(l10n.delete),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            draft.paused
                ? l10n.saveHintPaused
                : l10n.saveHintActive(_hintDate(context)),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 11,
              height: 1.45,
              color: BqColors.textFaint,
            ),
          ),
        ],
      ),
    );
  }

  /// Shared outlined-button shape (surface fill, 1px border, 13.5/600,
  /// pressed overlay per Interaction Contract 7).
  static ButtonStyle _outlinedStyle({
    required Color foreground,
    required Color border,
    required Color pressed,
  }) {
    return OutlinedButton.styleFrom(
      backgroundColor: BqColors.surface,
      foregroundColor: foreground,
      overlayColor: pressed,
      side: BorderSide(color: border),
      padding: const EdgeInsetsDirectional.symmetric(vertical: 13),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(BqRadii.button),
      ),
      textStyle: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
    );
  }

  /// Locale-aware "14 серпня"-style date for the active save hint.
  String _hintDate(BuildContext context) => DateFormat.MMMMd(
        Localizations.localeOf(context).toString(),
      ).format(widget.draft.startDate);

  /// Persists the draft through the tested controller, then leaves the
  /// editor (the controller reuses the regimen id — PF-8). Guarded against
  /// double activation (CR-01).
  Future<void> _save(BuildContext context) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await widget.controller.save();
    } catch (_) {
      // Re-enable the button so the user can retry.
      if (mounted) setState(() => _saving = false);
      rethrow;
    }
    // Success: _saving stays true through the pop so a late tap can never
    // trigger a second maybePop underneath the exit transition.
    if (context.mounted) await Navigator.of(context).maybePop();
  }

  /// The REQUIRED confirmation gate in front of the soft-delete cascade
  /// (threat T-02-04). Cancel/dismiss returns to the editor unchanged; only
  /// the dialog's confirm handler calls [RegimenEditorController.deleteSupplement].
  Future<void> _confirmDelete(BuildContext context) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.deleteConfirmTitle(widget.supplementName)),
        content: Text(l10n.deleteConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: BqColors.risk,
              overlayColor: BqColors.riskBg,
            ),
            onPressed: () async {
              // The cascade call lives here and ONLY here (UI-SPEC #19).
              await widget.controller.deleteSupplement();
              if (dialogContext.mounted) {
                Navigator.of(dialogContext).pop(true);
              }
            },
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    // Only the confirmed path leaves the editor; cancel/dismiss changes
    // nothing (UI-SPEC #19).
    if (confirmed == true && context.mounted) {
      await Navigator.of(context).maybePop();
    }
  }
}
