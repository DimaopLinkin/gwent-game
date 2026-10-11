import 'dart:convert';

import 'package:gwent_content/gwent_content.dart';
import 'package:test/test.dart';

void main() {
  test('ключи отсортированы на всех уровнях, пробелов нет', () {
    expect(
      canonicalJson({
        'b': 1,
        'a': {
          'd': [3, 2],
          'c': null,
        },
      }),
      '{"a":{"c":null,"d":[3,2]},"b":1}',
    );
  });

  test('одинаковые по смыслу данные дают одинаковую строку', () {
    final pretty = const JsonEncoder.withIndent('  ').convert({'y': true, 'x': 'текст'});
    expect(canonicalJson(jsonDecode(pretty)), canonicalJson({'x': 'текст', 'y': true}));
  });

  test('строки экранируются как в jsonEncode, кириллица остаётся как есть', () {
    expect(canonicalJson('кавычка " и\nперевод'), r'"кавычка \" и\nперевод"');
  });

  test('дробные числа и чужие типы не канонизируются, ошибка указывает путь', () {
    expect(
      () => canonicalJson({
        'a': [1, 2.5],
      }),
      throwsA(isA<CanonicalJsonException>().having((e) => e.path, 'path', r'$.a[1]')),
    );
    expect(() => canonicalJson(DateTime(2026)), throwsA(isA<CanonicalJsonException>()));
  });

  test('хеш содержимого это sha256 в hex с префиксом', () {
    expect(
      contentHashOf(utf8.encode('abc')),
      'sha256:ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
    );
  });
}
