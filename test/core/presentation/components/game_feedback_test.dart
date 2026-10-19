import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gwent/src/core/presentation/components/confirm_dialog.dart';
import 'package:gwent/src/core/presentation/components/deck_counter.dart';
import 'package:gwent/src/core/presentation/components/game_loader.dart';
import 'package:gwent/src/core/presentation/components/game_toast.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_colors.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_icon.dart';

import '../../../support/fonts.dart';
import '../../../support/localized_app.dart';

void main() {
  setUpAll(loadDesignFonts);

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

    group('подпись кнопки не переносится ни на какой ширине', () {
      Future<void> openAt(
        WidgetTester tester, {
        required double width,
        double textScale = 1,
        String confirmLabel = 'Покинуть',
      }) async {
        tester.view.physicalSize = Size(width, 700);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          localizedApp(
            MediaQuery(
              data: MediaQueryData(size: Size(width, 700), textScaler: TextScaler.linear(textScale)),
              child: Builder(
                builder: (context) => TextButton(
                  onPressed: () => showConfirmDialog(
                    context,
                    title: 'Покинуть лобби?',
                    body: 'Партия закроется, соперник вернётся к поиску.',
                    confirmLabel: confirmLabel,
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
      }

      /// Подпись в одну строку: выделение всего текста даёт один прямоугольник.
      void expectSingleLine(WidgetTester tester, String label) {
        final paragraph = tester.renderObject<RenderParagraph>(find.text(label));
        final boxes = paragraph.getBoxesForSelection(TextSelection(baseOffset: 0, extentOffset: label.length));
        expect(boxes, hasLength(1), reason: 'подпись «$label» перенеслась');
      }

      for (final width in [320.0, 360.0, 375.0, 390.0]) {
        testWidgets('ширина $width pt: «Покинуть» и «Отмена» в одну строку, кнопки целиком в диалоге', (tester) async {
          await openAt(tester, width: width);
          expectSingleLine(tester, 'Покинуть');
          expectSingleLine(tester, 'Отмена');
          final dialog = tester.getRect(find.byType(ConfirmDialog));
          for (final button in [find.byType(FilledButton), find.byType(OutlinedButton)]) {
            final rect = tester.getRect(button);
            expect(dialog.contains(rect.topLeft) && dialog.contains(rect.bottomRight), isTrue);
          }
          expect(tester.takeException(), isNull);
        });
      }

      testWidgets('крупный шрифт системы: подпись остаётся в одну строку, кнопки одна под другой', (tester) async {
        await openAt(tester, width: 360, textScale: 1.6);
        expectSingleLine(tester, 'Покинуть');
        expect(
          tester.getTopLeft(find.byType(FilledButton)).dy,
          isNot(tester.getTopLeft(find.byType(OutlinedButton)).dy),
        );
        expect(tester.takeException(), isNull);
      });

      testWidgets('узкий экран: кнопки столбиком на всю ширину, подпись по центру, подтверждение сверху', (
        tester,
      ) async {
        await openAt(tester, width: 320);
        final confirm = tester.getRect(find.byType(FilledButton));
        final cancel = tester.getRect(find.byType(OutlinedButton));
        expect(confirm.width, cancel.width);
        expect(confirm.top, lessThan(cancel.top));
        expect(tester.getCenter(find.text('Покинуть')).dx, closeTo(confirm.center.dx, 1));
      });

      testWidgets('короткая подпись помещается: кнопки в ряд, «Отмена» слева', (tester) async {
        await openAt(tester, width: 390, confirmLabel: 'Пас');
        expect(tester.getTopLeft(find.byType(OutlinedButton)).dy, tester.getTopLeft(find.byType(FilledButton)).dy);
        expect(
          tester.getTopLeft(find.byType(OutlinedButton)).dx,
          lessThan(tester.getTopLeft(find.byType(FilledButton)).dx),
        );
      });
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
