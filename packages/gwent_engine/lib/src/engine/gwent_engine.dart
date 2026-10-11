import 'package:gwent_engine/src/cards/card_catalog.dart';
import 'package:gwent_engine/src/cards/deck.dart';
import 'package:gwent_engine/src/engine/engine_result.dart';
import 'package:gwent_engine/src/engine/internal/agile_optimizer.dart';
import 'package:gwent_engine/src/engine/internal/board_score.dart';
import 'package:gwent_engine/src/engine/internal/card_play.dart';
import 'package:gwent_engine/src/engine/internal/draft.dart';
import 'package:gwent_engine/src/engine/internal/effect_resolver.dart';
import 'package:gwent_engine/src/engine/internal/enter_abilities.dart';
import 'package:gwent_engine/src/engine/internal/faction_perks.dart';
import 'package:gwent_engine/src/engine/internal/field_rules.dart';
import 'package:gwent_engine/src/engine/internal/leader_actions.dart';
import 'package:gwent_engine/src/engine/internal/legality.dart';
import 'package:gwent_engine/src/engine/internal/match_context.dart';
import 'package:gwent_engine/src/engine/internal/match_setup_rules.dart';
import 'package:gwent_engine/src/engine/internal/projector.dart';
import 'package:gwent_engine/src/engine/internal/round_transition.dart';
import 'package:gwent_engine/src/engine/internal/scorch_rules.dart';
import 'package:gwent_engine/src/engine/internal/turn_flow.dart';
import 'package:gwent_engine/src/engine/internal/weather_rules.dart';
import 'package:gwent_engine/src/engine/match_engine.dart';
import 'package:gwent_engine/src/engine/match_setup.dart';
import 'package:gwent_engine/src/engine/reject.dart';
import 'package:gwent_engine/src/event/event_visibility.dart' as visibility;
import 'package:gwent_engine/src/event/game_event.dart';
import 'package:gwent_engine/src/intent/intent.dart';
import 'package:gwent_engine/src/rules/deck_validator.dart';
import 'package:gwent_engine/src/rules/deck_violation.dart';
import 'package:gwent_engine/src/rules/game_rules.dart';
import 'package:gwent_engine/src/state/match_phase.dart';
import 'package:gwent_engine/src/state/match_state.dart';
import 'package:gwent_engine/src/state/seat.dart';
import 'package:gwent_engine/src/view/player_view.dart';

/// Движок Гвинта из «Ведьмака 3» по правилам `docs/hand/main.md`.
final class GwentEngine implements MatchEngine {
  const GwentEngine(this._catalog, {GameRules rules = const GameRules()}) : _rules = rules;

  final CardCatalog _catalog;
  final GameRules _rules;

  @override
  EngineResult start(MatchSetup setup) {
    for (final seat in Seat.values) {
      final violations = validateDeck(setup.deck(seat));
      if (violations.isNotEmpty) {
        return Rejected(Reject(RejectReason.invalidDeck, seat: seat, deckViolations: List.unmodifiable(violations)));
      }
    }
    final draft = Draft(
      players: {
        for (final seat in Seat.values)
          seat: DraftPlayer(
            leader: setup.deck(seat).leader,
            faction: _catalog.leader(setup.deck(seat).leader)!.faction,
            crystals: _rules.crystals,
          ),
      },
      rng: setup.rng,
    );
    final rules = _Rules(MatchContext(draft, _catalog, _rules));
    rules.setup.start(setup.deck);
    rules.resolver.run();
    return Accepted(draft.freeze(), List.unmodifiable(rules.ctx.events));
  }

  @override
  EngineResult apply(MatchState state, Seat seat, Intent intent) {
    if (state.phase == MatchPhase.finished) return const Rejected(Reject(RejectReason.matchFinished));
    final rules = _Rules(MatchContext(Draft.from(state), _catalog, _rules));
    final reject = rules.handle(seat, intent);
    if (reject != null) return Rejected(reject);
    rules.resolver.run();
    return Accepted(rules.ctx.draft.freeze(), List.unmodifiable(rules.ctx.events));
  }

  @override
  PlayerView project(MatchState state, Seat seat) =>
      _Rules(MatchContext(Draft.from(state), _catalog, _rules)).projector.project(seat);

  @override
  List<GameEvent> eventsFor(List<GameEvent> events, Seat seat) => visibility.eventsFor(events, seat);

  @override
  List<DeckViolation> validateDeck(Deck deck) => DeckValidator(_catalog, _rules).validate(deck);
}

/// Части движка, связанные одним контекстом на время одного вызова.
final class _Rules {
  factory _Rules(MatchContext ctx) {
    final field = FieldRules(ctx);
    final score = BoardScore(ctx);
    final weather = WeatherRules(ctx);
    final scorch = ScorchRules(ctx, score, field);
    final legality = Legality(ctx, field);
    final rounds = RoundTransition(ctx, field, score, weather, FactionPerks(ctx));
    final turns = TurnFlow(ctx, rounds, legality);
    final setup = MatchSetupRules(ctx, turns);
    return _Rules._(
      ctx: ctx,
      field: field,
      legality: legality,
      turns: turns,
      setup: setup,
      resolver: EffectResolver(ctx, field, EnterAbilities(ctx, scorch), weather, turns, setup.dealAndRedraw),
      cards: CardPlay(ctx, field, weather, scorch),
      leaders: LeaderActions(ctx, field, weather, scorch, legality, AgileOptimizer(ctx, field, score)),
      projector: Projector(ctx, score, legality),
    );
  }

  _Rules._({
    required this.ctx,
    required this.field,
    required this.legality,
    required this.turns,
    required this.setup,
    required this.resolver,
    required this.cards,
    required this.leaders,
    required this.projector,
  });

  final MatchContext ctx;
  final FieldRules field;
  final Legality legality;
  final TurnFlow turns;
  final MatchSetupRules setup;
  final EffectResolver resolver;
  final CardPlay cards;
  final LeaderActions leaders;
  final Projector projector;

  Reject? handle(Seat seat, Intent intent) {
    final draft = ctx.draft;
    if (intent is Resign) {
      turns.resign(seat);
      return null;
    }
    if (intent is ChooseOption) return resolver.choose(seat, intent.option);
    if (draft.choice != null) return const Reject(RejectReason.choicePending);
    return switch (intent) {
      RedrawCard(:final card) => setup.redraw(seat, card),
      FinishRedraw() => setup.finishRedraw(seat),
      PlayCard() || UseLeader() || Pass() => _turnAction(seat, intent),
      ChooseOption() || Resign() => throw StateError('Обработано выше'),
    };
  }

  /// Ход: карта, лидер или пас (раздел 4).
  Reject? _turnAction(Seat seat, Intent intent) {
    final draft = ctx.draft;
    if (draft.phase != MatchPhase.playing) return const Reject(RejectReason.wrongPhase);
    if (ctx.player(seat).passed) return const Reject(RejectReason.alreadyPassed);
    if (draft.turn != seat) return const Reject(RejectReason.notYourTurn);
    return switch (intent) {
      PlayCard() => cards.play(seat, intent),
      UseLeader() => leaders.use(seat),
      Pass() => _pass(seat),
      RedrawCard() || FinishRedraw() || ChooseOption() || Resign() => throw StateError('Не действие хода'),
    };
  }

  Reject? _pass(Seat seat) {
    turns.pass(seat, auto: false);
    return null;
  }
}
