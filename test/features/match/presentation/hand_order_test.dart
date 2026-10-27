import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:gwent/src/core/l10n/l10n.dart';
import 'package:gwent/src/features/content/domain/game_content.dart';
import 'package:gwent/src/features/match/presentation/field/field_content.dart';
import 'package:gwent_engine/gwent_engine.dart';

import '../../../support/match_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late GameContent content;
  late FieldContent fieldContent;

  setUpAll(() async {
    content = await loadBaseContent();
    fieldContent = FieldContent(content: content, l10n: lookupAppLocalizations(const Locale('ru')));
  });

  var serial = 1;
  CardInstance instanceOf(String id) => CardInstance(CardInstanceId(serial++), CardId(id));

  List<CardInstance> every(Iterable<String> ids) => [for (final id in ids) instanceOf(id)];

  test('особые карты слева в порядке TW3, потом отряды по возрастанию силы', () {
    final specials = every([for (final card in content.pack.rules.specialCards) card.id]);
    final units = every([for (final card in content.pack.rules.squadCards) card.id]);
    final hand = [...units, ...specials].reversed.toList();

    final ordered = fieldContent.handOrder(hand);

    expect(ordered.toSet(), hand.toSet(), reason: 'состав руки не меняется');
    final specialPart = ordered.take(specials.length).toList();
    expect(specialPart.every((card) => fieldContent.special(card) != null), isTrue, reason: 'особые карты слева');
    String label(CardInstance card) => switch (fieldContent.special(card)!.ability) {
      DecoyAbility() => 'decoy',
      HornCardAbility() => 'horn',
      ScorchAbility() => 'scorch',
      WeatherAbility(:final rows) =>
        'weather:${(rows.toList()..sort((a, b) => a.index - b.index)).map((row) => row.name).join('+')}',
      ClearWeatherAbility() => 'clear',
      MardremCardAbility() => 'mardrem',
    };
    final labels = [for (final card in specialPart) label(card)];
    final distinct = labels.toSet().toList();
    expect(distinct.take(3), ['decoy', 'horn', 'scorch']);
    expect(distinct.skip(3).take(3), ['weather:siege', 'weather:ranged', 'weather:melee']);
    expect(distinct.skip(distinct.length - 2), ['clear', 'mardrem']);

    final unitPart = ordered.skip(specials.length).toList();
    final strengths = [for (final card in unitPart) fieldContent.baseStrength(card)];
    expect(strengths, [...strengths]..sort(), reason: 'отряды по возрастанию силы, герои среди них');
  });

  test('при равной силе карты идут по имени, а одинаковые по порядку выдачи', () {
    final squads = content.pack.rules.squadCards.toList();
    final byPower = <int, List<String>>{};
    for (final card in squads) {
      byPower.putIfAbsent(fieldContent.baseStrength(instanceOf(card.id)), () => []).add(card.id);
    }
    final group = byPower.values.firstWhere((ids) => ids.length >= 3);
    final hand = every(group).reversed.toList();

    final names = [for (final card in fieldContent.handOrder(hand)) fieldContent.face(card).name];

    expect(names, [...names]..sort());
  });

  test('новая карта встаёт на своё место, порядок не зависит от порядка прихода', () {
    final hand = every([for (final card in content.pack.rules.squadCards.take(8)) card.id]);
    final expected = fieldContent.handOrder(hand).map((card) => card.id).toList();

    expect(fieldContent.handOrder(hand.reversed.toList()).map((card) => card.id), expected);
    expect(fieldContent.handOrder(const []), isEmpty);
  });
}
