import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:gwent/src/core/l10n/l10n.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_colors.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_space.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_text.dart';

/// Показывает диалог подтверждения (макет дизайн-системы, `confirmDialog`) и возвращает `true`, если игрок
/// подтвердил. Закрытие тапом вне диалога и «Отмена» дают `false`.
///
/// Безопасное действие слева, подтверждающее справа и основным стилем; если подписи не влезают в ряд, кнопки идут
/// столбиком, подтверждение сверху. Фокус по умолчанию на «Отмена».
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
///
/// Кнопки стоят в ряд, пока обе подписи помещаются в одну строку; иначе (длинная подпись, узкий экран, крупный шрифт
/// системы) они встают столбиком на всю ширину, подтверждение сверху. Подпись никогда не переносится по буквам.
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
          child: SingleChildScrollView(
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
                  child: _Actions(confirmLabel: confirmLabel),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

/// Кнопки диалога: «Отмена» и подтверждение, в ряд или столбиком в зависимости от ширины подписей.
class _Actions extends StatelessWidget {
  const _Actions({required this.confirmLabel});

  final String confirmLabel;

  /// Промежуток между кнопками.
  static const double _gap = 12;

  @override
  Widget build(BuildContext context) {
    final cancelLabel = context.l10n.dialogCancel;
    final cancel = OutlinedButton(
      autofocus: true,
      onPressed: () => Navigator.of(context).pop(false),
      child: _Label(cancelLabel),
    );
    final confirm = FilledButton(onPressed: () => Navigator.of(context).pop(true), child: _Label(confirmLabel));
    return LayoutBuilder(
      builder: (context, constraints) {
        final widest = math.max(_width(context, cancelLabel), _width(context, confirmLabel));
        final rowFits = 2 * (widest + 2 * GwentSpace.buttonPadding) + _gap <= constraints.maxWidth;
        return rowFits
            ? Row(
                spacing: _gap,
                children: [
                  Expanded(child: cancel),
                  Expanded(child: confirm),
                ],
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: _gap,
                children: [confirm, cancel],
              );
      },
    );
  }

  /// Ширина подписи в одну строку с учётом масштаба шрифта системы; стиль тот же, что у кнопок темы.
  static double _width(BuildContext context, String label) {
    final painter = TextPainter(
      text: TextSpan(text: label, style: GwentText.label),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final width = painter.width;
    painter.dispose();
    return width;
  }
}

/// Подпись кнопки: одна строка по центру; если не влезла даже на всю ширину, сжимается, а не переносится.
class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => FittedBox(
    fit: BoxFit.scaleDown,
    child: Text(text, maxLines: 1, softWrap: false, textAlign: TextAlign.center),
  );
}
