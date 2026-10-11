import 'package:gwent_content/src/model/effect_key.dart';
import 'package:gwent_content/src/model/raw_params.dart';

/// Способность из таблиц `squad_abilities`, `special_abilities`, `leader_abilities` или `fraction_abilities`.
final class Ability {
  /// Создаёт способность.
  const Ability({
    required this.id,
    required this.effect,
    required this.params,
    required this.nameKey,
    required this.descriptionKey,
  });

  /// UUID способности.
  final String id;

  /// Эффект, который реализует движок.
  final EffectKey effect;

  /// Общие для всех карт параметры эффекта. Параметры конкретной карты лежат в её `ability_params`.
  final RawParams params;

  /// Ключ строки с названием. У способностей лидеров и перков фракций названия нет.
  final String? nameKey;

  /// Ключ строки с описанием.
  final String descriptionKey;
}
