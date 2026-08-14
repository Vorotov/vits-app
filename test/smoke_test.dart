import 'package:boostque/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('app boots inside ProviderScope and renders a MaterialApp',
      (tester) async {
    await tester.pumpWidget(const ProviderScope(child: BoostqueApp()));
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
