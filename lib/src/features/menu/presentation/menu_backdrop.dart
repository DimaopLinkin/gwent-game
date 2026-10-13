import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:gwent/src/core/presentation/card/card_face.dart';
import 'package:gwent/src/core/presentation/card/card_size.dart';
import 'package:gwent/src/core/presentation/card/gwent_card.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_colors.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_faction.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_text.dart';

/// Фон главного меню и заставки (макет 6): тёмный стол в досках, тёплый отсвет свечи справа сверху, виньетка.
///
/// В верхней части лежат рубашки карт, золотая монета и свеча с мерцающим пламенем. При «уменьшить движение»
/// пламя и отсвет не мерцают.
class MenuBackdrop extends StatelessWidget {
  /// Создаёт фон.
  const MenuBackdrop({super.key});

  @override
  Widget build(BuildContext context) => const ExcludeSemantics(
    child: Stack(
      fit: StackFit.expand,
      children: [
        _Wood(),
        _Vignette(),
        Positioned(left: 0, right: 0, top: 0, height: 330, child: _Table()),
      ],
    ),
  );
}

class _Wood extends StatelessWidget {
  const _Wood();

  @override
  Widget build(BuildContext context) => CustomPaint(painter: _WoodPainter(), size: Size.infinite);
}

class _WoodPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset.zero,
          Offset(0, size.height),
          const [Color(0xFF2A1D12), Color(0xFF1A120B), Color(0xFF120C07)],
          const [0, 0.6, 1],
        ),
    );
    final seam = Paint()..color = const Color(0x59000000);
    for (var x = 96.0; x < size.width; x += 98) {
      canvas.drawRect(Rect.fromLTWH(x, 0, 2, size.height), seam);
    }
    final grain = Paint()..color = const Color(0x06FFE1AA);
    for (var y = 0.0; y < size.height; y += 7) {
      canvas.drawRect(Rect.fromLTWH(0, y, size.width, 3), grain);
    }
  }

  @override
  bool shouldRepaint(_WoodPainter oldDelegate) => false;
}

class _Vignette extends StatelessWidget {
  const _Vignette();

  @override
  Widget build(BuildContext context) => const Stack(
    fit: StackFit.expand,
    children: [
      DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0.64, -0.66),
            radius: 0.7,
            colors: [Color(0x57E8AA50), Color(0x00E8AA50)],
          ),
        ),
      ),
      DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.2),
            radius: 1.1,
            colors: [Color(0x00050302), Color(0xD9050302)],
            stops: [0.3, 1],
          ),
        ),
      ),
    ],
  );
}

class _Table extends StatelessWidget {
  const _Table();

  static Widget _card(double left, double top, double degrees, GwentFaction faction) => Positioned(
    left: left,
    top: top,
    child: Transform.rotate(
      angle: degrees * 0.017453292519943295,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          boxShadow: [BoxShadow(color: Color(0xB3000000), blurRadius: 10, offset: Offset(0, 8))],
        ),
        child: GwentCard(
          face: CardBackFace(faction: faction),
          size: CardSize.hand,
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => Stack(
    clipBehavior: Clip.none,
    children: [
      _card(18, 84, -16, GwentFaction.northernRealms),
      _card(84, 104, 9, GwentFaction.monsters),
      _card(70, 58, -4, GwentFaction.skellige),
      _card(158, 76, 8, GwentFaction.nilfgaard),
      Positioned(
        right: 60,
        top: 196,
        child: Container(
          width: 54,
          height: 54,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              center: Alignment(-0.3, -0.44),
              radius: 0.9,
              colors: [Color(0xFFF0D68E), GwentColors.gold, GwentColors.brass],
              stops: [0, 0.52, 1],
            ),
            boxShadow: [
              BoxShadow(color: Color(0x99000000), offset: Offset(0, 6), blurRadius: 8),
              BoxShadow(color: GwentColors.brassDark, spreadRadius: 2),
            ],
          ),
        ),
      ),
      const Positioned(right: 36, top: 128, width: 36, height: 84, child: _Candle()),
    ],
  );
}

/// Свеча: воск, подставка, фитиль и пламя; пламя и отсвет мерцают.
class _Candle extends StatefulWidget {
  const _Candle();

  @override
  State<_Candle> createState() => _CandleState();
}

class _CandleState extends State<_Candle> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller
        ..stop()
        ..value = 0;
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, _) {
      final t = _controller.value;
      // Мерцание: огонь чуть меняет высоту и ширину (0,9 с на цикл), отсвет вспыхивает и гаснет.
      final cycle = (t * 2200 / 900) % 1;
      final flicker = cycle < 0.5 ? cycle * 2 : 2 - cycle * 2;
      final pulse = (t * 3) % 1;
      final glow = 0.7 + 0.3 * (pulse < 0.5 ? pulse * 2 : 2 - pulse * 2);
      final sx = 0.94 + 0.09 * flicker;
      final sy = 1.06 - 0.11 * flicker;
      return Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: -60,
            top: -60,
            width: 156,
            height: 156,
            child: Opacity(
              opacity: glow,
              child: const DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [Color(0x80FFC86E), Color(0x00FFC86E)], stops: [0, 0.68]),
                ),
              ),
            ),
          ),
          const Positioned(
            left: 8,
            bottom: 0,
            width: 20,
            height: 62,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.vertical(top: Radius.circular(3), bottom: Radius.circular(4)),
                gradient: LinearGradient(
                  colors: [Color(0xFFB9A27A), Color(0xFFE5D3AC), Color(0xFF9D8761)],
                  stops: [0, 0.45, 1],
                ),
                boxShadow: [BoxShadow(color: Color(0xB3000000), offset: Offset(0, 6), blurRadius: 10)],
              ),
            ),
          ),
          Positioned(
            left: 6,
            bottom: -4,
            width: 24,
            height: 8,
            child: DecoratedBox(
              decoration: BoxDecoration(color: GwentColors.brassDark, borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const Positioned(
            left: 17,
            bottom: 62,
            width: 2,
            height: 7,
            child: ColoredBox(color: GwentColors.onParchment),
          ),
          Positioned(
            left: 11,
            bottom: 66,
            width: 14,
            height: 24,
            child: Transform(
              alignment: const Alignment(0, 0.8),
              transform: Matrix4.diagonal3Values(sx, sy, 1),
              child: const DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.all(Radius.elliptical(7, 14)),
                  gradient: RadialGradient(
                    center: Alignment(0, 0.5),
                    colors: [Color(0xFFFFF4C2), Color(0xFFF6B84A), Color(0x33E66E1E)],
                    stops: [0, 0.55, 1],
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    },
  );
}

/// Название игры золотым леттерингом с тенью и свечением.
class GwentLogo extends StatelessWidget {
  /// Создаёт название кеглем [size] с разрядкой [spacing] (в долях кегля).
  const GwentLogo({super.key, required this.text, required this.size, required this.spacing});

  /// Надпись.
  final String text;

  /// Кегль.
  final double size;

  /// Разрядка в долях кегля.
  final double spacing;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontFamily: GwentText.cormorant,
      fontWeight: FontWeight.w700,
      fontSize: size,
      height: 1,
      letterSpacing: size * spacing,
    );
    return Padding(
      // Разрядка добавляется и после последней буквы: слева столько же, чтобы надпись стояла по центру.
      padding: EdgeInsets.only(left: size * spacing),
      child: Stack(
        children: [
          Transform.translate(
            offset: const Offset(0, 3),
            child: Text(
              text,
              textScaler: TextScaler.noScaling,
              style: style.copyWith(
                color: const Color(0xFF1A120B),
                shadows: const [Shadow(color: Color(0x40C8A35B), blurRadius: 18)],
              ),
            ),
          ),
          ShaderMask(
            blendMode: BlendMode.srcIn,
            shaderCallback: (bounds) => const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFF3DD9E), GwentColors.gold, GwentColors.brass],
              stops: [0, 0.55, 1],
            ).createShader(bounds),
            child: Text(
              text,
              textScaler: TextScaler.noScaling,
              style: style.copyWith(color: const Color(0xFFFFFFFF)),
            ),
          ),
        ],
      ),
    );
  }
}
