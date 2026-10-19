import 'package:gwent/src/features/match/presentation/field/round_summary.dart';
import 'package:gwent/src/features/match/presentation/stage/stage_script.dart';
import 'package:gwent_engine/gwent_engine.dart';
import 'package:meta/meta.dart';

export 'package:gwent/src/features/match/presentation/field/round_summary.dart';

/// Лист поверх поля, которым управляет сам игрок (листы выбора, которого ждёт движок, строятся из проекции).
@immutable
sealed class FieldOverlay {
  const FieldOverlay();
}

/// Листов нет.
final class NoOverlay extends FieldOverlay {
  /// Создаёт состояние.
  const NoOverlay();
}

/// Лист сброса: свой ([mine]) или соперника. Сброс открыт обоим игрокам.
final class DiscardOverlay extends FieldOverlay {
  /// Создаёт состояние.
  const DiscardOverlay({required this.mine});

  /// Чей сброс.
  final bool mine;
}

/// Лист лидера: полная карта, способность и кнопка «Использовать».
final class LeaderOverlay extends FieldOverlay {
  /// Создаёт состояние.
  const LeaderOverlay({required this.mine});

  /// Чей лидер.
  final bool mine;
}

/// Три карты руки соперника, которые показал лидер.
final class RevealOverlay extends FieldOverlay {
  /// Создаёт состояние.
  RevealOverlay(List<CardInstance> cards) : cards = List.unmodifiable(cards);

  /// Показанные карты.
  final List<CardInstance> cards;
}

/// Порядок карт в листе сброса.
enum DiscardSort {
  /// По убыванию силы, особые карты в конце.
  byStrength,

  /// В порядке сброса, сверху последняя.
  byOrder,
}

/// Баннер на всю ширину поля (макет 5): объявляет раунд, ход или пас. Показывается по одному, по очереди.
@immutable
sealed class FieldBanner {
  const FieldBanner();
}

/// Начало раунда [round]; [decisive] — у обоих остался последний кристалл («Решающий раунд»).
final class RoundStartBanner extends FieldBanner {
  /// Создаёт баннер.
  const RoundStartBanner({required this.round, required this.decisive});

  /// Номер раунда.
  final int round;

  /// У каждого по одному кристаллу.
  final bool decisive;
}

/// Ход перешёл к [seat]; [mine] — это место игрока, который держит телефон.
final class TurnStartBanner extends FieldBanner {
  /// Создаёт баннер.
  const TurnStartBanner({required this.seat, required this.mine});

  /// Чей ход.
  final Seat seat;

  /// Ход того, кто смотрит на экран.
  final bool mine;
}

/// [seat] спасовал; [mine] — это место игрока, который держит телефон.
final class PassBanner extends FieldBanner {
  /// Создаёт баннер.
  const PassBanner({required this.seat, required this.mine});

  /// Кто спасовал.
  final Seat seat;

  /// Спасовал тот, кто смотрит на экран.
  final bool mine;
}

/// Слой паузы поверх поля: меню паузы, справочник правил или подтверждение сдачи.
enum PauseLayer {
  /// Игра идёт.
  none,

  /// Меню паузы.
  menu,

  /// Справочник правил (открывается из меню паузы).
  rules,

  /// «Сдаться?» (открывается из меню паузы).
  surrenderConfirm,
}

/// Короткое сообщение игроку (тост); текст подбирает экран по строкам интерфейса.
enum FieldMessage {
  /// Нажали карту в руке, пока ходит соперник.
  opponentTurn,

  /// Нажали карту в руке после своего паса.
  alreadyPassed,

  /// Ход сейчас мой, но эту карту сыграть некуда.
  cardNotPlayable,

  /// Движок отклонил действие: интерфейс разошёлся с партией.
  refused,
}

/// Тост с номером: новое сообщение того же вида показывается заново.
@immutable
final class FieldToast {
  /// Создаёт тост.
  const FieldToast(this.id, this.message);

  /// Номер показа.
  final int id;

  /// Что сказать.
  final FieldMessage message;

  /// Сообщение об ошибке: красная рамка и иконка.
  bool get isError => message == FieldMessage.refused;
}

/// Состояние оверлеев и выбора на поле.
@immutable
final class FieldState {
  /// Создаёт состояние.
  const FieldState({
    this.selected,
    this.overlay = const NoOverlay(),
    this.toast,
    this.banners = const [],
    this.summary,
    this.pause = PauseLayer.none,
    this.recent = const {},
    this.sort = DiscardSort.byStrength,
    this.finishing = false,
    this.stage,
  });

  /// Выбранная карта руки.
  final CardInstanceId? selected;

  /// Лист поверх поля.
  final FieldOverlay overlay;

  /// Тост, пока он показывается.
  final FieldToast? toast;

  /// Очередь баннеров; показывается первый, экран убирает его по таймеру через `dismissBanner`.
  final List<FieldBanner> banners;

  /// Итог раунда, пока игрок его не закрыл.
  final RoundSummary? summary;

  /// Слой паузы.
  final PauseLayer pause;

  /// Карты, которые только что легли на стол: их подсвечивает вспышка.
  final Set<CardInstanceId> recent;

  /// Порядок карт в листе сброса.
  final DiscardSort sort;

  /// Партия закончена, и поле ещё держит последний ход и счёт на экране, прежде чем открыть итог матча.
  final bool finishing;

  /// Сценарий показа последнего обновления партии (розыгрыш карты и эффекты, макет 12), пока он идёт.
  final StageScript? stage;

  /// Поле что-то показывает или ждёт игрока и не принимает ходов: идут баннеры, открыт итог раунда или пауза, поле
  /// держит конец партии. Пока это так, экран партии откладывает следующие состояния партии и не пускает ходы игрока.
  /// Сюда же входит показ розыгрыша карт: `FieldState.stage`.
  bool get isBusy => banners.isNotEmpty || summary != null || pause != PauseLayer.none || finishing || stage != null;

  /// Ничего не выбрано, не открыто и не показывается: состояние равно начальному.
  bool get isClean =>
      selected == null &&
      overlay is NoOverlay &&
      toast == null &&
      banners.isEmpty &&
      summary == null &&
      pause == PauseLayer.none &&
      recent.isEmpty &&
      sort == DiscardSort.byStrength &&
      !finishing &&
      stage == null;

  /// Копия с заменёнными полями; [clearSelected], [clearToast], [clearSummary] и [clearStage] обнуляют выбор, тост,
  /// итог раунда и сценарий показа.
  FieldState copyWith({
    CardInstanceId? selected,
    bool clearSelected = false,
    FieldOverlay? overlay,
    FieldToast? toast,
    bool clearToast = false,
    List<FieldBanner>? banners,
    RoundSummary? summary,
    bool clearSummary = false,
    PauseLayer? pause,
    Set<CardInstanceId>? recent,
    DiscardSort? sort,
    bool? finishing,
    StageScript? stage,
    bool clearStage = false,
  }) => FieldState(
    selected: clearSelected ? null : selected ?? this.selected,
    overlay: overlay ?? this.overlay,
    toast: clearToast ? null : toast ?? this.toast,
    banners: banners ?? this.banners,
    summary: clearSummary ? null : summary ?? this.summary,
    pause: pause ?? this.pause,
    recent: recent ?? this.recent,
    sort: sort ?? this.sort,
    finishing: finishing ?? this.finishing,
    stage: clearStage ? null : stage ?? this.stage,
  );
}
