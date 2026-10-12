import 'package:flutter/widgets.dart';
import 'package:gwent/src/core/l10n/l10n.dart';
import 'package:gwent/src/core/presentation/card/parts/card_coin.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_colors.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_icon.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_icon_view.dart';

/// Что лежит в слоте рога.
enum HornSlotLook {
  /// Пусто: пунктирная рамка.
  empty,

  /// Лежит Командирский рог или Мардрём: мини-карта с монетой эффекта.
  filled,

  /// Выбрана карта рога, слот — цель: золотая рамка, свечение и пульс.
  target,
}

/// Слот рога у ряда (макет дизайн-системы, `hornSlot`): мини-карта 31×44 между бейджем силы ряда и картами, тап-зона
/// 44×44. Мардрём занимает тот же слот.
class HornSlot extends StatefulWidget {
  /// Создаёт слот.
  const HornSlot({
    super.key,
    required this.look,
    this.art,
    this.effect = GwentIcon.abilityCommanderHorn,
    this.effectName,
    this.onTap,
  }) : assert(look != HornSlotLook.filled || effectName != null, 'для занятого слота нужно название карты');

  /// Ширина мини-карты.
  static const double width = 31;

  /// Высота мини-карты.
  static const double height = 44;

  /// Состояние слота.
  final HornSlotLook look;

  /// Арт карты в слоте (при [HornSlotLook.filled]).
  final ImageProvider? art;

  /// Эффект в слоте: рог или Мардрём.
  final GwentIcon effect;

  /// Название карты в слоте для скринридера (при [HornSlotLook.filled]): «Командирский рог» или «Мардрём».
  final String? effectName;

  /// Нажатие: положить рог сюда, когда слот — цель.
  final VoidCallback? onTap;

  @override
  State<HornSlot> createState() => _HornSlotState();
}

class _HornSlotState extends State<HornSlot> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncPulse();
  }

  @override
  void didUpdateWidget(HornSlot oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncPulse();
  }

  void _syncPulse() {
    final animate = widget.look == HornSlotLook.target && !MediaQuery.disableAnimationsOf(context);
    if (animate && !_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    } else if (!animate) {
      _pulse
        ..stop()
        ..value = 1;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final label = switch (widget.look) {
      HornSlotLook.empty => l10n.hornSlotEmpty,
      HornSlotLook.filled => l10n.hornSlotFilled(widget.effectName ?? ''),
      HornSlotLook.target => l10n.hornSlotTargetSemantics,
    };
    return Semantics(
      button: widget.onTap != null,
      label: label,
      onTap: widget.onTap,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: SizedBox.square(
          dimension: 44,
          child: Center(
            child: switch (widget.look) {
              HornSlotLook.empty => const _EmptySlot(),
              HornSlotLook.filled => _FilledSlot(art: widget.art, effect: widget.effect),
              HornSlotLook.target => AnimatedBuilder(
                animation: _pulse,
                builder: (context, _) => _TargetSlot(pulse: _pulse.value),
              ),
            },
          ),
        ),
      ),
    );
  }
}

class _EmptySlot extends StatelessWidget {
  const _EmptySlot();

  @override
  Widget build(BuildContext context) => Container(
    width: HornSlot.width,
    height: HornSlot.height,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: const Color(0x590A0806),
      border: Border.all(color: const Color(0x80C8A35B)),
      borderRadius: BorderRadius.circular(2),
    ),
    child: const GwentIconView(GwentIcon.abilityCommanderHorn, size: 16, color: Color(0x8CA99B80)),
  );
}

class _FilledSlot extends StatelessWidget {
  const _FilledSlot({required this.art, required this.effect});

  final ImageProvider? art;
  final GwentIcon effect;

  @override
  Widget build(BuildContext context) => Stack(
    clipBehavior: Clip.none,
    alignment: Alignment.center,
    children: [
      Container(
        width: HornSlot.width,
        height: HornSlot.height,
        decoration: BoxDecoration(
          color: GwentColors.artPlaceholder,
          image: art == null
              ? null
              : DecorationImage(image: art!, fit: BoxFit.cover, alignment: const Alignment(0, -0.6)),
          borderRadius: BorderRadius.circular(2),
          boxShadow: const [
            BoxShadow(color: GwentColors.brass, spreadRadius: 1),
            BoxShadow(color: Color(0x80000000), offset: Offset(0, 2), blurRadius: 4),
          ],
        ),
      ),
      Positioned(
        bottom: -6,
        child: CardCoin.effect(
          icon: effect,
          diameter: 20,
          iconSize: 13,
          rings: const [BoxShadow(color: Color(0x99000000), offset: Offset(0, 1), blurRadius: 2)],
        ),
      ),
    ],
  );
}

class _TargetSlot extends StatelessWidget {
  const _TargetSlot({required this.pulse});

  final double pulse;

  @override
  Widget build(BuildContext context) => Stack(
    clipBehavior: Clip.none,
    alignment: Alignment.center,
    children: [
      Positioned(
        left: -5,
        top: -5,
        right: -5,
        bottom: -5,
        child: Opacity(
          opacity: 0.25 + 0.75 * pulse,
          child: Transform.scale(
            scale: 1 + 0.07 * pulse,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: const Color(0x80C8A35B)),
              ),
            ),
          ),
        ),
      ),
      Container(
        width: HornSlot.width,
        height: HornSlot.height,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0x24C8A35B),
          border: Border.all(color: GwentColors.gold, width: 1.5),
          borderRadius: BorderRadius.circular(2),
          boxShadow: const [BoxShadow(color: Color(0x73C8A35B), blurRadius: 14)],
        ),
        child: const GwentIconView(GwentIcon.abilityCommanderHorn, size: 16),
      ),
    ],
  );
}
