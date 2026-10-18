import 'package:gwent_engine/gwent_engine.dart';
import 'package:meta/meta.dart';

/// Место на поле, откуда или куда летит карта или где горит эффект.
///
/// Сценарий описывает места по смыслу («слот в руке», «карта в ряду», «колода»), а не координатами: координаты
/// даёт `FieldGeometry` при рисовании, поэтому сценарий не зависит от размера экрана.
@immutable
sealed class StagePlace {
  const StagePlace();
}

/// Слот [index] из [count] в моей руке (веер без поворота).
final class HandPlace extends StagePlace {
  /// Создаёт место.
  const HandPlace(this.index, this.count);

  /// Номер слота слева направо.
  final int index;

  /// Сколько карт в руке.
  final int count;

  @override
  bool operator ==(Object other) => other is HandPlace && other.index == index && other.count == count;

  @override
  int get hashCode => Object.hash(index, count);
}

/// Счётчик карт в руке на полосе игрока: у соперника рука показана числом, и карты вылетают отсюда.
final class BarHandPlace extends StagePlace {
  /// Создаёт место.
  const BarHandPlace({required this.mine});

  /// Своя полоса или соперника.
  final bool mine;

  @override
  bool operator ==(Object other) => other is BarHandPlace && other.mine == mine;

  @override
  int get hashCode => mine.hashCode;
}

/// Колода игрока на его полосе.
final class DeckPlace extends StagePlace {
  /// Создаёт место.
  const DeckPlace({required this.mine});

  /// Своя полоса или соперника.
  final bool mine;

  @override
  bool operator ==(Object other) => other is DeckPlace && other.mine == mine;

  @override
  int get hashCode => mine.hashCode ^ 0x1;
}

/// Сброс игрока на его полосе.
final class DiscardPlace extends StagePlace {
  /// Создаёт место.
  const DiscardPlace({required this.mine});

  /// Своя полоса или соперника.
  final bool mine;

  @override
  bool operator ==(Object other) => other is DiscardPlace && other.mine == mine;

  @override
  int get hashCode => mine.hashCode ^ 0x2;
}

/// Мини-карта лидера на полосе игрока.
final class LeaderPlace extends StagePlace {
  /// Создаёт место.
  const LeaderPlace({required this.mine});

  /// Своя полоса или соперника.
  final bool mine;

  @override
  bool operator ==(Object other) => other is LeaderPlace && other.mine == mine;

  @override
  int get hashCode => mine.hashCode ^ 0x3;
}

/// Полоса игрока целиком (для подсветки).
final class BarPlace extends StagePlace {
  /// Создаёт место.
  const BarPlace({required this.mine});

  /// Своя полоса или соперника.
  final bool mine;

  @override
  bool operator ==(Object other) => other is BarPlace && other.mine == mine;

  @override
  int get hashCode => mine.hashCode ^ 0x4;
}

/// Место карты [card] в ряду по составу ряда на этот момент показа: ряд перестраивается по ходу сцены, поэтому
/// номер места определяет рисование, а не сценарий.
final class RowCardPlace extends StagePlace {
  /// Создаёт место.
  const RowCardPlace({required this.mine, required this.row, required this.card});

  /// Ряд мой или соперника.
  final bool mine;

  /// Тип ряда.
  final Row row;

  /// Карта в ряду.
  final CardInstanceId card;

  @override
  bool operator ==(Object other) =>
      other is RowCardPlace && other.mine == mine && other.row == row && other.card == card;

  @override
  int get hashCode => Object.hash(mine, row, card);
}

/// Ряд целиком: подсветка и волны.
final class RowPlace extends StagePlace {
  /// Создаёт место.
  const RowPlace({required this.mine, required this.row});

  /// Ряд мой или соперника.
  final bool mine;

  /// Тип ряда.
  final Row row;

  @override
  bool operator ==(Object other) => other is RowPlace && other.mine == mine && other.row == row;

  @override
  int get hashCode => Object.hash(mine, row, 0x5);
}

/// Слот рога ряда.
final class HornPlace extends StagePlace {
  /// Создаёт место.
  const HornPlace({required this.mine, required this.row});

  /// Ряд мой или соперника.
  final bool mine;

  /// Тип ряда.
  final Row row;

  @override
  bool operator ==(Object other) => other is HornPlace && other.mine == mine && other.row == row;

  @override
  int get hashCode => Object.hash(mine, row, 0x6);
}

/// Слот погоды в центральной полосе: по одному на тип ряда.
final class WeatherSlotPlace extends StagePlace {
  /// Создаёт место.
  const WeatherSlotPlace(this.row);

  /// Тип ряда, к которому относится слот.
  final Row row;

  @override
  bool operator ==(Object other) => other is WeatherSlotPlace && other.row == row;

  @override
  int get hashCode => Object.hash(row, 0x7);
}

/// Центр поля: сюда выходит карта, когда её показывают крупно (103×148).
final class CenterPlace extends StagePlace {
  /// Создаёт место.
  const CenterPlace();

  @override
  bool operator ==(Object other) => other is CenterPlace;

  @override
  int get hashCode => 0x8;
}

/// Центр поля, размер мини-карты 31×44: сюда выходит лидер, увеличенный втрое (около 93×132).
final class MiniCenterPlace extends StagePlace {
  /// Создаёт место.
  const MiniCenterPlace();

  @override
  bool operator ==(Object other) => other is MiniCenterPlace;

  @override
  int get hashCode => 0x9;
}

/// Всё поле: затемнение.
final class FieldPlace extends StagePlace {
  /// Создаёт место.
  const FieldPlace();

  @override
  bool operator ==(Object other) => other is FieldPlace;

  @override
  int get hashCode => 0x9;
}
