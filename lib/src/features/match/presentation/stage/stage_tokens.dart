import 'package:flutter/animation.dart';
import 'package:meta/meta.dart';

/// Токены движения из макета 12 (длительности в миллисекундах при обычной скорости).
///
/// Имена сохранены из таблицы «Производные длительности» макета, чтобы их можно было сверять один к одному.
abstract final class StageTokens {
  /// Перестроение веера руки и ряда.
  static const int fan = 180;

  /// Подписи, плашки, затухание; при «Уменьшить движение» появление карты в ряду.
  static const int fade = 180;

  /// Проявление бейджа силы на карте.
  static const int badge = 100;

  /// Посадка: масштаб 1,1 → 1 и тень.
  static const int land = 120;

  /// Переворот рубашка → лицо.
  static const int flip = 200;

  /// Интервал между картами Двойника.
  static const int twin = 120;

  /// Полёт карты по дуге (рука → ряд, слот, колода).
  static const int flight = 400;

  /// Короткий перелёт: сброс, возврат, соперник → ряд.
  static const int flightShort = 300;

  /// Прокрутка цифр (вертикальный счётчик).
  static const int roll = 320;

  /// Подсветка прироста (зелёная) или потери (красная).
  static const int highlight = 400;

  /// Волна эффекта по ряду.
  static const int wave = 400;

  /// Обзор целей Казни.
  static const int target = 400;

  /// Сгорание: фронт огня снизу вверх и пепел.
  static const int burn = 450;

  /// Берсерк → медведь: разворот по Y.
  static const int morph = 450;

  /// Пауза «соперник думает».
  static const int think = 300;

  /// Карта крупно (особые карты, ход соперника).
  static const int hold = 700;

  /// Карта погоды крупно.
  static const int holdWeather = 600;

  /// Казнь крупно.
  static const int holdScorch = 800;

  /// Мини-карта лидера в центре.
  static const int leader = 600;

  /// Ясное небо: эффект «выдыхается».
  static const int clear = 700;

  /// Быстрая скорость: доля обычных длительностей (в том числе показа карт).
  static const double fastFactor = 0.55;

  /// Во сколько раз тап ускоряет текущую сцену.
  static const double tapSpeedUp = 6;

  /// Кривая для полётов и прокрутки.
  static const Curve out = Cubic(0.22, 1, 0.36, 1);

  /// Кривая для переворота, волн и сгорания.
  static const Curve inOut = Cubic(0.65, 0, 0.35, 1);
}

/// Как показывать анимации: скорость и режим «Уменьшить движение».
///
/// Длительности сценария считаются один раз при сборке: [ms] приводит токен к выбранной скорости.
@immutable
final class StageStyle {
  /// Создаёт стиль; [scale] — доля обычных длительностей (1 или [StageTokens.fastFactor]).
  const StageStyle({this.scale = 1, this.reduceMotion = false});

  /// Обычная скорость, полное движение.
  static const StageStyle normal = StageStyle();

  /// Доля обычных длительностей.
  final double scale;

  /// Системная настройка «Уменьшить движение»: вместо полётов короткие появления на месте назначения.
  final bool reduceMotion;

  /// Длительность токена [normal] мс при выбранной скорости.
  int ms(int normal) => (normal * scale).round();

  /// Длительность появления на месте при «Уменьшить движение» (150–200 мс по макету).
  int get appear => ms(StageTokens.fade);

  @override
  bool operator ==(Object other) => other is StageStyle && other.scale == scale && other.reduceMotion == reduceMotion;

  @override
  int get hashCode => Object.hash(scale, reduceMotion);
}
