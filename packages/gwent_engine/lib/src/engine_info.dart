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
/// отряда, специальных карт и лидеров; Командирский рог у отряда и у специальной карты — один эффект `horn`.
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
  ScorchAbility.effectKey,
  MardremCardAbility.effectKey,
  PlayWeatherFromDeckAbility.effectKey,
  ClearAllWeatherAbility.effectKey,
  LeaderHornAbility.effectKey,
  ScorchOpponentRowAbility.effectKey,
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
