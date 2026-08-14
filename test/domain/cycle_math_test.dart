import 'package:boostque/core/domain/cycle_math.dart';
import 'package:boostque/core/domain/models.dart';
import 'package:flutter_test/flutter_test.dart';

Regimen cyclic({
  int on = 56,
  int off = 28,
  bool paused = false,
  DateTime? start,
}) =>
    Regimen(
      id: 'r1',
      supplementId: 's1',
      kind: RegimenKind.cyclic,
      startDate: start ?? DateTime.utc(2026, 8, 14),
      endDate: null,
      onDays: on,
      offDays: off,
      paused: paused,
      slots: const [],
    );

Regimen course({DateTime? start, DateTime? end}) => Regimen(
      id: 'r2',
      supplementId: 's1',
      kind: RegimenKind.course,
      startDate: start ?? DateTime.utc(2026, 8, 14),
      endDate: end,
      onDays: 0,
      offDays: 0,
      paused: false,
      slots: const [],
    );

void main() {
  final start = DateTime.utc(2026, 8, 14);

  group('cyclic 56on/28off from 2026-08-14 (CONTEXT exemplar)', () {
    // This 84-day window crosses the EU DST transition (2026-10-25 = day 72);
    // correct modulo arithmetic across it is exactly what these assertions
    // prove.
    test('day 0 is active', () {
      expect(isActiveOn(cyclic(), start), isTrue);
    });
    test('day 55 (last on-day) is active', () {
      expect(isActiveOn(cyclic(), start.add(const Duration(days: 55))), isTrue);
    });
    test('day 56 (first off-day) is inactive', () {
      expect(
          isActiveOn(cyclic(), start.add(const Duration(days: 56))), isFalse);
    });
    test('day 83 (last off-day) is inactive', () {
      expect(
          isActiveOn(cyclic(), start.add(const Duration(days: 83))), isFalse);
    });
    test('day 84 (cycle 2 start) is active', () {
      expect(isActiveOn(cyclic(), start.add(const Duration(days: 84))), isTrue);
    });
  });

  group('DST parity: cyclic 1on/1off from 2026-03-01', () {
    // Even day index = active, odd = inactive. Under local-time arithmetic a
    // 23h/25h DST day breaks the parity; UTC math must not.
    final r = cyclic(on: 1, off: 1, start: DateTime.utc(2026, 3, 1));

    test('parity across EU DST start (2026-03-29)', () {
      expect(isActiveOn(r, DateTime.utc(2026, 3, 8)), isFalse); // day 7, odd
      expect(isActiveOn(r, DateTime.utc(2026, 3, 9)), isTrue); // day 8, even
    });

    test('parity across EU DST end (2026-10-25/26)', () {
      expect(isActiveOn(r, DateTime.utc(2026, 10, 25)), isTrue); // day 238
      expect(isActiveOn(r, DateTime.utc(2026, 10, 26)), isFalse); // day 239
    });
  });

  group('year boundary: cyclic 28on/28off from 2026-12-01 (CONTEXT exemplar)',
      () {
    final r = cyclic(on: 28, off: 28, start: DateTime.utc(2026, 12, 1));

    test('2026-12-28 (day 27) is active', () {
      expect(isActiveOn(r, DateTime.utc(2026, 12, 28)), isTrue);
    });
    test('2027-01-05 (day 35) is inactive', () {
      expect(isActiveOn(r, DateTime.utc(2027, 1, 5)), isFalse);
    });
    test('2027-01-26 (day 56, cycle 2) is active', () {
      expect(isActiveOn(r, DateTime.utc(2027, 1, 26)), isTrue);
    });
  });

  group('course semantics', () {
    test('inclusive end date (CONTEXT exemplar 2026-08-14..2026-09-30)', () {
      final r = course(end: DateTime.utc(2026, 9, 30));
      expect(isActiveOn(r, DateTime.utc(2026, 9, 30)), isTrue);
      expect(isActiveOn(r, DateTime.utc(2026, 10, 1)), isFalse);
    });

    test('course with null endDate is inactive on any day at/after start', () {
      final r = course(end: null);
      expect(isActiveOn(r, start), isFalse);
      expect(isActiveOn(r, start.add(const Duration(days: 30))), isFalse);
    });
  });

  group('guards', () {
    test('paused regimen is inactive on any day', () {
      expect(isActiveOn(cyclic(paused: true), start), isFalse);
      expect(
        isActiveOn(cyclic(paused: true), start.add(const Duration(days: 10))),
        isFalse,
      );
    });

    test('any regimen is inactive before startDate', () {
      expect(isActiveOn(cyclic(), DateTime.utc(2026, 8, 13)), isFalse);
      expect(
        isActiveOn(course(end: DateTime.utc(2026, 9, 30)),
            DateTime.utc(2026, 8, 13)),
        isFalse,
      );
    });

    test('cyclic with offDays 0 is active on day 200', () {
      expect(
        isActiveOn(cyclic(off: 0), start.add(const Duration(days: 200))),
        isTrue,
      );
    });

    test('cyclic with onDays 0 is never active', () {
      expect(isActiveOn(cyclic(on: 0, off: 7), start), isFalse);
    });
  });

  group('dateOnly (D-13)', () {
    test('local wall-clock input normalizes to UTC calendar day of y/m/d', () {
      final normalized = dateOnly(DateTime(2026, 3, 29, 23, 30));
      expect(normalized, DateTime.utc(2026, 3, 29));
      expect(normalized.isUtc, isTrue);
    });
  });
}
