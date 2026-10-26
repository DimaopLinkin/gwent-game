import 'package:gwent/src/features/tutorial/domain/tutorial_move.dart';
import 'package:gwent_engine/gwent_engine.dart';

/// Намерение игрока для хода сценария [move] по его проекции [view].
Intent intentFor(PlayerView view, TutorialMove move) => switch (move) {
  PlayMove(:final cardId, :final row) => PlayCard(
    view.me.hand!.firstWhere((card) => card.cardId.value == cardId).id,
    row: row,
  ),
  LeaderMove() => const UseLeader(),
  PassMove() => const Pass(),
};
