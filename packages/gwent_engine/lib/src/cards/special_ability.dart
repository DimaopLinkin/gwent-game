import 'package:gwent_engine/src/cards/row.dart';
import 'package:gwent_engine/src/core/value.dart';

/// Способность специальной карты (раздел 9.3 правил).
sealed class SpecialAbility extends Value {
  const SpecialAbility();

  /// Машинный ключ эффекта для проверки совместимости пакета контента.
  String get key;
}

/// Погода: ряды [rows] обоих игроков под погодой (Мороз, Мгла, Ливень, Шторм со Скеллиге).
final class WeatherAbility extends SpecialAbility {
  const WeatherAbility(this.rows);

  static const String effectKey = 'weather';

  final Set<Row> rows;

  @override
  String get key => effectKey;

  @override
  List<Object?> get props => [rows];
}

/// Ясное небо: снимает всю погоду.
final class ClearWeatherAbility extends SpecialAbility {
  const ClearWeatherAbility();

  static const String effectKey = 'clear_weather';

  @override
  String get key => effectKey;

  @override
  List<Object?> get props => const [];
}

/// Командирский рог: кладётся в свободный слот рога своего ряда и удваивает обычные отряды ряда.
final class HornCardAbility extends SpecialAbility {
  const HornCardAbility();

  static const String effectKey = 'commander_horn';

  @override
  String get key => effectKey;

  @override
  List<Object?> get props => const [];
}

/// Чучело: возвращает обычный отряд своей стороны в руку и встаёт на его место.
final class DecoyAbility extends SpecialAbility {
  const DecoyAbility();

  static const String effectKey = 'decoy';

  @override
  String get key => effectKey;

  @override
  List<Object?> get props => const [];
}

/// Казнь: уничтожает сильнейшие обычные отряды на всём поле.
final class ScorchAbility extends SpecialAbility {
  const ScorchAbility();

  static const String effectKey = 'scorch';

  @override
  String get key => effectKey;

  @override
  List<Object?> get props => const [];
}

/// Мардрём: занимает слот рога ряда и превращает Берсерков этого ряда.
final class MardremCardAbility extends SpecialAbility {
  const MardremCardAbility();

  static const String effectKey = 'mardroeme';

  @override
  String get key => effectKey;

  @override
  List<Object?> get props => const [];
}
