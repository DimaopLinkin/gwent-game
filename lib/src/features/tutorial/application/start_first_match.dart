import 'package:gwent/src/features/content/application/load_game_content.dart';
import 'package:gwent/src/features/content/domain/game_content.dart';
import 'package:gwent/src/features/deck_builder/domain/engine_deck.dart';
import 'package:gwent/src/features/match/domain/local_match_table.dart';
import 'package:gwent/src/features/match/domain/match_pause.dart';
import 'package:gwent/src/features/match/domain/match_session.dart';
import 'package:gwent/src/features/match_history/domain/match_record.dart' show MatchMode;
import 'package:gwent/src/features/tutorial/domain/first_match_script.dart';
import 'package:gwent/src/features/tutorial/domain/scenario_director.dart';
import 'package:gwent/src/features/tutorial/domain/scripted_table.dart';
import 'package:gwent_content/gwent_content.dart' show ValidationIssue;
import 'package:gwent_engine/gwent_engine.dart';
import 'package:meta/meta.dart';

/// Итог попытки начать «Первую партию».
sealed class StartFirstMatchResult {
  const StartFirstMatchResult();
}

/// Партия начата: стол ждёт первого хода игрока, [director] ведёт сценарий.
@immutable
final class FirstMatchStarted extends StartFirstMatchResult {
  /// Создаёт итог.
  const FirstMatchStarted(this.session, this.director);

  /// Партия для экрана партии.
  final MatchSession session;

  /// Режиссёр сценария: на него смотрит слой подсказок.
  final ScenarioDirector director;
}

/// «Первую партию» начать нельзя: пакет контента не прошёл проверку или не подходит сценарию (нет карты или колода
/// не проходит правила).
final class FirstMatchUnavailable extends StartFirstMatchResult {
  /// Создаёт итог; [issues] — проблемы пакета, пусто, если не подошла колода сценария.
  FirstMatchUnavailable([List<ValidationIssue> issues = const []]) : issues = List.unmodifiable(issues);

  /// Проблемы пакета.
  final List<ValidationIssue> issues;
}

/// Сценарий: начать «Первую партию» (ADR 0034).
///
/// Колоды и сид берутся из [FirstMatchScript], а не из хранилища и не от генератора: раздача одна и та же. Пересдачи
/// в обучении нет (лимит замен 0), бот делает ходы сценария. Партия не пишется в историю.
final class StartFirstMatch {
  /// Создаёт сценарий; [botThinkTime] — пауза перед ходом бота.
  StartFirstMatch(this._content, {Duration botThinkTime = const Duration(milliseconds: 700)})
    : _botThinkTime = botThinkTime;

  final LoadGameContent _content;
  final Duration _botThinkTime;

  /// Начинает партию; [playerDeckName] и [opponentDeckName] — названия колод для экрана знакомства.
  Future<StartFirstMatchResult> call({required String playerDeckName, required String opponentDeckName}) async {
    final GameContent content;
    switch (await _content()) {
      case GameContentReady(content: final ready):
        content = ready;
      case GameContentRejected(:final issues):
        return FirstMatchUnavailable(issues);
    }
    final engine = GwentEngine(content.catalog, rules: _withoutRedraw(content.rules));
    final one = FirstMatchScript.playerDeck;
    final two = FirstMatchScript.opponentDeck;
    final started = engine.start(
      MatchSetup(one: one.toEngineDeck(), two: two.toEngineDeck(), rng: const SeededRng(FirstMatchScript.seed)),
    );
    switch (started) {
      case Rejected():
        return FirstMatchUnavailable();
      case Accepted(:final state, :final events):
        final director = ScenarioDirector(FirstMatchScript.beats);
        final pause = MatchPause();
        final table = ScriptedTable(
          LocalMatchTable(
            engine: engine,
            state: state,
            startEvents: events,
            journal: director.journal,
            pause: pause,
            agents: {Seat.two: ScriptedBotAgent(director, thinkTime: _botThinkTime, pause: pause)},
          ),
          director,
        );
        return FirstMatchStarted(
          MatchSession(
            mode: MatchMode.ai,
            table: table,
            content: content,
            factionIds: {Seat.one: one.factionId, Seat.two: two.factionId},
            deckNames: {Seat.one: playerDeckName, Seat.two: opponentDeckName},
            recordsHistory: false,
          ),
          director,
        );
    }
  }

  /// Правила пакета без пересдачи: в обучении первый шаг сразу про карту на столе.
  static GameRules _withoutRedraw(GameRules rules) => GameRules(
    startingHand: rules.startingHand,
    redrawLimit: 0,
    crystals: rules.crystals,
    minUnitCards: rules.minUnitCards,
    maxSpecialCards: rules.maxSpecialCards,
  );
}
