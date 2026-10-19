import 'package:flutter/widgets.dart';
import 'package:gwent/src/core/l10n/l10n.dart';
import 'package:gwent/src/core/presentation/components/gwent_button.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_colors.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_text.dart';

/// Меню паузы (макет 5, раздел 4): панель по центру на затемнённом на 80 % поле.
///
/// «Продолжить» — главное действие, «Правила» и «Настройки» второстепенные, «Сдаться» — приглушённый красный контур,
/// чтобы не нажать случайно. «Настройки» недоступны, если экран настроек не передан ([onSettings] `null`). Нажатие мимо
/// панели продолжает игру.
class PauseMenuLayer extends StatelessWidget {
  /// Создаёт меню паузы.
  const PauseMenuLayer({
    super.key,
    required this.onResume,
    required this.onRules,
    required this.onSurrender,
    this.onSettings,
  });

  /// Продолжить игру.
  final VoidCallback onResume;

  /// Открыть правила.
  final VoidCallback onRules;

  /// Спросить, сдаваться ли.
  final VoidCallback onSurrender;

  /// Открыть настройки; `null` — кнопка недоступна.
  final VoidCallback? onSettings;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return _Dimmed(
      color: const Color(0xCC0A0806),
      onDismissed: onResume,
      child: _Panel(
        ringColor: GwentColors.brass,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 14,
          children: [
            Text(
              l10n.pauseTitle,
              textScaler: TextScaler.noScaling,
              style: const TextStyle(
                fontFamily: GwentText.cormorant,
                fontWeight: FontWeight.w700,
                fontSize: 38,
                height: 1,
                letterSpacing: 38 * 0.04,
                color: GwentColors.goldHighlight,
              ),
            ),
            const SizedBox(
              width: 120,
              height: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [Color(0x008C6A3F), GwentColors.brass, Color(0x008C6A3F)]),
                ),
              ),
            ),
            SizedBox(
              width: double.infinity,
              child: GwentButton(label: l10n.pauseResume, height: 58, fontSize: 24, onPressed: onResume),
            ),
            SizedBox(
              width: double.infinity,
              child: GwentButton(
                label: l10n.pauseRules,
                style: GwentButtonStyle.secondary,
                height: 52,
                fontSize: 21,
                onPressed: onRules,
              ),
            ),
            SizedBox(
              width: double.infinity,
              child: GwentButton(
                label: l10n.pauseSettings,
                style: GwentButtonStyle.secondary,
                height: 52,
                fontSize: 21,
                onPressed: onSettings,
              ),
            ),
            SizedBox(
              width: double.infinity,
              child: GwentButton(
                label: l10n.pauseSurrender,
                style: GwentButtonStyle.danger,
                height: 52,
                fontSize: 21,
                onPressed: onSurrender,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Подтверждение сдачи (макет 5, раздел 4): «Сдаться?», «Отмена» с золотым кольцом и «Сдаться» красным контуром.
class SurrenderConfirmLayer extends StatelessWidget {
  /// Создаёт подтверждение.
  const SurrenderConfirmLayer({super.key, required this.onCancel, required this.onConfirm});

  /// Передумал: назад в меню паузы.
  final VoidCallback onCancel;

  /// Сдаться.
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return _Dimmed(
      color: const Color(0xDB0A0806),
      onDismissed: onCancel,
      child: _Panel(
        ringColor: GwentColors.dangerPanelRing,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 12,
          children: [
            Text(
              l10n.surrenderTitle,
              textAlign: TextAlign.center,
              textScaler: TextScaler.noScaling,
              style: const TextStyle(
                fontFamily: GwentText.cormorant,
                fontWeight: FontWeight.w700,
                fontSize: 36,
                height: 1,
                color: GwentColors.textPrimary,
              ),
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 250),
              child: Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  l10n.surrenderBody,
                  textAlign: TextAlign.center,
                  textScaler: TextScaler.noScaling,
                  style: const TextStyle(
                    fontFamily: GwentText.alegreya,
                    fontWeight: FontWeight.w500,
                    fontSize: 17,
                    height: 1.35,
                    color: GwentColors.textTertiary,
                  ),
                ),
              ),
            ),
            Row(
              spacing: 12,
              children: [
                Expanded(
                  child: GwentButton(label: l10n.dialogCancel, fontSize: 21, onPressed: onCancel),
                ),
                Expanded(
                  child: GwentButton(
                    label: l10n.pauseSurrender,
                    style: GwentButtonStyle.danger,
                    fontSize: 21,
                    onPressed: onConfirm,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Dimmed extends StatelessWidget {
  const _Dimmed({required this.color, required this.onDismissed, required this.child});

  final Color color;
  final VoidCallback onDismissed;
  final Widget child;

  @override
  Widget build(BuildContext context) => Semantics(
    scopesRoute: true,
    explicitChildNodes: true,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onDismissed,
      child: ColoredBox(
        color: color,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            // Нажатие по панели не должно закрывать слой.
            child: GestureDetector(onTap: () {}, child: child),
          ),
        ),
      ),
    ),
  );
}

class _Panel extends StatelessWidget {
  const _Panel({required this.ringColor, required this.child});

  final Color ringColor;
  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(6),
      gradient: const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF1B1612), GwentColors.bg],
      ),
      boxShadow: [
        BoxShadow(color: ringColor, spreadRadius: 1),
        const BoxShadow(color: Color(0xB3000000), blurRadius: 50, offset: Offset(0, 20)),
      ],
    ),
    child: Padding(padding: const EdgeInsets.fromLTRB(22, 28, 22, 24), child: child),
  );
}
