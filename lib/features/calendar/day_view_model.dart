/// Pure day view-model derivation for the Today/Calendar screen
/// (plan 03-02, P-4, P-5, P-6, PF-6, DECIDED-1/5/6/7).
///
/// Top-level pure functions in the `stack_status.dart` style: `today`,
/// `viewingToday` and `nowMinutes` arrive as explicit parameters and every
/// date comparison goes through [dateOnly] — this file NEVER reads the clock.
/// It imports only the three pure domain libraries: no UI framework, no l10n,
/// no persistence, so no status write is reachable from here (T-03-05) and
/// nothing in it decides whether a day is cycle-active (T-03-06) — the day
/// stream is the single source of that truth.
///
/// No user-visible strings: the renderer switches exhaustively over the
/// sealed [BlockTag] hierarchy and maps each case to an ARB key itself.
library;

import 'package:vitomy/core/domain/cycle_math.dart';
import 'package:vitomy/core/domain/models.dart';
import 'package:vitomy/core/domain/repositories.dart';

/// Start minute of each time block, in chronological order (DECIDED-1):
/// Ранок 00:00-11:59, День 12:00-17:59, Вечір 18:00-21:59, Ніч 22:00-23:59.
///
/// This const is the ONE place a boundary lives — the mockup's `BLOCK_META`
/// anchors (08:00 / 13:00 / 19:00 / 22:00) are Phase-2 editor defaults, not
/// ranges, and this list generalizes them so every default the editor can
/// produce lands in its intuitive block. Named-constant convention follows
/// `regimen_editor_controller.nextSlotDefaults`; changing a boundary is a
/// one-line, test-caught edit.
const blockStartsMinutes = <int>[0, 720, 1080, 1320];

/// Block index (0..3) for a wall-clock slot time in minutes since midnight.
///
/// Scans [blockStartsMinutes] from the end, so a minute equal to a block's
/// start opens that block and the last block runs to end of day.
int blockIndexOf(int minutesFromMidnight) {
  for (var i = blockStartsMinutes.length - 1; i >= 0; i--) {
    if (minutesFromMidnight >= blockStartsMinutes[i]) return i;
  }
  return 0;
}

/// One non-empty time block of a rendered day.
///
/// Carries no time of its own since v1.2. It used to expose the block's
/// earliest real slot minute because the block HEADER printed exactly one
/// time, but a single printed time is only ever right for a block whose doses
/// all share a minute: a morning holding 08:20 and 09:05 filed both rows under
/// an "08:20" heading that was false for the second one. The time moved down to
/// the rows — see [groupByTime] — and a field documented as "what the header
/// prints" would now describe something nothing prints, so it is gone rather
/// than left behind to mislead the next reader.
class DayBlock {
  /// Index into [blockStartsMinutes].
  final int blockIndex;

  /// The block's doses, in the input list's slot-time order.
  final List<DayDose> doses;

  const DayBlock({required this.blockIndex, required this.doses});
}

/// Groups a day's doses into non-empty blocks, ordered by block index.
///
/// Empty blocks are omitted entirely (DECIDED-1) and the input order is
/// preserved inside each block — `watchDay` already emits slot-time order.
List<DayBlock> groupIntoBlocks(List<DayDose> doses) {
  final byBlock = <int, List<DayDose>>{};
  for (final d in doses) {
    byBlock
        .putIfAbsent(
          blockIndexOf(d.slot.minutesFromMidnight),
          () => <DayDose>[],
        )
        .add(d);
  }
  final indices = byBlock.keys.toList()..sort();
  return [
    for (final i in indices)
      DayBlock(blockIndex: i, doses: List.unmodifiable(byBlock[i]!)),
  ];
}

/// The doses of one block that share a single wall-clock minute.
///
/// [minutes] is a REAL `slot.minutesFromMidnight` taken from the doses in
/// [doses] — never a block boundary and never one of the mockup's 08:00 /
/// 13:00 / 19:00 / 22:00 anchors, which are Phase-2 editor defaults rather
/// than anything to print above rows that do not sit at them (M5).
class TimeGroup {
  /// The exact minute every dose in [doses] is scheduled for.
  final int minutes;

  /// The doses at [minutes], in the input list's order.
  final List<DayDose> doses;

  const TimeGroup({required this.minutes, required this.doses});
}

/// Sub-groups ONE block's doses by their exact [DoseSlot.minutesFromMidnight],
/// ascending (v1.2).
///
/// The four blocks are wide — Ранок alone spans 00:00-11:59 — so a block is a
/// coarse container, not a time. Printing one time per block was therefore
/// wrong the moment a block held two different slot times: two supplements at
/// 08:20 and 09:05 both sat under a single "08:20" heading, which states
/// something false about the 09:05 dose. Each distinct minute now gets its own
/// small heading above its own rows, and the block keeps its ONE label.
///
/// The key is the raw minute with no rounding and no tolerance window: two
/// doses group together when the user scheduled them at the same time and at
/// no other time, so 08:00 and 08:01 stay two headings. Anything looser would
/// have to invent a heading time that matches neither dose.
///
/// Ordering is this function's job, not the caller's: the renderer walks the
/// returned list in order, and `watchDay`'s slot-time order is an input
/// guarantee this function deliberately does not lean on.
List<TimeGroup> groupByTime(List<DayDose> blockDoses) {
  final byMinute = <int, List<DayDose>>{};
  for (final d in blockDoses) {
    byMinute
        .putIfAbsent(d.slot.minutesFromMidnight, () => <DayDose>[])
        .add(d);
  }
  final minutes = byMinute.keys.toList()..sort();
  return [
    for (final m in minutes)
      TimeGroup(minutes: m, doses: List.unmodifiable(byMinute[m]!)),
  ];
}

/// The `доза n з m` position of [dose] within its regimen's doses that day.
///
/// Derived by grouping [dayDoses] by `regimen.id` — NEVER from
/// `dose.regimen.slots`, which carries only this dose's own slot (PF-6).
/// The renderer shows the chip only when `m > 1`.
({int n, int m}) doseCyclePosition(List<DayDose> dayDoses, DayDose dose) {
  final group = [
    for (final d in dayDoses)
      if (d.regimen.id == dose.regimen.id) d,
  ];
  final index = group.indexWhere((d) => d.logId == dose.logId);
  return (n: index < 0 ? 1 : index + 1, m: group.isEmpty ? 1 : group.length);
}

/// The ONE missed rule (TRACK-03, P-6): an unmarked dose whose calendar day
/// is strictly before [today] reads as missed.
///
/// View-computed only — the IntakeLog row stays `pending`; nothing in this
/// library can write a status. Both dates are normalized via [dateOnly].
bool isMissed(
  DayDose d, {
  required DateTime viewedDay,
  required DateTime today,
}) =>
    d.status == DoseStatus.pending &&
    dateOnly(viewedDay).isBefore(dateOnly(today));

/// The mirror of the missed rule (v1.2): a day strictly AFTER [today] has not
/// happened yet, so nothing on it may be marked.
///
/// Deliberately day-level, not dose-level — future-ness is a property of the
/// calendar day and holds whatever a dose's status is, so no combination of
/// stored statuses can talk a row out of it. Both dates are normalized via
/// [dateOnly], exactly as [isMissed] does, and this library still never reads
/// the clock: [today] arrives as a parameter.
///
/// The boundary is strict on purpose. Today is NOT future, so a 21:00 dose
/// stays tickable at 10:00 — taking a dose early, or marking one before bed,
/// is legitimate. Only a day that has not arrived is refused.
bool isFutureDay(DateTime viewedDay, {required DateTime today}) =>
    dateOnly(viewedDay).isAfter(dateOnly(today));

/// Overdue applies on today only (P-5, DECIDED-5): a pending dose whose slot
/// time is strictly before [nowMinutes].
///
/// [viewingToday] gates the whole predicate, so no warn-colored state is
/// derivable for any other day (TRACK-03 neutrality mandate).
bool isOverdue(
  DayDose d, {
  required bool viewingToday,
  required int nowMinutes,
}) =>
    viewingToday &&
    d.status == DoseStatus.pending &&
    d.slot.minutesFromMidnight < nowMinutes;

/// Structured block-header tag — the renderer switches exhaustively (sealed,
/// Dart 3) and maps each case to an ARB key and a color pair.
sealed class BlockTag {
  const BlockTag();
}

/// Every dose in the block is `taken` (calm treatment).
class AllTakenTag extends BlockTag {
  const AllTakenTag();
}

/// Every dose is marked and at least one is `skipped` — neutral, because the
/// block must not claim skipped doses were taken (DECIDED-6).
class AllMarkedTag extends BlockTag {
  const AllMarkedTag();
}

/// Today's past block that still holds a pending dose (warn treatment).
///
/// [done] counts `taken` doses only; `skipped` is not done.
class ProgressTag extends BlockTag {
  final int done;
  final int total;

  const ProgressTag({required this.done, required this.total});
}

/// The block's own meal tag — the neutral default, including a future block
/// of today and every block of a non-today day.
class MealTag extends BlockTag {
  const MealTag();
}

/// Resolves the block-header tag in the DECIDED-6 order.
///
/// all taken -> [AllTakenTag]; all marked with >= 1 skip -> [AllMarkedTag];
/// today only, every dose's slot time passed and >= 1 pending ->
/// [ProgressTag]; otherwise [MealTag].
BlockTag blockTagOf(
  DayBlock block, {
  required bool viewingToday,
  required int nowMinutes,
}) {
  final doses = block.doses;
  if (doses.isEmpty) return const MealTag();

  final taken = doses.where((d) => d.status == DoseStatus.taken).length;
  final pending = doses.where((d) => d.status == DoseStatus.pending).length;

  if (taken == doses.length) return const AllTakenTag();
  if (pending == 0) return const AllMarkedTag();

  if (viewingToday && _blockHasPassed(block, nowMinutes)) {
    return ProgressTag(done: taken, total: doses.length);
  }
  return const MealTag();
}

/// The block index the header renders in the accent color (P-5): the first
/// block of today whose doses have not all passed.
///
/// Null for any non-today view and once every block of today has passed.
int? currentBlockIndex(
  List<DayBlock> blocks, {
  required bool viewingToday,
  required int nowMinutes,
}) {
  if (!viewingToday) return null;
  for (final b in blocks) {
    if (!_blockHasPassed(b, nowMinutes)) return b.blockIndex;
  }
  return null;
}

/// A block is past once every one of its doses' slot times has passed —
/// strictly, so a dose exactly at [nowMinutes] is still due.
bool _blockHasPassed(DayBlock block, int nowMinutes) =>
    block.doses.every((d) => d.slot.minutesFromMidnight < nowMinutes);

/// The one time heading inside a block that renders in the accent color, or
/// null when the block carries no accent (v1.2).
///
/// Where the accent belongs had to be re-decided when the time moved off the
/// block header. The old rule accented the current block's single header time,
/// i.e. its EARLIEST dose — which, in a morning holding 09:30 and 11:00 at
/// 10:00, pointed the eye at a time that had already gone by, because
/// [currentBlockIndex] calls a block current while ANY of its doses is still
/// ahead. Sub-grouping makes a sharper answer available, so the accent now
/// marks the earliest heading that has not passed: the next time actually due.
///
/// Two properties of the old treatment are kept deliberately. Exactly one time
/// on the whole day is accented, because [isCurrentBlock] is true for at most
/// one block; and no accent is reachable off today, because
/// [currentBlockIndex] returns null for every non-today view, which is what
/// makes [isCurrentBlock] false there (TRACK-03 neutrality).
///
/// The `>=` boundary mirrors [_blockHasPassed]'s strict `<`: a dose exactly at
/// [nowMinutes] is still due, so its heading is the one that leads. A current
/// block always holds at least one such heading — that is what made it current
/// — so the null tail is unreachable through [currentBlockIndex]; it exists so
/// the function is total for any [groups]/[nowMinutes] pair a caller hands it.
int? accentedTimeMinutes(
  List<TimeGroup> groups, {
  required bool isCurrentBlock,
  required int nowMinutes,
}) {
  if (!isCurrentBlock) return null;
  for (final g in groups) {
    if (g.minutes >= nowMinutes) return g.minutes;
  }
  return null;
}

/// Day-progress ring counts (DECIDED-7, mockup formula): `taken` against
/// every dose of the day, with `skipped` counted as not-taken.
///
/// The renderer hides the ring entirely at `total == 0`.
({int taken, int total}) dayRingCounts(List<DayDose> doses) => (
  taken: doses.where((d) => d.status == DoseStatus.taken).length,
  total: doses.length,
);
