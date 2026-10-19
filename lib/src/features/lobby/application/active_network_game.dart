import 'package:gwent/src/features/lobby/application/network_game.dart';

/// Сетевая игра, которая сейчас ведётся на этом телефоне: общая для экранов лобби и партии, потому что игра живёт
/// дольше любого из них. Игра одна: новая закрывает прежнюю.
final class ActiveNetworkGame {
  /// Создаёт пустое хранилище.
  ActiveNetworkGame();

  NetworkGame? _game;

  /// Игра, которую ведёт телефон; `null`, если игры нет или она закрыта.
  NetworkGame? get current {
    final game = _game;
    if (game != null && game.isClosed) _game = null;
    return _game;
  }

  /// Делает [game] текущей; прежняя игра закрывается.
  Future<void> set(NetworkGame game) async {
    final previous = _game;
    _game = game;
    if (previous != null && !identical(previous, game)) await previous.close();
  }

  /// Забывает [game], если она текущая. Закрывает её тот, кто её закрывает.
  void forget(NetworkGame game) {
    if (identical(_game, game)) _game = null;
  }
}
