import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gwent/src/core/presentation/card/card_face.dart';
import 'package:gwent/src/core/presentation/card/card_highlight.dart';
import 'package:gwent/src/core/presentation/card/card_size.dart';
import 'package:gwent/src/core/presentation/card/gwent_card.dart';
import 'package:gwent/src/core/presentation/card/parts/card_art_overlays.dart';
import 'package:gwent/src/core/presentation/card/parts/card_plaque.dart';
import 'package:gwent/src/core/presentation/card/parts/leader_marker.dart';
import 'package:gwent/src/core/presentation/card/parts/power_medallion.dart';
import 'package:gwent/src/core/presentation/card/parts/spy_ribbon.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_faction.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_icon.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_weather.dart';

import '../../../support/localized_app.dart';

const _unit = UnitCardFace(
  art: null,
  name: 'Лучник клана Броквар',
  faction: GwentFaction.skellige,
  basePower: 6,
  row: GwentIcon.rowRanged,
  ability: GwentIcon.abilityTightBond,
);

const _faces = <CardFace>[
  _unit,
  UnitCardFace(
    art: null,
    name: 'Хьялмар',
    faction: GwentFaction.skellige,
    basePower: 10,
    row: GwentIcon.rowRanged,
    isHero: true,
  ),
  SpecialCardFace(
    art: null,
    name: 'Командирский рог',
    faction: GwentFaction.neutral,
    effect: GwentIcon.specialCommanderHorn,
  ),
  WeatherCardFace(art: null, name: 'Мороз', weather: GwentWeather.frost),
  LeaderCardFace(
    art: null,
    name: 'Эмгыр вар Эмрейс: Белое Пламя, Пляшущее на Курганах Врагов',
    faction: GwentFaction.nilfgaard,
  ),
  CardBackFace(faction: GwentFaction.skellige),
];

Future<void> _pump(WidgetTester tester, Widget card) => tester.pumpWidget(localizedApp(Center(child: card)));

void main() {
  testWidgets('каждый вариант в каждом размере рисуется в размер макета без переполнений', (tester) async {
    for (final face in _faces) {
      for (final size in CardSize.values) {
        await _pump(tester, GwentCard(face: face, size: size));
        expect(tester.takeException(), isNull, reason: '${face.runtimeType} $size');
        expect(
          tester.getSize(find.byType(GwentCard)),
          Size(size.metrics.width, size.metrics.height),
          reason: '${face.runtimeType} $size',
        );
      }
    }
  });

  testWidgets('плашка с названием есть на полной карте, в сетке и на руке, но не в ряду и не на мини-карте', (
    tester,
  ) async {
    for (final size in CardSize.values) {
      await _pump(tester, GwentCard(face: _unit, size: size));
      expect(find.byType(CardPlaque), size.hasPlaque ? findsOneWidget : findsNothing, reason: '$size');
    }
  });

  testWidgets('медальон силы показывает усиление, ослабление и героя', (tester) async {
    Future<PowerLook> lookOf(UnitCardFace face) async {
      await _pump(tester, GwentCard(face: face, size: CardSize.hand));
      return tester.widget<PowerMedallion>(find.byType(PowerMedallion)).look;
    }

    UnitCardFace withPower(int power, {bool hero = false}) => UnitCardFace(
      art: null,
      name: 'Лучник',
      faction: GwentFaction.skellige,
      basePower: 6,
      power: power,
      row: GwentIcon.rowRanged,
      isHero: hero,
    );

    expect(await lookOf(withPower(6)), PowerLook.base);
    expect(await lookOf(withPower(12)), PowerLook.buffed);
    expect(await lookOf(withPower(1)), PowerLook.debuffed);
    expect(await lookOf(withPower(10, hero: true)), PowerLook.hero);
  });

  testWidgets('иней под погодой рисуется на отряде, но не на герое', (tester) async {
    UnitCardFace frosted({required bool hero}) => UnitCardFace(
      art: null,
      name: 'Лучник',
      faction: GwentFaction.skellige,
      basePower: 6,
      power: 1,
      row: GwentIcon.rowRanged,
      isHero: hero,
      frosted: true,
    );

    await _pump(tester, GwentCard(face: frosted(hero: false), size: CardSize.hand));
    expect(find.byType(CardFrostLayer), findsOneWidget);
    await _pump(tester, GwentCard(face: frosted(hero: true), size: CardSize.hand));
    expect(find.byType(CardFrostLayer), findsNothing);
  });

  testWidgets('подпись способности лидера только на полной карте', (tester) async {
    const leader = LeaderCardFace(art: null, name: 'Крах ан Крайт', faction: GwentFaction.skellige);
    await _pump(tester, const GwentCard(face: leader, size: CardSize.full));
    expect(find.text('Доступна'), findsOneWidget);
    await _pump(
      tester,
      const GwentCard(
        face: LeaderCardFace(art: null, name: 'Крах ан Крайт', faction: GwentFaction.skellige, abilityUsed: true),
        size: CardSize.full,
      ),
    );
    expect(find.text('Использована'), findsOneWidget);
    for (final size in [CardSize.grid, CardSize.hand, CardSize.row, CardSize.mini]) {
      await _pump(tester, GwentCard(face: leader, size: size));
      expect(find.byType(LeaderMarker), findsOneWidget, reason: '$size');
      expect(find.text('Доступна'), findsNothing, reason: '$size');
    }
  });

  testWidgets('выбранная карта поднимается на высоту из макета', (tester) async {
    await _pump(tester, const GwentCard(face: _unit, size: CardSize.hand));
    final rest = tester.getTopLeft(find.byType(CardPlaque));
    await _pump(tester, const GwentCard(face: _unit, size: CardSize.hand, highlight: CardHighlight.selected));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.byType(CardPlaque)).dy, rest.dy - CardSize.hand.metrics.lift);
  });

  testWidgets('недоступная карта обесцвечена, шпион помечен лентой', (tester) async {
    await _pump(tester, const GwentCard(face: _unit, size: CardSize.hand, highlight: CardHighlight.disabled));
    expect(find.descendant(of: find.byType(GwentCard), matching: find.byType(ColorFiltered)), findsOneWidget);

    await _pump(tester, const GwentCard(face: _unit, size: CardSize.hand, highlight: CardHighlight.spy));
    expect(find.byType(SpyRibbon), findsOneWidget);
  });

  testWidgets('только что сыгранная карта гаснет за 600 мс без ошибок', (tester) async {
    await _pump(tester, const GwentCard(face: _unit, size: CardSize.hand, highlight: CardHighlight.justPlayed));
    await tester.pump(GwentCard.justPlayedDuration);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('касание и удержание 0,45 с вызывают свои колбэки', (tester) async {
    var taps = 0;
    var longPresses = 0;
    await _pump(
      tester,
      GwentCard(face: _unit, size: CardSize.hand, onTap: () => taps++, onLongPress: () => longPresses++),
    );

    await tester.tap(find.byType(GwentCard));
    expect((taps, longPresses), (1, 0));

    final gesture = await tester.startGesture(tester.getCenter(find.byType(GwentCard)));
    await tester.pump(const Duration(milliseconds: 300));
    expect(longPresses, 0);
    await tester.pump(const Duration(milliseconds: 200));
    await gesture.up();
    expect((taps, longPresses), (1, 1));
  });

  testWidgets('скринридер слышит имя и силу отряда, а у рубашки — что это рубашка', (tester) async {
    final semantics = tester.ensureSemantics();
    await _pump(tester, GwentCard(face: _unit, size: CardSize.hand, onTap: () {}));
    expect(find.bySemanticsLabel('Лучник клана Броквар, сила 6'), findsOneWidget);
    await _pump(
      tester,
      const GwentCard(
        face: CardBackFace(faction: GwentFaction.skellige),
        size: CardSize.hand,
      ),
    );
    expect(find.bySemanticsLabel('Рубашка карты'), findsOneWidget);
    semantics.dispose();
  });
}
