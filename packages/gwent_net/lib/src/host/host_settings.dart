import 'package:gwent_engine/gwent_engine.dart';
import 'package:gwent_net/src/protocol/ruleset.dart';

/// Настройки хоста партии.
final class HostSettings extends Value {
  const HostSettings({
    required this.ruleset,
    this.reconnectGrace = const Duration(minutes: 2),
    this.linkTimeout = const Duration(seconds: 9),
  });

  /// Набор правил хоста: гость с другим набором не подключится.
  final Ruleset ruleset;

  /// Сколько ждать отключившегося игрока (раздел 5 сетевой спецификации). Потом партия заканчивается
  /// его сдачей, а в лобби место освобождается.
  final Duration reconnectGrace;

  /// Сколько клиент может молчать, пока соединение считается живым. Клиент шлёт `ping` чаще.
  final Duration linkTimeout;

  @override
  List<Object?> get props => [ruleset, reconnectGrace, linkTimeout];
}
