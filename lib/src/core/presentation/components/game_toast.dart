import 'package:flutter/widgets.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_colors.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_icon.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_icon_view.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_space.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_text.dart';

/// Тост в игре (макет дизайн-системы, `toast`): пергаментная плашка с иконкой.
///
/// Экран показывает его на 3 с сверху, под плашкой противника. Ошибка отличается красной рамкой и своей иконкой, а не
/// только цветом.
class GameToast extends StatelessWidget {
  /// Создаёт тост с сообщением [message] и иконкой [icon].
  const GameToast({super.key, required this.message, required this.icon, this.isError = false});

  /// Сколько тост держится на экране.
  static const Duration visibleFor = Duration(seconds: 3);

  /// Текст.
  final String message;

  /// Иконка слева.
  final GwentIcon icon;

  /// Сообщение об ошибке.
  final bool isError;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    label: message,
    excludeSemantics: true,
    child: DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [GwentColors.parchmentLight, GwentColors.parchmentShade],
        ),
        borderRadius: BorderRadius.circular(GwentSpace.radiusS),
        border: Border.all(color: isError ? GwentColors.debuff : GwentColors.brass),
        boxShadow: const [BoxShadow(color: Color(0x8C080502), offset: Offset(0, 6), blurRadius: 16)],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          spacing: 12,
          children: [
            GwentIconView(icon, size: 20, color: isError ? GwentColors.debuff : GwentColors.onParchment),
            Expanded(
              child: Text(
                message,
                textScaler: TextScaler.noScaling,
                style: const TextStyle(
                  fontFamily: GwentText.alegreya,
                  fontWeight: FontWeight.w500,
                  fontSize: 15,
                  height: 1.3,
                  color: GwentColors.onParchment,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
