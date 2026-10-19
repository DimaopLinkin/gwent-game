import 'package:gwent/src/features/sound/domain/sound_effect.dart';
import 'package:gwent_engine/gwent_engine.dart';

/// Звук отряда, вставшего в ряд [row] (героя озвучивает [SoundEffect.hero], шпиона — [SoundEffect.spy]).
SoundEffect soundOfRow(Row row) => switch (row) {
  Row.melee => SoundEffect.unitMelee,
  Row.ranged => SoundEffect.unitRanged,
  Row.siege => SoundEffect.unitSiege,
};

/// Звук способности отряда в момент выхода на поле; `null`, если у способности нет своего звука.
///
/// Здесь только то, что звучит при выходе самого отряда. Рог и Мардрём озвучивает слот рога, Казнь — сгорание,
/// Медика и Двойника — призыв карт: у них свои моменты в сценарии. Крепкую связь отряд озвучивает, только если в ряду
/// есть пара: это решает сборщик сценария.
SoundEffect? soundOfUnitAbility(UnitAbility? ability) => switch (ability) {
  SpyAbility() => SoundEffect.spy,
  MoraleBoostAbility() => SoundEffect.morale,
  TightBondAbility() => SoundEffect.bond,
  null ||
  MedicAbility() ||
  MusterAbility() ||
  UnitHornAbility() ||
  MardremAuraAbility() ||
  ScorchRowAbility() ||
  ScorchAllAbility() ||
  BaitAbility() ||
  BerserkAbility() => null,
};

/// Звук погоды, которая ложится на [rows]: мороз на ближний бой, туман на дальний, дождь на осадный; шторм Скеллиге,
/// закрывающий сразу несколько рядов, звучит как дождь.
SoundEffect soundOfWeather(Set<Row> rows) => switch (rows.length == 1 ? rows.first : null) {
  Row.melee => SoundEffect.frost,
  Row.ranged => SoundEffect.fog,
  _ => SoundEffect.rain,
};
