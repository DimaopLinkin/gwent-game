import 'package:collection/collection.dart';
import 'package:gwent/src/features/lobby/domain/room_code.dart';
import 'package:meta/meta.dart';

/// Куда подключаться к объявленной партии. Вид адреса задаёт вид связи.
@immutable
sealed class GameAddress {
  const GameAddress();

  /// Идентификатор партии (`GameAd.id`): хост по нему отличает свою партию от прежней на том же адресе.
  String get gameId;
}

/// Партия в локальной сети (Wi-Fi): адреса хоста и порт.
final class LanAddress extends GameAddress {
  /// Создаёт адрес. [hosts] — IP-адреса хоста по порядку предпочтения.
  ///
  /// Бросает [ArgumentError], если адресов нет или порт вне диапазона.
  LanAddress({required this.gameId, required List<String> hosts, required this.port})
    : hosts = List.unmodifiable(hosts) {
    if (hosts.isEmpty) throw ArgumentError.value(hosts, 'hosts', 'Нужен хотя бы один адрес');
    if (port < 1 || port > 65535) throw ArgumentError.value(port, 'port', 'Порт вне диапазона 1–65535');
  }

  @override
  final String gameId;

  /// IP-адреса хоста: у телефона их бывает несколько (IPv4, IPv6, точка доступа).
  final List<String> hosts;

  /// Порт сервера хоста.
  final int port;

  @override
  bool operator ==(Object other) =>
      other is LanAddress &&
      other.gameId == gameId &&
      const ListEquality<String>().equals(other.hosts, hosts) &&
      other.port == port;

  @override
  int get hashCode => Object.hash(gameId, Object.hashAll(hosts), port);

  @override
  String toString() => 'LanAddress($gameId, $hosts, $port)';
}

/// Партия через интернет: комната с кодом (ADR 0025). Хост узнаёт код при создании партии, гость вводит его.
final class OnlineAddress extends GameAddress {
  /// Создаёт адрес комнаты с кодом [code].
  const OnlineAddress(this.code);

  /// Код комнаты.
  final RoomCode code;

  /// Комнату определяет её код: идентификатор партии (`GameAd.id`) гость не знает.
  @override
  String get gameId => code.value;

  @override
  bool operator ==(Object other) => other is OnlineAddress && other.code == code;

  @override
  int get hashCode => code.hashCode;

  @override
  String toString() => 'OnlineAddress($code)';
}
