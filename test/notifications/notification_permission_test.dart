/// The permission controller: one ask per install, one fresh read per resume
/// (NOTIF-03, and the state NOTIF-05's Settings row reports).
///
/// Everything here runs against the mocked seam and a mocked key-value store.
/// What is under test is the once-per-install gate, the three-state answer and
/// the failure stance — never the plugin, which no test in this repository may
/// reach.
library;

import 'dart:io';

import 'package:vitomy/core/notifications/notification_permission.dart';
import 'package:vitomy/core/notifications/notification_providers.dart';
import 'package:vitomy/core/providers.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'recording_scheduler.dart';

/// Delivers a real platform lifecycle message, the way the engine does.
///
/// Taken verbatim from `notification_sync_test.dart`, which drives the other
/// lifecycle listener in this layer the same way:
/// `WidgetsBinding.handleAppLifecycleStateChanged` is `@protected` and the
/// channel is the supported test seam.
Future<void> sendLifecycle(WidgetTester tester, AppLifecycleState state) async {
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    'flutter/lifecycle',
    const StringCodec().encodeMessage(state.toString()),
    (_) {},
  );
}

void main() {
  late RecordingScheduler scheduler;
  late ProviderContainer container;

  setUp(() {
    scheduler = RecordingScheduler();
  });

  tearDown(() => container.dispose());

  /// Mounts the container and keeps the notifier alive — an unlistened
  /// provider is PAUSED in this version of Riverpod, so a test that merely
  /// built one would observe nothing at all.
  ///
  /// [noStore] drives the CR-02 case: the key-value store could not be opened
  /// on this launch, which is a state the app must survive rather than a state
  /// it may crash on.
  Future<NotificationPermission> start(
    WidgetTester tester, {
    Map<String, Object> stored = const <String, Object>{},
    bool noStore = false,
  }) async {
    SharedPreferences.setMockInitialValues(stored);
    final prefs = noStore ? null : await SharedPreferences.getInstance();
    container = ProviderContainer(
      overrides: [
        notificationSchedulerProvider.overrideWithValue(scheduler),
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const SizedBox.shrink(),
      ),
    );
    container.listen(notificationPermissionProvider, (_, _) {});
    return container.read(notificationPermissionProvider.notifier);
  }

  bool? currentState() => container.read(notificationPermissionProvider);

  List<String> methods() => scheduler.calls.map((c) => c.method).toList();

  group('the three-state answer', () {
    testWidgets('the state starts UNKNOWN and nothing is asked of the platform '
        'until someone wants the answer', (tester) async {
      await start(tester);

      expect(currentState(), isNull,
          reason: 'a screen that must not lie needs a way to say "not yet '
              'known"; two states would force it to claim one of them.');
      expect(scheduler.calls, isEmpty,
          reason: 'the sync watches this notifier as a TRIGGER, so building it '
              'may not cost a platform round trip nobody asked for.');
    });

    for (final answer in const <bool?>[true, false, null]) {
      testWidgets('a refresh maps the seam answer $answer straight onto the '
          'state', (tester) async {
        scheduler.enabled = answer;
        final permission = await start(tester);

        await permission.refresh();

        expect(currentState(), answer,
            reason: 'including the unknown answer: off-platform the seam '
                'cannot say, and inventing a false there would make the row '
                'claim reminders are blocked in every widget test.');
        expect(methods(), <String>[isEnabledCall]);
      });
    }
  });

  group('the ask — at most once per install', () {
    testWidgets('the first ask issues one request, records that it asked, and '
        'refreshes the state', (tester) async {
      scheduler.enabled = true;
      final permission = await start(tester);

      await permission.askOnce();

      expect(methods(), <String>[requestPermissionCall, isEnabledCall]);
      expect(currentState(), isTrue);
      final store = await SharedPreferences.getInstance();
      expect(store.getBool(notificationAskedKey), isTrue,
          reason: 'neither platform can answer "have we ever asked?", so the '
              'app has to remember it itself.');
    });

    testWidgets('a second ask in the same install issues no request at all',
        (tester) async {
      final permission = await start(tester);

      await permission.askOnce();
      scheduler.calls.clear();
      await permission.askOnce();

      expect(scheduler.calls, isEmpty,
          reason: 'without the gate Android re-shows its rationale dialog on '
              'EVERY regimen save until the user has denied twice, which is '
              'exactly the nagging the approved spec forbids.');
    });

    testWidgets('an ask with the flag already stored — a user upgrading from a '
        'build that asked — issues no request', (tester) async {
      final permission = await start(
        tester,
        stored: <String, Object>{notificationAskedKey: true},
      );

      await permission.askOnce();

      expect(scheduler.calls, isEmpty);
    });

    testWidgets('a stored value of the WRONG TYPE is treated as absent, not as '
        'a crash', (tester) async {
      final permission = await start(
        tester,
        stored: <String, Object>{notificationAskedKey: 'yes'},
      );

      await permission.askOnce();

      expect(methods(), contains(requestPermissionCall),
          reason: 'the type of untrusted storage is as untrusted as its '
              'content — a wrong type means "not yet asked", never a throw '
              'inside a build (CR-01).');
      expect(tester.takeException(), isNull);
    });

    testWidgets('with no key-value store at all the ask still happens; only '
        'the memory of it is lost', (tester) async {
      final permission = await start(tester, noStore: true);

      await permission.askOnce();

      expect(methods(), contains(requestPermissionCall));
      expect(tester.takeException(), isNull,
          reason: 'a store that could not be opened is the same state an empty '
              'store leaves, and it may not cost the user the one prompt iOS '
              'will ever show.');
    });

    testWidgets('a request that THROWS is reported to the crash logger, leaves '
        'the state as it was, and surfaces nothing', (tester) async {
      scheduler.requestFailure = Exception('no notification plugin here');
      final permission = await start(tester);

      await permission.askOnce();

      expect(currentState(), isNull,
          reason: 'the state is left exactly as it was — a failed ask is not '
              'evidence about the answer.');
      expect(tester.takeException(), isNotNull,
          reason: 'absorbed means REPORTED to the crash logger, never shown: '
              'FlutterError.reportError is what the test binding records.');
    });

    testWidgets('an ask whose request threw is still not repeated', (tester) async {
      scheduler.requestFailure = Exception('no notification plugin here');
      final permission = await start(tester);

      await permission.askOnce();
      expect(tester.takeException(), isNotNull);
      scheduler.calls.clear();
      await permission.askOnce();

      expect(scheduler.calls, isEmpty,
          reason: 'the operating system may well have shown its dialog before '
              'the failure, and on iOS there is no second prompt to spend — so '
              'a throw may not become a licence to nag.');
    });
  });

  group('the route back, and the state that follows it', () {
    testWidgets('opening the system settings calls the seam once and changes '
        'nothing by itself', (tester) async {
      final permission = await start(tester);

      await permission.openSystemSettings();

      expect(methods(), <String>[openSystemSettingsCall]);
      expect(currentState(), isNull,
          reason: 'leaving for the operating system is not an answer; the '
              'answer arrives on the way back, as a resume.');
    });

    testWidgets('a RESUME re-reads the state, so a permission granted or '
        'revoked outside the app is picked up', (tester) async {
      scheduler.enabled = false;
      final permission = await start(tester);
      await permission.refresh();
      expect(currentState(), isFalse);

      // The user leaves for the operating system's own settings, switches
      // reminders on, and comes back. Returning IS a resume.
      scheduler.enabled = true;
      await sendLifecycle(tester, AppLifecycleState.inactive);
      await sendLifecycle(tester, AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump();

      expect(currentState(), isTrue,
          reason: 'this is what makes the Settings row self-correcting without '
              'a retry control — which that screen\'s own gates forbid anyway.');
    });

    testWidgets('a resume arriving after the container is gone is inert and '
        'throws nothing', (tester) async {
      await start(tester);
      container.dispose();

      await sendLifecycle(tester, AppLifecycleState.inactive);
      await sendLifecycle(tester, AppLifecycleState.resumed);
      await tester.pump();

      expect(tester.takeException(), isNull,
          reason: 'a resume reaching a disposed ref would throw; the guard and '
              'the disposal both have to hold. This test cannot tell WHICH of '
              'the two saved it — the source gate below carries the disposal.');
    });
  });

  group('source gates — the facts no run of this suite can carry', () {
    const path = 'lib/core/notifications/notification_permission.dart';
    String source() => File(path).readAsStringSync();

    test('nothing on this path can produce a user-visible surface', () {
      for (final token in const [
        'showDialog',
        'showModalBottomSheet',
        'SnackBar',
        'MaterialBanner',
        'BuildContext',
      ]) {
        expect(source().contains(token), isFalse,
            reason: '$path can reach $token. DECIDED-7 is provable by ABSENCE: '
                'nothing of the app\'s own precedes the operating system\'s '
                'dialog, and nothing of the app\'s own follows a failure on '
                'this path either.');
      }
    });

    test('this state is one key in the small store, not a domain row', () {
      for (final token in const ['drift', 'Repository', 'database']) {
        expect(source().contains(token), isFalse,
            reason: '$path reaches persistence it has no business in: the '
                'asked-once flag lives beside the language override, in the '
                'same key-value store, for the same reason.');
      }
    });

    test('no public member names a plugin permission primitive', () {
      // Plan 07-06 turns this into a standing gate over lib/features/. It is
      // asserted HERE, on the controller's own API, because the Settings row is
      // allowed to exist only by calling these methods instead of those
      // primitives — so a member named after one would break an invariant two
      // waves later, in a plan that could not fix it without renaming this API.
      for (final primitive in const [
        'areNotificationsEnabled',
        'checkPermissions',
        'requestPermissions',
        'requestNotificationsPermission',
        'openAppNotificationSettings',
      ]) {
        expect(source().contains(primitive), isFalse,
            reason: '$path spells $primitive. The row reaches named controller '
                'methods precisely so that the primitive names still resolve '
                'nowhere under lib/features/.');
      }
    });

    test('there is ONE lifecycle listener, and the disposal callback disposes '
        'it', () {
      final code = source();
      expect(
        RegExp(r'AppLifecycleListener\(').allMatches(code).length,
        1,
        reason: 'a second listener would be a second opinion about what a '
            'resume means. CONSTRUCTIONS, not occurrences: a listener held in '
            'order to be disposed names its type twice.',
      );
      final onDispose = code.substring(
        code.indexOf('ref.onDispose('),
        code.indexOf('});', code.indexOf('ref.onDispose(')),
      );
      expect(
        onDispose.contains('_lifecycle?.dispose()'),
        isTrue,
        reason: 'a SOURCE gate on purpose: the resume path returns immediately '
            'on an unmounted ref, so from the outside a leaked listener is '
            'indistinguishable from a disposed one — the same limit '
            'notification_sync_test.dart records for its own listener.',
      );
    });
  });
}
