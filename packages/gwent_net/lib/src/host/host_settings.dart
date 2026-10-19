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
    this.maxUnacked = 500,
    this.resendCooldown = const Duration(seconds: 1),
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

  /// Сколько сообщений хоста игрок может не подтверждать. Честный клиент подтверждает всё в каждом своём кадре
  /// (проверка связи идёт каждые 3 с), а хранить очередь неподтверждённого без предела нельзя: каждый `resend`
  /// отправил бы её всю. При переполнении очередь сбрасывается, соединение закрывается, а вернувшийся игрок
  /// начинает со снимка.
  final int maxUnacked;

  /// Как часто хост отвечает на `resend` одного игрока: чаще просьбы пропускаются. Одна просьба на каждый
  /// обрыв нужна честному клиенту, а повторами её можно использовать как усилитель нагрузки.
  final Duration resendCooldown;

  @override
  List<Object?> get props => [
    ruleset,
    reconnectGrace,
    linkTimeout,
    startDelay,
    unstableAfter,
    maxUnacked,
    resendCooldown,
  ];
}
