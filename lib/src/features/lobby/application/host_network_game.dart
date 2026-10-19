import 'package:gwent/src/features/lobby/application/active_network_game.dart';
import 'package:gwent/src/features/lobby/application/load_network_setup.dart';
import 'package:gwent/src/features/lobby/application/network_game.dart';
import 'package:gwent/src/features/lobby/application/network_open_result.dart';
import 'package:gwent/src/features/lobby/domain/game_ad.dart';
import 'package:gwent/src/features/lobby/domain/game_lobby.dart';
import 'package:gwent/src/features/lobby/domain/lobby_exception.dart';
import 'package:gwent_engine/gwent_engine.dart';
import 'package:gwent_net/gwent_net.dart';

/// Сценарий: создать сетевую игру. Телефон становится хостом партии, объявляет её в сети и ждёт соперника.
///
/// Партию ведёт `MatchHost`; игрок хоста подключается к нему тем же клиентом, что и гость, только через память.
/// Отсчёт перед стартом ([startDelay]) задаёт хост: за это время любой из двоих может отменить готовность (ADR 0019).
final class HostNetworkGame {
  /// Создаёт сценарий.
  HostNetworkGame(
    this._setup,
    this._lobby,
    this._active,
    this._entropy,
    this._scheduler, {
    this.startDelay = const Duration(seconds: 3),
  });

  final LoadNetworkSetup _setup;
  final GameLobby _lobby;
  final ActiveNetworkGame _active;
  final Entropy _entropy;
  final Scheduler _scheduler;

  /// Сколько идёт отсчёт между готовностью обоих игроков и началом партии.
  final Duration startDelay;

  /// Создаёт игру с названием [gameName] для списка найденных партий; в игре телефон называется [playerName].
  Future<NetworkOpenResult> call({required String gameName, required String playerName}) async {
    final NetworkSetup setup;
    switch (await _setup()) {
      case NetworkSetupReady(setup: final ready):
        setup = ready;
      case NetworkSetupUnavailable():
        return const NetworkContentUnavailable();
    }
    final content = setup.content;
    final host = MatchHost(
      engine: GwentEngine(content.catalog, rules: content.rules),
      settings: HostSettings(ruleset: setup.ruleset, startDelay: startDelay),
      scheduler: _scheduler,
      entropy: _entropy,
    );
    final HostedGame hosted;
    try {
      hosted = await _lobby.host(GameAd(id: _entropy.token(), hostName: gameName, ruleset: setup.ruleset));
    } on LobbyException {
      await host.close();
      return const NetworkUnavailable();
    }
    final client = MatchClient(
      settings: ClientSettings(ruleset: setup.ruleset, playerName: playerName, appVersion: setup.appVersion),
      scheduler: _scheduler,
    );
    final game = NetworkGame(
      client: client,
      content: content,
      scheduler: _scheduler,
      playerName: playerName,
      host: host,
      hosted: hosted,
    );
    final (hostEnd, clientEnd) = InMemoryTransport.pair();
    host.accept(hostEnd);
    client.connect(clientEnd);
    await _active.set(game);
    return NetworkGameOpened(game);
  }
}
