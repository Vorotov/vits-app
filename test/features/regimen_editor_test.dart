/// Widget tests for [RegimenEditorScreen] (plan 02-04).
///
/// Harness: real in-memory Drift database behind the repository providers
/// (Phase-1 pattern), locale uk, 390x844 logical surface. A supplement is
/// seeded through the repository before pumping; the editor controller
/// seeds its draft synchronously (UI-SPEC #17).
///
/// Task 1 coverage — structure:
/// - segmented toggle switches cyclic/course panels in place
/// - the preview strip always renders exactly 28 bars in BOTH modes
/// - slot cap (6) disables add; slot floor (1) disables remove — disabled,
///   never hidden (UI-SPEC #12)
/// - takeException null in uk locale throughout
///
/// Task 2 coverage — footer actions:
/// - save persists a course regimen (kind + inclusive end date) through the
///   controller into the real in-memory DB
/// - cyclic save persists onDays/offDays/slot times after controller edits
/// - paused renders all four pause signals together (UI-SPEC #13)
/// - Видалити opens the confirmation dialog; cancel changes nothing;
///   confirm cascades the soft delete and pops the route (UI-SPEC #19)
///
/// Plan 05-04 coverage — the bilingual matrix:
/// - the harness no longer hardcodes a language: it takes the
///   `String locale = 'uk'` + `TextScaler?` shape shared with every other
///   suite (`planner_screen_test.dart:142-163`)
/// - cyclic / course / paused rendered in BOTH languages at textScaler 1.0
///   and 1.6 — this is the screen with the most controls per pixel in the app,
///   and it had zero English render coverage (V-4, E-14)
/// - a locale change re-localizes the editor IN PLACE while it is a pushed
///   route, in one frame (V-6, E-11)
/// - the date and time picker chrome — `GlobalMaterialLocalizations`, not this
///   app's ARB — renders in the active language (Interaction Contract 8)
library;

import 'dart:async' show unawaited;

import 'package:boostque/core/db/database.dart' show BoostqueDb;
import 'package:boostque/core/domain/models.dart';
import 'package:boostque/core/domain/repositories.dart';
import 'package:boostque/core/l10n/l10n.dart';
import 'package:boostque/core/l10n/locale_controller.dart';
import 'package:boostque/core/notifications/notification_providers.dart';
import 'package:boostque/core/providers.dart';
import 'package:boostque/core/theme/theme.dart';
import 'package:boostque/core/theme/tokens.dart';
import 'package:boostque/features/stack/regimen_editor_controller.dart';
import 'package:boostque/features/stack/regimen_editor_screen.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../notifications/recording_scheduler.dart';
import '../support/locale_matrix.dart';

/// Records the moment the editor route actually leaves the navigator, so the
/// ORDER of the pop and the permission request can be ASSERTED rather than
/// assumed.
///
/// The alternative — looking for the editor widget at the moment the request is
/// recorded — cannot carry the claim: `maybePop` resolves while the exit
/// transition is still running, so the editor is still in the tree either way
/// and the test would pass with the ask issued before the pop.
class _PopRecorder extends NavigatorObserver {
  _PopRecorder(this.events);

  final List<String> events;

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    events.add(popEvent);
    super.didPop(route, previousRoute);
  }
}

/// The two things the ordering test compares, named so neither is a bare
/// literal twice.
const popEvent = 'pop';
const requestEvent = 'request';

/// A regimen repository whose writes always fail — drives the WR-04 error
/// surface without touching Drift.
class _FailingRegimenRepo implements RegimenRepository {
  @override
  Stream<List<Regimen>> watchAll() => Stream.value(const <Regimen>[]);

  @override
  Future<Regimen?> findForSupplement(String supplementId) async => null;

  @override
  Future<void> upsert(Regimen r) async => throw Exception('disk full');

  @override
  Future<void> setPaused(String regimenId, bool paused) async {}

  @override
  Future<void> softDelete(String regimenId) async {}
}

void main() {
  const supplement = Supplement(
    id: 's1',
    name: 'Магній',
    doseText: '400 мг',
    colorValue: 0xFF6B6FA8,
    note: '',
  );

  late SharedPreferences seededPrefs;

  setUp(() async {
    // The one-time cycle hint is pre-dismissed: every case here models a user
    // past first run, and the hint would otherwise sit above the sliders in
    // every structural and matrix assertion. It has its own suite
    // (first_run_hints_test.dart).
    SharedPreferences.setMockInitialValues({
      'first_run_hints_seen': <String>['hint_cycle', 'hint_mark_dose'],
    });
    seededPrefs = await SharedPreferences.getInstance();
  });

  /// A supplement whose name carries no Cyrillic, for the matrix cases only.
  ///
  /// The header name is USER DATA — it never re-localizes (E-12) — so a
  /// Cyrillic-named seed would trip the English Cyrillic sweep on a string
  /// that is correct, and the only ways out would be to weaken the sweep or to
  /// allowlist user data wholesale. Neither is acceptable (A8): the chrome is
  /// what gets swept, so the seed is kept neutral.
  const neutralSupplement = Supplement(
    id: 's1',
    name: 'Magnesium 400',
    doseText: '400 mg',
    colorValue: 0xFF6B6FA8,
    note: '',
  );

  /// Creates the provider container over an in-memory database and seeds
  /// the supplement through the repository BEFORE the screen pumps.
  ///
  /// [prefs] overrides the store for the propagation test, which drives the
  /// language through [localeControllerProvider]; every other container gets
  /// the suite's seeded instance. The override is no longer optional: since
  /// v1.2 the schedule panel reads the dismissed-hint set from the same
  /// store, and [sharedPreferencesProvider] throws unless overridden
  /// (plan 05-01, P-4 Option A).
  Future<ProviderContainer> makeContainer(
    WidgetTester tester, {
    Supplement seed = supplement,
    SharedPreferences? prefs,
  }) async {
    final container = ProviderContainer(
      overrides: [
        dbProvider.overrideWith((ref) {
          final db = BoostqueDb.forTesting(NativeDatabase.memory());
          ref.onDispose(db.close);
          return db;
        }),
        sharedPreferencesProvider.overrideWithValue(prefs ?? seededPrefs),
      ],
    );
    // Keep the stack graph warm (Riverpod 3 pauses unlistened providers).
    final sub = container.listen(stackEntriesProvider, (_, _) {});
    addTearDown(sub.close);
    await container.read(supplementRepoProvider).upsert(seed);
    return container;
  }

  /// [locale] and [textScaler] are pinned from OUTSIDE — the `plannerApp`
  /// harness signature (05-PATTERNS), so the matrix below is a loop rather
  /// than twelve copies. [home] lets a test pump a base route and push the
  /// editor onto it instead of making it the root.
  Widget app(
    ProviderContainer container, {
    String locale = 'uk',
    TextScaler? textScaler,
    GlobalKey<NavigatorState>? navigatorKey,
    Widget home = const RegimenEditorScreen(supplementId: 's1'),
  }) {
    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        navigatorKey: navigatorKey,
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
        home: home,
      ),
    );
  }

  /// The same tree with the language coming from [localeControllerProvider]
  /// instead of from a pinned `locale:` — the only harness that can change the
  /// language of an ALREADY-MOUNTED route, which is what E-11 needs.
  Widget localeDrivenApp(
    ProviderContainer container,
    GlobalKey<NavigatorState> navigatorKey,
  ) {
    return UncontrolledProviderScope(
      container: container,
      child: Consumer(
        builder: (context, ref, _) => MaterialApp(
          navigatorKey: navigatorKey,
          locale: ref.watch(localeControllerProvider),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: bqTheme(),
          home: const Scaffold(body: SizedBox(key: Key('base-route'))),
        ),
      ),
    );
  }

  /// Sets a phone-sized logical surface (390x844) so the S3 layout renders
  /// at design width; restored automatically.
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

  Finder previewBars() => find.byWidgetPredicate(
        (w) =>
            w.key is ValueKey<String> &&
            (w.key! as ValueKey<String>).value.startsWith('cycle-preview-bar-'),
      );

  group('structure (Task 1)', () {
    testWidgets(
        'uk: segmented toggle switches cyclic/course panels in place',
        (tester) async {
      usePhoneSurface(tester);
      final container = await makeContainer(tester);
      await tester.pumpWidget(app(container));
      await tester.pump();

      // Cyclic by default: two sliders, one Старт field, no Кінець.
      expect(find.byType(Slider), findsNWidgets(2));
      expect(find.text('Старт'), findsOneWidget);
      expect(find.text('Кінець'), findsNothing);

      // Switch to course: sliders gone, Старт + Кінець side by side.
      await tester.tap(find.text('Разовий курс'));
      await tester.pump();
      expect(find.byType(Slider), findsNothing);
      expect(find.text('Старт'), findsOneWidget);
      expect(find.text('Кінець'), findsOneWidget);

      // And back, in place — no page transition.
      await tester.tap(find.text('Циклічно'));
      await tester.pump();
      expect(find.byType(Slider), findsNWidgets(2));
      expect(find.text('Кінець'), findsNothing);

      expect(tester.takeException(), isNull,
          reason: 'no overflow/exception in uk locale');
      await tearDownTree(tester, container);
    });

    testWidgets('preview strip renders exactly 28 bars in BOTH modes',
        (tester) async {
      usePhoneSurface(tester);
      final container = await makeContainer(tester);
      await tester.pumpWidget(app(container));
      await tester.pump();

      expect(previewBars(), findsNWidgets(28),
          reason: 'cyclic mode: exactly 28 bars (UI-SPEC #14)');

      await tester.tap(find.text('Разовий курс'));
      await tester.pump();
      expect(previewBars(), findsNWidgets(28),
          reason: 'course mode: still exactly 28 bars, never an empty strip');

      // A 28-day course inside a 112-day window must show inactive bars
      // after the end — assert at least one bar of each color.
      Color barColor(int i) {
        final container = tester.widget<Container>(
          find.byKey(ValueKey('cycle-preview-bar-$i')),
        );
        return (container.decoration! as BoxDecoration).color!;
      }

      expect(barColor(0), BqColors.accent,
          reason: 'the course starts active at its start date');
      expect(barColor(27), BqColors.field,
          reason: 'a course ending mid-window shows inactive field bars');

      expect(tester.takeException(), isNull);
      await tearDownTree(tester, container);
    });

    testWidgets(
        'slot cap: add disables at 6; slot floor: remove disabled at 1 — '
        'disabled visuals, never hidden', (tester) async {
      usePhoneSurface(tester);
      final container = await makeContainer(tester);
      await tester.pumpWidget(app(container));
      await tester.pump();

      final addButton = find.text('+ Додати слот часу');

      // Floor: exactly one seeded slot (08:00) — minus rendered but
      // disabled (iconDisabled glyph).
      expect(find.text('−'), findsOneWidget);
      expect(tester.widget<Text>(find.text('−')).style!.color,
          BqColors.iconDisabled,
          reason: 'remove is disabled at the 1-slot floor, not hidden');

      // Add is enabled: accent label.
      expect(tester.widget<Text>(addButton).style!.color, BqColors.accent);

      // Walk to the 6-slot cap.
      for (var n = 1; n < 6; n++) {
        await tester.ensureVisible(addButton);
        await tester.tap(addButton);
        await tester.pump();
      }
      expect(find.text('−'), findsNWidgets(6));

      // With >1 slot the minus glyphs are enabled (textMuted).
      expect(
        tester.widgetList<Text>(find.text('−')).map((t) => t.style!.color),
        everyElement(BqColors.textMuted),
      );

      // Cap: add rendered but disabled (textDisabled label).
      expect(tester.widget<Text>(addButton).style!.color,
          BqColors.textDisabled,
          reason: 'add is disabled at the 6-slot cap, not hidden');

      // Tapping the disabled button changes nothing.
      await tester.ensureVisible(addButton);
      await tester.tap(addButton);
      await tester.pump();
      expect(find.text('−'), findsNWidgets(6));

      // Removing one slot re-enables add and keeps removes enabled.
      await tester.ensureVisible(find.text('−').first);
      await tester.tap(find.text('−').first);
      await tester.pump();
      expect(find.text('−'), findsNWidgets(5));
      expect(tester.widget<Text>(addButton).style!.color, BqColors.accent);

      expect(tester.takeException(), isNull,
          reason: 'no overflow/exception in uk locale');
      await tearDownTree(tester, container);
    });

    testWidgets('read-only supplement header renders name and dose (PF-5)',
        (tester) async {
      usePhoneSurface(tester);
      final container = await makeContainer(tester);
      await tester.pumpWidget(app(container));
      // Let the Drift stream deliver the seeded supplement.
      for (var i = 0; i < 50; i++) {
        await tester.pump(const Duration(milliseconds: 10));
        if (find.text('Магній').evaluate().isNotEmpty) break;
      }

      expect(find.text('Магній'), findsOneWidget);
      expect(find.text('400 мг'), findsOneWidget);
      expect(find.byType(DropdownButton), findsNothing,
          reason: 'no supplement dropdown ships in v1 (PF-5)');

      expect(tester.takeException(), isNull);
      await tearDownTree(tester, container);
    });
  });

  group('footer actions (Task 2)', () {
    testWidgets(
        'save persists a course regimen with an inclusive end date (REGI-02)',
        (tester) async {
      usePhoneSurface(tester);
      final container = await makeContainer(tester);
      await tester.pumpWidget(app(container));
      await tester.pump();

      // Switch to course mode — the controller seeds a 28-day inclusive
      // course (endDate = startDate + 27 days).
      await tester.tap(find.text('Разовий курс'));
      await tester.pump();

      // The footer is pinned (bottomNavigationBar) — no scrolling needed.
      await tester.tap(find.text('Додати й запустити цикл'));
      // Flush the async save (in-memory Drift completes via microtasks).
      await tester.pump(const Duration(milliseconds: 10));
      await tester.pump(const Duration(milliseconds: 10));

      final regimen =
          await container.read(regimenRepoProvider).findForSupplement('s1');
      expect(regimen, isNotNull, reason: 'save persisted a regimen');
      expect(regimen!.kind, RegimenKind.course);
      expect(regimen.endDate, isNotNull);
      expect(
        regimen.endDate,
        regimen.startDate.add(const Duration(days: 27)),
        reason: 'default course = 28 inclusive days (start + 27)',
      );

      expect(tester.takeException(), isNull);
      await tearDownTree(tester, container);
    });

    testWidgets(
        'cyclic save persists onDays/offDays/slot times after controller '
        'edits (REGI-01, REGI-03)', (tester) async {
      usePhoneSurface(tester);
      final container = await makeContainer(tester);
      await tester.pumpWidget(app(container));
      await tester.pump();

      // Drive the tested controller directly (sliders/pickers are thin
      // wrappers over these methods — Task 1 proved the wiring).
      final controller =
          container.read(regimenEditorProvider('s1').notifier);
      controller.setOnDays(28);
      controller.setOffDays(14);
      controller.addSlot(); // 13:00 (780) — first unused default
      controller.setSlotTime(1, 20 * 60 + 30); // move it to 20:30
      await tester.pump();

      await tester.tap(find.text('Додати й запустити цикл'));
      await tester.pump(const Duration(milliseconds: 10));
      await tester.pump(const Duration(milliseconds: 10));

      final regimen =
          await container.read(regimenRepoProvider).findForSupplement('s1');
      expect(regimen, isNotNull);
      expect(regimen!.kind, RegimenKind.cyclic);
      expect(regimen.onDays, 28);
      expect(regimen.offDays, 14);
      expect(
        regimen.slots.map((s) => s.minutesFromMidnight).toList()..sort(),
        [480, 20 * 60 + 30],
        reason: 'both slot times persisted (08:00 seed + edited 20:30)',
      );

      expect(tester.takeException(), isNull);
      await tearDownTree(tester, container);
    });

    testWidgets(
        'double-tapping save persists exactly ONE regimen and pops the '
        'editor exactly once (CR-01)', (tester) async {
      usePhoneSurface(tester);
      final container = await makeContainer(tester);
      final navKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        app(
          container,
          navigatorKey: navKey,
          home: const Scaffold(body: SizedBox(key: Key('base-route'))),
        ),
      );
      unawaited(
        navKey.currentState!.push(
          MaterialPageRoute<void>(
            builder: (_) => const RegimenEditorScreen(supplementId: 's1'),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Observe regimens pump-driven (awaiting .first un-pumped deadlocks).
      List<Regimen>? regimens;
      final watchSub = container
          .read(regimenRepoProvider)
          .watchAll()
          .listen((v) => regimens = v);
      await tester.pump(const Duration(milliseconds: 10));

      // Two taps with NO pump in between — both hit the still-built button;
      // the in-flight guard must swallow the second.
      final save = find.text('Додати й запустити цикл');
      await tester.tap(save);
      await tester.tap(save);
      // Flush the async save + the pop's exit transition.
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(regimens, isNotNull);
      expect(regimens, hasLength(1),
          reason: 'the double tap must not create a ghost regimen (PF-8)');
      expect(find.byType(RegimenEditorScreen), findsNothing,
          reason: 'save pops the editor once');
      expect(find.byKey(const Key('base-route')), findsOneWidget,
          reason: 'the second tap must not pop the base route underneath');

      expect(tester.takeException(), isNull);
      unawaited(watchSub.cancel());
      await tester.pump(const Duration(milliseconds: 10));
      await tearDownTree(tester, container);
    });

    testWidgets(
        'paused renders all four pause signals together — badge, resume '
        'label, save label, save hint (UI-SPEC #13)', (tester) async {
      usePhoneSurface(tester);
      final container = await makeContainer(tester);
      await tester.pumpWidget(app(container));
      await tester.pump();

      // Not paused: none of the paused signals; active labels shown.
      expect(find.text('НА ПАУЗІ'), findsNothing);
      expect(find.text('Пауза'), findsOneWidget);
      expect(find.text('Додати й запустити цикл'), findsOneWidget);

      // Tap the pause button — one state flips all four signals.
      await tester.tap(find.text('Пауза'));
      await tester.pump();

      expect(find.text('НА ПАУЗІ'), findsOneWidget,
          reason: 'top-bar badge appears while paused');
      expect(find.text('Відновити цикл'), findsOneWidget,
          reason: 'pause button label switches to resume');
      expect(find.text('Зберегти, цикл на паузі'), findsOneWidget,
          reason: 'save button label switches to the paused variant');
      expect(
        find.text(
          'Цикл збережеться в стеку зі статусом «пауза», '
          'у календарі його не буде.',
        ),
        findsOneWidget,
        reason: 'save hint switches to the paused variant',
      );

      // And back — the whole set reverts together.
      await tester.tap(find.text('Відновити цикл'));
      await tester.pump();
      expect(find.text('НА ПАУЗІ'), findsNothing);
      expect(find.text('Пауза'), findsOneWidget);
      expect(find.text('Додати й запустити цикл'), findsOneWidget);

      expect(tester.takeException(), isNull);
      await tearDownTree(tester, container);
    });

    testWidgets(
        'a failed save shows the saveFailed SnackBar, stays on screen, and '
        're-enables the button for a retry (WR-04)', (tester) async {
      usePhoneSurface(tester);
      final container = ProviderContainer(
        overrides: [
          dbProvider.overrideWith((ref) {
            final db = BoostqueDb.forTesting(NativeDatabase.memory());
            ref.onDispose(db.close);
            return db;
          }),
          // The schedule panel reads the dismissed-hint set since v1.2.
          sharedPreferencesProvider.overrideWithValue(seededPrefs),
          regimenRepoProvider.overrideWithValue(_FailingRegimenRepo()),
        ],
      );
      final sub = container.listen(stackEntriesProvider, (_, _) {});
      addTearDown(sub.close);
      await container.read(supplementRepoProvider).upsert(supplement);
      await tester.pumpWidget(app(container));
      await tester.pump();

      await tester.tap(find.text('Додати й запустити цикл'));
      await tester.pump(const Duration(milliseconds: 10));
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Не вдалося зберегти. Спробуйте ще раз.'),
          findsOneWidget,
          reason: 'the write failure must surface a SnackBar (WR-04)');
      expect(find.byType(RegimenEditorScreen), findsOneWidget,
          reason: 'the editor must NOT pop as if saved');
      final saveButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Додати й запустити цикл'),
      );
      expect(saveButton.onPressed, isNotNull,
          reason: 'the save button re-enables for a retry');
      expect(tester.takeException(), isNull,
          reason: 'the failure is handled — no unhandled zone exception');

      await tearDownTree(tester, container);
    });

    testWidgets(
        'delete opens the confirm dialog; cancel changes nothing; confirm '
        'cascades and pops (UI-SPEC #19, STACK-04)', (tester) async {
      usePhoneSurface(tester);
      final container = await makeContainer(tester);
      final navKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        app(
          container,
          navigatorKey: navKey,
          home: const Scaffold(body: SizedBox()),
        ),
      );
      // Push the editor so the confirmed delete has a route to pop.
      unawaited(
        navKey.currentState!.push(
          MaterialPageRoute<void>(
            builder: (_) => const RegimenEditorScreen(supplementId: 's1'),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Observe watchAll pump-driven: Drift emits via zero-duration timers,
      // so awaiting `.first` inside the fake-async test zone would deadlock.
      List<Supplement>? supplements;
      final watchSub = container
          .read(supplementRepoProvider)
          .watchAll()
          .listen((v) => supplements = v);
      await tester.pump(const Duration(milliseconds: 10));

      // Видалити's ONLY direct effect is opening the dialog.
      await tester.tap(find.text('Видалити'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Видалити «Магній»?'), findsOneWidget,
          reason: 'dialog title carries the supplement name');
      expect(
        find.text(
          'Видалення прибирає розклад і майбутні дози. Історія прийому залишається.',
        ),
        findsOneWidget,
        reason: 'dialog body states history is kept',
      );
      expect(supplements, isNotEmpty,
          reason: 'opening the dialog deletes nothing');

      // Cancel returns to the editor unchanged.
      await tester.tap(find.text('Скасувати'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(RegimenEditorScreen), findsOneWidget,
          reason: 'cancel keeps the editor open');
      expect(supplements, isNotEmpty, reason: 'cancel deletes nothing');

      // Confirm cascades the soft delete and pops back to the base route.
      await tester.tap(find.text('Видалити'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Видалити'),
        ),
      );
      // Flush the cascade + dialog pop + the editor route's exit animation.
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(supplements, isEmpty,
          reason: 'confirm runs softDeleteCascade');
      expect(find.byType(RegimenEditorScreen), findsNothing,
          reason: 'confirm pops the editor route');

      expect(tester.takeException(), isNull);
      // Cancel pump-driven (Drift resolves the cancel future via a
      // zero-duration timer — awaiting it un-pumped would deadlock).
      unawaited(watchSub.cancel());
      await tester.pump(const Duration(milliseconds: 10));
      await tearDownTree(tester, container);
    });
  });

  // -------------------------------------------------------------------
  // The bilingual × text-scale matrix (plan 05-04, L10N-01 criterion 1,
  // V-4 / E-14 / T-05-08 / T-05-09).
  //
  // This is the screen with the most controls per pixel in the app, and it
  // had ZERO English render coverage before this plan. 1.6 is the case most
  // likely to go red; if it does, the fix is a computed extent or a flexible
  // child, never a relaxed assertion.
  // -------------------------------------------------------------------

  /// Bounded frame pumping. `pumpAndSettle` is not used anywhere in this file:
  /// the graph kept warm by [makeContainer] reaches the shared clock, and
  /// settling against a live timer either hangs or passes for a reason the
  /// test did not intend (PF-7).
  Future<void> pumpFrames(WidgetTester tester, [int frames = 20]) async {
    for (var i = 0; i < frames; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
  }

  group('bilingual render matrix (L10N-01)', () {
    for (final locale in const ['uk', 'en']) {
      final l10n = lookupAppLocalizations(Locale(locale));

      for (final scale in const <double>[1.0, 1.6]) {
        final scaler = TextScaler.linear(scale);

        Future<ProviderContainer> pumpEditor(WidgetTester tester) async {
          usePhoneSurface(tester);
          final container =
              await makeContainer(tester, seed: neutralSupplement);
          await tester.pumpWidget(
            app(container, locale: locale, textScaler: scaler),
          );
          await tester.pump();
          return container;
        }

        testWidgets(
            '$locale: the CYCLIC editor renders in the active language with '
            'no layout exception at textScaler $scale', (tester) async {
          final container = await pumpEditor(tester);

          // In the RIGHT language, not merely rendered: every one of these
          // differs between uk and en, so an editor that fell back to the
          // other language fails here rather than passing on a bare render.
          expect(find.text(l10n.scheduleTitle), findsOneWidget);
          expect(find.text(l10n.periodicityLabel), findsOneWidget);
          expect(find.text(l10n.cycleLength), findsOneWidget);
          expect(find.text(l10n.timeSlotsLabel), findsOneWidget);
          expect(find.text(l10n.saveAndStart), findsOneWidget);
          expect(find.byType(Slider), findsNWidgets(2),
              reason: 'cyclic mode is the default — the two sliders are the '
                  'densest control pair on the screen');

          if (locale == 'en') {
            expectNoCyrillicWhileEn(tester);
          }
          expect(tester.takeException(), isNull, reason: overflowReason);

          await tearDownTree(tester, container);
        });

        testWidgets(
            '$locale: the COURSE editor renders in the active language with '
            'no layout exception at textScaler $scale', (tester) async {
          final container = await pumpEditor(tester);

          await tester.tap(find.text(l10n.courseTab));
          await tester.pump();

          expect(find.text(l10n.startLabel), findsOneWidget);
          expect(find.text(l10n.endLabel), findsOneWidget,
              reason: 'course mode puts two date fields side by side — the '
                  'row that has the least horizontal slack on this screen');
          expect(find.byType(Slider), findsNothing);
          expect(find.text(l10n.saveAndStart), findsOneWidget);

          if (locale == 'en') {
            expectNoCyrillicWhileEn(tester);
          }
          expect(tester.takeException(), isNull, reason: overflowReason);

          await tearDownTree(tester, container);
        });

        testWidgets(
            '$locale: the PAUSED editor renders in the active language with '
            'no layout exception at textScaler $scale', (tester) async {
          final container = await pumpEditor(tester);

          await tester.tap(find.text(l10n.pause));
          await tester.pump();

          // The paused state renders the most simultaneous chrome — badge,
          // resume label, paused save label and the long paused save hint —
          // which is why it is the third matrix state (UI-SPEC #13).
          expect(find.text(l10n.pausedBadge), findsOneWidget);
          expect(find.text(l10n.resume), findsOneWidget);
          expect(find.text(l10n.saveWhilePaused), findsOneWidget);
          expect(find.text(l10n.saveHintPaused), findsOneWidget);

          if (locale == 'en') {
            expectNoCyrillicWhileEn(tester);
          }
          expect(tester.takeException(), isNull, reason: overflowReason);

          await tearDownTree(tester, container);
        });
      }
    }
  });

  // -------------------------------------------------------------------
  // Propagation: criterion-3 work, not criterion-1 work (V-6, E-11).
  // -------------------------------------------------------------------

  testWidgets(
      'a locale change re-localizes the PUSHED editor IN PLACE, within a '
      'single pump (V-6, E-11, Interaction Contract 8)', (tester) async {
    usePhoneSurface(tester);
    // Locales as named data rather than literals buried in the body: nothing
    // in this file hardcodes a rendering language any more (plan 05-04).
    const ukLocale = Locale('uk');
    const enLocale = Locale('en');
    final uk = lookupAppLocalizations(ukLocale);
    final en = lookupAppLocalizations(enLocale);

    SharedPreferences.setMockInitialValues({'app_locale': 'uk', 'first_run_hints_seen': <String>['hint_cycle', 'hint_mark_dose'],});
    final prefs = await SharedPreferences.getInstance();
    final container = await makeContainer(
      tester,
      seed: neutralSupplement,
      prefs: prefs,
    );
    final navKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(localeDrivenApp(container, navKey));
    unawaited(
      navKey.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => const RegimenEditorScreen(supplementId: 's1'),
        ),
      ),
    );
    await pumpFrames(tester);

    expect(find.text(uk.scheduleTitle), findsOneWidget,
        reason: 'the editor must be the pushed route under test');
    expect(find.text(en.scheduleTitle), findsNothing);

    container.read(localeControllerProvider.notifier).setLocale(enLocale);
    // EXACTLY one frame. Needing more would itself prove the switch is not
    // instant (PF-3); and against a live retry timer `pumpAndSettle` would
    // also pass for the wrong reason (PF-7).
    await tester.pump();

    expect(find.text(en.scheduleTitle), findsOneWidget,
        reason: 'a pushed route sits in the Navigator BELOW MaterialApp\'s '
            'Localizations, so it must re-localize with everything else — a '
            'user who changed the language and kept reading the old one on '
            'the screen they are actually looking at reads that as broken');
    expect(find.text(uk.scheduleTitle), findsNothing,
        reason: 'the old-language string must be GONE, not merely joined by '
            'its counterpart — two languages on one screen is the defect');
    expect(find.text(en.saveWhilePaused), findsNothing);
    expect(find.text(en.saveAndStart), findsOneWidget,
        reason: 'the pinned footer follows too, not just the header');
    expect(find.byType(RegimenEditorScreen), findsOneWidget,
        reason: 'IN PLACE: the route was never popped and re-pushed — this is '
            'a rebuild of the mounted route, not a fresh one');
    expect(tester.takeException(), isNull);

    await tearDownTree(tester, container);
  });

  // -------------------------------------------------------------------
  // Picker chrome: GlobalMaterialLocalizations, not this app's ARB — the
  // half of "every screen displays correctly" no ARB gate can ever cover.
  // -------------------------------------------------------------------

  // The two pickers get a test each, on a freshly pumped editor: a dismissed
  // picker route leaves the page it was opened from unresponsive to further
  // synthetic taps in this harness, so chaining both into one body would only
  // prove the second picker never opened.
  for (final locale in const ['uk', 'en']) {
    testWidgets(
        '$locale: the DATE picker chrome renders in the active language '
        '(Interaction Contract 8, E-11)', (tester) async {
      usePhoneSurface(tester);
      final l10n = lookupAppLocalizations(Locale(locale));
      // The Material chrome's own strings, read from the SAME delegate the
      // app installs — hardcoding them here would test this test's spelling
      // rather than the delegate the app actually resolves.
      final material =
          await GlobalMaterialLocalizations.delegate.load(Locale(locale));
      final container = await makeContainer(tester, seed: neutralSupplement);
      await tester.pumpWidget(app(container, locale: locale));
      await tester.pump();

      // The start-date field: label + tappable value box (_DateField).
      final startField = find
          .ancestor(
            of: find.text(l10n.startLabel),
            matching: find.byType(Column),
          )
          .first;
      await tester.tap(
        find
            .descendant(of: startField, matching: find.byType(GestureDetector))
            .first,
      );
      await pumpFrames(tester);

      expect(find.text(material.datePickerHelpText), findsOneWidget,
          reason: 'the date picker header comes from '
              'GlobalMaterialLocalizations, not from this app\'s ARB — if it '
              'lagged the app language a user would be picking a date out of '
              'a dialog in a language they did not choose, and no ARB gate '
              'would ever see it');
      expect(find.text(material.cancelButtonLabel), findsOneWidget,
          reason: 'the dialog actions come from the same delegate');
      expect(tester.takeException(), isNull, reason: overflowReason);

      await tester.tap(find.text(material.cancelButtonLabel));
      await pumpFrames(tester);
      expect(find.text(material.datePickerHelpText), findsNothing,
          reason: 'cancel dismissed the picker without picking a date');

      await tearDownTree(tester, container);
    });

    testWidgets(
        '$locale: the TIME picker chrome renders in the active language '
        '(Interaction Contract 8, E-11)', (tester) async {
      usePhoneSurface(tester);
      final material =
          await GlobalMaterialLocalizations.delegate.load(Locale(locale));
      final container = await makeContainer(tester, seed: neutralSupplement);
      await tester.pumpWidget(app(container, locale: locale));
      await tester.pump();

      // The slot row's time box opens the time picker. "08:00" is the same
      // string in both languages by design — one 24-h convention on picker
      // and display alike (PF-3) — so it is a safe finder here.
      await tester.tap(find.text('08:00'));
      await pumpFrames(tester);

      expect(find.text(material.timePickerDialHelpText), findsOneWidget,
          reason: 'the time picker header follows the same Material delegate '
              'as the date picker, and is the other half of "every screen '
              'displays correctly" that no ARB gate can cover');
      expect(find.text(material.cancelButtonLabel), findsOneWidget);
      expect(tester.takeException(), isNull, reason: overflowReason);

      await tester.tap(find.text(material.cancelButtonLabel));
      await pumpFrames(tester);
      expect(find.text(material.timePickerDialHelpText), findsNothing,
          reason: 'cancel dismissed the picker without changing the slot');

      await tearDownTree(tester, container);
    });
  }

  // -------------------------------------------------------------------
  // The permission ask at the save call site (NOTIF-03, plan 07-05).
  //
  // Everything below is ADDITIVE. The save's own behaviour — the pop, the
  // saveFailed SnackBar, the button re-enable, the delete-confirmation gate —
  // is proven by the groups above, unedited, and that is the point: the ask
  // hangs off the end of a method whose behaviour did not change.
  // -------------------------------------------------------------------

  group('the permission ask (NOTIF-03)', () {
    late RecordingScheduler scheduler;
    late List<String> events;

    setUp(() {
      scheduler = RecordingScheduler();
      events = <String>[];
      scheduler.onRequestPermission = () => events.add(requestEvent);
    });

    /// A container carrying the two overrides the ask needs: the mocked seam
    /// and a real (mock-backed) key-value store for the asked-once flag.
    Future<ProviderContainer> permissionContainer(
      WidgetTester tester, {
      RegimenRepository? regimenRepo,
    }) async {
      SharedPreferences.setMockInitialValues(<String, Object>{'first_run_hints_seen': <String>['hint_cycle', 'hint_mark_dose'],});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          dbProvider.overrideWith((ref) {
            final db = BoostqueDb.forTesting(NativeDatabase.memory());
            ref.onDispose(db.close);
            return db;
          }),
          sharedPreferencesProvider.overrideWithValue(prefs),
          notificationSchedulerProvider.overrideWithValue(scheduler),
          if (regimenRepo != null)
            regimenRepoProvider.overrideWithValue(regimenRepo),
        ],
      );
      final sub = container.listen(stackEntriesProvider, (_, _) {});
      addTearDown(sub.close);
      await container.read(supplementRepoProvider).upsert(supplement);
      return container;
    }

    Widget permissionApp(
      ProviderContainer container,
      GlobalKey<NavigatorState> navKey,
    ) {
      return UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          navigatorKey: navKey,
          navigatorObservers: [_PopRecorder(events)],
          locale: const Locale('uk'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: bqTheme(),
          home: const Scaffold(body: SizedBox(key: Key('base-route'))),
        ),
      );
    }

    Future<void> pushEditor(
      WidgetTester tester,
      GlobalKey<NavigatorState> navKey, [
      String supplementId = 's1',
    ]) async {
      unawaited(
        navKey.currentState!.push(
          MaterialPageRoute<void>(
            builder: (_) => RegimenEditorScreen(supplementId: supplementId),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }

    /// Flushes the save, the pop's exit transition and the fire-and-forget ask.
    Future<void> settle(WidgetTester tester) async {
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    Future<void> tapSave(WidgetTester tester) =>
        tester.tap(find.text('Додати й запустити цикл'));

    int requests() => scheduler.calls
        .where((c) => c.method == requestPermissionCall)
        .length;

    /// Everything the tree is rendering, with every string it is rendering —
    /// the comparison behind "the permission answer changes nothing on screen".
    List<String> snapshot(WidgetTester tester) => [
          for (final widget in tester.allWidgets)
            if (widget is Text)
              'Text:${widget.data}'
            else
              widget.runtimeType.toString(),
        ];

    testWidgets(
        'the FIRST save issues exactly one request, and issues it AFTER the '
        'editor route has popped', (tester) async {
      usePhoneSurface(tester);
      final container = await permissionContainer(tester);
      final navKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(permissionApp(container, navKey));
      await pushEditor(tester, navKey);

      await tapSave(tester);
      await settle(tester);

      expect(
        await container.read(regimenRepoProvider).findForSupplement('s1'),
        isNotNull,
        reason: 'the write completed — the ask hangs off a save that worked',
      );
      expect(requests(), 1);
      expect(
        events,
        <String>[popEvent, requestEvent],
        reason: 'ordering is a CONTRACT, not an implementation detail: a system '
            'dialog raised over a route that is mid-exit-transition is '
            'disorienting on both platforms and, on iOS, lands over a view '
            'being torn down. Issuing the ask before the await would produce '
            'the same two events in the opposite order.',
      );
      expect(find.byType(RegimenEditorScreen), findsNothing);
      expect(tester.takeException(), isNull);

      await tearDownTree(tester, container);
    });

    testWidgets('saving a SECOND regimen issues no further request',
        (tester) async {
      usePhoneSurface(tester);
      final container = await permissionContainer(tester);
      await container.read(supplementRepoProvider).upsert(
            const Supplement(
              id: 's2',
              name: 'Цинк',
              doseText: '25 мг',
              colorValue: 0xFF6B6FA8,
              note: '',
            ),
          );
      final navKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(permissionApp(container, navKey));

      await pushEditor(tester, navKey);
      await tapSave(tester);
      await settle(tester);

      await pushEditor(tester, navKey, 's2');
      await tapSave(tester);
      await settle(tester);

      expect(
        await container.read(regimenRepoProvider).findForSupplement('s2'),
        isNotNull,
        reason: 'the second save really did happen — otherwise "no second '
            'request" would be true for the wrong reason',
      );
      expect(requests(), 1,
          reason: 'without the persisted flag Android re-shows its rationale '
              'dialog on every single save until the user has denied twice.');

      await tearDownTree(tester, container);
    });

    testWidgets(
        'a FAILED save issues no request at all — no pop, the saveFailed '
        'SnackBar, and the button re-enabled', (tester) async {
      usePhoneSurface(tester);
      final container = await permissionContainer(
        tester,
        regimenRepo: _FailingRegimenRepo(),
      );
      final navKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(permissionApp(container, navKey));
      await pushEditor(tester, navKey);

      await tapSave(tester);
      await settle(tester);

      expect(scheduler.calls, isEmpty,
          reason: 'a user whose write just failed is being asked about '
              'reminders for a schedule that does not exist.');
      expect(events, isEmpty, reason: 'and nothing popped either');
      expect(find.text('Не вдалося зберегти. Спробуйте ще раз.'), findsOneWidget);
      expect(find.byType(RegimenEditorScreen), findsOneWidget);
      final saveButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Додати й запустити цикл'),
      );
      expect(saveButton.onPressed, isNotNull);
      expect(tester.takeException(), isNull);

      await tearDownTree(tester, container);
    });

    for (final answer in const <bool>[true, false]) {
      testWidgets(
          'the permission answer $answer changes NOTHING on screen',
          (tester) async {
        usePhoneSurface(tester);
        scheduler.enabled = answer;
        final container = await permissionContainer(tester);
        final navKey = GlobalKey<NavigatorState>();
        await tester.pumpWidget(permissionApp(container, navKey));
        // The tree BEFORE the editor was ever pushed. Comparing against this
        // rather than against a pinned literal is what makes the claim the
        // contract actually states — "whatever the user answers, the app looks
        // identical afterwards" — instead of "two runs agree with each other".
        final before = snapshot(tester);
        await pushEditor(tester, navKey);

        await tapSave(tester);
        await settle(tester);

        expect(requests(), 1);
        expect(find.byType(SnackBar), findsNothing);
        expect(find.byType(AlertDialog), findsNothing);
        expect(find.byType(MaterialBanner), findsNothing);
        expect(find.byKey(const Key('base-route')), findsOneWidget);
        expect(snapshot(tester), before,
            reason: 'granted and denied must be indistinguishable from inside '
                'the app: the same widgets and the same strings the user was '
                'looking at before they opened the editor at all.');

        await tearDownTree(tester, container);
      });
    }

    testWidgets('a request that THROWS leaves the app exactly as a successful '
        'save leaves it', (tester) async {
      usePhoneSurface(tester);
      scheduler.requestFailure = Exception('no notification plugin here');
      final container = await permissionContainer(tester);
      final navKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(permissionApp(container, navKey));
      final before = snapshot(tester);
      await pushEditor(tester, navKey);

      await tapSave(tester);
      await settle(tester);

      expect(
        await container.read(regimenRepoProvider).findForSupplement('s1'),
        isNotNull,
      );
      expect(find.byType(RegimenEditorScreen), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
      expect(snapshot(tester), before,
          reason: 'the failure is absorbed and reported, never surfaced — the '
              'same requirement as the no-primer decision, seen from the '
              'failure side.');
      expect(tester.takeException(), isNotNull,
          reason: 'absorbed means REPORTED to the crash logger.');

      await tearDownTree(tester, container);
    });

    testWidgets('the delete-confirmation gate and the cascade behind it issue '
        'no request', (tester) async {
      usePhoneSurface(tester);
      final container = await permissionContainer(tester);
      final navKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(permissionApp(container, navKey));
      await pushEditor(tester, navKey);

      // The footer's destructive button, then the dialog's confirm — both
      // labelled `delete`, so the second is scoped to the dialog.
      await tester.tap(find.text('Видалити'));
      await settle(tester);
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Видалити'),
        ),
      );
      await settle(tester);

      expect(find.byType(RegimenEditorScreen), findsNothing,
          reason: 'the cascade ran and the editor popped — otherwise "no '
              'request" would be true because nothing happened');
      expect(scheduler.calls, isEmpty,
          reason: 'deleting a supplement is not the moment to ask a user for '
              'permission to remind them about it.');

      await tearDownTree(tester, container);
    });
  });
}
