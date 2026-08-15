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
import 'package:boostque/core/domain/models.dart';
import 'package:boostque/core/l10n/l10n.dart';
import 'package:boostque/core/providers.dart';
import 'package:boostque/core/theme/theme.dart';
import 'package:boostque/core/theme/tokens.dart';
import 'package:boostque/core/today_controller.dart';
import 'package:boostque/features/calendar/calendar_providers.dart';
import 'package:boostque/features/calendar/calendar_screen.dart';
import 'package:boostque/features/calendar/day_block_section.dart';
import 'package:boostque/features/calendar/day_progress_ring.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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

  Widget app(ProviderContainer container) {
    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        locale: const Locale('uk'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: bqTheme(),
        home: const CalendarScreen(),
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
    final rawSub = db.select(db.intakeLogs).watch().listen((v) => raw = v);
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
    final rawSub = db.select(db.intakeLogs).watch().listen((v) => raw = v);
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
      final rawSub = db.select(db.intakeLogs).watch().listen((v) => raw = v);
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
      final rawSub = db.select(db.intakeLogs).watch().listen((v) => raw = v);
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
}

/// A clock frozen on one day: [TodayController] with no timer and no
/// `DateTime.now()` read, so header date assertions are machine-independent.
class _FixedToday extends TodayController {
  _FixedToday(this.day);

  final DateTime day;

  @override
  DateTime build() => day;
}
