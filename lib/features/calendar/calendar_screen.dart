/// Calendar tab — the Today screen's permanent frame (UI-SPEC S4).
///
/// Structure, and who owns each region:
/// - fixed header (plan 03-03): title, locale-formatted subtitle, the
///   `backToToday` escape hatch, and [DayProgressRing] on the end side. It
///   lives OUTSIDE the scroll view, so it never scrolls away.
/// - week strip (plan 03-05): [WeekStrip], 16px below the header and also
///   outside the scroll view — a bounded Monday-first week pager.
/// - scroll body: the day's doses as chronological time blocks
///   ([DayBlockSection], plan 03-04), closed by the two-sentence disclaimer
///   line (plan 03-03, mockup line 264).
/// - empty / error surfaces (`emptyDayTitle`, `dayLoadError` + retry) arrive in
///   plan 03-05; today the body simply renders nothing for those branches.
///
/// Screen states: following today · browsing a past day · a day with no doses
/// (ring omitted, DECIDED-7) · the dose stream loading (no spinner — a local-DB
/// stream resolves within a frame) · the stream in error.
///
/// The clock is never read in this file: the day arrives through
/// [resolvedDayProvider], which follows the app's single clock source
/// `todayProvider` (03-01, IN-06), and the minute of day arrives through
/// `nowMinutesProvider` — never through a per-build wall-clock read.
/// Weekday and month names come from intl `DateFormat` with the ACTIVE locale
/// — never from ARB and never from a hand-built table.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:boostque/core/domain/repositories.dart';
import 'package:boostque/core/l10n/l10n.dart';
import 'package:boostque/core/providers.dart';
import 'package:boostque/core/theme/tokens.dart';
import 'package:boostque/core/today_controller.dart';
import 'package:boostque/features/calendar/calendar_providers.dart';
import 'package:boostque/features/calendar/day_block_section.dart';
import 'package:boostque/features/calendar/day_progress_ring.dart';
import 'package:boostque/features/calendar/day_view_model.dart';
import 'package:boostque/features/calendar/week_strip.dart';

/// Screen horizontal padding — the mockup-exact override used by both the
/// header and the scroll body, so one edge runs down the whole screen
/// (mockup lines 203, 225).
const double _screenPadding = 20;

/// The Calendar screen ("Сьогодні", mockup screen 02, UI-SPEC S4).
class CalendarScreen extends ConsumerWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final day = ref.watch(resolvedDayProvider);
    final doses = ref.watch(dayDosesProvider(day));

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(day: day, doses: doses),
            // Header -> week strip gap (mockup line 215, on the BqSpace
            // scale). The strip sits OUTSIDE the scroll view, like the header.
            const SizedBox(height: BqSpace.md),
            const WeekStrip(),
            Expanded(child: _DayBody(doses: doses, day: day)),
          ],
        ),
      ),
    );
  }
}

/// Fixed header: title column on the start side, ring on the end side.
///
/// Both text lines are clock- and intl-derived and can never be empty, so the
/// header has no empty state (E5); only `backToToday` and the ring come and go.
class _Header extends ConsumerWidget {
  const _Header({required this.day, required this.doses});

  /// The resolved day being rendered.
  final DateTime day;

  /// That day's dose stream — read only for the ring's counts.
  final AsyncValue<List<DayDose>> doses;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    // The locale ALWAYS comes from the widget tree, never a literal tag: a
    // hardcoded 'uk' would silently ignore the user's language override.
    final locale = Localizations.localeOf(context).toString();
    final isToday = day == ref.watch(todayProvider);

    final title = isToday
        ? l10n.calendarTitleToday
        : _capitalizeFirst(DateFormat('EEEE', locale).format(day));
    // On today the weekday leads the subtitle; on any other day the title
    // already carries it, so the subtitle drops it (UI-SPEC S4).
    final subtitle = isToday
        ? DateFormat('EEEE, d MMMM', locale).format(day)
        : DateFormat('d MMMM', locale).format(day);

    // The ring is omitted entirely at zero total and while the day has not
    // resolved — never a spinner, never a "0/0" ring (DECIDED-7).
    final data = switch (doses) {
      AsyncData(:final value) => value,
      _ => null,
    };
    final counts = data == null ? null : dayRingCounts(data);

    return Padding(
      padding: const EdgeInsetsDirectional.only(
        start: _screenPadding,
        end: _screenPadding,
        top: 6, // mockup line 203
      ),
      child: Row(
        // The mockup's `align-items:flex-end` (line 204).
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: BqSpace.xs), // mockup line 207
                Text(
                  subtitle,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: BqColors.textMuted),
                ),
                if (!isToday) ...[
                  const SizedBox(height: BqSpace.sm),
                  // Named for its destination, not its effect — same word as
                  // the title by design (UI-SPEC Copywriting Contract).
                  TextButton(
                    onPressed: () =>
                        ref.read(selectedDayProvider.notifier).followToday(),
                    child: Text(
                      l10n.backToToday,
                      style: const TextStyle(
                        fontSize: 13,
                        color: BqColors.accent,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10), // mockup line 209
          if (counts != null && counts.total > 0)
            DayProgressRing(taken: counts.taken, total: counts.total),
        ],
      ),
    );
  }
}

/// Capitalizes the first character of an intl weekday (uk renders it
/// lowercase), leaving the rest of the string untouched.
///
/// Operates on the first RUNE, not the first UTF-16 code unit, so a locale
/// whose weekday starts outside the BMP is not corrupted.
String _capitalizeFirst(String value) {
  if (value.isEmpty) return value;
  final first = String.fromCharCode(value.runes.first);
  return first.toUpperCase() + value.substring(first.length);
}

/// Scrolling day body: the day's non-empty time blocks, closed by the
/// disclaimer.
class _DayBody extends ConsumerStatefulWidget {
  const _DayBody({required this.doses, required this.day});

  final AsyncValue<List<DayDose>> doses;

  /// The resolved day these doses belong to.
  final DateTime day;

  @override
  ConsumerState<_DayBody> createState() => _DayBodyState();
}

class _DayBodyState extends ConsumerState<_DayBody> {
  /// Last minute-of-day the ticker delivered.
  ///
  /// The body renders from this cache rather than blocking on the provider's
  /// first frame: `nowMinutes` decides only the accent header and the overdue
  /// treatment, and holding the previous minute for one frame is strictly
  /// better than withholding the whole day list waiting for a clock read.
  int _nowMinutes = 0;

  @override
  Widget build(BuildContext context) {
    // Riverpod 3: pattern-match the AsyncValue; there is no `valueOrNull`.
    final tick = switch (ref.watch(nowMinutesProvider)) {
      AsyncData(:final value) => value,
      _ => null,
    };
    if (tick != null) _nowMinutes = tick;
    final viewingToday = widget.day == ref.watch(todayProvider);

    return ListView(
      // Bottom >= 84px clears the nav bar (Phase-2 rule, locked); 18px top and
      // 20px horizontal are the mockup-exact body padding (line 225).
      padding: const EdgeInsetsDirectional.only(
        start: _screenPadding,
        end: _screenPadding,
        top: 18,
        bottom: 84,
      ),
      children: [
        ...widget.doses.when(
          data: (list) {
            // Grouping, ordering and empty-block omission are the pure
            // helpers' job (DECIDED-1) — this widget only renders the result.
            final blocks = groupIntoBlocks(list);
            final current = currentBlockIndex(
              blocks,
              viewingToday: viewingToday,
              nowMinutes: _nowMinutes,
            );
            return <Widget>[
              for (final block in blocks)
                DayBlockSection(
                  block: block,
                  dayDoses: list,
                  day: widget.day,
                  viewingToday: viewingToday,
                  nowMinutes: _nowMinutes,
                  isCurrentBlock: block.blockIndex == current,
                ),
            ];
          },
          // Loading: empty list area, NO spinner — the local-DB stream
          // resolves within a frame and a spinner would flash.
          loading: () => const <Widget>[],
          // The documented error surface (`dayLoadError` + retry) is owned by
          // plan 03-05; rendering nothing is the interim state.
          error: (_, _) => const <Widget>[],
        ),
        // Closes the body on EVERY day, including empty and error ones
        // (UI-SPEC S4, M9).
        const _Disclaimer(),
      ],
    );
  }
}

/// The two-sentence disclaimer line closing the scroll body (mockup line 264).
class _Disclaimer extends StatelessWidget {
  const _Disclaimer();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(
        top: BqSpace.md,
        start: BqSpace.xs,
        end: BqSpace.xs,
      ),
      child: Text(
        context.l10n.calendarDisclaimer,
        style: const TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w400,
          height: 1.5,
          color: BqColors.textFaint,
        ),
      ),
    );
  }
}
