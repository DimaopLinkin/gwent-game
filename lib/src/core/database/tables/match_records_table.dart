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

  @override
  Set<Column<Object>> get primaryKey => {id};
}
