import 'package:flutter/painting.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_colors.dart';

/// Типографика дизайн-системы (макет, раздел «Типографика», `GwentText`).
///
/// Два шрифта под OFL 1.1 с кириллицей лежат в `assets/fonts/`: Cormorant SC (капитель) для заголовков, кнопок
/// и баннеров и Alegreya для текста и всех цифр. В цифрах Alegreya по умолчанию старостильные, поэтому стили
/// с числами включают `lnum` и `tnum`. Межстрочный интервал задан как в макете: кегль/строка.
abstract final class GwentText {
  /// Семейство заголовков.
  static const String cormorant = 'Cormorant SC';

  /// Семейство текста и цифр.
  static const String alegreya = 'Alegreya';

  /// Ровные цифры одной ширины: сила и счёт не прыгают при смене значения.
  static const List<FontFeature> numbers = [FontFeature.liningFigures(), FontFeature.tabularFigures()];

  /// Крупный заголовок: Cormorant SC 600, 36/40, +2 %.
  static const TextStyle display = TextStyle(
    fontFamily: cormorant,
    fontWeight: FontWeight.w600,
    fontSize: 36,
    height: 40 / 36,
    letterSpacing: 36 * 0.02,
    color: GwentColors.textPrimary,
  );

  /// Заголовок: Cormorant SC 600, 24/28.
  static const TextStyle title = TextStyle(
    fontFamily: cormorant,
    fontWeight: FontWeight.w600,
    fontSize: 24,
    height: 28 / 24,
    color: GwentColors.textPrimary,
  );

  /// Надпись на кнопке: Cormorant SC 700, 18/20, +6 %.
  static const TextStyle label = TextStyle(
    fontFamily: cormorant,
    fontWeight: FontWeight.w700,
    fontSize: 18,
    height: 20 / 18,
    letterSpacing: 18 * 0.06,
    color: GwentColors.textPrimary,
  );

  /// Основной текст: Alegreya 400, 16/22.
  static const TextStyle body = TextStyle(
    fontFamily: alegreya,
    fontWeight: FontWeight.w400,
    fontSize: 16,
    height: 22 / 16,
    color: GwentColors.textPrimary,
  );

  /// Подпись: Alegreya 500, 13/16.
  static const TextStyle caption = TextStyle(
    fontFamily: alegreya,
    fontWeight: FontWeight.w500,
    fontSize: 13,
    height: 16 / 13,
    color: GwentColors.textSecondary,
  );

  /// Сила на карте: Alegreya 800, 12–14 pt. Кегль медальона карты задаёт размер карты.
  static const TextStyle powerCard = TextStyle(
    fontFamily: alegreya,
    fontWeight: FontWeight.w800,
    fontSize: 14,
    height: 1,
    fontFeatures: numbers,
    color: GwentColors.textPrimary,
  );

  /// Сила ряда: Alegreya 800, 16/16.
  static const TextStyle scoreRow = TextStyle(
    fontFamily: alegreya,
    fontWeight: FontWeight.w800,
    fontSize: 16,
    height: 1,
    fontFeatures: numbers,
    color: GwentColors.textPrimary,
  );

  /// Общий счёт: Alegreya 900, 20–24 pt.
  static const TextStyle scoreTotal = TextStyle(
    fontFamily: alegreya,
    fontWeight: FontWeight.w900,
    fontSize: 24,
    height: 1,
    fontFeatures: numbers,
    color: GwentColors.textPrimary,
  );
}
