import 'package:flutter/widgets.dart';
import 'package:gwent/src/core/l10n/l10n.dart';
import 'package:gwent/src/core/presentation/card/parts/card_coin.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_colors.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_icon.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_icon_view.dart';

/// Что лежит в слоте рога и как он выглядит при прицеливании (макет 14).
enum HornSlotLook {
  /// Пусто: пунктирная рамка.
  empty,

  /// Лежит Командирский рог или Мардрём: мини-карта с монетой эффекта.
  filled,

  /// Выбрана карта рога, пустой слот — допустимая цель: слабая золотая рамка.
  target,

  /// Выбрана карта рога, слот занят — допустимая цель: на старом роге слабая янтарная рамка. Новый рог уйдёт в отбой.
  targetFilled,

  /// Палец над пустым слотом: яркий «призрак» рога.
  ghost,

  /// Палец над занятым слотом: янтарный призрак со значком сброса, старый рог слегка тускнеет.
  ghostReplace
  ;

  /// Слот — цель хода в любом из состояний.
  bool get isTarget => this == target || this == targetFilled || this == ghost || this == ghostReplace;

  /// В слоте уже лежит карта.
  bool get isOccupied => this == filled || this == targetFilled || this == ghostReplace;
}

/// Слот рога у ряда (макет дизайн-системы, `hornSlot`): мини-карта 31×44 между бейджем силы ряда и картами, тап-зона
/// 44×44. Мардрём занимает тот же слот.
class HornSlot extends StatelessWidget {
  /// Создаёт слот. [ghostLabel] — микро-подпись призрака («×2»); она не нужна, пока слот не цель под пальцем.
  const HornSlot({
    super.key,
    required this.look,
    this.art,
    this.effect = GwentIcon.abilityCommanderHorn,
    this.effectName,
    this.ghostLabel,
    this.onTap,
  }) : assert(
         effectName != null ||
             (look != HornSlotLook.filled && look != HornSlotLook.targetFilled && look != HornSlotLook.ghostReplace),
         'для занятого слота нужно название карты',
       );

  /// Ширина мини-карты.
  static const double width = 31;

  /// Высота мини-карты.
  static const double height = 44;

  /// Состояние слота.
  final HornSlotLook look;

  /// Арт карты в слоте, если он занят.
  final ImageProvider? art;

  /// Эффект в слоте: рог или Мардрём.
  final GwentIcon effect;

  /// Название карты в слоте для скринридера, если он занят: «Командирский рог» или «Мардрём».
  final String? effectName;

  /// Микро-подпись призрака в пустом слоте, например «×2»; `null` — без подписи.
  final String? ghostLabel;

  /// Нажатие: положить рог сюда, когда слот — цель.
  final VoidCallback? onTap;

  static const Duration _fade = Duration(milliseconds: 120);

  /// Янтарь занятого слота: чем он отличается от золота пустого, видно слабо, поэтому на нём ещё значок сброса.
  static const Color amber = Color(0xFFE0A03C);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final label = look.isTarget
        ? l10n.hornSlotTargetSemantics
        : look.isOccupied
        ? l10n.hornSlotFilled(effectName ?? '')
        : l10n.hornSlotEmpty;
    return Semantics(
      button: onTap != null,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox.square(
          dimension: 44,
          child: Center(
            // Вид слота перетекает за то же время, что и рамка ряда (`TargetHighlight.duration`): иначе слот щёлкает,
            // а рамка ещё гаснет, и смена ряда выглядит как лаг.
            child: AnimatedSwitcher(
              duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : _fade,
              child: KeyedSubtree(
                key: ValueKey(look),
                child: switch (look) {
                  HornSlotLook.empty => const _EmptySlot(),
                  HornSlotLook.filled => _FilledSlot(art: art, effect: effect),
                  HornSlotLook.target => const _TargetSlot(hot: false),
                  HornSlotLook.ghost => _TargetSlot(hot: true, label: ghostLabel),
                  HornSlotLook.targetFilled => _FilledSlot(art: art, effect: effect, ring: _Ring.weak),
                  HornSlotLook.ghostReplace => _FilledSlot(art: art, effect: effect, ring: _Ring.hot),
                },
              ),
            ),
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

enum _Ring { none, weak, hot }

class _FilledSlot extends StatelessWidget {
  const _FilledSlot({required this.art, required this.effect, this.ring = _Ring.none});

  final ImageProvider? art;
  final GwentIcon effect;
  final _Ring ring;

  @override
  Widget build(BuildContext context) {
    const amber = HornSlot.amber;
    final card = Stack(
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
    if (ring == _Ring.none) return card;
    final hot = ring == _Ring.hot;
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        Opacity(opacity: hot ? 0.55 : 1, child: card),
        Positioned(
          left: -4,
          top: -4,
          right: -4,
          bottom: -4,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: hot ? amber : amber.withValues(alpha: 0.35), width: hot ? 2 : 1.5),
                color: hot ? amber.withValues(alpha: 0.16) : null,
                boxShadow: hot ? const [BoxShadow(color: Color(0x73E0A03C), blurRadius: 14)] : null,
              ),
            ),
          ),
        ),
        if (hot)
          const Positioned(
            top: -2,
            right: -6,
            child: DecoratedBox(
              decoration: BoxDecoration(color: GwentColors.bg, shape: BoxShape.circle),
              child: Padding(
                padding: EdgeInsets.all(2),
                child: GwentIconView(GwentIcon.iconDiscard, size: 12, color: amber),
              ),
            ),
          ),
      ],
    );
  }
}

class _TargetSlot extends StatelessWidget {
  const _TargetSlot({required this.hot, this.label});

  final bool hot;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final label = this.label;
    return Container(
      width: HornSlot.width,
      height: HornSlot.height,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: hot ? const Color(0x3DC8A35B) : const Color(0x0DC8A35B),
        border: Border.all(
          color: hot ? GwentColors.gold : GwentColors.gold.withValues(alpha: 0.35),
          width: hot ? 2 : 1.5,
        ),
        borderRadius: BorderRadius.circular(2),
        boxShadow: hot ? const [BoxShadow(color: Color(0x73C8A35B), blurRadius: 14)] : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Opacity(
            opacity: hot ? 1 : 0.5,
            child: const GwentIconView(GwentIcon.abilityCommanderHorn, size: 16),
          ),
          if (hot && label != null)
            Text(
              label,
              maxLines: 1,
              textScaler: TextScaler.noScaling,
              style: const TextStyle(
                fontSize: 10,
                height: 1.1,
                fontWeight: FontWeight.w700,
                color: GwentColors.goldHighlight,
              ),
            ),
        ],
      ),
    );
  }
}
