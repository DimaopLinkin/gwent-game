import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:gwent/src/features/lobby/application/network_game.dart';
import 'package:gwent/src/features/lobby/domain/lobby_room.dart';
import 'package:gwent/src/features/lobby/presentation/match_connection_state.dart';

/// Держатель связи в сетевой партии (макет 9, экраны 5 и 6): следит за комнатой игры и отсчитывает время, которое
/// ждут возвращения соперника или хоста.
///
/// Время ожидания то же, что у хоста до сдачи отсутствующего (`reconnectWindow`): когда оно выйдет, партию заканчивает
/// сам хост, а экран узнаёт об этом из стола.
final class MatchConnectionCubit extends Cubit<MatchConnectionState> {
  /// Создаёт держатель; [tick] — шаг отсчёта.
  MatchConnectionCubit(this._game, {Duration tick = const Duration(seconds: 1)})
    : _tick = tick,
      super(MatchConnectionState(isHost: _game.isHost)) {
    _apply(_game.room);
    _subscription = _game.rooms.listen(_apply);
  }

  final NetworkGame _game;
  final Duration _tick;

  /// Всё время ожидания, от него считается полоса.
  Duration get total => _game.reconnectWindow;
  late final StreamSubscription<LobbyRoom> _subscription;
  Timer? _timer;

  bool _isLost(LobbyRoom room) => _game.isHost ? room.opponent?.online == false : room.link != RoomLink.online;

  void _apply(LobbyRoom room) {
    final lost = _isLost(room);
    if (lost == state.lost) return;
    _timer?.cancel();
    _timer = null;
    if (!lost) {
      emit(state.copyWith(lost: false, left: Duration.zero, dismissed: false));
      return;
    }
    emit(state.copyWith(lost: true, left: _game.reconnectWindow, dismissed: false));
    _timer = Timer.periodic(_tick, (_) {
      final left = state.left - _tick;
      if (left <= Duration.zero) {
        _timer?.cancel();
        _timer = null;
        emit(state.copyWith(left: Duration.zero));
      } else {
        emit(state.copyWith(left: left));
      }
    });
  }

  /// Закрывает окно обрыва, ожидание идёт дальше.
  void wait() => emit(state.copyWith(dismissed: true));

  @override
  Future<void> close() async {
    _timer?.cancel();
    await _subscription.cancel();
    return super.close();
  }
}
