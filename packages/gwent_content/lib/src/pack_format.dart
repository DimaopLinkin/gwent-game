/// Версия формата пакета контента (`format_version` в `manifest.json`).
///
/// Пакет с другой версией формата приложение не читает. Любое изменение формата, даже новое необязательное поле,
/// повышает версию: парсер отклоняет неизвестные поля.
const int packFormatVersion = 2;

/// Язык строк, который есть в каждом пакете и служит запасным.
const String fallbackLocale = 'ru';

/// Имя файла манифеста в папке пакета.
const String manifestFileName = 'manifest.json';

/// Имя файла с таблицами правил. Его канонический хеш это `content_hash` пакета.
const String rulesFileName = 'pack.json';

/// Имя файла строк для языка [locale], например `strings.ru.json`.
String stringsFileName(String locale) => 'strings.$locale.json';

/// Имя файла каталога кампании. Необязателен: пакет без него просто не показывает кампанию.
const String campaignFileName = 'campaign.json';

/// Версия формата каталога кампании (`format_version` в `campaign.json`).
const int campaignFormatVersion = 1;

/// Префикс ключей строк каталога кампании. Эти строки лежат в `strings.<язык>.json` рядом с остальными,
/// но нужны каталогу, а не таблицам правил.
const String campaignStringPrefix = 'campaign.';
