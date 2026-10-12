import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:gwent/src/core/l10n/l10n.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_colors.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_space.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_text.dart';

/// Кнопка «Пас» (макет дизайн-системы, `passButton`): 56 pt, двойная рамка и свечение свечи.
///
/// Два режима, по настройке «Подтверждать пас». С подтверждением ([holdToPass] = `false`) тап вызывает [onPressed], и
/// экран открывает диалог. Без подтверждения ([holdToPass] = `true`) нужно держать кнопку [holdDuration]: заливка идёт
/// слева направо, над кнопкой появляется подсказка, отпускание раньше отменяет, в конце лёгкая вибрация и [onPressed].
/// Для скринридера удержание заменено обычным нажатием.
class PassButton extends StatefulWidget {
  /// Создаёт кнопку.
  const PassButton({
    super.key,
    required this.onPressed,
    this.enabled = true,
    this.holdToPass = false,
    this.holdDuration = const Duration(seconds: 1),
  });

  /// Высота кнопки.
  static const double height = 56;

  /// Пас оформлен.
  final VoidCallback onPressed;

  /// Сейчас можно пасовать (ваш ход).
  final bool enabled;

  /// Нужно держать кнопку вместо диалога подтверждения.
  final bool holdToPass;

  /// Сколько держать в режиме [holdToPass].
  final Duration holdDuration;

  @override
  State<PassButton> createState() => _PassButtonState();
}

class _PassButtonState extends State<PassButton> with SingleTickerProviderStateMixin {
  late final AnimationController _hold = AnimationController(vsync: this, duration: widget.holdDuration)
    ..addStatusListener(_onHoldStatus);
  bool _pressed = false;
  bool _focused = false;

  @override
  void dispose() {
    _hold.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(PassButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Ход ушёл или режим сменился, пока кнопку держали: удержание отменяется, пас не оформляется.
    if (!widget.enabled || widget.holdToPass != oldWidget.holdToPass) _cancelHold();
  }

  void _cancelHold() {
    _hold
      ..stop()
      ..value = 0;
    _pressed = false;
  }

  void _onHoldStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    unawaited(HapticFeedback.lightImpact());
    _hold.value = 0;
    setState(() => _pressed = false);
    if (widget.enabled) widget.onPressed();
  }

  void _down() {
    if (!widget.enabled) return;
    setState(() => _pressed = true);
    if (widget.holdToPass) _hold.duration = widget.holdDuration;
    if (widget.holdToPass) unawaited(_hold.forward());
  }

  void _up({required bool completedTap}) {
    if (!_pressed) return;
    setState(() => _pressed = false);
    if (widget.holdToPass) {
      if (_hold.status != AnimationStatus.completed) _hold.value = 0;
    } else if (completedTap) {
      widget.onPressed();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final enabled = widget.enabled;
    final holding = widget.holdToPass && _pressed;
    return Semantics(
      button: true,
      enabled: enabled,
      label: l10n.passButtonLabel,
      onTap: enabled ? widget.onPressed : null,
      excludeSemantics: true,
      child: Focus(
        onFocusChange: (focused) => setState(() => _focused = focused),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => _down(),
          onTapUp: (_) => _up(completedTap: true),
          onTapCancel: () => _up(completedTap: false),
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Transform.translate(
                offset: Offset(0, _pressed ? 1 : 0),
                child: AnimatedBuilder(
                  animation: _hold,
                  builder: (context, _) => _PassSurface(
                    enabled: enabled,
                    pressed: _pressed,
                    focused: _focused,
                    progress: _hold.value,
                  ),
                ),
              ),
              if (holding)
                Positioned(
                  bottom: PassButton.height + 8,
                  child: Text(
                    l10n.passButtonHoldHint,
                    textScaler: TextScaler.noScaling,
                    style: const TextStyle(
                      fontFamily: GwentText.alegreya,
                      fontStyle: FontStyle.italic,
                      fontSize: 13,
                      height: 1,
                      color: GwentColors.textSecondary,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PassSurface extends StatelessWidget {
  const _PassSurface({required this.enabled, required this.pressed, required this.focused, required this.progress});

  final bool enabled;
  final bool pressed;
  final bool focused;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final label = context.l10n.passButtonLabel;
    final accent = enabled ? GwentColors.gold : GwentColors.line;
    final textColor = !enabled
        ? GwentColors.muted
        : pressed && progress == 0
        ? GwentColors.gold
        : GwentColors.textPrimary;
    final ringColor = enabled ? GwentColors.brass : GwentColors.surfaceRaised;
    return Container(
      height: PassButton.height,
      constraints: const BoxConstraints(minWidth: 156),
      padding: const EdgeInsets.symmetric(horizontal: 28),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(GwentSpace.radiusPill),
        color: !enabled
            ? GwentColors.surfaceSunken
            : pressed
            ? GwentColors.pressed
            : null,
        gradient: enabled && !pressed
            ? const RadialGradient(
                center: Alignment(0, -0.4),
                radius: 1.1,
                colors: [GwentColors.surfaceWarm, GwentColors.surface],
                stops: [0, 0.7],
              )
            : null,
        // Внешнее кольцо и свечение рисуются тенями вокруг кнопки; внутреннюю двойную рамку (3 pt фона и 1 pt латуни)
        // тени дать не могут, она лежит отдельным слоем поверх заливки.
        boxShadow: [
          if (enabled && !pressed) ...GwentShadows.glowCandle,
          BoxShadow(color: enabled ? GwentColors.gold : GwentColors.panelLine, spreadRadius: 1.5),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(GwentSpace.radiusPill),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: const ShapeDecoration(
                  shape: StadiumBorder(side: BorderSide(color: GwentColors.bg, width: 3)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(3),
                  child: DecoratedBox(
                    decoration: ShapeDecoration(
                      shape: StadiumBorder(side: BorderSide(color: ringColor)),
                    ),
                  ),
                ),
              ),
            ),
            if (progress > 0)
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: progress,
                      child: const DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.horizontal(left: Radius.circular(GwentSpace.radiusPill)),
                          gradient: LinearGradient(colors: [Color(0x1AC8A35B), Color(0x5CC8A35B)]),
                          border: Border(right: BorderSide(color: GwentColors.gold, width: 2)),
                        ),
                        child: SizedBox.expand(),
                      ),
                    ),
                  ),
                ),
              ),
            Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 12,
              children: [
                _Diamond(color: accent),
                Text(
                  label,
                  textScaler: TextScaler.noScaling,
                  style: TextStyle(
                    fontFamily: GwentText.cormorant,
                    fontWeight: FontWeight.w700,
                    fontSize: 26,
                    height: 1,
                    letterSpacing: 1.56,
                    color: textColor,
                  ),
                ),
                _Diamond(color: accent),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Diamond extends StatelessWidget {
  const _Diamond({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => Transform.rotate(
    angle: 0.785398,
    child: SizedBox.square(dimension: 6, child: ColoredBox(color: color)),
  );
}
