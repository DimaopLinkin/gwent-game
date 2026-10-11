import 'package:meta/meta.dart';

/// Веса и пороги жадного бота. Все величины в очках силы.
@immutable
final class GreedyBotSettings {
  const GreedyBotSettings({
    this.cardWeight = 6,
    this.leaderCost = 4,
    this.passLead = 12,
    this.giveUpDeficit = 25,
    this.redrawBelow = 4,
  });

  /// Во сколько очков бот ценит карту в руке: примерно средняя сила карты.
  final int cardWeight;

  /// Во сколько очков бот ценит неиспользованную способность лидера.
  final int leaderCost;

  /// Отрыв, с которым бот пасует, пока соперник ещё играет: чтобы отыграться, сопернику придётся тратить карты.
  final int passLead;

  /// Отставание, при котором бот сдаёт раунд, если его проигрыш не проигрывает партию.
  final int giveUpDeficit;

  /// Карты с оценкой ниже этой бот меняет при пересдаче.
  final int redrawBelow;
}
