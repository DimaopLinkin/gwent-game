/// Откуда берутся файлы пакета: ассеты приложения, сервер, соперник по матчу.
///
/// Реализация только отдаёт байты; разбор и проверку делает загрузчик, поэтому все источники проверяются
/// одинаково.
abstract interface class ContentSource {
  /// Байты файла [path] относительно папки пакета, например `manifest.json`.
  ///
  /// Если файла нет или его не удалось прочитать, бросает [ContentSourceException].
  Future<List<int>> readFile(String path);
}

/// Источник не смог отдать файл пакета.
final class ContentSourceException implements Exception {
  /// Создаёт исключение для файла [path] с причиной [message].
  const ContentSourceException(this.path, this.message);

  /// Путь файла относительно папки пакета.
  final String path;

  /// Причина.
  final String message;

  @override
  String toString() => 'ContentSourceException($path): $message';
}
