# Phase 3: Daily Tracking - Pattern Map

**Mapped:** 2026-08-15
**Files analyzed:** 12 (7 new lib files/edits, 5 new/extended test files)
**Analogs found:** 12 / 12 (every new file has a Phase-1/2 analog — zero greenfield shapes)

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `lib/core/providers.dart` (MODIFY — add `todayProvider`, `dayDosesProvider`, minute ticker) | provider/state | event-driven + streaming | same file, `stackEntriesProvider` / `regimensStreamProvider` (lines 59-88) | exact (in-file) |
| `lib/features/calendar/today_controller.dart` (NEW, or inline in providers.dart) | state (Notifier) | event-driven (timer/lifecycle) | `lib/features/stack/regimen_editor_controller.dart:134-150, 320-340, 413-419` | role-match (Notifier + in-flight/lifecycle discipline) |
| `lib/features/calendar/day_view_model.dart` (NEW — `blockIndexOf`, `groupIntoBlocks`, `isMissed`, `isOverdue`, dose-index) | pure view-model | transform | `lib/features/stack/stack_status.dart` (whole file, 105 lines) | **exact** |
| `lib/features/calendar/calendar_screen.dart` (REWRITE — header, ring, strip, block list) | screen widget | request-response (stream → render) | `lib/features/stack/stack_screen.dart` (whole file, 390 lines) | **exact** |
| `_DoseRow` (in calendar_screen.dart or `dose_row.dart`) | widget + write gesture | CRUD write (setStatus) | `_StackCard` `stack_screen.dart:202-284` (tap target) + `_EditorFooterState` `regimen_editor_screen.dart:801-807` (in-flight guard) | composite exact |
| `_ProgressRing` CustomPaint (NEW) | widget (paint) | transform | `_DashedBorderPainter` `regimen_editor_screen.dart:744-776` | **exact** |
| `_WeekStrip` (NEW) | widget | request-response | `BqSegmented` `lib/core/widgets/bq_segmented.dart:41-97` (Expanded row of tappable cells + Semantics) | role-match |
| chips (`пропущено`, `не прийнято вчасно`, `доза n з m`) | widget | — | `_StatusChip` `stack_screen.dart:289-336` | **exact** |
| `lib/core/l10n/arb/app_uk.arb` + `app_en.arb` (MODIFY — ~14 new keys) | config/i18n | — | same files, `slotsPerDay` line 45 / `stackSummary` line 11 | exact (in-file) |
| `test/features/day_view_model_test.dart` (NEW) | test (pure) | — | `test/features/stack_status_test.dart:1-40` | **exact** |
| `test/db/materialization_boundaries_test.dart` (NEW) | test (repo chain) | — | `test/db/pause_filter_test.dart:1-59` | **exact** |
| `test/providers_calendar_test.dart` (NEW) | test (container) | — | `test/providers_test.dart` (whole file, 87 lines) | **exact** |
| `test/features/calendar_screen_test.dart` (NEW) | test (widget) | — | `test/features/stack_screen_test.dart:32-106` harness + `regimen_editor_test.dart:387-399` double-tap | **exact** |
| `test/l10n/plurals_test.dart` (EXTEND — `ringSemantics`) | test | — | same file, lines 22-57 | exact (in-file) |

---

## Pattern Assignments

### `lib/core/providers.dart` — add `todayProvider` + `dayDosesProvider` (provider/state, streaming)

**Analog:** the same file. Every new provider must follow its existing shape and the D-23 policy doc-comment at the top.

**Library doc-comment + dispose policy** (`providers.dart:1-22`) — new providers must extend this doc, not add a competing policy comment:
```dart
/// Riverpod provider graph for VitoMy (D-22, D-23).
///
/// ## Dispose policy (D-23) — decided once for the whole app, recorded here
///
/// Repository-level providers and StreamProviders in this file are
/// intentionally NOT autoDispose: they are app-lifetime, cheap to keep warm,
/// and shared across all three tabs ...
/// Screen-scoped state in `features/` MAY be autoDispose. This file is the
/// single place this policy is recorded; do not re-litigate it per provider.
library;
```
Consequence: `todayProvider` (shared by Calendar + Stack) is NOT autoDispose and lives here; `dayDosesProvider` family IS autoDispose and its per-provider justification goes in its own doc-comment (one line, referencing D-23 — do not restate the policy).

**StreamProvider shape** (`providers.dart:59-68`):
```dart
/// Active regimens with slots, live from the database (NOT autoDispose
/// per D-23).
final regimensStreamProvider = StreamProvider<List<Regimen>>(
  (ref) => ref.watch(regimenRepoProvider).watchAll(),
);
```

**Composition pattern for derived providers** (`providers.dart:76-88`) — copy this `AsyncValue.when` nesting if the calendar needs a derived combined provider (e.g. day doses + today):
```dart
final stackEntriesProvider = Provider<AsyncValue<List<StackEntry>>>((ref) {
  final supplements = ref.watch(supplementsStreamProvider);
  final regimens = ref.watch(regimensStreamProvider);
  return supplements.when(
    data: (s) => regimens.when(
      data: (r) => AsyncData(combineStackEntries(s, r)),
      loading: () => const AsyncLoading(),
      error: AsyncError.new,
    ),
    loading: () => const AsyncLoading(),
    error: AsyncError.new,
  );
});
```

**Import convention** (`providers.dart:24-29`): relative imports inside `lib/core/` (`import 'db/database.dart' show VitomyDb;`), package-absolute imports everywhere in `lib/features/` (see stack_screen below). Note the `show` clause on the Drift database import — keep Drift symbols narrowed.

---

### `lib/features/calendar/today_controller.dart` — `TodayController` (state, event-driven)

**Analog:** `lib/features/stack/regimen_editor_controller.dart`

**Notifier + constructor-arg family + autoDispose declaration** (lines 1-8, 134-139, 413-419):
```dart
/// Regimen editor draft state + controller (plan 02-03, P-5/PF-8/D-23).
///
/// Screen-scoped state ... built as a Riverpod 3
/// constructor-arg family Notifier (P-5: `FamilyNotifier` is gone in
/// Riverpod 3 — the argument arrives through the constructor and the
/// provider is `NotifierProvider.autoDispose.family`; autoDispose is correct
/// for screen-scoped state per the D-23 policy recorded in
/// `core/providers.dart`).
...
class RegimenEditorController extends Notifier<RegimenDraft> {
  RegimenEditorController(this.supplementId);
  final String supplementId;
...
/// Per-supplement editor state. autoDispose: screen-scoped per the D-23
/// policy recorded in `core/providers.dart`; family arg = supplementId
/// (Riverpod 3 constructor-arg pattern, P-5).
final regimenEditorProvider = NotifierProvider.autoDispose
    .family<RegimenEditorController, RegimenDraft, String>(
  RegimenEditorController.new,
);
```
For `TodayController`: same class shape, **no family arg**, plain `NotifierProvider<TodayController, DateTime>(TodayController.new)`, NOT autoDispose.

**Named-constant convention** (lines 141-157) — the block-boundary const list (P-4) copies this style: `static const` with the mockup line cited in the doc comment:
```dart
  /// Default times (minutes from midnight) walked in order when adding a
  /// slot, skipping already-used times — mockup NEXT_SLOT
  /// `['08:00','13:00','19:00','22:00','10:30','16:00']`.
  static const List<int> nextSlotDefaults = [480, 780, 1140, 1320, 630, 960];
```

**Single-flight / in-flight future pattern** (lines 323-340) — reuse verbatim shape for any async guard in the controller (and it is the state-layer twin of the row `_busy` guard):
```dart
  /// In-flight save future — see [save]'s single-flight contract (CR-01).
  Future<void>? _saveInFlight;

  Future<void> save() =>
      _saveInFlight ??= _doSave().whenComplete(() => _saveInFlight = null);
```

**Clock-read boundary** (line 406-410) — precedent that the feature layer MAY read the clock, always through `dateOnly`:
```dart
  Future<void> deleteSupplement() =>
      ref.read(supplementRepoProvider).softDeleteCascade(
            supplementId,
            fromDay: dateOnly(DateTime.now()),
          );
```
`TodayController` is the new *centralized* version of this read; `ref.onDispose` for the `Timer`/`AppLifecycleListener` mirrors `dbProvider`'s `ref.onDispose(db.close)` (`providers.dart:35-39`).

---

### `lib/features/calendar/day_view_model.dart` (pure view-model, transform)

**Analog:** `lib/features/stack/stack_status.dart` — copy this file's entire shape.

**File header contract** (lines 1-18) — the exact template for the new file's doc comment:
```dart
/// Pure status + schedule-summary derivation for stack cards
/// (plan 02-03, P-4, E-4/D10, E-7).
///
/// Top-level pure functions in the `combineStackEntries` style: `today` is
/// passed explicitly and every date comparison goes through [dateOnly] —
/// this file NEVER reads the clock. No Flutter imports, no user-visible
/// strings: the wave-4 card renderer switches exhaustively over the sealed
/// [ScheduleSummary] hierarchy and maps to ARB keys itself.
library;

import 'package:vitomy/core/domain/cycle_math.dart';
import 'package:vitomy/core/domain/models.dart';
import 'package:vitomy/core/domain/repositories.dart';
```
Note the three imports: no `flutter/material.dart`, no l10n, no Drift. `day_view_model.dart` must have exactly this import set.

**Clockless pure function taking `today` explicitly** (lines 27-46) — `isMissed`/`isOverdue` copy this signature and `dateOnly()`-normalization discipline:
```dart
/// Derives the card status for [e] on the calendar day of [today].
///
/// [today] is normalized via [dateOnly]; the widget layer reads the clock
/// and passes the normalized current day in — this file never does.
StackStatus statusOf(StackEntry e, DateTime today) {
  final r = e.regimen;
  if (r == null) return StackStatus.fresh;
  if (r.paused) return StackStatus.paused;

  final day = dateOnly(today);
  if (day.isBefore(dateOnly(r.startDate))) return StackStatus.planned;
  ...
}
```

**Sealed-hierarchy + exhaustive-switch result type** (lines 50-84, 90-105) — the model for a `DayBlock`/`DoseView` result type carrying data but NO strings:
```dart
/// Structured schedule summary for a stack card — the wave-4 renderer
/// switches exhaustively (sealed, Dart 3) and formats via ARB/ICU keys.
sealed class ScheduleSummary {
  const ScheduleSummary();
}

class CyclicSummary extends ScheduleSummary {
  final int onDays;
  final int offDays;
  final int slotCount;
  const CyclicSummary({required this.onDays, required this.offDays, required this.slotCount});
}
...
ScheduleSummary scheduleSummaryOf(StackEntry e) {
  final r = e.regimen;
  if (r == null) return const NoSummary();
  return switch (r.kind) { ... };
}
```
Apply: `DayBlock` carries `blockIndex`, `earliestMinutes`, `List<DoseView>`; the *renderer* maps `blockIndex` → `l10n.blockMorning` etc. Never a label string in this file.

---

### `lib/features/calendar/calendar_screen.dart` (screen widget, stream → render)

**Analog:** `lib/features/stack/stack_screen.dart`

**Header doc-comment enumerating the UI-SPEC contract + clock note** (lines 1-19) — mandatory convention; the calendar screen's header must enumerate its own states the same way:
```dart
/// Stack tab — full S1 contract (plan 02-05; tracer slice was plan 02-01).
///
/// Renders the complete card anatomy from [stackEntriesProvider]: ...
/// - empty: `emptyStackTitle`/`emptyStackBody` below the still-visible CTA ...
/// - loading: header + CTA with an empty list area, NO spinner (#2)
/// - error: `stackLoadError` + retry (provider invalidate) — raw exception
///   text is never user-visible (#3, threat T-02-08)
///
/// Card tap pushes [RegimenEditorScreen] (STACK-04 edit path). The clock is
/// read HERE (widget layer) and passed into the pure `statusOf` as
/// `dateOnly(DateTime.now())` — domain helpers never read the clock.
library;
```
**Phase-3 delta:** the clock sentence changes — the calendar reads `ref.watch(todayProvider)` instead, and `stack_screen.dart:43` (`final today = dateOnly(DateTime.now());`) is edited to `final today = ref.watch(todayProvider);` (closes IN-06).

**Imports — package-absolute, alphabetized, flutter/riverpod/intl first** (lines 21-33):
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:vitomy/core/domain/cycle_math.dart';
import 'package:vitomy/core/domain/repositories.dart';
import 'package:vitomy/core/l10n/l10n.dart';
import 'package:vitomy/core/providers.dart';
import 'package:vitomy/core/theme/theme.dart';
import 'package:vitomy/core/theme/tokens.dart';
import 'package:vitomy/features/stack/stack_status.dart';
```

**ConsumerWidget + screen scaffold/padding** (lines 36-56) — 20px horizontal, bottom 84 for nav-bar clearance:
```dart
class StackScreen extends ConsumerWidget {
  const StackScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(stackEntriesProvider);
    final l10n = context.l10n;
    final today = dateOnly(DateTime.now());
    return Scaffold(
      body: SafeArea(
        child: ListView(
          // 20px horizontal padding is the UI-SPEC mockup-exact override for
          // screen bodies; bottom >= 84px clears the nav bar (UI-SPEC #4).
          padding: const EdgeInsetsDirectional.only(
            start: 20, end: 20, top: BqSpace.lg, bottom: 84,
          ),
          children: [
            Text(l10n.stackTitle, style: Theme.of(context).textTheme.headlineSmall),
```

**AsyncValue three-state rendering — no spinner, no raw exception text** (lines 101-155) — the calendar's day list copies this exactly (`calendarLoadError` + `retry` invalidating `dayDosesProvider(day)`):
```dart
            ...entries.when(
              data: (list) => list.isEmpty
                  ? const <Widget>[_EmptyStackState()]
                  : <Widget>[ ... ],
              // Loading: empty list area, NO spinner — the local-DB stream
              // resolves within a frame; a spinner would flash (#2).
              loading: () => const <Widget>[],
              // Error: documented copy + retry only — never exception text
              // (#3, T-02-08).
              error: (_, _) => <Widget>[
                Text(l10n.stackLoadError, style: ...),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton(
                    onPressed: () {
                      ref.invalidate(supplementsStreamProvider);
                      ref.invalidate(regimensStreamProvider);
                    },
                    child: Text(l10n.retry, ...),
                  ),
                ),
              ],
            ),
```

**Interleaved-gap list idiom** (lines 117-120) — reuse for dose rows inside a block:
```dart
                      for (final (i, entry) in list.indexed) ...[
                        if (i > 0) const SizedBox(height: 9),
                        _StackCard(entry: entry, today: today),
                      ],
```

**Empty-state widget** (lines 165-198) — `_EmptyDayState` copies this verbatim (title 15/w600/ink, body 13/1.4/textMuted, `BqSpace.xs` gap).

**Tappable card container** (lines 211-238) — the dose-row tap target copies `GestureDetector(behavior: HitTestBehavior.opaque)` + token-only decoration:
```dart
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.of(context).push(...),
      child: Container(
        padding: const EdgeInsetsDirectional.all(14),
        decoration: BoxDecoration(
          color: BqColors.surface,
          border: Border.all(color: BqColors.cardBorder),
          borderRadius: BorderRadius.circular(BqRadii.card),
        ),
```

**Chip widget — the exact template for `пропущено` / `не прийнято вчасно` / `доза n з m`** (lines 286-336):
```dart
/// Status chip (P-4 table verbatim + D10): mono 10.5/w500, radius
/// `BqRadii.chip`, padding 5/7. Semantic status colors are NOT accent
/// budget: АКТИВНА uses calm/calmBg, ПАУЗА textSecondary/chip.
class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final StackStatus status;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final (String label, Color fg, Color bg) = switch (status) {
      StackStatus.active => (l10n.statusActive, BqColors.calm, BqColors.calmBg),
      StackStatus.paused => (l10n.statusPaused, BqColors.textSecondary, BqColors.chip),
      ...
    };
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(vertical: 5, horizontal: 7),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(BqRadii.chip)),
      child: Text(label, style: BqText.mono(size: 10.5, color: fg, letterSpacing: 0.3)),
    );
  }
}
```
Note the record-destructuring `switch` returning `(label, fg, bg)` — copy this for the missed/overdue/taken/skipped chip variants. The neutral "missed" palette (`textSecondary` on `chip`) is literally the ПАУЗА arm above.

**Chips live in a `Wrap`** (lines 266-274) — dose-row chip stacks must too (`spacing: 6, runSpacing: 6`), never a fixed-width Row.

**Locale date formatting via intl, never hand-built** (lines 380-388) — the header's `DateFormat('EEEE, d MMMM')` copies this locale-sourcing:
```dart
  static String _courseRange(BuildContext context, DateTime start, DateTime? end) {
    final fmt = DateFormat.yMd(Localizations.localeOf(context).toString());
    ...
  }
```

---

### `_ProgressRing` — `CustomPaint` (widget, paint)

**Analog:** `_DashedBorderPainter`, `lib/features/stack/regimen_editor_screen.dart:744-776`

**Painter shape — const ctor, token color field, `shouldRepaint` comparing only the inputs** (lines 743-776):
```dart
/// 1px dashed rounded-rect border (mockup line 549).
class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    ...
  }

  @override
  bool shouldRepaint(_DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color;
}
```
Apply: `_RingPainter({required this.pct})`, `shouldRepaint => oldDelegate.pct != pct`, `Paint()..style = PaintingStyle.stroke..strokeWidth = 5..strokeCap = StrokeCap.butt`, `canvas.drawArc(...)`.

**Semantics wrapper on a painted/gesture widget** (lines 712-720) — a bare CustomPaint is invisible to screen readers; copy this wrapping:
```dart
    return Semantics(
      button: true,
      enabled: canAdd,
      child: GestureDetector(
        onTap: canAdd ? controller.addSlot : null,
        child: CustomPaint(
          painter: _DashedBorderPainter(
            color: canAdd ? BqColors.accentBorder : BqColors.hairline,
          ),
```
Ring version: `Semantics(label: l10n.ringSemantics(taken, total), child: CustomPaint(...))`.

---

### `_WeekStrip` (widget, 7 tappable cells)

**Analog:** `lib/core/widgets/bq_segmented.dart:41-97`

**Expanded row of tap cells with per-cell Semantics + selection styling** (lines 52-93):
```dart
      child: Row(
        children: [
          for (int i = 0; i < labels.length; i++)
            Expanded(
              child: MergeSemantics(
                child: Semantics(
                  selected: i == selectedIndex,
                  button: true,
                  label: labels[i],
                  excludeSemantics: true,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onChanged(i),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      decoration: BoxDecoration(
                        color: i == selectedIndex ? BqColors.surface : Colors.transparent,
                        borderRadius: const BorderRadius.all(Radius.circular(BqRadii.segInner)),
                      ),
```
Apply: 7 `Expanded` cells, `selected: day == resolvedDay`, `onTap: () => ref.read(selectedDayProvider.notifier).select(day)`, accent fill for today per P-9. Day labels come from `DateFormat.E`/`.d`, not from a `labels` list of hardcoded strings.

**Token-reuse comment convention** (lines 44-46) — when the mockup's rgba value equals an existing token, say so in a comment rather than adding a hex literal:
```dart
      // The mockup's segmented container fill is rgba(23,23,27,.09) — the
      // same value as the `cardBorder` token (02-UI-SPEC Token Additions);
      // that token is intentionally reused here as the container fill.
```
(If `warnBorder = Color(0x66B07A22)` really is new, add it to `tokens.dart` with the same mockup-line citation style, never inline in feature code.)

---

### `_DoseRow` — mark taken/skipped/undo (widget + CRUD write)

**Analog (gesture guard):** `_EditorFooterState`, `regimen_editor_screen.dart:801-807`
```dart
class _EditorFooterState extends State<_EditorFooter> {
  /// In-flight save guard (CR-01): while a save runs, the button is
  /// disabled AND [_save] short-circuits re-entry, so a double tap can
  /// neither race two `save()` calls (PF-8 ghost-regimen threat T-02-05)
  /// nor run `Navigator.maybePop` twice under the exit transition.
  bool _saving = false;
```
Apply: `_DoseRow` is a `StatefulWidget` with `bool _busy = false`; both `onTap` and `onLongPress` short-circuit while `_busy`, set it in `setState` before the await and clear it in `whenComplete`/`finally`. `next` is computed from `widget.dose.status` at gesture time (PF-4).

**Write call shape:** `ref.read(intakeRepoProvider).setStatus(logId, next)` — mirrors `ref.read(regimenRepoProvider)` / `ref.read(supplementRepoProvider)` in the controller (`regimen_editor_controller.dart:343, 407`). Never `ref.watch` for a write.

---

### ARB files — `lib/core/l10n/arb/app_uk.arb` + `app_en.arb`

**Analog:** the same files.

**Flat key/value, ICU plural with all four uk forms** (`app_uk.arb:8-11, 45`):
```json
  "substancesCount": "{count, plural, one{{count} речовина} few{{count} речовини} many{{count} речовин} other{{count} речовини}}",
  "weeksCount": "{count, plural, one{{count} тиждень} few{{count} тижні} many{{count} тижнів} other{{count} тижні}}",
  "stackSummary": "{total, plural, one{{total} добавка} few{{total} добавки} many{{total} добавок} other{{total} добавки}} · {active, plural, one{{active} активна} few{{active} активні} many{{active} активних} other{{active} активні}}",
  "slotsPerDay": "{count, plural, one{{count} раз на день} few{{count} рази на день} many{{count} разів на день} other{{count} разу на день}}",
```
Non-count keys are plain strings with `{placeholder}` interpolation (`app_uk.arb:47, 56`):
```json
  "removeSlot": "Видалити слот {time}",
  "saveHintActive": "Слоти з'являться в календарі з {start}. Пауза прибирає їх, не видаляючи налаштувань.",
```
Note: `stackSummary` proves *two* independently-declined placeholders in one key — the model for `ringSemantics("{taken} з {total} прийнято")`. `blockProgress` ("{done} з {total}", bare numerals) needs no plural block. Both ARB files change in the same commit (PF-8).

---

## Shared Patterns

### Clock-read boundary (applies to: `today_controller.dart`, `calendar_screen.dart`, `stack_screen.dart` edit)
**Source:** `stack_screen.dart:16-18` + `stack_status.dart:1-8`
```dart
/// The clock is read HERE (widget layer) and passed into the pure `statusOf` as
/// `dateOnly(DateTime.now())` — domain helpers never read the clock.
```
Phase 3 centralizes it: the ONLY `DateTime.now()` in the calendar feature is inside `TodayController` (+ the minute ticker). Every pure helper takes `today`/`nowMinutes` as parameters.

### Date normalization (applies to: every provider family key, every helper)
**Source:** `stack_status.dart:36-42`, `regimen_editor_controller.dart:381-384, 409`
```dart
  final day = dateOnly(today);
  if (day.isBefore(dateOnly(r.startDate))) return StackStatus.planned;
```
Every `DateTime` crossing a boundary passes through `dateOnly()` from `core/domain/cycle_math.dart`. `dayDosesProvider` adds `assert(day == dateOnly(day))` as the backstop (PF-1).

### In-flight guard on any user-triggered write (applies to: dose rows, any calendar CTA)
**Source:** `regimen_editor_controller.dart:323-340` (future-sharing) and `regimen_editor_screen.dart:801-806` (widget bool)
Two flavors — share the future in state-layer controllers; use a `bool _busy` in stateful row/button widgets. Both cite CR-01.

### Token-only styling (applies to: every calendar widget)
**Source:** `stack_screen.dart:72-77, 219-238, 321-334`, `bq_segmented.dart:44-50`
No hex literals in `features/`. Colors from `BqColors.*`, radii from `BqRadii.*`, spacing from `BqSpace.*` (with mockup-exact numeric overrides allowed inline *with a citing comment*, e.g. `padding: ... start: 20` / `bottom: 84`). Mono numerals via `BqText.mono(size:, color:, letterSpacing:)`.

### Localization access (applies to: every widget)
**Source:** `stack_screen.dart:42` / `regimen_editor_screen.dart:727`
```dart
    final l10n = context.l10n;              // from package:vitomy/core/l10n/l10n.dart
    ... Text(l10n.addTimeSlot, ...)
```
Zero string literals in widget code except separators (`' · '`, `' – '`) — see `stack_screen.dart:350-357` for the sanctioned separator-only exception.

### Repository access (applies to: providers + controllers)
**Source:** `providers.dart:41-57` + `regimen_editor_controller.dart:343`
Features touch `SupplementRepository`/`RegimenRepository`/`IntakeRepository` via `ref.read/watch(*RepoProvider)` only; no Drift import in `lib/features/` anywhere (verify at review).

---

## Shared Test Patterns

### In-memory DB behind the provider graph (applies to: `providers_calendar_test.dart`, `calendar_screen_test.dart`)
**Source:** `test/providers_test.dart:18-30` and `test/features/stack_screen_test.dart:48-62`
```dart
    container = ProviderContainer(
      overrides: [
        dbProvider.overrideWith((ref) {
          final db = VitomyDb.forTesting(NativeDatabase.memory());
          ref.onDispose(db.close);
          return db;
        }),
      ],
    );
    // Keep the stack graph warm (Riverpod 3 pauses unlistened providers).
    final sub = container.listen(stackEntriesProvider, (_, _) {});
    addTearDown(sub.close);
```
**Critical for Phase 3:** Riverpod 3 pauses unlistened providers — a `dayDosesProvider(day)` that is never listened to will never run `ensureLogsForDay`. Every provider test must `container.listen(dayDosesProvider(day), (_, _) {})`.

### Async-emission polling helper (applies to: all stream-backed tests)
**Source:** `providers_test.dart:32-43` (value flavor) and `stack_screen_test.dart:98-106` (widget flavor)
```dart
  Future<List<StackEntry>> waitForEntries(int count) async {
    for (var i = 0; i < 200; i++) {
      final value = container.read(stackEntriesProvider);
      if (value case AsyncData(value: final data) when data.length == count) return data;
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    fail('stackEntriesProvider never reached $count entries');
  }
```
```dart
  Future<void> pumpUntilFound(WidgetTester tester, Finder finder) async {
    for (var i = 0; i < 200; i++) {
      await tester.pump(const Duration(milliseconds: 10));
      if (finder.evaluate().isNotEmpty) return;
    }
    fail('Timed out waiting for $finder');
  }
```
Never `pumpAndSettle` — the calendar's minute ticker (`Stream.periodic`) makes the tree never settle. Use `pump(Duration)` loops only.

### Widget-test app harness + phone surface + explicit teardown (applies to: `calendar_screen_test.dart`)
**Source:** `stack_screen_test.dart:41-96`
```dart
  setUp(() {
    // LocaleController loads its persisted override from SharedPreferences.
    SharedPreferences.setMockInitialValues({});
  });

  Widget app(ProviderContainer container) => UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      locale: const Locale('uk'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: bqTheme(),
      home: const StackScreen(),
    ),
  );

  void usePhoneSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  /// Tears the tree down inside the test body so Drift's stream-close
  /// zero-duration timers fire before flutter_test's pending-timer check.
  Future<void> tearDownTree(WidgetTester tester, ProviderContainer container) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 10));
    container.dispose();
    await tester.pump(const Duration(milliseconds: 10));
    await tester.pump(const Duration(milliseconds: 10));
  }
```
`tearDownTree` matters doubly this phase: the midnight `Timer` and the minute ticker are both pending timers that will fail the test otherwise — cancel via `container.dispose()` inside the body.

### Double-activation widget test (applies to: TRACK-02 row gestures)
**Source:** `test/features/regimen_editor_test.dart:386-399`
```dart
      // Two taps with NO pump in between — both hit the still-built button;
      // the in-flight guard must swallow the second.
      final save = find.text('Додати й запустити цикл');
      await tester.tap(save);
      await tester.tap(save);
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(regimens, hasLength(1),
          reason: 'the double tap must not create a ghost regimen (PF-8)');
```
Apply: two `tester.tap` on a dose row with no pump between; assert the final `status == taken` (not flipped back).

### Raw-row assertion via direct repositories (applies to: `materialization_boundaries_test.dart`, missed-stays-pending assert)
**Source:** `test/db/pause_filter_test.dart:1-59`
```dart
/// Proves pause is a pure query-level filter in `watchDay`: pausing hides a
/// regimen's PENDING doses without mutating a single IntakeLog row (raw
/// zero-stamp assertion) ...
library;

import 'package:vitomy/core/db/database.dart' show VitomyDb, IntakeLogsCompanion;
import 'package:vitomy/core/db/drift_repositories.dart';
...
  setUp(() {
    db = VitomyDb.forTesting(NativeDatabase.memory());
    supps = DriftSupplementRepository(db);
    regs = DriftRegimenRepository(db);
    intake = DriftIntakeRepository(db);
  });
  tearDown(() => db.close());
```
This is the ONLY sanctioned place Drift types are imported outside `lib/core/db/` — `test/db/*` only. Reuse its `s1` / `r1()` fixtures for the pause-interplay view-model tests (PF-9).

### Pure-function unit test (applies to: `day_view_model_test.dart`)
**Source:** `test/features/stack_status_test.dart:1-40`
```dart
/// Unit tests for statusOf + scheduleSummaryOf (plan 02-03, Task 2).
///
/// Pure-function matrix in the cycle_math_test style: no widgets, no clock —
/// `today` passed explicitly, all fixtures UTC date-only (P-4, E-4/D10, E-7).
/// Boundary cases follow the 11-14 discipline: today == startDate is active
/// (not planned), today == endDate is active (inclusive end), and
/// today == endDate + 1 day is finished.
library;
...
  Regimen regimen({ RegimenKind kind = RegimenKind.cyclic, DateTime? startDate, ... }) => Regimen(...);
```
Note the named-optional fixture-builder function — copy for `DayDose` fixtures. Boundary discipline applies directly to block boundaries (719/720, 1079/1080, 1319/1320).

### Plural test extension (applies to: `ringSemantics`)
**Source:** `test/l10n/plurals_test.dart:18-29`
```dart
    setUpAll(() async {
      l10n = await AppLocalizations.delegate.load(const Locale('uk'));
    });

    test('substancesCount covers all four CLDR forms incl. 11-14 exception', () {
      expect(l10n.substancesCount(1), '1 речовина');  // one
      expect(l10n.substancesCount(2), '2 речовини');  // few
      expect(l10n.substancesCount(5), '5 речовин');   // many
      expect(l10n.substancesCount(11), '11 речовин'); // many (11-14 exception)
      expect(l10n.substancesCount(21), '21 речовина');// one (i%10=1)
    });
```
Every new count key gets one uk test (1/2/5/11/21) and one en test (1/2/21) in the corresponding group.

---

## No Analog Found

| File / element | Role | Data Flow | Reason |
|----------------|------|-----------|--------|
| `AppLifecycleListener` usage inside `TodayController` | state | event-driven | No lifecycle observer exists anywhere in the codebase. Follow the RESEARCH P-1 snippet + api.flutter.dev; the `ref.onDispose(db.close)` idiom (`providers.dart:37`) is the only local precedent for disposal. |
| Minute-ticker `StreamProvider` (`Stream.periodic`) | provider | streaming | All existing StreamProviders wrap a Drift stream; no timer-driven provider exists. Nearest shape is `regimensStreamProvider` (`providers.dart:66-68`); dispose discipline from D-23 (autoDispose, calendar-scoped). |
| `StreamProvider.autoDispose.family` with an `async*` body | provider | streaming | No async-generator provider exists (all are one-line `ref.watch(repo).watchX()`). Family-with-arg precedent is `NotifierProvider.autoDispose.family` (`regimen_editor_controller.dart:416-419`); combine the two shapes. |

## Metadata

**Analog search scope:** `lib/core/`, `lib/features/stack/`, `lib/features/calendar/`, `lib/core/widgets/`, `lib/core/l10n/arb/`, `test/` (all)
**Files scanned:** 41 Dart files listed; 11 read for excerpts (providers.dart, stack_screen.dart, stack_status.dart, regimen_editor_controller.dart, regimen_editor_screen.dart §700-820, calendar_screen.dart, bq_segmented.dart, providers_test.dart, stack_screen_test.dart §1-106, pause_filter_test.dart §1-59, plurals_test.dart, stack_status_test.dart §1-40, app_uk.arb)
**Pattern extraction date:** 2026-08-15
