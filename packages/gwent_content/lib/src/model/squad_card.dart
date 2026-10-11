import 'package:gwent_content/src/model/raw_params.dart';

/// Карта отряда (`squad_cards`).
final class SquadCard {
  /// Создаёт карту отряда.
  const SquadCard({
    required this.id,
    required this.fractionId,
    required this.zoneId,
    required this.strength,
    required this.isHero,
    required this.count,
    required this.abilityId,
    required this.abilityParams,
    required this.nameKey,
    required this.descriptionKey,
  });

  /// UUID карты. Не меняется никогда.
  final String id;

  /// UUID фракции.
  final String fractionId;

  /// UUID зоны.
  final String zoneId;

  /// Базовая сила.
  final int strength;

  /// Герой: на него не действуют спецкарты и способности (раздел 9.1).
  final bool isHero;

  /// Сколько копий можно взять в колоду. 0 у созданных карт, которые в колоду не кладутся (раздел 1.2).
  final int count;

  /// UUID способности (`squad_abilities`) или `null`.
  final String? abilityId;

  /// Параметры эффекта, свои у этой карты. Пусто, если способности нет.
  final RawParams abilityParams;

  /// Ключ строки с названием.
  final String nameKey;

  /// Ключ строки с описанием (цитатой).
  final String descriptionKey;
}
