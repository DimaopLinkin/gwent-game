import 'package:gwent_engine/gwent_engine.dart';
import 'package:gwent_net/src/protocol/ruleset.dart';

/// Настройки хоста партии.
final class HostSettings extends Value {
  const HostSettings({
    required this.ruleset,
    this.reconnectGrace = const Duration(minutes: 2),
    this.linkTimeout = const Duration(seconds: 9),
    this.startDelay = Duration.zero,
    this.unstableAfter = const Duration(seconds: 5),
  });

  /// Набор правил хоста: гость с другим набором не подключится.
  final Ruleset ruleset;

  /// Сколько ждать отключившегося игрока (раздел 5 сетевой спецификации). Потом партия заканчивается
  /// его сдачей, а в лобби место освобождается.
  final Duration reconnectGrace;

  /// Сколько клиент может молчать, пока соединение считается живым. Клиент шлёт `ping` чаще.
  final Duration linkTimeout;

  /// Сколько ждать между готовностью обоих игроков и началом партии: за это время любой может отозвать колоду
  /// (ADR 0019). Ноль — партия начинается сразу, как только хост получил обе колоды.
  final Duration startDelay;

  /// Сколько игрок может молчать, пока связь с ним ещё не считается нестабильной: раньше [linkTimeout].
  final Duration unstableAfter;

  @override
  List<Object?> get props => [ruleset, reconnectGrace, linkTimeout, startDelay, unstableAfter];
}
