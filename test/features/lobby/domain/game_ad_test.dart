import 'package:flutter_test/flutter_test.dart';
import 'package:gwent/src/features/lobby/domain/game_ad.dart';
import 'package:gwent_net/gwent_net.dart';

import '../support/lobby_fakes.dart';

void main() {
  const ad = GameAd(id: 'game-1', hostName: 'Геральт', ruleset: testRuleset);

  test('к открытой партии с тем же набором правил присоединиться можно', () {
    expect(ad.refusalFor(testRuleset), isNull);
  });

  test('объявление заранее называет ту же причину отказа, что и хост', () {
    expect(
      const GameAd(id: 'g', hostName: 'x', ruleset: testRuleset, protocol: protocolVersion + 1).refusalFor(testRuleset),
      JoinRefusal.protocolMismatch,
    );
    expect(
      ad.refusalFor(const Ruleset(id: 'gwent-w3-base', hash: 'other', engineVersion: 1)),
      JoinRefusal.rulesetMismatch,
    );
    expect(
      ad.refusalFor(const Ruleset(id: 'gwent-w3-base', hash: 'abc123', engineVersion: 2)),
      JoinRefusal.rulesetMismatch,
    );
    expect(ad.copyWith(open: false).refusalFor(testRuleset), JoinRefusal.matchFull);
  });

  test('объявления сравниваются по значению', () {
    expect(ad.copyWith(), ad);
    expect(ad.copyWith(open: false), isNot(ad));
    expect(ad.copyWith(hostName: 'Цири').hashCode, isNot(ad.hashCode));
  });
}
