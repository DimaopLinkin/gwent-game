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

  /// Версия приложения: справочно, совместимость проверяется по [ruleset] и версии протокола.
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

  /// Хост не пустил игрока или не ответил вовремя.
  declined,
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

/// Где игрок в лобби перед партией: макет «Два телефона», блок игрока (ADR 0019).
enum LobbyStage {
  /// Выбирает колоду из сохранённых.
  choosing,

  /// Собирает колоду в конструкторе.
  building,

  /// Колода выбрана, но игрок ещё не готов.
  chosen,

  /// Готов: колода отправлена хосту (`DeckSubmission`) и не отозвана.
  ready,
}

/// Состояние игрока в лобби до готовности: чем он занят и какого лидера выбрал.
///
/// Готовность не передаётся этим сообщением: «готов» значит, что хост получил колоду (`DeckSubmission`).
/// Сообщение с новым состоянием отменяет прежнюю готовность, как [DeckWithdrawal].
final class LobbyStatus extends ClientMessage {
  const LobbyStatus(this.stage, {this.leader}) : assert(stage != LobbyStage.ready, 'готовность — это колода хосту');

  final LobbyStage stage;

  /// Лидер выбранной колоды; лидера видно сопернику сразу: он не скрытая информация партии.
  final LeaderId? leader;

  @override
  List<Object?> get props => [stage, leader];
}

/// Игрок берёт колоду обратно (отмена готовности): отсчёт старта прерывается, колоду можно сменить.
final class DeckWithdrawal extends ClientMessage {
  const DeckWithdrawal();

  @override
  List<Object?> get props => const [];
}

/// Игрок уходит из лобби: хост освобождает его место сразу, не ожидая возвращения.
final class LobbyLeave extends ClientMessage {
  const LobbyLeave();

  @override
  List<Object?> get props => const [];
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
  const OpponentPresence({required this.online, required this.name, this.unstable = false, this.away = false});

  final bool online;

  /// Имя соперника из его `hello`.
  final String name;

  /// Соперник на связи, но хост давно не слышал его: связь нестабильна, обрыв ещё не засчитан.
  final bool unstable;

  /// Соперник свернул приложение: партия ждёт его возвращения, пока связь жива.
  final bool away;

  @override
  List<Object?> get props => [online, name, unstable, away];
}

/// Хост → клиент: что делает соперник в лобби. Приходит при каждом его изменении и сразу после подключения.
final class OpponentLobby extends HostMessage {
  const OpponentLobby(this.stage, {this.leader});

  final LobbyStage stage;

  /// Лидер выбранной колоды соперника; `null`, пока колода не выбрана.
  final LeaderId? leader;

  @override
  List<Object?> get props => [stage, leader];
}

/// Хост → клиент: оба игрока готовы, партия начнётся через [duration].
final class CountdownStart extends HostMessage {
  const CountdownStart(this.duration);

  final Duration duration;

  @override
  List<Object?> get props => [duration];
}

/// Хост → клиент: отсчёт прерван (игрок отозвал колоду, ушёл или потерял связь), партия не начнётся.
final class CountdownCancel extends HostMessage {
  const CountdownCancel();

  @override
  List<Object?> get props => const [];
}

/// Хост → клиент: соперник ушёл из лобби, его место свободно.
final class OpponentLeave extends HostMessage {
  const OpponentLeave();

  @override
  List<Object?> get props => const [];
}

/// Хост → клиент: хост закрыл лобби; следом закрывается соединение, возвращаться некуда.
final class LobbyClose extends HostMessage {
  const LobbyClose();

  @override
  List<Object?> get props => const [];
}

/// Хост → клиент: хост пустил игрока в лобби. До этого сообщения игрок ждёт решения хоста (ADR 0022).
final class Admitted extends HostMessage {
  const Admitted();

  @override
  List<Object?> get props => const [];
}
