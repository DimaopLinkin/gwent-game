import 'package:flutter/widgets.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_colors.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_space.dart';

/// Кнопка паузы в полосе погоды (макет 5, раздел 4): круг 30 pt с двумя вертикальными чёрточками.
///
/// Круг в макете меньше 44 pt, поэтому зона нажатия расширена до [GwentSpace.minTapTarget] вокруг круга: сама
/// кнопка занимает 44×44, а рисует круг в центре. Нажатие обрабатывает вся зона.
class PauseButton extends StatelessWidget {
  /// Создаёт кнопку; [semanticsLabel] читает экранный диктор.
  const PauseButton({super.key, required this.onPressed, required this.semanticsLabel});

  /// Сторона зоны нажатия.
  static const double hitSize = GwentSpace.minTapTarget;

  /// Диаметр круга.
  static const double diameter = 30;

  /// Нажатие.
  final VoidCallback onPressed;

  /// Подпись для диктора.
  final String semanticsLabel;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: semanticsLabel,
    excludeSemantics: true,
    onTap: onPressed,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onPressed,
      child: SizedBox.square(
        dimension: hitSize,
        child: Center(
          child: Container(
            width: diameter,
            height: diameter,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                center: Alignment(0, -0.3),
                radius: 0.75,
                colors: [GwentColors.surfaceWarm, GwentColors.pressed],
              ),
              boxShadow: [BoxShadow(color: GwentColors.brass, spreadRadius: 1)],
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              spacing: 4,
              children: [_Bar(), _Bar()],
            ),
          ),
        ),
      ),
    ),
  );
}

class _Bar extends StatelessWidget {
  const _Bar();

  @override
  Widget build(BuildContext context) => const SizedBox(
    width: 3,
    height: 12,
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: GwentColors.textPrimary,
        borderRadius: BorderRadius.all(Radius.circular(1.5)),
      ),
    ),
  );
}
