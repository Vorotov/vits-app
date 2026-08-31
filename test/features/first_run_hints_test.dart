/// The one-time contextual hints (v1.2 path A): the store's degradation
/// rules, and each hint appearing at the moment it is relevant and never
/// again after it is dismissed.
///
/// These are the cases every OTHER screen suite deliberately seeds away, so
/// this file is the only place the hint-visible state is exercised.
library;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:boostque/core/db/database.dart' show BoostqueDb;
import 'package:boostque/core/domain/models.dart';
import 'package:boostque/core/l10n/l10n.dart';
import 'package:boostque/core/providers.dart';
import 'package:boostque/core/theme/theme.dart';
import 'package:boostque/core/today_controller.dart';
import 'package:boostque/core/widgets/bq_hint_card.dart';
import 'package:boostque/features/calendar/today_screen.dart';
import 'package:boostque/features/onboarding/first_run_hints.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  ProviderContainer plainScope(SharedPreferences? prefs) {
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('the hint store', () {
    test('an empty store shows every hint — nothing dismissed yet', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final hints = plainScope(prefs).read(firstRunHintsProvider.notifier);
      for (final hint in BqHint.values) {
        expect(hints.shouldShow(hint), isTrue, reason: '${hint.id} is unseen');
      }
    });

    test('a stored id hides exactly that hint', () async {
      SharedPreferences.setMockInitialValues({
        'first_run_hints_seen': <String>['hint_cycle'],
      });
      final prefs = await SharedPreferences.getInstance();
      final hints = plainScope(prefs).read(firstRunHintsProvider.notifier);
      expect(hints.shouldShow(BqHint.cycle), isFalse);
      expect(hints.shouldShow(BqHint.markDose), isTrue);
    });

    test('a null store hides every hint — an undismissable hint would '
        'reappear forever', () {
      final hints = plainScope(null).read(firstRunHintsProvider.notifier);
      for (final hint in BqHint.values) {
        expect(hints.shouldShow(hint), isFalse);
      }
    });

    test('a wrong-typed stored value hides every hint without throwing',
        () async {
      SharedPreferences.setMockInitialValues({'first_run_hints_seen': 'oops'});
      final prefs = await SharedPreferences.getInstance();
      final hints = plainScope(prefs).read(firstRunHintsProvider.notifier);
      expect(hints.shouldShow(BqHint.cycle), isFalse);
    });

    test('dismiss persists and is idempotent', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = plainScope(prefs);
      final hints = container.read(firstRunHintsProvider.notifier);

      await hints.dismiss(BqHint.cycle);
      expect(hints.shouldShow(BqHint.cycle), isFalse);
      expect(prefs.getStringList('first_run_hints_seen'), <String>['hint_cycle']);

      await hints.dismiss(BqHint.cycle);
      expect(prefs.getStringList('first_run_hints_seen'), <String>['hint_cycle'],
          reason: 'dismissing twice must not duplicate the id');
      expect(hints.shouldShow(BqHint.markDose), isTrue,
          reason: 'dismissing one hint says nothing about the others');
    });

    test('a null store still hides the hint in memory — never blocks the UI',
        () async {
      final container = plainScope(null);
      final hints = container.read(firstRunHintsProvider.notifier);
      await hints.dismiss(BqHint.markDose);
      expect(hints.shouldShow(BqHint.markDose), isFalse);
    });
  });

  group('the mark-a-dose hint on Сьогодні', () {
    late SharedPreferences prefs;
    final pinnedToday = DateTime.utc(2026, 8, 13);

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    ProviderContainer todayScope() {
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          dbProvider.overrideWith((ref) {
            final db = BoostqueDb.forTesting(NativeDatabase.memory());
            ref.onDispose(db.close);
            return db;
          }),
          todayProvider.overrideWith(() => _FixedToday(pinnedToday)),
        ],
      );
      final sub = container.listen(dayDosesProvider(pinnedToday), (_, _) {});
      addTearDown(sub.close);
      return container;
    }

    Widget todayApp(ProviderContainer container) => UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            locale: const Locale('uk'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: bqTheme(),
            home: const TodayScreen(),
          ),
        );

    Future<void> pumpFrames(WidgetTester tester, [int frames = 25]) async {
      for (var i = 0; i < frames; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }
    }

    Future<void> flushTearDown(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 10));
      await tester.pump(const Duration(milliseconds: 10));
    }

    Future<void> seedDose(ProviderContainer container) async {
      await container.read(supplementRepoProvider).upsert(
            const Supplement(
              id: 's1',
              name: 'Магній',
              doseText: '400 мг',
              colorValue: 0xFF6B6FA8,
              note: '',
            ),
          );
      await container.read(regimenRepoProvider).upsert(
            Regimen(
              id: 'r1',
              supplementId: 's1',
              kind: RegimenKind.cyclic,
              startDate: DateTime.utc(2026, 8, 1),
              endDate: null,
              onDays: 28,
              offDays: 0,
              paused: false,
              slots: const [
                DoseSlot(
                  id: 'sl1',
                  minutesFromMidnight: 480,
                  doseLabel: '1 капсула',
                ),
              ],
            ),
          );
    }

    testWidgets('a day with doses shows the hint once, and dismissing it is '
        'permanent', (tester) async {
      final container = todayScope();
      await seedDose(container);
      await tester.pumpWidget(todayApp(container));
      await pumpFrames(tester);

      expect(find.byType(BqHintCard), findsOneWidget);
      expect(
        find.text('Торкніться дози, щоб відмітити прийом. Довге натискання — '
            'інші варіанти.'),
        findsOneWidget,
      );

      // Scoped to the card: dose rows carry InkWells of their own, and a
      // bare `.last` finder tapped one of those instead.
      await tester.tap(find.descendant(
        of: find.byType(BqHintCard),
        matching: find.byType(InkWell),
      ));
      await pumpFrames(tester);

      expect(find.byType(BqHintCard), findsNothing);
      expect(prefs.getStringList('first_run_hints_seen'),
          contains('hint_mark_dose'));

      await flushTearDown(tester);
    });

    testWidgets('a day with NO doses shows no hint — there is nothing to tap',
        (tester) async {
      final container = todayScope();
      await tester.pumpWidget(todayApp(container));
      await pumpFrames(tester);

      expect(find.byType(BqHintCard), findsNothing,
          reason: 'a hint about tapping a dose on a day that has none is '
              'exactly the mistimed coach mark this design avoids');

      await flushTearDown(tester);
    });
  });
}

class _FixedToday extends TodayController {
  _FixedToday(this._day);

  final DateTime _day;

  @override
  DateTime build() => _day;
}
