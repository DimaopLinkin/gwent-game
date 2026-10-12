import 'package:flutter/material.dart';
import 'package:gwent/src/core/l10n/l10n.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_colors.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_space.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_text.dart';

/// Показывает диалог подтверждения (макет дизайн-системы, `confirmDialog`) и возвращает `true`, если игрок
/// подтвердил. Закрытие тапом вне диалога и «Отмена» дают `false`.
///
/// Безопасное действие слева, подтверждающее справа и основным стилем; фокус по умолчанию на «Отмена».
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String body,
  required String confirmLabel,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    barrierColor: GwentColors.scrim,
    builder: (context) => ConfirmDialog(title: title, body: body, confirmLabel: confirmLabel),
  );
  return confirmed ?? false;
}

/// Содержимое диалога подтверждения: заголовок, пояснение и две кнопки.
class ConfirmDialog extends StatelessWidget {
  /// Создаёт диалог.
  const ConfirmDialog({super.key, required this.title, required this.body, required this.confirmLabel});

  /// Заголовок вопроса.
  final String title;

  /// Что произойдёт при подтверждении.
  final String body;

  /// Подпись подтверждающей кнопки.
  final String confirmLabel;

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: Colors.transparent,
    elevation: 0,
    insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 326),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [GwentColors.surfaceRaised, Color(0xFF241D16)],
          ),
          borderRadius: BorderRadius.circular(GwentSpace.radiusM),
          boxShadow: const [
            BoxShadow(color: GwentColors.brass, spreadRadius: 1),
            BoxShadow(color: Color(0xB30A0603), offset: Offset(0, 12), blurRadius: 32),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            spacing: 12,
            children: [
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: GwentText.cormorant,
                  fontWeight: FontWeight.w600,
                  fontSize: 26,
                  height: 1.1,
                  color: GwentColors.textPrimary,
                ),
              ),
              Text(
                body,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: GwentText.alegreya,
                  fontSize: 15,
                  height: 21 / 15,
                  color: GwentColors.textSecondary,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  spacing: 12,
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        autofocus: true,
                        onPressed: () => Navigator.of(context).pop(false),
                        child: Text(context.l10n.dialogCancel),
                      ),
                    ),
                    Expanded(
                      child: FilledButton(onPressed: () => Navigator.of(context).pop(true), child: Text(confirmLabel)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
