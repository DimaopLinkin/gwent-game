import 'package:gwent_engine/gwent_engine.dart';

/// Поле после последнего хода раунда, но до подсчёта: игрок видит этот ход, а потом начинаются итоги (ADR 0018).
///
/// Таблица отдаёт только поле перед ходом ([closing]) и поле после уборки, поля между ними нет. Его собирают по
/// событиям [moves] (всё, что случилось до [RoundEnded]): разыгранный отряд встаёт в ряд с базовой силой, и разница
/// между суммой рядов и счётом из [result] ложится на ряд последнего вышедшего отряда, так что счёт сторон точный.
/// Сила соседей по ряду (бонусы, погода) при этом не пересчитывается.
///
/// Возвращает `null`, если ход не сводится к отрядам, вышедшим из руки (особая карта, лидер, выбор, Двойник, Медик):
/// тогда остаётся показ из [closing].
PlayerView? boardAfterLastMove({
  required PlayerView closing,
  required List<GameEvent> moves,
  required RoundResult result,
  required CardCatalog catalog,
}) {
  bool isUnit(CardInstance card) => catalog.card(card.cardId) is UnitCardDefinition;
  final plays = moves.whereType<CardPlayed>().toList();
  final shown = moves.every(
    (event) => switch (event) {
      CardPlayed(:final card) => isUnit(card),
      UnitPlaced(:final source) => source == EntrySource.hand,
      CardsDrawn() || CardsDrawnHidden() || Passed() || TurnStarted() => true,
      _ => false,
    },
  );
  if (plays.isEmpty || !shown) return null;
  // Ходы относятся ровно к одному обновлению после [closing]: карта, уже лежащая на поле, значит, события повторяются.
  final onField = {
    for (final side in [closing.me, closing.opponent])
      for (final row in side.rows.values)
        for (final view in row.cards) view.card.id,
  };
  if (moves.any((event) => event is UnitPlaced && onField.contains(event.card.id))) return null;

  SideView sideOf(Seat seat) => seat == closing.viewer ? closing.me : closing.opponent;
  final sides = {for (final seat in Seat.values) seat: _Draft(sideOf(seat))};
  for (final event in moves) {
    switch (event) {
      case CardPlayed(:final seat, :final card):
        sides[seat]!.played(card);
      case UnitPlaced(:final side, :final row, :final card):
        final definition = catalog.card(card.cardId);
        if (definition is UnitCardDefinition) sides[side]!.placed(row, card, definition.strength);
      case CardsDrawn(:final seat, :final cards):
        sides[seat]!.drawn(cards);
      case CardsDrawnHidden(:final seat, :final count):
        sides[seat]!.drawnHidden(count);
      case Passed(:final seat):
        sides[seat]!.passed = true;
      default:
        break;
    }
  }
  return PlayerView(
    viewer: closing.viewer,
    phase: closing.phase,
    round: closing.round,
    roundStarter: closing.roundStarter,
    me: sides[closing.viewer]!.freeze(result.scores[closing.viewer] ?? 0),
    opponent: sides[closing.viewer.opponent]!.freeze(result.scores[closing.viewer.opponent] ?? 0),
    weather: closing.weather,
    history: closing.history,
  );
}

/// Сторона, пока по ней применяются события хода.
final class _Draft {
  _Draft(this.side)
    : rows = {...side.rows},
      hand = side.hand == null ? null : [...side.hand!],
      handCount = side.handCount,
      deckCount = side.deckCount,
      passed = side.passed;

  final SideView side;
  final Map<Row, RowView> rows;
  final List<CardInstance>? hand;
  int handCount;
  int deckCount;
  bool passed;
  Row? lastRow;

  void played(CardInstance card) {
    hand?.removeWhere((candidate) => candidate.id == card.id);
    handCount--;
  }

  void placed(Row row, CardInstance card, int strength) {
    final before = rows[row] ?? const RowView(cards: [], slot: null, weather: false, strength: 0);
    rows[row] = RowView(
      cards: [
        ...before.cards,
        FieldCardView(card: card, strength: strength),
      ],
      slot: before.slot,
      weather: before.weather,
      strength: before.strength + strength,
    );
    lastRow = row;
  }

  void drawn(List<CardInstance> cards) {
    hand?.addAll(cards);
    handCount += cards.length;
    deckCount -= cards.length;
  }

  void drawnHidden(int count) {
    handCount += count;
    deckCount -= count;
  }

  /// Сторона с счётом [score]: разница с суммой рядов уходит на ряд последнего вышедшего отряда.
  SideView freeze(int score) {
    final adjusted = {...rows};
    final row = lastRow;
    if (row != null) {
      final total = adjusted.values.fold<int>(0, (sum, view) => sum + view.strength);
      final view = adjusted[row]!;
      adjusted[row] = RowView(
        cards: view.cards,
        slot: view.slot,
        weather: view.weather,
        strength: view.strength + score - total,
      );
    }
    return SideView(
      seat: side.seat,
      leader: side.leader,
      faction: side.faction,
      leaderAvailable: side.leaderAvailable,
      leaderUsed: side.leaderUsed,
      leaderDisabled: side.leaderDisabled,
      crystals: side.crystals,
      passed: passed,
      hand: hand,
      handCount: handCount,
      deckCount: deckCount,
      discard: side.discard,
      rows: adjusted,
      score: score,
      redrawDone: side.redrawDone,
      redrawsLeft: side.redrawsLeft,
    );
  }
}
