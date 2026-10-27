import 'package:collection/collection.dart';
import 'package:gwent/src/features/campaign/domain/campaign_repository.dart';
import 'package:gwent_content/gwent_content.dart';
import 'package:meta/meta.dart';

/// Состояние узла на тропе.
enum NodeStatus {
  /// Закрыт: предыдущий узел не пройден или глава ещё не выпущена.
  locked,

  /// Открыт и ещё не пройден.
  open,

  /// Пройден хотя бы раз.
  passed,
}

/// Узел тропы: узел каталога и то, что о нём известно по прогрессу игрока.
@immutable
final class NodeView {
  /// Создаёт вид узла.
  const NodeView({required this.node, required this.status, required this.progress, required this.chapterReleased});

  /// Узел каталога.
  final CampaignNode node;

  /// Состояние.
  final NodeStatus status;

  /// Запись о прогрессе или `null`, если узел ни разу не выигран.
  final NodeProgress? progress;

  /// Глава узла выпущена; в узлах невыпущенной главы играть нельзя.
  final bool chapterReleased;

  /// Сколько раз узел выигран.
  int get wins => progress?.wins ?? 0;

  /// У узла есть условие дополнительной награды.
  bool get hasBonus => node.bonus != null;

  /// Награда за условие получена.
  bool get bonusClaimed => progress?.bonusClaimed ?? false;

  /// В узле можно играть: он открыт или пройден (повтор без награды первой победы), и глава выпущена.
  bool get isPlayable => chapterReleased && status != NodeStatus.locked;

  /// Узел закрыт потому, что его глава ещё не выпущена.
  bool get isComingSoon => !chapterReleased;
}

/// Глава тропы.
@immutable
final class ChapterView {
  /// Создаёт вид главы.
  ChapterView({required this.chapter, required List<NodeView> nodes}) : nodes = List.unmodifiable(nodes);

  /// Глава каталога.
  final CampaignChapter chapter;

  /// Узлы главы по порядку каталога.
  final List<NodeView> nodes;

  /// Пройдено узлов главы.
  int get passedCount => nodes.where((node) => node.status == NodeStatus.passed).length;

  /// Сколько всего узлов в главе.
  int get totalCount => nodes.length;

  /// Сколько условий дополнительной награды выполнено и сколько их всего в главе (звёзды).
  (int, int) get stars => (
    nodes.where((node) => node.hasBonus && node.bonusClaimed).length,
    nodes.where((node) => node.hasBonus).length,
  );

  /// Глава пройдена: пройдены все основные узлы (не заказы), в том числе босс. В главе 2 после босса есть ещё партия,
  /// она и открывает следующую главу, поэтому босс один главу не заканчивает.
  bool get isCleared =>
      nodes.where((node) => node.node.kind != NodeKind.order).every((node) => node.status == NodeStatus.passed);

  /// Глава ждёт выпуска: играть в её узлах нельзя.
  bool get isComingSoon => !chapter.released;

  /// В главу можно войти: она выпущена и её первый узел открыт или пройден.
  bool get isUnlocked => !isComingSoon && nodes.first.status != NodeStatus.locked;
}

/// Тропа: каталог кампании, прогресс игрока и всё, что из них вычисляется.
///
/// Состояния узлов не хранятся, а вычисляются при каждом снимке прогресса: узел открыт, когда пройден узел,
/// после которого он открывается (`after`), глава выпущена и сам узел ещё не пройден. Прогресс по узлам, которых
/// нет в каталоге (пакет обновился), не показывается и не считается.
@immutable
final class CampaignPath {
  /// Строит тропу по [catalog] и [progress] (идентификатор узла → запись).
  factory CampaignPath.build(CampaignCatalog catalog, Map<String, NodeProgress> progress) {
    bool passed(String? nodeId) => nodeId != null && (progress[nodeId]?.wins ?? 0) > 0;
    final chapters = [
      for (final chapter in catalog.chapters)
        ChapterView(
          chapter: chapter,
          nodes: [
            for (final node in chapter.nodes)
              NodeView(
                node: node,
                progress: progress[node.id],
                chapterReleased: chapter.released,
                status: switch ((passed(node.id), node.afterId == null || passed(node.afterId))) {
                  (true, _) => NodeStatus.passed,
                  (false, true) when chapter.released => NodeStatus.open,
                  _ => NodeStatus.locked,
                },
              ),
          ],
        ),
    ];
    return CampaignPath._(catalog, chapters);
  }

  CampaignPath._(this.catalog, this.chapters);

  /// Каталог кампании.
  final CampaignCatalog catalog;

  /// Главы по порядку.
  final List<ChapterView> chapters;

  /// Все узлы по порядку.
  Iterable<NodeView> get nodes => chapters.expand((chapter) => chapter.nodes);

  late final Map<String, NodeView> _byId = {for (final view in nodes) view.node.id: view};

  /// Вид узла по идентификатору или `null`.
  NodeView? node(String nodeId) => _byId[nodeId];

  /// Пройдено узлов всего.
  int get passedCount => nodes.where((node) => node.status == NodeStatus.passed).length;

  /// Всего узлов.
  int get totalCount => nodes.length;

  /// Первый узел кампании («Первая партия») пройден: игрок получил стартовый набор.
  bool get started => nodes.first.status == NodeStatus.passed;

  /// Узел, с которого идёт «Продолжить»: первый открытый узел основного пути, а если такого нет, первый открытый
  /// заказ. `null`, если открытых узлов нет (всё выпущенное пройдено).
  NodeView? get current {
    final open = nodes.where((node) => node.status == NodeStatus.open).toList();
    return open.where((node) => node.node.kind != NodeKind.order).firstOrNull ?? open.firstOrNull;
  }

  /// Глава, в которой сейчас идёт игрок: глава текущего основного узла. Когда основной путь пройден (остались только
  /// заказы), это последняя доступная глава, а не глава заказа: конец кампании не возвращает шапку в Белый сад.
  ChapterView? get currentChapter {
    final node = current;
    if (node != null && node.node.kind != NodeKind.order) {
      return chapters.firstWhere((chapter) => chapter.nodes.any((view) => view.node.id == node.node.id));
    }
    return chapters.where((chapter) => chapter.isUnlocked).lastOrNull ??
        chapters.where((chapter) => !chapter.isComingSoon).lastOrNull;
  }
}
