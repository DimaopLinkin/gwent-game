import 'package:gwent/src/features/match/domain/match_pause.dart';
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
///
/// Пока включена [pause] партии, бот не думает: время на паузе в [thinkTime] не входит.
final class BotAgent implements SeatAgent {
  /// Создаёт агента над ботом [bot]; [pause] — пауза партии, по умолчанию бот её не замечает.
  BotAgent(this._bot, {this.thinkTime = const Duration(milliseconds: 700), MatchPause? pause})
    : _pause = pause ?? MatchPause();

  final MatchBot _bot;
  final MatchPause _pause;

  /// Пауза перед каждым ходом бота.
  final Duration thinkTime;

  @override
  Future<Intent?> decide(MatchState state, Seat seat) async {
    final intent = _bot.decide(state, seat);
    if (intent != null && thinkTime > Duration.zero) await _pause.delay(thinkTime);
    return intent;
  }
}
