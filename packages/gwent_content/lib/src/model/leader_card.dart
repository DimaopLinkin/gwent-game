import 'package:gwent_content/src/model/raw_params.dart';

/// Карта лидера (`leader_cards`).
final class LeaderCard {
  /// Создаёт карту лидера.
  const LeaderCard({
    required this.id,
    required this.fractionId,
    required this.abilityId,
    required this.abilityParams,
    required this.nameKey,
    required this.descriptionKey,
  });

  /// UUID карты. Не меняется никогда.
  final String id;

  /// UUID фракции.
  final String fractionId;

  /// UUID способности (`leader_abilities`).
  final String abilityId;

  /// Параметры эффекта, свои у этой карты.
  final RawParams abilityParams;

  /// Ключ строки с названием.
  final String nameKey;

  /// Ключ строки с описанием (цитатой).
  final String descriptionKey;
}
