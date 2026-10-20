import 'dart:async';
import 'dart:io';

import 'package:collection/collection.dart';
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
      final records = <String, FoundGame>{};
      var shown = const <FoundGame>[];
      void publish() {
        final next = _visible(records);
        if (const ListEquality<FoundGame>().equals(next, shown)) return;
        shown = next;
        controller.add(next);
      }

      controller.add(const []);
      final subscription = _directory.browse().listen(
        (event) {
          switch (event) {
            case ServiceFound(:final record):
              _remember(records, record);
            case ServiceLost(:final name):
              records.remove(name);
          }
          publish();
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
    // Комната с кодом живёт на сервере, в локальной сети её нет.
    OnlineAddress() => Future.error(const LobbyException(LobbyFailure.unreachable)),
  };

  /// IPv4-адреса сетевых интерфейсов без петли: в Wi-Fi сети гость доберётся до хоста по IPv4.
  static Future<List<String>> interfaceAddresses() async {
    final interfaces = await NetworkInterface.list(type: InternetAddressType.IPv4);
    return preferredAddresses([
      for (final interface in interfaces)
        for (final address in interface.addresses) (interface.name, address.address),
    ]);
  }

  /// Адреса `(интерфейс, адрес)` в порядке попыток гостя: сначала Wi-Fi и точка доступа, затем частные сети,
  /// в конце сотовая связь и VPN. Гость ждёт тайм-аут на каждом недоступном адресе, поэтому порядок важен.
  static List<String> preferredAddresses(List<(String, String)> addresses) {
    int rank((String, String) entry) {
      final (interface, address) = entry;
      final wifi = _wifiInterfaces.any(interface.startsWith);
      return (wifi ? 0 : 2) + (_isPrivate(address) ? 0 : 1);
    }

    final indexed = [for (final (index, entry) in addresses.indexed) (rank(entry), index, entry.$2)]
      ..sort((a, b) => a.$1 != b.$1 ? a.$1.compareTo(b.$1) : a.$2.compareTo(b.$2));
    return [for (final (_, _, address) in indexed) address];
  }

  /// Интерфейсы Wi-Fi и точки доступа: `en` (iOS), `wlan`/`swlan`/`ap` (Android), `bridge` (режим модема iOS).
  static const List<String> _wifiInterfaces = ['en', 'wlan', 'swlan', 'ap', 'bridge'];

  static bool _isPrivate(String address) {
    final octets = address.split('.').map(int.tryParse).toList();
    if (octets.length != 4 || octets.contains(null)) return false;
    final [a, b, _, _] = octets.cast<int>();
    return a == 10 || (a == 172 && b >= 16 && b <= 31) || (a == 192 && b == 168);
  }

  ServiceRecord _record(GameAd ad, int port) =>
      ServiceRecord(name: ad.id, port: port, attributes: GameAdRecord.encode(ad));

  /// Запоминает объявление [record] или забывает его, если оно не наше или недоступно.
  static void _remember(Map<String, FoundGame> games, ServiceRecord record) {
    final ad = GameAdRecord.decode(record.attributes);
    final hosts = LanConnector.orderedHosts(record.hosts);
    if (ad == null || hosts.isEmpty || record.port < 1 || record.port > 65535) {
      games.remove(record.name);
      return;
    }
    games[record.name] = FoundGame(
      ad: ad,
      address: LanAddress(gameId: ad.id, hosts: hosts, port: record.port),
    );
  }

  /// Список партий для игрока: по одной записи на партию.
  ///
  /// Объявление принимает любое устройство сети, а идентификатор партии открыт, поэтому самозванец может объявить
  /// «ту же» партию со своим адресом. Партию определяет первое увиденное объявление; последующие с тем же
  /// идентификатором принимаются, только если у них есть общий адрес с первым (ОС переименовала новое объявление
  /// того же хоста, пока старое не пропало), и из них берутся лишь общие адреса. Если первое пропало, на его место
  /// встаёт следующее: хост мог сменить сеть.
  static List<FoundGame> _visible(Map<String, FoundGame> records) {
    final anchors = <String, FoundGame>{};
    final chosen = <String, FoundGame>{};
    for (final game in records.values) {
      final id = game.ad.id;
      final anchor = anchors.putIfAbsent(id, () => game);
      if (identical(anchor, game)) {
        chosen[id] = game;
        continue;
      }
      final common = [
        for (final host in (game.address as LanAddress).hosts)
          if ((anchor.address as LanAddress).hosts.contains(host)) host,
      ];
      if (common.isEmpty) continue;
      chosen[id] = FoundGame(
        ad: game.ad,
        address: LanAddress(gameId: id, hosts: common, port: (game.address as LanAddress).port),
      );
    }
    return List.unmodifiable(chosen.values);
  }
}

final class _LanHostedGame implements HostedGame {
  _LanHostedGame(this._lobby, this._server, this._ad, this._advertisement) {
    // ОС закрыла приём (iOS при сворачивании): объявлять мёртвый порт незачем.
    unawaited(_server.done.then((_) => close()));
  }

  final LanLobby _lobby;
  final LanServer _server;
  GameAd _ad;
  ServiceAdvertisement? _advertisement;
  bool _closed = false;

  /// Конец последней операции с объявлением: объявления и закрытие идут по очереди, иначе одно из объявлений
  /// останется в сети без хозяина.
  Future<void> _queue = Future<void>.value();

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
  Future<void> advertise(GameAd ad) {
    if (ad.id != _ad.id) throw ArgumentError.value(ad.id, 'ad.id', 'Идентификатор партии менять нельзя');
    return _serially(() async {
      if (_closed) throw StateError('Партия уже не объявляется');
      await _advertisement?.stop();
      _advertisement = null;
      final advertisement = await _lobby._directory.advertise(_lobby._record(ad, _server.port));
      if (_closed) {
        await advertisement.stop();
        throw StateError('Партия закрыта во время объявления');
      }
      _advertisement = advertisement;
      _ad = ad;
    });
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _server.close();
    await _serially(() async {
      final advertisement = _advertisement;
      _advertisement = null;
      await advertisement?.stop();
    });
  }

  Future<void> _serially(Future<void> Function() operation) async {
    final previous = _queue;
    final current = Completer<void>();
    _queue = current.future;
    try {
      await previous;
      await operation();
    } finally {
      current.complete();
    }
  }
}
