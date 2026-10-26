import 'package:flutter/widgets.dart';
import 'package:gwent/src/core/l10n/l10n.dart';
import 'package:gwent/src/core/presentation/components/diamond_marker.dart';
import 'package:gwent/src/core/presentation/components/gwent_button.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_colors.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_space.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_text.dart';

/// Лист «Первая партия пройдена» (макет 16): поверх поля, на котором закончилась партия, что игрок узнал и что делать
/// дальше. Кнопки: сыграть с ботом, пройти ещё раз и выйти в меню.
class TutorialDoneSheet extends StatelessWidget {
  /// Создаёт лист.
  const TutorialDoneSheet({super.key, required this.onPlay, required this.onAgain, required this.onMenu});

  /// «Играть против бота».
  final VoidCallback onPlay;

  /// «Пройти ещё раз».
  final VoidCallback onAgain;

  /// «В меню».
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final learned = [
      l10n.tutorialDoneGoal,
      l10n.tutorialDoneRows,
      l10n.tutorialDonePass,
      l10n.tutorialDoneWeather,
      l10n.tutorialDoneAbilities,
    ];
    return ColoredBox(
      color: GwentColors.scrim,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [GwentColors.surfaceRaised, GwentColors.surface],
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(GwentSpace.radiusL)),
              border: Border.all(color: GwentColors.brass, width: GwentSpace.borderGold),
              boxShadow: GwentShadows.high,
            ),
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      l10n.tutorialDoneTitle,
                      textAlign: TextAlign.center,
                      textScaler: TextScaler.noScaling,
                      style: const TextStyle(
                        fontFamily: GwentText.cormorant,
                        fontWeight: FontWeight.w700,
                        fontSize: 28,
                        height: 1.1,
                        color: GwentColors.goldHighlight,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.tutorialDoneSubtitle,
                      textAlign: TextAlign.center,
                      textScaler: TextScaler.noScaling,
                      style: const TextStyle(
                        fontFamily: GwentText.alegreya,
                        fontStyle: FontStyle.italic,
                        fontWeight: FontWeight.w500,
                        fontSize: 16,
                        color: GwentColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 14),
                    for (final line in learned)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: Row(
                          spacing: 12,
                          children: [
                            const SizedBox(
                              width: 14,
                              child: Center(child: DiamondMarker(size: 7, color: GwentColors.gold)),
                            ),
                            Expanded(
                              child: Text(
                                line,
                                textScaler: TextScaler.noScaling,
                                style: const TextStyle(
                                  fontFamily: GwentText.alegreya,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 17,
                                  height: 1.25,
                                  color: GwentColors.textPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 18),
                    Column(
                      spacing: 10,
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: GwentButton(label: l10n.tutorialDonePlay, solid: true, onPressed: onPlay),
                        ),
                        SizedBox(
                          width: double.infinity,
                          child: GwentButton(
                            label: l10n.tutorialDoneAgain,
                            style: GwentButtonStyle.secondary,
                            solid: true,
                            onPressed: onAgain,
                          ),
                        ),
                        SizedBox(
                          width: double.infinity,
                          child: GwentButton(
                            label: l10n.tutorialDoneMenu,
                            style: GwentButtonStyle.secondary,
                            solid: true,
                            onPressed: onMenu,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
