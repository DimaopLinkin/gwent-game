import 'package:gwent_content/gwent_content.dart';
import 'package:test/test.dart';

import 'support/sample_pack.dart';

void main() {
  List<ValidationIssue> issuesOf(Map<String, Object?> json) => switch (decodeRules(json)) {
    Decoded() => const [],
    DecodeFailed(:final issues) => issues,
  };

  test('эталонный пакет разбирается и записывается обратно без потерь', () {
    final json = samplePackJson();
    final rules = (decodeRules(json) as Decoded<PackRules>).value;
    expect(canonicalJson(encodeRules(rules)), canonicalJson(json));
    expect(rules.squadCardsById[Ids.hero]!.isHero, isTrue);
    expect(rules.zones.map((zone) => zone.key), ZoneKey.values);
  });

  test('проблемы схемы собираются все сразу и указывают путь', () {
    final json = samplePackJson();
    row(json, 'squad_cards', Ids.hero)
      ..remove('strength')
      ..['zone_id'] = 'не-uuid'
      ..['extra'] = 1;
    row(json, 'squad_cards', Ids.spy)['count'] = -1;

    final issues = issuesOf(json);
    expect(
      issues.map((issue) => issue.code),
      containsAll(['missing_field', 'invalid_uuid', 'unknown_field', 'out_of_range']),
    );
    expect(issues.every((issue) => issue.level == ValidationLevel.schema), isTrue);
    expect(issues.map((issue) => issue.path), contains(r'pack.json:$.squad_cards[0].strength'));
  });

  test('неизвестный эффект это проблема совместимости, а не схемы', () {
    final json = samplePackJson();
    row(json, 'squad_abilities', Ids.spyAbility)['effect'] = 'teleport';
    final issues = issuesOf(json);
    expect(issues.single.code, 'unknown_effect');
    expect(issues.single.level, ValidationLevel.compatibility);
  });

  test('эффект из чужой таблицы отклоняется', () {
    final json = samplePackJson();
    row(json, 'squad_abilities', Ids.spyAbility)['effect'] = 'weather';
    expect(issuesOf(json).single.code, 'effect_not_allowed');
  });

  test('у способности лидера нет name_key, у способности отряда он обязателен', () {
    final json = samplePackJson();
    row(json, 'leader_abilities', Ids.leaderAbility)['name_key'] = 'x';
    row(json, 'squad_abilities', Ids.spyAbility).remove('name_key');
    expect(issuesOf(json).map((issue) => issue.code), unorderedEquals(['unknown_field', 'missing_field']));
  });

  test('параметры у карты без способности запрещены', () {
    final json = samplePackJson();
    row(json, 'squad_cards', Ids.hero)['ability_params'] = {'draw': 1};
    expect(issuesOf(json).single.code, 'params_without_ability');
  });

  test('параметр может быть только числом, строкой или списком строк', () {
    final json = samplePackJson();
    row(json, 'squad_cards', Ids.cow)['ability_params'] = {
      'summons': [1, 2],
    };
    expect(issuesOf(json).single.code, 'wrong_type');
  });

  test('нет таблицы или корень не объект', () {
    final json = samplePackJson()..remove('zones');
    expect(issuesOf(json).single.path, r'pack.json:$.zones');
    expect(decodeRules([]), isA<DecodeFailed<PackRules>>());
  });

  test('ключ зоны только из закрытого списка, ключ фракции латиницей', () {
    final json = samplePackJson();
    row(json, 'zones', Ids.agile)['key'] = 'flying';
    row(json, 'fractions', Ids.skellige)['key'] = 'Скеллиге';
    expect(issuesOf(json).map((issue) => issue.code), ['invalid_value', 'invalid_format']);
  });
}
