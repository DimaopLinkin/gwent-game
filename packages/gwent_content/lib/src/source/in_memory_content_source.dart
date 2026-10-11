import 'package:gwent_content/src/source/content_source.dart';

/// Пакет, файлы которого уже в памяти: только что собранный утилитой или полученный от соперника по матчу.
final class InMemoryContentSource implements ContentSource {
  /// Создаёт источник из файлов [files] (путь → байты).
  InMemoryContentSource(Map<String, List<int>> files) : _files = Map.unmodifiable(files);

  final Map<String, List<int>> _files;

  @override
  Future<List<int>> readFile(String path) async =>
      _files[path] ?? (throw ContentSourceException(path, 'файла нет в пакете'));
}
