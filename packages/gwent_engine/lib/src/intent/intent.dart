import 'package:gwent_engine/src/cards/ids.dart';
import 'package:gwent_engine/src/cards/row.dart';
import 'package:gwent_engine/src/core/value.dart';
import 'package:gwent_engine/src/state/choice.dart';

/// Намерение игрока. По сети передаются только намерения, а не состояние.
sealed class Intent extends Value {
  const Intent();
}

/// Заменить карту руки при пересдаче.
final class RedrawCard extends Intent {
  const RedrawCard(this.card);

  final CardInstanceId card;

  @override
  List<Object?> get props => [card];
}

/// Закончить пересдачу.
final class FinishRedraw extends Intent {
  const FinishRedraw();

  @override
  List<Object?> get props => const [];
}

/// Сыграть карту из руки.
///
/// [row] нужен проворной карте (ближний или дальний ряд), Командирскому рогу и Мардрёму (ряд слота);
/// у остальных карт он либо не указывается, либо совпадает с рядом карты.
/// [target] нужен Чучелу: отряд на своей стороне, который вернётся в руку.
final class PlayCard extends Intent {
  const PlayCard(this.card, {this.row, this.target});

  final CardInstanceId card;
  final Row? row;
  final CardInstanceId? target;

  @override
  List<Object?> get props => [card, row, target];
}

/// Применить активную способность лидера.
final class UseLeader extends Intent {
  const UseLeader();

  @override
  List<Object?> get props => const [];
}

/// Спасовать до конца раунда.
final class Pass extends Intent {
  const Pass();

  @override
  List<Object?> get props => const [];
}

/// Ответ на выбор, которого ждёт партия.
final class ChooseOption extends Intent {
  const ChooseOption(this.option);

  final ChoiceOption option;

  @override
  List<Object?> get props => [option];
}

/// Сдаться: партия заканчивается победой соперника.
final class Resign extends Intent {
  const Resign();

  @override
  List<Object?> get props => const [];
}
