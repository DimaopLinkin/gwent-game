import 'dart:convert';

import 'package:gwent_content/src/codec/decode_result.dart';
import 'package:gwent_content/src/codec/manifest_codec.dart';
import 'package:gwent_content/src/loading/pack_load_result.dart';
import 'package:gwent_content/src/model/content_pack.dart';
import 'package:gwent_content/src/pack_format.dart';
import 'package:gwent_content/src/source/content_source.dart';
import 'package:gwent_content/src/validation/compatibility_check.dart';
import 'package:gwent_content/src/validation/content_validator.dart';
import 'package:gwent_content/src/validation/engine_capabilities.dart';
import 'package:gwent_content/src/validation/integrity_check.dart';
import 'package:gwent_content/src/validation/validation_issue.dart';

/// Загружает пакет из любого [ContentSource] и проверяет его по всем пяти уровням.
///
/// Порядок: версия формата и манифест, совместимость с движком, целостность файлов и `content_hash`, схема,
/// ссылки, инварианты, эффекты движка. На первом уровне с проблемами загрузка останавливается
/// и возвращает [PackRejected]; исключения наружу не выходят.
final class ContentPackLoader {
  /// Создаёт загрузчик для движка [engine].
  const ContentPackLoader({required this.engine});

  /// Что умеет движок приложения.
  final EngineCapabilities engine;

  /// Загружает и проверяет пакет из [source].
  Future<PackLoadResult> load(ContentSource source) async {
    try {
      return PackLoaded(await _load(source));
    } on _Rejection catch (rejection) {
      return PackRejected(rejection.issues);
    }
  }

  Future<ContentPack> _load(ContentSource source) async {
    final manifestJson = _parseJson(manifestFileName, await _read(source, manifestFileName));
    if (manifestJson is Map<String, Object?>) {
      _rejectIfAny([?checkFormatVersion(manifestJson[formatVersionField])]);
    }
    final manifest = _decoded(decodeManifest(manifestJson));
    _rejectIfAny(checkManifestCompatibility(manifest, engine));

    final bytes = <String, List<int>>{};
    final integrity = <ValidationIssue>[];
    for (final file in manifest.files) {
      final content = await _read(source, file.path);
      bytes[file.path] = content;
      integrity.addAll(checkFileIntegrity(file, content));
    }
    _rejectIfAny(integrity);

    final rulesJson = _parseJson(rulesFileName, bytes[rulesFileName]!);
    final stringsJson = {
      for (final locale in manifest.locales)
        locale: _parseJson(stringsFileName(locale), bytes[stringsFileName(locale)]!),
    };
    _rejectIfAny(checkContentHash(manifest, rulesJson));

    final content = _decoded(validateContent(rulesJson, stringsJson));
    _rejectIfAny(checkEffectCompatibility(content.rules, engine));
    return ContentPack(manifest: manifest, rules: content.rules, strings: content.strings);
  }

  static Future<List<int>> _read(ContentSource source, String path) async {
    try {
      return await source.readFile(path);
    } on ContentSourceException catch (e) {
      throw _Rejection([
        ValidationIssue(level: ValidationLevel.integrity, code: 'file_unavailable', path: path, message: e.message),
      ]);
    }
  }

  static Object? _parseJson(String path, List<int> bytes) {
    try {
      return jsonDecode(utf8.decode(bytes));
    } on FormatException catch (e) {
      throw _Rejection([
        ValidationIssue(level: ValidationLevel.schema, code: 'invalid_json', path: path, message: e.message),
      ]);
    }
  }

  static T _decoded<T>(DecodeResult<T> result) => switch (result) {
    Decoded(:final value) => value,
    DecodeFailed(:final issues) => throw _Rejection(issues),
  };

  static void _rejectIfAny(List<ValidationIssue> issues) {
    if (issues.isNotEmpty) throw _Rejection(issues);
  }
}

/// Внутренний сигнал остановки загрузки; наружу превращается в [PackRejected].
final class _Rejection implements Exception {
  const _Rejection(this.issues);

  final List<ValidationIssue> issues;
}
