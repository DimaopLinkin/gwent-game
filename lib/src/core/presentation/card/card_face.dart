import 'package:flutter/painting.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_faction.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_icon.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_weather.dart';

/// Что нарисовано на лицевой стороне карты: вариант карты и данные для него (макет карты, «Варианты»).
///
/// Это модель отображения, а не данные пакета контента: её собирает `CardContentMapper` из пакета или экран из
/// состояния партии (текущая сила, иней на ряду, использованная способность лидера).
sealed class CardFace {
  const CardFace({required this.art});

  /// Арт карты; `null` — заглушка.
  final ImageProvider? art;

  /// Название карты для плашки и экранного диктора.
  String get name;
}

/// Отряд или герой: сила в медальоне, под ним иконки ряда и способности.
final class UnitCardFace extends CardFace {
  /// Создаёт отряд.
  const UnitCardFace({
    required super.art,
    required this.name,
    required this.faction,
    required this.basePower,
    required this.row,
    int? power,
    this.ability,
    this.isHero = false,
    this.frosted = false,
  }) : power = power ?? basePower;

  @override
  final String name;

  /// Фракция: полоса на плашке.
  final GwentFaction faction;

  /// Сила по данным карты.
  final int basePower;

  /// Текущая сила на поле; выше базовой — зелёная ▲, ниже — красная ▼. У героя не меняется.
  final int power;

  /// Иконка ряда.
  final GwentIcon row;

  /// Иконка способности; `null` — способности нет.
  final GwentIcon? ability;

  /// Герой: золотая рамка, золотой медальон, погода и способности на него не действуют.
  final bool isHero;

  /// Отряд под погодой: иней на арте. У героя не рисуется.
  final bool frosted;
}

/// Особая карта: вместо силы латунный медальон эффекта.
final class SpecialCardFace extends CardFace {
  /// Создаёт особую карту.
  const SpecialCardFace({required super.art, required this.name, required this.faction, required this.effect});

  @override
  final String name;

  /// Фракция: полоса на плашке.
  final GwentFaction faction;

  /// Иконка эффекта.
  final GwentIcon effect;
}

/// Погода: тёмный медальон, рамка и подсветка арта цветом погоды.
final class WeatherCardFace extends CardFace {
  /// Создаёт карту погоды.
  const WeatherCardFace({required super.art, required this.name, required this.weather});

  @override
  final String name;

  /// Погода.
  final GwentWeather weather;
}

/// Лидер: герб вместо силы и метка способности справа сверху.
final class LeaderCardFace extends CardFace {
  /// Создаёт лидера.
  const LeaderCardFace({
    required super.art,
    required this.name,
    required this.faction,
    this.abilityUsed = false,
  });

  @override
  final String name;

  /// Фракция: герб и кант рамки.
  final GwentFaction faction;

  /// Способность лидера уже использована.
  final bool abilityUsed;
}

/// Рубашка: колода и закрытые карты.
final class CardBackFace extends CardFace {
  /// Создаёт рубашку фракции [faction].
  const CardBackFace({required this.faction}) : super(art: null);

  /// Фракция: герб на рубашке.
  final GwentFaction faction;

  @override
  String get name => '';
}
