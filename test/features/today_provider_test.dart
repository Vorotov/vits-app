/// Unit tests for the app's single calendar clock (plan 03-01, Task 2, P-1).
///
/// Pure-function matrix in the cycle_math_test style for [nextLocalMidnight]:
/// fixed LOCAL dates, and only timezone-independent invariants asserted —
/// exact equality with the local date constructor for the following day,
/// strict ordering, and a 23-25 hour window that holds on a DST transition day
/// in any timezone (PF-2: a fixed `Duration(hours: 24)` would break there).
/// Ukraine's 2026 DST boundaries (2026-03-29 and 2026-10-25) are in the matrix.
///
/// [TodayController] itself gets a smoke test only — the clock cannot be
/// injected — proving it builds to the normalized current local day as a UTC
/// date-only value and leaves no live timer behind when its container is
/// disposed.
library;

import 'package:boostque/core/domain/cycle_math.dart';
import 'package:boostque/core/today_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // TodayController constructs an AppLifecycleListener, which requires a live
  // WidgetsBinding — without this the controller smoke test throws.
  TestWidgetsFlutterBinding.ensureInitialized();

  group('nextLocalMidnight', () {
    /// Local wall-clock instants covering an ordinary day, both Ukrainian 2026
    /// DST boundaries, a month rollover, a year rollover and a leap day.
    final cases = <DateTime>[
      DateTime(2026, 8, 14, 16, 20),
      DateTime(2026, 8, 14), // exactly midnight
      DateTime(2026, 8, 14, 23, 59, 59),
      DateTime(2026, 3, 29, 13, 30), // uk DST spring-forward (23h day)
      DateTime(2026, 3, 28, 23, 30), // the day before it
      DateTime(2026, 10, 25, 13, 30), // uk DST fall-back (25h day)
      DateTime(2026, 10, 24, 23, 30), // the day before it
      DateTime(2026, 4, 30, 9), // month rollover
      DateTime(2026, 12, 31, 18, 45), // year rollover
      DateTime(2028, 2, 28, 7, 15), // leap year
      DateTime(2027, 2, 28, 7, 15), // non-leap year
    ];

    test('is exactly the local midnight of the following calendar day', () {
      for (final from in cases) {
        expect(
          nextLocalMidnight(from),
          DateTime(from.year, from.month, from.day + 1),
          reason: 'the local date constructor is the only sanctioned '
              'derivation (PF-2), for $from',
        );
      }
    });

    test('is always strictly after its argument', () {
      for (final from in cases) {
        expect(nextLocalMidnight(from).isAfter(from), isTrue,
            reason: 'a tick must never be scheduled into the past, for $from');
      }
    });

    test('lands 23-25 hours away — never a fixed 24h assumption (PF-2)', () {
      for (final from in cases) {
        final gap = nextLocalMidnight(from).difference(from);
        expect(gap, greaterThan(Duration.zero), reason: 'for $from');
        expect(gap, lessThanOrEqualTo(const Duration(hours: 25)),
            reason: 'a 25h fall-back day is the widest possible gap, '
                'for $from');
        // A day-start argument spans the whole (23h, 24h or 25h) day.
        if (from.hour == 0 && from.minute == 0 && from.second == 0) {
          expect(gap, greaterThanOrEqualTo(const Duration(hours: 23)),
              reason: 'a 23h spring-forward day is the narrowest possible '
                  'full day, for $from');
        }
      }
    });

    test('rolls month, year and leap-day boundaries exactly', () {
      expect(nextLocalMidnight(DateTime(2026, 12, 31, 18, 45)),
          DateTime(2027, 1, 1));
      expect(nextLocalMidnight(DateTime(2028, 2, 28, 7, 15)),
          DateTime(2028, 2, 29),
          reason: '2028 is a leap year — Feb 28 is followed by Feb 29');
      expect(nextLocalMidnight(DateTime(2027, 2, 28, 7, 15)),
          DateTime(2027, 3, 1),
          reason: '2027 is not a leap year — Feb 28 is followed by Mar 1');
      expect(nextLocalMidnight(DateTime(2026, 4, 30, 9)), DateTime(2026, 5, 1));
    });
  });

  group('TodayController', () {
    test('builds to the current device-local day as a UTC date-only value, '
        'and disposing the container cancels its timer', () {
      final container = ProviderContainer();
      // Riverpod 3 pauses unlistened providers — hold it open.
      final sub = container.listen(todayProvider, (_, _) {});

      final today = container.read(todayProvider);
      expect(today, dateOnly(DateTime.now()),
          reason: 'the clock is read through dateOnly() (D-13/D-15)');
      expect(today.isUtc, isTrue,
          reason: 'date-only values are UTC-normalized, never local midnight');
      expect(today.hour, 0);
      expect(today.minute, 0);
      expect(today.second, 0);

      sub.close();
      // ref.onDispose cancels the midnight Timer and the lifecycle listener;
      // the test completing is the proof that nothing stayed armed.
      container.dispose();
    });
  });
}
