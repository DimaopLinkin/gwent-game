import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:gwent/src/features/match/presentation/stage/stage_frame.dart';
import 'package:gwent/src/features/match/presentation/stage/stage_script.dart';
import 'package:gwent/src/features/match/presentation/stage/stage_tokens.dart';
import 'package:gwent/src/features/sound/domain/sound_effect.dart';

/// Строит поле для кадра сценария; [speedUp] ускоряет текущий сценарий (тап по полю), [skip] переходит к следующему
/// шагу (кнопка «Пропустить»).
typedef StageBuilderFn =
    Widget Function(BuildContext context, StageFrame? frame, VoidCallback speedUp, VoidCallback skip);

/// Часы сценария: гоняют время от нуля до конца [script] и отдают поле кадр за кадром.
///
/// Время идёт одним тикером, поэтому тап «ускорить» просто увеличивает скорость хода времени в
/// [StageTokens.tapSpeedUp] раз, не меняя самого сценария. Когда время дошло до конца, часы один раз сообщают об этом
/// через [onDone]; пока сценария нет, поле строится без кадра, как обычно. Звуки сценария ([StageScript.cues]) уходят в
/// [onCue], когда время доходит до их момента; кнопка «Пропустить» пропущенные звуки не играет.
class StageHost extends StatefulWidget {
  /// Создаёт часы.
  const StageHost({super.key, required this.script, required this.onDone, required this.builder, this.onCue});

  /// Сценарий; `null`, пока показывать нечего.
  final StageScript? script;

  /// Сценарий [StageScript.id] отыгран до конца.
  final ValueChanged<int> onDone;

  /// Строит поле.
  final StageBuilderFn builder;

  /// Звук сценария начался; `null` — без звука.
  final ValueChanged<SoundEffect>? onCue;

  @override
  State<StageHost> createState() => _StageHostState();
}

class _StageHostState extends State<StageHost> with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_onTick);
  Duration _last = Duration.zero;
  double _time = 0;
  double _speed = 1;
  int? _playing;
  int _nextCue = 0;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void didUpdateWidget(StageHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.script?.id != _playing) _start();
  }

  void _start() {
    final script = widget.script;
    _playing = script?.id;
    _time = 0;
    _speed = 1;
    _last = Duration.zero;
    _nextCue = 0;
    if (_ticker.isActive) _ticker.stop();
    if (script != null) unawaited(_ticker.start());
  }

  void _onTick(Duration elapsed) {
    final script = widget.script;
    if (script == null) return;
    final delta = (elapsed - _last).inMicroseconds / 1000;
    _last = elapsed;
    // Плашки итога тап не ускоряет, даже если игрок тапнул раньше: внутри окна время идёт как обычно.
    final speed = script.tapSpeedsUp(_time) ? _speed : 1;
    setState(() => _time += delta * speed);
    _playCues(script);
    if (_time >= script.duration) {
      _ticker.stop();
      widget.onDone(script.id);
    }
  }

  void _speedUp() {
    final script = widget.script;
    if (script == null || script.tapSpeedsUp(_time)) _speed = StageTokens.tapSpeedUp;
  }

  void _skip() {
    final script = widget.script;
    if (script == null) return;
    final target = script.nextStep(_time);
    // Звуки, оставшиеся за перескоком, пропадают: иначе они наложились бы друг на друга одним залпом.
    while (_nextCue < script.cues.length && script.cues[_nextCue].at < target) {
      _nextCue++;
    }
    setState(() => _time = target);
  }

  /// Играет звуки, чьё время уже настало.
  void _playCues(StageScript script) {
    final onCue = widget.onCue;
    while (_nextCue < script.cues.length && script.cues[_nextCue].at <= _time) {
      final cue = script.cues[_nextCue++];
      onCue?.call(cue.effect);
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final script = widget.script;
    StageFrame? frame;
    if (script != null) frame = script.frameAt(_time.clamp(0, script.duration));
    return widget.builder(context, frame, _speedUp, _skip);
  }
}
