import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:gwent/src/features/lobby/application/network_game.dart';
import 'package:gwent/src/features/lobby/domain/lobby_room.dart';
import 'package:gwent/src/features/lobby/presentation/match_connection_state.dart';

/// Держатель связи в сетевой партии (макет 9, экраны 5 и 6): следит за комнатой игры, показывает нестабильную связь
/// и сворачивание хоста, отсчитывает время, которое ждут возвращения соперника или хоста.
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

  /// Хост свернул приложение, а связь с ним ещё жива; хост о госте такого не узнаёт.
  bool _isAway(LobbyRoom room) => !_game.isHost && room.link == RoomLink.online && room.opponent?.away == true;

  bool _isUnstable(LobbyRoom room) => _game.isHost
      ? room.opponent?.online == true && room.opponent?.unstable == true
      : room.link == RoomLink.online && room.linkUnstable;

  void _apply(LobbyRoom room) {
    final lost = _isLost(room);
    final away = !lost && _isAway(room);
    final unstable = !lost && !away && _isUnstable(room);
    final was = state;
    if (lost == was.lost && away == was.away && unstable == was.unstable) return;
    final lostChanged = lost != was.lost;
    if (lostChanged) {
      _timer?.cancel();
      _timer = null;
    }
    emit(
      was.copyWith(
        lost: lost,
        away: away,
        unstable: unstable,
        left: lostChanged ? (lost ? _game.reconnectWindow : Duration.zero) : was.left,
        // «Ждать» прячет окно до следующей перемены: новый обрыв или сворачивание открывают его снова.
        dismissed: !lostChanged && away == was.away && was.dismissed,
      ),
    );
    if (lost && lostChanged) _timer = Timer.periodic(_tick, (_) => _countDown());
  }

  void _countDown() {
    final left = state.left - _tick;
    if (left <= Duration.zero) {
      _timer?.cancel();
      _timer = null;
      emit(state.copyWith(left: Duration.zero));
    } else {
      emit(state.copyWith(left: left));
    }
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
