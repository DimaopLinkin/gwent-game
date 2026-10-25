import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gwent/src/core/presentation/components/button_sound_scope.dart';
import 'package:gwent/src/core/presentation/components/chevron_button.dart';
import 'package:gwent/src/core/presentation/components/gwent_button.dart';
import 'package:gwent/src/core/presentation/components/pause_button.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_colors.dart';

import '../../../support/fonts.dart';
import '../../../support/localized_app.dart';

/// Кнопки экранов вокруг поля: большая «пилюля» и кнопка паузы.
void main() {
  setUpAll(loadDesignFonts);

  Future<void> pump(WidgetTester tester, Widget child, {double width = 390}) async {
    tester.view.physicalSize = Size(width, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(localizedApp(Align(alignment: Alignment.topLeft, child: child)));
  }

  Text label(WidgetTester tester, String text) => tester.widget<Text>(find.text(text));

  group('звук нажатия', () {
    Widget scoped(int presses, Widget child, List<String> log) =>
        ButtonSoundScope(onPress: () => log.add('звук'), child: child);

    testWidgets('большая кнопка: звук идёт перед действием, недоступная молчит', (tester) async {
      final log = <String>[];
      await pump(
        tester,
        scoped(
          0,
          Column(
            children: [
              GwentButton(label: 'Играть', onPressed: () => log.add('действие')),
              const GwentButton(label: 'Нельзя', onPressed: null),
            ],
          ),
          log,
        ),
      );
      await tester.tap(find.text('Играть'));
      await tester.tap(find.text('Нельзя'), warnIfMissed: false);
      expect(log, ['звук', 'действие']);
    });

    testWidgets('стрелка «назад» тоже звучит', (tester) async {
      final log = <String>[];
      await pump(
        tester,
        scoped(0, ChevronButton(label: 'Назад', onPressed: () => log.add('действие')), log),
      );
      await tester.tap(find.byType(ChevronButton));
      expect(log, ['звук', 'действие']);
    });

    testWidgets('без области кнопки молчат и работают как раньше', (tester) async {
      var pressed = 0;
      await pump(tester, GwentButton(label: 'Играть', onPressed: () => pressed++));
      await tester.tap(find.text('Играть'));
      expect(pressed, 1);
    });
  });

  group('GwentButton', () {
    for (final style in GwentButtonStyle.values) {
      testWidgets('${style.name}: нажатие вызывает действие, высота по умолчанию 54', (tester) async {
        var pressed = 0;
        await pump(tester, GwentButton(label: 'Играть', style: style, onPressed: () => pressed++));
        expect(tester.getSize(find.byType(GwentButton)).height, 54);
        await tester.tap(find.text('Играть'));
        expect(pressed, 1);
      });

      testWidgets('${style.name}: без обработчика кнопка недоступна, текст тусклый, нажатие не принимается', (
        tester,
      ) async {
        await pump(tester, GwentButton(label: 'Играть', style: style, onPressed: null));
        expect(label(tester, 'Играть').style?.color, GwentColors.muted);
        await tester.tap(find.text('Играть'));
      });
    }

    testWidgets('высота не меньше 44 pt: меньшую зону нажатия сборка не допускает', (tester) async {
      expect(() => GwentButton(label: 'Мало', onPressed: () {}, height: 40), throwsAssertionError);
      await pump(tester, GwentButton(label: 'Предел', onPressed: () {}, height: 44));
      expect(tester.getSize(find.byType(GwentButton)).height, 44);
    });

    testWidgets('цвет подписи подсвеченной кнопки действует, у недоступной — нет', (tester) async {
      await pump(
        tester,
        GwentButton(
          label: 'Колоды',
          style: GwentButtonStyle.secondary,
          labelColor: GwentColors.goldHighlight,
          onPressed: () {},
        ),
      );
      expect(label(tester, 'Колоды').style?.color, GwentColors.goldHighlight);
      await pump(
        tester,
        const GwentButton(
          label: 'Колоды',
          style: GwentButtonStyle.secondary,
          labelColor: GwentColors.goldHighlight,
          onPressed: null,
        ),
      );
      expect(label(tester, 'Колоды').style?.color, GwentColors.muted);
    });

    testWidgets('опасная кнопка красная, обычная светлая', (tester) async {
      await pump(tester, GwentButton(label: 'Сдаться', style: GwentButtonStyle.danger, onPressed: () {}));
      expect(label(tester, 'Сдаться').style?.color, GwentColors.errorText);
      await pump(tester, GwentButton(label: 'Играть', onPressed: () {}));
      expect(label(tester, 'Играть').style?.color, GwentColors.textPrimary);
    });

    testWidgets('нажатая кнопка сдвигается на пиксель, после отпускания возвращается', (tester) async {
      await pump(tester, GwentButton(label: 'Играть', onPressed: () {}));
      final rest = tester.getTopLeft(find.byType(GwentButton)).dy;
      final gesture = await tester.startGesture(tester.getCenter(find.byType(GwentButton)));
      await tester.pump();
      expect(tester.getTopLeft(find.text('Играть')).dy, greaterThan(rest));
      await gesture.up();
      await tester.pump();
      expect(tester.getTopLeft(find.byType(GwentButton)).dy, rest);
    });

    testWidgets('диктор читает подпись, а не видимый текст, если она задана; кнопка отмечена как недоступная', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await pump(tester, const GwentButton(label: 'Играть', semanticsLabel: 'Начать игру', onPressed: null));
      expect(find.bySemanticsLabel('Начать игру'), findsOneWidget);
      final data = tester.getSemantics(find.bySemanticsLabel('Начать игру'));
      expect(data.flagsCollection.isButton, isTrue);
      expect(data.flagsCollection.isEnabled, ui.Tristate.isFalse);
      semantics.dispose();
    });

    testWidgets('кнопка принимает фокус с клавиатуры, недоступная — нет', (tester) async {
      await pump(tester, GwentButton(label: 'Играть', onPressed: () {}));
      final focus = tester.widget<Focus>(
        find.descendant(of: find.byType(GwentButton), matching: find.byType(Focus)).first,
      );
      expect(focus.canRequestFocus, isTrue);
      await pump(tester, const GwentButton(label: 'Играть', onPressed: null));
      final disabled = tester.widget<Focus>(
        find.descendant(of: find.byType(GwentButton), matching: find.byType(Focus)).first,
      );
      expect(disabled.canRequestFocus, isFalse);
    });

    testWidgets('длинная подпись не ломает кнопку: одна строка с многоточием', (tester) async {
      await pump(
        tester,
        SizedBox(
          width: 120,
          child: GwentButton(label: 'Очень длинная подпись кнопки', onPressed: () {}),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(label(tester, 'Очень длинная подпись кнопки').maxLines, 1);
    });
  });

  group('PauseButton', () {
    testWidgets('зона нажатия 44×44, круг 30, нажатие по краю зоны срабатывает', (tester) async {
      var pressed = 0;
      await pump(tester, PauseButton(onPressed: () => pressed++, semanticsLabel: 'Пауза'));
      expect(tester.getSize(find.byType(PauseButton)), const Size(44, 44));
      await tester.tapAt(tester.getTopLeft(find.byType(PauseButton)) + const Offset(2, 2));
      expect(pressed, 1);
    });

    testWidgets('диктор читает «Пауза» как кнопку', (tester) async {
      final semantics = tester.ensureSemantics();
      await pump(tester, PauseButton(onPressed: () {}, semanticsLabel: 'Пауза'));
      expect(tester.getSemantics(find.bySemanticsLabel('Пауза')).flagsCollection.isButton, isTrue);
      semantics.dispose();
    });
  });
}
