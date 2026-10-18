import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:gwent/src/features/content/domain/game_content.dart';
import 'package:gwent/src/features/match/presentation/field/field_state.dart';
import 'package:gwent/src/features/match/presentation/match_screen_state.dart';
import 'package:gwent/src/features/match/presentation/stage/stage_builder.dart';
import 'package:gwent/src/features/match/presentation/stage/stage_script.dart';
import 'package:gwent/src/features/match/presentation/stage/stage_tokens.dart';
import 'package:gwent_engine/gwent_engine.dart';

/// Держатель того, что на поле решает сам игрок или что объявляют события: выбранная карта руки, листы сброса и
/// лидера, тосты и вспышки, баннеры, итог раунда и слой паузы.
///
/// Партию не меняет: ходы уходят в `MatchBloc`. Состояние партии держатель получает от экрана через
/// [onMatchState]: сбрасывает выбор, который устарел, и берёт из событий то, что надо показать (карты руки соперника,
/// баннеры раунда, хода и паса, итог раунда, только что сыгранные карты).
///
/// В hot-seat события каждого места копятся, пока телефон у другого, поэтому раунд, ход и итог раунда
/// объявляются один раз, а не заново каждому месту.
///
/// Показ занимает время (баннеры, итог раунда, пауза, последний ход партии, розыгрыш карт): пока он идёт,
/// [FieldState.isBusy] верно. Экран партии в это время откладывает следующие состояния партии, а поле не принимает
/// ходов.
///
/// Розыгрыш карт и эффекты (макет 12, ADR 0017) строятся здесь же из событий и двух проекций, до и после
/// обновления: сценарий собирается сразу, поэтому поле занято с первого кадра. Сценарий одинаков для своего хода,
/// хода бота и хода соперника по сети.
final class FieldCubit extends Cubit<FieldState> {
  /// Создаёт держатель с пустым состоянием; [finishHold] — сколько поле держит конец партии (последний ход и счёт),
  /// прежде чем открыть итог матча.
  FieldCubit({this.finishHold = defaultFinishHold}) : super(const FieldState());

  /// Сколько поле держит конец партии по умолчанию.
  static const Duration defaultFinishHold = Duration(milliseconds: 2200);

  /// Сколько поле держит конец партии.
  final Duration finishHold;

  /// Запас времени сверх длительности сценария: если поле его не отыграло (экран ушёл), сценарий снимается сам.
  static const Duration stageGrace = Duration(milliseconds: 1500);

  Timer? _finishTimer;
  Timer? _stageTimer;
  int _stageCount = 0;
  final Map<Seat, PlayerView> _seen = {};
  int _toastCount = 0;
  final Set<int> _announcedRounds = {};
  final Set<int> _summarizedRounds = {};
  Seat? _lastTurn;

  /// Выбирает карту руки [id]; повторный выбор той же карты снимает выбор.
  void toggleSelected(CardInstanceId id) =>
      emit(state.selected == id ? state.copyWith(clearSelected: true) : state.copyWith(selected: id));

  /// Выбирает карту руки [id] (например, когда её начали тащить).
  void select(CardInstanceId id) {
    if (state.selected != id) emit(state.copyWith(selected: id));
  }

  /// Снимает выбор карты.
  void clearSelected() {
    if (state.selected != null) emit(state.copyWith(clearSelected: true));
  }

  /// Открывает лист сброса.
  void openDiscard({required bool mine}) => emit(state.copyWith(overlay: DiscardOverlay(mine: mine)));

  /// Открывает лист лидера.
  void openLeader({required bool mine}) => emit(state.copyWith(overlay: LeaderOverlay(mine: mine)));

  /// Закрывает лист.
  void closeOverlay() {
    if (state.overlay is! NoOverlay) emit(state.copyWith(overlay: const NoOverlay()));
  }

  /// Порядок карт в листе сброса.
  void setSort(DiscardSort sort) => emit(state.copyWith(sort: sort));

  /// Показывает тост.
  void say(FieldMessage message) => emit(state.copyWith(toast: FieldToast(++_toastCount, message)));

  /// Убирает показанный баннер: на экран выходит следующий в очереди.
  void dismissBanner() {
    if (state.banners.isNotEmpty) emit(state.copyWith(banners: state.banners.sublist(1)));
  }

  /// Закрывает итог раунда.
  void dismissSummary() {
    if (state.summary != null) emit(state.copyWith(clearSummary: true));
  }

  /// Сценарий [id] отыгран: поле свободно, экран партии выпускает следующее состояние.
  void endStage(int id) {
    if (state.stage?.id != id) return;
    _stageTimer?.cancel();
    emit(state.copyWith(clearStage: true));
  }

  /// Открывает меню паузы; пока поле держит конец партии, пауза не нужна.
  void openPause() {
    if (!state.finishing) emit(state.copyWith(pause: PauseLayer.menu, clearSelected: true));
  }

  /// Закрывает слой паузы и возвращается к игре.
  void closePause() {
    if (state.pause != PauseLayer.none) emit(state.copyWith(pause: PauseLayer.none));
  }

  /// Открывает справочник правил из меню паузы.
  void openRules() => emit(state.copyWith(pause: PauseLayer.rules));

  /// Спрашивает, сдаваться ли.
  void askSurrender() => emit(state.copyWith(pause: PauseLayer.surrenderConfirm));

  /// Возвращает из правил или подтверждения сдачи в меню паузы.
  void backToPauseMenu() {
    if (state.pause == PauseLayer.rules || state.pause == PauseLayer.surrenderConfirm) {
      emit(state.copyWith(pause: PauseLayer.menu));
    }
  }

  /// Убирает тост [id], если он ещё на экране.
  void clearToast(int id) {
    if (state.toast?.id == id) emit(state.copyWith(clearToast: true));
  }

  /// Принимает новое состояние партии от экрана; [style] — скорость и «Уменьшить движение» для анимаций карт.
  void onMatchState(MatchScreenState match, {StageStyle style = StageStyle.normal}) {
    switch (match) {
      case MatchInProgress(:final view, :final events, :final refusal, :final content):
        _onProgress(view, events, refusal, content, style);
      case MatchIdle() ||
          MatchStarting() ||
          MatchStartFailed() ||
          MatchIntro() ||
          MatchToss() ||
          MatchHandover() ||
          MatchFinished() ||
          MatchCrashed():
        // Телефон ушёл другому игроку или партия закончилась: чужие выбор, листы, тосты и баннеры не переносятся.
        _finishTimer?.cancel();
        _stageTimer?.cancel();
        if (!state.isClean) emit(const FieldState());
        if (match is MatchIntro || match is MatchStarting) _forget();
    }
  }

  /// Новая партия: что объявлялось в прошлой, уже не считается.
  void _forget() {
    _announcedRounds.clear();
    _summarizedRounds.clear();
    _seen.clear();
    _lastTurn = null;
  }

  void _onProgress(PlayerView view, List<GameEvent> events, Reject? refusal, GameContent content, StageStyle style) {
    var next = state;
    final script = _stageFor(view, events, content, style);
    if (script != null) {
      next = next.copyWith(stage: script);
      _stageTimer?.cancel();
      _stageTimer = Timer(Duration(milliseconds: script.duration.ceil()) + stageGrace, () => endStage(script.id));
    }
    if (next.selected case final selected? when !view.me.playable.contains(selected)) {
      next = next.copyWith(clearSelected: true);
    }
    if (events.isNotEmpty) {
      final recent = <CardInstanceId>{};
      for (final event in events) {
        switch (event) {
          case HandRevealed(viewer: final shownTo, :final cards) when shownTo == view.viewer:
            next = next.copyWith(overlay: RevealOverlay(cards));
          case UnitPlaced(:final card) || CreatedCardPlaced(:final card):
            recent.add(card.id);
          case UnitDecoyed(:final decoy):
            recent.add(decoy.id);
          default:
            break;
        }
      }
      next = next.copyWith(recent: recent);
      final banners = _bannersFrom(view, events);
      if (banners.isNotEmpty) next = next.copyWith(banners: [...next.banners, ...banners]);
      if (_summaryFrom(view, events) case final summary?) next = next.copyWith(summary: summary);
    }
    if (refusal != null) next = next.copyWith(toast: FieldToast(++_toastCount, FieldMessage.refused));
    if (_endsByCrystals(events) && view.phase == MatchPhase.finished && finishHold > Duration.zero) {
      // Игрок должен увидеть, чем и со счётом сколько закончилась партия, прежде чем откроется итог матча.
      next = next.copyWith(finishing: true);
      _finishTimer?.cancel();
      _finishTimer = Timer(finishHold, _endFinishing);
    }
    if (!identical(next, state)) emit(next);
  }

  /// Сценарий показа розыгрыша карт и эффектов; `null`, если показывать нечего или нет проекции «до».
  ///
  /// Проекцию «до» держим по местам: в hot-seat каждый игрок сравнивает с тем, что видел сам.
  StageScript? _stageFor(PlayerView view, List<GameEvent> events, GameContent content, StageStyle style) {
    final prev = _seen[view.viewer];
    _seen[view.viewer] = view;
    if (prev == null || events.isEmpty) return null;
    return StageScriptBuilder(
      prev: prev,
      next: view,
      catalog: content.catalog,
      style: style,
    ).build(++_stageCount, events);
  }

  /// Партию закончил последний раунд; сдача держать поле не должна.
  static bool _endsByCrystals(List<GameEvent> events) =>
      events.any((event) => event is MatchEnded && event.outcome.reason == MatchEndReason.crystals);

  void _endFinishing() {
    if (!isClosed && state.finishing) emit(state.copyWith(finishing: false));
  }

  @override
  Future<void> close() {
    _finishTimer?.cancel();
    _stageTimer?.cancel();
    return super.close();
  }

  /// Баннеры по порядку показа: раунд, пас, ход. Ход объявляется, только когда он перешёл к другому месту:
  /// после паса соперника каждый мой ход начинается заново, и баннер каждый раз был бы лишним.
  List<FieldBanner> _bannersFrom(PlayerView view, List<GameEvent> events) {
    final banners = <FieldBanner>[];
    final roundEnded = events.any((event) => event is RoundEnded);
    final started = events.whereType<RoundStarted>().lastOrNull;
    if (started != null) {
      _lastTurn = null;
      if (_announcedRounds.add(started.round)) {
        banners.add(
          RoundStartBanner(round: started.round, decisive: view.me.crystals == 1 && view.opponent.crystals == 1),
        );
      }
    }
    // Пас, после которого закончился раунд, объявляет итог раунда.
    if (!roundEnded) {
      for (final passed in events.whereType<Passed>()) {
        banners.add(PassBanner(seat: passed.seat, mine: passed.seat == view.viewer));
      }
    }
    final turn = events.whereType<TurnStarted>().lastOrNull;
    if (turn != null && turn.seat != _lastTurn) {
      _lastTurn = turn.seat;
      if (!banners.any((banner) => banner is PassBanner && !banner.mine)) {
        banners.add(TurnStartBanner(seat: turn.seat, mine: turn.seat == view.viewer));
      }
    }
    return banners;
  }

  /// Итог раунда, закончившегося в [events], если игрок его ещё не видел; в конце партии итог раунда не нужен
  /// (его заменяет итог матча).
  RoundSummary? _summaryFrom(PlayerView view, List<GameEvent> events) {
    final endIndex = events.lastIndexWhere((event) => event is RoundEnded);
    if (endIndex < 0 || events.any((event) => event is MatchEnded)) return null;
    final result = (events[endIndex] as RoundEnded).result;
    if (!_summarizedRounds.add(result.round)) return null;
    final me = view.viewer;
    // Перки фракций сыграли до первого хода нового раунда; ход бота в той же пачке (лидер, добор) к ним не относится.
    final after = events.sublist(endIndex + 1).takeWhile((event) => event is! TurnStarted);
    final marks = <FactionMark>[];
    Faction factionOf(Seat seat) => seat == me ? view.me.faction : view.opponent.faction;
    void mark(Seat seat, FactionMarkKind kind) =>
        marks.add(FactionMark(seat: seat, mine: seat == me, faction: factionOf(seat), kind: kind));
    final winner = result.winner;
    if (winner != null && result.scores[Seat.one] == result.scores[Seat.two]) mark(winner, FactionMarkKind.wonTie);
    for (final event in after) {
      switch (event) {
        case UnitKept(side: final seat):
          mark(seat, FactionMarkKind.unitStays);
        case CardsDrawn(:final seat) || CardsDrawnHidden(:final seat):
          mark(seat, FactionMarkKind.extraCard);
        default:
          break;
      }
    }
    return RoundSummary(
      round: result.round,
      mineSeat: me,
      scoreMine: result.scores[me] ?? 0,
      scoreOpponent: result.scores[me.opponent] ?? 0,
      outcome: switch (winner) {
        null => RoundOutcome.draw,
        _ when winner == me => RoundOutcome.win,
        _ => RoundOutcome.loss,
      },
      crystalsMine: view.me.crystals,
      crystalsOpponent: view.opponent.crystals,
      mineFaction: view.me.faction,
      opponentFaction: view.opponent.faction,
      marks: marks,
    );
  }
}
