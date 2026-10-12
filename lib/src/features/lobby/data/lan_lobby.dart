import 'dart:async';
import 'dart:io';

import 'package:gwent/src/features/lobby/data/game_ad_record.dart';
import 'package:gwent/src/features/lobby/data/lan_connector.dart';
import 'package:gwent/src/features/lobby/data/lan_server.dart';
import 'package:gwent/src/features/lobby/data/service_directory.dart';
import 'package:gwent/src/features/lobby/domain/found_game.dart';
import 'package:gwent/src/features/lobby/domain/game_ad.dart';
import 'package:gwent/src/features/lobby/domain/game_address.dart';
import 'package:gwent/src/features/lobby/domain/game_lobby.dart';
import 'package:gwent/src/features/lobby/domain/lobby_exception.dart';
import 'package:gwent_net/gwent_net.dart';

/// IP-адреса этого телефона для приглашения.
typedef LocalAddresses = Future<List<String>> Function();

/// Лобби в локальной сети (Wi-Fi): объявление и поиск через DNS-SD (mDNS), соединение — WebSocket
/// (раздел 6.2 спецификации, ADR 0007).
final class LanLobby implements GameLobby {
  /// Создаёт лобби. [localAddresses] по умолчанию берёт IPv4-адреса сетевых интерфейсов.
  LanLobby({
    required ServiceDirectory directory,
    LanConnector connector = const LanConnector(),
    LocalAddresses? localAddresses,
  }) : _directory = directory,
       _connector = connector,
       _localAddresses = localAddresses ?? interfaceAddresses;

  final ServiceDirectory _directory;
  final LanConnector _connector;
  final LocalAddresses _localAddresses;

  @override
  Future<HostedGame> host(GameAd ad) async {
    final LanServer server;
    try {
      server = await LanServer.bind(gameId: ad.id);
    } on SocketException catch (error) {
      throw LobbyException(LobbyFailure.unavailable, error);
    }
    try {
      final advertisement = await _directory.advertise(_record(ad, server.port));
      return _LanHostedGame(this, server, ad, advertisement);
    } on LobbyException {
      await server.close();
      rethrow;
    }
  }

  @override
  Stream<List<FoundGame>> discover() {
    return Stream<List<FoundGame>>.multi((controller) {
      // Ключ — имя экземпляра сервиса: событие пропажи несёт только его.
      final games = <String, FoundGame>{};
      controller.add(const []);
      final subscription = _directory.browse().listen(
        (event) {
          final changed = switch (event) {
            ServiceFound(:final record) => _found(games, record),
            ServiceLost(:final name) => games.remove(name) != null,
          };
          if (changed) controller.add(List.unmodifiable(games.values));
        },
        onError: controller.addError,
        onDone: controller.close,
      );
      controller.onCancel = subscription.cancel;
    });
  }

  @override
  Future<Transport> join(GameAddress address) => switch (address) {
    LanAddress() => _connector.connect(address),
  };

  /// IPv4-адреса сетевых интерфейсов без петли: в Wi-Fi сети гость доберётся до хоста по IPv4.
  static Future<List<String>> interfaceAddresses() async {
    final interfaces = await NetworkInterface.list(type: InternetAddressType.IPv4);
    return [
      for (final interface in interfaces)
        for (final address in interface.addresses) address.address,
    ];
  }

  ServiceRecord _record(GameAd ad, int port) =>
      ServiceRecord(name: ad.id, port: port, attributes: GameAdRecord.encode(ad));

  /// Добавляет или обновляет партию; `true`, если список изменился.
  static bool _found(Map<String, FoundGame> games, ServiceRecord record) {
    final ad = GameAdRecord.decode(record.attributes);
    final hosts = LanConnector.orderedHosts(record.hosts);
    if (ad == null || hosts.isEmpty || record.port < 1 || record.port > 65535) {
      return games.remove(record.name) != null;
    }
    final game = FoundGame(
      ad: ad,
      address: LanAddress(gameId: ad.id, hosts: hosts, port: record.port),
    );
    if (games[record.name] == game) return false;
    games[record.name] = game;
    return true;
  }
}

final class _LanHostedGame implements HostedGame {
  _LanHostedGame(this._lobby, this._server, this._ad, this._advertisement);

  final LanLobby _lobby;
  final LanServer _server;
  GameAd _ad;
  ServiceAdvertisement? _advertisement;
  bool _closed = false;

  @override
  GameAd get ad => _ad;

  @override
  Stream<Transport> get connections => _server.connections;

  @override
  Future<GameAddress> address() async {
    final hosts = await _lobby._localAddresses();
    if (hosts.isEmpty) throw const LobbyException(LobbyFailure.unavailable);
    return LanAddress(gameId: _ad.id, hosts: hosts, port: _server.port);
  }

  @override
  Future<void> advertise(GameAd ad) async {
    if (ad.id != _ad.id) throw ArgumentError.value(ad.id, 'ad.id', 'Идентификатор партии менять нельзя');
    if (_closed) throw StateError('Партия уже не объявляется');
    await _advertisement?.stop();
    _advertisement = null;
    _advertisement = await _lobby._directory.advertise(_lobby._record(ad, _server.port));
    _ad = ad;
  }

  @override
  Future<void> close() async {
    _closed = true;
    final advertisement = _advertisement;
    _advertisement = null;
    await advertisement?.stop();
    await _server.close();
  }
}
