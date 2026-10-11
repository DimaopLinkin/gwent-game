import 'package:gwent_engine/src/cards/card_definition.dart';
import 'package:gwent_engine/src/cards/special_ability.dart';
import 'package:gwent_engine/src/engine/internal/match_context.dart';
import 'package:gwent_engine/src/event/game_event.dart';
import 'package:gwent_engine/src/state/card_instance.dart';
import 'package:gwent_engine/src/state/seat.dart';
import 'package:gwent_engine/src/state/weather_card.dart';

/// Зона погоды: карты погоды и Ясное небо (раздел 9.3).
final class WeatherRules {
  const WeatherRules(this._ctx);

  final MatchContext _ctx;

  /// Карта погоды или Ясное небо от игрока [owner].
  void play(Seat owner, CardInstance card) {
    switch (_ctx.definition(card)) {
      case SpecialCardDefinition(ability: WeatherAbility()):
        if (_ctx.draft.weather.any((weather) => weather.card.cardId == card.cardId)) {
          _ctx.discard(owner, card);
        } else {
          _ctx.draft.weather.add(WeatherCard(card, owner));
          _ctx.emit(WeatherPlayed(owner, card));
        }
      case SpecialCardDefinition(ability: ClearWeatherAbility()):
        clear();
        _ctx.discard(owner, card);
      case SpecialCardDefinition() || UnitCardDefinition():
        throw StateError('Карта ${card.cardId} не погода');
    }
  }

  /// Снимает всю погоду: карты уходят в отбой своих хозяев.
  void clear() {
    final weather = [..._ctx.draft.weather];
    _ctx.draft.weather.clear();
    _ctx.emit(const WeatherCleared());
    for (final card in weather) {
      _ctx.discard(card.owner, card.card);
    }
  }
}
