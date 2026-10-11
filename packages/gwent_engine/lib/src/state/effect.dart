import 'package:gwent_engine/src/cards/row.dart';
import 'package:gwent_engine/src/core/value.dart';
import 'package:gwent_engine/src/state/card_instance.dart';
import 'package:gwent_engine/src/state/entry_source.dart';
import 'package:gwent_engine/src/state/seat.dart';

/// Шаг разрешения действия, который ещё не выполнен.
///
/// Эффекты лежат в стеке состояния партии. Шаг, которому нужно решение игрока (Медик, ряд проворной карты,
/// выбор лидера), останавливает разрешение до намерения `ChooseOption`. Так цепочки вроде
/// «Медик → Медик → Шпион» выполняются в одном ходу, а между выборами состояние можно сохранить и передать.
/// Это деталь движка, не часть публичного API.
sealed class Effect extends Value {
  const Effect();
}

/// Скоя'таэли решают, кто ходит первым; после выбора идут раздача и пересдача.
final class ChooseFirstPlayerEffect extends Effect {
  const ChooseFirstPlayerEffect(this.chooser);

  final Seat chooser;

  @override
  List<Object?> get props => [chooser];
}

/// Карта отряда выходит на поле. Ряд `null` у проворной карты значит, что ряд выберет игрок.
final class EnterFieldEffect extends Effect {
  const EnterFieldEffect(this.player, this.card, this.source, {this.row});

  /// Игрок, который выкладывает карту.
  final Seat player;
  final CardInstance card;
  final EntrySource source;
  final Row? row;

  @override
  List<Object?> get props => [player, card, source, row];
}

/// Медик выбирает отряд в отбое игрока.
final class MedicEffect extends Effect {
  const MedicEffect(this.player);

  final Seat player;

  @override
  List<Object?> get props => [player];
}

/// Лидер берёт обычный отряд из отбоя игрока [from] в руку [player].
final class TakeFromDiscardEffect extends Effect {
  const TakeFromDiscardEffect(this.player, this.from);

  final Seat player;
  final Seat from;

  @override
  List<Object?> get props => [player, from];
}

/// Лидер сбрасывает ещё [remaining] карт из руки.
final class DiscardFromHandEffect extends Effect {
  const DiscardFromHandEffect(this.player, this.remaining);

  final Seat player;
  final int remaining;

  @override
  List<Object?> get props => [player, remaining];
}

/// Лидер берёт ещё [remaining] выбранных карт из колоды.
final class TakeFromDeckEffect extends Effect {
  const TakeFromDeckEffect(this.player, this.remaining);

  final Seat player;
  final int remaining;

  @override
  List<Object?> get props => [player, remaining];
}

/// Лидер выбирает в колоде карту погоды и сразу играет её.
final class PickWeatherFromDeckEffect extends Effect {
  const PickWeatherFromDeckEffect(this.player);

  final Seat player;

  @override
  List<Object?> get props => [player];
}

/// Действие игрока разрешено полностью: ход переходит дальше.
final class EndTurnEffect extends Effect {
  const EndTurnEffect(this.player);

  final Seat player;

  @override
  List<Object?> get props => [player];
}

/// Эффекты начала раунда выполнены: проверка автопаса и первый ход.
final class BeginTurnsEffect extends Effect {
  const BeginTurnsEffect();

  @override
  List<Object?> get props => const [];
}
