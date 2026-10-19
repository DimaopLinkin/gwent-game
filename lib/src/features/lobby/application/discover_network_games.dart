import 'package:gwent/src/features/lobby/application/load_network_setup.dart';
import 'package:gwent/src/features/lobby/domain/found_game.dart';
import 'package:gwent/src/features/lobby/domain/game_lobby.dart';
import 'package:gwent_net/gwent_net.dart' show JoinRefusal;
import 'package:meta/meta.dart';

/// Найденная партия и то, можно ли к ней присоединиться с этим приложением.
@immutable
final class DiscoveredGame {
  /// Создаёт запись.
  const DiscoveredGame(this.found, this.refusal);

  /// Партия из поиска.
  final FoundGame found;

  /// Почему присоединиться нельзя: другая версия протокола или данных карт, мест нет. `null`, если можно.
  final JoinRefusal? refusal;

  /// К партии можно присоединиться.
  bool get joinable => refusal == null;

  @override
  bool operator ==(Object other) => other is DiscoveredGame && other.found == found && other.refusal == refusal;

  @override
  int get hashCode => Object.hash(found, refusal);
}

/// Сценарий: искать партии рядом. Каждое значение потока — полный список найденного сейчас.
///
/// Партии с другой версией остаются в списке с причиной: игрок видит, что партия есть, но не подходит. Отказ поиска
/// приходит ошибкой потока (`LobbyException`), а недоступный набор карт — `StateError`.
final class DiscoverNetworkGames {
  /// Создаёт сценарий.
  const DiscoverNetworkGames(this._setup, this._lobby);

  final LoadNetworkSetup _setup;
  final GameLobby _lobby;

  /// Запускает поиск; отмена подписки его останавливает.
  Stream<List<DiscoveredGame>> call() async* {
    final ruleset = switch (await _setup()) {
      NetworkSetupReady(:final setup) => setup.ruleset,
      NetworkSetupUnavailable() => throw StateError('Набор карт недоступен'),
    };
    yield* _lobby.discover().map(
      (games) => List.unmodifiable([
        for (final game in games) DiscoveredGame(game, game.ad.refusalFor(ruleset)),
      ]),
    );
  }
}
