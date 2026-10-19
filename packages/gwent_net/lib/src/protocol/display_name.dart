import 'dart:convert';

/// Предел длины имени игрока в байтах UTF-8.
const int maxDisplayNameBytes = 64;

/// Приводит имя, пришедшее от собеседника, к безопасному для показа и хранения виду.
///
/// Убирает управляющие знаки и невидимые знаки (нулевой ширины, направления письма: ими можно перевернуть подпись
/// или подделать чужое имя), обрезает пробелы по краям и длину до [maxDisplayNameBytes]. Имя может оказаться
/// пустым: подставить вместо него надпись должен экран.
String cleanDisplayName(String raw) {
  final visible = String.fromCharCodes(raw.runes.where((rune) => !_isHidden(rune)));
  return truncateUtf8(visible.trim(), maxDisplayNameBytes).trim();
}

/// [text], обрезанный по целым символам так, чтобы в UTF-8 занимать не больше [maxBytes] байт.
String truncateUtf8(String text, int maxBytes) {
  final buffer = StringBuffer();
  var bytes = 0;
  for (final rune in text.runes) {
    final char = String.fromCharCode(rune);
    bytes += utf8.encode(char).length;
    if (bytes > maxBytes) break;
    buffer.write(char);
  }
  return buffer.toString();
}

bool _isHidden(int rune) =>
    rune < 0x20 ||
    (rune >= 0x7f && rune < 0xa0) ||
    // U+200D (соединитель) оставлен: без него рассыпаются составные эмодзи.
    (rune >= 0x200b && rune <= 0x200f && rune != 0x200d) ||
    (rune >= 0x2028 && rune <= 0x202e) ||
    (rune >= 0x2060 && rune <= 0x2069) ||
    rune == 0x061c ||
    rune == 0x180e ||
    rune == 0x115f ||
    rune == 0x1160 ||
    rune == 0x3164 ||
    rune == 0x2800 ||
    rune == 0xfeff ||
    (rune >= 0xfff9 && rune <= 0xfffb) ||
    (rune >= 0xe0000 && rune <= 0xe007f);
