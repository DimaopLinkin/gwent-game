import 'package:flutter_test/flutter_test.dart';
import 'package:gwent/src/features/sound/data/recent_slots.dart';

void main() {
  test('пока места хватает, ничего не вытесняется', () {
    final slots = RecentSlots<String, int>(2);
    expect(slots.put('a', 1), isNull);
    expect(slots.put('b', 2), isNull);
    expect(slots.length, 2);
  });

  test('при переполнении уходит то, чем дольше всего не пользовались', () {
    final slots = RecentSlots<String, int>(2)
      ..put('a', 1)
      ..put('b', 2);
    expect(slots.use('a'), 1, reason: 'теперь «b» самый старый');
    final evicted = slots.put('c', 3);
    expect(evicted?.key, 'b');
    expect(evicted?.value, 2);
    expect(slots.use('b'), isNull);
    expect(slots.use('a'), 1);
    expect(slots.use('c'), 3);
  });

  test('повторная запись того же ключа заменяет значение и возвращает прежнее, чтобы его можно было закрыть', () {
    final slots = RecentSlots<String, int>(2)
      ..put('a', 1)
      ..put('b', 2);
    final replaced = slots.put('a', 10);
    expect(replaced?.key, 'a');
    expect(replaced?.value, 1);
    expect(slots.use('a'), 10);
    expect(slots.length, 2);
  });

  test('при вместимости 1 новое значение вытесняет единственное прежнее', () {
    final slots = RecentSlots<String, int>(1)..put('a', 1);
    expect(slots.put('b', 2)?.key, 'a');
    expect(slots.use('b'), 2);
  });

  test('обращение к отсутствующему ключу порядок не меняет', () {
    final slots = RecentSlots<String, int>(2)
      ..put('a', 1)
      ..put('b', 2);
    expect(slots.use('z'), isNull);
    expect(slots.put('c', 3)?.key, 'a');
  });

  test('remove убирает значение только если по ключу лежит именно оно', () {
    final slots = RecentSlots<String, Object>(2);
    final first = Object();
    final second = Object();
    slots.put('a', first);
    slots.remove('a', second);
    expect(slots.use('a'), same(first));
    slots.remove('a', first);
    expect(slots.use('a'), isNull);
  });
}
