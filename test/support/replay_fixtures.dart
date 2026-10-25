import 'dart:async';

import 'package:flutter/services.dart';
import 'package:gwent/src/features/content/application/load_game_content.dart';
import 'package:gwent/src/features/content/data/asset_content_source.dart';
import 'package:gwent/src/features/match/application/record_finished_match.dart';
import 'package:gwent/src/features/match/application/start_match.dart';
import 'package:gwent/src/features/match/domain/local_match_table.dart';
import 'package:gwent/src/features/match/domain/match_session.dart' show LocalMatchMode;
import 'package:gwent/src/features/match/domain/match_table.dart';
import 'package:gwent/src/features/match_history/application/record_match.dart';
import 'package:gwent/src/features/match_history/domain/match_record.dart';
import 'package:gwent_ai/gwent_ai.dart';
import 'package:gwent_engine/gwent_engine.dart' hide Deck, MatchOutcome;

import 'fakes.dart';
import 'match_fixtures.dart';

/// Партия, сыгранная до конца и записанная в историю вместе с реплеем.
typedef PlayedMatch = ({
  InMemoryMatchHistoryRepository history,
  LoadGameContent loader,
  MatchRecord record,
});

/// Играет партию «человек (жадный бот) против бота» до конца на настоящем наборе карт и записывает её в историю с
/// реплеем. Тест должен вызвать `TestWidgetsFlutterBinding.ensureInitialized()`.
Future<PlayedMatch> playRecordedMatch({int seed = 5}) async {
  final loader = LoadGameContent(AssetContentSource.basePack(rootBundle));
  final content = await loadBaseContent();
  final decks = InMemoryDeckRepository([
    realDeck(content, Faction.skellige, id: 'skellige'),
    realDeck(content, Faction.monsters, id: 'monsters'),
  ]);
  final started = await StartMatch(loader, decks, FixedSeedGenerator(seed), botThinkTime: Duration.zero)(
    const LocalMatchRequest(mode: LocalMatchMode.vsBot, deckOne: 'skellige', deckTwo: 'monsters'),
  );
  final session = (started as MatchStarted).session;
  final table = session.table as LocalMatchTable;
  final engine = GwentEngine(session.content.catalog, rules: session.content.rules);
  final human = GreedyBot(engine, session.content.catalog);
  final finished = Completer<PlayerView>();
  table.updates.listen((update) {
    switch (update) {
      case ViewsChanged(:final views):
        final view = views[Seat.one]!;
        if (view.outcome != null) {
          finished.complete(view);
        } else if (human.decide(table.state, Seat.one) case final intent?) {
          table.submit(Seat.one, intent);
        }
      case IntentRefused(:final reject):
        finished.completeError(StateError('отказ ${reject.reason}'));
      case TableFailed(:final error):
        finished.completeError(error);
      case TableRematchChanged() || TableRematchAgreed():
        break;
    }
  });
  final finalView = await finished.future;
  await table.close();
  final history = InMemoryMatchHistoryRepository();
  final record = await RecordFinishedMatch(
    RecordMatch(history, FakeClock(DateTime.utc(2026, 10, 12)), SequentialIdGenerator()),
  )(session, finalView);
  return (history: history, loader: loader, record: record);
}
