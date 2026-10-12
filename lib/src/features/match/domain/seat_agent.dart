import 'package:gwent_ai/gwent_ai.dart';
import 'package:gwent_engine/gwent_engine.dart';

/// Источник ходов за место без человека на этом устройстве в местной партии.
///
/// Стол спрашивает его после каждого изменения партии. Решение асинхронное: бот «думает» с задержкой, а другая
/// реализация может считать ход в отдельном изоляте.
abstract interface class SeatAgent {
  /// Намерение за место [seat] в состоянии [state] или `null`, если сейчас от места ничего не ждут.
  Future<Intent?> decide(MatchState state, Seat seat);
}

/// Бот: решение [MatchBot] после паузы [thinkTime], чтобы игрок успел увидеть свой ход и ответ на него.
final class BotAgent implements SeatAgent {
  /// Создаёт агента над ботом [bot].
  const BotAgent(this._bot, {this.thinkTime = const Duration(milliseconds: 700)});

  final MatchBot _bot;

  /// Пауза перед каждым ходом бота.
  final Duration thinkTime;

  @override
  Future<Intent?> decide(MatchState state, Seat seat) async {
    final intent = _bot.decide(state, seat);
    if (intent != null && thinkTime > Duration.zero) await Future<void>.delayed(thinkTime);
    return intent;
  }
}
