/// The planner's standing invariants, as executable gates (plan 04-05 task 2,
/// UI-SPEC #21, T-04-21 / T-04-22, 04-RESEARCH V-1.1..V-1.10).
///
/// Every assertion in this file replaces an acceptance-criterion grep — a check
/// that runs ONCE, at execution, and never again. The three guarantees this
/// phase is safe to ship on are architectural rather than type-enforced:
///
/// 1. **Read-only.** No planner path writes, materializes an `IntakeLog` row,
///    or so much as names the materializing provider. Nothing in the type
///    system stops a future phase reintroducing that in one line (WR-06 is what
///    it costs at pager scale), so the guard has to be mechanical.
/// 2. **Single clock source.** `todayProvider` is the app's only clock; a
///    direct `DateTime.now()` in a planner file silently un-pins every test in
///    the suite and breaks the midnight rollover.
/// 3. **Editorial framing.** PLAN-04 is a liability boundary, and it is
///    enforced here over the RENDERED tree — the ARB-level half already lives
///    in `test/l10n/planner_copy_safety_test.dart`.
///
/// Comment stripping is not optional. Several planner files carry doc comments
/// that NAME the provider they must never import, precisely so the reason
/// survives; a gate that trips on its own documentation is a gate a team
/// deletes instead of the defect.
library;

import 'dart:io';

import 'package:boostque/core/db/database.dart' show BoostqueDb;
import 'package:boostque/core/domain/models.dart';
import 'package:boostque/core/l10n/l10n.dart';
import 'package:boostque/core/providers.dart';
import 'package:boostque/core/theme/theme.dart';
import 'package:boostque/core/today_controller.dart';
import 'package:boostque/core/widgets/bq_segmented.dart';
import 'package:boostque/features/calendar/planner_providers.dart';
import 'package:boostque/features/calendar/planner_screen.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Mockup content this phase deliberately does NOT ship, one entry per row of
/// the UI-SPEC's "Mockup Deviations Locked for v1" table.
///
/// ONE place to extend. Every entry is something a well-meaning later edit
/// could restore from the mockup without realizing it was excluded on purpose.
///
/// **Matching is CASE-SENSITIVE where an entry is capitalized, and that is
/// load-bearing.** `Зсунути` is the mockup's "Зсунути цикл" button label — a
/// schedule mutation on a read-only screen (M3). Its LOWERCASE form is an
/// ordinary verb approved copy could use in a sentence — `weekNoteOverLimit`,
/// deleted in phase 06, read "Варто зсунути старт частини з них". A
/// case-insensitive match would fire on correct, approved copy, and a gate
/// that cries wolf is a gate that gets deleted.
const excludedMockupContent = <({String text, String basis})>[
  (text: 'взаємодія', basis: 'M1 — the `є взаємодія` legend entry and the '
      'interaction claim behind it are never-ship (REQUIREMENTS Out of Scope)'),
  (text: 'жиророзчин', basis: 'M2 — the note this clause was truncated out of '
      'is itself deleted (PLAN-05), but the fat-soluble claim stays forbidden: '
      'the guarantee outlives the sentence it was attached to'),
  (text: 'Зсунути', basis: 'M3 — a schedule mutation on a read-only screen'),
  (text: 'Порівняти', basis: 'M3 — no compare-weeks action was ever scoped'),
  (text: 'Додати', basis: 'M4 — the add flow belongs to the Stack tab; the '
      'planner has no add control at all'),
  (text: 'Радник', basis: 'M5 — the Phase-1 three-tab shell renders instead'),
  (text: 'Профіль', basis: 'M5 — idem'),
];

/// True when [haystack] contains [needle], case-sensitively for a capitalized
/// needle and case-insensitively otherwise.
///
/// The same rule `planner_copy_safety_test.dart` applies at the ARB layer, so
/// the two halves of the PLAN-04 gate can never disagree about what a hit is.
bool containsExcluded(String haystack, String needle) {
  final first = String.fromCharCode(needle.runes.first);
  return first != first.toLowerCase()
      ? haystack.contains(needle)
      : haystack.toLowerCase().contains(needle.toLowerCase());
}

/// Every planner source file, resolved by GLOB rather than by a hardcoded
/// list: a ninth planner file added by a later phase is covered the day it
/// lands, with no one having to remember this test exists.
List<File> plannerSources() {
  final dir = Directory('lib/features/calendar');
  final files = dir
      .listSync()
      .whereType<File>()
      .where((f) {
        final name = f.uri.pathSegments.last;
        return name.startsWith('planner_') && name.endsWith('.dart');
      })
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  return files;
}

/// [source] with every comment line removed.
///
/// Line comments only, because this codebase writes no block comments — a fact
/// this function asserts on its own behalf below, so the day one appears the
/// gate says so instead of silently reading commentary as code.
String stripComments(String source) => source
    .split('\n')
    .where((line) {
      final t = line.trimLeft();
      return !t.startsWith('//');
    })
    .join('\n');

void main() {
  // -------------------------------------------------------------------
  // Source-level gates (UI-SPEC #21, Interaction Contract 6, T-04-21).
  // -------------------------------------------------------------------

  group('planner source invariants', () {
    late Map<String, String> sources;

    setUpAll(() {
      sources = {
        for (final file in plannerSources())
          file.path: stripComments(file.readAsStringSync()),
      };
    });

    test('the glob actually resolves the planner files — a gate over an empty '
        'file set is worse than no gate', () {
      expect(sources, isNotEmpty);
      expect(sources.length, greaterThanOrEqualTo(8),
          reason: 'the phase ships eight planner files (view model, providers, '
              'screen, gantt, load chart, week detail, year grid, month '
              'detail); a smaller set means the glob stopped matching');
      expect(
        sources.keys.any((p) => p.endsWith('planner_view_model.dart')),
        isTrue,
        reason: 'the pure view model must be inside the globbed set',
      );
    });

    test('no planner file carries a block comment, so line-comment stripping '
        'is a complete comment strip', () {
      sources.forEach((path, source) {
        expect(source.contains('/*'), isFalse,
            reason: '$path opens a block comment. The stripper only removes '
                'line comments, so a block comment could hide a forbidden '
                'reference from every gate below — either drop it or teach '
                'stripComments about it, never leave the gate half-blind');
      });
    });

    test('no planner file names the materializing path (Interaction Contract '
        '6, T-04-21, the WR-06 lesson)', () {
      const forbidden = <String, String>{
        'dayDosesProvider': 'the MATERIALIZING day provider — reading it once '
            'per rendered day would write a log row per slot per day across '
            'a four-month window (WR-06 at pager scale)',
        'dayDosesReadOnlyProvider': 'even the read-only day provider is out of '
            'bounds: the planner projects from `isActiveOn`, and a second '
            'source of daily truth is how the two screens start disagreeing',
        'ensureLogsForDay': 'the materializing call itself',
        'IntakeRepository': 'the write surface; the planner reaches '
            'stackEntriesProvider and todayProvider and nothing else',
        'intakeRepoProvider': 'idem, by provider',
      };

      final hits = <String>[];
      sources.forEach((path, source) {
        forbidden.forEach((needle, why) {
          if (source.contains(needle)) hits.add('$path references $needle');
        });
      });

      expect(hits, isEmpty,
          reason: 'the planner is a READ-ONLY projection. Nothing in the type '
              'system enforces that — one import is all it takes to undo it, '
              'and the cost is silent database growth a user never asked for. '
              'Forbidden: ${forbidden.keys.join(', ')}. Offenders: $hits');
    });

    test('no planner file reads the wall clock directly — todayProvider is '
        'the app\'s single clock source (PF-3)', () {
      const forbidden = <String>[
        'DateTime.now(',
        'DateTime.timestamp(',
        'clock.now(',
      ];

      final hits = <String>[];
      sources.forEach((path, source) {
        for (final needle in forbidden) {
          if (source.contains(needle)) hits.add('$path calls $needle');
        }
      });

      expect(hits, isEmpty,
          reason: 'a direct clock read un-pins the whole suite (every planner '
              'test fixes today through todayProvider) and breaks the '
              'midnight rollover, because the widget reading it never learns '
              'the day changed. Offenders: $hits');
    });

    test('no planner file contains a raw colour literal — every colour comes '
        'from a token or from the supplement\'s own stored value (D-07)', () {
      // `Colors.` is anchored so `BqColors.` — the sanctioned source — does not
      // match it. That anchoring is the whole difficulty of this gate.
      final literal = RegExp(
        r'Color\(0x|Color\.fromARGB|(^|[^A-Za-z0-9_])Colors\.',
        multiLine: true,
      );

      final hits = <String>[];
      sources.forEach((path, source) {
        for (final match in literal.allMatches(source)) {
          hits.add('$path: ${match.group(0)!.trim()}');
        }
      });

      expect(hits, isEmpty,
          reason: 'a hex literal or a Material named colour on these screens '
              'is a value that silently stops tracking the design system — '
              'the ONLY sanctioned non-token colour is Color(entry.supplement'
              '.colorValue), the user\'s own tag colour. Offenders: $hits');
    });

    test('no planner file paints a judgement colour — the risk, warn and calm '
        'families are gone from THESE files and only these (PLAN-05)', () {
      // **This gate is scoped to `planner_*.dart` ON PURPOSE, and the scope is
      // the assertion.** `lib/features/calendar/` also holds four Today-screen
      // surfaces whose state colours are legitimate and MUST survive:
      //   • dose_row.dart          — taken circle, warn border, overdue label
      //   • day_block_section.dart — all-taken tag, progress tag
      //   • day_progress_ring.dart — the ring counter
      //   • week_strip.dart        — today marker
      // A directory-wide glob is RED on correct code, and an executor
      // "fixing" it would strip the Today screen's state colours. If this
      // gate ever fires, the planner regained a verdict — fix the widget.
      // Do not widen the glob, and do not narrow the token list.
      final judgement = RegExp(r'BqColors\.(risk|warn|calm)');

      final hits = <String>[];
      sources.forEach((path, source) {
        for (final match in judgement.allMatches(source)) {
          hits.add('$path: ${match.group(0)}');
        }
      });

      expect(hits, isEmpty,
          reason: 'PLAN-05: the planner shows how much of the stack overlaps '
              'and never how good or bad that is. A judgement colour on a '
              'planner surface is a verdict without words — the exact thing '
              'this phase deleted. Offenders: $hits');
    });

    test('no planner file rebuilds a deleted judgement widget — the verdict '
        'chip, the slot pips, the threshold line and the over-bar (PLAN-05)',
        () {
      const forbidden = <String, String>{
        'week-verdict-chip': 'the verdict chip on the week-detail card',
        'week-pip-': 'the slot-pip row, whose whole subject was a denominator',
        '_SlotPips': 'the pip widget itself',
        'load-threshold': 'the comfort-3 dashed reference line',
        'load-over-': 'the over-limit bar segment',
        'thresholdDash': 'the reference line\'s colour token, deleted',
        'editorialLimit': 'the limit constant, deleted',
        'comfortLoad': 'the comfort constant, deleted',
        'verdictOf': 'the band resolver, deleted',
        // The resolver's RETURN TYPE, which was missing while the resolver
        // itself was listed. A gate that forbids the function but permits the
        // enum it returned is half a gate: the enum is the thing that made a
        // verdict expressible, and `verdictOf` is only one of the names that
        // could produce one.
        'LoadVerdict': 'the verdict enum itself, deleted',
      };

      final hits = <String>[];
      sources.forEach((path, source) {
        forbidden.forEach((needle, what) {
          if (source.contains(needle)) hits.add('$path names $needle ($what)');
        });
      });

      expect(hits, isEmpty,
          reason: 'PLAN-05 is proven by ABSENCE, and absence is only a '
              'guarantee while something checks for it. Each of these names '
              'belonged to a surface that judged the load; none of them has '
              'a legitimate reason to return. Offenders: $hits');
    });

    test('the pure view model imports EXACTLY the three domain libraries — no '
        'UI framework, no l10n, no persistence (P-1, T-04-01)', () {
      final source = sources.keys
          .where((p) => p.endsWith('planner_view_model.dart'))
          .map((p) => sources[p]!)
          .single;
      final imports = RegExp(r"^import '([^']+)'", multiLine: true)
          .allMatches(source)
          .map((m) => m.group(1)!)
          .toList()
        ..sort();

      expect(
        imports,
        const [
          'package:boostque/core/domain/cycle_math.dart',
          'package:boostque/core/domain/models.dart',
          'package:boostque/core/domain/repositories.dart',
        ],
        reason: 'the import list IS the proof that no materializing path is '
            'reachable from the model at all: with no persistence and no '
            'framework in scope, there is nothing to call. Adding a fourth '
            'import is the moment that stops being true, whatever the fourth '
            'one is',
      );
    });

    test('the pure view model restates no cycle-period arithmetic — activity '
        'is decided in exactly one place (PF-1)', () {
      final source = sources.keys
          .where((p) => p.endsWith('planner_view_model.dart'))
          .map((p) => sources[p]!)
          .single;

      for (final needle in const ['onDays', 'offDays', '%']) {
        expect(source.contains(needle), isFalse,
            reason: 'the model asks `isActiveOn` day by day and never '
                'recomputes the on/off formula. A second copy of that formula '
                'is a planner that disagrees with the Today screen the first '
                'time a regimen kind, a pre-start rule or a pause semantic '
                'changes — and it disagrees silently. Found: "$needle"');
      }
    });

    test('the pure view model holds no user-visible sentence — the renderer '
        'maps each shape to an ARB key (L10N-04)', () {
      final source = sources.keys
          .where((p) => p.endsWith('planner_view_model.dart'))
          .map((p) => sources[p]!)
          .single;
      final cyrillic = RegExp(r'[Ѐ-ӿ]');

      expect(cyrillic.hasMatch(source), isFalse,
          reason: 'a Cyrillic character in the comment-stripped model means uk '
              'copy has leaked out of the ARB layer and into code no '
              'localization delegate can reach — untranslatable, and invisible '
              'to the PLAN-04 copy gate that reads the ARB');
    });
  });

  // -------------------------------------------------------------------
  // Rendered-tree gates (PLAN-04, T-04-22, and the phase's headline
  // read-only promise proven through the real widget tree).
  // -------------------------------------------------------------------

  group('planner rendered-tree invariants', () {
    final today = DateTime.utc(2026, 8, 13);
    late BoostqueDb db;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    ProviderContainer makeContainer() {
      return ProviderContainer(
        overrides: [
          dbProvider.overrideWith((ref) {
            final database = BoostqueDb.forTesting(NativeDatabase.memory());
            ref.onDispose(database.close);
            db = database;
            return database;
          }),
          todayProvider.overrideWith(() => _FixedToday(today)),
        ],
      );
    }

    Widget plannerApp(ProviderContainer container, String locale) {
      return UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: Locale(locale),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: bqTheme(),
          home: const PlannerScreen(),
        ),
      );
    }

    void usePhoneSurface(WidgetTester tester) {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
    }

    /// Never `pumpAndSettle`: the midnight timer is permanently pending.
    Future<void> pumpUntil(
      WidgetTester tester,
      bool Function() condition,
      String what,
    ) async {
      for (var i = 0; i < 200; i++) {
        await tester.pump(const Duration(milliseconds: 10));
        if (condition()) return;
      }
      fail('Timed out waiting for $what');
    }

    Future<void> tearDownTree(
      WidgetTester tester,
      ProviderContainer container,
    ) async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 10));
      container.dispose();
      await tester.pump(const Duration(milliseconds: 10));
      await tester.pump(const Duration(milliseconds: 10));
    }

    Finder byKeyPrefix(String prefix) => find.byWidgetPredicate((w) {
          final key = w.key;
          return key is ValueKey<String> && key.value.startsWith(prefix);
        });

    Future<void> scrollBody(WidgetTester tester, double dy) async {
      await tester.drag(find.byType(ListView), Offset(0, -dy));
      await tester.pump();
    }

    /// A stack with a cycle, a paused cycle and a course, so the gantt, the
    /// chart, the grid and both detail cards all have something to draw.
    Future<void> seed(ProviderContainer container) async {
      final supplements = container.read(supplementRepoProvider);
      final regimens = container.read(regimenRepoProvider);
      for (var i = 0; i < 3; i++) {
        await supplements.upsert(
          Supplement(
            id: 'i$i',
            name: 'Добавка $i',
            doseText: '1 капс.',
            colorValue: 0xFF6B6FA8,
            note: '',
          ),
        );
      }
      await regimens.upsert(
        Regimen(
          id: 'ir0',
          supplementId: 'i0',
          kind: RegimenKind.cyclic,
          startDate: DateTime.utc(2026, 8, 1),
          endDate: null,
          onDays: 14,
          offDays: 14,
          paused: false,
          slots: const [
            DoseSlot(id: 'is', minutesFromMidnight: 480, doseLabel: '1 капс.'),
          ],
        ),
      );
      await regimens.upsert(
        Regimen(
          id: 'ir1',
          supplementId: 'i1',
          kind: RegimenKind.cyclic,
          startDate: DateTime.utc(2026, 8, 1),
          endDate: null,
          onDays: 28,
          offDays: 0,
          paused: true,
          slots: const [
            DoseSlot(id: 'is', minutesFromMidnight: 600, doseLabel: '1 капс.'),
          ],
        ),
      );
      await regimens.upsert(
        Regimen(
          id: 'ir2',
          supplementId: 'i2',
          kind: RegimenKind.course,
          startDate: DateTime.utc(2026, 8, 5),
          endDate: DateTime.utc(2026, 9, 30),
          onDays: 0,
          offDays: 0,
          paused: false,
          slots: const [
            DoseSlot(id: 'is', minutesFromMidnight: 540, doseLabel: '1 крапля'),
          ],
        ),
      );
    }

    /// Every string currently in the tree, from `Text` widgets of any shape.
    List<String> renderedText(WidgetTester tester) => tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data ?? t.textSpan?.toPlainText() ?? '')
        .where((s) => s.isNotEmpty)
        .toList();

    void expectNoExcludedContent(WidgetTester tester, String where) {
      final strings = renderedText(tester);
      final hits = <String>[];
      for (final excluded in excludedMockupContent) {
        for (final rendered in strings) {
          if (containsExcluded(rendered, excluded.text)) {
            hits.add('$where renders "${excluded.text}" '
                '(${excluded.basis}) inside "$rendered"');
          }
        }
      }

      expect(hits, isEmpty,
          reason: 'the "Mockup Deviations Locked for v1" table is not '
              'commentary — each row is content the mockup contains and this '
              'app deliberately does not. Restoring any of it ships an '
              'interaction or pharmacological claim, or a schedule-mutating '
              'control on a read-only screen. Offenders: $hits');
    }

    for (final tag in const ['uk', 'en']) {
      testWidgets('$tag: no excluded mockup content is reachable on either '
          'segment, and the disclaimer closes both (PLAN-04, M1-M5, M9)',
          (tester) async {
        usePhoneSurface(tester);
        final container = makeContainer();
        await seed(container);
        final l10n = await AppLocalizations.delegate.load(Locale(tag));

        await tester.pumpWidget(plannerApp(container, tag));
        await pumpUntil(
          tester,
          () => find.byType(BqSegmented).evaluate().isNotEmpty,
          'the planner header in $tag',
        );
        await pumpUntil(
          tester,
          () => byKeyPrefix('gantt-legend-').evaluate().isNotEmpty,
          'the Цикли body in $tag',
        );

        expect(byKeyPrefix('gantt-legend-'), findsNWidgets(3),
            reason: 'the legend ships THREE entries. A fourth is M1\'s '
                '`є взаємодія` — an interaction claim this app never makes');
        expect(find.byType(FloatingActionButton), findsNothing,
            reason: 'M4: the mockup\'s "+ Додати" belongs to the Stack tab. An '
                'add control on a read-only projection would promise a write '
                'this screen cannot perform');
        expectNoExcludedContent(tester, '$tag Цикли (above the fold)');

        // The disclaimer closes the body, so it needs the body scrolled.
        await scrollBody(tester, 600);
        expect(find.text(l10n.plannerDisclaimer), findsOneWidget,
            reason: 'PLAN-04\'s positive half: Цикли closes with the '
                'editorial framing of the 5-substance limit');
        expectNoExcludedContent(tester, '$tag Цикли (below the fold)');

        await tester.tap(find.text(l10n.plannerSegYear));
        await tester.pump();
        await pumpUntil(
          tester,
          () => byKeyPrefix('month-card-').evaluate().isNotEmpty,
          'the year grid in $tag',
        );
        expectNoExcludedContent(tester, '$tag Рік (above the fold)');

        await scrollBody(tester, 600);
        expect(find.text(l10n.plannerDisclaimer), findsOneWidget,
            reason: 'M9/DECIDED-8: the mockup\'s Year footnote carries no '
                'disclaimer, and PLAN-04 requires one on EVERY planner '
                'surface — both segments render the same key');
        expectNoExcludedContent(tester, '$tag Рік (below the fold)');
        expect(tester.takeException(), isNull);

        await tearDownTree(tester, container);
      });
    }

    testWidgets('a rendered pass over both segments, including a week '
        'selection and a month selection, writes NOT ONE IntakeLog row '
        '(T-04-21, UI-SPEC #21)', (tester) async {
      usePhoneSurface(tester);
      final container = makeContainer();
      await seed(container);

      await tester.pumpWidget(plannerApp(container, 'uk'));
      await pumpUntil(
        tester,
        () => byKeyPrefix('load-week-').evaluate().isNotEmpty,
        'the load chart columns',
      );

      final before = (await db.select(db.intakeLogs).get()).length;
      expect(before, 0,
          reason: 'the planner alone materializes nothing at all — this is '
              'the baseline the rest of the test is measured against');

      await scrollBody(tester, 300);
      // `warnIfMissed: false`: the keyed `Stack` holds its bars at the BOTTOM
      // of the column, so a low-load week has no painted child under the
      // centre point. The tap target is the opaque `GestureDetector` spanning
      // the whole column above it — which is exactly DECIDED-10's mitigation
      // for a ~15px-wide column, not a missed tap.
      await tester.tap(
        find.byKey(const ValueKey('load-week-5')),
        warnIfMissed: false,
      );
      await tester.pump();
      expect(container.read(resolvedWeekIndexProvider), 5);

      await tester.tap(find.text('Рік'));
      await tester.pump();
      await pumpUntil(
        tester,
        () => byKeyPrefix('month-card-').evaluate().isNotEmpty,
        'the year grid',
      );
      await tester.tap(find.byKey(const ValueKey('month-card-3')));
      await tester.pump();
      expect(container.read(resolvedMonthIndexProvider), 3);

      await tester.tap(find.text('Цикли'));
      await tester.pump();
      // Give any stray materialization a generous chance to land.
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 10));
      }

      expect((await db.select(db.intakeLogs).get()).length, before,
          reason: 'the source-level gate above proves no planner file NAMES '
              'the materializing path; this one proves the finished widget '
              'tree does not reach it through any other seam either. Both '
              'halves are needed — a grep cannot see a transitive call, and a '
              'row count cannot see an import that is not exercised yet');

      await tearDownTree(tester, container);
    });
  });
}

/// Pins `todayProvider` to a fixed calendar day.
class _FixedToday extends TodayController {
  _FixedToday(this.day);

  final DateTime day;

  @override
  DateTime build() => day;
}
