import 'package:flutter_test/flutter_test.dart';
import 'package:gwent/src/features/lobby/data/lan_lobby.dart';
import 'package:gwent/src/features/lobby/domain/game_ad.dart';
import 'package:gwent/src/features/lobby/domain/game_lobby.dart';
import 'package:gwent_engine/gwent_engine.dart';
import 'package:gwent_net/gwent_net.dart';

import '../support/lobby_fakes.dart';

/// Партия протокола `gwent_net` между хостом и гостем через лобби Wi-Fi на настоящих сокетах и настоящем времени.
void main() {
  final catalog = InMemoryCardCatalog(
    cards: [
      for (final (id, strength) in [('footman', 3), ('archer', 4), ('knight', 5)])
        UnitCardDefinition(
          id: CardId(id),
          faction: Faction.neutral,
          copies: 4,
          placement: UnitPlacement.melee,
          strength: strength,
        ),
    ],
    leaders: [const LeaderDefinition(id: LeaderId('bran'), faction: Faction.skellige, ability: HalveWeatherAbility())],
  );
  final deck = Deck(
    leader: const LeaderId('bran'),
    cards: [
      for (final id in ['footman', 'archer', 'knight'])
        for (var copy = 0; copy < 4; copy++) CardId(id),
    ],
  );

  late MatchHost host;
  late HostedGame hosted;
  late MatchClient hostClient;
  late MatchClient guest;
  late List<ClientEvent> hostEvents;
  late List<ClientEvent> guestEvents;

  /// Одна сеть на двоих: что объявил хост, находит гость.
  late FakeServiceDirectory network;

  MatchClient client(String name, List<ClientEvent> log) {
    final client = MatchClient(
      settings: ClientSettings(ruleset: testRuleset, playerName: name, appVersion: 'test'),
      scheduler: const SystemScheduler(),
      catalog: catalog,
    );
    client.events.listen(log.add);
    return client;
  }

  setUp(() async {
    hostEvents = [];
    guestEvents = [];
    network = FakeServiceDirectory();
    host = MatchHost(
      engine: GwentEngine(catalog, rules: const GameRules(minUnitCards: 0)),
      settings: const HostSettings(ruleset: testRuleset),
      scheduler: const SystemScheduler(),
      entropy: SecureEntropy(),
    );
    hosted = await LanLobby(
      directory: network,
    ).host(const GameAd(id: 'game-1', hostName: 'Хост', ruleset: testRuleset));
    hosted.connections.listen(host.accept);
    hostClient = client('Хост', hostEvents);
    guest = client('Гость', guestEvents);
    final (near, far) = InMemoryTransport.pair();
    host.accept(far);
    hostClient.connect(near);
    await _until(() => hostEvents.contains(const Joined(Seat.one)));
  });

  tearDown(() async {
    await guest.close();
    await hostClient.close();
    await host.close();
    await hosted.close();
  });

  /// Гость ищет партию и подключается к ней по найденному адресу.
  Future<Transport> join() async {
    final lobby = LanLobby(directory: network);
    final found = await lobby.discover().firstWhere((games) => games.isNotEmpty);
    expect(found.single.ad.refusalFor(testRuleset), isNull);
    return lobby.join(found.single.address);
  }

  int views(List<ClientEvent> log) => log.whereType<ViewChanged>().length;

  test('гость находит партию, начинает её и возвращается на своё место после обрыва', () async {
    final link = await join();
    guest.connect(link);
    await _until(() => guestEvents.contains(const Joined(Seat.two)));

    hostClient.submitDeck(deck);
    guest.submitDeck(deck);
    await _until(() => views(hostEvents) > 0 && views(guestEvents) > 0);
    expect(guest.view!.phase, MatchPhase.redraw);
    expect(guest.view!.me.hand, hasLength(10));

    guest.send(const FinishRedraw());
    final before = views(hostEvents);
    await _until(() => views(hostEvents) > before);

    // Обрыв Wi-Fi у гостя: хост ставит партию на паузу.
    await link.close();
    await _until(() => guestEvents.contains(const ConnectionLost()));
    await _until(() => hostEvents.contains(const OpponentPresenceChanged(online: false, name: 'Гость')));

    final joinedBefore = guestEvents.whereType<Joined>().length;
    guest.connect(await join());
    await _until(() => guestEvents.whereType<Joined>().length > joinedBefore);
    expect(guestEvents.whereType<Joined>().last, const Joined(Seat.two), reason: 'место вернулось по токену');
    await _until(() => hostEvents.last == const OpponentPresenceChanged(online: true, name: 'Гость'));
    expect(guestEvents.whereType<ActionRefused>(), isEmpty);
  });

  test('гость с другим набором правил видит отказ заранее и получает его от хоста', () async {
    const other = Ruleset(id: 'gwent-w3-base', hash: 'other', engineVersion: 1);
    final lobby = LanLobby(directory: network);
    final found = await lobby.discover().firstWhere((games) => games.isNotEmpty);
    expect(found.single.ad.refusalFor(other), JoinRefusal.rulesetMismatch);

    final stranger = MatchClient(
      settings: const ClientSettings(ruleset: other, playerName: 'Чужой', appVersion: 'test'),
      scheduler: const SystemScheduler(),
      catalog: catalog,
    );
    final events = <ClientEvent>[];
    stranger.events.listen(events.add);
    stranger.connect(await lobby.join(found.single.address));
    await _until(() => events.whereType<JoinRefused>().isNotEmpty);
    expect(events.whereType<JoinRefused>().single.reason, JoinRefusal.rulesetMismatch);
    await stranger.close();
  });
}

Future<void> _until(bool Function() condition) async {
  final deadline = DateTime.now().add(const Duration(seconds: 10));
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) fail('условие не выполнилось за 10 с');
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}
