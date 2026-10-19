import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:gwent/src/features/lobby/application/discover_network_games.dart';
import 'package:gwent/src/features/lobby/application/join_network_game.dart';
import 'package:gwent/src/features/lobby/application/network_open_result.dart';
import 'package:gwent/src/features/lobby/presentation/find_games_state.dart';
import 'package:gwent/src/features/settings/application/watch_settings.dart';

/// Держатель экрана поиска: показывает найденные партии и подключает гостя к выбранной.
///
/// Пока гость подключается, поиск стоит: так сеть не занята лишней работой, а список не прыгает под пальцем.
final class FindGamesCubit extends Cubit<FindGamesState> {
  /// Создаёт держатель и сразу начинает поиск. [fallbackName] — имя гостя, если в настройках его нет.
  FindGamesCubit(this._discover, this._join, this._watchSettings, {required String fallbackName})
    : _fallbackName = fallbackName,
      super(FindGamesSearching(const [])) {
    search();
  }

  final DiscoverNetworkGames _discover;
  final JoinNetworkGame _join;
  final WatchSettings _watchSettings;
  final String _fallbackName;
  StreamSubscription<List<DiscoveredGame>>? _subscription;

  /// Начинает поиск заново; прежний останавливается.
  void search() {
    unawaited(_subscription?.cancel());
    emit(FindGamesSearching(const []));
    _subscription = _discover().listen(
      (games) {
        if (state is FindGamesSearching) emit(FindGamesSearching(games));
      },
      onError: (Object error, StackTrace stackTrace) {
        // Служба поиска отказала: Wi-Fi выключен или нет доступа к локальной сети.
        addError(error, stackTrace);
        if (state is FindGamesSearching) emit(const FindGamesUnavailable());
      },
    );
  }

  /// Подключается к партии [game], если к ней можно присоединиться.
  Future<void> join(DiscoveredGame game) async {
    final current = state;
    if (current is! FindGamesSearching && current is! FindGamesFailed) return;
    if (!game.joinable) return;
    final games = current is FindGamesSearching ? current.games : [game];
    await _subscription?.cancel();
    _subscription = null;
    emit(FindGamesJoining(games, game.found.ad.id));
    final NetworkOpenResult result;
    try {
      result = await _join(found: game.found, playerName: await _playerName());
    } on Object catch (error, stackTrace) {
      addError(error, stackTrace);
      if (!isClosed) emit(FindGamesFailed(const NetworkUnreachable(), game));
      return;
    }
    if (isClosed) return;
    emit(switch (result) {
      NetworkGameOpened() => const FindGamesJoined(),
      _ => FindGamesFailed(result, game),
    });
  }

  Future<String> _playerName() async {
    try {
      final name = (await _watchSettings().first).playerName?.trim();
      if (name != null && name.isNotEmpty) return name;
    } on Object catch (error, stackTrace) {
      addError(error, stackTrace);
    }
    return _fallbackName;
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}
