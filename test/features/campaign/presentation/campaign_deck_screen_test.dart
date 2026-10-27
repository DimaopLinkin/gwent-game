import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gwent/src/core/l10n/l10n.dart';
import 'package:gwent/src/core/presentation/components/gwent_button.dart';
import 'package:gwent/src/features/campaign/application/choose_campaign_deck.dart';
import 'package:gwent/src/features/campaign/application/claim_starting_set.dart';
import 'package:gwent/src/features/campaign/application/get_campaign_deck.dart';
import 'package:gwent/src/features/campaign/application/list_campaign_decks.dart';
import 'package:gwent/src/features/campaign/application/load_campaign.dart';
import 'package:gwent/src/features/campaign/application/record_campaign_result.dart';
import 'package:gwent/src/features/campaign/presentation/campaign_deck_cubit.dart';
import 'package:gwent/src/features/campaign/presentation/campaign_deck_screen.dart';
import 'package:gwent/src/features/campaign/presentation/campaign_deck_state.dart';
import 'package:gwent/src/features/content/application/load_game_content.dart';
import 'package:gwent/src/features/content/data/asset_content_source.dart';
import 'package:gwent/src/features/deck_builder/application/game_content_deck_rules_source.dart';
import 'package:gwent/src/features/deck_builder/domain/deck.dart';

import '../../../support/fakes.dart';
import '../../../support/fonts.dart';
import '../../../support/localized_app.dart';
import '../../../support/screen_guards.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LoadGameContent content;
  late AppLocalizations l10n;
  late InMemoryCollectionRepository collection;
  late InMemoryCampaignRepository progress;
  late InMemoryDeckRepository decks;
  late InMemorySettingsRepository settings;
  late List<String> battles;
  late int chosen;
  late List<String> edited;
  late CampaignDeckCubit lastCubit;
  Future<void> Function(String deckId)? whileEditing;

  setUpAll(() async {
    await loadDesignFonts();
    content = LoadGameContent(AssetContentSource.basePack(rootBundle));
    // Пакет читается один раз здесь: чтение, начатое в зоне теста, не дожило бы до следующего теста.
    await LoadCampaign(content)();
    l10n = await AppLocalizations.delegate.load(const Locale('ru'));
  });

  setUp(() {
    collection = InMemoryCollectionRepository();
    progress = InMemoryCampaignRepository(collection);
    decks = InMemoryDeckRepository();
    settings = InMemorySettingsRepository();
    battles = [];
    chosen = 0;
    edited = [];
    whileEditing = null;
  });

  Future<void> pumpDecks(WidgetTester tester, {String? nodeId}) async {
    final rules = GameContentDeckRulesSource(content);
    final list = ListCampaignDecks(decks, rules, collection);
    final cubit = CampaignDeckCubit(
      list,
      GetCampaignDeck(list, settings),
      ChooseCampaignDeck(decks, rules, collection, settings),
      LoadCampaign(content),
      nodeId: nodeId,
    );
    lastCubit = cubit;
    // Подписка создана в зоне теста: её отмена завершается там же, ждать её снаружи нельзя.
    addTearDown(() => unawaited(cubit.close()));
    await tester.pumpWidget(
      BlocProvider.value(
        value: cubit,
        child: localizedScreen(
          CampaignDeckScreen(
            onBack: () {},
            onBattle: battles.add,
            onChosen: () => chosen++,
            onBuild: () async {},
            onEdit: (deckId) async {
              edited.add(deckId);
              await whileEditing?.call(deckId);
            },
          ),
        ),
      ),
    );
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  /// Выдаёт стартовый набор настоящим сценарием. Сценарии строятся и работают в настоящей зоне: их очереди
  /// (`Future`), созданные в зоне теста, ждали бы кадров.
  Future<void> issueStartingSet(WidgetTester tester) async {
    final ready = await tester.runAsync(() async {
      await settings.save(settings.saved.copyWith(firstMatchPassed: true));
      final campaign = LoadCampaign(content);
      final claim = ClaimStartingSet(
        campaign,
        progress,
        settings,
        RecordCampaignResult(campaign, progress, collection, decks, settings, FakeClock(DateTime.utc(2026, 10, 27))),
      );
      await claim();
      return (await ListCampaignDecks(decks, GameContentDeckRulesSource(content), collection)()).any((d) => d.isReady);
    });
    expect(ready, isTrue);
  }

  testWidgets('без колод: пояснение и «Собрать колоду» главным действием, «Назад» у края', (tester) async {
    await pumpDecks(tester);

    expect(find.text(l10n.campaignNoDeckTitle), findsOneWidget);
    expect(find.text(l10n.campaignToBattle), findsNothing);
    expect(find.widgetWithText(GwentButton, l10n.campaignBuildDeck), findsOneWidget);
    expectNoFallbackTextStyle(tester);
    expectBackButtonAtEdge(tester);
  });

  testWidgets('годная колода выбрана, «В бой» запоминает её и ведёт на узел', (tester) async {
    await issueStartingSet(tester);
    await pumpDecks(tester, nodeId: 'c1-01');

    expect(find.text(l10n.campaignDeckReady.toUpperCase()), findsOneWidget);
    await tester.tap(find.text(l10n.campaignToBattle));
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(battles, ['c1-01']);
    expect(settings.saved.campaignDeckId, isNotNull);
  });

  testWidgets('без узла выбор запоминается и экран сообщает, что готово', (tester) async {
    await issueStartingSet(tester);
    await pumpDecks(tester);

    await tester.tap(find.text(l10n.campaignChooseDeck));
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(chosen, 1);
    expect(battles, isEmpty);
  });

  testWidgets('«Изменить» открывает конструктор кампании для этой колоды, не выбирая её', (tester) async {
    await issueStartingSet(tester);
    await pumpDecks(tester);
    final deckId = (await tester.runAsync(() => decks.watchAll().first))!.single.id;

    await tester.tap(find.text(l10n.campaignEditDeck));
    for (var i = 0; i < 3; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(edited, [deckId]);
    expect(chosen, 0);
    expectNoFallbackTextStyle(tester);
  });

  testWidgets('негодную колоду тоже можно изменить: так её доводят до годной', (tester) async {
    await issueStartingSet(tester);
    final starter = (await tester.runAsync(() => decks.watchAll().first))!.single;
    await tester.runAsync(() => decks.save(starter.copyWith(cards: const {}, name: 'Пустая')));
    await pumpDecks(tester);

    expect(find.text(l10n.campaignDeckReady.toUpperCase()), findsNothing, reason: 'колода негодна');
    expect(find.text(l10n.campaignNoDeckTitle), findsOneWidget, reason: 'пояснение стоит над списком негодных');
    await tester.tap(find.text(l10n.campaignEditDeck));
    await tester.pump();

    expect(edited, [starter.id]);
  });

  testWidgets('после правки список читается заново: негодная колода становится годной', (tester) async {
    await issueStartingSet(tester);
    final starter = (await tester.runAsync(() => decks.watchAll().first))!.single;
    await tester.runAsync(() => decks.save(starter.copyWith(cards: const {}, name: 'Пустая')));
    // Игрок в конструкторе возвращает колоде карты.
    whileEditing = (_) => decks.save(starter);
    await pumpDecks(tester);
    expect(find.text(l10n.campaignDeckReady.toUpperCase()), findsNothing);

    await tester.tap(find.text(l10n.campaignEditDeck));
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.text(l10n.campaignDeckReady.toUpperCase()), findsOneWidget);
    expect(find.text(l10n.campaignChooseDeck), findsOneWidget);
  });

  testWidgets('«Изменить» у невыбранной колоды не меняет выбор', (tester) async {
    await issueStartingSet(tester);
    final starter = (await tester.runAsync(() => decks.watchAll().first))!.single;
    final second = starter.copyWith(name: 'Вторая', updatedAt: DateTime.utc(2020));
    await tester.runAsync(
      () => decks.save(
        Deck(
          id: 'second',
          name: second.name,
          factionId: second.factionId,
          leaderId: second.leaderId,
          cards: second.cards,
          updatedAt: second.updatedAt,
        ),
      ),
    );
    await pumpDecks(tester);
    final before = (lastCubit.state as CampaignDeckLoaded).selectedId;
    expect(before, isNotNull);
    final other = before == starter.id ? 'second' : starter.id;

    await tester.tap(find.text(l10n.campaignEditDeck).at(before == starter.id ? 1 : 0));
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(edited, [other], reason: 'открыта именно невыбранная колода');
    expect((lastCubit.state as CampaignDeckLoaded).selectedId, before);
  });
}
