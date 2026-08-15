/// Week strip — the Calendar tab's day pager (UI-SPEC S4 "Week strip",
/// DECIDED-4, Interaction Contracts 4/5/8).
///
/// A horizontally-swipeable [PageView] of week rows. Each page is a `Row` of
/// seven `flex: 1` cells; tapping a cell browses that day, tapping today's
/// cell drops back to "follow today".
///
/// ## Monday-first is deliberate, in EVERY locale
///
/// The first column is Monday everywhere — computed arithmetically from the
/// UTC date-only day, deliberately NOT from the platform's localized
/// first-day-of-week value. That value would flip en-US to Sunday and diverge
/// from the approved mockup, so DECIDED-4 locks Monday-first for both uk and
/// en. This is recorded here so it is not "fixed" later by accident: reaching
/// for `MaterialLocalizations` here would be the bug, not the fix.
///
/// ## The pager is BOUNDED
///
/// [weekPageCount] is a finite 53 — 52 weeks back plus the week containing
/// today — so the builder can never run away and browsing cannot accumulate
/// unbounded Drift subscriptions (T-03-17). The LAST page is always today's
/// week: forward paging past it is impossible, while future days *inside* the
/// current week stay selectable (E-10).
///
/// ## The strip never blocks on data
///
/// Cells render synchronously from `todayProvider` + `selectedDayProvider`.
/// Each cell watches its own day's `dayDosesReadOnlyProvider` purely for the
/// handled dot — a READ, never a write (WR-06) — and a day that is loading,
/// errored, empty or in the future simply shows the neutral dot. Never a
/// spinner, never an error cell (E3 loading/error).
///
/// The "generated ahead for the near horizon" materialization is a separate,
/// bounded job: `_WeekWarmer` warms the CURRENT week only, and only while the
/// Calendar tab is the visible one.
///
/// The strip carries NO status semantics beyond that dot: it uses neither the
/// warn nor the destructive palette, on any day (TRACK-03 neutrality).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:boostque/core/domain/cycle_math.dart';
import 'package:boostque/core/domain/models.dart';
import 'package:boostque/core/providers.dart';
import 'package:boostque/core/theme/theme.dart';
import 'package:boostque/core/theme/tokens.dart';
import 'package:boostque/core/today_controller.dart';
import 'package:boostque/features/calendar/calendar_providers.dart';

/// Total pages in the week pager: 52 weeks back plus the week containing
/// today (DECIDED-4). Finite by construction — the last page is today's week
/// and there is no page after it.
const int weekPageCount = 53;

/// The part of the strip's height that does NOT follow the text scale:
/// padding 9/10, the 6px and 7px gaps, the 4px dot, the 1px borders, plus the
/// design slack the mockup's 82px carries at scale 1.0.
const double _stripFixedExtent = 48;

/// The text-bearing part of a cell at scale 1.0: the mono 10 dow line plus the
/// 14px day number, with their line boxes.
const double _stripTextExtent = 34;

/// Height reserved for the strip, for [scaler].
///
/// The `PageView` needs a BOUNDED cross-axis extent, so this extent has to be
/// computed rather than measured — and a constant would clip the cells at any
/// accessibility text scale (CR-01 reproduced 7 bottom overflows at 1.6 and at
/// 2.0). Only the two text lines grow with the scaler; the paddings, the gaps
/// and the 4px dot do not. Scaling only the text part therefore keeps the
/// mockup-exact 82px at scale 1.0 while growing exactly as fast as the content
/// it has to hold — the locked "no fixed-size text container" rule applies to
/// the vertical axis too.
double stripHeightFor(TextScaler scaler) =>
    _stripFixedExtent + scaler.scale(_stripTextExtent);

/// Gap between the seven cells (mockup line 215).
const double _cellGap = 5;

/// The Monday of [day]'s week, as a date-only UTC value.
///
/// Pure arithmetic on the UTC calendar day — `subtract` on a UTC value can
/// never be bitten by a DST transition (the project's date-only rule).
DateTime mondayOfWeek(DateTime day) {
  final d = dateOnly(day);
  return d.subtract(Duration(days: d.weekday - DateTime.monday));
}

/// The week-start rendered by [page], counting back from today's week on the
/// last page.
DateTime weekStartForPage(int page, DateTime today) =>
    mondayOfWeek(today).subtract(Duration(days: 7 * (weekPageCount - 1 - page)));

/// The bounded week pager (UI-SPEC S4).
class WeekStrip extends ConsumerStatefulWidget {
  const WeekStrip({super.key});

  @override
  ConsumerState<WeekStrip> createState() => _WeekStripState();
}

class _WeekStripState extends ConsumerState<WeekStrip> {
  late final PageController _controller =
      PageController(initialPage: weekPageCount - 1);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Brings the pager to the week holding [day] when the selection moves
  /// outside the visible week (e.g. the header's `backToToday`).
  ///
  /// `jumpToPage`, not `animateToPage`: an animation would leave a ticker
  /// running and buys nothing for a jump the user did not swipe.
  void _syncPageTo(DateTime day, DateTime today) {
    final target = weekPageCount -
        1 -
        (mondayOfWeek(today).difference(mondayOfWeek(day)).inDays ~/ 7);
    if (target < 0 || target >= weekPageCount) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_controller.hasClients) return;
      if (_controller.page?.round() == target) return;
      _controller.jumpToPage(target);
    });
  }

  @override
  Widget build(BuildContext context) {
    final today = ref.watch(todayProvider);
    final resolved = ref.watch(resolvedDayProvider);
    ref.listen<DateTime>(resolvedDayProvider, (_, next) {
      _syncPageTo(next, today);
    });

    return SizedBox(
      height: stripHeightFor(MediaQuery.textScalerOf(context)),
      child: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: weekPageCount,
            itemBuilder: (context, page) => _WeekPage(
              weekStart: weekStartForPage(page, today),
              today: today,
              resolved: resolved,
            ),
          ),
          // The "generated ahead for the near horizon" warm-up, bounded to
          // ONE week and to the tab actually being visible (WR-05 / WR-06):
          // paging back through the year no longer writes a row per day
          // travelled, and the app writes nothing at all for a calendar the
          // user has not opened.
          if (TickerMode.valuesOf(context).enabled)
            _WeekWarmer(weekStart: mondayOfWeek(today)),
        ],
      ),
    );
  }
}

/// Materializes the seven days of [weekStart] and draws nothing.
///
/// A widget of its own so the warm-up's rebuilds stay off the pager: it holds
/// the only `dayDosesProvider` watches the strip makes.
class _WeekWarmer extends ConsumerWidget {
  const _WeekWarmer({required this.weekStart});

  final DateTime weekStart;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    for (var i = 0; i < 7; i++) {
      ref.watch(dayDosesProvider(weekStart.add(Duration(days: i))));
    }
    return const SizedBox.shrink();
  }
}

/// One week: seven Monday-first cells, 5px apart.
class _WeekPage extends StatelessWidget {
  const _WeekPage({
    required this.weekStart,
    required this.today,
    required this.resolved,
  });

  final DateTime weekStart;
  final DateTime today;
  final DateTime resolved;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < 7; i++) ...[
          if (i > 0) const SizedBox(width: _cellGap),
          Expanded(
            child: _WeekCell(
              day: weekStart.add(Duration(days: i)),
              today: today,
              resolved: resolved,
            ),
          ),
        ],
      ],
    );
  }
}

/// A single day cell: dow label, day number, handled dot.
class _WeekCell extends ConsumerWidget {
  const _WeekCell({
    required this.day,
    required this.today,
    required this.resolved,
  });

  /// This cell's date-only UTC day — also its `dayDosesProvider` family key.
  final DateTime day;

  final DateTime today;
  final DateTime resolved;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The locale ALWAYS comes from the widget tree: dow labels and day
    // numbers are intl output, never ARB and never a hand-built table.
    final locale = Localizations.localeOf(context).toString();
    final isToday = day == today;
    final isSelected = day == resolved;

    // Three cell states, straight from the UI-SPEC list. No warn palette, no
    // destructive palette, on any day.
    final Color fill = isToday ? BqColors.accent : BqColors.surface;
    final Color borderColor =
        isToday || isSelected ? BqColors.accent : BqColors.cardBorder;
    final double borderWidth = isSelected && !isToday ? 1.5 : 1;
    final Color numberColor = isToday ? BqColors.surface : BqColors.ink;
    final Color labelColor =
        isToday ? BqColors.onAccentMuted : BqColors.textFaint;

    void select() {
      final selection = ref.read(selectedDayProvider.notifier);
      if (isToday) {
        selection.followToday();
      } else {
        selection.select(day);
      }
    }

    return MergeSemantics(
      child: Semantics(
        button: true,
        selected: isSelected,
        label: DateFormat.yMMMMEEEEd(locale).format(day),
        excludeSemantics: true,
        // The action lives on THIS node, not on the GestureDetector below it:
        // `excludeSemantics` drops every descendant action, so without this a
        // cell announced itself as a button that VoiceOver / TalkBack could
        // not activate — and day browsing is the screen's primary affordance
        // (WR-02).
        onTap: select,
        child: GestureDetector(
          // The whole padded cell is the tap target — a 4px dot must never
          // define it (Interaction Contract 8).
          behavior: HitTestBehavior.opaque,
          onTap: select,
          child: Container(
            key: ValueKey<DateTime>(day),
            padding: const EdgeInsetsDirectional.only(top: 9, bottom: 10),
            decoration: BoxDecoration(
              color: fill,
              border: Border.all(color: borderColor, width: borderWidth),
              borderRadius:
                  const BorderRadius.all(Radius.circular(BqRadii.dayCell)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  DateFormat.E(locale).format(day).toUpperCase(),
                  textAlign: TextAlign.center,
                  // A 2-3 character weekday abbreviation and a day number are
                  // single-line by nature: wrapping one at a large text scale
                  // would grow the cell by a whole line and clip the dot
                  // (CR-01), so the line count is pinned and only the line
                  // HEIGHT follows the scaler — which is what the strip's
                  // reserved extent is computed from.
                  maxLines: 1,
                  softWrap: false,
                  style: BqText.mono(
                    size: 10,
                    color: labelColor,
                    weight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 6), // mockup line 219
                Text(
                  DateFormat.d(locale).format(day),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  softWrap: false,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: numberColor,
                  ),
                ),
                const SizedBox(height: 7), // mockup line 220
                _HandledDot(day: day, today: today, isToday: isToday),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The 4×4 status dot under a day number.
///
/// Calm only when the day is strictly past AND every dose it has is already
/// handled; neutral `field` in every other case — future, empty, loading and
/// errored days all read the same, because the strip makes no claim it cannot
/// support (E3 loading/error).
class _HandledDot extends ConsumerWidget {
  const _HandledDot({
    required this.day,
    required this.today,
    required this.isToday,
  });

  final DateTime day;
  final DateTime today;
  final bool isToday;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // READ-ONLY (WR-06): the dot reports on the day's rows, it does not create
    // them. Materialization stays with the day the user is actually looking at
    // and with the current week's warm-up in [_WeekStripState].
    final doses = ref.watch(dayDosesReadOnlyProvider(day));
    final list = switch (doses) {
      AsyncData(:final value) => value,
      _ => null,
    };

    final handled = day.isBefore(today) &&
        list != null &&
        list.isNotEmpty &&
        list.every((d) => d.status != DoseStatus.pending);

    final Color color = isToday
        ? BqColors.onAccentMuted
        : handled
            ? BqColors.calm
            : BqColors.field;

    return Container(
      key: const ValueKey('week-dot'),
      width: 4,
      height: 4,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
