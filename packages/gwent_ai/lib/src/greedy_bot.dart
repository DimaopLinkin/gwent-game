import 'dart:math' show max;

import 'package:gwent_ai/src/bot_difficulty.dart';
import 'package:gwent_ai/src/card_values.dart';
import 'package:gwent_ai/src/greedy_bot_settings.dart';
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
  /// Создаёт бота. [seed] нужен только ошибкам лёгкого уровня (`GreedyBotSettings.mistakeChance`): с одним сидом
  /// и одинаковыми партиями бот ошибается одинаково.
  GreedyBot(this._engine, CardCatalog catalog, {GreedyBotSettings settings = const GreedyBotSettings(), int seed = 0})
    : _catalog = catalog,
      _settings = settings,
      _values = CardValues(catalog, settings),
      _rng = SeededRng(seed);

  /// Бот уровня [difficulty] с настройками этого уровня.
  GreedyBot.forDifficulty(MatchEngine engine, CardCatalog catalog, BotDifficulty difficulty, {int seed = 0})
    : this(engine, catalog, settings: GreedyBotSettings.forDifficulty(difficulty), seed: seed);

  final MatchEngine _engine;
  final CardCatalog _catalog;
  final GreedyBotSettings _settings;
  final CardValues _values;

  /// Источник случайности для ошибок; движется только у бота с `mistakeChance` больше нуля.
  Rng _rng;

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
    final intent = _policy(view, moves);
    return _firstAccepted(state, seat, [_mistake(intent, moves) ?? intent, const Pass()]);
  }

  /// Случайная карта вместо задуманного розыгрыша: бросок на ошибку лёгкого уровня. Пас и ответ спасовавшему
  /// сопернику ошибкой не портятся: `null`, когда ход остаётся задуманным.
  Intent? _mistake(Intent intent, List<_Move> moves) {
    if (_settings.mistakeChance == 0 || intent is Pass || moves.isEmpty) return null;
    final (roll, afterRoll) = _rng.nextInt(100);
    _rng = afterRoll;
    if (roll >= _settings.mistakeChance) return null;
    final (index, afterPick) = _rng.nextInt(moves.length);
    _rng = afterPick;
    return moves[index].intent;
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
      // Одной картой не догнать. На двух кристаллах раунд стоит догонять, только если хватит нескольких карт,
      // иначе бот отдаёт его и сохраняет руку. Догоняют очками: карты, оставшиеся в руке, этот раунд не выигрывают.
      final needed = _cardsToCatchUp(me, -lead);
      if (needed == null) return me.crystals == 1 ? best.intent : pass;
      if (me.crystals > 1 && needed > _settings.catchUpCards) return pass;
      var strongest = best;
      for (final move in moves) {
        if (move.lead > strongest.lead || move.lead == strongest.lead && move.gain > strongest.gain) strongest = move;
      }
      return strongest.intent;
    }

    // Соперник не может ответить: ему остаётся автопас, лишние карты не нужны.
    if (ahead && opponent.handCount == 0 && !opponent.leaderAvailable) return pass;
    if (me.crystals == 1) {
      // Проигрыш раунда проигрывает партию: пас с отрывом только тогда, когда любой ход его уменьшает.
      return ahead && best.gain <= 0 ? pass : _frugal(moves, best).intent;
    }
    if (ahead && lead >= _settings.passLead) return pass;
    if (!ahead && -lead >= _settings.giveUpDeficit) return pass;
    return best.gain > 0 ? _frugal(moves, best).intent : pass;
  }

  /// Ход, который бот играет вместо лучшего [best]: самый дешёвый из не хуже лучшего больше чем на допуск экономии.
  _Move _frugal(List<_Move> moves, _Move best) {
    final slack = _settings.frugalSlack + max(best.gain, 0) * _settings.frugalShare / 100;
    if (slack == 0 || best.gain <= 0) return best;
    var pick = best;
    for (final move in moves) {
      // Ход, который ничего не прибавляет (Рог на пустой ряд) или вредит (погода себе, казнь своей карты), не экономия.
      if (move.gain <= 0 || move.gain < best.gain - slack) continue;
      final cheaper = _settings.wasteful ? move.spent > pick.spent : move.spent < pick.spent;
      if (cheaper || move.spent == pick.spent && move.gain > pick.gain) pick = move;
    }
    return pick;
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
    return (intent: intent, gain: gain.toDouble(), lead: leadAfter, winsRound: winsRound, spent: spent);
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

  /// Сколько карт руки нужно, чтобы обогнать соперника при отставании [deficit], если класть сильнейшие;
  /// `null`, если всей руки не хватит.
  int? _cardsToCatchUp(SideView me, int deficit) {
    final points = [for (final card in me.hand ?? const <CardInstance>[]) _values.points(card.cardId)]
      ..sort((a, b) => b.compareTo(a));
    var sum = 0;
    for (var count = 0; count < points.length; count++) {
      sum += points[count];
      if (sum > deficit) return count + 1;
    }
    return null;
  }

  /// Первое намерение, которое движок принимает.
  Intent _firstAccepted(MatchState state, Seat seat, List<Intent> intents) {
    for (final intent in intents) {
      if (_engine.apply(state, seat, intent) is Accepted) return intent;
    }
    throw StateError('Движок отклонил все намерения бота: $intents');
  }
}

/// Пробный ход: прирост оценки [gain], разница очков после хода [lead], выигрывает ли он раунд и оценка
/// потраченного [spent].
typedef _Move = ({Intent intent, double gain, int lead, bool winsRound, int spent});

/// Вариант выбора с состоянием после него и оценкой.
typedef _Option = ({ChoiceOption option, MatchState state, double score});
