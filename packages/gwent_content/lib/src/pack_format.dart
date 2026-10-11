/// Версия формата пакета контента (`format_version` в `manifest.json`).
///
/// Пакет с другой мажорной версией формата приложение не читает.
const int packFormatVersion = 1;

/// Язык строк, который есть в каждом пакете и служит запасным.
const String fallbackLocale = 'ru';
