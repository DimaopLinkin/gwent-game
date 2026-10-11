import 'package:gwent_engine/src/cards/deck.dart';
import 'package:gwent_engine/src/cards/faction.dart';
import 'package:gwent_engine/src/cards/ids.dart';
import 'package:gwent_engine/src/cards/leader_ability.dart';
import 'package:gwent_engine/src/engine/internal/match_context.dart';
import 'package:gwent_engine/src/engine/internal/turn_flow.dart';
import 'package:gwent_engine/src/engine/reject.dart';
import 'package:gwent_engine/src/event/game_event.dart';
import 'package:gwent_engine/src/state/card_instance.dart';
import 'package:gwent_engine/src/state/effect.dart';
import 'package:gwent_engine/src/state/match_phase.dart';
import 'package:gwent_engine/src/state/seat.dart';

/// Подготовка партии и пересдача (раздел 3 правил).
final class MatchSetupRules {
  const MatchSetupRules(this._ctx, this._turns);

  final MatchContext _ctx;
  final TurnFlow _turns;

  /// Шаги 1–3: перемешивание колод, Белое Пламя, выбор первого хода. Колоды уже проверены.
  void start(Map<Seat, Deck> decks) {
    for (final seat in Seat.values) {
      final cards = [...decks[seat]!.cards];
      _ctx.shuffle(cards);
      // Номера экземпляров идут по перемешанной колоде: по номеру нельзя узнать карту соперника.
      _ctx.player(seat).deck.addAll(cards.map((id) => CardInstance(CardInstanceId(_ctx.draft.nextInstanceId++), id)));
      _ctx.emit(DeckShuffled(seat));
    }
    for (final seat in Seat.values) {
      final opponentLeader = _ctx.catalog.leader(_ctx.player(seat.opponent).leader)!;
      _ctx.player(seat).leaderDisabled = opponentLeader.ability is DisableOpponentLeaderAbility;
    }

    final choosers = [
      for (final seat in Seat.values)
        if (_ctx.player(seat).faction.perk == FactionPerk.chooseFirstPlayer) seat,
    ];
    if (choosers.length == 1) {
      _ctx.draft.phase = MatchPhase.choosingFirstPlayer;
      _ctx.draft.effects.add(ChooseFirstPlayerEffect(choosers.single));
    } else {
      final first = Seat.values[_ctx.random(Seat.values.length)];
      _ctx.emit(FirstPlayerChosen(first, byChoice: false));
      dealAndRedraw(first);
    }
  }

  /// Шаги 4–5: раздача и начало пересдачи.
  void dealAndRedraw(Seat first) {
    _ctx.draft
      ..roundStarter = first
      ..phase = MatchPhase.redraw;
    for (final seat in Seat.values) {
      final extra = switch (_ctx.leaderAbility(seat)) {
        ExtraStartingCardsAbility(:final count) => count,
        _ => 0,
      };
      _ctx.draw(seat, _ctx.rules.startingHand + extra);
      _ctx.player(seat).redrawsLeft = _ctx.rules.redrawLimit;
    }
    for (final seat in Seat.values) {
      if (_ctx.rules.redrawLimit == 0) _finish(seat);
    }
  }

  /// Замена карты: она уходит под низ колоды, игрок берёт верхнюю карту.
  Reject? redraw(Seat seat, CardInstanceId id) {
    final reject = _check(seat);
    if (reject != null) return reject;
    final player = _ctx.player(seat);
    final index = player.hand.indexWhere((card) => card.id == id);
    if (index < 0) return const Reject(RejectReason.cardNotInHand);
    final returned = player.hand[index];
    player.deck.add(returned);
    final drawn = player.deck.removeAt(0);
    player.hand[index] = drawn;
    _ctx.emit(CardRedrawn(seat, returned: returned, drawn: drawn));
    if (--player.redrawsLeft == 0) _finish(seat);
    return null;
  }

  /// Игрок закончил пересдачу раньше лимита.
  Reject? finishRedraw(Seat seat) {
    final reject = _check(seat);
    if (reject != null) return reject;
    _finish(seat);
    return null;
  }

  Reject? _check(Seat seat) {
    if (_ctx.draft.phase != MatchPhase.redraw) return const Reject(RejectReason.wrongPhase);
    if (_ctx.player(seat).redrawDone) return const Reject(RejectReason.redrawFinished);
    return null;
  }

  /// Когда оба закончили, колоды перемешиваются (сначала игрок 1) и начинается раунд 1.
  void _finish(Seat seat) {
    _ctx.player(seat).redrawDone = true;
    _ctx.emit(RedrawFinished(seat));
    if (!Seat.values.every((seat) => _ctx.player(seat).redrawDone)) return;
    for (final seat in Seat.values) {
      _ctx.shuffle(_ctx.player(seat).deck);
      _ctx.emit(DeckShuffled(seat));
    }
    _turns.startMatch(_ctx.draft.roundStarter!);
  }
}
