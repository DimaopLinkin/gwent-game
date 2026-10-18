import 'package:flutter/widgets.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_colors.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_text.dart';

/// Надпись над заголовком: Cormorant SC, прописные, разрядка 16 %.
class Eyebrow extends StatelessWidget {
  /// Создаёт надпись.
  const Eyebrow(this.text, {super.key, this.size = 13, this.color = GwentColors.textSecondary, this.align});

  /// Текст.
  final String text;

  /// Кегль.
  final double size;

  /// Цвет.
  final Color color;

  /// Выравнивание строк.
  final TextAlign? align;

  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    textAlign: align,
    textScaler: TextScaler.noScaling,
    style: TextStyle(
      fontFamily: GwentText.cormorant,
      fontWeight: FontWeight.w600,
      fontSize: size,
      height: 1.15,
      letterSpacing: size * 0.16,
      color: color,
    ),
  );
}

/// Крупная надпись Cormorant SC.
class ScreenTitle extends StatelessWidget {
  /// Создаёт надпись.
  const ScreenTitle(this.text, {super.key, required this.size, this.color = GwentColors.textPrimary, this.align});

  /// Текст.
  final String text;

  /// Кегль.
  final double size;

  /// Цвет.
  final Color color;

  /// Выравнивание строк.
  final TextAlign? align;

  @override
  Widget build(BuildContext context) => Text(
    text,
    textAlign: align,
    textScaler: TextScaler.noScaling,
    style: TextStyle(
      fontFamily: GwentText.cormorant,
      fontWeight: FontWeight.w700,
      fontSize: size,
      height: 1.04,
      color: color,
    ),
  );
}
