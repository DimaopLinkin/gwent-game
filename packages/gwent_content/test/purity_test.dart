import 'dart:io';

import 'package:test/test.dart';

/// Пакет контента работает в приложении, в CLI-инструментах и у валидатора, поэтому не зависит от Flutter
/// и не работает с файлами: данные приходят ему строками или байтами.
final _forbidden = <String, RegExp>{
  'Flutter': RegExp(r'''^\s*(import|export)\b.*['"]package:flutter''', multiLine: true),
  'dart:io': RegExp(r'''^\s*(import|export)\b.*['"]dart:io['"]''', multiLine: true),
  'dart:ui': RegExp(r'''^\s*(import|export)\b.*['"]dart:ui['"]''', multiLine: true),
};

/// Убирает комментарии, чтобы слова из документации не считались нарушением.
String _withoutComments(String source) =>
    source.replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '').replaceAll(RegExp(r'//.*$', multiLine: true), '');

void main() {
  test('lib/ не использует Flutter и ввод-вывод', () {
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
