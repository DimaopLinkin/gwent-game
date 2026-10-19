import 'package:gwent/src/features/lobby/application/active_network_game.dart';
import 'package:gwent/src/features/lobby/application/load_network_setup.dart';
import 'package:gwent/src/features/lobby/application/network_game.dart';
import 'package:gwent/src/features/lobby/application/network_open_result.dart';
import 'package:gwent/src/features/lobby/domain/found_game.dart';
import 'package:gwent/src/features/lobby/domain/game_ad.dart';
import 'package:gwent/src/features/lobby/domain/game_address.dart';
import 'package:gwent/src/features/lobby/domain/game_lobby.dart';
import 'package:gwent/src/features/lobby/domain/lobby_exception.dart';
import 'package:gwent/src/features/lobby/domain/lobby_room.dart';
import 'package:gwent_net/gwent_net.dart';

/// Сценарий: подключиться к найденной партии гостем.
///
/// Возвращает игру, когда хост выдал место. Если хост отказал, недоступен или молчит дольше [joinTimeout],
/// возвращает причину и ничего не оставляет открытым.
final class JoinNetworkGame {
  /// Создаёт сценарий.
  JoinNetworkGame(
    this._setup,
    this._lobby,
    this._active,
    this._scheduler, {
    this.joinTimeout = const Duration(seconds: 8),
  });

  final LoadNetworkSetup _setup;
  final GameLobby _lobby;
  final ActiveNetworkGame _active;
  final Scheduler _scheduler;

  /// Сколько ждать ответа хоста после соединения.
  final Duration joinTimeout;

  /// Подключается к [found]; в игре телефон называется [playerName].
  Future<NetworkOpenResult> call({required FoundGame found, required String playerName}) =>
      _join(found.address, playerName: playerName, ad: found.ad);

  /// Подключается по [address] из QR-кода: объявления гость не видел, поэтому несовместимость данных карт или версии
  /// выясняется при рукопожатии, и отказ приходит от хоста.
  Future<NetworkOpenResult> byAddress(GameAddress address, {required String playerName}) =>
      _join(address, playerName: playerName);

  Future<NetworkOpenResult> _join(GameAddress address, {required String playerName, GameAd? ad}) async {
    final NetworkSetup setup;
    switch (await _setup()) {
      case NetworkSetupReady(setup: final ready):
        setup = ready;
      case NetworkSetupUnavailable():
        return const NetworkContentUnavailable();
    }
    if (ad?.refusalFor(setup.ruleset) case final refusal?) return NetworkRefused(refusal);
    final Transport transport;
    try {
      transport = await _lobby.join(address);
    } on LobbyException catch (error) {
      return switch (error.failure) {
        LobbyFailure.unavailable => const NetworkUnavailable(),
        LobbyFailure.unreachable => const NetworkUnreachable(),
      };
    }
    final client = MatchClient(
      settings: ClientSettings(ruleset: setup.ruleset, playerName: playerName, appVersion: setup.appVersion),
      scheduler: _scheduler,
    );
    final game = NetworkGame(
      client: client,
      content: setup.content,
      scheduler: _scheduler,
      playerName: playerName,
      lobby: _lobby,
      address: address,
    );
    client.connect(transport);
    final room = await game.settled(joinTimeout);
    switch (room.end) {
      case RoomRefused(:final reason):
        await game.close();
        return NetworkRefused(reason);
      case RoomHostClosed() || RoomConnectionLost():
        await game.close();
        return const NetworkUnreachable();
      case null:
        await _active.set(game);
        return NetworkGameOpened(game);
    }
  }
}
