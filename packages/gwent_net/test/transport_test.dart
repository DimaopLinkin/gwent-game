import 'dart:typed_data';

import 'package:gwent_net/gwent_net.dart';
import 'package:gwent_net/testing.dart';
import 'package:test/test.dart';

void main() {
  Uint8List bytes(int value) => Uint8List.fromList([value]);

  test('транспорт в памяти доставляет кадры по порядку и закрывается с обеих сторон', () async {
    final (a, b) = InMemoryTransport.pair();
    final received = <int>[];
    var done = false;
    b.incoming.listen((frame) => received.add(frame.single), onDone: () => done = true);
    final frame = bytes(1);
    a
      ..send(frame)
      ..send(bytes(2));
    frame[0] = 9;
    await a.close();
    a.send(bytes(3));
    await Future<void>.delayed(Duration.zero);
    expect(received, [1, 2], reason: 'кадр копируется, после закрытия ничего не уходит');
    expect(done, isTrue);
  });

  test('неполадки воспроизводятся по сиду и сохраняют порядок кадров', () async {
    Future<List<int>> run(int seed) async {
      final scheduler = FakeScheduler();
      final (a, b) = InMemoryTransport.pair();
      final faulty = FaultyTransport(
        a,
        scheduler: scheduler,
        faults: const Faults(drop: 0.3, duplicate: 0.3, maxDelay: Duration(milliseconds: 50)),
        seed: seed,
      );
      final received = <int>[];
      b.incoming.listen((frame) => received.add(frame.single));
      for (var i = 0; i < 50; i++) {
        faulty.send(bytes(i));
      }
      await scheduler.elapse(const Duration(seconds: 10));
      return received;
    }

    final first = await run(1);
    expect(await run(1), first);
    expect(await run(2), isNot(first));
    expect(first.length, inInclusiveRange(20, 70));
    for (var i = 1; i < first.length; i++) {
      expect(first[i], greaterThanOrEqualTo(first[i - 1]), reason: 'порядок сохранён');
    }
  });

  test('обрыв закрывает обе стороны', () async {
    final scheduler = FakeScheduler();
    final (a, b) = InMemoryTransport.pair();
    final faulty = FaultyTransport(a, scheduler: scheduler);
    var nearDone = false;
    var farDone = false;
    faulty.incoming.listen(null, onDone: () => nearDone = true);
    b.incoming.listen(null, onDone: () => farDone = true);
    await faulty.cut();
    await scheduler.flush();
    expect([nearDone, farDone], [true, true]);
  });

  test('управляемое время вызывает таймеры по порядку', () async {
    final scheduler = FakeScheduler();
    final calls = <String>[];
    final periodic = scheduler.periodic(const Duration(seconds: 3), () => calls.add('ping ${scheduler.now.inSeconds}'));
    scheduler
      ..timer(const Duration(seconds: 4), () => calls.add('once'))
      ..timer(const Duration(seconds: 20), () => calls.add('never')).cancel();
    await scheduler.elapse(const Duration(seconds: 7));
    periodic.cancel();
    await scheduler.elapse(const Duration(seconds: 30));
    expect(calls, ['ping 3', 'once', 'ping 6']);
    expect(scheduler.now, const Duration(seconds: 37));
  });
}
