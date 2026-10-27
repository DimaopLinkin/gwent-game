import 'package:gwent/src/features/tutorial/domain/hint_target.dart';
import 'package:gwent_engine/gwent_engine.dart';

/// Ход сценария: что игрок или бот должен сделать в этот момент партии.
sealed class TutorialMove extends Value {
  const TutorialMove();

  /// Это намерение [intent] места [seat] и есть ход сценария при состоянии партии [state] (до применения).
  bool matches(MatchState state, Seat seat, Intent intent);
}

/// Сыграть карту [cardId] (UUID пакета); если [row] задан, в этот ряд.
final class PlayMove extends TutorialMove {
  /// Создаёт ход; [destination] — куда игрок должен положить карту, для подсветки.
  const PlayMove(this.cardId, {this.row, this.destination});

  /// UUID карты пакета контента.
  final String cardId;

  /// Ряд в намерении; `null` — любой (погода, отряд с единственным рядом).
  final Row? row;

  /// Цель, которую подсвечивает слой после выбора карты; `null` у ходов бота.
  final HintTarget? destination;

  /// Карта [cardId] в руке места [seat] (первая из копий); `null`, если её там нет.
  CardInstance? handCard(MatchState state, Seat seat) =>
      state.player(seat).hand.where((card) => card.cardId.value == cardId).firstOrNull;

  /// Намерение бота: сыграть карту из руки; `null`, если её нет в руке.
  PlayCard? toIntent(MatchState state, Seat seat) {
    final card = handCard(state, seat);
    return card == null ? null : PlayCard(card.id, row: row);
  }

  @override
  bool matches(MatchState state, Seat seat, Intent intent) =>
      intent is PlayCard &&
      state.player(seat).hand.any((card) => card.id == intent.card && card.cardId.value == cardId) &&
      (row == null || intent.row == row);

  @override
  List<Object?> get props => [cardId, row, destination];
}

/// Применить способность лидера.
final class LeaderMove extends TutorialMove {
  /// Создаёт ход.
  const LeaderMove();

  @override
  bool matches(MatchState state, Seat seat, Intent intent) => intent is UseLeader;

  @override
  List<Object?> get props => const [];
}

/// Спасовать.
final class PassMove extends TutorialMove {
  /// Создаёт ход.
  const PassMove();

  @override
  bool matches(MatchState state, Seat seat, Intent intent) => intent is Pass;

  @override
  List<Object?> get props => const [];
}
