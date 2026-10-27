import 'package:gwent/src/core/l10n/l10n.dart';
import 'package:gwent_content/gwent_content.dart';

/// Вид награды: подпись под силуэтом, пока карта скрыта.
enum RewardKind {
  /// Обычный отряд.
  squad,

  /// Герой.
  hero,

  /// Особая карта.
  special,

  /// Лидер.
  leader,
}

/// Вид карты [cardId] по пакету.
RewardKind rewardKindOf(PackRules rules, String cardId) {
  if (rules.leaderCardsById.containsKey(cardId)) return RewardKind.leader;
  if (rules.specialCardsById.containsKey(cardId)) return RewardKind.special;
  return (rules.squadCardsById[cardId]?.isHero ?? false) ? RewardKind.hero : RewardKind.squad;
}

/// Подписи кампании по перечислениям каталога.
extension CampaignTexts on AppLocalizations {
  /// Подпись вида награды.
  String rewardKindLabel(RewardKind kind) => switch (kind) {
    RewardKind.squad => campaignKindSquad,
    RewardKind.hero => campaignKindHero,
    RewardKind.special => campaignKindSpecial,
    RewardKind.leader => campaignKindLeader,
  };

  /// Название уровня сложности узла.
  String difficultyLabel(CampaignDifficulty difficulty) => switch (difficulty) {
    CampaignDifficulty.easy => campaignDifficultyEasy,
    CampaignDifficulty.normal => campaignDifficultyNormal,
    CampaignDifficulty.hard => campaignDifficultyHard,
    CampaignDifficulty.deathMatch => campaignDifficultyDeathMatch,
  };

  /// Условие дополнительной награды словами.
  String conditionLabel(BonusCondition condition) => switch (condition) {
    BonusCondition.winTwoZero => campaignConditionTwoZero,
    BonusCondition.noSpecials => campaignConditionNoSpecials,
    BonusCondition.margin20 => campaignConditionMargin,
  };
}

/// Сколько ромбов (из четырёх) закрашено у уровня сложности.
int difficultyDiamonds(CampaignDifficulty difficulty) => switch (difficulty) {
  CampaignDifficulty.easy => 1,
  CampaignDifficulty.normal => 2,
  CampaignDifficulty.hard => 3,
  CampaignDifficulty.deathMatch => 4,
};
