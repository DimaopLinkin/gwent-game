import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:gwent/src/core/l10n/l10n.dart';
import 'package:gwent/src/core/presentation/card/card_face.dart';
import 'package:gwent/src/core/presentation/card/card_highlight.dart';
import 'package:gwent/src/core/presentation/card/card_size.dart';
import 'package:gwent/src/core/presentation/card/parts/card_art_layer.dart';
import 'package:gwent/src/core/presentation/card/parts/card_art_overlays.dart';
import 'package:gwent/src/core/presentation/card/parts/card_back_layer.dart';
import 'package:gwent/src/core/presentation/card/parts/card_coin.dart';
import 'package:gwent/src/core/presentation/card/parts/card_frame_painter.dart';
import 'package:gwent/src/core/presentation/card/parts/card_plaque.dart';
import 'package:gwent/src/core/presentation/card/parts/compact_power.dart';
import 'package:gwent/src/core/presentation/card/parts/dashed_rrect_painter.dart';
import 'package:gwent/src/core/presentation/card/parts/leader_marker.dart';
import 'package:gwent/src/core/presentation/card/parts/power_medallion.dart';
import 'package:gwent/src/core/presentation/card/parts/spy_ribbon.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_colors.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_faction.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_icon_view.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_text.dart';

/// Карта Гвинта (макет карты, компонент `gwentCard`): вариант [face] в размере [size] с состоянием [highlight].
///
/// Арт — нижний слой, всё остальное (рамку, силу, иконки, название) рисует приложение поверх, слоями L1–L7 из
/// макета. Долгое нажатие ([longPressDuration]) обычно открывает полный просмотр (`showCardDetail`).
class GwentCard extends StatelessWidget {
  /// Создаёт карту.
  const GwentCard({
    super.key,
    required this.face,
    required this.size,
    this.highlight = CardHighlight.normal,
    this.spyOwner,
    this.compactWidth,
    this.onTap,
    this.onLongPress,
  });

  /// Сколько держать палец, чтобы открыть полный просмотр.
  static const Duration longPressDuration = Duration(milliseconds: 450);

  /// Сколько длятся подъём и смена тени при выборе.
  static const Duration selectDuration = Duration(milliseconds: 180);

  /// Сколько гаснет свечение только что сыгранной карты.
  static const Duration justPlayedDuration = Duration(milliseconds: 600);

  /// Что нарисовано на карте.
  final CardFace face;

  /// Размер.
  final CardSize size;

  /// Состояние на столе.
  final CardHighlight highlight;

  /// Фракция владельца шпиона: цвет ленты и пунктира при [CardHighlight.spy]. По умолчанию Скеллиге.
  final GwentFaction? spyOwner;

  /// Ширина видимой полоски отряда в тесном ряду: пока карту закрывает следующая, вместо медальона и значков
  /// рисуется сжатая сила ([CompactPower]) этой ширины. Только для отряда размера [CardSize.row].
  final double? compactWidth;

  /// Касание.
  final VoidCallback? onTap;

  /// Долгое нажатие.
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final m = size.metrics;
    Widget card = SizedBox(
      width: m.width,
      height: m.height,
      child: Stack(clipBehavior: Clip.none, children: _layers()),
    );
    if (highlight == CardHighlight.disabled) {
      card = ColorFiltered(colorFilter: const ColorFilter.matrix(_disabledMatrix), child: card);
    }
    card = TweenAnimationBuilder<double>(
      key: ValueKey(highlight == CardHighlight.justPlayed),
      tween: Tween(begin: highlight == CardHighlight.justPlayed ? 1 : 0, end: 0),
      duration: justPlayedDuration,
      builder: (context, freshness, child) => AnimatedContainer(
        duration: selectDuration,
        curve: Curves.easeOut,
        transform: Matrix4.translationValues(0, highlight == CardHighlight.selected ? -m.lift : 0, 0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(m.radius),
          boxShadow: _shadows(m, freshness),
        ),
        child: child,
      ),
      child: card,
    );
    if (highlight == CardHighlight.spy) {
      card = Stack(
        clipBehavior: Clip.none,
        children: [
          card,
          Positioned(
            left: -m.stateOffset,
            top: -m.stateOffset,
            right: -m.stateOffset,
            bottom: -m.stateOffset,
            child: IgnorePointer(
              child: CustomPaint(
                painter: DashedRRectPainter(
                  color: (spyOwner ?? GwentFaction.skellige).color,
                  strokeWidth: 1.5,
                  radius: m.radius + m.stateOffset,
                ),
              ),
            ),
          ),
        ],
      );
    }
    // Карта сама задаёт стиль текста: вне Material (оверлей, тест) не наследует отладочный стиль по умолчанию.
    card = DefaultTextStyle(
      style: const TextStyle(fontFamily: GwentText.alegreya, color: GwentColors.textPrimary),
      child: card,
    );
    return Semantics(
      button: onTap != null || onLongPress != null,
      selected: highlight == CardHighlight.selected,
      enabled: highlight != CardHighlight.disabled,
      label: _semanticsLabel(context.l10n),
      // excludeSemantics отбрасывает и действия детей, поэтому нажатия отдаются скринридеру отсюда.
      onTap: onTap,
      onLongPress: onLongPress,
      excludeSemantics: true,
      child: _gestures(card),
    );
  }

  List<Widget> _layers() {
    final m = size.metrics;
    final face = this.face;
    final radius = BorderRadius.circular(m.radius);
    return [
      Positioned.fill(
        child: ClipRRect(
          borderRadius: radius,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (face case CardBackFace(:final faction))
                CardBackLayer(faction: faction, metrics: m)
              else
                CardArtLayer(art: face.art, cardWidth: m.width),
              if (face case WeatherCardFace(:final weather)) CardWeatherWash(tint: weather.tint),
              if (face case UnitCardFace(frosted: true, isHero: false)) CardFrostLayer(glow: m.glow),
              if (face is! CardBackFace) const CardCornerShade(),
            ],
          ),
        ),
      ),
      if (size.hasPlaque && face is! CardBackFace)
        Positioned(
          left: m.frameWidth,
          right: m.frameWidth,
          bottom: m.frameWidth,
          child: CardPlaque(name: face.name, stripeColor: _stripeColor(face), size: size),
        ),
      if (size == CardSize.row && face is UnitCardFace)
        Positioned(
          left: m.frameWidth,
          right: m.frameWidth,
          bottom: m.frameWidth,
          height: m.stripe,
          child: ColoredBox(color: face.faction.color),
        ),
      Positioned.fill(
        child: IgnorePointer(
          child: CustomPaint(
            painter: CardFramePainter(face: face, metrics: m),
          ),
        ),
      ),
      if (size.hasColumn && face is! CardBackFace)
        Positioned(left: compactWidth == null ? m.columnInset : 0.5, top: m.columnInset, child: _column(face, m)),
      if (size == CardSize.mini) ?_miniCenter(face, m),
      if (face case LeaderCardFace(:final abilityUsed))
        Positioned(
          top: m.leaderMarkerInset,
          right: m.leaderMarkerInset,
          child: LeaderMarker(used: abilityUsed, metrics: m),
        ),
      if (highlight == CardHighlight.spy && m.ribbon > 0)
        Positioned(
          top: m.frameWidth,
          right: m.columnInset,
          child: SpyRibbon(width: m.ribbon, color: (spyOwner ?? GwentFaction.skellige).color),
        ),
    ];
  }

  /// Колонка слева сверху (L6): сила, эффект или герб, под ними иконки ряда и способности.
  Widget _column(CardFace face, CardMetrics m) {
    final (r1, r2, _) = m.rings;
    final coinOffset = m.disc > m.coin ? (m.disc - m.coin) / 2 : 0.0;
    final discRings = [
      BoxShadow(color: const Color(0x99000000), offset: Offset(0, m.shadowY / 2), blurRadius: m.shadowY),
      BoxShadow(color: GwentColors.bg, spreadRadius: r2),
      BoxShadow(color: GwentColors.brass, spreadRadius: r1),
    ];
    Widget coin(Widget child) => Padding(
      padding: EdgeInsets.only(left: coinOffset),
      child: child,
    );
    final compactWidth = this.compactWidth;
    final children = switch (face) {
      UnitCardFace(:final power, :final basePower, :final isHero) when compactWidth != null && size == CardSize.row => [
        CompactPower(power: power, look: _powerLook(power, basePower, isHero), width: compactWidth),
      ],
      UnitCardFace(:final power, :final basePower, :final isHero, :final row, :final ability) => [
        PowerMedallion(
          power: power,
          look: _powerLook(power, basePower, isHero),
          metrics: m,
        ),
        coin(CardCoin(icon: row, look: CoinLook.dark, diameter: m.coin, iconSize: m.coinIcon)),
        if (ability != null)
          coin(CardCoin(icon: ability, look: CoinLook.brass, diameter: m.coin, iconSize: m.coinIcon)),
      ],
      SpecialCardFace(:final effect) => [
        CardCoin.effect(icon: effect, diameter: m.effect, iconSize: m.effectIcon, rings: discRings),
      ],
      WeatherCardFace(:final weather) => [
        CardCoin.weather(
          icon: weather.icon,
          diameter: m.effect,
          iconSize: m.effectIcon,
          tint: weather.tint,
          rings: [
            BoxShadow(color: weather.tint.withValues(alpha: 0.6), blurRadius: m.glow),
            BoxShadow(color: weather.tint, spreadRadius: r1),
          ],
        ),
      ],
      LeaderCardFace(:final faction) => [
        if (faction.crest case final crest?) GwentIconView(crest, size: m.crest),
      ],
      CardBackFace() => const <Widget>[],
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: m.columnGap,
      children: children,
    );
  }

  static PowerLook _powerLook(int power, int basePower, bool isHero) => isHero
      ? PowerLook.hero
      : power > basePower
      ? PowerLook.buffed
      : power < basePower
      ? PowerLook.debuffed
      : PowerLook.base;

  /// Мини-карта: эффект или герб по центру; у отряда только арт и рамка.
  Widget? _miniCenter(CardFace face, CardMetrics m) {
    final child = switch (face) {
      SpecialCardFace(:final effect) => CardCoin.effect(
        icon: effect,
        diameter: m.effect,
        iconSize: m.effectIcon,
        rings: const [BoxShadow(color: GwentColors.brassDeep, spreadRadius: 1)],
      ),
      WeatherCardFace(:final weather) => CardCoin.weather(
        icon: weather.icon,
        diameter: m.effect,
        iconSize: m.effectIcon,
        tint: weather.tint,
        rings: [BoxShadow(color: weather.tint, spreadRadius: 1)],
      ),
      LeaderCardFace(faction: GwentFaction(:final crest?)) => GwentIconView(crest, size: m.crest),
      _ => null,
    };
    return child == null ? null : Positioned.fill(child: Center(child: child));
  }

  List<BoxShadow> _shadows(CardMetrics m, double freshness) {
    final base = BoxShadow(color: const Color(0x8C000000), offset: Offset(0, m.shadowY), blurRadius: m.shadowBlur);
    return switch (highlight) {
      CardHighlight.selected => [
        BoxShadow(color: const Color(0x99000000), offset: Offset(0, m.shadowY * 3), blurRadius: m.shadowBlur * 2),
        BoxShadow(color: const Color(0x8CC8A35B), blurRadius: m.glow * 1.6),
        const BoxShadow(color: GwentColors.gold, spreadRadius: 2),
      ],
      CardHighlight.justPlayed when freshness > 0 => [
        base,
        BoxShadow(
          color: GwentColors.textPrimary.withValues(alpha: 0.6 * freshness),
          blurRadius: m.glow * 2,
        ),
        BoxShadow(color: GwentColors.textPrimary.withValues(alpha: freshness), spreadRadius: 1.5),
      ],
      _ => [base],
    };
  }

  Widget _gestures(Widget child) {
    final onTap = this.onTap;
    final onLongPress = this.onLongPress;
    if (onTap == null && onLongPress == null) return child;
    return RawGestureDetector(
      behavior: HitTestBehavior.opaque,
      gestures: {
        if (onTap != null)
          TapGestureRecognizer: GestureRecognizerFactoryWithHandlers<TapGestureRecognizer>(
            TapGestureRecognizer.new,
            (recognizer) => recognizer.onTap = onTap,
          ),
        if (onLongPress != null)
          LongPressGestureRecognizer: GestureRecognizerFactoryWithHandlers<LongPressGestureRecognizer>(
            () => LongPressGestureRecognizer(duration: longPressDuration),
            (recognizer) => recognizer.onLongPress = onLongPress,
          ),
      },
      child: child,
    );
  }

  String _semanticsLabel(AppLocalizations l10n) => switch (face) {
    UnitCardFace(:final name, :final power) => l10n.cardSemanticsUnit(name, power),
    CardBackFace() => l10n.cardSemanticsBack,
    final face => face.name,
  };

  static Color _stripeColor(CardFace face) => switch (face) {
    UnitCardFace(:final faction) || SpecialCardFace(:final faction) || LeaderCardFace(:final faction) => faction.color,
    WeatherCardFace(:final weather) => weather.tint,
    CardBackFace(:final faction) => faction.color,
  };

  /// Недоступная карта: насыщенность 30 %, яркость 55 %.
  static const List<double> _disabledMatrix = [
    0.55 * (0.2126 * 0.7 + 0.3), 0.55 * 0.7152 * 0.7, 0.55 * 0.0722 * 0.7, 0, 0, //
    0.55 * 0.2126 * 0.7, 0.55 * (0.7152 * 0.7 + 0.3), 0.55 * 0.0722 * 0.7, 0, 0, //
    0.55 * 0.2126 * 0.7, 0.55 * 0.7152 * 0.7, 0.55 * (0.0722 * 0.7 + 0.3), 0, 0, //
    0, 0, 0, 1, 0,
  ];
}
