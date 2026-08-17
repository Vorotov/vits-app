/// Source-glob gates over `lib/` for the shell restructure (plan 06-03,
/// NAV-02 / NAV-03).
///
/// Deletion is the whole point of this plan, and a deletion has no runtime
/// surface to assert against: once the page swap is gone there is no widget
/// to pump, no provider to read and no tap path to drive. What CAN regress is
/// someone re-introducing a symbol — or, just as expensively in this codebase,
/// a doc comment that still describes the deleted mechanism. Comments are
/// therefore gated too: this project writes rationale into doc comments, so a
/// comment about a deleted file is a durable lie, and the deletion inventory
/// (06-PATTERNS) lists two such comments that had to be rewritten by hand.
///
/// Its own file, deliberately, rather than another group inside
/// `planner_invariants_test.dart`: the later planner plans (06-05, 06-06) edit
/// that file heavily, and two plans editing one gate file is a merge conflict
/// waiting to happen.
///
/// The scan is a GLOB over `lib/`, not a hardcoded file list — a file added by
/// a later phase is gated the day it lands, with nobody having to remember
/// this test exists.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Every Dart file under `lib/`, generated localizations included.
///
/// The generated `app_localizations*.dart` files are IN scope on purpose:
/// `tabSettings` living on there would mean `flutter gen-l10n` was never
/// re-run after the ARB rename, which is exactly the half-finished state this
/// gate exists to catch.
List<File> libSources() {
  final files = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  return files;
}

void main() {
  late Map<String, String> sources;

  setUpAll(() {
    sources = {
      for (final file in libSources()) file.path: file.readAsStringSync(),
    };
  });

  test('the glob actually resolves the app sources — a gate over an empty file '
      'set is worse than no gate', () {
    expect(sources, isNotEmpty);
    expect(sources.length, greaterThanOrEqualTo(20),
        reason: 'lib/ holds well over twenty Dart files; a smaller set means '
            'the glob stopped matching and every gate below became vacuous');
    expect(
      sources.keys.any((p) => p.endsWith('app_shell.dart')),
      isTrue,
      reason: 'the shell itself must be in the scanned set — it is the file '
          'most of these gates are about',
    );
  });

  test('the deleted page-swap machinery resolves nowhere in lib/, comments '
      'included (NAV-02, deletion inventory A)', () {
    const forbidden = <String, String>{
      'CalendarScreen': 'the deleted screen class. The Today page is '
          'TodayScreen and the planner is a destination; a reference here '
          'means the swap host came back',
      'CalendarPage': 'the page-swap enum (and, by prefix, its controller '
          'CalendarPageController)',
      'calendarPageProvider': 'the page-swap provider — the single piece of '
          'state the whole deleted mechanism turned on',
      'PopScope': 'the back-interception. System back on a tab must behave '
          'exactly as it does in any single-screen app: it leaves. A PopScope '
          'anywhere in lib/ means something started intercepting it again',
      'tabSettings': 'the old ARB key name. Settings is not a destination, so '
          'a key named after one lies; it was renamed settingsTitle, and a '
          'surviving reference means gen-l10n was not re-run or a call site '
          'was missed',
      // Constructor calls and the theme FIELD, not the bare words: BqNavBar's
      // own doc comment names `NavigationBar` and `navigationBarTheme.height`
      // on purpose — it is the D-1 rationale for refusing the SDK widget, and
      // wave 1 required it be written down. `Scaffold(bottomNavigationBar:)`
      // is likewise a slot name every screen keeps using. What must not exist
      // is a MOUNT.
      'NavigationBar(': 'a mount of the SDK bar, replaced by the hand-built '
          'BqNavBar in plan 06-01 because its resolved height lands in a hard '
          'SizedBox that does not grow with the text scaler (NAV-01, D-1)',
      'NavigationDestination(': 'an SDK destination — the same widget family, '
          'and the thing the deleted settings destination was',
      'navigationBarTheme:': 'the SDK bar\'s sub-theme; its values moved into '
          'BqNavBar and a theme entry for a widget nothing mounts is dead '
          'configuration that reads as if it still applied',
    };

    final hits = <String>[];
    sources.forEach((path, source) {
      forbidden.forEach((needle, why) {
        if (source.contains(needle)) hits.add('$path references $needle');
      });
    });

    expect(hits, isEmpty,
        reason: 'the page swap, its back-interception and the SDK nav bar '
            'were deleted in plans 06-01 and 06-03. Comments count: this '
            'codebase writes rationale into doc comments, so a comment '
            'describing a deleted mechanism misleads the next reader as '
            'effectively as live code would. Forbidden: '
            '${forbidden.keys.join(', ')}. Offenders: $hits');
  });

  test('plannerTitle labels the planner screen and NOTHING else — the Today '
      'header\'s entry action is gone (deletion inventory A)', () {
    // Scoped rather than absolute, and the scope is the point. `plannerTitle`
    // is still the planner's own screen title (mockup line 287) — deleting it
    // would leave the screen untitled. What was deleted is its SECOND
    // placement: the Today header's `TextButton` into the page swap. So the
    // gate is "exactly one file may name this key", which fails both if the
    // header action returns and if some third screen starts borrowing the
    // planner's title.
    const key = 'plannerTitle';
    const allowed = 'planner_screen.dart';

    final offenders = <String>[
      for (final entry in sources.entries)
        if (entry.value.contains(key) &&
            !entry.key.endsWith(allowed) &&
            !entry.key.contains('/l10n/'))
          entry.key,
    ];

    expect(offenders, isEmpty,
        reason: 'only $allowed (and the generated/ARB l10n files that declare '
            'the key) may name $key. A second placement means the deleted '
            'header entry action — or something like it — came back. '
            'Offenders: $offenders');
  });

  test('the shell mounts exactly the three destination screens (NAV-02, S9)',
      () {
    final shell = sources.entries
        .firstWhere((e) => e.key.endsWith('app_shell.dart'))
        .value;

    for (final screen in const ['StackScreen()', 'TodayScreen()',
      'PlannerScreen()']) {
      expect(shell.contains(screen), isTrue,
          reason: '$screen is one of the three IndexedStack children the '
              'shell is contracted to hold');
    }
    expect(shell.contains('SettingsScreen'), isFalse,
        reason: 'Settings is a route pushed by the gear, never a child of the '
            'shell\'s IndexedStack — mounting it here would put it back one '
            'refactor away from being a destination again (NAV-03)');
    expect(shell.contains('TickerMode('), isTrue,
        reason: 'the WR-05 per-child TickerMode wrapper survives the '
            'restructure; without it the offstage Сьогодні tab re-arms the '
            'minute ticker and nothing at runtime shows it');
  });
}
