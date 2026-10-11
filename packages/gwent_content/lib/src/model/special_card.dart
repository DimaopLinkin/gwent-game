import 'package:gwent_content/src/model/raw_params.dart';

/// Специальная карта (`special_cards`).
final class SpecialCard {
  /// Создаёт специальную карту.
  const SpecialCard({
    required this.id,
    required this.fractionId,
    required this.abilityId,
    required this.abilityParams,
    required this.count,
    required this.nameKey,
    required this.descriptionKey,
  });

  /// UUID карты. Не меняется никогда.
  final String id;

  /// UUID фракции.
  final String fractionId;

  /// UUID способности (`special_abilities`).
  final String abilityId;

  /// Параметры эффекта, свои у этой карты.
  final RawParams abilityParams;

  /// Сколько копий можно взять в колоду.
  final int count;

  /// Ключ строки с названием.
  final String nameKey;

  /// Ключ строки с описанием (цитатой).
  final String descriptionKey;
}
