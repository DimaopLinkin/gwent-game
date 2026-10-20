import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:gwent/src/features/lobby/application/network_game.dart';
import 'package:gwent/src/features/lobby/domain/game_address.dart';
import 'package:gwent/src/features/lobby/domain/lobby_room.dart';
import 'package:gwent/src/features/lobby/presentation/room_code_state.dart';

/// Держатель кода комнаты у хоста игры через интернет.
///
/// Код меняется: когда гость уходит или хост ему отказывает, комната создаётся заново, а старый код перестаёт
/// работать (ADR 0025, 0026). Игра отдаёт актуальный код через `address()`, но не сообщает о смене, поэтому держатель
/// перечитывает его при каждом изменении комнаты и раз в [refresh], пока жив. Само чтение на сервер не ходит, но
/// встаёт в очередь за пересозданием комнаты и отвечает, когда оно закончилось. Когда соперник ушёл, прежний код
/// считается устаревшим и пропадает с экрана, пока не прочитан новый.
final class RoomCodeCubit extends Cubit<RoomCodeState> {
  /// Создаёт держатель и сразу читает код игры [game].
  RoomCodeCubit(this._game, {Duration refresh = const Duration(seconds: 2)}) : super(const RoomCodeLoading()) {
    _subscription = _game.rooms.listen(_onRoom);
    _ticker = Timer.periodic(refresh, (_) => unawaited(_load()));
    unawaited(_load());
  }

  final NetworkGame _game;
  late final StreamSubscription<void> _subscription;
  late final Timer _ticker;
  bool _loading = false;
  bool _hadOpponent = false;

  void _onRoom(LobbyRoom room) {
    // Соперник ушёл: комната создаётся заново, и пока она не создана, старый код уже не годится.
    if (_hadOpponent && room.opponent == null && state is RoomCodeReady) emit(const RoomCodeLoading());
    _hadOpponent = room.opponent != null;
    unawaited(_load());
  }

  Future<void> _load() async {
    if (_loading || isClosed || _game.isClosed) return;
    _loading = true;
    try {
      final address = await _game.address();
      // Игру закрыли, пока ждали ответа: экран уходит, а не показывает ошибку.
      if (isClosed || _game.isClosed) return;
      if (address is OnlineAddress) {
        final current = state;
        if (current is! RoomCodeReady || current.code != address.code) emit(RoomCodeReady(address.code));
      } else if (state is! RoomCodeFailed) {
        emit(const RoomCodeFailed());
      }
    } on Object catch (error, stackTrace) {
      addError(error, stackTrace);
      // Прежний код остаётся на экране, пока не станет ясно, что нового не будет.
      if (isClosed) return;
      // Комнаты больше нет: новый код не появится, повторять чтение незачем.
      _ticker.cancel();
      if (state is! RoomCodeFailed) emit(const RoomCodeFailed());
    } finally {
      _loading = false;
    }
  }

  @override
  Future<void> close() async {
    _ticker.cancel();
    await _subscription.cancel();
    return super.close();
  }
}
