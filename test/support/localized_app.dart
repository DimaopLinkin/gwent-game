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
