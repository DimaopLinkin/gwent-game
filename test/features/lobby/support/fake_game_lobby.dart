import 'dart:async';

import 'package:gwent/src/features/lobby/domain/found_game.dart';
import 'package:gwent/src/features/lobby/domain/game_ad.dart';
import 'package:gwent/src/features/lobby/domain/game_address.dart';
import 'package:gwent/src/features/lobby/domain/game_lobby.dart';
import 'package:gwent/src/features/lobby/domain/lobby_exception.dart';
import 'package:gwent_net/gwent_net.dart';

/// Лобби в памяти: хосты и гости соединяются через `InMemoryTransport`, поиск видит объявленные партии.
final class FakeGameLobby implements GameLobby {
  /// Партии, которые сейчас ведут хосты, по идентификатору.
  final Map<String, FakeHostedGame> hosted = {};

  /// Следующая попытка создать партию откажет.
  bool failHost = false;

  /// Следующие [failJoins] подключений откажут как недоступные.
  int failJoins = 0;

  /// Сколько раз гости подключались.
  int joinCalls = 0;

  /// Концы соединений на стороне хоста по порядку подключений: тест рвёт связь, закрывая нужный.
  final List<Transport> hostEnds = [];

  final StreamController<void> _changes = StreamController<void>.broadcast(sync: true);
  final StreamController<void> _failures = StreamController<void>.broadcast(sync: true);

  @override
  Future<HostedGame> host(GameAd ad) async {
    if (failHost) {
      failHost = false;
      throw const LobbyException(LobbyFailure.unavailable);
    }
    final game = FakeHostedGame(this, ad);
    hosted[ad.id] = game;
    _changes.add(null);
    return game;
  }

  @override
  Stream<List<FoundGame>> discover() => Stream<List<FoundGame>>.multi((controller) {
    List<FoundGame> games() => List.unmodifiable([
      for (final game in hosted.values) FoundGame(ad: game.ad, address: game.lanAddress),
    ]);
    controller.add(games());
    final subscription = _changes.stream.listen((_) => controller.add(games()));
    final failure = _failures.stream.listen((_) {
      controller.addError(const LobbyException(LobbyFailure.unavailable));
      unawaited(controller.close());
    });
    controller.onCancel = () async {
      await subscription.cancel();
      await failure.cancel();
    };
  });

  @override
  Future<Transport> join(GameAddress address) async {
    joinCalls++;
    if (failJoins > 0) {
      failJoins--;
      throw const LobbyException(LobbyFailure.unreachable);
    }
    final game = hosted[address.gameId];
    if (game == null || game.closed) throw const LobbyException(LobbyFailure.unreachable);
    final (hostEnd, guestEnd) = InMemoryTransport.pair();
    hostEnds.add(hostEnd);
    game._connections.add(hostEnd);
    return guestEnd;
  }

  /// Служба поиска отказывает во всех идущих поисках.
  void failDiscover() => _failures.add(null);

  void _changed() => _changes.add(null);
}

/// Партия хоста в [FakeGameLobby].
final class FakeHostedGame implements HostedGame {
  FakeHostedGame(this._lobby, this._ad);

  final FakeGameLobby _lobby;
  GameAd _ad;
  final StreamController<Transport> _connections = StreamController<Transport>();

  /// Сколько раз объявление менялось.
  int advertiseCalls = 0;

  /// Партия закрыта.
  bool closed = false;

  @override
  GameAd get ad => _ad;

  @override
  Stream<Transport> get connections => _connections.stream;

  /// Адрес партии в сети.
  LanAddress get lanAddress => LanAddress(gameId: _ad.id, hosts: const ['10.0.0.2'], port: 4000);

  @override
  Future<GameAddress> address() async => lanAddress;

  @override
  Future<void> advertise(GameAd ad) async {
    if (closed) throw StateError('Партия закрыта');
    advertiseCalls++;
    _ad = ad;
    _lobby._changed();
  }

  @override
  Future<void> close() async {
    if (closed) return;
    closed = true;
    _lobby.hosted.remove(_ad.id);
    _lobby._changed();
    unawaited(_connections.close());
  }
}
