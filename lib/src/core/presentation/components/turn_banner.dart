import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_colors.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_text.dart';

/// Вид баннера на всю ширину.
enum TurnBannerKind {
  /// «Ваш ход»: золото, ромбы по бокам.
  yourTurn,

  /// Начало раунда, пас соперника и прочее: обычный цвет.
  info,
}

/// Баннер на всю ширину (макет дизайн-системы, `turnBanner`): затемнённая полоса с линиями сверху и снизу.
///
/// Заголовок 32 pt; если не помещается в строку (на экране 390 pt это 326 pt), 24 pt; если и так не помещается,
/// переносится на две строки. Подзаголовок 13 pt центрируется и тоже переносится.
///
/// Баннеры равны, если равны заголовок, подзаголовок и вид: [TurnBannerPresenter] по этому решает, показывать ли
/// баннер заново.
class TurnBanner extends StatelessWidget {
  /// Создаёт баннер.
  const TurnBanner({super.key, required this.title, this.subtitle, this.kind = TurnBannerKind.info});

  /// Поля слева и справа от текста.
  static const double horizontalPadding = 32;

  /// Ромб (6 pt) и промежуток до него (14 pt) по каждую сторону золотого заголовка.
  static const double diamondsWidth = 2 * (6 + 14);

  /// Заголовок.
  final String title;

  /// Подзаголовок.
  final String? subtitle;

  /// Вид.
  final TurnBannerKind kind;

  /// Показывают ли [a] и [b] один и тот же баннер: виджет сравнить через `==` нельзя, поэтому по содержимому.
  static bool isSame(TurnBanner? a, TurnBanner? b) =>
      a == b || (a != null && b != null && a.title == b.title && a.subtitle == b.subtitle && a.kind == b.kind);

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final gold = kind == TurnBannerKind.yourTurn;
      final width = constraints.maxWidth.isFinite ? constraints.maxWidth : 390.0;
      final titleWidth = width - 2 * horizontalPadding - (gold ? diamondsWidth : 0);
      return SizedBox(width: double.infinity, child: _body(titleWidth));
    },
  );

  Widget _body(double titleWidth) {
    final gold = kind == TurnBannerKind.yourTurn;
    final lineColor = gold ? GwentColors.gold : GwentColors.brass;
    final subtitle = this.subtitle;
    final titleStyle = TextStyle(
      fontFamily: GwentText.cormorant,
      fontWeight: FontWeight.w600,
      height: 1.05,
      letterSpacing: 1.28,
      color: gold ? GwentColors.gold : GwentColors.textPrimary,
    );
    final fontSize = _titleFontSize(title, titleStyle, titleWidth);
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0x000E0B09), Color(0xF20E0B09), Color(0xF20E0B09), Color(0x000E0B09)],
          stops: [0, 0.08, 0.92, 1],
        ),
      ),
      child: Stack(
        children: [
          Positioned(left: 0, right: 0, top: 0, child: _Rule(color: lineColor)),
          Positioned(left: 0, right: 0, bottom: 0, child: _Rule(color: lineColor)),
          Container(
            constraints: const BoxConstraints(minHeight: 72),
            padding: const EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 10),
            alignment: Alignment.center,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              spacing: 4,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: 14,
                  children: [
                    if (gold) const _BannerDiamond(),
                    Flexible(
                      child: Text(
                        title,
                        textAlign: TextAlign.center,
                        textScaler: TextScaler.noScaling,
                        style: titleStyle.copyWith(fontSize: fontSize),
                      ),
                    ),
                    if (gold) const _BannerDiamond(),
                  ],
                ),
                if (subtitle != null)
                  Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    textScaler: TextScaler.noScaling,
                    style: const TextStyle(
                      fontFamily: GwentText.alegreya,
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                      height: 1.25,
                      color: GwentColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 32 pt, если заголовок влезает в одну строку, иначе 24 pt (и перенос, если и тогда не влезает).
  static double _titleFontSize(String title, TextStyle style, double maxWidth) {
    for (final size in const [32.0, 24.0]) {
      final painter = TextPainter(
        text: TextSpan(
          text: title,
          style: style.copyWith(fontSize: size),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout();
      final fits = painter.width <= maxWidth;
      painter.dispose();
      if (fits) return size;
    }
    return 24;
  }
}

class _Rule extends StatelessWidget {
  const _Rule({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 1,
    child: DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withValues(alpha: 0), color, color, color.withValues(alpha: 0)],
          stops: const [0, 0.25, 0.75, 1],
        ),
      ),
    ),
  );
}

class _BannerDiamond extends StatelessWidget {
  const _BannerDiamond();

  @override
  Widget build(BuildContext context) => Transform.rotate(
    angle: math.pi / 4,
    child: const SizedBox.square(dimension: 6, child: ColoredBox(color: GwentColors.gold)),
  );
}

/// Показывает баннер поверх экрана: появление 200 мс, пауза [visibleFor], исчезновение; касания не блокирует.
///
/// Новый [banner] (не равный прежнему) заменяет показанный и запускает отсчёт заново; `null` убирает баннер. Равный
/// баннер при перерисовке родителя ничего не меняет: ни не продлевает показ, ни не показывает баннер снова после
/// таймаута. Чтобы показать тот же баннер ещё раз, родитель сначала передаёт `null` (удобно в [onDismissed]).
/// Для скринридера баннер — живая область. При «уменьшить движение» появление без сдвига.
class TurnBannerPresenter extends StatefulWidget {
  /// Создаёт показ баннера [banner] поверх [child].
  const TurnBannerPresenter({
    super.key,
    required this.banner,
    required this.child,
    this.visibleFor = const Duration(milliseconds: 1600),
    this.onDismissed,
  });

  /// Время появления и исчезновения.
  static const Duration transition = Duration(milliseconds: 200);

  /// Что показать; `null` — ничего.
  final TurnBanner? banner;

  /// Экран под баннером.
  final Widget child;

  /// Сколько баннер держится на экране.
  final Duration visibleFor;

  /// Баннер скрыт по таймеру.
  final VoidCallback? onDismissed;

  @override
  State<TurnBannerPresenter> createState() => _TurnBannerPresenterState();
}

class _TurnBannerPresenterState extends State<TurnBannerPresenter> {
  Timer? _timer;
  TurnBanner? _shown;

  @override
  void initState() {
    super.initState();
    _show(widget.banner);
  }

  @override
  void didUpdateWidget(TurnBannerPresenter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!TurnBanner.isSame(widget.banner, oldWidget.banner)) _show(widget.banner);
  }

  void _show(TurnBanner? banner) {
    _timer?.cancel();
    _shown = banner;
    if (banner != null) {
      _timer = Timer(widget.visibleFor, () {
        if (!mounted) return;
        setState(() => _shown = null);
        widget.onDismissed?.call();
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    final shown = _shown;
    return Stack(
      children: [
        widget.child,
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          bottom: 0,
          child: IgnorePointer(
            child: Center(
              child: AnimatedSwitcher(
                duration: TurnBannerPresenter.transition,
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: reduce
                      ? child
                      : SlideTransition(
                          position: Tween(begin: const Offset(0, -0.08), end: Offset.zero).animate(animation),
                          child: child,
                        ),
                ),
                child: shown == null
                    ? const SizedBox.shrink()
                    : Semantics(liveRegion: true, key: ValueKey(shown), child: shown),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
