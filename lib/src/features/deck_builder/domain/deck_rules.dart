import 'dart:math' as math;

import 'package:gwent/src/features/deck_builder/domain/collection_card.dart';
import 'package:gwent/src/features/deck_builder/domain/deck.dart';
import 'package:gwent/src/features/deck_builder/domain/deck_exceptions.dart';
import 'package:gwent/src/features/deck_builder/domain/deck_issue.dart';
import 'package:gwent/src/features/deck_builder/domain/engine_deck.dart';
import 'package:gwent/src/features/deck_builder/domain/faction_info.dart';
import 'package:gwent_content/gwent_content.dart' show ContentPack, Fraction, SpecialCard, SquadCard;
import 'package:gwent_engine/gwent_engine.dart'
    show
        CardCatalog,
        CardId,
        ClearWeatherAbility,
        DeckValidator,
        GameRules,
        SpecialCardDefinition,
        UnitCardDefinition,
        UnitPlacement,
        WeatherAbility;

/// Правила сборки колод по активному пакету контента: какие фракции доступны, годна ли колода, стартовая колода.
///
/// Проверку состава делает движок ([DeckValidator], разделы 2.1–2.2 `docs/hand/main.md`), поэтому конструктор колоды
/// и хост партии судят колоду одинаково. [catalog] и [gameRules] должны быть построены по тому же [pack].
final class DeckRules {
  /// Создаёт правила по пакету [pack] и построенным по нему справочнику движка [catalog] и параметрам [gameRules].
  DeckRules({required this.pack, required this.catalog, required this.gameRules})
    : _validator = DeckValidator(catalog, gameRules);

  /// Пакет контента: карты, лидеры, фракции и их названия.
  final ContentPack pack;

  /// Справочник карт движка, построенный по [pack].
  final CardCatalog catalog;

  /// Параметры колоды в виде, понятном движку.
  final GameRules gameRules;

  final DeckValidator _validator;

  /// Фракции, из которых можно собрать колоду, в порядке пакета.
  List<Fraction> get deckFactions => List.unmodifiable(pack.rules.fractions.where((fraction) => fraction.isDeck));

  /// Фракции, из которых можно собрать колоду, с перком и лидерами: тексты берутся из строк пакета.
  late final List<FactionInfo> factionInfos = List.unmodifiable([
    for (final fraction in deckFactions)
      FactionInfo(
        id: fraction.id,
        key: fraction.key,
        name: pack.text(fraction.nameKey),
        perk: switch (pack.rules.fractionAbilitiesById[fraction.abilityId]) {
          final ability? => pack.text(ability.descriptionKey),
          null => '',
        },
        leaders: [
          for (final leader in pack.rules.leaderCards.where((card) => card.fractionId == fraction.id))
            LeaderInfo(
              id: leader.id,
              factionId: fraction.id,
              name: pack.text(leader.nameKey),
              ability: switch (pack.rules.leaderAbilitiesById[leader.abilityId]) {
                final ability? => pack.text(ability.descriptionKey),
                null => '',
              },
            ),
        ],
      ),
  ]);

  /// Сколько экземпляров героя можно положить в колоду (раздел 2.2 `docs/hand/main.md`): в наборе карт у героев
  /// и так одна копия, но правило не зависит от данных.
  static const int heroCopies = 1;

  /// Все карты коллекции в порядке пакета: сначала отряды, потом особые; созданные карты (`count` = 0) не входят.
  late final List<CollectionCard> allCards = List.unmodifiable([
    for (final card in pack.rules.squadCards) ?_unit(card),
    for (final card in pack.rules.specialCards) ?_special(card),
  ]);

  /// Карты коллекции по UUID.
  late final Map<String, CollectionCard> cardsById = Map.unmodifiable({for (final card in allCards) card.id: card});

  /// Карты, из которых собирают колоду фракции [factionId]: её карты и нейтральные, в порядке пакета.
  List<CollectionCard> collectionFor(String factionId) => List.unmodifiable(
    allCards.where((card) => card.isNeutral || card.fractionId == factionId),
  );

  CollectionCard? _unit(SquadCard card) {
    final definition = catalog.card(CardId(card.id));
    if (card.count < 1 || definition is! UnitCardDefinition) return null;
    return CollectionCard(
      id: card.id,
      fractionId: card.fractionId,
      isNeutral: !isDeckFaction(card.fractionId),
      kind: definition.isHero ? CollectionKind.hero : CollectionKind.unit,
      maxCopies: definition.isHero ? math.min(card.count, heroCopies) : card.count,
      placement: switch (definition.placement) {
        UnitPlacement.melee => CollectionPlacement.melee,
        UnitPlacement.ranged => CollectionPlacement.ranged,
        UnitPlacement.siege => CollectionPlacement.siege,
        UnitPlacement.agile => CollectionPlacement.agile,
      },
      strength: card.strength,
    );
  }

  CollectionCard? _special(SpecialCard card) {
    final definition = catalog.card(CardId(card.id));
    if (card.count < 1 || definition is! SpecialCardDefinition) return null;
    return CollectionCard(
      id: card.id,
      fractionId: card.fractionId,
      isNeutral: !isDeckFaction(card.fractionId),
      kind: switch (definition.ability) {
        WeatherAbility() || ClearWeatherAbility() => CollectionKind.weather,
        _ => CollectionKind.special,
      },
      maxCopies: card.count,
    );
  }

  /// Счётчики черновика [draft]; карты, которых нет в пакете, в счётчики не входят.
  DeckStats statsOf(DeckDraft draft) {
    var total = 0;
    var units = 0;
    var specials = 0;
    var power = 0;
    var heroes = 0;
    for (final MapEntry(key: id, value: copies) in draft.cards.entries) {
      final card = cardsById[id];
      if (card == null) continue;
      total += copies;
      if (card.isUnit) {
        units += copies;
        power += copies * card.strength;
      } else {
        specials += copies;
      }
      if (card.kind == CollectionKind.hero) heroes += copies;
    }
    return DeckStats(total: total, units: units, specials: specials, power: power, heroes: heroes);
  }

  /// Почему карту [card] нельзя добавить в черновик [draft]; `null`, если можно.
  AddRefusal? refusalToAdd(DeckDraft draft, CollectionCard card) {
    if (draft.copiesOf(card.id) >= card.maxCopies) {
      return card.kind == CollectionKind.hero ? AddRefusal.heroLimit : AddRefusal.allCopiesInDeck;
    }
    if (card.isSpecial && statsOf(draft).specials >= gameRules.maxSpecialCards) return AddRefusal.specialLimit;
    return null;
  }

  /// Проблемы черновика: те же правила, что у сохранённой колоды. Пока лидер не выбран, проблема — лидер.
  List<DeckIssue> checkDraft(DeckDraft draft) => check(
    Deck(
      id: draft.id ?? '',
      name: draft.name,
      factionId: draft.factionId,
      leaderId: draft.leaderId ?? '',
      cards: draft.cards,
      updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
    ),
  );

  /// Можно ли собрать колоду фракции [factionId].
  bool isDeckFaction(String factionId) => pack.rules.fractionsById[factionId]?.isDeck ?? false;

  /// Все проблемы колоды; пустой список значит, что с колодой можно идти в партию.
  List<DeckIssue> check(Deck deck) {
    final leader = pack.rules.leaderCardsById[deck.leaderId];
    return List.unmodifiable([
      for (final violation in _validator.validate(deck.toEngineDeck())) DeckRuleViolation(violation),
      if (leader != null && leader.fractionId != deck.factionId)
        LeaderOfOtherFaction(leaderId: leader.id, leaderFactionId: leader.fractionId),
    ]);
  }

  /// Стартовая колода фракции [factionId]: годная колода, с которой можно сразу идти в партию.
  ///
  /// Собирается однозначно из пакета, в порядке карт в нём: первый лидер фракции; все копии карт отрядов фракции,
  /// а если их меньше минимума, то нейтральные отряды со всеми копиями, пока минимум не набран; по одной копии
  /// специальных карт фракции, затем нейтральных, пока не набран максимум. Называется по фракции.
  ///
  /// Бросает [NotADeckFactionException], если из фракции нельзя собрать колоду.
  Deck starterDeck(String factionId, {required String id, required DateTime updatedAt}) {
    final rules = pack.rules;
    final faction = rules.fractionsById[factionId];
    if (faction == null || !faction.isDeck) throw NotADeckFactionException(factionId);
    // Проверенный пакет гарантирует лидера у каждой фракции с колодой (инварианты, ADR 0002).
    final leader = rules.leaderCards.firstWhere((leader) => leader.fractionId == factionId);
    bool isNeutral(String fractionId) => !(rules.fractionsById[fractionId]?.isDeck ?? true);

    final cards = <String, int>{};
    var units = 0;
    for (final card in rules.squadCards.where((card) => card.count > 0 && card.fractionId == factionId)) {
      cards[card.id] = card.count;
      units += card.count;
    }
    for (final card in rules.squadCards.where((card) => card.count > 0 && isNeutral(card.fractionId))) {
      if (units >= gameRules.minUnitCards) break;
      cards[card.id] = card.count;
      units += card.count;
    }
    final specials = [
      ...rules.specialCards.where((card) => card.count > 0 && card.fractionId == factionId),
      ...rules.specialCards.where((card) => card.count > 0 && isNeutral(card.fractionId)),
    ];
    for (final card in specials.take(gameRules.maxSpecialCards)) {
      cards[card.id] = 1;
    }

    return Deck(
      id: id,
      name: pack.text(faction.nameKey),
      factionId: factionId,
      leaderId: leader.id,
      cards: cards,
      updatedAt: updatedAt,
    );
  }
}
