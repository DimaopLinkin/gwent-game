import 'dart:async';
import 'dart:io';

import 'package:gwent/src/features/lobby/data/lan_server.dart';
import 'package:gwent/src/features/lobby/data/web_socket_transport.dart';
import 'package:gwent/src/features/lobby/domain/game_address.dart';
import 'package:gwent/src/features/lobby/domain/lobby_exception.dart';
import 'package:gwent_net/gwent_net.dart';

/// Подключение гостя к серверу хоста в локальной сети.
final class LanConnector {
  /// Создаёт подключатель. [timeout] — сколько ждать каждый адрес.
  const LanConnector({this.timeout = const Duration(seconds: 4)});

  /// Сколько ждать соединения по одному адресу.
  final Duration timeout;

  /// Пробует адреса хоста по очереди: сначала IPv4, затем IPv6. Адреса IPv6 с зоной (`fe80::1%en0`) пропускаются:
  /// их нельзя записать в URI WebSocket, а IPv4 в той же Wi-Fi сети есть всегда.
  ///
  /// Бросает [LobbyException] с `LobbyFailure.unreachable`, если не ответил ни один адрес.
  Future<Transport> connect(LanAddress address) async {
    Object? lastError;
    for (final host in orderedHosts(address.hosts)) {
      final uri = Uri(scheme: 'ws', host: host, port: address.port, pathSegments: LanServer.pathFor(address.gameId));
      try {
        return WebSocketTransport(await _open(uri));
      } on SocketException catch (error) {
        lastError = error;
      } on WebSocketException catch (error) {
        lastError = error;
      } on HttpException catch (error) {
        lastError = error;
      } on TimeoutException catch (error) {
        lastError = error;
      }
    }
    throw LobbyException(LobbyFailure.unreachable, lastError);
  }

  /// Адреса в порядке попыток.
  static List<String> orderedHosts(List<String> hosts) {
    final usable = [
      for (final host in hosts)
        if (!host.contains('%')) ?InternetAddress.tryParse(host),
    ];
    return [
      for (final address in usable)
        if (address.type == InternetAddressType.IPv4) address.address,
      for (final address in usable)
        if (address.type == InternetAddressType.IPv6) address.address,
    ];
  }

  Future<WebSocket> _open(Uri uri) async {
    final client = HttpClient()..connectionTimeout = timeout;
    final pending = WebSocket.connect(
      uri.toString(),
      customClient: client,
      // Хост может оказаться чужим (подделанное объявление, QR): сжатие превратило бы мегабайт в гигабайт памяти.
      compression: CompressionOptions.compressionOff,
    );
    try {
      return await pending.timeout(timeout);
    } on TimeoutException {
      // Соединение, которое всё же откроется после тайм-аута, никому не нужно.
      pending.then((socket) => socket.close()).ignore();
      rethrow;
    } finally {
      client.close();
    }
  }
}
