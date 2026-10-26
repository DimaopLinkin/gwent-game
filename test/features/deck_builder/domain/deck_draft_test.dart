import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gwent/src/features/content/application/load_game_content.dart';
import 'package:gwent/src/features/content/data/asset_content_source.dart';
import 'package:gwent/src/features/deck_builder/application/game_content_deck_rules_source.dart';
import 'package:gwent/src/features/deck_builder/domain/collection_card.dart';
import 'package:gwent/src/features/deck_builder/domain/deck_issue.dart';

import '../../../support/deck_rules_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final rules = smallDeckRules;
  DeckDraft draft({Map<String, int> cards = const {}, String? leader = Small.crach}) =>
      DeckDraft(name: 'Черновик', factionId: Small.skellige, leaderId: leader, cards: cards);

  group('DeckDraft', () {
    test('копии добавляются и убираются, без копий карта уходит из состава', () {
      final one = draft().withAdded(Small.warrior);
      final two = one.withAdded(Small.warrior);

      expect(two.copiesOf(Small.warrior), 2);
      expect(two.withRemoved(Small.warrior).cards, {Small.warrior: 1});
      expect(one.withRemoved(Small.warrior).cards, isEmpty);
      expect(draft().withRemoved(Small.warrior).cards, isEmpty, reason: 'убрать то, чего нет, не ломает состав');
      expect(one.cards, {Small.warrior: 1}, reason: 'черновик неизменяем');
    });

    test('смена фракции и сброс лидера', () {
      final changed = draft().copyWith(factionId: Small.monsters, clearLeader: true);

      expect(changed.factionId, Small.monsters);
      expect(changed.leaderId, isNull);
      expect(draft().copyWith(name: 'Другое').leaderId, Small.crach);
    });
  });

  group('коллекция', () {
    test('карты своей фракции и нейтральные в порядке пакета; созданные не входят', () {
      final ids = rules.collectionFor(Small.skellige).map((card) => card.id);

      expect(ids, [
        Small.warrior,
        Small.cerys,
        Small.geralt,
        Small.vesemir,
        Small.frost,
        Small.mardroeme,
        Small.horn,
      ]);
      expect(rules.collectionFor(Small.monsters).map((card) => card.id), isNot(contains(Small.warrior)));
    });

    test('число копий и признак нейтральной карты берутся из набора карт', () {
      final byId = rules.cardsById;

      expect(byId[Small.warrior]!.maxCopies, 3);
      expect(byId[Small.warrior]!.isNeutral, isFalse);
      expect(byId[Small.vesemir]!.maxCopies, 2);
      expect(byId[Small.vesemir]!.isNeutral, isTrue);
      expect(byId[Small.frost]!.isSpecial, isTrue);
      expect(byId[Small.vildkaarl], isNull);
    });

    test('в настоящем наборе: герой в одном экземпляре, погода отделена от особых, ряды известны', () async {
      final source = GameContentDeckRulesSource(LoadGameContent(AssetContentSource.basePack(rootBundle)));
      final real = await source.load();
      final cards = real.allCards;

      expect(cards.where((card) => card.kind == CollectionKind.hero), isNotEmpty);
      expect(cards.where((card) => card.kind == CollectionKind.hero).every((card) => card.maxCopies == 1), isTrue);
      expect(cards.where((card) => card.kind == CollectionKind.weather), isNotEmpty);
      expect(cards.where((card) => card.kind == CollectionKind.special), isNotEmpty);
      expect(cards.where((card) => card.isUnit).every((card) => card.placement != null), isTrue);
      expect(cards.where((card) => card.isSpecial).every((card) => card.placement == null), isTrue);
      expect(cards.every((card) => card.maxCopies >= 1), isTrue);
    });
  });

  group('счётчики и ограничения', () {
    test('считают отряды, особые карты, силу и героев', () {
      final stats = rules.statsOf(draft(cards: {Small.warrior: 3, Small.geralt: 1, Small.frost: 2, 'нет такой': 4}));

      expect(
        (stats.total, stats.units, stats.specials, stats.power, stats.heroes),
        (6, 4, 2, 20, 0),
        reason: 'карты вне набора не считаются',
      );
    });

    test('добавить можно, пока есть копии; потом отказ', () {
      final warrior = rules.cardsById[Small.warrior]!;

      expect(rules.refusalToAdd(draft(), warrior), isNull);
      expect(rules.refusalToAdd(draft(cards: {Small.warrior: 2}), warrior), isNull);
      expect(rules.refusalToAdd(draft(cards: {Small.warrior: 3}), warrior), AddRefusal.allCopiesInDeck);
    });

    test('особых карт не больше максимума', () {
      final horn = rules.cardsById[Small.horn]!;
      final full = draft(cards: {Small.frost: 2});

      expect(rules.refusalToAdd(full, horn), AddRefusal.specialLimit);
      expect(
        rules.refusalToAdd(full, rules.cardsById[Small.warrior]!),
        isNull,
        reason: 'отряды лимит особых не трогает',
      );
    });

    test('второй экземпляр героя запрещён отдельным отказом', () {
      const hero = CollectionCard(
        id: 'hero',
        name: 'Герой',
        fractionId: Small.common,
        isNeutral: true,
        kind: CollectionKind.hero,
        maxCopies: 1,
      );

      expect(rules.refusalToAdd(draft(cards: {'hero': 1}), hero), AddRefusal.heroLimit);
    });
  });

  group('проверка черновика', () {
    test('без лидера проблема — лидер', () {
      final issues = rules.checkDraft(draft(leader: null, cards: {Small.warrior: 3, Small.cerys: 1, Small.geralt: 1}));

      expect(issues, isNotEmpty);
    });

    test('годный черновик без проблем, с лидером другой фракции — лидер не из фракции', () {
      final cards = {Small.warrior: 3, Small.cerys: 1, Small.geralt: 1};

      expect(rules.checkDraft(draft(cards: cards)), isEmpty);
      expect(rules.checkDraft(draft(leader: Small.eredin, cards: cards)), contains(isA<DeckIssue>()));
    });
  });
}
