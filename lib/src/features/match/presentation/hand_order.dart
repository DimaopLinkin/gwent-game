import 'package:gwent/src/features/content/domain/game_content.dart';
import 'package:gwent_engine/gwent_engine.dart';

/// Порядок карт в руке и в рядах поля, как в TW3: слева особые карты (Чучело, Рог, Казнь, Дождь, Туман, Мороз, Шторм,
/// Ясное небо, Мардрём), правее отряды по возрастанию силы, при равной силе по имени.
///
/// Порядок зависит только от состава руки, поэтому карта, пришедшая позже (шпион, медик, добор), сразу встаёт на место.
/// По нему рисуется рука и считаются места вылета и возврата карт в сценариях показа. Ряды поля идут в том же порядке
/// (`RowOrder`): по базовой силе, а не по текущей, поэтому погода, рог и узы карты в ряду не переставляют.
final class HandOrder {
  /// Создаёт порядок по контенту партии.
  HandOrder(this.content);

  /// Контент партии: определения карт и их имена.
  final GameContent content;

  static const int _firstUnitRank = 100;

  /// Рука слева направо.
  List<CardInstance> sort(List<CardInstance> hand) => sortBy(hand, (card) => card);

  /// Элементы [items] слева направо по порядку их карт [cardOf].
  List<T> sortBy<T>(List<T> items, CardInstance Function(T item) cardOf) {
    final keys = {
      for (final item in items) cardOf(item).id: (rank: _rank(cardOf(item)), name: _name(cardOf(item))),
    };
    return [...items]..sort((first, second) {
      final a = cardOf(first);
      final b = cardOf(second);
      final left = keys[a.id]!;
      final right = keys[b.id]!;
      final byRank = left.rank.compareTo(right.rank);
      if (byRank != 0) return byRank;
      final byName = left.name.compareTo(right.name);
      return byName != 0 ? byName : a.id.value.compareTo(b.id.value);
    });
  }

  String _name(CardInstance card) {
    final id = card.cardId.value;
    final rules = content.pack.rules;
    final key = rules.squadCardsById[id]?.nameKey ?? rules.specialCardsById[id]?.nameKey;
    return key == null ? id : content.pack.text(key);
  }

  int _rank(CardInstance card) => switch (content.catalog.card(card.cardId)) {
    UnitCardDefinition(:final strength) => _firstUnitRank + strength,
    SpecialCardDefinition(:final ability) => switch (ability) {
      DecoyAbility() => 0,
      HornCardAbility() => 1,
      ScorchAbility() => 2,
      WeatherAbility(:final rows) when rows.length == 1 => switch (rows.single) {
        Row.siege => 3,
        Row.ranged => 4,
        Row.melee => 5,
      },
      WeatherAbility() => 6,
      ClearWeatherAbility() => 7,
      MardremCardAbility() => 8,
    },
    null => _firstUnitRank,
  };
}
