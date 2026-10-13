import 'package:flutter/widgets.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_colors.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_space.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_text.dart';

/// Вид большой кнопки экранов вокруг поля.
enum GwentButtonStyle {
  /// Главное действие экрана: золотая двойная рамка и свечение, как у «Пас».
  primary,

  /// Второстепенное действие: тонкая латунная рамка.
  secondary,

  /// Опасное действие («Сдаться»): приглушённый красный контур.
  danger,
}

/// Большая кнопка-«пилюля» экранов старта, итогов, паузы и главного меню (макеты 4–6).
///
/// Без [onPressed] кнопка недоступна: тусклая рамка и текст, нажатие не принимается. Высота не меньше
/// [GwentSpace.minTapTarget]. Текст не следует масштабу системы: размеры заданы макетом.
class GwentButton extends StatefulWidget {
  /// Создаёт кнопку.
  const GwentButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.style = GwentButtonStyle.primary,
    this.height = 54,
    this.fontSize = 22,
    this.solid = false,
    this.labelColor,
    this.semanticsLabel,
  }) : assert(height >= GwentSpace.minTapTarget, 'зона нажатия не меньше 44 pt');

  /// Подпись.
  final String label;

  /// Нажатие; `null` — кнопка недоступна.
  final VoidCallback? onPressed;

  /// Вид кнопки.
  final GwentButtonStyle style;

  /// Высота кнопки.
  final double height;

  /// Размер подписи.
  final double fontSize;

  /// У второстепенной кнопки непрозрачная тёмная заливка (на фоне стола), иначе фон просвечивает.
  final bool solid;

  /// Цвет подписи, если он отличается от обычного (подсвеченная кнопка); у недоступной кнопки не действует.
  final Color? labelColor;

  /// Подпись для экранного диктора, если она отличается от видимой.
  final String? semanticsLabel;

  @override
  State<GwentButton> createState() => _GwentButtonState();
}

class _GwentButtonState extends State<GwentButton> {
  bool _pressed = false;
  bool _focused = false;

  bool get _enabled => widget.onPressed != null;

  @override
  Widget build(BuildContext context) {
    final enabled = _enabled;
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.semanticsLabel ?? widget.label,
      onTap: widget.onPressed,
      excludeSemantics: true,
      child: Focus(
        canRequestFocus: enabled,
        onFocusChange: (focused) => setState(() => _focused = focused),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
          onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
          onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
          onTap: widget.onPressed,
          child: Transform.translate(
            offset: Offset(0, _pressed ? 1 : 0),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(GwentSpace.radiusPill),
                boxShadow: _focused
                    ? const [BoxShadow(color: GwentColors.focusRing, spreadRadius: GwentSpace.focusRingOffset + 2)]
                    : null,
              ),
              child: _surface(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _surface() {
    final enabled = _enabled;
    final text = Text(
      widget.label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
      textScaler: TextScaler.noScaling,
      style: TextStyle(
        fontFamily: GwentText.cormorant,
        fontWeight: FontWeight.w700,
        fontSize: widget.fontSize,
        height: 1,
        letterSpacing: widget.fontSize * 0.06,
        color: _textColor(enabled),
      ),
    );
    final padded = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Center(child: text),
    );
    return switch (widget.style) {
      GwentButtonStyle.primary when enabled => _primary(padded),
      GwentButtonStyle.primary => _flat(padded, fill: const Color(0xCC14110E), ring: GwentColors.panelLine, width: 1),
      GwentButtonStyle.secondary when enabled => _flat(
        padded,
        fill: widget.solid ? const Color(0xE614110E) : null,
        ring: GwentColors.muted,
        width: 1,
      ),
      GwentButtonStyle.secondary => _flat(padded, fill: const Color(0xCC14110E), ring: GwentColors.panelLine, width: 1),
      GwentButtonStyle.danger => _flat(
        padded,
        ring: enabled ? GwentColors.dangerRing : GwentColors.panelLine,
        width: 1.5,
      ),
    };
  }

  Color _textColor(bool enabled) {
    if (!enabled) return GwentColors.muted;
    return widget.labelColor ??
        switch (widget.style) {
          GwentButtonStyle.danger => GwentColors.errorText,
          GwentButtonStyle.primary || GwentButtonStyle.secondary => GwentColors.textPrimary,
        };
  }

  /// Золотая кнопка: кольцо золота, кольцо фона, тонкая латунь и свечение (как у «Пас», макет 5).
  Widget _primary(Widget child) => Container(
    height: widget.height,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(GwentSpace.radiusPill),
      color: _pressed ? GwentColors.pressed : null,
      gradient: _pressed
          ? null
          : const RadialGradient(
              center: Alignment(0, -0.4),
              radius: 1.1,
              colors: [GwentColors.surfaceWarm, GwentColors.surface],
              stops: [0, 0.7],
            ),
      boxShadow: [
        if (!_pressed) const BoxShadow(color: Color(0x4DC8A35B), blurRadius: 16),
        const BoxShadow(color: GwentColors.gold, spreadRadius: 1.5),
      ],
    ),
    child: DecoratedBox(
      decoration: const ShapeDecoration(
        shape: StadiumBorder(side: BorderSide(color: GwentColors.bg, width: 2.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(2.5),
        child: DecoratedBox(
          decoration: const ShapeDecoration(
            shape: StadiumBorder(side: BorderSide(color: GwentColors.brass)),
          ),
          child: child,
        ),
      ),
    ),
  );

  Widget _flat(Widget child, {Color? fill, required Color ring, required double width}) => Container(
    height: widget.height,
    decoration: ShapeDecoration(
      color: _pressed ? GwentColors.pressed : fill,
      shape: StadiumBorder(
        side: BorderSide(color: ring, width: width),
      ),
    ),
    child: child,
  );
}
