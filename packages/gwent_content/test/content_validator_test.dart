import 'package:gwent_content/gwent_content.dart';
import 'package:test/test.dart';

import 'support/sample_pack.dart';

void main() {
  late Map<String, Object?> pack;
  late Map<String, Object?> strings;

  setUp(() {
    pack = samplePackJson();
    strings = sampleStringsJson();
  });

  List<ValidationIssue> issues() => switch (validateContent(pack, {fallbackLocale: strings})) {
    Decoded() => const [],
    DecodeFailed(:final issues) => issues,
  };

  List<String> codes() => [for (final issue in issues()) issue.code];

  test('эталонный пакет проходит все уровни и отдаёт эффекты с параметрами', () {
    final content = (validateContent(pack, {fallbackLocale: strings}) as Decoded<ValidatedContent>).value;
    final rules = content.rules;
    expect(rules.effectOfSquadCard(rules.squadCardsById[Ids.spy]!)!.count('draw'), 2);
    expect(rules.effectOfSquadCard(rules.squadCardsById[Ids.muster]!)!.cardIds('summons'), [Ids.muster]);
    final scorch = rules.effectOfSquadCard(rules.squadCardsById[Ids.scorcher]!)!;
    expect((scorch.effect, scorch.row('row'), scorch.count('threshold')), (EffectKey.scorchRow, CombatRow.melee, 10));
    expect(rules.effectOfLeaderCard(rules.leaderCardsById[Ids.leader]!).cardId('card_id'), Ids.frost);
    expect(rules.effectOfSpecialCard(rules.specialCardsById[Ids.frost]!).rows('rows'), [CombatRow.melee]);
    expect(rules.perkOfFraction(rules.fractionsById[Ids.skellige]!)!.count('round'), 3);
    expect(rules.effectOfSquadCard(rules.squadCardsById[Ids.hero]!), isNull);
    expect(() => scorch.cardId('row'), throwsStateError);
  });

  test('нет строк запасного языка', () {
    expect(switch (validateContent(pack, const {})) {
      Decoded() => null,
      DecodeFailed(:final issues) => issues.single.code,
    }, 'missing_fallback_locale');
  });

  group('ссылки', () {
    test('ссылка на несуществующую запись', () {
      row(pack, 'squad_cards', Ids.hero)['fraction_id'] = id(999);
      row(pack, 'leader_cards', Ids.leader)['ability_id'] = id(998);
      expect(codes(), ['unknown_reference', 'unknown_reference']);
      expect(issues().first.level, ValidationLevel.references);
      expect(issues().first.path, r'pack.json:$.squad_cards[0].fraction_id');
    });

    test('UUID и ключи уникальны во всём пакете', () {
      row(pack, 'special_cards', Ids.frost)['id'] = Ids.hero;
      row(pack, 'fractions', Ids.neutral)['key'] = 'skellige';
      expect(codes(), containsAll(['duplicate_id', 'duplicate_key']));
    });

    test('параметры: нет нужного, лишний, конфликт со способностью, неверный тип', () {
      row(pack, 'squad_cards', Ids.cow)['ability_params'] = <String, Object?>{};
      row(pack, 'squad_cards', Ids.berserk)['ability_params'] = {'transform_to': Ids.bear, 'speed': 2};
      row(pack, 'squad_cards', Ids.spy)['ability_params'] = {'draw': 1};
      row(pack, 'squad_cards', Ids.scorcher)['ability_params'] = {'row': 'sky'};
      expect(codes(), unorderedEquals(['missing_param', 'unknown_param', 'param_conflict', 'invalid_param']));
    });

    test('ссылки в параметрах ведут в нужную таблицу', () {
      row(pack, 'squad_cards', Ids.muster)['ability_params'] = {
        'summons': [id(999)],
      };
      row(pack, 'leader_abilities', Ids.leaderAbility)['params'] = {'card_id': Ids.hero};
      expect(codes(), ['unknown_reference', 'unknown_reference']);
    });

    test('у каждого ключа есть текст и каждый текст кому-то нужен', () {
      strings
        ..remove('lc.name')
        ..['orphan'] = 'лишний';
      expect(codes(), ['missing_string', 'unused_string']);
      expect(issues().last.path, r'strings.ru.json:$["orphan"]');
    });
  });

  group('инварианты', () {
    test('все зоны на месте', () {
      rows(pack, 'zones').removeWhere((zone) => zone['key'] == 'siege');
      strings.remove('zone.siege');
      expect(codes(), ['missing_zone']);
      expect(issues().single.level, ValidationLevel.invariants);
    });

    test('у фракции с колодой есть лидер и хватает карт отрядов', () {
      rows(pack, 'leader_cards').clear();
      strings
        ..remove('lc.name')
        ..remove('lc.description');
      (pack['game_rules']! as Map<String, Object?>)['min_squad_cards'] = 50;
      expect(codes(), ['fraction_without_leaders', 'too_few_squad_cards']);
    });

    test('лидер только у фракции с колодой', () {
      row(pack, 'leader_cards', Ids.leader)['fraction_id'] = Ids.neutral;
      expect(codes(), ['fraction_without_leaders', 'leader_of_non_deck_fraction']);
    });

    test('герой только в одном экземпляре', () {
      row(pack, 'squad_cards', Ids.hero)['count'] = 2;
      expect(codes(), ['hero_multiple_copies']);
    });

    test('созданные карты: цель Приманки не кладётся в колоду, у карты с count 0 есть создатель', () {
      row(pack, 'squad_cards', Ids.bovine)['count'] = 1;
      row(pack, 'squad_cards', Ids.berserk)['ability_params'] = {'transform_to': Ids.hero};
      expect(codes(), ['created_card_in_deck', 'created_card_in_deck', 'unreachable_created_card']);
    });

    test('цель Берсерка сама не Берсерк', () {
      row(pack, 'squad_cards', Ids.bear)
        ..['ability_id'] = Ids.berserkAbility
        ..['ability_params'] = {'transform_to': Ids.bear};
      // Сообщают обе карты: исходный Берсерк и сама созданная карта, ставшая Берсерком.
      expect(codes(), ['created_card_chain', 'created_card_chain']);
    });

    test('Двойник призывает карты из колоды; призыв своих копий требует больше одной копии', () {
      row(pack, 'squad_cards', Ids.muster)
        ..['count'] = 1
        ..['ability_params'] = {
          'summons': [Ids.muster, Ids.bovine],
        };
      expect(codes(), ['muster_self_single_copy', 'muster_target_not_in_deck']);
    });

    test('Проворство не назначается способностью', () {
      row(pack, 'squad_cards', Ids.hero)['ability_id'] = Ids.agileAbility;
      expect(codes(), ['agile_ability_assigned']);
    });

    test('Прочная связь требует уникального названия', () {
      strings['card.${Ids.hero}.name'] = strings['card.${Ids.bond}.name'];
      expect(codes(), ['tight_bond_name_ambiguous']);
    });
  });
}
