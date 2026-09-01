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
/// - plan 05-04: a locale × textScaler matrix over three screen states
///   (populated, empty, add-supplement sheet open) in BOTH shipped languages,
///   plus the E-12 copy-on-add assertion
/// - plan 05-05: the catalog add affordance's accessibility label read off the
///   semantics tree in BOTH languages (A2 / PF-5), and the LOCKED-FONT
///   source gates over pubspec.yaml + lib/core/theme/ (T-05-11)
library;

import 'dart:async';
import 'dart:io';

import 'package:boostque/core/db/database.dart' show BoostqueDb;
import 'package:boostque/core/domain/models.dart';
import 'package:boostque/core/domain/repositories.dart' show StackEntry;
import 'package:boostque/core/l10n/l10n.dart';
import 'package:boostque/core/l10n/locale_controller.dart';
import 'package:boostque/core/providers.dart';
import 'package:boostque/core/theme/theme.dart';
import 'package:boostque/core/today_controller.dart';
import 'package:boostque/core/widgets/bq_add_fab.dart';
import 'package:boostque/features/settings/settings_screen.dart';
import 'package:boostque/features/stack/regimen_editor_screen.dart';
import 'package:boostque/features/stack/stack_screen.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/locale_matrix.dart';

void main() {
  const supplement = Supplement(
    id: 's1',
    name: 'Магній бісглицинат',
    doseText: '400 мг · капсули',
    colorValue: 0xFF6B6FA8,
    note: '',
  );

  late SharedPreferences seededPrefs;

  setUp(() async {
    // LocaleController loads its persisted override from SharedPreferences.
    // The one-time hints are pre-dismissed: every case here models a user
    // past first run, and since v1.2 the regimen editor this screen pushes
    // into renders the cycle hint from the same store. The hints have their
    // own suite (first_run_hints_test.dart).
    SharedPreferences.setMockInitialValues({
      'first_run_hints_seen': <String>['hint_cycle', 'hint_mark_dose'],
    });
    seededPrefs = await SharedPreferences.getInstance();
  });

  /// Provider container over an in-memory database; callers seed through
  /// the repositories before pumping. Passing [today] pins the shared calendar
  /// clock so card statuses are asserted against a fixed day (IN-06).
  /// [prefs] overrides the store for the one test that drives the language
  /// through [localeControllerProvider]; every other container gets the
  /// suite's seeded instance. The override is no longer optional: since v1.2
  /// the regimen editor this screen pushes into reads the dismissed-hint set
  /// from the same store, and [sharedPreferencesProvider] throws unless
  /// overridden (plan 05-01, P-4 Option A).
  ProviderContainer makeContainer({DateTime? today, SharedPreferences? prefs}) {
    final container = ProviderContainer(
      overrides: [
        dbProvider.overrideWith((ref) {
          final db = BoostqueDb.forTesting(NativeDatabase.memory());
          ref.onDispose(db.close);
          return db;
        }),
        if (today != null) todayProvider.overrideWith(() => _FixedToday(today)),
        sharedPreferencesProvider.overrideWithValue(prefs ?? seededPrefs),
      ],
    );
    // Keep the stack graph warm (Riverpod 3 pauses unlistened providers).
    final sub = container.listen(stackEntriesProvider, (_, _) {});
    addTearDown(sub.close);
    return container;
  }

  /// [locale] parameterizes the render matrix: an error state is a screen
  /// state, so it has to be proven in BOTH shipped languages (L10N-01).
  /// [textScaler] pins the accessibility text scale for the whole subtree —
  /// the axis longer translated strings break on, and the one this screen had
  /// no coverage of at all before plan 05-04 (E-14). Same signature as
  /// `plannerApp` (`planner_screen_test.dart:142-163`), so the matrix below is
  /// a loop rather than a dozen copies.
  Widget app(
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
        // Since plan 06-04 the add affordance is the shell's floating + , not
        // a button on this screen — the full-width accent CTA is deleted. The
        // harness therefore hosts StackScreen the way the shell does, under a
        // Scaffold carrying the REAL [BqAddFab], so every add flow below is
        // driven through the same control the user actually touches. Where
        // the FAB is mounted (root Scaffold, all three tabs, never Settings)
        // is asserted in `app_shell_test.dart`; this file asserts what
        // happens when it is used above the Стек screen.
        home: const Scaffold(
          body: StackScreen(),
          floatingActionButton: BqAddFab(),
        ),
      ),
    );
  }

  /// Opens the add-supplement sheet through the FAB.
  ///
  /// Matched by WIDGET TYPE, never by the `addSupplement` label: that string
  /// is also the FAB's semantics label and, before plan 06-04, was the
  /// deleted button's painted text. A label finder here would be a finder
  /// that says "some node carrying this string", which is exactly how a
  /// retargeted assertion starts passing for the wrong reason (T-06-10).
  Future<void> openAddSheet(WidgetTester tester) async {
    expect(find.byType(BqAddFab), findsOneWidget);
    await tester.tap(find.byType(BqAddFab));
    await tester.pumpAndSettle();
  }

  /// The same screen with the language coming from [localeControllerProvider]
  /// instead of from a pinned `locale:` — the only harness that can flip the
  /// language of an already-mounted tree, which is what E-12 needs.
  Widget localeDrivenApp(ProviderContainer container) {
    return UncontrolledProviderScope(
      container: container,
      child: Consumer(
        builder: (context, ref, _) => MaterialApp(
          locale: ref.watch(localeControllerProvider),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: bqTheme(),
          // Same shell-shaped host as `app` above: the add flow this harness
          // drives goes through the FAB since plan 06-04.
          home: const Scaffold(
            body: StackScreen(),
            floatingActionButton: BqAddFab(),
          ),
        ),
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

    // Open the add sheet through the single add affordance — the FAB.
    await openAddSheet(tester);

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

    await openAddSheet(tester);

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

    await openAddSheet(tester);

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

    await openAddSheet(tester);

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

    await openAddSheet(tester);

    final Finder searchField = find.descendant(
      of: find.byType(BottomSheet),
      matching: find.byType(TextField),
    );
    await tester.enterText(searchField, 'йцукен123');
    await tester.pump();

    expect(
      find.text('У каталозі нічого не знайшлося. Додайте цю добавку вручну.'),
      findsOneWidget,
    );
    expect(find.text('Креатин моногідрат'), findsNothing);
    expect(tester.takeException(), isNull);

    await tearDownTree(tester, container);
  });

  testWidgets(
      'uk: empty stack renders emptyStackTitle, body copy pointing at the + , '
      'and omits the ДОБАВКИ eyebrow (UI-SPEC #1, UX-01)', (tester) async {
    usePhoneSurface(tester);
    final handle = tester.ensureSemantics();
    final container = makeContainer();
    await tester.pumpWidget(app(container));
    await pumpUntilFound(tester, find.text('Стек порожній'));

    expect(find.text('Стек порожній'), findsOneWidget);
    // The rewritten body (plan 06-04): it names the + ACTION, not a screen
    // corner, so it stays true under RTL and if the FAB ever moves.
    expect(find.text('Додайте першу добавку кнопкою +: з каталогу або вручну.'),
        findsOneWidget);

    // The affordance the copy points at, asserted as the FAB's OWN semantics
    // node — deliberately NOT `find.text('Додати добавку')`. That finder used
    // to match the deleted full-width button, and a bare-label finder here
    // would be satisfied by any node carrying the string rather than by the
    // control existing (T-06-10).
    expect(find.byType(BqAddFab), findsOneWidget);
    expect(
      tester.getSemantics(find.byType(BqAddFab)),
      isSemantics(
        isButton: true,
        label: 'Додати добавку',
        hasTapAction: true,
      ),
      reason: 'the empty state\'s single next step is the floating + , and a '
          'screen-reader user learns what it does from this node alone',
    );
    expect(find.byType(FilledButton), findsNothing,
        reason: 'the full-width accent add button is DELETED — the Стек '
            'screen has no accent-filled block of its own (UX-01)');

    expect(find.text('ДОБАВКИ'), findsNothing,
        reason: 'the eyebrow is omitted when the list is empty (#1)');
    expect(tester.takeException(), isNull);

    handle.dispose();

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
      'uk: the LAST card of a full stack is still reachable by scrolling with '
      'the FAB present at textScaler 2.0 (T-06-11, UX-01)', (tester) async {
    usePhoneSurface(tester);
    final container = makeContainer();
    // Enough entries that the list must scroll at any scale.
    for (var i = 0; i < 12; i++) {
      await container.read(supplementRepoProvider).upsert(
            Supplement(
              id: 's$i',
              name: 'Добавка $i',
              doseText: '${100 + i} мг · капсули',
              colorValue: 0xFF6B6FA8,
              note: '',
            ),
          );
    }
    await tester.pumpWidget(
      app(container, textScaler: const TextScaler.linear(2.0)),
    );
    await pumpUntilFound(tester, find.text('Добавка 0'));

    // What `bottom: 84` is FOR: the FAB occupies 16 + 56 = 72px above the
    // viewport bottom, so the last card must come to rest clear of it. This
    // is asserted rather than re-derived — a padding someone "tidied" to 56
    // would put the last card under the disc, where it cannot be tapped.
    await tester.dragUntilVisible(
      find.text('Добавка 11'),
      find.byType(ListView),
      const Offset(0, -300),
    );
    // Then all the way to the END of the extent, which is where the last card
    // comes to rest and the only position `bottom: 84` has to protect.
    // `dragUntilVisible` stops as soon as the target is on screen, which is
    // not the same place.
    await tester.drag(find.byType(ListView), const Offset(0, -2000));
    await tester.pumpAndSettle();
    final ScrollPosition position =
        tester.state<ScrollableState>(find.byType(Scrollable).first).position;
    expect(position.pixels, position.maxScrollExtent,
        reason: 'the assertion below is only about the RESTING position of '
            'the last card; if the list is not at its end, it measures '
            'nothing');

    // The WHOLE card, not just its name line: the name sits at the card's top
    // and would clear the FAB even with the bottom padding removed, which is
    // precisely the assertion that would measure nothing. The card's own tap
    // target is the box that must stay clear.
    final Rect card = tester.getRect(
      find
          .ancestor(
            of: find.text('Добавка 11'),
            matching: find.byType(GestureDetector),
          )
          .first,
    );
    final Rect fab = tester.getRect(find.byType(BqAddFab));
    expect(card.bottom, lessThanOrEqualTo(fab.top),
        reason: 'the last card scrolled to a position the FAB covers — the '
            'user cannot read or tap the entry they scrolled to');
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

  // ---------------------------------------------------------------------
  // The error surface under LIVE retry (plan 05-02, UI-SPEC A1 / P-9).
  // ---------------------------------------------------------------------

  /// The consequence of a red case, named in device terms rather than as a
  /// restatement of the assertion.
  const blankBodyReason =
      'a user whose local database fails sees an EMPTY stack body for the '
      "whole of Riverpod's ~38.2s default backoff — indistinguishable from "
      '"you have no supplements" — instead of the error copy and the retry '
      'control this screen already has designed and localized. The fix is the '
      'rendering rule (skipLoadingOnReload), never a disabled retry';

  for (final locale in const ['uk', 'en']) {
    final loadError = locale == 'uk'
        ? 'Не вдалося завантажити стек. Спробуйте ще раз.'
        : "Couldn't load your stack. Try again.";
    final retryLabel = locale == 'uk' ? 'Повторити' : 'Retry';

    testWidgets(
        '$locale: a failing stack stream shows the error copy plus retry on '
        "the FIRST frame, not after Riverpod's ~38s backoff (A1 / P-9)",
        (tester) async {
      usePhoneSurface(tester);
      // NOTE: this container deliberately supplies NO `retry:` override. The
      // ABSENCE of it is the whole point: Riverpod's default backoff is LIVE
      // here, which is the state the neighbouring CR-02 recovery test disables
      // and therefore never exercised. Copying that test's `retry:` line into
      // this one would silently restore the blind spot the defect lived in.
      //
      // The failure is seeded on the STREAM that actually fails, not on the
      // derived `stackEntriesProvider` — the named-recovery-path rule (CR-02):
      // a derivation has no subscription of its own, so pinning it would prove
      // nothing about how a real Drift failure propagates.
      final container = ProviderContainer(
        overrides: [
          supplementsStreamProvider.overrideWith(
            (ref) => Stream<List<Supplement>>.error(
              Exception('boom-from-drift'),
              StackTrace.empty,
            ),
          ),
          regimensStreamProvider.overrideWith(
            (ref) => Stream.value(const <Regimen>[]),
          ),
        ],
      );

      await tester.pumpWidget(app(container, locale: locale));
      // ONE frame. Never pumpAndSettle: with the retry timers live it would
      // either time out or wait out the backoff and pass for the wrong
      // reason (PF-7).
      await tester.pump();

      expect(find.text(loadError), findsOneWidget, reason: blankBodyReason);
      expect(find.text(retryLabel), findsOneWidget,
          reason: 'the error copy without its recovery control is a dead end');
      expect(find.textContaining('boom-from-drift'), findsNothing,
          reason: 'raw exception text never enters the widget tree (T-05-03)');
      expect(find.textContaining('Exception'), findsNothing,
          reason: 'nor does the exception type name (T-05-03)');
      expect(tester.takeException(), isNull);

      await tearDownTree(tester, container);
    });

    testWidgets(
        '$locale: a failing regimen stream reaches the error surface while the '
        'supplement stream is still in its FIRST load (WR-01)', (tester) async {
      usePhoneSurface(tester);
      // The composition inside stackEntriesProvider evaluates `supplements`
      // first, so its loading arm decided the outcome for BOTH sources: an
      // error already sitting in `regimens` was discarded. skipLoadingOnReload
      // cannot help here by construction — a first load carries no previous
      // value, so there is no reload to skip. This is the same defect class as
      // the case above, one layer higher up.
      final firstLoad = StreamController<List<Supplement>>();
      addTearDown(firstLoad.close);
      final container = ProviderContainer(
        overrides: [
          supplementsStreamProvider.overrideWith((ref) => firstLoad.stream),
          regimensStreamProvider.overrideWith(
            (ref) => Stream<List<Regimen>>.error(
              Exception('boom-from-drift'),
              StackTrace.empty,
            ),
          ),
        ],
      );

      await tester.pumpWidget(app(container, locale: locale));
      await tester.pump();

      expect(find.text(loadError), findsOneWidget, reason: blankBodyReason);
      expect(find.text(retryLabel), findsOneWidget,
          reason: 'the error copy without its recovery control is a dead end');
      expect(find.textContaining('boom-from-drift'), findsNothing,
          reason: 'raw exception text never enters the widget tree (T-05-03)');
      expect(tester.takeException(), isNull);

      await tearDownTree(tester, container);
    });

    testWidgets(
        '$locale: the screen renders the error surface from a RETRYING '
        'failure on its own terms, not because of what the derivation '
        'returns (WR-02)', (tester) async {
      usePhoneSurface(tester);
      // The screen is pinned straight to a failed value, bypassing
      // stackEntriesProvider's own wiring, so what is asserted here is the
      // SCREEN's rendering rule — the layer WR-02 found was decorative (a
      // `skipLoadingOnReload` argument that could never change an outcome,
      // under a comment claiming the error surface depended on it).
      //
      // The rule is a match on the hasError PROPERTY, in this arm order, so
      // every shape a failure takes during Riverpod's backoff reaches the
      // error arm — the plain error below, the `retrying` error 3.4.2 parks in
      // between attempts, and a loading value that carries a previous error.
      // Matching an error SUBTYPE alone would cover only the first.
      final failed = AsyncError<List<StackEntry>>(
        Exception('boom-from-drift'),
        StackTrace.empty,
      );
      expect(failed.hasError, isTrue);

      final container = ProviderContainer(
        overrides: [stackEntriesProvider.overrideWithValue(failed)],
      );

      await tester.pumpWidget(app(container, locale: locale));
      await tester.pump();

      expect(find.text(loadError), findsOneWidget, reason: blankBodyReason);
      expect(find.text(retryLabel), findsOneWidget,
          reason: 'the error copy without its recovery control is a dead end');
      expect(tester.takeException(), isNull);

      await tearDownTree(tester, container);
    });
  }

  // ---------------------------------------------------------------------
  // The bilingual × text-scale matrix (plan 05-04, L10N-01 criterion 1,
  // V-4 / E-14 / T-05-08 / T-05-09).
  //
  // Before this plan the Stack screen and its add-supplement sheet had been
  // rendered in English exactly zero times by any test: criterion 1 is a claim
  // about SCREENS, and an ARB audit cannot make it.
  // ---------------------------------------------------------------------

  /// Seed for the matrix cases: a LATIN supplement name, on purpose.
  ///
  /// A supplement's name is user data — typed by the user, or copied off the
  /// catalog in whichever language was active at add-time — and it never
  /// re-localizes (E-12, asserted at the bottom of this file). Seeding a
  /// Cyrillic name here would therefore trip the English Cyrillic sweep on a
  /// string that is CORRECT, and the only ways out would be to weaken the
  /// sweep or to allowlist user data wholesale. Neither is acceptable (A8), so
  /// the chrome is what gets swept and the seeded data is kept neutral.
  const matrixSupplement = Supplement(
    id: 'm1',
    name: 'Magnesium 400',
    doseText: '400 mg',
    colorValue: 0xFF6B6FA8,
    note: '',
  );

  Regimen matrixRegimen() => Regimen(
        id: 'mr1',
        supplementId: 'm1',
        kind: RegimenKind.cyclic,
        startDate: DateTime.utc(2026, 8, 1),
        endDate: null,
        onDays: 56,
        offDays: 28,
        paused: false,
        slots: const [
          DoseSlot(id: 'ms1', minutesFromMidnight: 480, doseLabel: ''),
          DoseSlot(id: 'ms2', minutesFromMidnight: 1140, doseLabel: ''),
        ],
      );

  group('bilingual render matrix (L10N-01)', () {
    for (final locale in const ['uk', 'en']) {
      final l10n = lookupAppLocalizations(Locale(locale));

      for (final scale in const <double>[1.0, 1.6]) {
        final scaler = TextScaler.linear(scale);

        testWidgets(
            '$locale: a POPULATED stack renders in the active language with '
            'no layout exception at textScaler $scale', (tester) async {
          usePhoneSurface(tester);
          // The clock is pinned inside the regimen's window so the card's
          // status is the same string on any machine, on any day (IN-06).
          final container = makeContainer(today: DateTime.utc(2026, 8, 10));
          await container.read(supplementRepoProvider).upsert(matrixSupplement);
          await container.read(regimenRepoProvider).upsert(matrixRegimen());
          await tester.pumpWidget(
            app(container, locale: locale, textScaler: scaler),
          );
          await pumpUntilFound(tester, find.text(l10n.statusActive));

          // In the RIGHT language, not merely rendered: all three of these
          // differ between uk and en, so a screen that fell back to the other
          // language fails here instead of passing on a bare render.
          expect(find.text(l10n.stackTitle), findsOneWidget);
          expect(find.text(l10n.supplementsLabel), findsOneWidget);
          expect(find.text(l10n.statusActive), findsOneWidget);
          expect(find.text('Magnesium 400'), findsOneWidget,
              reason: 'the card is populated — a matrix case over an empty '
                  'body would prove nothing about the card layout');

          if (locale == 'en') {
            expectNoCyrillicWhileEn(tester);
          }
          expect(tester.takeException(), isNull, reason: overflowReason);

          await tearDownTree(tester, container);
        });

        testWidgets(
            '$locale: an EMPTY stack renders in the active language with no '
            'layout exception at textScaler $scale', (tester) async {
          usePhoneSurface(tester);
          final container = makeContainer(today: DateTime.utc(2026, 8, 10));
          await tester.pumpWidget(
            app(container, locale: locale, textScaler: scaler),
          );
          await pumpUntilFound(tester, find.text(l10n.emptyStackTitle));

          expect(find.text(l10n.emptyStackTitle), findsOneWidget);
          expect(find.text(l10n.emptyStackBody), findsOneWidget);
          // The add affordance, matched by WIDGET rather than by the
          // `addSupplement` string: since plan 06-04 that string is a
          // semantics label, and a text finder for it would now assert
          // nothing about whether the control is on screen (T-06-10).
          expect(find.byType(BqAddFab), findsOneWidget,
              reason: 'the floating + is the empty state\'s single next step '
                  'in $locale at scale $scale (#1, UX-01)');

          if (locale == 'en') {
            expectNoCyrillicWhileEn(tester);
          }
          expect(tester.takeException(), isNull, reason: overflowReason);

          await tearDownTree(tester, container);
        });

        testWidgets(
            '$locale: the ADD-SUPPLEMENT SHEET renders BOTH tabs in the '
            'active language with no layout exception at textScaler $scale',
            (tester) async {
          usePhoneSurface(tester);
          final container = makeContainer(today: DateTime.utc(2026, 8, 10));
          await tester.pumpWidget(
            app(container, locale: locale, textScaler: scaler),
          );
          await pumpUntilFound(tester, find.byType(BqAddFab));

          await openAddSheet(tester);

          // Search tab (the default): hint + the catalog resolved in the
          // ACTIVE language — the catalog is ARB-backed, so an en render that
          // still listed Ukrainian names would be a leak, not user data.
          expect(find.text(l10n.searchCatalogHint), findsOneWidget);
          expect(find.text(l10n.catalogCreatineName), findsOneWidget);
          if (locale == 'en') {
            expectNoCyrillicWhileEn(tester);
          }
          expect(tester.takeException(), isNull, reason: overflowReason);

          // Manual tab: the form swaps in place.
          await tester.tap(find.text(l10n.manualTab));
          await tester.pump();
          expect(find.text(l10n.nameLabel), findsOneWidget);
          expect(find.text(l10n.doseLabel), findsOneWidget);
          expect(find.text(l10n.searchCatalogHint), findsNothing);

          if (locale == 'en') {
            expectNoCyrillicWhileEn(tester);
          }
          expect(tester.takeException(), isNull, reason: overflowReason);

          await tearDownTree(tester, container);
        });
      }
    }
  });

  // ---------------------------------------------------------------------
  // Amendment A2 / PF-5: the catalog row's add affordance carries an
  // accessibility label built from ONE ARB key with two placeholders, so the
  // word order and the separator between "the action" and "the name" are a
  // translator's decision rather than a Dart string literal.
  //
  // The label is invisible: it is never rendered text, so no text finder and
  // no render-matrix case can see it, and the bilingual matrix above would
  // stay green with the two fragments glued together in the wrong order for
  // Ukrainian. It is read off the semantics tree here, in BOTH languages,
  // because "uk and en happen to share this word order" is an assumption and
  // not a fact about any future language (T-05-04).
  // ---------------------------------------------------------------------

  group('catalog add affordance: a11y label comes from the ARB (A2, PF-5)', () {
    /// The expected label per language, written out as a LITERAL.
    ///
    /// Deliberately NOT rebuilt by calling
    /// `l10n.addSupplementCatalogSemantics(l10n.addSupplement, name)` — that
    /// is the exact expression the widget evaluates, so an assertion against
    /// it would pass for any word order, any separator and any placeholder
    /// ordering, i.e. it would pin nothing at all. Spelling the sentence out
    /// is what makes a reordered uk translation a red test rather than a
    /// silent change to what a screen-reader user hears.
    const expectedLabel = <String, String>{
      'uk': 'Додати добавку: Креатин моногідрат',
      'en': 'Add supplement: Creatine monohydrate',
    };

    for (final locale in const ['uk', 'en']) {
      final l10n = lookupAppLocalizations(Locale(locale));
      final other = locale == 'uk' ? 'en' : 'uk';

      testWidgets(
          '$locale: the trailing "+" announces "${expectedLabel[locale]}" — '
          'one ARB key, two placeholders, no Dart-side concatenation',
          (tester) async {
        usePhoneSurface(tester);
        final handle = tester.ensureSemantics();
        final container = makeContainer(today: DateTime.utc(2026, 8, 10));
        await tester.pumpWidget(app(container, locale: locale));
        await pumpUntilFound(tester, find.byType(BqAddFab));

        await openAddSheet(tester);
        await pumpUntilFound(tester, find.text(l10n.catalogCreatineName));

        // Scope to ONE catalog row: every row carries a "+", so an unscoped
        // finder would be ambiguous and `getSemantics` would throw.
        final row = find
            .ancestor(
              of: find.text(l10n.catalogCreatineName),
              matching: find.byType(Row),
            )
            .first;
        final plus = find.descendant(of: row, matching: find.text('+'));
        expect(plus, findsOneWidget,
            reason: 'the icon-only affordance is the thing being labelled; if '
                'this stops matching, the assertion below is measuring some '
                'other node');

        // `excludeSemantics: true` drops the bare "+" glyph, and the whole
        // row is one tap target, so the "+"'s annotation is MERGED into the
        // row's node alongside the name and dose Texts: the published label
        // is "name\ndose\n<the sentence>", not the sentence alone. Assert on
        // the segment rather than on the whole node — that keeps the check
        // exact about the part this task owns (the ARB sentence) without
        // freezing what else the row happens to announce.
        final node = tester.getSemantics(plus);
        final segments = node.label.split('\n');
        expect(segments, contains(expectedLabel[locale]),
            reason: 'an icon-only control with a wrong-language or '
                'wrong-order label is unusable with a screen reader, and it '
                'is invisible to every rendered assertion in this file — the '
                'sentence belongs to the ARB (PF-5, T-05-04)');
        expect(node, isSemantics(isButton: true),
            reason: 'the label only helps if the node is announced as a '
                'control the user can activate');
        expect(node.label, isNot(contains('+')),
            reason: 'excludeSemantics keeps the decorative glyph out of the '
                'announcement');

        // The OTHER language's sentence must not be reachable — proof the
        // label followed the active locale rather than a captured default.
        // Asserted against this node's own label, not through a tree-wide
        // finder: `bySemanticsLabel` matches a node label WHOLE, and this
        // node's label is the merged multi-line string above, so a tree-wide
        // finder would report "not found" in both locales and prove nothing.
        expect(node.label, isNot(contains(expectedLabel[other]!)),
            reason: 'the label is resolved per-locale like every other ARB '
                'value, not baked in at first build');

        expect(tester.takeException(), isNull, reason: overflowReason);

        handle.dispose();
        await tearDownTree(tester, container);
      });
    }

    test(
        'add_supplement_sheet.dart concatenates no localized fragments — the '
        'PF-5 source gate', () {
      final source = File('lib/features/stack/add_supplement_sheet.dart')
          .readAsStringSync()
          .split('\n')
          .where((line) => !line.trimLeft().startsWith('//'))
          .join('\n');

      expect(source, isNot(contains(r'${l10n.')),
          reason: 'gluing two localized fragments together inside a Dart '
              'string hardcodes this language pair\'s word order and its '
              'separator into the binary, where no translator can reach them '
              'and no ARB-parity gate can see them: the resulting string is '
              'not a literal, so the no-hardcoded-strings gate passes it. The '
              'fix is always a new ARB key with placeholders (the '
              'pre-formatted-count idiom), never an allowlist entry '
              '(PF-5, A2)');
    });
  });

  // ---------------------------------------------------------------------
  // LOCKED-FONT (05-UI-SPEC, P-10, threat T-05-11): the app keeps the
  // PLATFORM Cyrillic fallback. Instrument Sans carries no Cyrillic glyphs —
  // cmap-verified twice, and upstream declares latin subsets only — so
  // Ukrainian letters render from SF (iOS) / Roboto (Android) while Latin
  // letters and digits on the same line render from Instrument Sans. The
  // approved HTML mockup was itself rendered in a browser where that font
  // has no Cyrillic, so the Ukrainian screens the user signed off on ARE
  // this fallback rendering. Mixed-family lines are an ACCEPTED consequence,
  // not a defect (see the locked-decisions section of 05-05-SUMMARY.md).
  //
  // These gates exist because that decision is a "change nothing" decision,
  // and a "change nothing" decision is the kind a later reader silently
  // reverses after seeing the symptom without the reasoning. They read
  // SOURCE off disk rather than the running theme, because two of the three
  // things being protected (the pubspec declaration, the absence of a
  // fallback family) are not observable from a widget tree at all.
  // ---------------------------------------------------------------------

  group('LOCKED-FONT gates (T-05-11)', () {
    /// Named once: every assertion below has the same consequence, and a
    /// `reason:` that drifts between them stops naming one defect class.
    const fontChangeReason =
        'the bundled font families are a LOCKED v1 decision (05-UI-SPEC '
        'LOCKED-FONT). Changing the primary family, or adding a fallback '
        'family, changes glyph metrics app-wide: it invalidates the Phase-4 '
        'gantt truncation measurements (156.0px allotted / 183.1px intrinsic) '
        'and requires a full re-run of the bilingual text-scale matrix. That '
        'is a deliberate decision with that work budgeted — never a quiet '
        'edit, and never a red test relaxed to green';

    const sansFamily = 'Instrument Sans';
    const monoFamily = 'JetBrains Mono';

    test('pubspec.yaml declares exactly two font families, unchanged', () {
      final pubspec = File('pubspec.yaml').readAsLinesSync();

      final families = pubspec
          .map((line) => RegExp(r'^\s*-\s*family:\s*(.+?)\s*$').firstMatch(line))
          .nonNulls
          .map((m) => m.group(1)!)
          .toList();
      expect(families, <String>[sansFamily, monoFamily],
          reason: 'a THIRD family — a Cyrillic-capable primary, or a family '
              'added to be used as a fallback — is the forbidden remediation: '
              '$fontChangeReason');

      final assets = pubspec
          .map((line) => RegExp(r'^\s*-\s*asset:\s*(.+?)\s*$').firstMatch(line))
          .nonNulls
          .map((m) => m.group(1)!)
          .toList();
      expect(
          assets,
          <String>[
            'assets/fonts/InstrumentSans[wdth,wght].ttf',
            'assets/fonts/JetBrainsMono[wght].ttf',
          ],
          reason: 'swapping the FILE behind an unchanged family name is the '
              'same change wearing a disguise: $fontChangeReason');
    });

    test('no fontFamilyFallback anywhere under lib/', () {
      final offenders = <String>[];
      for (final entity in Directory('lib').listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        if (entity.path.contains('/l10n/gen/')) continue;
        final source = entity
            .readAsLinesSync()
            .where((line) => !line.trimLeft().startsWith('//'))
            .join('\n');
        if (source.contains('fontFamilyFallback')) offenders.add(entity.path);
      }
      // The glob must have resolved something — an empty scan passing
      // silently is the way a source gate stops gating.
      expect(Directory('lib').listSync(recursive: true).whereType<File>(),
          isNotEmpty);
      expect(offenders, isEmpty,
          reason: 'a fallback family is the WORST of the rejected options — '
              'it still mixes two families inside a single line (digits from '
              'the primary, Cyrillic from the fallback) AND pays the bundle '
              'cost, so it buys nothing over the platform fallback the app '
              'already gets for free. $fontChangeReason');
    });

    test('the theme uses the bundled families and nothing else', () {
      final theme = File('lib/core/theme/theme.dart').readAsStringSync();

      final declared = RegExp(r"fontFamily:\s*'([^']+)'")
          .allMatches(theme)
          .map((m) => m.group(1)!)
          .toList();
      expect(declared, isNotEmpty,
          reason: 'if the regex stops matching, this gate has silently '
              'stopped reading the thing it protects');
      expect(declared.first, sansFamily,
          reason: 'ThemeData.fontFamily is the app-wide primary: every '
              'non-mono string in both languages renders through it. '
              '$fontChangeReason');
      expect(declared.toSet(), <String>{sansFamily, monoFamily},
          reason: 'the theme may name only families pubspec actually '
              'bundles; anything else resolves to a platform default at '
              'runtime with no build-time error. $fontChangeReason');
    });
  });

  testWidgets(
      'a catalog-added supplement keeps its add-time NAME after the language '
      'changes — copy-on-add is intended behaviour, not a bug (E-12)',
      (tester) async {
    usePhoneSurface(tester);
    final uk = lookupAppLocalizations(const Locale('uk'));
    final en = lookupAppLocalizations(const Locale('en'));

    SharedPreferences.setMockInitialValues({'app_locale': 'uk', 'first_run_hints_seen': <String>['hint_cycle', 'hint_mark_dose'],});
    final prefs = await SharedPreferences.getInstance();
    final container = makeContainer(
      today: DateTime.utc(2026, 8, 10),
      prefs: prefs,
    );
    await tester.pumpWidget(localeDrivenApp(container));
    await tester.pump();

    // Add the catalog entry while UKRAINIAN is active: the row copies the
    // active locale's name onto the Supplement (catalog.dart:11-15).
    await openAddSheet(tester);
    await tester.tap(find.text(uk.catalogCreatineName));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.arrow_back_ios_new));
    await tester.pumpAndSettle();
    await pumpUntilFound(tester, find.text(uk.catalogCreatineName));

    // Flip the language on the mounted tree. ONE frame: more than one would
    // itself say the switch is not instant (PF-3).
    container.read(localeControllerProvider.notifier).setLocale(
          const Locale('en'),
        );
    await tester.pump();

    // The chrome DID change — without this the assertion below would pass
    // trivially on a flip that never happened.
    expect(find.text(en.supplementsLabel), findsOneWidget,
        reason: 'the eyebrow is ARB copy, so it must follow the language');
    expect(find.text(uk.supplementsLabel), findsNothing);

    // The stored name did NOT. From the moment of the add it is user data:
    // renaming a user's supplements out from under them because they changed
    // the app language would be the actual bug. State this at UAT so it is
    // not filed as one (E-12).
    expect(find.text(uk.catalogCreatineName), findsOneWidget,
        reason: 'copy-on-add: the row holds the name captured at add-time');
    expect(find.text(en.catalogCreatineName), findsNothing,
        reason: 'the stack row is not a live view of the catalog — it is a '
            'copy, and a copy does not re-translate');
    expect(tester.takeException(), isNull);

    await tearDownTree(tester, container);
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
        final rowHeights = <double>[];
        for (final scale in bqTextScaleMatrix) {
          await tester.pumpWidget(
            app(
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
          expect(find.bySemanticsLabel(l10n.settingsTitle), findsOneWidget,
              reason: 'the gear is icon-only, so the ARB label is the only '
                  'thing a screen-reader user has — and it follows the active '
                  'language like every other string');
          final size = tester.getSize(gearControl());
          expect(size.width, greaterThanOrEqualTo(44.0),
              reason: gearTapTargetReason);
          expect(size.height, greaterThanOrEqualTo(44.0),
              reason: gearTapTargetReason);
          expect(tester.takeException(), isNull, reason: overflowReason);
          sizes.add(size);
          rowHeights.add(tester.getSize(gearRow()).height);
        }

        expect(sizes.toSet(), hasLength(1), reason: gearGeometryReason(sizes));
        expect(rowHeights.toSet(), hasLength(1),
            reason: gearGeometryReason(rowHeights));
        await tearDownTree(tester, container);
      });
    }

    testWidgets('activating the gear through SemanticsAction.tap PUSHES the '
        'Settings route — not a coordinate tap', (tester) async {
      usePhoneSurface(tester);
      SharedPreferences.setMockInitialValues({'first_run_hints_seen': <String>['hint_cycle', 'hint_mark_dose'],});
      final prefs = await SharedPreferences.getInstance();
      final container = makeContainer(prefs: prefs);
      final l10n = lookupAppLocalizations(const Locale('uk'));
      await tester.pumpWidget(app(container));
      await tester.pump();

      expect(
        tester
            .getSemantics(find.bySemanticsLabel(l10n.settingsTitle))
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
        find.semantics.byLabel(l10n.settingsTitle),
        SemanticsAction.tap,
      );
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }

      expect(find.byType(SettingsScreen), findsOneWidget,
          reason: 'the gear pushes Settings as a full-screen route; a control '
              'that announces itself and navigates nowhere is worse than no '
              'control at all');
      expect(find.byType(StackScreen), findsOneWidget,
          reason: 'a PUSH, not a replacement: the tab underneath stays '
              'mounted, which is what keeps the selected destination and the '
              'screen state intact across the return trip');

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

/// The gear's own `Row` — the first one ABOVE the control, so it is the row
/// the screen owns and never some row inside `IconButton`.
Finder gearRow() =>
    find.ancestor(of: gearControl(), matching: find.byType(Row)).first;

/// Why the gear must not be conditional.
const String gearPresenceReason =
    'the gear is the only way into Settings once the destination is removed '
    '(plan 06-03). A gear that renders only in some list state is a screen the '
    'user can get stranded on — and "some list state" includes the empty stack '
    'a first-run user sees';

/// Why the gear box is asserted as a FLOOR and not as 44.0 exactly.
const String gearTapTargetReason =
    'the gear is built to the S11 recipe — an IconButton with '
    'BoxConstraints.tightFor(44, 44) and zero padding — and Material then '
    'wraps it to its 48dp padded tap target, so the rendered box is 48 while '
    'the constrained icon box is 44. 48 >= 44 satisfies the guidance; what '
    'must not happen is a box SMALLER than 44 or one that changes with the '
    'text scaler';

/// Why the gear row's extent must not move with the text scaler.
String gearGeometryReason(Object measured) =>
    'the gear row holds NO text, so its extent is pure geometry — a '
    'scale-dependent box means something textual leaked into the row, and the '
    'D-5 argument that this header CANNOT overflow no longer holds '
    '(measured: $measured)';

/// Pins the shared calendar clock to a fixed UTC date-only day; overriding
/// [TodayController.build] also means no midnight Timer and no lifecycle
/// listener are armed inside the test.
class _FixedToday extends TodayController {
  _FixedToday(this.day);

  final DateTime day;

  @override
  DateTime build() => day;
}
