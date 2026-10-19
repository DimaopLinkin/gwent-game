import 'package:flutter_test/flutter_test.dart';

import '../../../support/base_pack.dart';
import '../../../support/deck_rules_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('фракции с колодой в порядке пакета, у каждой свои лидеры; нейтральной нет', () {
    final factions = smallDeckRules.factionInfos;

    expect(factions.map((faction) => faction.id), [Small.skellige, Small.monsters]);
    expect(factions.first.name, 'Скеллиге');
    expect(factions.first.leaders.map((leader) => leader.id), [Small.crach, Small.bran]);
    expect(factions.last.leaders.map((leader) => leader.id), [Small.eredin]);
    expect(factions.every((faction) => faction.leaders.every((leader) => leader.factionId == faction.id)), isTrue);
  });

  test('лидера ищут среди лидеров своей фракции; список лидеров не меняют', () {
    final skellige = smallDeckRules.factionInfos.first;

    expect(skellige.leader(Small.bran)?.id, Small.bran);
    expect(skellige.leader(Small.eredin), isNull);
    expect(() => skellige.leaders.add(skellige.leaders.first), throwsUnsupportedError);
    expect(skellige.leaders.every((leader) => leader.available), isTrue, reason: 'коллекции пока нет');
  });

  test('в настоящем пакете у каждой фракции есть имя и хотя бы один лидер с описанием способности', () async {
    final pack = await loadBasePack();
    final rules = deckRulesFor(pack);

    expect(rules.factionInfos, hasLength(5));
    for (final faction in rules.factionInfos) {
      expect(faction.name, isNotEmpty, reason: faction.key);
      expect(faction.leaders, isNotEmpty, reason: faction.key);
      for (final leader in faction.leaders) {
        expect(leader.name, isNot(startsWith('card.')), reason: 'имя лидера взято из строк пакета');
        expect(leader.ability, isNotEmpty, reason: leader.name);
      }
    }
  });
}
