import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

/// Колода игрока: фракция, лидер и карты.
///
/// Фракция, лидер и карты задаются UUID из пакета контента: UUID карты не меняется никогда,
/// поэтому колода переживает обновления данных. Проверку правил состава колоды делает движок.
@immutable
final class Deck {
  /// Создаёт колоду. [cards] сопоставляет UUID карты и число её копий.
  ///
  /// Бросает [ArgumentError], если у карты меньше одной копии.
  Deck({
    required this.id,
    required this.name,
    required this.factionId,
    required this.leaderId,
    required Map<String, int> cards,
    required this.updatedAt,
  }) : cards = Map.unmodifiable(cards) {
    for (final MapEntry(key: cardId, value: copies) in cards.entries) {
      if (copies < 1) throw ArgumentError.value(copies, 'cards[$cardId]', 'Число копий карты должно быть больше нуля');
    }
  }

  /// Идентификатор колоды.
  final String id;

  /// Название, которое дал игрок.
  final String name;

  /// UUID фракции.
  final String factionId;

  /// UUID карты лидера.
  final String leaderId;

  /// UUID карты и число её копий.
  final Map<String, int> cards;

  /// Момент последнего сохранения (UTC).
  final DateTime updatedAt;

  /// Общее число карт в колоде без лидера.
  int get cardCount => cards.values.sum;

  /// Копия с заменёнными полями.
  Deck copyWith({String? name, String? factionId, String? leaderId, Map<String, int>? cards, DateTime? updatedAt}) =>
      Deck(
        id: id,
        name: name ?? this.name,
        factionId: factionId ?? this.factionId,
        leaderId: leaderId ?? this.leaderId,
        cards: cards ?? this.cards,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  @override
  bool operator ==(Object other) =>
      other is Deck &&
      other.id == id &&
      other.name == name &&
      other.factionId == factionId &&
      other.leaderId == leaderId &&
      const MapEquality<String, int>().equals(other.cards, cards) &&
      other.updatedAt == updatedAt;

  @override
  int get hashCode =>
      Object.hash(id, name, factionId, leaderId, const MapEquality<String, int>().hash(cards), updatedAt);

  @override
  String toString() => 'Deck($id, $name, $cardCount карт)';
}
