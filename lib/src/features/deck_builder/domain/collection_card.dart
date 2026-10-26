import 'package:gwent/src/features/deck_builder/domain/deck.dart';
import 'package:meta/meta.dart';

/// Вид карты в коллекции игрока (для фильтров и правил конструктора).
enum CollectionKind {
  /// Обычный отряд.
  unit,

  /// Герой: к нему не применяются погода и особые карты, в колоду идёт в одном экземпляре.
  hero,

  /// Особая карта (рог, чучело, казнь, мардрём).
  special,

  /// Погода и «Ясное небо».
  weather,
}

/// Группа карты в сетке конструктора: так карты разделены метками.
enum CollectionGroup {
  /// Герои.
  heroes,

  /// Обычные отряды.
  units,

  /// Особые карты и погода.
  specials,
}

/// Куда играется карта отряда.
enum CollectionPlacement {
  /// Ближний ряд.
  melee,

  /// Дальний ряд.
  ranged,

  /// Осадный ряд.
  siege,

  /// Проворство: ближний или дальний ряд по выбору.
  agile,
}

/// Карта коллекции, из которой собирают колоду: без лидеров, с числом копий, которое можно положить в колоду.
@immutable
final class CollectionCard {
  /// Создаёт карту коллекции.
  const CollectionCard({
    required this.id,
    required this.fractionId,
    required this.isNeutral,
    required this.kind,
    required this.maxCopies,
    this.name = '',
    this.placement,
    this.strength = 0,
  });

  /// UUID карты.
  final String id;

  /// UUID фракции карты; у нейтральных карт — нейтральная фракция пакета.
  final String fractionId;

  /// Нейтральная ли карта: её можно положить в колоду любой фракции.
  final bool isNeutral;

  /// Вид карты.
  final CollectionKind kind;

  /// Название карты из пакета контента: по нему равные по силе карты идут в сетке по имени.
  final String name;

  /// Сколько копий карты можно положить в колоду: число из набора карт, у героя не больше одной.
  final int maxCopies;

  /// Ряд отряда; `null` у особых карт и погоды.
  final CollectionPlacement? placement;

  /// Базовая сила; у особых карт 0.
  final int strength;

  /// Группа карты в сетке конструктора.
  CollectionGroup get group => switch (kind) {
    CollectionKind.hero => CollectionGroup.heroes,
    CollectionKind.unit => CollectionGroup.units,
    CollectionKind.special || CollectionKind.weather => CollectionGroup.specials,
  };

  /// Отряд или герой: считается в «Отряды» и «Силу».
  bool get isUnit => kind == CollectionKind.unit || kind == CollectionKind.hero;

  /// Особая карта или погода: считается в «Особые».
  bool get isSpecial => !isUnit;
}

/// Состав колоды при сборке: может быть неполным и негодным, пока игрок её собирает.
@immutable
final class DeckDraft {
  /// Создаёт черновик. [id] `null` у новой колоды, [leaderId] `null`, пока лидер не выбран.
  DeckDraft({
    this.id,
    required this.name,
    required this.factionId,
    this.leaderId,
    Map<String, int> cards = const {},
  }) : cards = Map.unmodifiable(cards);

  /// Черновик сохранённой колоды [deck].
  DeckDraft.of(Deck deck)
    : this(id: deck.id, name: deck.name, factionId: deck.factionId, leaderId: deck.leaderId, cards: deck.cards);

  /// Идентификатор сохранённой колоды; `null` у новой.
  final String? id;

  /// Название.
  final String name;

  /// UUID фракции.
  final String factionId;

  /// UUID лидера; `null`, если не выбран.
  final String? leaderId;

  /// Копии карт по UUID, не меньше одной.
  final Map<String, int> cards;

  /// Сколько копий карты [cardId] лежит в колоде.
  int copiesOf(String cardId) => cards[cardId] ?? 0;

  /// Черновик с изменёнными полями. Лидера сбрасывает [clearLeader].
  DeckDraft copyWith({
    String? name,
    String? factionId,
    String? leaderId,
    bool clearLeader = false,
    Map<String, int>? cards,
  }) => DeckDraft(
    id: id,
    name: name ?? this.name,
    factionId: factionId ?? this.factionId,
    leaderId: clearLeader ? null : leaderId ?? this.leaderId,
    cards: cards ?? this.cards,
  );

  /// Черновик с картой [cardId] на одну копию больше.
  DeckDraft withAdded(String cardId) => copyWith(cards: {...cards, cardId: copiesOf(cardId) + 1});

  /// Черновик с картой [cardId] на одну копию меньше; без копий карта уходит из состава.
  DeckDraft withRemoved(String cardId) {
    final left = copiesOf(cardId) - 1;
    final next = {...cards};
    if (left > 0) {
      next[cardId] = left;
    } else {
      next.remove(cardId);
    }
    return copyWith(cards: next);
  }
}

/// Счётчики колоды для статистики конструктора.
@immutable
final class DeckStats {
  /// Создаёт счётчики.
  const DeckStats({
    required this.total,
    required this.units,
    required this.specials,
    required this.power,
    required this.heroes,
  });

  /// Все карты.
  final int total;

  /// Отряды вместе с героями.
  final int units;

  /// Особые карты и погода.
  final int specials;

  /// Суммарная базовая сила отрядов.
  final int power;

  /// Герои.
  final int heroes;
}

/// Почему карту нельзя добавить в колоду.
enum AddRefusal {
  /// Все копии карты уже в колоде.
  allCopiesInDeck,

  /// Герой уже в колоде: герой идёт в одном экземпляре.
  heroLimit,

  /// Особых карт уже максимум.
  specialLimit,
}
