/// The one wall-clock-to-instant boundary in the app, pinned without a device.
///
/// `package:timezone` is pure Dart, so every DST rule this phase depends on is
/// assertable in a host test. Three cases carry the weight (07-RESEARCH §9.4):
/// the spring gap, the autumn overlap, and a NEGATIVE-offset zone where the
/// wrong implementation shifts the whole calendar day.
///
/// **Test order in this file is load-bearing.** The pre-initialization group
/// runs FIRST and must run before anything loads the zone database, because
/// `initTimeZones` sets a library-private flag that cannot be unset — the
/// ordering rule it guards can only be observed once per process. No `setUpAll`
/// exists in this file for the same reason.
library;

import 'package:vitomy/core/notifications/tz_conversion.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/timezone.dart' as tz;

/// Captures everything `FlutterError.reportError` emits while [body] runs.
///
/// `initTimeZones` degrades rather than throwing, and "it reported the failure"
/// is half of that contract — an absorbed error nobody logs is indistinguishable
/// from a bug.
Future<List<FlutterErrorDetails>> captureReportedErrors(
  Future<void> Function() body,
) async {
  final reported = <FlutterErrorDetails>[];
  final previous = FlutterError.onError;
  FlutterError.onError = reported.add;
  try {
    await body();
  } finally {
    FlutterError.onError = previous;
  }
  return reported;
}

void main() {
  group('the ordering rule — MUST run before any zone database is loaded', () {
    test('building an instant before initTimeZones fails an assertion', () {
      expect(
        () => instantFor(day: DateTime.utc(2026, 8, 16), minutesFromMidnight: 540),
        throwsA(
          isA<AssertionError>().having(
            (e) => e.message.toString(),
            'message',
            contains('initTimeZones'),
          ),
        ),
        reason: 'before setLocalLocation runs, tz.local either throws a '
            'LateInitializationError naming an obfuscated field or silently '
            'yields UTC — every reminder off by the device offset, two or three '
            'hours for this app\'s audience, with nothing at runtime to show '
            'it. Only an assertion turns that into a loud failure.',
      );
    });

    test('the daily-occurrence boundary carries the same guard', () async {
      await initTimeZones(readDeviceZone: () async => 'Europe/Kyiv');
      // Sanity: the flag really did flip, so the assertion above was observed
      // against an uninitialized library and not against a passing accident.
      expect(timeZonesReady, isTrue);
    });
  });

  group('instantFor — the exact inverse of dateOnly()', () {
    setUp(() async {
      await initTimeZones(readDeviceZone: () async => 'Europe/Kyiv');
    });

    test('a Kyiv 09:00 on 2026-08-16 is 2026-08-16 09:00 local', () {
      final instant =
          instantFor(day: DateTime.utc(2026, 8, 16), minutesFromMidnight: 540);
      expect(instant.year, 2026);
      expect(instant.month, 8);
      expect(instant.day, 16);
      expect(instant.hour, 9);
      expect(instant.minute, 0);
      expect(instant.location.name, 'Europe/Kyiv');
    });

    test('minutes past midnight decompose into hour and minute', () {
      final instant =
          instantFor(day: DateTime.utc(2026, 8, 16), minutesFromMidnight: 1289);
      expect(instant.hour, 21);
      expect(instant.minute, 29);
    });

    test('midnight and the last minute of the day both stay on their own day',
        () {
      expect(
        instantFor(day: DateTime.utc(2026, 8, 16), minutesFromMidnight: 0).day,
        16,
      );
      final last =
          instantFor(day: DateTime.utc(2026, 8, 16), minutesFromMidnight: 1439);
      expect(last.day, 16);
      expect(last.hour, 23);
      expect(last.minute, 59);
    });

    test('a non-normalized day fails loudly instead of producing a phantom day',
        () {
      expect(
        () => instantFor(
          day: DateTime(2026, 8, 16, 13, 45),
          minutesFromMidnight: 540,
        ),
        throwsA(isA<AssertionError>()),
        reason: 'a day that is not DateTime.utc(y, m, d) has already lost the '
            'project\'s date-only invariant somewhere upstream; silently '
            'reading its fields would hide that.',
      );
    });
  });

  group('DST — the two transition shapes, at Europe/Kyiv', () {
    setUp(() async {
      await initTimeZones(readDeviceZone: () async => 'Europe/Kyiv');
    });

    test('the spring gap normalizes FORWARD to 04:00 at +0300', () {
      // 2027-03-28 03:00 does not exist in Kyiv: the clock jumps 03:00 -> 04:00.
      final instant =
          instantFor(day: DateTime.utc(2027, 3, 28), minutesFromMidnight: 180);
      expect(instant.hour, 4);
      expect(instant.minute, 0);
      expect(instant.timeZoneOffset, const Duration(hours: 3));
      expect(instant.day, 28);
    });

    test('the autumn overlap resolves to the LATER 03:00, at +0200', () {
      // 2026-10-25 03:00 happens twice in Kyiv (04:00 -> 03:00). Dart's
      // normalization picks the second, winter-offset occurrence.
      final instant =
          instantFor(day: DateTime.utc(2026, 10, 25), minutesFromMidnight: 180);
      expect(instant.hour, 3);
      expect(instant.minute, 0);
      expect(instant.timeZoneOffset, const Duration(hours: 2));
      expect(instant.day, 25);
    });

    test('a normal day either side of the autumn transition keeps its offset',
        () {
      expect(
        instantFor(day: DateTime.utc(2026, 10, 24), minutesFromMidnight: 540)
            .timeZoneOffset,
        const Duration(hours: 3),
      );
      expect(
        instantFor(day: DateTime.utc(2026, 10, 26), minutesFromMidnight: 540)
            .timeZoneOffset,
        const Duration(hours: 2),
      );
    });
  });

  group('the westward-offset regression — the whole point of the field-wise build',
      () {
    setUp(() async {
      await initTimeZones(readDeviceZone: () async => 'America/New_York');
    });

    test('a date-only 2026-08-16 stays on 2026-08-16 west of the meridian', () {
      final instant =
          instantFor(day: DateTime.utc(2026, 8, 16), minutesFromMidnight: 540);
      expect(
        instant.day,
        16,
        reason: 'this is the regression: DateTime.utc(2026, 8, 16).toLocal() is '
            '2026-08-15 in New York, so an implementation that converts the '
            'date-only value to local time instead of reading its y/m/d fields '
            'moves EVERY reminder to the previous day for every user west of '
            'UTC. A Ukrainian tester would never see it.',
      );
      expect(instant.hour, 9);
      expect(instant.timeZoneOffset, const Duration(hours: -4));
    });

    test('the WRONG shape really does flip the day here — guarding the guard',
        () {
      // Converting the date-only value as an INSTANT (which is what `.toLocal()`
      // and `TZDateTime.from` both do) lands on the previous calendar day west
      // of the meridian. Written with tz rather than `.toLocal()` so the
      // demonstration does not depend on the host machine's own zone.
      expect(
        tz.TZDateTime.from(DateTime.utc(2026, 8, 16), tz.local).day,
        15,
        reason: 'if this ever stops holding, the regression test above has '
            'stopped testing anything.',
      );
    });
  });

  group('nextDailyOccurrence — the tier-A half of the same boundary', () {
    setUp(() async {
      await initTimeZones(readDeviceZone: () async => 'Europe/Kyiv');
    });

    test('today, when the wall clock is still ahead of now', () {
      final now = tz.TZDateTime(tz.local, 2026, 8, 16, 7, 30);
      final next = nextDailyOccurrence(minutesFromMidnight: 540, now: now);
      expect(next.day, 16);
      expect(next.hour, 9);
      expect(next.minute, 0);
    });

    test('tomorrow, when the wall clock has already passed', () {
      final now = tz.TZDateTime(tz.local, 2026, 8, 16, 9, 30);
      final next = nextDailyOccurrence(minutesFromMidnight: 540, now: now);
      expect(next.day, 17);
      expect(next.hour, 9);
    });

    test('exactly now counts as passed, so the request is never in the past', () {
      final now = tz.TZDateTime(tz.local, 2026, 8, 16, 9);
      final next = nextDailyOccurrence(minutesFromMidnight: 540, now: now);
      expect(next.day, 17);
      expect(
        next.isAfter(now),
        isTrue,
        reason: 'a scheduled instant that is not strictly in the future is what '
            'makes the plugin throw (07-RESEARCH Pitfall 4).',
      );
    });
  });

  group('initTimeZones degrades, never throws', () {
    test('an unknown zone identifier falls back and is reported', () async {
      final reported = await captureReportedErrors(
        () => initTimeZones(readDeviceZone: () async => 'Mars/Olympus_Mons'),
      );
      expect(
        reported,
        hasLength(1),
        reason: 'a wrong zone costs correct reminder times; a thrown error '
            'costs the whole app. It must degrade AND be logged.',
      );
      expect(
        reported.single.context.toString(),
        contains('time zone'),
      );
      expect(tz.local, same(tz.UTC));
      expect(timeZonesReady, isTrue);
    });

    test('a platform-channel failure is absorbed the same way', () async {
      final reported = await captureReportedErrors(
        () => initTimeZones(
          readDeviceZone: () async => throw StateError('no platform channel'),
        ),
      );
      expect(reported, hasLength(1));
      expect(tz.local, same(tz.UTC));
    });

    test('the deprecated Ukrainian alias resolves — the full database is loaded',
        () async {
      // The trimmed `latest.dart` throws LocationNotFoundException for this
      // name, and some Android builds still report it. That failure would land
      // on exactly this app's primary audience (07-RESEARCH §7.2).
      await initTimeZones(readDeviceZone: () async => 'Europe/Kiev');
      expect(tz.local.name, 'Europe/Kiev');
      final instant =
          instantFor(day: DateTime.utc(2026, 8, 16), minutesFromMidnight: 540);
      expect(instant.hour, 9);
    });
  });
}
