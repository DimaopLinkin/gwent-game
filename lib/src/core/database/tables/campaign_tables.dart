import 'package:drift/drift.dart';

/// Карты и лидеры, открытые игроком в кампании (ADR 0033), и число открытых копий.
///
/// Свободная игра и сеть таблицу не читают: там доступны все карты пакета.
@DataClassName('OwnedCardRow')
class OwnedCardEntries extends Table {
  @override
  String get tableName => 'owned_cards';

  /// UUID карты или лидера из пакета контента.
  TextColumn get cardId => text()();

  /// Сколько копий открыто, больше нуля.
  IntColumn get copies => integer()();

  @override
  Set<Column<Object>> get primaryKey => {cardId};

  @override
  List<String> get customConstraints => ['CHECK (copies > 0)'];
}

/// Прогресс по узлам кампании (ADR 0033): сколько побед и когда получены награды.
///
/// Таблица заводится вместе с коллекцией, чтобы схема кампании менялась одной миграцией; сценарии кампании
/// начнут её читать и писать на следующем этапе.
@DataClassName('CampaignProgressRow')
class CampaignProgress extends Table {
  /// Идентификатор узла из каталога кампании. Не меняется никогда: узел нельзя переименовать или подменить другим.
  TextColumn get nodeId => text()();

  /// Сколько раз игрок выиграл узел; идёт в «Книгу карт».
  IntColumn get wins => integer()();

  /// Момент первой победы (UTC).
  DateTimeColumn get firstWinAt => dateTime()();

  /// Момент получения дополнительной награды за условие (UTC); `null`, пока она не получена.
  DateTimeColumn get bonusClaimedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {nodeId};
}
