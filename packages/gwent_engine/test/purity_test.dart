import 'dart:io';

import 'package:test/test.dart';

/// Движок обязан оставаться чистым Dart: его запускают тесты без устройства, хост сетевой партии и сервер.
final _forbidden = <String, RegExp>{
  'Flutter': RegExp(r'''import\s+['"]package:flutter'''),
  'dart:io': RegExp(r'''import\s+['"]dart:io['"]'''),
  'dart:ui': RegExp(r'''import\s+['"]dart:ui['"]'''),
  'DateTime.now()': RegExp(r'DateTime\.now\('),
  'Random() без сида': RegExp(r'Random(\.secure)?\(\s*\)'),
};

void main() {
  test('lib/ не использует Flutter, ввод-вывод, текущее время и случайность без сида', () {
    final violations = <String>[];
    final files = Directory('lib').listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'));
    for (final file in files) {
      // Комментарии не проверяются: в документации эти слова встречаются законно.
      final source = file.readAsLinesSync().where((line) => !line.trimLeft().startsWith('//')).join('\n');
      _forbidden.forEach((what, pattern) {
        if (pattern.hasMatch(source)) violations.add('${file.path}: $what');
      });
    }
    expect(violations, isEmpty);
  });
}
