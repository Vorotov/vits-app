/// A tapped reminder reaches Сьогодні — warm and cold (NOTIF-01,
/// DECIDED-10/11/12/13).
///
/// Every warm case here drives the REAL shell with the scheduler seam left at
/// its no-op default and reports the payload straight into the tap notifier.
/// That split is the whole point of the report-then-apply shape: no test in
/// this file touches the plugin, and every one of them still exercises the
/// exact code path a real tap takes, because the plugin's callback does nothing
/// except call the same mutator these tests call.
///
/// ## The COUNTED gate over the pre-`runApp` window lives here
///
/// This file owns it, because it belongs beside the frame-1 guarantee it
/// protects. **The count is now TWO** — the preferences resolution that has
/// been there since plan 05-01, and the notification launch-details read this
/// plan adds. Only the second has a frame-1 dependency; nothing else may join
/// them (07-UI-CHECK FLAG-3).
///
/// Plan 07-01 deliberately shipped a **needle** gate over the same window
/// (`notification_bootstrap_test.dart`) — it names the three bootstrap calls
/// that may never appear there and counts nothing, precisely so this plan's
/// legitimate addition could not put two gates into contradiction. Between
/// them the window has one gate saying what may never be there and one saying
/// how much may be, with one owner each. Do not move either one into the
/// other's file, and do not relax either to make the other pass.
library;

import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:boostque/app_shell.dart';
import 'package:boostque/core/db/database.dart' show BoostqueDb;
import 'package:boostque/core/l10n/l10n.dart';
import 'package:boostque/core/notifications/notification_constants.dart';
import 'package:boostque/core/notifications/notification_providers.dart';
import 'package:boostque/core/notifications/notification_service.dart';
import 'package:boostque/core/providers.dart';
import 'package:boostque/core/selected_tab_controller.dart';
import 'package:boostque/core/theme/theme.dart';
import 'package:boostque/core/widgets/bq_add_fab.dart';
import 'package:boostque/core/widgets/bq_nav_bar.dart';
import 'package:boostque/core/today_controller.dart';
import 'package:boostque/features/calendar/calendar_providers.dart';
import 'package:boostque/features/calendar/today_screen.dart';
import 'package:boostque/features/settings/settings_screen.dart';
import 'package:boostque/main.dart' as entrypoint;

void main() {
  final uk = lookupAppLocalizations(const Locale('uk'));
  late SharedPreferences prefs;

  setUp(() async {
    // LocaleController seeds itself synchronously from this store (P-4).
    // `onboarding_seen`: a launch payload can only exist for a user who
    // saved a regimen long after onboarding, so the cold-start frames are a
    // returning user's — an empty store would (correctly) paint the intro
    // instead of the shell and fail every frame-one assertion below.
    SharedPreferences.setMockInitialValues({'onboarding_seen': true});
    prefs = await SharedPreferences.getInstance();
  });

  ProviderContainer makeContainer() {
    return ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        dbProvider.overrideWith((ref) {
          final db = BoostqueDb.forTesting(NativeDatabase.memory());
          ref.onDispose(db.close);
          return db;
        }),
      ],
    );
  }

  Widget shellApp(ProviderContainer container) {
    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        locale: const Locale('uk'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: bqTheme(),
        home: const AppShell(),
      ),
    );
  }

  /// Bounded pumping. Never `pumpAndSettle`: the shell holds a midnight
  /// [Timer] for the whole session, so settling either hangs or passes for a
  /// reason the test did not intend (PF-7).
  Future<void> pumpFrames(WidgetTester tester, [int frames = 20]) async {
    for (var i = 0; i < frames; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
  }

  Future<void> flushTearDown(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 10));
    await tester.pump(const Duration(milliseconds: 10));
  }

  /// What the platform hands back on a tap, delivered exactly as the plugin's
  /// callback delivers it.
  void reportTap(ProviderContainer container, String? payload) =>
      container.read(notificationTapProvider.notifier).report(payload);

  int selectedTab(WidgetTester tester) => tester
      .widget<BqNavBar>(find.byType(BqNavBar, skipOffstage: false))
      .selectedIndex;

  /// The Сьогодні screen's own heading, scoped to its subtree — the nav bar
  /// carries the identical string as a destination label, so an unscoped
  /// finder would pass while the screen showed a past day.
  Finder todayHeading() => find.descendant(
        of: find.byType(TodayScreen),
        matching: find.text(uk.calendarTitleToday),
      );

  group('the warm tap (DECIDED-10, DECIDED-13)', () {
    testWidgets('the known payload selects Сьогодні', (tester) async {
      final container = makeContainer();
      await tester.pumpWidget(shellApp(container));
      await pumpFrames(tester);

      expect(selectedTab(tester), stackTabIndex,
          reason: 'the app opens on Стек — the case is about the tap MOVING '
              'the destination, not about the default being right');

      reportTap(container, doseTapPayload);
      await pumpFrames(tester);

      expect(selectedTab(tester), todayTabIndex);
      expect(find.byType(TodayScreen), findsOneWidget);
      expect(tester.takeException(), isNull);

      await flushTearDown(tester);
      container.dispose();
      await tester.pump(const Duration(milliseconds: 10));
    });

    testWidgets(
        'BOTH effects, in one case: the destination moves AND the browsed day '
        'returns to today', (tester) async {
      final container = makeContainer();
      await tester.pumpWidget(shellApp(container));
      await pumpFrames(tester);

      // A past day, selected the way the week strip selects one.
      final today = container.read(todayProvider);
      final browsed = today.subtract(const Duration(days: 3));
      container.read(selectedDayProvider.notifier).select(browsed);
      await pumpFrames(tester);
      expect(container.read(selectedDayProvider), browsed);

      reportTap(container, doseTapPayload);
      await pumpFrames(tester);

      // Asserted TOGETHER on purpose: a handler that sets the tab and forgets
      // the day passes two separate tests and still lands the user on
      // Monday's dose list with the reminder describing doses that are not on
      // screen and a past day's taken state (DECIDED-10).
      expect(selectedTab(tester), todayTabIndex);
      expect(
        container.read(selectedDayProvider),
        isNull,
        reason: 'null is "follow today". The browsed day survives a tab round '
            'trip BY CONSTRUCTION (the shell keeps Сьогодні mounted on every '
            'destination), so it does not clear itself',
      );
      expect(
        todayHeading(),
        findsOneWidget,
        reason: 'the screen the user now reads is TODAY: the heading is the '
            'today title, not the browsed weekday',
      );
      expect(
        find.descendant(
          of: find.byType(TodayScreen),
          matching: find.text(
            DateFormat('EEEE', 'uk').format(browsed),
          ),
        ),
        findsNothing,
        reason: 'and the browsed day\'s weekday is gone from the screen',
      );

      await flushTearDown(tester);
      container.dispose();
      await tester.pump(const Duration(milliseconds: 10));
    });

    testWidgets('an unknown payload is inert — no destination change, no day '
        'reset', (tester) async {
      final container = makeContainer();
      await tester.pumpWidget(shellApp(container));
      await pumpFrames(tester);

      final today = container.read(todayProvider);
      final browsed = today.subtract(const Duration(days: 3));
      container.read(selectedDayProvider.notifier).select(browsed);
      await pumpFrames(tester);

      // A payload an OLDER BUILD could have written and the operating system
      // replayed after an update — the exact case the whitelist exists for.
      reportTap(container, 'today/2026-08-17/08:00');
      await pumpFrames(tester);

      expect(selectedTab(tester), stackTabIndex);
      expect(container.read(selectedDayProvider), browsed);
      expect(tester.takeException(), isNull,
          reason: 'inert means inert: no error surfaces, nothing is logged to '
              'the user, the app opens on whatever it would have opened on');

      await flushTearDown(tester);
      container.dispose();
      await tester.pump(const Duration(milliseconds: 10));
    });

    testWidgets('a null payload is inert', (tester) async {
      final container = makeContainer();
      await tester.pumpWidget(shellApp(container));
      await pumpFrames(tester);

      final browsed =
          container.read(todayProvider).subtract(const Duration(days: 3));
      container.read(selectedDayProvider.notifier).select(browsed);
      await pumpFrames(tester);

      reportTap(container, null);
      await pumpFrames(tester);

      expect(selectedTab(tester), stackTabIndex);
      expect(container.read(selectedDayProvider), browsed);
      expect(tester.takeException(), isNull);

      await flushTearDown(tester);
      container.dispose();
      await tester.pump(const Duration(milliseconds: 10));
    });

    testWidgets('the known payload twice in a row lands in the same state, and '
        'the second tap still returns the day', (tester) async {
      final container = makeContainer();
      await tester.pumpWidget(shellApp(container));
      await pumpFrames(tester);

      reportTap(container, doseTapPayload);
      await pumpFrames(tester);
      expect(selectedTab(tester), todayTabIndex);

      // Between the two taps the user browses away — which is what makes the
      // second tap a real event rather than a duplicate to swallow. A report
      // that carried only the payload string would compare equal to the first
      // and notify nobody, so the user would tap a reminder and stay on a past
      // day.
      final browsed =
          container.read(todayProvider).subtract(const Duration(days: 2));
      container.read(selectedDayProvider.notifier).select(browsed);
      await pumpFrames(tester);

      reportTap(container, doseTapPayload);
      await pumpFrames(tester);

      expect(selectedTab(tester), todayTabIndex);
      expect(container.read(selectedDayProvider), isNull);
      expect(tester.takeException(), isNull);

      await flushTearDown(tester);
      container.dispose();
      await tester.pump(const Duration(milliseconds: 10));
    });

    testWidgets('nothing is shown: no snackbar, no banner, no dialog on any '
        'path', (tester) async {
      final container = makeContainer();
      await tester.pumpWidget(shellApp(container));
      await pumpFrames(tester);

      for (final payload in <String?>[doseTapPayload, null, 'nope']) {
        reportTap(container, payload);
        await pumpFrames(tester);
        expect(find.byType(SnackBar), findsNothing);
        expect(find.byType(MaterialBanner), findsNothing);
        expect(find.byType(Dialog), findsNothing);
        expect(find.byType(AlertDialog), findsNothing);
        expect(tester.takeException(), isNull);
      }

      await flushTearDown(tester);
      container.dispose();
      await tester.pump(const Duration(milliseconds: 10));
    });
  });

  group('the tap never pops a pushed route (DECIDED-11)', () {
    testWidgets('with Settings pushed, the destination changes UNDERNEATH and '
        'the route is still on screen', (tester) async {
      final container = makeContainer();
      await tester.pumpWidget(shellApp(container));
      await pumpFrames(tester);

      await tester.tap(find.byIcon(Icons.settings_outlined));
      await tester.pumpAndSettle();
      expect(find.byType(SettingsScreen), findsOneWidget);

      reportTap(container, doseTapPayload);
      await pumpFrames(tester);

      expect(
        find.text(uk.settingsTitle),
        findsOneWidget,
        reason: 'the pushed route survives the tap. Popping would discard an '
            'in-progress regimen edit because a timer fired — a destructive '
            'side effect triggered by the clock (DECIDED-11)',
      );
      expect(
        find.byType(BqAddFab),
        findsNothing,
        reason: 'the shell is still offstage under the opaque route, exactly '
            'as it was before the tap — the tap changed a destination, not '
            'the route stack',
      );
      // The destination underneath DID move — read from the CONTAINER, not
      // from the offstage bar. Flutter does not rebuild a subtree that is
      // offstage under an opaque route, so the bar widget sitting under
      // Settings still carries the index it was built with; asserting on it
      // would be asserting a repaint the framework deliberately defers, and
      // the first version of this test failed exactly that way
      // (Expected: <1> / Actual: <0>) while the state was already right.
      expect(container.read(selectedTabProvider), todayTabIndex);

      // And the deferral IS the accepted cost, so it is asserted rather than
      // described: the user leaves the route themselves and lands on Сьогодні
      // — the right place, just later (DECIDED-11).
      await tester
          .state<NavigatorState>(find.byType(Navigator).first)
          .maybePop();
      await pumpFrames(tester);

      expect(selectedTab(tester), todayTabIndex);
      expect(find.byType(TodayScreen), findsOneWidget);
      expect(tester.takeException(), isNull);

      await flushTearDown(tester);
      container.dispose();
      await tester.pump(const Duration(milliseconds: 10));
    });
  });

  // ---------------------------------------------------------------------
  // The cold start (DECIDED-12). The launch answer has to exist BEFORE the
  // first frame, because the defect this is about is a Стек frame that paints
  // and is then replaced — and that defect passes every test that settles
  // first. So these cases assert on the FIRST pump, with no settle anywhere.
  // ---------------------------------------------------------------------

  group('the cold start renders the right destination on frame ONE', () {
    final en = lookupAppLocalizations(const Locale('en'));

    /// The ROOT app widget, not the shell: the launch seed is installed by
    /// `main()` as an override, and the widget under test has to be the one
    /// the user actually gets.
    Widget rootApp(ProviderContainer container) => UncontrolledProviderScope(
          container: container,
          child: const entrypoint.BoostqueApp(),
        );

    ProviderContainer coldContainer(String? launchPayload) {
      return ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          dbProvider.overrideWith((ref) {
            final db = BoostqueDb.forTesting(NativeDatabase.memory());
            ref.onDispose(db.close);
            return db;
          }),
          launchNotificationPayloadProvider.overrideWithValue(launchPayload),
        ],
      );
    }

    testWidgets('launched from a tap: Сьогодні is on the first frame and Стек '
        'is never painted', (tester) async {
      final container = coldContainer(doseTapPayload);

      // ONE pump, and that is the assertion. Settling would hide exactly the
      // defect this test is about: a Стек frame followed by a jump passes any
      // test that settles first.
      await tester.pumpWidget(rootApp(container));

      expect(
        find.descendant(
          of: find.byType(TodayScreen),
          matching: find.text(en.calendarTitleToday),
        ),
        findsOneWidget,
        reason: 'scoped to the screen: the nav bar carries the identical '
            'string as a destination label, so an unscoped finder would pass '
            'while Стек was the painted screen',
      );
      expect(
        find.text(en.stackTitle),
        findsNothing,
        reason: 'the Стек heading is not painted on frame one and is '
            'therefore never replaced — a launch answer that arrived a frame '
            'later would show it here',
      );
      expect(container.read(selectedTabProvider), todayTabIndex);
      expect(tester.takeException(), isNull);

      await flushTearDown(tester);
      container.dispose();
      await tester.pump(const Duration(milliseconds: 10));
    });

    for (final (name, payload) in const <(String, String?)>[
      ('no launch payload at all', null),
      ('a payload from an older build', 'today/2026-08-17/08:00'),
    ]) {
      testWidgets('$name: frame one is Стек, exactly as it is today',
          (tester) async {
        final container = coldContainer(payload);
        await tester.pumpWidget(rootApp(container));

        expect(find.text(en.stackTitle), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(TodayScreen),
            matching: find.text(en.calendarTitleToday),
          ),
          findsNothing,
        );
        expect(container.read(selectedTabProvider), stackTabIndex);
        expect(tester.takeException(), isNull);

        await flushTearDown(tester);
        container.dispose();
        await tester.pump(const Duration(milliseconds: 10));
      });
    }

    testWidgets('warm and cold land in the SAME state — same destination, same '
        'browsed day', (tester) async {
      // Cold: the launch answer seeds the notifier.
      final cold = coldContainer(doseTapPayload);
      await tester.pumpWidget(rootApp(cold));
      await pumpFrames(tester);
      final coldTab = cold.read(selectedTabProvider);
      final coldDay = cold.read(selectedDayProvider);
      await flushTearDown(tester);
      cold.dispose();
      await tester.pump(const Duration(milliseconds: 10));

      // Warm: the same payload arrives through the tap callback instead.
      final warm = makeContainer();
      await tester.pumpWidget(shellApp(warm));
      await pumpFrames(tester);
      reportTap(warm, doseTapPayload);
      await pumpFrames(tester);
      final warmTab = warm.read(selectedTabProvider);
      final warmDay = warm.read(selectedDayProvider);

      expect(coldTab, warmTab,
          reason: 'the two paths share ONE predicate and ONE destination '
              'index, and this is what holds two code paths to one answer');
      expect(coldDay, warmDay);
      expect(coldTab, todayTabIndex);
      expect(
        coldDay,
        isNull,
        reason: 'the cold path\'s day reset is FREE today — the browsed day '
            'starts out following today — and it is asserted anyway, because '
            '"free" is a property of the current default and this is what '
            'notices if that default ever changes',
      );

      await flushTearDown(tester);
      warm.dispose();
      await tester.pump(const Duration(milliseconds: 10));
    });
  });

  group('FLAG-3 — how much may sit before the first frame (the COUNTED gate)',
      () {
    /// The source between `ensureInitialized()` and `runApp(`, with line
    /// comments stripped so commentary naming an await cannot trip its own
    /// gate — the convention every source gate in this suite follows.
    String preRunAppWindow() {
      final stripped = File('lib/main.dart')
          .readAsStringSync()
          .split('\n')
          .where((line) => !line.trimLeft().startsWith('//'))
          .join('\n');
      final start = stripped.indexOf('ensureInitialized()');
      final end = stripped.indexOf('runApp(');
      expect(start, greaterThanOrEqualTo(0),
          reason: 'lib/main.dart no longer calls ensureInitialized(); this '
              'gate cannot locate the window it protects');
      expect(end, greaterThan(start),
          reason: 'lib/main.dart no longer calls runApp() after '
              'ensureInitialized(); this gate cannot locate the window');
      return stripped.substring(start, end);
    }

    test('EXACTLY two awaits sit between binding initialization and runApp',
        () {
      final window = preRunAppWindow();
      final awaits = RegExp(r'\bawait\b').allMatches(window).length;
      expect(
        awaits,
        2,
        reason: 'FLAG-3: exactly two things may be awaited before the first '
            'frame, and both are here because their ANSWERS have to exist by '
            'frame one — the SharedPreferences resolution (the stored '
            'language override, P-4 Option A) and the notification '
            'launch-details read (the destination a tap launched the app '
            'into, DECIDED-12). A third would cost every cold start: the zone '
            'database alone is roughly a megabyte to parse, and the plugin\'s '
            'initialize() and the channel creation are platform round trips, '
            'all of which already sit AFTER the first frame. The existing '
            'cold-start guarantee cannot catch this — it asserts the shell '
            'paints on frame ONE, which is a frame count, so added work here '
            'leaves every test green and every launch slower. Found $awaits.',
      );
    });
  });

  group('a launch-details read that throws cannot stop the app from starting',
      () {
    late Directory dbDir;

    setUpAll(() {
      // The real main() opens the real database, so path_provider — and only
      // path_provider — is given a working host implementation. Registered for
      // the whole group because the database opens lazily and the resolution
      // can land after the test that triggered it.
      dbDir = Directory.systemTemp.createTempSync('boostque_launch_read');
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

    testWidgets('the real main() still reaches runApp, starts on Стек, and '
        'reports the failure to the crash logger', (tester) async {
      final en = lookupAppLocalizations(const Locale('en'));
      // Collected rather than counted: this launch path reports several faults
      // in a plugin-less host, and takeException() collapses to a summary
      // string as soon as there is more than one.
      final reported = <FlutterErrorDetails>[];
      final previousOnError = FlutterError.onError;
      FlutterError.onError = reported.add;
      addTearDown(() => FlutterError.onError = previousOnError);

      // runAsync, because the launch path talks to platform channels and the
      // fake clock a widget test runs under never delivers those replies.
      await tester.runAsync(() async {
        // The premise, asserted rather than assumed: with no notification
        // plugin registered the launch-details read genuinely throws (the
        // plugin's platform instance is a static late field with no default —
        // 07-RESEARCH correction C-3). If it ever stops throwing here, this
        // test passes vacuously.
        await expectLater(
          PluginNotificationScheduler().launchPayload(),
          throwsA(anything),
        );
        await entrypoint.main();
      });
      await tester.pump();

      expect(
        find.byType(MaterialApp),
        findsOneWidget,
        reason: 'a notification tap must NEVER be able to prevent the app '
            'from starting. This window sits between binding initialization '
            'and runApp, so an escaping error means runApp is never called at '
            'all: no Flutter UI attaches, the user stares at the launch '
            'screen, and because the failure is deterministic restarting does '
            'not help',
      );
      expect(
        find.text(en.stackTitle),
        findsOneWidget,
        reason: 'and it degrades to the DEFAULT destination — an unreadable '
            'launch answer is no launch answer',
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)),
      );
      await tester.pump();
      expect(
        reported.map((details) => details.context.toString()),
        contains(contains('launch')),
        reason: 'reported for the crash logger, never surfaced: there is '
            'nothing the user could do, and the app works',
      );

      await flushTearDown(tester);
    });
  });
}
