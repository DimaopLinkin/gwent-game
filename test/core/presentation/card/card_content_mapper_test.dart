import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gwent/src/core/l10n/l10n.dart';
import 'package:gwent/src/core/presentation/card/card_content_mapper.dart';
import 'package:gwent/src/core/presentation/card/card_detail.dart';
import 'package:gwent/src/core/presentation/card/card_face.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_faction.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_icon.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_weather.dart';
import 'package:gwent_content/gwent_content.dart';

import '../../../support/base_pack.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ContentPack pack;
  late CardContentMapper mapper;

  setUpAll(() async {
    pack = await loadBasePack();
    mapper = CardContentMapper(pack: pack, l10n: await AppLocalizations.delegate.load(const Locale('ru')));
  });

  CardDetail named(String name) {
    final rules = pack.rules;
    final ids = [
      for (final card in rules.squadCards)
        if (pack.text(card.nameKey) == name) card.id,
      for (final card in rules.specialCards)
        if (pack.text(card.nameKey) == name) card.id,
      for (final card in rules.leaderCards)
        if (pack.text(card.nameKey) == name) card.id,
    ];
    return mapper.byId(ids.single)!;
  }

  test('каждая карта пакета сопоставляется, и у каждой есть арт в ассетах', () async {
    final rules = pack.rules;
    final ids = [
      for (final card in rules.squadCards) card.id,
      for (final card in rules.specialCards) card.id,
      for (final card in rules.leaderCards) card.id,
    ];
    expect(ids, isNotEmpty);
    for (final id in ids) {
      final detail = mapper.byId(id)!;
      expect(detail.face.name, isNot(contains('.')), reason: id);
      final art = detail.face.art! as AssetImage;
      expect((await rootBundle.load(art.assetName)).lengthInBytes, greaterThan(0), reason: art.assetName);
    }
    expect(mapper.byId('00000000-0000-4000-8000-000000000000'), isNull);
  });

  test('проворный отряд: иконка ряда «проворный», способность и строка «фракция · ряд · тип»', () {
    final olaf = named('Олаф');
    expect(
      olaf.face,
      isA<UnitCardFace>()
          .having((f) => f.faction, 'faction', GwentFaction.skellige)
          .having((f) => f.row, 'row', GwentIcon.rowAgile)
          .having((f) => f.ability, 'ability', GwentIcon.abilityMoraleBoost)
          .having((f) => f.basePower, 'basePower', 12),
    );
    expect(olaf.meta, 'Скеллиге · Ближний бой / Дальний бой · Отряд');
    expect(olaf.abilities.map((a) => a.icon), [GwentIcon.abilityMoraleBoost]);
    expect(olaf.quote, isNotNull);
  });

  test('герой: первой строкой свойство героя', () {
    final hjalmar = named('Хьялмар');
    expect(hjalmar.face, isA<UnitCardFace>().having((f) => f.isHero, 'isHero', isTrue));
    expect(hjalmar.meta, endsWith('· Герой'));
    expect(hjalmar.abilities.first.icon, GwentIcon.iconCrownLeading);
    expect(hjalmar.abilities.first.name, 'Герой');
  });

  test('погода по рядам эффекта, ясное небо — тоже погода', () {
    final expected = {
      'Мороз': GwentWeather.frost,
      'Мгла': GwentWeather.fog,
      'Ливень': GwentWeather.rain,
      'Шторм со Скеллиге': GwentWeather.skelligeStorm,
      'Ясное небо': GwentWeather.clear,
    };
    for (final MapEntry(key: name, value: weather) in expected.entries) {
      final detail = named(name);
      expect(detail.face, isA<WeatherCardFace>().having((f) => f.weather, 'weather', weather), reason: name);
      expect(detail.meta, startsWith('Погода · '), reason: name);
    }
    expect(named('Мороз').meta, 'Погода · Общая');
  });

  test('особые карты получают иконку своего эффекта', () {
    final expected = {
      'Командирский рог': GwentIcon.specialCommanderHorn,
      'Казнь': GwentIcon.specialScorch,
      'Чучело': GwentIcon.specialDecoy,
      'Мардрём': GwentIcon.specialMardroeme,
    };
    for (final MapEntry(key: name, value: icon) in expected.entries) {
      final detail = named(name);
      expect(detail.face, isA<SpecialCardFace>().having((f) => f.effect, 'effect', icon), reason: name);
      expect(detail.meta, startsWith('Особая карта · '), reason: name);
      expect(detail.abilities.single.icon, icon, reason: name);
    }
  });

  test('лидер: герб фракции, «Способность лидера» и состояние способности', () {
    final leader = pack.rules.leaderCards.firstWhere((card) => pack.text(card.nameKey).startsWith('Эмгыр'));
    final ready = mapper.leader(leader);
    expect(ready.face, isA<LeaderCardFace>().having((f) => f.faction, 'faction', GwentFaction.nilfgaard));
    expect(ready.meta, 'Нильфгаард · Лидер · способность доступна');
    expect(ready.abilities.single.name, 'Способность лидера');
    expect(mapper.leader(leader, abilityUsed: true).meta, endsWith('способность использована'));
  });

  test('сила на столе и иней передаются в карту', () {
    final card = pack.rules.squadCards.firstWhere((card) => !card.isHero && card.count > 0);
    final face = mapper.squad(card, power: 1, frosted: true).face as UnitCardFace;
    expect((face.power, face.basePower, face.frosted), (1, card.strength, true));
  });
}
