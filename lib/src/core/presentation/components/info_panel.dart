import 'package:flutter/widgets.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_colors.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_text.dart';

/// Панель с рамкой для текста способности (фон `#14110E` 92 %, рамка линии).
class InfoPanel extends StatelessWidget {
  /// Создаёт панель.
  const InfoPanel({super.key, required this.child, this.minHeight = 0});

  /// Содержимое.
  final Widget child;

  /// Минимальная высота.
  final double minHeight;

  @override
  Widget build(BuildContext context) => Container(
    constraints: BoxConstraints(minHeight: minHeight),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      color: const Color(0xEB14110E),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: GwentColors.line),
    ),
    child: child,
  );
}

/// Надпись над текстом в панели: Alegreya 12 pt, прописные, разрядка 14 %.
class InfoPanelLabel extends StatelessWidget {
  /// Создаёт надпись.
  const InfoPanelLabel(this.text, {super.key});

  /// Текст.
  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    textScaler: TextScaler.noScaling,
    style: const TextStyle(
      fontFamily: GwentText.alegreya,
      fontWeight: FontWeight.w700,
      fontSize: 12,
      height: 1,
      letterSpacing: 12 * 0.14,
      color: GwentColors.textSecondary,
    ),
  );
}
