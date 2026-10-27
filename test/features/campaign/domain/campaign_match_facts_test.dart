import 'package:flutter_test/flutter_test.dart';
import 'package:gwent/src/features/campaign/domain/campaign_match_facts.dart';
import 'package:gwent/src/features/content/domain/game_content.dart';
import 'package:gwent_content/gwent_content.dart' show BonusCondition;
import 'package:gwent_engine/gwent_engine.dart';

import '../../../support/bot_match.dart';
import '../../../support/match_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  RoundScore won(int mine, int theirs) => RoundScore(mine: mine, theirs: theirs, won: true);
  RoundScore lost(int mine, int theirs) => RoundScore(mine: mine, theirs: theirs, won: false);

  group('условия дополнительной награды', () {
    test('2:0: два выигранных раунда, без проигранных и ничейных', () {
      expect(
        CampaignMatchFacts(won: true, rounds: [won(20, 10), won(15, 12)]).meets(BonusCondition.winTwoZero),
        isTrue,
      );
      expect(
        CampaignMatchFacts(won: true, rounds: [won(20, 10), lost(5, 9), won(15, 12)]).meets(BonusCondition.winTwoZero),
        isFalse,
        reason: '2:1 это не 2:0',
      );
      expect(
        CampaignMatchFacts(won: true, rounds: [won(10, 10), won(15, 12)]).meets(BonusCondition.winTwoZero),
        isTrue,
        reason: 'раунд при равных очках выигран по перку: решает движок, а не сравнение очков',
      );
      expect(
        CampaignMatchFacts(
          won: true,
          rounds: [const RoundScore(mine: 9, theirs: 9, won: false), won(15, 12), won(11, 9)],
        ).meets(BonusCondition.winTwoZero),
        isFalse,
        reason: 'ничья в первом раунде',
      );
    });

    test('без особых карт: ни одной сыгранной особой карты', () {
      expect(CampaignMatchFacts(won: true).meets(BonusCondition.noSpecials), isTrue);
      expect(CampaignMatchFacts(won: true, specialsPlayed: 1).meets(BonusCondition.noSpecials), isFalse);
    });

    test('перевес от 20: в каком-то выигранном раунде', () {
      expect(CampaignMatchFacts(won: true, rounds: [won(30, 10)]).meets(BonusCondition.margin20), isTrue);
      expect(CampaignMatchFacts(won: true, rounds: [won(29, 10)]).meets(BonusCondition.margin20), isFalse);
      expect(
        CampaignMatchFacts(won: true, rounds: [lost(5, 40), won(21, 10), won(22, 11)]).meets(BonusCondition.margin20),
        isFalse,
        reason: 'перевес проигранного раунда не считается',
      );
    });

    test('в проигранной партии ни одно условие не выполнено', () {
      final facts = CampaignMatchFacts(won: false, rounds: [won(40, 10), won(40, 10)]);
      for (final condition in BonusCondition.values) {
        expect(facts.meets(condition), isFalse, reason: condition.key);
      }
    });
  });

  group('итог по журналу партии двух ботов', () {
    late GameContent content;

    setUpAll(() async => content = await loadBaseContent());

    test('раунды и сыгранные особые карты совпадают с тем, что видел движок при игре', () {
      final match = playBotMatch(
        content,
        realDeck(content, Faction.northernRealms, id: 'one'),
        realDeck(content, Faction.nilfgaard, id: 'two'),
      );
      final engine = GwentEngine(content.catalog, rules: content.rules);

      for (final me in Seat.values) {
        final view = engine.project(_replayed(engine, match), me);
        final facts = CampaignMatchFacts.fromMatch(
          record: match.record,
          engine: engine,
          catalog: content.catalog,
          finalView: view,
          me: me,
        );
        expect(facts.won, view.outcome!.winner == me);
        expect(facts.rounds.length, view.history.length);
        expect(
          facts.rounds.where((round) => round.won).length,
          view.history.where((round) => round.winner == me).length,
        );
        expect(facts.specialsPlayed, match.specialsPlayed[me], reason: '$me');
      }
      expect(
        match.specialsPlayed.values.reduce((a, b) => a + b),
        greaterThan(0),
        reason: 'в партии играли особые карты',
      );
    });

    test('журнал не от этого движка: ход отклоняется, бросается StateError', () {
      final match = playBotMatch(
        content,
        realDeck(content, Faction.northernRealms, id: 'one'),
        realDeck(content, Faction.nilfgaard, id: 'two'),
      );
      final engine = GwentEngine(content.catalog, rules: content.rules);
      final broken = match.record.moves.isEmpty
          ? match.record
          : match.record.adding(match.record.moves.first); // ход, который после конца партии отклоняется
      expect(
        () => CampaignMatchFacts.fromMatch(
          record: broken,
          engine: engine,
          catalog: content.catalog,
          finalView: match.finalView,
          me: Seat.one,
        ),
        throwsStateError,
      );
    });
  });
}

MatchState _replayed(MatchEngine engine, BotMatch match) => match.record.replay(engine);
