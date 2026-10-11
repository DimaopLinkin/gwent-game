import 'package:gwent_content/gwent_content.dart';
import 'package:test/test.dart';

void main() {
  test('версия формата пакета положительна', () {
    expect(packFormatVersion, greaterThan(0));
  });

  test('запасной язык строк русский', () {
    expect(fallbackLocale, 'ru');
  });
}
