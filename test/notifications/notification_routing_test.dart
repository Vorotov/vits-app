/// A tapped reminder reaches Сьогодні — warm (NOTIF-01, DECIDED-10/11/13).
///
/// Every case here drives the REAL shell with the scheduler seam left at its
/// no-op default and reports the payload straight into the tap notifier. That
/// split is the whole point of the report-then-apply shape: no test in this
/// file touches the plugin, and every one of them still exercises the exact
/// code path a real tap takes, because the plugin's callback does nothing
/// except call the same mutator these tests call.
library;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:boostque/app_shell.dart';
import 'package:boostque/core/db/database.dart' show BoostqueDb;
import 'package:boostque/core/l10n/l10n.dart';
import 'package:boostque/core/notifications/notification_constants.dart';
import 'package:boostque/core/notifications/notification_providers.dart';
import 'package:boostque/core/providers.dart';
import 'package:boostque/core/selected_tab_controller.dart';
import 'package:boostque/core/theme/theme.dart';
import 'package:boostque/core/widgets/bq_add_fab.dart';
import 'package:boostque/core/widgets/bq_nav_bar.dart';
import 'package:boostque/core/today_controller.dart';
import 'package:boostque/features/calendar/calendar_providers.dart';
import 'package:boostque/features/calendar/today_screen.dart';
import 'package:boostque/features/settings/settings_screen.dart';

void main() {
  final uk = lookupAppLocalizations(const Locale('uk'));
  late SharedPreferences prefs;

  setUp(() async {
    // LocaleController seeds itself synchronously from this store (P-4).
    SharedPreferences.setMockInitialValues({});
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
}
