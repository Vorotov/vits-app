/// Cold-start degradation: a key-value store that cannot be opened costs the
/// language override, never the launch (05-REVIEW CR-02).
///
/// `main()` resolves `SharedPreferences` BEFORE `runApp` so the stored override
/// is on frame 1 (P-4 Option A). That ordering puts the store on the critical
/// path of starting at all: an unguarded `await` there means a plugin
/// registration failure, a corrupted prefs file or an OEM storage-permission
/// denial ends `main()` with an error, `runApp` is never called, and the user
/// sees the launch screen forever — deterministically, so restarting does not
/// help. The whole store carries ONE cosmetic key, so that trade is
/// disproportionate by orders of magnitude.
///
/// NOTHING in this file may call `SharedPreferences.setMockInitialValues`: the
/// premise is a store that FAILS, and that helper installs one that works —
/// process-wide, for every test after it. The first assertion below states the
/// premise out loud rather than assuming it.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:boostque/core/l10n/locale_controller.dart';
import 'package:boostque/core/providers.dart';
import 'package:boostque/main.dart' as entrypoint;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// The real `main()` opens the real database, so `path_provider` — and ONLY
  /// path_provider — is given a working host implementation below. The store
  /// under test stays broken; a test that mocked everything would prove the
  /// app starts when nothing is wrong, which is not the claim.
  late Directory dbDir;

  setUpAll(() {
    dbDir = Directory.systemTemp.createTempSync('boostque_cold_start');
    // Registered for the WHOLE file, never per test: the database opens lazily
    // and the resolution can land after the test that triggered it, so a
    // handler torn down per test would leave a real launch-path failure
    // reported against whatever ran next.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => dbDir.path,
    );
  });

  tearDownAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      null,
    );
    if (dbDir.existsSync()) dbDir.deleteSync(recursive: true);
  });

  testWidgets(
      'a store that cannot be opened still reaches runApp — the app starts in '
      'the system language instead of not starting (CR-02)', (tester) async {
    // Every error the launch path reports, collected instead of counted.
    //
    // Phase 7 made the launch path report MORE than one fault in a host
    // environment: the notification bootstrap runs after the first frame and, with
    // no notification plugin registered here, both its device-zone read and the
    // plugin's own initialization fail and are reported — exactly as they would be
    // reported on a device where they genuinely failed. `takeException()` returns
    // ONE exception and collapses to a summary string as soon as there are
    // several, so the assertion below names the fault it cares about rather than
    // depending on how many other subsystems also had something to say. The claim
    // is unchanged and now stated more precisely: the store failure IS reported,
    // by an app that started.
    final reported = <FlutterErrorDetails>[];
    final previousOnError = FlutterError.onError;
    FlutterError.onError = reported.add;
    addTearDown(() => FlutterError.onError = previousOnError);

    // `runAsync`, because both steps below talk to a platform channel and the
    // fake clock a widget test normally runs under never delivers that reply.
    await tester.runAsync(() async {
      // Premise, asserted rather than assumed: with no mock store registered
      // the channel has no implementation, so the resolve genuinely throws.
      await expectLater(
        SharedPreferences.getInstance(),
        throwsA(anything),
        reason: 'this file only proves anything while the store is broken; if '
            'a working store ever leaks in here the test passes vacuously',
      );

      await entrypoint.main();
    });
    await tester.pump();

    expect(
      find.byType(MaterialApp),
      findsOneWidget,
      reason: 'runApp must still have been called: an app whose entire '
          'local-first database is healthy may not be prevented from starting '
          'because one cosmetic preference could not be read',
    );
    // Let the real (lazily opened) database finish resolving inside the test
    // rather than trailing past it: the launch path is what is under test, so
    // it has to complete here.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pump();
    expect(
      reported
          .where((details) => details.exception is MissingPluginException)
          .map((details) => details.context.toString()),
      contains(contains('SharedPreferences')),
      reason: 'the store failure IS reported (a crash logger must still see a '
          'real device fault) — but it is reported by an app that started, '
          'rather than replacing the launch. Nothing user-visible carries it',
    );

    // Tear the tree down inside the body so Drift's stream-close zero-duration
    // timers fire before flutter_test's pending-timer check (the
    // `tearDownTree` shape from stack_screen_test.dart).
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 10));
    await tester.pump(const Duration(milliseconds: 10));
  });

  test('a missing store means follow-system, and the session still applies',
      () {
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(null)],
    );
    addTearDown(container.dispose);

    expect(
      container.read(localeControllerProvider),
      isNull,
      reason: 'no store means no override to read — the same state an empty '
          'store produces, so MaterialApp resolves the system locale',
    );
  });

  test('setLocale on a missing store applies for the session and does not throw',
      () async {
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(null)],
    );
    addTearDown(container.dispose);

    await container
        .read(localeControllerProvider.notifier)
        .setLocale(const Locale('uk'));

    expect(
      container.read(localeControllerProvider),
      const Locale('uk'),
      reason: 'state-first (PF-3) means the in-memory value is the truth for '
          'the session; only the NEXT launch loses it, which is exactly the '
          'cost DECIDED-8 already accepts for a failed write',
    );

    await container.read(localeControllerProvider.notifier).setLocale(null);
    expect(container.read(localeControllerProvider), isNull);
  });
}
