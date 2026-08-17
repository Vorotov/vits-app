import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:boostque/app_shell.dart';
import 'package:boostque/core/db/database.dart' show BoostqueDb;
import 'package:boostque/core/l10n/l10n.dart';
import 'package:boostque/core/providers.dart';
import 'package:boostque/core/theme/theme.dart';
import 'package:boostque/core/widgets/bq_nav_bar.dart';
import 'package:boostque/features/calendar/calendar_providers.dart';
import 'package:boostque/main.dart';

import '../support/locale_matrix.dart';

/// D-27: the shell renders localized tab labels in en and uk, switches tabs,
/// and produces no overflow with the longest uk label ("Налаштування").
///
/// Since plan 02-01 the Stack tab watches [stackEntriesProvider], so every
/// shell test overrides [dbProvider] with an in-memory database (D-19) and
/// flushes Drift's stream-close timers before the test ends.
///
/// Plan 05-04: the harness no longer hardcodes a language — it takes the
/// `String locale` + `TextScaler?` parameter shape every suite in this
/// repository now shares (`planner_screen_test.dart:142-163`), and the
/// label-render claim is asserted once, by the locale × text-scale matrix at
/// the bottom, in BOTH languages at BOTH scales. The two former single-locale
/// label tests were folded into it rather than left alongside as duplicates;
/// what the English test uniquely claimed — that [BoostqueApp] with no stored
/// override follows the system locale, and that tabs switch in place — is
/// kept below as its own test.
void main() {
  late SharedPreferences prefs;

  setUp(() async {
    // LocaleController reads its persisted override from SharedPreferences;
    // an empty store means "follow system" (English in the test environment).
    // Since plan 05-01 that read is SYNCHRONOUS, through
    // sharedPreferencesProvider — which throws unless overridden — so the
    // instance is resolved here and handed to every scope below.
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  ProviderScope scoped(Widget child) {
    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        dbProvider.overrideWith((ref) {
          final db = BoostqueDb.forTesting(NativeDatabase.memory());
          ref.onDispose(db.close);
          return db;
        }),
      ],
      child: child,
    );
  }

  /// The shell under a rendering locale and text scale pinned from OUTSIDE —
  /// the `plannerApp` harness signature (05-PATTERNS), so the matrix below is
  /// a loop rather than four copies.
  Widget shellTree({String locale = 'uk', TextScaler? textScaler}) {
    return MaterialApp(
      locale: Locale(locale),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: bqTheme(),
      builder: (context, child) => textScaler == null
          ? child!
          : MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: textScaler),
              child: child!,
            ),
      home: const AppShell(),
    );
  }

  Widget shellApp({String locale = 'uk', TextScaler? textScaler}) =>
      scoped(shellTree(locale: locale, textScaler: textScaler));

  /// Tears the tree down inside the test body so Drift's stream-close
  /// zero-duration timers fire before flutter_test's pending-timer check.
  Future<void> flushTearDown(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 10));
    await tester.pump(const Duration(milliseconds: 10));
  }

  /// Bounded frame pumping. Never `pumpAndSettle` in the matrix: the shell
  /// keeps a midnight `Timer` alive for the whole session, and settling
  /// against a live clock either hangs or passes for a reason the test did not
  /// intend (PF-7).
  Future<void> pumpFrames(WidgetTester tester, [int frames = 20]) async {
    for (var i = 0; i < frames; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
  }

  testWidgets(
      'en: BoostqueApp with no stored override follows the system locale and '
      'switches tabs in place', (tester) async {
    await tester.pumpWidget(scoped(const BoostqueApp()));
    await tester.pumpAndSettle();

    // Three en tab labels present; initial tab shows the Stack screen
    // heading (stackTitle, since plan 02-01).
    expect(find.text('Stack'), findsOneWidget);
    expect(find.text('My stack'), findsOneWidget);
    expect(find.text('Calendar'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);

    // Switch to Settings: its heading appears (2 widgets), Stack heading
    // hidden again (tab label only).
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    expect(find.text('Settings'), findsNWidgets(2));
    expect(find.text('Stack'), findsOneWidget);
    expect(find.text('My stack'), findsNothing);

    await flushTearDown(tester);
  });

  testWidgets('uk: the minute ticker runs only while the Calendar tab is the '
      'visible one (WR-05)', (tester) async {
    final container = ProviderContainer(overrides: [
      // AppShell mounts the Settings tab even while the Stack tab is visible
      // (IndexedStack), and its language picker reaches LocaleController —
      // so this container needs the prefs seed too (P-4 Option A).
      sharedPreferencesProvider.overrideWithValue(prefs),
      dbProvider.overrideWith((ref) {
        final db = BoostqueDb.forTesting(NativeDatabase.memory());
        ref.onDispose(db.close);
        return db;
      }),
    ]);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: shellTree(locale: 'uk'),
    ));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }

    expect(container.exists(nowMinutesProvider), isFalse,
        reason: 'the app opens on the Stack tab — an IndexedStack mounts the '
            'Calendar too, but no periodic clock may run for it');

    await tester.tap(find.text('Календар'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(container.exists(nowMinutesProvider), isTrue,
        reason: 'the visible calendar needs the minute of day for its current '
            'block and overdue treatments');

    await tester.tap(find.text('Стек'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(container.exists(nowMinutesProvider), isFalse,
        reason: 'leaving the tab cancels the subscription again');

    await flushTearDown(tester);
    container.dispose();
    await tester.pump(const Duration(milliseconds: 10));
  });

  testWidgets('uk: switching to Settings renders heading without overflow',
      (tester) async {
    await tester.pumpWidget(shellApp(locale: 'uk'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Налаштування'));
    await tester.pumpAndSettle();

    // E2 overflow truth: uk heading renders twice (tab label + heading),
    // no exception thrown.
    expect(find.text('Налаштування'), findsNWidgets(2));
    expect(tester.takeException(), isNull);

    await flushTearDown(tester);
  });

  testWidgets(
      'uk: a destination is activatable through SemanticsAction.tap, and '
      'activating the already-selected one is a no-op (WR-02)',
      (tester) async {
    await tester.pumpWidget(shellApp(locale: 'uk'));
    await pumpFrames(tester);

    final l10n = lookupAppLocalizations(const Locale('uk'));

    // The node has to carry the action ITSELF: `excludeSemantics: true` on
    // the destination drops every descendant action, so a bar whose onTap
    // lived only on the InkResponse would announce three buttons that
    // VoiceOver / TalkBack cannot press — and it would pass every
    // coordinate-tap test in this file (WR-02).
    expect(
      tester.getSemantics(find.text(l10n.tabCalendar)),
      isSemantics(isButton: true, isSelected: false, hasTapAction: true),
      reason: 'the unselected Calendar destination is a pressable button '
          'that reports itself unselected',
    );

    // Assistive technology does not tap widgets. It activates semantics
    // actions, which is the only path that proves this contract.
    tester.semantics.performAction(
      find.semantics.byLabel(l10n.tabCalendar),
      SemanticsAction.tap,
    );
    await pumpFrames(tester);

    // The Calendar screen is now the painted one; the Stack heading is gone.
    expect(find.text(l10n.stackTitle), findsNothing,
        reason: 'activating the node switched the visible screen, not just '
            'the bar styling');
    expect(
      tester.getSemantics(find.text(l10n.tabCalendar)),
      isSemantics(isButton: true, isSelected: true, hasTapAction: true),
      reason: 'and the node it activated now reports itself selected',
    );

    // Re-activating the selected destination must stay a no-op rather than
    // throw or unmount the screen.
    tester.semantics.performAction(
      find.semantics.byLabel(l10n.tabCalendar),
      SemanticsAction.tap,
    );
    await pumpFrames(tester);
    expect(tester.takeException(), isNull);
    expect(find.text(l10n.stackTitle), findsNothing);

    await flushTearDown(tester);
  });

  testWidgets('uk: the bar is the hand-built BqNavBar at its computed extent',
      (tester) async {
    await tester.pumpWidget(shellApp(locale: 'uk'));
    await pumpFrames(tester);

    expect(find.byType(BqNavBar), findsOneWidget);
    expect(
      tester.getSize(find.byType(BqNavBar)).height,
      navBarHeightFor(TextScaler.noScaling),
      reason: 'with no safe-area inset in the test window the painted bar is '
          'exactly the computed extent — 56dp at scale 1.0 (NAV-01), down '
          'from v1\'s 80dp',
    );

    await flushTearDown(tester);
  });

  // ---------------------------------------------------------------------
  // The bilingual × text-scale matrix (plan 05-04, L10N-01 criterion 1).
  //
  // The shell is the frame every other screen is read inside, and before this
  // plan it had been rendered in English exactly once, at scale 1.0, through
  // BoostqueApp's system-locale path — never with the locale pinned, never at
  // an accessibility scale.
  // ---------------------------------------------------------------------

  group('bilingual render matrix (L10N-01)', () {
    for (final locale in const ['uk', 'en']) {
      final l10n = lookupAppLocalizations(Locale(locale));

      for (final scale in const <double>[1.0, 1.6]) {
        testWidgets(
            '$locale: the shell renders its three nav destinations and the '
            'Stack heading in the active language, with no layout exception '
            'at textScaler $scale (V-4, E-14)', (tester) async {
          await tester.pumpWidget(
            shellApp(locale: locale, textScaler: TextScaler.linear(scale)),
          );
          await pumpFrames(tester);

          // In the RIGHT language, not merely rendered: these four strings
          // differ between uk and en, so a shell that fell back to the other
          // language fails here rather than passing on a bare render.
          expect(find.text(l10n.tabStack), findsOneWidget);
          expect(find.text(l10n.tabCalendar), findsOneWidget);
          expect(find.text(l10n.tabSettings), findsOneWidget);
          expect(find.text(l10n.stackTitle), findsOneWidget,
              reason: 'the Stack tab is the one the app opens on, so its '
                  'heading is part of the shell frame the user first reads');

          if (locale == 'en') {
            expectNoCyrillicWhileEn(tester);
          }
          expect(tester.takeException(), isNull, reason: overflowReason);

          await flushTearDown(tester);
        });
      }
    }
  });
}
