import 'package:gwent/src/features/lobby/application/network_open_result.dart';

/// Состояние экрана создания сетевой игры.
sealed class CreateGameState {
  const CreateGameState();
}

/// Имя игрока читается из настроек.
final class CreateGameLoading extends CreateGameState {
  /// Создаёт состояние.
  const CreateGameLoading();
}

/// Игрок вводит название партии.
final class CreateGameForm extends CreateGameState {
  /// Создаёт состояние с названием [initialName] по умолчанию.
  const CreateGameForm(this.initialName);

  /// Название, которое стоит в поле при открытии: имя игрока.
  final String initialName;
}

/// Партия создаётся: поднимается сервер и объявление в сети.
final class CreateGameCreating extends CreateGameState {
  /// Создаёт состояние.
  const CreateGameCreating();
}

/// Партия создана: экран уходит в комнату ожидания.
final class CreateGameCreated extends CreateGameState {
  /// Создаёт состояние.
  const CreateGameCreated();
}

/// Партию создать не удалось.
final class CreateGameFailed extends CreateGameState {
  /// Создаёт состояние.
  const CreateGameFailed(this.result, this.name);

  /// Почему не вышло.
  final NetworkOpenResult result;

  /// Название, которое ввёл игрок: «Повторить» создаёт партию с ним же.
  final String name;
}
