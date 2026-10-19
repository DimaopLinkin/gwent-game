import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:gwent/src/core/l10n/l10n.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_colors.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_text.dart';
import 'package:gwent/src/features/match/presentation/field/field_state.dart';
import 'package:gwent/src/features/match/presentation/match_roster.dart';

/// Вес баннера задаёт размер полосы и время показа (макет 5, раздел 1; времена раунда и хода по макету 13): раунд —
/// 176 pt и 1,1 с, пас — 92 pt и 1,5 с, ход — 56 pt и 0,7 с.
enum BannerWeight {
  /// Начало раунда: двойная золотая рамка, ромбы, метки раундов, затемнение поля.
  round(Duration(milliseconds: 1100), 176),

  /// Пас: подпись под заголовком, лёгкое затемнение.
  pass(Duration(milliseconds: 1500), 92),

  /// Ход: одна строка, поле не затемняется.
  turn(Duration(milliseconds: 700), 56)
  ;

  const BannerWeight(this.visibleFor, this.height);

  /// Сколько баннер держится на экране вместе с появлением и уходом.
  final Duration visibleFor;

  /// Высота полосы.
  final double height;
}

/// Метка раунда под заголовком баннера раунда.
enum RoundPip {
  /// Раунд сыгран.
  done,

  /// Идёт сейчас.
  current,

  /// Ещё впереди.
  future,
}

/// Полоса баннера на всю ширину (макет 5, раздел 1): затемнённая лента с линиями сверху и снизу.
///
/// Рисует только вид без анимации и затемнения; появление и уход, затемнение поля и время показа — у
/// [BannerLayer]. Баннер не принимает касаний.
class MatchBannerStrip extends StatelessWidget {
  /// Создаёт полосу.
  const MatchBannerStrip({
    super.key,
    required this.weight,
    required this.title,
    required this.titleColor,
    required this.ruleColor,
    this.subtitle,
    this.subtitleColor = GwentColors.textSecondary,
    this.pips = const [],
    this.emberPip = false,
    this.decisive = false,
    this.titleSize,
    this.height,
  });

  /// Вес баннера.
  final BannerWeight weight;

  /// Заголовок.
  final String title;

  /// Цвет заголовка.
  final Color titleColor;

  /// Цвет линий сверху и снизу.
  final Color ruleColor;

  /// Подпись под заголовком.
  final String? subtitle;

  /// Цвет подписи.
  final Color subtitleColor;

  /// Метки раундов (только у баннера раунда).
  final List<RoundPip> pips;

  /// Текущая метка красная: решающий раунд.
  final bool emberPip;

  /// Решающий раунд: полоса выше, заголовок мельче.
  final bool decisive;

  /// Размер заголовка вместо стандартного для веса: у плашки итога раунда длинная подпись.
  final double? titleSize;

  /// Высота полосы вместо стандартной для веса: у баннера хода с подписью (макет 13) она 76 pt.
  final double? height;

  double get _height => height ?? (decisive ? 190 : weight.height);

  @override
  Widget build(BuildContext context) {
    final round = weight == BannerWeight.round;
    final titleSize =
        this.titleSize ??
        switch (weight) {
          BannerWeight.round => decisive ? 42.0 : 58.0,
          BannerWeight.pass => 31.0,
          BannerWeight.turn => 26.0,
        };
    final titleText = Text(
      title,
      textAlign: TextAlign.center,
      textScaler: TextScaler.noScaling,
      style: TextStyle(
        fontFamily: GwentText.cormorant,
        fontWeight: FontWeight.w700,
        fontSize: titleSize,
        height: 1.05,
        letterSpacing: titleSize * (round ? (decisive ? 0.04 : 0.06) : 0.03),
        color: titleColor,
        shadows: const [Shadow(color: Color(0x99000000), offset: Offset(0, 2), blurRadius: 10)],
      ),
    );
    return SizedBox(
      height: _height,
      width: double.infinity,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0x000E0B09), Color(0xF50E0B09), Color(0xF50E0B09), Color(0x000E0B09)],
            stops: [0, 0.07, 0.93, 1],
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned(left: 0, right: 0, top: 0, child: _Rule(color: ruleColor)),
            Positioned(left: 0, right: 0, bottom: 0, child: _Rule(color: ruleColor)),
            if (round) ...[
              Positioned(left: 0, right: 0, top: 7, child: _Rule(color: ruleColor, opacity: 0.5)),
              Positioned(left: 0, right: 0, bottom: 7, child: _Rule(color: ruleColor, opacity: 0.5)),
            ],
            Column(
              mainAxisSize: MainAxisSize.min,
              spacing: round ? 14 : (weight == BannerWeight.pass ? 7 : 8),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    spacing: 14,
                    children: [
                      if (round) _Diamond(color: titleColor, size: 8),
                      Flexible(child: titleText),
                      if (round) _Diamond(color: titleColor, size: 8),
                    ],
                  ),
                ),
                if (pips.isNotEmpty)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    spacing: 8,
                    children: [for (final pip in pips) _PipDiamond(pip: pip, ember: emberPip)],
                  ),
                if (subtitle case final subtitle?)
                  Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    textScaler: TextScaler.noScaling,
                    style: TextStyle(
                      fontFamily: GwentText.alegreya,
                      fontWeight: FontWeight.w500,
                      fontSize: decisive ? 15.5 : 14.5,
                      height: 1.2,
                      color: subtitleColor,
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

class _Rule extends StatelessWidget {
  const _Rule({required this.color, this.opacity = 1});

  final Color color;
  final double opacity;

  @override
  Widget build(BuildContext context) => Opacity(
    opacity: opacity,
    child: SizedBox(
      height: 1,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color.withValues(alpha: 0), color, color, color.withValues(alpha: 0)],
            stops: const [0, 0.22, 0.78, 1],
          ),
        ),
      ),
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

class _PipDiamond extends StatelessWidget {
  const _PipDiamond({required this.pip, required this.ember});

  final RoundPip pip;
  final bool ember;

  @override
  Widget build(BuildContext context) {
    final (fill, ring) = switch (pip) {
      RoundPip.current =>
        ember ? (GwentColors.debuff, GwentColors.debuff) : (GwentColors.goldHighlight, GwentColors.gold),
      RoundPip.done => (GwentColors.brassDark, GwentColors.brass),
      RoundPip.future => (const Color(0x00000000), GwentColors.muted),
    };
    return Transform.rotate(
      angle: math.pi / 4,
      child: Container(
        width: 9,
        height: 9,
        decoration: BoxDecoration(
          color: fill,
          border: Border.all(color: ring),
        ),
      ),
    );
  }
}

/// Слой баннеров поверх поля: показывает первый баннер очереди, по таймеру просит убрать его ([onDismissed]).
///
/// Появление и уход зависят от веса: раунд раскрывается от центра, ход въезжает слева и уходит вправо, пас
/// поднимается снизу. Баннер раунда и паса слегка затемняют поле. Касания проходят сквозь слой. При «уменьшить
/// движение» баннер просто появляется и гаснет. Новый баннер (другой объект) заменяет показанный.
class BannerLayer extends StatefulWidget {
  /// Создаёт слой над [roster]: по нему называются игроки в hot-seat.
  const BannerLayer({super.key, required this.banner, required this.roster, required this.onDismissed});

  /// Что показать; `null` — ничего.
  final FieldBanner? banner;

  /// Участники партии.
  final MatchRoster roster;

  /// Время показа вышло.
  final VoidCallback onDismissed;

  @override
  State<BannerLayer> createState() => _BannerLayerState();
}

class _BannerLayerState extends State<BannerLayer> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this)..addStatusListener(_onStatus);

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void didUpdateWidget(BannerLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(widget.banner, oldWidget.banner)) _start();
  }

  void _start() {
    final banner = widget.banner;
    if (banner == null) {
      _controller.stop();
      return;
    }
    _controller
      ..duration = _durationOf(banner)
      ..forward(from: 0);
  }

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && widget.banner != null) widget.onDismissed();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  static BannerWeight _weightOf(FieldBanner banner) => switch (banner) {
    RoundStartBanner() => BannerWeight.round,
    PassBanner() => BannerWeight.pass,
    TurnStartBanner() => BannerWeight.turn,
  };

  /// Время показа: баннер хода с подписью о выборе Скоя'таэлей держится дольше обычного, подпись надо успеть прочесть.
  static Duration _durationOf(FieldBanner banner) =>
      banner is TurnStartBanner && banner.chosenBy != null ? turnNoteVisibleFor : _weightOf(banner).visibleFor;

  /// Сколько держится баннер хода с подписью о выборе Скоя'таэлей.
  static const Duration turnNoteVisibleFor = Duration(milliseconds: 1800);

  /// 0 → 1 за появление, 1 на выдержке, 1 → 0 за уход: те же доли времени, что в макете (12 % и 84–95 %).
  double _presence(double t) {
    if (t < 0.12) return t / 0.12;
    if (t < 0.84) return 1;
    if (t < 0.95) return 1 - (t - 0.84) / 0.11;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final banner = widget.banner;
    if (banner == null) return const SizedBox.shrink();
    final reduce = MediaQuery.disableAnimationsOf(context);
    final weight = _weightOf(banner);
    final strip = _strip(context, banner, weight);
    return Semantics(
      liveRegion: true,
      container: true,
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final t = _controller.value;
            final presence = _presence(t);
            final dim = switch (weight) {
              BannerWeight.round => 0.55,
              BannerWeight.pass => 0.28,
              BannerWeight.turn => 0.0,
            };
            final Widget shown;
            if (reduce) {
              shown = Opacity(opacity: presence, child: strip);
            } else {
              shown = switch (weight) {
                BannerWeight.round => Opacity(
                  opacity: presence > 0 ? 1 : 0,
                  child: ClipRect(
                    clipper: _CenterReveal(presence),
                    child: strip,
                  ),
                ),
                BannerWeight.turn => Opacity(
                  opacity: presence,
                  child: Transform.translate(
                    offset: Offset(t < 0.5 ? -36 * (1 - presence) : 36 * (1 - presence), 0),
                    child: strip,
                  ),
                ),
                BannerWeight.pass => Opacity(
                  opacity: presence,
                  child: Transform.translate(
                    offset: Offset(0, t < 0.5 ? 12 * (1 - presence) : -8 * (1 - presence)),
                    child: strip,
                  ),
                ),
              };
            }
            return Stack(
              fit: StackFit.expand,
              children: [
                if (dim > 0) ColoredBox(color: const Color(0xFF0A0806).withValues(alpha: dim * presence)),
                Center(child: shown),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _strip(BuildContext context, FieldBanner banner, BannerWeight weight) {
    final l10n = context.l10n;
    final roster = widget.roster;
    switch (banner) {
      case RoundStartBanner(:final round, :final decisive):
        return MatchBannerStrip(
          weight: weight,
          title: decisive ? l10n.bannerDecisiveRound : l10n.bannerRound(round),
          titleColor: GwentColors.goldHighlight,
          ruleColor: GwentColors.gold,
          decisive: decisive,
          subtitle: decisive ? l10n.bannerDecisiveRoundHint : null,
          subtitleColor: GwentColors.errorText,
          emberPip: decisive,
          pips: [
            for (var i = 1; i <= 3; i++)
              i < round
                  ? RoundPip.done
                  : i == round
                  ? RoundPip.current
                  : RoundPip.future,
          ],
        );
      case TurnStartBanner(:final seat, :final mine, :final chosenBy, :final chosenByMine):
        final theirs = !mine && !roster.hotSeat;
        final note = chosenBy == null
            ? null
            : roster.hotSeat
            ? l10n.bannerFirstChoiceBy(roster.name(chosenBy, l10n))
            : chosenByMine
            ? l10n.bannerFirstChoiceYou
            : l10n.bannerFirstChoiceOpponent;
        return MatchBannerStrip(
          weight: weight,
          height: note == null ? null : 76,
          subtitle: note,
          title: roster.hotSeat
              ? l10n.bannerTurnOf(roster.name(seat, l10n))
              : mine
              ? l10n.bannerYourTurn
              : l10n.bannerOpponentTurn,
          titleColor: theirs ? GwentColors.textTertiary : GwentColors.goldHighlight,
          ruleColor: theirs ? GwentColors.line : GwentColors.brass,
        );
      case PassBanner(:final seat, :final mine):
        return MatchBannerStrip(
          weight: weight,
          title: roster.hotSeat
              ? l10n.bannerPassedBy(roster.name(seat, l10n))
              : mine
              ? l10n.bannerYouPassed
              : l10n.bannerOpponentPassed,
          titleColor: mine ? GwentColors.textTertiary : GwentColors.textPrimary,
          ruleColor: mine ? GwentColors.muted : const Color(0xFF8A4A3A),
          subtitle: mine ? l10n.bannerYouPassedHint : l10n.bannerOpponentPassedHint,
        );
    }
  }
}

/// Показывает полосу, раскрытую от центра по высоте на долю [factor].
class _CenterReveal extends CustomClipper<Rect> {
  const _CenterReveal(this.factor);

  final double factor;

  @override
  Rect getClip(Size size) {
    final half = size.height / 2 * factor;
    return Rect.fromLTRB(0, size.height / 2 - half, size.width, size.height / 2 + half);
  }

  @override
  bool shouldReclip(_CenterReveal oldClipper) => oldClipper.factor != factor;
}
