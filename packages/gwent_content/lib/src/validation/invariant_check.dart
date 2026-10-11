import 'package:gwent_content/src/model/effect_key.dart';
import 'package:gwent_content/src/model/pack_rules.dart';
import 'package:gwent_content/src/model/resolved_effect.dart';
import 'package:gwent_content/src/model/squad_card.dart';
import 'package:gwent_content/src/model/string_table.dart';
import 'package:gwent_content/src/model/zone_key.dart';
import 'package:gwent_content/src/validation/issue_sink.dart';
import 'package:gwent_content/src/validation/validation_issue.dart';

/// Уровень «инварианты»: правила игры из `docs/hand/main.md`, которые держатся на данных.
///
/// Запускается только на пакете, прошедшем проверку ссылок: здесь все ссылки и параметры уже верны.
/// [fallbackStrings] нужны для проверки названий карт с Прочной связью.
List<ValidationIssue> checkInvariants(PackRules rules, StringTable fallbackStrings) {
  final sink = IssueSink(ValidationLevel.invariants);
  _checkZones(rules, sink);
  _checkFractions(rules, sink);
  _checkSquadCards(rules, fallbackStrings, sink);
  return sink.issues;
}

/// Каждая зона из закрытого списка есть ровно один раз (повторы ключей ловит проверка ссылок).
void _checkZones(PackRules rules, IssueSink sink) {
  final present = {for (final zone in rules.zones) zone.key};
  for (final key in ZoneKey.values) {
    if (!present.contains(key)) sink.add(r'$.zones', 'missing_zone', 'нет зоны ${key.key}');
  }
}

/// Раздел 2.1: у каждой фракции с колодой есть лидер и хватает карт отрядов вместе с нейтральными.
/// Лидеры бывают только у фракций с колодой.
void _checkFractions(PackRules rules, IssueSink sink) {
  final neutral = {
    for (final fraction in rules.fractions)
      if (!fraction.isDeck) fraction.id,
  };
  final neutralCopies = _copies(rules.squadCards.where((card) => neutral.contains(card.fractionId)));
  for (final (i, fraction) in rules.fractions.indexed) {
    if (!fraction.isDeck) continue;
    final path = '\$.fractions[$i]';
    if (!rules.leaderCards.any((leader) => leader.fractionId == fraction.id)) {
      sink.add(path, 'fraction_without_leaders', 'у фракции ${fraction.key} нет лидеров');
    }
    final copies = neutralCopies + _copies(rules.squadCards.where((card) => card.fractionId == fraction.id));
    if (copies < rules.gameRules.minSquadCards) {
      sink.add(
        path,
        'too_few_squad_cards',
        'фракции ${fraction.key} доступно $copies копий карт отрядов, а колоде нужно ${rules.gameRules.minSquadCards}',
      );
    }
  }
  for (final (i, leader) in rules.leaderCards.indexed) {
    if (neutral.contains(leader.fractionId)) {
      sink.add('\$.leader_cards[$i].fraction_id', 'leader_of_non_deck_fraction', 'лидер фракции без колоды');
    }
  }
}

int _copies(Iterable<SquadCard> cards) => cards.fold(0, (sum, card) => sum + card.count);

/// Разделы 1.2, 2.2 и 9.4: герои в одном экземпляре; созданные карты (`count` = 0) появляются только через
/// Приманку и Берсерка, а их цели в колоду не кладутся; Двойник призывает карты, которые есть в колоде;
/// Проворство задаётся зоной; Прочная связь опирается на уникальное название.
void _checkSquadCards(PackRules rules, StringTable fallbackStrings, IssueSink sink) {
  final effects = <String, ResolvedEffect>{
    for (final card in rules.squadCards) card.id: ?rules.effectOfSquadCard(card),
  };
  final createdTargets = <String>{};
  final names = <String, int>{};
  for (final card in rules.squadCards) {
    final name = fallbackStrings[card.nameKey];
    if (name != null) names[name] = (names[name] ?? 0) + 1;
  }

  for (final (i, card) in rules.squadCards.indexed) {
    final path = '\$.squad_cards[$i]';
    if (card.isHero && card.count > 1) {
      sink.add('$path.count', 'hero_multiple_copies', 'герой может быть только в одном экземпляре');
    }
    final effect = effects[card.id];
    switch (effect?.effect) {
      case EffectKey.bait:
      case EffectKey.berserk:
        final paramName = effect!.effect == EffectKey.bait ? 'summons' : 'transform_to';
        final targetId = effect.cardId(paramName);
        createdTargets.add(targetId);
        final target = rules.squadCardsById[targetId]!;
        if (target.count != 0) {
          sink.add('$path.$paramName', 'created_card_in_deck', 'созданная карта $targetId должна иметь count = 0');
        }
        final targetEffect = effects[targetId]?.effect;
        if (targetEffect == EffectKey.bait || targetEffect == EffectKey.berserk) {
          sink.add('$path.$paramName', 'created_card_chain', 'созданная карта $targetId сама ${targetEffect!.key}');
        }
      case EffectKey.muster:
        for (final targetId in effect!.cardIds('summons')) {
          final target = rules.squadCardsById[targetId]!;
          if (target.count == 0) {
            sink.add('$path.summons', 'muster_target_not_in_deck', 'Двойник призывает карту $targetId без копий');
          } else if (targetId == card.id && card.count < 2) {
            sink.add('$path.summons', 'muster_self_single_copy', 'карта призывает свои копии, а копия одна');
          }
        }
      case EffectKey.agile:
        sink.add('$path.ability_id', 'agile_ability_assigned', 'Проворство задаётся зоной agile, а не способностью');
      case EffectKey.tightBond:
        final name = fallbackStrings[card.nameKey];
        if (name != null && (names[name] ?? 0) > 1) {
          sink.add(
            '$path.name_key',
            'tight_bond_name_ambiguous',
            'Прочная связь считает карты по названию «$name», '
                'а оно есть у нескольких карт',
          );
        }
      case _:
        break;
    }
  }

  for (final (i, card) in rules.squadCards.indexed) {
    if (card.count == 0 && !createdTargets.contains(card.id)) {
      sink.add(
        '\$.squad_cards[$i].count',
        'unreachable_created_card',
        'карту с count = 0 не создаёт ни одна способность',
      );
    }
  }
}
