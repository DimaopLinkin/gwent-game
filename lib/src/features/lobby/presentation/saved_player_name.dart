import 'package:gwent/src/features/settings/application/watch_settings.dart';

/// Имя игрока из настроек; `null`, если он его не задал или настройки не прочитались ([onError] получает причину).
Future<String?> savedPlayerName(WatchSettings watchSettings, {void Function(Object, StackTrace)? onError}) async {
  try {
    final name = (await watchSettings().first).playerName?.trim();
    return name == null || name.isEmpty ? null : name;
  } on Object catch (error, stackTrace) {
    onError?.call(error, stackTrace);
    return null;
  }
}
