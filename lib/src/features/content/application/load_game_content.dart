import 'package:gwent/src/features/content/domain/engine_content.dart';
import 'package:gwent/src/features/content/domain/game_content.dart';
import 'package:gwent_content/gwent_content.dart';

/// Сценарий: получить контент для партии и конструктора колод.
///
/// Загружает пакет из [ContentSource] с проверкой по всем уровням и переводит его в справочник движка.
/// Результат запоминается: пакет неизменяем, а загрузка и проверка занимают заметное время, поэтому экраны,
/// которым нужен контент, получают одну и ту же загрузку.
final class LoadGameContent {
  /// Создаёт сценарий над источником [source].
  LoadGameContent(this._source);

  final ContentSource _source;
  Future<GameContentResult>? _result;

  /// Контент или проблемы, из-за которых его нет.
  Future<GameContentResult> call() => _result ??= _load();

  Future<GameContentResult> _load() async =>
      switch (await ContentPackLoader(engine: engineCapabilities).load(_source)) {
        PackLoaded(:final pack) => mapContentToEngine(pack),
        PackRejected(:final issues) => GameContentRejected(issues),
      };
}
