import 'package:flutter_test/flutter_test.dart';
import 'package:gwent_content/gwent_content.dart';
import 'package:gwent_engine/gwent_engine.dart';

void main() {
  test('приложение видит пакеты движка и контента', () {
    expect(engineVersion, greaterThan(0));
    expect(packFormatVersion, greaterThan(0));
  });
}
