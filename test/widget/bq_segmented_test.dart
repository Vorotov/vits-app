import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vitomy/core/theme/theme.dart';
import 'package:vitomy/core/widgets/bq_segmented.dart';

/// BqSegmented (02-RESEARCH.md P-10): tap selection via callback, Semantics
/// selected flag tracks selectedIndex, and long uk labels never overflow at a
/// 390-wide phone surface.
void main() {
  const List<String> ukLabels = ['Пошук у базі', 'Разовий курс'];

  Widget host({
    required int selectedIndex,
    required ValueChanged<int> onChanged,
  }) {
    return MaterialApp(
      theme: bqTheme(),
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsetsDirectional.symmetric(horizontal: 20),
          child: BqSegmented(
            labels: ukLabels,
            selectedIndex: selectedIndex,
            onChanged: onChanged,
          ),
        ),
      ),
    );
  }

  testWidgets('tapping a segment reports its index via onChanged',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final List<int> changes = [];
    await tester.pumpWidget(
      host(selectedIndex: 0, onChanged: changes.add),
    );

    await tester.tap(find.bySemanticsLabel('Разовий курс'));
    await tester.pump();

    expect(changes, [1]);
  });

  testWidgets('Semantics selected flag moves with selectedIndex',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final SemanticsHandle handle = tester.ensureSemantics();

    await tester.pumpWidget(host(selectedIndex: 0, onChanged: (_) {}));

    expect(
      tester.getSemantics(find.bySemanticsLabel('Пошук у базі')),
      isSemantics(isSelected: true, isButton: true),
    );
    expect(
      tester.getSemantics(find.bySemanticsLabel('Разовий курс')),
      isSemantics(isSelected: false, isButton: true),
    );

    // Parent moves the selection to index 1 — flags must swap.
    await tester.pumpWidget(host(selectedIndex: 1, onChanged: (_) {}));

    expect(
      tester.getSemantics(find.bySemanticsLabel('Пошук у базі')),
      isSemantics(isSelected: false, isButton: true),
    );
    expect(
      tester.getSemantics(find.bySemanticsLabel('Разовий курс')),
      isSemantics(isSelected: true, isButton: true),
    );

    handle.dispose();
  });

  testWidgets('long uk labels at 390 width cause no overflow', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(host(selectedIndex: 0, onChanged: (_) {}));

    expect(find.text('Пошук у базі'), findsOneWidget);
    expect(find.text('Разовий курс'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
