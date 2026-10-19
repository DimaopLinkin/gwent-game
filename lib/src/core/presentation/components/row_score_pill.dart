import 'package:flutter/widgets.dart';
import 'package:gwent/src/core/l10n/l10n.dart';
import 'package:gwent/src/core/presentation/components/rolling_number.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_colors.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_text.dart';

/// Как сила ряда соотносится с базовой силой его карт: цвет кольца пилюли.
enum RowScoreTone {
  /// Без изменений: латунь.
  neutral,

  /// Ряд усилен (Рог, Прилив сил, Прочная связь): зелёное кольцо.
  boosted,

  /// Ряд ослаблен погодой: красное кольцо.
  weakened,
}

/// Сила ряда на поле (макет поля, «Горизонтальная сетка»): пилюля не уже 26×24 pt с кольцом цвета [tone].
///
/// Компактная версия `RowScoreBadge` из макета дизайн-системы: в ряду на поле колонке слева отведено 34 pt, и круг
/// 32 pt вместе со слотом рога в 80 pt высоты ряда не помещается.
class RowScorePill extends StatelessWidget {
  /// Создаёт пилюлю силы ряда [score].
  const RowScorePill({super.key, required this.score, this.tone = RowScoreTone.neutral, this.roll});

  /// Высота.
  static const double height = 24;

  /// Наименьшая ширина.
  static const double minWidth = 26;

  /// Сила ряда.
  final int score;

  /// Сравнение с базовой силой.
  final RowScoreTone tone;

  /// Сила прокручивается (анимации карт): вместо [score] показывается она.
  final RollValue? roll;

  @override
  Widget build(BuildContext context) {
    final ring = switch (tone) {
      RowScoreTone.neutral => GwentColors.brass,
      RowScoreTone.boosted => GwentColors.buff,
      RowScoreTone.weakened => GwentColors.debuff,
    };
    final style = GwentText.powerCard.copyWith(fontSize: score >= 100 || (roll?.to ?? 0) >= 100 ? 12 : 14);
    return Semantics(
      label: context.l10n.rowScoreSemantics(score),
      excludeSemantics: true,
      child: Container(
        constraints: const BoxConstraints(minWidth: minWidth),
        height: height,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(height / 2),
          gradient: const RadialGradient(
            center: Alignment(0, -0.3),
            radius: 0.9,
            colors: [GwentColors.surfaceRaised, GwentColors.bg],
            stops: [0, 0.8],
          ),
          boxShadow: [BoxShadow(color: ring, spreadRadius: 1.5)],
        ),
        // Без alignment у контейнера: он растянулся бы на всю колонку, а пилюля должна быть по цифре.
        child: Center(
          widthFactor: 1,
          child: roll == null
              ? Text('$score', textScaler: TextScaler.noScaling, style: style)
              : RollingNumber(roll!, style: style),
        ),
      ),
    );
  }
}
