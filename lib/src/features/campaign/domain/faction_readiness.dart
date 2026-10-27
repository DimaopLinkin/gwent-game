import 'package:gwent/src/features/collection/domain/owned_cards.dart';
import 'package:gwent_content/gwent_content.dart';

/// Фракции, колоду которых можно собрать из открытых карт: открыт лидер фракции и открыто не меньше
/// `min_squad_cards` отрядов самой фракции и нейтральных вместе (по числу копий).
///
/// Так считает и таблица «Когда становится доступна колода фракции» в `docs/spec/campaign-nodes.md`; экран награды
/// показывает «Колода … готова», когда фракция попала в этот набор впервые.
Set<String> readyFactions(PackRules rules, OwnedCards owned) {
  final neutral = {
    for (final fraction in rules.fractions)
      if (!fraction.isDeck) fraction.id,
  };
  return {
    for (final fraction in rules.fractions)
      if (fraction.isDeck &&
          rules.leaderCards.any((leader) => leader.fractionId == fraction.id && owned.copiesOf(leader.id) > 0) &&
          rules.squadCards
                  .where((card) => card.fractionId == fraction.id || neutral.contains(card.fractionId))
                  .fold(0, (sum, card) => sum + owned.copiesOf(card.id)) >=
              rules.gameRules.minSquadCards)
        fraction.id,
  };
}
