import 'package:flutter/services.dart';

/// Прячет строку состояния и системную навигацию: игра занимает весь экран.
///
/// Панели выходят по смахиванию от края и сами убираются (`immersiveSticky`). Вырез и жест «домой» остаются в
/// безопасных зонах, поэтому содержимое экранов лежит в `SafeArea`, а фон идёт под ней на весь экран. На iOS Flutter
/// прячет только строку состояния: индикатор «домой» остаётся, и фон под ним такой же, как у экрана.
Future<void> hideSystemOverlays() => SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
