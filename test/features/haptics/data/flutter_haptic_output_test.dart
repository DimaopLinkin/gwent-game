import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gwent/src/features/haptics/data/flutter_haptic_output.dart';
import 'package:gwent/src/features/haptics/domain/haptic_pattern.dart';

void main() {
  late List<String> log;
  late List<Duration> delays;
  late FlutterHapticOutput output;

  setUp(() {
    log = [];
    delays = [];
    output = FlutterHapticOutput(
      impact: (strength) async => log.add(strength.name),
      delay: (duration) async => delays.add(duration),
    );
  });

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  test('паттерн играется касаниями по порядку с паузами из паттерна', () async {
    output.play(HapticPattern.ripple);
    await settle();
    expect(log, ['medium', 'soft', 'tick']);
    expect(delays, [const Duration(milliseconds: 60), const Duration(milliseconds: 60)]);
  });

  test('новый паттерн обрывает недоигранный', () async {
    final gates = <Future<void>>[];
    output = FlutterHapticOutput(
      impact: (strength) async => log.add(strength.name),
      delay: (duration) {
        final gate = Future<void>.delayed(const Duration(milliseconds: 20));
        gates.add(gate);
        return gate;
      },
    );
    output.play(HapticPattern.rumble);
    await settle();
    expect(log, ['heavy'], reason: 'остальное ждёт паузы');
    output.play(HapticPattern.tick);
    await settle();
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(log, ['heavy', 'tick'], reason: 'хвост рокота отброшен');
  });

  test('сбой платформы не роняет игру', () async {
    final failing = FlutterHapticOutput(impact: (_) => throw Exception('нет мотора'), delay: (_) async {});
    final errors = <Object>[];
    final previous = FlutterError.onError;
    FlutterError.onError = (details) => errors.add(details.exception);
    addTearDown(() => FlutterError.onError = previous);
    failing.play(HapticPattern.double);
    await settle();
    expect(errors, hasLength(1));
  });
}
