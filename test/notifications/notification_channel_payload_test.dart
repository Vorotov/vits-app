/// What actually crosses the platform channel — the only place the platform-side
/// facts of this phase are assertable at all.
///
/// This test drives the REAL `PluginNotificationScheduler`, not a mock of the
/// app's own seam: it registers the Android platform implementation (which sets
/// the plugin's `static late` instance and is the only reason a plugin call does
/// not throw here) and installs a mock handler on the plugin's method channel,
/// capturing every call. Under `flutter test` `defaultTargetPlatform` is forced
/// to android, so the Android branch is the one taken.
///
/// **The accepted one-hour divergence at the autumn transition, and why it is not
/// a bug to fix.** Only the wall clock (`scheduledDateTime`, offset stripped) and
/// the zone name reach Android; `scheduledDateTimeISO8601` is sent and never
/// read, so the offset the Dart side computed is DISCARDED. Android rebuilds the
/// instant as `ZonedDateTime.of(LocalDateTime.parse(...), ZoneId.of(...))`, and
/// `java.time`'s documented overlap rule picks the EARLIER of two identical wall
/// clocks where Dart's normalization picked the later. So on the last Sunday of
/// October a 03:00 reminder fires an hour before what the pure `TZDateTime` test
/// asserts. That is why the overlap cannot be pinned by a unit test on the zoned
/// value alone, and why the assertion that matters lives here: the platform's
/// rule is the platform's, and it is documented rather than fought
/// (07-RESEARCH correction C-2, Pitfall 3, risk R-6).
library;

import 'dart:io';
import 'dart:ui';

import 'package:boostque/core/l10n/gen/app_localizations.dart';
import 'package:boostque/core/notifications/notification_constants.dart';
import 'package:boostque/core/notifications/notification_service.dart';
import 'package:boostque/core/notifications/tz_conversion.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';

/// The plugin's own method channel.
const _pluginChannel = MethodChannel('dexterous.com/flutter/local_notifications');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<MethodCall> calls;
  late PluginNotificationScheduler scheduler;

  /// The single captured call to [method].
  Map<String, Object?> argsOf(String method) {
    final matching = calls.where((call) => call.method == method).toList();
    expect(matching, hasLength(1), reason: 'expected exactly one $method call');
    return (matching.single.arguments as Map).cast<String, Object?>();
  }

  Map<String, Object?> platformSpecificsOf(String method) =>
      (argsOf(method)['platformSpecifics'] as Map).cast<String, Object?>();

  setUp(() async {
    // Sets the plugin's `static late` platform instance. Without this every call
    // below throws a LateInitializationError naming an obfuscated field
    // (07-RESEARCH §9.3) — which is exactly why the app's own seam exists.
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_pluginChannel, (call) async {
      calls.add(call);
      if (call.method == 'pendingNotificationRequests') return <dynamic>[];
      if (call.method == 'initialize') return true;
      return null;
    });
    await initTimeZones(readDeviceZone: () async => 'Europe/Kyiv');
    scheduler = PluginNotificationScheduler();
    await scheduler.initialize(onTap: (_) {});
    final uk = lookupAppLocalizations(const Locale('uk'));
    await scheduler.ensureChannel(
      name: uk.doseChannelName,
      description: uk.doseChannelDescription,
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_pluginChannel, null);
  });

  group('initialization', () {
    test('the Android small icon is the launcher resource the project ships', () {
      expect(argsOf('initialize')['defaultIcon'], '@mipmap/ic_launcher');
    });

    test('only the Android settings cross this channel, which is why the Darwin '
        'flags need a SOURCE gate', () {
      // Under flutter test defaultTargetPlatform is forced to android, so the
      // Android branch of initialize() is the one taken and only
      // AndroidInitializationSettings is serialized. The iOS request flags —
      // the single highest-consequence defaults in this whole API — therefore
      // cannot be observed on any wire from a host test at all. That is not a
      // gap to shrug at: it is why the source gate below exists.
      final settings = argsOf('initialize');
      expect(settings.containsKey('requestAlertPermission'), isFalse);
    });
  });

  group('source gates — the facts no wire in a host test can carry', () {
    late String service;

    setUpAll(() {
      service = File('lib/core/notifications/notification_service.dart')
          .readAsStringSync()
          .split('\n')
          .where((line) => !line.trimLeft().startsWith('//'))
          .join('\n');
    });

    test('all three Darwin permission-request flags are literal false', () {
      for (final flag in const [
        'requestAlertPermission',
        'requestSoundPermission',
        'requestBadgePermission',
      ]) {
        expect(
          service.contains('$flag: false'),
          isTrue,
          reason: '$flag is not literal false in notification_service.dart. Each '
              'of the three DEFAULTS TO TRUE, and any one left alone fires the '
              'one-and-only iOS system prompt at initialize() — that is, at '
              'launch — which breaks "asked at first regimen save, never at '
              'launch" silently and with no second chance on that device, ever '
              '(Pitfall 1). They sit in the same constructor as the five '
              'defaultPresent* flags, which keep their true defaults '
              'deliberately and mean the opposite thing; that adjacency is why '
              'this gate exists.',
        );
      }
    });

    test('no privileged permission request and no exact schedule mode appears',
        () {
      for (final forbidden in const [
        'requestExactAlarmsPermission',
        'requestFullScreenIntentPermission',
        'AndroidScheduleMode.exact',
        'cancelAll',
      ]) {
        expect(
          service.contains(forbidden),
          isFalse,
          reason: 'notification_service.dart references $forbidden. The first '
              'two sit right beside the permission methods the app does call and '
              'are both Play-policy landmines for this app; an exact schedule '
              'mode would need a permission this milestone refuses; and '
              'cancelAll dismisses delivered-but-unacted reminders and leaves a '
              'window with nothing scheduled.',
        );
      }
    });

    test('no chrome the UI contract forbids is set', () {
      for (final forbidden in const [
        'color:',
        'badgeNumber',
        'groupKey',
        'threadIdentifier',
        'interruptionLevel',
      ]) {
        expect(
          service.contains(forbidden),
          isFalse,
          reason: 'notification_service.dart sets $forbidden. Every one of these '
              'is a DECIDED absence with a stated reason (DECIDED-18), and the '
              'point of writing them down was to stop one being added '
              'defensively.',
        );
      }
    });

    test('private visibility is set on every Android detail object built', () {
      final details =
          RegExp('AndroidNotificationDetails' r'\(').allMatches(service).length;
      final private =
          'NotificationVisibility.private'.allMatches(service).length;
      expect(details, greaterThanOrEqualTo(1));
      expect(
        private,
        details,
        reason: 'AndroidNotificationChannel has no visibility parameter at all, '
            'so a "set it once on the channel" shortcut produces PUBLIC '
            'lock-screen content (correction C-1). Every detail object built '
            'must carry it.',
      );
    });

    test('neither the plan nor the service can learn a supplement name', () {
      for (final path in const [
        'lib/core/notifications/notification_plan.dart',
        'lib/core/notifications/notification_service.dart',
      ]) {
        final source = File(path).readAsStringSync();
        for (final capability in const [
          'SupplementRepository',
          'stackEntriesProvider',
          'supplementsStreamProvider',
        ]) {
          expect(
            source.contains(capability),
            isFalse,
            reason: '$path can reach $capability. A capability that does not '
                'exist cannot leak a health-adjacent name onto a lock screen; '
                'the count-only body is a security control, not a copy choice.',
          );
        }
      }
    });
  });

  group('the channel', () {
    test('carries the id doses_v1 and ARB-sourced name and description', () {
      final channel = argsOf('createNotificationChannel');
      final uk = lookupAppLocalizations(const Locale('uk'));
      expect(channel['id'], 'doses_v1');
      expect(channel['id'], doseChannelId);
      expect(channel['name'], uk.doseChannelName);
      expect(channel['name'], 'Нагадування про прийом');
      expect(channel['description'], uk.doseChannelDescription);
      // Importance.high — heads-up delivery is the point of a dose reminder.
      // Safe to re-apply: Android ignores an attempt to RAISE importance on an
      // existing channel, so a user who turned it down keeps their choice.
      expect(channel['importance'], 4);
    });

    test('the channel is created in whatever locale it was asked for', () async {
      final en = lookupAppLocalizations(const Locale('en'));
      await scheduler.ensureChannel(
        name: en.doseChannelName,
        description: en.doseChannelDescription,
      );
      final created = calls
          .where((call) => call.method == 'createNotificationChannel')
          .map((call) => (call.arguments as Map)['name'])
          .toList();
      expect(created, <String>['Нагадування про прийом', 'Dose reminders']);
      final ids = calls
          .where((call) => call.method == 'createNotificationChannel')
          .map((call) => (call.arguments as Map)['id'])
          .toSet();
      expect(
        ids,
        <String>{'doses_v1'},
        reason: 'the id is never re-versioned to change the language: Android '
            'UPDATES an existing channel\'s name and description, and a new id '
            'would create a second channel and orphan the customizations the '
            'user made on the first (DECIDED-14).',
      );
    });
  });

  group('a tier-B one-shot on the wire', () {
    setUp(() async {
      // Far future: the plugin throws ArgumentError for a past instant on
      // exactly this path, and it reads the real clock.
      await scheduler.scheduleOnce(
        id: 42,
        day: DateTime.utc(2030, 6, 15),
        minutesFromMidnight: 480,
        title: 'Час прийому',
        body: '08:00 · 3 прийоми',
      );
    });

    test('carries the exact wall clock and the device zone name', () {
      final args = argsOf('zonedSchedule');
      expect(args['id'], 42);
      expect(args['title'], 'Час прийому');
      expect(args['body'], '08:00 · 3 прийоми');
      expect(args['payload'], doseTapPayload);
      expect(args['timeZoneName'], 'Europe/Kyiv');
      expect(
        args['scheduledDateTime'],
        '2030-06-15T08:00:00',
        reason: 'the wall clock with its offset STRIPPED is what Android '
            'rebuilds the instant from; the offset the Dart side computed never '
            'arrives.',
      );
    });

    test('carries NO date-time-components field — a course must never repeat', () {
      final args = argsOf('zonedSchedule');
      expect(
        args.containsKey('matchDateTimeComponents'),
        isFalse,
        reason: 'the plugin only writes this key when the argument is non-null, '
            'so its absence is the structural difference between a one-shot and '
            'a repeat. One-shot and repeat are separate methods on the seam for '
            'the same reason: "a course must never repeat" is true by shape, not '
            'by a conditional argument nobody can see at the call site.',
      );
    });

    test('carries the unprivileged schedule mode, private visibility and the '
        'channel', () {
      final specifics = platformSpecificsOf('zonedSchedule');
      expect(
        specifics['scheduleMode'],
        'inexactAllowWhileIdle',
        reason: 'this mode needs no permission at all and cannot reach the '
            'plugin\'s exact-alarm throw path. Accepted cost: 10-15 minutes of '
            'jitter while the device is dozing (NOTIF-02).',
      );
      expect(
        specifics['visibility'],
        0,
        reason: 'NotificationVisibility.private, set per-notification because '
            'AndroidNotificationChannel has no visibility parameter at all '
            '(correction C-1). It ASKS Android to conceal content on a secure '
            'lock screen; whether it does depends on a user setting whose '
            'default is to show everything, which is why the count-only body is '
            'the actual privacy control.',
      );
      expect(specifics['channelId'], doseChannelId);
      expect(
        specifics['channelName'],
        lookupAppLocalizations(const Locale('uk')).doseChannelName,
        reason: 'the details are built PER CALL from the same copy the channel '
            'was created with, so the name inside a notification can never '
            'disagree with the channel the app actually created (U-2).',
      );
      expect(specifics['category'], 'reminder');
      expect(specifics['importance'], 4);
    });

    test('sets none of the chrome the UI contract forbids', () {
      final specifics = platformSpecificsOf('zonedSchedule');
      // Each of these is a DECIDED absence with a stated reason; the point of
      // writing them down was to stop an executor adding one defensively.
      expect(specifics['color'], isNull);
      expect(specifics['groupKey'], isNull);
      expect(specifics['fullScreenIntent'], isFalse);
      expect(specifics['ongoing'], isFalse);
    });

    test('no supplement name can reach the title, body or payload', () {
      final args = argsOf('zonedSchedule');
      // Structural, not incidental: neither notification_plan.dart nor
      // notification_service.dart imports the supplement repository or the
      // paired-stack provider, so the capability to learn a name does not exist.
      for (final field in <Object?>[
        args['title'],
        args['body'],
        args['payload'],
      ]) {
        expect(field.toString().contains('Creatine'), isFalse);
      }
      expect(args['payload'], 'today');
    });

    test('an instant already in the past is skipped, never sent', () async {
      calls.clear();
      await scheduler.scheduleOnce(
        id: 7,
        day: DateTime.utc(2020, 1, 1),
        minutesFromMidnight: 480,
        title: 'Час прийому',
        body: '08:00 · 1 прийом',
      );
      expect(
        calls.where((call) => call.method == 'zonedSchedule'),
        isEmpty,
        reason: 'the plugin throws an ArgumentError for a past instant on the '
            'one-shot path, and there is a real race: today\'s 09:00 slot is in '
            'the past by the time a 09:05 resume syncs (Pitfall 4).',
      );
    });
  });

  group('a tier-A repeat on the wire', () {
    test('carries the date-time-components field at the time-only value', () async {
      await scheduler.scheduleDaily(
        id: 99,
        minutesFromMidnight: 480,
        title: 'Час прийому',
        body: '08:00 · 2 прийоми',
      );
      final args = argsOf('zonedSchedule');
      expect(
        args['matchDateTimeComponents'],
        0,
        reason: 'DateTimeComponents.time — index 0 — is what makes the request '
            'a daily repeat costing one slot against the iOS cap forever.',
      );
      expect(args['timeZoneName'], 'Europe/Kyiv');
      expect(platformSpecificsOf('zonedSchedule')['scheduleMode'],
          'inexactAllowWhileIdle');
      expect(platformSpecificsOf('zonedSchedule')['visibility'], 0);
    });
  });

  group('cancel and pending speak the seam\'s own types', () {
    test('cancel reaches the platform with the id', () async {
      calls.clear();
      await scheduler.cancel(id: 42);
      expect(argsOf('cancel')['id'], 42);
    });

    test('cancelAll is never called — it would dismiss delivered reminders', () {
      expect(calls.where((call) => call.method == 'cancelAll'), isEmpty);
    });

    test('pending returns the seam\'s own value type, not the plugin\'s', () async {
      expect(await scheduler.pending(), isEmpty);
    });
  });

  group('the rendered copy, exactly as the OS will read it aloud', () {
    test('uk at a count of 3', () {
      final uk = lookupAppLocalizations(const Locale('uk'));
      expect(uk.doseReminderTitle, 'Час прийому');
      expect(uk.doseReminderBody(3, '08:00'), '08:00 · 3 прийоми');
    });

    test('en at a count of 1', () {
      final en = lookupAppLocalizations(const Locale('en'));
      expect(en.doseReminderTitle, 'Time for your doses');
      expect(en.doseReminderBody(1, '08:00'), '08:00 · 1 dose');
    });

    test('every Ukrainian plural form, including the 11-14 exception', () {
      final uk = lookupAppLocalizations(const Locale('uk'));
      expect(uk.doseReminderBody(1, '08:00'), '08:00 · 1 прийом');
      expect(uk.doseReminderBody(2, '08:00'), '08:00 · 2 прийоми');
      expect(uk.doseReminderBody(5, '08:00'), '08:00 · 5 прийомів');
      expect(uk.doseReminderBody(11, '08:00'), '08:00 · 11 прийомів');
      expect(uk.doseReminderBody(21, '08:00'), '08:00 · 21 прийом');
      expect(uk.doseReminderBody(22, '08:00'), '08:00 · 22 прийоми');
      expect(uk.doseReminderBody(25, '08:00'), '08:00 · 25 прийомів');
    });
  });
}
