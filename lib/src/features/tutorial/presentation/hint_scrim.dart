import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_colors.dart';

/// Окно в затемнении: [frame] рисуется золотой рамкой (если [framed]), [touch] пропускает нажатия к полю под слоем.
@immutable
final class HintWindow {
  /// Создаёт окно.
  const HintWindow(this.frame, {this.touch, this.framed = true});

  /// Место окна в координатах слоя.
  final Rect frame;

  /// Где нажатия идут сквозь затемнение; `null` — окно нажатий не пропускает (показ), пустой прямоугольник — то же.
  final Rect? touch;

  /// Обвести окно рамкой; без неё окно только пропускает нажатия (кнопка паузы).
  final bool framed;

  @override
  bool operator ==(Object other) =>
      other is HintWindow && other.frame == frame && other.touch == touch && other.framed == framed;

  @override
  int get hashCode => Object.hash(frame, touch, framed);
}

/// Затемнение поля с окнами и золотыми рамками на них (макет 16).
///
/// Затемнение ловит нажатия вне окон и сообщает о них в [onBlocked]; нажатия в [HintWindow.touch] проходят к полю.
/// Без [dimmed] слой только рисует рамки и нажатий не ловит (свободный ход игрока). Рамки пульсируют с [pulse];
/// без него (экономия движения) рамка горит ровно.
class HintScrim extends LeafRenderObjectWidget {
  /// Создаёт слой.
  const HintScrim({
    super.key,
    required this.windows,
    required this.dimmed,
    this.pulse,
    this.onBlocked,
    this.emphasis = const {},
  });

  /// Окна затемнения.
  final List<HintWindow> windows;

  /// Затемнять поле и ловить нажатия вне окон.
  final bool dimmed;

  /// Фаза пульса рамок, 0–1; `null` — рамки без пульса.
  final Animation<double>? pulse;

  /// Нажали вне окон.
  final VoidCallback? onBlocked;

  /// Окна, рамка которых горит ярче остальных (то, что нужно нажать сейчас), по номеру в [windows].
  final Set<int> emphasis;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      RenderHintScrim(windows: windows, dimmed: dimmed, pulse: pulse, onBlocked: onBlocked, emphasis: emphasis);

  @override
  void updateRenderObject(BuildContext context, RenderHintScrim renderObject) {
    renderObject
      ..windows = windows
      ..dimmed = dimmed
      ..pulse = pulse
      ..onBlocked = onBlocked
      ..emphasis = emphasis;
  }
}

/// Рисует затемнение и рамки и решает, куда идут нажатия ([HintScrim]).
class RenderHintScrim extends RenderBox {
  RenderHintScrim({
    required List<HintWindow> windows,
    required bool dimmed,
    required Animation<double>? pulse,
    required this.onBlocked,
    required Set<int> emphasis,
  }) : _windows = windows,
       _dimmed = dimmed,
       _pulse = pulse,
       _emphasis = emphasis;

  VoidCallback? onBlocked;

  List<HintWindow> _windows;

  /// Окна затемнения.
  List<HintWindow> get windows => _windows;
  set windows(List<HintWindow> value) {
    if (listEquals(value, _windows)) return;
    _windows = value;
    markNeedsPaint();
  }

  bool _dimmed;

  /// Затемнять поле и ловить нажатия.
  bool get dimmed => _dimmed;
  set dimmed(bool value) {
    if (value == _dimmed) return;
    _dimmed = value;
    markNeedsPaint();
  }

  Set<int> _emphasis;

  /// Окна с яркой рамкой.
  Set<int> get emphasis => _emphasis;
  set emphasis(Set<int> value) {
    if (setEquals(value, _emphasis)) return;
    _emphasis = value;
    markNeedsPaint();
  }

  Animation<double>? _pulse;

  /// Фаза пульса рамок.
  Animation<double>? get pulse => _pulse;
  set pulse(Animation<double>? value) {
    if (value == _pulse) return;
    if (attached) _pulse?.removeListener(markNeedsPaint);
    _pulse = value;
    if (attached) _pulse?.addListener(markNeedsPaint);
    markNeedsPaint();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _pulse?.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    _pulse?.removeListener(markNeedsPaint);
    super.detach();
  }

  @override
  bool get sizedByParent => true;

  @override
  Size computeDryLayout(BoxConstraints constraints) => constraints.biggest;

  @override
  bool hitTestSelf(Offset position) => _dimmed && !_windows.any((window) => window.touch?.contains(position) ?? false);

  @override
  void handleEvent(PointerEvent event, BoxHitTestEntry entry) {
    if (event is PointerDownEvent) onBlocked?.call();
  }

  static RRect _round(Rect rect, [double outset = 3]) =>
      RRect.fromRectAndRadius(rect.inflate(outset), const Radius.circular(8));

  @override
  void paint(PaintingContext context, Offset offset) {
    final canvas = context.canvas;
    final bounds = offset & size;
    if (_dimmed) {
      final holes = Path();
      for (final window in _windows) {
        holes.addRRect(_round(window.frame.shift(offset)));
      }
      final scrim = Path.combine(PathOperation.difference, Path()..addRect(bounds), holes);
      canvas.drawPath(scrim, Paint()..color = GwentColors.scrim);
    }
    final phase = _pulse?.value ?? 1;
    for (var i = 0; i < _windows.length; i++) {
      final window = _windows[i];
      if (!window.framed) continue;
      final rect = _round(window.frame.shift(offset));
      final bright = _emphasis.isEmpty || _emphasis.contains(i);
      final strength = bright ? 0.65 + 0.35 * phase : 0.55;
      canvas
        ..drawRRect(
          rect.inflate(3),
          Paint()
            ..color = GwentColors.gold.withValues(alpha: 0.28 * strength)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 6
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
        )
        ..drawRRect(
          rect,
          Paint()
            ..color = GwentColors.goldHighlight.withValues(alpha: strength)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
    }
  }
}
