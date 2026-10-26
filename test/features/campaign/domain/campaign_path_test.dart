import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gwent/src/features/campaign/application/load_campaign.dart';
import 'package:gwent/src/features/campaign/domain/campaign_path.dart';
import 'package:gwent/src/features/campaign/domain/campaign_repository.dart';
import 'package:gwent/src/features/content/application/load_game_content.dart';
import 'package:gwent/src/features/content/data/asset_content_source.dart';

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

  test('когда остались только заказы, «Продолжить» ведёт на заказ', () {
    final onlyOrders = path([
      'c1-00',
      'c1-01',
      'c1-02',
      'c1-03',
      'c1-05',
      'c1-06',
      'c1-08',
      'c1-09',
    ]);
    expect(onlyOrders.nodes.where((node) => node.status == NodeStatus.open).map((node) => node.node.id), [
      'c1-04',
      'c1-07',
    ]);
    expect(onlyOrders.current!.node.id, 'c1-04');
  });

  test('глава 1 пройдена победой над боссом, главы 2–4 закрыты как «скоро», узлы в них не играются', () {
    final cleared = path(['c1-00', 'c1-01', 'c1-02', 'c1-03', 'c1-05', 'c1-06', 'c1-08', 'c1-09']);
    final chapter1 = cleared.chapters.first;
    expect(chapter1.isCleared, isTrue);
    expect(chapter1.passedCount, 8);
    expect(chapter1.totalCount, 10);
    expect(cleared.chapters.skip(1).every((chapter) => chapter.isComingSoon && !chapter.isUnlocked), isTrue);
    expect(cleared.node('c2-00')!.status, NodeStatus.locked, reason: 'глава 2 не выпущена, хотя босс 1 побеждён');
    expect(cleared.node('c2-00')!.isComingSoon, isTrue);
    expect(cleared.node('c2-00')!.isPlayable, isFalse);
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
