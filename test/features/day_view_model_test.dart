/// Unit tests for the pure day view-model (plan 03-02, Task 1).
///
/// Pure-function matrix in the cycle_math_test / stack_status_test style: no
/// widgets, no clock — `today`, `viewingToday` and `nowMinutes` are passed
/// explicitly and every date fixture is a UTC date-only value (P-4, P-5, P-6,
/// PF-6, PF-9, DECIDED-1/5/6/7).
///
/// Boundary discipline follows the cycle-math tests: both sides of every time
/// block boundary are asserted explicitly (719/720, 1079/1080, 1319/1320), so
/// moving a boundary is a one-line change that a test catches.
library;

import 'package:vitomy/core/domain/models.dart';
import 'package:vitomy/core/domain/repositories.dart';
import 'package:vitomy/features/calendar/day_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Supplement supplement({
    String id = 's1',
    String name = 'Магній',
    String note = '',
  }) => Supplement(
    id: id,
    name: name,
    doseText: '400 мг',
    colorValue: 0xFF6B6FA8,
    note: note,
  );

  /// A [DayDose] as `watchDay` emits it: the embedded regimen carries ONLY
  /// this dose's own slot (PF-6) — never the regimen's full slot set.
  DayDose dose({
    required String logId,
    required int minutes,
    String regimenId = 'r1',
    String supplementId = 's1',
    DoseStatus status = DoseStatus.pending,
    bool paused = false,
  }) {
    final slot = DoseSlot(
      id: 'sl-$logId',
      minutesFromMidnight: minutes,
      doseLabel: '200 мг',
    );
    return DayDose(
      logId: logId,
      supplement: supplement(id: supplementId),
      regimen: Regimen(
        id: regimenId,
        supplementId: supplementId,
        kind: RegimenKind.cyclic,
        startDate: DateTime.utc(2026, 8, 1),
        endDate: null,
        onDays: 56,
        offDays: 0,
        paused: paused,
        // Exactly one slot — the production shape (PF-6).
        slots: [slot],
      ),
      slot: slot,
      status: status,
    );
  }

  group('blockIndexOf boundaries (DECIDED-1)', () {
    test('both sides of every boundary', () {
      // Morning: 00:00-11:59
      expect(blockIndexOf(0), 0);
      expect(blockIndexOf(719), 0);
      // Day: 12:00-17:59
      expect(blockIndexOf(720), 1);
      expect(blockIndexOf(1079), 1);
      // Evening: 18:00-21:59
      expect(blockIndexOf(1080), 2);
      expect(blockIndexOf(1319), 2);
      // Night: 22:00-23:59
      expect(blockIndexOf(1320), 3);
      expect(blockIndexOf(1439), 3);
    });

    test('every Phase-2 editor default lands in its intuitive block', () {
      expect(blockIndexOf(480), 0, reason: '08:00 -> Ранок');
      expect(blockIndexOf(630), 0, reason: '10:30 -> Ранок');
      expect(blockIndexOf(780), 1, reason: '13:00 -> День');
      expect(blockIndexOf(960), 1, reason: '16:00 -> День');
      expect(blockIndexOf(1140), 2, reason: '19:00 -> Вечір');
      expect(blockIndexOf(1320), 3, reason: '22:00 -> Ніч');
      expect(blockIndexOf(1260), 2, reason: 'the 21:00 fallback -> Вечір');
    });

    test('the boundary const is the single source of the four blocks', () {
      expect(blockStartsMinutes, hasLength(4));
      for (var i = 0; i < blockStartsMinutes.length; i++) {
        expect(
          blockIndexOf(blockStartsMinutes[i]),
          i,
          reason: 'each start minute opens its own block',
        );
      }
    });
  });

  group('groupIntoBlocks (DECIDED-1, M5)', () {
    test('only non-empty blocks, in block order, input order kept', () {
      final doses = [
        dose(logId: 'l1', minutes: 570), // 09:30 morning
        dose(logId: 'l2', minutes: 660, regimenId: 'r2'), // 11:00 morning
        dose(logId: 'l3', minutes: 1350, regimenId: 'r3'), // 22:30 night
      ];

      final blocks = groupIntoBlocks(doses);

      expect(
        blocks,
        hasLength(2),
        reason: 'День and Вечір are empty -> hidden',
      );
      expect(blocks[0].blockIndex, 0);
      expect(blocks[1].blockIndex, 3);
      expect(
        blocks[0].doses.map((d) => d.slot.minutesFromMidnight),
        [570, 660],
        reason: 'a block carries every real slot time it holds — since v1.2 '
            'each of them heads its own rows, so none may be dropped or '
            'collapsed into a single block time (M5)',
      );
      expect(blocks[1].doses.map((d) => d.slot.minutesFromMidnight), [1350]);
      expect(blocks[0].doses.map((d) => d.logId), [
        'l1',
        'l2',
      ], reason: 'input slot-time order preserved inside the block');
      expect(blocks[1].doses.map((d) => d.logId), ['l3']);
    });

    test(
      'blocks come out in chronological order regardless of input order',
      () {
        final blocks = groupIntoBlocks([
          dose(logId: 'night', minutes: 1320),
          dose(logId: 'morning', minutes: 480, regimenId: 'r2'),
          dose(logId: 'day', minutes: 720, regimenId: 'r3'),
        ]);
        expect(blocks.map((b) => b.blockIndex), [0, 1, 3]);
        expect(
          blocks.map((b) => b.doses.single.slot.minutesFromMidnight),
          [480, 720, 1320],
        );
      },
    );

    test('empty day yields no blocks', () {
      expect(groupIntoBlocks(const []), isEmpty);
    });
  });

  // -------------------------------------------------------------------
  // Sub-grouping a block by exact slot time (v1.2). The block header used
  // to print ONE time — the block's earliest real slot — which silently
  // filed a 09:05 dose under an "08:20" heading. The time now belongs to
  // the rows, so the grouping that produces it is asserted here rather
  // than inferred from a rendered widget.
  // -------------------------------------------------------------------
  group('groupByTime (v1.2 per-time sub-grouping)', () {
    test('two doses at the SAME minute collapse into ONE group', () {
      final groups = groupByTime([
        dose(logId: 'l1', minutes: 480),
        dose(logId: 'l2', minutes: 480, regimenId: 'r2', supplementId: 's2'),
      ]);

      expect(groups, hasLength(1),
          reason: 'one printed time, two rows under it — the whole point of '
              'moving the time off the block header');
      expect(groups.single.minutes, 480);
      expect(groups.single.doses.map((d) => d.logId), ['l1', 'l2'],
          reason: 'input order preserved inside a group');
    });

    test('different minutes inside one block make separate groups', () {
      final groups = groupByTime([
        dose(logId: 'l1', minutes: 500), // 08:20
        dose(logId: 'l2', minutes: 545, regimenId: 'r2'), // 09:05
      ]);

      expect(groups.map((g) => g.minutes), [500, 545],
          reason: '08:20 and 09:05 are two headings, not one');
      expect(groups.map((g) => g.doses.single.logId), ['l1', 'l2']);
    });

    test('groups ascend regardless of input order', () {
      final groups = groupByTime([
        dose(logId: 'late', minutes: 660),
        dose(logId: 'early', minutes: 480, regimenId: 'r2'),
        dose(logId: 'mid', minutes: 545, regimenId: 'r3'),
      ]);

      expect(groups.map((g) => g.minutes), [480, 545, 660],
          reason: 'the renderer prints groups in list order, so ordering is '
              'this function’s responsibility — not the caller’s');
      expect(groups.map((g) => g.doses.single.logId), [
        'early',
        'mid',
        'late',
      ]);
    });

    test('a single dose still yields exactly one group', () {
      final groups = groupByTime([dose(logId: 'only', minutes: 1140)]);

      expect(groups, hasLength(1));
      expect(groups.single.minutes, 1140);
      expect(groups.single.doses.single.logId, 'only');
    });

    test('an empty list yields no groups', () {
      expect(groupByTime(const []), isEmpty);
    });

    test('minute precision is exact — 08:00 and 08:01 do not merge', () {
      final groups = groupByTime([
        dose(logId: 'l1', minutes: 480),
        dose(logId: 'l2', minutes: 481, regimenId: 'r2'),
      ]);

      expect(groups.map((g) => g.minutes), [480, 481],
          reason: 'the grouping key is the exact minutesFromMidnight, with no '
              'rounding or tolerance window anywhere');
    });
  });

  // -------------------------------------------------------------------
  // Where the accent lives now that the time moved off the header. The
  // old rule accented the current block's ONE header time; the day still
  // gets exactly one accented time, but it is now the next time actually
  // due, which the old rule could not express (a 09:30/11:00 morning at
  // 10:00 accented the 09:30 that had already gone by).
  // -------------------------------------------------------------------
  group('accentedTimeMinutes (v1.2)', () {
    List<TimeGroup> morning() => groupByTime([
          dose(logId: 'a', minutes: 570), // 09:30
          dose(logId: 'b', minutes: 660, regimenId: 'r2'), // 11:00
        ]);

    test('nothing is accented outside the current block', () {
      expect(
        accentedTimeMinutes(morning(), isCurrentBlock: false, nowMinutes: 600),
        isNull,
        reason: 'isCurrentBlock is already false on every non-today view, so '
            'no accent is reachable off today',
      );
    });

    test('the earliest time NOT yet passed carries the accent', () {
      expect(
        accentedTimeMinutes(morning(), isCurrentBlock: true, nowMinutes: 600),
        660,
        reason: '10:00: the 09:30 group is behind the user, 11:00 is next',
      );
    });

    test('a time exactly at now is still due, so it takes the accent', () {
      expect(
        accentedTimeMinutes(morning(), isCurrentBlock: true, nowMinutes: 570),
        570,
        reason: 'the >= boundary matches _blockHasPassed’s strict <',
      );
    });

    test('a block whose every time has passed accents nothing', () {
      expect(
        accentedTimeMinutes(morning(), isCurrentBlock: true, nowMinutes: 1200),
        isNull,
        reason: 'unreachable through currentBlockIndex — such a block is not '
            'current — but the function stays total rather than throwing',
      );
    });

    test('an empty group list accents nothing', () {
      expect(
        accentedTimeMinutes(const [], isCurrentBlock: true, nowMinutes: 600),
        isNull,
      );
    });
  });

  group('doseCyclePosition (PF-6)', () {
    test(
      'm comes from the day list even though every regimen.slots holds 1',
      () {
        final a1 = dose(logId: 'a1', minutes: 480);
        final a2 = dose(logId: 'a2', minutes: 780);
        final a3 = dose(logId: 'a3', minutes: 1140);
        final b1 = dose(logId: 'b1', minutes: 600, regimenId: 'r2');
        final day = [a1, b1, a2, a3];

        // The production shape: each embedded regimen carries one slot only.
        for (final d in day) {
          expect(d.regimen.slots, hasLength(1));
        }

        expect(doseCyclePosition(day, a1), (n: 1, m: 3));
        expect(doseCyclePosition(day, a2), (n: 2, m: 3));
        expect(doseCyclePosition(day, a3), (n: 3, m: 3));
        expect(doseCyclePosition(day, b1), (n: 1, m: 1));
      },
    );

    test('n follows the day list order (slot-time ordered by watchDay)', () {
      final early = dose(logId: 'e', minutes: 480);
      final late = dose(logId: 'l', minutes: 1320);
      expect(doseCyclePosition([early, late], late), (n: 2, m: 2));
    });
  });

  group('isMissed — the ONE missed rule (TRACK-03, P-6)', () {
    final today = DateTime.utc(2026, 8, 15);
    final yesterday = DateTime.utc(2026, 8, 14);
    final tomorrow = DateTime.utc(2026, 8, 16);

    test('pending on a strictly past day -> missed', () {
      expect(
        isMissed(
          dose(logId: 'l1', minutes: 480),
          viewedDay: yesterday,
          today: today,
        ),
        isTrue,
      );
    });

    test('pending on today or a future day -> not missed', () {
      final d = dose(logId: 'l1', minutes: 480);
      expect(isMissed(d, viewedDay: today, today: today), isFalse);
      expect(isMissed(d, viewedDay: tomorrow, today: today), isFalse);
    });

    test('taken or skipped on a past day -> never missed', () {
      expect(
        isMissed(
          dose(logId: 'l1', minutes: 480, status: DoseStatus.taken),
          viewedDay: yesterday,
          today: today,
        ),
        isFalse,
      );
      expect(
        isMissed(
          dose(logId: 'l2', minutes: 480, status: DoseStatus.skipped),
          viewedDay: yesterday,
          today: today,
        ),
        isFalse,
      );
    });

    test('non-date-only inputs are normalized through dateOnly', () {
      expect(
        isMissed(
          dose(logId: 'l1', minutes: 480),
          viewedDay: DateTime(2026, 8, 15, 23, 45),
          today: DateTime(2026, 8, 15, 0, 5),
        ),
        isFalse,
        reason: 'same calendar day either side of the wall clock',
      );
    });
  });

  group('isFutureDay — the mirror of the missed rule (v1.2)', () {
    final today = DateTime.utc(2026, 8, 15);
    final yesterday = DateTime.utc(2026, 8, 14);
    final tomorrow = DateTime.utc(2026, 8, 16);

    test('a strictly later calendar day -> future', () {
      expect(isFutureDay(tomorrow, today: today), isTrue);
      expect(
        isFutureDay(today.add(const Duration(days: 40)), today: today),
        isTrue,
      );
    });

    test('today itself is NOT future — the boundary that keeps a later dose '
        'of today tickable', () {
      expect(isFutureDay(today, today: today), isFalse);
    });

    test('a past day is not future', () {
      expect(isFutureDay(yesterday, today: today), isFalse);
    });

    test('non-date-only inputs are normalized through dateOnly', () {
      expect(
        isFutureDay(
          DateTime(2026, 8, 15, 23, 45),
          today: DateTime(2026, 8, 15, 0, 5),
        ),
        isFalse,
        reason: 'same calendar day either side of the wall clock',
      );
      expect(
        isFutureDay(
          DateTime(2026, 8, 16, 0, 5),
          today: DateTime(2026, 8, 15, 23, 45),
        ),
        isTrue,
        reason: 'the calendar day decides, never the elapsed hours',
      );
    });

    test('future and missed are mutually exclusive by construction', () {
      for (final day in [yesterday, today, tomorrow]) {
        final bothHold = isFutureDay(day, today: today) &&
            isMissed(dose(logId: 'l1', minutes: 480),
                viewedDay: day, today: today);
        expect(bothHold, isFalse, reason: 'day $day claimed both states');
      }
    });
  });

  group('isOverdue — today only (DECIDED-5, P-5)', () {
    test('today, pending, slot time strictly past -> overdue', () {
      final d = dose(logId: 'l1', minutes: 480);
      expect(isOverdue(d, viewingToday: true, nowMinutes: 481), isTrue);
      expect(
        isOverdue(d, viewingToday: true, nowMinutes: 480),
        isFalse,
        reason: 'boundary: exactly due is not yet overdue',
      );
      expect(isOverdue(d, viewingToday: true, nowMinutes: 479), isFalse);
    });

    test('marked doses are never overdue', () {
      expect(
        isOverdue(
          dose(logId: 'l1', minutes: 480, status: DoseStatus.taken),
          viewingToday: true,
          nowMinutes: 1200,
        ),
        isFalse,
      );
      expect(
        isOverdue(
          dose(logId: 'l2', minutes: 480, status: DoseStatus.skipped),
          viewingToday: true,
          nowMinutes: 1200,
        ),
        isFalse,
      );
    });

    test('no non-today view can derive overdue, whatever the now-minute', () {
      final d = dose(logId: 'l1', minutes: 480);
      expect(
        isOverdue(d, viewingToday: false, nowMinutes: 1439),
        isFalse,
        reason: 'TRACK-03 neutrality: past days carry no warn state',
      );
      expect(isOverdue(d, viewingToday: false, nowMinutes: 0), isFalse);
    });
  });

  group('blockTagOf (DECIDED-6)', () {
    DayBlock blockOf(List<DayDose> doses) => groupIntoBlocks(doses).single;

    test('every dose taken -> allTaken', () {
      final block = blockOf([
        dose(logId: 'l1', minutes: 480, status: DoseStatus.taken),
        dose(logId: 'l2', minutes: 600, status: DoseStatus.taken),
      ]);
      expect(
        blockTagOf(block, viewingToday: true, nowMinutes: 1200),
        isA<AllTakenTag>(),
      );
      expect(
        blockTagOf(block, viewingToday: false, nowMinutes: 0),
        isA<AllTakenTag>(),
      );
    });

    test('all marked with at least one skip -> allMarked, never allTaken', () {
      final block = blockOf([
        dose(logId: 'l1', minutes: 480, status: DoseStatus.taken),
        dose(logId: 'l2', minutes: 600, status: DoseStatus.skipped),
      ]);
      expect(
        blockTagOf(block, viewingToday: true, nowMinutes: 1200),
        isA<AllMarkedTag>(),
      );
    });

    test('every dose skipped -> allMarked', () {
      final block = blockOf([
        dose(logId: 'l1', minutes: 480, status: DoseStatus.skipped),
      ]);
      expect(
        blockTagOf(block, viewingToday: true, nowMinutes: 1200),
        isA<AllMarkedTag>(),
      );
    });

    test('today, past block with a pending dose -> progress(done, total)', () {
      final block = blockOf([
        dose(logId: 'l1', minutes: 480, status: DoseStatus.taken),
        dose(logId: 'l2', minutes: 600),
      ]);
      final tag = blockTagOf(block, viewingToday: true, nowMinutes: 601);
      expect(tag, isA<ProgressTag>());
      final progress = tag as ProgressTag;
      expect(
        progress.done,
        1,
        reason: 'taken vs total (UI-SPEC blockProgress)',
      );
      expect(progress.total, 2);
    });

    test('skipped counts toward "marked" but not toward done', () {
      final block = blockOf([
        dose(logId: 'l1', minutes: 480, status: DoseStatus.skipped),
        dose(logId: 'l2', minutes: 600),
      ]);
      final tag =
          blockTagOf(block, viewingToday: true, nowMinutes: 601) as ProgressTag;
      expect(tag.done, 0);
      expect(tag.total, 2);
    });

    test('not every dose has passed yet -> meal tag, not progress', () {
      final block = blockOf([
        dose(logId: 'l1', minutes: 480, status: DoseStatus.taken),
        dose(logId: 'l2', minutes: 600),
      ]);
      expect(
        blockTagOf(block, viewingToday: true, nowMinutes: 600),
        isA<MealTag>(),
        reason: 'boundary: exactly-due is not past',
      );
      expect(
        blockTagOf(block, viewingToday: true, nowMinutes: 300),
        isA<MealTag>(),
        reason: 'a future block of today',
      );
    });

    test('a past day never shows progress, however late the now-minute', () {
      final block = blockOf([
        dose(logId: 'l1', minutes: 480, status: DoseStatus.taken),
        dose(logId: 'l2', minutes: 600),
      ]);
      expect(
        blockTagOf(block, viewingToday: false, nowMinutes: 1439),
        isA<MealTag>(),
        reason: 'TRACK-03 neutrality: no warn tag off today',
      );
    });

    test('sealed hierarchy switches exhaustively', () {
      String describe(BlockTag t) => switch (t) {
        AllTakenTag() => 'allTaken',
        AllMarkedTag() => 'allMarked',
        ProgressTag() => 'progress',
        MealTag() => 'meal',
      };
      expect(describe(const MealTag()), 'meal');
    });
  });

  group('currentBlockIndex (P-5)', () {
    final blocks = groupIntoBlocks([
      dose(logId: 'l1', minutes: 480), // morning
      dose(logId: 'l2', minutes: 780, regimenId: 'r2'), // day
      dose(logId: 'l3', minutes: 1320, regimenId: 'r3'), // night
    ]);

    test('first block whose doses have not all passed', () {
      expect(currentBlockIndex(blocks, viewingToday: true, nowMinutes: 300), 0);
      expect(currentBlockIndex(blocks, viewingToday: true, nowMinutes: 481), 1);
      expect(
        currentBlockIndex(blocks, viewingToday: true, nowMinutes: 980),
        3,
        reason: 'the evening block is empty and therefore absent',
      );
    });

    test('boundary: a dose exactly at the now-minute has not passed', () {
      expect(currentBlockIndex(blocks, viewingToday: true, nowMinutes: 480), 0);
    });

    test('null once every block of today has passed', () {
      expect(
        currentBlockIndex(blocks, viewingToday: true, nowMinutes: 1439),
        null,
      );
    });

    test('null for any non-today view', () {
      expect(
        currentBlockIndex(blocks, viewingToday: false, nowMinutes: 300),
        isNull,
      );
      expect(
        currentBlockIndex(blocks, viewingToday: false, nowMinutes: 1439),
        isNull,
      );
    });

    test('null for an empty day', () {
      expect(
        currentBlockIndex(const [], viewingToday: true, nowMinutes: 600),
        isNull,
      );
    });
  });

  group('dayRingCounts (DECIDED-7)', () {
    test('taken vs every dose of the day; skipped counts as not-taken', () {
      final counts = dayRingCounts([
        dose(logId: 'l1', minutes: 480, status: DoseStatus.taken),
        dose(logId: 'l2', minutes: 600, status: DoseStatus.skipped),
        dose(logId: 'l3', minutes: 780),
      ]);
      expect(counts, (taken: 1, total: 3));
    });

    test('all skipped -> 0 of n (E-6)', () {
      expect(
        dayRingCounts([
          dose(logId: 'l1', minutes: 480, status: DoseStatus.skipped),
          dose(logId: 'l2', minutes: 600, status: DoseStatus.skipped),
        ]),
        (taken: 0, total: 2),
      );
    });

    test('empty day -> 0 of 0', () {
      expect(dayRingCounts(const []), (taken: 0, total: 0));
    });
  });

  group('paused-regimen interplay (PF-9)', () {
    test('helpers make no pause-specific decision', () {
      // watchDay filters a paused regimen's PENDING doses at the query level;
      // its already-marked doses still arrive here and read normally.
      final block = groupIntoBlocks([
        dose(logId: 'l1', minutes: 480, status: DoseStatus.taken, paused: true),
      ]).single;
      expect(
        blockTagOf(block, viewingToday: true, nowMinutes: 1200),
        isA<AllTakenTag>(),
      );
      expect(
        dayRingCounts([
          dose(
            logId: 'l1',
            minutes: 480,
            status: DoseStatus.taken,
            paused: true,
          ),
        ]),
        (taken: 1, total: 1),
      );
      expect(
        isMissed(
          dose(
            logId: 'l1',
            minutes: 480,
            status: DoseStatus.taken,
            paused: true,
          ),
          viewedDay: DateTime.utc(2026, 8, 14),
          today: DateTime.utc(2026, 8, 15),
        ),
        isFalse,
      );
    });
  });
}
