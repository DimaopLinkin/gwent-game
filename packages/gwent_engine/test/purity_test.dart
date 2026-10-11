import 'dart:io';

import 'package:test/test.dart';

/// Движок обязан оставаться чистым Dart: его запускают тесты без устройства, хост сетевой партии и сервер.
final _forbidden = <String, RegExp>{
  'Flutter': RegExp(r'''^\s*(import|export)\b.*['"]package:flutter''', multiLine: true),
  'dart:io': RegExp(r'''^\s*(import|export)\b.*['"]dart:io['"]''', multiLine: true),
  'dart:ui': RegExp(r'''^\s*(import|export)\b.*['"]dart:ui['"]''', multiLine: true),
  'текущее время': RegExp(r'\bDateTime\.(now|timestamp)\('),
  'Random() без сида': RegExp(r'\bRandom(\.secure|\.new)?\(\s*\)'),
};

/// Убирает комментарии, чтобы слова из документации не считались нарушением.
String _withoutComments(String source) =>
    source.replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '').replaceAll(RegExp(r'//.*$', multiLine: true), '');

void main() {
  test('lib/ не использует Flutter, ввод-вывод, текущее время и случайность без сида', () {
    final violations = <String>[];
    final files = Directory('lib').listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'));
    for (final file in files) {
      final source = _withoutComments(file.readAsStringSync());
      _forbidden.forEach((what, pattern) {
        if (pattern.hasMatch(source)) violations.add('${file.path}: $what');
      });
    }
    expect(violations, isEmpty);
  });
}
