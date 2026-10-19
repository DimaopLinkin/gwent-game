/// Ряд на стороне игрока.
enum Row {
  /// Ближний бой.
  melee,

  /// Дальний бой.
  ranged,

  /// Осадные.
  siege,
}

/// Куда кладётся карта отряда: в один ряд или, у проворной карты, в ближний либо дальний по выбору игрока.
enum UnitPlacement {
  melee(Row.melee),
  ranged(Row.ranged),
  siege(Row.siege),

  /// Проворство: ближний или дальний ряд по выбору игрока.
  agile(null)
  ;

  const UnitPlacement(this.row);

  /// Ряд для обычной карты; `null` у проворной.
  final Row? row;

  /// Ряды, в которые можно положить карту.
  List<Row> get rows => switch (this) {
    UnitPlacement.agile => const [Row.melee, Row.ranged],
    UnitPlacement.melee || UnitPlacement.ranged || UnitPlacement.siege => [row!],
  };
}
