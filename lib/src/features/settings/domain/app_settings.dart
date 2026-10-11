import 'package:meta/meta.dart';

/// Настройки игрока.
///
/// Новая настройка добавляется полем со значением по умолчанию: хранилище отдаёт его, пока игрок ничего не выбрал.
@immutable
final class AppSettings {
  /// Создаёт настройки.
  const AppSettings({this.playerName});

  /// Имя игрока, которое видит соперник в сетевой игре. `null`, пока игрок его не задал.
  final String? playerName;

  /// Копия с другим именем игрока; `null` стирает имя.
  AppSettings withPlayerName(String? playerName) => AppSettings(playerName: playerName);

  @override
  bool operator ==(Object other) => other is AppSettings && other.playerName == playerName;

  @override
  int get hashCode => playerName.hashCode;

  @override
  String toString() => 'AppSettings(playerName: $playerName)';
}
