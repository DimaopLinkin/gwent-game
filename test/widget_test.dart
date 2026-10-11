import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gwent/main.dart';

void main() {
  testWidgets('приложение запускается и показывает генератор UUID', (tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.byType(FloatingActionButton), findsOneWidget);
    expect(find.text('Press the button to generate a UUID'), findsOneWidget);
  });
}
