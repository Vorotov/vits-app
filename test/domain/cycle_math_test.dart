import 'dart:math';

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

  group('runsEveryDayFrom — the tier-A predicate', () {
    final today = DateTime.utc(2026, 8, 16);

    test('a not-paused daily cycle already started runs every day', () {
      expect(
        runsEveryDayFrom(cyclic(on: 30, off: 0, start: today), today),
        isTrue,
      );
      expect(
        runsEveryDayFrom(
          cyclic(on: 30, off: 0, start: DateTime.utc(2020, 1, 1)),
          today,
        ),
        isTrue,
      );
    });

    test('a daily cycle whose start date is TOMORROW does not', () {
      expect(
        runsEveryDayFrom(
          cyclic(on: 30, off: 0, start: DateTime.utc(2026, 8, 17)),
          today,
        ),
        isFalse,
        reason: 'promoting it would arm a repeat that fires before the regimen '
            'begins — the one case where the tier predicate must be stricter '
            'than offDays == 0.',
      );
    });

    test('a paused daily cycle does not', () {
      expect(
        runsEveryDayFrom(
          cyclic(on: 30, off: 0, paused: true, start: today),
          today,
        ),
        isFalse,
      );
    });

    test('a cycle with a zero on-day count does not', () {
      expect(runsEveryDayFrom(cyclic(on: 0, off: 0, start: today), today),
          isFalse);
    });

    test('a cycle with any non-zero off-day count does not', () {
      expect(runsEveryDayFrom(cyclic(on: 56, off: 28, start: today), today),
          isFalse);
      expect(runsEveryDayFrom(cyclic(on: 364, off: 1, start: today), today),
          isFalse);
    });

    test('a course never does, whatever its dates', () {
      expect(
        runsEveryDayFrom(
          course(start: today, end: DateTime.utc(2026, 9, 30)),
          today,
        ),
        isFalse,
      );
      expect(
        runsEveryDayFrom(
          course(start: today, end: DateTime.utc(2099, 12, 31)),
          today,
        ),
        isFalse,
        reason: 'a course ends, and a repeat does not — even one ending in 2099 '
            'is a lie the platform would keep telling afterwards.',
      );
      expect(runsEveryDayFrom(course(start: today, end: null), today), isFalse);
    });

    // ---- The property that binds the predicate to the rule it mirrors ----
    //
    // A comment claiming these two agree is worth nothing. These two tests are
    // what will fail the day someone changes the activity rule — a new regimen
    // kind, a new pre-start rule, a new pause semantic — without looking at the
    // predicate one screenful below it.

    test('POSITIVE: everything the predicate accepts is active on all 400 days',
        () {
      // Unbounded: this direction holds for ALL inputs, so the generator is
      // deliberately wide (see _generateRegimen).
      final rnd = Random(_propertySeed);
      var accepted = 0;
      for (var sample = 0; sample < _propertySamples; sample++) {
        final r = _generateRegimen(rnd, today, bounded: false);
        if (!runsEveryDayFrom(r, today)) continue;
        accepted++;
        for (var offset = 0; offset < _propertyWalkDays; offset++) {
          expect(
            isActiveOn(r, today.add(Duration(days: offset))),
            isTrue,
            reason: 'runsEveryDayFrom accepted ${_describe(r, today)} but '
                'isActiveOn is false on day $offset of the walk.',
          );
        }
      }
      expect(
        accepted,
        greaterThan(20),
        reason: 'a generator that produced no accepted regimen would make this '
            'property vacuous, which is the one way it can pass while proving '
            'nothing.',
      );
    });

    // Bounded, and the bound is part of the property rather than a convenience.
    // Two shapes make the predicate answer false while isActiveOn holds across
    // all 400 days, and NEITHER is a defect — both are the walk being too short
    // to observe a lapse that really is coming:
    //
    //   1. a COURSE starting on or before today whose inclusive end date is on
    //      or after today + 399: it ends, so the predicate is right to refuse
    //      it, but it has not ended inside the walk;
    //   2. a CYCLIC regimen with a non-zero off-day count and an on-day count
    //      of 400 or more: it has breaks, so the predicate is right to refuse
    //      it, but the first break falls outside the walk.
    //
    // So the generator is bounded so that every regimen it produces lapses
    // within the walk — and those bounds also match what this product's own
    // editor can produce, which is why the bound costs nothing in coverage.
    // Widen them and this test goes red on a predicate that is still correct.
    //
    // A future-start DAILY regimen is NOT one of these shapes and is NOT
    // exempt: isActiveOn is false on day zero of the walk, because the walk
    // starts before the regimen does, so the negative direction holds for it.
    // What is special about it is only that its predicate answer changes when
    // its start date arrives — at which point the ordinary re-derivation
    // promotes it. That is a time-varying answer, not an exempt shape.
    test('NEGATIVE: everything the predicate rejects lapses inside 400 days',
        () {
      final rnd = Random(_propertySeed);
      var rejected = 0;
      for (var sample = 0; sample < _propertySamples; sample++) {
        final r = _generateRegimen(rnd, today, bounded: true);
        if (runsEveryDayFrom(r, today)) continue;
        rejected++;
        final lapses = List.generate(_propertyWalkDays, (offset) => offset).any(
          (offset) => !isActiveOn(r, today.add(Duration(days: offset))),
        );
        expect(
          lapses,
          isTrue,
          reason: 'runsEveryDayFrom rejected ${_describe(r, today)} but '
              'isActiveOn holds on every one of the $_propertyWalkDays days of '
              'the walk — so the predicate is stricter than the rule.',
        );
      }
      expect(rejected, greaterThan(20), reason: 'the property must not be '
          'vacuous — see the positive direction.');
    });
  });
}

/// Fixed so a property failure is reproducible from the failure message alone.
const _propertySeed = 20260817;

/// Samples per direction. 400 days each, ~1.6M `isActiveOn` calls in total,
/// which costs a fraction of a second on pure UTC date arithmetic.
const _propertySamples = 1000;

/// The walk length. 400 days rather than a month for the same reason the DST and
/// year-boundary groups above reach that far: it must cross a year boundary and
/// both DST transitions.
const _propertyWalkDays = 400;

/// The NEGATIVE generator's bounds — named so the bound reads as a decision
/// rather than as a coincidence. See the comment on the negative property for
/// why each one is load-bearing.
const _boundedMaxOnDays = 30;
const _boundedMaxOffDays = 14;
const _boundedMaxCourseLengthDays = 120;

/// The POSITIVE generator's (deliberately wide) ranges.
const _wideMaxOnDays = 500;
const _wideMaxOffDays = 500;
const _wideMaxStartOffsetDays = 450;
const _wideMaxCourseLengthDays = 500;

/// One random regimen.
///
/// `bounded: true` restricts on-days, off-days and course length so that every
/// regimen the predicate rejects can be observed lapsing inside the 400-day
/// walk — the negative direction's precondition. `bounded: false` is wide.
///
/// `offDays == 0` is drawn with probability 1/4 rather than uniformly: it is the
/// single branch the predicate turns on, and a uniform draw over 0..500 would
/// hit it about twice in a thousand samples, leaving the positive direction
/// technically green and practically untested.
///
/// A negative `onDays` is unreachable: `Regimen`'s own assert forbids it, so the
/// predicate's `<= 0` guard (which mirrors `isActiveOn`'s) is exercised at 0.
Regimen _generateRegimen(Random rnd, DateTime today, {required bool bounded}) {
  final kind = rnd.nextBool() ? RegimenKind.cyclic : RegimenKind.course;
  final maxStartOffset = bounded ? 400 : _wideMaxStartOffsetDays;
  final startOffset = rnd.nextInt(maxStartOffset * 2 + 1) - maxStartOffset;
  final start = today.add(Duration(days: startOffset));
  final on = bounded
      ? 1 + rnd.nextInt(_boundedMaxOnDays)
      : rnd.nextInt(_wideMaxOnDays + 1);
  final off = bounded
      ? rnd.nextInt(_boundedMaxOffDays + 1)
      : (rnd.nextInt(4) == 0 ? 0 : 1 + rnd.nextInt(_wideMaxOffDays));
  final maxCourseLength =
      bounded ? _boundedMaxCourseLengthDays : _wideMaxCourseLengthDays;
  final DateTime? end = kind == RegimenKind.course && rnd.nextInt(8) != 0
      ? (bounded
          // Bounded: the end date is within today + 120 whatever the start, so
          // the course provably ends inside the walk.
          ? today.add(Duration(days: rnd.nextInt(maxCourseLength + 1)))
          : start.add(Duration(days: rnd.nextInt(maxCourseLength + 1))))
      : null;
  return Regimen(
    id: 'gen',
    supplementId: 's-gen',
    kind: kind,
    startDate: start,
    endDate: end,
    onDays: on,
    offDays: off,
    paused: rnd.nextInt(4) == 0,
    slots: const [],
  );
}

/// A regimen rendered for a property-failure message, so a red test names the
/// exact input rather than only the seed.
String _describe(Regimen r, DateTime today) => '${r.kind.name}('
    'start: ${r.startDate.toIso8601String().substring(0, 10)}'
    '${startOffsetLabel(r, today)}, '
    'end: ${r.endDate?.toIso8601String().substring(0, 10) ?? 'null'}, '
    'on: ${r.onDays}, off: ${r.offDays}, paused: ${r.paused})';

String startOffsetLabel(Regimen r, DateTime today) =>
    ' [today${r.startDate.difference(today).inDays >= 0 ? '+' : ''}'
    '${r.startDate.difference(today).inDays}]';
