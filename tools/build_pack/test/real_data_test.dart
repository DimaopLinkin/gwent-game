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

  test('эффекты всех лидеров по разделу 10 main.md', () {
    String special(String cardId) => name(rules.specialCardsById[cardId]!.nameKey);
    final expected = <String, (EffectKey, Map<String, Object>)>{
      'Фольтест: Король Темерии': (EffectKey.playWeatherFromDeck, {'card_id': 'Мгла'}),
      'Фольтест: Предводитель Севера': (EffectKey.clearWeather, {}),
      'Фольтест: Завоеватель': (EffectKey.leaderHorn, {'row': CombatRow.siege}),
      'Фольтест: Железный Владыка': (EffectKey.scorchRow, {'row': CombatRow.siege, 'threshold': 10}),
      'Фольтест: Сын Меделла': (EffectKey.scorchRow, {'row': CombatRow.ranged, 'threshold': 10}),
      'Эмгыр вар Эмрейс: Йож из Эрленвальда': (EffectKey.playWeatherFromDeck, {'card_id': 'Ливень'}),
      'Эмгыр вар Эмрейс: Император Нильфгаарда': (EffectKey.revealOpponentHand, {'count': 3}),
      'Эмгыр вар Эмрейс: Белое Пламя, Пляшущее на Курганах Врагов': (EffectKey.disableOpponentLeader, {}),
      'Эмгыр вар Эмрейс: Властелин Юга': (EffectKey.takeFromOpponentDiscard, {}),
      'Эмгыр вар Эмрейс: Завоеватель Севера': (EffectKey.randomMedic, {}),
      'Эредин Бреакк Глас: Король Aen Elle': (EffectKey.leaderHorn, {'row': CombatRow.melee}),
      'Эредин Бреакк Глас: Владыка Тир на Лиа': (EffectKey.returnFromDiscard, {}),
      'Эредин Бреакк Глас: Убийца Оберона': (EffectKey.discardAndDraw, {'discard': 2, 'draw': 1}),
      'Эредин Бреакк Глас: Командир Дикой Охоты': (EffectKey.playAnyWeatherFromDeck, {}),
      'Эредин Бреакк Глас: Вероломный': (EffectKey.doubleSpies, {}),
      'Францеска Финдабаир: Истинная эльфка': (EffectKey.playWeatherFromDeck, {'card_id': 'Мороз'}),
      'Францеска Финдабаир: Королева Дол Блатанны': (EffectKey.scorchRow, {'row': CombatRow.melee, 'threshold': 10}),
      'Францеска Финдабаир: Прекраснейшая': (EffectKey.leaderHorn, {'row': CombatRow.ranged}),
      'Францеска Финдабаир: Маргаритка из Долин': (EffectKey.extraStartingCard, {'count': 1}),
      'Францеска Финдабаир: Надежда Aen Seidhe': (EffectKey.optimizeAgile, {}),
      'Король Бран': (EffectKey.halveWeather, {}),
      'Крах ан Крайт': (EffectKey.shuffleDiscardsIntoDecks, {}),
    };
    expect(rules.leaderCards.map((card) => name(card.nameKey)).toSet(), expected.keys.toSet());
    for (final card in rules.leaderCards) {
      final effect = rules.effectOfLeaderCard(card);
      final (key, params) = expected[name(card.nameKey)]!;
      expect(effect.effect, key, reason: name(card.nameKey));
      expect(
        {
          for (final MapEntry(key: param, :value) in effect.params.entries)
            param: switch (value) {
              CountParam(:final value) => value,
              RowParam(:final value) => value,
              CardRefParam(:final cardId) => special(cardId),
              RowsParam() || CardRefsParam() => fail('у лидера нет списков'),
            },
        },
        params,
        reason: name(card.nameKey),
      );
    }
  });

  test('эффекты всех специальных карт по разделу 9.3 main.md', () {
    final expected = <String, (EffectKey, List<CombatRow>?)>{
      'Мороз': (EffectKey.weather, [CombatRow.melee]),
      'Мгла': (EffectKey.weather, [CombatRow.ranged]),
      'Ливень': (EffectKey.weather, [CombatRow.siege]),
      'Шторм со Скеллиге': (EffectKey.weather, [CombatRow.ranged, CombatRow.siege]),
      'Ясное небо': (EffectKey.clearWeather, null),
      'Командирский рог': (EffectKey.commanderHorn, null),
      'Мардрём': (EffectKey.mardroeme, null),
      'Чучело': (EffectKey.decoy, null),
      'Казнь': (EffectKey.scorch, null),
    };
    expect(rules.specialCards.map((card) => name(card.nameKey)).toSet(), expected.keys.toSet());
    for (final card in rules.specialCards) {
      final effect = rules.effectOfSpecialCard(card);
      final (key, rows) = expected[name(card.nameKey)]!;
      expect(effect.effect, key, reason: name(card.nameKey));
      expect(effect.params.isEmpty ? null : effect.rows('rows'), rows, reason: name(card.nameKey));
    }
  });

  test('перки всех фракций по разделу 11 main.md', () {
    final expected = <String, (EffectKey, Map<String, int>)>{
      'northern_realms': (EffectKey.drawOnRoundWin, {'count': 1}),
      'nilfgaardian_empire': (EffectKey.winOnTie, {}),
      'monsters': (EffectKey.keepRandomUnit, {'count': 1}),
      'scoia_tael': (EffectKey.chooseFirstPlayer, {}),
      'skellige': (EffectKey.reviveRandomUnits, {'count': 2, 'round': 3}),
    };
    for (final fraction in rules.fractions.where((fraction) => fraction.isDeck)) {
      final perk = rules.perkOfFraction(fraction)!;
      final (key, params) = expected[fraction.key]!;
      expect(perk.effect, key, reason: fraction.key);
      expect({for (final param in params.keys) param: perk.count(param)}, params, reason: fraction.key);
    }
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
