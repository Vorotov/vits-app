/// The notification seam, its providers, and the FLAG-3 ordering of the app's
/// bootstrap.
///
/// Two things that belong together: the bootstrap notifier's own behaviour, and
/// a source gate over the window in `lib/main.dart` between binding
/// initialization and `runApp`.
///
/// **The window gate here is NEEDLE-based and counts nothing, and that is
/// load-bearing.** Plan 07-03 legitimately adds exactly one `await` to that same
/// window — the notification launch-details read, whose answer has to seed frame
/// 1 — so a gate that counted awaits here would go red one wave later and would
/// have to be deleted or weakened by a plan that does not own it. A needle gate
/// states the property FLAG-3 actually protects (no zone-database load, no
/// plugin initialization, no channel creation before the first frame), keeps
/// holding after 07-03's addition, and is never edited.
///
/// The COUNTED gate belongs to plan 07-03 alone and lives in its own routing
/// test beside the frame-1 guarantee it protects. This file must not grow a
/// second opinion about the same window.
library;

import 'dart:io';

import 'package:boostque/core/l10n/gen/app_localizations.dart';
import 'package:boostque/core/notifications/notification_providers.dart';
import 'package:boostque/core/notifications/notification_scheduler.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// A scheduler that records what it was asked to do and touches no plugin.
class RecordingScheduler extends NotificationScheduler {
  final List<String> calls = <String>[];
  String? channelName;
  String? channelDescription;

  @override
  Future<void> initialize({
    required void Function(String? payload) onTap,
  }) async {
    calls.add('initialize');
  }

  @override
  Future<void> ensureChannel({
    required String name,
    required String description,
  }) async {
    calls.add('ensureChannel');
    channelName = name;
    channelDescription = description;
  }

  @override
  Future<List<PendingNotification>> pending() async => const [];

  @override
  Future<void> scheduleOnce({
    required int id,
    required DateTime day,
    required int minutesFromMidnight,
    required String title,
    required String body,
  }) async {
    calls.add('scheduleOnce');
  }

  @override
  Future<void> scheduleDaily({
    required int id,
    required int minutesFromMidnight,
    required String title,
    required String body,
  }) async {
    calls.add('scheduleDaily');
  }

  @override
  Future<void> cancel({required int id}) async => calls.add('cancel');

  @override
  Future<bool?> requestPermission() async => null;

  @override
  Future<bool?> isEnabled() async => null;

  @override
  Future<void> openSystemSettings() async => calls.add('openSystemSettings');

  @override
  Future<String?> launchPayload() async => null;
}

/// Mimics `main.dart`'s wiring: watch the flag, and drive the bootstrap from a
/// post-FIRST-frame callback with the locale the tree is actually rendering.
class BootstrapHarness extends ConsumerStatefulWidget {
  const BootstrapHarness({required this.locale, super.key});

  final Locale locale;

  @override
  ConsumerState<BootstrapHarness> createState() => _BootstrapHarnessState();
}

class _BootstrapHarnessState extends ConsumerState<BootstrapHarness> {
  @override
  Widget build(BuildContext context) {
    final ready = ref.watch(notificationBootstrapProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref
          .read(notificationBootstrapProvider.notifier)
          .bootstrap(locale: widget.locale);
    });
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Text(ready ? 'ready' : 'waiting'),
    );
  }
}

void main() {
  group('FLAG-3 — the pre-runApp window in lib/main.dart', () {
    /// The source between `ensureInitialized()` and the `runApp(` call, with
    /// line comments stripped so commentary naming a needle cannot trip its own
    /// gate (the convention every source gate in this suite follows).
    String preRunAppWindow() {
      final source = File('lib/main.dart').readAsStringSync();
      final stripped = source
          .split('\n')
          .where((line) => !line.trimLeft().startsWith('//'))
          .join('\n');
      final start = stripped.indexOf('ensureInitialized()');
      final end = stripped.indexOf('runApp(');
      expect(start, greaterThanOrEqualTo(0),
          reason: 'lib/main.dart no longer calls ensureInitialized(); this gate '
              'cannot locate the window it protects.');
      expect(end, greaterThan(start),
          reason: 'lib/main.dart no longer calls runApp() after '
              'ensureInitialized(); this gate cannot locate the window.');
      return stripped.substring(start, end);
    }

    test('the window is actually resolved — a gate over an empty window is worse '
        'than no gate', () {
      final window = preRunAppWindow();
      expect(
        window,
        contains('SharedPreferences'),
        reason: 'the one thing that legitimately lives in this window today is '
            'the preferences read (P-4 Option A). If it is not in the extracted '
            'window, the extraction is wrong and every assertion below passes '
            'vacuously.',
      );
    });

    test('no zone load, no plugin initialization and no channel creation appears '
        'before the first frame', () {
      final window = preRunAppWindow();
      const needles = <String, String>{
        'initTimeZones': 'the zone database is roughly a megabyte of data to '
            'parse',
        'initializeTimeZones': 'same — the package call underneath it',
        'setLocalLocation': 'the device-zone platform round trip',
        'ensureChannel': 'a platform-channel round trip',
        'createNotificationChannel': 'same, one layer down',
        'PluginNotificationScheduler(': 'constructing the plugin-backed '
            'scheduler here would make its initialize() the next thing anyone '
            'adds; it belongs in a lazy provider override',
      };
      needles.forEach((needle, cost) {
        expect(
          window.contains(needle),
          isFalse,
          reason: 'lib/main.dart runs "$needle" BEFORE runApp — $cost. FLAG-3 '
              'permits only the notification launch-details read in this '
              'window, because only that has a frame-1 dependency. The existing '
              'cold-start guarantee asserts the shell paints on frame ONE — a '
              'frame count, not a time budget — so work added here leaves every '
              'test green and every cold start slower.',
        );
      });
    });

    test('main() installs both notification overrides', () {
      // Whitespace-collapsed so a formatter wrapping the call cannot break the
      // gate — the property is "the override is installed", not "it fits on one
      // line".
      final source = File('lib/main.dart')
          .readAsStringSync()
          .replaceAll(RegExp(r'\s+'), '');
      expect(
        source.contains('notificationSchedulerProvider.overrideWith'),
        isTrue,
        reason: 'the scheduler provider defaults to the NO-OP implementation so '
            'no test can reach the plugin by accident. The cost of that choice '
            'is that a forgotten override means production silently schedules '
            'nothing — which is why the override is asserted here.',
      );
      expect(
        source.contains('timeZoneLoaderProvider.overrideWith'),
        isTrue,
        reason: 'the timezone loader defaults to null ("nothing to bootstrap"), '
            'for the same reason and with the same cost.',
      );
    });
  });

  group('the seam defaults — what makes every existing widget test safe', () {
    test('notificationSchedulerProvider resolves to the no-op in a bare container',
        () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(
        container.read(notificationSchedulerProvider),
        isA<NoopNotificationScheduler>(),
        reason: 'under flutter test the plugin\'s platform instance is a static '
            'late field with no default and the target platform is forced to '
            'android, so EVERY plugin call path throws a LateInitializationError '
            'rather than no-opping (07-RESEARCH §9.3, correction C-3). A no-op '
            'default is what makes it impossible for a widget test to reach the '
            'plugin at all.',
      );
    });

    test('timeZoneLoaderProvider resolves to null in a bare container', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(timeZoneLoaderProvider), isNull);
    });

    test('the no-op answers every method, without throwing and without a plugin',
        () async {
      const noop = NoopNotificationScheduler();
      await noop.initialize(onTap: (_) {});
      await noop.ensureChannel(name: 'n', description: 'd');
      await noop.scheduleOnce(
        id: 1,
        day: DateTime.utc(2030, 1, 1),
        minutesFromMidnight: 540,
        title: 't',
        body: 'b',
      );
      await noop.scheduleDaily(
        id: 2,
        minutesFromMidnight: 540,
        title: 't',
        body: 'b',
      );
      await noop.cancel(id: 1);
      await noop.openSystemSettings();
      expect(await noop.pending(), isEmpty);
      expect(await noop.launchPayload(), isNull);
      expect(
        await noop.requestPermission(),
        isNull,
        reason: 'null is the real third state: the platform answers null '
            'off-platform, and neither platform can distinguish "denied" from '
            '"never asked". A false here would make a later settings row claim, '
            'in every widget test, that reminders are blocked.',
      );
      expect(await noop.isEnabled(), isNull);
    });
  });

  group('the bootstrap notifier', () {
    testWidgets('reports not-ready on its first build', (tester) async {
      final scheduler = RecordingScheduler();
      final container = ProviderContainer(
        overrides: [
          notificationSchedulerProvider.overrideWithValue(scheduler),
          timeZoneLoaderProvider.overrideWithValue(() async {}),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(notificationBootstrapProvider), isFalse);
      expect(scheduler.calls, isEmpty);
    });

    testWidgets('reports ready only after the load, the init and the channel',
        (tester) async {
      final scheduler = RecordingScheduler();
      var loaded = 0;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            notificationSchedulerProvider.overrideWithValue(scheduler),
            timeZoneLoaderProvider.overrideWithValue(() async => loaded++),
          ],
          child: const BootstrapHarness(locale: Locale('uk')),
        ),
      );

      expect(
        find.text('waiting'),
        findsOneWidget,
        reason: 'FRAME ONE renders not-ready. The bootstrap cannot have '
            'contributed anything to the first frame, because it is not even '
            'started until that frame\'s post-frame callback runs.',
      );

      await tester.pumpAndSettle();

      expect(find.text('ready'), findsOneWidget);
      expect(loaded, 1);
      expect(scheduler.calls, <String>['initialize', 'ensureChannel']);
      expect(
        scheduler.channelName,
        lookupAppLocalizations(const Locale('uk')).doseChannelName,
      );
      expect(
        scheduler.channelDescription,
        lookupAppLocalizations(const Locale('uk')).doseChannelDescription,
      );
    });

    testWidgets('the channel copy follows the locale the tree renders in',
        (tester) async {
      final scheduler = RecordingScheduler();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            notificationSchedulerProvider.overrideWithValue(scheduler),
            timeZoneLoaderProvider.overrideWithValue(() async {}),
          ],
          child: const BootstrapHarness(locale: Locale('en')),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        scheduler.channelName,
        lookupAppLocalizations(const Locale('en')).doseChannelName,
      );
    });

    testWidgets('nothing at all happens when no loader is installed',
        (tester) async {
      final scheduler = RecordingScheduler();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            notificationSchedulerProvider.overrideWithValue(scheduler),
          ],
          child: const BootstrapHarness(locale: Locale('uk')),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        scheduler.calls,
        isEmpty,
        reason: 'a bare container is every existing widget test in this repo. '
            'Not-ready is the honest answer there: nothing was bootstrapped.',
      );
      expect(find.text('waiting'), findsOneWidget);
    });

    testWidgets('the work runs once, not once per frame', (tester) async {
      final scheduler = RecordingScheduler();
      var loaded = 0;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            notificationSchedulerProvider.overrideWithValue(scheduler),
            timeZoneLoaderProvider.overrideWithValue(() async => loaded++),
          ],
          child: const BootstrapHarness(locale: Locale('uk')),
        ),
      );
      await tester.pumpAndSettle();
      await tester.pump();
      await tester.pumpAndSettle();

      expect(loaded, 1);
      expect(scheduler.calls, <String>['initialize', 'ensureChannel']);
    });
  });
}
