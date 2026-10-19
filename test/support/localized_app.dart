import 'package:flutter/material.dart';
import 'package:gwent/src/app/theme/app_theme.dart';
import 'package:gwent/src/core/l10n/l10n.dart';

/// Оборачивает [child] в приложение с темой и русскими строками интерфейса.
Widget localizedApp(Widget child) => MaterialApp(
  theme: AppTheme.dark(),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  locale: const Locale('ru'),
  home: Scaffold(body: child),
);

/// Оборачивает экран маршрута так же, как `go_router`: прямо в `home`, без `Scaffold`.
///
/// Так тест видит, что экран сам даёт себе `Material`, а не берёт его у обёртки. Обычные экраны проверяют этим вместе
/// с `expectNoFallbackTextStyle`; [localizedApp] подходит для компонентов, которым экран вокруг не нужен.
Widget localizedScreen(Widget screen) => MaterialApp(
  theme: AppTheme.dark(),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  locale: const Locale('ru'),
  home: screen,
);
