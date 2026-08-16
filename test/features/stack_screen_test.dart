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
import 'package:boostque/features/stack/regimen_editor_screen.dart';
import 'package:boostque/features/stack/stack_screen.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
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

  setUp(() {
    // LocaleController loads its persisted override from SharedPreferences.
    SharedPreferences.setMockInitialValues({});
  });

  /// Provider container over an in-memory database; callers seed through
  /// the repositories before pumping. Passing [today] pins the shared calendar
  /// clock so card statuses are asserted against a fixed day (IN-06).
  /// [prefs] is only needed by the one test that drives the language through
  /// [localeControllerProvider] — the controller reads its stored override
  /// synchronously through [sharedPreferencesProvider], which throws unless
  /// overridden (plan 05-01, P-4 Option A). The Stack screen itself never
  /// reaches it, which is why every other container below omits it.
  ProviderContainer makeContainer({DateTime? today, SharedPreferences? prefs}) {
    final container = ProviderContainer(
      overrides: [
        dbProvider.overrideWith((ref) {
          final db = BoostqueDb.forTesting(NativeDatabase.memory());
          ref.onDispose(db.close);
          return db;
        }),
        if (today != null) todayProvider.overrideWith(() => _FixedToday(today)),
        if (prefs != null) sharedPreferencesProvider.overrideWithValue(prefs),
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
        home: const StackScreen(),
      ),
    );
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
          home: const StackScreen(),
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
          expect(find.text(l10n.addSupplement), findsOneWidget,
              reason: 'the CTA stays visible above the empty state (#1)');

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
          await pumpUntilFound(tester, find.text(l10n.addSupplement));

          await tester.tap(find.text(l10n.addSupplement));
          await tester.pumpAndSettle();

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
        await pumpUntilFound(tester, find.text(l10n.addSupplement));

        await tester.tap(find.text(l10n.addSupplement));
        await tester.pumpAndSettle();
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
              'weekLoadLabel idiom), never an allowlist entry (PF-5, A2)');
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

    SharedPreferences.setMockInitialValues({'app_locale': 'uk'});
    final prefs = await SharedPreferences.getInstance();
    final container = makeContainer(
      today: DateTime.utc(2026, 8, 10),
      prefs: prefs,
    );
    await tester.pumpWidget(localeDrivenApp(container));
    await tester.pump();

    // Add the catalog entry while UKRAINIAN is active: the row copies the
    // active locale's name onto the Supplement (catalog.dart:11-15).
    await tester.tap(find.text(uk.addSupplement));
    await tester.pumpAndSettle();
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
