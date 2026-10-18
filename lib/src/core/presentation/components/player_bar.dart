import 'package:flutter/widgets.dart';
import 'package:gwent/src/core/l10n/l10n.dart';
import 'package:gwent/src/core/presentation/card/card_face.dart';
import 'package:gwent/src/core/presentation/card/card_highlight.dart';
import 'package:gwent/src/core/presentation/card/card_size.dart';
import 'package:gwent/src/core/presentation/card/gwent_card.dart';
import 'package:gwent/src/core/presentation/components/card_pile.dart';
import 'package:gwent/src/core/presentation/components/rolling_number.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_colors.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_faction.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_icon.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_icon_view.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_text.dart';

/// Метки частей полосы: по ним анимации карт находят, куда лететь и откуда (макет 12).
///
/// Ключи долгоживущие, поэтому объект создаёт тот, кто держит поле, и отдаёт его полосе.
class PlayerBarAnchors {
  /// Создаёт набор меток.
  PlayerBarAnchors();

  /// Мини-карта лидера.
  final GlobalKey leader = GlobalKey();

  /// Число карт в руке.
  final GlobalKey hand = GlobalKey();

  /// Колода.
  final GlobalKey deck = GlobalKey();

  /// Сброс.
  final GlobalKey discard = GlobalKey();

  /// Круг общего счёта.
  final GlobalKey score = GlobalKey();
}

/// Полоса игрока на поле (макет поля, «Панель игрока»): высота 48 pt, поля 8, промежуток 8.
///
/// Слева направо: мини-карта лидера 31×44, имя с гербом, камни и число карт в руке, счёт в круге 40 pt, колода и
/// сброс мини-стопками, справа [trailing] — «Пас» у своего игрока или метка «Спасовал» у соперника. Полоса игрока
/// отличается от плашки из макета дизайн-системы (`PlayerPlate`, 68 pt): на поле вертикаль расписана до пункта.
class PlayerBar extends StatelessWidget {
  /// Создаёт полосу.
  const PlayerBar({
    super.key,
    required this.name,
    required this.faction,
    required this.leader,
    required this.lifeRemaining,
    required this.handCount,
    required this.score,
    required this.deckCount,
    required this.discardCount,
    this.leaderAvailable = false,
    this.leading = false,
    this.discardTop,
    this.trailing,
    this.lifeTotal = 2,
    this.mine = true,
    this.onLeaderTap,
    this.onLeaderLongPress,
    this.onDiscardTap,
    this.scoreRoll,
    this.handRoll,
    this.deckRoll,
    this.discardRoll,
    this.anchors,
  });

  /// Высота полосы.
  static const double height = 48;

  /// Имя игрока.
  final String name;

  /// Фракция колоды: герб рядом с именем и на рубашке колоды.
  final GwentFaction faction;

  /// Лицо мини-карты лидера.
  final LeaderCardFace leader;

  /// Способность лидера можно применить: золотое кольцо вокруг мини-карты.
  final bool leaderAvailable;

  /// Сколько камней-жизней осталось.
  final int lifeRemaining;

  /// Сколько камней в партии.
  final int lifeTotal;

  /// Карт в руке.
  final int handCount;

  /// Очки в круге.
  final int score;

  /// Игрок ведёт по очкам: золотое кольцо и корона.
  final bool leading;

  /// Карт в колоде.
  final int deckCount;

  /// Карт в сбросе.
  final int discardCount;

  /// Верхняя карта сброса; `null` у пустого сброса.
  final CardFace? discardTop;

  /// Что справа: кнопка «Пас» или метка «Спасовал».
  final Widget? trailing;

  /// Своя полоса (тёплый фон, граница сверху) или соперника (граница снизу).
  final bool mine;

  /// Тап по лидеру.
  final VoidCallback? onLeaderTap;

  /// Долгое нажатие на лидера.
  final VoidCallback? onLeaderLongPress;

  /// Тап по сбросу.
  final VoidCallback? onDiscardTap;

  /// Прокрутка общего счёта, числа карт в руке, в колоде и в сбросе (анимации карт); `null` — число стоит.
  final RollValue? scoreRoll;

  /// См. [scoreRoll].
  final RollValue? handRoll;

  /// См. [scoreRoll].
  final RollValue? deckRoll;

  /// См. [scoreRoll].
  final RollValue? discardRoll;

  /// Метки частей полосы для анимаций карт.
  final PlayerBarAnchors? anchors;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: mine
              ? const [GwentColors.surface, Color(0xFF1B1612)]
              : const [Color(0xFF1B1612), GwentColors.surface],
        ),
        border: Border(
          top: mine ? const BorderSide(color: GwentColors.line) : BorderSide.none,
          bottom: mine ? BorderSide.none : const BorderSide(color: GwentColors.line),
        ),
      ),
      child: Row(
        spacing: 8,
        children: [
          KeyedSubtree(
            key: anchors?.leader,
            child: _LeaderSlot(
              face: leader,
              available: leaderAvailable,
              onTap: onLeaderTap,
              onLongPress: onLeaderLongPress,
            ),
          ),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 4,
              children: [
                Row(
                  spacing: 5,
                  children: [
                    if (faction.crest case final crest?) GwentIconView(crest, size: 16),
                    Expanded(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textScaler: TextScaler.noScaling,
                        style: const TextStyle(
                          fontFamily: GwentText.cormorant,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          height: 1.1,
                          color: GwentColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                Row(
                  spacing: 8,
                  children: [
                    _Gems(remaining: lifeRemaining, total: lifeTotal),
                    KeyedSubtree(
                      key: anchors?.hand,
                      child: Semantics(
                        label: l10n.playerPlateHandCount(handCount),
                        excludeSemantics: true,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          spacing: 3,
                          children: [
                            const GwentIconView(GwentIcon.iconHand, size: 13, color: GwentColors.textSecondary),
                            _handLabel(),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          KeyedSubtree(
            key: anchors?.score,
            child: _ScoreDisc(score: score, leading: leading, roll: scoreRoll),
          ),
          KeyedSubtree(
            key: anchors?.deck,
            child: CardPile(
              top: CardBackFace(faction: faction),
              count: deckCount,
              roll: deckRoll,
              semanticsLabel: l10n.fieldDeckSemantics(deckCount),
            ),
          ),
          KeyedSubtree(
            key: anchors?.discard,
            child: CardPile(
              top: discardTop,
              count: discardCount,
              roll: discardRoll,
              semanticsLabel: l10n.fieldDiscardSemantics(discardCount),
              onTap: onDiscardTap,
            ),
          ),
          if (trailing != null) SizedBox(width: 70, child: Center(child: trailing)),
        ],
      ),
    );
  }
}

extension on PlayerBar {
  Widget _handLabel() {
    final style = GwentText.caption.copyWith(
      fontWeight: FontWeight.w700,
      fontSize: 12.5,
      height: 1,
      fontFeatures: GwentText.numbers,
    );
    final roll = handRoll;
    return roll == null
        ? Text('$handCount', textScaler: TextScaler.noScaling, style: style)
        : RollingNumber(roll, style: style);
  }
}

class _LeaderSlot extends StatelessWidget {
  const _LeaderSlot({required this.face, required this.available, this.onTap, this.onLongPress});

  final LeaderCardFace face;
  final bool available;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(2),
      boxShadow: available
          ? const [
              BoxShadow(color: Color(0x8CC8A35B), blurRadius: 12),
              BoxShadow(color: GwentColors.gold, spreadRadius: 1.5),
            ]
          : null,
    ),
    child: GwentCard(
      face: face,
      size: CardSize.mini,
      highlight: face.abilityUsed ? CardHighlight.disabled : CardHighlight.normal,
      onTap: onTap,
      onLongPress: onLongPress,
    ),
  );
}

class _Gems extends StatelessWidget {
  const _Gems({required this.remaining, required this.total});

  final int remaining;
  final int total;

  @override
  Widget build(BuildContext context) => Semantics(
    label: context.l10n.lifeGemsSemantics(remaining, total),
    excludeSemantics: true,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 2,
      children: [
        for (var i = 0; i < total; i++)
          GwentIconView(
            i < remaining ? GwentIcon.iconLifeGem : GwentIcon.iconLifeGemLost,
            size: 14,
            color: i < remaining ? GwentColors.goldHighlight : GwentColors.disabledIcon,
          ),
      ],
    ),
  );
}

class _ScoreDisc extends StatelessWidget {
  const _ScoreDisc({required this.score, required this.leading, this.roll});

  final int score;
  final bool leading;
  final RollValue? roll;

  @override
  Widget build(BuildContext context) => Semantics(
    label: context.l10n.totalScoreSemantics(score),
    excludeSemantics: true,
    child: Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const RadialGradient(
              center: Alignment(0, -0.3),
              radius: 0.75,
              colors: [GwentColors.surfaceWarm, GwentColors.bg],
              stops: [0, 0.75],
            ),
            // Flutter рисует тени по порядку списка, поэтому широкие кольца идут первыми, узкие поверх них.
            boxShadow: [
              if (leading) ...const [
                BoxShadow(color: Color(0x8CC8A35B), blurRadius: 16),
                BoxShadow(color: GwentColors.brass, spreadRadius: 4),
              ],
              const BoxShadow(color: GwentColors.bg, spreadRadius: 3),
              BoxShadow(color: leading ? GwentColors.gold : GwentColors.brass, spreadRadius: 1.5),
            ],
          ),
          child: roll == null
              ? Text('$score', textScaler: TextScaler.noScaling, style: GwentText.scoreTotal.copyWith(fontSize: 19))
              : RollingNumber(roll!, style: GwentText.scoreTotal.copyWith(fontSize: 19)),
        ),
        if (leading)
          Positioned(
            top: -6,
            right: -7,
            child: Container(
              width: 18,
              height: 18,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: GwentColors.bg,
                boxShadow: [BoxShadow(color: GwentColors.gold, spreadRadius: 1)],
              ),
              child: const GwentIconView(GwentIcon.iconCrownLeading, size: 12, color: GwentColors.goldHighlight),
            ),
          ),
      ],
    ),
  );
}
