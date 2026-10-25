import 'package:gwent/src/features/content/domain/game_content.dart';
import 'package:gwent/src/features/match/application/start_match.dart';
import 'package:gwent/src/features/match/domain/awaited_action.dart';
import 'package:gwent/src/features/match/domain/rematch_offer.dart';
import 'package:gwent/src/features/match/presentation/match_roster.dart';
import 'package:gwent/src/features/match_history/domain/match_record.dart' show MatchRecord;
import 'package:gwent_engine/gwent_engine.dart';
import 'package:meta/meta.dart';

/// Состояние экрана партии.
@immutable
sealed class MatchScreenState {
  const MatchScreenState();
}

/// Партия ещё не начата: игрок выбирает режим и колоды.
final class MatchIdle extends MatchScreenState {
  /// Создаёт состояние.
  const MatchIdle();
}

/// Партия начинается: загрузка контента и колод, раздача.
final class MatchStarting extends MatchScreenState {
  /// Создаёт состояние.
  const MatchStarting();
}

/// Партию начать не удалось: контента нет, колоды нет или она не по правилам.
final class MatchStartFailed extends MatchScreenState {
  /// Создаёт состояние.
  const MatchStartFailed(this.reason);

  /// Итог сценария с причиной: `MatchContentUnavailable`, `MatchDeckNotFound` или `MatchDeckInvalid`.
  final StartMatchResult reason;
}

/// Знакомство: кто с кем играет, фракции, лидеры и колоды (макет 4, экран 1). Держится, пока игрок не нажмёт или
/// не выйдет время; экран нейтральный, рук на нём нет.
final class MatchIntro extends MatchScreenState {
  /// Создаёт состояние.
  const MatchIntro(this.roster);

  /// Участники партии.
  final MatchRoster roster;
}

/// Жребий или итог выбора Скоя'таэлей: кто ходит первым (макет 4, экран 2). Нейтральный экран.
final class MatchToss extends MatchScreenState {
  /// Создаёт состояние.
  const MatchToss({required this.roster, required this.first, required this.byChoice});

  /// Участники партии.
  final MatchRoster roster;

  /// Кто ходит первым.
  final Seat first;

  /// Решил игрок Скоя'таэлей, а не жребий.
  final bool byChoice;
}

/// Зачем передаётся телефон: от этого зависит подпись на экране передачи.
enum HandoverKind {
  /// Игрок Скоя'таэлей решает, кто ходит первым.
  firstPlayerChoice,

  /// Пересдача карт.
  redraw,

  /// Первый ход партии.
  firstMove,

  /// Ход в ходе партии.
  turn,
}

/// Hot-seat: телефон передаётся игроку [next]; его руку показывать нельзя, пока он не подтвердит.
final class MatchHandover extends MatchScreenState {
  /// Создаёт состояние.
  const MatchHandover(this.next, {required this.kind, required this.roster});

  /// Кто берёт телефон.
  final Seat next;

  /// Что он будет делать.
  final HandoverKind kind;

  /// Участники партии.
  final MatchRoster roster;
}

/// Партия идёт; экран показывает её глазами `view.viewer`.
final class MatchInProgress extends MatchScreenState {
  /// Создаёт состояние.
  MatchInProgress({
    required this.view,
    required this.content,
    required this.roster,
    required List<GameEvent> events,
    this.refusal,
    this.closing,
  }) : events = List.unmodifiable(events);

  /// Что видит игрок, который держит телефон.
  final PlayerView view;

  /// Контент партии: по нему экран рисует карты проекции.
  final GameContent content;

  /// Участники партии: по ним экран называет игроков.
  final MatchRoster roster;

  /// События, которых этот игрок ещё не видел, по порядку: для анимаций и журнала хода. В hot-seat сюда
  /// попадает и всё, что сделал соперник, пока телефон был у него.
  final List<GameEvent> events;

  /// Движок отклонил последнее действие игрока: интерфейс разошёлся с партией, состояние не изменилось.
  final Reject? refusal;

  /// Поле раунда, который закончился в [events], как оно стояло перед последним действием (пасом): в [view] ряды уже
  /// очищены, а подсчёт и уход карт показывают по этой проекции. `null`, если в [events] раунд не кончался.
  final PlayerView? closing;

  /// Партия ждёт действия от этого игрока; иначе ход соперника (бот думает или выбирает).
  bool get awaitsMe => awaitsAction(view);
}

/// Пересдача: игрок поменял последнюю карту. Экран держит руку с пришедшей картой, пока её видно, и только потом
/// идёт следующее состояние: ожидание соперника, передача телефона или поле. Нейтральная заставка, действий она
/// не принимает.
final class MatchRedrawSettled extends MatchScreenState {
  /// Создаёт состояние.
  MatchRedrawSettled({required this.view, required this.roster, required List<GameEvent> events})
    : events = List.unmodifiable(events);

  /// Проекция игрока после последней замены: в руке уже пришедшая карта.
  final PlayerView view;

  /// Участники партии.
  final MatchRoster roster;

  /// События замены (`CardRedrawn`) этого игрока: по ним играет звук. Остальные события придут со следующим состоянием.
  final List<GameEvent> events;
}

/// Партия окончена.
final class MatchFinished extends MatchScreenState {
  /// Создаёт состояние.
  MatchFinished({
    required this.view,
    required this.roster,
    required List<GameEvent> events,
    this.record,
    this.canRematch = false,
    this.rematch,
  }) : events = List.unmodifiable(events);

  /// Итоговая проекция: счёт раундов в `history`, победитель в `outcome`.
  final PlayerView view;

  /// Участники партии.
  final MatchRoster roster;

  /// Партию можно сыграть заново с теми же колодами (местная партия); сетевую так не повторить.
  final bool canRematch;

  /// Договорённость о реванше в сетевой партии; `null` в местной, где реванш — просто [canRematch].
  final RematchOffer? rematch;

  /// Последние события партии, которых игрок ещё не видел.
  final List<GameEvent> events;

  /// Запись в истории партий; `null`, пока она сохраняется или если сохранить не удалось.
  final MatchRecord? record;

  /// Итог партии.
  MatchOutcome get outcome => view.outcome!;

  /// Копия с другим предложением реванша.
  MatchFinished withRematch(RematchOffer offer) =>
      MatchFinished(view: view, roster: roster, events: events, record: record, canRematch: canRematch, rematch: offer);
}

/// Оба игрока сетевой партии согласились на реванш: экран уходит в комнату, где они выбирают колоды заново.
final class MatchRematchAgreed extends MatchScreenState {
  /// Создаёт состояние.
  const MatchRematchAgreed();
}

/// Партия прервалась: соперник не смог сделать ход (ошибка бота или движка).
final class MatchCrashed extends MatchScreenState {
  /// Создаёт состояние.
  const MatchCrashed(this.error);

  /// Причина для журнала; игроку показывается общее сообщение.
  final Object error;
}
