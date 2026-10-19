import 'dart:ui';

import 'package:gwent/src/core/presentation/design_system/gwent_colors.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_icon.dart';

/// Погода в оформлении: иконка и цвет подсветки рамки и арта (макет карты, «Погода»).
enum GwentWeather {
  /// Мороз.
  frost(GwentIcon.weatherFrost, GwentColors.frostTint),

  /// Мгла.
  fog(GwentIcon.weatherFog, Color(0xFFD6D0C4)),

  /// Ливень.
  rain(GwentIcon.weatherRain, Color(0xFFC3D4E6)),

  /// Шторм со Скеллиге.
  skelligeStorm(GwentIcon.weatherSkelligeStorm, Color(0xFFBDB4DC)),

  /// Ясное небо.
  clear(GwentIcon.weatherClear, Color(0xFFE3C478))
  ;

  const GwentWeather(this.icon, this.tint);

  /// Иконка погоды.
  final GwentIcon icon;

  /// Цвет подсветки.
  final Color tint;
}
