import 'package:gwent_engine/gwent_engine.dart';
import 'package:gwent_net/gwent_net.dart';
import 'package:gwent_net/testing.dart';
import 'package:test/test.dart';

import 'support/fixtures.dart';
import 'support/table.dart';

/// Надёжность (раздел 8, пункт 3 сетевой спецификации): потери, дубли, задержки и обрывы на всём пути партии.
/// После каждого хода проекции обоих игроков совпадают с проекциями хоста.
void main() {
  const scenarios = {
    'потери': Faults(drop: 0.2),
    'дубли': Faults(duplicate: 0.3),
    'задержки': Faults(maxDelay: Duration(milliseconds: 1500)),
    'всё сразу': Faults(drop: 0.15, duplicate: 0.15, maxDelay: Duration(milliseconds: 800)),
  };

  for (final MapEntry(key: name, value: faults) in scenarios.entries) {
    for (var faultSeed = 1; faultSeed <= 3; faultSeed++) {
      test('$name, сид $faultSeed: партия доигрывается, проекции сходятся', () async {
        final (hostDeck, guestDeck) = pairings[faultSeed % pairings.length];
        final table = Table(seed: faultSeed, guestFaults: faults, faultSeed: faultSeed)..autoReconnect = true;
        await table.start(hostDeck, guestDeck);
        await table.playOut();

        final state = table.host.state!;
        expect(state.phase, MatchPhase.finished);
        expect(table.guest.view, engine.project(state, Seat.two));
        expect(table.journal.record!.replay(engine), state);
        if (faults.drop > 0) {
          expect(table.guestLinks.fold(0, (sum, link) => sum + link.dropped), greaterThan(0), reason: 'потери были');
        }
      });
    }
  }

  test('обрыв на каждом ходу: гость переподключается и партия идёт дальше', () async {
    final table = Table(seed: 7)..autoReconnect = true;
    await table.start(skellige, northern);
    final bot = ViewBot();
    var cuts = 0;
    while (table.host.state!.phase != MatchPhase.finished) {
      await table.guestLink!.cut();
      cuts++;
      await table.waitFor(() => table.converged, 'гость не вернулся после обрыва $cuts');
      final client = [table.hostClient, table.guest].firstWhere((client) => ViewBot.canAct(client.view!));
      await bot.act(table, client);
    }
    expect(cuts, greaterThan(10));
    expect(table.eventsOf<Joined>(table.guest), hasLength(cuts + 1));
    expect(table.guest.view!.outcome, table.host.state!.outcome);
  });
}
