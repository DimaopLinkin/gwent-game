import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

/// Какие карты и лидеры открыты игроком в кампании (ADR 0033).
///
/// Правила сборки колоды (`DeckRules`) принимают необязательный фильтр такого вида: без него доступны все карты
/// пакета (свободная игра и сеть), с ним колода собирается только из открытого.
abstract interface class OwnedCards {
  /// Сколько копий карты или лидера [cardId] открыто; ноль, если не открыта.
  int copiesOf(String cardId);
}

/// Снимок коллекции: UUID карты или лидера и число открытых копий.
@immutable
final class CardCollection implements OwnedCards {
  /// Создаёт снимок; записи с нулём копий отбрасываются.
  ///
  /// Бросает [ArgumentError], если у карты отрицательное число копий.
  CardCollection(Map<String, int> copies)
    : copies = Map.unmodifiable({
        for (final MapEntry(key: cardId, value: count) in copies.entries)
          if (_checked(cardId, count) > 0) cardId: count,
      });

  static int _checked(String cardId, int count) {
    if (count < 0) throw ArgumentError.value(count, 'copies[$cardId]', 'Число копий не может быть отрицательным');
    return count;
  }

  /// Пустая коллекция: у игрока, не начинавшего кампанию, нет открытых карт.
  static final CardCollection empty = CardCollection(const {});

  /// UUID карты или лидера и число открытых копий, всегда больше нуля.
  final Map<String, int> copies;

  @override
  int copiesOf(String cardId) => copies[cardId] ?? 0;

  /// Сколько всего открыто копий.
  int get total => copies.values.sum;

  @override
  bool operator ==(Object other) =>
      other is CardCollection && const MapEquality<String, int>().equals(other.copies, copies);

  @override
  int get hashCode => const MapEquality<String, int>().hash(copies);

  @override
  String toString() => 'CardCollection(${copies.length} карт, $total копий)';
}
