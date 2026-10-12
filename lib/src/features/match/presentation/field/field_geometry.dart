import 'dart:math' as math;
import 'dart:ui';

import 'package:gwent_engine/gwent_engine.dart' show Row;

/// Размеры и положение всех зон поля (макет поля, «Вертикальная сетка» и «Горизонтальная сетка»).
///
/// Всё считается от ширины экрана и высоты зоны руки; вёрстка и вырезы затемнения в оверлеях берут координаты
/// отсюда, поэтому не расходятся. Координаты в pt от верхнего левого угла поля, без системных отступов.
final class FieldGeometry {
  /// Поле шириной [width]; зона руки выше [minHandHeight], если экран выше бюджета макета.
  const FieldGeometry({required this.width, this.handHeight = minHandHeight});

  /// Полоса игрока.
  static const double barHeight = 48;

  /// Ряд: карта 74 pt и по 3 pt сверху и снизу.
  static const double rowHeight = 80;

  /// Центральная полоса.
  static const double stripHeight = 40;

  /// Зона руки по макету.
  static const double minHandHeight = 135;

  /// Поля по бокам рядов.
  static const double rowInset = 6;

  /// Колонка слева в ряду: бейдж силы и слот рога.
  static const double columnWidth = 34;

  /// Отступ колонки от края ряда.
  static const double columnLeft = 2;

  /// Промежуток между колонкой и картами.
  static const double columnGap = 4;

  /// Отступ карт от правого края ряда.
  static const double cardsRight = 4;

  /// Карта в ряду.
  static const double cardWidth = 52;

  /// Высота карты в ряду.
  static const double cardHeight = 74;

  /// Промежуток между картами, пока ряд не переполнен.
  static const double cardGap = 4;

  /// Высота бюджета макета: 48 + 240 + 40 + 240 + 48 + 135.
  static const double budgetHeight = barHeight * 2 + rowHeight * 6 + stripHeight + minHandHeight;

  /// Ширина поля.
  final double width;

  /// Высота зоны руки.
  final double handHeight;

  /// Высота поля.
  double get height => barHeight * 2 + rowHeight * 6 + stripHeight + handHeight;

  /// Верх рядов соперника.
  double get opponentRowsTop => barHeight;

  /// Верх центральной полосы.
  double get stripTop => barHeight + rowHeight * 3;

  /// Верх моих рядов.
  double get myRowsTop => stripTop + stripHeight;

  /// Верх моей полосы игрока.
  double get myBarTop => myRowsTop + rowHeight * 3;

  /// Верх зоны руки.
  double get handTop => myBarTop + barHeight;

  /// Полоса соперника.
  Rect get opponentBar => Rect.fromLTWH(0, 0, width, barHeight);

  /// Зона затемнения при выборе цели: ряды и центральная полоса, без полос игроков и руки.
  Rect get scrimArea => Rect.fromLTRB(0, opponentRowsTop, width, myBarTop);

  /// Моя полоса игрока.
  Rect get myBar => Rect.fromLTWH(0, myBarTop, width, barHeight);

  /// Центральная полоса.
  Rect get strip => Rect.fromLTWH(0, stripTop, width, stripHeight);

  /// Зона руки.
  Rect get hand => Rect.fromLTWH(0, handTop, width, handHeight);

  /// Ряд типа [row] у соперника (сверху вниз: осадный, дальний, ближний) или у меня (ближний, дальний, осадный).
  Rect rowRect(Row row, {required bool mine}) {
    final index = mine ? row.index : Row.values.length - 1 - row.index;
    final top = (mine ? myRowsTop : opponentRowsTop) + index * rowHeight;
    return Rect.fromLTWH(rowInset, top, width - 2 * rowInset, rowHeight);
  }

  /// Слот рога ряда: 31×44 под бейджем силы, колонка 34 pt.
  Rect hornSlotRect(Row row, {required bool mine}) {
    final rect = rowRect(row, mine: mine);
    return Rect.fromLTWH(rect.left + columnLeft + 1.5, rect.top + 4 + 24 + 4, 31, 44);
  }

  /// Бейдж силы ряда.
  Rect scoreRect(Row row, {required bool mine}) {
    final rect = rowRect(row, mine: mine);
    return Rect.fromLTWH(rect.left + columnLeft + 4, rect.top + 4, 26, 24);
  }

  /// Зона карт ряда: от колонки до правого поля.
  Rect cardsArea(Row row, {required bool mine}) {
    final rect = rowRect(row, mine: mine);
    final left = rect.left + columnLeft + columnWidth + columnGap;
    return Rect.fromLTRB(left, rect.top + 3, rect.right - cardsRight, rect.top + 3 + cardHeight);
  }

  /// Сколько карт помещается без перекрытия.
  int get cardsWithoutOverlap {
    final area = cardsArea(Row.melee, mine: true).width;
    return ((area + cardGap) / (cardWidth + cardGap)).floor();
  }

  /// Карта номер [index] из [count] в ряду: без перекрытия по центру с промежутком 4 pt, а при переполнении — с
  /// общим шагом `(A − 52) / (n − 1)`; каждая следующая карта лежит поверх предыдущей.
  Rect cardRect(Row row, int index, int count, {required bool mine}) {
    final area = cardsArea(Row.melee, mine: mine).width;
    final total = count * cardWidth + math.max(0, count - 1) * cardGap;
    var step = cardWidth + cardGap;
    var offset = (area - total) / 2;
    if (count > 1 && total > area) {
      step = (area - cardWidth) / (count - 1);
      offset = 0;
    }
    final base = cardsArea(row, mine: mine);
    return Rect.fromLTWH((base.left + offset + index * step).roundToDouble(), base.top, cardWidth, cardHeight);
  }

  /// Шаг веера руки из [count] карт: поля 28 pt, шаг не больше 81 pt.
  double fanStep(int count) => count > 1 ? math.min(81, (width - 2 * fanInset - 77) / (count - 1)) : 0;

  /// Отступ веера от краёв экрана: скругления экрана не должны срезать медальоны крайних карт.
  static const double fanInset = 28;

  /// Веер сменяется прокруткой, когда шаг меньше этого значения.
  static const double minFanStep = 26;

  /// Для [count] карт на руке нужна горизонтальная прокрутка, а не веер.
  bool handScrolls(int count) => count > 1 && fanStep(count) < minFanStep;
}
