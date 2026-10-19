import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gwent/src/core/presentation/components/confirm_dialog.dart';
import 'package:gwent/src/core/presentation/components/deck_counter.dart';
import 'package:gwent/src/core/presentation/components/game_loader.dart';
import 'package:gwent/src/core/presentation/components/game_toast.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_colors.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_icon.dart';

import '../../../support/localized_app.dart';

void main() {
  group('тост', () {
    testWidgets('показывает сообщение, ошибка отличается рамкой и иконкой', (tester) async {
      await tester.pumpWidget(
        localizedApp(
          const Column(
            children: [
              GameToast(message: 'Мороз: сила ближнего боя снижена до 1', icon: GwentIcon.weatherFrost),
              GameToast(message: 'Колода пуста', icon: GwentIcon.iconDeck, isError: true),
            ],
          ),
        ),
      );
      expect(find.text('Мороз: сила ближнего боя снижена до 1'), findsOneWidget);
      final borders = [
        for (final box in tester.widgetList<DecoratedBox>(
          find.descendant(of: find.byType(GameToast), matching: find.byType(DecoratedBox)),
        ))
          if (box.decoration is BoxDecoration && (box.decoration as BoxDecoration).border != null)
            ((box.decoration as BoxDecoration).border! as Border).top.color,
      ];
      expect(borders, [GwentColors.brass, GwentColors.debuff]);
      expect(GameToast.visibleFor, const Duration(seconds: 3));
    });
  });

  group('загрузка', () {
    testWidgets('подпись по умолчанию «Тасуем колоду…», три камня, свои подписи работают', (tester) async {
      await tester.pumpWidget(localizedApp(const Center(child: GameLoader())));
      expect(find.text('Тасуем колоду…'), findsOneWidget);
      expect(find.byType(Opacity), findsNWidgets(3));
      await tester.pump(const Duration(milliseconds: 600));

      await tester.pumpWidget(localizedApp(const Center(child: GameLoader(caption: 'Ждём соперника…'))));
      expect(find.text('Ждём соперника…'), findsOneWidget);
    });

    testWidgets('при «уменьшить движение» камни статичны, кольцо не крутится', (tester) async {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: localizedApp(const Column(children: [GameLoader(), GwentSpinner()])),
        ),
      );
      await tester.pump();
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('камни мерцают по кругу: на границе цикла нет скачка фазы', (tester) async {
      await tester.pumpWidget(localizedApp(const Center(child: GameLoader())));
      double opacityOfFirst() => tester.widgetList<Opacity>(find.byType(Opacity)).first.opacity;
      await tester.pump(const Duration(milliseconds: 1199));
      final beforeWrap = opacityOfFirst();
      await tester.pump(const Duration(milliseconds: 2));
      expect((opacityOfFirst() - beforeWrap).abs(), lessThan(0.01));
    });

    testWidgets('кольцо подписано для скринридера', (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(localizedApp(const Center(child: GwentSpinner())));
      expect(find.bySemanticsLabel('Загрузка'), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('кольцо 28 pt крутится', (tester) async {
      await tester.pumpWidget(localizedApp(const Center(child: GwentSpinner())));
      expect(tester.getSize(find.byType(GwentSpinner)), const Size.square(28));
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.hasRunningAnimations, isTrue);
    });
  });

  group('счётчик колоды', () {
    Future<void> pump(WidgetTester tester, DeckCounter counter) =>
        tester.pumpWidget(localizedApp(Center(child: counter)));

    testWidgets('число и норма, подпись для скринридера', (tester) async {
      final semantics = tester.ensureSemantics();
      await pump(tester, const DeckCounter(label: 'Карты отрядов', count: 22, target: 22));
      expect(find.textContaining('22'), findsWidgets);
      expect(find.bySemanticsLabel('Карты отрядов: 22 из 22'), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('недобор: красная рамка и стрелка вниз вместо иконки колоды, лимит: золото', (tester) async {
      Color? borderOf(WidgetTester tester) {
        final box = tester.widget<Container>(
          find.descendant(of: find.byType(DeckCounter), matching: find.byType(Container)).first,
        );
        return ((box.decoration! as BoxDecoration).border! as Border).top.color;
      }

      await pump(tester, const DeckCounter(label: 'Карты отрядов', count: 22, target: 22));
      expect(borderOf(tester), GwentColors.line);

      await pump(
        tester,
        const DeckCounter(label: 'Нужно ещё 4 карты', count: 18, target: 22, status: DeckCounterStatus.shortfall),
      );
      expect(borderOf(tester), GwentColors.debuff);

      await pump(
        tester,
        const DeckCounter(label: 'Особые · максимум', count: 10, target: 10, status: DeckCounterStatus.limit),
      );
      expect(borderOf(tester), GwentColors.gold);
    });
  });

  group('диалог подтверждения', () {
    Future<void> open(WidgetTester tester, ValueSetter<bool> onResult) async {
      await tester.pumpWidget(
        localizedApp(
          Builder(
            builder: (context) => TextButton(
              onPressed: () async => onResult(
                await showConfirmDialog(
                  context,
                  title: 'Спасовать?',
                  body: 'До конца раунда вы не сможете разыгрывать карты.',
                  confirmLabel: 'Пас',
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    testWidgets('«Отмена» слева в фокусе, «Пас» справа; подтверждение возвращает true', (tester) async {
      bool? result;
      await open(tester, (value) => result = value);
      expect(find.text('Спасовать?'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Отмена')).dx,
        lessThan(tester.getTopLeft(find.widgetWithText(FilledButton, 'Пас')).dx),
      );
      expect(tester.widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'Отмена')).autofocus, isTrue);

      await tester.tap(find.widgetWithText(FilledButton, 'Пас'));
      await tester.pumpAndSettle();
      expect(result, isTrue);
    });

    testWidgets('«Отмена» и тап вне диалога возвращают false', (tester) async {
      bool? result;
      await open(tester, (value) => result = value);
      await tester.tap(find.text('Отмена'));
      await tester.pumpAndSettle();
      expect(result, isFalse);

      result = null;
      await open(tester, (value) => result = value);
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(result, isFalse);
    });
  });
}
