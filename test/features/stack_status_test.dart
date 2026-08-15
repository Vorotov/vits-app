/// Unit tests for statusOf + scheduleSummaryOf (plan 02-03, Task 2).
///
/// Pure-function matrix in the cycle_math_test style: no widgets, no clock —
/// `today` passed explicitly, all fixtures UTC date-only (P-4, E-4/D10, E-7).
/// Boundary cases follow the 11-14 discipline: today == startDate is active
/// (not planned), today == endDate is active (inclusive end), and
/// today == endDate + 1 day is finished.
library;

import 'package:boostque/core/domain/models.dart';
import 'package:boostque/core/domain/repositories.dart';
import 'package:boostque/features/stack/stack_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const supplement = Supplement(
    id: 's1',
    name: 'Магній',
    doseText: '400 мг',
    colorValue: 0xFF6B6FA8,
    note: '',
  );

  const slot1 = DoseSlot(id: 'sl1', minutesFromMidnight: 480, doseLabel: '');
  const slot2 = DoseSlot(id: 'sl2', minutesFromMidnight: 1140, doseLabel: '');

  Regimen regimen({
    RegimenKind kind = RegimenKind.cyclic,
    DateTime? startDate,
    DateTime? endDate,
    int onDays = 56,
    int offDays = 28,
    bool paused = false,
    List<DoseSlot> slots = const [slot1],
  }) =>
      Regimen(
        id: 'r1',
        supplementId: 's1',
        kind: kind,
        startDate: startDate ?? DateTime.utc(2026, 8, 1),
        endDate: endDate,
        onDays: onDays,
        offDays: offDays,
        paused: paused,
        slots: slots,
      );

  StackEntry entryWith(Regimen? r) =>
      StackEntry(supplement: supplement, regimen: r);

  group('statusOf matrix (P-4, D10)', () {
    final today = DateTime.utc(2026, 8, 15);

    test('null regimen -> fresh (E-7)', () {
      expect(statusOf(entryWith(null), today), StackStatus.fresh);
    });

    test('paused -> paused, before any date logic', () {
      expect(
        statusOf(entryWith(regimen(paused: true)), today),
        StackStatus.paused,
      );
      // Paused wins over planned...
      expect(
        statusOf(
          entryWith(
              regimen(paused: true, startDate: DateTime.utc(2026, 9, 1))),
          today,
        ),
        StackStatus.paused,
      );
      // ...and over finished.
      expect(
        statusOf(
          entryWith(regimen(
            paused: true,
            kind: RegimenKind.course,
            startDate: DateTime.utc(2026, 7, 1),
            endDate: DateTime.utc(2026, 7, 28),
          )),
          today,
        ),
        StackStatus.paused,
      );
    });

    test('today before startDate -> planned', () {
      expect(
        statusOf(
          entryWith(regimen(startDate: DateTime.utc(2026, 8, 16))),
          today,
        ),
        StackStatus.planned,
      );
    });

    test('course ended before today -> finished (E-4/D10)', () {
      expect(
        statusOf(
          entryWith(regimen(
            kind: RegimenKind.course,
            startDate: DateTime.utc(2026, 7, 1),
            endDate: DateTime.utc(2026, 7, 28),
          )),
          today,
        ),
        StackStatus.finished,
      );
    });

    test('course with null endDate never reads finished', () {
      expect(
        statusOf(
          entryWith(regimen(
            kind: RegimenKind.course,
            startDate: DateTime.utc(2026, 7, 1),
            endDate: null,
          )),
          today,
        ),
        StackStatus.active,
      );
    });

    test('cyclic past endDate-irrelevant dates -> active', () {
      expect(statusOf(entryWith(regimen()), today), StackStatus.active);
    });

    test('boundary: today == startDate is active, not planned', () {
      expect(
        statusOf(
          entryWith(regimen(startDate: DateTime.utc(2026, 8, 15))),
          today,
        ),
        StackStatus.active,
      );
    });

    test('boundary: today == endDate is active (inclusive end)', () {
      expect(
        statusOf(
          entryWith(regimen(
            kind: RegimenKind.course,
            startDate: DateTime.utc(2026, 8, 1),
            endDate: DateTime.utc(2026, 8, 15),
          )),
          today,
        ),
        StackStatus.active,
      );
    });

    test('boundary: today == endDate + 1 day is finished', () {
      expect(
        statusOf(
          entryWith(regimen(
            kind: RegimenKind.course,
            startDate: DateTime.utc(2026, 8, 1),
            endDate: DateTime.utc(2026, 8, 14),
          )),
          today,
        ),
        StackStatus.finished,
      );
    });

    test('non-date-only today is normalized (dateOnly discipline)', () {
      // A local wall-clock "today" must compare like its calendar day.
      expect(
        statusOf(
          entryWith(regimen(startDate: DateTime.utc(2026, 8, 15))),
          DateTime(2026, 8, 15, 23, 45),
        ),
        StackStatus.active,
      );
    });
  });

  group('scheduleSummaryOf (P-4)', () {
    test('null regimen -> NoSummary', () {
      expect(scheduleSummaryOf(entryWith(null)), isA<NoSummary>());
    });

    test('cyclic -> CyclicSummary(onDays, offDays, slotCount)', () {
      final summary = scheduleSummaryOf(
        entryWith(regimen(onDays: 56, offDays: 28, slots: [slot1, slot2])),
      );
      expect(summary, isA<CyclicSummary>());
      final cyclic = summary as CyclicSummary;
      expect(cyclic.onDays, 56);
      expect(cyclic.offDays, 28);
      expect(cyclic.slotCount, 2);
    });

    test('course -> CourseSummary(start, end, slotCount)', () {
      final summary = scheduleSummaryOf(entryWith(regimen(
        kind: RegimenKind.course,
        startDate: DateTime.utc(2026, 9, 1),
        endDate: DateTime.utc(2026, 9, 28),
        slots: [slot1],
      )));
      expect(summary, isA<CourseSummary>());
      final course = summary as CourseSummary;
      expect(course.start, DateTime.utc(2026, 9, 1));
      expect(course.end, DateTime.utc(2026, 9, 28));
      expect(course.slotCount, 1);
    });

    test('paused regimens keep their summary (chip carries the pause '
        'signal, UI-SPEC S1)', () {
      final summary =
          scheduleSummaryOf(entryWith(regimen(paused: true)));
      expect(summary, isA<CyclicSummary>());
    });

    test('sealed hierarchy switches exhaustively', () {
      // Compile-time proof: a switch over ScheduleSummary needs no default.
      String describe(ScheduleSummary s) => switch (s) {
            CyclicSummary() => 'cyclic',
            CourseSummary() => 'course',
            NoSummary() => 'none',
          };
      expect(describe(const NoSummary()), 'none');
    });
  });
}
