import 'package:gwent_content/src/model/zone_key.dart';

/// Зона карты отряда: ряд или признак проворной карты (`zones`).
final class Zone {
  /// Создаёт зону.
  const Zone({required this.id, required this.key, required this.nameKey});

  /// UUID зоны.
  final String id;

  /// Машинный ключ зоны.
  final ZoneKey key;

  /// Ключ строки с названием.
  final String nameKey;
}
