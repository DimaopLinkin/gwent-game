/// Файл пакета в манифесте: путь, размер и SHA-256.
final class ManifestFile {
  /// Создаёт запись о файле.
  const ManifestFile({required this.path, required this.sha256, required this.size});

  /// Путь относительно папки пакета, например `pack.json`.
  final String path;

  /// SHA-256 содержимого, 64 символа hex в нижнем регистре.
  final String sha256;

  /// Размер в байтах.
  final int size;
}

/// Манифест пакета (`manifest.json`).
final class Manifest {
  /// Создаёт манифест.
  Manifest({
    required this.formatVersion,
    required this.packId,
    required this.packVersion,
    required this.minEngineVersion,
    required this.contentHash,
    required List<String> locales,
    required List<ManifestFile> files,
  }) : locales = List.unmodifiable(locales),
       files = List.unmodifiable(files);

  /// Версия формата пакета.
  final int formatVersion;

  /// Идентификатор набора, например `gwent-w3-base`.
  final String packId;

  /// Версия набора. Растёт монотонно: новая правка данных = новая версия.
  final int packVersion;

  /// Минимальная версия движка правил.
  final int minEngineVersion;

  /// `sha256:<hex>` канонического `pack.json`. Строки в хеш не входят. Используется в сетевом рукопожатии.
  final String contentHash;

  /// Языки строк пакета. Запасной язык есть всегда.
  final List<String> locales;

  /// Файлы пакета, кроме самого манифеста.
  final List<ManifestFile> files;
}
