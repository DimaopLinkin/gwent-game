import 'package:gwent/src/features/lobby/application/discover_network_games.dart';
import 'package:gwent/src/features/lobby/application/network_open_result.dart';
import 'package:gwent/src/features/lobby/domain/game_address.dart';
import 'package:gwent/src/features/lobby/domain/network_access.dart';

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

/// Гость подключается по адресу из QR-кода.
final class FindGamesJoiningByCode extends FindGamesState {
  /// Создаёт состояние.
  const FindGamesJoiningByCode(this.address);

  /// Адрес из QR-кода.
  final GameAddress address;
}

/// Гость подключился: экран уходит в комнату хоста.
final class FindGamesJoined extends FindGamesState {
  /// Создаёт состояние.
  const FindGamesJoined();
}

/// Подключиться не удалось.
final class FindGamesFailed extends FindGamesState {
  /// Создаёт состояние: [result] — причина, [game] — партия из списка, [address] — адрес из QR-кода. Задан ровно
  /// один из двух.
  const FindGamesFailed(this.result, {this.game, this.address})
    : assert((game == null) != (address == null), 'нужна ровно одна цель: партия из списка или адрес');

  /// Почему не вышло.
  final NetworkOpenResult result;

  /// Партия из списка, к которой подключались; «Повторить» подключается к ней же.
  final DiscoveredGame? game;

  /// Адрес из QR-кода, к которому подключались; «Повторить» подключается к нему же.
  final GameAddress? address;
}

/// Поиск не работает: Wi-Fi выключен или нет доступа к локальной сети.
final class FindGamesUnavailable extends FindGamesState {
  /// Создаёт состояние. [problem] — причина, если телефон смог её назвать.
  const FindGamesUnavailable({this.problem});

  /// Что именно мешает; `null`, если известно только, что поиск не работает.
  final NetworkProblem? problem;
}
