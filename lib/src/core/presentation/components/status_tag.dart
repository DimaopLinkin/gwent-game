import 'package:flutter/widgets.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_text.dart';

/// Метка-«бирка»: короткая надпись Cormorant SC на плотной подложке («Доступен», «Готова», «Колода не готова»).
class StatusTag extends StatelessWidget {
  /// Создаёт метку.
  const StatusTag(this.text, {super.key, required this.background, required this.color, this.ring});

  /// Текст.
  final String text;

  /// Цвет подложки.
  final Color background;

  /// Цвет текста.
  final Color color;

  /// Цвет тонкой рамки или `null`, если рамки нет.
  final Color? ring;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(3),
      border: ring == null ? null : Border.all(color: ring!),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: Text(
        text,
        textAlign: TextAlign.center,
        textScaler: TextScaler.noScaling,
        style: TextStyle(
          fontFamily: GwentText.cormorant,
          fontWeight: FontWeight.w700,
          fontSize: 12,
          height: 1.1,
          letterSpacing: 12 * 0.05,
          color: color,
        ),
      ),
    ),
  );
}
