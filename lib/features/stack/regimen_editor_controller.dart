/// Regimen editor draft state + controller (plan 02-03, P-5/PF-8/D-23).
///
/// Screen-scoped state for the Dosing Schedule editor, built as a Riverpod 3
/// constructor-arg family Notifier (P-5: `FamilyNotifier` is gone in
/// Riverpod 3 — the argument arrives through the constructor and the
/// provider is `NotifierProvider.autoDispose.family`; autoDispose is correct
/// for screen-scoped state per the D-23 policy recorded in
/// `core/providers.dart`).
///
/// Invariants owned here:
/// - Synchronous seeding (UI-SPEC #17): `build()` reads the warm
///   [stackEntriesProvider] snapshot and seeds either the supplement's
///   existing regimen or the documented defaults — never an async gap,
///   never an empty form.
/// - PF-8 one-regimen-per-supplement: `save()` reuses `draft.regimenId`,
///   else re-checks `findForSupplement` at save time, and only mints a new
///   UUID when no regimen exists. Surviving slot ids are reused; new slots
///   mint UUIDs at the save boundary only (never in `build()`).
/// - Slot clamping by construction (REGI-03/V-1): cap 6 / floor 1 via
///   [RegimenEditorController.canAddSlot]/[RegimenEditorController.canRemoveSlot];
///   slots re-sort by time after every add/edit.
/// - Date discipline (PF-2): every stored date goes through [dateOnly];
///   course `endDate` is clamped to `>= startDate` (V-1/E-6). The default
///   start date and the cascade-delete boundary read the day from
///   `todayProvider`, the app's single calendar clock (plan 03-01, IN-06) —
///   never a fresh wall-clock read per call.
/// - `togglePause()` flips the draft only — persistence happens on `save()`,
///   matching the mockup's "Зберегти, цикл на паузі" CTA (the footer save
///   button carries the pause state to disk).
///
/// No Flutter widget imports, no Drift imports — repositories are reached
/// through the provider graph interfaces only (D-22).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:boostque/core/domain/cycle_math.dart';
import 'package:boostque/core/domain/models.dart';
import 'package:boostque/core/providers.dart';
import 'package:boostque/core/today_controller.dart';

/// Sentinel for [RegimenDraft.copyWith] nullable parameters.
const Object _unset = Object();

/// One editable time slot in the draft. [id] is null until the slot has been
/// persisted once; surviving ids are carried across saves (PF-8).
class DraftSlot {
  /// Persisted slot UUID, or null for a slot not yet saved.
  final String? id;

  /// Wall-clock time of day, minutes since midnight (0..1439).
  final int minutesFromMidnight;

  /// User-facing dose label (e.g. "5 g"); may be empty.
  final String doseLabel;

  const DraftSlot({
    required this.id,
    required this.minutesFromMidnight,
    required this.doseLabel,
  });

  DraftSlot copyWith({
    Object? id = _unset,
    int? minutesFromMidnight,
    String? doseLabel,
  }) =>
      DraftSlot(
        id: id == _unset ? this.id : id as String?,
        minutesFromMidnight: minutesFromMidnight ?? this.minutesFromMidnight,
        doseLabel: doseLabel ?? this.doseLabel,
      );
}

/// Immutable editor draft: the whole form state for one supplement's regimen.
class RegimenDraft {
  /// Persisted regimen UUID, or null while no save has resolved one (PF-8).
  final String? regimenId;

  /// Cyclic (on/off pattern) or one-time course.
  final RegimenKind kind;

  /// First active day — always a UTC date-only value (PF-2).
  final DateTime startDate;

  /// Inclusive course end — UTC date-only, null for cyclic drafts.
  final DateTime? endDate;

  /// Consecutive active days per cycle (7..112 in steps of 7 via the UI).
  final int onDays;

  /// Consecutive break days per cycle (0..84 in steps of 7 via the UI).
  final int offDays;

  /// Draft pause flag — persisted only on [RegimenEditorController.save].
  final bool paused;

  /// Time slots, kept sorted by [DraftSlot.minutesFromMidnight]; 1..6.
  final List<DraftSlot> slots;

  const RegimenDraft({
    required this.regimenId,
    required this.kind,
    required this.startDate,
    required this.endDate,
    required this.onDays,
    required this.offDays,
    required this.paused,
    required this.slots,
  });

  RegimenDraft copyWith({
    Object? regimenId = _unset,
    RegimenKind? kind,
    DateTime? startDate,
    Object? endDate = _unset,
    int? onDays,
    int? offDays,
    bool? paused,
    List<DraftSlot>? slots,
  }) =>
      RegimenDraft(
        regimenId: regimenId == _unset ? this.regimenId : regimenId as String?,
        kind: kind ?? this.kind,
        startDate: startDate ?? this.startDate,
        endDate: endDate == _unset ? this.endDate : endDate as DateTime?,
        onDays: onDays ?? this.onDays,
        offDays: offDays ?? this.offDays,
        paused: paused ?? this.paused,
        slots: slots ?? this.slots,
      );
}

/// Draft state machine for the regimen editor screen.
class RegimenEditorController extends Notifier<RegimenDraft> {
  RegimenEditorController(this.supplementId);

  /// The supplement whose regimen is being edited (constructor-arg family,
  /// P-5).
  final String supplementId;

  /// Maximum daily time slots (mockup cap; REGI-03).
  static const int maxSlots = 6;

  /// Minimum daily time slots (mockup floor; REGI-03).
  static const int minSlots = 1;

  /// Default times (minutes from midnight) walked in order when adding a
  /// slot, skipping already-used times — mockup NEXT_SLOT
  /// `['08:00','13:00','19:00','22:00','10:30','16:00']`.
  static const List<int> nextSlotDefaults = [480, 780, 1140, 1320, 630, 960];

  /// Fallback time (21:00) when every default is taken (mockup parity).
  static const int fallbackSlotMinutes = 1260;

  /// Course length seeded when switching to course mode without an end date:
  /// startDate + 27 days = a 28-day inclusive course.
  static const int _defaultCourseLengthDays = 27;

  /// True when [build] had to seed defaults WITHOUT a warm `AsyncData`
  /// snapshot (WR-03). Both v1 entry points open the editor over a warm
  /// stack graph, but nothing enforces that for future callers (deep links,
  /// state restoration, Phase 3+ navigation) — a blind-seeded draft must
  /// never silently overwrite a regimen it never saw.
  bool _seedWasBlind = false;

  @override
  RegimenDraft build() {
    // Synchronous seeding (UI-SPEC #17): the stack graph is warm by the time
    // the editor opens — pattern-match the current AsyncValue snapshot.
    final entries = ref.read(stackEntriesProvider);
    if (entries case AsyncData(value: final list)) {
      _seedWasBlind = false;
      for (final entry in list) {
        final regimen = entry.regimen;
        if (entry.supplement.id == supplementId && regimen != null) {
          return _draftFrom(regimen);
        }
      }
      return _defaults();
    }
    // Loading/error: the one-shot read cannot see a regimen that may exist.
    // Seed defaults so the form is never empty, but mark the seed blind —
    // [save] refuses to clobber an existing regimen with this draft (WR-03).
    _seedWasBlind = true;
    return _defaults();
  }

  /// Documented defaults for a fresh supplement (A6: 1 slot at 08:00;
  /// mockup seed 56/28 cyclic). The day comes from `todayProvider` — the
  /// app's single calendar clock (plan 03-01, IN-06) — already normalized as
  /// a UTC date-only value; domain code never reads the clock.
  RegimenDraft _defaults() => RegimenDraft(
        regimenId: null,
        kind: RegimenKind.cyclic,
        startDate: ref.read(todayProvider),
        endDate: null,
        onDays: 56,
        offDays: 28,
        paused: false,
        slots: const [
          DraftSlot(id: null, minutesFromMidnight: 480, doseLabel: ''),
        ],
      );

  /// Maps a persisted regimen to a draft, carrying regimen and slot ids
  /// (PF-8). `onDays`/`offDays` are clamped into the editor's slider ranges
  /// at this seed boundary (WR-02): the Drift column default is 0 and
  /// non-editor writers (tests, a future sync backend) are unconstrained —
  /// an out-of-range `Slider.value` would assert and red-screen the editor,
  /// making the supplement uneditable and undeletable through the UI.
  RegimenDraft _draftFrom(Regimen r) => RegimenDraft(
        regimenId: r.id,
        kind: r.kind,
        startDate: dateOnly(r.startDate),
        endDate: r.endDate == null ? null : dateOnly(r.endDate!),
        onDays: _clampDays(r.onDays, min: 7, max: 112),
        offDays: _clampDays(r.offDays, min: 0, max: 84),
        paused: r.paused,
        slots: _sorted([
          for (final s in r.slots)
            DraftSlot(
              id: s.id,
              minutesFromMidnight: s.minutesFromMidnight,
              doseLabel: s.doseLabel,
            ),
        ]),
      );

  /// Snaps a persisted day count onto the editor's whole-week grid, then
  /// clamps it into `[min, max]` (WR-02). Lossless for editor-written rows —
  /// this UI only ever produces 7-step values inside the slider ranges.
  static int _clampDays(int days, {required int min, required int max}) {
    final snapped = (days / 7).round() * 7;
    return snapped.clamp(min, max);
  }

  /// The single sorting rule: slots always ordered by time ascending.
  static List<DraftSlot> _sorted(List<DraftSlot> slots) {
    final copy = [...slots]
      ..sort((a, b) => a.minutesFromMidnight.compareTo(b.minutesFromMidnight));
    return copy;
  }

  /// Whether another slot may be added (cap [maxSlots]).
  bool get canAddSlot => state.slots.length < maxSlots;

  /// Whether a slot may be removed (floor [minSlots]).
  bool get canRemoveSlot => state.slots.length > minSlots;

  /// Switches cyclic/course. Entering course mode with no end date seeds a
  /// 28-day inclusive course (endDate = startDate + 27 days).
  void setKind(RegimenKind kind) {
    var endDate = state.endDate;
    if (kind == RegimenKind.course && endDate == null) {
      endDate =
          state.startDate.add(const Duration(days: _defaultCourseLengthDays));
    }
    state = state.copyWith(kind: kind, endDate: endDate);
  }

  /// Sets the start date (normalized via [dateOnly]); an end date left
  /// behind the new start is clamped up to it (V-1/E-6).
  void setStartDate(DateTime date) {
    final start = dateOnly(date);
    var end = state.endDate;
    if (end != null && end.isBefore(start)) end = start;
    state = state.copyWith(startDate: start, endDate: end);
  }

  /// Sets the inclusive course end date (normalized via [dateOnly]).
  void setEndDate(DateTime date) {
    state = state.copyWith(endDate: dateOnly(date));
  }

  /// Sets consecutive active days per cycle.
  void setOnDays(int days) => state = state.copyWith(onDays: days);

  /// Sets consecutive break days per cycle.
  void setOffDays(int days) => state = state.copyWith(offDays: days);

  /// Adds a slot at the first unused [nextSlotDefaults] time (fallback
  /// 21:00), keeping slots sorted. Refuses at the cap of [maxSlots].
  void addSlot() {
    if (!canAddSlot) return;
    final used = {for (final s in state.slots) s.minutesFromMidnight};
    final minutes = nextSlotDefaults.firstWhere(
      (t) => !used.contains(t),
      orElse: () => fallbackSlotMinutes,
    );
    state = state.copyWith(
      slots: _sorted([
        ...state.slots,
        DraftSlot(id: null, minutesFromMidnight: minutes, doseLabel: ''),
      ]),
    );
  }

  /// Removes the slot at [index]. Refuses at the floor of [minSlots].
  void removeSlot(int index) {
    if (!canRemoveSlot) return;
    final slots = [...state.slots]..removeAt(index);
    state = state.copyWith(slots: slots);
  }

  /// Changes the time of the slot at [index], then re-sorts.
  void setSlotTime(int index, int minutesFromMidnight) {
    final slots = [...state.slots];
    slots[index] =
        slots[index].copyWith(minutesFromMidnight: minutesFromMidnight);
    state = state.copyWith(slots: _sorted(slots));
  }

  /// Changes the dose label of the slot at [index].
  void setSlotDoseLabel(int index, String doseLabel) {
    final slots = [...state.slots];
    slots[index] = slots[index].copyWith(doseLabel: doseLabel);
    state = state.copyWith(slots: slots);
  }

  /// Flips the draft's pause flag only — persisted on [save] (mockup's
  /// "Зберегти, цикл на паузі" CTA carries the pause state to disk).
  void togglePause() => state = state.copyWith(paused: !state.paused);

  /// In-flight save future — see [save]'s single-flight contract (CR-01).
  Future<void>? _saveInFlight;

  /// Persists the draft as the supplement's ONE regimen (PF-8).
  ///
  /// Single-flight (CR-01): concurrent callers — e.g. a double-tapped save
  /// button — share the SAME in-flight future, so the save-time
  /// `findForSupplement` re-check can never race itself into minting two
  /// regimen ids (ghost rows that double-dose materialization, threat
  /// T-02-05).
  ///
  /// Id resolution order: `draft.regimenId` → save-time
  /// `findForSupplement` re-check (belt-and-suspenders against ghost
  /// regimen rows, threat T-02-05) → mint a new UUID. The resolved regimen
  /// id and all slot ids are stored back into the draft so subsequent saves
  /// reuse them.
  Future<void> save() =>
      _saveInFlight ??= _doSave().whenComplete(() => _saveInFlight = null);

  Future<void> _doSave() async {
    final repo = ref.read(regimenRepoProvider);
    final draft = state;

    var regimenId = draft.regimenId;
    if (regimenId == null) {
      final found = await repo.findForSupplement(supplementId);
      if (found != null && _seedWasBlind) {
        // WR-03: the draft was seeded with defaults before the stack graph
        // was warm — persisting it would silently overwrite the regimen's
        // real settings and soft-delete all of its slots. Re-seed the draft
        // from the store (the form now shows the real settings) and refuse
        // this save; the UI surfaces the failure and stays on screen.
        _seedWasBlind = false;
        state = _draftFrom(found);
        throw StateError(
          'RegimenEditor draft for $supplementId was seeded before the '
          'stack graph was warm (UI-SPEC #17); refusing to overwrite '
          'regimen ${found.id} with defaults',
        );
      }
      regimenId = found?.id;
    }
    regimenId ??= const Uuid().v4();

    final slots = [
      for (final s in draft.slots)
        DraftSlot(
          id: s.id ?? const Uuid().v4(),
          minutesFromMidnight: s.minutesFromMidnight,
          doseLabel: s.doseLabel,
        ),
    ];

    final isCourse = draft.kind == RegimenKind.course;
    await repo.upsert(Regimen(
      id: regimenId,
      supplementId: supplementId,
      kind: draft.kind,
      startDate: dateOnly(draft.startDate),
      endDate: isCourse && draft.endDate != null
          ? dateOnly(draft.endDate!)
          : null,
      onDays: draft.onDays,
      offDays: draft.offDays,
      paused: draft.paused,
      slots: [
        for (final s in slots)
          DoseSlot(
            id: s.id!,
            minutesFromMidnight: s.minutesFromMidnight,
            doseLabel: s.doseLabel,
          ),
      ],
    ));

    state = draft.copyWith(regimenId: regimenId, slots: slots);
    // The draft now owns a persisted id — any earlier blind seed is moot.
    _seedWasBlind = false;
  }

  /// Cascade-soft-deletes the supplement, its regimen(s), slots, and future
  /// pending doses (delegates to `softDeleteCascade`, owned/tested in plan
  /// 02-01). The confirmation UI guarding this lives in plan 02-04.
  Future<void> deleteSupplement() =>
      ref.read(supplementRepoProvider).softDeleteCascade(
            supplementId,
            fromDay: ref.read(todayProvider),
          );
}

/// Per-supplement editor state. autoDispose: screen-scoped per the D-23
/// policy recorded in `core/providers.dart`; family arg = supplementId
/// (Riverpod 3 constructor-arg pattern, P-5).
final regimenEditorProvider = NotifierProvider.autoDispose
    .family<RegimenEditorController, RegimenDraft, String>(
  RegimenEditorController.new,
);
