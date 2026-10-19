import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:test/test.dart';

/// Пакет контента работает в приложении, в CLI-инструментах и у валидатора, поэтому не зависит от Flutter
/// и не работает с файлами: данные приходят ему строками или байтами.
///
/// Файлы разбираются парсером Dart, поэтому комментарии и строки не дают ложных срабатываний и пропусков.
void main() {
  test('lib/ не использует Flutter и ввод-вывод', () {
    final violations = <String>[];
    for (final file in _dartFiles('lib')) {
      final unit = parseString(content: file.readAsStringSync(), throwIfDiagnostics: false).unit;
      for (final uri in _directiveUris(unit)) {
        if (uri.startsWith('package:flutter/') || uri == 'dart:io' || uri == 'dart:ui') {
          violations.add('${file.path}: $uri');
        }
      }
    }
    expect(violations, isEmpty);
  });
}

Iterable<File> _dartFiles(String dir) =>
    Directory(dir).listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'));

/// URI всех import и export, включая условные варианты (`if (dart.library.io) '...'`).
Iterable<String> _directiveUris(CompilationUnit unit) sync* {
  for (final directive in unit.directives.whereType<NamespaceDirective>()) {
    final uri = directive.uri.stringValue;
    if (uri != null) yield uri;
    for (final configuration in directive.configurations) {
      final conditional = configuration.uri.stringValue;
      if (conditional != null) yield conditional;
    }
  }
}
