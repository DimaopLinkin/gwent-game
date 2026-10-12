import 'package:gwent_engine/gwent_engine.dart';
import 'package:meta/meta.dart';

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
    this.showOpponentPassed = false,
    this.recent = const {},
    this.sort = DiscardSort.byStrength,
  });

  /// Выбранная карта руки.
  final CardInstanceId? selected;

  /// Лист поверх поля.
  final FieldOverlay overlay;

  /// Тост, пока он показывается.
  final FieldToast? toast;

  /// Показывается баннер «Противник спасовал»; экран убирает его по таймеру через `clearBanner`.
  final bool showOpponentPassed;

  /// Карты, которые только что легли на стол: их подсвечивает вспышка.
  final Set<CardInstanceId> recent;

  /// Порядок карт в листе сброса.
  final DiscardSort sort;

  /// Копия с заменёнными полями; [clearSelected] и [clearToast] обнуляют выбор и тост.
  FieldState copyWith({
    CardInstanceId? selected,
    bool clearSelected = false,
    FieldOverlay? overlay,
    FieldToast? toast,
    bool clearToast = false,
    bool? showOpponentPassed,
    Set<CardInstanceId>? recent,
    DiscardSort? sort,
  }) => FieldState(
    selected: clearSelected ? null : selected ?? this.selected,
    overlay: overlay ?? this.overlay,
    toast: clearToast ? null : toast ?? this.toast,
    showOpponentPassed: showOpponentPassed ?? this.showOpponentPassed,
    recent: recent ?? this.recent,
    sort: sort ?? this.sort,
  );
}
