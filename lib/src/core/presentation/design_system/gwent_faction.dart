import 'dart:ui';

import 'package:gwent/src/core/presentation/design_system/gwent_colors.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_icon.dart';

/// Фракция в оформлении: цвет поля герба, тонкой метки на плашке и обложки колоды (макет, «Фракции»).
///
/// Цвет фракции не годится для текста на тёмном фоне. Нейтральные карты (фракция `common` в данных) в макете
/// не описаны: у них латунная полоса и нет герба.
enum GwentFaction {
  /// Королевства Севера (`northern_realms`).
  northernRealms('northern_realms', Color(0xFF3E6FA8), GwentColors.gold, GwentIcon.crestNorthernRealms),

  /// Нильфгаард (`nilfgaardian_empire`).
  nilfgaard('nilfgaardian_empire', Color(0xFF1A1A1A), Color(0xFFC9A64A), GwentIcon.crestNilfgaard),

  /// Чудовища (`monsters`).
  monsters('monsters', Color(0xFF9E2B25), GwentColors.gold, GwentIcon.crestMonsters),

  /// Скоя'таэли (`scoia_tael`).
  scoiatael('scoia_tael', Color(0xFF4F7A3A), GwentColors.gold, GwentIcon.crestScoiatael),

  /// Скеллиге (`skellige`).
  skellige('skellige', Color(0xFF6B4C8A), GwentColors.gold, GwentIcon.crestSkellige),

  /// Нейтральные карты (`common`).
  neutral('common', GwentColors.brass, GwentColors.gold, null)
  ;

  const GwentFaction(this.key, this.color, this.charge, this.crest);

  /// Ключ фракции в пакете контента.
  final String key;

  /// Цвет фракции: поле герба, полоса на плашке карты, кант лидера.
  final Color color;

  /// Цвет фигуры герба.
  final Color charge;

  /// Герб; у нейтральных карт его нет.
  final GwentIcon? crest;

  /// Свечение фона экранов старта и передачи телефона в цвете фракции (макет 4): 30 % цвета поля герба, у
  /// Нильфгаарда чёрное поле не светится, поэтому берётся золото герба, 14 %.
  Color get glow => this == nilfgaard ? charge.withValues(alpha: 0.14) : color.withValues(alpha: 0.30);

  /// Фракция по ключу из пакета контента; неизвестный ключ считается нейтральным.
  static GwentFaction fromKey(String key) => values.firstWhere((f) => f.key == key, orElse: () => neutral);
}
