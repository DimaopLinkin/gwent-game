import 'dart:math' as math;

import 'package:flutter/widgets.dart' hide Row;
import 'package:gwent/src/core/l10n/l10n.dart';
import 'package:gwent/src/core/presentation/card/card_face.dart';
import 'package:gwent/src/core/presentation/card/card_size.dart';
import 'package:gwent/src/core/presentation/card/gwent_card.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_colors.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_text.dart';
import 'package:gwent/src/features/match/presentation/field/field_content.dart';
import 'package:gwent/src/features/match/presentation/stage/stage_frame.dart';
import 'package:gwent/src/features/match/presentation/stage/stage_geometry.dart';
import 'package:gwent/src/features/match/presentation/stage/stage_place.dart';
import 'package:gwent_engine/gwent_engine.dart';

/// Слой эффектов поверх поля (макет 12): затемнение, подсветки, летящие карты, волны погоды, сгорание, пепел,
/// превращение Берсерка и подписи. Слой ничего не принимает на себя: нажатия идут сквозь него.
class StageLayer extends StatelessWidget {
  /// Создаёт слой для кадра [frame].
  const StageLayer({
    super.key,
    required this.frame,
    required this.geometry,
    required this.faceOf,
    required this.backOf,
    required this.leaderOf,
  });

  /// Кадр сценария.
  final StageFrame frame;

  /// Координаты мест.
  final StageGeometry geometry;

  /// Лицо карты.
  final CardFace Function(CardInstance card) faceOf;

  /// Рубашка колоды: моей или соперника.
  final CardFace Function({required bool mine}) backOf;

  /// Мини-карта лидера: моя или соперника.
  final CardFace Function({required bool mine}) leaderOf;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Stack(
      clipBehavior: Clip.none,
      children: [for (final item in frame.items) ?_build(context, item)],
    ),
  );

  Widget? _build(BuildContext context, StageItem item) => switch (item) {
    ScrimItem(:final alpha) => Positioned.fill(child: ColoredBox(color: Color.fromRGBO(0, 0, 0, alpha))),
    final GlowItem glow => _glow(glow),
    final CardFlightItem flight => _flight(flight),
    final CaptionItem caption => _caption(context, caption),
    final WaveItem wave => _wave(wave),
    final BurnItem burn => _burn(burn),
    final AshItem ash => _ash(ash),
    final MorphItem morph => _morph(morph),
  };

  Widget? _glow(GlowItem glow) {
    final rect = geometry.rectOf(glow.place, frame);
    if (rect == null) return null;
    final color = glow.color;
    final alpha = glow.alpha.clamp(0.0, 1.0);
    final child = switch (glow.kind) {
      GlowKind.frame => DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(3),
          color: color.withValues(alpha: 0.12 * alpha),
          border: Border.all(color: color.withValues(alpha: alpha), width: 1.5),
          boxShadow: [BoxShadow(color: color.withValues(alpha: 0.5 * alpha), blurRadius: 12)],
        ),
      ),
      GlowKind.wash => ColoredBox(color: color.withValues(alpha: 0.35 * alpha)),
      GlowKind.sweep => Align(
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: glow.progress,
          child: ColoredBox(
            color: color.withValues(alpha: 0.35 * alpha),
            child: const SizedBox.expand(),
          ),
        ),
      ),
    };
    return Positioned.fromRect(rect: rect, child: child);
  }

  Widget? _flight(CardFlightItem item) {
    final from = geometry.rectOf(item.from, frame);
    final to = geometry.rectOf(item.to, frame);
    if (from == null || to == null) return null;
    final base = Rect.lerp(from, to, item.u)!;
    final lifted = base.shift(Offset(0, item.arc * math.sin(math.pi * item.u) - item.lift));
    final metrics = item.size.metrics;
    final angle = item.ry * math.pi / 180;
    final showsBack = math.cos(angle) < 0;
    final face = switch (item.ref) {
      CardFaceRef(:final card, :final mine) => showsBack ? backOf(mine: mine) : faceOf(card),
      CardBackRef(:final mine) => backOf(mine: mine),
      LeaderRef(:final mine) => leaderOf(mine: mine),
    };
    Widget card = SizedBox(
      width: metrics.width,
      height: metrics.height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(3),
          boxShadow: item.shadow <= 0
              ? null
              : [
                  BoxShadow(
                    color: Color.fromRGBO(0, 0, 0, 0.6 * item.shadow),
                    offset: Offset(0, 10 * item.shadow),
                    blurRadius: 18 * item.shadow,
                  ),
                ],
        ),
        child: GwentCard(face: face, size: item.size),
      ),
    );
    if (showsBack) card = Transform.flip(flipX: true, child: card);
    return Positioned.fromRect(
      rect: lifted,
      child: Opacity(
        opacity: item.opacity.clamp(0.0, 1.0),
        child: Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.0015)
            ..rotateY(angle)
            ..scaleByDouble(item.scale, item.scale, 1, 1),
          child: FittedBox(fit: BoxFit.fill, child: card),
        ),
      ),
    );
  }

  Widget? _caption(BuildContext context, CaptionItem item) {
    final rect = geometry.rectOf(const CenterPlace(), frame);
    if (rect == null) return null;
    final l10n = context.l10n;
    final text = switch (item.kind) {
      CaptionKind.opponentPlays => l10n.stageOpponentPlays(item.card == null ? '' : faceOf(item.card!).name),
      CaptionKind.noTargets => l10n.stageNoTargets,
    };
    return Positioned(
      left: 16,
      right: 16,
      top: rect.bottom + 10,
      child: Opacity(
        opacity: item.alpha.clamp(0.0, 1.0),
        child: Center(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: GwentColors.bg.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: GwentColors.brass),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              child: Text(
                text,
                textAlign: TextAlign.center,
                textScaler: TextScaler.noScaling,
                style: GwentText.caption.copyWith(fontWeight: FontWeight.w700, fontSize: 13),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget? _wave(WaveItem wave) {
    final rect = geometry.rectOf(wave.place, frame);
    if (rect == null) return null;
    final tint = FieldContent.weatherOf(wave.place.row).tint;
    final color = wave.reverse ? const Color(0xFFE8DCC0) : tint;
    final progress = wave.reverse ? 1 - wave.progress : wave.progress;
    final bandWidth = rect.width * 0.4;
    final left = -bandWidth + (rect.width + bandWidth) * progress;
    final flash =
        wave.storm && ((wave.progress > 0.3 && wave.progress < 0.4) || (wave.progress > 0.6 && wave.progress < 0.7));
    return Positioned.fromRect(
      rect: rect,
      child: ClipRect(
        child: Stack(
          children: [
            Positioned(
              left: left,
              width: bandWidth,
              top: 0,
              bottom: 0,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color.withValues(alpha: 0), color.withValues(alpha: 0.55), color.withValues(alpha: 0)],
                  ),
                ),
              ),
            ),
            if (flash) const Positioned.fill(child: ColoredBox(color: Color(0x66FFFFFF))),
          ],
        ),
      ),
    );
  }

  Widget? _burn(BurnItem item) {
    final rect = geometry.rectOf(item.place, frame);
    if (rect == null) return null;
    final fade = 1 - ((item.burn - 0.85) / 0.15).clamp(0.0, 1.0);
    return Positioned.fromRect(
      rect: rect.shift(Offset(0, -8 * item.target)),
      child: Opacity(
        opacity: fade,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColorFiltered(
              colorFilter: ColorFilter.mode(Color.fromRGBO(0, 0, 0, 0.7 * item.burn), BlendMode.srcATop),
              child: GwentCard(face: faceOf(item.card), size: CardSize.row),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(3),
                border: Border.all(color: GwentColors.debuff.withValues(alpha: item.target), width: 1.5),
              ),
            ),
            if (item.burn > 0)
              Align(
                alignment: Alignment.bottomCenter,
                child: FractionallySizedBox(
                  heightFactor: item.burn,
                  widthFactor: 1,
                  child: const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0x00FF6A1A), Color(0xCCFF6A1A), Color(0xCCFFC44D)],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget? _ash(AshItem item) {
    final rect = geometry.rectOf(item.place, frame);
    if (rect == null) return null;
    return Positioned.fromRect(
      rect: rect.inflate(18),
      child: CustomPaint(
        painter: _AshPainter(progress: item.progress, seed: item.seed, count: item.count),
      ),
    );
  }

  Widget? _morph(MorphItem item) {
    final rect = geometry.rectOf(item.place, frame);
    if (rect == null) return null;
    final angle = item.progress * math.pi;
    final second = item.progress >= 0.5;
    return Positioned.fromRect(
      rect: rect,
      child: Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()
          ..setEntry(3, 2, 0.003)
          ..rotateY(second ? angle - math.pi : angle),
        child: GwentCard(face: faceOf(second ? item.to : item.from), size: CardSize.row),
      ),
    );
  }
}

/// Пепел от сгоревшей карты: частицы разлетаются вверх и в стороны и гаснут.
class _AshPainter extends CustomPainter {
  const _AshPainter({required this.progress, required this.seed, required this.count});

  final double progress;
  final int seed;
  final int count;

  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(seed);
    final paint = Paint();
    for (var i = 0; i < count; i++) {
      final x = random.nextDouble();
      final drift = (random.nextDouble() - 0.5) * 30;
      final rise = 18 + random.nextDouble() * 34;
      final radius = 1 + random.nextDouble() * 1.6;
      final warm = random.nextBool();
      paint.color = (warm ? const Color(0xFFFFA64D) : const Color(0xFF8A8176)).withValues(alpha: (1 - progress) * 0.9);
      canvas.drawCircle(Offset(size.width * x + drift * progress, size.height * 0.8 - rise * progress), radius, paint);
    }
  }

  @override
  bool shouldRepaint(_AshPainter oldDelegate) => oldDelegate.progress != progress;
}
