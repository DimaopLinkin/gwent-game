import 'package:gwent_engine/src/cards/card_definition.dart';
import 'package:gwent_engine/src/cards/leader_ability.dart';
import 'package:gwent_engine/src/cards/special_ability.dart';
import 'package:gwent_engine/src/cards/unit_ability.dart';
import 'package:gwent_engine/src/engine/internal/enter_abilities.dart';
import 'package:gwent_engine/src/engine/internal/field_rules.dart';
import 'package:gwent_engine/src/engine/internal/match_context.dart';
import 'package:gwent_engine/src/engine/internal/turn_flow.dart';
import 'package:gwent_engine/src/engine/internal/weather_rules.dart';
import 'package:gwent_engine/src/engine/reject.dart';
import 'package:gwent_engine/src/event/game_event.dart';
import 'package:gwent_engine/src/state/card_instance.dart';
import 'package:gwent_engine/src/state/choice.dart';
import 'package:gwent_engine/src/state/effect.dart';
import 'package:gwent_engine/src/state/entry_source.dart';
import 'package:gwent_engine/src/state/match_phase.dart';
import 'package:gwent_engine/src/state/seat.dart';

/// Выполняет стек эффектов, пока он не опустеет или не понадобится выбор игрока.
final class EffectResolver {
  const EffectResolver(this._ctx, this._field, this._enter, this._weather, this._turns, this._onFirstPlayerChosen);

  final MatchContext _ctx;
  final FieldRules _field;
  final EnterAbilities _enter;
  final WeatherRules _weather;
  final TurnFlow _turns;

  /// Продолжение подготовки партии после выбора Скоя'таэлей.
  final void Function(Seat first) _onFirstPlayerChosen;

  /// Выполняет эффекты по порядку. Останавливается на первом эффекте, которому нужен выбор.
  void run() {
    final draft = _ctx.draft;
    while (draft.effects.isNotEmpty && draft.phase != MatchPhase.finished) {
      final effect = draft.effects.last;
      final request = _request(effect);
      if (request != null) {
        draft.choice = request;
        _ctx.emit(ChoiceRequested(request.seat, request.kind, request.options));
        return;
      }
      draft.effects.removeLast();
      _execute(effect, null);
    }
  }

  /// Ответ игрока на выбор, которого ждёт партия.
  Reject? choose(Seat seat, ChoiceOption option) {
    final choice = _ctx.draft.choice;
    if (choice == null) return const Reject(RejectReason.invalidOption);
    if (choice.seat != seat) return const Reject(RejectReason.notYourChoice);
    if (!choice.options.contains(option)) return const Reject(RejectReason.invalidOption);
    _ctx.draft.choice = null;
    _execute(_ctx.draft.effects.removeLast(), option);
    return null;
  }

  /// Выбор, который нужен эффекту; `null`, если эффект выполняется сам.
  PendingChoice? _request(Effect effect) {
    PendingChoice? cards(Seat seat, ChoiceKind kind, Iterable<CardInstance> options) => options.isEmpty
        ? null
        : PendingChoice(seat: seat, kind: kind, options: List.unmodifiable(options.map(CardOption.new)));

    return switch (effect) {
      ChooseFirstPlayerEffect(:final chooser) => PendingChoice(
        seat: chooser,
        kind: ChoiceKind.firstPlayer,
        options: const [SeatOption(Seat.one), SeatOption(Seat.two)],
      ),
      EnterFieldEffect(:final player, :final card, row: null) => PendingChoice(
        seat: player,
        kind: ChoiceKind.unitRow,
        options: List.unmodifiable(_ctx.unit(card)!.placement.rows.map(RowOption.new)),
        subject: card,
      ),
      EnterFieldEffect() => null,
      MedicEffect(:final player) => _randomMedic ? null : cards(player, ChoiceKind.medicTarget, _medicTargets(player)),
      TakeFromDiscardEffect(:final player, :final from) => cards(
        player,
        from == player ? ChoiceKind.ownDiscardCard : ChoiceKind.opponentDiscardCard,
        _ctx.player(from).discard.where(_ctx.isNormalUnit),
      ),
      DiscardFromHandEffect(:final player) => cards(player, ChoiceKind.handCardToDiscard, _ctx.player(player).hand),
      TakeFromDeckEffect(:final player) => cards(player, ChoiceKind.deckCard, _sortedDeck(player)),
      PickWeatherFromDeckEffect(:final player) => cards(
        player,
        ChoiceKind.deckWeather,
        _sortedDeck(player).where(_isWeather),
      ),
      EndTurnEffect() || BeginTurnsEffect() => null,
    };
  }

  void _execute(Effect effect, ChoiceOption? option) {
    switch (effect) {
      case ChooseFirstPlayerEffect():
        final first = (option! as SeatOption).seat;
        _ctx.emit(FirstPlayerChosen(first, byChoice: true));
        _onFirstPlayerChosen(first);

      case EnterFieldEffect(:final player, :final card, :final source):
        final row = effect.row ?? (option! as RowOption).row;
        final spy = _ctx.unit(card)!.ability is SpyAbility && source != EntrySource.perk;
        _field.placeUnit(spy ? player.opponent : player, row, card, source);
        if (source != EntrySource.perk) _enter.trigger(player, card, source);

      case MedicEffect(:final player):
        final targets = _medicTargets(player);
        final CardInstance? chosen = switch (option) {
          CardOption(:final card) => targets.firstWhere((target) => target == card),
          RowOption() || SeatOption() || null => targets.isEmpty ? null : targets[_ctx.random(targets.length)],
        };
        if (chosen == null) return;
        _ctx.player(player).discard.remove(chosen);
        _ctx.draft.effects.add(
          EnterFieldEffect(player, chosen, EntrySource.medic, row: _ctx.unit(chosen)!.placement.row),
        );

      case TakeFromDiscardEffect(:final player, :final from):
        final card = _take(_ctx.player(from).discard, option);
        if (card == null) return;
        _ctx.player(player).hand.add(card);
        _ctx.emit(CardTakenFromDiscard(player, from, card));

      case DiscardFromHandEffect(:final player, :final remaining):
        final card = _take(_ctx.player(player).hand, option);
        if (card == null) return;
        _ctx.discard(player, card);
        if (remaining > 1) _ctx.draft.effects.add(DiscardFromHandEffect(player, remaining - 1));

      case TakeFromDeckEffect(:final player, :final remaining):
        final card = _take(_ctx.player(player).deck, option);
        if (card == null) return;
        _ctx.player(player).hand.add(card);
        _ctx.emit(CardsDrawn(player, List.unmodifiable([card])));
        if (remaining > 1) _ctx.draft.effects.add(TakeFromDeckEffect(player, remaining - 1));

      case PickWeatherFromDeckEffect(:final player):
        final card = _take(_ctx.player(player).deck, option);
        if (card != null) _weather.play(player, card);

      case EndTurnEffect(:final player):
        _turns.advanceTurn(player);

      case BeginTurnsEffect():
        _turns.beginRoundTurns();
    }
  }

  /// Убирает из зоны карту, выбранную игроком; `null`, если выбирать было не из чего.
  static CardInstance? _take(List<CardInstance> zone, ChoiceOption? option) {
    if (option is! CardOption) return null;
    return zone.removeAt(zone.indexWhere((card) => card == option.card));
  }

  /// Медик выбирает случайно, если действует «Завоеватель Севера» (раздел 10).
  bool get _randomMedic => _ctx.anyLeader((ability) => ability is RandomMedicAbility);

  List<CardInstance> _medicTargets(Seat seat) => _ctx.player(seat).discard.where(_ctx.isNormalUnit).toList();

  bool _isWeather(CardInstance card) => switch (_ctx.definition(card)) {
    SpecialCardDefinition(ability: WeatherAbility() || ClearWeatherAbility()) => true,
    _ => false,
  };

  /// Карты колоды для выбора: порядок не выдаёт порядок колоды.
  List<CardInstance> _sortedDeck(Seat seat) =>
      [..._ctx.player(seat).deck]..sort((a, b) => a.id.value.compareTo(b.id.value));
}
