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
/// Цели сообщают о входе и выходе пальца через [enter] и [leave]. Состояние меняется после того, как отработали все
/// сообщения одного движения: при переходе с цели на цель Flutter сначала сообщает о выходе из прежней, потом о входе
/// в новую, а игроку это одно непрерывное «над целью». [onChanged] получает только настоящую смену состояния,
/// поэтому вибрация входа и выхода не дребезжит.
class DragHover extends ValueNotifier<bool> {
  /// Создаёт трекер без цели под пальцем.
  DragHover({this.onChanged}) : super(false);

  /// Состояние сменилось: палец вошёл в цель (`true`) или вышел из всех целей (`false`).
  final void Function({required bool over})? onChanged;

  int _targets = 0;
  bool _settling = false;

  /// Палец вошёл в цель.
  void enter() {
    _targets++;
    _settle();
  }

  /// Палец вышел из цели.
  void leave() {
    if (_targets > 0) _targets--;
    _settle();
  }

  /// Перетаскивание кончилось (карту отпустили или отменили): целей под пальцем больше нет. Об отпускании игрок
  /// узнаёт по своей вибрации, поэтому [onChanged] не зовётся.
  void reset() {
    _targets = 0;
    value = false;
  }

  void _settle() {
    if (_settling) return;
    _settling = true;
    scheduleMicrotask(() {
      _settling = false;
      final over = _targets > 0;
      if (over == value) return;
      value = over;
      onChanged?.call(over: over);
    });
  }
}
