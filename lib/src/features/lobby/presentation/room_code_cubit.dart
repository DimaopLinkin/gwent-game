import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:gwent/src/features/lobby/application/network_game.dart';
import 'package:gwent/src/features/lobby/domain/game_address.dart';
import 'package:gwent/src/features/lobby/presentation/room_code_state.dart';

/// Держатель кода комнаты у хоста игры через интернет.
///
/// Код меняется: когда гость уходит или хост ему отказывает, комната создаётся заново, а старый код перестаёт
/// работать (ADR 0025, 0026). Игра отдаёт актуальный код через `address()`, но не сообщает о смене, поэтому держатель
/// перечитывает его при каждом изменении комнаты и раз в [refresh], пока жив: чтение идёт из памяти, на сервер оно
/// не ходит.
final class RoomCodeCubit extends Cubit<RoomCodeState> {
  /// Создаёт держатель и сразу читает код игры [game].
  RoomCodeCubit(this._game, {Duration refresh = const Duration(seconds: 2)}) : super(const RoomCodeLoading()) {
    _subscription = _game.rooms.listen((_) => unawaited(_load()));
    _ticker = Timer.periodic(refresh, (_) => unawaited(_load()));
    unawaited(_load());
  }

  final NetworkGame _game;
  late final StreamSubscription<void> _subscription;
  late final Timer _ticker;
  bool _loading = false;

  Future<void> _load() async {
    if (_loading || isClosed || _game.isClosed) return;
    _loading = true;
    try {
      final address = await _game.address();
      if (isClosed) return;
      if (address is OnlineAddress) {
        final current = state;
        if (current is! RoomCodeReady || current.code != address.code) emit(RoomCodeReady(address.code));
      } else if (state is! RoomCodeFailed) {
        emit(const RoomCodeFailed());
      }
    } on Object catch (error, stackTrace) {
      addError(error, stackTrace);
      // Прежний код остаётся на экране, пока не станет ясно, что нового не будет.
      if (!isClosed && state is RoomCodeLoading) emit(const RoomCodeFailed());
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
