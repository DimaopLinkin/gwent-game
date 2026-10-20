import 'package:bloc/bloc.dart';
import 'package:gwent/src/features/lobby/application/host_network_game.dart';
import 'package:gwent/src/features/lobby/application/network_open_result.dart';
import 'package:gwent/src/features/lobby/presentation/create_game_state.dart';
import 'package:gwent/src/features/lobby/presentation/saved_player_name.dart';
import 'package:gwent/src/features/settings/application/watch_settings.dart';

/// Держатель экрана создания комнаты для игры через интернет: комната создаётся сразу, как экран открылся.
///
/// Название партии здесь не спрашивают: гостя находят по коду, а не по списку. Хост называется именем игрока.
final class CreateOnlineGameCubit extends Cubit<CreateGameState> {
  /// Создаёт держатель и сразу создаёт комнату. [fallbackName] — имя, если игрок не задал своё в настройках.
  CreateOnlineGameCubit(this._hostOnlineGame, this._watchSettings, {required String fallbackName})
    : _fallbackName = fallbackName,
      super(const CreateGameCreating()) {
    create();
  }

  final HostNetworkGame _hostOnlineGame;
  final WatchSettings _watchSettings;
  final String _fallbackName;
  bool _busy = false;

  /// Создаёт комнату; после неудачи это же «Повторить». Пока комната создаётся, повторный вызов ничего не делает.
  Future<void> create() async {
    if (_busy || state is CreateGameCreated) return;
    _busy = true;
    try {
      await _create();
    } finally {
      _busy = false;
    }
  }

  Future<void> _create() async {
    final name = await savedPlayerName(_watchSettings, onError: addError) ?? _fallbackName;
    if (isClosed) return;
    emit(const CreateGameCreating());
    final NetworkOpenResult result;
    try {
      result = await _hostOnlineGame(gameName: name, playerName: name);
    } on Object catch (error, stackTrace) {
      addError(error, stackTrace);
      if (!isClosed) emit(CreateGameFailed(const NetworkUnavailable(), name));
      return;
    }
    if (isClosed) {
      // Игрок ушёл с экрана, пока комната создавалась: она никому не нужна, и закрыться она должна на сервере.
      if (result case NetworkGameOpened(:final game)) await game.close();
      return;
    }
    emit(switch (result) {
      NetworkGameOpened() => const CreateGameCreated(),
      _ => CreateGameFailed(result, name),
    });
  }
}
