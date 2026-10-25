import 'package:flutter/widgets.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_colors.dart';

/// Как выглядит цель хода, пока выбрана карта (макет 14, ADR 0010).
enum TargetLook {
  /// Не цель: ничего не рисуется.
  none,

  /// Допустимая цель: слабо горит золотом.
  candidate,

  /// Цель под пальцем: горит ярко и принимает карту. Яркая цель всегда ровно одна.
  hot,
}

/// Подсветка цели хода поверх зоны: рамка и заливка золотом (макет 14).
///
/// Допустимая цель горит на 35 % без мигания, цель под пальцем на 100 % с мягким свечением. Смена состояния идёт
/// 120 мс (при «Уменьшить движение» сразу). Касания проходят сквозь подсветку: цели ловят нажатия и броски сами.
class TargetHighlight extends StatelessWidget {
  /// Создаёт подсветку со скруглением [radius].
  const TargetHighlight({super.key, required this.look, this.radius = 0});

  /// Прозрачность допустимой цели.
  static const double candidateAlpha = 0.35;

  /// Длительность смены состояния цели.
  static const Duration duration = Duration(milliseconds: 120);

  /// Состояние цели.
  final TargetLook look;

  /// Радиус скругления рамки.
  final double radius;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(radius);
    final decoration = switch (look) {
      TargetLook.none => BoxDecoration(
        borderRadius: borderRadius,
        border: Border.all(color: GwentColors.gold.withValues(alpha: 0), width: 1.5),
      ),
      TargetLook.candidate => BoxDecoration(
        color: GwentColors.gold.withValues(alpha: 0.05),
        borderRadius: borderRadius,
        border: Border.all(color: GwentColors.gold.withValues(alpha: candidateAlpha), width: 1.5),
      ),
      TargetLook.hot => BoxDecoration(
        color: GwentColors.gold.withValues(alpha: 0.16),
        borderRadius: borderRadius,
        border: Border.all(color: GwentColors.gold, width: 2),
        boxShadow: const [BoxShadow(color: Color(0x73C8A35B), blurRadius: 14)],
      ),
    };
    return Positioned.fill(
      child: IgnorePointer(
        child: AnimatedContainer(
          duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : duration,
          decoration: decoration,
        ),
      ),
    );
  }
}
