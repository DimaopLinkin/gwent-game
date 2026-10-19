import 'package:gwent_ai/src/bot_difficulty.dart';
import 'package:meta/meta.dart';

/// Веса и пороги жадного бота. Все величины в очках силы. Уровни сложности — наборы этих значений
/// ([GreedyBotSettings.forDifficulty]).
@immutable
final class GreedyBotSettings {
  const GreedyBotSettings({
    this.cardWeight = 6,
    this.leaderCost = 4,
    this.passLead = 12,
    this.giveUpDeficit = 25,
    this.catchUpCards = 2,
    this.redrawBelow = 4,
    this.mistakeChance = 0,
    this.frugalSlack = 0,
    this.frugalShare = 0,
    this.wasteful = false,
  }) : assert(mistakeChance >= 0 && mistakeChance <= 100, 'шанс ошибки в процентах'),
       assert(frugalSlack >= 0, 'допуск экономии не отрицателен'),
       assert(frugalShare >= 0, 'доля экономии не отрицательна');

  /// Настройки уровня [difficulty]. Нормальный уровень — значения по умолчанию.
  factory GreedyBotSettings.forDifficulty(BotDifficulty difficulty) => switch (difficulty) {
    BotDifficulty.easy => const GreedyBotSettings(
      mistakeChance: 35,
      wasteful: true,
      frugalShare: 100,
      passLead: 6,
      redrawBelow: 0,
    ),
    BotDifficulty.normal => const GreedyBotSettings(),
    BotDifficulty.hard => const GreedyBotSettings(frugalSlack: 6),
    BotDifficulty.deathMatch => const GreedyBotSettings(frugalSlack: 6, frugalShare: 50),
  };

  /// Во сколько очков бот ценит карту в руке: примерно средняя сила карты.
  final int cardWeight;

  /// Во сколько очков бот ценит неиспользованную способность лидера.
  final int leaderCost;

  /// Отрыв, с которым бот пасует, пока соперник ещё играет: чтобы отыграться, сопернику придётся тратить карты.
  final int passLead;

  /// Отставание, при котором бот сдаёт раунд, если его проигрыш не проигрывает партию.
  final int giveUpDeficit;

  /// Сколько карт бот готов потратить, чтобы догнать спасовавшего соперника, если проигрыш раунда
  /// не проигрывает партию.
  final int catchUpCards;

  /// Карты с оценкой ниже этой бот меняет при пересдаче.
  final int redrawBelow;

  /// Шанс в процентах, что вместо лучшего хода бот сыграет случайную карту из тех, что принимает движок.
  final int mistakeChance;

  /// Допуск экономии в очках. Когда он больше нуля и бот не пасует, он берёт не лучший ход, а самый дешёвый
  /// из тех, что хуже лучшего не больше чем на допуск: слабые карты уходят раньше сильных. Ходы, которые ничего
  /// не прибавляют или вредят (Рог на пустой ряд, погода себе, Казнь своей карты), экономией не считаются.
  final int frugalSlack;

  /// Допуск экономии в процентах от прироста лучшего хода; складывается с [frugalSlack].
  final int frugalShare;

  /// Бот тратит самую дорогую карту из тех, что хуже лучшего хода не больше чем на допуск экономии, и держит слабые
  /// до конца: обратная экономия.
  final bool wasteful;
}
