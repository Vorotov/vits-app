# Phase 4: Planner Views - Pattern Map

**Mapped:** 2026-08-16
**Files analyzed:** 15 (10 new lib files, 1 modified lib file, 2 modified ARB files, 5 new/2 extended test files)
**Analogs found:** 13 / 15 (2 elements have NO local analog — see "No Analog Found")

Source of the file list: `04-RESEARCH.md` — "Architectural Responsibility Map" (lines 79-90), P-2 (line 185, the `planner_` file naming), the system-flow diagram (lines 141-173), "Token Additions" (lines 112-128), "New ARB key inventory" (lines 667-706) and "Wave 0 Gaps" (lines 764-770).

---

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `lib/features/calendar/planner_view_model.dart` (new) | pure view-model / domain projection | transform | `lib/features/calendar/day_view_model.dart` | **exact** |
| `lib/core/domain/cycle_math.dart` (modify: `firstOfMonth`, `addMonths`, `daysInMonth`, `plannerWindow`, promoted `mondayOfWeek`) | domain utility | transform | `lib/core/domain/cycle_math.dart` itself (`dateOnly`/`isActiveOn` house style) | **exact (self)** |
| `lib/features/calendar/planner_providers.dart` (new) | provider / screen state | request-response (derived, cached) | `lib/features/calendar/calendar_providers.dart` + `stackEntriesProvider` in `lib/core/providers.dart` | **exact** |
| `lib/features/calendar/planner_screen.dart` (new) | screen | request-response | `lib/features/calendar/calendar_screen.dart` | **exact** |
| `lib/features/calendar/planner_gantt.dart` (new) | component + CustomPainter | transform (render-only) | `lib/features/calendar/day_progress_ring.dart` | role-match (painter idiom exact; hatch/gridlines are new) |
| `lib/features/calendar/planner_load_chart.dart` (new) | component (bars + selection) | event-driven (tap → selection) | `lib/features/calendar/week_strip.dart` (`_WeekCell` tap/semantics) | role-match |
| `lib/features/calendar/planner_week_detail.dart` (new, inline card) | component | request-response | `lib/features/calendar/calendar_screen.dart` `_EmptyDayState` / `_Disclaimer` (inline scroll-body cards) | role-match |
| `lib/features/calendar/planner_year_grid.dart` (new) | component (grid of cards) | event-driven (tap → month selection) | `lib/features/calendar/week_strip.dart` (`stripHeightFor` computed extent + cell selection) | partial (grid layout has no analog) |
| `lib/features/calendar/planner_month_detail.dart` (new, inline card) | component | request-response | `lib/features/stack/stack_screen.dart` card row (colour bar + name/hint column) | role-match |
| `lib/features/calendar/calendar_screen.dart` (modify: in-tab page swap + header entry affordance) | screen | event-driven | itself (`_Header` TextButton `backToToday`, lines 138-153) | **exact (self)** |
| `lib/core/theme/tokens.dart` (modify: `// --- Phase-4 additions ---`) | config | — | `tokens.dart` Phase-2/Phase-3 banners (lines 76, 107) | **exact** |
| `lib/core/l10n/arb/app_uk.arb` + `app_en.arb` (modify) | config / i18n | — | existing `substancesCount` / `disclaimerEducational` entries | **exact** |
| `test/features/planner_view_model_test.dart` (new) | test (pure matrix) | — | `test/features/day_view_model_test.dart` | **exact** |
| `test/domain/planner_window_test.dart` (new) | test (pure date math) | — | `test/domain/cycle_math_test.dart` | **exact** |
| `test/providers_planner_test.dart` (new) | test (provider + in-memory Drift, row-count gate) | — | `test/providers_calendar_test.dart` | **exact** |
| `test/features/planner_screen_test.dart` (new) | test (widget) | — | `test/features/calendar_screen_test.dart` | **exact** |
| `test/l10n/month_names_test.dart` (new) / `test/l10n/plurals_test.dart` (extend) | test (i18n) | — | `test/l10n/plurals_test.dart` | **exact** |

---

## Pattern Assignments

### `lib/features/calendar/planner_view_model.dart` (pure view-model, transform)

**Analog:** `lib/features/calendar/day_view_model.dart` — copy the header, import set, sealed-type idiom and doc-comment density verbatim.

**Library doc header + the exact three imports** (`day_view_model.dart:1-18`) — this is the template; substitute the plan/pitfall references:
```dart
/// Pure day view-model derivation for the Today/Calendar screen
/// (plan 03-02, P-4, P-5, P-6, PF-6, DECIDED-1/5/6/7).
///
/// Top-level pure functions in the `stack_status.dart` style: `today`,
/// `viewingToday` and `nowMinutes` arrive as explicit parameters and every
/// date comparison goes through [dateOnly] — this file NEVER reads the clock.
/// It imports only the three pure domain libraries: no UI framework, no l10n,
/// no persistence, so no status write is reachable from here (T-03-05) and
/// nothing in it decides whether a day is cycle-active (T-03-06) — the day
/// stream is the single source of that truth.
///
/// No user-visible strings: the renderer switches exhaustively over the
/// sealed [BlockTag] hierarchy and maps each case to an ARB key itself.
library;

import 'package:boostque/core/domain/cycle_math.dart';
import 'package:boostque/core/domain/models.dart';
import 'package:boostque/core/domain/repositories.dart';
```
V-1.4 is satisfied by copying exactly these three imports and nothing else.

**Sealed-hierarchy idiom for `LoadVerdict`** — copy `BlockTag` (`day_view_model.dart:132-163`), including the "renderer switches exhaustively … maps each case to an ARB key" comment and the payload-carrying subclass shape (`ProgressTag` is the model for `OverLimitVerdict(load)`):
```dart
/// Structured block-header tag — the renderer switches exhaustively (sealed,
/// Dart 3) and maps each case to an ARB key and a color pair.
sealed class BlockTag {
  const BlockTag();
}

class AllTakenTag extends BlockTag {
  const AllTakenTag();
}

/// Today's past block that still holds a pending dose (warn treatment).
///
/// [done] counts `taken` doses only; `skipped` is not done.
class ProgressTag extends BlockTag {
  final int done;
  final int total;

  const ProgressTag({required this.done, required this.total});
}
```

**Named-constant + resolver pattern** for `editorialLimit` / `comfortLoad` / `verdictOf` — copy `blockStartsMinutes` + `blockIndexOf` (`day_view_model.dart:20-40`), whose doc explicitly frames itself as "the ONE place a boundary lives … changing a boundary is a one-line, test-caught edit". Same sentence should carry the PLAN-04 editorial framing.

**Data-class shape for `DateRun` / `WeekBucket` / `GanttSegment` / `MonthCell`** — copy `DayBlock` (`day_view_model.dart:47-62`): plain `final` fields, `const` constructor with `required` named params, a doc comment on each field stating what it is NOT (`earliestMinutes` "is the earliest REAL slot time … never the block's boundary value").

**`List.unmodifiable` on returned collections** (`day_view_model.dart:86`) and the `[for (...) ...]` collection-literal build style (`day_view_model.dart:79-88`) — use for `activeRuns`, `ganttSegments`, `weekLoads`, `monthCells`.

**`isActiveOn` is the only activity call** — `lib/core/domain/cycle_math.dart:26-45`; note `if (r.paused) return false;` (line 27) already delivers E-3 and the null-ended course rule (lines 34-36) already delivers PF-11/E-4. Do not re-implement either.

---

### `lib/core/domain/cycle_math.dart` (modification — window helpers + promoted `mondayOfWeek`)

**Analog:** the file itself. Match `dateOnly`'s one-line-function + why-comment form (`cycle_math.dart:11-16`):
```dart
/// Normalizes any [DateTime] to its calendar day as `DateTime.utc(y, m, d)`.
///
/// Uses the y/m/d fields of the input as-is — a local wall-clock value maps
/// to the UTC calendar day with the same date fields, never local midnight
/// (D-13).
DateTime dateOnly(DateTime d) => DateTime.utc(d.year, d.month, d.day);
```

**`mondayOfWeek` is moved verbatim** from `lib/features/calendar/week_strip.dart:83-90`, comment included:
```dart
/// The Monday of [day]'s week, as a date-only UTC value.
///
/// Pure arithmetic on the UTC calendar day — `subtract` on a UTC value can
/// never be bitten by a DST transition (the project's date-only rule).
DateTime mondayOfWeek(DateTime day) {
  final d = dateOnly(day);
  return d.subtract(Duration(days: d.weekday - DateTime.monday));
}
```
`week_strip.dart` then imports it from `cycle_math.dart` (it already imports that library at line 45) and drops its local copy; `weekStartForPage` (line 94) keeps calling it unchanged.

**Exactness comment to reuse** on any `inDays` arithmetic — `cycle_math.dart:41`: `// Exact on UTC date-only values: every day is precisely 24h in UTC.`

---

### `lib/features/calendar/planner_providers.dart` (providers, derived + screen state)

**Analog:** `lib/features/calendar/calendar_providers.dart` (screen-scoped state, autoDispose, D-23 rationale in the library header) plus `stackEntriesProvider` in `lib/core/providers.dart` (derived-from-AsyncValue composition).

**Library header stating the D-23 side** (`calendar_providers.dart:1-8`):
```dart
/// Screen-scoped calendar state (plan 03-01, P-3, D-23).
///
/// autoDispose here is the screen-scoped half of the D-23 dispose policy
/// recorded in `core/providers.dart`: this is Calendar-tab state, not
/// app-lifetime state (the clock itself lives in `core/today_controller.dart`).
library;
```

**Derived-provider composition** — `lib/core/providers.dart:132-144`, the shape `cyclesModelProvider` / `yearModelProvider` copy (note `Provider<AsyncValue<T>>`, not `FutureProvider`):
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

**Read-only / no-materialization precedent to cite in the doc comment** — `lib/core/providers.dart:99-124`, especially lines 104-110, which is the WR-06 sentence the planner's header should echo:
```dart
/// The same day's doses, READ-ONLY: it never calls `ensureLogsForDay`.
///
/// ... each week the pager passed through materialized
/// 7 days × slots of IntakeLog rows, so the database grew with pager travel
/// rather than with user intent — up to ~371 days for a strip the user may
/// never have looked at (WR-06).
///
/// The dot reads exactly the same rows; it just does not create them.
```
The planner goes one step further: it imports **neither** day provider (V-1.2).

**Selection notifier + autoDispose registration** for `selectedWeekProvider` / `selectedMonthProvider` — copy `SelectedDayController` (`calendar_providers.dart:19-39`), including the `null` = "follow today" trick, which is exactly the seeding rule the research demands (P-13, E-14):
```dart
class SelectedDayController extends Notifier<DateTime?> {
  @override
  DateTime? build() => null;

  /// Browses [day] (normalized — every family key must be `dateOnly()`, PF-1).
  void select(DateTime day) => state = dateOnly(day);

  /// Clears the selection back to "follow today".
  void followToday() => state = null;
}

final selectedDayProvider =
    NotifierProvider.autoDispose<SelectedDayController, DateTime?>(
  SelectedDayController.new,
);
```
And the resolver that folds selection over the clock (`calendar_providers.dart:48-50`) — the model for "the selected week, or the week containing today":
```dart
final resolvedDayProvider = Provider.autoDispose<DateTime>(
  (ref) => ref.watch(selectedDayProvider) ?? ref.watch(todayProvider),
);
```

---

### `lib/features/calendar/planner_screen.dart` (screen, request-response)

**Analog:** `lib/features/calendar/calendar_screen.dart`.

**Library header enumerating regions and who owns each** (`calendar_screen.dart:1-27`) — reproduce the same structure list, screen-states list and the "the clock is never read in this file" paragraph:
```dart
/// Calendar tab — the Today screen's permanent frame (UI-SPEC S4).
///
/// Structure, and who owns each region:
/// - fixed header (plan 03-03): title, locale-formatted subtitle, ...
/// - scroll body: the day's doses as chronological time blocks
///   ([DayBlockSection], plan 03-04), closed by the two-sentence disclaimer
///   line (plan 03-03, mockup line 264).
/// ...
/// The clock is never read in this file: the day arrives through
/// [resolvedDayProvider], which follows the app's single clock source
/// `todayProvider` (03-01, IN-06) ...
/// Weekday and month names come from intl `DateFormat` with the ACTIVE locale
/// — never from ARB and never from a hand-built table.
library;
```

**Screen skeleton: fixed header outside the scroll, body in `Expanded`** (`calendar_screen.dart:44-74`):
```dart
const double _screenPadding = 20;

class CalendarScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(day: day, doses: doses),
            const SizedBox(height: BqSpace.md),
            const WeekStrip(),
            Expanded(child: _DayBody(doses: doses, day: day)),
          ],
        ),
      ),
    );
  }
}
```
Planner mapping: `_Header` (title + range subtitle + `BqSegmented`) fixed; the Цикли/Рік body in the `Expanded` `ListView`.

**Locale + intl discipline** (`calendar_screen.dart:92-104`) — the comment on line 92-93 is mandatory boilerplate for the planner's `LLLL` month names:
```dart
// The locale ALWAYS comes from the widget tree, never a literal tag: a
// hardcoded 'uk' would silently ignore the user's language override.
final locale = Localizations.localeOf(context).toString();
...
final subtitle = isToday
    ? DateFormat('EEEE, d MMMM', locale).format(day)
    : DateFormat('d MMMM', locale).format(day);
```
Planner uses `DateFormat('LLLL', locale)` / `DateFormat('LLL', locale)` (PF-4) and `_capitalizeFirst` (`calendar_screen.dart:171-175`) for the peak-month and range labels — that helper already operates on runes, copy it rather than re-inventing:
```dart
String _capitalizeFirst(String value) {
  if (value.isEmpty) return value;
  final first = String.fromCharCode(value.runes.first);
  return first.toUpperCase() + value.substring(first.length);
}
```

**Scroll body padding + AsyncValue handling with NO spinner** (`calendar_screen.dart:241-317`) — copy the `ListView` padding (bottom ≥ 84 clears the nav bar), the `data/loading/error` triple, and the error branch's copy+retry:
```dart
return ListView(
  padding: const EdgeInsetsDirectional.only(
    start: _screenPadding, end: _screenPadding, top: 18, bottom: 84,
  ),
  children: [
    ...widget.doses.when(
      data: (list) => ...,
      loading: () { /* hold last list; NO spinner */ },
      error: (_, _) => <Widget>[
        Text(l10n.dayLoadError, style: const TextStyle(
          fontSize: 13, height: 1.4, color: BqColors.textSecondary)),
        const SizedBox(height: BqSpace.sm),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton(
            onPressed: () => ref.invalidate(dayDosesProvider(widget.day)),
            child: Text(l10n.retry, style: const TextStyle(
              fontSize: 13.5, fontWeight: FontWeight.w600,
              color: BqColors.accent)),
          ),
        ),
      ],
    ),
    const _Disclaimer(),
  ],
);
```

**Disclaimer widget — copy verbatim, swap the ARB key** (`calendar_screen.dart:403-424`). This is the PLAN-04 / V-1.8 pattern; it must be the last child of BOTH the Цикли and Рік bodies:
```dart
/// The two-sentence disclaimer line closing the scroll body (mockup line 264).
class _Disclaimer extends StatelessWidget {
  const _Disclaimer();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(
        top: BqSpace.md, start: BqSpace.xs, end: BqSpace.xs,
      ),
      child: Text(
        context.l10n.calendarDisclaimer,
        style: const TextStyle(
          fontSize: 11.5, fontWeight: FontWeight.w400,
          height: 1.5, color: BqColors.textFaint,
        ),
      ),
    );
  }
}
```

**Empty state** (`calendar_screen.dart:356-399`) — `_EmptyDayState` is the template for the invented `emptyPlannerTitle`/`emptyPlannerBody` (PF-12/E-1), including the "until the stack resolves, assume it has entries" defensive default:
```dart
final hasStack = switch (ref.watch(stackEntriesProvider)) {
  AsyncData(:final value) => value.isNotEmpty,
  // Until the stack resolves, assume it has entries: ...
  _ => true,
};
```

**Header action button** (the invented planner entry affordance, A1) — copy the `backToToday` `TextButton` (`calendar_screen.dart:142-152`):
```dart
TextButton(
  onPressed: () => ref.read(selectedDayProvider.notifier).followToday(),
  child: Text(
    l10n.backToToday,
    style: const TextStyle(fontSize: 13, color: BqColors.accent),
  ),
),
```

**Segmented control** — `lib/core/widgets/bq_segmented.dart:24-39`; use as-is, no subclassing:
```dart
BqSegmented(
  labels: [l10n.plannerSegYear, l10n.plannerSegCycles],
  selectedIndex: index,
  onChanged: (i) => ...,
)
```

---

### `lib/features/calendar/planner_gantt.dart` (component + CustomPainter, render-only)

**Analog:** `lib/features/calendar/day_progress_ring.dart`.

**Painter file header justifying CustomPaint over a Material widget** (`day_progress_ring.dart:1-14`) — the planner's version says the same about hatch fills and gridlines:
```dart
/// M10: the mockup draws this as a CSS `conic-gradient`. It is reproduced here
/// as a hard-edged `CustomPaint` arc rather than through the Material circular
/// progress indicator, whose rounded stroke caps, leading gap and implicit
/// animation all fight the drawn design ...
library;
```

**Named private geometry constants with mockup line refs** (`day_progress_ring.dart:24-32`):
```dart
/// Outer box of the ring (mockup line 210).
const double _ringBox = 46;

/// Track stroke width — 46px outer minus the 36px inner disc (lines 210-211).
const double _ringStroke = 5;
```
Planner equivalents: `_trackHeight = 11`, `_trackRadius = 6`, `_rowGap = 13`, `_barMinPx = 2` (PF-6), each with its mockup line.

**Semantics wrapper over a bare canvas** (`day_progress_ring.dart:56-63`) — mandatory for every gantt row (a painted canvas is invisible to screen readers):
```dart
return Semantics(
  // A bare canvas is invisible to screen readers, so the counts are
  // restated as a localized label (UI-SPEC Layout & i18n Rules).
  label: context.l10n.ringSemantics(taken, total),
  // The counter Text is visual chrome for the same two numbers: without
  // excluding it, the label reads out as "2 з 5 доз прийнято, 2/5".
  excludeSemantics: true,
  child: SizedBox(... CustomPaint(painter: _RingPainter(...)) ...),
);
```

**Painter class + `shouldRepaint` discipline** (`day_progress_ring.dart:84-124`) — note the field doc that states *why* `shouldRepaint` compares nothing else; the planner painter repeats it for `segments`:
```dart
class _RingPainter extends CustomPainter {
  const _RingPainter({required this.fraction});

  /// Progress in 0..1 — the ONLY thing this painter draws from, which is why
  /// the repaint check below compares nothing else (Interaction Contract 9).
  final double fraction;

  @override
  void paint(Canvas canvas, Size size) {
    final track = Paint()
      ..color = BqColors.field
      ..style = PaintingStyle.stroke
      ..strokeWidth = _ringStroke;
    canvas.drawCircle(rect.center, _ringDiameter / 2, track);
    if (fraction <= 0) return;
    ...
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) =>
      oldDelegate.fraction != fraction;
}
```
(The planner's `_GanttRowPainter` skeleton in RESEARCH Code Examples lines 596-646 is already written against this template — carry it in as spec-code.)

**Assert-the-caller-contract idiom** (`day_progress_ring.dart:41-46`) — reuse for "the gantt is never constructed with zero rows" (the empty state is the caller's job):
```dart
const DayProgressRing({super.key, required this.taken, required this.total})
    : assert(
        total > 0,
        'DayProgressRing must not be constructed at total == 0 — the '
        'caller omits it entirely on an empty day (DECIDED-7).',
      );
```

**Per-supplement colour + alpha tint** — `lib/features/stack/stack_screen.dart:232-238`:
```dart
Container(
  width: 4,
  margin: const EdgeInsetsDirectional.only(end: 12),
  decoration: BoxDecoration(
    color: Color(entry.supplement.colorValue).withValues(alpha: 0.85),
    borderRadius: BorderRadius.circular(3),
  ),
),
```
Planner uses `alpha: 0.30` (planned year bars) and `alpha: 0.50` (planned month-row dot) per RESEARCH line 128. `Color(supplement.colorValue)` + `.withValues(alpha:)` is the sanctioned exception to V-1.6, since it is data, not a literal.

---

### `lib/features/calendar/planner_load_chart.dart` (component, event-driven selection)

**Analog:** `lib/features/calendar/week_strip.dart` `_WeekCell` (`week_strip.dart:217-324`).

**Tap target + semantics — the exact WR-02 / Interaction-Contract-8 pattern** (`week_strip.dart:257-273`). Copy the structure AND both comments; this is PF-8's remediation verbatim:
```dart
return MergeSemantics(
  child: Semantics(
    button: true,
    selected: isSelected,
    label: DateFormat.yMMMMEEEEd(locale).format(day),
    excludeSemantics: true,
    // The action lives on THIS node, not on the GestureDetector below it:
    // `excludeSemantics` drops every descendant action, so without this a
    // cell announced itself as a button that VoiceOver / TalkBack could
    // not activate — and day browsing is the screen's primary affordance
    // (WR-02).
    onTap: select,
    child: GestureDetector(
      // The whole padded cell is the tap target — a 4px dot must never
      // define it (Interaction Contract 8).
      behavior: HitTestBehavior.opaque,
      onTap: select,
      child: Container(...),
    ),
  ),
);
```
Planner mapping: the whole 46px-tall week column is the `GestureDetector`, the label is the week range + load, `selected:` is the current week index.

**Selection write goes through the notifier read, not watch** (`week_strip.dart:248-255`):
```dart
void select() {
  final selection = ref.read(selectedDayProvider.notifier);
  if (isToday) {
    selection.followToday();
  } else {
    selection.select(day);
  }
}
```

**Row of flex children with explicit gaps** (`week_strip.dart:196-213`) — the load chart's 18 columns:
```dart
return Row(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    for (var i = 0; i < 7; i++) ...[
      if (i > 0) const SizedBox(width: _cellGap),
      Expanded(child: _WeekCell(...)),
    ],
  ],
);
```

**Bar/dot container styling** (`week_strip.dart:365-370`) — the model for each load bar:
```dart
return Container(
  key: const ValueKey('week-dot'),
  width: 4,
  height: 4,
  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
);
```
Keys of the `ValueKey('...')` form are the established way the widget tests find painted primitives — give every load bar and month card one.

---

### `lib/features/calendar/planner_year_grid.dart` (component, computed extent)

**Analog:** `week_strip.dart:58-78` — the `stripHeightFor` computed-extent pattern is exactly what `mainAxisExtent` must copy (P-11, PF-7):
```dart
/// The part of the strip's height that does NOT follow the text scale:
/// padding 9/10, the 6px and 7px gaps, the 4px dot, the 1px borders, plus the
/// design slack the mockup's 82px carries at scale 1.0.
const double _stripFixedExtent = 48;

/// The text-bearing part of a cell at scale 1.0: the mono 10 dow line plus the
/// 14px day number, with their line boxes.
const double _stripTextExtent = 34;

/// Height reserved for the strip, for [scaler].
///
/// The `PageView` needs a BOUNDED cross-axis extent, so this extent has to be
/// computed rather than measured — and a constant would clip the cells at any
/// accessibility text scale (CR-01 reproduced 7 bottom overflows at 1.6 and at
/// 2.0). Only the two text lines grow with the scaler ...
double stripHeightFor(TextScaler scaler) =>
    _stripFixedExtent + scaler.scale(_stripTextExtent);
```
Planner form: `double monthCardExtentFor(TextScaler scaler, int rowCount)` = fixed part (`9 + N*4 + (N-1)*3 + 19`) + `scaler.scale(headerTextExtent)`; consumed as `MediaQuery.textScalerOf(context)` (`week_strip.dart:141`).

**Pinned line count on short labels at large scales** (`week_strip.dart:286-302`) — apply to the month card's mono label + count row:
```dart
Text(
  DateFormat.E(locale).format(day).toUpperCase(),
  textAlign: TextAlign.center,
  // A 2-3 character weekday abbreviation and a day number are
  // single-line by nature: wrapping one at a large text scale
  // would grow the cell by a whole line and clip the dot
  // (CR-01) ...
  maxLines: 1,
  softWrap: false,
  style: BqText.mono(size: 10, color: labelColor, weight: FontWeight.w400),
),
```

**Selected/unselected cell decoration triple** (`week_strip.dart:240-246`) — directly maps to the month card's selected `#F2F2F7` + 1.6px accent border vs unselected `surfaceAlt` + 1px `cardBorder`:
```dart
final Color fill = isToday ? BqColors.accent : BqColors.surface;
final Color borderColor =
    isToday || isSelected ? BqColors.accent : BqColors.cardBorder;
final double borderWidth = isSelected && !isToday ? 1.5 : 1;
```

---

### `lib/core/theme/tokens.dart` (config)

**Analog:** the Phase-2/Phase-3 banner + doc-comment convention (`tokens.dart:76`, `tokens.dart:107`). Every Phase-4 token gets a banner, a mockup line reference and its rgba source:
```dart
// --- Phase-2 additions (02-UI-SPEC "Token Additions", mockup-sourced) ---

/// 1px border on cards, result rows, panels, slot rows — mockup's
/// `rgba(23,23,27,.09)` (lines 107, 141, 505, 542). Also the segmented
/// control's container fill (same mockup value; see `BqSegmented`).
static const Color cardBorder = Color(0x1717171B);

// --- Phase-3 additions (03-UI-SPEC "Token Additions", mockup-sourced) ---

/// 1.8px border of an unchecked dose circle (pending / overdue / missed) —
/// mockup's `rgba(23,23,27,.22)` (line 730).
static const Color checkBorder = Color(0x3817171B);
```
The nine Phase-4 values are already computed in RESEARCH lines 116-127. Note the deliberate-duplicate-token precedent the research cites (`thresholdDash` == `checkBorder` value): `BqRadii.dayCell` vs `input` (`tokens.dart:143`, `165-167`).

Existing tokens to reuse rather than add: `BqRadii.panel = 16.0` (`tokens.dart:143`), `BqSpace.xs/sm/md/lg` (`tokens.dart:175-183`), `BqText.mono(size:, color:, weight:)` (`lib/core/theme/theme.dart:128-146`, used at `day_progress_ring.dart:73` and `week_strip.dart:297-301`).

---

### `lib/core/l10n/arb/app_uk.arb` + `app_en.arb` (config)

**Analog:** existing entries `lib/core/l10n/arb/app_uk.arb:7-9`:
```json
"disclaimerEducational": "Освітній матеріал, не медична порада.",
"substancesCount": "{count, plural, one{{count} речовина} few{{count} речовини} many{{count} речовин} other{{count} речовини}}",
"weeksCount": "{count, plural, one{{count} тиждень} few{{count} тижні} many{{count} тижнів} other{{count} тижні}}",
```
All four uk CLDR forms on every count key (`cyclesCount`); `@`-descriptions in `app_en.arb` (the pattern at `app_en.arb:175`, `app_en.arb:573`) — including a description recording that `plannerDisclaimer` is editorial framing, not a medical claim. `substancesCount` is pre-formatted and passed as a `{count}` placeholder string into the sentence key (`stackSummary`, `app_uk.arb:10`, is the in-file composition example).

---

### Test files

**`test/features/planner_view_model_test.dart`** — analog `test/features/day_view_model_test.dart:1-16`:
```dart
/// Unit tests for the pure day view-model (plan 03-02, Task 1).
///
/// Pure-function matrix in the cycle_math_test / stack_status_test style: no
/// widgets, no clock — `today`, `viewingToday` and `nowMinutes` are passed
/// explicitly and every date fixture is a UTC date-only value (P-4, P-5, P-6,
/// PF-6, PF-9, DECIDED-1/5/6/7).
///
/// Boundary discipline follows the cycle-math tests: both sides of every time
/// block boundary are asserted explicitly (719/720, 1079/1080, 1319/1320), so
/// moving a boundary is a one-line change that a test catches.
library;

import 'package:boostque/core/domain/models.dart';
import 'package:boostque/core/domain/repositories.dart';
import 'package:boostque/features/calendar/day_view_model.dart';
import 'package:flutter_test/flutter_test.dart';
```
Plus the local fixture-builder-function idiom (`day_view_model_test.dart:19-61`): a `Supplement supplement({...})` and a `DayDose dose({...})` helper with defaults, each documented with the production shape it mimics. Planner needs `Regimen cyclic({onDays, offDays, start, paused})` and `Regimen course({start, end})`. Boundary discipline maps to: verdict at load 3/4 and 5/6, `frac` at 0.84/0.85, run-start on today vs today+1 (P-5).

**`test/domain/planner_window_test.dart`** — analog `test/domain/cycle_math_test.dart` (same directory, same pure style; `dart analyze` treats `core/domain` as build-breaking per CLAUDE.md).

**`test/providers_planner_test.dart`** — analog `test/providers_calendar_test.dart:1-47`, header and container harness verbatim:
```dart
/// Container harness copied from test/providers_test.dart: [dbProvider] is
/// overridden with an in-memory database, so no test touches the on-disk
/// boostque.sqlite file (D-19). Seeding goes through the repository providers
/// read off the SAME container, so production code paths are exercised.
///
/// Riverpod 3 pauses unlistened providers, so every family instance under test
/// is held open with `container.listen(...)` before its emissions are awaited;
/// an unlistened instance never runs its build and never materializes.
library;

setUp(() {
  container = ProviderContainer(
    overrides: [
      dbProvider.overrideWith((ref) {
        final database = BoostqueDb.forTesting(NativeDatabase.memory());
        ref.onDispose(database.close);
        db = database;
        return database;
      }),
    ],
  );
});

tearDown(() => container.dispose());
```
Plus the `keepOpen` / poll-loop pattern (`providers_calendar_test.dart:77-90`) — the planner's providers must be `container.listen`ed before reading, or they never build:
```dart
void keepOpen(DateTime d) {
  final sub = container.listen(dayDosesProvider(d), (_, _) {});
  addTearDown(sub.close);
}

Future<List<DayDose>> waitForDoses(DateTime d, int count) async {
  for (var i = 0; i < 200; i++) {
    final value = container.read(dayDosesProvider(d));
    if (value case AsyncData(value: final doses) when doses.length == count) {
      return doses;
    }
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
```
Raw-row assertions for the WR-06 gate: `test/db/pause_filter_test.dart` is the raw `db.select(db.intakeLogs)` precedent (research's gate skeleton is at 04-RESEARCH.md:651-665).

**`test/features/planner_screen_test.dart`** — analog `test/features/calendar_screen_test.dart`. Copy four harness pieces verbatim:

`makeContainer` with the pinned clock (`calendar_screen_test.dart:78-92`):
```dart
ProviderContainer makeContainer({DateTime? today, int? nowMinutes}) {
  return ProviderContainer(
    overrides: [
      dbProvider.overrideWith((ref) {
        final database = BoostqueDb.forTesting(NativeDatabase.memory());
        ref.onDispose(database.close);
        db = database;
        return database;
      }),
      if (today != null) todayProvider.overrideWith(() => _FixedToday(today)),
      if (nowMinutes != null)
        nowMinutesProvider.overrideWith((ref) => Stream.value(nowMinutes)),
    ],
  );
}
```

`app()` with locale, theme, and text-scaler injection (`calendar_screen_test.dart:98-118`):
```dart
Widget app(
  ProviderContainer container, {
  Locale locale = const Locale('uk'),
  TextScaler textScaler = TextScaler.noScaling,
  Widget home = const CalendarScreen(),
}) {
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: bqTheme(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: textScaler),
        child: child!,
      ),
      home: home,
    ),
  );
}
```

`usePhoneSurface` + `tearDownTree` + `pumpUntil` (`calendar_screen_test.dart:120-150`) — `tearDownTree` must be called **inside every test body**, not in `tearDown`, because of the midnight `Timer`:
```dart
void usePhoneSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> tearDownTree(WidgetTester tester, ProviderContainer container) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(milliseconds: 10));
  container.dispose();
  await tester.pump(const Duration(milliseconds: 10));
  await tester.pump(const Duration(milliseconds: 10));
}
```
Also `SharedPreferences.setMockInitialValues({});` in `setUp` (`calendar_screen_test.dart:64-67`) — `LocaleController` needs it.

Text-scale group (`calendar_screen_test.dart:2696-2780`) — the PF-7 pattern, loop over scales, pump extra frames, assert `takeException()` is null with a release-consequence `reason:`:
```dart
for (final scale in <double>[1.0, 1.6, 2.0]) {
  testWidgets('uk: ... at textScaler $scale (WR-04)', (tester) async {
    usePhoneSurface(tester);
    final container = makeContainer(today: pinnedToday, nowMinutes: 600);
    ...
    await tester.pumpWidget(app(container, textScaler: TextScaler.linear(scale)));
    await pumpUntil(tester, () => ..., 'the block header');
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(tester.takeException(), isNull,
        reason: 'the three header texts must shrink, not overflow, when '
            'the text scale grows them past the row');
    await tearDownTree(tester, container);
  });
}
```

**`test/l10n/month_names_test.dart`** — analog `test/l10n/plurals_test.dart:1-45`; load the delegate with no widget pump and assert exact uk strings:
```dart
setUpAll(() async {
  l10n = await AppLocalizations.delegate.load(const Locale('uk'));
});

test('substancesCount covers all four CLDR forms incl. 11-14 exception', () {
  expect(l10n.substancesCount(1), '1 речовина'); // one
  expect(l10n.substancesCount(2), '2 речовини'); // few
  expect(l10n.substancesCount(5), '5 речовин'); // many
  expect(l10n.substancesCount(11), '11 речовин'); // many (11-14 exception)
  expect(l10n.substancesCount(21), '21 речовина'); // one (i%10=1)
});
```
Extend the same file for `cyclesCount` at 1/2/5/11/21; the new month-name test asserts `DateFormat('LLLL', 'uk').format(DateTime.utc(2026, 8, 1)) == 'серпень'` (nominative) vs `MMMM` → `серпня` (A2).

---

## Shared Patterns

### Library-level doc header on every file
**Source:** every file read this session — `day_view_model.dart:1-14`, `calendar_screen.dart:1-27`, `week_strip.dart:1-39`, `calendar_providers.dart:1-6`, `bq_segmented.dart:1-11`, `providers.dart:1-22`, all four test files.
**Apply to:** all 10 new lib files and all 5 new test files.
**Shape:** one-line purpose + plan/requirement ID, then `## `-headed prose sections explaining *why* the non-obvious choices were made, closed by `library;`. Decisions are recorded where they are enforced ("This file is the single place this policy is recorded; do not re-litigate it per provider." — `providers.dart:10-11`).

### Clock access
**Source:** `lib/core/today_controller.dart` via `todayProvider`; `calendar_screen.dart:22-24`, `week_strip.dart:134`.
**Apply to:** `planner_providers.dart` (the only planner file that may read `todayProvider`); every other planner file receives `today` as a parameter. V-1.5: `DateTime.now()` must not appear in `lib/features/calendar/planner_*.dart`.

### Token-only styling (D-07)
**Source:** `lib/core/theme/tokens.dart`; usage at `week_strip.dart:240-246`, `day_progress_ring.dart:98-109`, `calendar_screen.dart:289-293`.
**Apply to:** every planner widget. Only sanctioned literals are geometry (px/radii) and typography (fontSize/weight), each with a mockup-line comment. `Color(supplement.colorValue).withValues(alpha: …)` is data, not a literal.

### Directional padding + no fixed-width text containers
**Source:** `calendar_screen.dart:114-119, 244-249`, `week_strip.dart:276`, `bq_segmented.dart:22-23` ("Labels size to content: no fixed widths, so long uk labels never overflow").
**Apply to:** every planner widget — `EdgeInsetsDirectional` only, `Flexible`/`Expanded` + `ellipsis` on the gantt row name/hint (PF-7).

### Semantics on tappable, painted or icon-only surfaces
**Source:** `week_strip.dart:257-273` (action on the `Semantics` node, `excludeSemantics: true`), `day_progress_ring.dart:56-63` (label restating a canvas), `bq_segmented.dart:56-64`.
**Apply to:** gantt rows (label only), load-chart week columns (`button: true, selected:, onTap:`), month cards (same), the segmented control (free — `BqSegmented` already does it).

### Riverpod 3 AsyncValue pattern-matching (no `valueOrNull`)
**Source:** `calendar_screen.dart:229-235` (`// Riverpod 3: pattern-match the AsyncValue; there is no valueOrNull.`), `calendar_screen.dart:108-111`, `week_strip.dart:349-352`, `providers_calendar_test.dart:86`.
```dart
final data = switch (doses) {
  AsyncData(:final value) => value,
  _ => null,
};
```
**Apply to:** every planner widget reading `cyclesModelProvider` / `yearModelProvider`.

### Never a spinner, never raw exception text
**Source:** `calendar_screen.dart:256-311`, `week_strip.dart:29-31`.
**Apply to:** both planner segments' loading/error surfaces.

---

## No Analog Found

The planner needs code with no existing precedent in the tree. The planner must carry spec-level code (RESEARCH Code Examples / UI-SPEC) for these, not a "follow the pattern of X" instruction:

| Element | Role | Data Flow | Why no analog |
|---|---|---|---|
| Diagonal 4-on/4-off **hatch fill** inside a clipped RRect (planned gantt segment) | painter | render | The only `CustomPainter` in the repo is `_RingPainter`, which draws a solid arc. No `clipRRect` + repeating-stroke code exists anywhere. **Use the skeleton at 04-RESEARCH.md:596-646 verbatim**; the only thing borrowed from `_RingPainter` is the `shouldRepaint` discipline. |
| **Dashed horizontal threshold line** (4px on / 4px off, `thresholdDash`) | painter | render | No dashed-line painting exists in `lib/`. `BqColors.accentBorder` names a "dashed border" in the mockup but is rendered as a solid border today. Spec-carried code required. |
| **Absolutely positioned gridlines / today marker** over a `Stack` with `LayoutBuilder`-computed pixel offsets | component | render | No `Stack` + `Positioned`-from-fraction layout exists; `week_strip.dart:142-160` uses `Stack` only to park an invisible warmer widget. P-8's `LayoutBuilder` → `Positioned(left: f * width, top: 0, bottom: 0, width: 1)` mapping is new. |
| **12-cell 4×3 `GridView` with computed `mainAxisExtent`** | component | render | The repo has no `GridView` at all (grep: zero hits in `lib/`). The *extent computation* has an analog (`stripHeightFor`, `week_strip.dart:60-78`); the grid delegate itself does not. Follow P-11 (`SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, mainAxisSpacing: 8, crossAxisSpacing: 8, mainAxisExtent: computed)` + `shrinkWrap: true` + `NeverScrollableScrollPhysics`). |
| **In-tab page swap** (Сьогодні ↔ Планувальник inside the Calendar tab, nav bar preserved) | screen navigation | event-driven | `lib/app_shell.dart:38-45` is an `IndexedStack` at the *tab* level; there is no in-tab page enum anywhere. A1/Open Question 1 — invented seam, cheap to reverse. |
| **`RepaintBoundary`** around the gantt card (P-8 performance note) | component | render | Not used anywhere in `lib/`. Trivially additive; no pattern needed. |
| **Slot pips row** (max(5, load) small squares, over-limit ones in risk colour) | component | render | Closest is the 4px `_HandledDot` container (`week_strip.dart:365-370`) for the shape, but the count-driven row with an over-limit branch is new. Transcribe from mockup lines 770-776. |

---

## Metadata

**Analog search scope:** `lib/core/`, `lib/core/domain/`, `lib/core/theme/`, `lib/core/widgets/`, `lib/core/l10n/arb/`, `lib/features/calendar/`, `lib/features/stack/`, `test/`, `test/features/`, `test/domain/`, `test/db/`, `test/l10n/`
**Files scanned:** 14 read in full or in targeted ranges (`day_view_model.dart`, `day_progress_ring.dart`, `week_strip.dart`, `calendar_providers.dart`, `calendar_screen.dart`, `core/providers.dart`, `bq_segmented.dart`, `cycle_math.dart`, `stack_status.dart`, `stack_screen.dart` excerpt, `tokens.dart` excerpts, `app_uk.arb` excerpt, plus 4 test files); directory listings across `lib/features/calendar/` and all `test/` subdirectories
**Pattern extraction date:** 2026-08-16
