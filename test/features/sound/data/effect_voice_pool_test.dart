import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:gwent/src/features/sound/data/effect_voice_pool.dart';
import 'package:gwent/src/features/sound/domain/sound_effect.dart';

final class _FakeVoice implements EffectVoice {
  _FakeVoice(this.effect, this.id, this.log);

  final SoundEffect effect;
  final int id;
  final List<String> log;
  bool disposed = false;
  Exception? playError;
  Completer<void>? playGate;

  @override
  Future<void> play(double volume) async {
    log.add('play:${effect.name}#$id');
    await playGate?.future;
    final error = playError;
    if (error != null) throw error;
  }

  @override
  Future<void> dispose() async {
    disposed = true;
    log.add('dispose:${effect.name}#$id');
  }
}

void main() {
  late List<String> log;
  late List<_FakeVoice> voices;
  late List<String> errors;
  late DateTime clock;
  Exception? createError;
  Completer<void>? createGate;

  EffectVoicePool poolOf({int maxEffects = 2, int voicesPerEffect = 2}) => EffectVoicePool(
    create: (effect) async {
      await createGate?.future;
      final error = createError;
      if (error != null) throw error;
      final voice = _FakeVoice(effect, voices.length, log);
      voices.add(voice);
      return voice;
    },
    onError: (error, stackTrace, action) => errors.add('$action: $error'),
    maxEffects: maxEffects,
    voicesPerEffect: voicesPerEffect,
    overlapWindow: const Duration(seconds: 1),
    closeDelay: Duration.zero,
    now: () => clock,
  );

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  setUp(() {
    log = [];
    voices = [];
    errors = [];
    clock = DateTime(2026);
    createError = null;
    createGate = null;
  });

  test('первый запуск создаёт проигрыватель и играет', () async {
    poolOf().play(SoundEffect.select, 0.5);
    await settle();
    expect(voices, hasLength(1));
    expect(log, ['play:select#0']);
  });

  test('редкий повтор того же эффекта идёт на том же проигрывателе', () async {
    final pool = poolOf()..play(SoundEffect.select, 1);
    await settle();
    clock = clock.add(const Duration(seconds: 5));
    pool.play(SoundEffect.select, 1);
    await settle();
    expect(voices, hasLength(1));
    expect(log, ['play:select#0', 'play:select#0']);
  });

  test('быстрый повтор звучит поверх прежнего: заводится второй проигрыватель, дальше они чередуются', () async {
    final pool = poolOf()..play(SoundEffect.select, 1);
    await settle();
    clock = clock.add(const Duration(milliseconds: 100));
    pool.play(SoundEffect.select, 1);
    await settle();
    clock = clock.add(const Duration(milliseconds: 100));
    pool.play(SoundEffect.select, 1);
    await settle();
    expect(voices, hasLength(2));
    expect(log, ['play:select#0', 'play:select#1', 'play:select#0']);
  });

  test('разные эффекты играют на разных проигрывателях и не ждут друг друга', () async {
    final gate = Completer<void>();
    final pool = poolOf(voicesPerEffect: 1)..play(SoundEffect.select, 1);
    await settle();
    voices.single.playGate = gate;
    pool
      ..play(SoundEffect.select, 1)
      ..play(SoundEffect.pass, 1);
    await settle();
    expect(log, contains('play:pass#1'));
    gate.complete();
  });

  test('запуски одного проигрывателя идут по очереди', () async {
    final pool = poolOf(voicesPerEffect: 1)..play(SoundEffect.select, 1);
    await settle();
    final gate = Completer<void>();
    voices.single.playGate = gate;
    pool
      ..play(SoundEffect.select, 1)
      ..play(SoundEffect.select, 1);
    await settle();
    expect(log.where((entry) => entry.startsWith('play')), hasLength(2), reason: 'третий ждёт второй');
    gate.complete();
    await settle();
    expect(log.where((entry) => entry.startsWith('play')), hasLength(3));
  });

  test('при нехватке места закрывается эффект, которым дольше всего не пользовались', () async {
    final pool = poolOf()
      ..play(SoundEffect.select, 1)
      ..play(SoundEffect.pass, 1);
    await settle();
    pool
      ..play(SoundEffect.select, 1)
      ..play(SoundEffect.draw, 1);
    await settle();
    await settle();
    expect(voices.where((voice) => voice.disposed).map((voice) => voice.effect), [SoundEffect.pass]);
  });

  test('вытесненный эффект создаётся заново, когда до него доходит очередь', () async {
    final pool = poolOf(maxEffects: 1)
      ..play(SoundEffect.select, 1)
      ..play(SoundEffect.pass, 1);
    await settle();
    await settle();
    pool.play(SoundEffect.select, 1);
    await settle();
    expect(voices.map((voice) => voice.effect), [SoundEffect.select, SoundEffect.pass, SoundEffect.select]);
  });

  test('вытесняемый проигрыватель сначала доигрывает запуски, стоящие в его очереди', () async {
    final pool = poolOf(maxEffects: 1, voicesPerEffect: 1)..play(SoundEffect.select, 1);
    await settle();
    final gate = Completer<void>();
    voices.single.playGate = gate;
    pool
      ..play(SoundEffect.select, 1)
      ..play(SoundEffect.pass, 1);
    await settle();
    await settle();
    expect(voices.first.disposed, isFalse, reason: 'запуск в очереди ещё не вернулся');
    gate.complete();
    await settle();
    await settle();
    expect(voices.first.disposed, isTrue);
  });

  test(
    'сорвавшаяся подготовка сообщается один раз, не оставляет проигрыватель и повторяется при следующем запуске',
    () async {
      createError = Exception('нет ресурсов');
      final pool = poolOf()..play(SoundEffect.select, 1);
      await settle();
      await settle();
      expect(errors, hasLength(1));
      expect(errors.single, contains('подготовка select'));
      expect(voices, isEmpty);

      createError = null;
      clock = clock.add(const Duration(seconds: 5));
      pool.play(SoundEffect.select, 1);
      await settle();
      expect(log, ['play:select#0']);
    },
  );

  test('проигрыватель, на котором сорвался запуск, закрывается, а следующий запуск создаёт новый', () async {
    final pool = poolOf(voicesPerEffect: 1)..play(SoundEffect.select, 1);
    await settle();
    voices.single.playError = TimeoutException('завис');
    pool.play(SoundEffect.select, 1);
    await settle();
    await settle();
    expect(errors.single, contains('воспроизведение select'));
    expect(voices.single.disposed, isTrue);

    pool.play(SoundEffect.select, 1);
    await settle();
    expect(voices, hasLength(2));
    expect(log.last, 'play:select#1');
  });

  test('warm готовит эффект заранее, а играет он сразу', () async {
    final pool = poolOf();
    await pool.warm(SoundEffect.select);
    expect(voices, hasLength(1));
    expect(log, isEmpty);
    pool.play(SoundEffect.select, 1);
    await settle();
    expect(voices, hasLength(1));
    expect(log, ['play:select#0']);
  });

  test('warm не бросает, если подготовка сорвалась', () async {
    createError = Exception('нет ресурсов');
    final pool = poolOf();
    await pool.warm(SoundEffect.select);
    expect(errors, hasLength(1));
  });
}
