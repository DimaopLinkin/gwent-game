import 'package:drift/drift.dart';
import 'package:gwent/src/features/match_history/domain/match_record.dart';

/// История сыгранных партий.
@DataClassName('MatchRecordRow')
class MatchRecords extends Table {
  /// Идентификатор записи (UUID).
  TextColumn get id => text()();

  /// Как шла партия; хранится имя значения [MatchMode].
  TextColumn get mode => textEnum<MatchMode>()();

  /// UUID фракции игрока.
  TextColumn get playerFactionId => text()();

  /// UUID фракции соперника.
  TextColumn get opponentFactionId => text()();

  /// Имя соперника, если известно.
  TextColumn get opponentName => text().nullable()();

  /// Итог для игрока; хранится имя значения [MatchOutcome].
  TextColumn get outcome => textEnum<MatchOutcome>()();

  /// Раунды, выигранные игроком.
  IntColumn get roundsWon => integer()();

  /// Раунды, выигранные соперником.
  IntColumn get roundsLost => integer()();

  /// Момент окончания партии.
  DateTimeColumn get finishedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
