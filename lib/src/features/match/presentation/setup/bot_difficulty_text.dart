import 'package:gwent/src/core/l10n/l10n.dart';
import 'package:gwent_ai/gwent_ai.dart' show BotDifficulty;

/// Название уровня сложности бота для игрока.
String botDifficultyName(AppLocalizations l10n, BotDifficulty difficulty) => switch (difficulty) {
  BotDifficulty.easy => l10n.botDifficultyEasy,
  BotDifficulty.normal => l10n.botDifficultyNormal,
  BotDifficulty.hard => l10n.botDifficultyHard,
  BotDifficulty.deathMatch => l10n.botDifficultyDeathMatch,
};

/// Описание уровня сложности бота: как он играет и какую колоду собирает.
String botDifficultyDescription(AppLocalizations l10n, BotDifficulty difficulty) => switch (difficulty) {
  BotDifficulty.easy => l10n.botDifficultyEasyHint,
  BotDifficulty.normal => l10n.botDifficultyNormalHint,
  BotDifficulty.hard => l10n.botDifficultyHardHint,
  BotDifficulty.deathMatch => l10n.botDifficultyDeathMatchHint,
};
