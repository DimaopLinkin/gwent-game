import 'package:flutter_test/flutter_test.dart';
import 'package:gwent/src/features/campaign/application/choose_campaign_deck.dart';
import 'package:gwent/src/features/campaign/application/get_campaign_deck.dart';
import 'package:gwent/src/features/campaign/application/list_campaign_decks.dart';
import 'package:gwent/src/features/deck_builder/application/create_starter_deck.dart';
import 'package:gwent/src/features/deck_builder/application/deck_selection_lock.dart';
import 'package:gwent/src/features/deck_builder/application/get_active_deck.dart';
import 'package:gwent/src/features/deck_builder/domain/deck_exceptions.dart';
import 'package:gwent/src/features/deck_builder/domain/deck_issue.dart';

import '../../../support/deck_rules_fixtures.dart';
import '../../../support/fakes.dart';

void main() {
  late InMemoryDeckRepository decks;
  late InMemoryCollectionRepository collection;
  late InMemorySettingsRepository settings;
  late FakeDeckRulesSource rules;

  // Колода Скеллиге из маленького пакета: лидер Крах, 3 воина, Кэрис, Геральт и мороз.
  final skellige = smallSkelligeDeck(id: 'skellige', updatedAt: DateTime.utc(2026, 10, 20));
  final everything = {Small.crach: 1, Small.warrior: 3, Small.cerys: 1, Small.geralt: 1, Small.frost: 1};

  setUp(() {
    decks = InMemoryDeckRepository([skellige]);
    collection = InMemoryCollectionRepository();
    settings = InMemorySettingsRepository();
    rules = FakeDeckRulesSource();
  });

  ListCampaignDecks list() => ListCampaignDecks(decks, rules, collection);
  ChooseCampaignDeck choose() => ChooseCampaignDeck(decks, rules, collection, settings);
  GetCampaignDeck get() => GetCampaignDeck(list(), settings);

  group('список колод кампании', () {
    test('колода негодна, пока карты не открыты, и годна, когда открыты все', () async {
      final before = (await list()()).single;
      expect(before.isReady, isFalse);
      expect(before.issues, contains(const LeaderNotOwned(Small.crach)));

      await collection.grant(everything);

      expect((await list()()).single.isReady, isTrue);
    });

    test('колоды не меняются: список только оценивает их', () async {
      await list()();

      expect(await decks.findById('skellige'), skellige);
    });
  });

  group('выбор колоды кампании', () {
    test('годная колода запоминается в настройках кампании', () async {
      await collection.grant(everything);

      await choose()('skellige');

      expect(settings.saved.campaignDeckId, 'skellige');
    });

    test('колода с неоткрытыми картами отклоняется с проблемами, выбор не меняется', () async {
      await expectLater(
        choose()('skellige'),
        throwsA(
          isA<InvalidDeckException>()
              .having((e) => e.deckId, 'deckId', 'skellige')
              .having((e) => e.issues, 'issues', contains(const LeaderNotOwned(Small.crach))),
        ),
      );
      expect(settings.saved.campaignDeckId, isNull);
    });

    test('колода, нарушающая обычные правила, отклоняется, даже когда все карты открыты', () async {
      await decks.save(smallSkelligeDeck(id: 'short', cards: const {Small.warrior: 3, Small.cerys: 1}));
      await collection.grant(everything);

      await expectLater(
        choose()('short'),
        throwsA(isA<InvalidDeckException>().having((e) => e.issues, 'issues', [isA<DeckRuleViolation>()])),
      );
    });

    test('колоды нет: DeckNotFoundException', () async {
      await expectLater(choose()('нет такой'), throwsA(isA<DeckNotFoundException>()));
    });

    test('выбор не трогает активные колоды свободной игры', () async {
      await collection.grant(everything);

      await choose()('skellige');

      expect(await decks.findActiveDeckId(Small.skellige), isNull);
    });

    test('свободная игра не знает о коллекции: активная колода выбирается при пустой коллекции', () async {
      final getActive = GetActiveDeck(
        decks,
        rules,
        CreateStarterDeck(decks, FakeClock(DateTime.utc(2026, 10, 26)), SequentialIdGenerator()),
        DeckSelectionLock(),
      );

      expect((await getActive(Small.skellige)).id, 'skellige');
    });
  });

  group('колода для партии кампании', () {
    test('выбранная колода, пока она годится', () async {
      await collection.grant(everything);
      final other = smallSkelligeDeck(id: 'newer', updatedAt: DateTime.utc(2026, 10, 25));
      await decks.save(other);
      await choose()('skellige');

      expect((await get()())?.id, 'skellige');
    });

    test('выбор потерял годность: берётся самая недавняя годная колода', () async {
      await collection.grant(everything);
      await decks.save(smallSkelligeDeck(id: 'newer', updatedAt: DateTime.utc(2026, 10, 25)));
      await choose()('skellige');
      await decks.save(skellige.copyWith(leaderId: Small.bran));

      expect((await get()())?.id, 'newer');
    });

    test('выбора не было: берётся самая недавно изменённая из нескольких годных колод', () async {
      await collection.grant(everything);
      await decks.save(smallSkelligeDeck(id: 'newer', updatedAt: DateTime.utc(2026, 10, 25)));

      expect((await get()())?.id, 'newer');
    });

    test('выбранную колоду удалили: берётся годная колода, выбор не падает', () async {
      await collection.grant(everything);
      await choose()('skellige');
      await decks.delete('skellige');
      await decks.save(smallSkelligeDeck(id: 'other'));

      expect((await get()())?.id, 'other');
    });

    test('годных колод нет: null, и колода сама не создаётся', () async {
      expect(await get()(), isNull);
      expect(await decks.watchAll().first, [skellige]);
    });
  });
}
