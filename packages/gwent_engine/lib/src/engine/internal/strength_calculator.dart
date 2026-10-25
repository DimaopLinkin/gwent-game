import 'package:gwent_engine/src/cards/card_catalog.dart';
import 'package:gwent_engine/src/cards/card_definition.dart';
import 'package:gwent_engine/src/cards/ids.dart';
import 'package:gwent_engine/src/cards/special_ability.dart';
import 'package:gwent_engine/src/cards/unit_ability.dart';
import 'package:gwent_engine/src/state/field_card.dart';
import 'package:gwent_engine/src/state/row_slot.dart';

/// Условия ряда, от которых зависит сила его карт.
final class RowConditions {
  const RowConditions({required this.weather, required this.halveWeather, required this.doubleSpies});

  /// На ряд действует погода.
  final bool weather;

  /// Погода уменьшает силу вдвое, а не до 1 (Король Бран на этой стороне).
  final bool halveWeather;

  /// Шпионы удваиваются (Вероломный).
  final bool doubleSpies;
}

/// Расчёт текущей силы карт ряда (раздел 8 правил).
///
/// Порядок шагов: погода → Вероломный → Прилив сил → Прочная связь → рог. Герой всегда равен базовой силе,
/// Чучело всегда 0.
final class StrengthCalculator {
  const StrengthCalculator(this._catalog);

  final CardCatalog _catalog;

  /// Текущая сила каждой карты ряда, в порядке [cards].
  List<int> row(List<FieldCard> cards, RowSlot? slot, RowConditions conditions) {
    final units = [for (final card in cards) _catalog.card(card.card.cardId)];
    final bondCounts = <CardId, int>{};
    var moraleSources = 0;
    var hornUnits = 0;
    for (final unit in units.whereType<UnitCardDefinition>()) {
      bondCounts[unit.id] = (bondCounts[unit.id] ?? 0) + 1;
      if (unit.ability is MoraleBoostAbility) moraleSources++;
      if (unit.ability is UnitHornAbility) hornUnits++;
    }
    final slotHorn = switch (slot) {
      LeaderHornSlot() => true,
      CardSlot(:final card) => switch (_catalog.card(card.cardId)) {
        SpecialCardDefinition(ability: HornCardAbility()) => true,
        _ => false,
      },
      null => false,
    };

    return [
      for (final definition in units)
        switch (definition) {
          UnitCardDefinition() => _unit(
            definition,
            conditions,
            bondCount: bondCounts[definition.id]!,
            moraleSources: moraleSources,
            horned: slotHorn || hornUnits > (definition.ability is UnitHornAbility ? 1 : 0),
          ),
          SpecialCardDefinition() || null => 0,
        },
    ];
  }

  int _unit(
    UnitCardDefinition unit,
    RowConditions conditions, {
    required int bondCount,
    required int moraleSources,
    required bool horned,
  }) {
    if (unit.isHero) return unit.strength;
    var strength = unit.strength;
    if (conditions.weather) {
      strength = conditions.halveWeather ? _min(strength, _max(1, strength ~/ 2)) : _min(strength, 1);
    }
    final ability = unit.ability;
    if (conditions.doubleSpies && ability is SpyAbility) strength *= 2;
    strength += moraleSources - (ability is MoraleBoostAbility ? 1 : 0);
    if (ability is TightBondAbility && bondCount > 1) strength *= bondCount;
    if (horned) strength *= 2;
    return strength;
  }

  static int _min(int a, int b) => a < b ? a : b;

  static int _max(int a, int b) => a > b ? a : b;
}
