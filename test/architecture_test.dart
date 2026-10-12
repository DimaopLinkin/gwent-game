import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:flutter_test/flutter_test.dart';

/// Слои приложения и направление зависимостей из CLAUDE.md («Архитектура»).
///
/// Слой файла определяется по пути в `lib/`. Файлы разбираются парсером Dart, поэтому комментарии и строки
/// не дают ложных срабатываний.
void main() {
  final files = [for (final file in _dartFiles('lib')) _SourceFile.parse(file)];

  test('каждый файл lib/ лежит в известном слое', () {
    expect([
      for (final file in files)
        if (file.layer == null) file.path,
    ], isEmpty);
  });

  for (final layer in _Layer.values) {
    test('${layer.name} зависит только от разрешённых слоёв и пакетов', () {
      final violations = <String>[];
      for (final file in files.where((file) => file.layer == layer)) {
        for (final uri in file.imports) {
          final reason = layer.violation(uri);
          if (reason != null) violations.add('${file.path}: $uri ($reason)');
        }
      }
      expect(violations, isEmpty);
    });
  }
}

enum _Layer {
  domain,
  application,
  data,
  presentation,

  /// Точка сборки и навигация: связывает все слои.
  app
  ;

  /// Слои приложения, от которых может зависеть этот.
  Set<_Layer> get allowedLayers => switch (this) {
    domain => {domain},
    application => {domain, application},
    data => {domain, data},
    presentation => {domain, application, presentation},
    app => _Layer.values.toSet(),
  };

  /// Причина, по которой слою нельзя импортировать [uri], или `null`.
  String? violation(String uri) {
    if (uri.startsWith('package:gwent/')) {
      final target = _layerOf(uri.substring('package:gwent/'.length));
      if (target == null) return 'файл вне слоёв';
      return allowedLayers.contains(target) ? null : 'слой ${target.name}';
    }
    final package = _packageOf(uri);
    return switch (this) {
      domain || application =>
        uri.startsWith('dart:')
            ? (_pureDartLibraries.contains(uri) ? null : 'платформенная библиотека')
            : (_pureDartPackages.contains(package) ? null : 'пакет не из чистого Dart'),
      presentation => _storagePackages.contains(package) || uri == 'dart:io' ? 'хранилище или ввод-вывод' : null,
      data || app => null,
    };
  }
}

/// Библиотеки Dart SDK без Flutter, ввода-вывода и платформы.
const Set<String> _pureDartLibraries = {
  'dart:async',
  'dart:collection',
  'dart:convert',
  'dart:core',
  'dart:math',
  'dart:typed_data',
};

/// Пакеты, которые разрешены домену и сценариям (CLAUDE.md, таблица слоёв).
const Set<String> _pureDartPackages = {'collection', 'meta', 'gwent_ai', 'gwent_content', 'gwent_engine'};

/// Пакеты хранилища: экраны обращаются к данным только через сценарии.
const Set<String> _storagePackages = {'drift', 'drift_flutter', 'path_provider', 'sqlite3', 'uuid'};

_Layer? _layerOf(String libPath) {
  if (libPath == 'main.dart' || libPath.startsWith('src/app/')) return _Layer.app;
  const core = {
    'src/core/domain/': _Layer.domain,
    'src/core/data/': _Layer.data,
    'src/core/database/': _Layer.data,
    'src/core/l10n/': _Layer.presentation,
    'src/core/presentation/': _Layer.presentation,
  };
  for (final MapEntry(key: prefix, value: layer) in core.entries) {
    if (libPath.startsWith(prefix)) return layer;
  }
  final feature = RegExp('^src/features/[a-z_]+/([a-z]+)/').firstMatch(libPath);
  return _Layer.values.where((layer) => layer != _Layer.app && layer.name == feature?.group(1)).firstOrNull;
}

String? _packageOf(String uri) => uri.startsWith('package:') ? uri.substring(8).split('/').first : null;

final class _SourceFile {
  _SourceFile(this.path, this.layer, this.imports);

  factory _SourceFile.parse(File file) {
    final path = file.path.replaceAll(r'\', '/');
    final unit = parseString(content: file.readAsStringSync(), throwIfDiagnostics: false).unit;
    return _SourceFile(path, _layerOf(path.substring('lib/'.length)), _directiveUris(unit).toList());
  }

  final String path;
  final _Layer? layer;
  final List<String> imports;
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
