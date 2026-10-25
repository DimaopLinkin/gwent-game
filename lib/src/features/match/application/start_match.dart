import 'package:gwent/src/core/domain/seed_generator.dart';
import 'package:gwent/src/features/content/application/load_game_content.dart';
import 'package:gwent/src/features/content/domain/game_content.dart';
import 'package:gwent/src/features/deck_builder/domain/deck.dart' as app;
import 'package:gwent/src/features/deck_builder/domain/deck_repository.dart';
import 'package:gwent/src/features/deck_builder/domain/engine_deck.dart';
import 'package:gwent/src/features/match/domain/local_match_table.dart';
import 'package:gwent/src/features/match/domain/match_pause.dart';
import 'package:gwent/src/features/match/domain/match_session.dart';
import 'package:gwent/src/features/match/domain/seat_agent.dart';
import 'package:gwent/src/features/match_history/domain/match_record.dart' show MatchMode;
import 'package:gwent/src/features/match_history/domain/replay_recorder.dart';
import 'package:gwent_ai/gwent_ai.dart';
import 'package:gwent_content/gwent_content.dart' show ValidationIssue;
import 'package:gwent_engine/gwent_engine.dart';
import 'package:gwent_net/gwent_net.dart' show InMemoryMatchJournal, MatchRecord, Ruleset;
import 'package:meta/meta.dart';

/// Создаёт бота уровня `difficulty` для партии над движком и справочником карт; `seed` задаёт ошибки лёгкого уровня
/// и догадки о руке соперника, поэтому с одним сидом бот играет одинаково.
typedef BotFactory = MatchBot Function(MatchEngine engine, CardCatalog catalog, BotDifficulty difficulty, int seed);

/// Что выбрал игрок перед местной партией: режим, колоды мест и, если игрок выбрал, лидеры.
@immutable
final class LocalMatchRequest {
  /// Создаёт запрос. Против бота [deckTwo] — колода бота: если собранной колоды нет ([opponentDeck]), она лежит
  /// в хранилище.
  ///
  /// [leaderOne] и [leaderTwo] — UUID лидеров, с которыми места идут в эту партию вместо лидера колоды: лидер
  /// выбирается перед партией и не меняет сохранённую колоду. Без них места играют лидерами своих колод.
  const LocalMatchRequest({
    required this.mode,
    required this.deckOne,
    required this.deckTwo,
    this.leaderOne,
    this.leaderTwo,
    this.difficulty = BotDifficulty.normal,
    this.opponentDeck,
  });

  /// Режим.
  final LocalMatchMode mode;

  /// Уровень сложности бота; в hot-seat не используется.
  final BotDifficulty difficulty;

  /// Колода бота, собранная под уровень: в хранилище её нет. `null` — колода второго места берётся из хранилища
  /// по [deckTwo].
  final app.Deck? opponentDeck;

  /// Идентификатор колоды первого места.
  final String deckOne;

  /// Идентификатор колоды второго места.
  final String deckTwo;

  /// UUID лидера первого места на эту партию или `null`, если играет лидер колоды.
  final String? leaderOne;

  /// UUID лидера второго места на эту партию или `null`, если играет лидер колоды.
  final String? leaderTwo;

  /// Колода места [seat].
  String deck(Seat seat) => switch (seat) {
    Seat.one => deckOne,
    Seat.two => deckTwo,
  };

  /// Выбранный лидер места [seat] или `null`, если играет лидер колоды.
  String? leader(Seat seat) => switch (seat) {
    Seat.one => leaderOne,
    Seat.two => leaderTwo,
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
/// Колоды берутся из хранилища (колода бота может прийти собранной в самом запросе), проверяются и раздаются
/// движком; сид партии даёт [SeedGenerator]. Против бота второе место занимает [BotAgent] над ботом из [BotFactory]
/// (по умолчанию `GreedyBot` выбранного уровня).
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

  static MatchBot _greedyBot(MatchEngine engine, CardCatalog catalog, BotDifficulty difficulty, int seed) =>
      GreedyBot.forDifficulty(engine, catalog, difficulty, seed: seed);

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
      final built = seat == Seat.two ? request.opponentDeck : null;
      final deck = built ?? await _decks.findById(request.deck(seat));
      if (deck == null) return MatchDeckNotFound(seat, request.deck(seat));
      decks[seat] = switch (request.leader(seat)) {
        final leaderId? => deck.copyWith(leaderId: leaderId),
        null => deck,
      };
    }
    return _start(request, content, decks);
  }

  StartMatchResult _start(LocalMatchRequest request, GameContent content, Map<Seat, app.Deck> decks) {
    final mode = request.mode;
    final engine = GwentEngine(content.catalog, rules: content.rules);
    final seed = _seeds.next();
    final setup = MatchSetup(
      one: decks[Seat.one]!.toEngineDeck(),
      two: decks[Seat.two]!.toEngineDeck(),
      rng: SeededRng(seed),
    );
    switch (engine.start(setup)) {
      case Rejected(:final reject):
        return MatchDeckInvalid(reject.seat!, reject.deckViolations);
      case Accepted(:final state, :final events):
        // Журнал начинается до стола: стол пишет в него с первого хода (реплей, ADR 0029).
        final manifest = content.pack.manifest;
        final journal = InMemoryMatchJournal()
          ..begin(
            MatchRecord(
              matchId: 'local-$seed',
              ruleset: Ruleset(id: manifest.packId, hash: manifest.contentHash, engineVersion: engineVersion),
              seed: seed,
              one: setup.one,
              two: setup.two,
            ),
          );
        // Пауза общая: стол не принимает ходы на паузе, а бот не тратит на ней время размышления.
        final pause = MatchPause();
        final table = LocalMatchTable(
          engine: engine,
          state: state,
          startEvents: events,
          journal: journal,
          pause: pause,
          agents: switch (mode) {
            LocalMatchMode.hotSeat => const {},
            LocalMatchMode.vsBot => {
              Seat.two: BotAgent(
                _createBot(engine, content.catalog, request.difficulty, _seeds.next()),
                thinkTime: _botThinkTime,
                pause: pause,
              ),
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
            recorder: JournalReplayRecorder(journal, perspective: Seat.one),
          ),
        );
    }
  }
}
