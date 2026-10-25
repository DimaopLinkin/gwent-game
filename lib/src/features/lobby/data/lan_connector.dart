import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:gwent/src/features/lobby/data/capped_socket.dart';
import 'package:gwent/src/features/lobby/data/lan_server.dart';
import 'package:gwent/src/features/lobby/data/web_socket_transport.dart';
import 'package:gwent/src/features/lobby/domain/game_address.dart';
import 'package:gwent/src/features/lobby/domain/lobby_exception.dart';
import 'package:gwent_net/gwent_net.dart';

/// Подключение гостя к серверу хоста в локальной сети.
final class LanConnector {
  /// Создаёт подключатель. [timeout] — сколько ждать каждый адрес, [maxMessageBytes] — сколько байт принимать без
  /// целого сообщения от хоста.
  const LanConnector({
    this.timeout = const Duration(seconds: 4),
    this.maxMessageBytes = LanServer.defaultMaxMessageBytes,
  });

  /// Сколько ждать соединения по одному адресу.
  final Duration timeout;

  /// Предел байт без целого сообщения, как у сервера хоста: хост может оказаться чужим (подделанное объявление,
  /// QR), и огромное сообщение не должно занять память телефона гостя (ADR 0022).
  final int maxMessageBytes;

  /// Пробует адреса хоста по очереди: сначала IPv4, затем IPv6. Адреса IPv6 с зоной (`fe80::1%en0`) пропускаются:
  /// их нельзя записать в URI WebSocket, а IPv4 в той же Wi-Fi сети есть всегда.
  ///
  /// Бросает [LobbyException] с `LobbyFailure.unreachable`, если не ответил ни один адрес.
  Future<Transport> connect(LanAddress address) async {
    Object? lastError;
    for (final host in orderedHosts(address.hosts)) {
      final uri = Uri(scheme: 'ws', host: host, port: address.port, pathSegments: LanServer.pathFor(address.gameId));
      try {
        final budget = ByteBudget(maxMessageBytes);
        return WebSocketTransport(await _open(uri, budget), budget: budget);
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

  Future<WebSocket> _open(Uri uri, ByteBudget budget) async {
    final client = HttpClient()..connectionTimeout = timeout;
    final pending = _upgrade(client, uri, budget);
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

  /// Рукопожатие WebSocket пишем сами, как на стороне хоста (`LanServer`): `WebSocket.connect` не даёт ограничить
  /// размер сообщения, а сжатие (permessage-deflate) превращает мегабайт по сети в гигабайт в памяти. Расширений мы
  /// не предлагаем, поэтому размер сообщения не больше размера байт из сети, а [CappedSocket] считает эти байты.
  Future<WebSocket> _upgrade(HttpClient client, Uri uri, ByteBudget budget) async {
    final random = Random.secure();
    final key = base64.encode(List<int>.generate(16, (_) => random.nextInt(256)));
    final request = await client.openUrl('GET', uri.replace(scheme: 'http'));
    request.headers
      ..set(HttpHeaders.connectionHeader, 'Upgrade')
      ..set(HttpHeaders.upgradeHeader, 'websocket')
      ..set('Sec-WebSocket-Key', key)
      ..set('Sec-WebSocket-Version', '13');
    final response = await request.close();
    final accept = base64.encode(sha1.convert(utf8.encode('$key$_handshakeGuid')).bytes);
    if (response.statusCode != HttpStatus.switchingProtocols ||
        response.headers.value('sec-websocket-accept') != accept ||
        response.headers.value('sec-websocket-extensions') != null) {
      // Не WebSocket, чужой ответ или расширение, которого мы не просили: сжатие обошло бы предел.
      unawaited(response.drain<void>().then<void>((_) {}, onError: (Object _) {}));
      throw WebSocketException('Хост не принял рукопожатие: ${response.statusCode}');
    }
    // ignore: close_sinks, сокет закрывает WebSocketTransport, которому он передан.
    final raw = await response.detachSocket();
    return WebSocket.fromUpgradedSocket(
      CappedSocket(raw, budget),
      serverSide: false,
      compression: CompressionOptions.compressionOff,
    );
  }

  /// Константа RFC 6455 для проверки ответа на ключ рукопожатия.
  static const String _handshakeGuid = '258EAFA5-E914-47DA-95CA-C5AB0DC85B11';
}
