import 'package:gwent_ai/src/greedy_bot_settings.dart';
import 'package:gwent_ai/src/internal/card_values.dart';
import 'package:gwent_ai/src/internal/turn_candidates.dart';
import 'package:gwent_ai/src/match_bot.dart';
import 'package:gwent_engine/gwent_engine.dart';

/// Жадный бот: пробует движком все намерения и берёт то, что лучше всего сразу после хода.
///
/// Ход оценивается по проекции бота после него и после цепочки выборов, которую он запускает (Медик, ряд проворной
/// карты, выбор лидера): прирост разницы очков плюс карты, которые ход добавил руке. Когда пасовать, решают простые
/// правила по счёту, кристаллам и числу карт.
///
/// Скрытые зоны бот не читает: он смотрит только на свою проекцию, а из пробного хода берёт очки, число карт
/// и варианты выбора, но не то, какие именно карты пришли в руку. Пробный ход видит и случайный исход самого хода
/// (например, отряд, которого выбрал случайный Медик): такое знание бот получает до хода, а не после.
final class GreedyBot implements MatchBot {
  GreedyBot(this._engine, CardCatalog catalog, {GreedyBotSettings settings = const GreedyBotSettings()})
    : _catalog = catalog,
      _settings = settings,
      _values = CardValues(catalog, settings);

  final MatchEngine _engine;
  final CardCatalog _catalog;
  final GreedyBotSettings _settings;
  final CardValues _values;

  /// Предел цепочки выборов после одного хода: защита от зацикливания.
  static const int _chainLimit = 16;

  /// Оценка выигранной партии: больше любой разницы очков и карт.
  static const double _matchWeight = 1e6;

  @override
  Intent? decide(MatchState state, Seat seat) {
    final view = _engine.project(state, seat);
    if (view.choice case final choice?) {
      final best = _bestOption(state, seat, choice, deep: true);
      if (best == null) throw StateError('Движок отклонил все варианты выбора ${choice.kind}');
      return ChooseOption(best.option);
    }
    if (view.opponentChoosing != null) return null;
    return switch (view.phase) {
      MatchPhase.redraw => view.me.redrawDone ? null : _redraw(state, seat, view),
      MatchPhase.playing => view.turn == seat ? _turn(state, seat, view) : null,
      MatchPhase.choosingFirstPlayer || MatchPhase.finished => null,
    };
  }

  /// Пересдача: меняет самую слабую карту, пока она дешевле порога и замены не кончились.
  Intent _redraw(MatchState state, Seat seat, PlayerView view) {
    CardInstance? worst;
    for (final card in view.me.hand ?? const <CardInstance>[]) {
      if (worst == null || _values.worth(card.cardId) < _values.worth(worst.cardId)) worst = card;
    }
    return _firstAccepted(state, seat, [
      if (worst != null && (view.me.redrawsLeft ?? 0) > 0 && _values.worth(worst.cardId) < _settings.redrawBelow)
        RedrawCard(worst.id),
      const FinishRedraw(),
    ]);
  }

  /// Ход: оценивает все принятые движком намерения и выбирает между лучшим из них и пасом.
  Intent _turn(MatchState state, Seat seat, PlayerView view) {
    final moves = [
      for (final intent in turnCandidates(view, _catalog))
        if (_engine.apply(state, seat, intent) case Accepted(state: final next))
          _move(intent, view, _engine.project(_settle(next, seat), seat)),
    ];
    return _firstAccepted(state, seat, [_policy(view, moves), const Pass()]);
  }

  /// Правила паса поверх жадного выбора хода.
  Intent _policy(PlayerView view, List<_Move> moves) {
    const pass = Pass();
    final me = view.me;
    final opponent = view.opponent;
    final lead = me.score - opponent.score;
    final ahead = _ahead(lead, view);
    _Move? best;
    for (final move in moves) {
      if (best == null || move.gain > best.gain) best = move;
    }
    if (best == null) return pass;

    if (opponent.passed) {
      if (ahead) return pass;
      // Соперник больше не ходит: хватит самой дешёвой карты, которая выводит вперёд.
      _Move? cheapest;
      for (final move in moves.where((move) => move.winsRound)) {
        if (cheapest == null ||
            move.spent < cheapest.spent ||
            move.spent == cheapest.spent && move.gain > cheapest.gain) {
          cheapest = move;
        }
      }
      if (cheapest != null) return cheapest.intent;
      final reachable = _handPoints(me) > -lead && best.gain > 0;
      return me.crystals == 1 || reachable ? best.intent : pass;
    }

    if (me.crystals == 1) {
      // Проигрыш раунда проигрывает партию: пас только с отрывом, на который соперник не ответит или ответит хуже.
      final unanswerable = opponent.handCount == 0 && !opponent.leaderAvailable;
      return ahead && (unanswerable || best.gain <= 0) ? pass : best.intent;
    }
    if (ahead && lead >= _settings.passLead) return pass;
    if (!ahead && -lead >= _settings.giveUpDeficit) return pass;
    return best.gain > 0 ? best.intent : pass;
  }

  /// Итог пробного хода: прирост оценки, выигран ли раунд и сколько стоит потраченное.
  _Move _move(Intent intent, PlayerView before, PlayerView after) {
    final seat = before.viewer;
    final finishedRound = after.history.length > before.history.length ? after.history[before.history.length] : null;
    final leadAfter = switch (finishedRound) {
      RoundResult(:final scores) => scores[seat]! - scores[seat.opponent]!,
      null => after.me.score - after.opponent.score,
    };
    final winsRound = switch (finishedRound) {
      RoundResult(:final winner) => winner == seat,
      null => _ahead(leadAfter, after),
    };
    final weight = _settings.cardWeight;
    final gain = after.outcome != null
        ? _material(after)
        : (leadAfter - (before.me.score - before.opponent.score)) +
              weight * _cardsGained(intent, before, after, roundOver: finishedRound != null) -
              weight * (after.opponent.handCount - before.opponent.handCount) -
              (intent is UseLeader ? _settings.leaderCost : 0);
    final spent = switch (intent) {
      PlayCard(:final card) => _values.worth(before.me.hand!.firstWhere((instance) => instance.id == card).cardId),
      _ => _settings.leaderCost,
    };
    return (intent: intent, gain: gain.toDouble(), winsRound: winsRound, spent: spent);
  }

  /// Сколько карт ход добавил руке сверх розыгрыша одной карты: взятые Шпионом, возвращённые Чучелом и лидером,
  /// минус ушедшие из руки не на поле (сброс лидером). Двойник из руки картой не считается: отряды вышли на поле.
  int _cardsGained(Intent intent, PlayerView before, PlayerView after, {required bool roundOver}) {
    final was = {for (final card in before.me.hand!) card.id};
    final now = {for (final card in after.me.hand!) card.id};
    final arrived = now.difference(was).length;
    if (roundOver) return arrived;
    final onField = {
      for (final row in after.me.rows.values)
        for (final card in row.cards) card.card.id,
    };
    final played = intent is PlayCard ? intent.card : null;
    final lost = was.difference(now).where((id) => id != played && !onField.contains(id)).length;
    return arrived - lost;
  }

  /// Лучший вариант выбора. С [deep] каждый вариант доигрывается до конца цепочки выборов, которую он запускает.
  _Option? _bestOption(MatchState state, Seat seat, PendingChoice choice, {required bool deep}) {
    _Option? best;
    for (final option in choice.options) {
      if (_engine.apply(state, seat, ChooseOption(option)) case Accepted(state: final next)) {
        final settled = deep ? _settle(next, seat) : next;
        final score = _material(_engine.project(settled, seat)) + _tieBreak(choice.kind, option, seat);
        if (best == null || score > best.score) best = (option: option, state: next, score: score);
      }
    }
    return best;
  }

  /// Состояние после того, как бот сделал все свои выборы цепочки, каждый раз беря лучший сразу после выбора.
  MatchState _settle(MatchState state, Seat seat) {
    var current = state;
    for (var step = 0; step < _chainLimit; step++) {
      final choice = _engine.project(current, seat).choice;
      if (choice == null) break;
      final best = _bestOption(current, seat, choice, deep: false);
      if (best == null) break;
      current = best.state;
    }
    return current;
  }

  /// Оценка позиции для сравнения вариантов выбора: разница очков и карт в руках.
  double _material(PlayerView view) {
    if (view.outcome case MatchOutcome(:final winner)) {
      return winner == null ? 0 : (winner == view.viewer ? _matchWeight : -_matchWeight);
    }
    var lead = view.me.score - view.opponent.score;
    // Карта, которой бот ещё выбирает ряд, всё равно выйдет на поле.
    if (view.choice case PendingChoice(kind: ChoiceKind.unitRow, subject: final subject?)) {
      lead += _values.points(subject.cardId);
    }
    return (lead + _settings.cardWeight * (view.me.handCount - view.opponent.handCount)).toDouble();
  }

  /// Поправка между вариантами с равной оценкой, меньше одного очка: брать сильную карту, сбрасывать слабую,
  /// уступать первый ход (второй игрок видит ход соперника перед своим).
  double _tieBreak(ChoiceKind kind, ChoiceOption option, Seat seat) => switch (option) {
    CardOption(:final card) => (kind == ChoiceKind.handCardToDiscard ? -1 : 1) * _values.worth(card.cardId) / 100,
    SeatOption(seat: final first) => first == seat ? 0 : 0.01,
    RowOption() => 0,
  };

  /// Выиграет ли бот раунд, если оба спасуют сейчас. Ничью выигрывает Нильфгаард, если он только у одного игрока.
  bool _ahead(int lead, PlayerView view) =>
      lead > 0 ||
      lead == 0 && view.me.faction.perk == FactionPerk.winTies && view.opponent.faction.perk != FactionPerk.winTies;

  /// Сколько очков рука может добавить своей стороне.
  int _handPoints(SideView me) =>
      (me.hand ?? const <CardInstance>[]).fold(0, (sum, card) => sum + _values.points(card.cardId));

  /// Первое намерение, которое движок принимает.
  Intent _firstAccepted(MatchState state, Seat seat, List<Intent> intents) {
    for (final intent in intents) {
      if (_engine.apply(state, seat, intent) is Accepted) return intent;
    }
    throw StateError('Движок отклонил все намерения бота: $intents');
  }
}

/// Пробный ход: прирост оценки [gain], выигрывает ли он раунд и оценка потраченного [spent].
typedef _Move = ({Intent intent, double gain, bool winsRound, int spent});

/// Вариант выбора с состоянием после него и оценкой.
typedef _Option = ({ChoiceOption option, MatchState state, double score});
