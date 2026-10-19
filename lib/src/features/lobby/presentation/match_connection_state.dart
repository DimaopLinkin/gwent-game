import 'package:meta/meta.dart';

/// Связь в сетевой партии, как её видит экран: на связи ли соперник (для хоста) или хост (для гостя).
@immutable
final class MatchConnectionState {
  /// Создаёт состояние.
  const MatchConnectionState({
    required this.isHost,
    this.lost = false,
    this.left = Duration.zero,
    this.dismissed = false,
  });

  /// Этот телефон создал игру.
  final bool isHost;

  /// Связь потеряна: у хоста пропал гость, у гостя пропал хост.
  final bool lost;

  /// Сколько осталось ждать возвращения; потом партию заканчивает хост.
  final Duration left;

  /// Игрок закрыл окно обрыва кнопкой «Ждать»: ожидание идёт дальше, в углу остаётся таймер.
  final bool dismissed;

  /// Копия с заменёнными полями.
  MatchConnectionState copyWith({bool? lost, Duration? left, bool? dismissed}) => MatchConnectionState(
    isHost: isHost,
    lost: lost ?? this.lost,
    left: left ?? this.left,
    dismissed: dismissed ?? this.dismissed,
  );

  @override
  bool operator ==(Object other) =>
      other is MatchConnectionState &&
      other.isHost == isHost &&
      other.lost == lost &&
      other.left == left &&
      other.dismissed == dismissed;

  @override
  int get hashCode => Object.hash(isHost, lost, left, dismissed);
}
