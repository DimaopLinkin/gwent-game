/// Почему лобби не смогло объявить, найти партию или подключиться к ней.
enum LobbyFailure {
  /// Поиск или объявление в сети не работает: нет Wi-Fi, служба ОС отказала.
  unavailable,

  /// К хосту не удалось подключиться ни по одному адресу: хост ушёл, сеть изолирует клиентов
  /// или партии с таким идентификатором на этом адресе больше нет.
  unreachable,
}

/// Ошибка лобби: ловится по типу и показывается игроку по [failure].
final class LobbyException implements Exception {
  /// Создаёт ошибку.
  const LobbyException(this.failure, [this.cause]);

  /// Что не получилось.
  final LobbyFailure failure;

  /// Исходная ошибка платформы, для журнала.
  final Object? cause;

  @override
  String toString() => 'LobbyException(${failure.name}${cause == null ? '' : ', $cause'})';
}
