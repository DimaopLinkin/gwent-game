import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:gwent/src/core/l10n/l10n.dart';
import 'package:gwent/src/core/presentation/components/life_gems.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_colors.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_text.dart';

/// Загрузка на весь экран (макет дизайн-системы, `gameLoader`): три камня мерцают по очереди, под ними подпись.
/// При «уменьшить движение» камни статичны.
class GameLoader extends StatefulWidget {
  /// Создаёт загрузку с подписью [caption]; по умолчанию «Тасуем колоду…».
  const GameLoader({super.key, this.caption});

  /// Подпись; `null` — «Тасуем колоду…».
  final String? caption;

  @override
  State<GameLoader> createState() => _GameLoaderState();
}

class _GameLoaderState extends State<GameLoader> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller
        ..stop()
        ..value = 0.25;
    } else if (!_controller.isAnimating) {
      unawaited(_controller.repeat());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final caption = widget.caption ?? context.l10n.loaderShuffling;
    return Semantics(
      liveRegion: true,
      label: caption,
      excludeSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: 14,
        children: [
          AnimatedBuilder(
            animation: _controller,
            builder: (context, _) => Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 10,
              children: [
                for (var i = 0; i < 3; i++)
                  Builder(
                    builder: (context) {
                      // Фаза каждого камня сдвинута на 0,2 с от периода 1,2 с, как в макете.
                      final phase = ((_controller.value * 1.5) - i * (0.2 / 1.2)) % 1;
                      final wave = 0.5 - 0.5 * math.cos(phase * 2 * math.pi);
                      return Opacity(
                        opacity: 0.4 + 0.6 * wave,
                        child: Transform.scale(scale: 0.78 + 0.22 * wave, child: const LifeGem(lost: false, size: 16)),
                      );
                    },
                  ),
              ],
            ),
          ),
          Text(
            caption,
            textScaler: TextScaler.noScaling,
            style: const TextStyle(
              fontFamily: GwentText.alegreya,
              fontStyle: FontStyle.italic,
              fontSize: 14,
              height: 1,
              color: GwentColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Встроенный индикатор 28 pt (макет дизайн-системы, `loaderRing`): кольцо с золотой дугой, оборот за секунду.
class GwentSpinner extends StatefulWidget {
  /// Создаёт индикатор.
  const GwentSpinner({super.key, this.size = 28});

  /// Диаметр.
  final double size;

  @override
  State<GwentSpinner> createState() => _GwentSpinnerState();
}

class _GwentSpinnerState extends State<GwentSpinner> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: const Duration(seconds: 1));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      unawaited(_controller.repeat());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RotationTransition(
    turns: _controller,
    child: CustomPaint(size: Size.square(widget.size), painter: const _RingPainter()),
  );
}

class _RingPainter extends CustomPainter {
  const _RingPainter();

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 2.0;
    final rect = (Offset.zero & size).deflate(stroke / 2);
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = GwentColors.line;
    canvas
      ..drawArc(rect, 0, 2 * math.pi, false, ring)
      ..drawArc(rect, -math.pi * 3 / 4, math.pi / 2, false, ring..color = GwentColors.gold);
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) => false;
}
