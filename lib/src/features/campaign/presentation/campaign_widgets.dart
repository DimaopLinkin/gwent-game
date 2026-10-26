import 'package:flutter/widgets.dart';
import 'package:gwent/src/core/l10n/l10n.dart';
import 'package:gwent/src/core/presentation/card/card_face.dart';
import 'package:gwent/src/core/presentation/card/card_size.dart';
import 'package:gwent/src/core/presentation/card/gwent_card.dart';
import 'package:gwent/src/core/presentation/components/diamond_marker.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_colors.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_faction.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_text.dart';
import 'package:gwent/src/features/campaign/presentation/campaign_texts.dart';
import 'package:gwent_content/gwent_content.dart';

/// Герб фракции [fractionId] из пакета; нейтральный, если фракции нет.
GwentFaction factionLook(PackRules rules, String? fractionId) =>
    fractionId == null ? GwentFaction.neutral : GwentFaction.fromKey(rules.fractionsById[fractionId]?.key ?? '');

/// Подпись мелким капителем: «ЛИДЕР ПРОТИВНИКА», «НАГРАДА ЗА ПОБЕДУ».
class CampaignLabel extends StatelessWidget {
  /// Создаёт подпись.
  const CampaignLabel(this.text, {super.key, this.color = GwentColors.textSecondary});

  /// Текст.
  final String text;

  /// Цвет.
  final Color color;

  @override
  Widget build(BuildContext context) => Text(
    text,
    textScaler: TextScaler.noScaling,
    style: TextStyle(
      fontFamily: GwentText.cormorant,
      fontWeight: FontWeight.w700,
      fontSize: 13,
      height: 1.1,
      letterSpacing: 13 * 0.08,
      color: color,
    ),
  );
}

/// Силуэт награды: рубашка карты с «?», вид карты и число копий. Настоящая карта до победы не показывается.
class RewardSilhouette extends StatelessWidget {
  /// Создаёт силуэт.
  const RewardSilhouette({super.key, required this.kind, required this.copies, this.muted = false});

  /// Вид карты.
  final RewardKind kind;

  /// Сколько копий.
  final int copies;

  /// Серый силуэт закрытого узла.
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final label = l10n.rewardKindLabel(kind);
    return Semantics(
      label: copies > 1 ? l10n.campaignRewardCopies(label, copies) : label,
      excludeSemantics: true,
      child: Opacity(
        opacity: muted ? 0.5 : 1,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 4,
          children: [
            Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                const GwentCard(
                  face: CardBackFace(faction: GwentFaction.neutral),
                  size: CardSize.row,
                ),
                const Text(
                  '?',
                  textScaler: TextScaler.noScaling,
                  style: TextStyle(
                    fontFamily: GwentText.cormorant,
                    fontWeight: FontWeight.w700,
                    fontSize: 28,
                    height: 1,
                    color: GwentColors.gold,
                  ),
                ),
                if (copies > 1)
                  Positioned(
                    right: -6,
                    bottom: -4,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: GwentColors.gold,
                        borderRadius: BorderRadius.circular(999),
                        boxShadow: const [BoxShadow(color: GwentColors.bg, spreadRadius: 1.5)],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        child: Text(
                          '×$copies',
                          textScaler: TextScaler.noScaling,
                          style: const TextStyle(
                            fontFamily: GwentText.cormorant,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                            height: 1,
                            color: GwentColors.onGold,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            CampaignLabel(label.toUpperCase()),
          ],
        ),
      ),
    );
  }
}

/// Уровень сложности: четыре ромба и подпись; «НА СМЕРТЬ!» красным.
class DifficultyDiamonds extends StatelessWidget {
  /// Создаёт указатель уровня.
  const DifficultyDiamonds(this.difficulty, {super.key, this.showLabel = true});

  /// Уровень.
  final CampaignDifficulty difficulty;

  /// Показывать подпись рядом с ромбами.
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final filled = difficultyDiamonds(difficulty);
    final deadly = difficulty == CampaignDifficulty.deathMatch;
    final accent = deadly ? GwentColors.debuff : GwentColors.gold;
    final label = context.l10n.difficultyLabel(difficulty);
    return Semantics(
      label: label,
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 5,
        children: [
          for (var i = 0; i < 4; i++) DiamondMarker(size: 6, color: i < filled ? accent : GwentColors.line),
          if (showLabel)
            Padding(
              padding: const EdgeInsets.only(left: 3),
              child: Text(
                label,
                textScaler: TextScaler.noScaling,
                style: TextStyle(
                  fontFamily: GwentText.alegreya,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  height: 1,
                  color: deadly ? GwentColors.errorText : GwentColors.textSecondary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Пергаментная плашка: условие дополнительной награды и награды.
class ParchmentPlate extends StatelessWidget {
  /// Создаёт плашку.
  const ParchmentPlate({super.key, required this.child});

  /// Содержимое.
  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(6),
      gradient: const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [GwentColors.parchmentLight, GwentColors.parchmentDark],
      ),
      border: Border.all(color: GwentColors.parchmentLow),
    ),
    child: Padding(padding: const EdgeInsets.all(12), child: child),
  );
}

/// Плашка «Режим кампании» над конструктором: закрытые карты откроются за победы на тропе.
class CampaignModeBanner extends StatelessWidget {
  /// Создаёт плашку.
  const CampaignModeBanner({super.key});

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: GwentColors.goldSurface,
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: GwentColors.brass),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Text(
        context.l10n.campaignModeBanner,
        style: const TextStyle(
          fontFamily: GwentText.alegreya,
          fontSize: 14,
          height: 1.2,
          color: GwentColors.goldHighlight,
        ),
      ),
    ),
  );
}
