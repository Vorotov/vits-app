/// Widget tests for the planner page and its Calendar-tab seam
/// (plan 04-01, DECIDED-1, UI-SPEC S4-amendment / S6a).
///
/// Harness pieces come from `calendar_screen_test.dart`: real in-memory Drift
/// database behind the repository providers, a PINNED clock so the window is
/// the same on any machine on any day, locale uk, a 390x844 logical surface,
/// `pumpUntil` instead of `pumpAndSettle` (the midnight timer and the minute
/// ticker are both permanently pending), and an in-body `tearDownTree`.
///
/// The navigation test is driven from the Calendar screen, not by pumping
/// `PlannerScreen` directly, so the tap path under test is the real one.
library;

import 'package:boostque/app_shell.dart';
import 'package:boostque/core/db/database.dart' show BoostqueDb;
import 'package:boostque/core/domain/models.dart';
import 'package:boostque/core/l10n/l10n.dart';
import 'package:boostque/core/domain/repositories.dart' show StackEntry;
import 'package:boostque/core/providers.dart';
import 'package:boostque/core/theme/theme.dart';
import 'package:boostque/core/theme/tokens.dart';
import 'package:boostque/core/today_controller.dart';
import 'package:boostque/features/calendar/calendar_providers.dart';
import 'package:boostque/features/calendar/calendar_screen.dart';
import 'package:boostque/core/widgets/bq_nav_bar.dart';
import 'package:boostque/core/widgets/bq_segmented.dart';
import 'package:boostque/features/calendar/planner_gantt.dart';
import 'package:boostque/features/calendar/planner_providers.dart';
import 'package:boostque/features/calendar/planner_screen.dart';
import 'package:boostque/features/calendar/planner_year_grid.dart';
import 'package:boostque/features/calendar/week_strip.dart';
import 'package:boostque/features/settings/settings_screen.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

// `show` rather than a bare import: one group below declares a local
// `overflowReason` that predates the shared library, and importing the whole
// library would collide. The scale list is the one thing that must NOT be a
// per-file literal — the file that quietly omits a scale has a matrix that no
// longer covers it.
import '../support/locale_matrix.dart' show bqTextScaleMatrix;

void main() {
  const magnesium = Supplement(
    id: 's1',
    name: 'Магній бісглицинат',
    doseText: '400 мг · капсули',
    colorValue: 0xFF6B6FA8,
    note: '',
  );
  const creatine = Supplement(
    id: 's2',
    name: 'Креатин моногідрат',
    doseText: '5 г',
    colorValue: 0xFF3F7A6A,
    note: '',
  );
  const vitaminD = Supplement(
    id: 's3',
    name: 'Вітамін D3',
    doseText: '2000 МО',
    colorValue: 0xFFB08A2A,
    note: '',
  );

  final today = DateTime.utc(2026, 8, 13);

  late BoostqueDb db;
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    // Since plan 05-01 LocaleController seeds itself SYNCHRONOUSLY from
    // sharedPreferencesProvider, which throws unless overridden. Only the
    // `system back` group mounts the real AppShell (and with it the Settings
    // tab's language picker), but the seed goes in the shared container so a
    // later test that mounts the shell is covered the day it lands.
    prefs = await SharedPreferences.getInstance();
  });

  /// [stackState] pins `stackEntriesProvider` to a fixed AsyncValue so the
  /// loading and error surfaces can be exercised.
  ///
  /// It is an AsyncValue rather than a list of overrides because Riverpod 3
  /// does not export `Override` as public API — the same shape of gap as
  /// `ProviderListenable`, and the same workaround: type against the concrete
  /// thing instead.
  ProviderContainer makeContainer({
    DateTime? clock,
    AsyncValue<List<StackEntry>>? stackState,
  }) {
    return ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        dbProvider.overrideWith((ref) {
          final database = BoostqueDb.forTesting(NativeDatabase.memory());
          ref.onDispose(database.close);
          db = database;
          return database;
        }),
        todayProvider.overrideWith(() => _FixedToday(clock ?? today)),
        // Pins the OTHER sanctioned clock read so the Today page under the
        // planner never depends on what time the suite runs at.
        nowMinutesProvider.overrideWith((ref) => Stream.value(600)),
        if (stackState != null)
          stackEntriesProvider.overrideWith((ref) => stackState),
      ],
    );
  }

  /// The Calendar tab, which is where the planner is entered from.
  ///
  /// [textScaler] pins the accessibility text scale for the whole subtree —
  /// the S4-amendment header action pair is only meaningful against a scale it
  /// did not choose (WR-04).
  Widget app(ProviderContainer container, {TextScaler? textScaler}) {
    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        locale: const Locale('uk'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: bqTheme(),
        builder: (context, child) => textScaler == null
            ? child!
            : MediaQuery(
                data: MediaQuery.of(context).copyWith(textScaler: textScaler),
                child: child!,
              ),
        home: const CalendarScreen(),
      ),
    );
  }

  /// The planner pumped on its own.
  ///
  /// Legitimate because the screen is navigation-agnostic by design: the tap
  /// path from the Calendar header is proven once, by the tests above, and
  /// every shell assertion below is about the planner itself. It also keeps
  /// the Today page — and its bounded materialization — out of these tests.
  ///
  /// [textScaler] pins the accessibility text scale for the whole subtree —
  /// the year grid's computed extent is only meaningful against a scale it
  /// did not choose (PF-7).
  Widget plannerApp(
    ProviderContainer container, {
    String locale = 'uk',
    TextScaler? textScaler,
  }) {
    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        locale: Locale(locale),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: bqTheme(),
        builder: (context, child) => textScaler == null
            ? child!
            : MediaQuery(
                data: MediaQuery.of(context).copyWith(textScaler: textScaler),
                child: child!,
              ),
        home: const PlannerScreen(),
      ),
    );
  }

  /// Finds every widget carrying a `ValueKey<String>` under [prefix].
  ///
  /// Painted primitives — gridlines, the today marker, bars, pips — have no
  /// distinguishing type of their own, so this codebase gives each a keyed
  /// container and finds it by key (the `week-dot` idiom).
  Finder byKeyPrefix(String prefix) => find.byWidgetPredicate((w) {
        final key = w.key;
        return key is ValueKey<String> && key.value.startsWith(prefix);
      });

  /// The Monday of bucket [index] in the currently-resolved Цикли model.
  ///
  /// Selections are keyed by DATE, never by position (WR-03), so a test that
  /// wants "the fourth column" has to ask the model which week that is — the
  /// same question the tapped column itself answers.
  DateTime bucketStart(ProviderContainer container, int index) {
    final model = switch (container.read(cyclesModelProvider)) {
      AsyncData(:final value) => value,
      _ => fail('the Цикли model has not resolved yet'),
    };
    return model.weeks[index].bucket.start;
  }

  void usePhoneSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Future<void> tearDownTree(
    WidgetTester tester,
    ProviderContainer container,
  ) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 10));
    container.dispose();
    await tester.pump(const Duration(milliseconds: 10));
    await tester.pump(const Duration(milliseconds: 10));
  }

  Future<void> pumpUntil(
    WidgetTester tester,
    bool Function() condition,
    String what,
  ) async {
    for (var i = 0; i < 200; i++) {
      await tester.pump(const Duration(milliseconds: 10));
      if (condition()) return;
    }
    fail('Timed out waiting for $what');
  }

  Regimen cyclic(String id, String supplementId, {bool paused = false}) =>
      Regimen(
        id: id,
        supplementId: supplementId,
        kind: RegimenKind.cyclic,
        startDate: DateTime.utc(2026, 8, 1),
        endDate: null,
        onDays: 14,
        offDays: 14,
        paused: paused,
        slots: const [
          DoseSlot(id: 'sl-x', minutesFromMidnight: 480, doseLabel: '1 капс.'),
        ],
      );

  /// Two regimen-bearing supplements (one of them paused) plus one fresh
  /// supplement with no regimen at all — so "one row per regimen-bearing
  /// entry" is a real filter, not a tautology.
  /// A one-time course, so the gantt hint's course branch has a real subject.
  final course = Regimen(
    id: 'r3',
    supplementId: 's3',
    kind: RegimenKind.course,
    startDate: DateTime.utc(2026, 8, 5),
    endDate: DateTime.utc(2026, 9, 30),
    onDays: 0,
    offDays: 0,
    paused: false,
    slots: const [
      DoseSlot(id: 'sl-z', minutesFromMidnight: 540, doseLabel: '1 крапля'),
    ],
  );

  /// Seeds one course per start date so the load chart lands a week in every
  /// band at a KNOWN bucket index.
  ///
  /// The window for the pinned 13 August clock runs 1 Aug – 30 Nov, and the
  /// Monday buckets covering it start on 27 July (DECIDED-3). So:
  /// bucket 0 = 27 Jul–2 Aug (nothing has started: load 0),
  /// bucket 1 = 3–9 Aug (load 3), bucket 2 = 10–16 Aug (load 4, and it
  /// contains today), bucket 3 = 17–23 Aug (load 7).
  Future<void> seedBands(
    ProviderContainer container, {
    List<int> startsOnAugust = const [5, 5, 5, 10, 17, 17, 17],
  }) async {
    final supplements = container.read(supplementRepoProvider);
    final regimens = container.read(regimenRepoProvider);
    for (var i = 0; i < startsOnAugust.length; i++) {
      await supplements.upsert(
        Supplement(
          id: 'b$i',
          name: 'Добавка $i',
          doseText: '1 капс.',
          colorValue: 0xFF6B6FA8,
          note: '',
        ),
      );
      await regimens.upsert(
        Regimen(
          id: 'br$i',
          supplementId: 'b$i',
          kind: RegimenKind.course,
          startDate: DateTime.utc(2026, 8, startsOnAugust[i]),
          endDate: DateTime.utc(2026, 11, 30),
          onDays: 0,
          offDays: 0,
          paused: false,
          slots: const [
            DoseSlot(
              id: 'bs',
              minutesFromMidnight: 480,
              doseLabel: '1 капс.',
            ),
          ],
        ),
      );
    }
  }

  Future<void> seed(
    ProviderContainer container, {
    bool courseForVitaminD = false,
  }) async {
    final supplements = container.read(supplementRepoProvider);
    await supplements.upsert(magnesium);
    await supplements.upsert(creatine);
    await supplements.upsert(vitaminD);
    final regimens = container.read(regimenRepoProvider);
    await regimens.upsert(cyclic('r1', 's1'));
    if (courseForVitaminD) await regimens.upsert(course);
    await regimens.upsert(
      Regimen(
        id: 'r2',
        supplementId: 's2',
        kind: RegimenKind.cyclic,
        startDate: DateTime.utc(2026, 8, 1),
        endDate: null,
        onDays: 28,
        offDays: 0,
        paused: true,
        slots: const [
          DoseSlot(id: 'sl-y', minutesFromMidnight: 600, doseLabel: '5 г'),
        ],
      ),
    );
  }

  testWidgets(
      'tapping the Calendar header\'s planner action opens the planner and '
      'draws one gantt row per regimen-bearing entry (DECIDED-1, DECIDED-7)',
      (tester) async {
    usePhoneSurface(tester);
    final container = makeContainer();
    await seed(container);

    await tester.pumpWidget(app(container));
    await pumpUntil(
      tester,
      () => find.text('Планувальник').evaluate().isNotEmpty,
      'the Calendar header entry action',
    );

    // Today's header is what is on screen before the tap.
    expect(find.text('Сьогодні'), findsOneWidget);

    await tester.tap(find.text('Планувальник'));
    await pumpUntil(
      tester,
      () => find.byType(GanttRowBar).evaluate().isNotEmpty,
      'the planner gantt rows',
    );

    expect(find.text('Планувальник'), findsOneWidget,
        reason: 'the planner titles itself with the same key the button used');
    expect(find.byType(GanttRowBar), findsNWidgets(2),
        reason: 'two regimens: one active, one paused — the supplement with '
            'no regimen at all draws no row (DECIDED-7)');
    // Scoped to the gantt: an active supplement's name also appears as a
    // week-detail name chip further down the same scroll body.
    Finder inGantt(String name) => find.descendant(
          of: find.byType(PlannerGantt),
          matching: find.text(name),
        );
    expect(inGantt('Магній бісглицинат'), findsOneWidget);
    expect(inGantt('Креатин моногідрат'), findsOneWidget,
        reason: 'a paused regimen keeps its row and shows a bare track');
    expect(find.text('Вітамін D3'), findsNothing);

    await tearDownTree(tester, container);
  });

  testWidgets('the planner\'s back control restores the Today header',
      (tester) async {
    usePhoneSurface(tester);
    final container = makeContainer();
    await seed(container);

    await tester.pumpWidget(app(container));
    await pumpUntil(
      tester,
      () => find.text('Планувальник').evaluate().isNotEmpty,
      'the Calendar header entry action',
    );
    await tester.tap(find.text('Планувальник'));
    await pumpUntil(
      tester,
      () => find.byType(GanttRowBar).evaluate().isNotEmpty,
      'the planner gantt rows',
    );

    // The back control carries the reused `backToToday` copy behind a "‹".
    await tester.tap(find.text('‹ Сьогодні'));
    await pumpUntil(
      tester,
      () => find.byType(GanttRowBar).evaluate().isEmpty,
      'the Today page to come back',
    );

    expect(find.text('Сьогодні'), findsWidgets,
        reason: 'the Today header is back');
    expect(find.byType(GanttRowBar), findsNothing);

    await tearDownTree(tester, container);
  });

  testWidgets('opening the planner writes no IntakeLog row through the UI '
      '(PF-2 / WR-06)', (tester) async {
    usePhoneSurface(tester);
    final container = makeContainer();
    await seed(container);

    await tester.pumpWidget(app(container));
    await pumpUntil(
      tester,
      () => find.text('Планувальник').evaluate().isNotEmpty,
      'the Calendar header entry action',
    );

    // The Today page materializes its own day and the current week — that is
    // Phase 3's bounded, intentional write. Whatever it produced is the
    // baseline the planner must not move.
    var before = 0;
    // Cancelled in-body, never via addTearDown: a Drift subscription's
    // `cancel()` does not settle once the database is closed, so an AWAITED
    // teardown cancel hangs the test until flutter_test's 10-minute timeout.
    final beforeSub = (db.select(db.intakeLogs)).watch().listen((rows) {
      before = rows.length;
    });
    await pumpUntil(tester, () => before > 0, 'the Today page to materialize');
    final baseline = before;

    await tester.tap(find.text('Планувальник'));
    await pumpUntil(
      tester,
      () => find.byType(GanttRowBar).evaluate().isNotEmpty,
      'the planner gantt rows',
    );
    // Give any stray materialization a generous chance to land.
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 10));
    }

    expect(before, baseline,
        reason: 'reaching the planner through the real tap path created no '
            'IntakeLog row (PF-2 / WR-06)');

    beforeSub.cancel();
    await tearDownTree(tester, container);
  });

  // ---------------------------------------------------------------------
  // The shell (plan 04-02, UI-SPEC S6 / S6c, DECIDED-8, Interaction
  // Contracts 1, 2 and 5).
  // ---------------------------------------------------------------------

  /// ONE finder, asserted once per segment — which is what makes DECIDED-8
  /// ("both segments close with the SAME key") the thing actually proven,
  /// rather than two segments each carrying some disclaimer or other.
  final disclaimer = find.text(
    'Межа в 5 речовин — наше редакційне правило для зручності відстеження, '
    'а не медичний норматив. Освітній матеріал, не медична порада.',
  );
  final emptyTitle = find.text('Планувати ще нічого');
  final loadError =
      find.text('Не вдалося завантажити планувальник. Спробуйте ще раз.');

  Future<void> openPlanner(
    WidgetTester tester,
    ProviderContainer container, {
    String locale = 'uk',
    TextScaler? textScaler,
  }) async {
    await tester.pumpWidget(
      plannerApp(container, locale: locale, textScaler: textScaler),
    );
    // The Цикли body is now four cards deep, so anything below the chart
    // lives outside the viewport until the body is scrolled.
    await pumpUntil(
      tester,
      () => find.byType(BqSegmented).evaluate().isNotEmpty,
      'the planner header',
    );
  }

  /// Drags the planner's scroll body up by [dy] logical pixels.
  ///
  /// A `ListView` only builds what its viewport (plus cache extent) covers, so
  /// the closing disclaimer and the week-detail card have to be scrolled into
  /// range before a finder can see them.
  Future<void> scrollBody(WidgetTester tester, double dy) async {
    await tester.drag(find.byType(ListView), Offset(0, -dy));
    await tester.pump();
  }

  // ---------------------------------------------------------------------
  // System back (UI-SPEC S6 truth #18: "system back from the planner returns
  // to Today rather than leaving the tab").
  //
  // These are the only tests in the suite that mount the REAL [AppShell]:
  // truth #18 is a claim about the nav bar and the route stack, and neither
  // exists when `CalendarScreen` is pumped as a bare `home`. The back itself
  // is driven down the actual platform channel a hardware/gesture back
  // arrives on, so the assertion covers the whole path — engine message ->
  // `WidgetsBinding.handlePopRoute` -> `WidgetsApp.didPopRoute` ->
  // `Navigator.maybePop` -> the screen's `PopScope` — rather than calling
  // the callback by hand, which would prove nothing about who invokes it.
  // ---------------------------------------------------------------------

  group('system back', () {
    /// The real three-tab shell — nav bar, `IndexedStack` and all.
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

    /// Every method call the app makes on `SystemChannels.platform`.
    ///
    /// `SystemNavigator.pop()` — "close the app" — travels this channel, and
    /// it is the ONLY observable difference between a back the screen
    /// consumed and a back that fell through to the platform. Asserting on
    /// the widget tree alone cannot tell those apart, because a real app
    /// exit leaves the tree exactly as it was.
    List<MethodCall> recordPlatformCalls(WidgetTester tester) {
      final calls = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          calls.add(call);
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null),
      );
      return calls;
    }

    /// Delivers the engine's `popRoute` notification on
    /// `SystemChannels.navigation` — an Android hardware/gesture back, or an
    /// iOS back, as the framework actually receives it.
    Future<void> systemBack(WidgetTester tester) async {
      final message = const JSONMethodCodec().encodeMethodCall(
        const MethodCall('popRoute'),
      );
      await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
        SystemChannels.navigation.name,
        message,
        (_) {},
      );
      await tester.pump();
    }

    /// Opens the Calendar tab of the real shell and waits for the Today page.
    Future<void> openCalendarTab(
      WidgetTester tester,
      ProviderContainer container,
    ) async {
      await tester.pumpWidget(shellApp(container));
      await pumpUntil(
        tester,
        () => find.text('Календар').evaluate().isNotEmpty,
        'the shell nav bar',
      );
      await tester.tap(find.text('Календар'));
      await pumpUntil(
        tester,
        () => find.text('Планувальник').evaluate().isNotEmpty,
        'the Calendar header entry action',
      );
    }

    // Plan 06-01: the shell's bar is the hand-built [BqNavBar]; the claim
    // this reads is unchanged — WHICH TAB the shell reports as selected.
    int selectedTab(WidgetTester tester) =>
        tester.widget<BqNavBar>(find.byType(BqNavBar)).selectedIndex;

    testWidgets('a system back with the planner open returns to Today and '
        'never leaves the Calendar tab (UI-SPEC truth #18)', (tester) async {
      usePhoneSurface(tester);
      final container = makeContainer();
      await seed(container);
      final platformCalls = recordPlatformCalls(tester);

      await openCalendarTab(tester, container);
      await tester.tap(find.text('Планувальник'));
      await pumpUntil(
        tester,
        () => find.byType(GanttRowBar).evaluate().isNotEmpty,
        'the planner gantt rows',
      );
      expect(find.byType(PlannerScreen), findsOneWidget);
      expect(selectedTab(tester), 1,
          reason: 'the planner lives UNDER Calendar — opening it never moves '
              'the nav bar selection');

      // Cleared here so the assertion below is about the back gesture only,
      // not about anything the app said to the platform while starting up.
      platformCalls.clear();
      await systemBack(tester);
      await pumpUntil(
        tester,
        () => find.byType(PlannerScreen).evaluate().isEmpty,
        'the Today page to come back',
      );

      // 1. Back on Today: a Today-only element is present, and every
      //    planner-only element is gone from the tree rather than covered.
      expect(find.text('Сьогодні'), findsWidgets,
          reason: 'the Today header is back');
      expect(find.byType(WeekStrip), findsOneWidget,
          reason: 'the week strip belongs to the Today page alone');
      expect(find.byType(GanttRowBar), findsNothing);
      expect(find.byType(BqSegmented), findsNothing,
          reason: 'the Цикли/Рік control is a planner-only affordance');

      // 2. Still inside the tab, and the app was never asked to close: the
      //    PopScope consumed the back instead of letting it bubble.
      expect(selectedTab(tester), 1,
          reason: 'system back returned to Today WITHIN the Calendar tab — it '
              'did not fall back to another destination');
      expect(find.text('Мій стек'), findsNothing,
          reason: 'nor did it surface the Stack tab underneath');
      expect(
        platformCalls.where((call) => call.method == 'SystemNavigator.pop'),
        isEmpty,
        reason: 'a back the screen did NOT consume ends in '
            'SystemNavigator.pop — closing the app. The PopScope must swallow '
            'this one, which is exactly the half of truth #18 ("rather than '
            'leaving the tab") that a widget-tree assertion cannot see: an '
            'app exit leaves the tree looking identical.',
      );
      expect(tester.takeException(), isNull);

      await tearDownTree(tester, container);
    });

    testWidgets('a second system back, now on Today, is NOT swallowed — it '
        'bubbles to the platform, so the interception is scoped to the '
        'planner and never traps the user', (tester) async {
      usePhoneSurface(tester);
      final container = makeContainer();
      await seed(container);
      final platformCalls = recordPlatformCalls(tester);

      await openCalendarTab(tester, container);
      await tester.tap(find.text('Планувальник'));
      await pumpUntil(
        tester,
        () => find.byType(GanttRowBar).evaluate().isNotEmpty,
        'the planner gantt rows',
      );
      await systemBack(tester);
      await pumpUntil(
        tester,
        () => find.byType(PlannerScreen).evaluate().isEmpty,
        'the Today page to come back',
      );

      platformCalls.clear();
      await systemBack(tester);
      await pumpUntil(
        tester,
        () => platformCalls.any((c) => c.method == 'SystemNavigator.pop'),
        'the back on Today to reach the platform',
      );

      // The Today page mounts no PopScope, so back leaves the app exactly as
      // it does from any single-screen Android app. That is the correct
      // contract: `canPop: false` is conditional on the planner being open,
      // so consuming a back the app has nowhere to spend would strand the
      // user on Today with a dead back button.
      expect(
        platformCalls.map((call) => call.method),
        contains('SystemNavigator.pop'),
        reason: 'back from the app\'s root page is an exit, not a no-op',
      );
      expect(selectedTab(tester), 1,
          reason: 'and the tab selection is untouched by a back the app '
              'declined to handle');
      expect(find.byType(PlannerScreen), findsNothing,
          reason: 'back on Today never re-opens the planner');
      expect(tester.takeException(), isNull);

      await tearDownTree(tester, container);
    });
  });

  group('planner shell', () {
    testWidgets('Цикли is the default segment; the subtitle and the body '
        'switch with it, instantly and both ways (S6, Interaction Contract 2)',
        (tester) async {
      usePhoneSurface(tester);
      final container = makeContainer();
      await seed(container);
      await openPlanner(tester, container);
      await pumpUntil(
        tester,
        () => find.byType(GanttRowBar).evaluate().isNotEmpty,
        'the gantt rows',
      );

      // Both segment labels always render (UI-SPEC truth #18).
      expect(find.text('Цикли'), findsOneWidget);
      expect(find.text('Рік'), findsOneWidget);
      // The window subtitle, pinned exactly: uk standalone (nominative) month
      // names for the Aug-Nov window around the pinned clock (PF-4).
      expect(find.text('серпень — листопад 2026'), findsOneWidget);
      expect(find.byType(GanttRowBar), findsWidgets,
          reason: 'Цикли is the default segment (index 1)');

      await tester.tap(find.text('Рік'));
      await tester.pump();

      expect(find.text('2026 · 12 місяців'), findsOneWidget,
          reason: 'the Рік subtitle names the year and a pre-formatted month '
              'count');
      expect(find.text('серпень — листопад 2026'), findsNothing);
      expect(find.byType(GanttRowBar), findsNothing,
          reason: 'the Цикли body is gone, not merely covered');

      await tester.tap(find.text('Цикли'));
      await tester.pump();

      expect(find.text('серпень — листопад 2026'), findsOneWidget);
      expect(find.byType(GanttRowBar), findsWidgets);

      await tearDownTree(tester, container);
    });

    testWidgets('a window crossing 31 December renders the cross-year '
        'subtitle with BOTH years (E-8)', (tester) async {
      usePhoneSurface(tester);
      final container = makeContainer(clock: DateTime.utc(2026, 10, 15));
      await seed(container);
      await openPlanner(tester, container);

      expect(find.text('жовтень 2026 — січень 2027'), findsOneWidget);
      // The Рік matrix stays on today's year while the window has already
      // crossed into the next one (DECIDED-9).
      await tester.tap(find.text('Рік'));
      await tester.pump();
      expect(find.text('2026 · 12 місяців'), findsOneWidget);

      await tearDownTree(tester, container);
    });

    testWidgets('the disclaimer closes BOTH segments — the same key, one '
        'finder (DECIDED-8, PLAN-04)', (tester) async {
      usePhoneSurface(tester);
      final container = makeContainer();
      await seed(container);
      await openPlanner(tester, container);
      await pumpUntil(
        tester,
        () => find.byType(GanttRowBar).evaluate().isNotEmpty,
        'the gantt rows',
      );
      // Цикли is four cards deep now; its closing line sits below the fold.
      await scrollBody(tester, 500);

      expect(disclaimer, findsOneWidget, reason: 'Цикли closes with it');

      await tester.tap(find.text('Рік'));
      await tester.pump();
      // Рік is five elements deep too — chip, grid, legend, detail, footnote —
      // so its closing line also sits below the fold.
      await scrollBody(tester, 500);

      expect(disclaimer, findsOneWidget, reason: 'Рік closes with it too');
      expect(
        find.text('Рік показує, як цикли накладаються один на одний. '
            'Червоне число в місяці означає перевищення нашої межі у '
            '5 речовин одночасно.'),
        findsOneWidget,
        reason: 'the year footnote renders ABOVE the disclaimer, never '
            'instead of it (M9)',
      );

      await tearDownTree(tester, container);
    });

    testWidgets('an empty stack renders the empty block with the '
        'no-supplements body on both segments, and still the disclaimer '
        '(S6c, PLAN-04 is unconditional)', (tester) async {
      usePhoneSurface(tester);
      final container = makeContainer();
      await openPlanner(tester, container);
      await pumpUntil(
        tester,
        () => emptyTitle.evaluate().isNotEmpty,
        'the empty planner block',
      );

      expect(
        find.text('Додайте добавку у вкладці «Стек» — її цикли '
            'з\'являться тут.'),
        findsOneWidget,
      );
      expect(find.byType(GanttRowBar), findsNothing);
      expect(disclaimer, findsOneWidget);

      await tester.tap(find.text('Рік'));
      await tester.pump();

      expect(emptyTitle, findsOneWidget);
      expect(disclaimer, findsOneWidget);

      await tearDownTree(tester, container);
    });

    testWidgets('supplements that all lack a regimen render the OTHER empty '
        'body — a user who owns supplements is never told to add one '
        '(DECIDED-7)', (tester) async {
      usePhoneSurface(tester);
      final container = makeContainer();
      final supplements = container.read(supplementRepoProvider);
      await supplements.upsert(magnesium);
      await supplements.upsert(creatine);

      await openPlanner(tester, container);
      await pumpUntil(
        tester,
        () => emptyTitle.evaluate().isNotEmpty,
        'the empty planner block',
      );

      expect(
        find.text('У ваших добавок ще немає розкладу. Відкрийте добавку у '
            'вкладці «Стек», щоб задати цикл.'),
        findsOneWidget,
      );
      expect(
        find.text('Додайте добавку у вкладці «Стек» — її цикли '
            'з\'являться тут.'),
        findsNothing,
      );
      expect(disclaimer, findsOneWidget);

      await tearDownTree(tester, container);
    });

    testWidgets('a failing stack stream renders the designed error copy plus '
        'retry, and never the exception (S6c, T-04-09)', (tester) async {
      usePhoneSurface(tester);
      final container = makeContainer(
        stackState: AsyncError(
          Exception('boom-from-drift'),
          StackTrace.empty,
        ),
      );
      await openPlanner(tester, container);

      expect(loadError, findsOneWidget);
      expect(find.text('Повторити'), findsOneWidget);
      expect(find.textContaining('boom-from-drift'), findsNothing,
          reason: 'raw exception text never enters the widget tree');
      expect(find.textContaining('Exception'), findsNothing);
      expect(disclaimer, findsOneWidget,
          reason: 'PLAN-04 is unconditional — it closes the error surface too');

      await tester.tap(find.text('Рік'));
      await tester.pump();

      expect(loadError, findsOneWidget);
      expect(disclaimer, findsOneWidget);

      await tearDownTree(tester, container);
    });

    testWidgets('tapping retry re-subscribes the streams that actually failed, '
        'and the planner recovers (S6c, CR-02)', (tester) async {
      usePhoneSurface(tester);
      // The error is seeded on the STREAM the planner's derivation reads, not
      // on the derivation itself — which is the whole point of the finding:
      // `stackEntriesProvider` is a plain Provider with no subscription of its
      // own, so invalidating IT re-runs its body against the same errored
      // streams and the surface can never recover. Riverpod invalidation
      // propagates to dependents, never to dependencies.
      var attempt = 0;
      final container = ProviderContainer(
        // Riverpod 3 retries a failed provider on its own backoff schedule and
        // reports the interim state as loading-carrying-an-error, which the
        // planner renders as its blank loading surface. Retries are disabled
        // here so the error surface — the thing under test — is reached
        // deterministically and the recovery is the BUTTON'S doing, never a
        // background timer's.
        retry: (retryCount, error) => null,
        overrides: [
          todayProvider.overrideWith(() => _FixedToday(today)),
          nowMinutesProvider.overrideWith((ref) => Stream.value(600)),
          supplementsStreamProvider.overrideWith((ref) {
            attempt += 1;
            return attempt == 1
                ? Stream<List<Supplement>>.error(
                    Exception('boom-from-drift'),
                    StackTrace.empty,
                  )
                : Stream.value(const [magnesium]);
          }),
          regimensStreamProvider.overrideWith(
            (ref) => Stream.value([cyclic('r1', 's1')]),
          ),
        ],
      );

      await openPlanner(tester, container);
      await pumpUntil(
        tester,
        () => loadError.evaluate().isNotEmpty,
        'the planner error surface',
      );
      expect(find.text('Повторити'), findsOneWidget);

      await tester.tap(find.text('Повторити'));
      await pumpUntil(
        tester,
        () => find.byType(GanttRowBar).evaluate().isNotEmpty,
        'the planner to recover after retry',
      );

      expect(attempt, 2,
          reason: 'the failing stream provider was rebuilt — a retry that '
              'invalidates only the derived provider never re-subscribes it');
      expect(loadError, findsNothing,
          reason: 'the error surface is replaced by real content, so the '
              'control the screen offers is one that can actually recover');
      expect(find.text('Магній бісглицинат'), findsWidgets,
          reason: 'the recovered stack is really rendered — the gantt row and '
              'the week detail both name it');
      expect(tester.takeException(), isNull);

      await tearDownTree(tester, container);
    });

    // -------------------------------------------------------------------
    // The error surface under LIVE retry (plan 05-02, UI-SPEC A1 / P-9).
    // -------------------------------------------------------------------

    /// The consequence of a red case, named in device terms rather than as a
    /// restatement of the assertion.
    const blankBodyReason =
        'a user whose local database fails sees an EMPTY planner body for the '
        "whole of Riverpod's ~38.2s default backoff — no copy, no retry, "
        'nothing to act on — because Riverpod reports a retrying failure as an '
        'AsyncLoading that CARRIES the error and the loading surface wins. The '
        'fix is the rendering rule at the surface, never a disabled retry';

    for (final locale in const ['uk', 'en']) {
      final errorCopy = locale == 'uk'
          ? 'Не вдалося завантажити планувальник. Спробуйте ще раз.'
          : "Couldn't load the planner. Try again.";
      final retryLabel = locale == 'uk' ? 'Повторити' : 'Retry';

      testWidgets(
          '$locale: a failing stack stream shows the planner error copy plus '
          "retry on the FIRST frame, not after Riverpod's ~38s backoff "
          '(A1 / P-9)', (tester) async {
        usePhoneSurface(tester);
        // NOTE: this container deliberately supplies NO `retry:` override.
        // The ABSENCE of it is the whole point — the neighbouring CR-02
        // recovery test above disables retry on purpose (it is asking whether
        // the BUTTON recovers), and that is exactly why it passed all through
        // Phase 4 without catching this. Copying its `retry:` line down here
        // would silently restore the blind spot.
        //
        // The failure is seeded on the STREAM that actually fails, not on the
        // derived `stackEntriesProvider` (the named-recovery-path rule,
        // CR-02): pinning the derivation to a fixed AsyncError would bypass
        // the retry state under test entirely.
        final container = ProviderContainer(
          overrides: [
            todayProvider.overrideWith(() => _FixedToday(today)),
            nowMinutesProvider.overrideWith((ref) => Stream.value(600)),
            supplementsStreamProvider.overrideWith(
              (ref) => Stream<List<Supplement>>.error(
                Exception('boom-from-drift'),
                StackTrace.empty,
              ),
            ),
            regimensStreamProvider.overrideWith(
              (ref) => Stream.value([cyclic('r1', 's1')]),
            ),
          ],
        );

        await tester.pumpWidget(plannerApp(container, locale: locale));
        // ONE frame. Never pumpAndSettle: with the retry timers live it would
        // either time out or wait out the backoff and pass for the wrong
        // reason (PF-7).
        await tester.pump();

        expect(find.text(errorCopy), findsOneWidget, reason: blankBodyReason);
        expect(find.text(retryLabel), findsOneWidget,
            reason: 'the error copy without its recovery control is a dead '
                'end');
        expect(find.textContaining('boom-from-drift'), findsNothing,
            reason: 'raw exception text never enters the widget tree '
                '(T-05-03)');
        expect(find.textContaining('Exception'), findsNothing,
            reason: 'nor does the exception type name (T-05-03)');
        expect(tester.takeException(), isNull);

        await tearDownTree(tester, container);
      });
    }

    testWidgets('while the stack is loading the header and segmented control '
        'render over an empty body with NO spinner (S6c)', (tester) async {
      usePhoneSurface(tester);
      final container = makeContainer(
        stackState: const AsyncLoading(),
      );
      await openPlanner(tester, container);

      expect(find.text('Планувальник'), findsOneWidget);
      expect(find.byType(BqSegmented), findsOneWidget);
      expect(find.text('серпень — листопад 2026'), findsOneWidget,
          reason: 'the subtitle is clock-derived and never waits on the stack');
      expect(find.byType(CircularProgressIndicator), findsNothing,
          reason: 'a local-DB stream resolves within a frame; a spinner would '
              'only flash');
      expect(find.byType(GanttRowBar), findsNothing);
      expect(emptyTitle, findsNothing,
          reason: 'until the stack resolves the planner assumes it has '
              'entries — the empty block must never flash on the way to data');

      await tearDownTree(tester, container);
    });

    testWidgets('a week selected on Цикли survives a switch to Рік and back '
        '(Interaction Contract 2)', (tester) async {
      usePhoneSurface(tester);
      final container = makeContainer();
      await seed(container);
      // Riverpod 3 pauses providers nobody listens to; this subscription is
      // what keeps the screen-scoped selection alive for the assertion, and
      // stands in for the week column plan 04-03 will add.
      final sub = container.listen(resolvedWeekIndexProvider, (_, _) {});
      addTearDown(sub.close);

      await openPlanner(tester, container);
      await pumpUntil(
        tester,
        () => find.byType(GanttRowBar).evaluate().isNotEmpty,
        'the gantt rows',
      );

      container
          .read(selectedWeekProvider.notifier)
          .select(bucketStart(container, 3));
      await tester.pump();
      expect(container.read(resolvedWeekIndexProvider), 3);

      await tester.tap(find.text('Рік'));
      await tester.pump();
      await tester.tap(find.text('Цикли'));
      await tester.pump();

      expect(container.read(resolvedWeekIndexProvider), 3,
          reason: 'the segment index chooses which body builds and nothing '
              'else — selection state lives in its own provider');

      await tearDownTree(tester, container);
    });
  });

  // ---------------------------------------------------------------------
  // The gantt row hint (plan 04-02 task 3, M13).
  // ---------------------------------------------------------------------

  group('gantt row hint', () {
    testWidgets('reads the Stack card\'s own schedule description, minus the '
        'daily-slot tail (M13)', (tester) async {
      usePhoneSurface(tester);
      final container = makeContainer();
      await seed(container, courseForVitaminD: true);
      await openPlanner(tester, container);
      await pumpUntil(
        tester,
        () => find.byType(GanttRowBar).evaluate().isNotEmpty,
        'the gantt rows',
      );

      // Cyclic with a break: the same "on / off" composition the Stack chip
      // renders, in the same words.
      expect(find.text('2 тижні / 2 тижні'), findsOneWidget);
      // Cyclic with no break: the no-break wording, never "0 тижнів".
      expect(find.text('4 тижні / без перерви'), findsOneWidget);
      expect(find.textContaining('0 тижнів'), findsNothing);
      // Course: the locale-formatted inclusive range.
      final range = DateFormat.yMd('uk');
      expect(
        find.text('${range.format(DateTime.utc(2026, 8, 5))} – '
            '${range.format(DateTime.utc(2026, 9, 30))}'),
        findsOneWidget,
      );
      // The planner is about time, not daily doses: the slot tail the Stack
      // card appends is absent from every hint.
      expect(find.textContaining('раз на день'), findsNothing);
      expect(find.textContaining('рази на день'), findsNothing);

      await tearDownTree(tester, container);
    });

    testWidgets('each row speaks its name, its schedule and its run count — '
        'the painted bands are invisible to assistive tech', (tester) async {
      usePhoneSurface(tester);
      final handle = tester.ensureSemantics();
      final container = makeContainer();
      await seed(container);
      await openPlanner(tester, container);
      await pumpUntil(
        tester,
        () => find.byType(GanttRowBar).evaluate().isNotEmpty,
        'the gantt rows',
      );

      final label = tester.getSemantics(find.byType(GanttRowBar).first).label;
      expect(label, startsWith('Магній бісглицинат, 2 тижні / 2 тижні, '),
          reason: 'name, then the shared schedule description');
      expect(label, endsWith('періодів'),
          reason: 'closing with a pre-formatted periodsCount — the count of '
              'painted runs is the information the canvas carries');

      // A paused regimen paints a BARE TRACK and the legend turns that into
      // one word — both purely visual (DECIDED-7). The row therefore says the
      // state instead of counting periods: "0 періодів" cannot distinguish a
      // paused supplement from one that is merely off-cycle all window, or
      // from one that starts next year (WR-01).
      final paused = tester.getSemantics(find.byType(GanttRowBar).at(1)).label;
      expect(paused, 'Креатин моногідрат, 4 тижні / без перерви, пауза',
          reason: 'the word is the legend\'s own legendPaused key, so the '
              'PLAN-04 gate stays authoritative over ONE vocabulary for this '
              'state');
      expect(paused, isNot(contains('періодів')),
          reason: 'a period count on a row that paints nothing is the claim '
              'this label exists to stop making');

      handle.dispose();
      await tearDownTree(tester, container);
    });

    testWidgets('a paused supplement is named as paused on the Рік legend '
        'too — the only place that segment names it at all (WR-01)',
        (tester) async {
      usePhoneSurface(tester);
      final handle = tester.ensureSemantics();
      final container = makeContainer();
      await seed(container);
      await openPlanner(tester, container);
      await tester.tap(find.text('Рік'));
      await tester.pump();
      await pumpUntil(
        tester,
        () => byKeyPrefix('year-legend-entry-').evaluate().isNotEmpty,
        'the year legend',
      );

      // The legend is one merged semantics node — the entries are read as one
      // run of text — so the assertion is about what that node SAYS, entry by
      // entry, not about a node per entry.
      final legend = tester
          .getSemantics(find.byKey(
            const ValueKey<String>('year-legend-entry-s2'),
          ))
          .label;
      expect(legend, contains('Креатин моногідрат, пауза'),
          reason: 'every coverage bar of a paused supplement is zero-width and '
              'therefore silent, so without this the Рік segment offers a '
              'name with nothing behind it and no reason why');
      // The active supplement's entry is untouched: no wrapper, no second
      // vocabulary, just the name the legend already read out.
      expect(legend, contains('Магній бісглицинат\n'),
          reason: 'an ACTIVE entry keeps exactly the node it had — the clause '
              'marks the exception, never every row');

      handle.dispose();
      await tearDownTree(tester, container);
    });
  });

  // ---------------------------------------------------------------------
  // The gantt chrome (plan 04-03 task 1, UI-SPEC S6a item 2, P-4/P-8,
  // PF-3, M1, Interaction Contract 12).
  // ---------------------------------------------------------------------

  group('gantt chrome', () {
    testWidgets('four standalone uk month abbreviations render in window '
        'order, uppercased (PF-4)', (tester) async {
      usePhoneSurface(tester);
      final container = makeContainer();
      await seed(container);
      await openPlanner(tester, container);
      await pumpUntil(
        tester,
        () => find.byType(GanttRowBar).evaluate().isNotEmpty,
        'the gantt rows',
      );

      // The Aug-Nov window around the pinned clock, in the STANDALONE
      // (nominative) abbreviated forms — `LLL`, never `MMM` and never a table.
      expect(find.text('СЕРП.'), findsOneWidget);
      expect(find.text('ВЕР.'), findsOneWidget);
      expect(find.text('ЖОВТ.'), findsOneWidget);
      expect(find.text('ЛИСТ.'), findsOneWidget);
      expect(byKeyPrefix('gantt-month-'), findsNWidgets(4));

      // Window order, read off the keyed slots rather than the tree order.
      for (final (index, label) in <(int, String)>[
        (0, 'СЕРП.'),
        (1, 'ВЕР.'),
        (2, 'ЖОВТ.'),
        (3, 'ЛИСТ.'),
      ]) {
        expect(
          tester.widget<Text>(find.byKey(ValueKey('gantt-month-$index'))).data,
          label,
        );
      }

      await tearDownTree(tester, container);
    });

    testWidgets('month columns are sized to REAL day counts — a 31-day month '
        'is wider than a 30-day one (PF-3, T-04-11)', (tester) async {
      usePhoneSurface(tester);
      final container = makeContainer();
      await seed(container);
      await openPlanner(tester, container);
      await pumpUntil(
        tester,
        () => find.byType(GanttRowBar).evaluate().isNotEmpty,
        'the gantt rows',
      );

      final august =
          tester.getSize(find.byKey(const ValueKey('gantt-month-0'))).width;
      final september =
          tester.getSize(find.byKey(const ValueKey('gantt-month-1'))).width;
      final october =
          tester.getSize(find.byKey(const ValueKey('gantt-month-2'))).width;

      expect(august, greaterThan(september),
          reason: 'August has 31 days and September 30 — fixed quarter '
              'columns would make these equal');
      expect(october, closeTo(august, 0.01),
          reason: 'October is also 31 days');

      await tearDownTree(tester, container);
    });

    testWidgets('three gridlines sit at the interior month boundaries and '
        'exactly one today marker renders (P-4)', (tester) async {
      usePhoneSurface(tester);
      final container = makeContainer();
      await seed(container);
      await openPlanner(tester, container);
      await pumpUntil(
        tester,
        () => find.byType(GanttRowBar).evaluate().isNotEmpty,
        'the gantt rows',
      );

      expect(byKeyPrefix('gantt-gridline-'), findsNWidgets(3),
          reason: 'a four-month window has three interior boundaries');
      expect(find.byKey(const ValueKey('gantt-today-marker')), findsOneWidget,
          reason: 'today is inside the window by construction, so the marker '
              'always renders — there is no absent branch');

      // The boundaries sit at the cumulative REAL day fractions of a 122-day
      // window — 31/122, 61/122, 92/122 — never at 0.25 / 0.50 / 0.75.
      final track = tester.getRect(find.byType(GanttRowBar).first);
      double fractionOf(int i) =>
          (tester.getRect(byKeyPrefix('gantt-gridline-').at(i)).left -
              track.left) /
          track.width;
      expect(fractionOf(0), closeTo(31 / 122, 0.002));
      expect(fractionOf(1), closeTo(61 / 122, 0.002));
      expect(fractionOf(2), closeTo(92 / 122, 0.002));
      // 31/122 is 0.2541, not 0.25 — the middle boundary happens to land on
      // 0.5 for THIS window (31 + 30 = 61 of 122), which is exactly why the
      // outer two are the ones that prove the columns are not quarters.
      expect(fractionOf(0), isNot(closeTo(0.25, 0.002)));
      expect(fractionOf(2), isNot(closeTo(0.75, 0.002)));

      // (todayIndex + 0.5) / span for the pinned 13 August clock.
      final marker = tester.getRect(find.byKey(const ValueKey(
        'gantt-today-marker',
      )));
      expect((marker.left - track.left) / track.width,
          closeTo(12.5 / 122, 0.002));
      expect(marker.height, greaterThan(0),
          reason: 'the rules span the full height of the row stack');

      await tearDownTree(tester, container);
    });

    testWidgets('the legend renders exactly three entries in BOTH locales — '
        'the mockup\'s interaction entry does not ship (M1)', (tester) async {
      usePhoneSurface(tester);
      final container = makeContainer();
      await seed(container);
      await openPlanner(tester, container);
      await pumpUntil(
        tester,
        () => find.byType(GanttRowBar).evaluate().isNotEmpty,
        'the gantt rows',
      );

      expect(byKeyPrefix('gantt-legend-'), findsNWidgets(3));
      expect(find.text('приймаю'), findsOneWidget);
      expect(find.text('заплановано'), findsOneWidget);
      expect(find.text('пауза'), findsOneWidget);
      expect(find.text('є взаємодія'), findsNothing,
          reason: 'an interaction claim this product does not make');

      await tearDownTree(tester, container);
    });

    testWidgets('the legend still renders exactly three entries in en',
        (tester) async {
      usePhoneSurface(tester);
      final container = makeContainer();
      await seed(container);
      await openPlanner(tester, container, locale: 'en');
      await pumpUntil(
        tester,
        () => find.byType(GanttRowBar).evaluate().isNotEmpty,
        'the gantt rows',
      );

      expect(byKeyPrefix('gantt-legend-'), findsNWidgets(3));
      expect(find.text('taking'), findsOneWidget);
      expect(find.text('planned'), findsOneWidget);
      expect(find.text('paused'), findsOneWidget);
      expect(find.textContaining('interaction'), findsNothing);

      await tearDownTree(tester, container);
    });

    testWidgets('changing the selected week does not rebuild the gantt '
        '(Interaction Contract 12)', (tester) async {
      usePhoneSurface(tester);
      final container = makeContainer();
      await seed(container);
      final sub = container.listen(resolvedWeekIndexProvider, (_, _) {});
      addTearDown(sub.close);

      await openPlanner(tester, container);
      await pumpUntil(
        tester,
        () => find.byType(GanttRowBar).evaluate().isNotEmpty,
        'the gantt rows',
      );

      Finder painted() => find.descendant(
            of: find.byType(GanttRowBar).first,
            matching: find.byType(CustomPaint),
          );
      final before = tester.widget<CustomPaint>(painted());
      expect(
        find.descendant(
          of: find.byType(PlannerGantt),
          matching: find.byType(RepaintBoundary),
        ),
        findsWidgets,
        reason: 'the card is isolated behind its own boundary',
      );

      container
          .read(selectedWeekProvider.notifier)
          .select(bucketStart(container, 4));
      await tester.pump();
      expect(container.read(resolvedWeekIndexProvider), 4);

      expect(identical(tester.widget<CustomPaint>(painted()), before), isTrue,
          reason: 'the gantt subtree did not even rebuild, so it cannot have '
              'repainted — selection lives in a provider the gantt never '
              'watches');

      await tearDownTree(tester, container);
    });
  });

  // ---------------------------------------------------------------------
  // The concurrent-load chart (plan 04-03 task 2, UI-SPEC S6a item 3,
  // P-9, DECIDED-2/3/10, Interaction Contracts 3, 5, 11).
  // ---------------------------------------------------------------------

  group('load chart', () {
    Future<void> openBands(
      WidgetTester tester,
      ProviderContainer container, {
      List<int> startsOnAugust = const [5, 5, 5, 10, 17, 17, 17],
    }) async {
      await seedBands(container, startsOnAugust: startsOnAugust);
      await openPlanner(tester, container);
      await pumpUntil(
        tester,
        () => byKeyPrefix('load-week-').evaluate().isNotEmpty,
        'the load chart columns',
      );
    }

    Color? fillOf(WidgetTester tester, String key) {
      final box = tester.widget<Container>(find.byKey(ValueKey<String>(key)));
      return (box.decoration! as BoxDecoration).color;
    }

    testWidgets('one column per Monday week of the window — 18 or 19 of them '
        '(DECIDED-3)', (tester) async {
      usePhoneSurface(tester);
      final container = makeContainer();
      await openBands(tester, container);

      final model = container.read(cyclesModelProvider).value!;
      expect(byKeyPrefix('load-week-'), findsNWidgets(model.weeks.length));
      expect(model.weeks.length, anyOf(18, 19),
          reason: 'full Monday weeks covering a 120-123 day window');

      // The axis carries the ACTUAL bucket bounds, never the mockup's
      // hardcoded "1 серп" / "30 лис" (M6).
      expect(find.text('ОДНОЧАСНЕ НАВАНТАЖЕННЯ'), findsOneWidget);
      expect(find.text('по тижнях'), findsOneWidget);
      expect(find.text('межа 5 · комфорт 3'), findsOneWidget);
      final axis = DateFormat.MMMd('uk');
      expect(find.text(axis.format(model.weeks.first.bucket.start)),
          findsOneWidget);
      expect(find.text(axis.format(model.weeks.last.bucket.endInclusive)),
          findsOneWidget);
      expect(find.text('1 серп.'), findsNothing);

      await tearDownTree(tester, container);
    });

    testWidgets('every band draws its own bar: comfort, at the limit, and a '
        'capped main bar with a proportional over-bar (UI-SPEC banding)',
        (tester) async {
      usePhoneSurface(tester);
      final container = makeContainer();
      await openBands(tester, container);

      // Bucket 1 — load 3: the quiet comfort tone, round(3/5*38) = 23.
      expect(fillOf(tester, 'load-main-1'), BqColors.loadBar);
      expect(tester.getSize(find.byKey(const ValueKey('load-main-1'))).height,
          23);
      expect(find.byKey(const ValueKey('load-over-1')), findsNothing);

      // Bucket 2 — load 4: at our editorial limit, round(4/5*38) = 30.
      expect(fillOf(tester, 'load-main-2'), BqColors.warn);
      expect(tester.getSize(find.byKey(const ValueKey('load-main-2'))).height,
          30);

      // Bucket 3 — load 7: the main bar caps at 38 and the excess becomes a
      // proportional over-bar, round(2/5*38) = 15.
      expect(fillOf(tester, 'load-main-3'), BqColors.risk);
      expect(tester.getSize(find.byKey(const ValueKey('load-main-3'))).height,
          38);
      expect(fillOf(tester, 'load-over-3'), BqColors.risk);
      expect(tester.getSize(find.byKey(const ValueKey('load-over-3'))).height,
          15);

      await tearDownTree(tester, container);
    });

    testWidgets('a zero-load week draws the 2px stub and stays selectable '
        '(DECIDED-3, M8)', (tester) async {
      usePhoneSurface(tester);
      final container = makeContainer();
      await openBands(tester, container);

      expect(fillOf(tester, 'load-stub-0'), BqColors.field);
      expect(tester.getSize(find.byKey(const ValueKey('load-stub-0'))).height,
          2);
      expect(find.byKey(const ValueKey('load-main-0')), findsNothing,
          reason: 'the stub stands IN PLACE of a zero-height bar');

      expect(container.read(resolvedWeekIndexProvider), 2,
          reason: 'the default follows the bucket containing today');
      await tester.tap(find.byKey(const ValueKey('load-week-0')));
      await tester.pump();
      expect(container.read(resolvedWeekIndexProvider), 0);

      await tearDownTree(tester, container);
    });

    testWidgets('the WHOLE column is the tap target — a hit well above a '
        'short bar still selects the week (DECIDED-10)', (tester) async {
      usePhoneSurface(tester);
      final container = makeContainer();
      await openBands(tester, container);

      final column = tester.getRect(find.byKey(const ValueKey('load-week-5')));
      expect(column.height, greaterThanOrEqualTo(53),
          reason: 'a ~15px wide column earns its target from its HEIGHT');

      // Two pixels below the column's top edge is empty space above every bar
      // in this chart — the bar itself is at most 38px of a 53px column.
      await tester.tapAt(Offset(column.center.dx, column.top + 2));
      await tester.pump();

      expect(container.read(resolvedWeekIndexProvider), 5);

      await tearDownTree(tester, container);
    });

    testWidgets('the selected column is opaque and every other is half '
        '(Interaction Contract 3)', (tester) async {
      usePhoneSurface(tester);
      final container = makeContainer();
      await openBands(tester, container);

      double opacityOf(int i) => tester
          .widget<Opacity>(
            find
                .ancestor(
                  of: find.byKey(ValueKey<String>('load-week-$i')),
                  matching: find.byType(Opacity),
                )
                .first,
          )
          .opacity;

      expect(opacityOf(2), 1.0, reason: 'today\'s week is the default');
      expect(opacityOf(3), 0.5);

      await tester.tap(find.byKey(const ValueKey('load-week-3')));
      await tester.pump();

      expect(opacityOf(3), 1.0);
      expect(opacityOf(2), 0.5);
      // Selection is the feedback; no ripple (Interaction Contract 11).
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('load-week-3')),
          matching: find.byType(InkWell),
        ),
        findsNothing,
      );

      await tearDownTree(tester, container);
    });

    testWidgets('each column carries its own button, selected state and tap '
        'action, labelled with the week and its load (WR-02)', (tester) async {
      usePhoneSurface(tester);
      final handle = tester.ensureSemantics();
      final container = makeContainer();
      await openBands(tester, container);

      final node = tester.getSemantics(
        find.byKey(const ValueKey('load-week-2')),
      );
      expect(node.label, contains('4 з 5 слотів'),
          reason: 'a pre-formatted weekLoadLabel inside weekBarSemantics');
      expect(node.label, contains('серп.'), reason: 'the week range');
      // The action must sit on THIS node — `excludeSemantics` drops every
      // descendant action, which is the WR-02 bug shape.
      expect(
        node,
        isSemantics(isButton: true, isSelected: true, hasTapAction: true),
      );
      expect(
        tester.getSemantics(find.byKey(const ValueKey('load-week-4'))),
        isSemantics(isButton: true, isSelected: false, hasTapAction: true),
      );

      handle.dispose();
      await tearDownTree(tester, container);
    });

    testWidgets('exactly one dashed reference line renders, at the comfort '
        'height (DECIDED-2)', (tester) async {
      usePhoneSurface(tester);
      final container = makeContainer();
      await openBands(tester, container);

      expect(find.byKey(const ValueKey('load-threshold')), findsOneWidget,
          reason: 'the 5 limit is drawn structurally, as the cap of the main '
              'bar — a second line there would be redundant chrome');

      // 22.8px above the chart baseline, which is the bottom of a column —
      // 0.6 x 38px, the height of a load-3 bar (DECIDED-2).
      final line = tester.getRect(find.byKey(const ValueKey('load-threshold')));
      final column = tester.getRect(find.byKey(const ValueKey('load-week-0')));
      expect(column.bottom - line.bottom, closeTo(22.8, 0.1));
      expect(line.height, 1);

      await tearDownTree(tester, container);
    });

    testWidgets('selecting a week writes nothing (Interaction Contract 5, '
        'T-04-01)', (tester) async {
      usePhoneSurface(tester);
      final container = makeContainer();
      await openBands(tester, container);

      final before = (await db.select(db.intakeLogs).get()).length;
      await tester.tap(find.byKey(const ValueKey('load-week-7')));
      await tester.pump();
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 10));
      }

      expect(container.read(resolvedWeekIndexProvider), 7);
      expect((await db.select(db.intakeLogs).get()).length, before,
          reason: 'the one gesture this screen has materializes no row');

      await tearDownTree(tester, container);
    });

    testWidgets('the summary chip names this week\'s load and bands at OR '
        'above the limit (DECIDED-6)', (tester) async {
      usePhoneSurface(tester);
      final container = makeContainer();
      await openBands(tester, container);

      expect(find.text('Цього тижня одночасно 4 речовини'), findsOneWidget);
      expect(find.text('межа 5'), findsOneWidget);
      expect(fillOf(tester, 'cycles-summary-chip'), BqColors.calmBg,
          reason: 'a load of 4 is still below the limit');

      await tearDownTree(tester, container);
    });

    testWidgets('a this-week load AT the limit turns the summary chip amber '
        '(DECIDED-6)', (tester) async {
      usePhoneSurface(tester);
      final container = makeContainer();
      await openBands(tester, container, startsOnAugust: const [1, 1, 1, 1, 1]);

      expect(find.text('Цього тижня одночасно 5 речовин'), findsOneWidget);
      expect(fillOf(tester, 'cycles-summary-chip'), BqColors.warnBg,
          reason: 'the WEEK chip nudges AT the limit — the year peak chip '
              'deliberately does not (DECIDED-6)');

      await tearDownTree(tester, container);
    });
  });

  // ---------------------------------------------------------------------
  // The inline week detail (plan 04-03 task 3, UI-SPEC S6a item 4, P-7,
  // P-13, DECIDED-8, Interaction Contracts 3 and 5).
  // ---------------------------------------------------------------------

  group('week detail', () {
    Future<void> openBands(
      WidgetTester tester,
      ProviderContainer container, {
      String locale = 'uk',
    }) async {
      await seedBands(container);
      await openPlanner(tester, container, locale: locale);
      await pumpUntil(
        tester,
        () => byKeyPrefix('load-week-').evaluate().isNotEmpty,
        'the load chart columns',
      );
      // Brings the chart and the card below it into one screenful, which is
      // the exact reading posture the inline detail exists for (P-13).
      await scrollBody(tester, 300);
      await pumpUntil(
        tester,
        () => find.byKey(const ValueKey('week-detail-card'))
            .evaluate()
            .isNotEmpty,
        'the week detail card',
      );
    }

    Color? fillOf(WidgetTester tester, String key) {
      final box = tester.widget<Container>(find.byKey(ValueKey<String>(key)));
      return (box.decoration! as BoxDecoration).color;
    }

    testWidgets('at load 0 it reads comfort, five empty pips and five free '
        'slots — an empty chip row, never an empty state (UI-SPEC truth #11)',
        (tester) async {
      usePhoneSurface(tester);
      final container = makeContainer();
      await openBands(tester, container);

      await tester.tap(find.byKey(const ValueKey('load-week-0')));
      await tester.pump();

      expect(find.text('КОМФОРТНО'), findsOneWidget);
      expect(fillOf(tester, 'week-verdict-chip'), BqColors.calmBg);
      expect(byKeyPrefix('week-pip-'), findsNWidgets(5));
      for (var i = 0; i < 5; i++) {
        expect(fillOf(tester, 'week-pip-$i'), BqColors.surface,
            reason: 'no slot is used in a week with no cycles');
      }
      expect(
        find.textContaining('0 з 5 слотів · Вільно 5 — можна планувати старт'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<Wrap>(find.byKey(const ValueKey('week-name-chips')))
            .children,
        isEmpty,
        reason: 'zero names is a normal state of a real week — an empty Wrap, '
            'never an empty-state block',
      );
      expect(find.text('Планувати ще нічого'), findsNothing);
      expect(find.text(
        'До трьох речовин одночасно легко відстежувати: якщо щось піде не '
        'так, зрозуміло, що саме прибрати.',
      ), findsOneWidget);

      await tearDownTree(tester, container);
    });

    testWidgets('at load 4 it reads МЕЖА in the warn band with four filled '
        'pips and one empty (P-7)', (tester) async {
      usePhoneSurface(tester);
      final container = makeContainer();
      await openBands(tester, container);

      // The default selection is the bucket containing today — load 4.
      final range = DateFormat.MMMd('uk');
      expect(
        find.text('${range.format(DateTime.utc(2026, 8, 10))} – '
            '${range.format(DateTime.utc(2026, 8, 16))}'),
        findsOneWidget,
      );
      expect(find.text('МЕЖА'), findsOneWidget);
      expect(fillOf(tester, 'week-verdict-chip'), BqColors.warnBg);
      expect(byKeyPrefix('week-pip-'), findsNWidgets(5));
      for (var i = 0; i < 4; i++) {
        expect(fillOf(tester, 'week-pip-$i'), BqColors.accent);
      }
      expect(fillOf(tester, 'week-pip-4'), BqColors.surface);
      expect(
        find.textContaining('4 з 5 слотів · Вільно 1 — можна планувати старт'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<Wrap>(find.byKey(const ValueKey('week-name-chips')))
            .children
            .length,
        4,
      );

      await tearDownTree(tester, container);
    });

    testWidgets('tapping an over-limit week re-renders the card IN PLACE: '
        'seven pips, the last two in risk, and the truncated note (P-13, '
        'DECIDED-8)', (tester) async {
      usePhoneSurface(tester);
      final container = makeContainer();
      await openBands(tester, container);

      await tester.tap(find.byKey(const ValueKey('load-week-3')));
      await tester.pump();

      expect(find.text('ПОНАД МЕЖУ'), findsOneWidget);
      expect(fillOf(tester, 'week-verdict-chip'), BqColors.riskBg);
      expect(byKeyPrefix('week-pip-'), findsNWidgets(7),
          reason: 'the excess runs PAST the row — the visual half of what the '
              'note says in words');
      expect(fillOf(tester, 'week-pip-4'), BqColors.accent);
      expect(fillOf(tester, 'week-pip-5'), BqColors.risk);
      expect(fillOf(tester, 'week-pip-6'), BqColors.risk);
      expect(find.textContaining('7 з 5 слотів · Вільних слотів немає'),
          findsOneWidget);
      expect(
        find.text('Цього тижня перетинаються 7 циклів. Варто зсунути старт '
            'частини з них або обговорити такий обсяг із лікарем.'),
        findsOneWidget,
        reason: 'a pre-formatted cyclesCount inside the note key',
      );

      // Inline, always — the user is comparing this against the chart
      // directly above it (P-13).
      expect(find.byType(BottomSheet), findsNothing);
      expect(find.byType(Dialog), findsNothing);

      await tearDownTree(tester, container);
    });

    testWidgets('the excluded pharmacological clause is nowhere in the tree, '
        'in either locale (M2, PF-5)', (tester) async {
      usePhoneSurface(tester);
      for (final locale in const ['uk', 'en']) {
        final container = makeContainer();
        await openBands(tester, container, locale: locale);
        await tester.tap(find.byKey(const ValueKey('load-week-3')));
        await tester.pump();

        for (final excluded in const [
          'жиророзчин',
          'сумарне навантаження',
          'fat-soluble',
          'cumulative load',
        ]) {
          expect(find.textContaining(excluded), findsNothing,
              reason: '"$excluded" is a pharmacological claim inside the '
                  'never-ship interaction-advice exclusion');
        }

        await tearDownTree(tester, container);
      }
    });
  });

  // ---------------------------------------------------------------------
  // The year grid (plan 04-04 task 1, UI-SPEC S6b item 2, P-10, P-11,
  // DECIDED-5, DECIDED-9, Interaction Contracts 4 and 11).
  // ---------------------------------------------------------------------

  /// Seeds one course-regimen supplement per `(id, start, endInclusive)`.
  ///
  /// Ids are zero-padded by every caller on purpose: the stack order is
  /// `createdAt asc, id asc`, and two inserts landing in the same millisecond
  /// would otherwise fall back to a STRING sort where 'y10' sorts before 'y2'.
  Future<void> seedCourses(
    ProviderContainer container,
    List<(String, DateTime, DateTime)> courses,
  ) async {
    final supplements = container.read(supplementRepoProvider);
    final regimens = container.read(regimenRepoProvider);
    for (var i = 0; i < courses.length; i++) {
      final (id, start, end) = courses[i];
      await supplements.upsert(
        Supplement(
          id: id,
          name: 'Добавка $id',
          doseText: '1 капс.',
          // A distinct colour per entry, so a bar painted from the WRONG
          // supplement's colour is a visible failure rather than a coincidence.
          colorValue: 0xFF6B6FA8 + i,
          note: '',
        ),
      );
      await regimens.upsert(
        Regimen(
          id: 'r-$id',
          supplementId: id,
          kind: RegimenKind.course,
          startDate: start,
          endDate: end,
          onDays: 0,
          offDays: 0,
          paused: false,
          slots: const [
            DoseSlot(id: 'sl', minutesFromMidnight: 480, doseLabel: '1 капс.'),
          ],
        ),
      );
    }
  }

  Future<void> openYear(
    WidgetTester tester,
    ProviderContainer container, {
    String locale = 'uk',
    TextScaler? textScaler,
  }) async {
    await openPlanner(tester, container, locale: locale, textScaler: textScaler);
    await tester.tap(find.text(locale == 'uk' ? 'Рік' : 'Year'));
    await tester.pump();
    await pumpUntil(
      tester,
      () => byKeyPrefix('month-card-').evaluate().isNotEmpty,
      'the year grid',
    );
  }

  Material cardAt(WidgetTester tester, int index) =>
      tester.widget<Material>(find.byKey(ValueKey<String>('month-card-$index')));

  group('year grid', () {
    /// Two days of March for `y00`, the whole of June for `y01`..`y06`.
    ///
    /// June therefore carries a load of SIX — one above the editorial limit,
    /// which is exactly the boundary the month-count colour turns on — while
    /// March carries one.
    Future<void> seedYear(ProviderContainer container) => seedCourses(
          container,
          [
            ('y00', DateTime.utc(2026, 3, 1), DateTime.utc(2026, 3, 2)),
            for (var i = 1; i <= 6; i++)
              (
                'y0$i',
                DateTime.utc(2026, 6, 1),
                DateTime.utc(2026, 6, 30),
              ),
          ],
        );

    test('monthCardExtentFor grows with the text scale and with the stack, '
        'and is capped by neither (DECIDED-5, PF-7)', () {
      const plain = TextScaler.noScaling;
      const doubled = TextScaler.linear(2.0);

      expect(monthCardExtentFor(doubled, 3),
          greaterThan(monthCardExtentFor(plain, 3)),
          reason: 'the text-bearing header line follows the scaler');
      expect(monthCardExtentFor(plain, 12),
          greaterThan(monthCardExtentFor(plain, 3)));
      expect(
        monthCardExtentFor(plain, 12) - monthCardExtentFor(plain, 3),
        // Nine more bars: nine 4px tracks and nine 3px gaps.
        9 * 4 + 9 * 3,
        reason: 'the bar extent is exactly N×4 + (N−1)×3 — no cap, no rounding',
      );
      expect(monthCardExtentFor(plain, 0), monthCardExtentFor(plain, 0),
          reason: 'a zero-row extent is well defined, never negative');
      expect(monthCardExtentFor(plain, 0), greaterThan(0));
    });

    testWidgets('renders twelve month cards for today\'s year, labelled with '
        'the uppercased uk standalone abbreviations (DECIDED-9, PF-4)',
        (tester) async {
      usePhoneSurface(tester);
      final container = makeContainer();
      await seedYear(container);
      await openYear(tester, container);

      expect(byKeyPrefix('month-card-'), findsNWidgets(12));

      final abbr = DateFormat('LLL', 'uk');
      for (var m = 0; m < 12; m++) {
        expect(
          tester
              .widget<Text>(find.byKey(ValueKey<String>('month-$m-label')))
              .data,
          abbr.format(DateTime.utc(2026, m + 1, 1)).toUpperCase(),
          reason: 'standalone (nominative) abbreviations, uppercased in the '
              'active locale — never a hardcoded month table (PF-4, M6)',
        );
      }

      // One track per gantt-eligible supplement on EVERY card, whether or not
      // that supplement covers that month — otherwise cards in one row would
      // not be the same height.
      for (final m in const [0, 2, 5, 11]) {
        expect(byKeyPrefix('month-$m-track-'), findsNWidgets(7));
      }

      await tearDownTree(tester, container);
    });

    testWidgets('two days of coverage still paint a visible bar and a full '
        'month paints a full-width one (P-10, the 22% floor)', (tester) async {
      usePhoneSurface(tester);
      final container = makeContainer();
      await seedYear(container);
      await openYear(tester, container);

      final track =
          tester.getSize(find.byKey(const ValueKey('month-2-track-0'))).width;
      final floored =
          tester.getSize(find.byKey(const ValueKey('month-2-bar-0'))).width;
      final full =
          tester.getSize(find.byKey(const ValueKey('month-5-bar-1'))).width;

      expect(floored, closeTo(track * 0.22, 0.5),
          reason: 'the mockup\'s max(round(frac × 100), 22)% floor ships');
      expect(floored, greaterThan(track * 2 / 31),
          reason: '2/31 of a track is a hairline — the floor is the whole '
              'point of the rule');
      expect(full, closeTo(track, 0.5),
          reason: 'frac ≥ 0.85 reads as a full month');
      expect(full, greaterThan(floored));
      expect(
        tester.getSize(find.byKey(const ValueKey('month-2-bar-1'))).width,
        0,
        reason: 'no coverage paints no bar — but the TRACK still renders',
      );

      await tearDownTree(tester, container);
    });

    testWidgets('a month above the editorial limit counts in risk; every '
        'other month counts faint (UI-SPEC banding, strictly above)',
        (tester) async {
      usePhoneSurface(tester);
      final container = makeContainer();
      await seedYear(container);
      await openYear(tester, container);

      Color? countColor(int m) => tester
          .widget<Text>(find.byKey(ValueKey<String>('month-$m-count')))
          .style
          ?.color;

      expect(countColor(5), BqColors.risk,
          reason: 'June carries six concurrent cycles — one above the limit, '
              'which is what the year footnote explains');
      expect(countColor(2), BqColors.textFaint,
          reason: 'March carries one');
      expect(countColor(0), BqColors.textFaint,
          reason: 'an empty month is faint, never red');

      await tearDownTree(tester, container);
    });

    testWidgets('exactly one card is selected, and tapping another moves the '
        'selection — changing only the fill and the border width '
        '(Interaction Contract 4)', (tester) async {
      usePhoneSurface(tester);
      final container = makeContainer();
      await seedYear(container);
      await openYear(tester, container);

      List<int> selectedIndices() => [
            for (var m = 0; m < 12; m++)
              if (cardAt(tester, m).color == BqColors.monthSelectedBg) m,
          ];

      // Follows today by default: the pinned clock is 13 August 2026.
      expect(selectedIndices(), const [7]);
      expect(
        (cardAt(tester, 7).shape! as RoundedRectangleBorder).side.width,
        1.6,
      );
      expect(
        (cardAt(tester, 2).shape! as RoundedRectangleBorder).side.width,
        1.0,
      );
      final labelColorBefore = tester
          .widget<Text>(find.byKey(const ValueKey('month-2-label')))
          .style
          ?.color;

      await tester.tap(find.byKey(const ValueKey('month-card-2')));
      await tester.pump();

      expect(selectedIndices(), const [2],
          reason: 'exactly one month card is selected at any time');
      expect(
        (cardAt(tester, 2).shape! as RoundedRectangleBorder).side.width,
        1.6,
      );
      expect(cardAt(tester, 2).color, BqColors.monthSelectedBg);
      expect(cardAt(tester, 7).color, BqColors.surfaceAlt);
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('month-2-label')))
            .style
            ?.color,
        labelColorBefore,
        reason: 'selection changes the fill and the border width and nothing '
            'else — the label never restyles',
      );

      await tearDownTree(tester, container);
    });

    testWidgets('twelve supplements at a text scaler of 2.0 grow the cards '
        'instead of clipping them, and drop no bar (DECIDED-5, PF-7)',
        (tester) async {
      usePhoneSurface(tester);
      final container = makeContainer();
      await seedCourses(container, [
        for (var i = 0; i < 12; i++)
          (
            'y${i.toString().padLeft(2, '0')}',
            DateTime.utc(2026, 1, 1),
            DateTime.utc(2026, 12, 31),
          ),
      ]);
      await openPlanner(
        tester,
        container,
        textScaler: const TextScaler.linear(2.0),
      );
      await tester.tap(find.text('Рік'));
      await tester.pump();
      // At scale 2.0 the peak chip's sentence is many lines tall — which is
      // the "no fixed-size text container" rule working, not a defect — so
      // the grid starts below the viewport and its cards build only once the
      // body is scrolled.
      await pumpUntil(
        tester,
        () => find.byKey(const ValueKey('year-peak-chip')).evaluate().isNotEmpty,
        'the Рік body',
      );
      await scrollBody(tester, 700);
      await pumpUntil(
        tester,
        () => byKeyPrefix('month-card-').evaluate().isNotEmpty,
        'the year grid at a text scaler of 2.0',
      );

      expect(byKeyPrefix('month-card-'), findsNWidgets(12));
      expect(byKeyPrefix('month-0-track-'), findsNWidgets(12),
          reason: 'no bar is dropped and no card is capped (DECIDED-5)');
      expect(
        tester.takeException(),
        isNull,
        reason: 'a constant card extent — or a fixed child aspect ratio — is '
            'the CR-01/WR-04 defect class this phase exists not to repeat: '
            'seven bottom overflows at accessibility text scales',
      );

      await tearDownTree(tester, container);
    });
  });

  // ---------------------------------------------------------------------
  // The month detail and the year chrome (plan 04-04 task 2, UI-SPEC S6b
  // items 1, 3, 4 and 5, P-10, DECIDED-6, DECIDED-8, M9, PF-12).
  // ---------------------------------------------------------------------

  group('month detail and year chrome', () {
    /// August 2026 carries all three coverage states at once, and December
    /// carries a supplement that August must NOT list.
    Future<void> seedAugust(ProviderContainer container) => seedCourses(
          container,
          [
            // The whole month, already started → приймаю.
            ('m00', DateTime.utc(2026, 8, 1), DateTime.utc(2026, 8, 31)),
            // Starts after the pinned 13 August clock → заплановано.
            ('m01', DateTime.utc(2026, 8, 20), DateTime.utc(2026, 8, 31)),
            // Ten days, already started → частина місяця.
            ('m02', DateTime.utc(2026, 8, 1), DateTime.utc(2026, 8, 10)),
            // No August coverage at all → no row.
            ('m03', DateTime.utc(2026, 12, 1), DateTime.utc(2026, 12, 31)),
          ],
        );

    Color? fillOfKey(WidgetTester tester, String key) {
      final box = tester.widget<Container>(find.byKey(ValueKey<String>(key)));
      return (box.decoration! as BoxDecoration).color;
    }

    /// Built lazily inside each test body: intl's locale data is only
    /// initialized once the localizations delegates have loaded.
    String nominative(int month) =>
        DateFormat('LLLL', 'uk').format(DateTime.utc(2026, month, 1));

    testWidgets('the detail lists only supplements with coverage, in stack '
        'order, each with its state — inline, never a modal (UI-SPEC S6b '
        'item 4, P-13)', (tester) async {
      usePhoneSurface(tester);
      final container = makeContainer();
      await seedAugust(container);
      await openYear(tester, container);

      expect(find.byKey(const ValueKey('month-detail-card')), findsOneWidget);
      expect(
        find.text(nominative(8).toUpperCase()),
        findsOneWidget,
        reason: 'the standalone FULL month name, uppercased in the locale',
      );
      expect(find.text('3 речовини · межа 5'), findsOneWidget,
          reason: 'a pre-formatted substancesCount inside monthMeta');

      expect(byKeyPrefix('month-detail-row-'), findsNWidgets(3));
      expect(find.text('приймаю'), findsOneWidget);
      expect(find.text('заплановано'), findsOneWidget);
      expect(find.text('частина місяця'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('month-detail-card')),
          matching: find.text('Добавка m03'),
        ),
        findsNothing,
        reason: 'a supplement with no coverage in the month has no row — it '
            'still earns a legend entry, which is a different surface',
      );

      expect(find.byType(BottomSheet), findsNothing);
      expect(find.byType(Dialog), findsNothing);

      await tearDownTree(tester, container);
    });

    testWidgets('a month with no coverage renders the empty-month sentence '
        'INSIDE the same card, and the tap re-renders it in place '
        '(Interaction Contract 4)', (tester) async {
      usePhoneSurface(tester);
      final container = makeContainer();
      await seedAugust(container);
      await openYear(tester, container);

      // February: nothing seeded touches it.
      await tester.tap(find.byKey(const ValueKey('month-card-1')));
      await tester.pump();

      expect(find.byKey(const ValueKey('month-detail-card')), findsOneWidget,
          reason: 'the card never collapses to an empty box');
      expect(
        find.text(nominative(2).toUpperCase()),
        findsOneWidget,
      );
      expect(find.text('Цього місяця жоден цикл не активний.'), findsOneWidget);
      expect(find.text('0 речовин · межа 5'), findsOneWidget);
      expect(byKeyPrefix('month-detail-row-'), findsNothing);
      expect(find.byType(BottomSheet), findsNothing);
      expect(find.byType(Dialog), findsNothing);

      await tearDownTree(tester, container);
    });

    testWidgets('the peak chip names the densest month in the calm band, and '
        'the legend names every supplement (S6b items 1 and 3)',
        (tester) async {
      usePhoneSurface(tester);
      final container = makeContainer();
      await seedAugust(container);
      await openYear(tester, container);

      expect(
        find.text('Найщільніший місяць — '
            '${nominative(8)}'),
        findsOneWidget,
      );
      expect(fillOfKey(tester, 'year-peak-chip'), BqColors.calmBg);

      expect(byKeyPrefix('year-legend-entry-'), findsNWidgets(4),
          reason: 'one two-tone swatch per gantt-eligible supplement');
      expect(find.text('світліше = заплановано'), findsOneWidget);

      await tearDownTree(tester, container);
    });

    testWidgets('a tied year reads the tie label, broken toward the month '
        'nearest today (P-10)', (tester) async {
      usePhoneSurface(tester);
      final container = makeContainer();
      await seedCourses(container, [
        ('t00', DateTime.utc(2026, 3, 1), DateTime.utc(2026, 3, 31)),
        ('t01', DateTime.utc(2026, 9, 1), DateTime.utc(2026, 9, 30)),
      ]);
      await openYear(tester, container);

      expect(
        find.text('Найщільніші місяці, зокрема '
            '${nominative(9)}'),
        findsOneWidget,
        reason: 'March and September tie at one; September is nearer the '
            'pinned August clock',
      );

      await tearDownTree(tester, container);
    });

    testWidgets('a year with ZERO coverage renders NO peak chip — it never '
        'claims a densest month it does not have (WR-04)', (tester) async {
      usePhoneSurface(tester);
      final container = makeContainer();
      // A paused regimen keeps its entry and its grid column (DECIDED-7), so
      // the screen-level empty state does NOT fire — reachable in three taps:
      // add a supplement, save a regimen, pause it.
      await container.read(supplementRepoProvider).upsert(magnesium);
      await container.read(regimenRepoProvider).upsert(
            cyclic('r1', 's1', paused: true),
          );
      await openYear(tester, container);

      expect(byKeyPrefix('month-card-'), findsNWidgets(12),
          reason: 'the grid still renders — this is the zero-LOAD case, not '
              'the empty-STACK case the empty state keys on');
      expect(find.byKey(const ValueKey('year-peak-chip')), findsNothing,
          reason: 'with nothing to summarize the chip is omitted, exactly as '
              'UI-SPEC S6c omits it on the empty surface (WR-04)');
      expect(find.textContaining('Найщільніш'), findsNothing,
          reason: 'a peak folded from a seed of 0 ties all twelve months, '
              'resolves to the current one, and reads "the densest months, '
              'including August" for a year with no coverage at all');
      expect(find.text('0 речовин'), findsNothing);

      await tearDownTree(tester, container);
    });

    testWidgets('the peak chip warns STRICTLY above the editorial limit — a '
        'peak sitting exactly at it stays calm (DECIDED-6)', (tester) async {
      usePhoneSurface(tester);

      final atLimit = makeContainer();
      await seedCourses(atLimit, [
        for (var i = 0; i < 5; i++)
          (
            'p0$i',
            DateTime.utc(2026, 6, 1),
            DateTime.utc(2026, 6, 30),
          ),
      ]);
      await openYear(tester, atLimit);

      expect(find.text('5 речовин'), findsOneWidget);
      expect(fillOfKey(tester, 'year-peak-chip'), BqColors.calmBg,
          reason: 'a month that merely TOUCHES the limit is not flagged — the '
              'Цикли summary chip warns at or above it instead, and that '
              'asymmetry is deliberate (DECIDED-6)');
      await tearDownTree(tester, atLimit);

      final over = makeContainer();
      await seedCourses(over, [
        for (var i = 0; i < 6; i++)
          (
            'p0$i',
            DateTime.utc(2026, 6, 1),
            DateTime.utc(2026, 6, 30),
          ),
      ]);
      await openYear(tester, over);

      expect(find.text('6 речовин'), findsOneWidget);
      expect(fillOfKey(tester, 'year-peak-chip'), BqColors.warnBg);
      await tearDownTree(tester, over);
    });

    testWidgets('the year footnote renders ABOVE the disclaimer, proven by '
        'rendered position, not by presence (DECIDED-8, M9, PLAN-04)',
        (tester) async {
      usePhoneSurface(tester);
      final container = makeContainer();
      await seedAugust(container);
      await openYear(tester, container);
      // The Рік body is five elements deep now; its closing lines sit below
      // the fold.
      await scrollBody(tester, 400);

      final footnote = find.text(
        'Рік показує, як цикли накладаються один на одний. Червоне число в '
        'місяці означає перевищення нашої межі у 5 речовин одночасно.',
      );
      expect(footnote, findsOneWidget);
      expect(disclaimer, findsOneWidget);
      expect(
        tester.getTopLeft(footnote).dy,
        lessThan(tester.getTopLeft(disclaimer).dy),
        reason: 'the footnote explains the red counts; the disclaimer frames '
            'the limit as OURS — Рік carries both, in that order, and the '
            'footnote never replaces it',
      );

      await tearDownTree(tester, container);
    });
  });

  // ---------------------------------------------------------------------
  // Cross-segment integration (plan 04-04 task 3, Interaction Contracts 2,
  // 6, 7, 8 and 9, E-14, E-15, T-04-01).
  // ---------------------------------------------------------------------

  group('cross-segment integration', () {
    /// Two supplements covering the whole of August, so a pause or a delete
    /// moves a number the test can name.
    Future<void> seedPair(ProviderContainer container) => seedCourses(
          container,
          [
            ('q00', DateTime.utc(2026, 8, 1), DateTime.utc(2026, 8, 31)),
            ('q01', DateTime.utc(2026, 8, 1), DateTime.utc(2026, 8, 31)),
          ],
        );

    String? countAt(WidgetTester tester, int month) => tester
        .widget<Text>(find.byKey(ValueKey<String>('month-$month-count')))
        .data;

    GanttRowBar rowFor(WidgetTester tester, String supplementId) =>
        tester.widgetList<GanttRowBar>(find.byType(GanttRowBar)).firstWhere(
              (bar) => bar.row.entry.supplement.id == supplementId,
            );

    testWidgets('a week selected on Цикли and a month selected on Рік are '
        'independent — two round trips through the segmented control leave '
        'both intact (Interaction Contract 2)', (tester) async {
      usePhoneSurface(tester);
      final container = makeContainer();
      await seedBands(container);
      await openPlanner(tester, container);
      await pumpUntil(
        tester,
        () => byKeyPrefix('load-week-').evaluate().isNotEmpty,
        'the load chart columns',
      );
      await scrollBody(tester, 300);
      await tester.tap(find.byKey(const ValueKey('load-week-3')));
      await tester.pump();
      expect(container.read(resolvedWeekIndexProvider), 3);

      await tester.tap(find.text('Рік'));
      await tester.pump();
      await pumpUntil(
        tester,
        () => byKeyPrefix('month-card-').evaluate().isNotEmpty,
        'the year grid',
      );
      await tester.tap(find.byKey(const ValueKey('month-card-2')));
      await tester.pump();
      expect(container.read(resolvedMonthIndexProvider), 2);

      for (var i = 0; i < 2; i++) {
        await tester.tap(find.text('Цикли'));
        await tester.pump();
        await tester.tap(find.text('Рік'));
        await tester.pump();
      }

      expect(container.read(resolvedMonthIndexProvider), 2,
          reason: 'the segment index chooses which body builds and nothing '
              'else — neither selection is screen-body state');
      expect(container.read(resolvedWeekIndexProvider), 3);
      expect(cardAt(tester, 2).color, BqColors.monthSelectedBg,
          reason: 'and the surviving selection is the one actually drawn');

      await tearDownTree(tester, container);
    });

    testWidgets('pausing a regimen through the repositories re-renders BOTH '
        'segments with no coverage for it, and no manual refresh (E-15, '
        'DECIDED-7)', (tester) async {
      usePhoneSurface(tester);
      final container = makeContainer();
      await seedPair(container);
      await openYear(tester, container);

      // August is index 7 — the month the pinned clock sits in.
      expect(countAt(tester, 7), '2');

      await container.read(regimenRepoProvider).setPaused('r-q01', true);
      await pumpUntil(
        tester,
        () => countAt(tester, 7) == '1',
        'the year grid to follow the pause',
      );

      expect(
        tester.getSize(find.byKey(const ValueKey('month-7-bar-1'))).width,
        0,
        reason: 'a paused regimen contributes no coverage to any month cell',
      );
      expect(byKeyPrefix('month-7-track-'), findsNWidgets(2),
          reason: 'its TRACK stays — the row is not hidden (DECIDED-7)');

      await tester.tap(find.text('Цикли'));
      await tester.pump();
      await pumpUntil(
        tester,
        () => find.byType(GanttRowBar).evaluate().isNotEmpty,
        'the gantt rows',
      );

      expect(find.byType(GanttRowBar), findsNWidgets(2));
      expect(rowFor(tester, 'q01').row.segments, isEmpty,
          reason: 'a paused row is a bare track, which is the design\'s own '
              'way of saying "paused"');
      expect(rowFor(tester, 'q00').row.segments, isNotEmpty);

      await tearDownTree(tester, container);
    });

    testWidgets('deleting a supplement while the planner is mounted removes '
        'its gantt row, its legend entry and its coverage tracks (E-15)',
        (tester) async {
      usePhoneSurface(tester);
      final container = makeContainer();
      await seedPair(container);
      await openYear(tester, container);

      expect(byKeyPrefix('year-legend-entry-'), findsNWidgets(2));
      expect(byKeyPrefix('month-7-track-'), findsNWidgets(2));

      await container
          .read(supplementRepoProvider)
          .softDeleteCascade('q01', fromDay: today);
      await pumpUntil(
        tester,
        () => byKeyPrefix('year-legend-entry-').evaluate().length == 1,
        'the year legend to follow the delete',
      );

      expect(byKeyPrefix('month-7-track-'), findsNWidgets(1),
          reason: 'the soft-delete filter one layer down reaches the grid');
      expect(find.byKey(const ValueKey('year-legend-entry-q01')), findsNothing);
      expect(countAt(tester, 7), '1');

      await tester.tap(find.text('Цикли'));
      await tester.pump();
      await pumpUntil(
        tester,
        () => find.byType(GanttRowBar).evaluate().isNotEmpty,
        'the gantt rows',
      );
      expect(find.byType(GanttRowBar), findsNWidgets(1));

      await tearDownTree(tester, container);
    });

    testWidgets('advancing the pinned clock past midnight moves the today '
        'marker and flips a run starting that day from planned to active '
        '(E-14, DECIDED-4)', (tester) async {
      usePhoneSurface(tester);
      final container = makeContainer();
      await seedCourses(container, [
        ('n00', DateTime.utc(2026, 8, 14), DateTime.utc(2026, 8, 31)),
      ]);
      await openPlanner(tester, container);
      await pumpUntil(
        tester,
        () => find.byType(GanttRowBar).evaluate().isNotEmpty,
        'the gantt rows',
      );

      final marker = find.byKey(const ValueKey('gantt-today-marker'));
      final before = tester.getTopLeft(marker).dx;
      expect(rowFor(tester, 'n00').row.segments.single.planned, isTrue,
          reason: 'the run starts tomorrow, so it is hatched today');

      (container.read(todayProvider.notifier) as _FixedToday)
          .advanceTo(DateTime.utc(2026, 8, 14));
      await pumpUntil(
        tester,
        () => !rowFor(tester, 'n00').row.segments.single.planned,
        'the run to become active at the rollover',
      );

      expect(tester.getTopLeft(marker).dx, greaterThan(before),
          reason: 'the today marker moved one day into the window');

      await tearDownTree(tester, container);
    });

    testWidgets('a full pass of segment switching, a week selection and a '
        'month selection writes NOT ONE IntakeLog row (T-04-01, PF-2/WR-06)',
        (tester) async {
      usePhoneSurface(tester);
      final container = makeContainer();
      await seedBands(container);
      await openPlanner(tester, container);
      await pumpUntil(
        tester,
        () => byKeyPrefix('load-week-').evaluate().isNotEmpty,
        'the load chart columns',
      );

      final before = (await db.select(db.intakeLogs).get()).length;
      expect(before, 0,
          reason: 'the planner alone materializes nothing at all');

      await scrollBody(tester, 300);
      await tester.tap(find.byKey(const ValueKey('load-week-3')));
      await tester.pump();
      await tester.tap(find.text('Рік'));
      await tester.pump();
      await pumpUntil(
        tester,
        () => byKeyPrefix('month-card-').evaluate().isNotEmpty,
        'the year grid',
      );
      await tester.tap(find.byKey(const ValueKey('month-card-2')));
      await tester.pump();
      await tester.tap(find.text('Цикли'));
      await tester.pump();
      // Give any stray materialization a generous chance to land.
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 10));
      }

      expect((await db.select(db.intakeLogs).get()).length, before,
          reason: 'both planner segments are read-only projections — this is '
              'the phase\'s headline guarantee, proven against the finished '
              'screen and not only against the tracer');

      await tearDownTree(tester, container);
    });
  });

  // ---------------------------------------------------------------------
  // The text-scale matrix and assistive-technology activation (plan 04-05
  // task 1, UI-SPEC #20 and DECIDED-10, T-04-23 and T-04-24).
  //
  // Phase 3 shipped BOTH defect classes this group exists to catch: a fixed
  // extent that clipped every cell at accessibility text scales (CR-01), a
  // rigid header row that overflowed horizontally (WR-04), and a semantics
  // node that announced a button assistive technology could not activate
  // (WR-02). Each was found on a device, after the phase closed. A matrix in
  // the suite is what turns that into a red test instead of a review note.
  // ---------------------------------------------------------------------

  group('text scale matrix and assistive-technology activation', () {
    /// Eight supplements carrying the longest uk names in the catalogue, six
    /// overlapping courses, one active cycle and one paused one.
    ///
    /// The overlap is deliberate: the week containing the pinned clock carries
    /// a load of SEVEN against an editorial limit of five, so the over-bar,
    /// the extra free-slot pips and the LONGEST verdict note are all in the
    /// tree while the matrix runs. A matrix pumped against two short-named
    /// supplements puts no layout under pressure and proves nothing.
    Future<void> seedPressure(ProviderContainer container) async {
      const names = <String>[
        'Вітамін B12 метилкобаламін',
        'Магній бісглицинат хелат',
        'Хондропротектор комплекс',
        'Омега-3 риб\'ячий жир концентрат',
        'Вітамін D3 з вітаміном K2',
        'Комплекс вітамінів групи B',
        'Креатин моногідрат мікронізований',
        'Ашваганда екстракт кореня',
      ];
      final supplements = container.read(supplementRepoProvider);
      final regimens = container.read(regimenRepoProvider);
      for (var i = 0; i < names.length; i++) {
        await supplements.upsert(
          Supplement(
            id: 'p$i',
            name: names[i],
            doseText: '1 капсула вранці',
            colorValue: 0xFF6B6FA8,
            note: '',
          ),
        );
      }
      // Six courses covering the whole window: a floor of six concurrent
      // substances everywhere, one above the limit on its own.
      for (var i = 0; i < 6; i++) {
        await regimens.upsert(
          Regimen(
            id: 'pr$i',
            supplementId: 'p$i',
            kind: RegimenKind.course,
            startDate: DateTime.utc(2026, 8, 1),
            endDate: DateTime.utc(2026, 11, 30),
            onDays: 0,
            offDays: 0,
            paused: false,
            slots: const [
              DoseSlot(
                id: 'ps',
                minutesFromMidnight: 480,
                doseLabel: '1 капс.',
              ),
            ],
          ),
        );
      }
      // A live 14/14 cycle covering the week the pinned clock sits in, which
      // takes that week to seven, and a paused one that keeps its bare track.
      await regimens.upsert(cyclic('pr6', 'p6'));
      await regimens.upsert(cyclic('pr7', 'p7', paused: true));
    }

    /// Pumps deferred layout out: a grid delegate resolving its extent, an
    /// intl format landing, a scroll settling.
    Future<void> pumpFrames(WidgetTester tester, [int frames = 12]) async {
      for (var i = 0; i < frames; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }
    }

    /// The page's own scroll position.
    ///
    /// `.first` on purpose: the Рік body nests a `GridView` — a second
    /// `Scrollable`, pinned with `NeverScrollableScrollPhysics` — inside the
    /// page `ListView`, and the outer one comes first in tree order.
    ScrollPosition bodyPosition(WidgetTester tester) => tester
        .state<ScrollableState>(
          find
              .descendant(
                of: find.byType(ListView),
                matching: find.byType(Scrollable),
              )
              .first,
        )
        .position;

    /// Drags the body to its end, building every card on the way.
    ///
    /// A `ListView` only builds what its viewport plus cache extent covers, so
    /// a matrix that never scrolls asserts nothing about the cards below the
    /// fold — which at a text scaler of 2.0 is most of them.
    Future<void> sweepBody(WidgetTester tester) async {
      for (var i = 0; i < 80; i++) {
        final position = bodyPosition(tester);
        if (position.pixels >= position.maxScrollExtent) return;
        await scrollBody(tester, 500);
        await pumpFrames(tester, 3);
      }
      fail('Timed out sweeping the planner body to its end');
    }

    /// The consequence of a red case, named in device terms rather than as a
    /// restatement of the assertion.
    const overflowReason =
        'a layout exception at an accessibility text scale is a clipped label '
        'or a dropped bar in RELEASE — not debug stripes. This is the CR-01 / '
        'WR-04 defect class Phase 3 shipped twice; the fix is a computed '
        'extent or a flexible child, never a relaxed assertion';

    for (final locale in const ['uk', 'en']) {
      final cyclesLabel = locale == 'uk' ? 'Цикли' : 'Cycles';
      final yearLabel = locale == 'uk' ? 'Рік' : 'Year';

      for (final scale in const <double>[1.0, 1.6, 2.0]) {
        testWidgets(
            '$locale: the Цикли segment renders a pressured stack with no '
            'layout exception at textScaler $scale (UI-SPEC #20)',
            (tester) async {
          usePhoneSurface(tester);
          final container = makeContainer();
          await seedPressure(container);
          await openPlanner(
            tester,
            container,
            locale: locale,
            textScaler: TextScaler.linear(scale),
          );
          await pumpUntil(
            tester,
            () => find.byType(GanttRowBar).evaluate().isNotEmpty,
            'the gantt rows in $locale at textScaler $scale',
          );
          await pumpFrames(tester);
          await sweepBody(tester);

          expect(bodyPosition(tester).pixels,
              bodyPosition(tester).maxScrollExtent,
              reason: 'the sweep reached the end of the body, so every card '
                  'below the fold was actually built and laid out');
          expect(tester.takeException(), isNull, reason: overflowReason);

          await tearDownTree(tester, container);
        });

        testWidgets(
            '$locale: the Рік segment renders a pressured stack with no '
            'layout exception at textScaler $scale (UI-SPEC #20, DECIDED-5)',
            (tester) async {
          usePhoneSurface(tester);
          final container = makeContainer();
          await seedPressure(container);
          await openPlanner(
            tester,
            container,
            locale: locale,
            textScaler: TextScaler.linear(scale),
          );
          await tester.tap(find.text(yearLabel));
          await tester.pump();
          await pumpUntil(
            tester,
            () =>
                find.byKey(const ValueKey('year-peak-chip')).evaluate().isNotEmpty,
            'the Рік body in $locale at textScaler $scale',
          );
          await pumpFrames(tester);
          await sweepBody(tester);

          expect(bodyPosition(tester).pixels,
              bodyPosition(tester).maxScrollExtent,
              reason: 'the sweep reached the end of the body, so the grid, '
                  'the legend and the month detail were all built');
          expect(tester.takeException(), isNull, reason: overflowReason);

          await tearDownTree(tester, container);
        });

        testWidgets(
            '$locale: the EMPTY surface renders on both segments with no '
            'layout exception at textScaler $scale (UI-SPEC #20, S6c)',
            (tester) async {
          usePhoneSurface(tester);
          // Nothing seeded at all: the stack resolves empty, which is the
          // empty surface's first variant.
          final container = makeContainer();
          await openPlanner(
            tester,
            container,
            locale: locale,
            textScaler: TextScaler.linear(scale),
          );
          await pumpFrames(tester);
          await sweepBody(tester);

          await tester.tap(find.text(yearLabel));
          await tester.pump();
          await pumpFrames(tester);
          await sweepBody(tester);

          await tester.tap(find.text(cyclesLabel));
          await tester.pump();
          await pumpFrames(tester);

          expect(tester.takeException(), isNull, reason: overflowReason);

          await tearDownTree(tester, container);
        });

        testWidgets(
            '$locale: the ERROR surface renders on both segments with no '
            'layout exception at textScaler $scale (UI-SPEC #20, S6c)',
            (tester) async {
          usePhoneSurface(tester);
          final container = makeContainer(
            stackState: AsyncError(
              Exception('boom-from-drift'),
              StackTrace.empty,
            ),
          );
          await openPlanner(
            tester,
            container,
            locale: locale,
            textScaler: TextScaler.linear(scale),
          );
          await pumpFrames(tester);
          await sweepBody(tester);

          await tester.tap(find.text(yearLabel));
          await tester.pump();
          await pumpFrames(tester);
          await sweepBody(tester);

          expect(tester.takeException(), isNull, reason: overflowReason);

          await tearDownTree(tester, container);
        });
      }
    }

    testWidgets('a week column is ACTIVATED through its semantics action — '
        'not by a widget tap — and the selection follows (DECIDED-10, WR-02)',
        (tester) async {
      usePhoneSurface(tester);
      final handle = tester.ensureSemantics();
      final container = makeContainer();
      await seedBands(container);
      await openPlanner(tester, container);
      await pumpUntil(
        tester,
        () => byKeyPrefix('load-week-').evaluate().isNotEmpty,
        'the load chart columns',
      );
      await scrollBody(tester, 300);

      final target = find.byKey(const ValueKey('load-week-4'));
      expect(container.read(resolvedWeekIndexProvider), isNot(4),
          reason: 'the default selection is the bucket containing today, so '
              'bucket 4 is a real change');
      final node = tester.getSemantics(target);
      expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue,
          reason: '`excludeSemantics` drops every descendant action, so the '
              'column node has to carry one itself — without it the column '
              'announces itself as a button VoiceOver and TalkBack cannot '
              'press (WR-02)');

      // Assistive technology does not tap widgets. It activates semantics
      // actions, which is the ONLY path that proves what WR-02 got wrong.
      tester.semantics.performAction(
        find.semantics.byLabel(node.label),
        SemanticsAction.tap,
      );
      await tester.pump();

      expect(container.read(resolvedWeekIndexProvider), 4,
          reason: 'activating the node selected the week — a screen-reader '
              'user can drive this chart, not merely hear it');
      expect(
        tester.getSemantics(target),
        isSemantics(isButton: true, isSelected: true, hasTapAction: true),
        reason: 'and the node it activated now reports itself selected',
      );
      expect(
        tester.getSemantics(find.byKey(const ValueKey('load-week-3'))),
        isSemantics(isButton: true, isSelected: false, hasTapAction: true),
        reason: 'every other column reports itself unselected — the selected '
            'flag tracks the live selection, it is not a static property',
      );
      expect(tester.takeException(), isNull);

      handle.dispose();
      await tearDownTree(tester, container);
    });

    testWidgets('a month card is ACTIVATED through its semantics action — '
        'not by a widget tap — and the selection follows (WR-02)',
        (tester) async {
      usePhoneSurface(tester);
      final handle = tester.ensureSemantics();
      final container = makeContainer();
      await seedBands(container);
      await openYear(tester, container);

      final target = find.byKey(const ValueKey('month-card-5'));
      expect(container.read(resolvedMonthIndexProvider), isNot(5),
          reason: 'the default selection is today\'s month (August, index 7)');
      final node = tester.getSemantics(target);
      expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue,
          reason: 'the card wraps an InkWell in an excluding Semantics node, '
              'so the action must live on the node itself (WR-02)');

      tester.semantics.performAction(
        find.semantics.byLabel(node.label),
        SemanticsAction.tap,
      );
      await tester.pump();

      expect(container.read(resolvedMonthIndexProvider), 5,
          reason: 'activating the node selected the month');
      expect(
        tester.getSemantics(target),
        isSemantics(isButton: true, isSelected: true, hasTapAction: true),
      );
      expect(
        tester.getSemantics(find.byKey(const ValueKey('month-card-7'))),
        isSemantics(isButton: true, isSelected: false, hasTapAction: true),
        reason: 'the previously-selected month reports itself unselected — '
            'the flag follows the live selection on every card',
      );
      expect(tester.takeException(), isNull);

      handle.dispose();
      await tearDownTree(tester, container);
    });

    testWidgets('the Calendar header\'s two text actions flow onto a SECOND '
        'LINE at textScaler 2.0 rather than overflowing (S4-amendment, WR-04)',
        (tester) async {
      usePhoneSurface(tester);
      final container = makeContainer();
      await seed(container);

      await tester.pumpWidget(
        app(container, textScaler: const TextScaler.linear(2.0)),
      );
      await pumpUntil(
        tester,
        () => find.text('Планувальник').evaluate().isNotEmpty,
        'the Calendar header actions',
      );
      // A resolved day that is NOT today, so the second action renders too —
      // which is the only configuration where the pair can overflow.
      container
          .read(selectedDayProvider.notifier)
          .select(DateTime.utc(2026, 8, 10));
      await pumpUntil(
        tester,
        () => find.text('Сьогодні').evaluate().isNotEmpty,
        'the back-to-today action',
      );
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }

      final actions = find
          .ancestor(
            of: find.text('Планувальник'),
            matching: find.byType(Wrap),
          )
          .first;
      final buttons =
          find.descendant(of: actions, matching: find.byType(TextButton));
      expect(buttons, findsNWidgets(2));

      final first = tester.getRect(buttons.at(0));
      final second = tester.getRect(buttons.at(1));
      expect(second.top, greaterThanOrEqualTo(first.bottom),
          reason: 'a Wrap, not a Row: at textScaler 2.0 the two uk labels do '
              'not fit one line, and a Row would clip the second action off '
              'the screen exactly as the Phase-3 header did (WR-04)');
      expect(tester.takeException(), isNull,
          reason: 'the app\'s most-used screen gained this action pair in '
              'this phase — an overflow here reaches every user, not only '
              'planner users');

      await tearDownTree(tester, container);
    });
  });

  // ---------------------------------------------------------------------
  // The settings gear (plan 06-02, UI-SPEC S11 / D-5, NAV-03).
  // ---------------------------------------------------------------------

  group('the settings gear (S11)', () {
    for (final locale in const ['uk', 'en']) {
      final l10n = lookupAppLocalizations(Locale(locale));

      testWidgets(
          '$locale: the gear renders exactly once, in the OUTLINED variant, '
          'with a box >= 44 that is identical at 1.0 / 1.6 / 2.0',
          (tester) async {
        usePhoneSurface(tester);
        final container = makeContainer();
        final sizes = <Size>[];
        for (final scale in bqTextScaleMatrix) {
          await tester.pumpWidget(
            plannerApp(
              container,
              locale: locale,
              textScaler: TextScaler.linear(scale),
            ),
          );
          await tester.pump();

          expect(gearControl(), findsOneWidget, reason: gearPresenceReason);
          expect(find.byIcon(Icons.settings), findsNothing,
              reason: 'the FILLED glyph expresses a selected state, and the '
                  'gear has none — it is a control, not a destination');
          expect(find.bySemanticsLabel(l10n.tabSettings), findsOneWidget,
              reason: 'the gear is icon-only, so the ARB label is the only '
                  'thing a screen-reader user has — and it follows the active '
                  'language like every other string');
          final size = tester.getSize(gearControl());
          expect(size.width, greaterThanOrEqualTo(44.0),
              reason: gearTapTargetReason);
          expect(size.height, greaterThanOrEqualTo(44.0),
              reason: gearTapTargetReason);
          expect(tester.takeException(), isNull, reason: gearOverflowReason);
          sizes.add(size);
        }

        expect(sizes.toSet(), hasLength(1), reason: gearGeometryReason(sizes));
        await tearDownTree(tester, container);
      });
    }

    testWidgets('activating the gear through SemanticsAction.tap PUSHES the '
        'Settings route — not a coordinate tap', (tester) async {
      usePhoneSurface(tester);
      final container = makeContainer();
      final l10n = lookupAppLocalizations(const Locale('uk'));
      await tester.pumpWidget(plannerApp(container));
      await tester.pump();

      expect(
        tester
            .getSemantics(find.bySemanticsLabel(l10n.tabSettings))
            .getSemanticsData()
            .hasAction(SemanticsAction.tap),
        isTrue,
        reason: '`excludeSemantics: true` drops every DESCENDANT action, so '
            'the gear node has to carry one itself — without it the control '
            'announces a button VoiceOver and TalkBack cannot press, while '
            'passing every coordinate-tap test (WR-02)',
      );

      // Assistive technology does not tap widgets. It activates actions.
      tester.semantics.performAction(
        find.semantics.byLabel(l10n.tabSettings),
        SemanticsAction.tap,
      );
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }

      expect(find.byType(SettingsScreen), findsOneWidget,
          reason: 'the gear pushes Settings as a full-screen route; a control '
              'that announces itself and navigates nowhere is worse than no '
              'control at all');
      expect(find.byType(PlannerScreen), findsOneWidget,
          reason: 'a PUSH, not a replacement: the planner underneath stays '
              'mounted, which is what keeps the selected segment, week and '
              'month intact across the return trip');

      await tearDownTree(tester, container);
    });

    testWidgets('the gear row carries NO text, so the header cannot overflow '
        'through it at any scale in either locale', (tester) async {
      usePhoneSurface(tester);
      final container = makeContainer();
      await tester.pumpWidget(plannerApp(container));
      await tester.pump();

      final row = tester.widget<Row>(
        find
            .ancestor(
              of: find.byIcon(Icons.settings_outlined),
              matching: find.byType(Row),
            )
            .last,
      );
      expect(
        find.descendant(
          of: find.byWidget(row),
          matching: find.byType(Text),
        ),
        findsNothing,
        reason: 'the whole D-5 argument is that this row holds one text-free '
            'control and nothing else: the moment a Text lands in it, the row '
            'starts following the text scaler and the "cannot overflow" claim '
            'in the widget comment becomes a lie',
      );

      await tearDownTree(tester, container);
    });
  });
}

/// The settings gear's `IconButton`, scoped through its glyph so the finder
/// cannot drift onto some other button the header grows later.
Finder gearControl() => find.ancestor(
      of: find.byIcon(Icons.settings_outlined),
      matching: find.byType(IconButton),
    );

/// The consequence of a layout exception in the header the gear row joined.
const String gearOverflowReason =
    'a layout exception at an accessibility text scale is a clipped header in '
    'RELEASE — not debug stripes. The gear row is the newest child of this '
    'header; the fix is a computed extent or a flexible child, never a '
    'relaxed assertion (CR-01 / WR-04)';

/// Why the gear must not be conditional.
const String gearPresenceReason =
    'the gear is the only way into Settings once the destination is removed '
    '(plan 06-03). A gear that renders only in some screen state is a screen '
    'the user can get stranded on — and "some screen state" includes the empty '
    'and failing surfaces this suite covers elsewhere';

/// Why the gear box is asserted as a FLOOR and not as 44.0 exactly.
const String gearTapTargetReason =
    'the gear is built to the S11 recipe — an IconButton with '
    'BoxConstraints.tightFor(44, 44) and zero padding — and Material then '
    'wraps it to its 48dp padded tap target, so the rendered box is 48 while '
    'the constrained icon box is 44. 48 >= 44 satisfies the guidance; what '
    'must not happen is a box SMALLER than 44 or one that changes with the '
    'text scaler';

/// Why the gear row's extent must not move with the text scaler.
String gearGeometryReason(List<Size> sizes) =>
    'the gear row holds NO text, so its extent is pure geometry — a '
    'scale-dependent box means something textual leaked into the row, and the '
    'D-5 argument that this header CANNOT overflow no longer holds '
    '(measured: $sizes)';

/// Pins `todayProvider` to a fixed calendar day.
class _FixedToday extends TodayController {
  _FixedToday(this.day);

  final DateTime day;

  @override
  DateTime build() => day;

  /// Moves the pinned clock — the automatable half of the midnight-rollover
  /// backstop (E-14). The real controller re-derives the day from the system
  /// clock at local midnight; this stands in for that tick.
  void advanceTo(DateTime next) => state = next;
}
