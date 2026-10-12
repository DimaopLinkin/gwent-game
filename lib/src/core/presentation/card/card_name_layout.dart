import 'dart:math' as math;

import 'package:gwent/src/core/presentation/card/card_size.dart';

/// Как название ложится на плашку (макет карты v2, «Длинное имя»).
///
/// В полном просмотре и в сетке имя занимает до двух строк, а «Имя: Титул» делится на имя и курсивный титул;
/// кегль подбирается по длине строки. На руке и меньше имя всегда в одну строку с многоточием. Ширина символа
/// оценивается долей кегля, как в макете: так раскладка не зависит от загрузки шрифта и одинакова в тестах.
sealed class CardNameLayout {
  const CardNameLayout();

  /// Раскладка названия [name] для карты размера [size].
  factory CardNameLayout.of(String name, CardSize size) {
    final m = size.metrics;
    if (!size.wrapsName) return SingleLineName(name, m.nameFontSize);
    final full = size == CardSize.full;
    final width = m.width - 2 * m.frameWidth - 2 * m.plaquePaddingX;
    final charWidth = full ? 0.56 : 0.52;
    const italicCharWidth = 0.46;
    final minSize = full ? 16.0 : 10.0;
    final colon = name.indexOf(': ');
    if (colon > 0) {
      final title = name.substring(0, colon);
      final subtitle = name.substring(colon + 2);
      return SplitName(
        title: title,
        titleFontSize: _clamp(_half(width / (title.length * charWidth)), minSize, full ? 24 : 11),
        subtitle: subtitle,
        subtitleFontSize: _clamp(
          _half(width * 0.98 / (subtitle.length * italicCharWidth)),
          full ? 12 : 9,
          full ? 16 : 10,
        ),
        gap: full ? 3 : 1,
      );
    }
    if (name.length * charWidth * m.nameFontSize <= width) return SingleLineName(name, m.nameFontSize);
    return TwoLineName(name, _clamp(_half(2 * width * 0.9 / (name.length * charWidth)), minSize, m.nameFontSize));
  }

  /// Округление кегля вниз до 0,5 pt.
  static double _half(double value) => (value * 2).floorToDouble() / 2;

  static double _clamp(double value, double min, double max) => math.max(min, math.min(max, value));
}

/// Одна строка с многоточием.
final class SingleLineName extends CardNameLayout {
  /// Создаёт раскладку.
  const SingleLineName(this.text, this.fontSize);

  /// Текст.
  final String text;

  /// Кегль.
  final double fontSize;
}

/// До двух строк уменьшенным кеглем.
final class TwoLineName extends CardNameLayout {
  /// Создаёт раскладку.
  const TwoLineName(this.text, this.fontSize);

  /// Текст.
  final String text;

  /// Кегль.
  final double fontSize;
}

/// Имя и курсивный титул отдельными строками.
final class SplitName extends CardNameLayout {
  /// Создаёт раскладку.
  const SplitName({
    required this.title,
    required this.titleFontSize,
    required this.subtitle,
    required this.subtitleFontSize,
    required this.gap,
  });

  /// Имя до двоеточия.
  final String title;

  /// Кегль имени.
  final double titleFontSize;

  /// Титул после двоеточия.
  final String subtitle;

  /// Кегль титула.
  final double subtitleFontSize;

  /// Промежуток между строками.
  final double gap;
}
