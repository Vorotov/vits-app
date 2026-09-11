/// Captures the App Store / Play listing screenshots from the REAL app.
///
/// This is a tool, not a gate. It asserts only enough to fail loudly when a
/// screen did not actually render — a blank or half-built frame turned into a
/// store asset is worse than no asset, because nobody looks at a PNG twice.
///
/// It follows `data03_loop_test.dart`'s mechanism exactly: the test process
/// runs on the device and cannot spawn `xcrun`, so it drops
/// `bq_shot_<name>.request` into the app's documents directory and waits for a
/// host-side watcher to turn it into a screenshot. Run the watcher in another
/// shell first, or use `tool/make_screenshots.sh`, which does both.
///
///     tool/make_screenshots.sh
///
/// The seed data is deliberate, not arbitrary. Five supplements with different
/// schedules, one of them deep in an OFF week, because the gantt with no break
/// visible in it is a picture of a to-do list and says nothing about what this
/// app is for. Every morning dose is marked taken, so the Today screen shows a
/// partly-filled ring rather than either extreme.
///
/// It writes to the device's real database. Run it against a simulator you are
/// willing to erase; `tool/make_screenshots.sh` erases one first.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:vitomy/core/domain/cycle_math.dart';
import 'package:vitomy/core/domain/models.dart';
import 'package:vitomy/core/domain/repositories.dart';
import 'package:vitomy/core/providers.dart';
import 'package:vitomy/core/theme/tokens.dart';
import 'package:vitomy/core/today_controller.dart';
import 'package:vitomy/features/calendar/planner_screen.dart';
import 'package:vitomy/features/calendar/today_screen.dart';
import 'package:vitomy/features/stack/regimen_editor_screen.dart';
import 'package:vitomy/features/stack/stack_screen.dart';
import 'package:vitomy/main.dart' show VitomyApp;

const Duration _screenshotWait = Duration(seconds: 8);
const _uuid = Uuid();

/// One seeded supplement and the schedule that makes it interesting.
class _Seed {
  const _Seed({
    required this.name,
    required this.dose,
    required this.colorIndex,
    required this.startOffsetDays,
    required this.onDays,
    required this.offDays,
    required this.slots,
    this.courseLengthDays,
  });

  final String name;
  final String dose;
  final int colorIndex;

  /// Negative: this many days before today. Chosen per row so the gantt shows
  /// bars at different phases rather than five bars starting on one line.
  final int startOffsetDays;
  final int onDays;
  final int offDays;

  /// Minutes from midnight.
  final List<int> slots;

  /// Non-null makes it a course rather than a cyclic regimen.
  final int? courseLengthDays;
}

const List<_Seed> _seeds = [
  _Seed(
    name: 'Vitamin D3',
    dose: '2000 IU · 1 capsule',
    colorIndex: 0,
    startOffsetDays: -34,
    onDays: 56,
    offDays: 28,
    slots: [8 * 60],
  ),
  _Seed(
    name: 'Omega-3',
    dose: '1000 mg · 2 softgels',
    colorIndex: 5,
    startOffsetDays: -61,
    onDays: 90,
    offDays: 14,
    slots: [8 * 60, 20 * 60],
  ),
  _Seed(
    // Started far enough back that today falls in the 28-day break. The gantt
    // and the year grid both need at least one of these to mean anything.
    name: 'Creatine',
    dose: '5 g · powder',
    colorIndex: 3,
    startOffsetDays: -71,
    onDays: 56,
    offDays: 28,
    slots: [9 * 60],
  ),
  _Seed(
    name: 'Magnesium',
    dose: '400 mg · 2 capsules',
    colorIndex: 2,
    startOffsetDays: -12,
    onDays: 30,
    offDays: 7,
    slots: [22 * 60],
  ),
  _Seed(
    name: 'Zinc',
    dose: '15 mg · 1 tablet',
    colorIndex: 4,
    startOffsetDays: -6,
    onDays: 0,
    offDays: 0,
    slots: [21 * 60],
    courseLengthDays: 30,
  ),
];

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('store listing screenshots', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    // English is the store's primary language, and neither the intro nor a
    // first-run hint belongs in a listing screenshot.
    await prefs.setString('app_locale', 'en');
    await prefs.setBool('onboarding_seen', true);
    await prefs.setStringList(
      'first_run_hints_seen',
      [for (final h in const ['hint_cycle', 'hint_mark_dose']) h],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: const VitomyApp(),
      ),
    );
    await _pump(tester, 20);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(VitomyApp)),
      listen: false,
    );
    final today = container.read(todayProvider);

    await _seedStack(tester, container, today);
    await _markMorningDosesTaken(tester, container, today);

    // ---- 1. My stack -------------------------------------------------
    await _tap(tester, find.text('Stack'));
    await _pumpUntil(
      tester,
      () =>
          find.byType(StackScreen).evaluate().isNotEmpty &&
          find.text('Creatine').evaluate().isNotEmpty,
      'the stack list to show the seeded supplements',
    );
    await _screenshot(tester, '01-stack');

    // ---- 2. Today ----------------------------------------------------
    await _tap(tester, find.text('Today'));
    await _pumpUntil(
      tester,
      () =>
          find.byType(TodayScreen).evaluate().isNotEmpty &&
          find.text('Vitamin D3').evaluate().isNotEmpty,
      "today's doses",
    );
    await _screenshot(tester, '02-today');

    // ---- 3. Cycles ---------------------------------------------------
    await _tap(tester, find.text('Calendar'));
    await _pumpUntil(
      tester,
      () => find.byType(PlannerScreen).evaluate().isNotEmpty,
      'the planner',
    );
    await _tap(tester, find.text('Cycles'));
    await _pumpUntil(
      tester,
      () => find.text('Creatine').evaluate().isNotEmpty,
      'the gantt rows',
    );
    await _screenshot(tester, '03-cycles');

    // ---- 4. Year -----------------------------------------------------
    await _tap(tester, find.text('Year'));
    await _pump(tester, 20);
    await _screenshot(tester, '04-year');

    // ---- 5. The schedule editor --------------------------------------
    // The one screen that shows what a cycle actually is, which is the thing
    // a listing has to explain in one picture.
    await _tap(tester, find.text('Stack'));
    await _pumpUntil(
      tester,
      () => find.text('Creatine').evaluate().isNotEmpty,
      'the stack list again',
    );
    await _tap(tester, find.text('Creatine'));
    await _pumpUntil(
      tester,
      () => find.byType(RegimenEditorScreen).evaluate().isNotEmpty,
      'the regimen editor',
    );
    await _screenshot(tester, '05-schedule');

    debugPrint('screenshots: done');
  });
}

/// Writes the seed stack straight through the repositories.
///
/// Driving the add sheet and the editor five times would test the UI, which
/// `data03_loop_test.dart` already does far more carefully than this file
/// would. Here the UI is the subject of the photograph, not the thing under
/// test, so the data goes in the short way.
Future<void> _seedStack(
  WidgetTester tester,
  ProviderContainer container,
  DateTime today,
) async {
  final supplements = container.read(supplementRepoProvider);
  final regimens = container.read(regimenRepoProvider);

  for (final seed in _seeds) {
    final supplementId = _uuid.v4();
    await supplements.upsert(
      Supplement(
        id: supplementId,
        name: seed.name,
        doseText: seed.dose,
        colorValue:
            BqSeriesColors.palette[seed.colorIndex].toARGB32(),
        note: '',
      ),
    );
    final start = dateOnly(today.add(Duration(days: seed.startOffsetDays)));
    await regimens.upsert(
      Regimen(
        id: _uuid.v4(),
        supplementId: supplementId,
        kind: seed.courseLengthDays == null
            ? RegimenKind.cyclic
            : RegimenKind.course,
        startDate: start,
        endDate: seed.courseLengthDays == null
            ? null
            : dateOnly(start.add(Duration(days: seed.courseLengthDays! - 1))),
        onDays: seed.onDays,
        offDays: seed.offDays,
        paused: false,
        slots: [
          for (final minutes in seed.slots)
            DoseSlot(
              id: _uuid.v4(),
              minutesFromMidnight: minutes,
              doseLabel: seed.dose,
            ),
        ],
      ),
    );
    await _pump(tester, 2);
  }

  await _pumpUntil(
    tester,
    () => switch (container.read(stackEntriesProvider)) {
      AsyncData(value: final list) => list.length >= _seeds.length,
      _ => false,
    },
    'the seeded stack to reach stackEntriesProvider',
  );
  debugPrint('screenshots: seeded ${_seeds.length} supplements');
}

/// Marks every dose whose slot has already passed, so the Today screen shows a
/// partly-filled ring and no overdue chips.
///
/// Observed through a `listen`, never `await stream.first`, and the
/// subscription is cancelled unawaited — both are house rules for a Drift
/// stream inside a widget test (.claude/CLAUDE.md, Conventions -> Testing).
Future<void> _markMorningDosesTaken(
  WidgetTester tester,
  ProviderContainer container,
  DateTime today,
) async {
  final intake = container.read(intakeRepoProvider);
  await intake.ensureLogsForDay(today);

  var doses = const <DayDose>[];
  final sub = intake.watchDay(today).listen((value) => doses = value);
  await _pumpUntil(tester, () => doses.isNotEmpty, 'the materialized day');

  // TodayController.now is the app's ONE sanctioned wall-clock read; going
  // through it here rather than calling DateTime.now() keeps that true.
  final wallClock = container.read(todayProvider.notifier).now();
  final nowMinutes = wallClock.hour * 60 + wallClock.minute;
  var marked = 0;
  for (final dose in doses) {
    if (dose.slot.minutesFromMidnight <= nowMinutes) {
      await intake.setStatus(dose.logId, DoseStatus.taken);
      marked++;
    }
  }
  await _pump(tester, 10);
  // ignore: unawaited_futures
  sub.cancel();
  await _pump(tester, 4);
  debugPrint('screenshots: marked $marked of ${doses.length} doses taken');
}

Future<void> _pump(WidgetTester tester, int frames, [int ms = 50]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(Duration(milliseconds: ms));
  }
}

/// Never `pumpAndSettle`: the Today screen's minute ticker and the midnight
/// timer are both permanently pending.
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
  final texts = find
      .byType(Text)
      .evaluate()
      .map((e) => (e.widget as Text).data)
      .where((s) => s != null)
      .toList();
  debugPrint('screenshots: on-screen text at timeout: $texts');
  fail('screenshots timed out waiting for $what');
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder.first);
  await _pump(tester, 4);
  await tester.tap(finder.first);
  await _pump(tester, 10);
}

/// Drops a request file for the host watcher and waits briefly for it.
/// With no watcher running the test still passes; it just waits and moves on.
Future<void> _screenshot(WidgetTester tester, String name) async {
  File? request;
  try {
    final dir = await getApplicationDocumentsDirectory();
    request = File('${dir.path}/bq_shot_$name.request');
    await request.writeAsString(name);
  } catch (e) {
    debugPrint('screenshot request failed for $name: $e');
    return;
  }
  for (var i = 0; i < _screenshotWait.inMilliseconds ~/ 50; i++) {
    await tester.pump(const Duration(milliseconds: 50));
    if (!request.existsSync()) {
      debugPrint('screenshots: captured $name');
      return;
    }
  }
  try {
    request.deleteSync();
  } catch (_) {}
  debugPrint('screenshots: NOT captured (no host watcher): $name');
}
