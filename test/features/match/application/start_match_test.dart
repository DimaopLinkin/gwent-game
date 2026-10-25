import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gwent/src/features/content/application/load_game_content.dart';
import 'package:gwent/src/features/content/data/asset_content_source.dart';
import 'package:gwent/src/features/content/domain/game_content.dart';
import 'package:gwent/src/features/deck_builder/domain/deck.dart';
import 'package:gwent/src/features/match/application/start_match.dart';
import 'package:gwent/src/features/match/domain/local_match_table.dart';
import 'package:gwent/src/features/match/domain/match_session.dart';
import 'package:gwent/src/features/match_history/domain/match_record.dart' show MatchMode;
import 'package:gwent/src/features/match_history/domain/replay_log.dart';
import 'package:gwent_ai/gwent_ai.dart' show BotDifficulty;
import 'package:gwent_content/gwent_content.dart' show InMemoryContentSource;
import 'package:gwent_engine/gwent_engine.dart' hide Deck;
import 'package:gwent_net/gwent_net.dart' show RecordedMove;

import '../../../support/fakes.dart';
import '../../../support/match_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late GameContent content;
  late InMemoryDeckRepository decks;
  final load = LoadGameContent(AssetContentSource.basePack(rootBundle));

  setUpAll(() async => content = await loadBaseContent());

  setUp(() {
    decks = InMemoryDeckRepository([
      realDeck(content, Faction.skellige, id: 'skellige'),
      realDeck(content, Faction.monsters, id: 'monsters'),
    ]);
  });

  StartMatch startMatch({int seed = 1}) =>
      StartMatch(load, decks, FixedSeedGenerator(seed), botThinkTime: Duration.zero);

  Future<MatchSession> started(LocalMatchRequest request, {int seed = 1}) async {
    final result = await startMatch(seed: seed)(request);
    if (result is! MatchStarted) fail('партия не начата: $result');
    addTearDown(result.session.table.close);
    return result.session;
  }

  test('против бота: человек за первым местом, бот за вторым', () async {
    final session = await started(
      const LocalMatchRequest(mode: LocalMatchMode.vsBot, deckOne: 'skellige', deckTwo: 'monsters'),
    );
    expect(session.mode, MatchMode.ai);
    expect(session.table.localSeats, {Seat.one});
    expect(session.perspective, Seat.one);
    expect(session.factionIds, {
      Seat.one: (await decks.findById('skellige'))!.factionId,
      Seat.two: (await decks.findById('monsters'))!.factionId,
    });
    expect(session.deckNames, {
      Seat.one: (await decks.findById('skellige'))!.name,
      Seat.two: (await decks.findById('monsters'))!.name,
    });
  });

  test('партия записывается для реплея: сид, колоды, набор правил и ходы человека', () async {
    final session = await started(
      const LocalMatchRequest(mode: LocalMatchMode.hotSeat, deckOne: 'skellige', deckTwo: 'monsters'),
      seed: 77,
    );

    final begun = session.recorder!.log! as JournalReplayLog;
    expect(begun.perspective, Seat.one);
    expect(begun.journal.seed, 77);
    expect(begun.journal.ruleset.hash, content.pack.manifest.contentHash);
    expect(begun.journal.ruleset.engineVersion, engineVersion);
    expect(begun.journal.moves, isEmpty);
    expect(begun.journal.one.leader, isNotNull);

    session.table.submit(Seat.one, const FinishRedraw());

    final after = session.recorder!.log! as JournalReplayLog;
    expect(after.journal.moves, const [RecordedMove(Seat.one, FinishRedraw())]);
    final engine = GwentEngine(content.catalog, rules: content.rules);
    expect(after.journal.replay(engine).player(Seat.one).redrawDone, isTrue);
  });

  test('колода бота берётся из запроса, а не из хранилища', () async {
    final bot = realDeck(content, Faction.nilfgaard, id: 'bot-opponent');
    final session = await started(
      LocalMatchRequest(mode: LocalMatchMode.vsBot, deckOne: 'skellige', deckTwo: bot.id, opponentDeck: bot),
    );

    expect(await decks.findById(bot.id), isNull);
    expect(session.factionIds[Seat.two], bot.factionId);
    expect(session.deckNames[Seat.two], bot.name);
  });

  test('бот получает уровень сложности из запроса и свой сид', () async {
    final asked = <(BotDifficulty, int)>[];
    final start = StartMatch(
      load,
      decks,
      FixedSeedGenerator(10),
      botThinkTime: Duration.zero,
      createBot: (engine, catalog, difficulty, seed) {
        asked.add((difficulty, seed));
        return plainGreedyBot(engine, catalog, difficulty, seed);
      },
    );

    final result = await start(
      const LocalMatchRequest(
        mode: LocalMatchMode.vsBot,
        deckOne: 'skellige',
        deckTwo: 'monsters',
        difficulty: BotDifficulty.deathMatch,
      ),
    );

    expect(result, isA<MatchStarted>());
    addTearDown((result as MatchStarted).session.table.close);
    expect(asked, [(BotDifficulty.deathMatch, 11)], reason: 'сид партии 10, сид бота следующий');
  });

  test('hot-seat: оба места здешние', () async {
    final session = await started(
      const LocalMatchRequest(mode: LocalMatchMode.hotSeat, deckOne: 'skellige', deckTwo: 'skellige'),
    );
    expect(session.table.localSeats, Seat.values.toSet());
  });

  test('одинаковый сид и колоды дают одинаковую раздачу, сид берётся из генератора', () async {
    const request = LocalMatchRequest(mode: LocalMatchMode.hotSeat, deckOne: 'skellige', deckTwo: 'monsters');
    final first = (await started(request, seed: 7)).table as LocalMatchTable;
    final second = (await started(request, seed: 7)).table as LocalMatchTable;
    final other = (await started(request, seed: 8)).table as LocalMatchTable;
    expect(second.state, first.state);
    expect(other.state, isNot(first.state));
  });

  test('колоды нет в хранилище', () async {
    final result = await startMatch()(
      const LocalMatchRequest(mode: LocalMatchMode.vsBot, deckOne: 'skellige', deckTwo: 'gone'),
    );
    expect(
      result,
      isA<MatchDeckNotFound>().having((r) => r.seat, 'seat', Seat.two).having((r) => r.deckId, 'deckId', 'gone'),
    );
  });

  test('пауза стола замораживает и размышление бота: он ходит, только когда доработает время после паузы', () async {
    // Настоящие таймеры: стол собирается из настоящих ассетов, поэтому фальшивые часы теста его не видят.
    final result =
        await StartMatch(load, decks, FixedSeedGenerator(1), botThinkTime: const Duration(milliseconds: 600))(
          const LocalMatchRequest(mode: LocalMatchMode.vsBot, deckOne: 'skellige', deckTwo: 'monsters'),
        );
    final table = (result as MatchStarted).session.table as LocalMatchTable;
    addTearDown(table.close);
    final startState = table.state;
    Future<void> wait(int milliseconds) => Future<void>.delayed(Duration(milliseconds: milliseconds));

    await wait(200);
    table.setPaused(paused: true);
    await wait(1000);
    expect(table.state, startState, reason: 'за время паузы бот не ходит');

    table.setPaused(paused: false);
    await wait(150);
    expect(table.state, startState, reason: 'от 600 мс размышления осталось ещё около 400');
    await wait(700);
    expect(table.state, isNot(startState));
  });

  test('колода не по правилам', () async {
    final skellige = (await decks.findById('skellige'))!;
    await decks.save(
      Deck(
        id: 'small',
        name: 'Мало карт',
        factionId: skellige.factionId,
        leaderId: skellige.leaderId,
        cards: {skellige.cards.keys.first: 1},
        updatedAt: skellige.updatedAt,
      ),
    );
    final result = await startMatch()(
      const LocalMatchRequest(mode: LocalMatchMode.vsBot, deckOne: 'small', deckTwo: 'monsters'),
    );
    expect(
      result,
      isA<MatchDeckInvalid>()
          .having((r) => r.seat, 'seat', Seat.one)
          .having((r) => r.violations, 'violations', isNotEmpty),
    );
  });

  test('контента нет', () async {
    final result = await StartMatch(LoadGameContent(InMemoryContentSource(const {})), decks, FixedSeedGenerator(1))(
      const LocalMatchRequest(mode: LocalMatchMode.vsBot, deckOne: 'skellige', deckTwo: 'monsters'),
    );
    expect(result, isA<MatchContentUnavailable>().having((r) => r.issues, 'issues', isNotEmpty));
  });
}
