import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:gwent/src/core/l10n/l10n.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_colors.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_icon.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_icon_view.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_text.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_weather.dart';

/// Слот погоды в центральной полосе: какая погода лежит над рядом этого типа.
///
/// [weather] `null` — слот пуст, в нём приглушённая иконка ряда [rowIcon].
typedef WeatherSlot = ({GwentIcon rowIcon, GwentWeather? weather});

/// Центральная полоса поля (макет поля, «Центральная полоса»): высота 40 pt между рядами соперника и моими.
///
/// Слева три слота погоды ⌀28 (ближний, дальний, осадный), по центру статус хода, справа номер раунда и ромбы
/// раундов. Когда в руке выбрана карта погоды, вся полоса — цель хода: золотая рамка и свечение.
class WeatherStrip extends StatelessWidget {
  /// Создаёт полосу.
  const WeatherStrip({
    super.key,
    required this.slots,
    required this.status,
    required this.round,
    this.statusActive = true,
    this.isTarget = false,
    this.onTap,
    this.showPauseSlot = false,
  }) : assert(slots.length == 3, 'слотов погоды три: ближний, дальний и осадный ряды');

  /// Высота полосы.
  static const double height = 40;

  /// Погода над ближним, дальним и осадным рядами.
  final List<WeatherSlot> slots;

  /// Текст статуса хода.
  final String status;

  /// Статус подсвечен золотом (ваш ход), иначе приглушён.
  final bool statusActive;

  /// Номер раунда, 1…3.
  final int round;

  /// Полоса — цель хода.
  final bool isTarget;

  /// Тап по полосе.
  final VoidCallback? onTap;

  /// Справа оставлено место под кнопку паузы: сама кнопка лежит поверх полосы (её зона нажатия больше полосы).
  final bool showPauseSlot;

  /// Сколько места справа занимает кнопка паузы: круг 30 pt и отступ 2 pt.
  static const double pauseSlotWidth = 32;

  @override
  Widget build(BuildContext context) {
    final statusColor = statusActive ? GwentColors.goldHighlight : GwentColors.textSecondary;
    return Semantics(
      button: isTarget,
      onTap: isTarget ? onTap : null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          height: height,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF120F0C), Color(0xFF1C1712), Color(0xFF120F0C)],
              stops: [0, 0.5, 1],
            ),
            border: Border.symmetric(horizontal: BorderSide(color: GwentColors.brass)),
          ),
          foregroundDecoration: isTarget
              ? BoxDecoration(
                  color: GwentColors.gold.withValues(alpha: 0.12),
                  border: Border.all(color: GwentColors.gold, width: 2),
                )
              : null,
          child: Row(
            spacing: 8,
            children: [
              Row(
                spacing: 4,
                children: [for (final slot in slots) _Slot(slot: slot)],
              ),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  spacing: 8,
                  children: [
                    _Diamond(color: statusColor, size: 5),
                    Flexible(
                      child: Text(
                        status,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textScaler: TextScaler.noScaling,
                        style: TextStyle(
                          fontFamily: GwentText.cormorant,
                          fontWeight: FontWeight.w700,
                          fontSize: 17,
                          height: 1,
                          letterSpacing: 0.68,
                          color: statusColor,
                        ),
                      ),
                    ),
                    _Diamond(color: statusColor, size: 5),
                  ],
                ),
              ),
              _RoundMark(round: round),
              if (showPauseSlot) const SizedBox(width: pauseSlotWidth - 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _Slot extends StatelessWidget {
  const _Slot({required this.slot});

  final WeatherSlot slot;

  @override
  Widget build(BuildContext context) {
    final weather = slot.weather;
    final tint = weather?.tint ?? GwentColors.disabledIcon;
    return Semantics(
      label: weather == null ? null : context.l10n.fieldWeatherSlotSemantics,
      excludeSemantics: weather == null,
      child: Container(
        width: 28,
        height: 28,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: GwentColors.bg,
          boxShadow: weather == null
              ? const [BoxShadow(color: GwentColors.line, spreadRadius: 1)]
              : [
                  BoxShadow(color: tint.withValues(alpha: 0.5), blurRadius: 10),
                  BoxShadow(color: tint, spreadRadius: 1.5),
                ],
        ),
        child: GwentIconView(weather?.icon ?? slot.rowIcon, size: 16, color: tint),
      ),
    );
  }
}

class _RoundMark extends StatelessWidget {
  const _RoundMark({required this.round});

  final int round;

  @override
  Widget build(BuildContext context) => Semantics(
    label: context.l10n.bannerRound(round),
    excludeSemantics: true,
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      spacing: 4,
      children: [
        Text(
          context.l10n.bannerRound(round),
          maxLines: 1,
          textScaler: TextScaler.noScaling,
          style: const TextStyle(
            fontFamily: GwentText.cormorant,
            fontWeight: FontWeight.w600,
            fontSize: 12.5,
            height: 1,
            letterSpacing: 0.75,
            color: GwentColors.textSecondary,
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 3,
          children: [
            for (var i = 1; i <= 3; i++)
              Transform.rotate(
                angle: math.pi / 4,
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: i < round
                        ? GwentColors.brass
                        : i == round
                        ? GwentColors.goldHighlight
                        : GwentColors.bg,
                    boxShadow: const [BoxShadow(color: GwentColors.brass, spreadRadius: 1)],
                  ),
                ),
              ),
          ],
        ),
      ],
    ),
  );
}

class _Diamond extends StatelessWidget {
  const _Diamond({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Transform.rotate(
    angle: math.pi / 4,
    child: SizedBox.square(
      dimension: size,
      child: ColoredBox(color: color),
    ),
  );
}
