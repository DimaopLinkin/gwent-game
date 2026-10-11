/// Место игрока в партии. Номера задаются при создании партии и не меняются (раздел 12 правил).
enum Seat {
  one,
  two
  ;

  /// Соперник.
  Seat get opponent => switch (this) {
    Seat.one => Seat.two,
    Seat.two => Seat.one,
  };
}
