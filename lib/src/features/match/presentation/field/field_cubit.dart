import 'package:bloc/bloc.dart';
import 'package:gwent/src/features/match/presentation/field/field_state.dart';
import 'package:gwent/src/features/match/presentation/match_screen_state.dart';
import 'package:gwent_engine/gwent_engine.dart';

/// Держатель того, что на поле решает сам игрок: выбранная карта руки, листы сброса и лидера, тосты и вспышки.
///
/// Партию не меняет: ходы уходят в `MatchBloc`. Состояние партии держатель получает от экрана через
/// [onMatchState]: сбрасывает выбор, который устарел, и берёт из событий то, что надо показать (карты руки соперника,
/// пас соперника, только что сыгранные карты).
final class FieldCubit extends Cubit<FieldState> {
  /// Создаёт держатель с пустым состоянием.
  FieldCubit() : super(const FieldState());

  int _toastCount = 0;

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

  /// Убирает баннер «Противник спасовал» после показа.
  void clearBanner() {
    if (state.showOpponentPassed) emit(state.copyWith(showOpponentPassed: false));
  }

  /// Убирает тост [id], если он ещё на экране.
  void clearToast(int id) {
    if (state.toast?.id == id) emit(state.copyWith(clearToast: true));
  }

  /// Принимает новое состояние партии от экрана.
  void onMatchState(MatchScreenState match) {
    switch (match) {
      case MatchInProgress(:final view, :final events, :final refusal):
        _onProgress(view, events, refusal);
      case MatchIdle() || MatchStarting() || MatchStartFailed() || MatchHandover() || MatchFinished() || MatchCrashed():
        // Телефон ушёл другому игроку или партия закончилась: чужие выбор, листы, тосты и баннеры не переносятся.
        if (!state.isClean) emit(const FieldState());
    }
  }

  void _onProgress(PlayerView view, List<GameEvent> events, Reject? refusal) {
    var next = state;
    if (next.selected case final selected? when !view.me.playable.contains(selected)) {
      next = next.copyWith(clearSelected: true);
    }
    if (events.isNotEmpty) {
      final recent = <CardInstanceId>{};
      for (final event in events) {
        switch (event) {
          case HandRevealed(viewer: final shownTo, :final cards) when shownTo == view.viewer:
            next = next.copyWith(overlay: RevealOverlay(cards));
          case Passed(:final seat) when seat != view.viewer:
            next = next.copyWith(showOpponentPassed: true);
          case UnitPlaced(:final card) || CreatedCardPlaced(:final card):
            recent.add(card.id);
          case UnitDecoyed(:final decoy):
            recent.add(decoy.id);
          default:
            break;
        }
      }
      next = next.copyWith(recent: recent);
    }
    if (refusal != null) next = next.copyWith(toast: FieldToast(++_toastCount, FieldMessage.refused));
    if (!identical(next, state)) emit(next);
  }
}
