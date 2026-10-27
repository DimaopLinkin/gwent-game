import 'package:gwent/src/features/match/presentation/hand_order.dart';
import 'package:gwent_engine/gwent_engine.dart';

/// Порядок карт в рядах поля на экране: тот же, что в руке (`HandOrder`), слева слабые, правее сильные, при равной
/// базовой силе по имени, поэтому копии одной карты (узы, сбор) стоят рядом.
///
/// Это порядок показа: движок и проекция `PlayerView` его не знают, в сеть и в реплей он не попадает. Сортируют по
/// базовой силе, а не по текущей: погода, рог и узы меняют цифры на картах, но не переставляют их. Карта, пришедшая
/// на ряд, встаёт на своё место, а остальные сдвигаются.
///
/// Чучело в ряду стоит на месте забранной карты: для сортировки оно выдаёт себя за неё ([replaced]). Движок забранную
/// карту не помнит, её запоминает экран по событию `UnitDecoyed`. Если Чучело не знакомо (экран открыт посреди
/// партии), оно стоит слева, как особая карта в руке.
final class RowOrder {
  /// Создаёт порядок рядов по порядку карт [order]; [replaced] — карта, которую заменило Чучело (по номеру Чучела).
  const RowOrder(this.order, {this.replaced = const {}});

  /// Порядок карт: общий с рукой.
  final HandOrder order;

  /// Карты, которые заменили Чучела на столе: по номеру Чучела.
  final Map<CardInstanceId, CardInstance> replaced;

  /// Проекция [view] с картами рядов обеих сторон в порядке показа; сама [view], если порядок уже верный.
  PlayerView apply(PlayerView view) {
    final me = _side(view.me);
    final opponent = _side(view.opponent);
    if (identical(me, view.me) && identical(opponent, view.opponent)) return view;
    return PlayerView(
      viewer: view.viewer,
      phase: view.phase,
      round: view.round,
      roundStarter: view.roundStarter,
      turn: view.turn,
      me: me,
      opponent: opponent,
      weather: view.weather,
      choice: view.choice,
      opponentChoosing: view.opponentChoosing,
      history: view.history,
      outcome: view.outcome,
    );
  }

  SideView _side(SideView side) {
    var changed = false;
    final rows = <Row, RowView>{};
    for (final MapEntry(key: row, value: view) in side.rows.entries) {
      final cards = order.sortBy(view.cards, (field) => replaced[field.card.id] ?? field.card);
      final sorted = _sameOrder(cards, view.cards);
      changed = changed || !sorted;
      rows[row] = sorted
          ? view
          : RowView(cards: cards, slot: view.slot, weather: view.weather, strength: view.strength);
    }
    if (!changed) return side;
    return SideView(
      seat: side.seat,
      leader: side.leader,
      faction: side.faction,
      leaderAvailable: side.leaderAvailable,
      leaderUsed: side.leaderUsed,
      leaderDisabled: side.leaderDisabled,
      crystals: side.crystals,
      passed: side.passed,
      handCount: side.handCount,
      deckCount: side.deckCount,
      discard: side.discard,
      rows: rows,
      score: side.score,
      redrawDone: side.redrawDone,
      hand: side.hand,
      redrawsLeft: side.redrawsLeft,
      playable: side.playable,
    );
  }

  bool _sameOrder(List<FieldCardView> sorted, List<FieldCardView> original) {
    for (var i = 0; i < sorted.length; i++) {
      if (!identical(sorted[i], original[i])) return false;
    }
    return true;
  }
}
