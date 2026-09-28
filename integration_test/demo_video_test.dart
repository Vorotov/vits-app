/// Drives the REAL app through a paced walkthrough, for the Devpost demo video.
///
/// This is a tool, not a gate, and it is throwaway in the same sense
/// `store_screenshots_test.dart` is not: it asserts only enough to fail loudly
/// when a screen did not render, because a recording of a blank frame is worse
/// than no recording.
///
/// Run it with the host recording the simulator:
///
///     tool/make_demo_video.sh
///
/// ## Why the tip screen is stubbed
///
/// A simulator cannot fetch products from the live App Store, so the support
/// screen would render its "not available" state — a picture of a bug the app
/// does not have. The stub is exactly the one in `iap_screenshot_test.dart`:
/// the REAL screen, the real copy, the real layout, the real product
/// identifiers and the real configured prices, with only the network fetch
/// replaced. Nothing here is drawn by this file, and the stub never enters
/// `lib/`.
///
/// ## Pacing
///
/// `_hold` pumps in real time, which is what the recorder captures. Every
/// number below is seconds on screen, chosen so a viewer can read the screen
/// before it changes.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:vitomy/core/domain/cycle_math.dart';
import 'package:vitomy/core/domain/models.dart';
import 'package:vitomy/core/domain/repositories.dart';
import 'package:vitomy/core/providers.dart';
import 'package:vitomy/core/purchases/purchase_gateway.dart';
import 'package:vitomy/core/purchases/purchase_providers.dart';
import 'package:vitomy/core/purchases/tip_products.dart';
import 'package:vitomy/core/theme/tokens.dart';
import 'package:vitomy/core/today_controller.dart';
import 'package:vitomy/features/calendar/planner_screen.dart';
import 'package:vitomy/features/calendar/today_screen.dart';
import 'package:vitomy/features/stack/regimen_editor_screen.dart';
import 'package:vitomy/features/stack/stack_screen.dart';
import 'package:vitomy/features/support/support_screen.dart';
import 'package:vitomy/main.dart' show VitomyApp;

const _uuid = Uuid();

/// The three tips exactly as configured in App Store Connect.
const _offering = <TipProduct>[
  TipProduct(id: tipSmallId, priceString: r'$0.99'),
  TipProduct(id: tipMediumId, priceString: r'$1.99'),
  TipProduct(id: tipLargeId, priceString: r'$4.99'),
];

class _DemoGateway extends PurchaseGateway {
  const _DemoGateway();

  @override
  Future<void> configure() async {}

  @override
  Future<List<TipProduct>> tips() async => _offering;

  /// Unreachable by design: a real attempt would open a system sheet over the
  /// frame being recorded.
  @override
  Future<TipPurchaseResult> buy(String productId) async =>
      TipPurchaseResult.cancelled;
}

class _Seed {
  const _Seed({
    required this.name,
    required this.dose,
    required this.colorIndex,
    required this.startOffsetDays,
    required this.onDays,
    required this.offDays,
    required this.slots,
  });

  final String name;
  final String dose;
  final int colorIndex;
  final int startOffsetDays;
  final int onDays;
  final int offDays;
  final List<int> slots;
}

/// The same stack the listing screenshots use: five supplements at different
/// phases, one of them deep inside its break, because a gantt with no break in
/// it is a picture of a to-do list.
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
    startOffsetDays: -5,
    onDays: 84,
    offDays: 0,
    slots: [13 * 60],
  ),
];

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('demo walkthrough', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_locale', 'en');
    await prefs.setBool('onboarding_seen', true);
    await prefs.setStringList(
      'first_run_hints_seen',
      const ['hint_cycle', 'hint_mark_dose'],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          purchaseGatewayProvider.overrideWithValue(const _DemoGateway()),
        ],
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
    // One past dose is left unmarked on purpose — it is the thing tapped on
    // camera, and a screen with nothing left to do demonstrates nothing.
    final pending = await _markPastDosesExceptOne(tester, container, today);

    // ---- 1. My stack -------------------------------------------------
    await _tap(tester, find.text('Stack'));
    await _pumpUntil(
      tester,
      () =>
          find.byType(StackScreen).evaluate().isNotEmpty &&
          find.text('Creatine').evaluate().isNotEmpty,
      'the stack list',
    );
    await _hold(tester, 4);

    // ---- 2. What a cycle actually is ---------------------------------
    await _tap(tester, find.text('Creatine'));
    await _pumpUntil(
      tester,
      () => find.byType(RegimenEditorScreen).evaluate().isNotEmpty,
      'the regimen editor',
    );
    await _hold(tester, 5);
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -260));
    await _hold(tester, 4);
    await _tap(
      tester,
      find.ancestor(
        of: find.byIcon(Icons.arrow_back_ios_new),
        matching: find.byType(IconButton),
      ),
    );
    await _pumpUntil(
      tester,
      () => find.byType(StackScreen).evaluate().isNotEmpty,
      'the stack list again',
    );
    await _hold(tester, 1);

    // ---- 3. Today, and marking a dose --------------------------------
    await _tap(tester, find.text('Today'));
    await _pumpUntil(
      tester,
      () =>
          find.byType(TodayScreen).evaluate().isNotEmpty &&
          find.text('Vitamin D3').evaluate().isNotEmpty,
      "today's doses",
    );
    await _hold(tester, 4);
    if (pending != null && find.text(pending).evaluate().isNotEmpty) {
      await _tap(tester, find.text(pending));
      await _hold(tester, 4);
    } else {
      debugPrint('demo: no pending dose to tap ($pending)');
      await _hold(tester, 2);
    }

    // ---- 4. Cycles ---------------------------------------------------
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
    await _hold(tester, 6);

    // ---- 5. Year -----------------------------------------------------
    await _tap(tester, find.text('Year'));
    await _hold(tester, 5);

    // ---- 6. The tip screen -------------------------------------------
    await _tap(
      tester,
      find.ancestor(
        of: find.byIcon(Icons.settings_outlined),
        matching: find.byType(IconButton),
      ),
    );
    await _pumpUntil(
      tester,
      () => find.text('Reset intro and hints').evaluate().isNotEmpty,
      'the Settings screen',
    );
    await _hold(tester, 2);

    final supportRow = find.text('Support the developer');
    if (supportRow.evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        supportRow,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await _pump(tester, 6);
    }
    await _tap(tester, supportRow.first);
    await _pumpUntil(
      tester,
      () =>
          find.byType(SupportScreen).evaluate().isNotEmpty &&
          find.text(r'$4.99').evaluate().isNotEmpty,
      'the support screen with all three tips priced',
    );
    await _hold(tester, 7);

    debugPrint('demo: done');
  });
}

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
        colorValue: BqSeriesColors.palette[seed.colorIndex].toARGB32(),
        note: '',
      ),
    );
    final start = dateOnly(today.add(Duration(days: seed.startOffsetDays)));
    await regimens.upsert(
      Regimen(
        id: _uuid.v4(),
        supplementId: supplementId,
        kind: RegimenKind.cyclic,
        startDate: start,
        endDate: null,
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
  debugPrint('demo: seeded ${_seeds.length} supplements');
}

/// Marks every already-passed dose taken except the last one, and returns that
/// one's supplement name so the walkthrough can tap it on camera.
///
/// Observed through a `listen`, never `await stream.first`, and the
/// subscription is cancelled unawaited — house rules for a Drift stream inside
/// a widget test.
Future<String?> _markPastDosesExceptOne(
  WidgetTester tester,
  ProviderContainer container,
  DateTime today,
) async {
  final intake = container.read(intakeRepoProvider);
  await intake.ensureLogsForDay(today);

  var doses = const <DayDose>[];
  final sub = intake.watchDay(today).listen((value) => doses = value);
  await _pumpUntil(tester, () => doses.isNotEmpty, 'the materialized day');

  final wallClock = container.read(todayProvider.notifier).now();
  final nowMinutes = wallClock.hour * 60 + wallClock.minute;
  final past = doses
      .where((d) => d.slot.minutesFromMidnight <= nowMinutes)
      .toList();

  String? pending;
  for (var i = 0; i < past.length; i++) {
    if (i == past.length - 1) {
      pending = past[i].supplement.name;
      continue;
    }
    await intake.setStatus(past[i].logId, DoseStatus.taken);
  }
  await _pump(tester, 10);
  // ignore: unawaited_futures
  sub.cancel();
  await _pump(tester, 4);
  debugPrint('demo: marked ${past.length - 1} taken, left "$pending" pending');
  return pending;
}

Future<void> _pump(WidgetTester tester, int frames, [int ms = 50]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(Duration(milliseconds: ms));
  }
}

/// Real seconds on screen, which is what the host recorder captures.
Future<void> _hold(WidgetTester tester, int seconds) =>
    _pump(tester, seconds * 20);

/// Never `pumpAndSettle`: the Today screen's minute ticker and the midnight
/// timer are both permanently pending.
Future<void> _pumpUntil(
  WidgetTester tester,
  bool Function() condition,
  String what, {
  int attempts = 200,
}) async {
  for (var i = 0; i < attempts; i++) {
    if (condition()) return;
    await tester.pump(const Duration(milliseconds: 50));
  }
  fail('demo timed out waiting for $what');
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder.first);
  await _pump(tester, 4);
  await tester.tap(finder.first);
  await _pump(tester, 10);
}
