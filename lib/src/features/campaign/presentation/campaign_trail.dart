import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:gwent/src/core/l10n/l10n.dart';
import 'package:gwent/src/core/presentation/components/faction_medallion.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_colors.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_faction.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_icon.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_icon_view.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_text.dart';
import 'package:gwent/src/features/campaign/application/load_campaign.dart';
import 'package:gwent/src/features/campaign/domain/campaign_path.dart';
import 'package:gwent/src/features/campaign/presentation/campaign_widgets.dart';
import 'package:gwent_content/gwent_content.dart';

/// Тропа главы: основные узлы идут по извилистой дороге сверху вниз, названия справа, заказы стоят слева в стороне.
///
/// Положения узлов вычисляются из данных главы, а не зашиты: сколько бы узлов ни было, дорога продолжается.
class ChapterTrail extends StatelessWidget {
  /// Создаёт тропу главы [chapter].
  const ChapterTrail({
    super.key,
    required this.chapter,
    required this.data,
    required this.currentNodeId,
    required this.onTap,
  });

  /// Глава с состояниями узлов.
  final ChapterView chapter;

  /// Каталог и тексты.
  final CampaignData data;

  /// Узел, на котором стоит игрок («Играть»).
  final String? currentNodeId;

  /// Касание узла.
  final ValueChanged<NodeView> onTap;

  /// Основные узлы подряд, каждый с заказами, которые идут за ним.
  List<_Stop> get _stops {
    final stops = <_Stop>[];
    for (final view in chapter.nodes) {
      if (view.node.kind == NodeKind.order && stops.isNotEmpty) {
        stops.last.orders.add(view);
      } else {
        stops.add(_Stop(view));
      }
    }
    return stops;
  }

  @override
  Widget build(BuildContext context) {
    final stops = _stops;
    var tournamentStep = 0;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        double x(int index) => width / 2 + 26 * math.sin(index * 0.9);
        return Column(
          children: [
            for (final (i, stop) in stops.indexed)
              () {
                final tournament = stop.main.node.kind == NodeKind.tournament;
                final starts = tournament && (i == 0 || stops[i - 1].main.node.kind != NodeKind.tournament);
                tournamentStep = tournament ? (starts ? 1 : tournamentStep + 1) : 0;
                final run = tournament
                    ? stops.skip(i).takeWhile((s) => s.main.node.kind == NodeKind.tournament).length
                    : 0;
                return _StopRow(
                  stop: stop,
                  width: width,
                  xPrev: i == 0 ? x(0) : x(i - 1),
                  x: x(i),
                  xNext: i == stops.length - 1 ? x(i) : x(i + 1),
                  isLast: i == stops.length - 1,
                  data: data,
                  isCurrent: stop.main.node.id == currentNodeId,
                  currentNodeId: currentNodeId,
                  tournamentStep: tournament ? tournamentStep : null,
                  tournamentRun: starts ? run : null,
                  onTap: onTap,
                );
              }(),
          ],
        );
      },
    );
  }
}

class _Stop {
  _Stop(this.main);

  final NodeView main;
  final List<NodeView> orders = [];
}

class _StopRow extends StatelessWidget {
  const _StopRow({
    required this.stop,
    required this.width,
    required this.xPrev,
    required this.x,
    required this.xNext,
    required this.isLast,
    required this.data,
    required this.isCurrent,
    required this.currentNodeId,
    required this.tournamentStep,
    required this.tournamentRun,
    required this.onTap,
  });

  static const double nodeSize = 60;
  static const double bossSize = 72;
  static const double orderRow = 116;

  final _Stop stop;
  final double width;
  final double xPrev;
  final double x;
  final double xNext;
  final bool isLast;
  final CampaignData data;
  final bool isCurrent;
  final String? currentNodeId;

  /// Номер соперника в турнире, если узел из турнира.
  final int? tournamentStep;

  /// Сколько соперников в турнире: задан у первого узла, над которым стоит лента.
  final int? tournamentRun;
  final ValueChanged<NodeView> onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final view = stop.main;
    final boss = view.node.kind == NodeKind.boss;
    final size = boss ? bossSize : nodeSize;
    final height = math.max(boss ? 112.0 : 96.0, stop.orders.length * orderRow);
    final titleLeft = x + size / 2 + 10;
    final rules = data.pack.rules;
    return Column(
      children: [
        if (tournamentRun != null)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            color: GwentColors.lifeGemDeep,
            child: Text(
              l10n.campaignTournamentRibbon(tournamentRun!).toUpperCase(),
              textAlign: TextAlign.center,
              textScaler: TextScaler.noScaling,
              style: const TextStyle(
                fontFamily: GwentText.cormorant,
                fontWeight: FontWeight.w700,
                fontSize: 14,
                letterSpacing: 14 * 0.08,
                color: GwentColors.errorText,
              ),
            ),
          ),
        SizedBox(
          height: height,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _RoadPainter(
                    xPrev: xPrev,
                    x: x,
                    xNext: xNext,
                    nodeY: height > 100 ? 48 : height / 2,
                    isLast: isLast,
                  ),
                ),
              ),
              for (final (i, order) in stop.orders.indexed)
                Positioned(
                  left: 12,
                  top: i * orderRow + 8,
                  width: x - nodeSize / 2 - 12 - 6,
                  height: orderRow - 8,
                  child: _OrderTile(
                    view: order,
                    name: data.text(order.node.opponent.nameKey),
                    look: factionLook(rules, order.node.opponent.fractionId),
                    isCurrent: order.node.id == currentNodeId,
                    onTap: () => onTap(order),
                  ),
                ),
              Positioned(
                left: x - size / 2,
                top: (height > 100 ? 48 : height / 2) - size / 2,
                child: _NodeCircle(
                  view: view,
                  size: size,
                  look: factionLook(rules, view.node.opponent.fractionId),
                  isCurrent: isCurrent,
                  step: tournamentStep,
                  onTap: () => onTap(view),
                ),
              ),
              Positioned(
                left: titleLeft,
                right: 10,
                top: (height > 100 ? 48 : height / 2) - 26,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onTap(view),
                  child: _NodeTitle(view: view, name: data.text(view.node.opponent.nameKey), isCurrent: isCurrent),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RoadPainter extends CustomPainter {
  const _RoadPainter({
    required this.xPrev,
    required this.x,
    required this.xNext,
    required this.nodeY,
    required this.isLast,
  });

  final double xPrev;
  final double x;
  final double xNext;
  final double nodeY;
  final bool isLast;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo((xPrev + x) / 2, 0)
      ..quadraticBezierTo(x, nodeY, isLast ? x : (x + xNext) / 2, isLast ? nodeY : size.height);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7
        ..color = GwentColors.brassDeep
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = GwentColors.brassDark,
    );
  }

  @override
  bool shouldRepaint(_RoadPainter old) =>
      old.xPrev != xPrev || old.x != x || old.xNext != xNext || old.nodeY != nodeY || old.isLast != isLast;
}

/// Круг узла: герб фракции соперника, замок у закрытого, золотое кольцо у открытого, галка у пройденного.
class _NodeCircle extends StatelessWidget {
  const _NodeCircle({
    required this.view,
    required this.size,
    required this.look,
    required this.isCurrent,
    required this.step,
    required this.onTap,
  });

  final NodeView view;
  final double size;
  final GwentFaction look;
  final bool isCurrent;
  final int? step;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final locked = view.status == NodeStatus.locked;
    final passed = view.status == NodeStatus.passed;
    final open = view.status == NodeStatus.open;
    final circle = DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: locked ? GwentColors.socket : GwentColors.surface,
        border: Border.all(
          color: open ? GwentColors.goldHighlight : (passed ? GwentColors.brass : GwentColors.line),
          width: open ? 3 : 2,
        ),
        boxShadow: open
            ? const [BoxShadow(color: GwentColors.powerRestoredGlow, blurRadius: 14, spreadRadius: 1)]
            : null,
      ),
      child: Center(
        child: locked
            ? GwentIconView(GwentIcon.iconLock, size: size * 0.4, color: GwentColors.disabledIcon)
            : view.node.isScripted
            ? GwentIconView(GwentIcon.iconLeader, size: size * 0.5)
            : FactionMedallion(faction: look, size: size - 14, crestSize: size * 0.4),
      ),
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox.square(
        dimension: size,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(child: open ? _Pulse(child: circle) : circle),
            if (passed)
              const Positioned(
                right: -2,
                bottom: -2,
                child: _Badge(text: '✓', color: GwentColors.gold),
              ),
            if (view.hasBonus && !locked)
              Positioned(
                right: -4,
                top: -4,
                child: _Badge(
                  text: view.bonusClaimed ? '★' : '☆',
                  color: view.bonusClaimed ? GwentColors.gold : GwentColors.textSecondary,
                ),
              ),
            if (step != null)
              Positioned(
                left: -4,
                top: -4,
                child: _Badge(text: '$step', color: GwentColors.errorText),
              ),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: GwentColors.bg,
      border: Border.all(color: color),
    ),
    child: SizedBox.square(
      dimension: 20,
      child: Center(
        child: Text(
          text,
          textScaler: TextScaler.noScaling,
          style: TextStyle(fontSize: 12, height: 1, color: color, fontWeight: FontWeight.w700),
        ),
      ),
    ),
  );
}

/// Пульсирующее золотое кольцо открытого узла; при «Уменьшить движение» кольцо стоит на месте.
class _Pulse extends StatefulWidget {
  const _Pulse({required this.child});

  final Widget child;

  @override
  State<_Pulse> createState() => _PulseState();
}

class _PulseState extends State<_Pulse> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, child) => Transform.scale(scale: 1 + 0.05 * _controller.value, child: child),
    child: widget.child,
  );
}

class _NodeTitle extends StatelessWidget {
  const _NodeTitle({required this.view, required this.name, required this.isCurrent});

  final NodeView view;
  final String name;
  final bool isCurrent;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locked = view.status == NodeStatus.locked;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 3,
      children: [
        if (view.node.kind == NodeKind.boss)
          CampaignLabel(l10n.campaignBossLabel.toUpperCase(), color: GwentColors.errorText),
        Text(
          name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: GwentText.cormorant,
            fontWeight: FontWeight.w700,
            fontSize: 19,
            height: 1.05,
            color: locked ? GwentColors.disabledText : GwentColors.textPrimary,
          ),
        ),
        Row(
          spacing: 8,
          children: [
            if (!view.node.isScripted) Flexible(child: DifficultyDiamonds(view.node.difficulty, showLabel: false)),
            if (isCurrent)
              DecoratedBox(
                decoration: BoxDecoration(
                  color: GwentColors.goldSurface,
                  borderRadius: BorderRadius.circular(3),
                  border: Border.all(color: GwentColors.brass),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  child: Text(
                    l10n.campaignPlayHere,
                    textScaler: TextScaler.noScaling,
                    style: const TextStyle(
                      fontFamily: GwentText.cormorant,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      color: GwentColors.gold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// Заказ: плитка в стороне от дороги с меткой «Заказ» и названием.
class _OrderTile extends StatelessWidget {
  const _OrderTile({
    required this.view,
    required this.name,
    required this.look,
    required this.isCurrent,
    required this.onTap,
  });

  final NodeView view;
  final String name;
  final GwentFaction look;
  final bool isCurrent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locked = view.status == NodeStatus.locked;
    final passed = view.status == NodeStatus.passed;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: 3,
        children: [
          SizedBox.square(
            dimension: 54,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: locked ? GwentColors.surfaceSunken : GwentColors.parchmentDark,
                      border: Border.all(
                        color: isCurrent ? GwentColors.goldHighlight : GwentColors.brass,
                        width: isCurrent ? 2.5 : 1.5,
                      ),
                    ),
                    child: Center(
                      child: locked
                          ? const GwentIconView(GwentIcon.iconLock, size: 22, color: GwentColors.disabledIcon)
                          : FactionMedallion(faction: look, size: 38, crestSize: 22),
                    ),
                  ),
                ),
                if (passed)
                  const Positioned(
                    right: -6,
                    bottom: -6,
                    child: _Badge(text: '✓', color: GwentColors.gold),
                  ),
                if (view.hasBonus && !locked)
                  Positioned(
                    right: -6,
                    top: -6,
                    child: _Badge(
                      text: view.bonusClaimed ? '★' : '☆',
                      color: view.bonusClaimed ? GwentColors.gold : GwentColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          CampaignLabel(l10n.campaignOrderLabel.toUpperCase(), color: GwentColors.brassLight),
          Text(
            name,
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: GwentText.alegreya,
              fontWeight: FontWeight.w600,
              fontSize: 14,
              height: 1.05,
              color: locked ? GwentColors.disabledText : GwentColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
