import 'package:meta/meta.dart';

/// Состояние главного меню.
@immutable
sealed class MenuState {
  const MenuState();
}

/// Идёт заставка: загружаются данные карт.
final class MenuLoading extends MenuState {
  /// Создаёт состояние.
  const MenuLoading();
}

/// Меню готово к показу.
final class MenuReady extends MenuState {
  /// Создаёт состояние.
  const MenuReady({
    this.appVersion,
    this.packVersion,
    required this.contentAvailable,
    required this.hasDeck,
    this.firstMatchPassed = true,
  });

  /// Версия приложения; `null`, если узнать её не удалось.
  final String? appVersion;

  /// Версия набора карт; `null`, если набор не загружен.
  final int? packVersion;

  /// Набор карт загружен и проверен.
  final bool contentAvailable;

  /// У игрока есть хотя бы одна колода.
  final bool hasDeck;

  /// Игрок прошёл «Первую партию»: пока нет, «Обучение» в меню помечено «Новое».
  final bool firstMatchPassed;

  /// Можно начинать партию: есть набор карт и колода.
  bool get canPlay => contentAvailable && hasDeck;

  @override
  bool operator ==(Object other) =>
      other is MenuReady &&
      other.appVersion == appVersion &&
      other.packVersion == packVersion &&
      other.contentAvailable == contentAvailable &&
      other.hasDeck == hasDeck &&
      other.firstMatchPassed == firstMatchPassed;

  @override
  int get hashCode => Object.hash(appVersion, packVersion, contentAvailable, hasDeck, firstMatchPassed);
}
