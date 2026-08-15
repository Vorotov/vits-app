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
library;

import 'package:boostque/core/db/database.dart' show BoostqueDb;
import 'package:boostque/core/domain/models.dart';
import 'package:boostque/core/l10n/l10n.dart';
import 'package:boostque/core/providers.dart';
import 'package:boostque/core/theme/theme.dart';
import 'package:boostque/core/theme/tokens.dart';
import 'package:boostque/features/stack/regimen_editor_screen.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
}
