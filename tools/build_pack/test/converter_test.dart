import 'package:gwent_build_pack/gwent_build_pack.dart';
import 'package:gwent_content/gwent_content.dart';
import 'package:test/test.dart';

import 'support.dart';

void main() {
  List<Map<String, Object?>> table(Map<String, Object?> tables, String name) =>
      (tables[name]! as List<Object?>).cast<Map<String, Object?>>();

  List<String> problemsOf(Map<String, Object?> tables) {
    try {
      convertHandData(tables);
      return const [];
    } on HandDataException catch (e) {
      return e.problems;
    }
  }

  test('у каждого тега способности и зоны в docs/hand есть сопоставление, лишних сопоставлений нет', () {
    final tables = realTables();
    Set<String> tags(String name) => {for (final row in table(tables, name)) row['tag']! as String};
    expect(tags('zones'), zoneKeysByTag.keys.toSet());
    expect(tags('squad_card_abilities'), squadEffectsByTag.keys.toSet());
    expect(tags('special_card_abilities'), specialEffectsByTag.keys.toSet());
    expect(tags('leader_card_abilities'), leaderEffectsByTag.keys.toSet());
    expect(tags('fraction_abilities'), fractionEffectsByTag.keys.toSet());
  });

  test('сборка детерминирована и не зависит от порядка строк в таблицах', () async {
    final (first, _) = await buildAndVerify(realTables(), realIdentity());
    final shuffled = realTables();
    for (final name in handTables.where((name) => name != 'game_rules')) {
      shuffled[name] = table(shuffled, name).reversed.toList();
    }
    final (second, _) = await buildAndVerify(shuffled, realIdentity());
    expect(second.files.keys, first.files.keys);
    for (final path in first.files.keys) {
      expect(second.files[path], first.files[path], reason: path);
    }
  });

  test('тексты уходят в строки, в правилах остаются ключи', () {
    final converted = convertHandData(realTables());
    final card = converted.rules.squadCards.first;
    expect(card.nameKey, 'squad_card.${card.id}.name');
    expect(converted.strings[card.nameKey], isNotEmpty);
    expect(converted.strings.locale, fallbackLocale);
  });

  test('неизвестный тег способности', () {
    final tables = realTables();
    table(tables, 'squad_card_abilities').first['tag'] = 'teleport';
    expect(problemsOf(tables), contains(contains('нет эффекта для tag teleport')));
  });

  test('связь Двойника у карты без Двойника и Приманка без связи', () {
    final tables = realTables();
    final geralt = table(tables, 'squad_cards').firstWhere((card) => card['name'] == 'Геральт из Ривии');
    table(tables, 'twin_config').first['squad_card_trigger_id'] = geralt['id'];
    table(tables, 'bait_config').removeAt(0);
    expect(problemsOf(tables), hasLength(greaterThanOrEqualTo(2)));
    expect(problemsOf(tables), contains(contains('bait_config: нет связей')));
    expect(problemsOf(tables), contains(contains('twin_config: карта ${geralt['id']} не имеет нужной способности')));
  });

  test('нет таблицы или поле не того типа', () {
    final tables = realTables()..remove('game_rules');
    table(tables, 'squad_cards').first['strength'] = '15';
    expect(problemsOf(tables), containsAll([contains('game_rules'), contains('поле strength')]));
  });

  test('испорченные данные, которые конвертер пропускает, ловит валидатор', () async {
    final tables = realTables();
    table(tables, 'squad_cards').firstWhere((card) => card['name'] == 'Геральт из Ривии')['count'] = 2;
    final (_, result) = await buildAndVerify(tables, realIdentity());
    expect((result as PackRejected).issues.single.code, 'hero_multiple_copies');
  });
}
