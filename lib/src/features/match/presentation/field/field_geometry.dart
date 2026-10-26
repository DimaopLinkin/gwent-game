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

  /// Шаг карт ряда меньше этого значения: перекрытая карта уже не показывает медальон силы со стрелкой (до 30 pt).
  static const double compactStep = 30;

  /// Насколько зона крайней карты ряда тянется за карту: палец чуть в стороне от крайней карты всё ещё её захватывает.
  static const double magnetReach = 24;

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

  /// Шаг между левыми краями карт ряда из [count] карт: 56 pt, пока ряд не переполнен, затем общий `(A − 52) / (n − 1)`.
  double cardStep(int count) {
    final area = cardsArea(Row.melee, mine: true).width;
    final total = count * cardWidth + math.max(0, count - 1) * cardGap;
    return count > 1 && total > area ? (area - cardWidth) / (count - 1) : cardWidth + cardGap;
  }

  /// Ряд из [count] карт настолько сжат, что у перекрытых карт медальон силы не помещается: они показывают
  /// сжатую силу (см. `GwentCard.compactWidth`), а полную карту видно только у последней.
  bool isRowCompact(int count) => count > 1 && cardStep(count) < compactStep;

  /// Карта номер [index] из [count] в ряду: без перекрытия по центру с промежутком 4 pt, а при переполнении — с
  /// общим шагом `(A − 52) / (n − 1)`; каждая следующая карта лежит поверх предыдущей.
  Rect cardRect(Row row, int index, int count, {required bool mine}) {
    final area = cardsArea(Row.melee, mine: mine).width;
    final total = count * cardWidth + math.max(0, count - 1) * cardGap;
    final step = cardStep(count);
    final offset = count > 1 && total > area ? 0 : (area - total) / 2;
    final base = cardsArea(row, mine: mine);
    return Rect.fromLTWH((base.left + offset + index * step).roundToDouble(), base.top, cardWidth, cardHeight);
  }

  /// Зоны захвата карт ряда из [count] карт (магнит, макет 14): зона номер `i` принадлежит карте номер `i`.
  ///
  /// Зоны делят ряд по горизонтали без щелей и перекрытий и занимают всю высоту ряда. Палец над видимой частью карты
  /// даёт зону этой карты; палец в щели между картами или в стороне от крайней карты (не дальше [magnetReach])
  /// достаётся ближайшей, а щель делится пополам. Карты, на которые нельзя играть, зоны тоже делят, но цели из них
  /// не делаются: над ними ничего не горит.
  List<Rect> magnetZones(Row row, int count, {required bool mine}) {
    if (count == 0) return const [];
    final rect = rowRect(row, mine: mine);
    final area = cardsArea(row, mine: mine);
    final cards = [for (var i = 0; i < count; i++) cardRect(row, i, count, mine: mine)];
    final bounds = <double>[
      math.max(area.left, cards.first.left - magnetReach),
      for (var i = 0; i < count - 1; i++) (math.min(cards[i].right, cards[i + 1].left) + cards[i + 1].left) / 2,
      math.min(rect.right, cards.last.right + magnetReach),
    ];
    return [for (var i = 0; i < count; i++) Rect.fromLTRB(bounds[i], rect.top, bounds[i + 1], rect.bottom)];
  }

  /// Шаг веера руки из [count] карт: поля 28 pt, шаг не больше 81 pt.
  double fanStep(int count) => count > 1 ? math.min(81, (width - 2 * fanInset - 77) / (count - 1)) : 0;

  /// Отступ веера от краёв экрана: скругления экрана не должны срезать медальоны крайних карт.
  static const double fanInset = 28;

  /// Веер сменяется прокруткой, когда шаг меньше этого значения.
  static const double minFanStep = 25;

  /// Для [count] карт на руке нужна горизонтальная прокрутка, а не веер.
  bool handScrolls(int count) => count > 1 && fanStep(count) < minFanStep;

  /// Карта номер [index] из [count] в руке 77×111 без поворота: туда карты прилетают, отсюда вылетают.
  ///
  /// Повторяет раскладку `HandView`: веер, а при прокрутке карты подряд с шагом 83 pt от левого поля.
  Rect handCardRect(int index, int count) {
    const cardWidth = 77.0;
    const cardHeight = 111.0;
    if (handScrolls(count)) {
      return Rect.fromLTWH(10 + index * (cardWidth + 6), handTop + 16, cardWidth, cardHeight);
    }
    final step = fanStep(count);
    final left = fanInset + (width - 2 * fanInset - (cardWidth + (count - 1) * step)) / 2;
    final extra = (handHeight - minHandHeight) / 2;
    final center = (count - 1) / 2;
    final distance = center == 0 ? 0.0 : (index - center) / center;
    const fanTop = 16.0;
    const arcDepth = 8.0;
    final top = extra + fanTop + (center == 0 ? arcDepth : arcDepth * (1 - distance * distance));
    return Rect.fromLTWH((left + index * step).roundToDouble(), handTop + top, cardWidth, cardHeight);
  }

  /// Крупная карта по центру поля 103×148: так показывают сыгранные особые карты и ходы соперника.
  Rect get centerCardRect => Rect.fromCenter(center: strip.center, width: 103, height: 148);

  /// Слот погоды в центральной полосе: круг ⌀28 слева, по одному на тип ряда.
  Rect weatherSlotRect(Row row) => Rect.fromLTWH(10.0 + row.index * 32, stripTop + (stripHeight - 28) / 2, 28, 28);
}

/// Как поле помещается в доступную область [maxWidth] × [maxHeight]: холст шириной экрана и высотой бюджета макета
/// (751 pt); на низких экранах он уменьшается целиком ([scale] меньше 1), на высоких лишнее достаётся руке.
final class FieldFit {
  /// Считает вписывание в область.
  FieldFit(double maxWidth, double maxHeight)
    : scale = math.min(1.0, maxHeight / FieldGeometry.budgetHeight),
      width = maxWidth / math.min(1.0, maxHeight / FieldGeometry.budgetHeight),
      height = maxHeight / math.min(1.0, maxHeight / FieldGeometry.budgetHeight);

  /// Во сколько раз холст уменьшен.
  final double scale;

  /// Ширина холста в его координатах.
  final double width;

  /// Высота холста в его координатах.
  final double height;

  /// Размеры зон холста.
  FieldGeometry get geometry => FieldGeometry(
    width: width,
    handHeight: height - (FieldGeometry.budgetHeight - FieldGeometry.minHandHeight),
  );
}
