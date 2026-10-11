import 'dart:io';

import 'package:test/test.dart';

/// Пакет контента работает в приложении, в CLI-инструментах и у валидатора, поэтому не зависит от Flutter.
final _forbidden = <String, RegExp>{
  'Flutter': RegExp(r'''import\s+['"]package:flutter'''),
  'dart:ui': RegExp(r'''import\s+['"]dart:ui['"]'''),
};

void main() {
  test('lib/ не использует Flutter', () {
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
