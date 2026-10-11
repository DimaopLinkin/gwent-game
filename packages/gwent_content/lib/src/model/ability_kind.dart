/// Таблица способностей, к которой относится эффект.
enum AbilityKind {
  /// Способности карт отрядов (`squad_abilities`).
  squad,

  /// Способности специальных карт (`special_abilities`).
  special,

  /// Способности лидеров (`leader_abilities`).
  leader,

  /// Перки фракций (`fraction_abilities`).
  fraction,
}
