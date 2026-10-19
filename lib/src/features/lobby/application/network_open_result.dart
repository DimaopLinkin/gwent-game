import 'package:gwent/src/features/lobby/application/network_game.dart';
import 'package:gwent_net/gwent_net.dart' show JoinRefusal;

/// Итог попытки создать сетевую игру или подключиться к ней.
sealed class NetworkOpenResult {
  const NetworkOpenResult();
}

/// Игра открыта: хост ждёт соперника, гость в комнате хоста.
final class NetworkGameOpened extends NetworkOpenResult {
  /// Создаёт итог.
  const NetworkGameOpened(this.game);

  /// Открытая игра.
  final NetworkGame game;
}

/// Набор карт не прошёл проверку: сетевая игра невозможна.
final class NetworkContentUnavailable extends NetworkOpenResult {
  /// Создаёт итог.
  const NetworkContentUnavailable();
}

/// Служба сети не работает: Wi-Fi выключен или ОС не дала доступ к локальной сети.
final class NetworkUnavailable extends NetworkOpenResult {
  /// Создаёт итог.
  const NetworkUnavailable();
}

/// К хосту подключиться не удалось: он ушёл из сети, закрыл партию или сеть не пропускает соединение.
final class NetworkUnreachable extends NetworkOpenResult {
  /// Создаёт итог.
  const NetworkUnreachable();
}

/// Хост не пустил гостя: другая версия, другие данные карт или мест нет.
final class NetworkRefused extends NetworkOpenResult {
  /// Создаёт итог.
  const NetworkRefused(this.reason);

  /// Причина отказа.
  final JoinRefusal reason;
}
