import 'package:gwent_engine/src/cards/faction.dart';
import 'package:gwent_engine/src/cards/ids.dart';
import 'package:gwent_engine/src/cards/leader_ability.dart';
import 'package:gwent_engine/src/cards/row.dart';
import 'package:gwent_engine/src/cards/special_ability.dart';
import 'package:gwent_engine/src/cards/unit_ability.dart';
import 'package:gwent_engine/src/core/value.dart';

/// Определение карты из пакета контента: то, что одинаково у всех её копий.
///
/// Названия и тексты движку не нужны: интерфейс берёт их из строк пакета контента.
sealed class CardDefinition extends Value {
  const CardDefinition({required this.id, required this.faction, required this.copies});

  final CardId id;
  final Faction faction;

  /// Сколько копий карты можно взять в колоду (`count` в данных). Ноль у созданных карт.
  final int copies;
}

/// Карта отряда (`squad_cards`).
final class UnitCardDefinition extends CardDefinition {
  const UnitCardDefinition({
    required super.id,
    required super.faction,
    required super.copies,
    required this.placement,
    required this.strength,
    this.isHero = false,
    this.ability,
  });

  final UnitPlacement placement;

  /// Базовая сила.
  final int strength;
  final bool isHero;
  final UnitAbility? ability;

  /// Созданная карта (раздел 1.2): в колоду не кладётся, уходя с поля, выходит из игры.
  bool get isCreated => copies == 0;

  @override
  List<Object?> get props => [id, faction, copies, placement, strength, isHero, ability];
}

/// Специальная карта (`special_cards`).
final class SpecialCardDefinition extends CardDefinition {
  const SpecialCardDefinition({
    required super.id,
    required super.faction,
    required super.copies,
    required this.ability,
  });

  final SpecialAbility ability;

  @override
  List<Object?> get props => [id, faction, copies, ability];
}

/// Карта лидера (`leader_cards`).
final class LeaderDefinition extends Value {
  const LeaderDefinition({required this.id, required this.faction, required this.ability});

  final LeaderId id;
  final Faction faction;
  final LeaderAbility ability;

  @override
  List<Object?> get props => [id, faction, ability];
}
