/// Перк фракции (раздел 11 правил). Логика каждого перка живёт в движке.
enum FactionPerk {
  /// Королевства Севера: после выигранного раунда игрок берёт карту в начале следующего.
  drawOnRoundWin,

  /// Нильфгаард: выигрывает раунд при ничьей по очкам.
  winTies,

  /// Чудовища: после раунда одна случайная карта отряда остаётся на поле.
  keepRandomUnit,

  /// Скоя'таэли: игрок решает, кто ходит первым.
  chooseFirstPlayer,

  /// Скеллиге: в начале раунда 3 на поле возвращаются 2 случайных обычных отряда из отбоя.
  reviveInFinalRound,
}

/// Фракция карты или колоды.
enum Faction {
  northernRealms(FactionPerk.drawOnRoundWin),
  nilfgaard(FactionPerk.winTies),
  monsters(FactionPerk.keepRandomUnit),
  scoiatael(FactionPerk.chooseFirstPlayer),
  skellige(FactionPerk.reviveInFinalRound),

  /// Нейтральные карты («Общий»): идут в колоду любой фракции, колодой быть не могут.
  neutral(null)
  ;

  const Faction(this.perk);

  /// Перк фракции колоды; у нейтральных карт перка нет.
  final FactionPerk? perk;

  /// Может ли фракция быть фракцией колоды.
  bool get isDeckFaction => perk != null;
}
