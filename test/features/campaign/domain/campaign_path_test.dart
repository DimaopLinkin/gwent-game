import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gwent/src/features/campaign/application/load_campaign.dart';
import 'package:gwent/src/features/campaign/domain/campaign_path.dart';
import 'package:gwent/src/features/campaign/domain/campaign_repository.dart';
import 'package:gwent/src/features/content/application/load_game_content.dart';
import 'package:gwent/src/features/content/data/asset_content_source.dart';
import 'package:gwent_content/gwent_content.dart' show NodeKind;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late CampaignData data;

  setUpAll(() async {
    data = (await LoadCampaign(LoadGameContent(AssetContentSource.basePack(rootBundle)))())!;
  });

  Map<String, NodeProgress> passed(Iterable<String> nodeIds) => {
    for (final id in nodeIds) id: NodeProgress(nodeId: id, wins: 1, firstWinAt: DateTime.utc(2026, 10, 27)),
  };

  CampaignPath path([Iterable<String> passedIds = const []]) => CampaignPath.build(data.catalog, passed(passedIds));

  String status(CampaignPath path, String nodeId) => path.node(nodeId)!.status.name;

  test('новый игрок: открыта только «Первая партия», остальное закрыто, кампания не начата', () {
    final fresh = path();
    expect(fresh.started, isFalse);
    expect(fresh.current!.node.id, 'c1-00');
    expect(fresh.nodes.where((node) => node.status == NodeStatus.open).map((node) => node.node.id), ['c1-00']);
    expect(fresh.passedCount, 0);
    expect(fresh.totalCount, 49);
  });

  test('победа открывает следующий основной узел; заказ открывается на указанном узле и не мешает «Продолжить»', () {
    final afterStart = path(['c1-00', 'c1-01', 'c1-02', 'c1-03']);
    expect(status(afterStart, 'c1-04'), 'open', reason: 'заказ «Трактирщица Эльза» открыт победой в c1-03');
    expect(status(afterStart, 'c1-05'), 'open');
    expect(afterStart.current!.node.id, 'c1-05', reason: 'основной путь идёт раньше заказов');
    expect(status(afterStart, 'c1-07'), 'locked', reason: 'заказ c1-07 ждёт c1-06');
  });

  test('после основного пути главы 1 заказы ждут, а «Продолжить» ведёт в главу 2', () {
    final afterBoss = path(['c1-00', 'c1-01', 'c1-02', 'c1-03', 'c1-05', 'c1-06', 'c1-08', 'c1-09']);
    expect(afterBoss.nodes.where((node) => node.status == NodeStatus.open).map((node) => node.node.id), [
      'c1-04',
      'c1-07',
      'c2-00',
    ]);
    expect(afterBoss.current!.node.id, 'c2-00', reason: 'основной путь идёт раньше заказов');
  });

  test('основной путь пройден, остались заказы: «Продолжить» ведёт на заказ, а шапка остаётся в последней главе', () {
    final ids = [for (final node in data.catalog.nodes) node.id];
    final mains = [
      for (final node in data.catalog.nodes)
        if (node.kind != NodeKind.order) node.id,
    ];
    final onlyOrders = path(mains);

    expect(
      onlyOrders.nodes.every((node) => node.node.kind == NodeKind.order || node.status == NodeStatus.passed),
      isTrue,
    );
    expect(onlyOrders.current!.node.kind, NodeKind.order);
    expect(onlyOrders.current!.node.id, 'c1-04', reason: 'первый открытый заказ каталога');
    expect(onlyOrders.currentChapter!.chapter.number, 4, reason: 'главы 1–4 пройдены, шапка в Скеллиге');
    expect(onlyOrders.chapters.every((chapter) => chapter.isCleared), isTrue);

    final everything = path(ids);
    expect(everything.current, isNull);
    expect(everything.currentChapter!.chapter.number, 4);
  });

  test('заказы не мешают закончить главу 3: Скеллиге открывает босс Новиграда без заказов', () {
    final mainsUpToBoss = [
      for (final node in data.catalog.nodes)
        if (node.kind != NodeKind.order) node.id,
    ].takeWhile((id) => id != 'c4-00').toList();

    final done = path(mainsUpToBoss);

    expect(done.chapters[2].isCleared, isTrue);
    expect(done.chapters[2].passedCount, 11, reason: 'четыре заказа главы 3 остались непройденными');
    expect(done.node('c4-00')!.status, NodeStatus.open);
  });

  test('глава 1 пройдена победой над боссом: глава 2 открывается, главы 3 и 4 закрыты до своих боссов', () {
    final cleared = path(['c1-00', 'c1-01', 'c1-02', 'c1-03', 'c1-05', 'c1-06', 'c1-08', 'c1-09']);
    final chapter1 = cleared.chapters.first;
    expect(chapter1.isCleared, isTrue);
    expect(chapter1.passedCount, 8);
    expect(chapter1.totalCount, 10);
    expect(cleared.chapters.every((chapter) => !chapter.isComingSoon), isTrue, reason: 'все главы выпущены');
    expect(cleared.chapters[1].isUnlocked, isTrue);
    expect(cleared.node('c2-00')!.status, NodeStatus.open);
    expect(cleared.node('c2-00')!.isPlayable, isTrue);
    expect(cleared.chapters.skip(2).every((chapter) => !chapter.isUnlocked), isTrue);
    expect(cleared.node('c3-00')!.isPlayable, isFalse, reason: 'глава 3 ждёт босса главы 2');
  });

  test('глава 2 заканчивается партией после босса: она же открывает Новиград', () {
    final afterBoss = [
      'c1-00', 'c1-01', 'c1-02', 'c1-03', 'c1-05', 'c1-06', 'c1-08', 'c1-09', //
      'c2-00', 'c2-01', 'c2-03', 'c2-04', 'c2-06', 'c2-07', 'c2-08', 'c2-10', 'c2-11',
    ];
    final bossOnly = path(afterBoss);
    expect(bossOnly.chapters[1].isCleared, isFalse, reason: 'после Лешего остаётся «Замковый воевода»');
    expect(bossOnly.node('c2-12')!.status, NodeStatus.open);
    expect(bossOnly.node('c3-00')!.status, NodeStatus.locked);

    final done = path([...afterBoss, 'c2-12']);
    expect(done.chapters[1].isCleared, isTrue);
    expect(done.node('c3-00')!.status, NodeStatus.open);
    expect(done.node('c4-00')!.status, NodeStatus.locked, reason: 'Скеллиге ждёт босса Новиграда');
  });

  test('пройденный узел можно играть снова, закрытый нельзя', () {
    final progress = path(['c1-00', 'c1-01']);
    expect(progress.node('c1-01')!.isPlayable, isTrue);
    expect(progress.node('c1-02')!.isPlayable, isTrue);
    expect(progress.node('c1-03')!.isPlayable, isFalse);
  });

  test('прогресс по узлу, которого нет в каталоге, игнорируется', () {
    final withStray = CampaignPath.build(data.catalog, passed(['c1-00', 'c9-99']));
    expect(withStray.passedCount, 1);
    expect(withStray.node('c9-99'), isNull);
  });

  test('звёзды главы: условия выполнены и всего', () {
    final progress = {
      'c1-00': NodeProgress(nodeId: 'c1-00', wins: 1, firstWinAt: DateTime.utc(2026, 10, 27)),
      'c1-01': NodeProgress(
        nodeId: 'c1-01',
        wins: 1,
        firstWinAt: DateTime.utc(2026, 10, 27),
        bonusClaimedAt: DateTime.utc(2026, 10, 27),
      ),
    };
    final stars = CampaignPath.build(data.catalog, progress).chapters.first.stars;
    expect(stars.$1, 1);
    expect(stars.$2, 5, reason: 'условия у c1-01, c1-02, c1-05, c1-06 и c1-08');
  });
}
