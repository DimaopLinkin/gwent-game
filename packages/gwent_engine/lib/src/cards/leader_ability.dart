import 'package:gwent_engine/src/cards/ids.dart';
import 'package:gwent_engine/src/cards/row.dart';
import 'package:gwent_engine/src/core/value.dart';

/// Способность лидера (раздел 10 правил).
///
/// Активная применяется один раз за партию вместо хода, пассивная действует всю партию.
sealed class LeaderAbility extends Value {
  const LeaderAbility();

  /// Машинный ключ эффекта для проверки совместимости пакета контента.
  String get key;

  /// Пассивная способность действует сама; применить её как ход нельзя.
  bool get isPassive => false;
}

/// Взять из своей колоды карту погоды [card] и сразу сыграть её (Король Темерии, Йож из Эрленвальда,
/// Истинная эльфка).
final class PlayWeatherFromDeckAbility extends LeaderAbility {
  const PlayWeatherFromDeckAbility(this.card);

  static const String effectKey = 'leader_play_weather_from_deck';

  final CardId card;

  @override
  String get key => effectKey;

  @override
  List<Object?> get props => [card];
}

/// Снять всю погоду без карты (Предводитель Севера).
final class ClearAllWeatherAbility extends LeaderAbility {
  const ClearAllWeatherAbility();

  static const String effectKey = 'leader_clear_weather';

  @override
  String get key => effectKey;

  @override
  List<Object?> get props => const [];
}

/// Рог лидера в слот своего ряда [row] до конца раунда, если слот свободен.
final class LeaderHornAbility extends LeaderAbility {
  const LeaderHornAbility(this.row);

  static const String effectKey = 'leader_horn';

  final Row row;

  @override
  String get key => effectKey;

  @override
  List<Object?> get props => [row];
}

/// Казнь по ряду [row] соперника с порогом [threshold].
final class ScorchOpponentRowAbility extends LeaderAbility {
  const ScorchOpponentRowAbility(this.row, {this.threshold = 10});

  static const String effectKey = 'leader_scorch_row';

  final Row row;
  final int threshold;

  @override
  String get key => effectKey;

  @override
  List<Object?> get props => [row, threshold];
}

/// Посмотреть [count] случайных карт руки соперника (Император Нильфгаарда).
final class RevealOpponentHandAbility extends LeaderAbility {
  const RevealOpponentHandAbility({this.count = 3});

  static const String effectKey = 'leader_reveal_hand';

  final int count;

  @override
  String get key => effectKey;

  @override
  List<Object?> get props => [count];
}

/// Пассивная: отключает способность лидера соперника (Белое Пламя).
final class DisableOpponentLeaderAbility extends LeaderAbility {
  const DisableOpponentLeaderAbility();

  static const String effectKey = 'leader_disable_opponent';

  @override
  String get key => effectKey;

  @override
  bool get isPassive => true;

  @override
  List<Object?> get props => const [];
}

/// Взять в руку обычный отряд из отбоя соперника (Властелин Юга).
final class TakeFromOpponentDiscardAbility extends LeaderAbility {
  const TakeFromOpponentDiscardAbility();

  static const String effectKey = 'leader_take_opponent_discard';

  @override
  String get key => effectKey;

  @override
  List<Object?> get props => const [];
}

/// Пассивная: у обоих игроков Медик выбирает отряд случайно (Завоеватель Севера).
final class RandomMedicAbility extends LeaderAbility {
  const RandomMedicAbility();

  static const String effectKey = 'leader_random_medic';

  @override
  String get key => effectKey;

  @override
  bool get isPassive => true;

  @override
  List<Object?> get props => const [];
}

/// Вернуть в руку обычный отряд из своего отбоя (Владыка Тир на Лиа).
final class ReturnFromDiscardAbility extends LeaderAbility {
  const ReturnFromDiscardAbility();

  static const String effectKey = 'leader_return_from_discard';

  @override
  String get key => effectKey;

  @override
  List<Object?> get props => const [];
}

/// Сбросить [discard] карт из руки, затем взять [take] выбранных карт из колоды (Убийца Оберона).
final class DiscardAndTakeFromDeckAbility extends LeaderAbility {
  const DiscardAndTakeFromDeckAbility({this.discard = 2, this.take = 1});

  static const String effectKey = 'leader_discard_and_take';

  final int discard;
  final int take;

  @override
  String get key => effectKey;

  @override
  List<Object?> get props => [discard, take];
}

/// Выбрать в колоде любую карту погоды или Ясное небо и сразу сыграть её (Командир Дикой Охоты).
final class PickWeatherFromDeckAbility extends LeaderAbility {
  const PickWeatherFromDeckAbility();

  static const String effectKey = 'leader_pick_weather';

  @override
  String get key => effectKey;

  @override
  List<Object?> get props => const [];
}

/// Пассивная: сила всех шпионов у обоих игроков удваивается (Вероломный).
final class DoubleSpiesAbility extends LeaderAbility {
  const DoubleSpiesAbility();

  static const String effectKey = 'leader_double_spies';

  @override
  String get key => effectKey;

  @override
  bool get isPassive => true;

  @override
  List<Object?> get props => const [];
}

/// Пассивная: при раздаче игрок берёт на [count] карт больше (Маргаритка из Долин).
final class ExtraStartingCardsAbility extends LeaderAbility {
  const ExtraStartingCardsAbility({this.count = 1});

  static const String effectKey = 'leader_extra_starting_cards';

  final int count;

  @override
  String get key => effectKey;

  @override
  bool get isPassive => true;

  @override
  List<Object?> get props => [count];
}

/// Переставить свои проворные обычные отряды так, чтобы сила ближнего и дальнего рядов была наибольшей
/// (Надежда Aen Seidhe).
final class OptimizeAgileAbility extends LeaderAbility {
  const OptimizeAgileAbility();

  static const String effectKey = 'leader_optimize_agile';

  @override
  String get key => effectKey;

  @override
  List<Object?> get props => const [];
}

/// Пассивная: на своей стороне погода уменьшает силу вдвое, но не ниже 1 (Король Бран).
final class HalveWeatherAbility extends LeaderAbility {
  const HalveWeatherAbility();

  static const String effectKey = 'leader_halve_weather';

  @override
  String get key => effectKey;

  @override
  bool get isPassive => true;

  @override
  List<Object?> get props => const [];
}

/// Отбой каждого игрока замешивается в его колоду (Крах ан Крайт).
final class ShuffleDiscardsIntoDecksAbility extends LeaderAbility {
  const ShuffleDiscardsIntoDecksAbility();

  static const String effectKey = 'leader_shuffle_discards';

  @override
  String get key => effectKey;

  @override
  List<Object?> get props => const [];
}
