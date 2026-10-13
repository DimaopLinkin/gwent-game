import 'package:gwent/src/features/deck_builder/domain/deck.dart';
import 'package:gwent/src/features/deck_builder/domain/deck_exceptions.dart';
import 'package:gwent/src/features/deck_builder/domain/deck_issue.dart';
import 'package:gwent/src/features/deck_builder/domain/engine_deck.dart';
import 'package:gwent/src/features/deck_builder/domain/faction_info.dart';
import 'package:gwent_content/gwent_content.dart' show ContentPack, Fraction;
import 'package:gwent_engine/gwent_engine.dart' show CardCatalog, DeckValidator, GameRules;

/// Правила сборки колод по активному пакету контента: какие фракции доступны, годна ли колода, стартовая колода.
///
/// Проверку состава делает движок ([DeckValidator], разделы 2.1–2.2 `docs/hand/main.md`), поэтому конструктор колоды
/// и хост партии судят колоду одинаково. [catalog] и [gameRules] должны быть построены по тому же [pack].
final class DeckRules {
  /// Создаёт правила по пакету [pack] и построенным по нему справочнику движка [catalog] и параметрам [gameRules].
  DeckRules({required this.pack, required CardCatalog catalog, required this.gameRules})
    : _validator = DeckValidator(catalog, gameRules);

  /// Пакет контента: карты, лидеры, фракции и их названия.
  final ContentPack pack;

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
