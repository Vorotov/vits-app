import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:boostque/core/theme/theme.dart';
import 'package:boostque/core/theme/tokens.dart';
import 'package:boostque/core/widgets/bq_nav_bar.dart';

import '../../support/locale_matrix.dart';

/// The `BqNavBar` contract (plan 06-01, NAV-01).
///
/// Four claims are asserted here that a rendered-only test cannot make:
///
/// 1. **The extent is a FUNCTION.** Three cases call [navBarHeightFor]
///    directly, with no `pumpWidget` in their body — that is the entire point
///    of splitting the height into a fixed and a scaled constant, and it is
///    what makes the 56dp target checkable without a device window.
/// 2. **Activation goes through the semantics action**, never a coordinate
///    tap. A coordinate tap passes whether or not `onTap` sits on the
///    `Semantics` node, so it is not evidence for the WR-02 contract; the
///    only assertion that discriminates is `performAction`.
/// 3. **The bar is static** — asserted as an absence, not claimed in prose.
/// 4. **No fixed-width box wraps a label** — the v1 66px destination column
///    is gone, and a test is what keeps it gone.
void main() {
  const List<BqNavDestination> destinations = <BqNavDestination>[
    BqNavDestination(
      icon: Icons.inventory_2_outlined,
      selectedIcon: Icons.inventory_2,
      label: 'Stack',
    ),
    BqNavDestination(
      icon: Icons.calendar_today_outlined,
      selectedIcon: Icons.calendar_today,
      label: 'Calendar',
    ),
    BqNavDestination(
      icon: Icons.settings_outlined,
      selectedIcon: Icons.settings,
      label: 'Settings',
    ),
  ];

  /// The bar alone, in a real `Scaffold` slot so its layout constraints match
  /// the shell's, with the selected index and the tap sink injected.
  Widget barApp({
    int selectedIndex = 0,
    ValueChanged<int>? onSelected,
    TextScaler? textScaler,
  }) {
    return MaterialApp(
      theme: bqTheme(),
      builder: (context, child) => textScaler == null
          ? child!
          : MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: textScaler),
              child: child!,
            ),
      home: Scaffold(
        bottomNavigationBar: BqNavBar(
          destinations: destinations,
          selectedIndex: selectedIndex,
          onSelected: onSelected ?? (_) {},
        ),
      ),
    );
  }

  Finder labelIn(String text) =>
      find.descendant(of: find.byType(BqNavBar), matching: find.text(text));

  TextStyle resolvedLabelStyle(WidgetTester tester, String text) =>
      tester.widget<Text>(labelIn(text)).style!;

  // ---------------------------------------------------------------------
  // The extent function — no widget pumped in this group at all.
  // ---------------------------------------------------------------------

  group('navBarHeightFor (NAV-01)', () {
    test('is exactly 56.0 at text scale 1.0', () {
      expect(navBarHeightFor(TextScaler.noScaling), 56.0,
          reason: 'the mockup-exact base height, down from v1\'s 80dp — 44 '
              'fixed (8 pad + 22 icon + 4 gap + 10 pad) + a 12px label box');
      expect(navBarHeightFor(TextScaler.linear(1.0)), 56.0,
          reason: 'linear(1.0) and noScaling must agree — a formula that only '
              'holds for one of them is scaling something it should not');
    });

    test('is strictly increasing across 1.0 -> 1.6 -> 2.0', () {
      final double at1 = navBarHeightFor(TextScaler.linear(1.0));
      final double at16 = navBarHeightFor(TextScaler.linear(1.6));
      final double at2 = navBarHeightFor(TextScaler.linear(2.0));
      expect(at16, greaterThan(at1));
      expect(at2, greaterThan(at16),
          reason: 'a bar that stops growing starts clipping — this is the '
              'CR-01 defect class the codebase paid for at the week strip '
              'and again at the year grid');
    });

    test('is exactly 68.0 at text scale 2.0 — the fixed part does NOT scale',
        () {
      expect(navBarHeightFor(TextScaler.linear(2.0)), 68.0,
          reason: '44 + 2.0 x 12. If this were 112 the whole 56 was being '
              'multiplied, over-reserving for a 22dp Icon that takes its size '
              'from IconThemeData and never follows the text scaler');
    });
  });

  // ---------------------------------------------------------------------
  // Styling, chrome and layout.
  // ---------------------------------------------------------------------

  group('selected / unselected styling', () {
    testWidgets('the selected label is accent at w600, the other two textFaint '
        'at w400', (tester) async {
      await tester.pumpWidget(barApp(selectedIndex: 1));

      final TextStyle middle = resolvedLabelStyle(tester, 'Calendar');
      expect(middle.color, BqColors.accent);
      expect(middle.fontWeight, FontWeight.w600);
      expect(middle.fontSize, 10);
      expect(middle.height, 1.2,
          reason: '10 x 1.2 is the 12px line box navBarHeightFor reserves — '
              'if the two drift apart the extent stops matching the content');

      for (final String other in const ['Stack', 'Settings']) {
        final TextStyle style = resolvedLabelStyle(tester, other);
        expect(style.color, BqColors.textFaint, reason: other);
        expect(style.fontWeight, FontWeight.w400, reason: other);
        expect(style.fontSize, 10, reason: other);
      }
    });

    testWidgets('the icons take the same colour split, at 22dp',
        (tester) async {
      await tester.pumpWidget(barApp(selectedIndex: 1));

      final List<Icon> icons = tester
          .widgetList<Icon>(
            find.descendant(
              of: find.byType(BqNavBar),
              matching: find.byType(Icon),
            ),
          )
          .toList();
      expect(icons, hasLength(3));
      expect(icons.map((i) => i.color).toList(), <Color>[
        BqColors.textFaint,
        BqColors.accent,
        BqColors.textFaint,
      ]);
      expect(icons.map((i) => i.size).toList(), const <double>[22, 22, 22]);
      expect(icons[1].icon, Icons.calendar_today,
          reason: 'the selected destination shows its FILLED glyph');
      expect(icons[0].icon, Icons.inventory_2_outlined,
          reason: 'the unselected ones show their outlined glyph');
    });

    testWidgets('the chrome is a surfaceAlt fill with a 1px hairline top '
        'border', (tester) async {
      await tester.pumpWidget(barApp());

      final BoxDecoration decoration = tester
          .widgetList<DecoratedBox>(
            find.descendant(
              of: find.byType(BqNavBar),
              matching: find.byType(DecoratedBox),
            ),
          )
          .map((d) => d.decoration)
          .whereType<BoxDecoration>()
          .firstWhere((d) => d.color == BqColors.surfaceAlt);

      final Border border = decoration.border! as Border;
      expect(border.top.color, BqColors.hairline);
      expect(border.top.width, 1);
      expect(border.bottom, BorderSide.none,
          reason: 'the bar is flat chrome, not a boxed card');
    });

    testWidgets('the painted extent is navBarHeightFor, border included — a '
        'Container border would have added a 57th pixel', (tester) async {
      await tester.pumpWidget(barApp());
      expect(tester.getSize(find.byType(BqNavBar)).height,
          navBarHeightFor(TextScaler.noScaling));

      await tester.pumpWidget(barApp(textScaler: TextScaler.linear(2.0)));
      expect(tester.getSize(find.byType(BqNavBar)).height,
          navBarHeightFor(TextScaler.linear(2.0)));
      expect(tester.takeException(), isNull, reason: overflowReason);
    });

    testWidgets('press feedback paints INSIDE the bar: the InkResponses have a '
        'Material of their own, above the surfaceAlt fill (CR-01)',
        (tester) async {
      await tester.pumpWidget(barApp());

      final Finder barMaterial = find.descendant(
        of: find.byType(BqNavBar),
        matching: find.byType(Material),
      );
      expect(
        barMaterial,
        findsOneWidget,
        reason: 'without a Material inside the bar the InkResponses register '
            'their splash on the Scaffold\'s root Material, whose ink layer '
            'paints BEFORE the whole child subtree — i.e. behind this bar\'s '
            'fully opaque surfaceAlt fill. Invisible press feedback.',
      );

      // Not merely "a Material exists": the layer the ink actually registers
      // on must be that one. Before the fix `Material.of` here resolved to the
      // Scaffold's full-screen root Material.
      final BuildContext inkContext = tester.element(
        find
            .descendant(
              of: find.byType(BqNavBar),
              matching: find.byType(InkResponse),
            )
            .first,
      );
      final RenderBox inkLayer = Material.of(inkContext) as RenderBox;
      expect(
        inkLayer.size.height,
        closeTo(tester.getSize(find.byType(BqNavBar)).height, 0.01),
        reason: 'the ink layer is the BAR, not the screen — a full-screen '
            'height here is the Scaffold\'s root Material',
      );

      // And a real splash lands on it. `paints` inspects the recorded canvas,
      // which is the only evidence a callback-only test cannot fake.
      final TestGesture gesture =
          await tester.startGesture(tester.getCenter(labelIn('Calendar')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      expect(barMaterial, paints..circle());
      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('each destination sits in an equal-width Expanded cell and no '
        'ancestor of a label bounds its width', (tester) async {
      await tester.pumpWidget(barApp());

      // Three Expanded cells, one per destination.
      expect(
        find.descendant(
          of: find.byType(BqNavBar),
          matching: find.byType(Expanded),
        ),
        findsNWidgets(3),
      );

      // Equal widths: the bar's width less the 22 + 22 horizontal override,
      // split three ways. A 66px destination column would fail here.
      final double barWidth = tester.getSize(find.byType(BqNavBar)).width;
      final double cell = (barWidth - 44) / 3;
      for (final String label in const ['Stack', 'Calendar', 'Settings']) {
        expect(
          tester
              .getSize(find.ancestor(
                of: labelIn(label),
                matching: find.byType(InkResponse),
              ))
              .width,
          closeTo(cell, 0.01),
          reason: label,
        );
      }

      // And nothing between a label and the bar pins a width. The bar's own
      // SizedBox sets height only; a width here would be the v1 66px column
      // reappearing as a fixed-size text container.
      for (final SizedBox box in tester.widgetList<SizedBox>(
        find.ancestor(of: labelIn('Settings'), matching: find.byType(SizedBox)),
      )) {
        expect(box.width, isNull);
      }
      for (final Container container in tester.widgetList<Container>(
        find.ancestor(of: labelIn('Settings'), matching: find.byType(Container)),
      )) {
        expect(container.constraints?.hasBoundedWidth ?? false, isFalse);
      }
    });

    testWidgets('the labels never wrap and never shrink', (tester) async {
      await tester.pumpWidget(barApp(textScaler: TextScaler.linear(2.0)));

      for (final String label in const ['Stack', 'Calendar', 'Settings']) {
        final Text text = tester.widget<Text>(labelIn(label));
        expect(text.maxLines, 1, reason: label);
        expect(text.softWrap, isFalse, reason: label);
      }
      // No shrink-to-fit backstop: the v1 spec's is void (UI-SPEC
      // Supersedes). A clipped cell means the extent constants are wrong.
      expect(
        find.descendant(
          of: find.byType(BqNavBar),
          matching: find.byType(FittedBox),
        ),
        findsNothing,
      );
      expect(tester.takeException(), isNull, reason: overflowReason);
    });
  });

  // ---------------------------------------------------------------------
  // Assistive-technology activation (WR-02).
  // ---------------------------------------------------------------------

  group('semantics activation (WR-02)', () {
    testWidgets('every destination is a button reporting its selected state',
        (tester) async {
      await tester.pumpWidget(barApp(selectedIndex: 1));

      expect(tester.getSemantics(labelIn('Stack')),
          isSemantics(isButton: true, isSelected: false, hasTapAction: true));
      expect(tester.getSemantics(labelIn('Calendar')),
          isSemantics(isButton: true, isSelected: true, hasTapAction: true));
      expect(tester.getSemantics(labelIn('Settings')),
          isSemantics(isButton: true, isSelected: false, hasTapAction: true));
    });

    testWidgets('each node carries its own tap action under excludeSemantics',
        (tester) async {
      await tester.pumpWidget(barApp());

      for (final String label in const ['Stack', 'Calendar', 'Settings']) {
        expect(
          tester
              .getSemantics(labelIn(label))
              .getSemanticsData()
              .hasAction(SemanticsAction.tap),
          isTrue,
          reason: '`excludeSemantics: true` drops every DESCENDANT action, so '
              'the destination node has to carry one itself — without it the '
              'bar announces three buttons VoiceOver and TalkBack cannot '
              'press, while passing every coordinate-tap test ($label)',
        );
      }
    });

    testWidgets('activating a destination through SemanticsAction.tap reports '
        'its index — not a coordinate tap', (tester) async {
      final List<int> selections = <int>[];
      await tester.pumpWidget(barApp(onSelected: selections.add));

      // Assistive technology does not tap widgets. It activates actions.
      tester.semantics.performAction(
        find.semantics.byLabel('Settings'),
        SemanticsAction.tap,
      );
      await tester.pump();
      expect(selections, <int>[2]);

      tester.semantics.performAction(
        find.semantics.byLabel('Calendar'),
        SemanticsAction.tap,
      );
      await tester.pump();
      expect(selections, <int>[2, 1]);
    });

    testWidgets('activating the ALREADY-SELECTED destination still reports it',
        (tester) async {
      final List<int> selections = <int>[];
      await tester.pumpWidget(
        barApp(selectedIndex: 0, onSelected: selections.add),
      );

      tester.semantics.performAction(
        find.semantics.byLabel('Stack'),
        SemanticsAction.tap,
      );
      await tester.pump();

      expect(selections, <int>[0],
          reason: 'the press must still register on the selected tab — the '
              'reason press feedback is InkResponse rather than an opacity '
              'change tied to selection');
      expect(tester.takeException(), isNull);
    });
  });

  // ---------------------------------------------------------------------
  // The bar is STATIC — asserted as an absence.
  // ---------------------------------------------------------------------

  group('static render', () {
    testWidgets('all three destinations render on the FIRST frame, with no '
        'provider scope and no async source', (tester) async {
      // One pump, no settle: whatever is on screen here is what the user
      // sees at frame zero.
      await tester.pumpWidget(barApp());

      expect(labelIn('Stack'), findsOneWidget);
      expect(labelIn('Calendar'), findsOneWidget);
      expect(labelIn('Settings'), findsOneWidget);
      expectNoCyrillicWhileEn(tester);
    });

    testWidgets('no loading, error or async surface exists in the subtree',
        (tester) async {
      await tester.pumpWidget(barApp());

      final Finder bar = find.byType(BqNavBar);
      expect(
        find.descendant(
            of: bar, matching: find.byType(CircularProgressIndicator)),
        findsNothing,
        reason: 'the bar has nothing to wait for — a spinner here would mean '
            'a data source crept into static chrome',
      );
      expect(
        find.descendant(of: bar, matching: find.byType(ProgressIndicator)),
        findsNothing,
      );
      expect(
        find.descendant(of: bar, matching: find.byType(FutureBuilder<Object?>)),
        findsNothing,
      );
      expect(
        find.descendant(of: bar, matching: find.byType(StreamBuilder<Object?>)),
        findsNothing,
      );
      // Exactly three Text widgets: the three labels and no error copy.
      expect(
        find.descendant(of: bar, matching: find.byType(Text)),
        findsNWidgets(3),
      );
    });
  });
}
