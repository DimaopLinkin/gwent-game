import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:gwent/src/features/haptics/domain/haptic_pattern.dart';

/// Вибрация прицеливания (макет 14, ADR 0031).
abstract final class TargetHaptics {
  /// Палец вошёл в цель.
  static const HapticPattern enter = HapticPattern.soft;

  /// Палец вышел из цели.
  static const HapticPattern leave = HapticPattern.tick;

  /// Карту отпустили на цели (броском или тапом).
  static const HapticPattern hit = HapticPattern.medium;

  /// Карту отпустили мимо цели, она вернулась в руку.
  static const HapticPattern miss = HapticPattern.double;
}

/// Над какой целью сейчас перетаскиваемая карта (макет 14): «над целью» или «не над целью».
///
/// Цели сообщают о входе и выходе пальца через [enter] и [leave], называя себя (`target`: ряд, карта, полоса). Состояние
/// решается после того, как отработали все сообщения одного движения: когда набор целей под пальцем меняется (например,
/// палец вышел с пустого места ряда на карту этого же ряда), Flutter сначала сообщает о выходе из всех целей, потом о
/// входе, а игроку это одно непрерывное «над целью». [onChanged] получает только настоящую смену состояния, поэтому
/// вибрация входа и выхода не дребезжит. Если палец ушёл на другую цель, а «над целью» не менялось, зовётся
/// [onSwitched].
class DragHover extends ValueNotifier<bool> {
  /// Создаёт трекер без цели под пальцем.
  DragHover({this.onChanged, this.onSwitched}) : super(false);

  /// Состояние сменилось: палец вошёл в цель (`true`) или вышел из всех целей (`false`).
  final void Function({required bool over})? onChanged;

  /// Палец перешёл с одной цели на другую, не побывав вне целей: игрок должен это почувствовать, хотя «над целью» не
  /// менялось. На ту же цель (в том числе через вложенную отвергающую карту) не зовётся.
  final VoidCallback? onSwitched;

  final Set<Object> _targets = {};
  Set<Object> _settled = {};
  bool _settling = false;
  bool _disposed = false;

  /// Палец вошёл в цель [target].
  void enter(Object target) {
    _targets.add(target);
    _settle();
  }

  /// Палец вышел из цели [target].
  void leave(Object target) {
    _targets.remove(target);
    _settle();
  }

  /// Перетаскивание кончилось (карту отпустили или отменили): целей под пальцем больше нет. Об отпускании игрок
  /// узнаёт по своей вибрации, поэтому [onChanged] не зовётся.
  void reset() {
    _targets.clear();
    _settled = {};
    value = false;
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _settle() {
    if (_settling) return;
    _settling = true;
    scheduleMicrotask(() {
      _settling = false;
      if (_disposed) return;
      final before = _settled;
      final now = {..._targets};
      _settled = now;
      final over = now.isNotEmpty;
      if (over == value) {
        final same = before.length == now.length && before.containsAll(now);
        if (over && !same) onSwitched?.call();
        return;
      }
      value = over;
      onChanged?.call(over: over);
    });
  }
}
