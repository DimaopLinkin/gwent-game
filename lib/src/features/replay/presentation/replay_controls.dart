import 'package:flutter/widgets.dart';
import 'package:gwent/src/core/l10n/l10n.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_colors.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_text.dart';
import 'package:gwent/src/features/replay/presentation/replay_state.dart';
import 'package:gwent_engine/gwent_engine.dart' show Seat;

/// Что нарисовано на кнопке реплея.
enum _Glyph { close, play, pause, stepBack, stepForward, roundBack, roundForward }

/// Полоса управления реплеем: закрыть, раунд назад, ход назад, пуск и пауза, ход вперёд, раунд вперёд; под ней
/// положение в партии, чьими глазами смотреть и скорость.
///
/// Лежит под полем, поле её не закрывает. Кнопки не меньше 44 pt.
class ReplayControls extends StatelessWidget {
  /// Создаёт полосу для состояния [state]; [seatName] называет место, а [onSeat] переключает зрителя на другое место
  /// (`null`, если смотреть можно только одним местом).
  const ReplayControls({
    super.key,
    required this.state,
    required this.seatName,
    required this.onClose,
    required this.onTogglePlay,
    required this.onPrevious,
    required this.onNext,
    required this.onPreviousRound,
    required this.onNextRound,
    required this.onSpeed,
    this.onSeat,
    this.canStepForward = true,
  });

  /// Состояние показа.
  final ReplayShowing state;

  /// Как называется место зрителя на экране.
  final String Function(Seat seat) seatName;

  /// Закрыть реплей.
  final VoidCallback onClose;

  /// Пуск или пауза.
  final VoidCallback onTogglePlay;

  /// Ход назад.
  final VoidCallback onPrevious;

  /// Ход вперёд.
  final VoidCallback onNext;

  /// К началу раунда.
  final VoidCallback onPreviousRound;

  /// К следующему раунду.
  final VoidCallback onNextRound;

  /// Сменить скорость.
  final VoidCallback onSpeed;

  /// Сменить место зрителя.
  final VoidCallback? onSeat;

  /// Ход вперёд сейчас можно сделать: поле не занято показом прошлого хода.
  final bool canStepForward;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final step = state.step;
    return ColoredBox(
      color: GwentColors.panel,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _GlyphButton(glyph: _Glyph.close, label: l10n.replayClose, onPressed: onClose),
                _GlyphButton(
                  glyph: _Glyph.roundBack,
                  label: l10n.replayRoundBack,
                  onPressed: state.atStart ? null : onPreviousRound,
                ),
                _GlyphButton(
                  glyph: _Glyph.stepBack,
                  label: l10n.replayStepBack,
                  onPressed: state.atStart ? null : onPrevious,
                ),
                _GlyphButton(
                  glyph: state.playing ? _Glyph.pause : _Glyph.play,
                  label: state.playing ? l10n.replayPause : l10n.replayPlay,
                  onPressed: onTogglePlay,
                  emphasized: true,
                ),
                _GlyphButton(
                  glyph: _Glyph.stepForward,
                  label: l10n.replayStepForward,
                  onPressed: state.atEnd || !canStepForward ? null : onNext,
                ),
                _GlyphButton(
                  glyph: _Glyph.roundForward,
                  label: l10n.replayRoundForward,
                  onPressed: state.atEnd ? null : onNextRound,
                ),
              ],
            ),
            Row(
              spacing: 8,
              children: [
                Expanded(
                  child: Text(
                    l10n.replayProgress(state.index + 1, state.steps.length, step.round),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textScaler: TextScaler.noScaling,
                    style: const TextStyle(
                      fontFamily: GwentText.alegreya,
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                      height: 1.15,
                      color: GwentColors.textSecondary,
                    ),
                  ),
                ),
                if (onSeat != null) _Chip(label: l10n.replayWatchAs(seatName(state.seat)), onPressed: onSeat!),
                _Chip(label: l10n.replaySpeed(_speedText(state.speed)), onPressed: onSpeed),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _speedText(ReplaySpeed speed) =>
      speed.factor == speed.factor.roundToDouble() ? speed.factor.toStringAsFixed(0) : speed.factor.toString();
}

class _GlyphButton extends StatelessWidget {
  const _GlyphButton({required this.glyph, required this.label, required this.onPressed, this.emphasized = false});

  final _Glyph glyph;
  final String label;
  final VoidCallback? onPressed;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final color = !enabled
        ? GwentColors.disabledText
        : emphasized
        ? GwentColors.onGold
        : GwentColors.textPrimary;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      onTap: onPressed,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: SizedBox.square(
          dimension: 44,
          child: Center(
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: emphasized && enabled ? GwentColors.gold : null,
                border: emphasized && enabled
                    ? null
                    : Border.all(color: enabled ? GwentColors.brass : GwentColors.line),
              ),
              child: SizedBox.square(
                dimension: 38,
                child: CustomPaint(painter: _GlyphPainter(glyph, color)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    excludeSemantics: true,
    onTap: onPressed,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onPressed,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
        child: Center(
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: GwentColors.brass),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Text(
                label,
                textScaler: TextScaler.noScaling,
                style: const TextStyle(
                  fontFamily: GwentText.cormorant,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  height: 1.1,
                  color: GwentColors.goldHighlight,
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _GlyphPainter extends CustomPainter {
  const _GlyphPainter(this.glyph, this.color);

  final _Glyph glyph;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final c = size.center(Offset.zero);
    const h = 7.0;

    // Треугольник, смотрящий вправо или влево, с вершиной в точке (tipX, c.dy).
    Path triangle(double tipX, {required bool right}) {
      final baseX = tipX + (right ? -h : h);
      return Path()
        ..moveTo(tipX, c.dy)
        ..lineTo(baseX, c.dy - h)
        ..lineTo(baseX, c.dy + h)
        ..close();
    }

    switch (glyph) {
      case _Glyph.close:
        canvas
          ..drawLine(c + const Offset(-6, -6), c + const Offset(6, 6), stroke)
          ..drawLine(c + const Offset(-6, 6), c + const Offset(6, -6), stroke);
      case _Glyph.play:
        canvas.drawPath(triangle(c.dx + 7, right: true), paint);
      case _Glyph.pause:
        canvas
          ..drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromCenter(center: c + const Offset(-4, 0), width: 4, height: 14),
              const Radius.circular(1),
            ),
            paint,
          )
          ..drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromCenter(center: c + const Offset(4, 0), width: 4, height: 14),
              const Radius.circular(1),
            ),
            paint,
          );
      case _Glyph.stepBack:
        canvas
          ..drawLine(c + const Offset(-7, -7), c + const Offset(-7, 7), stroke)
          ..drawPath(triangle(c.dx - 5, right: false), paint);
      case _Glyph.stepForward:
        canvas
          ..drawLine(c + const Offset(7, -7), c + const Offset(7, 7), stroke)
          ..drawPath(triangle(c.dx + 5, right: true), paint);
      case _Glyph.roundBack:
        canvas
          ..drawLine(c + const Offset(-8, -7), c + const Offset(-8, 7), stroke)
          ..drawPath(triangle(c.dx - 6, right: false), paint)
          ..drawPath(triangle(c.dx + 1, right: false), paint);
      case _Glyph.roundForward:
        canvas
          ..drawLine(c + const Offset(8, -7), c + const Offset(8, 7), stroke)
          ..drawPath(triangle(c.dx + 6, right: true), paint)
          ..drawPath(triangle(c.dx - 1, right: true), paint);
    }
  }

  @override
  bool shouldRepaint(_GlyphPainter oldDelegate) => oldDelegate.glyph != glyph || oldDelegate.color != color;
}
