import 'package:gwent_engine/src/core/value.dart';
import 'package:gwent_engine/src/state/seat.dart';
import 'package:gwent_engine/src/state/weather_card.dart';
import 'package:gwent_engine/src/view/player_view.dart';

/// Поле в момент конца раунда: после последнего хода, но до подсчёта и уборки.
///
/// В нём только открытое обоим игрокам: ряды с текущей силой, слоты рога, погода, отбои, счёт и число карт.
/// Руки здесь нет ([SideView.hand] пуст), поэтому событие с полем можно отдать любому игроку. Экран по нему
/// показывает последний ход раунда до подсчёта, не повторяя правил силы карт.
final class RoundBoard extends Value {
  const RoundBoard({required this.weather, required this.sides});

  /// Карты погоды на поле.
  final List<WeatherCard> weather;

  /// Обе стороны.
  final Map<Seat, SideView> sides;

  @override
  List<Object?> get props => [weather, sides];
}
