import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_colors.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_icon.dart';

/// Иконка дизайн-системы из слота [icon].
///
/// Иконка рисуется цветом [color] (`currentColor` в SVG). Вырезы внутри иконки нарисованы в файле цветом
/// [GwentIconView.cutColorInFile] и перекрашиваются в [cutColor], цвет подложки: на латунной монете это латунь,
/// на тёмной монете фон стола. Гербы ([GwentIcon.isCrest]) рисуются своими цветами.
class GwentIconView extends StatelessWidget {
  /// Создаёт иконку размером [size]×[size].
  const GwentIconView(
    this.icon, {
    super.key,
    required this.size,
    this.color = GwentColors.gold,
    this.cutColor = GwentColors.bg,
    this.semanticsLabel,
  });

  /// Цвет вырезов в файлах иконок.
  static const Color cutColorInFile = GwentColors.bg;

  /// Слот иконки.
  final GwentIcon icon;

  /// Сторона квадрата иконки.
  final double size;

  /// Цвет иконки.
  final Color color;

  /// Цвет вырезов: цвет того, на чём лежит иконка.
  final Color cutColor;

  /// Подпись для экранного диктора; без неё иконка декоративная.
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) => SvgPicture.asset(
    icon.assetPath,
    width: size,
    height: size,
    theme: SvgTheme(currentColor: color),
    colorMapper: icon.isCrest || cutColor == cutColorInFile ? null : _CutColorMapper(cutColor),
    semanticsLabel: semanticsLabel,
    excludeFromSemantics: semanticsLabel == null,
  );
}

/// Перекрашивает вырезы. Сравнивается по значению: от этого зависит кэш разобранных SVG.
@immutable
final class _CutColorMapper extends ColorMapper {
  const _CutColorMapper(this.cutColor);

  final Color cutColor;

  @override
  Color substitute(String? id, String elementName, String attributeName, Color color) =>
      color == GwentIconView.cutColorInFile ? cutColor : color;

  @override
  bool operator ==(Object other) => other is _CutColorMapper && other.cutColor == cutColor;

  @override
  int get hashCode => cutColor.hashCode;
}
