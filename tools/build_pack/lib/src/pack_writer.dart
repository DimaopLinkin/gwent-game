import 'dart:io';

final RegExp _packFile = RegExp(r'^(manifest|pack|strings\.[a-z]{2,3})\.json$');

/// Папку пакета нельзя перезаписать: в ней лежит что-то, кроме файлов пакета.
final class PackOutputException implements Exception {
  /// Создаёт исключение для папки [path] с причиной [message].
  const PackOutputException(this.path, this.message);

  /// Папка пакета.
  final String path;

  /// Причина.
  final String message;

  @override
  String toString() => 'PackOutputException($path): $message';
}

/// Записывает файлы пакета [files] (путь → байты) в папку [out].
///
/// Старые файлы пакета (`manifest.json`, `pack.json`, `strings.<язык>.json`) удаляются. Если в папке есть
/// что-то другое, ничего не трогается и бросается [PackOutputException]: так `--out` с опечаткой не сотрёт
/// чужие файлы.
void writePackFiles(Directory out, Map<String, List<int>> files) {
  if (out.existsSync()) {
    final entries = out.listSync();
    final foreign = [
      for (final entry in entries)
        if (entry is! File || !_packFile.hasMatch(entry.uri.pathSegments.last)) entry.path,
    ];
    if (foreign.isNotEmpty) {
      throw PackOutputException(out.path, 'в папке есть не файлы пакета: ${foreign.join(', ')}');
    }
    for (final entry in entries) {
      entry.deleteSync();
    }
  } else {
    out.createSync(recursive: true);
  }
  for (final MapEntry(key: path, value: bytes) in files.entries) {
    File('${out.path}/$path').writeAsBytesSync(bytes);
  }
}
