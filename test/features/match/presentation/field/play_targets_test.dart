import 'package:flutter_test/flutter_test.dart';
import 'package:gwent/src/features/content/domain/game_content.dart';
import 'package:gwent/src/features/match/presentation/field/play_targets.dart';
import 'package:gwent_engine/gwent_engine.dart';

import '../../../../support/match_fixtures.dart';
import 'field_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late GameContent content;
  late TestCards cards;

  setUpAll(() async => content = await loadBaseContent());
  setUp(() => cards = TestCards(content));

  PlayTargets targetsOf(CardInstance card, {SideView? me, Set<CardInstanceId>? playable}) {
    final view = viewOf(
      cards,
      me: me ?? sideOf(cards, Seat.one, hand: [card], playable: playable),
    );
    return PlayTargets.forCard(view, card, content.catalog);
  }

  test('обычный отряд идёт только в свой ряд', () {
    final unit = cards.unit(Row.ranged);
    final targets = targetsOf(unit);
    expect(targets.kind, PlayTargetKind.ownRow);
    expect(targets.rows, {Row.ranged});
    expect(targets.highlightsRow(Row.ranged, mine: true), isTrue);
    expect(targets.highlightsRow(Row.ranged, mine: false), isFalse);
    expect(targets.highlightsRow(Row.melee, mine: true), isFalse);
    expect(targets.atRow(Row.ranged, mine: true), PlayCard(unit.id, row: Row.ranged));
    expect(targets.atRow(Row.melee, mine: true), isNull);
    expect(targets.atStrip(), isNull);
  });

  test('проворный отряд выбирает из ближнего и дальнего рядов', () {
    final agile = cards.agile();
    final targets = targetsOf(agile);
    expect(targets.rows, {Row.melee, Row.ranged});
    expect(targets.atRow(Row.melee, mine: true), PlayCard(agile.id, row: Row.melee));
    expect(targets.atRow(Row.ranged, mine: true), PlayCard(agile.id, row: Row.ranged));
    expect(targets.atRow(Row.siege, mine: true), isNull);
  });

  test('шпион уходит в ряд соперника того же типа', () {
    final spy = cards.spy();
    final targets = targetsOf(spy);
    expect(targets.kind, PlayTargetKind.opponentRow);
    final row = targets.rows.single;
    expect(targets.highlightsRow(row, mine: false), isTrue);
    expect(targets.highlightsRow(row, mine: true), isFalse);
    expect(targets.atRow(row, mine: false), PlayCard(spy.id, row: row));
    expect(targets.atRow(row, mine: true), isNull);
  });

  test('погода, Ясное небо и Казнь играются на центральную полосу без цели', () {
    for (final card in [
      cards.special<WeatherAbility>(),
      cards.special<ClearWeatherAbility>(),
      cards.special<ScorchAbility>(),
    ]) {
      final targets = targetsOf(card);
      expect(targets.kind, PlayTargetKind.strip);
      expect(targets.highlightsStrip, isTrue);
      expect(targets.atStrip(), PlayCard(card.id));
      expect(targets.atRow(Row.melee, mine: true), isNull);
    }
  });

  test('рог идёт в любой свой ряд, занятый слот тоже цель', () {
    final horn = cards.special<HornCardAbility>();
    final me = sideOf(
      cards,
      Seat.one,
      hand: [horn],
      rows: {Row.melee: const RowView(cards: [], slot: LeaderHornSlot(), weather: false, strength: 0)},
    );
    final targets = targetsOf(horn, me: me);
    expect(targets.kind, PlayTargetKind.hornSlot);
    expect(targets.rows, Row.values.toSet());
    expect(targets.highlightsHornSlot(Row.ranged), isTrue);
    expect(targets.highlightsHornSlot(Row.melee), isTrue);
    expect(targets.atRow(Row.melee, mine: true), PlayCard(horn.id, row: Row.melee));
    expect(targets.atRow(Row.siege, mine: true), PlayCard(horn.id, row: Row.siege));
    expect(targets.atRow(Row.ranged, mine: false), isNull);
  });

  test('рог можно играть, когда заняты все слоты: карта уйдёт в отбой', () {
    final horn = cards.special<HornCardAbility>();
    final taken = RowView(
      cards: const [],
      slot: CardSlot(cards.special<HornCardAbility>()),
      weather: false,
      strength: 0,
    );
    final me = sideOf(cards, Seat.one, hand: [horn], rows: {for (final row in Row.values) row: taken});
    final targets = targetsOf(horn, me: me);
    expect(targets.isEmpty, isFalse);
    expect(targets.rows, Row.values.toSet());
  });

  test('Чучело подсвечивает свои отряды, кроме героев', () {
    final decoy = cards.special<DecoyAbility>();
    final unit = cards.unit(Row.melee);
    final hero = cards.hero();
    final me = sideOf(
      cards,
      Seat.one,
      hand: [decoy],
      rows: {
        Row.melee: rowOf([unit, hero], cards),
      },
    );
    final targets = targetsOf(decoy, me: me);
    expect(targets.kind, PlayTargetKind.decoy);
    expect(targets.highlightsFieldCard(unit.id), isTrue);
    expect(targets.highlightsFieldCard(hero.id), isFalse);
    expect(targets.atFieldCard(unit.id), PlayCard(decoy.id, target: unit.id));
    expect(targets.atFieldCard(hero.id), isNull);
  });

  test('Чучелу нечего заменять на пустом поле', () {
    final decoy = cards.special<DecoyAbility>();
    expect(targetsOf(decoy).isEmpty, isTrue);
  });

  test('карта вне набора допустимых не играется: целей нет', () {
    final unit = cards.unit(Row.melee);
    final targets = targetsOf(unit, playable: const {});
    expect(targets.kind, PlayTargetKind.none);
    expect(targets.isEmpty, isTrue);
    expect(targets.card, isNull);
    expect(targets.atRow(Row.melee, mine: true), isNull);
  });
}
