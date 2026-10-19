import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gwent/src/core/presentation/components/gwent_overlay.dart';

import '../../../support/localized_app.dart';
import '../../../support/screen_guards.dart';

void main() {
  testWidgets('оверлей даёт тексту Material: отладочного стиля нет', (tester) async {
    await tester.pumpWidget(
      localizedApp(
        Builder(
          builder: (context) => TextButton(
            onPressed: () => showGwentOverlay<void>(context, builder: (context) => const Center(child: Text('внутри'))),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('внутри'), findsOneWidget);
    expect(find.ancestor(of: find.text('внутри'), matching: find.byType(Material)), findsWidgets);
    expectNoFallbackTextStyle(tester);
  });
}
