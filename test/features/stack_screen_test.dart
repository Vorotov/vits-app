/// Tracer widget test (plan 02-01): the single happy path — open the add
/// sheet, type a name, save — flows through supplementRepoProvider into a
/// real in-memory Drift database and back out through stackEntriesProvider
/// onto the Stack screen as a card (STACK-02).
library;

import 'package:boostque/core/db/database.dart' show BoostqueDb;
import 'package:boostque/core/l10n/l10n.dart';
import 'package:boostque/core/providers.dart';
import 'package:boostque/core/theme/theme.dart';
import 'package:boostque/features/stack/stack_screen.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    // LocaleController loads its persisted override from SharedPreferences.
    SharedPreferences.setMockInitialValues({});
  });

  Widget app() {
    return ProviderScope(
      overrides: [
        dbProvider.overrideWith((ref) {
          final db = BoostqueDb.forTesting(NativeDatabase.memory());
          ref.onDispose(db.close);
          return db;
        }),
      ],
      child: MaterialApp(
        locale: const Locale('uk'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: bqTheme(),
        home: const StackScreen(),
      ),
    );
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

  testWidgets(
      'uk: manual add through the sheet persists and renders a card; '
      'save stays disabled for empty/whitespace names (V-1)', (tester) async {
    await tester.pumpWidget(app());
    await tester.pump();

    // Open the add sheet via the single CTA on the screen.
    await tester.tap(find.text('Додати добавку'));
    await tester.pumpAndSettle();

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
    await tester.enterText(nameField, 'Креатин моногідрат');
    await tester.pump();
    expect(tester.widget<FilledButton>(sheetSave).onPressed, isNotNull);

    // Save: writes through the repository into the real in-memory DB, the
    // sheet closes, and the Drift stream delivers the new card.
    await tester.tap(sheetSave);
    await tester.pumpAndSettle();

    await pumpUntilFound(tester, find.text('Креатин моногідрат'));
    expect(find.text('Креатин моногідрат'), findsOneWidget,
        reason: 'the added supplement renders as a stack card from the DB');
    expect(find.byType(BottomSheet), findsNothing,
        reason: 'the sheet closed after a successful save');
    expect(tester.takeException(), isNull,
        reason: 'no overflow/exception in uk locale');

    // Tear the tree down inside the test body so Drift's stream-close
    // zero-duration timers fire before flutter_test's pending-timer check.
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 10));
    await tester.pump(const Duration(milliseconds: 10));
  });
}
