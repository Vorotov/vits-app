/// Renders a [ScheduleSummary] into the one sentence that describes a
/// regimen (plan 04-02, M13).
///
/// **Why this is a sibling of `stack_status.dart` rather than a function in
/// it.** That file is a PURE derivation — no Flutter import, no l10n import,
/// no user-visible string — and its header says so; the sealed hierarchy is
/// deliberately string-free so it can be unit-tested and reused without a
/// widget tree. Rendering needs both `AppLocalizations` and `intl`, so it
/// lives here instead. The derivation decides WHAT a schedule is; this file
/// decides how it READS.
///
/// **Why it is shared.** The Stack card and the planner's gantt row both
/// describe the same regimen. If each composed its own sentence they would
/// eventually disagree — a break rounded differently, a date format changed in
/// one place — and the user would see one supplement described two ways in two
/// tabs. One composition, two callers, [withSlots] the only difference between
/// them: the planner is about time, so it omits the daily-slot tail.
library;

import 'package:intl/intl.dart';

import 'package:vitomy/core/l10n/gen/app_localizations.dart';
import 'package:vitomy/features/stack/stack_status.dart';

/// The schedule description for [summary].
///
/// [locale] is the ACTIVE locale read from the widget tree by the caller,
/// never a literal tag. [withSlots] appends the daily-slot tail: true for the
/// Stack card, false for the planner.
///
/// Returns an empty string for a regimen-less entry — the caller renders
/// nothing at all, never a placeholder dash.
String scheduleSummaryText(
  ScheduleSummary summary, {
  required AppLocalizations l10n,
  required String locale,
  required bool withSlots,
}) {
  final tail = switch (summary) {
    NoSummary() => '',
    CyclicSummary(:final slotCount) ||
    CourseSummary(:final slotCount) =>
      withSlots ? ' · ${l10n.slotsPerDay(slotCount)}' : '',
  };

  return switch (summary) {
    // Every word comes from an ARB key; only the separators live in code.
    CyclicSummary(:final onDays, :final offDays) =>
      '${l10n.weeksCount(onDays ~/ 7)} / '
          '${offDays == 0 ? l10n.noBreak : l10n.weeksCount(offDays ~/ 7)}'
          '$tail',
    CourseSummary(:final start, :final end) =>
      '${_courseRange(locale, start, end)}$tail',
    NoSummary() => '',
  };
}

/// Locale-formatted inclusive date range (uk "14.08.2026 – 30.09.2026").
String _courseRange(String locale, DateTime start, DateTime? end) {
  final fmt = DateFormat.yMd(locale);
  final startText = fmt.format(start);
  return end == null ? startText : '$startText – ${fmt.format(end)}';
}
