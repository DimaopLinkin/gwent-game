import 'package:gwent/src/features/deck_builder/domain/deck.dart';
import 'package:gwent/src/features/match/application/start_match.dart';
import 'package:gwent/src/features/match/domain/match_session.dart';
import 'package:gwent_engine/gwent_engine.dart' show Seat;
import 'package:meta/meta.dart';

/// Состояние выбора перед партией: режим и колоды мест.
@immutable
sealed class MatchSetupState {
  const MatchSetupState();
}

/// Колоды ещё читаются.
final class MatchSetupLoading extends MatchSetupState {
  /// Создаёт состояние.
  const MatchSetupLoading();
}

/// Колоды прочитать не удалось.
final class MatchSetupFailed extends MatchSetupState {
  /// Создаёт состояние с причиной [error].
  const MatchSetupFailed(this.error);

  /// Причина для журнала; игроку показывается общее сообщение.
  final Object error;
}

/// Колоды есть, игрок выбирает.
final class MatchSetupReady extends MatchSetupState {
  /// Создаёт состояние.
  MatchSetupReady({required List<Deck> decks, required this.mode, this.deckOne, this.deckTwo})
    : decks = List.unmodifiable(decks);

  /// Колоды игрока, сначала недавно изменённые.
  final List<Deck> decks;

  /// Режим.
  final LocalMatchMode mode;

  /// Выбранная колода первого места.
  final String? deckOne;

  /// Выбранная колода второго места (против бота — колода бота).
  final String? deckTwo;

  /// Выбранная колода места [seat].
  String? deck(Seat seat) => switch (seat) {
    Seat.one => deckOne,
    Seat.two => deckTwo,
  };

  /// Запрос на партию, когда выбраны обе колоды; иначе `null`.
  LocalMatchRequest? get request => switch ((deckOne, deckTwo)) {
    (final one?, final two?) => LocalMatchRequest(mode: mode, deckOne: one, deckTwo: two),
    _ => null,
  };
}
