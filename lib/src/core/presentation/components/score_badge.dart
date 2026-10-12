import 'package:flutter/widgets.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_colors.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_icon.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_icon_view.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_text.dart';

/// Сила ряда (макет дизайн-системы, `rowScoreBadge`): тёмный кружок 32 pt с латунной обводкой слева от ряда.
///
/// Трёхзначное число набирается 14 pt вместо 16, пустой ряд (0) приглушён.
class RowScoreBadge extends StatelessWidget {
  /// Создаёт бейдж силы ряда [score].
  const RowScoreBadge({super.key, required this.score});

  /// Диаметр.
  static const double diameter = 32;

  /// Сила ряда.
  final int score;

  @override
  Widget build(BuildContext context) {
    final empty = score == 0;
    return Container(
      width: diameter,
      height: diameter,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: empty ? GwentColors.bg : null,
        gradient: empty ? null : _discGradient(GwentColors.surfaceRaised, 0.8),
        boxShadow: empty
            ? const [BoxShadow(color: GwentColors.line, spreadRadius: 1)]
            : const [
                BoxShadow(color: Color(0x99000000), offset: Offset(0, 2), blurRadius: 4),
                BoxShadow(color: GwentColors.brass, spreadRadius: 1.5),
              ],
      ),
      child: Text(
        '$score',
        textScaler: TextScaler.noScaling,
        style: GwentText.scoreRow.copyWith(
          fontSize: score >= 100 ? 14 : 16,
          height: 1,
          color: empty ? GwentColors.muted : GwentColors.textPrimary,
        ),
      ),
    );
  }
}

/// Общий счёт игрока (макет дизайн-системы, `totalScoreBadge`): кружок 52 pt с двойной обводкой; у ведущего —
/// золотая обводка, свечение и корона над числом.
class TotalScoreBadge extends StatelessWidget {
  /// Создаёт бейдж общего счёта [score]; [leading] — игрок ведёт.
  const TotalScoreBadge({super.key, required this.score, this.leading = false, this.diameter = 52});

  /// Общий счёт.
  final int score;

  /// Игрок ведёт по очкам.
  final bool leading;

  /// Диаметр: 52 pt отдельно, 48 pt на плашке игрока.
  final double diameter;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: diameter,
    child: Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: _discGradient(leading ? GwentColors.surfaceWarm : GwentColors.surfaceRaised, 0.75),
              boxShadow: [
                if (leading)
                  const BoxShadow(color: Color(0x4DC8A35B), blurRadius: 20)
                else
                  const BoxShadow(color: Color(0x99000000), offset: Offset(0, 3), blurRadius: 8),
                BoxShadow(color: leading ? GwentColors.brass : GwentColors.line, spreadRadius: 4),
                const BoxShadow(color: GwentColors.bg, spreadRadius: 3),
                BoxShadow(color: leading ? GwentColors.gold : GwentColors.brass, spreadRadius: 1.5),
              ],
            ),
          ),
        ),
        Text(
          '$score',
          textScaler: TextScaler.noScaling,
          style: GwentText.scoreTotal.copyWith(fontSize: 22, height: 1, color: GwentColors.textPrimary),
        ),
        if (leading)
          Positioned(
            top: -diameter * 0.3,
            child: GwentIconView(GwentIcon.iconCrownLeading, size: diameter * 0.42),
          ),
      ],
    ),
  );
}

/// Тёмный диск со светлым бликом сверху: `radial-gradient(circle at 50% 35%, light, bg end)` из макета.
RadialGradient _discGradient(Color light, double end) => RadialGradient(
  center: const Alignment(0, -0.3),
  radius: 0.7,
  colors: [light, GwentColors.bg],
  stops: [0, end],
);
