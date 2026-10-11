import 'package:flutter/widgets.dart';
import 'package:gwent/src/core/l10n/generated/app_localizations.dart';

export 'package:gwent/src/core/l10n/generated/app_localizations.dart';

/// Короткий доступ к строкам интерфейса: `context.l10n.appTitle`.
extension AppLocalizationsContext on BuildContext {
  /// Строки текущей локали.
  AppLocalizations get l10n => AppLocalizations.of(this);
}
