import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gwent/src/core/presentation/components/pass_button.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_colors.dart';

import '../../../support/localized_app.dart';

void main() {
  Future<void> pump(WidgetTester tester, PassButton button) => tester.pumpWidget(localizedApp(Center(child: button)));

  testWidgets('высота 56 pt, ширина не меньше 156 pt', (tester) async {
    await pump(tester, PassButton(onPressed: () {}));
    final size = tester.getSize(find.byType(PassButton));
    expect(size.height, PassButton.height);
    expect(size.width, greaterThanOrEqualTo(156));
  });

  testWidgets('двойная рамка идёт по всему контуру: 3 pt фона и 1 pt латуни внутри золотого кольца', (tester) async {
    Future<void> check({required bool enabled, required Color ring}) async {
      await pump(tester, PassButton(onPressed: () {}, enabled: enabled));
      final button = tester.getRect(find.byType(PassButton));
      final layers = find
          .descendant(of: find.byType(PassButton), matching: find.byType(DecoratedBox))
          .evaluate()
          .map((element) => element.widget as DecoratedBox)
          .where((box) => box.decoration is ShapeDecoration)
          .toList();
      expect(layers.map((box) => (box.decoration as ShapeDecoration).shape), [
        const StadiumBorder(side: BorderSide(color: GwentColors.bg, width: 3)),
        StadiumBorder(side: BorderSide(color: ring)),
      ]);
      final outer = tester.getRect(find.byWidget(layers[0]));
      final inner = tester.getRect(find.byWidget(layers[1]));
      expect(outer, button);
      expect(inner, button.deflate(3));
    }

    await check(enabled: true, ring: GwentColors.brass);
    await check(enabled: false, ring: GwentColors.surfaceRaised);
  });

  testWidgets('с подтверждением тап сразу вызывает колбэк, диалог открывает экран', (tester) async {
    var passes = 0;
    await pump(tester, PassButton(onPressed: () => passes++));
    await tester.tap(find.byType(PassButton));
    expect(passes, 1);
  });

  testWidgets('не ваш ход: тап ничего не делает', (tester) async {
    var passes = 0;
    await pump(tester, PassButton(onPressed: () => passes++, enabled: false));
    await tester.tap(find.byType(PassButton));
    await tester.pump(const Duration(seconds: 2));
    expect(passes, 0);
  });

  group('удержание', () {
    final haptics = <String>[];

    setUp(() {
      haptics.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'HapticFeedback.vibrate') haptics.add('${call.arguments}');
          return null;
        },
      );
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      );
    });

    testWidgets('держим секунду: пас и лёгкая вибрация', (tester) async {
      var passes = 0;
      await pump(tester, PassButton(onPressed: () => passes++, holdToPass: true));
      final gesture = await tester.startGesture(tester.getCenter(find.byType(PassButton)));
      await tester.pump(const Duration(milliseconds: 500));
      expect(passes, 0);
      expect(find.text('Удерживайте 1 с'), findsOneWidget);
      // onTapDown приходит через 100 мс после касания (kPressTimeout), а заливка стартует на следующем кадре.
      await tester.pump(const Duration(milliseconds: 1100));
      expect(passes, 1);
      expect(haptics, ['HapticFeedbackType.lightImpact']);
      await gesture.up();
      await tester.pump();
      expect(passes, 1);
    });

    testWidgets('отпустили раньше: отмена, подсказка исчезает', (tester) async {
      var passes = 0;
      await pump(tester, PassButton(onPressed: () => passes++, holdToPass: true));
      final gesture = await tester.startGesture(tester.getCenter(find.byType(PassButton)));
      await tester.pump(const Duration(milliseconds: 600));
      await gesture.up();
      await tester.pump(const Duration(seconds: 2));
      expect(passes, 0);
      expect(haptics, isEmpty);
      expect(find.text('Удерживайте 1 с'), findsNothing);
    });

    testWidgets('ход перешёл к сопернику во время удержания: пас не уходит', (tester) async {
      var passes = 0;
      await pump(tester, PassButton(onPressed: () => passes++, holdToPass: true));
      final gesture = await tester.startGesture(tester.getCenter(find.byType(PassButton)));
      await tester.pump(const Duration(milliseconds: 600));
      await pump(tester, PassButton(onPressed: () => passes++, holdToPass: true, enabled: false));
      await tester.pump(const Duration(seconds: 2));
      await gesture.up();
      await tester.pump();
      expect(passes, 0);
      expect(haptics, isEmpty);
      expect(find.text('Удерживайте 1 с'), findsNothing);
    });

    testWidgets('обычный тап в режиме удержания не пасует', (tester) async {
      var passes = 0;
      await pump(tester, PassButton(onPressed: () => passes++, holdToPass: true));
      await tester.tap(find.byType(PassButton));
      await tester.pump(const Duration(seconds: 2));
      expect(passes, 0);
    });
  });

  testWidgets('скринридеру удержание заменено нажатием', (tester) async {
    final semantics = tester.ensureSemantics();
    var passes = 0;
    await pump(tester, PassButton(onPressed: () => passes++, holdToPass: true));
    tester.semantics.tap(find.semantics.byLabel('Пас'));
    expect(passes, 1);
    semantics.dispose();
  });
}
