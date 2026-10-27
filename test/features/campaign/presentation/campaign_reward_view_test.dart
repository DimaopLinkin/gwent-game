import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gwent/src/core/l10n/l10n.dart';
import 'package:gwent/src/core/presentation/card/card_face.dart';
import 'package:gwent/src/core/presentation/card/gwent_card.dart';
import 'package:gwent/src/features/campaign/application/load_campaign.dart';
import 'package:gwent/src/features/campaign/application/record_campaign_result.dart';
import 'package:gwent/src/features/campaign/domain/campaign_match_facts.dart';
import 'package:gwent/src/features/campaign/presentation/campaign_reward_view.dart';
import 'package:gwent/src/features/content/application/load_game_content.dart';
import 'package:gwent/src/features/content/data/asset_content_source.dart';

import '../../../support/fakes.dart';
import '../../../support/fonts.dart';
import '../../../support/localized_app.dart';
import '../../../support/screen_guards.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LoadGameContent content;
  late CampaignData data;
  late AppLocalizations l10n;

  setUpAll(() async {
    await loadDesignFonts();
    content = LoadGameContent(AssetContentSource.basePack(rootBundle));
    data = (await LoadCampaign(content)())!;
    l10n = await AppLocalizations.delegate.load(const Locale('ru'));
  });

  /// Победа в узлах по порядку: сценарии строятся в настоящей зоне, их очереди не должны ждать кадров.
  Future<CampaignWon> win(WidgetTester tester, List<String> nodeIds) async {
    final won = await tester.runAsync(() async {
      final collection = InMemoryCollectionRepository();
      final record = RecordCampaignResult(
        LoadCampaign(content),
        InMemoryCampaignRepository(collection),
        collection,
        InMemoryDeckRepository(),
        InMemorySettingsRepository(),
        FakeClock(DateTime.utc(2026, 10, 27)),
      );
      CampaignResult? last;
      for (final id in nodeIds) {
        last = await record(id, const CampaignMatchFacts.withoutMatch());
      }
      return last;
    });
    return won! as CampaignWon;
  }

  Future<void> pumpReward(
    WidgetTester tester,
    CampaignWon won, {
    ValueChanged<String>? onNext,
    VoidCallback? onTrail,
  }) async {
    tester.view
      ..physicalSize = const Size(390, 844)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      localizedScreen(
        CampaignRewardView(
          won: won,
          data: data,
          onNext: onNext ?? (_) {},
          onTrail: onTrail ?? () {},
          onBuildDeck: () {},
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('стартовый набор показан сразу, без переворотов, «К тропе» возвращает на тропу', (tester) async {
    final won = await win(tester, ['c1-00']);
    var trail = 0;

    await pumpReward(tester, won, onTrail: () => trail++);

    expect(find.text(l10n.campaignStartingSetLabel.toUpperCase()), findsOneWidget);
    expect(find.text(l10n.campaignSkip), findsNothing, reason: 'набор большой: переворачивать нечего');
    expectNoFallbackTextStyle(tester);

    await tester.tap(find.text(l10n.campaignToTrail));
    expect(trail, 1);
  });

  testWidgets('награда узла лежит рубашкой вверх до касания, «Пропустить» открывает всё', (tester) async {
    final won = await win(tester, ['c1-00', 'c1-01']);
    expect(won.firstWinReward, hasLength(1));

    await pumpReward(tester, won);

    expect(
      find.byWidgetPredicate((w) => w is GwentCard && w.face is CardBackFace),
      findsOneWidget,
      reason: 'карта закрыта',
    );
    await tester.tap(find.text(l10n.campaignSkip));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.byWidgetPredicate((w) => w is GwentCard && w.face is CardBackFace), findsNothing);
    expect(find.text(l10n.campaignToTrail), findsOneWidget);
    expectNoFallbackTextStyle(tester);
  });

  List<String> through(String nodeId) {
    final ids = [for (final node in data.catalog.nodes) node.id];
    return ids.sublist(0, ids.indexOf(nodeId) + 1);
  }

  Future<void> revealAll(WidgetTester tester) async {
    if (find.text(l10n.campaignSkip).evaluate().isNotEmpty) {
      await tester.tap(find.text(l10n.campaignSkip));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
    }
  }

  testWidgets('босс Велена главу не заканчивает: Новиград не объявляется, «Дальше» ведёт к Замковому воеводе', (
    tester,
  ) async {
    final won = await win(tester, through('c2-11'));
    expect(won.chapterCleared, isNull);
    String? next;

    await pumpReward(tester, won, onNext: (id) => next = id);
    await revealAll(tester);

    expect(find.text(l10n.campaignChapterOpened(3, data.text(data.catalog.chapters[2].nameKey))), findsNothing);
    await tester.tap(find.text(l10n.campaignNext(data.text(data.catalog.nodesById['c2-12']!.opponent.nameKey))));
    expect(next, 'c2-12');
    expectNoFallbackTextStyle(tester);
  });

  testWidgets('последняя партия Велена заканчивает главу и объявляет Новиград', (tester) async {
    final won = await win(tester, through('c2-12'));
    expect(won.chapterCleared!.id, 'c2');

    await pumpReward(tester, won);
    await revealAll(tester);

    expect(find.text(l10n.campaignChapterOpened(3, data.text(data.catalog.chapters[2].nameKey))), findsOneWidget);
    expect(find.text(l10n.campaignChapterClearedRibbon(2).toUpperCase()), findsOneWidget);
    expectNoFallbackTextStyle(tester);
  });
}
