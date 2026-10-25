import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gwent/src/core/presentation/components/horn_slot.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_icon.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_icon_view.dart';

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

  testWidgets('цель не мигает: слабая и яркая подсветка статичны', (tester) async {
    for (final look in [HornSlotLook.target, HornSlotLook.ghost]) {
      await tester.pumpWidget(
        localizedApp(
          Center(
            child: HornSlot(look: look, ghostLabel: '×2'),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      expect(tester.hasRunningAnimations, isFalse, reason: '$look');
    }
  });

  testWidgets('призрак: подпись только у яркого призрака, значок сброса только над занятым слотом', (tester) async {
    await tester.pumpWidget(
      localizedApp(
        const Center(
          child: HornSlot(look: HornSlotLook.target, ghostLabel: '×2'),
        ),
      ),
    );
    expect(find.text('×2'), findsNothing, reason: 'слабая цель без подписи');

    await tester.pumpWidget(
      localizedApp(
        const Center(
          child: HornSlot(look: HornSlotLook.ghost, ghostLabel: '×2'),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('×2'), findsOneWidget);
    expect(find.byWidgetPredicate((w) => w is GwentIconView && w.icon == GwentIcon.iconDiscard), findsNothing);

    await tester.pumpWidget(
      localizedApp(
        const Center(
          child: HornSlot(look: HornSlotLook.ghostReplace, effectName: 'Командирский рог'),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byWidgetPredicate((w) => w is GwentIconView && w.icon == GwentIcon.iconDiscard), findsOneWidget);
    expect(find.text('×2'), findsNothing);
  });

  testWidgets('смена вида слота перетекает, а не щёлкает: старый вид гаснет вместе с рамкой ряда', (tester) async {
    await tester.pumpWidget(
      localizedApp(
        const Center(
          child: HornSlot(look: HornSlotLook.ghost, ghostLabel: '×2'),
        ),
      ),
    );
    await tester.pumpWidget(
      localizedApp(
        const Center(
          child: HornSlot(look: HornSlotLook.target, ghostLabel: '×2'),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 60));
    expect(find.text('×2'), findsOneWidget, reason: 'на середине перехода прежний вид ещё виден');
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('×2'), findsNothing);
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
