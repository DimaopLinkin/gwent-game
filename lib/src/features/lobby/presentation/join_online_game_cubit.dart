import 'package:bloc/bloc.dart';
import 'package:gwent/src/features/lobby/application/join_network_game.dart';
import 'package:gwent/src/features/lobby/application/network_open_result.dart';
import 'package:gwent/src/features/lobby/domain/game_address.dart';
import 'package:gwent/src/features/lobby/domain/room_code.dart';
import 'package:gwent/src/features/lobby/presentation/join_online_game_state.dart';
import 'package:gwent/src/features/lobby/presentation/saved_player_name.dart';
import 'package:gwent/src/features/settings/application/watch_settings.dart';

/// Держатель экрана ввода кода: разбирает введённое, входит в комнату и сообщает, чем кончилось.
///
/// Каждый неверный код тратит лимит попыток игрока на сервере (ADR 0025), поэтому то, что заведомо не код, к сервису
/// не отправляется.
final class JoinOnlineGameCubit extends Cubit<JoinOnlineGameState> {
  /// Создаёт держатель. [fallbackName] — имя гостя, если в настройках его нет.
  JoinOnlineGameCubit(this._joinOnlineGame, this._watchSettings, {required String fallbackName})
    : _fallbackName = fallbackName,
      super(const JoinOnlineGameForm());

  final JoinNetworkGame _joinOnlineGame;
  final WatchSettings _watchSettings;
  final String _fallbackName;

  /// Входит в комнату по введённому [input].
  Future<void> join(String input) async {
    if (state is JoinOnlineGameJoining || state is JoinOnlineGameJoined) return;
    final code = RoomCode.tryParse(input);
    if (code == null) {
      emit(const JoinOnlineGameForm(badCode: true));
      return;
    }
    emit(JoinOnlineGameJoining(code));
    final NetworkOpenResult result;
    try {
      final name = await savedPlayerName(_watchSettings, onError: addError) ?? _fallbackName;
      result = await _joinOnlineGame.byAddress(OnlineAddress(code), playerName: name);
    } on Object catch (error, stackTrace) {
      addError(error, stackTrace);
      if (!isClosed) emit(const JoinOnlineGameForm(failure: NetworkUnavailable()));
      return;
    }
    if (isClosed) {
      // Игрок ушёл с экрана, пока входил: уходит и из лобби, чтобы хост сразу освободил место, а не ждал возвращения.
      if (result case NetworkGameOpened(:final game)) await game.leave();
      return;
    }
    emit(switch (result) {
      NetworkGameOpened() => const JoinOnlineGameJoined(),
      _ => JoinOnlineGameForm(failure: result),
    });
  }

  /// Игрок правит код: прежняя ошибка к новому тексту уже не относится.
  void edited() {
    if (state case JoinOnlineGameForm(failure: != null) || JoinOnlineGameForm(badCode: true)) {
      emit(const JoinOnlineGameForm());
    }
  }
}
