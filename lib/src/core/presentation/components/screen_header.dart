import 'package:flutter/widgets.dart';
import 'package:gwent/src/core/l10n/l10n.dart';
import 'package:gwent/src/core/presentation/components/chevron_button.dart';
import 'package:gwent/src/core/presentation/components/screen_labels.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_colors.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_space.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_text.dart';

/// Шапка экрана с кнопкой «назад»: одна на все экраны, где есть стрелка «Назад».
///
/// Стрелка стоит у левого края безопасной области с полем [GwentSpace.space4] и по высоте посередине шапки, как
/// ведущая кнопка навигации в платформенных гайдлайнах. Она не часть ряда: поле шапки не зависит от отступов
/// содержимого экрана, поэтому шапку кладут над ними, а не внутрь. Надпись, заголовок и подпись стоят по центру
/// между стрелкой и [trailing]; слева и справа для них отведено одинаково, чтобы центр не смещался.
class ScreenHeader extends StatelessWidget {
  /// Создаёт шапку. Нужна хотя бы одна из надписей [eyebrow] и [title].
  const ScreenHeader({
    super.key,
    required this.onBack,
    this.eyebrow,
    this.title,
    this.subtitle,
    this.trailing,
    this.titleSize = 30,
    this.backLabel,
  }) : assert(eyebrow != null || title != null, 'в шапке нужна надпись или заголовок');

  /// Нажатие «назад».
  final VoidCallback onBack;

  /// Надпись над заголовком, например «Шаг 2 из 2».
  final String? eyebrow;

  /// Заголовок. Длинный сжимается до одной строки, а не обрезается.
  final String? title;

  /// Подпись под заголовком, например название фракции.
  final String? subtitle;

  /// Что стоит у правого края, например герб фракции. Занимает зону [slot].
  final Widget? trailing;

  /// Размер заголовка.
  final double titleSize;

  /// Подпись кнопки для экранного диктора; по умолчанию «Назад».
  final String? backLabel;

  /// Поле стрелки от края безопасной области.
  static const double inset = GwentSpace.space4;

  /// Отступ сверху до шапки: у всех экранов одинаковый.
  static const double topMargin = 14;

  /// Зона под [trailing] и под стрелку: поле, кнопка 44 pt и просвет до надписи.
  static const double slot = inset + GwentSpace.minTapTarget + GwentSpace.space3;

  @override
  Widget build(BuildContext context) {
    final eyebrow = this.eyebrow;
    final title = this.title;
    final subtitle = this.subtitle;
    final trailing = this.trailing;
    return Padding(
      padding: const EdgeInsets.only(top: topMargin),
      // Во всю ширину, даже если родитель (`Column` с центровкой) даёт шапке только ширину содержимого.
      child: SizedBox(
        width: double.infinity,
        child: Stack(
          alignment: Alignment.center,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: GwentSpace.minTapTarget),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: slot),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  spacing: 4,
                  children: [
                    ?(eyebrow == null ? null : Eyebrow(eyebrow, size: 14, align: TextAlign.center)),
                    ?(title == null
                        ? null
                        : FittedBox(
                            fit: BoxFit.scaleDown,
                            child: ScreenTitle(title, size: titleSize, color: GwentColors.goldHighlight),
                          )),
                    ?(subtitle == null
                        ? null
                        : Text(
                            subtitle,
                            textAlign: TextAlign.center,
                            textScaler: TextScaler.noScaling,
                            style: const TextStyle(
                              fontFamily: GwentText.alegreya,
                              fontWeight: FontWeight.w500,
                              fontStyle: FontStyle.italic,
                              fontSize: 15,
                              height: 1.3,
                              color: GwentColors.textTertiary,
                            ),
                          )),
                  ],
                ),
              ),
            ),
            Positioned.fill(
              child: Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(left: inset),
                  child: ChevronButton(label: backLabel ?? context.l10n.setupBack, onPressed: onBack),
                ),
              ),
            ),
            if (trailing != null)
              Positioned.fill(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.only(right: inset),
                    child: trailing,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
