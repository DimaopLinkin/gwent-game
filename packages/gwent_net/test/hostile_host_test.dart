import 'dart:convert';
import 'dart:typed_data';

import 'package:gwent_engine/gwent_engine.dart';
import 'package:gwent_net/gwent_net.dart';
import 'package:gwent_net/src/codec/json_reader.dart';
import 'package:gwent_net/src/codec/view_json.dart';
import 'package:gwent_net/testing.dart';
import 'package:test/test.dart';

import 'support/fixtures.dart';
import 'support/table.dart';

/// Враждебный или модифицированный хост: гость не должен падать на данных, которых нет в его справочнике.
void main() {
  const codec = EnvelopeCodec();
  late FakeScheduler scheduler;
  late MatchClient client;
  late InMemoryTransport rogue;
  late List<ClientEvent> events;
  late PlayerView valid;
  late Seat seat;

  setUp(() async {
    final table = Table();
    await table.start(skellige, northern);
    valid = table.guest.view!;
    seat = table.guest.seat!;
    scheduler = FakeScheduler();
    client = MatchClient(
      settings: const ClientSettings(ruleset: ruleset, playerName: 'Гость', appVersion: 'test'),
      scheduler: scheduler,
      catalog: catalog,
    );
    events = [];
    client.events.listen(events.add);
    final (near, far) = InMemoryTransport.pair();
    rogue = far;
    client.connect(near);
    rogue.send(
      codec.encode(
        Envelope(
          Welcome(seat: seat, matchId: 'm', resumeToken: 't', next: 1),
          matchId: 'm',
        ),
      ),
    );
    await scheduler.flush();
  });

  void send(NetMessage message, {int seq = 1}) =>
      rogue.send(Uint8List.fromList(codec.encode(Envelope(message, seq: seq, matchId: 'm'))));

  PlayerView tamper(void Function(Map<String, Object?> json) edit) {
    final json = jsonDecode(jsonEncode(encodeView(valid))) as Map<String, Object?>;
    edit(json);
    return decodeView(JsonReader(json, r'$'));
  }

  Map<String, Object?> me(Map<String, Object?> json) => json['me']! as Map<String, Object?>;

  test('честная проекция принимается', () async {
    send(MatchSnapshot(valid));
    await scheduler.flush();
    expect(events.whereType<ViewChanged>(), hasLength(1));
    expect(events.whereType<HostDataInvalid>(), isEmpty);
  });

  test('карта вне справочника в руке: данные отвергаются, соединение закрывается', () async {
    final view = tamper((json) => ((me(json)['hand']! as List).first as Map<String, Object?>)['card'] = 'no_such_card');
    send(MatchSnapshot(view));
    await scheduler.flush();
    expect(events.whereType<ViewChanged>(), isEmpty);
    expect(events.whereType<HostDataInvalid>().single.problem, contains('no_such_card'));
    expect(client.status, ConnectionStatus.closed);
    expect(client.view, isNull);
  });

  test('огромные и отрицательные счётчики: данные отвергаются', () async {
    for (final edit in <void Function(Map<String, Object?>)>[
      (json) => me(json)['hand_count'] = 2000000000,
      (json) => me(json)['deck_count'] = -1,
      (json) => me(json)['crystals'] = 5000,
      (json) => json['round'] = -3,
    ]) {
      send(MatchSnapshot(tamper(edit)));
    }
    await scheduler.flush();
    expect(events.whereType<ViewChanged>(), isEmpty);
    expect(events.whereType<HostDataInvalid>(), hasLength(1), reason: 'после первого соединение закрыто');
  });

  test('ряды стороны не пришли: данные отвергаются', () async {
    send(MatchSnapshot(tamper((json) => me(json)['rows'] = <String, Object?>{})));
    await scheduler.flush();
    expect(events.whereType<HostDataInvalid>(), hasLength(1));
  });

  test('карта вне справочника в отбое', () async {
    send(
      MatchSnapshot(
        tamper(
          (json) => me(json)['discard'] = [
            {'card': 'no_such_card', 'id': 99},
          ],
        ),
      ),
    );
    await scheduler.flush();
    expect(events.whereType<HostDataInvalid>().single.problem, contains('no_such_card'));
  });

  test('лидер вне справочника', () async {
    final view = tamper((json) => me(json)['leader'] = 'no_such_leader');
    send(MatchSnapshot(view));
    await scheduler.flush();
    expect(events.whereType<HostDataInvalid>().single.problem, contains('no_such_leader'));
  });

  test('карта вне справочника только в событии', () async {
    send(MatchUpdate([CardPlayed(seat.opponent, const CardInstance(CardInstanceId(1), CardId('ghost')))], valid));
    await scheduler.flush();
    expect(events.whereType<HostDataInvalid>().single.problem, contains('ghost'));
    expect(events.whereType<ViewChanged>(), isEmpty);
  });

  test('проекция чужого места', () async {
    send(MatchSnapshot(tamper((json) => json['viewer'] = seat.opponent.wire)));
    await scheduler.flush();
    expect(events.whereType<HostDataInvalid>(), hasLength(1));
  });

  test('обратный отсчёт старта: только разумные значения', () {
    Map<String, Object?> frame(int ms) =>
        codec.toJson(const Envelope(CountdownStart(Duration(seconds: 3)), seq: 1))..['p'] = {'ms': ms};
    expect(codec.fromJson(frame(3000)).message, const CountdownStart(Duration(seconds: 3)));
    for (final ms in [-1, 60001, 1 << 50]) {
      expect(() => codec.fromJson(frame(ms)), throwsA(isA<MalformedFrame>()), reason: '$ms');
    }
  });
}
