/// Версия формата пакета контента (`format_version` в `manifest.json`).
///
/// Пакет с другой версией формата приложение не читает. Любое изменение формата, даже новое необязательное поле,
/// повышает версию: парсер отклоняет неизвестные поля.
const int packFormatVersion = 1;

/// Язык строк, который есть в каждом пакете и служит запасным.
const String fallbackLocale = 'ru';

/// Имя файла манифеста в папке пакета.
const String manifestFileName = 'manifest.json';

/// Имя файла с таблицами правил. Его канонический хеш это `content_hash` пакета.
const String rulesFileName = 'pack.json';

/// Имя файла строк для языка [locale], например `strings.ru.json`.
String stringsFileName(String locale) => 'strings.$locale.json';
