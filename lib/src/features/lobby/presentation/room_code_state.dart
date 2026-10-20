import 'package:gwent/src/features/lobby/domain/room_code.dart';

/// Код комнаты хоста для экрана ожидания.
sealed class RoomCodeState {
  const RoomCodeState();
}

/// Код ещё узнаётся.
final class RoomCodeLoading extends RoomCodeState {
  /// Создаёт состояние.
  const RoomCodeLoading();
}

/// Код известен: его можно показать и продиктовать.
final class RoomCodeReady extends RoomCodeState {
  /// Создаёт состояние.
  const RoomCodeReady(this.code);

  /// Действующий код комнаты.
  final RoomCode code;
}

/// Код узнать не удалось: комната закрыта или сервис не отвечает.
final class RoomCodeFailed extends RoomCodeState {
  /// Создаёт состояние.
  const RoomCodeFailed();
}
