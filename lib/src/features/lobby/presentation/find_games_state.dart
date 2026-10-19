import 'package:gwent/src/features/lobby/application/discover_network_games.dart';
import 'package:gwent/src/features/lobby/application/network_open_result.dart';

/// Состояние экрана поиска партий рядом.
sealed class FindGamesState {
  const FindGamesState();
}

/// Идёт поиск; [games] — всё найденное сейчас.
final class FindGamesSearching extends FindGamesState {
  /// Создаёт состояние.
  FindGamesSearching(List<DiscoveredGame> games) : games = List.unmodifiable(games);

  /// Найденные партии.
  final List<DiscoveredGame> games;
}

/// Гость подключается к партии [gameId].
final class FindGamesJoining extends FindGamesState {
  /// Создаёт состояние.
  FindGamesJoining(List<DiscoveredGame> games, this.gameId) : games = List.unmodifiable(games);

  /// Найденные партии на момент нажатия.
  final List<DiscoveredGame> games;

  /// Идентификатор партии, к которой подключаются.
  final String gameId;
}

/// Гость подключился: экран уходит в комнату хоста.
final class FindGamesJoined extends FindGamesState {
  /// Создаёт состояние.
  const FindGamesJoined();
}

/// Подключиться не удалось.
final class FindGamesFailed extends FindGamesState {
  /// Создаёт состояние: [result] — причина, [game] — партия, к которой подключались.
  const FindGamesFailed(this.result, this.game);

  /// Почему не вышло.
  final NetworkOpenResult result;

  /// Партия, к которой подключались; «Повторить» подключается к ней же.
  final DiscoveredGame game;
}

/// Поиск не работает: Wi-Fi выключен или нет доступа к локальной сети.
final class FindGamesUnavailable extends FindGamesState {
  /// Создаёт состояние.
  const FindGamesUnavailable();
}
