import 'package:gwent_engine/gwent_engine.dart';
import 'package:test/test.dart';

void main() {
  test('версия движка положительна', () {
    expect(engineVersion, greaterThan(0));
  });

  test('эффекты пока не реализованы', () {
    expect(knownEffects, isEmpty);
  });
}
