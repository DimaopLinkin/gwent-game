import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:gwent/src/features/deck_builder/application/get_deck.dart';
import 'package:gwent/src/features/deck_builder/application/load_deck_rules.dart';
import 'package:gwent/src/features/deck_builder/domain/deck_rules.dart';
import 'package:gwent/src/features/deck_builder/domain/engine_deck.dart';
import 'package:gwent/src/features/lobby/application/network_game.dart';
import 'package:gwent/src/features/lobby/domain/lobby_room.dart';
import 'package:gwent/src/features/lobby/presentation/room_state.dart';
import 'package:gwent_engine/gwent_engine.dart' show LeaderId;
import 'package:gwent_net/gwent_net.dart' show LobbyStage;

/// Держатель комнаты сетевой игры: следит за комнатой, выбирает колоду, отмечает готовность и ведёт отсчёт до старта.
///
/// Колода выбирается из сохранённых: хост видит только лидера выбранной колоды, остальное скрыто. Готовность — это
/// отправка колоды хосту; любое изменение (смена колоды, переход в конструктор) её отменяет. Если комната закрыта,
/// не начавшись партией, держатель уходит из игры сам.
final class RoomCubit extends Cubit<RoomState> {
  /// Создаёт держатель над игрой [game].
  ///
  /// [tick] — как часто убывает отсчёт до старта; секунда, тесты ускоряют.
  RoomCubit(this._game, this._loadDeckRules, this._getDeck, {Duration tick = const Duration(seconds: 1)})
    : _tick = tick,
      super(RoomState(room: _game.room)) {
    _subscription = _game.rooms.listen(_onRoom);
    unawaited(_loadRules());
  }

  final NetworkGame _game;
  final LoadDeckRules _loadDeckRules;
  final GetDeck _getDeck;
  final Duration _tick;
  late final StreamSubscription<LobbyRoom> _subscription;
  Timer? _ticker;

  /// Игра, которую показывает комната.
  NetworkGame get game => _game;

  Future<void> _loadRules() async {
    try {
      final DeckRules rules = await _loadDeckRules();
      if (!isClosed) emit(state.copyWith(rules: rules));
    } on Object catch (error, stackTrace) {
      // Без правил колоду проверить нельзя, «Готов» остаётся недоступной.
      addError(error, stackTrace);
    }
  }

  void _onRoom(LobbyRoom room) {
    final previous = state.room;
    emit(state.copyWith(room: room));
    final counting = room.countdown;
    if (counting != null && previous.countdown == null) {
      _startCountdown(counting);
    } else if (counting == null) {
      _stopCountdown();
    }
  }

  void _startCountdown(Duration duration) {
    _ticker?.cancel();
    var left = (duration.inMilliseconds / 1000).ceil();
    emit(state.copyWith(countdownLeft: left));
    _ticker = Timer.periodic(_tick, (timer) {
      left--;
      if (left <= 0) {
        timer.cancel();
        _ticker = null;
        return;
      }
      if (!isClosed) emit(state.copyWith(countdownLeft: left));
    });
  }

  void _stopCountdown() {
    _ticker?.cancel();
    _ticker = null;
    if (state.countdownLeft != null) emit(state.copyWith(clearCountdown: true));
  }

  /// Игрок открыл выбор колоды или конструктор: он занят, а прежняя готовность отменена.
  void startEditing({required bool building}) {
    _game.reportStage(building ? LobbyStage.building : LobbyStage.choosing);
  }

  /// Игрок вернулся из выбора колоды или конструктора; [deckId] — выбранная или сохранённая колода, `null`, если он
  /// ушёл, ничего не выбрав. Тогда игрок снова там, где был: с прежней колодой или без неё.
  Future<void> finishEditing(String? deckId) async {
    if (deckId != null && await _select(deckId)) return;
    if (isClosed) return;
    final deck = state.deck;
    _game.reportStage(
      deck == null ? LobbyStage.choosing : LobbyStage.chosen,
      leader: deck == null ? null : LeaderId(deck.leaderId),
    );
  }

  /// Выбирает сохранённую колоду [deckId]. Если колоды больше нет, ничего не меняется.
  Future<void> selectDeck(String deckId) async {
    await _select(deckId);
  }

  Future<bool> _select(String deckId) async {
    final deck = await _getDeck(deckId);
    if (deck == null || isClosed) return false;
    final rules = state.rules ?? await _loadRulesOrNull();
    if (isClosed) return false;
    emit(state.copyWith(rules: rules, deck: deck, issues: rules?.check(deck) ?? const []));
    _game.reportStage(LobbyStage.chosen, leader: LeaderId(deck.leaderId));
    return true;
  }

  Future<DeckRules?> _loadRulesOrNull() async {
    try {
      return await _loadDeckRules();
    } on Object {
      return null;
    }
  }

  /// Игрок готов: хост получает колоду. Не годная колода не отправляется.
  void ready() {
    final deck = state.deck;
    if (deck == null || !state.deckValid || state.room.myStage == LobbyStage.ready) return;
    _game.ready(deck.toEngineDeck(), deckName: deck.name);
  }

  /// Игрок больше не готов.
  void cancelReady() => _game.cancelReady();

  /// Игрок уходит из комнаты; игра закрывается.
  Future<void> leave() => _game.leave();

  @override
  Future<void> close() async {
    _ticker?.cancel();
    await _subscription.cancel();
    // Партия началась и её ведёт экран партии, иначе уход с экрана — это уход из игры.
    if (!_game.room.started) unawaited(_game.leave());
    return super.close();
  }
}
