import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gwent/src/core/l10n/l10n.dart';
import 'package:gwent/src/core/presentation/components/gwent_button.dart';
import 'package:gwent/src/features/campaign/application/claim_starting_set.dart';
import 'package:gwent/src/features/campaign/application/get_campaign_deck.dart';
import 'package:gwent/src/features/campaign/application/list_campaign_decks.dart';
import 'package:gwent/src/features/campaign/application/load_campaign.dart';
import 'package:gwent/src/features/campaign/application/load_campaign_overview.dart';
import 'package:gwent/src/features/campaign/application/record_campaign_result.dart';
import 'package:gwent/src/features/campaign/application/watch_campaign_path.dart';
import 'package:gwent/src/features/campaign/domain/campaign_match_facts.dart';
import 'package:gwent/src/features/campaign/domain/campaign_path.dart';
import 'package:gwent/src/features/campaign/domain/campaign_repository.dart';
import 'package:gwent/src/features/campaign/presentation/campaign_cubit.dart';
import 'package:gwent/src/features/campaign/presentation/campaign_node_sheet.dart';
import 'package:gwent/src/features/campaign/presentation/campaign_screen.dart';
import 'package:gwent/src/features/content/application/load_game_content.dart';
import 'package:gwent/src/features/content/data/asset_content_source.dart';
import 'package:gwent/src/features/deck_builder/application/game_content_deck_rules_source.dart';

import '../../../support/fakes.dart';
import '../../../support/fonts.dart';
import '../../../support/localized_app.dart';
import '../../../support/screen_guards.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LoadGameContent content;
  late CampaignData data;
  late AppLocalizations l10n;
  late InMemoryCollectionRepository collection;
  late InMemoryCampaignRepository progress;
  late InMemoryDeckRepository decks;
  late InMemorySettingsRepository settings;
  late RecordCampaignResult record;
  late CampaignCubit cubit;
  late List<String> played;
  late int firstMatches;

  setUpAll(() async {
    await loadDesignFonts();
    content = LoadGameContent(AssetContentSource.basePack(rootBundle));
    data = (await LoadCampaign(content)())!;
    l10n = await AppLocalizations.delegate.load(const Locale('ru'));
  });

  setUp(() {
    collection = InMemoryCollectionRepository();
    progress = InMemoryCampaignRepository(collection);
    decks = InMemoryDeckRepository();
    settings = InMemorySettingsRepository();
    played = [];
    firstMatches = 0;
    record = RecordCampaignResult(
      LoadCampaign(content),
      progress,
      collection,
      decks,
      settings,
      FakeClock(DateTime.utc(2026, 10, 27)),
    );
  });

  Future<void> pumpTrail(
    WidgetTester tester, {
    Size size = const Size(390, 844),
    CampaignRepository? repository,
  }) async {
    final path = repository ?? progress;
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final campaign = LoadCampaign(content);
    cubit = CampaignCubit(
      WatchCampaignPath(campaign, path),
      LoadCampaignOverview(
        campaign,
        path,
        collection,
        GetCampaignDeck(ListCampaignDecks(decks, GameContentDeckRulesSource(content), collection), settings),
      ),
      ClaimStartingSet(campaign, path, settings, record),
    );
    // Подписка создана в зоне теста: её отмена завершается там же, ждать её снаружи нельзя.
    addTearDown(() => unawaited(cubit.close()));
    await tester.pumpWidget(
      BlocProvider.value(
        value: cubit,
        child: localizedScreen(
          CampaignScreen(
            onBack: () {},
            onPlay: played.add,
            onFirstMatch: () => firstMatches++,
            onPickDeck: (_) async {},
            onBuildDeck: () async {},
          ),
        ),
      ),
    );
    await settle(tester);
  }

  testWidgets('новый игрок: открыт только первый узел, остальные закрыты, кнопка «Назад» у края', (tester) async {
    await pumpTrail(tester);

    expect(find.text(l10n.campaignTitle), findsOneWidget);
    expect(find.text(data.text(data.catalog.firstNode.opponent.nameKey)), findsWidgets);
    expect(find.text(l10n.campaignChipOpen), findsNothing, reason: 'состояние показывает лист узла, а не тропа');
    expectNoFallbackTextStyle(tester);
    expectBackButtonAtEdge(tester);
  });

  testWidgets('лист первого узла: «Начать» ведёт в «Первую партию»', (tester) async {
    await pumpTrail(tester);

    await tester.tap(find.text(l10n.campaignContinue(data.text(data.catalog.firstNode.opponent.nameKey))));
    await settle(tester);
    await tester.tap(find.text(l10n.campaignStartFirstMatch));
    await settle(tester);

    expect(firstMatches, 1);
  });

  testWidgets('кто прошёл «Первую партию» в обучении, при входе получает стартовый набор и колоду', (tester) async {
    await settings.save(settings.saved.copyWith(firstMatchPassed: true));

    await pumpTrail(tester);

    expect(find.text(l10n.campaignStartingSetLabel.toUpperCase()), findsOneWidget);
    expect((await tester.runAsync(collection.load))!.total, greaterThan(0));
    expect(await tester.runAsync(() => decks.watchAll().first), hasLength(1));

    await tester.tap(find.text(l10n.campaignToTrail));
    await settle(tester);

    expect(find.text(l10n.campaignStartingSetLabel.toUpperCase()), findsNothing);
    expect(
      find.text(l10n.campaignDeckPill(l10n.campaignDeckNotChosen)),
      findsNothing,
      reason: 'колода кампании выбрана',
    );
  });

  testWidgets('выдача стартового набора не удалась: тропа всё равно открывается', (tester) async {
    await settings.save(settings.saved.copyWith(firstMatchPassed: true));

    await pumpTrail(tester, repository: _FailsFirstLoad(progress));

    expect(find.text(l10n.campaignTitle), findsOneWidget);
    expect(find.text(l10n.campaignStartingSetLabel.toUpperCase()), findsNothing, reason: 'награда не выдана');
  });

  testWidgets('после босса Белого сада тропа ведёт в Велен; Новиград и Скеллиге закрыты, «скоро» нет', (tester) async {
    await tester.runAsync(() async {
      for (final id in ['c1-00', 'c1-01', 'c1-02', 'c1-03', 'c1-05', 'c1-06', 'c1-08', 'c1-09']) {
        await progress.recordWin(NodeWin(nodeId: id, at: DateTime.utc(2026, 10, 27)));
      }
    });
    await pumpTrail(tester);

    expect(find.text(l10n.campaignContinue('Охотник из Велена')), findsOneWidget);
    expect(find.text('Велен'), findsWidgets);
    await tester.scrollUntilVisible(find.text(l10n.campaignChapterLocked(3)), 300, scrollable: find.byType(Scrollable));
    expect(find.text(l10n.campaignChapterLocked(2)), findsOneWidget, reason: 'Новиград ждёт конца Велена');
    expect(find.text(l10n.campaignChapterLocked(3)), findsOneWidget, reason: 'Скеллиге ждёт конца Новиграда');
    expect(find.text(l10n.campaignChapterSoon), findsNothing);
    expectNoFallbackTextStyle(tester);
  });

  testWidgets('закрытый узел: «В бой» недоступна, награда силуэтом без имён карт', (tester) async {
    await tester.runAsync(() => record('c1-00', CampaignMatchFacts(won: true)));
    await pumpTrail(tester);
    final overview = (await tester.runAsync(
      LoadCampaignOverview(
        LoadCampaign(content),
        progress,
        collection,
        GetCampaignDeck(ListCampaignDecks(decks, GameContentDeckRulesSource(content), collection), settings),
      ).call,
    ))!;
    final closed = overview.path.node('c1-02')!;
    expect(closed.status, NodeStatus.locked);

    await tester.pumpWidget(
      localizedScreen(CampaignNodeSheet(overview: overview, view: closed)),
    );
    await tester.pump();

    expect(find.text(l10n.campaignToBattle), findsOneWidget);
    final battle = tester.widget<GwentButton>(find.widgetWithText(GwentButton, l10n.campaignToBattle));
    expect(battle.onPressed, isNull, reason: 'узел закрыт');
    final rules = data.pack.rules;
    for (final grant in closed.node.reward) {
      final nameKey = rules.squadCardsById[grant.cardId]?.nameKey ?? rules.specialCardsById[grant.cardId]?.nameKey;
      if (nameKey == null) continue;
      expect(find.text(data.text(nameKey)), findsNothing, reason: 'награда скрыта до победы');
    }
  });
}

/// Даёт настоящему времени дойти до загрузки пакета и кадрам отрисоваться.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Хранилище прогресса, первое чтение которого падает: так «ломается» выдача стартового набора.
final class _FailsFirstLoad implements CampaignRepository {
  _FailsFirstLoad(this._inner);

  final CampaignRepository _inner;
  var _failed = false;

  @override
  Future<Map<String, NodeProgress>> load() {
    if (_failed) return _inner.load();
    _failed = true;
    return Future.error(StateError('база недоступна'));
  }

  @override
  Stream<Map<String, NodeProgress>> watch() => _inner.watch();

  @override
  Future<void> recordWin(NodeWin win) => _inner.recordWin(win);
}
