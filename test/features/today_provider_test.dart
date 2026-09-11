/// Unit tests for the app's single calendar clock (plan 03-01, Task 2, P-1).
///
/// Pure-function matrix in the cycle_math_test style for [nextLocalMidnight]:
/// fixed LOCAL dates, and only timezone-independent invariants asserted —
/// exact equality with the local date constructor for the following day,
/// strict ordering, and a 23-25 hour window that holds on a DST transition day
/// in any timezone (PF-2: a fixed `Duration(hours: 24)` would break there).
/// Ukraine's 2026 DST boundaries (2026-03-29 and 2026-10-25) are in the matrix.
///
/// [TodayController] is exercised through its injected clock (TW-1): the
/// controller tests are `testWidgets`, so the automated binding's fake-async
/// zone drives the midnight `Timer` AND fails the test if one outlives it.
/// That pending-timer check is the disposal proof — the previous plain
/// `test()` claimed "the test completing is the proof that nothing stayed
/// armed", which it was not: deleting `ref.onDispose` from
/// `today_controller.dart` left it green. It now goes red, along with the
/// rollover, the DST-day scheduling, the re-arm and the resume-after-days
/// path, none of which had any coverage at all.
library;

import 'package:vitomy/core/domain/cycle_math.dart';
import 'package:vitomy/core/today_controller.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show AppLifecycleState;
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
    /// A container whose clock is [now] — a mutable local wall-clock the test
    /// moves by hand, in step with the fake-async clock `tester.pump`
    /// advances.
    ///
    /// `flutter_test`'s fake-async zone controls `Timer` but never
    /// `DateTime.now()`, so without the injected clock the midnight timer can
    /// be fired and the controller still reads back the same real day — which
    /// is precisely why the rollover had no test at all (TW-1).
    ProviderContainer clockedContainer(DateTime Function() now) =>
        ProviderContainer(
          overrides: [
            todayProvider.overrideWith(() => TodayController(now: now)),
          ],
        );

    /// Delivers a real platform lifecycle message, the way the engine does.
    ///
    /// `WidgetsBinding.handleAppLifecycleStateChanged` is `@protected`; the
    /// channel is the supported test seam.
    Future<void> sendLifecycle(
      WidgetTester tester,
      AppLifecycleState state,
    ) async {
      await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
        'flutter/lifecycle',
        const StringCodec().encodeMessage(state.toString()),
        (_) {},
      );
    }

    testWidgets('builds to the current device-local day as a UTC date-only '
        'value', (tester) async {
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
      container.dispose();
    });

    testWidgets('disposing the container leaves NO armed timer behind (TW-1)',
        (tester) async {
      // This is a `testWidgets`, not a `test`, deliberately: only the
      // automated binding's fake-async zone detects a timer that outlives the
      // test, and that detection IS the assertion here. Written as a plain
      // `test()` — as it was — deleting `ref.onDispose` from
      // today_controller.dart changed nothing and the test still passed, so
      // the comment claiming "the test completing is the proof that nothing
      // stayed armed" was claiming something the code did not establish.
      final container = ProviderContainer();
      final sub = container.listen(todayProvider, (_, _) {});
      container.read(todayProvider);

      sub.close();
      container.dispose();

      // The binding fails the test at teardown with "A Timer is still pending"
      // if ref.onDispose stopped cancelling the midnight Timer.
    });

    testWidgets('the day rolls over AT local midnight and the timer re-arms '
        'itself for the next one (TW-1)', (tester) async {
      var now = DateTime(2026, 8, 14, 23, 59, 30);
      final container = clockedContainer(() => now);
      final sub = container.listen(todayProvider, (_, _) {});

      expect(container.read(todayProvider), DateTime.utc(2026, 8, 14));

      // 30s to midnight + the 1s of fudge the scheduler adds.
      now = DateTime(2026, 8, 15, 0, 0, 1);
      await tester.pump(const Duration(seconds: 31));
      expect(container.read(todayProvider), DateTime.utc(2026, 8, 15),
          reason: 'the tick lands AFTER the boundary and flips the day');

      // Re-armed by _refresh: a second midnight rolls it again with no
      // external nudge. A day that flipped once and then went stale is the
      // failure this half of the test exists for.
      now = DateTime(2026, 8, 16, 0, 0, 1);
      await tester.pump(const Duration(hours: 24));
      expect(container.read(todayProvider), DateTime.utc(2026, 8, 16),
          reason: '_refresh re-arms the timer every time it fires');

      // Disposed INSIDE the body, never in addTearDown: the binding checks
      // for pending timers before tearDown callbacks run.
      sub.close();
      container.dispose();
    });

    testWidgets('a DST spring-forward midnight (23h day) is not missed by an '
        'hour (TW-1, PF-2)', (tester) async {
      // Ukraine springs forward on 2026-03-29. The day BEFORE it is 23 hours
      // long in local time, so a fixed Duration(hours: 24) would fire an hour
      // late — the defect nextLocalMidnight exists to prevent, now proven
      // through the scheduler rather than only through the pure function.
      var now = DateTime(2026, 3, 28);
      final container = clockedContainer(() => now);
      final sub = container.listen(todayProvider, (_, _) {});

      expect(container.read(todayProvider), DateTime.utc(2026, 3, 28));

      final untilMidnight =
          nextLocalMidnight(now).difference(now) + const Duration(seconds: 1);
      now = nextLocalMidnight(now).add(const Duration(seconds: 1));
      await tester.pump(untilMidnight);

      expect(container.read(todayProvider), DateTime.utc(2026, 3, 29),
          reason: 'the tick is derived from the local date constructor, so a '
              '23-hour or 25-hour day lands on its own midnight');

      // Disposed INSIDE the body, never in addTearDown: the binding checks
      // for pending timers before tearDown callbacks run.
      sub.close();
      container.dispose();
    });

    testWidgets('a resume after DAYS re-derives the day even though the timer '
        'never fired (TW-1, E-12)', (tester) async {
      var now = DateTime(2026, 8, 14, 9);
      final container = clockedContainer(() => now);
      final sub = container.listen(todayProvider, (_, _) {});

      expect(container.read(todayProvider), DateTime.utc(2026, 8, 14));

      // Backgrounded: OS timers are suspended, so nothing fires at all...
      await sendLifecycle(tester, AppLifecycleState.inactive);
      await sendLifecycle(tester, AppLifecycleState.hidden);
      await sendLifecycle(tester, AppLifecycleState.paused);

      // ...for three days. (A timezone change while backgrounded looks
      // exactly the same from here.)
      now = DateTime(2026, 8, 17, 8);
      expect(container.read(todayProvider), DateTime.utc(2026, 8, 14),
          reason: 'nothing has told it yet — no frame, no tick');

      await sendLifecycle(tester, AppLifecycleState.hidden);
      await sendLifecycle(tester, AppLifecycleState.inactive);
      await sendLifecycle(tester, AppLifecycleState.resumed);
      await tester.pump();

      expect(container.read(todayProvider), DateTime.utc(2026, 8, 17),
          reason: 'the resume RE-DERIVES the day from the clock — it never '
              'increments the previous value (PF-2), so three suspended days '
              'cost nothing');

      // Disposed INSIDE the body, never in addTearDown: the binding checks
      // for pending timers before tearDown callbacks run.
      sub.close();
      container.dispose();
    });
  });
}
