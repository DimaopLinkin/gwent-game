import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:gwent/src/features/deck_builder/application/deck_selection_lock.dart';

void main() {
  test('действия идут по одному в порядке постановки', () async {
    final lock = DeckSelectionLock();
    final gate = Completer<void>();
    final log = <String>[];

    final first = lock.run(() async {
      log.add('первое начато');
      await gate.future;
      log.add('первое закончено');
    });
    final second = lock.run(() async => log.add('второе'));
    await pumpEventQueue();
    gate.complete();
    await Future.wait([first, second]);

    expect(log, ['первое начато', 'первое закончено', 'второе']);
  });

  test('ошибка действия достаётся вызывающему, а очередь идёт дальше', () async {
    final lock = DeckSelectionLock();

    await expectLater(lock.run<void>(() async => throw StateError('сбой')), throwsStateError);
    await expectLater(lock.run<void>(() => throw StateError('синхронный сбой')), throwsStateError);
    expect(await lock.run(() async => 42), 42);
  });
}
