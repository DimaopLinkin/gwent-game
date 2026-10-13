import 'package:flutter/widgets.dart' hide Row;
import 'package:gwent/src/core/l10n/l10n.dart';
import 'package:gwent/src/core/presentation/card/card_highlight.dart';
import 'package:gwent/src/core/presentation/card/card_size.dart';
import 'package:gwent/src/core/presentation/card/gwent_card.dart';
import 'package:gwent/src/core/presentation/components/horn_slot.dart';
import 'package:gwent/src/core/presentation/components/row_score_pill.dart';
import 'package:gwent/src/core/presentation/components/row_weather_overlay.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_colors.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_icon.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_icon_view.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_weather.dart';
import 'package:gwent/src/features/match/presentation/field/field_content.dart';
import 'package:gwent/src/features/match/presentation/field/field_geometry.dart';
import 'package:gwent_engine/gwent_engine.dart';

/// Один ряд на поле (макет поля, «Z-порядок слоёв»): фон, погодный слой, водяной знак, колонка (сила ряда и слот
/// рога), карты и вуаль погоды.
///
/// Нажатие по ряду принимает весь ряд 80 pt, а не карта: так проще попасть пальцем. Цель хода рисуется золотой
/// рамкой по периметру ряда.
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
    this.decoyTargets = const {},
    this.recent = const {},
    this.onTap,
    this.canDrop,
    this.onDrop,
    this.onCardTap,
    this.onCardLongPress,
  });

  /// Размеры зон поля.
  final FieldGeometry geometry;

  /// Мост к контенту партии.
  final FieldContent content;

  /// Тип ряда.
  final Row row;

  /// Ряд мой или соперника.
  final bool mine;

  /// Ряд в проекции: карты, слот рога, погода, сила.
  final RowView data;

  /// Ряд — цель хода.
  final bool isTarget;

  /// Слот рога этого ряда — цель хода.
  final bool hornTarget;

  /// Мои карты на этом ряду, на которые можно положить Чучело.
  final Set<CardInstanceId> decoyTargets;

  /// Карты, которые только что легли на стол.
  final Set<CardInstanceId> recent;

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

  @override
  Widget build(BuildContext context) {
    final rect = geometry.rowRect(row, mine: mine);
    final weather = data.weather ? FieldContent.weatherOf(row) : null;
    final cards = data.cards;
    final base = cards.fold(0, (sum, view) => sum + content.baseStrength(view.card));
    final tone = data.strength > base
        ? RowScoreTone.boosted
        : data.strength < base
        ? RowScoreTone.weakened
        : RowScoreTone.neutral;
    final area = geometry.cardsArea(row, mine: mine).shift(-rect.topLeft);
    return Positioned.fromRect(
      rect: rect,
      child: DragTarget<CardInstance>(
        onWillAcceptWithDetails: (details) => canDrop?.call(details.data) ?? false,
        onAcceptWithDetails: (details) => onDrop?.call(details.data),
        builder: (context, _, _) => GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Semantics(
            container: true,
            label: context.l10n.fieldRowSemantics(_rowName(context), data.strength),
            child: Container(
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
              foregroundDecoration: isTarget
                  ? BoxDecoration(
                      color: GwentColors.gold.withValues(alpha: 0.1),
                      border: Border.all(color: GwentColors.gold, width: 1.5),
                    )
                  : null,
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
                      child: RowScorePill(score: data.strength, tone: tone),
                    ),
                  ),
                  Positioned(
                    left: FieldGeometry.columnLeft + 1.5,
                    top: 32,
                    child: _HornSlotView(slot: data.slot, content: content, target: hornTarget && mine),
                  ),
                  for (var i = 0; i < cards.length; i++)
                    _FieldCard(
                      key: ValueKey(cards[i].card.id),
                      view: cards[i],
                      content: content,
                      rect: geometry.cardRect(row, i, cards.length, mine: mine).shift(-rect.topLeft),
                      frosted: data.weather && row == Row.melee,
                      isDecoyTarget: decoyTargets.contains(cards[i].card.id),
                      justPlayed: recent.contains(cards[i].card.id),
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
  const _HornSlotView({required this.slot, required this.content, required this.target});

  final RowSlot? slot;
  final FieldContent content;
  final bool target;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return switch (slot) {
      CardSlot(:final card) => () {
        final isMardrem = content.special(card)?.ability is MardremCardAbility;
        final face = content.face(card);
        return HornSlot(
          look: HornSlotLook.filled,
          art: face.art,
          effect: isMardrem ? GwentIcon.abilityMardroeme : GwentIcon.abilityCommanderHorn,
          effectName: face.name,
        );
      }(),
      LeaderHornSlot() => HornSlot(look: HornSlotLook.filled, effectName: l10n.fieldLeaderHorn),
      null => HornSlot(look: target ? HornSlotLook.target : HornSlotLook.empty),
    };
  }
}

class _FieldCard extends StatelessWidget {
  const _FieldCard({
    super.key,
    required this.view,
    required this.content,
    required this.rect,
    required this.frosted,
    required this.isDecoyTarget,
    required this.justPlayed,
    required this.onTap,
    required this.onLongPress,
  });

  final FieldCardView view;
  final FieldContent content;
  final Rect rect;
  final bool frosted;
  final bool isDecoyTarget;
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
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(3),
          boxShadow: isDecoyTarget
              ? const [
                  BoxShadow(color: Color(0x8CC8A35B), blurRadius: 10),
                  BoxShadow(color: GwentColors.gold, spreadRadius: 1.5),
                ]
              : null,
        ),
        child: GwentCard(
          face: detail.face,
          size: CardSize.row,
          highlight: justPlayed ? CardHighlight.justPlayed : CardHighlight.normal,
          onTap: onTap == null ? null : () => onTap!(card),
          onLongPress: onLongPress == null ? null : () => onLongPress!(card, view.strength),
        ),
      ),
    );
  }
}
