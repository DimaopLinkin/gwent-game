import 'package:meta/meta.dart';

/// Код комнаты игры через интернет: шесть символов, по которым гость находит хоста (ADR 0025).
///
/// Алфавит без похожих знаков (нет 0, 1, I, O) совпадает с серверным. Игрок может вводить код в любом регистре,
/// с пробелами и дефисами: [tryParse] приводит ввод к виду, который принимает сервер, и не пускает к серверу
/// заведомо неверный код (каждый неверный код тратит лимит попыток игрока).
@immutable
final class RoomCode {
  const RoomCode._(this.value);

  /// Символы кода.
  static const String alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  /// Длина кода.
  static const int length = 6;

  static final RegExp _separators = RegExp(r'[\s-]');

  /// Код из ввода игрока или `null`, если ввод не код: не тот алфавит или не та длина.
  static RoomCode? tryParse(String input) {
    final value = input.replaceAll(_separators, '').toUpperCase();
    if (value.length != length || value.split('').any((char) => !alphabet.contains(char))) return null;
    return RoomCode._(value);
  }

  /// Код для хранения и обмена с сервером: заглавные буквы и цифры без разделителей.
  final String value;

  /// Код для показа игроку: `ABC-DEF`.
  String get formatted => '${value.substring(0, length ~/ 2)}-${value.substring(length ~/ 2)}';

  @override
  bool operator ==(Object other) => other is RoomCode && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'RoomCode($value)';
}
