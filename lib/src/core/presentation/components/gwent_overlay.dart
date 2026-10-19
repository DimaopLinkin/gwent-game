import 'package:flutter/material.dart';

/// Открывает [builder] полноэкранным оверлеем поверх текущего экрана и даёт ему прозрачный `Material`.
///
/// Маршрут `showGeneralDialog` сам `Material` не создаёт, а оверлей лежит вне экрана с `Scaffold` или `ScreenBackdrop`:
/// без `Material` весь текст получает отладочный стиль `MaterialApp` (жёлтое двойное подчёркивание), а `InkWell` и
/// `TextField` падают. Поэтому оверлеи, которые рисуют не `Dialog` и не `BottomSheet` (они `Material` дают сами),
/// открывают только так, а `showGeneralDialog` напрямую не вызывают. Появление и закрытие — плавное проявление.
Future<T?> showGwentOverlay<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  Color barrierColor = const Color(0x00000000),
  bool barrierDismissible = false,
  String? barrierLabel,
  Duration transitionDuration = const Duration(milliseconds: 200),
}) => showGeneralDialog<T>(
  context: context,
  barrierColor: barrierColor,
  barrierDismissible: barrierDismissible,
  barrierLabel: barrierLabel,
  transitionDuration: transitionDuration,
  pageBuilder: (context, _, _) => Material(
    type: MaterialType.transparency,
    child: Builder(builder: builder),
  ),
  transitionBuilder: (context, animation, _, child) => FadeTransition(opacity: animation, child: child),
);
