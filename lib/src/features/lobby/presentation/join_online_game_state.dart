import 'package:gwent/src/features/lobby/application/network_open_result.dart';
import 'package:gwent/src/features/lobby/domain/room_code.dart';

/// Состояние экрана ввода кода комнаты.
sealed class JoinOnlineGameState {
  const JoinOnlineGameState();
}

/// Игрок вводит код. После неудачи форма остаётся: код в поле не стирается, игрок исправляет его или повторяет.
final class JoinOnlineGameForm extends JoinOnlineGameState {
  /// Создаёт форму. [failure] — почему прошлая попытка не удалась; [badCode] — введённое не похоже на код.
  const JoinOnlineGameForm({this.failure, this.badCode = false})
    : assert(failure == null || !badCode, 'причина одна: или форма, или ответ сервиса');

  /// Ответ на прошлую попытку: комната не найдена, лимит попыток, сервис недоступен и так далее.
  final NetworkOpenResult? failure;

  /// Введённая строка не может быть кодом (не та длина или знаки вне алфавита); к сервису она не ходила.
  final bool badCode;
}

/// Гость входит в комнату с кодом [code]: сервис отвечает, затем хост решает, пустить ли его.
final class JoinOnlineGameJoining extends JoinOnlineGameState {
  /// Создаёт состояние.
  const JoinOnlineGameJoining(this.code);

  /// Код комнаты, в которую входят.
  final RoomCode code;
}

/// Гость вошёл: экран уходит в комнату хоста.
final class JoinOnlineGameJoined extends JoinOnlineGameState {
  /// Создаёт состояние.
  const JoinOnlineGameJoined();
}
