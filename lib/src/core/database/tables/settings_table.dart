import 'package:drift/drift.dart';

/// Настройки игрока как пары «ключ — значение».
///
/// Новая настройка не требует миграции схемы: отсутствующий ключ означает значение по умолчанию.
/// Ключи и разбор значений знает только репозиторий настроек.
@DataClassName('SettingRow')
class Settings extends Table {
  /// Ключ настройки.
  TextColumn get key => text()();

  /// Значение настройки в виде строки.
  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}
