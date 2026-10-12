import 'package:flutter/services.dart';
import 'package:gwent/src/features/content/application/load_game_content.dart';
import 'package:gwent/src/features/content/data/asset_content_source.dart';
import 'package:gwent/src/features/content/domain/game_content.dart';
import 'package:gwent/src/features/deck_builder/domain/deck.dart';
import 'package:gwent_engine/gwent_engine.dart' as engine show CardId, Deck, LeaderId;
import 'package:gwent_engine/gwent_engine.dart' show Faction;

/// Контент базового пакета из ассетов; тест должен вызвать `TestWidgetsFlutterBinding.ensureInitialized()`.
Future<GameContent> loadBaseContent() async => switch (await LoadGameContent(
  AssetContentSource.basePack(rootBundle),
)()) {
  GameContentReady(:final content) => content,
  GameContentRejected(:final issues) => throw StateError(issues.join('\n')),
};

/// Колода игрока по правилам из настоящего пакета: первый лидер фракции [faction], все карты отрядов фракции
/// и нейтральные со всеми копиями и первые разрешённые специальные карты.
Deck realDeck(GameContent content, Faction faction, {required String id}) {
  final rules = content.pack.rules;
  final fractionId = content.factions.entries.firstWhere((entry) => entry.value == faction).key;
  bool fits(String cardFraction) =>
      content.factions[cardFraction] == faction || content.factions[cardFraction] == Faction.neutral;
  final cards = <String, int>{
    for (final card in rules.squadCards)
      if (fits(card.fractionId) && card.count > 0) card.id: card.count,
  };
  var specials = 0;
  for (final card in rules.specialCards) {
    if (!fits(card.fractionId)) continue;
    final copies = (content.rules.maxSpecialCards - specials).clamp(0, card.count);
    if (copies == 0) break;
    cards[card.id] = copies;
    specials += copies;
  }
  return Deck(
    id: id,
    name: faction.name,
    factionId: fractionId,
    leaderId: rules.leaderCards.firstWhere((leader) => leader.fractionId == fractionId).id,
    cards: cards,
    updatedAt: DateTime.utc(2026, 10, 12),
  );
}

/// Колода движка из колоды игрока: по элементу на копию.
engine.Deck engineDeck(Deck deck) => engine.Deck(
  leader: engine.LeaderId(deck.leaderId),
  cards: [
    for (final MapEntry(key: id, value: copies) in deck.cards.entries)
      for (var i = 0; i < copies; i++) engine.CardId(id),
  ],
);
