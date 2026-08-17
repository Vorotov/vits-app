/// Calendar tab — the Today screen's permanent frame (UI-SPEC S4), plus the
/// planner page swapped in over it (plan 04-01, DECIDED-1).
///
/// This file owns the whole page swap: `calendarPageProvider` decides which
/// page renders, the header's action `Wrap` opens the planner, and a
/// `PopScope` sends system back to Today. `PlannerScreen` itself is
/// navigation-agnostic, so moving to a nested `Navigator` later touches only
/// this file (UI-SPEC S4-amendment).
///
/// Structure of the Today page, and who owns each region:
/// - fixed header (plan 03-03): title, locale-formatted subtitle, the
///   `backToToday` escape hatch, and [DayProgressRing] on the end side. It
///   lives OUTSIDE the scroll view, so it never scrolls away.
/// - week strip (plan 03-05): [WeekStrip], 16px below the header and also
///   outside the scroll view — a bounded Monday-first week pager.
/// - scroll body: the day's doses as chronological time blocks
///   ([DayBlockSection], plan 03-04), closed by the two-sentence disclaimer
///   line (plan 03-03, mockup line 264).
/// - empty / loading / error surfaces (plan 03-05): the empty-day title with
///   the body variant matching the user's stack, the previously rendered list
///   held across a day switch, and the documented day-load error copy plus a
///   retry — never a spinner, never raw exception text.
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
import 'package:boostque/features/calendar/planner_screen.dart';
import 'package:boostque/features/calendar/week_strip.dart';
import 'package:boostque/features/settings/settings_screen.dart';

/// Screen horizontal padding — the mockup-exact override used by both the
/// header and the scroll body, so one edge runs down the whole screen
/// (mockup lines 203, 225).
const double _screenPadding = 20;

/// Pushes Settings as a full-screen route, covering the nav bar (UI-SPEC S12).
///
/// Same call shape as every other push in this app
/// (`stack_screen.dart`'s card tap).
void _openSettings(BuildContext context) => Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
    );

/// The Calendar tab: the Today page, or the planner page swapped in over it
/// (DECIDED-1).
///
/// A page SWAP, not a `Navigator.push`: the app shell is an `IndexedStack` and
/// a root-level push would cover the `NavigationBar` the mockup deliberately
/// keeps visible on both planner screens. System back returns to Today rather
/// than leaving the tab.
class CalendarScreen extends ConsumerWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(calendarPageProvider) == CalendarPage.planner) {
      return PopScope(
        // The pop is intercepted rather than allowed: there is no route to pop
        // here, so letting it through would leave the Calendar tab (or the
        // app) instead of returning to Today.
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          ref.read(calendarPageProvider.notifier).showToday();
        },
        child: const PlannerScreen(),
      );
    }
    return const _TodayPage();
  }
}

/// The Today page ("Сьогодні", mockup screen 02, UI-SPEC S4).
class _TodayPage extends ConsumerWidget {
  const _TodayPage();

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
        // Sentence casing goes through intl WITH the active locale, never
        // Dart's locale-independent Unicode default casing: `i` uppercases to
        // `I` in en and to `İ` in tr/az, and a hand-rolled helper is
        // correct-but-lucky for the two languages that ship today and wrong
        // for the fourth ARB file (A3 / PF-6). The locale is the same one the
        // DateFormat above reads, threaded from the widget tree.
        : toBeginningOfSentenceCase(
            DateFormat('EEEE', locale).format(day),
            locale,
          );
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // The gear gets its OWN end-aligned row ABOVE the title, identical on
          // all three screens the nav bar reaches (UI-SPEC S11 / D-5). The row
          // holds NO text, so its extent is pure geometry and it cannot
          // overflow at any text scale, in any locale, in any direction.
          //
          // This is the WR-04 trap, stated so it is not rediscovered: the title
          // Row below already holds `Expanded` + `SizedBox` + `DayProgressRing`
          // and its comment says verbatim that it never gains a third
          // non-flexible child. Adding the gear there is the forbidden move —
          // do NOT "tidy" this row back into it. The rejected alternative (a
          // bounded trailing group holding ring + gear) is probably safe, but
          // it makes the header's overflow safety depend on a reader correctly
          // re-deriving "these two are not text" on every future edit; the
          // dedicated row makes it depend on nothing.
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Semantics(
                button: true,
                // One key, two placements: this label and the Settings screen
                // title, so the control and its destination can never disagree.
                label: l10n.tabSettings,
                excludeSemantics: true,
                // The action lives on THIS node, not only on the IconButton
                // below it: `excludeSemantics: true` drops every descendant
                // action, so without this the gear announces itself as a button
                // VoiceOver / TalkBack cannot press, while passing every
                // coordinate-tap test (WR-02).
                onTap: () => _openSettings(context),
                child: IconButton(
                  onPressed: () => _openSettings(context),
                  // A bounded, text-free box: >= 44pt guidance, and it cannot
                  // grow with the text scaler.
                  constraints: const BoxConstraints.tightFor(
                    width: 44,
                    height: 44,
                  ),
                  padding: EdgeInsets.zero,
                  icon: const Icon(
                    // Outlined only: the gear is never "selected", so the
                    // filled variant has no state to express.
                    Icons.settings_outlined,
                    size: 20,
                    color: BqColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          Row(
            // The mockup's `align-items:flex-end` (line 204).
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: BqSpace.xs), // mockup line 207
                    Text(
                      subtitle,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: BqColors.textMuted),
                    ),
                    const SizedBox(height: BqSpace.sm),
                    // A Wrap, NOT a Row: at textScaler 2.0 the two uk labels
                    // ("Планувальник", "Сьогодні") do not fit one line, and a
                    // Row would overflow exactly as the header did in WR-04.
                    // The header's title ROW above is left structurally
                    // untouched for the same reason — it never gains a third
                    // non-flexible child.
                    Wrap(
                      spacing: BqSpace.sm,
                      runSpacing: BqSpace.sm,
                      children: [
                        // Named for its destination, not its effect — the same
                        // key labels the planner's own title, so the button
                        // always names where it goes (UI-SPEC Copywriting
                        // Contract).
                        TextButton(
                          onPressed: () => ref
                              .read(calendarPageProvider.notifier)
                              .showPlanner(),
                          child: Text(
                            l10n.plannerTitle,
                            style: const TextStyle(
                              fontSize: 13,
                              color: BqColors.accent,
                            ),
                          ),
                        ),
                        // Named for its destination, not its effect — same
                        // word as the title by design (UI-SPEC Copywriting
                        // Contract).
                        if (!isToday)
                          TextButton(
                            onPressed: () => ref
                                .read(selectedDayProvider.notifier)
                                .followToday(),
                            child: Text(
                              l10n.backToToday,
                              style: const TextStyle(
                                fontSize: 13,
                                color: BqColors.accent,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10), // mockup line 209
              if (counts != null && counts.total > 0)
                DayProgressRing(taken: counts.taken, total: counts.total),
            ],
          ),
        ],
      ),
    );
  }
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

  /// The last dose list that actually resolved.
  ///
  /// PF-7 / Interaction Contract 6: switching days puts the new day's stream
  /// in `AsyncLoading`, and blanking the list for that frame reads as "this
  /// day is empty" — a lie that flashes. The previous rows stay on screen
  /// until the new day resolves; the header, ring and strip update
  /// immediately regardless, so the day change is never invisible.
  List<DayDose>? _held;

  /// The day [_held] actually belongs to.
  ///
  /// Held rows carry the PREVIOUS day's `logId`, so rendering them with the
  /// newly selected day's identity was wrong twice over (WR-01): a tap landing
  /// in the hold window wrote to a day the user is no longer looking at, and
  /// past-day rows momentarily took today's overdue treatment — the exact
  /// styling TRACK-03 forbids off today. The held frame now renders with the
  /// day the rows came from, and is inert until the new day resolves.
  DateTime? _heldDay;

  @override
  void initState() {
    super.initState();
    // Covers a mount over an ALREADY-settled provider; every later frame goes
    // through didUpdateWidget.
    _captureHold();
  }

  @override
  void didUpdateWidget(covariant _DayBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    _captureHold();
  }

  /// Remembers the last SETTLED day list, outside `build` (WR-06).
  ///
  /// This used to run inside `build`, from the settled arm of the same
  /// collection-`switch` that reads it back. Mutating `State` during build is
  /// a Flutter anti-pattern that happened to work only because nothing in the
  /// frame read the fields afterwards and `_heldRows` is reachable only from a
  /// DIFFERENT arm of that switch — i.e. the correctness of the hold rested on
  /// the arm ordering of a switch two authors have already reordered.
  ///
  /// The condition is the SAME one the settled arm matches on, and for the
  /// same reasons: an error beats a loading state (A1 / P-9), and anything
  /// still loading — including a re-emission that carries its previous value —
  /// must not be captured as settled (WR-06).
  void _captureHold() {
    final doses = widget.doses;
    if (doses.hasError || doses.isLoading) return;
    if (doses case AsyncData(:final value)) {
      _held = value;
      _heldDay = widget.day;
    }
  }

  @override
  Widget build(BuildContext context) {
    // The shell keeps this screen mounted on every tab (IndexedStack), so
    // "watched" is not the same as "looked at". TickerMode carries the shell's
    // answer: while the Calendar tab is offstage the ticker is not watched, so
    // the autoDispose StreamProvider tears its periodic timer down and the day
    // list stops rebuilding once a minute for nobody (WR-05). The last minute
    // stays cached, and re-entering the tab re-subscribes with an immediate
    // first value.
    final visible = TickerMode.valuesOf(context).enabled;
    // Riverpod 3: pattern-match the AsyncValue; there is no `valueOrNull`.
    final tick = visible
        ? switch (ref.watch(nowMinutesProvider)) {
            AsyncData(:final value) => value,
            _ => null,
          }
        : null;
    if (tick != null) _nowMinutes = tick;
    final today = ref.watch(todayProvider);
    final viewingToday = widget.day == today;
    final l10n = context.l10n;

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
        // Two rules, both matched on PROPERTIES so neither depends on which
        // arm a `when` happens to evaluate first:
        //
        // 1. "Has an error" beats "is loading" (A1 / P-9, 04-REVIEW.md CR-02).
        //    Riverpod 3 reports a failing provider as a value that carries the
        //    error while it retries on its own backoff, so an arm keyed on the
        //    error SUBTYPE alone leaves the designed error surface unreachable
        //    for the whole ~38.2s window and the held list wins instead.
        //
        // 2. Anything that is still LOADING renders held-and-inert, whatever
        //    shape it takes. `dayDosesProvider` re-runs on every regimen
        //    add/edit/pause/resume/delete as well as on a day switch
        //    (`providers.dart`), and that rebuild carries the previous value —
        //    so a rule that only recognised "loading with no value at all"
        //    would hand the user live, tappable rows built from a regimen that
        //    may have just been deleted (WR-06). The IgnorePointer window is
        //    exactly the one the Phase-4 WR-01 guard exists for, and it covers
        //    a same-day reload as well as a day switch.
        ...switch (widget.doses) {
          // Error: the documented copy plus a retry that re-subscribes.
          // A raw exception or stack trace is NEVER placed in the tree
          // (T-03-16).
          AsyncValue(hasError: true) => <Widget>[
              Text(
                l10n.dayLoadError,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: BqColors.textSecondary,
                ),
              ),
              const SizedBox(height: BqSpace.sm),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton(
                  onPressed: () => ref.invalidate(dayDosesProvider(widget.day)),
                  child: Text(
                    l10n.retry,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: BqColors.accent,
                    ),
                  ),
                ),
              ),
            ],
          // Resolved and settled: the live, interactive day.
          AsyncData(:final value) when !widget.doses.isLoading =>
            _resolved(value, viewingToday: viewingToday),
          // Loading in any shape: hold the last rendered list when there is
          // one, otherwise an empty list area — and NO spinner either way,
          // because the local-DB stream resolves within a frame and a spinner
          // would only flash.
          _ => _heldRows(today),
        },
        // Closes the body on EVERY day, including empty and error ones
        // (UI-SPEC S4, M9).
        const _Disclaimer(),
      ],
    );
  }

  /// The live day: [list] rendered interactively.
  ///
  /// Pure — the hold for the next loading window was captured in
  /// [_captureHold] before this frame began (WR-06).
  List<Widget> _resolved(
    List<DayDose> list, {
    required bool viewingToday,
  }) =>
      _blocks(list, widget.day, viewingToday: viewingToday);

  /// The previous day list, held and INERT, or nothing when there is none.
  ///
  /// The held rows are rendered with THEIR OWN day (WR-01) and wrapped in an
  /// `IgnorePointer`: a gesture in this window would otherwise write through a
  /// `logId` the list no longer describes — the day the user just left, or a
  /// regimen that was just deleted or paused (WR-06).
  List<Widget> _heldRows(DateTime today) {
    final held = _held;
    final heldDay = _heldDay;
    if (held == null || heldDay == null) return const <Widget>[];
    return <Widget>[
      IgnorePointer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: _blocks(held, heldDay, viewingToday: heldDay == today),
        ),
      ),
    ];
  }

  /// The day's time blocks, or the empty-day block when it has no doses.
  ///
  /// [day] is the day [list] BELONGS to — which is `widget.day` for a resolved
  /// list and the held day for a held one (WR-01), never assumed to be either.
  ///
  /// Grouping, ordering and empty-block omission are the pure helpers' job
  /// (DECIDED-1) — this widget only renders the result. A zero-dose day
  /// renders no block header at all, and the header's own zero-total rule
  /// keeps the ring off it (DECIDED-7).
  List<Widget> _blocks(
    List<DayDose> list,
    DateTime day, {
    required bool viewingToday,
  }) {
    if (list.isEmpty) return const <Widget>[_EmptyDayState()];

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
          day: day,
          viewingToday: viewingToday,
          nowMinutes: _nowMinutes,
          isCurrentBlock: block.blockIndex == current,
        ),
    ];
  }
}

/// Empty day (UI-SPEC S4 "Empty day"): a title plus the body variant that
/// matches the user's actual situation.
///
/// An off-week with a stocked stack is a CORRECT, expected state and gets no
/// call to action; an empty stack gets the one next step that helps — named,
/// not linked, because the nav bar is the affordance.
class _EmptyDayState extends ConsumerWidget {
  const _EmptyDayState();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final hasStack = switch (ref.watch(stackEntriesProvider)) {
      AsyncData(:final value) => value.isNotEmpty,
      // Until the stack resolves, assume it has entries: "no cycle active"
      // is the neutral statement, while wrongly telling a user with a full
      // stack to go add a supplement would be actively misleading.
      _ => true,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.emptyDayTitle,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            height: 1.3,
            color: BqColors.ink,
          ),
        ),
        const SizedBox(height: BqSpace.sm),
        Text(
          hasStack ? l10n.emptyDayBody : l10n.emptyDayBodyNoStack,
          style: const TextStyle(
            fontSize: 13,
            height: 1.5,
            color: BqColors.textMuted,
          ),
        ),
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
