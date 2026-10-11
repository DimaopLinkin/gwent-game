import 'package:gwent_build_pack/gwent_build_pack.dart';
import 'package:gwent_content/gwent_content.dart';
import 'package:test/test.dart';

import 'support.dart';

/// Пакет из настоящих `docs/hand/data` проходит все пять уровней проверки и совпадает с правилами `main.md`.
void main() {
  late ContentPack pack;
  late PackRules rules;

  setUpAll(() async {
    final (_, result) = await buildAndVerify(realTables(), realIdentity());
    if (result case PackRejected(:final issues)) fail('пакет отклонён:\n${issues.join('\n')}');
    pack = (result as PackLoaded).pack;
    rules = pack.rules;
  });

  String name(String nameKey) => pack.text(nameKey);
  SquadCard squad(String cardName) => rules.squadCards.singleWhere((card) => name(card.nameKey) == cardName);
  Iterable<String> names(List<String> ids) => ids.map((cardId) => name(rules.squadCardsById[cardId]!.nameKey));

  test('все карты, лидеры и фракции на месте', () {
    expect(pack.manifest.packId, 'gwent-w3-base');
    expect(pack.manifest.locales, [fallbackLocale]);
    expect(rules.squadCards, hasLength(153));
    expect(rules.specialCards, hasLength(9));
    expect(rules.leaderCards, hasLength(22));
    expect(rules.fractions.where((fraction) => fraction.isDeck).map((fraction) => fraction.key), {
      'northern_realms',
      'nilfgaardian_empire',
      'monsters',
      'scoia_tael',
      'skellige',
    });
  });

  test('параметры партии и колоды из docs/hand/main.md', () {
    final gameRules = rules.gameRules;
    expect(
      (
        gameRules.crystals,
        gameRules.startingHandSize,
        gameRules.maxRedraws,
        gameRules.minSquadCards,
        gameRules.maxSpecialCards,
      ),
      (2, 10, 2, 22, 10),
    );
  });

  test('карта отряда: сила, ряд, герой, фракция и тексты', () {
    final geralt = squad('Геральт из Ривии');
    expect((geralt.strength, geralt.isHero, geralt.count, geralt.abilityId), (15, true, 1, null));
    expect(rules.zonesById[geralt.zoneId]!.key, ZoneKey.melee);
    expect(rules.fractionsById[geralt.fractionId]!.key, 'common');
    expect(pack.text(geralt.descriptionKey), startsWith('Если нужно выбирать'));
  });

  test('Двойник несимметричен и может призывать свои копии', () {
    expect(names(rules.effectOfSquadCard(squad('Огромный главоглаз'))!.cardIds('summons')), ['Главоглаз']);
    expect(names(rules.effectOfSquadCard(squad('Главоглаз'))!.cardIds('summons')), ['Главоглаз']);
    expect(names(rules.effectOfSquadCard(squad('Керис'))!.cardIds('summons')), ['Воительница клана Друммонд']);
  });

  test('Приманка и Берсерк ведут на созданные карты', () {
    final bait = rules.effectOfSquadCard(squad('Корова'))!;
    expect(names([bait.cardId('summons')]), ['Скотские вооруженные силы']);
    final berserk = rules.effectOfSquadCard(squad('Берсерк'))!;
    expect(names([berserk.cardId('transform_to')]), ['Обратившийся вильдкаарл']);
    expect(rules.squadCards.where((card) => card.count == 0).map((card) => name(card.nameKey)), {
      'Хеймдалль',
      'Скотские вооруженные силы',
      'Обратившийся вильдкаарл',
      'Обратившийся молодой вильдкаарл',
    });
  });

  test('Казнь по ряду: ряд берётся из зоны карты, порог 10', () {
    for (final (cardName, row) in [
      ('Виллентретенмерт', CombatRow.melee),
      ('Принц-жаба', CombatRow.ranged),
      ('Ширру', CombatRow.siege),
    ]) {
      final effect = rules.effectOfSquadCard(squad(cardName))!;
      expect((effect.effect, effect.row('row'), effect.count('threshold')), (EffectKey.scorchRow, row, 10));
    }
    expect(rules.effectOfSquadCard(squad('Пират из клана Димун'))!.effect, EffectKey.scorch);
  });

  test('погода и лидеры, которые играют погоду из колоды', () {
    SpecialCard special(String cardName) => rules.specialCards.singleWhere((card) => name(card.nameKey) == cardName);
    expect(rules.effectOfSpecialCard(special('Шторм со Скеллиге')).rows('rows'), [CombatRow.ranged, CombatRow.siege]);
    final foltest = rules.leaderCards.singleWhere((card) => name(card.nameKey) == 'Фольтест: Король Темерии');
    final effect = rules.effectOfLeaderCard(foltest);
    expect(effect.effect, EffectKey.playWeatherFromDeck);
    expect(name(rules.specialCardsById[effect.cardId('card_id')]!.nameKey), 'Мгла');
  });

  test('перки фракций', () {
    final skellige = rules.fractions.singleWhere((fraction) => fraction.key == 'skellige');
    final perk = rules.perkOfFraction(skellige)!;
    expect((perk.effect, perk.count('count'), perk.count('round')), (EffectKey.reviveRandomUnits, 2, 3));
    expect(rules.perkOfFraction(rules.fractions.singleWhere((fraction) => fraction.key == 'common')), isNull);
  });

  test('каждая фракция с колодой может собрать колоду из 22 карт отрядов', () {
    final neutral = {
      for (final fraction in rules.fractions)
        if (!fraction.isDeck) fraction.id,
    };
    for (final fraction in rules.fractions.where((fraction) => fraction.isDeck)) {
      final copies = rules.squadCards
          .where((card) => card.fractionId == fraction.id || neutral.contains(card.fractionId))
          .fold(0, (sum, card) => sum + card.count);
      expect(copies, greaterThanOrEqualTo(22), reason: fraction.key);
      expect(rules.leaderCards.where((leader) => leader.fractionId == fraction.id), isNotEmpty, reason: fraction.key);
    }
  });
}
