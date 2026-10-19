import 'package:gwent_engine/src/cards/ids.dart';
import 'package:gwent_engine/src/cards/row.dart';
import 'package:gwent_engine/src/core/value.dart';

/// Способность карты отряда (раздел 9.4 правил).
///
/// Логика способности живёт в движке, параметры приходят из пакета контента.
/// Проворство не способность, а размещение карты ([UnitPlacement.agile]).
sealed class UnitAbility extends Value {
  const UnitAbility();

  /// Машинный ключ эффекта для проверки совместимости пакета контента.
  String get key;
}

/// Шпион: карта ложится на сторону соперника, сыгравший берёт [draw] карт.
final class SpyAbility extends UnitAbility {
  const SpyAbility({this.draw = 2});

  static const String effectKey = 'spy';

  final int draw;

  @override
  String get key => effectKey;

  @override
  List<Object?> get props => [draw];
}

/// Медик: из своего отбоя выбирается обычный отряд и сразу разыгрывается.
final class MedicAbility extends UnitAbility {
  const MedicAbility();

  static const String effectKey = 'medic';

  @override
  String get key => effectKey;

  @override
  List<Object?> get props => const [];
}

/// Двойник: при выходе карты на поле из колоды и руки выкладываются все карты [summons].
///
/// Связь несимметрична и задаётся у каждой карты отдельно (в данных это `twin_config`).
final class MusterAbility extends UnitAbility {
  const MusterAbility(this.summons);

  static const String effectKey = 'muster';

  /// Карты, которые призывает эта карта, в порядке призыва.
  final List<CardId> summons;

  @override
  String get key => effectKey;

  @override
  List<Object?> get props => [summons];
}

/// Прочная связь: сила умножается на число карт этого же определения в ряду.
final class TightBondAbility extends UnitAbility {
  const TightBondAbility();

  static const String effectKey = 'tight_bond';

  @override
  String get key => effectKey;

  @override
  List<Object?> get props => const [];
}

/// Прилив сил: +1 всем другим обычным отрядам ряда.
final class MoraleBoostAbility extends UnitAbility {
  const MoraleBoostAbility();

  static const String effectKey = 'morale_boost';

  @override
  String get key => effectKey;

  @override
  List<Object?> get props => const [];
}

/// Командирский рог у отряда (Лютик): удваивает другие обычные отряды ряда, слот рога не занимает.
final class UnitHornAbility extends UnitAbility {
  const UnitHornAbility();

  static const String effectKey = 'commander_horn';

  @override
  String get key => effectKey;

  @override
  List<Object?> get props => const [];
}

/// Казнь по ряду: при выходе карты уничтожает сильнейшие обычные отряды ряда [row] соперника,
/// если сила этого ряда не меньше [threshold].
final class ScorchRowAbility extends UnitAbility {
  const ScorchRowAbility(this.row, {this.threshold = 10});

  static const String effectKey = 'scorch_row';

  final Row row;
  final int threshold;

  @override
  String get key => effectKey;

  @override
  List<Object?> get props => [row, threshold];
}

/// Казнь всего поля при выходе карты (Пират из клана Димун). Карта может уничтожить и себя.
final class ScorchAllAbility extends UnitAbility {
  const ScorchAllAbility();

  static const String effectKey = 'scorch';

  @override
  String get key => effectKey;

  @override
  List<Object?> get props => const [];
}

/// Приманка: когда карта уходит с поля, на её место выкладывается созданная карта [summon].
final class BaitAbility extends UnitAbility {
  const BaitAbility(this.summon);

  static const String effectKey = 'bait';

  final CardId summon;

  @override
  String get key => effectKey;

  @override
  List<Object?> get props => [summon];
}

/// Берсерк: в ряду с Мардрёмом превращается в созданную карту [transformsInto].
final class BerserkAbility extends UnitAbility {
  const BerserkAbility(this.transformsInto);

  static const String effectKey = 'berserk';

  final CardId transformsInto;

  @override
  String get key => effectKey;

  @override
  List<Object?> get props => [transformsInto];
}

/// Мардрём у отряда (Мышовур): пока карта в ряду, ряд считается рядом с Мардрёмом.
final class MardremAuraAbility extends UnitAbility {
  const MardremAuraAbility();

  static const String effectKey = 'mardroeme';

  @override
  String get key => effectKey;

  @override
  List<Object?> get props => const [];
}
