import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:gwent/src/features/lobby/application/discover_network_games.dart';
import 'package:gwent/src/features/lobby/application/join_network_game.dart';
import 'package:gwent/src/features/lobby/application/network_open_result.dart';
import 'package:gwent/src/features/lobby/application/network_readiness.dart';
import 'package:gwent/src/features/lobby/domain/game_address.dart';
import 'package:gwent/src/features/lobby/domain/network_access.dart';
import 'package:gwent/src/features/lobby/presentation/find_games_state.dart';
import 'package:gwent/src/features/settings/application/watch_settings.dart';

/// Держатель экрана поиска: показывает найденные партии и подключает гостя к выбранной.
///
/// Пока гость подключается, поиск стоит: так сеть не занята лишней работой, а список не прыгает под пальцем.
final class FindGamesCubit extends Cubit<FindGamesState> {
  /// Создаёт держатель и сразу начинает поиск. [fallbackName] — имя гостя, если в настройках его нет.
  FindGamesCubit(this._discover, this._join, this._watchSettings, this._readiness, {required String fallbackName})
    : _fallbackName = fallbackName,
      super(FindGamesSearching(const [])) {
    search();
  }

  final DiscoverNetworkGames _discover;
  final JoinNetworkGame _join;
  final WatchSettings _watchSettings;
  final NetworkReadiness _readiness;
  final String _fallbackName;
  StreamSubscription<List<DiscoveredGame>>? _subscription;

  /// Начинает поиск заново; прежний останавливается.
  void search() {
    unawaited(_subscription?.cancel());
    _subscription = null;
    emit(FindGamesSearching(const []));
    unawaited(_start());
  }

  Future<void> _start() async {
    final NetworkProblem? problem;
    try {
      problem = await _readiness.check();
    } on Object catch (error, stackTrace) {
      // Не удалось проверить телефон: поиск покажет сам, работает ли сеть.
      addError(error, stackTrace);
      return _listen();
    }
    if (isClosed || state is! FindGamesSearching) return;
    if (problem != null) {
      emit(FindGamesUnavailable(problem: problem));
      return;
    }
    _listen();
  }

  void _listen() {
    if (isClosed || state is! FindGamesSearching) return;
    _subscription = _discover().listen(
      (games) {
        if (state is FindGamesSearching) emit(FindGamesSearching(games));
      },
      onError: (Object error, StackTrace stackTrace) {
        // Служба поиска отказала: Wi-Fi выключен или нет доступа к локальной сети.
        addError(error, stackTrace);
        unawaited(_unavailable());
      },
    );
  }

  Future<void> _unavailable() async {
    NetworkProblem? problem;
    try {
      problem = await _readiness.diagnose();
    } on Object catch (error, stackTrace) {
      addError(error, stackTrace);
    }
    if (!isClosed && state is FindGamesSearching) emit(FindGamesUnavailable(problem: problem));
  }

  /// Игрок прочитал пояснение про локальную сеть: оно больше не покажется, поиск начинается.
  Future<void> continueAfterExplainer() async {
    await _readiness.markExplained();
    if (!isClosed) search();
  }

  /// Открывает системные настройки, где игрок исправит [problem].
  Future<void> openSettings(NetworkProblem problem) => _readiness.openSettings(problem);

  /// Подключается к партии [game], если к ней можно присоединиться.
  Future<void> join(DiscoveredGame game) async {
    final current = state;
    if (current is! FindGamesSearching && current is! FindGamesFailed) return;
    if (!game.joinable) return;
    final games = current is FindGamesSearching ? current.games : [game];
    await _stopSearch();
    if (isClosed) return;
    emit(FindGamesJoining(games, game.found.ad.id));
    await _finishJoin(() async => _join(found: game.found, playerName: await _playerName()), (result) {
      return FindGamesFailed(result, game: game);
    });
  }

  /// Подключается по адресу [address] из QR-кода.
  Future<void> joinByCode(GameAddress address) async {
    final current = state;
    if (current is! FindGamesSearching && current is! FindGamesFailed) return;
    await _stopSearch();
    if (isClosed) return;
    emit(FindGamesJoiningByCode(address));
    await _finishJoin(() async {
      if (await _readiness.check() case final problem?) return NetworkUnavailable(problem: problem);
      return _join.byAddress(address, playerName: await _playerName());
    }, (result) => FindGamesFailed(result, address: address));
  }

  /// Повторяет подключение, которое не удалось.
  Future<void> retry() async {
    final failed = state;
    if (failed is! FindGamesFailed) return;
    if (failed.game case final game?) return join(game);
    if (failed.address case final address?) return joinByCode(address);
  }

  Future<void> _stopSearch() async {
    await _subscription?.cancel();
    _subscription = null;
  }

  Future<void> _finishJoin(
    Future<NetworkOpenResult> Function() connect,
    FindGamesFailed Function(NetworkOpenResult result) failed,
  ) async {
    final NetworkOpenResult result;
    try {
      result = await connect();
    } on Object catch (error, stackTrace) {
      addError(error, stackTrace);
      if (!isClosed) emit(failed(const NetworkUnreachable()));
      return;
    }
    if (isClosed) {
      // Игрок ушёл с экрана, пока подключался: место у хоста не держим.
      if (result case NetworkGameOpened(:final game)) await game.close();
      return;
    }
    emit(switch (result) {
      NetworkGameOpened() => const FindGamesJoined(),
      _ => failed(result),
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
