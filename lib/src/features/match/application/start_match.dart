import 'package:gwent/src/core/domain/seed_generator.dart';
import 'package:gwent/src/features/content/application/load_game_content.dart';
import 'package:gwent/src/features/content/domain/game_content.dart';
import 'package:gwent/src/features/deck_builder/domain/deck.dart' as app;
import 'package:gwent/src/features/deck_builder/domain/deck_repository.dart';
import 'package:gwent/src/features/deck_builder/domain/engine_deck.dart';
import 'package:gwent/src/features/match/domain/local_match_table.dart';
import 'package:gwent/src/features/match/domain/match_session.dart';
import 'package:gwent/src/features/match/domain/seat_agent.dart';
import 'package:gwent/src/features/match_history/domain/match_record.dart' show MatchMode;
import 'package:gwent_ai/gwent_ai.dart';
import 'package:gwent_content/gwent_content.dart' show ValidationIssue;
import 'package:gwent_engine/gwent_engine.dart';
import 'package:meta/meta.dart';

/// Создаёт бота для партии над движком и справочником карт.
typedef BotFactory = MatchBot Function(MatchEngine engine, CardCatalog catalog);

/// Что выбрал игрок перед местной партией: режим и колоды мест.
@immutable
final class LocalMatchRequest {
  /// Создаёт запрос. Против бота [deckTwo] — колода бота.
  const LocalMatchRequest({required this.mode, required this.deckOne, required this.deckTwo});

  /// Режим.
  final LocalMatchMode mode;

  /// Идентификатор колоды первого места.
  final String deckOne;

  /// Идентификатор колоды второго места.
  final String deckTwo;

  /// Колода места [seat].
  String deck(Seat seat) => switch (seat) {
    Seat.one => deckOne,
    Seat.two => deckTwo,
  };
}

/// Итог попытки начать партию.
sealed class StartMatchResult {
  const StartMatchResult();
}

/// Партия начата: раздача сделана, стол ждёт пересдачи (или выбора Скоя'таэлей).
final class MatchStarted extends StartMatchResult {
  /// Создаёт итог.
  const MatchStarted(this.session);

  /// Начатая партия.
  final MatchSession session;
}

/// Контент недоступен: пакет не прошёл проверку.
final class MatchContentUnavailable extends StartMatchResult {
  /// Создаёт итог.
  MatchContentUnavailable(List<ValidationIssue> issues) : issues = List.unmodifiable(issues);

  /// Проблемы пакета.
  final List<ValidationIssue> issues;
}

/// Колоды места нет в хранилище (например, её удалили, пока шёл выбор).
final class MatchDeckNotFound extends StartMatchResult {
  /// Создаёт итог.
  const MatchDeckNotFound(this.seat, this.deckId);

  /// Чья колода.
  final Seat seat;

  /// Идентификатор колоды.
  final String deckId;
}

/// Колода места не проходит правила сборки.
final class MatchDeckInvalid extends StartMatchResult {
  /// Создаёт итог.
  MatchDeckInvalid(this.seat, List<DeckViolation> violations) : violations = List.unmodifiable(violations);

  /// Чья колода.
  final Seat seat;

  /// Нарушения; не пустой список.
  final List<DeckViolation> violations;
}

/// Сценарий: начать местную партию (hot-seat или против бота) из сохранённых колод.
///
/// Колоды берутся из хранилища, проверяются и раздаются движком; сид партии даёт [SeedGenerator]. Против бота
/// второе место занимает [BotAgent] над ботом из [BotFactory] (по умолчанию жадный `GreedyBot`).
final class StartMatch {
  /// Создаёт сценарий.
  StartMatch(
    this._content,
    this._decks,
    this._seeds, {
    BotFactory createBot = _greedyBot,
    Duration botThinkTime = const Duration(milliseconds: 700),
  }) : _createBot = createBot,
       _botThinkTime = botThinkTime;

  final LoadGameContent _content;
  final DeckRepository _decks;
  final SeedGenerator _seeds;
  final BotFactory _createBot;
  final Duration _botThinkTime;

  static MatchBot _greedyBot(MatchEngine engine, CardCatalog catalog) => GreedyBot(engine, catalog);

  /// Начинает партию по запросу [request].
  Future<StartMatchResult> call(LocalMatchRequest request) async {
    final GameContent content;
    switch (await _content()) {
      case GameContentReady(content: final ready):
        content = ready;
      case GameContentRejected(:final issues):
        return MatchContentUnavailable(issues);
    }
    final decks = <Seat, app.Deck>{};
    for (final seat in Seat.values) {
      final deck = await _decks.findById(request.deck(seat));
      if (deck == null) return MatchDeckNotFound(seat, request.deck(seat));
      decks[seat] = deck;
    }
    return _start(request.mode, content, decks);
  }

  StartMatchResult _start(LocalMatchMode mode, GameContent content, Map<Seat, app.Deck> decks) {
    final engine = GwentEngine(content.catalog, rules: content.rules);
    final setup = MatchSetup(
      one: decks[Seat.one]!.toEngineDeck(),
      two: decks[Seat.two]!.toEngineDeck(),
      rng: SeededRng(_seeds.next()),
    );
    switch (engine.start(setup)) {
      case Rejected(:final reject):
        return MatchDeckInvalid(reject.seat!, reject.deckViolations);
      case Accepted(:final state, :final events):
        final table = LocalMatchTable(
          engine: engine,
          state: state,
          startEvents: events,
          agents: switch (mode) {
            LocalMatchMode.hotSeat => const {},
            LocalMatchMode.vsBot => {
              Seat.two: BotAgent(_createBot(engine, content.catalog), thinkTime: _botThinkTime),
            },
          },
        );
        return MatchStarted(
          MatchSession(
            mode: switch (mode) {
              LocalMatchMode.hotSeat => MatchMode.hotSeat,
              LocalMatchMode.vsBot => MatchMode.ai,
            },
            table: table,
            content: content,
            factionIds: {for (final seat in Seat.values) seat: decks[seat]!.factionId},
            deckNames: {for (final seat in Seat.values) seat: decks[seat]!.name},
          ),
        );
    }
  }
}
