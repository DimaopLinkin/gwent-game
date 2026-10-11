import 'package:flutter/material.dart';

/// Тема приложения до макетов: тёмная, в тонах стола Гвинта.
abstract final class AppTheme {
  /// Тёмная тема.
  static ThemeData dark() => ThemeData(
    colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF8C6A3F), brightness: Brightness.dark),
  );
}
