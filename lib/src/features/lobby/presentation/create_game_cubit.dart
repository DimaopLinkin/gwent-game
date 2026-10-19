import 'package:bloc/bloc.dart';
import 'package:gwent/src/features/lobby/application/host_network_game.dart';
import 'package:gwent/src/features/lobby/application/network_open_result.dart';
import 'package:gwent/src/features/lobby/presentation/create_game_state.dart';
import 'package:gwent/src/features/settings/application/watch_settings.dart';

/// Держатель экрана создания партии: подставляет имя игрока и создаёт игру.
final class CreateGameCubit extends Cubit<CreateGameState> {
  /// Создаёт держатель. [fallbackName] — имя, если игрок не задал своё в настройках.
  CreateGameCubit(this._hostNetworkGame, WatchSettings watchSettings, {required String fallbackName})
    : _watchSettings = watchSettings,
      _fallbackName = fallbackName,
      super(const CreateGameLoading()) {
    _load();
  }

  final HostNetworkGame _hostNetworkGame;
  final WatchSettings _watchSettings;
  final String _fallbackName;
  String? _playerName;

  Future<void> _load() async {
    try {
      _playerName = _clean((await _watchSettings().first).playerName);
    } on Object catch (error, stackTrace) {
      // Без настроек партия получит имя по умолчанию.
      addError(error, stackTrace);
    }
    if (!isClosed) emit(CreateGameForm(_playerName ?? _fallbackName));
  }

  String? _clean(String? name) {
    final trimmed = name?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  /// Создаёт партию с названием [name]; пустое название заменяется именем игрока.
  Future<void> create(String name) async {
    if (state is CreateGameCreating || state is CreateGameCreated) return;
    final gameName = _clean(name) ?? _playerName ?? _fallbackName;
    emit(const CreateGameCreating());
    final NetworkOpenResult result;
    try {
      result = await _hostNetworkGame(gameName: gameName, playerName: _playerName ?? gameName);
    } on Object catch (error, stackTrace) {
      addError(error, stackTrace);
      if (!isClosed) emit(CreateGameFailed(const NetworkUnavailable(), gameName));
      return;
    }
    if (isClosed) {
      // Игрок ушёл с экрана, пока партия создавалась: она никому не нужна, объявление не должно остаться в сети.
      if (result case NetworkGameOpened(:final game)) await game.close();
      return;
    }
    emit(switch (result) {
      NetworkGameOpened() => const CreateGameCreated(),
      _ => CreateGameFailed(result, gameName),
    });
  }

  /// Возвращает форму после неудачи.
  void edit() {
    if (state case CreateGameFailed(:final name)) emit(CreateGameForm(name));
  }
}
