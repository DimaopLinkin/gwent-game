import 'package:gwent_content/gwent_content.dart' show BonusCondition;
import 'package:gwent_engine/gwent_engine.dart';
import 'package:gwent_net/gwent_net.dart' show MatchRecord;
import 'package:meta/meta.dart';

/// Итог раунда для игрока: его очки, очки соперника и победитель.
@immutable
final class RoundScore {
  /// Создаёт итог раунда.
  const RoundScore({required this.mine, required this.theirs, required this.won});

  /// Очки игрока.
  final int mine;

  /// Очки соперника.
  final int theirs;

  /// Игрок выиграл раунд. При равных очках решают правила (перк Нильфгаарда), поэтому победителя называет движок,
  /// а не сравнение очков.
  final bool won;

  /// Перевес игрока в очках; у проигранного раунда отрицательный.
  int get margin => mine - theirs;
}

/// Что произошло в партии кампании: по этому судят о победе и об условии дополнительной награды (ADR 0033).
///
/// Условия считаются по итогу и по журналу партии. Новое условие добавляется кодом и тестом здесь, а данные
/// называют его в `BonusCondition`.
@immutable
final class CampaignMatchFacts {
  /// Создаёт итог партии.
  CampaignMatchFacts({required this.won, List<RoundScore> rounds = const [], this.specialsPlayed = 0})
    : rounds = List.unmodifiable(rounds),
      played = true;

  /// Победа без партии: «Первая партия» пройдена в обучении, и кампания засчитывает узел 0 при первом входе.
  /// Условия дополнительной награды при этом не выполнены: «ни одной особой карты» нельзя выполнить, не играя.
  const CampaignMatchFacts.withoutMatch() : won = true, rounds = const [], specialsPlayed = 0, played = false;

  /// Итог партии, снятый с журнала [record] и последней проекции [finalView] глазами места [me].
  ///
  /// Журнал проигрывается движком заново, чтобы увидеть, какие особые карты сыграл игрок (по сыгранным картам,
  /// а не по составу колоды). Бросает [StateError], если журнал не от этого движка (его ход отклоняется), и
  /// [ArgumentError], если партия в [finalView] ещё не окончена.
  factory CampaignMatchFacts.fromMatch({
    required MatchRecord record,
    required MatchEngine engine,
    required CardCatalog catalog,
    required PlayerView finalView,
    required Seat me,
  }) {
    final outcome =
        finalView.outcome ?? (throw ArgumentError.value(finalView.phase, 'finalView', 'Партия не окончена'));
    var specials = 0;
    var state = switch (engine.start(record.setup)) {
      Accepted(:final state) => state,
      Rejected(:final reject) => throw StateError('Журнал ${record.matchId}: партия не начинается: $reject'),
    };
    for (final (index, move) in record.moves.indexed) {
      switch (engine.apply(state, move.seat, move.intent)) {
        case Accepted(state: final next, :final events):
          state = next;
          for (final event in events) {
            if (event is CardPlayed && event.seat == me && catalog.card(event.card.cardId) is SpecialCardDefinition) {
              specials++;
            }
          }
        case Rejected(:final reject):
          throw StateError('Журнал ${record.matchId}: ход $index отклонён: $reject');
      }
    }
    return CampaignMatchFacts(
      won: outcome.winner == me,
      rounds: [
        for (final round in finalView.history)
          RoundScore(mine: round.scores[me] ?? 0, theirs: round.scores[me.opponent] ?? 0, won: round.winner == me),
      ],
      specialsPlayed: specials,
    );
  }

  /// Игрок выиграл партию. Сдача, выход и обрыв это поражение (ADR 0033).
  final bool won;

  /// Партия была сыграна в кампании; `false` у [CampaignMatchFacts.withoutMatch].
  final bool played;

  /// Итоги сыгранных раундов по порядку.
  final List<RoundScore> rounds;

  /// Сколько особых карт игрок сыграл из руки (рог, погода, чучело, казнь, мардрём, шторм); способность лидера
  /// и отряды с рогом или казнью не в счёт.
  final int specialsPlayed;

  /// Выполнено ли условие [condition]. У проигранной партии условие не выполнено.
  bool meets(BonusCondition condition) {
    if (!won || !played) return false;
    return switch (condition) {
      // «2:0»: два раунда, оба выиграны, без проигранных и ничейных.
      BonusCondition.winTwoZero => rounds.length == 2 && rounds.every((round) => round.won),
      BonusCondition.noSpecials => specialsPlayed == 0,
      BonusCondition.margin20 => rounds.any((round) => round.won && round.margin >= 20),
    };
  }
}
