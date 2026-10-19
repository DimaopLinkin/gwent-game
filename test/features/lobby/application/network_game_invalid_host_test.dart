import 'package:flutter_test/flutter_test.dart';
import 'package:gwent/src/features/content/domain/game_content.dart';
import 'package:gwent/src/features/lobby/application/network_game.dart';
import 'package:gwent/src/features/lobby/domain/lobby_room.dart';
import 'package:gwent/src/features/match/domain/match_table.dart';
import 'package:gwent_engine/gwent_engine.dart';
import 'package:gwent_net/gwent_net.dart';
import 'package:gwent_net/testing.dart';

import '../../../support/match_fixtures.dart';

/// Гость и хост с данными, которых нет в справочнике гостя: подделанное объявление, модифицированное приложение.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const codec = EnvelopeCodec();
  late GameContent content;
  late FakeScheduler scheduler;
  late NetworkGame game;
  late InMemoryTransport rogue;

  setUpAll(() async => content = await loadBaseContent());

  const ruleset = Ruleset(id: 'pack', hash: 'sha256:0', engineVersion: 1);

  setUp(() async {
    scheduler = FakeScheduler();
    final client = MatchClient(
      settings: const ClientSettings(ruleset: ruleset, playerName: 'Гость', appVersion: 'test'),
      scheduler: scheduler,
      catalog: content.catalog,
    );
    game = NetworkGame(client: client, content: content, scheduler: scheduler, playerName: 'Гость');
    final (near, far) = InMemoryTransport.pair();
    rogue = far;
    client.connect(near);
    rogue.send(codec.encode(const Envelope(Welcome(seat: Seat.two, matchId: 'm', resumeToken: 't', next: 1))));
    await scheduler.flush();
  });

  tearDown(() => game.close());

  SideView side(Seat seat, String leader) => SideView(
    seat: seat,
    leader: LeaderId(leader),
    faction: Faction.skellige,
    leaderAvailable: false,
    leaderUsed: false,
    leaderDisabled: false,
    crystals: 2,
    passed: false,
    handCount: 0,
    deckCount: 0,
    discard: const [],
    rows: {
      for (final row in Row.values) row: const RowView(cards: [], slot: null, weather: false, strength: 0),
    },
    score: 0,
    redrawDone: false,
  );

  PlayerView view(String opponentLeader) {
    final known = content.pack.rules.leaderCards.first.id;
    return PlayerView(
      viewer: Seat.two,
      phase: MatchPhase.redraw,
      round: 0,
      me: side(Seat.two, known),
      opponent: side(Seat.one, opponentLeader),
      weather: const [],
      history: const [],
    );
  }

  void sendSnapshot(PlayerView view) => rogue.send(codec.encode(Envelope(MatchSnapshot(view), seq: 1, matchId: 'm')));

  test('честные данные хоста принимаются, партия начинается', () async {
    sendSnapshot(view(content.pack.rules.leaderCards.last.id));
    await scheduler.flush();
    expect(game.room.started, isTrue);
    expect(game.room.end, isNull);
  });

  test('лидер, которого нет в справочнике: игра заканчивается причиной «хост прислал неверные данные»', () async {
    sendSnapshot(view('no-such-leader'));
    await scheduler.flush();
    expect(game.room.end, const RoomHostInvalid());
    expect(game.room.started, isFalse, reason: 'экран партии не открывается на негодных данных');
  });

  test('если партия уже идёт, стол получает отказ с той же причиной', () async {
    final updates = <TableUpdate>[];
    sendSnapshot(view(content.pack.rules.leaderCards.last.id));
    await scheduler.flush();
    final session = game.openMatch();
    final subscription = session.table.updates.listen(updates.add);
    rogue.send(
      codec.encode(Envelope(MatchSnapshot(view('no-such-leader')), seq: 2, matchId: 'm')),
    );
    await scheduler.flush();
    expect(updates.whereType<TableFailed>().single.error, const RoomHostInvalid());
    await subscription.cancel();
  });
}
