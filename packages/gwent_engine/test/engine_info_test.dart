import 'package:gwent_engine/gwent_engine.dart';
import 'package:test/test.dart';

void main() {
  test('версия движка положительна', () {
    expect(engineVersion, greaterThan(0));
  });

  test('ключи эффектов уникальны внутри каждого вида способностей', () {
    const unit = [
      SpyAbility(),
      MedicAbility(),
      MusterAbility([]),
      TightBondAbility(),
      MoraleBoostAbility(),
      UnitHornAbility(),
      ScorchRowAbility(Row.melee),
      ScorchAllAbility(),
      BaitAbility(CardId('x')),
      BerserkAbility(CardId('x')),
      MardremAuraAbility(),
    ];
    const special = [
      WeatherAbility({}),
      ClearWeatherAbility(),
      HornCardAbility(),
      DecoyAbility(),
      ScorchAbility(),
      MardremCardAbility(),
    ];
    const leader = [
      PlayWeatherFromDeckAbility(CardId('x')),
      ClearAllWeatherAbility(),
      LeaderHornAbility(Row.melee),
      ScorchOpponentRowAbility(Row.melee),
      RevealOpponentHandAbility(),
      DisableOpponentLeaderAbility(),
      TakeFromOpponentDiscardAbility(),
      RandomMedicAbility(),
      ReturnFromDiscardAbility(),
      DiscardAndTakeFromDeckAbility(),
      PickWeatherFromDeckAbility(),
      DoubleSpiesAbility(),
      ExtraStartingCardsAbility(),
      OptimizeAgileAbility(),
      HalveWeatherAbility(),
      ShuffleDiscardsIntoDecksAbility(),
    ];
    for (final keys in [
      unit.map((ability) => ability.key),
      special.map((ability) => ability.key),
      leader.map((ability) => ability.key),
    ]) {
      expect(keys.toSet(), hasLength(keys.length));
      expect(knownEffects, containsAll(keys));
    }
    // Одинаковое действие у разных видов карт — один эффект.
    expect(knownEffects, hasLength(unit.length + special.length + leader.length - 5));
    expect(knownEffects, containsAll(['commander_horn', 'scorch', 'mardroeme', 'clear_weather', 'scorch_row']));
  });
}
