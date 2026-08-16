/// Unit tests for [RegimenEditorController] (plan 02-03, Task 1).
///
/// Covers the editor's draft state machine without any widgets:
/// - synchronous seeding (defaults for a fresh supplement; existing regimen
///   read from a warm [stackEntriesProvider] — UI-SPEC #17)
/// - slot clamping by construction (cap 6, floor 1, auto-sort — REGI-03/V-1)
/// - course date clamping (endDate >= startDate — V-1/E-6)
/// - PF-8 one-regimen-per-supplement: double save reuses the regimen id,
///   including the save-time findForSupplement re-check (threat T-02-05)
/// - pause round-trip and cascade delete via softDeleteCascade
///
/// Harness: ProviderContainer with [dbProvider] overridden to an in-memory
/// Drift database; a listener on [stackEntriesProvider] keeps the graph
/// alive (Riverpod 3 pauses unlistened providers — Phase-1 pattern).
library;

import 'dart:async';

import 'package:boostque/core/db/database.dart' show BoostqueDb;
import 'package:boostque/core/domain/cycle_math.dart';
import 'package:boostque/core/domain/models.dart';
import 'package:boostque/core/domain/repositories.dart';
import 'package:boostque/core/providers.dart';
import 'package:boostque/features/stack/regimen_editor_controller.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// A [RegimenRepository] whose `upsert` parks on a gate until the test opens
/// it — the save-in-flight window a real transaction leaves open, made
/// deterministic.
///
/// Only the members the editor's save path touches do anything; the rest
/// throw, so a test that starts depending on them fails loudly instead of
/// silently exercising a stub.
class GatedRegimenRepo implements RegimenRepository {
  /// Every regimen handed to [upsert], in call order.
  final List<Regimen> upserts = <Regimen>[];

  Completer<void> _gate = Completer<void>();

  /// Lets every parked (and every future) `upsert` through.
  void release() {
    if (!_gate.isCompleted) _gate.complete();
  }

  /// Re-arms the gate so the NEXT `upsert` parks again.
  void rearm() => _gate = Completer<void>();

  @override
  Stream<List<Regimen>> watchAll() => Stream<List<Regimen>>.value(const []);

  @override
  Future<Regimen?> findForSupplement(String supplementId) async => null;

  @override
  Future<void> upsert(Regimen r) async {
    upserts.add(r);
    await _gate.future;
  }

  @override
  Future<void> setPaused(String regimenId, bool paused) async =>
      throw UnimplementedError();

  @override
  Future<void> softDelete(String regimenId) async =>
      throw UnimplementedError();
}

void main() {
  // The draft's default start date now comes from `todayProvider` (plan
  // 03-01, IN-06), whose controller constructs an AppLifecycleListener — that
  // requires a live WidgetsBinding even in a widget-free unit test.
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer(
      overrides: [
        dbProvider.overrideWith((ref) {
          final db = BoostqueDb.forTesting(NativeDatabase.memory());
          ref.onDispose(db.close);
          return db;
        }),
      ],
    );
    // Riverpod pauses unlistened providers; keep the stack graph warm so
    // stackEntriesProvider recomputes on Drift stream emissions.
    final sub = container.listen(stackEntriesProvider, (_, _) {});
    addTearDown(sub.close);
  });

  tearDown(() => container.dispose());

  const supplement = Supplement(
    id: 's1',
    name: 'Магній',
    doseText: '400 мг',
    colorValue: 0xFF6B6FA8,
    note: '',
  );

  /// Polls until [predicate] returns true (Drift emissions are async).
  Future<void> waitUntil(bool Function() predicate, String description) async {
    for (var i = 0; i < 200; i++) {
      if (predicate()) return;
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    fail('timed out waiting for: $description');
  }

  /// Waits until [stackEntriesProvider] holds AsyncData whose entry for
  /// [supplementId] has a non-null regimen.
  Future<void> waitForRegimenEntry(String supplementId) => waitUntil(() {
        final value = container.read(stackEntriesProvider);
        if (value case AsyncData(value: final entries)) {
          return entries.any(
            (e) => e.supplement.id == supplementId && e.regimen != null,
          );
        }
        return false;
      }, 'stackEntriesProvider entry with regimen for $supplementId');

  /// Reads the current regimen list snapshot from the repository stream.
  Future<List<Regimen>> regimensNow() =>
      container.read(regimenRepoProvider).watchAll().first;

  /// Opens the editor for [id], keeping the autoDispose provider alive for
  /// the rest of the test.
  RegimenEditorController editorFor(String id) {
    final sub = container.listen(regimenEditorProvider(id), (_, _) {});
    addTearDown(sub.close);
    return container.read(regimenEditorProvider(id).notifier);
  }

  RegimenDraft draftOf(String id) => container.read(regimenEditorProvider(id));

  group('seeding (UI-SPEC #17: synchronous, never an empty form)', () {
    test('fresh supplement seeds documented defaults (A6: 1 slot at 08:00)',
        () {
      editorFor('s1');
      final draft = draftOf('s1');

      expect(draft.regimenId, isNull);
      expect(draft.kind, RegimenKind.cyclic);
      expect(draft.onDays, 56);
      expect(draft.offDays, 28);
      expect(draft.paused, isFalse);
      expect(draft.endDate, isNull);
      expect(draft.slots, hasLength(1));
      expect(draft.slots.single.id, isNull);
      expect(draft.slots.single.minutesFromMidnight, 480);
      expect(draft.slots.single.doseLabel, isEmpty);
      // startDate is a UTC date-only value (PF-2 discipline).
      expect(draft.startDate, dateOnly(DateTime.now()));
      expect(draft.startDate.isUtc, isTrue);
    });

    test('existing regimen seeds the draft synchronously with carried ids',
        () async {
      await container.read(supplementRepoProvider).upsert(supplement);
      await container.read(regimenRepoProvider).upsert(Regimen(
            id: 'r1',
            supplementId: 's1',
            kind: RegimenKind.cyclic,
            startDate: DateTime.utc(2026, 8, 1),
            endDate: null,
            onDays: 28,
            offDays: 14,
            paused: false,
            slots: const [
              DoseSlot(id: 'sl-evening', minutesFromMidnight: 1140,
                  doseLabel: '2 капсули'),
              DoseSlot(id: 'sl-morning', minutesFromMidnight: 480,
                  doseLabel: '1 капсула'),
            ],
          ));
      await waitForRegimenEntry('s1');

      editorFor('s1');
      final draft = draftOf('s1');

      expect(draft.regimenId, 'r1');
      expect(draft.kind, RegimenKind.cyclic);
      expect(draft.startDate, DateTime.utc(2026, 8, 1));
      expect(draft.onDays, 28);
      expect(draft.offDays, 14);
      expect(draft.paused, isFalse);
      // Slots carried over with their ids, sorted by time.
      expect(draft.slots.map((s) => s.id), ['sl-morning', 'sl-evening']);
      expect(draft.slots.map((s) => s.minutesFromMidnight), [480, 1140]);
      expect(draft.slots.map((s) => s.doseLabel), ['1 капсула', '2 капсули']);
    });
  });

  group('seed clamping (WR-02: out-of-range DB values never crash sliders)',
      () {
    test('onDays/offDays outside the slider ranges are clamped at the seed '
        'boundary (0 -> 7, 200 -> 84)', () async {
      await container.read(supplementRepoProvider).upsert(supplement);
      // Rows written by non-editor writers are unconstrained; the Drift
      // column default for onDays is even 0.
      await container.read(regimenRepoProvider).upsert(Regimen(
            id: 'r-bad',
            supplementId: 's1',
            kind: RegimenKind.cyclic,
            startDate: DateTime.utc(2026, 8, 1),
            endDate: null,
            onDays: 0,
            offDays: 200,
            paused: false,
            slots: const [
              DoseSlot(id: 'sl1', minutesFromMidnight: 480, doseLabel: ''),
            ],
          ));
      await waitForRegimenEntry('s1');

      editorFor('s1');
      final draft = draftOf('s1');
      expect(draft.onDays, 7,
          reason: 'onDays clamps up to the slider floor (min 7)');
      expect(draft.offDays, 84,
          reason: 'offDays clamps down to the slider cap (max 84)');
    });

    test('off-grid day counts snap to the 7-day grid the sliders edit in',
        () async {
      await container.read(supplementRepoProvider).upsert(supplement);
      await container.read(regimenRepoProvider).upsert(Regimen(
            id: 'r-offgrid',
            supplementId: 's1',
            kind: RegimenKind.cyclic,
            startDate: DateTime.utc(2026, 8, 1),
            endDate: null,
            onDays: 60,
            offDays: 10,
            paused: false,
            slots: const [
              DoseSlot(id: 'sl1', minutesFromMidnight: 480, doseLabel: ''),
            ],
          ));
      await waitForRegimenEntry('s1');

      editorFor('s1');
      final draft = draftOf('s1');
      expect(draft.onDays, 63, reason: '60 snaps to the nearest week (63)');
      expect(draft.offDays, 7, reason: '10 snaps to the nearest week (7)');
    });
  });

  group('slot operations (REGI-03/V-1: clamped by construction)', () {
    test('addSlot walks nextSlotDefaults, skips used times, caps at 6', () {
      final editor = editorFor('s1');

      // Default slot occupies 08:00; the walk continues from 13:00.
      expect(draftOf('s1').slots.map((s) => s.minutesFromMidnight), [480]);

      editor.addSlot(); // 13:00
      editor.addSlot(); // 19:00
      editor.addSlot(); // 22:00
      editor.addSlot(); // 10:30
      expect(editor.canAddSlot, isTrue);
      editor.addSlot(); // 16:00 — now 6 slots

      // Sorted by minutesFromMidnight after every add.
      expect(
        draftOf('s1').slots.map((s) => s.minutesFromMidnight),
        [480, 630, 780, 960, 1140, 1320],
      );

      // Cap: refuses at 6.
      expect(editor.canAddSlot, isFalse);
      editor.addSlot();
      expect(draftOf('s1').slots, hasLength(6));
    });

    test('addSlot skips an already-used default time', () {
      final editor = editorFor('s1');
      editor.setSlotTime(0, 780); // move the only slot to 13:00
      editor.addSlot();
      // 08:00 is free again -> the walk picks it first.
      expect(
        draftOf('s1').slots.map((s) => s.minutesFromMidnight),
        [480, 780],
      );
    });

    test('removeSlot floors at 1', () {
      final editor = editorFor('s1');
      editor.addSlot();
      expect(draftOf('s1').slots, hasLength(2));
      expect(editor.canRemoveSlot, isTrue);

      editor.removeSlot(1);
      expect(draftOf('s1').slots, hasLength(1));
      expect(editor.canRemoveSlot, isFalse);

      editor.removeSlot(0);
      expect(draftOf('s1').slots, hasLength(1),
          reason: 'removeSlot must refuse at the floor of 1');
    });

    test('setSlotTime re-sorts slots by minutesFromMidnight', () {
      final editor = editorFor('s1');
      editor.addSlot(); // [480, 780]
      editor.setSlotDoseLabel(0, 'morning');
      editor.setSlotDoseLabel(1, 'afternoon');

      editor.setSlotTime(0, 1380); // morning slot moved to 23:00
      final slots = draftOf('s1').slots;
      expect(slots.map((s) => s.minutesFromMidnight), [780, 1380]);
      expect(slots.map((s) => s.doseLabel), ['afternoon', 'morning'],
          reason: 'the moved slot keeps its own label after the re-sort');
    });
  });

  group('course dates (V-1/E-6: endDate >= startDate by construction)', () {
    test('setKind(course) with null endDate seeds endDate = startDate + 27',
        () {
      final editor = editorFor('s1');
      final start = draftOf('s1').startDate;

      editor.setKind(RegimenKind.course);
      expect(draftOf('s1').endDate, start.add(const Duration(days: 27)));
    });

    test('setStartDate past endDate clamps endDate to the new startDate', () {
      final editor = editorFor('s1');
      editor.setKind(RegimenKind.course);
      editor.setStartDate(DateTime.utc(2026, 9, 1));
      editor.setEndDate(DateTime.utc(2026, 9, 10));

      editor.setStartDate(DateTime.utc(2026, 10, 1));
      expect(draftOf('s1').startDate, DateTime.utc(2026, 10, 1));
      expect(draftOf('s1').endDate, DateTime.utc(2026, 10, 1));
    });

    test('setStartDate/setEndDate normalize to UTC date-only (PF-2)', () {
      final editor = editorFor('s1');
      editor.setKind(RegimenKind.course);
      // Local-zone values as showDatePicker returns them.
      editor.setStartDate(DateTime(2026, 9, 1, 14, 30));
      editor.setEndDate(DateTime(2026, 9, 20, 9, 15));

      expect(draftOf('s1').startDate, DateTime.utc(2026, 9, 1));
      expect(draftOf('s1').endDate, DateTime.utc(2026, 9, 20));
    });
  });

  group('save (PF-8: one regimen per supplement, id reuse)', () {
    test('save persists a regimen matching the draft; double save keeps '
        'exactly one row with an unchanged id', () async {
      await container.read(supplementRepoProvider).upsert(supplement);
      final editor = editorFor('s1');
      editor.setOnDays(28);
      editor.setOffDays(7);
      editor.addSlot(); // second slot at 13:00

      await editor.save();
      var regimens = await regimensNow();
      expect(regimens, hasLength(1));
      final savedId = regimens.single.id;
      expect(savedId, isNotEmpty);
      expect(regimens.single.supplementId, 's1');
      expect(regimens.single.kind, RegimenKind.cyclic);
      expect(regimens.single.onDays, 28);
      expect(regimens.single.offDays, 7);
      expect(regimens.single.endDate, isNull,
          reason: 'cyclic regimens persist a null endDate');
      expect(
        regimens.single.slots.map((s) => s.minutesFromMidnight),
        [480, 780],
      );

      // The resolved id is stored back into the draft.
      expect(draftOf('s1').regimenId, savedId);
      final slotIdsAfterFirstSave =
          draftOf('s1').slots.map((s) => s.id).toList();
      expect(slotIdsAfterFirstSave, everyElement(isNotNull),
          reason: 'minted slot ids are stored back for reuse');

      // Second save: still exactly ONE regimen, same id, same slot ids.
      await editor.save();
      regimens = await regimensNow();
      expect(regimens, hasLength(1), reason: 'PF-8: no ghost regimen rows');
      expect(regimens.single.id, savedId);
      expect(
        regimens.single.slots.map((s) => s.id),
        slotIdsAfterFirstSave,
        reason: 'surviving slot ids are reused, not re-minted',
      );
    });

    test('concurrent saves are single-flight: two racing save() calls share '
        'one future and persist exactly one regimen row (CR-01)', () async {
      await container.read(supplementRepoProvider).upsert(supplement);
      final editor = editorFor('s1');

      // Two calls without an await in between — the double-tap race.
      final first = editor.save();
      final second = editor.save();
      expect(identical(first, second), isTrue,
          reason: 'save() must return the SAME in-flight future to '
              'concurrent callers (single-flight)');
      await Future.wait([first, second]);

      final regimens = await regimensNow();
      expect(regimens, hasLength(1),
          reason: 'a double-tap race must not mint two regimen ids (PF-8)');
      expect(draftOf('s1').regimenId, regimens.single.id);

      // A save AFTER completion starts a fresh (non-identical) future and
      // still reuses the resolved id.
      final third = editor.save();
      expect(identical(first, third), isFalse);
      await third;
      expect(await regimensNow(), hasLength(1));
    });

    test('save with a stale draft re-checks findForSupplement and reuses the '
        'existing regimen id (PF-8 belt-and-suspenders)', () async {
      // Warm the stack graph FIRST: this is the warm-seeded stale-draft
      // case (regimen appears behind the editor's back after a legitimate
      // open); the blind-seeded case is covered by the WR-03 group below.
      await waitUntil(
        () => container.read(stackEntriesProvider) is AsyncData,
        'stackEntriesProvider warm (AsyncData)',
      );
      // Editor seeded while the DB has no regimen -> draft.regimenId == null.
      final editor = editorFor('s1');
      expect(draftOf('s1').regimenId, isNull);

      // A regimen appears behind the editor's back.
      await container.read(supplementRepoProvider).upsert(supplement);
      await container.read(regimenRepoProvider).upsert(Regimen(
            id: 'r-existing',
            supplementId: 's1',
            kind: RegimenKind.cyclic,
            startDate: DateTime.utc(2026, 8, 1),
            endDate: null,
            onDays: 56,
            offDays: 28,
            paused: false,
            slots: const [
              DoseSlot(id: 'sl1', minutesFromMidnight: 480, doseLabel: ''),
            ],
          ));

      await editor.save();
      final regimens = await regimensNow();
      expect(regimens, hasLength(1),
          reason: 'save-time re-check must prevent a second regimen row');
      expect(regimens.single.id, 'r-existing');
      expect(draftOf('s1').regimenId, 'r-existing');
    });

    test('save persists endDate for course and nulls it for cyclic',
        () async {
      await container.read(supplementRepoProvider).upsert(supplement);
      final editor = editorFor('s1');
      editor.setKind(RegimenKind.course);
      editor.setStartDate(DateTime.utc(2026, 9, 1));
      editor.setEndDate(DateTime.utc(2026, 9, 28));

      await editor.save();
      var regimens = await regimensNow();
      expect(regimens.single.kind, RegimenKind.course);
      expect(regimens.single.startDate, DateTime.utc(2026, 9, 1));
      expect(regimens.single.endDate, DateTime.utc(2026, 9, 28));

      editor.setKind(RegimenKind.cyclic);
      await editor.save();
      regimens = await regimensNow();
      expect(regimens, hasLength(1));
      expect(regimens.single.kind, RegimenKind.cyclic);
      expect(regimens.single.endDate, isNull);
    });
  });

  group('blind seed (WR-03: never clobber a regimen the draft never saw)',
      () {
    test('save() with a blind-seeded draft refuses to overwrite an existing '
        'regimen, re-seeds the draft from the store, and a retry succeeds',
        () async {
      // A container whose stack graph is deliberately NEVER warm — the
      // editor opens over AsyncLoading (future callers: deep links, state
      // restoration).
      final cold = ProviderContainer(
        overrides: [
          dbProvider.overrideWith((ref) {
            final db = BoostqueDb.forTesting(NativeDatabase.memory());
            ref.onDispose(db.close);
            return db;
          }),
          stackEntriesProvider.overrideWithValue(const AsyncLoading()),
        ],
      );
      addTearDown(cold.dispose);

      await cold.read(supplementRepoProvider).upsert(supplement);
      await cold.read(regimenRepoProvider).upsert(Regimen(
            id: 'r-real',
            supplementId: 's1',
            kind: RegimenKind.cyclic,
            startDate: DateTime.utc(2026, 8, 1),
            endDate: null,
            onDays: 28,
            offDays: 14,
            paused: false,
            slots: const [
              DoseSlot(
                  id: 'sl-real',
                  minutesFromMidnight: 1140,
                  doseLabel: '2 капсули'),
            ],
          ));

      final sub = cold.listen(regimenEditorProvider('s1'), (_, _) {});
      addTearDown(sub.close);
      final editor = cold.read(regimenEditorProvider('s1').notifier);

      // Blind seed: the defaults, not the stored 28/14 regimen.
      expect(cold.read(regimenEditorProvider('s1')).regimenId, isNull);
      expect(cold.read(regimenEditorProvider('s1')).onDays, 56);

      // The destructive overwrite is refused...
      await expectLater(editor.save(), throwsStateError);

      // ...the stored regimen is untouched...
      final regimens =
          await cold.read(regimenRepoProvider).watchAll().first;
      expect(regimens, hasLength(1));
      expect(regimens.single.id, 'r-real');
      expect(regimens.single.onDays, 28);
      expect(regimens.single.offDays, 14);
      expect(regimens.single.slots.single.id, 'sl-real',
          reason: 'slot reconciliation must NOT have soft-deleted the '
              'real slots');

      // ...and the draft was re-seeded from the store, so the form now
      // shows the real settings and a retry save is safe.
      final reseeded = cold.read(regimenEditorProvider('s1'));
      expect(reseeded.regimenId, 'r-real');
      expect(reseeded.onDays, 28);
      expect(reseeded.offDays, 14);
      expect(reseeded.slots.single.id, 'sl-real');

      await editor.save();
      final afterRetry =
          await cold.read(regimenRepoProvider).watchAll().first;
      expect(afterRetry, hasLength(1));
      expect(afterRetry.single.id, 'r-real');
      expect(afterRetry.single.onDays, 28);
    });

    test('save() with a blind-seeded draft still mints a regimen when NONE '
        'exists (fresh add flow stays intact)', () async {
      final cold = ProviderContainer(
        overrides: [
          dbProvider.overrideWith((ref) {
            final db = BoostqueDb.forTesting(NativeDatabase.memory());
            ref.onDispose(db.close);
            return db;
          }),
          stackEntriesProvider.overrideWithValue(const AsyncLoading()),
        ],
      );
      addTearDown(cold.dispose);
      await cold.read(supplementRepoProvider).upsert(supplement);

      final sub = cold.listen(regimenEditorProvider('s1'), (_, _) {});
      addTearDown(sub.close);
      final editor = cold.read(regimenEditorProvider('s1').notifier);

      await editor.save();
      final regimens =
          await cold.read(regimenRepoProvider).watchAll().first;
      expect(regimens, hasLength(1),
          reason: 'no regimen existed — the blind guard must not block '
              'a genuinely fresh save');
      expect(cold.read(regimenEditorProvider('s1')).regimenId,
          regimens.single.id);
    });
  });

  group('pause and delete', () {
    test('togglePause flips the draft only; save persists it (round-trip)',
        () async {
      await container.read(supplementRepoProvider).upsert(supplement);
      final editor = editorFor('s1');

      editor.togglePause();
      expect(draftOf('s1').paused, isTrue);
      // Not yet persisted — persistence happens on save.
      expect(await regimensNow(), isEmpty);

      await editor.save();
      expect((await regimensNow()).single.paused, isTrue);

      editor.togglePause();
      expect(draftOf('s1').paused, isFalse);
      await editor.save();
      final regimens = await regimensNow();
      expect(regimens, hasLength(1));
      expect(regimens.single.paused, isFalse);
    });

    test('deleteSupplement cascades: supplement and regimen watchAll go empty',
        () async {
      await container.read(supplementRepoProvider).upsert(supplement);
      final editor = editorFor('s1');
      await editor.save();
      expect(await regimensNow(), hasLength(1));

      await editor.deleteSupplement();

      expect(
        await container.read(supplementRepoProvider).watchAll().first,
        isEmpty,
      );
      expect(await regimensNow(), isEmpty);
    });
  });

  group('save-in-flight window (WR-01/WR-02/WR-03)', () {
    late GatedRegimenRepo repo;
    late ProviderContainer gated;

    /// A container whose regimen writes park on [repo]'s gate and whose stack
    /// graph is WARM and empty (a fresh supplement, no regimen — so the seed
    /// is not blind and `save()` takes the mint-a-new-id path).
    setUp(() {
      repo = GatedRegimenRepo();
      gated = ProviderContainer(
        overrides: [
          regimenRepoProvider.overrideWithValue(repo),
          stackEntriesProvider.overrideWithValue(
            const AsyncData<List<StackEntry>>([
              StackEntry(supplement: supplement),
            ]),
          ),
        ],
      );
      addTearDown(gated.dispose);
    });

    RegimenEditorController openEditor() {
      final sub = gated.listen(regimenEditorProvider('s1'), (_, _) {});
      addTearDown(sub.close);
      return gated.read(regimenEditorProvider('s1').notifier);
    }

    RegimenDraft gatedDraft() => gated.read(regimenEditorProvider('s1'));

    test('an edit made DURING the save is not reverted by the save (WR-01)',
        () async {
      final editor = openEditor();
      final saving = editor.save();
      // Parked inside repo.upsert: the transaction is open, the form is not.
      await pumpEventQueue();
      expect(repo.upserts, hasLength(1), reason: 'the save is in flight');

      // The user keeps typing / dragging while the write runs — only the save
      // BUTTON is disabled during the flight, nothing else on the form is.
      editor.setSlotDoseLabel(0, '5 г');
      editor.setOnDays(21);

      repo.release();
      await saving;

      final draft = gatedDraft();
      expect(draft.slots.single.doseLabel, '5 г',
          reason: 'a keystroke made during the save must survive it — the '
              'post-await write must MERGE the resolved ids into the CURRENT '
              'draft, never restore the pre-await snapshot (WR-01)');
      expect(draft.onDays, 21,
          reason: 'the same holds for the sliders (WR-01)');
      expect(draft.regimenId, isNotNull,
          reason: 'the resolved regimen id is still stamped into the draft');
      expect(draft.slots.single.id, isNotNull,
          reason: 'the resolved slot id is still stamped into the draft, so '
              'the next save reuses it rather than minting a second one');
    });

    test('a second save() of a CHANGED draft persists that change (WR-02)',
        () async {
      final editor = openEditor();
      final first = editor.save();
      await pumpEventQueue();

      // The draft changes while the first write is still open, then the user
      // saves again (an autosave, a second tap after an edit, a test driving
      // the public API — save() is public).
      editor.setOnDays(21);
      final second = editor.save();
      expect(identical(first, second), isFalse,
          reason: 'awaiting save() must mean "the draft I had is on disk"; '
              'handing back the in-flight future of an OLDER draft resolves '
              'successfully without ever persisting the newer one (WR-02)');

      repo.release();
      await Future.wait<void>([first, second]);

      expect(repo.upserts, hasLength(2),
          reason: 'the changed draft must reach the repository');
      expect(repo.upserts.last.onDays, 21,
          reason: 'the LAST write must carry the newest draft (WR-02)');
      expect(repo.upserts.map((r) => r.id).toSet(), hasLength(1),
          reason: 'serialized, not concurrent: the second save reuses the '
              'first one\'s resolved regimen id — no ghost row (PF-8)');
    });

    test('a save that outlives its screen completes instead of throwing '
        '(WR-03)', () async {
      // Kept alive by ONE subscription, exactly like the screen's ref.watch.
      final sub = gated.listen(regimenEditorProvider('s1'), (_, _) {});
      final editor = gated.read(regimenEditorProvider('s1').notifier);
      final saving = editor.save();
      await pumpEventQueue();

      // The user taps Save and immediately backs out: the route pops, the
      // last listener goes, and the autoDispose editor provider is torn down
      // while the write is still open.
      sub.close();
      await pumpEventQueue();

      repo.release();
      await expectLater(
        saving,
        completes,
        reason: 'writing state after an await on a DISPOSED autoDispose '
            'Notifier throws, and that throw is swallowed by the catch the '
            'screen wrote for a FAILED WRITE — so a genuinely failed write '
            'and a screen that went away become indistinguishable (WR-03)',
      );
      expect(repo.upserts, hasLength(1),
          reason: 'the write itself still committed — only the state '
              'write-back is skipped');
    });
  });
}
