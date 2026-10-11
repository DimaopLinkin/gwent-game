/// Ряд на поле, на который ссылаются параметры эффектов (`row`, `rows`).
enum CombatRow {
  /// Ближний бой.
  melee,

  /// Дальний бой.
  ranged,

  /// Осадные.
  siege
  ;

  /// Машинный ключ ряда в пакете.
  String get key => name;

  /// Ряд по ключу или `null`, если ключ неизвестен.
  static CombatRow? fromKey(String key) {
    for (final row in values) {
      if (row.key == key) return row;
    }
    return null;
  }
}
