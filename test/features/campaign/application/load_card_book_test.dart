import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gwent/src/features/campaign/application/load_campaign.dart';
import 'package:gwent/src/features/campaign/application/load_card_book.dart';
import 'package:gwent/src/features/campaign/domain/campaign_totals.dart';
import 'package:gwent/src/features/campaign/domain/card_book.dart';
import 'package:gwent/src/features/content/application/load_game_content.dart';
import 'package:gwent/src/features/content/data/asset_content_source.dart';

import '../../../support/fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LoadCampaign campaign;
  late InMemoryCollectionRepository collection;

  setUpAll(() async {
    campaign = LoadCampaign(LoadGameContent(AssetContentSource.basePack(rootBundle)));
    await campaign();
  });

  setUp(() => collection = InMemoryCollectionRepository());

  Future<LoadedCardBook> load() async => (await LoadCardBook(campaign, collection)())!;

  test('сумма по разделам равна «Книге N/M» на тропе, у нового игрока открыто 0', () async {
    final loaded = await load();

    expect(loaded.book.opened, 0);
    expect(loaded.book.total, totalCardCopies(loaded.data.pack.rules));
  });

  test('разделы: фракции с колодой в порядке пакета, затем общие карты без лидеров', () async {
    final book = (await load()).book;
    final rules = (await load()).data.pack.rules;

    expect(book.sections.last.id, CardBook.commonId);
    expect(book.sections.last.leaders, isEmpty);
    expect(
      book.sections.take(book.sections.length - 1).map((section) => section.fractionId),
      [
        for (final fraction in rules.fractions)
          if (fraction.isDeck) fraction.id,
      ],
    );
    expect(book.section('нет такого'), isNull);
  });

  test('открытые копии попадают в свой раздел и не больше числа копий', () async {
    final before = await load();
    final section = before.book.sections.first;
    final squad = section.squads.firstWhere((card) => card.total > 1);
    final leader = section.leaders.first;
    await collection.grant({squad.cardId: squad.total + 5, leader.cardId: 1});

    final after = (await load()).book.sections.first;

    expect(
      after.squads.firstWhere((card) => card.cardId == squad.cardId).owned,
      squad.total,
      reason: 'не больше total',
    );
    expect(after.openedSquads, squad.total);
    expect(after.openedLeaders, 1);
    expect(after.opened, squad.total + 1);
    expect((await load()).book.sections.skip(1).every((s) => s.opened == 0), isTrue);
  });

  test('отряды идут героями вперёд и от сильных к слабым', () async {
    final loaded = await load();
    final rules = loaded.data.pack.rules;

    for (final section in loaded.book.sections) {
      final cards = [for (final card in section.squads) rules.squadCardsById[card.cardId]!];
      final firstOrdinary = cards.indexWhere((card) => !card.isHero);
      if (firstOrdinary > 0) expect(cards.skip(firstOrdinary).any((card) => card.isHero), isFalse);
      final heroes = cards.where((card) => card.isHero).map((card) => card.strength).toList();
      expect(heroes, [...heroes]..sort((a, b) => b.compareTo(a)));
    }
  });
}
