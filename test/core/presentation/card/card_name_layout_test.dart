import 'package:flutter_test/flutter_test.dart';
import 'package:gwent/src/core/presentation/card/card_name_layout.dart';
import 'package:gwent/src/core/presentation/card/card_size.dart';

void main() {
  test('короткое имя — одна строка базовым кеглем', () {
    for (final size in CardSize.values) {
      expect(
        CardNameLayout.of('Олаф', size),
        isA<SingleLineName>().having((l) => l.fontSize, 'fontSize', size.metrics.nameFontSize),
      );
    }
  });

  test('длинное имя в полном размере и сетке переносится на две строки уменьшенным кеглем', () {
    for (final (size, minSize) in [(CardSize.full, 16.0), (CardSize.grid, 10.0)]) {
      final layout = CardNameLayout.of('Лучник клана Броквар из дальних земель', size);
      expect(
        layout,
        isA<TwoLineName>()
            .having((l) => l.fontSize, 'fontSize', lessThan(size.metrics.nameFontSize))
            .having((l) => l.fontSize, 'fontSize', greaterThanOrEqualTo(minSize)),
      );
    }
  });

  test('на руке, в ряду и на мини-карте имя не переносится', () {
    for (final size in [CardSize.hand, CardSize.row, CardSize.mini]) {
      expect(CardNameLayout.of('Лучник клана Броквар из дальних земель', size), isA<SingleLineName>());
    }
  });

  test('«Имя: Титул» делится на имя и курсивный титул', () {
    const name = 'Эмгыр вар Эмрейс: Белое Пламя, Пляшущее на Курганах Врагов';
    final full = CardNameLayout.of(name, CardSize.full);
    expect(
      full,
      isA<SplitName>()
          .having((l) => l.title, 'title', 'Эмгыр вар Эмрейс')
          .having((l) => l.subtitle, 'subtitle', 'Белое Пламя, Пляшущее на Курганах Врагов')
          .having((l) => l.titleFontSize, 'titleFontSize', inInclusiveRange(16, 24))
          .having((l) => l.subtitleFontSize, 'subtitleFontSize', inInclusiveRange(12, 16)),
    );
    expect(CardNameLayout.of(name, CardSize.grid), isA<SplitName>());
    expect(CardNameLayout.of(name, CardSize.hand), isA<SingleLineName>());
  });

  test('кегль округляется вниз до 0,5', () {
    final layout = CardNameLayout.of('Лучник клана Броквар из дальних земель', CardSize.full) as TwoLineName;
    expect(layout.fontSize * 2, layout.fontSize * 2 ~/ 1);
  });
}
