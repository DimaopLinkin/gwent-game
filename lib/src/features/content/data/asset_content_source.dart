import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:gwent_content/gwent_content.dart';

/// Пакет контента из ассетов приложения: есть всегда, работает офлайн.
///
/// Пакет собирает `tools/scripts/setup.sh` из `docs/hand` в [basePackRoot]; `pubspec.yaml` регистрирует эту папку.
final class AssetContentSource implements ContentSource {
  /// Создаёт источник, который читает файлы пакета из папки [root] в [bundle].
  const AssetContentSource({required this.bundle, required this.root});

  /// Источник базового пакета `gwent-w3-base`.
  const AssetContentSource.basePack(this.bundle) : root = basePackRoot;

  /// Папка базового пакета в ассетах.
  static const String basePackRoot = 'assets/content/gwent-w3-base';

  /// Откуда читаются ассеты; в приложении это `rootBundle`.
  final AssetBundle bundle;

  /// Папка пакета внутри ассетов.
  final String root;

  @override
  Future<List<int>> readFile(String path) async {
    try {
      final data = await bundle.load('$root/$path');
      return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    } on FlutterError catch (e) {
      throw ContentSourceException(path, e.message);
    }
  }
}
