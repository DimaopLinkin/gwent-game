import 'package:gwent_engine/src/cards/leader_ability.dart';
import 'package:gwent_engine/src/cards/special_ability.dart';
import 'package:gwent_engine/src/cards/unit_ability.dart';

/// Версия движка правил.
///
/// Пакет контента объявляет `min_engine_version`; пакет, которому нужна версия выше этой,
/// приложение не активирует. Номер растёт при каждом изменении поведения движка.
const int engineVersion = 1;

/// Машинные ключи эффектов способностей, которые реализует движок.
///
/// Пакет контента с эффектом не из этого списка несовместим с движком. Ключ — поле `key` у способностей
/// отряда, специальных карт и лидеров; словарь согласован с пакетом контента (поле `effect`). Пять ключей общие
/// для разных видов карт: `commander_horn`, `scorch`, `mardroeme`, `clear_weather`, `scorch_row`.
const Set<String> knownEffects = {
  SpyAbility.effectKey,
  MedicAbility.effectKey,
  MusterAbility.effectKey,
  TightBondAbility.effectKey,
  MoraleBoostAbility.effectKey,
  UnitHornAbility.effectKey,
  ScorchRowAbility.effectKey,
  ScorchAllAbility.effectKey,
  BaitAbility.effectKey,
  BerserkAbility.effectKey,
  MardremAuraAbility.effectKey,
  WeatherAbility.effectKey,
  ClearWeatherAbility.effectKey,
  DecoyAbility.effectKey,
  PlayWeatherFromDeckAbility.effectKey,
  LeaderHornAbility.effectKey,
  RevealOpponentHandAbility.effectKey,
  DisableOpponentLeaderAbility.effectKey,
  TakeFromOpponentDiscardAbility.effectKey,
  RandomMedicAbility.effectKey,
  ReturnFromDiscardAbility.effectKey,
  DiscardAndTakeFromDeckAbility.effectKey,
  PickWeatherFromDeckAbility.effectKey,
  DoubleSpiesAbility.effectKey,
  ExtraStartingCardsAbility.effectKey,
  OptimizeAgileAbility.effectKey,
  HalveWeatherAbility.effectKey,
  ShuffleDiscardsIntoDecksAbility.effectKey,
};

/// Числа перков фракций (раздел 11 правил), с которыми играет движок.
///
/// Пакет контента задаёт их параметрами перков, но логика перков живёт в движке с этими значениями: приложение
/// сверяет с ними пакет и отклоняет пакет с другими числами.
abstract final class PerkNumbers {
  /// Сколько карт берёт игрок Королевств Севера после выигранного раунда.
  static const int northernRealmsDraw = 1;

  /// Сколько случайных отрядов Чудовищ остаётся на поле после раунда. Движок оставляет ровно один
  /// (`FactionPerks.keepRandomUnits`); другое значение потребует изменить его логику.
  static const int monstersKeptUnits = 1;

  /// Сколько случайных отрядов Скеллиге возвращается из отбоя на поле.
  static const int skelligeRevivedUnits = 2;

  /// В начале какого раунда срабатывает перк Скеллиге.
  static const int skelligeReviveRound = 3;
}
