/// Уровень проверки пакета. Порядок значений совпадает с порядком проверок при загрузке.
enum ValidationLevel {
  /// Файлы доступны, их размер и SHA-256 совпадают с манифестом, `content_hash` верен.
  integrity,

  /// Версия формата поддерживается, версия движка достаточна, все эффекты известны движку.
  compatibility,

  /// Обязательные поля, типы и допустимые значения.
  schema,

  /// Каждая ссылка указывает на запись нужной таблицы; идентификаторы и ключи уникальны; строки есть.
  references,

  /// Игровые инварианты: из каждой фракции можно собрать колоду, герои в одном экземпляре и т. п.
  invariants,
}

/// Одна найденная проблема пакета.
///
/// [code] стабилен и подходит для тестов и логов; [message] поясняет проблему человеку (это диагностика
/// для разработчика, а не строка интерфейса).
final class ValidationIssue {
  /// Создаёт проблему уровня [level] с кодом [code] по пути [path].
  const ValidationIssue({required this.level, required this.code, required this.path, required this.message});

  /// Уровень проверки, на котором найдена проблема.
  final ValidationLevel level;

  /// Машинный код проблемы, например `unknown_reference`.
  final String code;

  /// Где проблема: файл и JSON-путь, например `pack.json:$.squad_cards[3].zone_id`.
  final String path;

  /// Описание для человека.
  final String message;

  @override
  String toString() => '[${level.name}] $code $path: $message';
}
