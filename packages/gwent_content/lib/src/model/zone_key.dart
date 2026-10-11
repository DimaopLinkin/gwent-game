/// Машинный ключ зоны карты отряда (`zones[].key`).
enum ZoneKey {
  /// Ближний бой.
  melee,

  /// Дальний бой.
  ranged,

  /// Осадные.
  siege,

  /// Проворная карта: ближний или дальний ряд по выбору игрока. Не ряд на поле.
  agile
  ;

  /// Машинный ключ зоны в пакете.
  String get key => name;

  /// Зона по ключу или `null`, если ключ неизвестен.
  static ZoneKey? fromKey(String key) {
    for (final zone in values) {
      if (zone.key == key) return zone;
    }
    return null;
  }
}
