import 'package:gwent_engine/gwent_engine.dart';
import 'package:meta/meta.dart';

/// Куда можно сыграть выбранную карту руки.
enum PlayTargetKind {
  /// Сейчас карту сыграть нельзя: не ваш ход, нет цели.
  none,

  /// Свои ряды: отряд кладётся в ряд, проворный выбирает из двух.
  ownRow,

  /// Ряд соперника того же типа: шпион уходит на его сторону.
  opponentRow,

  /// Слоты рога своих рядов: Командирский рог и Мардрём. В занятый слот карта уходит в отбой.
  hornSlot,

  /// Центральная полоса: погода, Ясное небо и Казнь, которым цель не нужна.
  strip,

  /// Свои отряды на поле: Чучело возвращает отряд в руку.
  decoy,
}

/// Допустимые цели хода для карты руки (макет оверлеев, раздел «Выбор цели на поле») и намерения для движка.
///
/// Чистая логика над проекцией и справочником: решает, какие зоны поля подсветить, какие нажатия принимать и какое
/// `PlayCard` отправить. Окончательно ход проверяет движок: здесь только то, чтобы игрок не промахивался.
@immutable
final class PlayTargets {
  const PlayTargets._(
    this.kind,
    this.card, {
    this.rows = const {},
    this.fieldCards = const {},
    this.occupiedSlots = const {},
  });

  /// Целей нет.
  static const PlayTargets none = PlayTargets._(PlayTargetKind.none, null);

  /// Цели карты [card] из руки игрока `view.viewer`.
  factory PlayTargets.forCard(PlayerView view, CardInstance card, CardCatalog catalog) {
    if (!view.me.playable.contains(card.id)) return none;
    switch (catalog.card(card.cardId)) {
      case UnitCardDefinition(:final placement, :final ability):
        final rows = placement.rows.toSet();
        return PlayTargets._(
          ability is SpyAbility ? PlayTargetKind.opponentRow : PlayTargetKind.ownRow,
          card,
          rows: rows,
        );
      case SpecialCardDefinition(:final ability):
        switch (ability) {
          case WeatherAbility() || ClearWeatherAbility() || ScorchAbility():
            return PlayTargets._(PlayTargetKind.strip, card);
          case HornCardAbility() || MardremCardAbility():
            // Занятый слот тоже цель: карта применится вхолостую и уйдёт в отбой (правила 9.3).
            final occupied = {
              for (final MapEntry(key: row, value: rowView) in view.me.rows.entries)
                if (rowView.slot != null) row,
            };
            return PlayTargets._(
              PlayTargetKind.hornSlot,
              card,
              rows: Row.values.toSet(),
              occupiedSlots: occupied,
            );
          case DecoyAbility():
            final units = {
              for (final rowView in view.me.rows.values)
                for (final fieldCard in rowView.cards)
                  if (catalog.card(fieldCard.card.cardId) case UnitCardDefinition(isHero: false)) fieldCard.card.id,
            };
            return units.isEmpty ? none : PlayTargets._(PlayTargetKind.decoy, card, fieldCards: units);
        }
      case null:
        return none;
    }
  }

  /// Вид цели.
  final PlayTargetKind kind;

  /// Карта руки, которую играют; `null`, если целей нет.
  final CardInstance? card;

  /// Ряды: свои для [PlayTargetKind.ownRow] и [PlayTargetKind.hornSlot], соперника для
  /// [PlayTargetKind.opponentRow].
  final Set<Row> rows;

  /// Ряды, где слот рога уже занят: рог или Мардрём, сыгранные туда, сразу уйдут в отбой.
  final Set<Row> occupiedSlots;

  /// Свои отряды, на которые можно положить Чучело.
  final Set<CardInstanceId> fieldCards;

  /// Играть некуда.
  bool get isEmpty => kind == PlayTargetKind.none;

  /// Подсвечивается ли ряд [row] у стороны [mine].
  bool highlightsRow(Row row, {required bool mine}) =>
      rows.contains(row) &&
      switch (kind) {
        PlayTargetKind.ownRow || PlayTargetKind.hornSlot => mine,
        PlayTargetKind.opponentRow => !mine,
        PlayTargetKind.none || PlayTargetKind.strip || PlayTargetKind.decoy => false,
      };

  /// Подсвечивается ли слот рога моего ряда [row].
  bool highlightsHornSlot(Row row) => kind == PlayTargetKind.hornSlot && rows.contains(row);

  /// Карта, сыгранная в слот рога ряда [row], уйдёт в отбой впустую.
  bool wastesCard(Row row) => kind == PlayTargetKind.hornSlot && occupiedSlots.contains(row);

  /// Подсвечивается ли моя карта на поле (Чучело).
  bool highlightsFieldCard(CardInstanceId id) => kind == PlayTargetKind.decoy && fieldCards.contains(id);

  /// Подсвечивается ли центральная полоса.
  bool get highlightsStrip => kind == PlayTargetKind.strip;

  /// Ход по нажатию или броску на ряд [row] стороны [mine]; `null`, если ряд не цель.
  PlayCard? atRow(Row row, {required bool mine}) =>
      highlightsRow(row, mine: mine) ? PlayCard(card!.id, row: row) : null;

  /// Ход по нажатию или броску на центральную полосу.
  PlayCard? atStrip() => highlightsStrip ? PlayCard(card!.id) : null;

  /// Ход по нажатию на свою карту на поле (Чучело).
  PlayCard? atFieldCard(CardInstanceId target) =>
      highlightsFieldCard(target) ? PlayCard(card!.id, target: target) : null;
}
