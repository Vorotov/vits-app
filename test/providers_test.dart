/// Riverpod provider graph tests (plan 01-07).
///
/// Uses a ProviderContainer with [dbProvider] overridden to an in-memory
/// database — no test ever touches the on-disk vitomy.sqlite file (D-19).
library;

import 'package:vitomy/core/db/database.dart' show VitomyDb;
import 'package:vitomy/core/domain/models.dart';
import 'package:vitomy/core/domain/repositories.dart';
import 'package:vitomy/core/providers.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer(
      overrides: [
        dbProvider.overrideWith((ref) {
          final db = VitomyDb.forTesting(NativeDatabase.memory());
          ref.onDispose(db.close);
          return db;
        }),
      ],
    );
  });

  tearDown(() => container.dispose());

  /// Polls [stackEntriesProvider] until it holds AsyncData with [count]
  /// entries (drift stream emissions arrive asynchronously).
  Future<List<StackEntry>> waitForEntries(int count) async {
    for (var i = 0; i < 200; i++) {
      final value = container.read(stackEntriesProvider);
      if (value case AsyncData(value: final data) when data.length == count) {
        return data;
      }
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    fail('stackEntriesProvider never reached $count entries');
  }

  test('repo providers expose the domain interfaces, not Drift classes',
      () async {
    final repo = container.read(supplementRepoProvider);
    expect(repo, isA<SupplementRepository>());
    expect(container.read(regimenRepoProvider), isA<RegimenRepository>());
    expect(container.read(intakeRepoProvider), isA<IntakeRepository>());
  });

  test('fresh install: streams emit [] and stackEntries is empty AsyncData '
      '(DATA-01/empty)', () async {
    // Riverpod pauses unlistened providers; keep the graph active.
    final sub = container.listen(stackEntriesProvider, (_, _) {});
    addTearDown(sub.close);

    expect(await container.read(supplementsStreamProvider.future), isEmpty);
    expect(await container.read(regimensStreamProvider.future), isEmpty);

    final entries = await waitForEntries(0);
    expect(container.read(stackEntriesProvider),
        isA<AsyncData<List<StackEntry>>>());
    expect(entries, isEmpty);
  });

  test('upsert flows through the provider graph into stackEntries', () async {
    // Keep the graph alive so recomputation happens on stream emissions.
    final sub = container.listen(stackEntriesProvider, (_, _) {});
    addTearDown(sub.close);
    await waitForEntries(0);

    await container.read(supplementRepoProvider).upsert(const Supplement(
          id: 's1',
          name: 'Магній',
          doseText: '400 мг',
          colorValue: 0xFF6B6FA8,
          note: '',
        ));

    final entries = await waitForEntries(1);
    expect(entries.single.supplement.name, 'Магній');
    expect(entries.single.regimen, isNull,
        reason: 'supplement without a regimen pairs with null');
  });
}
