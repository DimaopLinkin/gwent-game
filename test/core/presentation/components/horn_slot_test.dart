import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gwent/src/core/presentation/components/horn_slot.dart';

import '../../../support/localized_app.dart';

void main() {
  testWidgets('тап-зона 44×44 при мини-карте 31×44 в любом состоянии', (tester) async {
    for (final look in HornSlotLook.values) {
      await tester.pumpWidget(
        localizedApp(
          Center(
            child: HornSlot(look: look, effectName: 'Командирский рог', onTap: () {}),
          ),
        ),
      );
      expect(tester.getSize(find.byType(HornSlot)), const Size.square(44), reason: '$look');
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull, reason: '$look');
    }
  });

  testWidgets('цель пульсирует, а при «уменьшить движение» нет', (tester) async {
    await tester.pumpWidget(localizedApp(const Center(child: HornSlot(look: HornSlotLook.target))));
    await tester.pump();
    expect(tester.hasRunningAnimations, isTrue);

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: localizedApp(const Center(child: HornSlot(look: HornSlotLook.target))),
      ),
    );
    await tester.pump();
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('нажатие работает, подпись зависит от состояния', (tester) async {
    final semantics = tester.ensureSemantics();
    var taps = 0;
    await tester.pumpWidget(
      localizedApp(
        Center(
          child: HornSlot(look: HornSlotLook.target, onTap: () => taps++),
        ),
      ),
    );
    await tester.tap(find.byType(HornSlot));
    expect(taps, 1);
    expect(find.bySemanticsLabel('Положить Командирский рог в этот ряд'), findsOneWidget);

    await tester.pumpWidget(localizedApp(const Center(child: HornSlot(look: HornSlotLook.empty))));
    expect(find.bySemanticsLabel('Слот рога: пусто'), findsOneWidget);

    await tester.pumpWidget(
      localizedApp(
        const Center(
          child: HornSlot(look: HornSlotLook.filled, effectName: 'Мардрём'),
        ),
      ),
    );
    expect(find.bySemanticsLabel('Слот рога: Мардрём'), findsOneWidget);
    semantics.dispose();
  });
}
