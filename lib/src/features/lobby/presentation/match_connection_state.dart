import 'package:meta/meta.dart';

/// Связь в сетевой партии, как её видит экран: на связи ли соперник (для хоста) или хост (для гостя).
@immutable
final class MatchConnectionState {
  /// Создаёт состояние.
  const MatchConnectionState({
    required this.isHost,
    this.lost = false,
    this.unstable = false,
    this.away = false,
    this.left = Duration.zero,
    this.dismissed = false,
  });

  /// Этот телефон создал игру.
  final bool isHost;

  /// Связь потеряна: у хоста пропал гость, у гостя пропал хост.
  final bool lost;

  /// Связь есть, но с задержками: собеседник молчит дольше обычного (ADR 0020).
  final bool unstable;

  /// Хост свернул приложение, пока связь жива: окно есть только у гостя (макет 9, экран 6c).
  final bool away;

  /// Сколько осталось ждать возвращения; потом партию заканчивает хост.
  final Duration left;

  /// Игрок закрыл окно кнопкой «Ждать»: ожидание идёт дальше, в углу остаётся плашка.
  final bool dismissed;

  /// Копия с заменёнными полями.
  MatchConnectionState copyWith({bool? lost, bool? unstable, bool? away, Duration? left, bool? dismissed}) =>
      MatchConnectionState(
        isHost: isHost,
        lost: lost ?? this.lost,
        unstable: unstable ?? this.unstable,
        away: away ?? this.away,
        left: left ?? this.left,
        dismissed: dismissed ?? this.dismissed,
      );

  @override
  bool operator ==(Object other) =>
      other is MatchConnectionState &&
      other.isHost == isHost &&
      other.lost == lost &&
      other.unstable == unstable &&
      other.away == away &&
      other.left == left &&
      other.dismissed == dismissed;

  @override
  int get hashCode => Object.hash(isHost, lost, unstable, away, left, dismissed);
}
