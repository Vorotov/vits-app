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
library;

import 'dart:async' show unawaited;

import 'package:boostque/core/db/database.dart' show BoostqueDb;
import 'package:boostque/core/domain/models.dart';
import 'package:boostque/core/domain/repositories.dart';
import 'package:boostque/core/l10n/l10n.dart';
import 'package:boostque/core/providers.dart';
import 'package:boostque/core/theme/theme.dart';
import 'package:boostque/core/theme/tokens.dart';
import 'package:boostque/features/stack/regimen_editor_controller.dart';
import 'package:boostque/features/stack/regimen_editor_screen.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  /// Creates the provider container over an in-memory database and seeds
  /// the supplement through the repository BEFORE the screen pumps.
  Future<ProviderContainer> makeContainer(WidgetTester tester) async {
    final container = ProviderContainer(
      overrides: [
        dbProvider.overrideWith((ref) {
          final db = BoostqueDb.forTesting(NativeDatabase.memory());
          ref.onDispose(db.close);
          return db;
        }),
      ],
    );
    // Keep the stack graph warm (Riverpod 3 pauses unlistened providers).
    final sub = container.listen(stackEntriesProvider, (_, _) {});
    addTearDown(sub.close);
    await container.read(supplementRepoProvider).upsert(supplement);
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
        home: const RegimenEditorScreen(supplementId: 's1'),
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
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            navigatorKey: navKey,
            locale: const Locale('uk'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: bqTheme(),
            home: const Scaffold(body: SizedBox(key: Key('base-route'))),
          ),
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
          'Цикл збережеться в стеку зі статусом «пауза» — '
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
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            navigatorKey: navKey,
            locale: const Locale('uk'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: bqTheme(),
            home: const Scaffold(body: SizedBox()),
          ),
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
          'Розклад і майбутні дози буде видалено. Історію прийому збережемо.',
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
}
