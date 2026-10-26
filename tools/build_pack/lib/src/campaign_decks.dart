import 'dart:math' as math;

import 'package:gwent_build_pack/src/hand_data_exception.dart';
import 'package:gwent_content/gwent_content.dart';

/// Рецепт колоды соперника: теги темы и сид. По рецепту [buildOpponentDeck] всегда даёт один список карт.
final class DeckRecipe {
  /// Создаёт рецепт.
  const DeckRecipe({required this.tags, required this.seed});

  /// Теги темы колоды, например `spy`, `weather`, `siege` (см. [DeckTag]).
  final List<DeckTag> tags;

  /// Сид случайной добавки.
  final int seed;
}

/// Тема, под которую подбирается колода соперника.
enum DeckTag {
  /// Шпионы.
  spy,

  /// Медики.
  medic,

  /// Двойник: призыв копий.
  muster,

  /// Прочная связь.
  bond,

  /// Прилив сил.
  morale,

  /// Командирский рог.
  horn,

  /// Казнь.
  scorch,

  /// Чучело и Приманка.
  decoy,

  /// Берсерки и Мардрём.
  berserk,

  /// Проворные карты.
  agile,

  /// Погодные карты.
  weather,

  /// Ясное небо.
  clearWeather,

  /// Осадные карты.
  siege,

  /// Дальний бой.
  ranged,

  /// Ближний бой.
  melee,

  /// Герои.
  heroes,

  /// Много слабых отрядов.
  weak,

  /// Сильные отряды.
  strong
  ;

  /// Тег по имени из рецепта или `null`.
  static DeckTag? byName(String name) {
    for (final tag in values) {
      if (tag.name == name) return tag;
    }
    return null;
  }
}

/// Собирает фиксированную колоду соперника: карты фракции [fractionId] и нейтральные из [rules] по теме [recipe]
/// для бота уровня [difficulty].
///
/// Колода проходит базовые правила (отрядов не меньше `min_squad_cards`, особых не больше `max_special_cards`,
/// копий не больше `count`, герой не больше одного раза). Результат зависит только от входных данных и сида,
/// поэтому его можно коммитить: перегенерация колод это осознанное решение, а не побочный эффект сборки.
/// Лидер колоды задаётся узлом и в список не входит.
List<CardGrant> buildOpponentDeck({
  required PackRules rules,
  required String fractionId,
  required CampaignDifficulty difficulty,
  required DeckRecipe recipe,
}) {
  final random = math.Random(recipe.seed);
  final profile = _profiles[difficulty]!;
  final tags = recipe.tags.toSet();
  final neutral = rules.fractions.where((fraction) => !fraction.isDeck).map((fraction) => fraction.id).toSet();
  bool allowed(String cardFraction) => cardFraction == fractionId || neutral.contains(cardFraction);

  final minUnits = rules.gameRules.minSquadCards;
  final unitTarget = minUnits + profile.extraUnits;
  final specialTarget = math.min(
    rules.gameRules.maxSpecialCards,
    profile.specials + (tags.contains(DeckTag.weather) ? 2 : 0),
  );

  final maxStrength = rules.squadCards.fold<int>(1, (top, card) => math.max(top, card.strength));
  final units = <_Candidate>[];
  for (final card in rules.squadCards) {
    if (card.count == 0 || !allowed(card.fractionId)) continue;
    if (card.isHero && !tags.contains(DeckTag.heroes) && profile.taste <= 0.5) continue;
    final strength = card.strength / maxStrength;
    var key = profile.taste * strength + profile.noise * random.nextDouble();
    key += 1.5 * _squadTags(rules, card).intersection(tags).length;
    if (tags.contains(DeckTag.weak) && !card.isHero && card.strength <= 4) key += 1.2;
    if (tags.contains(DeckTag.strong) && !card.isHero && card.strength >= 8) key += 1.2;
    if (tags.contains(DeckTag.heroes) && card.isHero) key += 1.5;
    units.add(_Candidate(card.id, card.count, key));
  }
  final specials = <_Candidate>[];
  for (final card in rules.specialCards) {
    if (card.count == 0 || !allowed(card.fractionId)) continue;
    var key = profile.noise * random.nextDouble();
    key += 3 * _specialTags(rules, card).intersection(tags).length;
    key += switch (rules.effectOfSpecialCard(card).effect) {
      EffectKey.commanderHorn => 1.0,
      EffectKey.scorch => 0.8,
      EffectKey.weather => 0.4,
      _ => 0.0,
    };
    specials.add(_Candidate(card.id, card.count, key));
  }

  final picked = <CardGrant>[
    ..._take(units, unitTarget),
    ..._take(specials, specialTarget),
  ];
  final unitCount = picked
      .where((grant) => rules.squadCardsById.containsKey(grant.cardId))
      .fold(0, (sum, g) => sum + g.copies);
  if (unitCount < minUnits) {
    throw HandDataException(['колоде фракции $fractionId не хватает отрядов: $unitCount из $minUnits']);
  }
  return picked;
}

/// Берёт карты по убыванию ключа всеми копиями, пока не наберётся [target]; последняя карта берётся неполностью.
List<CardGrant> _take(List<_Candidate> cards, int target) {
  final sorted = [...cards]..sort((a, b) => b.key != a.key ? b.key.compareTo(a.key) : a.id.compareTo(b.id));
  final result = <CardGrant>[];
  var taken = 0;
  for (final card in sorted) {
    if (taken >= target) break;
    final copies = math.min(card.count, target - taken);
    result.add(CardGrant(cardId: card.id, copies: copies));
    taken += copies;
  }
  return result;
}

Set<DeckTag> _squadTags(PackRules rules, SquadCard card) {
  final tags = <DeckTag>{};
  final effect = rules.effectOfSquadCard(card)?.effect;
  switch (effect) {
    case EffectKey.spy:
      tags.add(DeckTag.spy);
    case EffectKey.medic:
      tags.add(DeckTag.medic);
    case EffectKey.muster:
      tags.add(DeckTag.muster);
    case EffectKey.tightBond:
      tags.add(DeckTag.bond);
    case EffectKey.moraleBoost:
      tags.add(DeckTag.morale);
    case EffectKey.commanderHorn:
      tags.add(DeckTag.horn);
    case EffectKey.scorch || EffectKey.scorchRow:
      tags.add(DeckTag.scorch);
    case EffectKey.bait:
      tags.add(DeckTag.decoy);
    case EffectKey.berserk || EffectKey.mardroeme:
      tags.add(DeckTag.berserk);
    case _:
      break;
  }
  switch (rules.zonesById[card.zoneId]?.key) {
    case ZoneKey.melee:
      tags.add(DeckTag.melee);
    case ZoneKey.ranged:
      tags.add(DeckTag.ranged);
    case ZoneKey.siege:
      tags.add(DeckTag.siege);
    case ZoneKey.agile:
      tags.addAll({DeckTag.agile, DeckTag.melee, DeckTag.ranged});
    case null:
      break;
  }
  return tags;
}

Set<DeckTag> _specialTags(PackRules rules, SpecialCard card) => switch (rules.effectOfSpecialCard(card).effect) {
  EffectKey.weather => {DeckTag.weather},
  EffectKey.clearWeather => {DeckTag.clearWeather},
  EffectKey.commanderHorn => {DeckTag.horn},
  EffectKey.scorch => {DeckTag.scorch},
  EffectKey.decoy => {DeckTag.decoy},
  EffectKey.mardroeme => {DeckTag.berserk},
  _ => <DeckTag>{},
};

/// Карта, которую можно положить в колоду, и её ключ отбора.
class _Candidate {
  const _Candidate(this.id, this.count, this.key);

  final String id;
  final int count;
  final double key;
}

/// Как уровень сложности собирает колоду: лишние отряды, число особых карт, вкус к сильным картам, случайность.
class _Profile {
  const _Profile({required this.extraUnits, required this.specials, required this.taste, required this.noise});

  final int extraUnits;
  final int specials;
  final double taste;
  final double noise;
}

const Map<CampaignDifficulty, _Profile> _profiles = {
  CampaignDifficulty.easy: _Profile(extraUnits: 0, specials: 2, taste: -0.5, noise: 0.6),
  CampaignDifficulty.normal: _Profile(extraUnits: 1, specials: 4, taste: 0.2, noise: 0.8),
  CampaignDifficulty.hard: _Profile(extraUnits: 2, specials: 6, taste: 0.6, noise: 0.6),
  CampaignDifficulty.deathMatch: _Profile(extraUnits: 3, specials: 8, taste: 1, noise: 0.4),
};
