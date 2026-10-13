import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:gwent/src/core/l10n/l10n.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_colors.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_text.dart';
import 'package:gwent/src/features/menu/presentation/menu_backdrop.dart';

/// Заставка при запуске (макет 6): название золотым леттерингом на затемнённом столе, полоса загрузки данных карт.
///
/// Пока данные грузятся ([ready] `false`), полоса медленно ползёт к 90 %: настоящего счётчика у загрузки пакета нет.
/// Когда данные готовы, полоса доходит до конца, подпись меняется на «Готово», заставка растворяется и сообщает
/// об этом через [onDone]. При «уменьшить движение» заставка исчезает сразу.
class SplashLayer extends StatefulWidget {
  /// Создаёт заставку.
  const SplashLayer({super.key, required this.ready, required this.onDone});

  /// Полоса ползёт до 90 % за это время.
  static const Duration crawl = Duration(milliseconds: 2400);

  /// Завершение: полоса доходит до конца, пауза, растворение.
  static const Duration finish = Duration(milliseconds: 1050);

  /// Данные готовы, можно показывать меню.
  final bool ready;

  /// Заставка растворилась.
  final VoidCallback onDone;

  @override
  State<SplashLayer> createState() => _SplashLayerState();
}

class _SplashLayerState extends State<SplashLayer> with TickerProviderStateMixin {
  late final AnimationController _crawl = AnimationController(vsync: this, duration: SplashLayer.crawl);
  late final AnimationController _finish = AnimationController(vsync: this, duration: SplashLayer.finish)
    ..addStatusListener((status) {
      if (status == AnimationStatus.completed) widget.onDone();
    });

  @override
  void initState() {
    super.initState();
    unawaited(_crawl.forward());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _maybeFinish();
  }

  @override
  void didUpdateWidget(SplashLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    _maybeFinish();
  }

  void _maybeFinish() {
    if (!widget.ready || _finish.isAnimating || _finish.isCompleted) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onDone();
      });
    } else {
      unawaited(_finish.forward());
    }
  }

  @override
  void dispose() {
    _crawl.dispose();
    _finish.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AnimatedBuilder(
      animation: Listenable.merge([_crawl, _finish]),
      builder: (context, _) {
        final f = _finish.value;
        // До 0,24 полоса доходит до конца, до 0,33 пауза, дальше растворение.
        final fill = f == 0 ? 0.9 * Curves.easeOut.transform(_crawl.value) : 0.9 + 0.1 * (f / 0.24).clamp(0, 1);
        final opacity = f <= 0.33 ? 1.0 : 1 - ((f - 0.33) / 0.67).clamp(0, 1);
        final done = fill >= 1;
        // Растворяющаяся заставка пропускает нажатия к меню: решение берётся на каждом кадре.
        return IgnorePointer(
          ignoring: f > 0.33,
          child: Opacity(
            opacity: opacity.toDouble(),
            child: Semantics(
              container: true,
              liveRegion: true,
              label: done ? l10n.menuSplashReady : l10n.menuSplashLoading,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  const ColoredBox(color: Color(0xEE0B0907)),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: Alignment(0, -0.1),
                        radius: 0.8,
                        colors: [Color(0x24C8A35B), Color(0x00C8A35B)],
                        stops: [0, 0.7],
                      ),
                    ),
                  ),
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 60),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        spacing: 10,
                        children: [
                          const _Ornament(),
                          GwentLogo(text: l10n.appTitle.toUpperCase(), size: 80, spacing: 0.1),
                          const _Ornament(),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 60,
                    right: 60,
                    bottom: 96,
                    child: Column(
                      spacing: 12,
                      children: [
                        SizedBox(
                          height: 4,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: GwentColors.surfaceRaised,
                              borderRadius: BorderRadius.circular(2),
                            ),
                            child: FractionallySizedBox(
                              alignment: Alignment.centerLeft,
                              widthFactor: fill,
                              child: const DecoratedBox(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.all(Radius.circular(2)),
                                  gradient: LinearGradient(colors: [GwentColors.brassLight, GwentColors.goldHighlight]),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Text(
                          done ? l10n.menuSplashReady : l10n.menuSplashLoading,
                          textScaler: TextScaler.noScaling,
                          style: const TextStyle(
                            fontFamily: GwentText.alegreya,
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                            height: 1,
                            color: GwentColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Ornament extends StatelessWidget {
  const _Ornament();

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    spacing: 14,
    children: [
      const _Line(towardsEnd: false),
      Transform.rotate(
        angle: 0.7853981633974483,
        child: const SizedBox.square(dimension: 8, child: ColoredBox(color: GwentColors.gold)),
      ),
      const _Line(towardsEnd: true),
    ],
  );
}

class _Line extends StatelessWidget {
  const _Line({required this.towardsEnd});

  final bool towardsEnd;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 70,
    height: 1,
    child: DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: towardsEnd
              ? const [GwentColors.brass, Color(0x008C6A3F)]
              : const [Color(0x008C6A3F), GwentColors.brass],
        ),
      ),
    ),
  );
}
