/// Widget tests for the Stack screen (plans 02-01 tracer + 02-05 full S1).
///
/// Harness: real in-memory Drift database behind the repository providers
/// (Phase-1 pattern, same as regimen_editor_test.dart), locale uk, 390x844
/// logical surface. Entries are seeded through the repositories BEFORE the
/// screen pumps.
///
/// Coverage:
/// - tracer: manual add via the sheet persists and renders a card; save
///   disabled for empty/whitespace names (V-1)
/// - empty state shows emptyStackTitle and NO ДОБАВКИ eyebrow (UI-SPEC #1)
/// - fresh entry: ЩОЙНО ДОДАНО chip, zero schedule chips (UI-SPEC #6)
/// - paused entry: ПАУЗА chip, summary chip retained (S1)
/// - active cyclic entry: АКТИВНА chip + schedule chip with slotsPerDay text
/// - card tap navigates into RegimenEditorScreen (STACK-04 edit path)
/// - the card's status derives from the shared `todayProvider` clock, not a
///   per-build clock read: the same seeded regimen renders ЗАПЛАНОВАНО before
///   its start date and АКТИВНА inside its window (plan 03-01, IN-06)
/// - takeException null in uk locale throughout
library;

import 'package:boostque/core/db/database.dart' show BoostqueDb;
import 'package:boostque/core/domain/models.dart';
import 'package:boostque/core/l10n/l10n.dart';
import 'package:boostque/core/providers.dart';
import 'package:boostque/core/theme/theme.dart';
import 'package:boostque/core/today_controller.dart';
import 'package:boostque/features/stack/regimen_editor_screen.dart';
import 'package:boostque/features/stack/stack_screen.dart';
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

  setUp(() {
    // LocaleController loads its persisted override from SharedPreferences.
    SharedPreferences.setMockInitialValues({});
  });

  /// Provider container over an in-memory database; callers seed through
  /// the repositories before pumping. Passing [today] pins the shared calendar
  /// clock so card statuses are asserted against a fixed day (IN-06).
  ProviderContainer makeContainer({DateTime? today}) {
    final container = ProviderContainer(
      overrides: [
        dbProvider.overrideWith((ref) {
          final db = BoostqueDb.forTesting(NativeDatabase.memory());
          ref.onDispose(db.close);
          return db;
        }),
        if (today != null) todayProvider.overrideWith(() => _FixedToday(today)),
      ],
    );
    // Keep the stack graph warm (Riverpod 3 pauses unlistened providers).
    final sub = container.listen(stackEntriesProvider, (_, _) {});
    addTearDown(sub.close);
    return container;
  }

  Widget app(ProviderContainer container) {
    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        locale: const Locale('uk'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: bqTheme(),
        home: const StackScreen(),
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
  /// zero-duration timers fire before flutter_test's pending-timer check.
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

  /// Pumps frames until [finder] matches (Drift stream emissions arrive
  /// asynchronously — same polling idea as test/providers_test.dart).
  Future<void> pumpUntilFound(WidgetTester tester, Finder finder) async {
    for (var i = 0; i < 200; i++) {
      await tester.pump(const Duration(milliseconds: 10));
      if (finder.evaluate().isNotEmpty) return;
    }
    fail('Timed out waiting for $finder');
  }

  /// A cyclic regimen for [supplement]; start defaults to a recent past day.
  Regimen cyclicRegimen({bool paused = false, DateTime? start}) => Regimen(
        id: 'r1',
        supplementId: 's1',
        kind: RegimenKind.cyclic,
        startDate: start ?? DateTime.utc(2026, 8, 1),
        endDate: null,
        onDays: 56,
        offDays: 28,
        paused: paused,
        slots: const [
          DoseSlot(id: 'slot1', minutesFromMidnight: 480, doseLabel: ''),
          DoseSlot(id: 'slot2', minutesFromMidnight: 1140, doseLabel: ''),
        ],
      );

  testWidgets(
      'uk: manual add through the sheet persists, lands on the regimen '
      'editor, and renders a card after returning; save stays disabled for '
      'empty/whitespace names (V-1)', (tester) async {
    usePhoneSurface(tester);
    final container = makeContainer();
    await tester.pumpWidget(app(container));
    await tester.pump();

    // Open the add sheet via the single CTA on the screen.
    await tester.tap(find.text('Додати добавку'));
    await tester.pumpAndSettle();

    // Switch to the manual tab (the search tab is the default).
    await tester.tap(find.text('Вручну'));
    await tester.pump();

    final Finder sheetSave = find.descendant(
      of: find.byType(BottomSheet),
      matching: find.byType(FilledButton),
    );
    expect(sheetSave, findsOneWidget);
    expect(tester.widget<FilledButton>(sheetSave).onPressed, isNull,
        reason: 'save must be disabled while the name is empty (V-1)');

    final Finder nameField = find
        .descendant(
          of: find.byType(BottomSheet),
          matching: find.byType(TextField),
        )
        .first;

    // Whitespace-only name: still disabled (trim rule).
    await tester.enterText(nameField, '   ');
    await tester.pump();
    expect(tester.widget<FilledButton>(sheetSave).onPressed, isNull,
        reason: 'whitespace-only name must not enable save (V-1)');

    // Real name enables save.
    await tester.enterText(nameField, 'Власна добавка');
    await tester.pump();
    expect(tester.widget<FilledButton>(sheetSave).onPressed, isNotNull);

    // Save: writes through the repository into the real in-memory DB, the
    // sheet closes, and the regimen editor opens for the new supplement.
    await tester.tap(sheetSave);
    await tester.pumpAndSettle();

    expect(find.byType(BottomSheet), findsNothing,
        reason: 'the sheet closed after a successful save');
    expect(find.byType(RegimenEditorScreen), findsOneWidget,
        reason: 'manual save lands on the regimen editor (S2)');

    // Back to the stack: the Drift stream delivers the new card.
    await tester.tap(find.byIcon(Icons.arrow_back_ios_new));
    await tester.pumpAndSettle();
    await pumpUntilFound(tester, find.text('Власна добавка'));
    expect(tester.takeException(), isNull,
        reason: 'no overflow/exception in uk locale');

    await tearDownTree(tester, container);
  });

  testWidgets(
      'uk: sheet tabs switch content in place — search input vs manual form',
      (tester) async {
    usePhoneSurface(tester);
    final container = makeContainer();
    await tester.pumpWidget(app(container));
    await tester.pump();

    await tester.tap(find.text('Додати добавку'));
    await tester.pumpAndSettle();

    // Search tab is the default: hint visible, full catalog listed (#8).
    expect(find.text('Назва або діюча речовина'), findsOneWidget);
    expect(find.text('Креатин моногідрат'), findsOneWidget,
        reason: 'empty query lists the full catalog');
    expect(find.text('Ашваганда KSM-66'), findsOneWidget);

    // Switch to manual: form appears in place, search input gone.
    await tester.tap(find.text('Вручну'));
    await tester.pump();
    expect(find.text('Назва або діюча речовина'), findsNothing);
    expect(find.text('Назва'), findsOneWidget);
    expect(find.byType(BottomSheet), findsOneWidget,
        reason: 'no page transition — content swaps in place');

    // And back to search.
    await tester.tap(find.text('Пошук у базі'));
    await tester.pump();
    expect(find.text('Назва або діюча речовина'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tearDownTree(tester, container);
  });

  testWidgets(
      'uk: typing "креат" narrows results; tapping the row adds the '
      'supplement and lands on the regimen editor; the card appears after '
      'returning (STACK-01)', (tester) async {
    usePhoneSurface(tester);
    final container = makeContainer();
    await tester.pumpWidget(app(container));
    await tester.pump();

    await tester.tap(find.text('Додати добавку'));
    await tester.pumpAndSettle();

    final Finder searchField = find.descendant(
      of: find.byType(BottomSheet),
      matching: find.byType(TextField),
    );
    await tester.enterText(searchField, 'креат');
    await tester.pump();

    expect(find.text('Креатин моногідрат'), findsOneWidget,
        reason: 'the query narrows the list to the matching entry');
    expect(find.text('Ашваганда KSM-66'), findsNothing);

    await tester.tap(find.text('Креатин моногідрат'));
    await tester.pumpAndSettle();

    expect(find.byType(BottomSheet), findsNothing);
    expect(find.byType(RegimenEditorScreen), findsOneWidget,
        reason: 'a catalog pick lands on the regimen editor (S2)');

    // Back to the stack: the copy-on-add card renders the catalog name.
    await tester.tap(find.byIcon(Icons.arrow_back_ios_new));
    await tester.pumpAndSettle();
    await pumpUntilFound(tester, find.text('Креатин моногідрат'));
    expect(find.text('5 г · порошок'), findsOneWidget,
        reason: 'the active locale dose text was copied onto the row (P-1)');
    expect(tester.takeException(), isNull);

    await tearDownTree(tester, container);
  });

  testWidgets(
      'uk: double-tapping a catalog row adds exactly ONE supplement and '
      'pushes exactly one editor (WR-01)', (tester) async {
    usePhoneSurface(tester);
    final container = makeContainer();
    await tester.pumpWidget(app(container));
    await tester.pump();

    await tester.tap(find.text('Додати добавку'));
    await tester.pumpAndSettle();

    // Observe supplements pump-driven (awaiting .first un-pumped deadlocks
    // against Drift's zero-duration timers in the test zone).
    List<Supplement>? supplements;
    final watchSub = container
        .read(supplementRepoProvider)
        .watchAll()
        .listen((v) => supplements = v);
    await tester.pump(const Duration(milliseconds: 10));

    final Finder searchField = find.descendant(
      of: find.byType(BottomSheet),
      matching: find.byType(TextField),
    );
    await tester.enterText(searchField, 'креат');
    await tester.pump();

    // Two taps with NO pump in between — the _busy guard must swallow the
    // second before it can upsert a second UUID or pop the editor.
    final row = find.text('Креатин моногідрат');
    await tester.tap(row);
    await tester.tap(row, warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(supplements, isNotNull);
    expect(supplements, hasLength(1),
        reason: 'a double tap must not mint two supplement rows');
    expect(find.byType(BottomSheet), findsNothing);
    expect(find.byType(RegimenEditorScreen), findsOneWidget,
        reason: 'exactly one editor route was pushed');

    expect(tester.takeException(), isNull);
    // Cancel pump-driven (Drift resolves the cancel future via a
    // zero-duration timer — awaiting it un-pumped would deadlock).
    // ignore: unawaited_futures
    watchSub.cancel();
    await tester.pump(const Duration(milliseconds: 10));
    await tearDownTree(tester, container);
  });

  testWidgets(
      'uk: a garbage query shows the rewritten noResultsCatalog copy (#9/D3)',
      (tester) async {
    usePhoneSurface(tester);
    final container = makeContainer();
    await tester.pumpWidget(app(container));
    await tester.pump();

    await tester.tap(find.text('Додати добавку'));
    await tester.pumpAndSettle();

    final Finder searchField = find.descendant(
      of: find.byType(BottomSheet),
      matching: find.byType(TextField),
    );
    await tester.enterText(searchField, 'йцукен123');
    await tester.pump();

    expect(
      find.text('Нічого не знайшли в каталозі. Додайте цю добавку вручну.'),
      findsOneWidget,
    );
    expect(find.text('Креатин моногідрат'), findsNothing);
    expect(tester.takeException(), isNull);

    await tearDownTree(tester, container);
  });

  testWidgets(
      'uk: empty stack renders emptyStackTitle below the still-visible CTA '
      'and omits the ДОБАВКИ eyebrow (UI-SPEC #1)', (tester) async {
    usePhoneSurface(tester);
    final container = makeContainer();
    await tester.pumpWidget(app(container));
    await pumpUntilFound(tester, find.text('Стек порожній'));

    expect(find.text('Стек порожній'), findsOneWidget);
    expect(find.text('Додайте першу добавку — з каталогу або вручну.'),
        findsOneWidget);
    expect(find.text('Додати добавку'), findsOneWidget,
        reason: 'the CTA stays visible above the empty state');
    expect(find.text('ДОБАВКИ'), findsNothing,
        reason: 'the eyebrow is omitted when the list is empty (#1)');
    expect(tester.takeException(), isNull);

    await tearDownTree(tester, container);
  });

  testWidgets(
      'uk: a fresh entry (no regimen, E-7) shows ЩОЙНО ДОДАНО and exactly '
      'zero schedule chips (UI-SPEC #6)', (tester) async {
    usePhoneSurface(tester);
    final container = makeContainer();
    await container.read(supplementRepoProvider).upsert(supplement);
    await tester.pumpWidget(app(container));
    await pumpUntilFound(tester, find.text('ЩОЙНО ДОДАНО'));

    expect(find.text('ЩОЙНО ДОДАНО'), findsOneWidget);
    expect(find.text('ДОБАВКИ'), findsOneWidget,
        reason: 'the eyebrow renders above a non-empty list');
    expect(find.textContaining('на день'), findsNothing,
        reason: 'a fresh entry gets NO schedule chip — never a placeholder');
    expect(tester.takeException(), isNull);

    await tearDownTree(tester, container);
  });

  testWidgets(
      'uk: a paused entry shows ПАУЗА and keeps its schedule-summary chip',
      (tester) async {
    usePhoneSurface(tester);
    final container = makeContainer();
    await container.read(supplementRepoProvider).upsert(supplement);
    await container.read(regimenRepoProvider).upsert(cyclicRegimen());
    await container.read(regimenRepoProvider).setPaused('r1', true);
    await tester.pumpWidget(app(container));
    await pumpUntilFound(tester, find.text('ПАУЗА'));

    expect(find.text('ПАУЗА'), findsOneWidget);
    expect(find.textContaining('на день'), findsOneWidget,
        reason: 'paused regimens keep their summary chip (S1)');
    expect(tester.takeException(), isNull);

    await tearDownTree(tester, container);
  });

  testWidgets(
      'uk: an active cyclic entry shows АКТИВНА and a schedule chip with the '
      'slotsPerDay text', (tester) async {
    usePhoneSurface(tester);
    final container = makeContainer();
    await container.read(supplementRepoProvider).upsert(supplement);
    await container.read(regimenRepoProvider).upsert(cyclicRegimen());
    await tester.pumpWidget(app(container));
    await pumpUntilFound(tester, find.text('АКТИВНА'));

    expect(find.text('АКТИВНА'), findsOneWidget);
    expect(find.textContaining('2 рази на день'), findsOneWidget,
        reason: 'the schedule chip composes slot count via ICU plural');
    expect(find.textContaining('8 тижнів'), findsOneWidget,
        reason: 'the cyclic summary composes on-weeks via weeksCount');
    // Header summary counts this entry as active: "1 добавка · 1 активна".
    expect(find.text('1 добавка · 1 активна'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tearDownTree(tester, container);
  });

  testWidgets(
      'uk: card status follows the shared todayProvider clock — ЗАПЛАНОВАНО '
      'before the start date, АКТИВНА inside the window (IN-06)',
      (tester) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('uk'));

    usePhoneSurface(tester);
    // Two weeks BEFORE the regimen's 2026-08-01 start.
    final before = makeContainer(today: DateTime.utc(2026, 7, 18));
    await before.read(supplementRepoProvider).upsert(supplement);
    await before.read(regimenRepoProvider).upsert(cyclicRegimen());
    await tester.pumpWidget(app(before));
    await pumpUntilFound(tester, find.text(l10n.statusPlanned));

    expect(find.text(l10n.statusPlanned), findsOneWidget,
        reason: 'the overridden clock sits before startDate');
    expect(find.text(l10n.statusActive), findsNothing);
    expect(tester.takeException(), isNull);
    await tearDownTree(tester, before);

    // Same seed, same card — only the shared clock moves.
    final inside = makeContainer(today: DateTime.utc(2026, 8, 10));
    await inside.read(supplementRepoProvider).upsert(supplement);
    await inside.read(regimenRepoProvider).upsert(cyclicRegimen());
    await tester.pumpWidget(app(inside));
    await pumpUntilFound(tester, find.text(l10n.statusActive));

    expect(find.text(l10n.statusActive), findsOneWidget,
        reason: 'the card re-derives its status from todayProvider, never '
            'from a per-build clock read');
    expect(find.text(l10n.statusPlanned), findsNothing);
    expect(l10n.statusActive, isNot(l10n.statusPlanned));
    expect(tester.takeException(), isNull);
    await tearDownTree(tester, inside);
  });

  testWidgets('uk: tapping a card opens the regimen editor for it (STACK-04)',
      (tester) async {
    usePhoneSurface(tester);
    final container = makeContainer();
    await container.read(supplementRepoProvider).upsert(supplement);
    await tester.pumpWidget(app(container));
    await pumpUntilFound(tester, find.text('Магній бісглицинат'));

    await tester.tap(find.text('Магній бісглицинат'));
    await tester.pumpAndSettle();

    expect(find.byType(RegimenEditorScreen), findsOneWidget,
        reason: 'the whole card is the tap target into the editor');
    expect(tester.takeException(), isNull);

    await tearDownTree(tester, container);
  });
}

/// Pins the shared calendar clock to a fixed UTC date-only day; overriding
/// [TodayController.build] also means no midnight Timer and no lifecycle
/// listener are armed inside the test.
class _FixedToday extends TodayController {
  _FixedToday(this.day);

  final DateTime day;

  @override
  DateTime build() => day;
}
