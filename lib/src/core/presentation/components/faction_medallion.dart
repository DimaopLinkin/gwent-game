import 'package:flutter/widgets.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_colors.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_faction.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_icon_view.dart';

/// Герб фракции в круглой оправе цвета фракции (макеты 7 и 8): тонкое кольцо снаружи, тёмный пояс, свечение за гербом.
///
/// [size] — внешний диаметр. Крупный вариант (выбор фракции) добавляет тонкую линию внутри пояса, малый (шапка
/// конструктора и плашка лобби) обходится без неё.
class FactionMedallion extends StatelessWidget {
  /// Создаёт медальон.
  const FactionMedallion({
    super.key,
    required this.faction,
    required this.size,
    required this.crestSize,
    this.band = 2,
    this.innerLine = false,
    this.glow = true,
  });

  /// Фракция: цвет кольца и герб. У нейтральной герба нет, остаётся пустая оправа.
  final GwentFaction faction;

  /// Внешний диаметр вместе с кольцом.
  final double size;

  /// Сторона герба.
  final double crestSize;

  /// Ширина тёмного пояса между кольцом и гербом.
  final double band;

  /// Рисовать ли тонкую линию цвета фракции на внутренней кромке пояса.
  final bool innerLine;

  /// Рисовать ли свечение цвета фракции за гербом.
  final bool glow;

  @override
  Widget build(BuildContext context) {
    final accent = faction.accent;
    return SizedBox.square(
      dimension: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: glow
              ? RadialGradient(
                  center: const Alignment(0, -0.2),
                  radius: 0.7,
                  colors: [accent.withValues(alpha: 0.28), accent.withValues(alpha: 0)],
                )
              : null,
          border: Border.all(color: accent),
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: GwentColors.bg, width: band),
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: innerLine ? Border.all(color: accent) : null,
            ),
            child: Center(
              child: switch (faction.crest) {
                final crest? => GwentIconView(crest, size: crestSize),
                null => null,
              },
            ),
          ),
        ),
      ),
    );
  }
}
