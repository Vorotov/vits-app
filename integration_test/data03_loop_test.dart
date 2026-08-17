/// DATA-03 on-device regression test: the full plan → see → mark-taken loop,
/// driven against the REAL app on a real iOS/Android device or simulator.
///
/// Run it with (iOS simulator example):
///
/// ```
/// flutter test integration_test/data03_loop_test.dart -d <device-id>
/// ```
///
/// It boots `package:boostque/main.dart` unchanged — the on-device SQLite file
/// behind `dbProvider`, the real Drift streams, the real Riverpod graph — and
/// walks the loop a user walks: add a supplement, schedule a two-slot cyclic
/// regimen, see today's doses grouped into time blocks, mark one taken, skip
/// another, undo, restart the app tree and confirm the marks survived, then
/// browse a past day.
///
/// ## It runs against the user's real database
///
/// Nothing here deletes or edits pre-existing rows. Every supplement it creates
/// is named with the [_namePrefix] plus the first free index, so a rerun never
/// collides with the previous run's data, and every assertion is scoped to that
/// name or expressed as a DELTA against the counts observed at the start
/// (the day-progress ring in particular — other supplements may contribute
/// doses to the same day).
///
/// ## Screenshots
///
/// The test process runs ON the device, where `Process.run` is forbidden
/// ("Starting new processes is not supported on iOS"), and
/// `binding.takeScreenshot` requires the `flutter drive` harness. So
/// [_screenshot] drops a request file into the app's documents directory —
/// host-visible for a simulator — and waits briefly for a host-side watcher to
/// consume it. Start `tool/data03_screenshot_watcher.sh <device-id>` in another
/// shell before the run to collect the PNGs (it also dumps the on-device SQLite
/// file at the marked-doses step, which is out-of-process proof that the marks
/// really landed on disk). With no watcher running the test still passes; it
/// just waits [_screenshotWait] per shot and moves on.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:boostque/core/domain/cycle_math.dart' show dateOnly;
import 'package:boostque/core/domain/models.dart';
import 'package:boostque/core/domain/repositories.dart';
import 'package:boostque/core/providers.dart';
import 'package:boostque/core/today_controller.dart';
import 'package:boostque/core/widgets/bq_nav_bar.dart';
import 'package:boostque/features/calendar/calendar_screen.dart';
import 'package:boostque/features/calendar/day_progress_ring.dart';
import 'package:boostque/features/calendar/dose_row.dart';
import 'package:boostque/features/stack/regimen_editor_screen.dart';
import 'package:boostque/features/stack/stack_screen.dart';
import 'package:boostque/main.dart' show BoostqueApp;

/// Prefix every supplement this test creates carries.
const String _namePrefix = 'DATA-03 Тест';

/// How long [_screenshot] waits for a host watcher before giving up.
const Duration _screenshotWait = Duration(seconds: 6);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'DATA-03: plan -> see -> mark taken, on device, against the real DB',
    (tester) async {
      // ---------------------------------------------------------------
      // (a) launch -> three-tab shell, Stack tab
      // ---------------------------------------------------------------
      // Since plan 05-01 LocaleController seeds itself synchronously from
      // sharedPreferencesProvider, which throws unless overridden — exactly
      // what main() does before runApp. On device this is the REAL store, not
      // a mock: this test runs against the user's real app state.
      final prefs = await SharedPreferences.getInstance();
      ProviderScope bootScope() => ProviderScope(
            overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
            child: const BoostqueApp(),
          );

      await tester.pumpWidget(bootScope());
      await _pump(tester, 20);

      expect(find.byType(BqNavBar), findsOneWidget, reason: 'app shell');
      expect(find.byType(StackScreen), findsOneWidget);
      expect(find.text('Стек'), findsOneWidget);
      expect(find.text('Календар'), findsOneWidget);
      expect(find.text('Налаштування'), findsOneWidget);
      expect(find.text('Мій стек'), findsOneWidget, reason: 'Stack tab shown');

      final container = ProviderScope.containerOf(
        tester.element(find.byType(BoostqueApp)),
        listen: false,
      );
      final today = container.read(todayProvider);

      // The real, on-device stack as it stands BEFORE this run.
      final existing = await _stack(tester, container);
      debugPrint('DATA-03: stack already holds ${existing.length} supplement(s)');

      if (existing.isEmpty) {
        // Genuine first-run empty state.
        expect(find.text('Стек порожній'), findsOneWidget);
        expect(
          find.text('Додайте першу добавку — з каталогу або вручну.'),
          findsOneWidget,
        );
        debugPrint('DATA-03 step a: empty state asserted');
      } else {
        // Populated device DB (a rerun, or the user's own data): the empty
        // state must NOT be claimed, and the list header must be there.
        expect(find.text('Стек порожній'), findsNothing);
        expect(find.text('ДОБАВКИ'), findsOneWidget);
        debugPrint('DATA-03 step a: populated stack asserted (no empty state)');
      }

      // First free name — derived from the existing stack, never random.
      var index = existing.length;
      String name() => '$_namePrefix $index';
      while (existing.any((e) => e.supplement.name == name())) {
        index++;
      }
      final supplementName = name();
      expect(find.text(supplementName), findsNothing);
      debugPrint('DATA-03: this run uses "$supplementName"');

      // ---------------------------------------------------------------
      // (b) add a supplement manually
      // ---------------------------------------------------------------
      await _tap(tester, find.widgetWithText(FilledButton, 'Додати добавку'));
      await _pump(tester, 10);
      expect(find.byType(BottomSheet), findsOneWidget, reason: 'add sheet');
      expect(find.text('Пошук у базі'), findsOneWidget);

      await _tap(tester, find.text('Вручну'));
      await _pump(tester, 6);

      final sheetFields = find.descendant(
        of: find.byType(BottomSheet),
        matching: find.byType(TextField),
      );
      expect(sheetFields, findsNWidgets(2), reason: 'name + dose fields');
      await tester.enterText(sheetFields.at(0), supplementName);
      await _pump(tester, 4);
      await tester.enterText(sheetFields.at(1), '500 мг · капсули');
      await _pump(tester, 4);

      await _tap(
        tester,
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.widgetWithText(FilledButton, 'Додати добавку'),
        ),
      );
      await _pumpUntil(
        tester,
        () => find.byType(RegimenEditorScreen).evaluate().isNotEmpty,
        'the regimen editor to open after the manual save',
      );
      debugPrint('DATA-03 step b: supplement created, editor opened');

      // ---------------------------------------------------------------
      // (c) configure a cyclic regimen with TWO time slots
      // ---------------------------------------------------------------
      expect(find.text('Розклад прийому'), findsOneWidget);
      expect(find.text('ПЕРІОДИЧНІСТЬ'), findsOneWidget);
      expect(find.text('Циклічно'), findsOneWidget);
      // Documented defaults: cyclic, start today, 56/28, one 08:00 slot.
      expect(find.text('08:00'), findsOneWidget);
      expect(find.text('1 раз на день'), findsOneWidget);

      await _tap(tester, find.text('+ Додати слот часу'));
      await _pump(tester, 8);
      expect(find.text('08:00'), findsOneWidget);
      expect(find.text('13:00'), findsOneWidget, reason: 'second slot added');
      expect(find.text('2 рази на день'), findsWidgets);
      debugPrint('DATA-03 step c: two slots configured (08:00 + 13:00)');

      await _screenshot(tester, 'p3-ios-03-editor');

      // ---------------------------------------------------------------
      // (d) save -> back on Stack with an active card
      // ---------------------------------------------------------------
      await _tap(
        tester,
        find.widgetWithText(FilledButton, 'Додати й запустити цикл'),
      );
      await _pumpUntil(
        tester,
        () => find.byType(RegimenEditorScreen).evaluate().isEmpty,
        'the editor to pop after save',
      );
      await _pumpUntil(
        tester,
        () => find.text(supplementName).evaluate().isNotEmpty,
        'the new card to appear on the Stack tab',
      );

      final card = find.ancestor(
        of: find.text(supplementName),
        matching: find.byType(IntrinsicHeight),
      );
      expect(card, findsOneWidget, reason: 'exactly one card for this run');
      expect(
        find.descendant(of: card, matching: find.text('АКТИВНА')),
        findsOneWidget,
        reason: 'saved cyclic regimen starting today reads as active',
      );
      expect(
        find.descendant(
          of: card,
          matching: find.text('8 тижнів / 4 тижні · 2 рази на день'),
        ),
        findsOneWidget,
        reason: 'schedule summary chip',
      );
      debugPrint('DATA-03 step d: card shows АКТИВНА + schedule chip');

      await _screenshot(tester, 'p3-ios-02-stack');

      // ---------------------------------------------------------------
      // (e) Calendar tab -> today's doses in time blocks, ring at 0 of N
      // ---------------------------------------------------------------
      await _tap(tester, find.text('Календар'));
      await _pumpUntil(
        tester,
        () => find.byType(CalendarScreen).evaluate().isNotEmpty,
        'the Calendar tab to show',
      );

      Finder rowAt(int minutes) => find.byWidgetPredicate(
            (w) =>
                w is DoseRow &&
                w.dose.supplement.name == supplementName &&
                w.dose.slot.minutesFromMidnight == minutes,
          );
      DoseStatus statusAt(int minutes) =>
          tester.widget<DoseRow>(rowAt(minutes)).dose.status;
      ({int taken, int total}) ring() {
        final w = tester.widget<DayProgressRing>(find.byType(DayProgressRing));
        return (taken: w.taken, total: w.total);
      }

      await _pumpUntil(
        tester,
        () =>
            rowAt(480).evaluate().isNotEmpty && rowAt(780).evaluate().isNotEmpty,
        "today's two materialized dose rows",
      );
      expect(find.text('Сьогодні'), findsWidgets);
      expect(find.text('Ранок'), findsOneWidget, reason: '08:00 block');
      expect(find.text('День'), findsOneWidget, reason: '13:00 block');
      expect(statusAt(480), DoseStatus.pending);
      expect(statusAt(780), DoseStatus.pending);

      expect(find.byType(DayProgressRing), findsOneWidget);
      final ring0 = ring();
      expect(ring0.total, greaterThanOrEqualTo(2));
      debugPrint(
        'DATA-03 step e: doses grouped; ring ${ring0.taken}/${ring0.total}',
      );

      await _screenshot(tester, 'p3-ios-04-today');

      // ---------------------------------------------------------------
      // (f) tap a dose row -> taken, ring increments
      // ---------------------------------------------------------------
      await _tap(tester, rowAt(480));
      await _pumpUntil(
        tester,
        () => statusAt(480) == DoseStatus.taken,
        'the 08:00 dose to become taken',
      );
      expect(ring().taken, ring0.taken + 1, reason: 'ring counted the mark');
      expect(ring().total, ring0.total);
      debugPrint('DATA-03 step f: 08:00 taken, ring ${ring().taken}/${ring().total}');

      // ---------------------------------------------------------------
      // (g) long-press another row -> action sheet -> "пропущено"
      // ---------------------------------------------------------------
      await tester.ensureVisible(rowAt(780));
      await _pump(tester, 4);
      await tester.longPress(rowAt(780));
      await _pumpUntil(
        tester,
        () => find.text('Позначити пропущено').evaluate().isNotEmpty,
        'the dose action sheet to open on long press',
      );
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.text('Позначити прийнято'), findsOneWidget);

      await _tap(tester, find.text('Позначити пропущено'));
      await _pumpUntil(
        tester,
        () => statusAt(780) == DoseStatus.skipped,
        'the 13:00 dose to become skipped',
      );
      expect(
        find.descendant(of: rowAt(780), matching: find.text('пропущено')),
        findsOneWidget,
      );
      expect(ring().taken, ring0.taken + 1, reason: 'skipped is not taken');
      debugPrint('DATA-03 step g: 13:00 skipped via the action sheet');

      // ---------------------------------------------------------------
      // (h) tap the taken row again -> pending again, ring decrements
      // ---------------------------------------------------------------
      await _tap(tester, rowAt(480));
      await _pumpUntil(
        tester,
        () => statusAt(480) == DoseStatus.pending,
        'the 08:00 dose to return to pending (undo)',
      );
      expect(ring().taken, ring0.taken, reason: 'ring decremented on undo');
      debugPrint('DATA-03 step h: undo returned 08:00 to pending');

      // Re-mark it so the persistence check below covers BOTH a taken and a
      // skipped row surviving a restart.
      await _tap(tester, rowAt(480));
      await _pumpUntil(
        tester,
        () => statusAt(480) == DoseStatus.taken,
        'the 08:00 dose to be taken again before the restart',
      );

      await _screenshot(tester, 'p3-ios-05-marked');

      // ---------------------------------------------------------------
      // (i) persistence: tear the tree down and boot a FRESH ProviderScope
      // ---------------------------------------------------------------
      await tester.pumpWidget(const SizedBox());
      await _pump(tester, 20);
      await tester.pumpWidget(bootScope());
      await _pump(tester, 20);
      expect(find.byType(StackScreen), findsOneWidget, reason: 'app rebooted');

      final container2 = ProviderScope.containerOf(
        tester.element(find.byType(BoostqueApp)),
        listen: false,
      );
      final reloaded = await _stack(tester, container2);
      expect(
        reloaded.any((e) => e.supplement.name == supplementName),
        isTrue,
        reason: 'the supplement survived the restart',
      );

      await _tap(tester, find.text('Календар'));
      await _pumpUntil(
        tester,
        () =>
            rowAt(480).evaluate().isNotEmpty && rowAt(780).evaluate().isNotEmpty,
        "today's doses after the restart",
      );
      expect(statusAt(480), DoseStatus.taken, reason: 'taken mark persisted');
      expect(statusAt(780), DoseStatus.skipped, reason: 'skip persisted');
      debugPrint('DATA-03 step i: marks survived a full app-tree restart');

      // ---------------------------------------------------------------
      // Past day: unmarked past doses render the neutral "не позначено" chip
      // ---------------------------------------------------------------
      // The regimen starts today, so first move its start into the previous
      // month through the editor's real date picker; then browse a past day.
      await _tap(tester, find.text('Стек'));
      await _pumpUntil(
        tester,
        () => find.text(supplementName).evaluate().isNotEmpty,
        'the Stack tab card',
      );
      await _tap(tester, find.text(supplementName).first);
      await _pumpUntil(
        tester,
        () => find.byType(RegimenEditorScreen).evaluate().isNotEmpty,
        'the editor to open from the card',
      );
      // The editor seeded from the persisted regimen: both slots are back.
      expect(find.text('08:00'), findsOneWidget);
      expect(find.text('13:00'), findsOneWidget);

      // The tappable element is the date VALUE box, not the "Старт" label —
      // formatted exactly as the editor formats it, in the app's own locale.
      final startLocale = Localizations.localeOf(
        tester.element(find.byType(RegimenEditorScreen)),
      ).toString();
      await _tap(tester, find.text(DateFormat.yMd(startLocale).format(today)));
      await _pumpUntil(
        tester,
        () => find.byType(DatePickerDialog).evaluate().isNotEmpty,
        'the start-date picker',
      );
      // One month back, day 10 — always exists, always well before any day of
      // the current week, and inside the 56-day active window.
      await _tap(
        tester,
        find.descendant(
          of: find.byType(DatePickerDialog),
          matching: find.byIcon(Icons.chevron_left),
        ),
      );
      await _pump(tester, 20);
      await _tap(
        tester,
        find
            .descendant(
              of: find.byType(DatePickerDialog),
              matching: find.text('10'),
            )
            .first,
      );
      await _pump(tester, 8);
      await _tap(
        tester,
        find
            .descendant(
              of: find.byType(DatePickerDialog),
              matching: find.byType(TextButton),
            )
            .last,
      );
      await _pumpUntil(
        tester,
        () => find.byType(DatePickerDialog).evaluate().isEmpty,
        'the date picker to close',
      );

      await _tap(
        tester,
        find.widgetWithText(FilledButton, 'Додати й запустити цикл'),
      );
      await _pumpUntil(
        tester,
        () => find.byType(RegimenEditorScreen).evaluate().isEmpty,
        'the editor to pop after the start-date change',
      );

      await _tap(tester, find.text('Календар'));
      await _pumpUntil(
        tester,
        () => find.byType(CalendarScreen).evaluate().isNotEmpty,
        'the Calendar tab',
      );

      // A past day inside the currently displayed week (the strip's last page
      // is today's week, Monday-first).
      final pastDay = today.weekday == DateTime.monday
          ? today.subtract(const Duration(days: 3))
          : today.subtract(const Duration(days: 1));
      if (today.weekday == DateTime.monday) {
        // Today's Monday cell is the week's first column, so the past day
        // lives on the previous page — swipe the pager back one week.
        await tester.drag(find.byType(PageView), const Offset(300, 0));
        await _pump(tester, 20);
      }
      await _tap(tester, find.byKey(ValueKey<DateTime>(dateOnly(pastDay))));
      // Wait for the PAST day's own rows — the previous day's list is held on
      // screen for a frame while the new day's stream resolves (PF-7), so the
      // chip, not the mere presence of a row, is the real condition.
      await _pumpUntil(
        tester,
        () =>
            find
                .descendant(of: rowAt(480), matching: find.text('не позначено'))
                .evaluate()
                .isNotEmpty &&
            find
                .descendant(of: rowAt(780), matching: find.text('не позначено'))
                .evaluate()
                .isNotEmpty,
        'the past day to materialize its unmarked doses',
      );

      expect(statusAt(480), DoseStatus.pending);
      expect(statusAt(780), DoseStatus.pending);
      expect(
        find.descendant(of: rowAt(480), matching: find.text('не позначено')),
        findsOneWidget,
        reason: 'past unmarked dose reads as не позначено',
      );
      expect(
        find.descendant(of: rowAt(780), matching: find.text('не позначено')),
        findsOneWidget,
      );
      // Nothing warn-colored and nothing thrown on a past day.
      expect(find.text('не прийнято вчасно'), findsNothing);
      expect(tester.takeException(), isNull);
      debugPrint('DATA-03 past day: не позначено chips rendered, no exception');

      await _screenshot(tester, 'p3-ios-06-pastday');

      // Leave the tree torn down so Drift's stream-close timers and the
      // midnight Timer are gone before the harness's pending-timer check.
      await tester.pumpWidget(const SizedBox());
      await _pump(tester, 20);
    },
    timeout: const Timeout(Duration(minutes: 10)),
  );
}

/// Pumps [frames] real frames, [ms] apart (the live binding runs real time).
Future<void> _pump(WidgetTester tester, int frames, [int ms = 50]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(Duration(milliseconds: ms));
  }
}

/// Pumps until [condition] holds, failing with [what] on timeout.
///
/// Never `pumpAndSettle`: the minute ticker and the midnight timer are both
/// permanently pending, and Drift emissions arrive asynchronously.
Future<void> _pumpUntil(
  WidgetTester tester,
  bool Function() condition,
  String what, {
  int attempts = 200,
}) async {
  for (var i = 0; i < attempts; i++) {
    await tester.pump(const Duration(milliseconds: 50));
    if (condition()) return;
  }
  fail('DATA-03 timed out waiting for $what');
}

/// Scrolls [finder] into view (no-op outside a scrollable), taps it, and pumps.
Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await _pump(tester, 4);
  await tester.tap(finder);
  await _pump(tester, 8);
}

/// The stack as the app's own provider graph reports it, once it has data.
Future<List<StackEntry>> _stack(
  WidgetTester tester,
  ProviderContainer container,
) async {
  List<StackEntry>? list;
  await _pumpUntil(
    tester,
    () {
      if (container.read(stackEntriesProvider)
          case AsyncData(value: final data)) {
        list = data;
        return true;
      }
      return false;
    },
    'stackEntriesProvider to resolve',
  );
  return list!;
}

/// Requests a host-side screenshot named [name] and waits briefly for it.
///
/// See the library doc: the device process cannot spawn `xcrun`, so this drops
/// a request file in the app documents directory (host-visible on a simulator)
/// for a watcher to pick up. Without a watcher the test simply continues.
Future<void> _screenshot(WidgetTester tester, String name) async {
  File? request;
  try {
    final dir = await getApplicationDocumentsDirectory();
    request = File('${dir.path}/bq_shot_$name.request');
    await request.writeAsString(name);
  } catch (e) {
    debugPrint('DATA-03 screenshot request failed for $name: $e');
    return;
  }
  final deadline = _screenshotWait.inMilliseconds ~/ 50;
  for (var i = 0; i < deadline; i++) {
    await tester.pump(const Duration(milliseconds: 50));
    if (!request.existsSync()) {
      debugPrint('DATA-03 screenshot taken: $name');
      return;
    }
  }
  try {
    request.deleteSync();
  } catch (_) {}
  debugPrint('DATA-03 screenshot NOT taken (no host watcher): $name');
}
