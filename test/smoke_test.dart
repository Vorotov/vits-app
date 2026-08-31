import 'package:boostque/core/db/database.dart' show BoostqueDb;
import 'package:boostque/core/providers.dart';
import 'package:boostque/main.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('app boots inside ProviderScope and renders a MaterialApp',
      (tester) async {
    // `onboarding_seen`: this test boots a RETURNING user into the shell;
    // the first-launch (onboarding) branch has its own suite
    // (onboarding_gate_test.dart).
    SharedPreferences.setMockInitialValues({'onboarding_seen': true});
    // Since plan 05-01 LocaleController seeds itself synchronously from
    // sharedPreferencesProvider, which throws unless overridden — every scope
    // that pumps BoostqueApp must hand it a resolved instance (P-4 Option A).
    final prefs = await SharedPreferences.getInstance();
    // Since plan 02-01 the Stack tab watches stackEntriesProvider, so the
    // boot test must override dbProvider with an in-memory database (D-19).
    await tester.pumpWidget(ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        dbProvider.overrideWith((ref) {
          final db = BoostqueDb.forTesting(NativeDatabase.memory());
          ref.onDispose(db.close);
          return db;
        }),
      ],
      child: const BoostqueApp(),
    ));
    expect(find.byType(MaterialApp), findsOneWidget);

    // Tear down inside the test body so Drift's stream-close zero-duration
    // timers fire before flutter_test's pending-timer check.
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 10));
    await tester.pump(const Duration(milliseconds: 10));
  });
}
