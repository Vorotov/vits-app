/// Widget tests for the Calendar tracer slice (plan 03-01, Task 1).
///
/// Harness: real in-memory Drift database behind the repository providers
/// (Phase-1/2 pattern, same as stack_screen_test.dart), locale uk, 390x844
/// logical surface. Supplements and regimens are seeded through the
/// repositories BEFORE the screen pumps — and NOTHING in this file ever calls
/// `ensureLogsForDay`: materialization is `dayDosesProvider`'s job (PF-3), and
/// proving that is the point of the first test.
///
/// Coverage:
/// - a seeded supplement + active regimen renders a dose row with no manual
///   materialization anywhere (TRACK-01/TRACK-04, PF-3)
/// - tapping the row drives the raw intakeLogs row to `taken`; tapping again
///   returns it to `pending` (TRACK-02 — undo is the inverse gesture)
/// - two taps with no pump between them end at `taken`, not oscillating back
///   (PF-4, the CR-01 lesson)
/// - a day on which the regimen's cycle is inactive renders no dose rows
///
/// Raw statuses are read back through a pump-driven `db.select(db.intakeLogs)`
/// watch: awaiting a Drift future un-pumped deadlocks against its
/// zero-duration timers inside the test zone (stack_screen_test.dart:273).
/// `tearDownTree` is called inside every test body — the midnight `Timer` in
/// `TodayController` is a pending timer that would otherwise fail the test.
library;

import 'dart:async';

import 'package:boostque/core/db/database.dart' show BoostqueDb, IntakeLog;
import 'package:boostque/core/db/drift_repositories.dart'
    show DriftIntakeRepository;
import 'package:boostque/core/domain/models.dart';
import 'package:boostque/core/domain/repositories.dart'
    show DayDose, IntakeRepository;
import 'package:boostque/core/l10n/l10n.dart';
import 'package:boostque/core/providers.dart';
import 'package:boostque/core/theme/theme.dart';
import 'package:boostque/core/theme/tokens.dart';
import 'package:boostque/core/today_controller.dart';
import 'package:boostque/features/calendar/calendar_providers.dart';
import 'package:boostque/features/calendar/calendar_screen.dart';
import 'package:boostque/features/calendar/day_block_section.dart';
import 'package:boostque/features/calendar/day_progress_ring.dart';
import 'package:boostque/features/calendar/dose_row.dart';
import 'package:boostque/features/calendar/week_strip.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const supplement = Supplement(
    id: 's1',
    name: 'Магній бісглицинат',
    doseText: '400 мг · капсули',
    colorValue: 0xFF6B6FA8,
    note: '',
  );

  late BoostqueDb db;

  setUp(() {
    // LocaleController loads its persisted override from SharedPreferences.
    SharedPreferences.setMockInitialValues({});
  });

  /// Provider container over an in-memory database; callers seed through the
  /// repositories before pumping.
  ///
  /// [today] pins the app's single clock so every intl assertion below is
  /// deterministic on any machine, on any day (the header's date strings are
  /// clock-derived — UI-SPEC S4). [nowMinutes] pins the OTHER sanctioned clock
  /// read — the minute ticker — so current-block and overdue assertions do not
  /// depend on what time the suite happens to run at; it also replaces the
  /// periodic timer with a single-value stream.
  ProviderContainer makeContainer({DateTime? today, int? nowMinutes}) {
    return ProviderContainer(
      overrides: [
        dbProvider.overrideWith((ref) {
          final database = BoostqueDb.forTesting(NativeDatabase.memory());
          ref.onDispose(database.close);
          db = database;
          return database;
        }),
        if (today != null) todayProvider.overrideWith(() => _FixedToday(today)),
        if (nowMinutes != null)
          nowMinutesProvider.overrideWith((ref) => Stream.value(nowMinutes)),
      ],
    );
  }

  /// [textScaler] pins the accessibility text scale for the whole tree — the
  /// axis CR-01 and WR-04 both broke on, and the one the suite had no coverage
  /// of at all (IN-08). [home] lets a test pump one calendar widget in
  /// isolation instead of the whole screen.
  Widget app(
    ProviderContainer container, {
    Locale locale = const Locale('uk'),
    TextScaler textScaler = TextScaler.noScaling,
    Widget home = const CalendarScreen(),
  }) {
    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: bqTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: textScaler),
          child: child!,
        ),
        home: home,
      ),
    );
  }

  /// Sets a phone-sized logical surface (390x844); restored automatically.
  void usePhoneSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  /// Tears the tree down inside the test body so Drift's stream-close
  /// zero-duration timers and the midnight Timer are gone before
  /// flutter_test's pending-timer check.
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

  /// Pumps frames until [condition] holds (Drift emissions arrive
  /// asynchronously — never settle the tree: the midnight timer and the minute
  /// ticker are both permanently pending).
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

  /// A raw intake-log watch scoped to ONE calendar day.
  ///
  /// Day-scoped on purpose (plan 03-05): mounting the screen now also mounts
  /// [WeekStrip], and each of its seven visible cells watches
  /// `dayDosesProvider` for its own day — which pre-materializes the whole
  /// visible week. An unfiltered `db.select(db.intakeLogs)` therefore returns
  /// a week of rows, while every assertion in this file is about one day's.
  Stream<List<IntakeLog>> rawLogsFor(DateTime day) =>
      (db.select(db.intakeLogs)..where((t) => t.date.equals(day))).watch();

  /// An always-active cyclic regimen (offDays 0) with one 08:00 slot.
  Regimen alwaysActive() => Regimen(
        id: 'r1',
        supplementId: 's1',
        kind: RegimenKind.cyclic,
        startDate: DateTime.utc(2020, 1, 1),
        endDate: null,
        onDays: 1,
        offDays: 0,
        paused: false,
        slots: const [
          DoseSlot(id: 'sl1', minutesFromMidnight: 480, doseLabel: '400 мг'),
        ],
      );

  testWidgets(
      'uk: a seeded supplement + active regimen renders a dose row with NO '
      'manual materialization call (PF-3, TRACK-01)', (tester) async {
    usePhoneSurface(tester);
    final container = makeContainer();
    await container.read(supplementRepoProvider).upsert(supplement);
    await container.read(regimenRepoProvider).upsert(alwaysActive());

    await tester.pumpWidget(app(container));
    await pumpUntil(
      tester,
      () => find.text('Магній бісглицинат').evaluate().isNotEmpty,
      'the dose row to materialize through dayDosesProvider',
    );

    expect(find.text('Сьогодні'), findsOneWidget,
        reason: 'the localized S4 heading renders (calendarTitleToday)');
    expect(find.text('400 мг'), findsOneWidget,
        reason: "the slot's dose label renders on the row");
    expect(tester.takeException(), isNull);

    await tearDownTree(tester, container);
  });

  testWidgets(
      'uk: tapping a dose row persists taken; tapping again returns it to '
      'pending (TRACK-02)', (tester) async {
    usePhoneSurface(tester);
    final container = makeContainer();
    await container.read(supplementRepoProvider).upsert(supplement);
    await container.read(regimenRepoProvider).upsert(alwaysActive());

    await tester.pumpWidget(app(container));
    final row = find.text('Магній бісглицинат');
    await pumpUntil(tester, () => row.evaluate().isNotEmpty, 'the dose row');

    // Raw table watch, pump-driven: awaiting a Drift future un-pumped
    // deadlocks in the test zone.
    var raw = <IntakeLog>[];
    final rawSub =
        rawLogsFor(container.read(todayProvider)).listen((v) => raw = v);
    await pumpUntil(tester, () => raw.length == 1, 'the materialized log row');
    expect(raw.single.status, DoseStatus.pending,
        reason: 'materialization creates the row as pending');

    await tester.tap(row);
    await pumpUntil(
      tester,
      () => raw.single.status == DoseStatus.taken,
      'the tap to persist DoseStatus.taken',
    );

    await tester.tap(row);
    await pumpUntil(
      tester,
      () => raw.single.status == DoseStatus.pending,
      'the second tap to undo back to DoseStatus.pending',
    );

    expect(tester.takeException(), isNull);
    // ignore: unawaited_futures
    rawSub.cancel();
    await tester.pump(const Duration(milliseconds: 10));
    await tearDownTree(tester, container);
  });

  testWidgets(
      'uk: two taps with NO pump between them end at taken, not oscillating '
      'back to pending (PF-4)', (tester) async {
    usePhoneSurface(tester);
    final container = makeContainer();
    await container.read(supplementRepoProvider).upsert(supplement);
    await container.read(regimenRepoProvider).upsert(alwaysActive());

    await tester.pumpWidget(app(container));
    final row = find.text('Магній бісглицинат');
    await pumpUntil(tester, () => row.evaluate().isNotEmpty, 'the dose row');

    var raw = <IntakeLog>[];
    final rawSub =
        rawLogsFor(container.read(todayProvider)).listen((v) => raw = v);
    await pumpUntil(tester, () => raw.length == 1, 'the materialized log row');

    // Two taps with NO pump in between — both hit the still-built row; the
    // in-flight guard must swallow the second.
    await tester.tap(row);
    await tester.tap(row, warnIfMissed: false);
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }

    expect(raw.single.status, DoseStatus.taken,
        reason: 'a rapid double tap must end at taken, never oscillate back');
    expect(tester.takeException(), isNull);
    // ignore: unawaited_futures
    rawSub.cancel();
    await tester.pump(const Duration(milliseconds: 10));
    await tearDownTree(tester, container);
  });

  testWidgets('uk: a day on which the cycle is inactive renders no dose rows',
      (tester) async {
    usePhoneSurface(tester);
    final container = makeContainer();
    await container.read(supplementRepoProvider).upsert(supplement);
    // Active for exactly one day in 2020, then off for ~274 years: today is
    // deterministically an off day, whatever the device clock says.
    await container.read(regimenRepoProvider).upsert(Regimen(
          id: 'r1',
          supplementId: 's1',
          kind: RegimenKind.cyclic,
          startDate: DateTime.utc(2020, 1, 1),
          endDate: null,
          onDays: 1,
          offDays: 100000,
          paused: false,
          slots: const [
            DoseSlot(id: 'sl1', minutesFromMidnight: 480, doseLabel: '400 мг'),
          ],
        ));

    await tester.pumpWidget(app(container));
    await pumpUntil(
      tester,
      () => find.text('Сьогодні').evaluate().isNotEmpty,
      'the calendar heading',
    );
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }

    expect(find.text('Магній бісглицинат'), findsNothing,
        reason: 'isActiveOn is the only activity gate — an off day is empty');
    expect(tester.takeException(), isNull);

    await tearDownTree(tester, container);
  });

  // --- DayProgressRing (plan 03-03, Task 2; UI-SPEC E4 / M10 / DECIDED-7) ---
  //
  // The ring is a pure StatelessWidget over two ints, so this group needs no
  // database and no provider container — just the localized MaterialApp so
  // `context.l10n.ringSemantics` resolves against real uk delegates. No timer
  // is alive here, so no tearDownTree is required.
  group('DayProgressRing', () {
    Widget ringApp(Widget child) => MaterialApp(
          locale: const Locale('uk'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: bqTheme(),
          home: Scaffold(body: Center(child: child)),
        );

    testWidgets('uk: taken 2 of 5 renders "2/5" and the localized '
        'ringSemantics label', (tester) async {
      usePhoneSurface(tester);
      final semantics = tester.ensureSemantics();

      await tester
          .pumpWidget(ringApp(const DayProgressRing(taken: 2, total: 5)));

      expect(find.text('2/5'), findsOneWidget,
          reason: 'the mono counter renders both counts, slash-separated');
      expect(
        tester.getSemantics(find.byType(DayProgressRing)).label,
        '2 з 5 доз прийнято',
        reason: 'a bare canvas is invisible to screen readers — the ring '
            'carries ringSemantics in the active locale',
      );
      expect(tester.takeException(), isNull);
      semantics.dispose();
    });

    testWidgets('shouldRepaint compares ONLY the fraction (Interaction '
        'Contract 9)', (tester) async {
      usePhoneSurface(tester);
      await tester.pumpWidget(ringApp(
        const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DayProgressRing(taken: 2, total: 5), // fraction .4
            DayProgressRing(taken: 4, total: 10), // fraction .4 — same
            DayProgressRing(taken: 4, total: 5), // fraction .8 — different
          ],
        ),
      ));

      final painters = tester
          .widgetList<CustomPaint>(
            find.descendant(
              of: find.byType(DayProgressRing),
              matching: find.byType(CustomPaint),
            ),
          )
          .map((c) => c.painter)
          .whereType<CustomPainter>()
          .toList();
      expect(painters.length, 3,
          reason: 'each ring paints through exactly one CustomPainter');

      expect(painters[0].shouldRepaint(painters[1]), isFalse,
          reason: '2/5 and 4/10 are the same fraction — no repaint');
      expect(painters[0].shouldRepaint(painters[2]), isTrue,
          reason: '.4 -> .8 changes what is drawn — repaint');
    });

    testWidgets('renders at both extremes: 0 of 4 (empty arc) and 4 of 4 '
        '(full sweep)', (tester) async {
      usePhoneSurface(tester);

      await tester
          .pumpWidget(ringApp(const DayProgressRing(taken: 0, total: 4)));
      expect(find.text('0/4'), findsOneWidget,
          reason: 'the ring still renders at zero progress (DECIDED-7 hides '
              'it only at total == 0)');
      expect(tester.takeException(), isNull);

      await tester
          .pumpWidget(ringApp(const DayProgressRing(taken: 4, total: 4)));
      expect(find.text('4/4'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    test('constructing at total == 0 is a programming error (DECIDED-7 — the '
        'header omits the ring entirely)', () {
      expect(() => DayProgressRing(taken: 0, total: 0), throwsAssertionError);
    });
  });

  // --- Fixed header (plan 03-03, Task 3; UI-SPEC S4 "Header", A7, E5) ---
  //
  // Every date string here is asserted against a PINNED clock (2026-08-13, a
  // Thursday) so the uk exemplar rendering is reproducible. The assertions run
  // inside the localized MaterialApp harness, which loads the real uk date
  // symbols through the global delegates — a plain unit test would need
  // `initializeDateFormatting('uk')` first or silently fall back to en.
  group('header', () {
    final pinnedToday = DateTime.utc(2026, 8, 13); // четвер
    final twoDaysEarlier = DateTime.utc(2026, 8, 11); // вівторок

    const disclaimer = 'Розклад складено з ваших власних записів. '
        'Освітній матеріал, не медична порада.';

    testWidgets('uk: following today renders the localized title and the '
        'pinned exemplar subtitle "четвер, 13 серпня" (A7)', (tester) async {
      usePhoneSurface(tester);
      final container = makeContainer(today: pinnedToday);
      await container.read(supplementRepoProvider).upsert(supplement);
      await container.read(regimenRepoProvider).upsert(alwaysActive());

      await tester.pumpWidget(app(container));
      await pumpUntil(
        tester,
        () => find.text('четвер, 13 серпня').evaluate().isNotEmpty,
        'the intl-formatted header subtitle',
      );

      expect(find.text('Сьогодні'), findsOneWidget,
          reason: 'the title is the localized today string while following');
      expect(tester.takeException(), isNull);

      await tearDownTree(tester, container);
    });

    testWidgets('uk: a non-today selection titles the capitalized weekday and '
        'drops it from the subtitle', (tester) async {
      usePhoneSurface(tester);
      final container = makeContainer(today: pinnedToday);
      await container.read(supplementRepoProvider).upsert(supplement);
      await container.read(regimenRepoProvider).upsert(alwaysActive());

      await tester.pumpWidget(app(container));
      await pumpUntil(
        tester,
        () => find.text('четвер, 13 серпня').evaluate().isNotEmpty,
        'the header to settle on today',
      );

      container.read(selectedDayProvider.notifier).select(twoDaysEarlier);
      await pumpUntil(
        tester,
        () => find.text('Вівторок').evaluate().isNotEmpty,
        'the title to become the capitalized weekday',
      );

      expect(find.text('11 серпня'), findsOneWidget,
          reason: 'the subtitle drops the weekday already shown in the title');
      expect(find.text('четвер, 13 серпня'), findsNothing);
      expect(tester.takeException(), isNull);

      await tearDownTree(tester, container);
    });

    testWidgets('uk: backToToday appears only off today and clears the '
        'selection when tapped (E5)', (tester) async {
      usePhoneSurface(tester);
      final container = makeContainer(today: pinnedToday);
      await container.read(supplementRepoProvider).upsert(supplement);
      await container.read(regimenRepoProvider).upsert(alwaysActive());

      await tester.pumpWidget(app(container));
      await pumpUntil(
        tester,
        () => find.text('четвер, 13 серпня').evaluate().isNotEmpty,
        'the header to settle on today',
      );

      final button = find.widgetWithText(TextButton, 'Сьогодні');
      expect(button, findsNothing,
          reason: 'no escape hatch is offered while already following today');

      container.read(selectedDayProvider.notifier).select(twoDaysEarlier);
      await pumpUntil(
        tester,
        () => button.evaluate().isNotEmpty,
        'backToToday to appear on a non-today day',
      );

      await tester.tap(button);
      await pumpUntil(
        tester,
        () => find.text('четвер, 13 серпня').evaluate().isNotEmpty,
        'the tap to clear the selection back to today',
      );

      expect(find.text('Сьогодні'), findsOneWidget,
          reason: 'the title is the localized today string again, and the '
              'button (same word) is gone');
      expect(button, findsNothing);
      expect(tester.takeException(), isNull);

      await tearDownTree(tester, container);
    });

    testWidgets('uk: the header sits OUTSIDE the scroll view and survives a '
        'scroll of the body', (tester) async {
      usePhoneSurface(tester);
      final container = makeContainer(today: pinnedToday);
      await container.read(supplementRepoProvider).upsert(supplement);
      await container.read(regimenRepoProvider).upsert(alwaysActive());

      await tester.pumpWidget(app(container));
      await pumpUntil(
        tester,
        () => find.text('четвер, 13 серпня').evaluate().isNotEmpty,
        'the header subtitle',
      );

      expect(
        find.descendant(
          of: find.byType(Scrollable),
          matching: find.text('четвер, 13 серпня'),
        ),
        findsNothing,
        reason: 'the header must never scroll away (UI-SPEC S4)',
      );

      await tester.drag(find.byType(Scrollable).first, const Offset(0, -300));
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('четвер, 13 серпня'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tearDownTree(tester, container);
    });

    testWidgets('uk: the disclaimer closes the scroll body on a day that has '
        'doses', (tester) async {
      usePhoneSurface(tester);
      final container = makeContainer(today: pinnedToday);
      await container.read(supplementRepoProvider).upsert(supplement);
      await container.read(regimenRepoProvider).upsert(alwaysActive());

      await tester.pumpWidget(app(container));
      await pumpUntil(
        tester,
        () => find.text('Магній бісглицинат').evaluate().isNotEmpty,
        'the dose row',
      );

      expect(find.text(disclaimer), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(Scrollable),
          matching: find.text(disclaimer),
        ),
        findsOneWidget,
        reason: 'the disclaimer is the last element INSIDE the scroll body',
      );
      expect(tester.takeException(), isNull);

      await tearDownTree(tester, container);
    });

    // -----------------------------------------------------------------
    // The weekday title's sentence casing, pinned byte-for-byte before and
    // after the intl swap (plan 05-02, UI-SPEC A3 / PF-6).
    // -----------------------------------------------------------------

    /// The consequence of a red case, named in device terms.
    const casingReason =
        'the day header is the first line of the screen: a weekday that '
        'renders lowercase (or mis-cased) there is a visible regression in a '
        'SHIPPED language. This pair pins the exact strings so swapping the '
        'casing implementation is provably a no-op for uk and en — the A7 '
        'fallback is to keep the old helper, never to relax this assertion';

    for (final locale in const ['uk', 'en']) {
      final weekdayTitle = locale == 'uk' ? 'Вівторок' : 'Tuesday';
      final subtitleOffToday = locale == 'uk' ? '11 серпня' : '11 August';

      testWidgets(
          '$locale: a non-today day titles the SENTENCE-CASED weekday, pinned '
          'byte-for-byte (A3)', (tester) async {
        usePhoneSurface(tester);
        final container = makeContainer(today: pinnedToday);
        await container.read(supplementRepoProvider).upsert(supplement);
        await container.read(regimenRepoProvider).upsert(alwaysActive());

        await tester.pumpWidget(app(container, locale: Locale(locale)));
        await pumpUntil(
          tester,
          () => find.byType(DayProgressRing).evaluate().isNotEmpty,
          'the header to settle on today',
        );

        container.read(selectedDayProvider.notifier).select(twoDaysEarlier);
        await pumpUntil(
          tester,
          () => find.text(weekdayTitle).evaluate().isNotEmpty,
          'the title to become the sentence-cased weekday',
        );

        expect(find.text(weekdayTitle), findsOneWidget, reason: casingReason);
        expect(find.text(subtitleOffToday), findsOneWidget,
            reason: 'the subtitle drops the weekday already in the title, and '
                'is locale-formatted rather than assembled in Dart');
        expect(find.text(weekdayTitle.toLowerCase()), findsNothing,
            reason: 'intl returns uk weekdays lowercase — an uncased title is '
                'exactly the regression this pins');
        expect(tester.takeException(), isNull);

        await tearDownTree(tester, container);
      });
    }
  });

  // --- Time blocks (plan 03-04, Task 1; UI-SPEC S4 "Scroll body",
  // DECIDED-1 / DECIDED-6, M5) ---
  //
  // Both clocks are pinned in every test here: `today` fixes the date and
  // `nowMinutes` fixes the minute ticker, so "current block", "past block" and
  // the warn progress tag are deterministic rather than a function of when the
  // suite runs. The ticker means the tree NEVER settles — `pump(Duration)`
  // loops only, `tearDownTree` in every body.
  group('blocks', () {
    final pinnedToday = DateTime.utc(2026, 8, 13);
    final pastDay = DateTime.utc(2026, 8, 11);

    Supplement supp(String id, String name) => Supplement(
          id: id,
          name: name,
          doseText: '',
          colorValue: 0xFF6B6FA8,
          note: '',
        );

    Regimen reg(
      String id,
      String supplementId,
      List<DoseSlot> slots, {
      bool paused = false,
    }) =>
        Regimen(
          id: id,
          supplementId: supplementId,
          kind: RegimenKind.cyclic,
          startDate: DateTime.utc(2020, 1, 1),
          endDate: null,
          onDays: 1,
          offDays: 0,
          paused: paused,
          slots: slots,
        );

    testWidgets('uk: only non-empty blocks render, in chronological order '
        '(DECIDED-1)', (tester) async {
      usePhoneSurface(tester);
      final container = makeContainer(today: pinnedToday, nowMinutes: 600);
      await container.read(supplementRepoProvider).upsert(supp('s1', 'Магній'));
      await container.read(supplementRepoProvider).upsert(supp('s2', 'Цинк'));
      await container.read(regimenRepoProvider).upsert(reg('r1', 's1', const [
            DoseSlot(id: 'sl1', minutesFromMidnight: 480, doseLabel: ''),
          ]));
      await container.read(regimenRepoProvider).upsert(reg('r2', 's2', const [
            DoseSlot(id: 'sl2', minutesFromMidnight: 1140, doseLabel: ''),
          ]));

      await tester.pumpWidget(app(container));
      await pumpUntil(
        tester,
        () => find.text('Ранок').evaluate().isNotEmpty,
        'the morning block header',
      );

      expect(find.byType(DayBlockSection), findsNWidgets(2),
          reason: 'a day with morning and evening doses renders exactly two '
              'blocks — the two empty ones are omitted entirely');
      expect(find.text('Вечір'), findsOneWidget);
      expect(find.text('День'), findsNothing,
          reason: 'an empty block renders nothing at all — no header, no '
              'placeholder row');
      expect(find.text('Ніч'), findsNothing);
      expect(
        tester.getTopLeft(find.text('Ранок')).dy <
            tester.getTopLeft(find.text('Вечір')).dy,
        isTrue,
        reason: 'blocks render in block order, morning first',
      );
      expect(tester.takeException(), isNull);

      await tearDownTree(tester, container);
    });

    testWidgets('uk: the block header shows the EARLIEST REAL slot time, not '
        'the mockup anchor (M5)', (tester) async {
      usePhoneSurface(tester);
      final container = makeContainer(today: pinnedToday, nowMinutes: 600);
      await container.read(supplementRepoProvider).upsert(supp('s1', 'Магній'));
      await container.read(regimenRepoProvider).upsert(reg('r1', 's1', const [
            DoseSlot(id: 'sl1', minutesFromMidnight: 570, doseLabel: ''),
            DoseSlot(id: 'sl2', minutesFromMidnight: 660, doseLabel: ''),
          ]));

      await tester.pumpWidget(app(container));
      await pumpUntil(
        tester,
        () => find.text('Ранок').evaluate().isNotEmpty,
        'the morning block header',
      );

      expect(find.text('09:30'), findsOneWidget,
          reason: 'the header time is the earliest slot actually in the block');
      expect(find.text('08:00'), findsNothing,
          reason: "printing the mockup's 08:00 anchor above a 09:30 block "
              'would be false information (M5)');
      expect(find.text('11:00'), findsNothing,
          reason: 'only the earliest slot time heads the block');
      expect(tester.takeException(), isNull);

      await tearDownTree(tester, container);
    });

    testWidgets('uk: on today ONLY the current block header time is accented',
        (tester) async {
      usePhoneSurface(tester);
      // 10:00: the 09:30 morning block has fully passed, the 19:00 evening
      // block has not — so evening is the current block.
      final container = makeContainer(today: pinnedToday, nowMinutes: 600);
      await container.read(supplementRepoProvider).upsert(supp('s1', 'Магній'));
      await container.read(supplementRepoProvider).upsert(supp('s2', 'Цинк'));
      await container.read(regimenRepoProvider).upsert(reg('r1', 's1', const [
            DoseSlot(id: 'sl1', minutesFromMidnight: 570, doseLabel: ''),
          ]));
      await container.read(regimenRepoProvider).upsert(reg('r2', 's2', const [
            DoseSlot(id: 'sl2', minutesFromMidnight: 1140, doseLabel: ''),
          ]));

      await tester.pumpWidget(app(container));
      await pumpUntil(
        tester,
        () => find.text('19:00').evaluate().isNotEmpty,
        'both block headers',
      );

      expect(tester.widget<Text>(find.text('19:00')).style?.color,
          BqColors.accent,
          reason: 'the current block leads the day in the accent color (P-5)');
      expect(tester.widget<Text>(find.text('09:30')).style?.color, BqColors.ink,
          reason: 'a past block keeps the neutral ink time');
      expect(tester.takeException(), isNull);

      await tearDownTree(tester, container);
    });

    testWidgets('uk: on a NON-today day no header time is accented',
        (tester) async {
      usePhoneSurface(tester);
      final container = makeContainer(today: pinnedToday, nowMinutes: 600);
      await container.read(supplementRepoProvider).upsert(supp('s1', 'Магній'));
      await container.read(regimenRepoProvider).upsert(reg('r1', 's1', const [
            DoseSlot(id: 'sl1', minutesFromMidnight: 1140, doseLabel: ''),
          ]));

      await tester.pumpWidget(app(container));
      await pumpUntil(
        tester,
        () => find.text('19:00').evaluate().isNotEmpty,
        "today's evening block",
      );
      expect(tester.widget<Text>(find.text('19:00')).style?.color,
          BqColors.accent);

      container.read(selectedDayProvider.notifier).select(pastDay);
      await pumpUntil(
        tester,
        () => find.text('11 серпня').evaluate().isNotEmpty,
        'the browsed past day',
      );
      // The past day re-materializes through its own stream; let it land
      // before reading the header color back.
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }

      expect(find.text('19:00'), findsOneWidget,
          reason: 'the past day carries the same 19:00 block');
      expect(tester.widget<Text>(find.text('19:00')).style?.color, BqColors.ink,
          reason: 'the accent header time is a today-only treatment');
      expect(tester.takeException(), isNull);

      await tearDownTree(tester, container);
    });

    testWidgets('uk: a fully-taken block shows the calm all-taken tag',
        (tester) async {
      usePhoneSurface(tester);
      // 06:40 — the 08:00 block has NOT passed, so the untouched block shows
      // its plain meal tag rather than the progress tag.
      final container = makeContainer(today: pinnedToday, nowMinutes: 400);
      await container.read(supplementRepoProvider).upsert(supp('s1', 'Магній'));
      await container.read(regimenRepoProvider).upsert(reg('r1', 's1', const [
            DoseSlot(id: 'sl1', minutesFromMidnight: 480, doseLabel: ''),
          ]));

      await tester.pumpWidget(app(container));
      final row = find.text('Магній');
      await pumpUntil(tester, () => row.evaluate().isNotEmpty, 'the dose row');

      expect(find.text('зі сніданком'), findsOneWidget,
          reason: 'an unhandled, not-yet-due block shows its neutral meal tag');

      await tester.tap(row);
      await pumpUntil(
        tester,
        () => find.text('усе прийнято').evaluate().isNotEmpty,
        'the all-taken block tag',
      );

      expect(tester.widget<Text>(find.text('усе прийнято')).style?.color,
          BqColors.calm,
          reason: 'all-taken is the calm treatment (DECIDED-6)');
      expect(find.text('зі сніданком'), findsNothing);
      expect(tester.takeException(), isNull);

      await tearDownTree(tester, container);
    });

    testWidgets('uk: a block where every dose is marked and one is skipped '
        'shows the NEUTRAL all-marked tag (DECIDED-6)', (tester) async {
      usePhoneSurface(tester);
      final container = makeContainer(today: pinnedToday, nowMinutes: 600);
      await container.read(supplementRepoProvider).upsert(supp('s1', 'Магній'));
      await container.read(regimenRepoProvider).upsert(reg('r1', 's1', const [
            DoseSlot(id: 'sl1', minutesFromMidnight: 480, doseLabel: 'перша'),
            DoseSlot(id: 'sl2', minutesFromMidnight: 540, doseLabel: 'друга'),
          ]));

      await tester.pumpWidget(app(container));
      await pumpUntil(
        tester,
        () => find.text('перша').evaluate().isNotEmpty,
        'both dose rows',
      );

      var raw = <IntakeLog>[];
      final rawSub = rawLogsFor(pinnedToday).listen((v) => raw = v);
      await pumpUntil(tester, () => raw.length == 2, 'both materialized logs');

      final intake = container.read(intakeRepoProvider);
      unawaited(intake.setStatus(
          raw.firstWhere((r) => r.slotId == 'sl1').id, DoseStatus.taken));
      unawaited(intake.setStatus(
          raw.firstWhere((r) => r.slotId == 'sl2').id, DoseStatus.skipped));
      await pumpUntil(
        tester,
        () => find.text('усе відмічено').evaluate().isNotEmpty,
        'the all-marked block tag',
      );

      expect(tester.widget<Text>(find.text('усе відмічено')).style?.color,
          BqColors.textSecondary,
          reason: 'a block holding a skip must not claim everything was taken '
              'and must not be warn-framed');
      expect(find.text('усе прийнято'), findsNothing);
      expect(tester.takeException(), isNull);
      // ignore: unawaited_futures
      rawSub.cancel();
      await tester.pump(const Duration(milliseconds: 10));
      await tearDownTree(tester, container);
    });

    testWidgets("uk: a PAST block of today with a pending dose shows the warn "
        '{done} з {total} tag', (tester) async {
      usePhoneSurface(tester);
      // 20:00 — the whole morning block has passed.
      final container = makeContainer(today: pinnedToday, nowMinutes: 1200);
      await container.read(supplementRepoProvider).upsert(supp('s1', 'Магній'));
      await container.read(regimenRepoProvider).upsert(reg('r1', 's1', const [
            DoseSlot(id: 'sl1', minutesFromMidnight: 480, doseLabel: 'перша'),
            DoseSlot(id: 'sl2', minutesFromMidnight: 540, doseLabel: 'друга'),
          ]));

      await tester.pumpWidget(app(container));
      await pumpUntil(
        tester,
        () => find.text('перша').evaluate().isNotEmpty,
        'both dose rows',
      );

      expect(find.text('0 з 2'), findsOneWidget,
          reason: 'a past block of today with pending doses reports progress');

      await tester.tap(find.text('Магній').first);
      await pumpUntil(
        tester,
        () => find.text('1 з 2').evaluate().isNotEmpty,
        'the progress tag to follow the write',
      );

      expect(tester.widget<Text>(find.text('1 з 2')).style?.color,
          BqColors.warn,
          reason: 'the progress tag is the warn treatment — today only '
              '(DECIDED-5)');
      expect(tester.takeException(), isNull);

      await tearDownTree(tester, container);
    });

    testWidgets('uk: a paused regimen contributes NO pending row and no '
        'placeholder, while its taken row still renders (PF-9)',
        (tester) async {
      usePhoneSurface(tester);
      final container = makeContainer(today: pinnedToday, nowMinutes: 600);
      await container.read(supplementRepoProvider).upsert(supp('s1', 'Магній'));
      await container.read(regimenRepoProvider).upsert(reg('r1', 's1', const [
            DoseSlot(id: 'sl1', minutesFromMidnight: 480, doseLabel: 'перша'),
            DoseSlot(id: 'sl2', minutesFromMidnight: 540, doseLabel: 'друга'),
          ]));

      await tester.pumpWidget(app(container));
      await pumpUntil(
        tester,
        () => find.text('друга').evaluate().isNotEmpty,
        'both dose rows',
      );

      var raw = <IntakeLog>[];
      final rawSub = rawLogsFor(pinnedToday).listen((v) => raw = v);
      await pumpUntil(tester, () => raw.length == 2, 'both materialized logs');

      unawaited(container.read(intakeRepoProvider).setStatus(
          raw.firstWhere((r) => r.slotId == 'sl1').id, DoseStatus.taken));
      await pumpUntil(
        tester,
        () => raw.any((r) => r.status == DoseStatus.taken),
        'the first dose to be taken',
      );

      unawaited(container.read(regimenRepoProvider).upsert(reg(
            'r1',
            's1',
            const [
              DoseSlot(id: 'sl1', minutesFromMidnight: 480, doseLabel: 'перша'),
              DoseSlot(id: 'sl2', minutesFromMidnight: 540, doseLabel: 'друга'),
            ],
            paused: true,
          )));
      await pumpUntil(
        tester,
        () => find.text('друга').evaluate().isEmpty,
        "the paused regimen's pending row to disappear",
      );

      expect(find.text('перша'), findsOneWidget,
          reason: 'already-taken history stays visible while paused');
      expect(find.text('Ранок'), findsOneWidget,
          reason: 'the block itself still renders for the surviving row');
      expect(raw.length, 2,
          reason: 'the pending row is filtered by the QUERY — nothing is '
              'deleted and no placeholder stands in for it');
      expect(tester.takeException(), isNull);
      // ignore: unawaited_futures
      rawSub.cancel();
      await tester.pump(const Duration(milliseconds: 10));
      await tearDownTree(tester, container);
    });
  });

  // --- Dose-row states and gestures (plan 03-04, Task 2; UI-SPEC S4 row
  // table, DECIDED-2/3/5, T-03-02 / T-03-13 / T-03-14) ---
  //
  // Every state assertion reads the ROW's own decorated Container and the
  // name Text back out of the tree, so a state that merely "looks close" in a
  // screenshot cannot pass. Raw statuses are read through the pump-driven
  // `db.select(db.intakeLogs)` watch, never an un-pumped await.
  group('dose row', () {
    final pinnedToday = DateTime.utc(2026, 8, 13);
    final pastDay = DateTime.utc(2026, 8, 11);
    final futureDay = DateTime.utc(2026, 8, 14);

    Supplement supp(String name, {String note = ''}) => Supplement(
          id: 's1',
          name: name,
          doseText: '',
          colorValue: 0xFF6B6FA8,
          note: note,
        );

    Regimen reg(List<DoseSlot> slots) => Regimen(
          id: 'r1',
          supplementId: 's1',
          kind: RegimenKind.cyclic,
          startDate: DateTime.utc(2020, 1, 1),
          endDate: null,
          onDays: 1,
          offDays: 0,
          paused: false,
          slots: slots,
        );

    const oneMorningSlot = [
      DoseSlot(id: 'sl1', minutesFromMidnight: 480, doseLabel: '400 мг'),
    ];

    /// The dose row's own decoration — the outermost Container inside DoseRow.
    BoxDecoration rowDecoration(WidgetTester tester) =>
        tester.widget<Container>(find
            .descendant(of: find.byType(DoseRow), matching: find.byType(Container))
            .first).decoration! as BoxDecoration;

    /// The row's 24px state circle (the second Container in the row).
    BoxDecoration circleDecoration(WidgetTester tester) =>
        tester.widget<Container>(find
            .descendant(of: find.byType(DoseRow), matching: find.byType(Container))
            .at(1)).decoration! as BoxDecoration;

    TextStyle nameStyle(WidgetTester tester, String name) =>
        tester.widget<Text>(find.text(name)).style!;

    testWidgets('uk: a not-yet-due pending dose on today renders the empty '
        'circle, ink name, surface fill and NO state chip', (tester) async {
      usePhoneSurface(tester);
      final container = makeContainer(today: pinnedToday, nowMinutes: 400);
      await container.read(supplementRepoProvider).upsert(supp('Магній'));
      await container.read(regimenRepoProvider).upsert(reg(oneMorningSlot));

      await tester.pumpWidget(app(container));
      await pumpUntil(
        tester,
        () => find.text('Магній').evaluate().isNotEmpty,
        'the dose row',
      );

      expect(circleDecoration(tester).color, BqColors.surface);
      expect(find.text('✓'), findsNothing);
      expect(find.text('−'), findsNothing);
      expect(nameStyle(tester, 'Магній').color, BqColors.ink);
      expect(nameStyle(tester, 'Магній').decoration, isNot(
          TextDecoration.lineThrough));
      final deco = rowDecoration(tester);
      expect(deco.color, BqColors.surface);
      expect((deco.border! as Border).top.color, BqColors.cardBorder);
      expect(find.text('не прийнято вчасно'), findsNothing);
      expect(find.text('пропущено'), findsNothing);
      expect(find.text('не позначено'), findsNothing);
      expect(tester.takeException(), isNull);

      await tearDownTree(tester, container);
    });

    testWidgets('uk: once its slot time passes on today the SAME dose renders '
        'the warn border and the overdue chip (DECIDED-5)', (tester) async {
      usePhoneSurface(tester);
      final container = makeContainer(today: pinnedToday, nowMinutes: 600);
      await container.read(supplementRepoProvider).upsert(supp('Магній'));
      await container.read(regimenRepoProvider).upsert(reg(oneMorningSlot));

      await tester.pumpWidget(app(container));
      await pumpUntil(
        tester,
        () => find.text('Магній').evaluate().isNotEmpty,
        'the dose row',
      );

      expect(find.text('не прийнято вчасно'), findsOneWidget);
      expect((rowDecoration(tester).border! as Border).top.color,
          BqColors.warnBorder);
      expect(circleDecoration(tester).color, BqColors.surface,
          reason: 'overdue differs from pending by the row border and the '
              'chip alone — the circle is untouched');
      expect(nameStyle(tester, 'Магній').color, BqColors.ink);
      expect(tester.takeException(), isNull);

      await tearDownTree(tester, container);
    });

    testWidgets('uk: on a day OTHER than today that same pending dose renders '
        'neither the overdue chip nor the warn border', (tester) async {
      usePhoneSurface(tester);
      final container = makeContainer(today: pinnedToday, nowMinutes: 600);
      await container.read(supplementRepoProvider).upsert(supp('Магній'));
      await container.read(regimenRepoProvider).upsert(reg(oneMorningSlot));

      await tester.pumpWidget(app(container));
      await pumpUntil(
        tester,
        () => find.text('не прийнято вчасно').evaluate().isNotEmpty,
        'the overdue treatment on today',
      );

      container.read(selectedDayProvider.notifier).select(futureDay);
      await pumpUntil(
        tester,
        () => find.text('14 серпня').evaluate().isNotEmpty,
        'the browsed future day',
      );
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }

      expect(find.text('Магній'), findsOneWidget);
      expect(find.text('не прийнято вчасно'), findsNothing,
          reason: 'overdue is a today-only derivation (isOverdue is gated on '
              'viewingToday)');
      expect(find.text('не позначено'), findsNothing,
          reason: 'a future day is not missed either — the two are mutually '
              'exclusive and neither applies here');
      expect((rowDecoration(tester).border! as Border).top.color,
          BqColors.cardBorder);
      expect(tester.takeException(), isNull);

      await tearDownTree(tester, container);
    });

    testWidgets('uk: a taken dose renders the calm circle with the check '
        'glyph, a struck muted name and the alternate fill', (tester) async {
      usePhoneSurface(tester);
      final container = makeContainer(today: pinnedToday, nowMinutes: 400);
      await container.read(supplementRepoProvider).upsert(supp('Магній'));
      await container.read(regimenRepoProvider).upsert(reg(oneMorningSlot));

      await tester.pumpWidget(app(container));
      final row = find.text('Магній');
      await pumpUntil(tester, () => row.evaluate().isNotEmpty, 'the dose row');

      await tester.tap(row);
      await pumpUntil(
        tester,
        () => find.text('✓').evaluate().isNotEmpty,
        'the taken visual',
      );

      expect(circleDecoration(tester).color, BqColors.calm);
      expect(nameStyle(tester, 'Магній').color, BqColors.textMuted);
      expect(nameStyle(tester, 'Магній').decoration, TextDecoration.lineThrough);
      expect(rowDecoration(tester).color, BqColors.surfaceAlt);
      expect(find.text('пропущено'), findsNothing);
      expect(tester.takeException(), isNull);

      await tearDownTree(tester, container);
    });

    testWidgets('uk: a skipped dose renders the neutral circle with the minus '
        'glyph, a struck name and the skipped chip', (tester) async {
      usePhoneSurface(tester);
      final container = makeContainer(today: pinnedToday, nowMinutes: 400);
      await container.read(supplementRepoProvider).upsert(supp('Магній'));
      await container.read(regimenRepoProvider).upsert(reg(oneMorningSlot));

      await tester.pumpWidget(app(container));
      await pumpUntil(
        tester,
        () => find.text('Магній').evaluate().isNotEmpty,
        'the dose row',
      );

      var raw = <IntakeLog>[];
      final rawSub = rawLogsFor(pinnedToday).listen((v) => raw = v);
      await pumpUntil(tester, () => raw.length == 1, 'the materialized log');

      unawaited(container
          .read(intakeRepoProvider)
          .setStatus(raw.single.id, DoseStatus.skipped));
      await pumpUntil(
        tester,
        () => find.text('пропущено').evaluate().isNotEmpty,
        'the skipped visual',
      );

      expect(find.text('−'), findsOneWidget);
      expect(circleDecoration(tester).color, BqColors.chip);
      expect(nameStyle(tester, 'Магній').decoration, TextDecoration.lineThrough);
      expect(rowDecoration(tester).color, BqColors.surfaceAlt);
      expect(tester.takeException(), isNull);
      // ignore: unawaited_futures
      rawSub.cancel();
      await tester.pump(const Duration(milliseconds: 10));
      await tearDownTree(tester, container);
    });

    testWidgets('uk: a pending dose on a PAST day renders the live pending '
        'visual plus the neutral not-marked chip, and stays tappable '
        '(DECIDED-3)', (tester) async {
      usePhoneSurface(tester);
      final container = makeContainer(today: pinnedToday, nowMinutes: 600);
      await container.read(supplementRepoProvider).upsert(supp('Магній'));
      await container.read(regimenRepoProvider).upsert(reg(oneMorningSlot));

      await tester.pumpWidget(app(container));
      await pumpUntil(
        tester,
        () => find.text('Магній').evaluate().isNotEmpty,
        'the dose row on today',
      );

      container.read(selectedDayProvider.notifier).select(pastDay);
      await pumpUntil(
        tester,
        () => find.text('не позначено').evaluate().isNotEmpty,
        'the missed treatment on the past day',
      );

      expect(nameStyle(tester, 'Магній').color, BqColors.ink,
          reason: 'the row stays visually live — no dead-grey name');
      expect(nameStyle(tester, 'Магній').decoration, isNot(
          TextDecoration.lineThrough));
      expect(circleDecoration(tester).color, BqColors.surface);
      final deco = rowDecoration(tester);
      expect(deco.color, BqColors.surface);
      expect((deco.border! as Border).top.color, BqColors.cardBorder,
          reason: 'no warn, no risk color anywhere on a past day (TRACK-03)');
      expect(find.text('не прийнято вчасно'), findsNothing,
          reason: 'missed and overdue can never render together');

      var raw = <IntakeLog>[];
      final rawSub = rawLogsFor(pastDay).listen((v) => raw = v);
      await pumpUntil(tester, () => raw.isNotEmpty, 'the past day log');
      await tester.tap(find.text('Магній'));
      await pumpUntil(
        tester,
        () => raw.any((r) => r.status == DoseStatus.taken),
        'the late correction to persist — a missed row is still tappable',
      );

      expect(tester.takeException(), isNull);
      // ignore: unawaited_futures
      rawSub.cancel();
      await tester.pump(const Duration(milliseconds: 10));
      await tearDownTree(tester, container);
    });

    testWidgets('uk: a regimen with three doses that day renders positions '
        '1, 2 and 3 of 3 in slot order (PF-6)', (tester) async {
      usePhoneSurface(tester);
      final container = makeContainer(today: pinnedToday, nowMinutes: 400);
      await container.read(supplementRepoProvider).upsert(supp('Магній'));
      await container.read(regimenRepoProvider).upsert(reg(const [
            DoseSlot(id: 'sl1', minutesFromMidnight: 480, doseLabel: ''),
            DoseSlot(id: 'sl2', minutesFromMidnight: 540, doseLabel: ''),
            DoseSlot(id: 'sl3', minutesFromMidnight: 600, doseLabel: ''),
          ]));

      await tester.pumpWidget(app(container));
      await pumpUntil(
        tester,
        () => find.text('доза 3 з 3').evaluate().isNotEmpty,
        'the cycle chips',
      );

      expect(find.text('доза 1 з 3'), findsOneWidget);
      expect(find.text('доза 2 з 3'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('доза 1 з 3')).dy <
            tester.getTopLeft(find.text('доза 2 з 3')).dy,
        isTrue,
        reason: 'positions follow slot-time order',
      );
      expect(tester.takeException(), isNull);

      await tearDownTree(tester, container);
    });

    testWidgets('uk: a single dose that day renders NO cycle chip',
        (tester) async {
      usePhoneSurface(tester);
      final container = makeContainer(today: pinnedToday, nowMinutes: 400);
      await container.read(supplementRepoProvider).upsert(supp('Магній'));
      await container.read(regimenRepoProvider).upsert(reg(oneMorningSlot));

      await tester.pumpWidget(app(container));
      await pumpUntil(
        tester,
        () => find.text('Магній').evaluate().isNotEmpty,
        'the dose row',
      );

      expect(find.text('доза 1 з 1'), findsNothing,
          reason: 'the chip is zero-information at m == 1');
      expect(tester.takeException(), isNull);

      await tearDownTree(tester, container);
    });

    testWidgets('uk: a user note renders as a chip AFTER the cycle chip and '
        'BEFORE the state chip; an empty note renders none', (tester) async {
      usePhoneSurface(tester);
      final container = makeContainer(today: pinnedToday, nowMinutes: 600);
      await container
          .read(supplementRepoProvider)
          .upsert(supp('Магній', note: 'з їжею'));
      await container.read(regimenRepoProvider).upsert(reg(const [
            DoseSlot(id: 'sl1', minutesFromMidnight: 480, doseLabel: ''),
            DoseSlot(id: 'sl2', minutesFromMidnight: 490, doseLabel: ''),
          ]));

      await tester.pumpWidget(app(container));
      await pumpUntil(
        tester,
        () => find.text('з їжею').evaluate().isNotEmpty,
        'the note chips',
      );

      // Reading order inside the Wrap: earlier run first, then start-to-end
      // within a run — a chip pushed onto a second line is still "after".
      bool before(Offset a, Offset b) =>
          a.dy < b.dy || (a.dy == b.dy && a.dx < b.dx);
      final cycle = tester.getTopLeft(find.text('доза 1 з 2'));
      final note = tester.getTopLeft(find.text('з їжею').first);
      final state = tester.getTopLeft(find.text('не прийнято вчасно').first);
      expect(before(cycle, note), isTrue,
          reason: 'the cycle chip leads the persistent chips');
      expect(before(note, state), isTrue,
          reason: 'the state chip always closes the chip row');

      // An empty note contributes nothing at all.
      unawaited(
          container.read(supplementRepoProvider).upsert(supp('Магній')));
      await pumpUntil(
        tester,
        () => find.text('з їжею').evaluate().isEmpty,
        'the note chip to disappear when the note is cleared',
      );
      expect(tester.takeException(), isNull);

      await tearDownTree(tester, container);
    });

    testWidgets('uk: the longest realistic uk name plus three chips does not '
        'overflow a 390pt row (E2 long-text)', (tester) async {
      usePhoneSurface(tester);
      final container = makeContainer(today: pinnedToday, nowMinutes: 600);
      await container.read(supplementRepoProvider).upsert(supp(
            'Вітамін B12 метилкобаламін',
            note: 'не разом із цинком',
          ));
      await container.read(regimenRepoProvider).upsert(reg(const [
            DoseSlot(
              id: 'sl1',
              minutesFromMidnight: 480,
              doseLabel: '1000 мкг · сублінгвально',
            ),
            DoseSlot(id: 'sl2', minutesFromMidnight: 490, doseLabel: '1000 мкг'),
            DoseSlot(id: 'sl3', minutesFromMidnight: 500, doseLabel: '1000 мкг'),
          ]));

      await tester.pumpWidget(app(container));
      await pumpUntil(
        tester,
        () => find.text('доза 3 з 3').evaluate().isNotEmpty,
        'the fully-loaded rows',
      );

      expect(find.text('Вітамін B12 метилкобаламін'), findsNWidgets(3));
      expect(find.text('не разом із цинком'), findsNWidgets(3));
      expect(find.text('не прийнято вчасно'), findsNWidgets(3));
      expect(tester.takeException(), isNull,
          reason: 'no RenderFlex overflow at 390pt with the longest uk name '
              'and a full chip stack');

      await tearDownTree(tester, container);
    });

    testWidgets('uk: tapping a SKIPPED row writes taken (DECIDED-2 tap '
        'column)', (tester) async {
      usePhoneSurface(tester);
      final container = makeContainer(today: pinnedToday, nowMinutes: 400);
      await container.read(supplementRepoProvider).upsert(supp('Магній'));
      await container.read(regimenRepoProvider).upsert(reg(oneMorningSlot));

      await tester.pumpWidget(app(container));
      await pumpUntil(
        tester,
        () => find.text('Магній').evaluate().isNotEmpty,
        'the dose row',
      );

      var raw = <IntakeLog>[];
      final rawSub = rawLogsFor(pinnedToday).listen((v) => raw = v);
      await pumpUntil(tester, () => raw.length == 1, 'the materialized log');

      unawaited(container
          .read(intakeRepoProvider)
          .setStatus(raw.single.id, DoseStatus.skipped));
      await pumpUntil(
        tester,
        () => find.text('пропущено').evaluate().isNotEmpty,
        'the skipped visual',
      );

      await tester.tap(find.text('Магній'));
      await pumpUntil(
        tester,
        () => raw.single.status == DoseStatus.taken,
        'the tap on a skipped row to write taken',
      );

      expect(tester.takeException(), isNull);
      // ignore: unawaited_futures
      rawSub.cancel();
      await tester.pump(const Duration(milliseconds: 10));
      await tearDownTree(tester, container);
    });

    testWidgets('uk: a failed write leaves the row at its previous status and '
        'surfaces markFailed once (T-03-13)', (tester) async {
      usePhoneSurface(tester);
      final container = ProviderContainer(overrides: [
        dbProvider.overrideWith((ref) {
          final database = BoostqueDb.forTesting(NativeDatabase.memory());
          ref.onDispose(database.close);
          db = database;
          return database;
        }),
        todayProvider.overrideWith(() => _FixedToday(pinnedToday)),
        nowMinutesProvider.overrideWith((ref) => Stream.value(400)),
        intakeRepoProvider.overrideWith((ref) => _FailingIntakeRepo(
              DriftIntakeRepository(
                ref.watch(dbProvider),
                regimens: ref.watch(regimenRepoProvider),
              ),
            )),
      ]);
      await container.read(supplementRepoProvider).upsert(supp('Магній'));
      await container.read(regimenRepoProvider).upsert(reg(oneMorningSlot));

      await tester.pumpWidget(app(container));
      final row = find.text('Магній');
      await pumpUntil(tester, () => row.evaluate().isNotEmpty, 'the dose row');

      var raw = <IntakeLog>[];
      final rawSub = rawLogsFor(pinnedToday).listen((v) => raw = v);
      await pumpUntil(tester, () => raw.length == 1, 'the materialized log');

      await tester.tap(row);
      await pumpUntil(
        tester,
        () => find.text('Не вдалося зберегти позначку.').evaluate().isNotEmpty,
        'the markFailed feedback',
      );

      expect(find.text('Не вдалося зберегти позначку.'), findsOneWidget,
          reason: 'the failure is surfaced exactly once');
      expect(raw.single.status, DoseStatus.pending,
          reason: 'nothing was written');
      expect(find.text('✓'), findsNothing,
          reason: 'no optimistic-then-reverted visual — the stream is the '
              'only source of truth');
      expect(nameStyle(tester, 'Магній').color, BqColors.ink);
      expect(tester.takeException(), isNull);
      // ignore: unawaited_futures
      rawSub.cancel();
      await tester.pump(const Duration(milliseconds: 10));
      await tearDownTree(tester, container);
    });
  });

  // --- Dose action sheet (plan 03-04, Task 3; UI-SPEC S5, DECIDED-2) ---
  //
  // The sheet is a CHOOSER: every assertion below is about which actions it
  // offers and what the RAW database row becomes afterwards. The sheet itself
  // performs no write — `DoseRow._apply` does, through the same guard tap uses.
  group('dose action sheet', () {
    final pinnedToday = DateTime.utc(2026, 8, 13);

    const markTaken = 'Позначити прийнято';
    const markSkipped = 'Позначити пропущено';
    const undoMark = 'Зняти позначку';

    const supplement = Supplement(
      id: 's1',
      name: 'Магній',
      doseText: '',
      colorValue: 0xFF6B6FA8,
      note: '',
    );

    Regimen reg() => Regimen(
          id: 'r1',
          supplementId: 's1',
          kind: RegimenKind.cyclic,
          startDate: DateTime.utc(2020, 1, 1),
          endDate: null,
          onDays: 1,
          offDays: 0,
          paused: false,
          slots: const [
            DoseSlot(id: 'sl1', minutesFromMidnight: 480, doseLabel: '400 мг'),
          ],
        );

    /// Pumps the screen, waits for the single dose row, and returns a live
    /// view of the raw log table plus its subscription.
    Future<(Finder, List<IntakeLog> Function(), StreamSubscription<void>)>
        pumpRow(WidgetTester tester, ProviderContainer container) async {
      await tester.pumpWidget(app(container));
      final row = find.text('Магній');
      await pumpUntil(tester, () => row.evaluate().isNotEmpty, 'the dose row');
      var raw = <IntakeLog>[];
      final sub = rawLogsFor(pinnedToday).listen((v) => raw = v);
      await pumpUntil(tester, () => raw.length == 1, 'the materialized log');
      return (row, () => raw, sub);
    }

    testWidgets('uk: long-pressing a PENDING row offers mark-taken and '
        'mark-skipped, with no undo row', (tester) async {
      usePhoneSurface(tester);
      final container = makeContainer(today: pinnedToday, nowMinutes: 400);
      await container.read(supplementRepoProvider).upsert(supplement);
      await container.read(regimenRepoProvider).upsert(reg());
      final (row, _, sub) = await pumpRow(tester, container);

      await tester.longPress(row);
      await pumpUntil(
        tester,
        () => find.text(markTaken).evaluate().isNotEmpty,
        'the action sheet',
      );

      expect(find.text(markSkipped), findsOneWidget);
      expect(find.text(undoMark), findsNothing,
          reason: 'there is nothing to undo on a pending dose — the row is '
              'absent, never disabled');
      expect(find.text('Магній'), findsNWidgets(2),
          reason: 'the sheet header repeats the supplement name');
      expect(find.text('08:00 · 400 мг'), findsOneWidget,
          reason: 'the mono subtitle composes the 24-hour slot time with the '
              "slot's dose label");
      expect(tester.takeException(), isNull);
      // ignore: unawaited_futures
      sub.cancel();
      await tester.pump(const Duration(milliseconds: 10));
      await tearDownTree(tester, container);
    });

    testWidgets('uk: a slot with NO dose label gets a time-only subtitle — no '
        'dangling separator (WR-07)', (tester) async {
      usePhoneSurface(tester);
      final container = makeContainer(today: pinnedToday, nowMinutes: 400);
      await container.read(supplementRepoProvider).upsert(supplement);
      await container.read(regimenRepoProvider).upsert(Regimen(
            id: 'r1',
            supplementId: 's1',
            kind: RegimenKind.cyclic,
            startDate: DateTime.utc(2020, 1, 1),
            endDate: null,
            onDays: 1,
            offDays: 0,
            paused: false,
            slots: const [
              DoseSlot(id: 'sl1', minutesFromMidnight: 480, doseLabel: ''),
            ],
          ));
      final (row, _, sub) = await pumpRow(tester, container);

      await tester.longPress(row);
      await pumpUntil(
        tester,
        () => find.text(markTaken).evaluate().isNotEmpty,
        'the action sheet',
      );

      expect(find.text('08:00'), findsNWidgets(2),
          reason: 'the sheet subtitle is the bare slot time, alongside the '
              "block header's — the dose label is optional and the separator "
              'belongs to the string, so an empty label drops it too');
      expect(find.textContaining('·'), findsNothing,
          reason: '"08:00 · " with a trailing middle dot is not a string the '
              'user may ever see (the row already guards this)');
      expect(tester.takeException(), isNull);

      // ignore: unawaited_futures
      sub.cancel();
      await tester.pump(const Duration(milliseconds: 10));
      await tearDownTree(tester, container);
    });

    testWidgets('uk: choosing an action after the row has left the tree is a '
        'no-op, not a deactivated-ancestor crash (WR-03)', (tester) async {
      usePhoneSurface(tester);
      final container = makeContainer(today: pinnedToday, nowMinutes: 400);
      await container.read(supplementRepoProvider).upsert(supplement);
      await container.read(regimenRepoProvider).upsert(reg());
      final (row, raw, sub) = await pumpRow(tester, container);

      await tester.longPress(row);
      await pumpUntil(
        tester,
        () => find.text(markTaken).evaluate().isNotEmpty,
        'the action sheet',
      );
      // Let the sheet finish sliding in, so the tap below genuinely lands on
      // the action rather than missing an off-screen row.
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }
      expect(tester.getCenter(find.text(markTaken)).dy < 844, isTrue,
          reason: 'the sheet is fully presented before the row is removed');

      // The day stream removes the row underneath the OPEN sheet — the pause
      // filter hides a pending dose with no write at all.
      unawaited(container.read(regimenRepoProvider).setPaused('r1', true));
      await pumpUntil(
        tester,
        () => find.text('Магній').evaluate().length == 1,
        'the row to disappear while the sheet is still open',
      );

      await tester.tap(find.text(markTaken));
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }

      expect(tester.takeException(), isNull,
          reason: 'the sheet gap is arbitrarily long — resolving a '
              'BuildContext after it must not throw');
      expect(raw().single.status, DoseStatus.pending,
          reason: 'a dose whose row is gone is not silently marked');

      // ignore: unawaited_futures
      sub.cancel();
      await tester.pump(const Duration(milliseconds: 10));
      await tearDownTree(tester, container);
    });

    testWidgets('uk: long-pressing a TAKEN row offers mark-skipped and undo, '
        'with no mark-taken row', (tester) async {
      usePhoneSurface(tester);
      final container = makeContainer(today: pinnedToday, nowMinutes: 400);
      await container.read(supplementRepoProvider).upsert(supplement);
      await container.read(regimenRepoProvider).upsert(reg());
      final (row, raw, sub) = await pumpRow(tester, container);

      await tester.tap(row);
      await pumpUntil(
        tester,
        () => raw().single.status == DoseStatus.taken,
        'the row to become taken',
      );

      await tester.longPress(row);
      await pumpUntil(
        tester,
        () => find.text(undoMark).evaluate().isNotEmpty,
        'the action sheet',
      );

      expect(find.text(markSkipped), findsOneWidget);
      expect(find.text(markTaken), findsNothing);
      expect(tester.takeException(), isNull);
      // ignore: unawaited_futures
      sub.cancel();
      await tester.pump(const Duration(milliseconds: 10));
      await tearDownTree(tester, container);
    });

    testWidgets('uk: long-pressing a SKIPPED row offers mark-taken and undo, '
        'with no mark-skipped row', (tester) async {
      usePhoneSurface(tester);
      final container = makeContainer(today: pinnedToday, nowMinutes: 400);
      await container.read(supplementRepoProvider).upsert(supplement);
      await container.read(regimenRepoProvider).upsert(reg());
      final (row, raw, sub) = await pumpRow(tester, container);

      unawaited(container
          .read(intakeRepoProvider)
          .setStatus(raw().single.id, DoseStatus.skipped));
      await pumpUntil(
        tester,
        () => raw().single.status == DoseStatus.skipped,
        'the row to become skipped',
      );

      await tester.longPress(row);
      await pumpUntil(
        tester,
        () => find.text(undoMark).evaluate().isNotEmpty,
        'the action sheet',
      );

      expect(find.text(markTaken), findsOneWidget);
      expect(find.text(markSkipped), findsNothing);
      expect(tester.takeException(), isNull);
      // ignore: unawaited_futures
      sub.cancel();
      await tester.pump(const Duration(milliseconds: 10));
      await tearDownTree(tester, container);
    });

    testWidgets('uk: choosing mark-skipped pops the sheet and drives the RAW '
        'row to skipped', (tester) async {
      usePhoneSurface(tester);
      final container = makeContainer(today: pinnedToday, nowMinutes: 400);
      await container.read(supplementRepoProvider).upsert(supplement);
      await container.read(regimenRepoProvider).upsert(reg());
      final (row, raw, sub) = await pumpRow(tester, container);

      await tester.longPress(row);
      await pumpUntil(
        tester,
        () => find.text(markSkipped).evaluate().isNotEmpty,
        'the action sheet',
      );
      // The sheet is mounted before it has finished sliding up; let the
      // route transition run out so the action row is actually hit-testable.
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }

      await tester.tap(find.text(markSkipped));
      await pumpUntil(
        tester,
        () => raw().single.status == DoseStatus.skipped,
        'the chosen status to persist through the row write path',
      );
      await pumpUntil(
        tester,
        () => find.text(markSkipped).evaluate().isEmpty,
        'the sheet to finish popping',
      );

      expect(find.text(markSkipped), findsNothing,
          reason: 'the sheet pops as soon as an action is chosen');
      expect(find.text('пропущено'), findsOneWidget,
          reason: 'the row re-renders from the stream, not from sheet state');
      expect(tester.takeException(), isNull);
      // ignore: unawaited_futures
      sub.cancel();
      await tester.pump(const Duration(milliseconds: 10));
      await tearDownTree(tester, container);
    });

    testWidgets('uk: dismissing the sheet without choosing leaves the raw '
        'status unchanged', (tester) async {
      usePhoneSurface(tester);
      final container = makeContainer(today: pinnedToday, nowMinutes: 400);
      await container.read(supplementRepoProvider).upsert(supplement);
      await container.read(regimenRepoProvider).upsert(reg());
      final (row, raw, sub) = await pumpRow(tester, container);

      await tester.longPress(row);
      await pumpUntil(
        tester,
        () => find.text(markTaken).evaluate().isNotEmpty,
        'the action sheet',
      );

      // Barrier tap at the very top of the screen — well clear of the sheet.
      await tester.tapAt(const Offset(200, 20));
      await pumpUntil(
        tester,
        () => find.text(markTaken).evaluate().isEmpty,
        'the sheet to dismiss',
      );
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }

      expect(raw().single.status, DoseStatus.pending,
          reason: 'dismissal is not a choice — nothing is written');
      expect(tester.takeException(), isNull);
      // ignore: unawaited_futures
      sub.cancel();
      await tester.pump(const Duration(milliseconds: 10));
      await tearDownTree(tester, container);
    });

    testWidgets('uk: a long press issued while the tap write is STILL in '
        'flight is swallowed — one write, no sheet (T-03-02)', (tester) async {
      usePhoneSurface(tester);
      // A deliberately slow repository holds the write open long enough for
      // the long-press timeout to elapse mid-flight — the Phase-2
      // double-activation pattern, applied across two different gestures.
      final container = ProviderContainer(overrides: [
        dbProvider.overrideWith((ref) {
          final database = BoostqueDb.forTesting(NativeDatabase.memory());
          ref.onDispose(database.close);
          db = database;
          return database;
        }),
        todayProvider.overrideWith(() => _FixedToday(pinnedToday)),
        nowMinutesProvider.overrideWith((ref) => Stream.value(400)),
        intakeRepoProvider.overrideWith((ref) => _SlowIntakeRepo(
              DriftIntakeRepository(
                ref.watch(dbProvider),
                regimens: ref.watch(regimenRepoProvider),
              ),
            )),
      ]);
      await container.read(supplementRepoProvider).upsert(supplement);
      await container.read(regimenRepoProvider).upsert(reg());
      final (row, raw, sub) = await pumpRow(tester, container);

      await tester.tap(row);
      await tester.pump(const Duration(milliseconds: 10));
      expect(raw().single.status, DoseStatus.pending,
          reason: 'the slow write has not landed yet — it is in flight');

      // `longPress` pumps past the long-press timeout while the write is open.
      await tester.longPress(row);
      await tester.pump(const Duration(milliseconds: 10));
      expect(find.text(markSkipped), findsNothing,
          reason: 'the sheet must not open while a write is in flight');

      await pumpUntil(
        tester,
        () => raw().single.status == DoseStatus.taken,
        'the single allowed write to land',
      );
      expect(raw().single.status, DoseStatus.taken,
          reason: 'exactly one write was allowed through, and it is the tap');
      expect(tester.takeException(), isNull);
      // ignore: unawaited_futures
      sub.cancel();
      await tester.pump(const Duration(milliseconds: 10));
      await tearDownTree(tester, container);
    });
  });

  // --- Week strip (plan 03-05, Task 1; UI-SPEC S4 "Week strip", DECIDED-4,
  // Interaction Contracts 4/5/8, E3) ---
  //
  // The clock is pinned to Thursday 2026-08-13, so the resolved week is
  // Monday 2026-08-10 .. Sunday 2026-08-16 on every machine. Cells are found
  // by their date-only `ValueKey`, so an assertion can never be satisfied by
  // the wrong cell.
  group('week strip', () {
    final pinnedToday = DateTime.utc(2026, 8, 13); // четвер
    final monday = DateTime.utc(2026, 8, 10);
    final pastDay = DateTime.utc(2026, 8, 11);
    final futureDay = DateTime.utc(2026, 8, 14);

    Supplement supp(String name) => Supplement(
          id: 's1',
          name: name,
          doseText: '',
          colorValue: 0xFF6B6FA8,
          note: '',
        );

    Regimen everyDay({int offDays = 0}) => Regimen(
          id: 'r1',
          supplementId: 's1',
          kind: RegimenKind.cyclic,
          startDate: DateTime.utc(2020, 1, 1),
          endDate: null,
          onDays: 1,
          offDays: offDays,
          paused: false,
          slots: const [
            DoseSlot(id: 'sl1', minutesFromMidnight: 480, doseLabel: ''),
          ],
        );

    Finder cell(DateTime day) => find.byKey(ValueKey<DateTime>(day));

    /// The cell's own decorated box.
    BoxDecoration cellDecoration(WidgetTester tester, DateTime day) =>
        tester.widget<Container>(cell(day)).decoration! as BoxDecoration;

    /// The cell's 4x4 status dot color.
    Color dotColor(WidgetTester tester, DateTime day) => (tester
            .widget<Container>(find.descendant(
              of: cell(day),
              matching: find.byKey(const ValueKey('week-dot')),
            ))
            .decoration! as BoxDecoration)
        .color!;

    /// Text rendered inside one cell (the uppercased dow, the day number).
    List<String> cellTexts(WidgetTester tester, DateTime day) => tester
        .widgetList<Text>(find.descendant(of: cell(day), matching: find.byType(Text)))
        .map((t) => t.data ?? '')
        .toList();

    testWidgets('uk: the resolved week renders exactly 7 Monday-first cells '
        'with intl dow labels and day numbers', (tester) async {
      usePhoneSurface(tester);
      final container = makeContainer(today: pinnedToday, nowMinutes: 600);
      await container.read(supplementRepoProvider).upsert(supp('Магній'));
      await container.read(regimenRepoProvider).upsert(everyDay());

      await tester.pumpWidget(app(container));
      await pumpUntil(
        tester,
        () => cell(monday).evaluate().isNotEmpty,
        'the week strip',
      );

      for (var i = 0; i < 7; i++) {
        expect(cell(monday.add(Duration(days: i))), findsOneWidget,
            reason: 'the strip renders every day of the resolved week');
      }
      expect(cell(DateTime.utc(2026, 8, 9)), findsNothing,
          reason: 'the Sunday BEFORE the Monday belongs to the previous week');
      expect(cell(DateTime.utc(2026, 8, 17)), findsNothing);

      // Monday is the FIRST column: a hard, locale-independent rule
      // (DECIDED-4), not MaterialLocalizations.firstDayOfWeekIndex.
      var previous = tester.getTopLeft(cell(monday)).dx;
      for (var i = 1; i < 7; i++) {
        final dx = tester.getTopLeft(cell(monday.add(Duration(days: i)))).dx;
        expect(dx > previous, isTrue,
            reason: 'cells run Monday -> Sunday in start-to-end order');
        previous = dx;
      }

      expect(cellTexts(tester, monday), contains('10'),
          reason: "the day number is intl's, for the active locale");
      expect(cellTexts(tester, pinnedToday), contains('13'));
      expect(cellTexts(tester, monday).first,
          DateFormat.E('uk').format(monday).toUpperCase(),
          reason: 'the dow label is the uppercased intl short weekday — never '
              'an ARB string and never a hand-built table');
      expect(tester.takeException(), isNull);

      await tearDownTree(tester, container);
    });

    testWidgets('en: the first cell is STILL Monday (DECIDED-4 divergence '
        'from firstDayOfWeekIndex)', (tester) async {
      usePhoneSurface(tester);
      final container = makeContainer(today: pinnedToday, nowMinutes: 600);
      await container.read(supplementRepoProvider).upsert(supp('Magnesium'));
      await container.read(regimenRepoProvider).upsert(everyDay());

      await tester.pumpWidget(app(container, locale: const Locale('en')));
      await pumpUntil(
        tester,
        () => cell(monday).evaluate().isNotEmpty,
        'the week strip',
      );

      // en-US would put Sunday first if the platform value were consulted.
      expect(cell(DateTime.utc(2026, 8, 9)), findsNothing,
          reason: 'Sunday 9 August belongs to the PREVIOUS week, in every '
              'locale');
      for (var i = 0; i < 7; i++) {
        expect(cell(monday.add(Duration(days: i))), findsOneWidget);
      }
      expect(
        tester.getTopLeft(cell(monday)).dx <
            tester.getTopLeft(cell(DateTime.utc(2026, 8, 16))).dx,
        isTrue,
        reason: 'Monday is the leading column and Sunday closes the week',
      );
      expect(cellTexts(tester, monday).first,
          DateFormat.E('en').format(monday).toUpperCase(),
          reason: 'the dow label follows the ACTIVE locale');
      expect(tester.takeException(), isNull);

      await tearDownTree(tester, container);
    });

    testWidgets("uk: today's cell is accent-filled; a selected non-today cell "
        'takes the accent border; every other cell keeps the card border',
        (tester) async {
      usePhoneSurface(tester);
      final container = makeContainer(today: pinnedToday, nowMinutes: 600);
      await container.read(supplementRepoProvider).upsert(supp('Магній'));
      await container.read(regimenRepoProvider).upsert(everyDay());

      await tester.pumpWidget(app(container));
      await pumpUntil(
        tester,
        () => cell(monday).evaluate().isNotEmpty,
        'the week strip',
      );

      expect(cellDecoration(tester, pinnedToday).color, BqColors.accent,
          reason: "today's cell is the single accent block in the row");
      expect((cellDecoration(tester, pinnedToday).border! as Border).top.color,
          BqColors.accent);
      expect(
        cellTexts(tester, pinnedToday),
        contains('13'),
      );
      expect(
        tester
            .widget<Text>(find.descendant(
              of: cell(pinnedToday),
              matching: find.text('13'),
            ))
            .style
            ?.color,
        BqColors.surface,
        reason: "the day number inverts on today's accent fill",
      );
      expect(cellDecoration(tester, pastDay).color, BqColors.surface);
      expect((cellDecoration(tester, pastDay).border! as Border).top.color,
          BqColors.cardBorder,
          reason: 'an unselected non-today cell keeps the neutral card border');

      container.read(selectedDayProvider.notifier).select(pastDay);
      await pumpUntil(
        tester,
        () => (cellDecoration(tester, pastDay).border! as Border).top.color ==
            BqColors.accent,
        'the selected cell to take the accent border',
      );

      final border = cellDecoration(tester, pastDay).border! as Border;
      expect(border.top.width, 1.5,
          reason: 'the browsed day is marked by a 1.5px accent border on a '
              'surface fill, never by a fill of its own');
      expect(cellDecoration(tester, pastDay).color, BqColors.surface);
      expect(cellDecoration(tester, pinnedToday).color, BqColors.accent,
          reason: "today's cell keeps its fill while another day is browsed");
      expect(tester.takeException(), isNull);

      await tearDownTree(tester, container);
    });

    testWidgets('uk: tapping a past cell browses that day; tapping today\'s '
        'cell clears the selection back to following today (Interaction '
        'Contract 4)', (tester) async {
      usePhoneSurface(tester);
      final container = makeContainer(today: pinnedToday, nowMinutes: 600);
      await container.read(supplementRepoProvider).upsert(supp('Магній'));
      await container.read(regimenRepoProvider).upsert(everyDay());

      await tester.pumpWidget(app(container));
      await pumpUntil(
        tester,
        () => cell(pastDay).evaluate().isNotEmpty,
        'the week strip',
      );

      await tester.tap(cell(pastDay));
      await pumpUntil(
        tester,
        () => find.text('11 серпня').evaluate().isNotEmpty,
        'the day body to re-resolve to the tapped day',
      );
      expect(container.read(selectedDayProvider), pastDay,
          reason: 'the tap writes a dateOnly() normalized selection (PF-1)');

      await tester.tap(cell(pinnedToday));
      await pumpUntil(
        tester,
        () => find.text('четвер, 13 серпня').evaluate().isNotEmpty,
        'the strip to drop back to following today',
      );
      expect(container.read(selectedDayProvider), isNull,
          reason: 'following today is null, not a concrete date — so the view '
              'auto-advances across midnight (P-3)');
      expect(tester.takeException(), isNull);

      await tearDownTree(tester, container);
    });

    testWidgets('uk: the pager is BOUNDED — 53 pages, the last of which is '
        "today's week; a forward swipe cannot leave it (DECIDED-4)",
        (tester) async {
      usePhoneSurface(tester);
      final container = makeContainer(today: pinnedToday, nowMinutes: 600);
      await container.read(supplementRepoProvider).upsert(supp('Магній'));
      await container.read(regimenRepoProvider).upsert(everyDay());

      await tester.pumpWidget(app(container));
      await pumpUntil(
        tester,
        () => cell(monday).evaluate().isNotEmpty,
        'the week strip',
      );

      // The bound is asserted from the widget's own page count and mapping,
      // not by swiping 52 times.
      expect(weekPageCount, 53,
          reason: '52 weeks back plus the week containing today — a FINITE '
              'itemCount, so the builder can never run away (T-03-17)');
      final pageView = tester.widget<PageView>(find.byType(PageView));
      expect(
        (pageView.childrenDelegate as SliverChildBuilderDelegate).childCount,
        weekPageCount,
        reason: 'the pager exposes exactly that many pages',
      );
      expect(weekStartForPage(weekPageCount - 1, pinnedToday), monday,
          reason: "the LAST page is the week containing today");
      expect(weekStartForPage(0, pinnedToday),
          monday.subtract(const Duration(days: 7 * 52)),
          reason: 'the first page is 52 weeks back');

      // A forward swipe from the last page changes nothing.
      await tester.drag(find.byType(PageView), const Offset(-320, 0));
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }
      expect(cell(pinnedToday), findsOneWidget,
          reason: 'forward paging is capped at the week containing today');
      expect(cell(DateTime.utc(2026, 8, 17)), findsNothing,
          reason: 'next week is unreachable — forward planning is Phase 4');
      expect(cell(futureDay), findsOneWidget,
          reason: 'a future day INSIDE the current week stays selectable '
              '(E-10)');

      // A backward swipe reaches the previous week.
      await tester.drag(find.byType(PageView), const Offset(320, 0));
      await pumpUntil(
        tester,
        () => cell(DateTime.utc(2026, 8, 3)).evaluate().isNotEmpty,
        'the previous week page',
      );
      expect(cell(DateTime.utc(2026, 8, 9)), findsOneWidget,
          reason: 'the previous page is the full Monday-to-Sunday week before');
      expect(tester.takeException(), isNull);

      await tearDownTree(tester, container);
    });

    testWidgets('uk: travelling the pager materializes nothing — only the '
        'current week is warmed (WR-06)', (tester) async {
      usePhoneSurface(tester);
      final container = makeContainer(today: pinnedToday, nowMinutes: 600);
      await container.read(supplementRepoProvider).upsert(supp('Магній'));
      await container.read(regimenRepoProvider).upsert(everyDay());

      await tester.pumpWidget(app(container));
      await pumpUntil(
        tester,
        () => cell(monday).evaluate().isNotEmpty,
        'the week strip',
      );

      var raw = <IntakeLog>[];
      final sub = db.select(db.intakeLogs).watch().listen((v) => raw = v);
      await pumpUntil(tester, () => raw.length == 7,
          "the current week's seven rows, warmed by the strip");

      // Three weeks back through the pager.
      for (var page = 0; page < 3; page++) {
        await tester.drag(find.byType(PageView), const Offset(320, 0));
        for (var i = 0; i < 40; i++) {
          await tester.pump(const Duration(milliseconds: 20));
        }
      }
      expect(cell(monday.subtract(const Duration(days: 21))), findsOneWidget,
          reason: 'the pager really did travel three weeks back');

      expect(raw, hasLength(7),
          reason: 'the dot is a READ — the database must grow with what the '
              'user actually does, not with how far the pager travelled');
      expect(raw.every((r) => !r.date.isBefore(monday)), isTrue,
          reason: 'nothing outside the current week was materialized');
      expect(tester.takeException(), isNull);

      // ignore: unawaited_futures
      sub.cancel();
      await tester.pump(const Duration(milliseconds: 10));
      await tearDownTree(tester, container);
    });

    testWidgets('uk: a past day whose every dose is handled shows the calm '
        'dot; a pending past day, an empty day and a future day show the '
        'neutral dot', (tester) async {
      usePhoneSurface(tester);
      final container = makeContainer(today: pinnedToday, nowMinutes: 600);
      await container.read(supplementRepoProvider).upsert(supp('Магній'));
      await container.read(regimenRepoProvider).upsert(everyDay());

      await tester.pumpWidget(app(container));
      await pumpUntil(
        tester,
        () => cell(pastDay).evaluate().isNotEmpty,
        'the week strip',
      );

      // The strip's own per-cell watch materializes the visible week — no
      // test-side ensureLogsForDay call anywhere (PF-3).
      var pastRaw = <IntakeLog>[];
      final pastSub = rawLogsFor(pastDay).listen((v) => pastRaw = v);
      await pumpUntil(tester, () => pastRaw.length == 1,
          "the past day's row, materialized by the strip");

      expect(dotColor(tester, pastDay), BqColors.field,
          reason: 'a past day still holding a pending dose is NOT handled');
      expect(dotColor(tester, futureDay), BqColors.field,
          reason: 'a future day is never "handled" — it has not happened');

      unawaited(container
          .read(intakeRepoProvider)
          .setStatus(pastRaw.single.id, DoseStatus.taken));
      await pumpUntil(
        tester,
        () => dotColor(tester, pastDay) == BqColors.calm,
        'the calm dot once every dose of the past day is handled',
      );

      expect(dotColor(tester, futureDay), BqColors.field,
          reason: 'handling one day changes no other cell');
      expect(tester.takeException(), isNull);
      // ignore: unawaited_futures
      pastSub.cancel();
      await tester.pump(const Duration(milliseconds: 10));
      await tearDownTree(tester, container);
    });

    testWidgets('uk: a day with NO doses shows the neutral dot and the strip '
        'still renders — never a spinner, never an error cell (E3)',
        (tester) async {
      usePhoneSurface(tester);
      final container = makeContainer(today: pinnedToday, nowMinutes: 600);
      await container.read(supplementRepoProvider).upsert(supp('Магній'));
      // Active for one day in 2020, then off for ~274 years: every day of the
      // rendered week is an off day.
      await container
          .read(regimenRepoProvider)
          .upsert(everyDay(offDays: 100000));

      await tester.pumpWidget(app(container));
      await pumpUntil(
        tester,
        () => cell(pastDay).evaluate().isNotEmpty,
        'the week strip',
      );
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }

      expect(dotColor(tester, pastDay), BqColors.field,
          reason: 'a day with zero doses is not "fully handled"');
      expect(find.byType(CircularProgressIndicator), findsNothing,
          reason: 'the strip renders synchronously and never blocks on data');
      expect(tester.takeException(), isNull);

      await tearDownTree(tester, container);
    });

    testWidgets('uk: every cell carries the localized full date as its '
        'Semantics label plus a selected flag, and the whole padded cell is '
        'the tap target (Interaction Contract 8)', (tester) async {
      usePhoneSurface(tester);
      final semantics = tester.ensureSemantics();
      final container = makeContainer(today: pinnedToday, nowMinutes: 600);
      await container.read(supplementRepoProvider).upsert(supp('Магній'));
      await container.read(regimenRepoProvider).upsert(everyDay());

      await tester.pumpWidget(app(container));
      await pumpUntil(
        tester,
        () => cell(pastDay).evaluate().isNotEmpty,
        'the week strip',
      );

      expect(tester.getSemantics(cell(pastDay)).label,
          DateFormat.yMMMMEEEEd('uk').format(pastDay),
          reason: 'a bare number is meaningless to a screen reader — the cell '
              'announces the full localized date');
      /// The cell's own `Semantics` wrapper — the nearest ancestor, since the
      /// cell excludes the semantics of its own text children.
      Semantics wrapper(DateTime day) => tester.widget<Semantics>(
          find.ancestor(of: cell(day), matching: find.byType(Semantics)).first);

      expect(wrapper(pinnedToday).properties.selected, isTrue,
          reason: 'the resolved day is announced as selected');
      expect(wrapper(pastDay).properties.selected, isFalse);
      expect(wrapper(pastDay).properties.button, isTrue,
          reason: 'a cell is a control, not decoration');

      // The cell must be ACTIVATABLE by assistive technology, not merely
      // announced as a button: `excludeSemantics` drops the GestureDetector's
      // own tap action, so the node has to carry one itself (WR-02).
      expect(
        tester
            .getSemantics(cell(pastDay))
            .getSemanticsData()
            .hasAction(SemanticsAction.tap),
        isTrue,
        reason: 'a screen reader must be able to browse days — a physical hit '
            'test is not the same thing as a semantics action',
      );
      tester.semantics.performAction(
        find.semantics.byLabel(DateFormat.yMMMMEEEEd('uk').format(pastDay)),
        SemanticsAction.tap,
      );
      await pumpUntil(
        tester,
        () => container.read(selectedDayProvider) == pastDay,
        'the semantics tap action to browse the day',
      );
      container.read(selectedDayProvider.notifier).followToday();
      await tester.pump();

      // The tap target is the padded cell, not the 4px dot: a tap 2px inside
      // the cell's top-start corner still selects the day.
      final rect = tester.getRect(cell(pastDay));
      await tester.tapAt(rect.topLeft + const Offset(2, 2));
      await pumpUntil(
        tester,
        () => container.read(selectedDayProvider) == pastDay,
        'a corner tap to select the day',
      );
      expect(tester.getRect(cell(pastDay)).height >= 44, isTrue,
          reason: 'cells are at least 44px tall (Interaction Contract 8)');
      expect(tester.takeException(), isNull);

      semantics.dispose();
      await tearDownTree(tester, container);
    });
  });

  // --- Past-day browsing + the empty / loading / error surfaces (plan 03-05,
  // Task 2; UI-SPEC S4 "Empty day", DECIDED-3/7, Interaction Contract 6,
  // E1 #1-#4, T-03-15 / T-03-16) ---
  //
  // The load-bearing test in this group is the raw-row proof: rendering a
  // past day is allowed to MATERIALIZE rows, and is never allowed to give
  // one a status. "Missed" is a derived reading of a `pending` row, and the
  // database is where that claim is checked.
  group('browsing', () {
    final pinnedToday = DateTime.utc(2026, 8, 13); // четвер
    final pastDay = DateTime.utc(2026, 8, 11);
    final futureDay = DateTime.utc(2026, 8, 14);
    // Three weeks back — deliberately OUTSIDE the visible week, so its
    // provider is genuinely cold and the day switch has a loading frame.
    final farPast = DateTime.utc(2026, 7, 20);

    const emptyTitle = 'Доз на цей день немає';
    const emptyBody = 'Жоден цикл не активний цього дня.';
    const emptyBodyNoStack =
        'Додайте добавку у вкладці «Стек», щоб побачити тут дози.';
    const loadError = 'Не вдалося завантажити день. Спробуйте ще раз.';
    const disclaimer = 'Розклад складено з ваших власних записів. '
        'Освітній матеріал, не медична порада.';

    Supplement supp(String name) => Supplement(
          id: 's1',
          name: name,
          doseText: '',
          colorValue: 0xFF6B6FA8,
          note: '',
        );

    Regimen reg({DateTime? startDate, int offDays = 0}) => Regimen(
          id: 'r1',
          supplementId: 's1',
          kind: RegimenKind.cyclic,
          startDate: startDate ?? DateTime.utc(2020, 1, 1),
          endDate: null,
          onDays: 1,
          offDays: offDays,
          paused: false,
          slots: const [
            DoseSlot(id: 'sl1', minutesFromMidnight: 480, doseLabel: ''),
          ],
        );

    /// Fails if ANY painted surface or text in the current tree carries a
    /// warn or destructive color (TRACK-03 neutrality mandate).
    void expectNoWarnOrRiskPaint(WidgetTester tester) {
      // A plain list, not a const Set: dart:ui's Color has no primitive
      // equality, so it cannot be a const set element.
      final banned = <Color>[
        BqColors.warnBorder,
        BqColors.warnBg,
        BqColors.warn,
        BqColors.risk,
        BqColors.riskBg,
        BqColors.riskBorder,
      ];
      for (final container in tester.widgetList<Container>(
        find.byType(Container),
      )) {
        expect(banned.contains(container.color), isFalse,
            reason: 'a Container fill uses a warn/destructive token');
        final decoration = container.decoration;
        if (decoration is BoxDecoration) {
          expect(banned.contains(decoration.color), isFalse,
              reason: 'a decorated fill uses a warn/destructive token');
          final border = decoration.border;
          if (border is Border) {
            expect(banned.contains(border.top.color), isFalse,
                reason: 'a border uses a warn/destructive token');
          }
        }
      }
      for (final text in tester.widgetList<Text>(find.byType(Text))) {
        expect(banned.contains(text.style?.color), isFalse,
            reason: 'text uses a warn/destructive token');
      }
    }

    testWidgets('uk: browsing a past day renders the not-marked chip while '
        'EVERY raw intake-log row stays pending (T-03-15, TRACK-03)',
        (tester) async {
      usePhoneSurface(tester);
      final container = makeContainer(today: pinnedToday, nowMinutes: 600);
      await container.read(supplementRepoProvider).upsert(supp('Магній'));
      await container.read(regimenRepoProvider).upsert(reg());

      await tester.pumpWidget(app(container));
      await pumpUntil(
        tester,
        () => find.text('Магній').evaluate().isNotEmpty,
        'the dose row on today',
      );

      container.read(selectedDayProvider.notifier).select(pastDay);
      await pumpUntil(
        tester,
        () => find.text('не позначено').evaluate().isNotEmpty,
        'the not-marked chip on the browsed past day',
      );

      // The WHOLE table, not just the browsed day: browsing (and the strip's
      // week pre-materialization) may create rows, and may never grade one.
      var raw = <IntakeLog>[];
      final rawSub = db.select(db.intakeLogs).watch().listen((v) => raw = v);
      await pumpUntil(tester, () => raw.isNotEmpty, 'the materialized rows');
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }

      expect(raw.every((r) => r.status == DoseStatus.pending), isTrue,
          reason: 'rendering a past day is a READ — "missed" is derived in a '
              'pure helper and the row it describes is still pending');
      expect(tester.takeException(), isNull);
      // ignore: unawaited_futures
      rawSub.cancel();
      await tester.pump(const Duration(milliseconds: 10));
      await tearDownTree(tester, container);
    });

    testWidgets('uk: no warn or destructive color renders anywhere on a past '
        'day, and its unmarked dose is still tappable (DECIDED-3)',
        (tester) async {
      usePhoneSurface(tester);
      final container = makeContainer(today: pinnedToday, nowMinutes: 600);
      await container.read(supplementRepoProvider).upsert(supp('Магній'));
      await container.read(regimenRepoProvider).upsert(reg());

      await tester.pumpWidget(app(container));
      await pumpUntil(
        tester,
        () => find.text('не прийнято вчасно').evaluate().isNotEmpty,
        'the warn treatment that today legitimately carries',
      );

      container.read(selectedDayProvider.notifier).select(pastDay);
      await pumpUntil(
        tester,
        () => find.text('не позначено').evaluate().isNotEmpty,
        'the browsed past day',
      );

      expect(find.text('не прийнято вчасно'), findsNothing,
          reason: 'overdue is a today-only treatment');
      expectNoWarnOrRiskPaint(tester);

      // Still live: marking a dose taken late is a legitimate correction.
      var raw = <IntakeLog>[];
      final rawSub = rawLogsFor(pastDay).listen((v) => raw = v);
      await pumpUntil(tester, () => raw.isNotEmpty, "the past day's row");
      await tester.tap(find.text('Магній'));
      await pumpUntil(
        tester,
        () => raw.single.status == DoseStatus.taken,
        'the late correction to persist',
      );

      expect(tester.takeException(), isNull);
      // ignore: unawaited_futures
      rawSub.cancel();
      await tester.pump(const Duration(milliseconds: 10));
      await tearDownTree(tester, container);
    });

    testWidgets('uk: switching to a day whose stream has not resolved HOLDS '
        'the previous rows — the list never blanks between days (PF-7)',
        (tester) async {
      usePhoneSurface(tester);
      final container = makeContainer(today: pinnedToday, nowMinutes: 600);
      await container.read(supplementRepoProvider).upsert(supp('Магній'));
      // Starts on the Monday of the CURRENT week, so the far-past day is
      // genuinely doseless — the held rows cannot be confused with its own.
      await container
          .read(regimenRepoProvider)
          .upsert(reg(startDate: DateTime.utc(2026, 8, 10)));

      await tester.pumpWidget(app(container));
      await pumpUntil(
        tester,
        () => find.text('Магній').evaluate().isNotEmpty,
        'the dose row on today',
      );

      container.read(selectedDayProvider.notifier).select(farPast);
      await tester.pump();

      expect(find.text('Магній'), findsOneWidget,
          reason: 'on the very next frame the previous list is still on '
              'screen — blanking it would read as "this day is empty"');
      expect(find.text('20 липня'), findsOneWidget,
          reason: 'the header moved immediately, so the switch is visible');
      expect(find.byType(CircularProgressIndicator), findsNothing,
          reason: 'no spinner ever flashes on a local-DB stream');

      await pumpUntil(
        tester,
        () => find.text(emptyTitle).evaluate().isNotEmpty,
        'the far-past day to resolve to its own (empty) content',
      );
      expect(find.text('Магній'), findsNothing,
          reason: 'once the new day resolves it replaces the held list');
      expect(tester.takeException(), isNull);

      await tearDownTree(tester, container);
    });

    testWidgets('uk: the held rows keep the identity of the day they came '
        'from — no missed chip, no overdue flash (WR-01)', (tester) async {
      usePhoneSurface(tester);
      final container = makeContainer(today: pinnedToday, nowMinutes: 600);
      await container.read(supplementRepoProvider).upsert(supp('Магній'));
      await container.read(regimenRepoProvider).upsert(reg());

      await tester.pumpWidget(app(container));
      await pumpUntil(
        tester,
        () => find.text('не прийнято вчасно').evaluate().isNotEmpty,
        "today's overdue row",
      );

      // The far-past day's provider is cold, so this frame is a hold frame.
      container.read(selectedDayProvider.notifier).select(farPast);
      await tester.pump();

      expect(find.text('Магній'), findsOneWidget,
          reason: 'the rows are held (PF-7)');
      expect(find.text('не прийнято вчасно'), findsOneWidget,
          reason: "the held rows are TODAY's and keep today's treatment — "
              'rendering them with the new day would restyle them mid-switch');
      expect(find.text('не позначено'), findsNothing,
          reason: "today's doses are not missed; that chip would mean the "
              "held rows were graded against the day they do not belong to");
      expect(tester.takeException(), isNull);

      await pumpUntil(
        tester,
        () => find.text('не позначено').evaluate().isNotEmpty,
        'the far-past day to resolve to its own rows',
      );
      await tearDownTree(tester, container);
    });

    testWidgets('uk: a tap during the hold window cannot write to the day the '
        'user just left (WR-01)', (tester) async {
      usePhoneSurface(tester);
      final container = makeContainer(today: pinnedToday, nowMinutes: 600);
      await container.read(supplementRepoProvider).upsert(supp('Магній'));
      await container.read(regimenRepoProvider).upsert(reg());

      await tester.pumpWidget(app(container));
      await pumpUntil(
        tester,
        () => find.text('Магній').evaluate().isNotEmpty,
        'the dose row on today',
      );

      var raw = <IntakeLog>[];
      final rawSub = rawLogsFor(pinnedToday).listen((v) => raw = v);
      await pumpUntil(tester, () => raw.length == 1, "today's row");

      container.read(selectedDayProvider.notifier).select(farPast);
      await tester.pump();

      // A real finger landing on the held row in the hold window. `tapAt`
      // rather than `tap`: the held frame is deliberately not hit-testable.
      await tester.tapAt(tester.getCenter(find.text('Магній')));
      await pumpUntil(
        tester,
        () => find.text('не позначено').evaluate().isNotEmpty,
        'the far-past day to resolve to its own rows',
      );
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }

      expect(raw.single.status, DoseStatus.pending,
          reason: "the tap landed while the header, ring and strip all showed "
              'another day — it must not mark a dose on the day left behind');
      expect(tester.takeException(), isNull);

      // ignore: unawaited_futures
      rawSub.cancel();
      await tester.pump(const Duration(milliseconds: 10));
      await tearDownTree(tester, container);
    });

    testWidgets('uk: a day with no active cycle renders the empty title with '
        'the no-cycle body, no block header and NO ring — and still closes '
        'with the disclaimer (DECIDED-7)', (tester) async {
      usePhoneSurface(tester);
      final container = makeContainer(today: pinnedToday, nowMinutes: 600);
      await container.read(supplementRepoProvider).upsert(supp('Магній'));
      await container.read(regimenRepoProvider).upsert(reg(offDays: 100000));

      await tester.pumpWidget(app(container));
      await pumpUntil(
        tester,
        () => find.text(emptyTitle).evaluate().isNotEmpty,
        'the empty-day block',
      );

      expect(find.text(emptyBody), findsOneWidget,
          reason: 'the stack HAS supplements — an off day is a correct, '
              'expected state and needs no call to action');
      expect(find.text(emptyBodyNoStack), findsNothing);
      expect(find.byType(DayBlockSection), findsNothing,
          reason: 'no block header stands over an empty day');
      expect(find.byType(DayProgressRing), findsNothing,
          reason: 'a "0/0" ring is meaningless chrome (DECIDED-7)');
      expect(find.text(disclaimer), findsOneWidget,
          reason: 'the disclaimer closes EVERY day, including empty ones');
      expect(tester.takeException(), isNull);

      await tearDownTree(tester, container);
    });

    testWidgets('uk: with an EMPTY stack the empty day names the one next '
        'step instead', (tester) async {
      usePhoneSurface(tester);
      final container = makeContainer(today: pinnedToday, nowMinutes: 600);
      // Nothing seeded at all: no supplements, no regimens.

      await tester.pumpWidget(app(container));
      await pumpUntil(
        tester,
        () => find.text(emptyBodyNoStack).evaluate().isNotEmpty,
        'the empty-stack body variant',
      );

      expect(find.text(emptyTitle), findsOneWidget);
      expect(find.text(emptyBody), findsNothing,
          reason: '"no cycle is active" would be a dead end for a user who '
              'has not added anything yet');
      expect(find.text(disclaimer), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tearDownTree(tester, container);
    });

    testWidgets('uk: an errored day stream renders the documented copy plus '
        'retry, and never a stack trace (T-03-16)', (tester) async {
      usePhoneSurface(tester);
      final container = ProviderContainer(overrides: [
        dbProvider.overrideWith((ref) {
          final database = BoostqueDb.forTesting(NativeDatabase.memory());
          ref.onDispose(database.close);
          db = database;
          return database;
        }),
        todayProvider.overrideWith(() => _FixedToday(pinnedToday)),
        nowMinutesProvider.overrideWith((ref) => Stream.value(600)),
        intakeRepoProvider.overrideWith((ref) => _ErroringIntakeRepo(
              DriftIntakeRepository(
                ref.watch(dbProvider),
                regimens: ref.watch(regimenRepoProvider),
              ),
            )),
      ]);
      await container.read(supplementRepoProvider).upsert(supp('Магній'));
      await container.read(regimenRepoProvider).upsert(reg());

      await tester.pumpWidget(app(container));
      await pumpUntil(
        tester,
        () => find.text(loadError).evaluate().isNotEmpty,
        'the day-load error copy',
      );

      expect(find.text('Повторити'), findsOneWidget,
          reason: 'the error surface always offers the way out');
      expect(find.textContaining('refused'), findsNothing,
          reason: 'the storage exception message never reaches the screen');
      expect(find.textContaining('Exception'), findsNothing);
      expect(find.textContaining('Error'), findsNothing);
      expect(find.text(disclaimer), findsOneWidget,
          reason: 'the body still closes normally on an errored day');
      expect(find.byType(CircularProgressIndicator), findsNothing);

      // Retry re-subscribes; the stubbed repository errors again, so the
      // surface is stable rather than crashing.
      await tester.tap(find.text('Повторити'));
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }
      expect(find.text(loadError), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tearDownTree(tester, container);
    });

    testWidgets('uk: a FUTURE day inside the current week renders plain '
        'pending rows — no overdue, no not-marked (E-10)', (tester) async {
      usePhoneSurface(tester);
      final container = makeContainer(today: pinnedToday, nowMinutes: 600);
      await container.read(supplementRepoProvider).upsert(supp('Магній'));
      await container.read(regimenRepoProvider).upsert(reg());

      await tester.pumpWidget(app(container));
      await pumpUntil(
        tester,
        () => find.text('не прийнято вчасно').evaluate().isNotEmpty,
        "today's overdue treatment",
      );

      container.read(selectedDayProvider.notifier).select(futureDay);
      await pumpUntil(
        tester,
        () => find.text('14 серпня').evaluate().isNotEmpty,
        'the browsed future day',
      );
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }

      expect(find.text('Магній'), findsOneWidget,
          reason: 'a future day inside the current week is reachable and '
              'renders its planned doses');
      expect(find.text('не прийнято вчасно'), findsNothing);
      expect(find.text('не позначено'), findsNothing,
          reason: 'a day that has not happened cannot be missed');
      expectNoWarnOrRiskPaint(tester);
      expect(tester.takeException(), isNull);

      await tearDownTree(tester, container);
    });

    // -------------------------------------------------------------------
    // The error surface under LIVE retry (plan 05-02, UI-SPEC A1 / P-9).
    // -------------------------------------------------------------------

    /// The consequence of a red case, named in device terms rather than as a
    /// restatement of the assertion.
    const heldOverErrorReason =
        "a user whose local database fails keeps looking at ANOTHER day's "
        "rows — inert, and silently mislabelled with the new day's header — "
        "for the whole of Riverpod's ~38.2s default backoff, with no copy and "
        'no retry to act on. The hold (PF-7 / WR-01) is right for a genuine '
        'day switch and wrong the moment the new day has actually failed';

    for (final locale in const ['uk', 'en']) {
      final dayError = locale == 'uk'
          ? 'Не вдалося завантажити день. Спробуйте ще раз.'
          : "Couldn't load this day. Try again.";
      final retryLabel = locale == 'uk' ? 'Повторити' : 'Retry';

      testWidgets(
          '$locale: when the browsed day FAILS, the error surface replaces '
          'the held rows on the very next frame — not after '
          "Riverpod's ~38s backoff (A1 / P-9)", (tester) async {
        usePhoneSurface(tester);
        // NOTE: this container deliberately supplies NO `retry:` override.
        // The ABSENCE of it is the whole point. The neighbouring T-03-16 test
        // above fails with a `StateError`, which `defaultRetry` refuses to
        // retry (`error is Error` => null) — so it reaches AsyncError at once
        // and never exercised the retry window. Drift throws `Exception`
        // subtypes, so the app's real failure mode is the retried one seeded
        // here; adding a `retry:` line would restore the blind spot.
        final container = ProviderContainer(overrides: [
          dbProvider.overrideWith((ref) {
            final database = BoostqueDb.forTesting(NativeDatabase.memory());
            ref.onDispose(database.close);
            db = database;
            return database;
          }),
          todayProvider.overrideWith(() => _FixedToday(pinnedToday)),
          nowMinutesProvider.overrideWith((ref) => Stream.value(600)),
          // Seeded on the STREAM that actually fails, and on ONE day only, so
          // today still resolves and there really ARE held rows for the error
          // surface to have to beat.
          intakeRepoProvider.overrideWith((ref) => _OneDayFailingIntakeRepo(
                DriftIntakeRepository(
                  ref.watch(dbProvider),
                  regimens: ref.watch(regimenRepoProvider),
                ),
                failingDay: farPast,
              )),
        ]);
        await container.read(supplementRepoProvider).upsert(supp('Магній'));
        await container.read(regimenRepoProvider).upsert(reg());

        await tester.pumpWidget(app(container, locale: Locale(locale)));
        await pumpUntil(
          tester,
          () => find.text('Магній').evaluate().isNotEmpty,
          'the dose row on today',
        );

        container.read(selectedDayProvider.notifier).select(farPast);
        // Pump only until the failure actually EXISTS. Drift's read is
        // genuinely asynchronous, and the claim under test is about the first
        // frame after the provider fails — not about how long the database
        // takes to fail. Never pumpAndSettle: with the retry timers live it
        // would either time out or wait out the backoff and pass for the
        // wrong reason (PF-7).
        await pumpUntil(
          tester,
          () => container.read(dayDosesProvider(farPast)).hasError,
          'the browsed day stream to fail',
        );
        // Exactly ONE frame after the failure.
        await tester.pump();

        expect(find.text(dayError), findsOneWidget,
            reason: heldOverErrorReason);
        expect(find.text('Магній'), findsNothing,
            reason: 'the held previous-day rows are gone: an inert list from '
                'a day the user has left is not an answer to "this day '
                'failed"');
        expect(find.text(retryLabel), findsOneWidget,
            reason: 'the error copy without its recovery control is a dead '
                'end');
        expect(find.byType(CircularProgressIndicator), findsNothing,
            reason: 'no spinner ever flashes on a local-DB stream');
        expect(find.textContaining('boom-from-drift'), findsNothing,
            reason: 'raw exception text never enters the widget tree '
                '(T-05-03)');
        expect(find.textContaining('Exception'), findsNothing,
            reason: 'nor does the exception type name (T-05-03)');
        expect(tester.takeException(), isNull);

        await tearDownTree(tester, container);
      });
    }
  });

  // --- Accessibility text scaling (CR-01, IN-08) ---
  //
  // 1.6 is inside the normal iOS "Larger Text" and Android font-size ranges,
  // and 2.0 is reachable on both: at those scales a fixed-height strip clipped
  // every cell. These pump the strip ALONE so the assertion is about the
  // strip's own layout and nothing else on the screen.
  group('text scaling', () {
    final pinnedToday = DateTime.utc(2026, 8, 13);

    Supplement supp(String name) => Supplement(
          id: 's1',
          name: name,
          doseText: '',
          colorValue: 0xFF6B6FA8,
          note: '',
        );

    Regimen everyDay() => Regimen(
          id: 'r1',
          supplementId: 's1',
          kind: RegimenKind.cyclic,
          startDate: DateTime.utc(2020, 1, 1),
          endDate: null,
          onDays: 1,
          offDays: 0,
          paused: false,
          slots: const [
            DoseSlot(id: 'sl1', minutesFromMidnight: 480, doseLabel: ''),
          ],
        );

    for (final scale in <double>[1.0, 1.3, 1.6, 2.0, 3.0]) {
      testWidgets(
          'uk: the week strip renders every cell without clipping at '
          'textScaler $scale (CR-01)', (tester) async {
        usePhoneSurface(tester);
        final container = makeContainer(today: pinnedToday, nowMinutes: 600);
        await container.read(supplementRepoProvider).upsert(supp('Магній'));
        await container.read(regimenRepoProvider).upsert(everyDay());

        await tester.pumpWidget(app(
          container,
          textScaler: TextScaler.linear(scale),
          home: const Scaffold(body: Column(children: [WeekStrip()])),
        ));
        await pumpUntil(
          tester,
          () =>
              find.byKey(ValueKey<DateTime>(pinnedToday)).evaluate().isNotEmpty,
          'the week strip',
        );
        for (var i = 0; i < 10; i++) {
          await tester.pump(const Duration(milliseconds: 20));
        }

        expect(tester.takeException(), isNull,
            reason: 'a RenderFlex overflow at an accessibility text scale is '
                'a clipped day number in release, not just debug stripes');
        expect(find.byKey(ValueKey<DateTime>(pinnedToday)), findsOneWidget);

        await tearDownTree(tester, container);
      });
    }

    for (final scale in <double>[1.0, 1.6, 2.0]) {
      testWidgets(
          'uk: the block header renders without overflowing at textScaler '
          '$scale (WR-04)', (tester) async {
        usePhoneSurface(tester);
        final container = makeContainer(today: pinnedToday, nowMinutes: 600);
        await container.read(supplementRepoProvider).upsert(supp('Магній'));
        await container.read(regimenRepoProvider).upsert(everyDay());

        await tester.pumpWidget(
            app(container, textScaler: TextScaler.linear(scale)));
        await pumpUntil(
          tester,
          () => find.byType(DayBlockSection).evaluate().isNotEmpty,
          'the block header',
        );
        for (var i = 0; i < 10; i++) {
          await tester.pump(const Duration(milliseconds: 20));
        }

        expect(tester.takeException(), isNull,
            reason: 'the three header texts must shrink, not overflow, when '
                'the text scale grows them past the row');
        expect(find.byType(DayBlockSection), findsOneWidget);

        await tearDownTree(tester, container);
      });
    }

    testWidgets('the reserved strip extent grows with the text scaler and is '
        'the mockup 82px at scale 1.0 (CR-01)', (tester) async {
      expect(stripHeightFor(TextScaler.noScaling), 82,
          reason: 'design fidelity at the default scale is unchanged');
      expect(stripHeightFor(const TextScaler.linear(2.0)) > 82, isTrue,
          reason: 'the extent follows the text it has to hold');
    });
  });
}

/// An [IntakeRepository] whose writes take a full second to land, so a test
/// can act while one is genuinely in flight. Reads delegate to the real
/// Drift implementation.
class _SlowIntakeRepo implements IntakeRepository {
  _SlowIntakeRepo(this.inner);

  final IntakeRepository inner;

  @override
  Stream<List<DayDose>> watchDay(DateTime day) => inner.watchDay(day);

  @override
  Future<void> ensureLogsForDay(DateTime day) => inner.ensureLogsForDay(day);

  @override
  Future<void> setStatus(String logId, DoseStatus status) async {
    await Future<void>.delayed(const Duration(seconds: 1));
    await inner.setStatus(logId, status);
  }
}

/// An [IntakeRepository] whose writes always fail; reads delegate to the real
/// Drift implementation so the day still materializes and renders.
class _FailingIntakeRepo implements IntakeRepository {
  _FailingIntakeRepo(this.inner);

  final IntakeRepository inner;

  @override
  Stream<List<DayDose>> watchDay(DateTime day) => inner.watchDay(day);

  @override
  Future<void> ensureLogsForDay(DateTime day) => inner.ensureLogsForDay(day);

  @override
  Future<void> setStatus(String logId, DoseStatus status) =>
      Future<void>.error(StateError('write refused by the test repository'));
}

/// An [IntakeRepository] whose day stream always fails, so the screen's
/// `AsyncValue.error` branch can be exercised end to end. Materialization
/// still succeeds — the failure is in the READ, which is where the day
/// surface's error copy lives.
class _ErroringIntakeRepo implements IntakeRepository {
  _ErroringIntakeRepo(this.inner);

  final IntakeRepository inner;

  @override
  Stream<List<DayDose>> watchDay(DateTime day) =>
      Stream<List<DayDose>>.error(StateError('day read refused by the test '
          'repository'));

  @override
  Future<void> ensureLogsForDay(DateTime day) => inner.ensureLogsForDay(day);

  @override
  Future<void> setStatus(String logId, DoseStatus status) =>
      inner.setStatus(logId, status);
}

/// Fails `watchDay` for ONE day, with an `Exception` rather than an `Error`.
///
/// The distinction is the whole point (A1 / P-9): `defaultRetry` refuses to
/// retry an `Error` (`if (error is ProviderException || error is Error) return
/// null`), so [_ErroringIntakeRepo]'s `StateError` reaches `AsyncError` at
/// once and never enters the backoff window. Drift throws `Exception`
/// subtypes, so this stub — not that one — reproduces the app's real failure
/// mode. Every other day delegates to the real repository, so the day the
/// user came FROM genuinely resolves and its rows are genuinely held.
class _OneDayFailingIntakeRepo implements IntakeRepository {
  _OneDayFailingIntakeRepo(this.inner, {required this.failingDay});

  final IntakeRepository inner;
  final DateTime failingDay;

  @override
  Stream<List<DayDose>> watchDay(DateTime day) => day == failingDay
      ? Stream<List<DayDose>>.error(
          Exception('boom-from-drift'),
          StackTrace.empty,
        )
      : inner.watchDay(day);

  @override
  Future<void> ensureLogsForDay(DateTime day) => inner.ensureLogsForDay(day);

  @override
  Future<void> setStatus(String logId, DoseStatus status) =>
      inner.setStatus(logId, status);
}

/// A clock frozen on one day: [TodayController] with no timer and no
/// `DateTime.now()` read, so header date assertions are machine-independent.
class _FixedToday extends TodayController {
  _FixedToday(this.day);

  final DateTime day;

  @override
  DateTime build() => day;
}
