/// NOTIF-01/02 on-device check: after a regimen is saved, the OPERATING SYSTEM
/// is actually holding the reminder the app asked it to hold.
///
/// Run it with (iOS simulator example):
///
/// ```
/// flutter test integration_test/notification_device_test.dart -d <device-id>
/// ```
///
/// ## PRE-STEP — notification permission, once per device, BEFORE this runs
///
/// **The test cannot do this itself and must not pretend to.** Both platforms'
/// notification-permission dialogs are operating-system surfaces outside the
/// Flutter view hierarchy; `WidgetTester` can neither see nor tap them.
///
/// - **Android:** grant it from the host shell before the run —
///   `adb shell pm grant com.boostque.dev android.permission.POST_NOTIFICATIONS`
///   (an emulator below API 33 needs no grant: the permission does not exist
///   there and `areNotificationsEnabled()` answers true).
/// - **iOS:** a person launches the app by hand, saves one regimen, and answers
///   the system dialog **Allow**. There is no shell equivalent, and there is
///   exactly one prompt per install.
///
/// Without the grant the app schedules **nothing, by design** — the sync's
/// `isEnabled()` gate is what makes a denied permission silent rather than a
/// stream of failing platform calls. So an ungranted run would find an empty
/// pending set, and a tolerantly-written test would report that emptiness as a
/// pass. This one fails instead, with a message naming the pre-step. There is
/// no code path here in which an empty pending set is a pass.
///
/// ## The other way this test could have measured nothing
///
/// `notificationSchedulerProvider` **defaults to the no-op implementation**,
/// deliberately, so that no widget test can reach the plugin by accident — and
/// the no-op's pending list is documented as always empty. The existing device
/// harness this file follows (`data03_loop_test.dart`) builds its OWN provider
/// scope with a single preferences override; it does not run `main()`, so it
/// does not inherit `main()`'s scheduler override. A device test written on
/// that precedent resolves the NO-OP and asserts against an empty list that has
/// nothing to do with the device.
///
/// That the default really is the no-op, and that the no-op really does answer
/// every method without a plugin, are asserted in the host suite
/// (`test/notifications/notification_bootstrap_test.dart`, "the seam defaults").
/// This file's first assertion is the other half of that fact: on a device, the
/// resolved scheduler must NOT be it.
///
/// So this file installs the plugin-backed scheduler exactly as `main()` does,
/// and its **first assertion** is that the resolved scheduler is not the no-op,
/// with a failure message naming the missing override. A mis-scoped run reports
/// its real cause on line one instead of failing somewhere confusing later — or,
/// worse, passing.
///
/// ## What this proves, and what it does NOT
///
/// It proves the app asked the operating system for the right thing and the
/// operating system **accepted** it: the pending-request set, read back through
/// the platform, contains the id the app derived for the configured time.
///
/// It does **not** prove that the notification arrives, when it arrives, or
/// what it looks like. Delivery, doze latency, the lock-screen rendering, the
/// two permission dialogs and the Android channel row are unobservable from
/// inside the app on either platform, and they are the phase's device pass —
/// `.planning/phases/07-dose-reminders/07-UAT.md`.
///
/// ## It runs against the user's real database, and cleans up after itself
///
/// Nothing here edits or deletes a pre-existing row. It creates one supplement
/// named with [_namePrefix] plus the first free index, at a deliberately
/// unusual time of day, and soft-deletes it at the end — which doubles as an
/// on-device check of the cancel path. Every assertion is scoped to the id that
/// time derives; the rest of the user's scheduled set is neither asserted on
/// nor disturbed.
///
/// ## One documented precondition of the assertion itself
///
/// The regimen it creates runs EVERY day from today, so the pure plan promotes
/// its minute to a single repeating request — which is ordered first and is
/// therefore structurally safe from the budget however large the device's real
/// stack is. That promotion holds only if no OTHER regimen in the user's stack
/// has a dose slot at the same minute without also running every day. [_minute]
/// is 23:47 to make that collision as unlikely as a minute can be; a failure
/// here names it as the first thing to check.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:boostque/core/domain/models.dart';
import 'package:boostque/core/notifications/notification_plan.dart';
import 'package:boostque/core/notifications/notification_providers.dart';
import 'package:boostque/core/notifications/notification_scheduler.dart';
import 'package:boostque/core/notifications/notification_service.dart';
import 'package:boostque/core/notifications/tz_conversion.dart';
import 'package:boostque/core/providers.dart';
import 'package:boostque/core/today_controller.dart';
import 'package:boostque/core/widgets/bq_nav_bar.dart';
import 'package:boostque/main.dart' show BoostqueApp;

/// Prefix every supplement this test creates carries.
const String _namePrefix = 'NOTIF-07 Тест';

/// The dose time this test configures, as minutes from midnight — 23:47.
///
/// Unusual on purpose: the assertion below identifies the app's reminder by the
/// id this minute derives, and an ordinary time like 08:00 would collide with
/// the user's own stack on a real device.
const int _minute = 23 * 60 + 47;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'NOTIF: a saved regimen is actually held by the OS scheduler, on device',
    (tester) async {
      // ---------------------------------------------------------------
      // (a) boot with the SAME overrides main() installs
      // ---------------------------------------------------------------
      // On device this is the REAL preferences store and the REAL database:
      // this test runs against the user's own app state, exactly as DATA-03
      // does.
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            // THE override this whole file turns on. Without it the provider
            // resolves the no-op, whose pending list is always empty.
            notificationSchedulerProvider
                .overrideWith((ref) => PluginNotificationScheduler()),
            timeZoneLoaderProvider.overrideWithValue(initTimeZones),
            deviceZoneReaderProvider.overrideWithValue(deviceZoneIdentifier),
          ],
          child: const BoostqueApp(),
        ),
      );
      await _pump(tester, 20);

      final container = ProviderScope.containerOf(
        tester.element(find.byType(BoostqueApp)),
        listen: false,
      );

      // ---------------------------------------------------------------
      // (b) THE FIRST ASSERTION: this is not the no-op
      // ---------------------------------------------------------------
      // Before anything else is asserted, because every later assertion is
      // meaningless if this one is false — and one of them would silently PASS.
      final scheduler = container.read(notificationSchedulerProvider);
      expect(
        scheduler,
        isA<PluginNotificationScheduler>(),
        reason: 'notificationSchedulerProvider resolved '
            '${scheduler.runtimeType}, not the plugin-backed adapter. This test '
            'MUST install `notificationSchedulerProvider.overrideWith((ref) => '
            'PluginNotificationScheduler())` in its own ProviderScope, exactly '
            'as main() does — it does not run main(), so it inherits nothing '
            'from it. The default is NoopNotificationScheduler, whose pending() '
            'is documented as always empty: a device test that resolves it '
            'measures nothing at all while looking like it measured the device, '
            'which is worse than having no device test.',
      );
      expect(
        scheduler,
        isNot(isA<NoopNotificationScheduler>()),
        reason: 'stated as its own assertion rather than left implicit in the '
            'one above: the no-op is the specific thing that must not be here.',
      );
      expect(find.byType(BqNavBar), findsOneWidget, reason: 'app shell painted');

      // ---------------------------------------------------------------
      // (c) the permission pre-step, checked rather than assumed
      // ---------------------------------------------------------------
      final enabled = await scheduler.isEnabled();
      expect(
        enabled,
        isTrue,
        reason: 'the operating system says notifications are not permitted for '
            'this app (the check answered $enabled), so the app will schedule '
            'NOTHING — by design, because that is what makes a denied '
            'permission silent instead of a stream of failing platform calls.\n'
            '\n'
            'THE PERMISSION PRE-STEP WAS NOT PERFORMED ON THIS DEVICE. It is '
            'not something this test can do: both platforms\' permission '
            'dialogs are OS surfaces the test driver cannot see or tap.\n'
            '  Android: adb shell pm grant com.boostque.dev '
            'android.permission.POST_NOTIFICATIONS\n'
            '  iOS:     launch the app by hand, save one regimen, answer the '
            'system dialog Allow.\n'
            '\n'
            'This assertion exists so that an ungranted run FAILS here rather '
            'than finding an empty pending set later and reporting it as a '
            'pass.',
      );

      // ---------------------------------------------------------------
      // (d) create one supplement and one daily regimen, at 23:47
      // ---------------------------------------------------------------
      final existing = await _stack(tester, container);
      debugPrint('NOTIF: stack already holds ${existing.length} supplement(s)');

      var index = existing.length;
      String name() => '$_namePrefix $index';
      while (existing.any((s) => s.name == name())) {
        index++;
      }
      final supplementName = name();
      final supplementId = 'notif-device-$index-${DateTime.now().microsecondsSinceEpoch}';
      debugPrint('NOTIF: this run uses "$supplementName" ($supplementId)');

      final today = container.read(todayProvider);
      await container.read(supplementRepoProvider).upsert(
            Supplement(
              id: supplementId,
              name: supplementName,
              doseText: '1 капсула',
              colorValue: 0xFF6B7A8F,
              note: '',
            ),
          );
      await container.read(regimenRepoProvider).upsert(
            Regimen(
              id: 'reg-$supplementId',
              supplementId: supplementId,
              kind: RegimenKind.cyclic,
              startDate: today,
              endDate: null,
              // Every day, no break: the pure plan promotes this minute to ONE
              // repeating request, which is ordered ahead of every one-shot and
              // is therefore never the entry the budget truncates — whatever
              // size the user's real stack is.
              onDays: 365,
              offDays: 0,
              paused: false,
              slots: const [
                DoseSlot(
                  id: 'slot-2347',
                  minutesFromMidnight: _minute,
                  doseLabel: '1',
                ),
              ],
            ),
          );

      // ---------------------------------------------------------------
      // (e) the operating system is holding it
      // ---------------------------------------------------------------
      final expectedId =
          notificationIdFor(day: null, minutesFromMidnight: _minute);
      debugPrint('NOTIF: waiting for pending request $expectedId (23:47 repeat)');

      await _pumpUntilPending(
        tester,
        scheduler,
        (ids) => ids.contains(expectedId),
        'the OS pending set to contain $expectedId — the repeat this app '
            'derives for 23:47. If it never arrives, check in this order: (1) '
            'the permission pre-step above; (2) whether another regimen in this '
            'device\'s stack has a dose slot at 23:47 without running every '
            'day, which blocks the promotion and would make the app schedule '
            'one-shots under different ids instead; (3) whether the write '
            'reached the regimens stream at all',
      );

      final held = await _pendingIds(scheduler);
      expect(
        held,
        contains(expectedId),
        reason: 'the platform accepted and is holding the reminder the app '
            'asked for. This is the strongest statement available from inside '
            'the app: it says nothing about delivery, timing or appearance, '
            'which are the device pass in 07-UAT.md.',
      );
      debugPrint('NOTIF: OS holds ${held.length} pending request(s), '
          'including $expectedId');

      // ---------------------------------------------------------------
      // (f) delete it again — the cancel path, on the device, and a clean
      //     device afterwards
      // ---------------------------------------------------------------
      await container.read(supplementRepoProvider).softDeleteCascade(
            supplementId,
            fromDay: today,
          );
      await _pumpUntilPending(
        tester,
        scheduler,
        (ids) => !ids.contains(expectedId),
        'the OS to stop holding $expectedId after the supplement was deleted. '
            'A cascade soft-delete removes the regimen from the stream the sync '
            'watches, and reconciliation cancels by id — never by clearing '
            'everything, which would also dismiss delivered reminders the user '
            'has not acted on',
      );
      debugPrint('NOTIF: $expectedId cancelled; this run left no reminder '
          'behind');

      // Leave the tree torn down so Drift's stream-close timers and the midnight
      // timer are gone before the harness's pending-timer check.
      await tester.pumpWidget(const SizedBox());
      await _pump(tester, 20);
    },
    timeout: const Timeout(Duration(minutes: 10)),
  );
}

/// Pumps [frames] real frames, [ms] apart (the live binding runs real time).
Future<void> _pump(WidgetTester tester, int frames, [int ms = 50]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(Duration(milliseconds: ms));
  }
}

/// The ids the platform is currently holding for this app.
Future<Set<int>> _pendingIds(NotificationScheduler scheduler) async =>
    {for (final request in await scheduler.pending()) request.id};

/// Pumps until the platform's pending set satisfies [condition].
///
/// Never `pumpAndSettle`: the minute ticker and the midnight timer are both
/// permanently pending, Drift emissions arrive asynchronously, and the sync
/// deliberately debounces before it applies anything.
Future<void> _pumpUntilPending(
  WidgetTester tester,
  NotificationScheduler scheduler,
  bool Function(Set<int> ids) condition,
  String what, {
  int attempts = 120,
}) async {
  Set<int> ids = const <int>{};
  for (var i = 0; i < attempts; i++) {
    await _pump(tester, 4, 100);
    ids = await _pendingIds(scheduler);
    if (condition(ids)) return;
  }
  // On a device the only thing worse than a timeout is a timeout that does not
  // say what the device actually held: dump both the pending set and the screen,
  // so the next failure is diagnosable from one run's log rather than from one
  // run per hypothesis.
  debugPrint('NOTIF pending ids at timeout (${ids.length}): $ids');
  final texts = find
      .byType(Text)
      .evaluate()
      .map((e) => (e.widget as Text).data)
      .where((s) => s != null)
      .toList();
  debugPrint('NOTIF on-screen text at timeout: $texts');
  fail('NOTIF timed out waiting for $what');
}

/// The stack as the app's own provider graph reports it, once it has data.
Future<List<Supplement>> _stack(
  WidgetTester tester,
  ProviderContainer container,
) async {
  for (var i = 0; i < 200; i++) {
    await tester.pump(const Duration(milliseconds: 50));
    switch (container.read(supplementsStreamProvider)) {
      case AsyncData(value: final data):
        return data;
      case _:
        continue;
    }
  }
  fail('NOTIF timed out waiting for supplementsStreamProvider to resolve');
}
