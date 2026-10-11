import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:test/test.dart';

/// Сетевой слой обязан оставаться чистым Dart: тот же код запустят хост на телефоне и сервер.
///
/// Файлы разбираются парсером Dart, поэтому комментарии и строки не дают ложных срабатываний и пропусков.
void main() {
  test('lib/ не использует Flutter, ввод-вывод, текущее время и случайность без сида', () {
    // Стойкая случайность нужна хосту для токенов и сида партии и живёт только в SecureEntropy.
    const secureEntropy = 'lib/src/entropy/secure_entropy.dart';
    final violations = <String>[];
    for (final file in _dartFiles('lib')) {
      final unit = parseString(content: file.readAsStringSync(), throwIfDiagnostics: false).unit;
      for (final uri in _directiveUris(unit)) {
        if (uri.startsWith('package:flutter/') || uri == 'dart:io' || uri == 'dart:ui') {
          violations.add('${file.path}: $uri');
        }
      }
      for (final call in _forbiddenCalls(unit)) {
        if (call == 'Random.secure' && file.path == secureEntropy) continue;
        violations.add('${file.path}: $call');
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

/// Текущее время и случайность без сида, включая tear-off (`DateTime.now`, `Random.new`).
Iterable<String> _forbiddenCalls(CompilationUnit unit) sync* {
  for (var token = unit.beginToken; !token.isEof; token = token.next!) {
    if (token.type != TokenType.IDENTIFIER) continue;
    final next = token.next!;
    final member = next.type == TokenType.PERIOD ? next.next!.lexeme : null;
    if (token.lexeme == 'DateTime' && (member == 'now' || member == 'timestamp')) {
      yield 'DateTime.$member';
    } else if (token.lexeme == 'Random') {
      if (member == 'new' || member == 'secure') {
        yield 'Random.$member';
      } else if (next.type == TokenType.OPEN_PAREN && next.next!.type == TokenType.CLOSE_PAREN) {
        yield 'Random() без сида';
      }
    }
  }
}
