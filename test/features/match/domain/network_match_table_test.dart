import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:gwent/src/features/match/domain/match_table.dart';
import 'package:gwent/src/features/match/domain/network_match_table.dart';
import 'package:gwent_engine/gwent_engine.dart';

void main() {
  late StreamController<TableUpdate> updates;
  late List<Intent> sent;
  late int closes;

  NetworkMatchTable table({Seat seat = Seat.two}) {
    final table = NetworkMatchTable(
      seat: seat,
      updates: updates.stream,
      onSubmit: sent.add,
      onClose: () async => closes++,
    );
    addTearDown(table.close);
    return table;
  }

  setUp(() {
    updates = StreamController<TableUpdate>();
    sent = [];
    closes = 0;
    addTearDown(() => unawaited(updates.close()));
  });

  test('телефон держит одно своё место', () {
    expect(table().localSeats, {Seat.two});
    expect(table(seat: Seat.one).localSeats, {Seat.one});
  });

  test('обновления берутся из сетевой игры как есть', () async {
    final seen = <TableUpdate>[];
    final subscription = table().updates.listen(seen.add);
    addTearDown(subscription.cancel);

    updates.add(const TableFailed(Object()));
    await pumpEventQueue();

    expect(seen, [isA<TableFailed>()]);
  });

  test('намерение своего места уходит сетевой игре; за место соперника ходить нельзя', () {
    final network = table();

    network.submit(Seat.two, const Pass());
    expect(sent, [const Pass()]);
    expect(() => network.submit(Seat.one, const Pass()), throwsArgumentError);
    expect(sent, hasLength(1));
  });

  test('закрытие просит сетевую игру закрыться один раз, а после него ходить нельзя', () async {
    final network = table();

    await network.close();
    await network.close();

    expect(closes, 1);
    expect(() => network.submit(Seat.two, const Pass()), throwsStateError);
  });
}
