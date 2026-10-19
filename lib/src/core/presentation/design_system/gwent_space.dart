import 'package:flutter/painting.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_colors.dart';

/// Сетка и форма (макет, раздел «Сетка и форма», `GwentSpace`): отступы с шагом 4 pt, радиусы, рамки и тени.
///
/// 1 pt макета равен одному логическому пикселю Flutter.
abstract final class GwentSpace {
  /// 4 pt.
  static const double space1 = 4;

  /// 8 pt.
  static const double space2 = 8;

  /// 12 pt.
  static const double space3 = 12;

  /// 16 pt: боковые поля экрана.
  static const double space4 = 16;

  /// 20 pt.
  static const double space5 = 20;

  /// 24 pt.
  static const double space6 = 24;

  /// 32 pt.
  static const double space8 = 32;

  /// 40 pt.
  static const double space10 = 40;

  /// 48 pt.
  static const double space12 = 48;

  /// Радиус карты.
  static const double radiusXs = 2;

  /// Радиус ряда, плашки, тоста.
  static const double radiusS = 4;

  /// Радиус кнопок и диалога.
  static const double radiusM = 6;

  /// Радиус верхних углов нижнего листа.
  static const double radiusL = 16;

  /// Радиус «пилюли»: кнопка «Пас», переключатель.
  static const double radiusPill = 999;

  /// Толщина разделителей ([GwentColors.line]).
  static const double borderLine = 1;

  /// Толщина латунной окантовки ([GwentColors.brass]).
  static const double borderBrass = 1;

  /// Толщина активной рамки ([GwentColors.gold]).
  static const double borderGold = 1.5;

  /// Толщина кольца фокуса.
  static const double focusRingWidth = 2;

  /// Отступ кольца фокуса от элемента.
  static const double focusRingOffset = 3;

  /// Зона нажатия: всегда 44 pt, даже если видимый элемент меньше.
  static const double minTapTarget = 44;

  /// Высота основной и второстепенной кнопки.
  static const double buttonHeight = 48;

  /// Боковые отступы кнопки.
  static const double buttonPadding = 24;
}

/// Тени дизайн-системы: тёплые, без глянца.
abstract final class GwentShadows {
  /// 0 1 2, 60 %.
  static const List<BoxShadow> low = [BoxShadow(color: Color(0x990A0603), offset: Offset(0, 1), blurRadius: 2)];

  /// 0 4 12, 55 %.
  static const List<BoxShadow> mid = [BoxShadow(color: Color(0x8C0A0603), offset: Offset(0, 4), blurRadius: 12)];

  /// 0 12 32, 70 %.
  static const List<BoxShadow> high = [BoxShadow(color: Color(0xB30A0603), offset: Offset(0, 12), blurRadius: 32)];

  /// Свечение свечи: 0 0 24 золото 28 % поверх латунной окантовки.
  static const List<BoxShadow> glowCandle = [
    BoxShadow(color: GwentColors.brass, spreadRadius: 1),
    BoxShadow(color: Color(0x47C8A35B), blurRadius: 24),
  ];
}
