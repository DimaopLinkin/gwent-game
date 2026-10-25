import 'package:drift/drift.dart';

/// История сыгранных партий.
@DataClassName('MatchRecordRow')
class MatchRecords extends Table {
  /// Идентификатор записи (UUID).
  TextColumn get id => text()();

  /// Как шла партия: стабильный строковый код, его задаёт репозиторий истории партий.
  TextColumn get mode => text()();

  /// UUID фракции игрока.
  TextColumn get playerFactionId => text()();

  /// UUID фракции соперника.
  TextColumn get opponentFactionId => text()();

  /// Имя соперника, если известно.
  TextColumn get opponentName => text().nullable()();

  /// Итог для игрока: стабильный строковый код, его задаёт репозиторий истории партий.
  TextColumn get outcome => text()();

  /// Раунды, выигранные игроком.
  IntColumn get roundsWon => integer()();

  /// Раунды, выигранные соперником.
  IntColumn get roundsLost => integer()();

  /// Момент окончания партии.
  DateTimeColumn get finishedAt => dateTime()();

  /// У партии сохранён реплей (строка в `match_replays`); у партий, сыгранных до реплеев, его нет.
  BoolColumn get hasReplay => boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Реплеи сыгранных партий: запись, из которой партию можно показать заново. Одна строка на партию истории.
///
/// Запись лежит отдельно от сводки, чтобы список истории не читал её. Вид записи и версия формата позволяют
/// хранить разные записи (журнал ходов, кадры) и менять формат без новой схемы.
@DataClassName('MatchReplayRow')
class MatchReplays extends Table {
  /// Идентификатор партии в `match_records`.
  TextColumn get recordId => text()();

  /// Чьими глазами записана партия: `one` или `two` (место игрока этого устройства).
  TextColumn get perspective => text()();

  /// Вид записи: стабильный строковый код, его задаёт репозиторий истории партий.
  TextColumn get kind => text()();

  /// Версия формата [payload] для этого вида записи.
  IntColumn get formatVersion => integer()();

  /// Сама запись: текст JSON.
  TextColumn get payload => text()();

  @override
  Set<Column<Object>> get primaryKey => {recordId};
}
