import 'package:flutter/widgets.dart';
import 'package:gwent/src/core/l10n/l10n.dart';
import 'package:gwent/src/core/presentation/components/chevron_button.dart';
import 'package:gwent/src/core/presentation/components/screen_backdrop.dart';
import 'package:gwent/src/core/presentation/components/screen_labels.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_colors.dart';
import 'package:gwent/src/features/match/presentation/start/start_parts.dart';

// Общие части экранов выбора фракции, лидера и колоды перед партией (макет 7).

/// Основа экрана выбора: фон стола и безопасные зоны. Сверху остаётся отступ 14 pt под строку состояния.
class SetupScaffold extends StatelessWidget {
  /// Создаёт основу; [child] ложится в безопасную область.
  const SetupScaffold({super.key, required this.child});

  /// Содержимое экрана.
  final Widget child;

  @override
  Widget build(BuildContext context) => ScreenBackdrop(
    child: Padding(padding: const EdgeInsets.only(top: 14), child: child),
  );
}

/// Шапка шага: кнопка «назад», надпись над заголовком, заголовок и необязательная подпись; справа [trailing].
class SetupHeader extends StatelessWidget {
  /// Создаёт шапку.
  const SetupHeader({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.onBack,
    this.subtitle,
    this.trailing,
    this.titleSize = 30,
  });

  /// Надпись над заголовком, например «Шаг 2 из 2».
  final String eyebrow;

  /// Заголовок.
  final String title;

  /// Подпись под заголовком, например название фракции.
  final String? subtitle;

  /// Что стоит справа, например герб фракции.
  final Widget? trailing;

  /// Размер заголовка.
  final double titleSize;

  /// Нажатие «назад».
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) => Row(
    spacing: 12,
    children: [
      ChevronButton(label: context.l10n.setupBack, onPressed: onBack),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 5,
          children: [
            Eyebrow(eyebrow),
            ScreenTitle(title, size: titleSize, color: GwentColors.goldHighlight),
            if (subtitle != null) StartBody(subtitle!, color: GwentColors.textTertiary, italic: true),
          ],
        ),
      ),
      ?trailing,
    ],
  );
}
