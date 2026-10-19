import 'package:gwent_engine/gwent_engine.dart';
import 'package:gwent_net/src/protocol/ruleset.dart';

/// Настройки клиента партии.
final class ClientSettings extends Value {
  const ClientSettings({
    required this.ruleset,
    required this.playerName,
    required this.appVersion,
    this.pingInterval = const Duration(seconds: 3),
    this.linkTimeout = const Duration(seconds: 9),
    this.unstableAfter = const Duration(seconds: 5),
  });

  /// Набор правил клиента: хост с другим набором откажет.
  final Ruleset ruleset;
  final String playerName;
  final String appVersion;

  /// Как часто проверять связь (раздел 3.2 сетевой спецификации).
  final Duration pingInterval;

  /// Сколько хост может молчать, пока соединение считается живым. Хост отвечает на каждый `ping`.
  final Duration linkTimeout;

  /// Сколько хост может молчать, пока связь ещё не считается нестабильной: раньше [linkTimeout], чтобы игрок
  /// успел увидеть задержку до обрыва.
  final Duration unstableAfter;

  @override
  List<Object?> get props => [ruleset, playerName, appVersion, pingInterval, linkTimeout, unstableAfter];
}
