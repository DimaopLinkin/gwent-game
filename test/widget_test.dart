import 'package:flutter/material.dart';
import 'package:flutter_game_test_21_05_2026/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('приложение запускается и показывает генератор UUID', (tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.byType(FloatingActionButton), findsOneWidget);
    expect(find.text('Press the button to generate a UUID'), findsOneWidget);
  });
}
