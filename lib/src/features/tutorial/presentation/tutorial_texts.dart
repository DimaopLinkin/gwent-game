import 'package:gwent/src/core/l10n/l10n.dart';
import 'package:gwent/src/features/tutorial/domain/tutorial_step.dart';

/// Заголовок и текст карточки шага.
typedef TutorialText = ({String title, String text});

/// Строки шага [step]; [mine] и [theirs] — счёт игроков для шага, где он назван в тексте.
TutorialText tutorialText(AppLocalizations l10n, TutorialStep step, {int mine = 0, int theirs = 0}) => switch (step) {
  TutorialStep.goal => (title: l10n.tutorialStepGoalTitle, text: l10n.tutorialStepGoalText),
  TutorialStep.handAndDeck => (title: l10n.tutorialStepHandAndDeckTitle, text: l10n.tutorialStepHandAndDeckText),
  TutorialStep.cardPower => (title: l10n.tutorialStepCardPowerTitle, text: l10n.tutorialStepCardPowerText),
  TutorialStep.firstCard => (title: l10n.tutorialStepFirstCardTitle, text: l10n.tutorialStepFirstCardText),
  TutorialStep.score => (title: l10n.tutorialStepScoreTitle, text: l10n.tutorialStepScoreText),
  TutorialStep.opponentMove => (title: l10n.tutorialStepOpponentMoveTitle, text: l10n.tutorialStepOpponentMoveText),
  TutorialStep.rows => (title: l10n.tutorialStepRowsTitle, text: l10n.tutorialStepRowsText),
  TutorialStep.hero => (title: l10n.tutorialStepHeroTitle, text: l10n.tutorialStepHeroText),
  TutorialStep.passIntro => (title: l10n.tutorialStepPassIntroTitle, text: l10n.tutorialStepPassIntroText),
  TutorialStep.passHold => (title: l10n.tutorialStepPassHoldTitle, text: l10n.tutorialStepPassHoldText),
  TutorialStep.roundResult => (title: l10n.tutorialStepRoundResultTitle, text: l10n.tutorialStepRoundResultText),
  TutorialStep.weather => (title: l10n.tutorialStepWeatherTitle, text: l10n.tutorialStepWeatherText),
  TutorialStep.spy => (title: l10n.tutorialStepSpyTitle, text: l10n.tutorialStepSpyText),
  TutorialStep.horn => (title: l10n.tutorialStepHornTitle, text: l10n.tutorialStepHornText),
  TutorialStep.leader => (title: l10n.tutorialStepLeaderTitle, text: l10n.tutorialStepLeaderText),
  TutorialStep.finalPass => (
    title: l10n.tutorialStepFinalPassTitle,
    text: l10n.tutorialStepFinalPassText(mine, theirs),
  ),
};
