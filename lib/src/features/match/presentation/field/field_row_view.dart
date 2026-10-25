import 'package:flutter/widgets.dart' hide Row;
import 'package:gwent/src/core/l10n/l10n.dart';
import 'package:gwent/src/core/presentation/card/card_highlight.dart';
import 'package:gwent/src/core/presentation/card/card_size.dart';
import 'package:gwent/src/core/presentation/card/gwent_card.dart';
import 'package:gwent/src/core/presentation/components/horn_slot.dart';
import 'package:gwent/src/core/presentation/components/rolling_number.dart';
import 'package:gwent/src/core/presentation/components/row_score_pill.dart';
import 'package:gwent/src/core/presentation/components/row_weather_overlay.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_colors.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_icon.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_icon_view.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_weather.dart';
import 'package:gwent/src/features/match/presentation/field/field_content.dart';
import 'package:gwent/src/features/match/presentation/field/field_geometry.dart';
import 'package:gwent/src/features/match/presentation/field/field_overlays.dart';
import 'package:gwent/src/features/match/presentation/stage/stage_frame.dart';
import 'package:gwent_engine/gwent_engine.dart';

/// Один ряд на поле (макет поля, «Z-порядок слоёв»): фон, погодный слой, водяной знак, колонка (сила ряда и слот
/// рога), карты и вуаль погоды.
///
/// Нажатие по ряду принимает весь ряд 80 pt, а не карта: так проще попасть пальцем. Допустимая цель хода слабо
/// горит золотой рамкой, цель под пальцем с картой горит ярко (`TargetHighlight`).
class FieldRowView extends StatelessWidget {
  /// Создаёт ряд типа [row] стороны [mine] с данными проекции [data].
  const FieldRowView({
    super.key,
    required this.geometry,
    required this.content,
    required this.row,
    required this.mine,
    required this.data,
    this.isTarget = false,
    this.hornTarget = false,
    this.hornLabel,
    this.decoyTargets = const {},
    this.recent = const {},
    this.staged,
    this.strengthRoll,
    this.flashes = const {},
    this.onTap,
    this.canDrop,
    this.onDrop,
    this.onCardTap,
    this.onCardLongPress,
    this.onDragEnter,
    this.onDragLeave,
    this.canDropOnCard,
    this.onDropOnCard,
  });

  /// Размеры зон поля.
  final FieldGeometry geometry;

  /// Мост к контенту партии.
  final FieldContent content;

  /// Тип ряда.
  final Row row;

  /// Ряд мой или соперника.
  final bool mine;

  /// Как ряд называет себя перед `DragHover`: переход пальца на другой ряд отличается от движения внутри ряда.
  Object get _target => (row: row, mine: mine);

  /// Ряд в проекции: карты, слот рога, погода, сила.
  final RowView data;

  /// Ряд — допустимая цель хода (слабая подсветка); под пальцем с картой ряд горит ярко.
  final bool isTarget;

  /// Слот рога этого ряда — цель хода: в нём призрак рога, когда над рядом палец с картой.
  final bool hornTarget;

  /// Микро-подпись призрака рога («×2»); `null` — без подписи (Мардрём).
  final String? hornLabel;

  /// Мои карты на этом ряду, на которые можно положить Чучело.
  final Set<CardInstanceId> decoyTargets;

  /// Карты, которые только что легли на стол.
  final Set<CardInstanceId> recent;

  /// Ряд на этот момент показа розыгрыша: карты в пути, прячущиеся и проявляющиеся; `null` — ряд как в проекции.
  final StagedRow? staged;

  /// Сила ряда прокручивается (анимации карт).
  final RollValue? strengthRoll;

  /// Подсветка силы карт ряда во время показа.
  final Map<CardInstanceId, CardFlash> flashes;

  /// Нажатие по ряду.
  final VoidCallback? onTap;

  /// Можно ли бросить на ряд карту руки.
  final bool Function(CardInstance card)? canDrop;

  /// Карту руки бросили на ряд.
  final void Function(CardInstance card)? onDrop;

  /// Нажатие по карте на ряду.
  final void Function(CardInstance card)? onCardTap;

  /// Долгое нажатие по карте на ряду.
  final void Function(CardInstance card, int strength)? onCardLongPress;

  /// Палец с картой руки вошёл в цель ряда или карты на нём.
  final void Function(Object target)? onDragEnter;

  /// Палец с картой руки вышел из цели ряда или карты на нём.
  final void Function(Object target)? onDragLeave;

  /// Можно ли бросить карту руки на карту ряда [target] (Чучело).
  final bool Function(CardInstance card, CardInstance target)? canDropOnCard;

  /// Карту руки бросили на карту ряда [target].
  final void Function(CardInstance card, CardInstance target)? onDropOnCard;

  @override
  Widget build(BuildContext context) {
    final rect = geometry.rowRect(row, mine: mine);
    final stage = staged;
    final hasWeather = stage?.weather ?? data.weather;
    final slot = stage == null ? data.slot : stage.slot;
    final weather = hasWeather ? FieldContent.weatherOf(row) : null;
    final staging = stage?.cards;
    final cards = staging == null ? data.cards : [for (final staged in staging) staged.view];
    // Цвет кольца берётся из итога обновления: пока карты едут и числа крутятся, он не мигает.
    final base = data.cards.fold(0, (sum, view) => sum + content.baseStrength(view.card));
    final shown = data.strength;
    final tone = shown > base
        ? RowScoreTone.boosted
        : shown < base
        ? RowScoreTone.weakened
        : RowScoreTone.neutral;
    final area = geometry.cardsArea(row, mine: mine).shift(-rect.topLeft);
    return Positioned.fromRect(
      rect: rect,
      child: DragTarget<CardInstance>(
        onWillAcceptWithDetails: (details) {
          final accepts = canDrop?.call(details.data) ?? false;
          if (accepts) onDragEnter?.call(_target);
          return accepts;
        },
        onLeave: (_) => onDragLeave?.call(_target),
        onAcceptWithDetails: (details) => onDrop?.call(details.data),
        builder: (context, candidates, _) => GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Semantics(
            container: true,
            label: context.l10n.fieldRowSemantics(_rowName(context), data.strength),
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: mine
                      ? const [Color(0xFF2A2119), Color(0xFF231C15)]
                      : const [Color(0xFF201B16), Color(0xFF1C1814)],
                ),
                border: Border(
                  top: mine ? const BorderSide(color: Color(0x990A0806)) : BorderSide.none,
                  bottom: mine ? BorderSide.none : const BorderSide(color: Color(0x990A0806)),
                ),
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: IgnorePointer(child: RowWeatherOverlay(weather: weather)),
                  ),
                  _Watermark(area: area, row: row, weather: weather, hasCards: cards.isNotEmpty),
                  Positioned(
                    left: FieldGeometry.columnLeft,
                    width: FieldGeometry.columnWidth,
                    top: 4,
                    child: Center(
                      child: RowScorePill(score: data.strength, tone: tone, roll: strengthRoll),
                    ),
                  ),
                  Positioned(
                    left: FieldGeometry.columnLeft + 1.5,
                    top: 32,
                    child: _HornSlotView(
                      slot: slot,
                      content: content,
                      target: hornTarget && mine,
                      hot: candidates.isNotEmpty,
                      label: hornLabel,
                    ),
                  ),
                  for (var i = 0; i < cards.length; i++)
                    _FieldCard(
                      key: ValueKey(cards[i].card.id),
                      view: cards[i],
                      content: content,
                      rect: geometry.cardRect(row, i, cards.length, mine: mine).shift(-rect.topLeft),
                      // Следующая карта закрывает медальон: в тесном ряду сила сжимается до видимой полоски.
                      compactWidth: i < cards.length - 1 && geometry.isRowCompact(cards.length)
                          ? geometry.cardStep(cards.length)
                          : null,
                      frosted: hasWeather && row == Row.melee,
                      hidden: staging?[i].hidden ?? false,
                      opacity: staging?[i].opacity ?? 1,
                      flash: flashes[cards[i].card.id],
                      isDecoyTarget: decoyTargets.contains(cards[i].card.id),
                      canDrop: canDropOnCard,
                      onDrop: onDropOnCard,
                      onDragEnter: onDragEnter,
                      onDragLeave: onDragLeave,
                      justPlayed: recent.contains(cards[i].card.id) && !(staging?[i].hidden ?? false),
                      onTap: onCardTap,
                      onLongPress: onCardLongPress,
                    ),
                  if (weather != null)
                    Positioned(
                      left: area.left - 6,
                      right: FieldGeometry.cardsRight,
                      bottom: 0,
                      height: rect.height * 0.45,
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [weather.tint.withValues(alpha: 0), weather.tint.withValues(alpha: 0.28)],
                            ),
                          ),
                        ),
                      ),
                    ),
                  TargetHighlight(
                    look: candidates.isNotEmpty
                        ? TargetLook.hot
                        : isTarget
                        ? TargetLook.candidate
                        : TargetLook.none,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _rowName(BuildContext context) {
    final l10n = context.l10n;
    final name = switch (row) {
      Row.melee => l10n.fieldRowMelee,
      Row.ranged => l10n.fieldRowRanged,
      Row.siege => l10n.fieldRowSiege,
    };
    return mine ? name : l10n.fieldOpponentRow(name);
  }
}

class _Watermark extends StatelessWidget {
  const _Watermark({required this.area, required this.row, required this.weather, required this.hasCards});

  final Rect area;
  final Row row;
  final GwentWeather? weather;
  final bool hasCards;

  @override
  Widget build(BuildContext context) {
    final weather = this.weather;
    final icon = weather?.icon ?? FieldContent.rowIcon(row);
    final color = weather?.tint ?? GwentColors.gold;
    final opacity = weather != null
        ? (hasCards ? 0.45 : 0.75)
        : hasCards
        ? 0.0
        : 0.14;
    return Positioned(
      left: area.center.dx - 14,
      top: area.center.dy - 14,
      child: IgnorePointer(
        child: Opacity(
          opacity: opacity,
          child: GwentIconView(icon, size: 28, color: color),
        ),
      ),
    );
  }
}

class _HornSlotView extends StatelessWidget {
  const _HornSlotView({
    required this.slot,
    required this.content,
    required this.target,
    required this.hot,
    required this.label,
  });

  final RowSlot? slot;
  final FieldContent content;

  /// Слот — цель хода.
  final bool target;

  /// Над рядом палец с картой.
  final bool hot;

  /// Микро-подпись призрака.
  final String? label;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return switch (slot) {
      CardSlot(:final card) => () {
        final isMardrem = content.special(card)?.ability is MardremCardAbility;
        final face = content.face(card);
        return HornSlot(
          look: !target
              ? HornSlotLook.filled
              : hot
              ? HornSlotLook.ghostReplace
              : HornSlotLook.targetFilled,
          art: face.art,
          effect: isMardrem ? GwentIcon.abilityMardroeme : GwentIcon.abilityCommanderHorn,
          effectName: face.name,
        );
      }(),
      LeaderHornSlot() => HornSlot(
        look: !target
            ? HornSlotLook.filled
            : hot
            ? HornSlotLook.ghostReplace
            : HornSlotLook.targetFilled,
        effectName: l10n.fieldLeaderHorn,
      ),
      null => HornSlot(
        look: !target
            ? HornSlotLook.empty
            : hot
            ? HornSlotLook.ghost
            : HornSlotLook.target,
        ghostLabel: label,
      ),
    };
  }
}

class _FieldCard extends StatelessWidget {
  const _FieldCard({
    super.key,
    required this.view,
    required this.content,
    required this.rect,
    required this.compactWidth,
    required this.frosted,
    required this.hidden,
    required this.opacity,
    required this.flash,
    required this.isDecoyTarget,
    required this.canDrop,
    required this.onDrop,
    required this.onDragEnter,
    required this.onDragLeave,
    required this.justPlayed,
    required this.onTap,
    required this.onLongPress,
  });

  final FieldCardView view;
  final FieldContent content;
  final Rect rect;
  final double? compactWidth;
  final bool frosted;
  final bool hidden;
  final double opacity;
  final CardFlash? flash;
  final bool isDecoyTarget;
  final bool Function(CardInstance card, CardInstance target)? canDrop;
  final void Function(CardInstance card, CardInstance target)? onDrop;
  final void Function(Object target)? onDragEnter;
  final void Function(Object target)? onDragLeave;
  final bool justPlayed;
  final void Function(CardInstance card)? onTap;
  final void Function(CardInstance card, int strength)? onLongPress;

  @override
  Widget build(BuildContext context) {
    final card = view.card;
    final detail = content.detail(card, power: view.strength, frosted: frosted);
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      left: rect.left,
      top: rect.top,
      width: rect.width,
      height: rect.height,
      child: IgnorePointer(
        ignoring: hidden,
        child: Opacity(
          opacity: hidden ? 0 : opacity.clamp(0.0, 1.0),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(3),
              boxShadow: [
                if (flash case final flash? when flash.tone != RollTone.none)
                  BoxShadow(
                    color: (flash.tone == RollTone.gain ? GwentColors.buff : GwentColors.debuff).withValues(
                      alpha: 0.85 * flash.alpha,
                    ),
                    blurRadius: 10,
                    spreadRadius: 1.5,
                  ),
              ],
            ),
            child: DragTarget<CardInstance>(
              onWillAcceptWithDetails: (details) {
                final accepts = isDecoyTarget && (canDrop?.call(details.data, card) ?? false);
                if (accepts) onDragEnter?.call(card.id.value);
                return accepts;
              },
              onLeave: (_) => onDragLeave?.call(card.id.value),
              onAcceptWithDetails: (details) => onDrop?.call(details.data, card),
              builder: (context, candidates, _) => Stack(
                clipBehavior: Clip.none,
                children: [
                  GwentCard(
                    face: detail.face,
                    size: CardSize.row,
                    compactWidth: compactWidth,
                    highlight: justPlayed ? CardHighlight.justPlayed : CardHighlight.normal,
                    onTap: onTap == null ? null : () => onTap!(card),
                    onLongPress: onLongPress == null ? null : () => onLongPress!(card, view.strength),
                  ),
                  TargetHighlight(
                    radius: 3,
                    look: candidates.isNotEmpty
                        ? TargetLook.hot
                        : isDecoyTarget
                        ? TargetLook.candidate
                        : TargetLook.none,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
