/// The single wall-clock-to-instant boundary in the app (NOTIF-04, Pitfall 5/6).
///
/// This file exists so that `package:timezone` stops here: the domain layer and
/// the pure plan never see a `TZDateTime`, and the platform adapter builds none
/// of its own. Every zoned value in the app comes out of [instantFor] or
/// [nextDailyOccurrence], so the DST rules live in exactly one tested place.
///
/// The device-zone read is injectable for the same reason `TodayController`'s
/// wall-clock read is (`today_controller.dart:47`): it is a platform-channel
/// round trip, and without the seam nothing in this file could be tested at all
/// without reaching a plugin.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
// The FULL zone database, not the trimmed `data/latest.dart`. Research ran both:
// the trimmed one throws LocationNotFoundException for the deprecated alias
// `Europe/Kiev`, which some Android builds still report — i.e. it fails on
// precisely this app's primary audience (07-RESEARCH §7.2, Pitfall 6).
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Whether the zone database has been loaded and a local location resolved.
///
/// Read by the notification bootstrap as its readiness answer, and asserted by
/// both constructors below.
bool get timeZonesReady => _ready;
bool _ready = false;

/// Loads the zone database and resolves the device's own zone.
///
/// [readDeviceZone] returns an IANA identifier; production takes the default,
/// which is the one platform-channel call in this file. A failure to resolve the
/// zone is caught, reported to the crash logger in the shape `main.dart:28-36`
/// establishes, and degraded to UTC: a wrong zone costs correct reminder times,
/// a thrown error costs the whole app, and this file must never be able to hold
/// the launch hostage.
///
/// The fallback is the timezone package's OWN default location rather than a
/// hand-written zone name — a literal there would be a platform identifier
/// paying for an allowlist exemption that the package already exposes as a
/// value.
///
/// Idempotent: safe to call again when the device zone may have changed (a user
/// who flew somewhere while the app was backgrounded).
Future<void> initTimeZones({
  Future<String> Function()? readDeviceZone,
}) async {
  tzdata.initializeTimeZones();
  // initializeTimeZones sets the local location to UTC, so `tz.local` is safe to
  // read from here on even if the resolution below fails.
  _ready = true;
  final read = readDeviceZone ?? deviceZoneIdentifier;
  try {
    tz.setLocalLocation(tz.getLocation(await read()));
  } catch (error, stack) {
    tz.setLocalLocation(tz.UTC);
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stack,
        library: 'vitomy',
        context: ErrorDescription('resolving the device time zone'),
      ),
    );
  }
}

/// The device's own IANA zone identifier — the one platform-channel call in
/// this file.
///
/// Public because it is read TWICE in the app's life: once at bootstrap, and
/// again on every resume, which is the only moment a zone change made while the
/// app was backgrounded can be noticed. It is installed into
/// `deviceZoneReaderProvider` by `main()` for the same reason the zone LOADER
/// is injected — an un-injected default would make every widget test reach a
/// plugin.
Future<String> deviceZoneIdentifier() async =>
    (await FlutterTimezone.getLocalTimezone()).identifier;

/// The identifier of the zone instants are currently being built in.
String get localZoneIdentifier => tz.local.name;

/// Points this boundary at [identifier], when it is not already pointed there.
///
/// Returns whether anything changed. Kept here rather than at the call site so
/// `package:timezone` still stops in this file: nothing above it names a
/// location, a zone database or a `TZDateTime`.
///
/// Throws for an identifier the database does not carry. That is deliberate and
/// the caller absorbs it — degrading silently to UTC here would move every
/// remaining reminder by the device offset with nothing to say so, where the
/// caller can keep the zone it already had.
bool setLocalZoneIfChanged(String identifier) {
  assert(_ready, 'initTimeZones() must complete before a zone is changed');
  if (identifier == tz.local.name) return false;
  tz.setLocalLocation(tz.getLocation(identifier));
  return true;
}

/// The instant at which [minutesFromMidnight] falls on calendar day [day].
///
/// **The exact inverse of `dateOnly()`** (`cycle_math.dart:16`), and the one line
/// the whole phase's correctness turns on. `dateOnly` reads a value's y/m/d
/// fields to make a UTC calendar day; this reads that calendar day's y/m/d
/// fields back out and pairs them with a wall clock in the device's zone.
///
/// **The wrong shape is a local-time CONVERSION of [day].** A date-only value is
/// a UTC-normalized calendar day by the project's own rule, so converting it as
/// an instant (`.toLocal()`, or `TZDateTime.from`) lands on the PREVIOUS calendar
/// day for every zone west of the meridian: a Ukrainian user would never see it
/// and an American user would get every single reminder on the wrong date. The
/// field-wise construction below cannot express that mistake.
///
/// DST is `TZDateTime`'s own normalization and is pinned by test: a wall clock
/// inside a spring gap moves forward past it, and one inside an autumn overlap
/// resolves to the later occurrence.
tz.TZDateTime instantFor({
  required DateTime day,
  required int minutesFromMidnight,
}) {
  assert(_ready, 'initTimeZones() must complete before an instant is built: '
      'before setLocalLocation runs, a zoned value silently comes out as UTC '
      'and every reminder is off by the device offset');
  assert(
    day == DateTime.utc(day.year, day.month, day.day),
    'day must already be a date-only DateTime.utc(y, m, d) value (D-15); a '
    'non-normalized day would build a phantom day here instead of failing '
    'where the invariant was actually lost',
  );
  assert(
    minutesFromMidnight >= 0 && minutesFromMidnight <= 1439,
    'minutesFromMidnight must be in 0..1439',
  );
  return tz.TZDateTime(
    tz.local,
    day.year,
    day.month,
    day.day,
    minutesFromMidnight ~/ 60,
    minutesFromMidnight % 60,
  );
}

/// The next instant at which [minutesFromMidnight] occurs, at or after [now].
///
/// Today's occurrence when it is still strictly ahead of [now], tomorrow's
/// otherwise — a repeating request whose first fire is not in the future makes
/// the plugin throw rather than degrade (Pitfall 4).
///
/// Nothing calls this until the tier-A repeating optimization lands in plan
/// 07-02. It is written here anyway because it is the other half of THIS
/// boundary, and splitting one boundary across two waves is how the two halves
/// drift apart.
tz.TZDateTime nextDailyOccurrence({
  required int minutesFromMidnight,
  required tz.TZDateTime now,
}) {
  assert(_ready, 'initTimeZones() must complete before an instant is built');
  final todayAt = instantFor(
    day: DateTime.utc(now.year, now.month, now.day),
    minutesFromMidnight: minutesFromMidnight,
  );
  if (todayAt.isAfter(now)) return todayAt;
  final tomorrow = DateTime.utc(now.year, now.month, now.day)
      .add(const Duration(days: 1));
  return instantFor(day: tomorrow, minutesFromMidnight: minutesFromMidnight);
}
