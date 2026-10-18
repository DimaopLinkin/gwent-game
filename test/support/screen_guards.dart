import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gwent/src/core/presentation/components/chevron_button.dart';
import 'package:gwent/src/core/presentation/components/screen_header.dart';

/// Проверяет, что ни один текст на экране не получил отладочный стиль `MaterialApp`.
///
/// Вне `Material` (`Scaffold`, `ScreenBackdrop`) текст наследует стиль по умолчанию приложения: красный, с жёлтым
/// двойным подчёркиванием. Тест, который кладёт экран в `Scaffold`, этого не видит, поэтому экраны маршрутов
/// проверяют без обёртки ([localizedApp]) и вызывают эту функцию после первой отрисовки.
void expectNoFallbackTextStyle(WidgetTester tester) {
  final underlined = [
    for (final text in tester.widgetList<RichText>(find.byType(RichText)))
      if (switch (text.text.style?.decoration) {
        null || TextDecoration.none => false,
        _ => true,
      })
        text.text.toPlainText(),
  ];
  expect(underlined, isEmpty, reason: 'текст без Material получил отладочный стиль: $underlined');
}

/// Проверяет, что кнопка «Назад» первая на экране и прижата к левому краю с полем [ScreenHeader.inset]: так она стоит
/// на всех экранах с шапкой, а не зависит от отступов содержимого. Экран должен стоять без боковых вырезов.
void expectBackButtonAtEdge(WidgetTester tester) {
  final back = find.byType(ChevronButton).first;
  expect(tester.getTopLeft(back).dx, ScreenHeader.inset, reason: 'кнопка «Назад» не у левого края');
  expect(tester.getSize(back), const Size.square(44), reason: 'зона нажатия кнопки «Назад»');
}
