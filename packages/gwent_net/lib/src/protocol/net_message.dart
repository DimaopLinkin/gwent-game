import 'package:gwent_engine/gwent_engine.dart';
import 'package:gwent_net/src/protocol/ruleset.dart';

/// Сообщение протокола. Ездит внутри конверта `Envelope`.
///
/// Три семейства: служебные сообщения соединения (без номера), сообщения клиента хосту и сообщения хоста
/// клиенту (с номером, доставляются по порядку и переотправляются после потерь).
sealed class NetMessage extends Value {
  const NetMessage();
}

/// Служебное сообщение соединения: без номера, не переотправляется.
sealed class ControlMessage extends NetMessage {
  const ControlMessage();
}

/// Клиент → хост: первое сообщение каждого соединения.
///
/// [resumeToken] передаётся при переподключении к уже занятому месту. Сколько сообщений хоста клиент уже
/// получил, говорит поле `ack` конверта.
final class Hello extends ControlMessage {
  const Hello({required this.ruleset, required this.playerName, required this.appVersion, this.resumeToken});

  final Ruleset ruleset;
  final String playerName;

  /// Версия приложения: для журнала и сообщений об ошибках, совместимость по ней не проверяется.
  final String appVersion;
  final String? resumeToken;

  @override
  List<Object?> get props => [ruleset, playerName, appVersion, resumeToken];
}

/// Хост → клиент: место в партии выдано или возвращено.
///
/// [next] — номер следующего сообщения хоста. Совпадает с `ack + 1` клиента, если хост дошлёт пропущенное,
/// и больше, если хост начнёт со снимка. Поле `ack` конверта говорит, сколько сообщений клиента хост принял.
final class Welcome extends ControlMessage {
  const Welcome({required this.seat, required this.matchId, required this.resumeToken, required this.next});

  final Seat seat;
  final String matchId;
  final String resumeToken;
  final int next;

  @override
  List<Object?> get props => [seat, matchId, resumeToken, next];
}

/// Почему хост не пустил клиента.
enum JoinRefusal {
  /// Другая версия протокола.
  protocolMismatch,

  /// Другие данные карт или другая версия движка.
  rulesetMismatch,

  /// Оба места заняты.
  matchFull,

  /// Токен переподключения не подходит к этой партии.
  unknownResumeToken,
}

/// Хост → клиент: подключение отклонено; хост закрывает соединение.
///
/// Формат не меняется между версиями протокола: [protocol] — версия хоста, чтобы клиент мог её показать.
final class JoinRejected extends ControlMessage {
  const JoinRejected(this.reason, {required this.protocol});

  final JoinRefusal reason;
  final int protocol;

  @override
  List<Object?> get props => [reason, protocol];
}

/// Клиент → хост: проверка связи. [sent] — номер последнего отправленного клиентом сообщения.
final class Ping extends ControlMessage {
  const Ping({required this.sent});

  final int sent;

  @override
  List<Object?> get props => [sent];
}

/// Хост → клиент: ответ на [Ping]. [sent] — номер последнего отправленного хостом сообщения.
final class Pong extends ControlMessage {
  const Pong({required this.sent});

  final int sent;

  @override
  List<Object?> get props => [sent];
}

/// Просьба переотправить все сообщения после `ack` конверта: получатель заметил пропуск.
final class ResendRequest extends ControlMessage {
  const ResendRequest();

  @override
  List<Object?> get props => const [];
}

/// Сообщение клиента хосту: с номером, доставляется по порядку.
sealed class ClientMessage extends NetMessage {
  const ClientMessage();
}

/// Колода игрока перед партией. Хост проверяет её правилами сборки.
final class DeckSubmission extends ClientMessage {
  const DeckSubmission(this.deck);

  final Deck deck;

  @override
  List<Object?> get props => [deck];
}

/// Намерение игрока. Место игрока хост берёт из соединения, а не из сообщения.
final class IntentMessage extends ClientMessage {
  const IntentMessage(this.intent);

  final Intent intent;

  @override
  List<Object?> get props => [intent];
}

/// Сообщение хоста клиенту: с номером, доставляется по порядку.
sealed class HostMessage extends NetMessage {
  const HostMessage();
}

/// Партия изменилась: события для этого игрока и его проекция после них.
///
/// События нужны интерфейсу для анимаций, проекция — единственный источник состояния у клиента.
final class MatchUpdate extends HostMessage {
  const MatchUpdate(this.events, this.view);

  /// События, уже пропущенные через `eventsFor` для этого игрока.
  final List<GameEvent> events;
  final PlayerView view;

  @override
  List<Object?> get props => [events, view];
}

/// Полная проекция без событий: после переподключения, когда пропущенное дослать нельзя.
final class MatchSnapshot extends HostMessage {
  const MatchSnapshot(this.view);

  final PlayerView view;

  @override
  List<Object?> get props => [view];
}

/// Почему хост не выполнил сообщение клиента.
enum RefusalCode {
  /// Колода не прошла правила сборки: подробности в [Refusal.reject].
  deckRejected,

  /// Колоду прислали после начала партии.
  matchStarted,

  /// Намерение прислали до начала партии.
  matchNotStarted,

  /// Соперник отключён, партия на паузе до его возвращения.
  matchPaused,

  /// Движок отклонил намерение: подробности в [Refusal.reject].
  intentRejected,
}

/// Хост → клиент: сообщение клиента с номером [replyTo] не выполнено.
///
/// Для клиента это рассинхрон интерфейса (кнопка нажата не вовремя), а не ошибка протокола.
final class Refusal extends HostMessage {
  const Refusal(this.code, {required this.replyTo, this.reject});

  final RefusalCode code;
  final int replyTo;
  final Reject? reject;

  @override
  List<Object?> get props => [code, replyTo, reject];
}

/// Хост → клиент: соперник подключился, отключился или вернулся.
final class OpponentPresence extends HostMessage {
  const OpponentPresence({required this.online});

  final bool online;

  @override
  List<Object?> get props => [online];
}
