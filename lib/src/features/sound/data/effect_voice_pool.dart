import 'dart:async';

import 'package:gwent/src/features/sound/data/recent_slots.dart';
import 'package:gwent/src/features/sound/domain/sound_effect.dart';

/// Один проигрыватель эффекта: перезапускает звук с нуля.
abstract interface class EffectVoice {
  /// Играет эффект с нуля; [volume] от 0 до 1. Не возвращается, пока звук не запущен.
  Future<void> play(double volume);

  /// Освобождает проигрыватель.
  Future<void> dispose();
}

/// Создаёт и готовит проигрыватель [effect]. Если подготовка не удалась, сам освобождает то, что успел занять.
typedef EffectVoiceFactory = Future<EffectVoice> Function(SoundEffect effect);

/// Сообщает об ошибке: что случилось и что делали.
typedef SoundErrorReporter = void Function(Object error, StackTrace stackTrace, String action);

/// Живые проигрыватели эффектов (ADR 0023).
///
/// На iOS каждый проигрыватель держит свой `AVPlayer`, поэтому их число ограничено: живых эффектов не больше
/// [maxEffects], а когда место кончилось, закрывается тот, которым дольше всего не пользовались (его звук
/// доигрывает [closeDelay], потом проигрыватель освобождается). Эффект создаётся при первом запуске или в [warm].
///
/// Один и тот же эффект, запущенный снова в пределах [overlapWindow], звучит поверх прежнего: для этого у эффекта
/// заводится до [voicesPerEffect] проигрывателей, и запуски идут по кругу. Запуски одного проигрывателя идут по
/// очереди. Проигрыватель, на котором что-то сорвалось, выбрасывается, и следующий запуск создаёт новый.
///
/// Запуск живёт [staleAfter]: если он простоял дольше (платформа держала вызов, пока экран был заблокирован), то
/// просто пропускается. Иначе после разблокировки все накопившиеся звуки сыграли бы разом.
final class EffectVoicePool {
  /// Создаёт пул; [create] делает проигрыватели, [onError] получает все ошибки, [now] отдаёт текущее время.
  EffectVoicePool({
    required EffectVoiceFactory create,
    required SoundErrorReporter onError,
    int maxEffects = 12,
    this.voicesPerEffect = 2,
    this.overlapWindow = const Duration(milliseconds: 1500),
    this.closeDelay = const Duration(seconds: 6),
    this.staleAfter = const Duration(milliseconds: 400),
    DateTime Function() now = DateTime.now,
  }) : assert(voicesPerEffect > 0, 'проигрывателей на эффект положительное число'),
       _create = create,
       _onError = onError,
       _now = now,
       _slots = RecentSlots(maxEffects);

  /// Сколько проигрывателей может быть у одного эффекта.
  final int voicesPerEffect;

  /// Повтор эффекта в пределах этого времени звучит поверх прежнего.
  final Duration overlapWindow;

  /// Сколько вытесненный эффект ещё может доиграть, прежде чем проигрыватель освободится.
  final Duration closeDelay;

  /// Через сколько после запроса запуск уже не нужен.
  final Duration staleAfter;

  final EffectVoiceFactory _create;
  final SoundErrorReporter _onError;
  final DateTime Function() _now;
  final RecentSlots<SoundEffect, _Slot> _slots;

  /// Готовит проигрыватель [effect] заранее; ошибка подготовки уходит в [onError].
  Future<void> warm(SoundEffect effect) async {
    final slot = _slot(effect);
    final voice = slot.voices.isEmpty ? _addVoice(slot, effect) : slot.voices.first;
    await voice.player.then<void>((_) {}, onError: (Object _) {});
  }

  /// Играет [effect] с громкостью [volume] (0–1); не ждёт, пока звук запустится.
  void play(SoundEffect effect, double volume) {
    final slot = _slot(effect);
    final now = _now();
    final last = slot.lastPlay;
    final overlapping = last != null && now.difference(last) < overlapWindow;
    slot.lastPlay = now;
    final _Voice voice;
    if (slot.voices.isEmpty || (overlapping && slot.voices.length < voicesPerEffect)) {
      voice = _addVoice(slot, effect);
      slot.cursor = slot.voices.length - 1;
    } else {
      if (overlapping) slot.cursor = (slot.cursor + 1) % slot.voices.length;
      voice = slot.voices[slot.cursor % slot.voices.length];
    }
    voice.tail = voice.tail.then((_) => _run(slot, voice, effect, volume, now));
  }

  _Slot _slot(SoundEffect effect) {
    final existing = _slots.use(effect);
    if (existing != null) return existing;
    final slot = _Slot();
    final displaced = _slots.put(effect, slot);
    if (displaced != null) unawaited(_close(displaced.key, displaced.value));
    return slot;
  }

  _Voice _addVoice(_Slot slot, SoundEffect effect) {
    final voice = _Voice(_create(effect));
    slot.voices.add(voice);
    unawaited(
      voice.player.then<void>(
        (_) {},
        onError: (Object error, StackTrace stackTrace) {
          slot.voices.remove(voice);
          _onError(error, stackTrace, 'подготовка ${effect.name}');
        },
      ),
    );
    return voice;
  }

  bool _isStale(DateTime requested) => _now().difference(requested) > staleAfter;

  Future<void> _run(_Slot slot, _Voice voice, SoundEffect effect, double volume, DateTime requested) async {
    if (_isStale(requested)) return;
    // Ошибка подготовки уже сообщена в [_addVoice].
    final player = await voice.player.then<EffectVoice?>((player) => player, onError: (Object _) => null);
    if (player == null || _isStale(requested)) return;
    try {
      await player.play(volume);
    } on Object catch (error, stackTrace) {
      _onError(error, stackTrace, 'воспроизведение ${effect.name}');
      slot.voices.remove(voice);
      await _dispose(player, effect);
    }
  }

  Future<void> _close(SoundEffect effect, _Slot slot) async {
    await Future<void>.delayed(closeDelay);
    for (final voice in List.of(slot.voices)) {
      await voice.tail;
      final player = await voice.player.then<EffectVoice?>((player) => player, onError: (Object _) => null);
      if (player != null) await _dispose(player, effect);
    }
    slot.voices.clear();
  }

  Future<void> _dispose(EffectVoice player, SoundEffect effect) async {
    try {
      await player.dispose();
    } on Object catch (error, stackTrace) {
      _onError(error, stackTrace, 'закрытие ${effect.name}');
    }
  }
}

final class _Voice {
  _Voice(this.player);

  final Future<EffectVoice> player;
  Future<void> tail = Future<void>.value();
}

final class _Slot {
  final List<_Voice> voices = [];
  int cursor = 0;
  DateTime? lastPlay;
}
